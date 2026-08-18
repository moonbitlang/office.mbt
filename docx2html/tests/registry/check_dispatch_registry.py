#!/usr/bin/env python3
"""Reconcile the committed dispatch registry with the docx package's readers.

`docx2html/docx` contains two implementations of the same reader semantics --
`BodyReader`, and the reader-order projection whose dispatch spans
`reader_order_projection.mbt`, `annotation_scan.mbt`'s name tables, and the
scanned-tree consumers (`field_projection.mbt`, `annotation_spans.mbt`,
`run_surgery.mbt`, ...). Issue #434 unifies them. Until it lands, this check
keeps the ledger of dispatched names honest: every name a read path dispatches
on must appear in `dispatch_registry.tsv`, and every registry row must still
exist in source. Drift fails CI until the registry is updated deliberately.

Closure, and its honest limits. Every production `.mbt` in the package must be
classified below -- extracted, or exempt with a reason -- and an unclassified
file that matches either name-dispatch detector is an error, so a new file
cannot join the dispatch surface silently. Within extracted files, functions
touching `local_name` must be declared dispatch or non-dispatch, and a
comparison of any identifier against a name-shaped string in an undeclared
function is flagged as possible dispatch. What a regex cannot do is dataflow:
a name smuggled through enough indirection can still escape. The endgame is
#434 itself -- one dispatch site, no parallel ledger to keep.

Run from anywhere:  python3 docx2html/tests/registry/check_dispatch_registry.py
`--emit` regenerates rows, preserving the kind/coverage columns of existing
entries.
"""
import os, re, sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..'))
DOCX = os.path.join(ROOT, 'docx2html', 'docx')
REGISTRY = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'dispatch_registry.tsv')

# Every production .mbt file must appear here. 'extract' pulls its names into
# the registry; 'exempt' names files whose name references are not read-side
# dispatch, with the reason. A file in neither bucket that matches a detector
# fails the check.
FILES = {
    # -- the reader: dispatches on qualified names through many shapes, so
    #    every qualified name quoted anywhere in the file registers.
    'docx_reader.mbt': {'extract': {'qualified': True, 'local': None}},
    # -- the projection walker and the scanner tables: dispatch on bare local
    #    names under separate uri checks; extraction is scoped to declared
    #    functions, closed by the local_name detector.
    'reader_order_projection.mbt': {'extract': {'qualified': True, 'local': {
        'functions': {
            'ReaderOrderWalker::walk',
            'ReaderOrderWalker::walk_flow_children',
            'ReaderOrderWalker::walk_structural_element',
            'ReaderOrderWalker::walk_inline_children',
            'ReaderOrderWalker::walk_inline_element',
            'ReaderOrderWalker::walk_paragraph_extras',
            'ReaderOrderWalker::walk_text_box_extras',
            'ReaderOrderWalker::walk_pict_extras',
            'ReaderOrderWalker::sdt_declares_checkbox',
            'ReaderOrderWalker::is_deleted_paragraph_mark',
            'collect_reader_order_body_outputs',
            'reader_order_body_output_kind',
            'reader_order_is_image_output_element',
            'reader_order_is_vml_flattening_container',
            'reader_order_is_body_flattening_container',
            'reader_order_projection_visibility',
            'reader_order_atom_span',
        },
        'non_dispatch': {
            'reader_order_first_direct_wml_child',
            'reader_order_first_direct_mc_child',
            'ReaderOrderWalker::first_wml_child',
            'ReaderOrderWalker::first_mc_child',
            'ReaderOrderWalker::walk_annotation_story_containers',
            'restore_reader_projection_subtree',
        },
    }}},
    'annotation_scan.mbt': {'extract': {'qualified': True, 'local': {
        'functions': {
            'is_property_container',
            'projection_kind',
            'is_transparent_container',
            'is_suppressed_container',
            'marker_kind',
            'revision_kind',
            'is_revision_site_name',
            'deleted_text_replacement',
            'nearest_revision_site',
            'scan_story',
            'StoryScan::complexity_counters',
        },
        'non_dispatch': {
            'canonical_physical_name',
            'canonical_physical_name_chars',
            'ScannedElement::physical_path',
            'ScannedRevision::container_path',
            'ScannedMarker::after_child',
            'projection_source_is_xml_qname',
            'nearest_frame_by_kind',
            'physical_counter_key',
            'finish_frame',
            'attribute_value',
            'relationship_attribute_value',
            'validate_projection_source_namespace',
        },
    }}},
    'field_projection.mbt': {'extract': {'qualified': True, 'local': {
        'functions': {
            'reader_order_field_story_identity',
            'scan_reader_order_field_carrier',
        },
        'non_dispatch': set(),
    }}},
    'annotation_spans.mbt': {'extract': {'qualified': True, 'local': {
        'functions': {
            'span_source_offset',
            'DocxAnnotatedResult::story_paragraph_span',
            'DocxAnnotatedResult::story_run_span',
            'DocxAnnotatedResult::story_row_span',
        },
        'non_dispatch': {'DocxAnnotatedResult::revision_spans'},
    }}},
    'run_surgery.mbt': {'extract': {'qualified': True, 'local': {
        'functions': {
            'plan_whole_run_replacement',
            'run_surgery_inside_checkbox_control',
            'run_surgery_first_content_position',
        },
        'non_dispatch': set(),
    }}},
    'annotate_plan.mbt': {'extract': {'qualified': True, 'local': {
        'functions': set(),
        'non_dispatch': {'qualified_child_name'},
    }}},
    'annotate_thread.mbt': {'extract': {'qualified': True, 'local': {
        'functions': {'ensure_w14_on_root', 'scan_comment_ex_part'},
        'non_dispatch': set(),
    }}},
    'annotation_index.mbt': {'extract': {'qualified': True, 'local': None}},
    'docx_package.mbt': {'extract': {'qualified': True, 'local': None}},
    # -- writers: their names construct output. They are the writing half of
    #    the round trip, not a second reading of it, and #434's gate is about
    #    the two READ implementations agreeing.
    'write_comments.mbt': {'exempt': 'writer'},
    'write_document.mbt': {'exempt': 'writer'},
    'write_headers.mbt': {'exempt': 'writer'},
    'write_media.mbt': {'exempt': 'writer'},
    'write_notes.mbt': {'exempt': 'writer'},
    'write_numbering.mbt': {'exempt': 'writer'},
    'write_tables.mbt': {'exempt': 'writer'},
    'annotate_fragments.mbt': {'exempt': 'writer'},
    'embedded_style_map.mbt': {'exempt': 'writer'},
    'new_document.mbt': {'exempt': 'writer'},
}

