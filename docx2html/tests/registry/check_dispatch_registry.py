#!/usr/bin/env python3
"""Reconcile the committed dispatch registry with the docx package's readers.

`docx2html/docx` contains two implementations of the same reader semantics --
`BodyReader`, and the reader-order projection whose dispatch spans the walker,
`annotation_scan.mbt`'s name tables, and the scanned-tree consumers. Issue
#434 unifies them. Until it lands, this check keeps the ledger of dispatched
names honest: names the read side dispatches on must appear in
`dispatch_registry.tsv`, and every registry row must still exist in source.
Drift fails CI until the registry is updated deliberately.

The design lesson from five review rounds: detecting dispatch by SHAPE
(comparisons, match arms, their parenthesised and reversed spellings) is an
arms race the detector loses. So extraction is TOTAL instead: in read-side
files, every quoted string that could be a name registers -- bare words,
qualified names, fragments -- attributed to its containing function, with a
`kind` column separating element names from attribute values, prefixes,
entities and message noise. A name smuggled through any spelling of dispatch
still has to be quoted somewhere, and the quote is what registers. What total
extraction cannot see is a name that never appears in these files at all
(passed in from outside the package); that residue is stated, not claimed
away, and #434 removes the second dispatch surface entirely.

Run from anywhere:
    python3 check_dispatch_registry.py             # reconcile
    python3 check_dispatch_registry.py --update    # rewrite rows, keep annotations
    python3 check_dispatch_registry.py --emit      # print rows to stdout
`--emit > dispatch_registry.tsv` would truncate the registry before this
process reads it, wiping every annotation (measured, not hypothetical);
--update exists so that cannot happen.
"""
import os, re, sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..'))
DOCX = os.path.join(ROOT, 'docx2html', 'docx')
if '--docx-dir' in sys.argv:
    DOCX = sys.argv[sys.argv.index('--docx-dir') + 1]
REGISTRY = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'dispatch_registry.tsv')

# Every production .mbt that touches XML names is classified here: 'extract'
# (total extraction of name-shaped strings) or 'exempt' (writers: their names
# construct output; #434's gate is about the two READ implementations).
# An unclassified file matching any detector fails the check.
FILES = {
    'docx_reader.mbt': 'extract',
    'reader_order_projection.mbt': 'extract',
    'annotation_scan.mbt': 'extract',
    'field_projection.mbt': 'extract',
    'annotation_spans.mbt': 'extract',
    'run_surgery.mbt': 'extract',
    'annotate_plan.mbt': 'extract',
    'annotate_thread.mbt': 'extract',
    'annotation_index.mbt': 'extract',
    'docx_package.mbt': 'extract',
    # mixed writer/reader: read_content_type_xml_entries dispatches on
    # content-types names, so the whole file extracts
    'embedded_style_map.mbt': 'extract',
    # root-name dispatch against PACKAGE_RELATIONSHIPS_ROOT constants
    'relationship_mutation.mbt': 'extract',
    # the byte-level w:t token map surgery reads through
    'token_map.mbt': 'extract',
    # font-name dispatch in the symbol resolver both readers share
    'dingbat_to_unicode.mbt': 'extract',
    'write_comments.mbt': 'exempt',
    'write_document.mbt': 'exempt',
    'write_headers.mbt': 'exempt',
    'write_media.mbt': 'exempt',
    'write_notes.mbt': 'exempt',
    'write_numbering.mbt': 'exempt',
    'write_tables.mbt': 'exempt',
    'annotate_fragments.mbt': 'exempt',
    'new_document.mbt': 'exempt',
}
# Functions in exempt files allowed to inspect element names, each with the
# argued reason held in review. Token-level closure below means no spelling
# of inspection can hide from this list.
ALLOWED_INSPECTORS = {
    'write_comments.mbt': {
        # inspects an XmlElement freshly returned by write_block -- its own
        # generated output, not a read document (verified in review round 4)
        'write_docx_with_annotations',
    },
}

