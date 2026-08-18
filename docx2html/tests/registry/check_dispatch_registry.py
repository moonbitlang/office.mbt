#!/usr/bin/env python3
"""Reconcile the committed dispatch registry with the two reader implementations.

The reader (`docx_reader.mbt`) and the reader-order projection
(`reader_order_projection.mbt` + the scanner tables in `annotation_scan.mbt`)
each dispatch on XML names. Issue #434 unifies them; until it lands, this
check is what keeps the ledger honest: every dispatched name must appear in
`dispatch_registry.tsv`, and every registry row must still exist in source.
A new match arm, a renamed element, or a deleted branch fails CI until the
registry -- and therefore the coverage ledger built on it -- is updated
deliberately.

Extraction is function-scoped rather than line-scoped: for each source file a
set of DISPATCH FUNCTIONS is declared below, and every XML-name-shaped quoted
string inside those functions is extracted. The declaration itself is checked
the other way: any function whose body inspects `element.name` or
`local_name` must be declared (or explicitly listed as non-dispatch), so a
new dispatch site cannot appear without this file noticing.

Run from the repo root:  python3 docx2html/tests/registry/check_dispatch_registry.py
"""
import re, sys, os

ROOT = os.path.join(os.path.dirname(__file__), '..', '..', '..')
DOCX = os.path.join(ROOT, 'docx2html', 'docx')
REGISTRY = os.path.join(os.path.dirname(__file__), 'dispatch_registry.tsv')

# Functions that dispatch on element names, per file. `kind` says how names
# are spelled there: 'qualified' ("w:p") or 'local' ("p", with the namespace
# checked separately via uri helpers).
DISPATCH = {
    # The reader dispatches through many shapes -- `match element.name`,
    # `first("w:x")`, `first_or_empty("w:x")`, `attributes.get("w:x")` -- with
    # varied receiver names, so no structural detector is reliable. The rule
    # is instead the strongest one: EVERY qualified name quoted anywhere in
    # the file is registered, with the containing functions as attribution.
    # A name in a warning string registers too; that is noise worth paying
    # for the property that no name reference can drift unregistered.
    'docx_reader.mbt': {
        'kind': 'qualified',
        'functions': None,  # whole file
        'non_dispatch': None,
    },
    # These two dispatch on `<receiver>.local_name` under a separate uri
    # check, and bare local names cannot be blanket-extracted (quoted English
    # words in messages would drown the ledger). Extraction is scoped to the
    # declared dispatch functions, and the declaration is closed the other
    # way: any function whose body touches `.local_name` must be declared
    # dispatch or non-dispatch, so a new dispatch site cannot hide.
    'reader_order_projection.mbt': {
        'kind': 'local',
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
            # name-neutral plumbing: these consume a name as data or defer to
            # a ledger table, and quote no names of their own
            'reader_order_first_direct_wml_child',
            'reader_order_first_direct_mc_child',
            'ReaderOrderWalker::first_wml_child',
            'ReaderOrderWalker::first_mc_child',
            'ReaderOrderWalker::walk_annotation_story_containers',
            'restore_reader_projection_subtree',
        },
    },
    'annotation_scan.mbt': {
        'kind': 'local',
        'functions': {
            'projection_kind',
            'is_transparent_container',
            'is_suppressed_container',
            'marker_kind',
            'revision_kind',
        },
        'non_dispatch': None,  # scanner internals touch local_name broadly;
                               # only the named tables are ledger rows
    },
}

QUALIFIED = re.compile(r'"((?:w|w14|w15|mc|wp|a|pic|v|o|r):[A-Za-z][A-Za-z0-9]*)"')
LOCAL = re.compile(r'"([A-Za-z][A-Za-z0-9]*)"')
FN = re.compile(r'^(?:pub )?fn (?:(\w+)::)?(\w+)')
NAME_INSPECT = re.compile(r'\blocal_name\b')

def functions(src):
    out, lines = [], src.split('\n')
    current, start = None, 0
    for i, l in enumerate(lines):
        m = FN.match(l)
        if m:
            if current is not None:
                out.append((current, start, i))
            current = (m.group(1) + '::' if m.group(1) else '') + m.group(2)
            start = i
    if current is not None:
        out.append((current, start, len(lines)))
    return out

def extract(path, spec):
    src = open(os.path.join(DOCX, path)).read()
    funcs = functions(src)
    lines = src.split('\n')
    found = {}
    inspectors = set()
    pat = QUALIFIED if spec['kind'] == 'qualified' else LOCAL
    for name, s, e in funcs:
        body = '\n'.join(lines[s:e])
        if NAME_INSPECT.search(body):
            inspectors.add(name)
        if spec['functions'] is None or name in spec['functions']:
            for m in pat.finditer(body):
                found.setdefault(m.group(1), set()).add(name)
    return found, inspectors

errors = []
rows = {}
for path, spec in DISPATCH.items():
    found, inspectors = extract(path, spec)
    if spec['functions'] is not None and spec['non_dispatch'] is not None:
        undeclared = inspectors - spec['functions'] - spec['non_dispatch']
        for fn in sorted(undeclared):
            errors.append(f"{path}: function {fn} inspects local names but is not declared as dispatch or non-dispatch")
        existing = {name for name, _, _ in functions(open(os.path.join(DOCX, path)).read())}
        for fn in sorted((spec['functions'] | spec['non_dispatch']) - existing):
            errors.append(f"{path}: declared function {fn} was removed -- update the declaration")

    for name, fns in found.items():
        rows.setdefault((path, name), set()).update(fns)

# Compare with the committed registry.
want = {}
if os.path.exists(REGISTRY):
    for i, line in enumerate(open(REGISTRY)):
        line = line.rstrip('\n')
        if not line or line.startswith('#') or i == 0 and line.startswith('file\t'):
            continue
        parts = line.split('\t')
        if len(parts) < 3:
            errors.append(f"registry line {i+1}: expected at least 3 tab-separated fields")
            continue
        path, name, fns = parts[0], parts[1], parts[2]
        want[(path, name)] = set(fns.split(','))
else:
    errors.append("dispatch_registry.tsv missing")

for key in sorted(set(rows) - set(want)):
    path, name = key
    errors.append(f"UNREGISTERED: {name} dispatched in {path} ({','.join(sorted(rows[key]))}) -- add it to dispatch_registry.tsv with coverage evidence")
for key in sorted(set(want) - set(rows)):
    path, name = key
    errors.append(f"STALE: registry lists {name} for {path} but it is no longer dispatched there")
for key in sorted(set(rows) & set(want)):
    if rows[key] != want[key]:
        path, name = key
        errors.append(f"MOVED: {name} in {path}: source says {','.join(sorted(rows[key]))}, registry says {','.join(sorted(want[key]))}")

if '--emit' in sys.argv:
    print('file\tname\tfunctions')
    for (path, name) in sorted(rows):
        print(f"{path}\t{name}\t{','.join(sorted(rows[(path, name)]))}")
    sys.exit(0)

if errors:
    for e in errors:
        print(e, file=sys.stderr)
    sys.exit(1)
print(f"dispatch registry: {len(rows)} names reconciled across {len(DISPATCH)} files")