FN = re.compile(r'^(?:pub(?:\(all\))? )?(?:async )?fn(?:\[[^\]]*\])? (?:(\w+)::)?(\w+)')
# Any prefix:local shape, anchored to the whole quoted string; URI-scheme
# spellings are names of things, not names of elements.
QNAME = re.compile(r'"([A-Za-z_][A-Za-z0-9_.\-]*):([A-Za-z_][A-Za-z0-9_.\-]*)"')
SCHEMES = {'urn', 'http', 'https', 'mailto', 'data'}
LOCAL_NAME_STR = re.compile(r'"([A-Za-z][A-Za-z0-9]*)"')
LOCAL_DETECT = re.compile(r'\blocal_name\b')
# an identifier compared against a name-shaped string: the smuggled-dispatch tell
COMPARISON = re.compile(r'(?:==|\bis)\s+"[A-Za-z][A-Za-z0-9]*"')
FRAGMENT = re.compile(r'"(?::[A-Za-z][A-Za-z0-9]*|[A-Za-z][A-Za-z0-9]*:)"')

def strip_comments(line):
    """Cut `// ...` when not inside a string literal."""
    out, in_str, i = [], False, 0
    while i < len(line):
        c = line[i]
        if in_str:
            if c == '\\':
                out.append(line[i:i+2]); i += 2; continue
            if c == '"':
                in_str = False
            out.append(c)
        else:
            if c == '"':
                in_str = True
                out.append(c)
            elif c == '/' and line[i:i+2] == '//':
                break
            else:
                out.append(c)
        i += 1
    return ''.join(out)

def functions(lines):
    """(name, start, end) per fn, a synthetic region for the file prefix, and
    `(test)` regions for inline test blocks so their strings attribute to
    tests rather than to whichever function precedes them."""
    out, current, start = [], '(file-prefix)', 0
    for i, l in enumerate(lines):
        m = FN.match(l)
        if m:
            out.append((current, start, i))
            current = (m.group(1) + '::' if m.group(1) else '') + m.group(2)
            start = i
        elif l.startswith('test ') or l.startswith('test"'):
            out.append((current, start, i))
            current = '(test)'
            start = i
    out.append((current, start, len(lines)))
    return out

def qualified_names(body_lines):
    found = set()
    for l in body_lines:
        text = l.lstrip()
        if text.startswith('#|'):
            # multiline string content: token-bounded QNames register too
            for m in re.finditer(r'(?<![A-Za-z0-9_.\-:])([A-Za-z_][A-Za-z0-9_.\-]*):([A-Za-z_][A-Za-z0-9_.\-]*)(?![A-Za-z0-9_.\-:])', text[2:]):
                if m.group(1) not in SCHEMES:
                    found.add(m.group(1) + ':' + m.group(2))
            continue
        l = strip_comments(l)
        for m in QNAME.finditer(l):
            if m.group(1) not in SCHEMES:
                found.add(m.group(1) + ':' + m.group(2))
    return found