FN = re.compile(r'^(?:pub(?:\(all\))? )?(?:async )?fn(?:\[[^\]]*\])? (?:(\w+)::)?(\w+)')
QNAME = re.compile(r'"([A-Za-z_][A-Za-z0-9_.\-]*):([A-Za-z_][A-Za-z0-9_.\-]*)"')
SCHEMES = {'urn', 'http', 'https', 'mailto', 'data'}
BARE = re.compile(r'"([A-Za-z][A-Za-z0-9]*)"')
FRAGMENT = re.compile(r'"(:[A-Za-z][A-Za-z0-9]*|[A-Za-z][A-Za-z0-9]*:|:)"')
# Inspection closure for exempt files and the unclassified-file detector is
# TOKEN-level -- parentheses and operand order cannot hide a token.
NAME_TOKEN = re.compile(r'\.name\b')
LOCAL_TOKEN = re.compile(r'\blocal_name\b')
# For unclassified files only: a bare comparison/match against a name-shaped
# string suggests smuggled dispatch. Optional parentheses covered. This is
# the one place a shape detector remains, and only as a classification
# trigger, never as the trust boundary.
SMUGGLE = re.compile(
    r'(?:==|!=|\bis\b)\s*\(?\s*"[A-Za-z][A-Za-z0-9]*"'
    r'|"[A-Za-z][A-Za-z0-9]*"\s*\)?\s*(?:==|!=|=>)'
)

def strip_comments(line):
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

def extract_region(raw_lines, stripped_lines):
    """All name-shaped strings in a region: qualified, bare, fragments,
    and QNames inside #| multiline strings."""
    found = set()
    for raw, l in zip(raw_lines, stripped_lines):
        text = raw.lstrip()
        if text.startswith('#|'):
            for m in re.finditer(r'(?<![A-Za-z0-9_.\-:])([A-Za-z_][A-Za-z0-9_.\-]*):([A-Za-z_][A-Za-z0-9_.\-]*)(?![A-Za-z0-9_.\-:])', text[2:]):
                if m.group(1) not in SCHEMES:
                    found.add(m.group(1) + ':' + m.group(2))
            continue
        for m in QNAME.finditer(l):
            if m.group(1) not in SCHEMES:
                found.add(m.group(1) + ':' + m.group(2))
        for m in FRAGMENT.finditer(l):
            found.add(m.group(1))
        # bare words, minus those that are part of a qualified name already
        no_qnames = QNAME.sub('""', l)
        for m in BARE.finditer(no_qnames):
            found.add(m.group(1))
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
    lines = open(os.path.join(DOCX, f)).read().split('\n')
    stripped = [strip_comments(l) for l in lines]
    joined = '\n'.join(stripped)
    has_qname = any(m.group(1) not in SCHEMES for l in stripped for m in QNAME.finditer(l))
    if (
        has_qname
        or LOCAL_TOKEN.search(joined)
        or NAME_TOKEN.search(joined)
        or any(FRAGMENT.search(l) for l in stripped)
        or SMUGGLE.search(joined)
    ):
        errors.append(f"UNCLASSIFIED FILE: {f} references XML names but is not classified in check_dispatch_registry.py")
for f in FILES:
    if f not in production:
        errors.append(f"MISSING FILE: {f} is classified but no longer exists")

for path, cls in FILES.items():
    if path not in production:
        continue
    lines = open(os.path.join(DOCX, path)).read().split('\n')
    stripped_lines = [strip_comments(l) for l in lines]
    funcs = functions(lines)
    if cls == 'extract':
        for name, s, e in funcs:
            if name == '(test)':
                continue
            for found in extract_region(lines[s:e], stripped_lines[s:e]):
                rows.setdefault((path, found), set()).add(name)
    else:  # exempt
        allowed = ALLOWED_INSPECTORS.get(path, set())
        for name, s, e in funcs:
            if name in ('(file-prefix)', '(test)'):
                continue
            body = '\n'.join(stripped_lines[s:e])
            if (LOCAL_TOKEN.search(body) or NAME_TOKEN.search(body)) and name not in allowed:
                errors.append(f"{path}: exempt file's function {name} inspects element names -- declare it in ALLOWED_INSPECTORS or reclassify the file")
        for fn in sorted(allowed - {n for n, _, _ in funcs}):
            errors.append(f"{path}: ALLOWED_INSPECTORS lists {fn} which no longer exists")

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

def emitted_lines():
    out = ['file\tname\tfunctions\tkind\tcoverage']
    for key in sorted(rows):
        extra = meta.get(key, [])
        kind = extra[0] if len(extra) > 0 else ''
        coverage = extra[1] if len(extra) > 1 else ''
        out.append(f"{key[0]}\t{key[1]}\t{','.join(sorted(rows[key]))}\t{kind}\t{coverage}")
    return out

if '--emit' in sys.argv:
    print('\n'.join(emitted_lines()))
    sys.exit(0)
if '--update' in sys.argv:
    with open(REGISTRY, 'w') as f:
        f.write('\n'.join(emitted_lines()) + '\n')
    print(f"dispatch_registry.tsv rewritten: {len(rows)} rows, annotations preserved")
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
print(f"dispatch registry: {len(rows)} names reconciled across {sum(1 for c in FILES.values() if c == 'extract')} files")