errors = []
rows = {}

production = sorted(
    f for f in os.listdir(DOCX)
    if f.endswith('.mbt') and not f.endswith('_test.mbt') and not f.endswith('_wbtest.mbt')
)
for f in production:
    if f in FILES:
        continue
    src = open(os.path.join(DOCX, f)).read()
    stripped = '\n'.join(strip_comments(l) for l in src.split('\n'))
    if LOCAL_DETECT.search(stripped) or qualified_names(src.split('\n')):
        errors.append(f"UNCLASSIFIED FILE: {f} references XML names but is not classified in check_dispatch_registry.py")
for f in FILES:
    if f not in production:
        errors.append(f"MISSING FILE: {f} is classified but no longer exists")

for path, spec in FILES.items():
    if path not in production or 'extract' not in spec:
        continue
    src = open(os.path.join(DOCX, path)).read()
    lines = src.split('\n')
    stripped_lines = [strip_comments(l) for l in lines]
    funcs = functions(lines)

    if spec['extract']['qualified']:
        for name, s, e in funcs:
            if name == '(test)':
                continue
            for q in qualified_names(lines[s:e]):
                rows.setdefault((path, q), set()).add(name)

    local = spec['extract']['local']
    if local is not None:
        declared = local['functions'] | local['non_dispatch']
        for name, s, e in funcs:
            body = '\n'.join(stripped_lines[s:e])
            if LOCAL_DETECT.search(body) and name not in declared and name not in ('(file-prefix)', '(test)'):
                errors.append(f"{path}: function {name} touches local_name but is not declared dispatch or non-dispatch")
            if name in local['functions']:
                for m in LOCAL_NAME_STR.finditer(body):
                    rows.setdefault((path, m.group(1)), set()).add(name)
            elif name not in ('(file-prefix)', '(test)') and COMPARISON.search(body) and QNAME.search(body) is None:
                # an undeclared function comparing something against a bare
                # name-shaped string: possibly smuggled local-name dispatch
                if name not in local['non_dispatch']:
                    errors.append(f"{path}: function {name} compares against a name-shaped string but is not declared -- possible dispatch, declare it either way")
        for fn in sorted(declared - {n for n, _, _ in funcs}):
            errors.append(f"{path}: declared function {fn} was removed -- update the declaration")

    # Name fragments -- prefix construction like `"w:" + kind`, or the
    # scanner's suffix matching on attribute names -- register as rows of
    # their own. Erroring on them would misrepresent genuinely fragment-shaped
    # dispatch; registering them means a smuggled fragment reconcile-fails
    # exactly like a whole name.
    for name, sl, el in funcs:
        if name == '(test)':
            continue
        for i in range(sl, el):
            for m in FRAGMENT.finditer(stripped_lines[i]):
                rows.setdefault((path, m.group(0).strip('"')), set()).add(name)

# ---- reconcile ----
want, meta = {}, {}
if os.path.exists(REGISTRY):
    for i, line in enumerate(open(REGISTRY)):
        line = line.rstrip('\n')
        if not line or line.startswith('#') or (i == 0 and line.startswith('file\t')):
            continue
        parts = line.split('\t')
        if len(parts) < 3:
            errors.append(f"registry line {i+1}: expected at least 3 tab-separated fields")
            continue
        key = (parts[0], parts[1])
        want[key] = set(parts[2].split(','))
        meta[key] = parts[3:]
else:
    errors.append("dispatch_registry.tsv missing")

if '--emit' in sys.argv:
    print('file\tname\tfunctions\tkind\tcoverage')
    for key in sorted(rows):
        extra = meta.get(key, [])
        kind = extra[0] if len(extra) > 0 else ''
        coverage = extra[1] if len(extra) > 1 else ''
        print(f"{key[0]}\t{key[1]}\t{','.join(sorted(rows[key]))}\t{kind}\t{coverage}")
    sys.exit(0)

for key in sorted(set(rows) - set(want)):
    errors.append(f"UNREGISTERED: {key[1]} dispatched in {key[0]} ({','.join(sorted(rows[key]))}) -- add it to dispatch_registry.tsv with coverage evidence")
for key in sorted(set(want) - set(rows)):
    errors.append(f"STALE: registry lists {key[1]} for {key[0]} but it is no longer dispatched there")
for key in sorted(set(rows) & set(want)):
    if rows[key] != want[key]:
        errors.append(f"MOVED: {key[1]} in {key[0]}: source says {','.join(sorted(rows[key]))}, registry says {','.join(sorted(want[key]))}")

if errors:
    for e in errors:
        print(e, file=sys.stderr)
    sys.exit(1)
print(f"dispatch registry: {len(rows)} names reconciled across {sum(1 for s in FILES.values() if 'extract' in s)} files")
