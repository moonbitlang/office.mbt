#!/usr/bin/env bash
# The checker's own adversarial suite: every escape a review round found is
# replayed against a scratch copy of the sources, and each must fail the
# reconciliation with the expected message. Four review rounds produced these;
# a change to the checker's regexes that reopens one should not survive CI.
#
#   bash docx2html/tests/registry/escape_suite.sh
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
docx="$here/../../docx"
work="$(mktemp -d "${TMPDIR:-/tmp}/dispatch-escapes.XXXXXX")"
trap 'rm -rf "$work"' EXIT

fresh() { rm -rf "$work/docx"; mkdir "$work/docx"; cp "$docx"/*.mbt "$work/docx/"; }
# The checker exiting 1 is the EXPECTED outcome for every escape case, so chk
# must not let that status meet `set -e`.
chk() { python3 "$here/check_dispatch_registry.py" --docx-dir "$work/docx" 2>&1 | head -n1 || true; }

fail=0
expect() { # expect <case> <needle> -- last mutation must produce a line containing needle
  local case="$1" needle="$2" got
  got="$(chk)"
  if [[ "$got" != *"$needle"* ]]; then
    echo "ESCAPE SUITE FAIL [$case]: wanted '$needle', got '$got'" >&2; fail=1
  fi
}
mutate() { # mutate <file> <perl-expr> <marker> -- and verify it applied
  local file="$1" expr="$2" marker="$3"
  perl -0pi -e "$expr" "$work/docx/$file"
  if ! grep -q "$marker" "$work/docx/$file"; then
    echo "ESCAPE SUITE FAIL: mutation for marker '$marker' did not apply to $file" >&2
    fail=1
  fi
}

fresh; expect baseline "names reconciled"

fresh; mutate annotation_scan.mbt 's/is \("tcPr"/is ("brandNew" | "tcPr"/' brandNew
expect E1-table-entry "UNREGISTERED: brandNew"

fresh; mutate docx_reader.mbt 's/"w:tab" => \[tab\(\)\]/"w:tab" => [tab()]\n    "w16:brandNew" => [tab()]/' 'w16:brandNew'
expect E2-unlisted-prefix "UNREGISTERED: w16:brandNew"

fresh; mutate docx_reader.mbt 's/"w:tab" => \[tab\(\)\]/"w:tab" => [tab()]\n    _ if element.name == "w" + ":brandNew" => [tab()]/' ':brandNew'
expect E3-concatenation "UNREGISTERED: :brandNew"

fresh; mutate docx_reader.mbt 's/^fn office_namespace_map/let escape_probe : String =\n  #|w:brandNew maps here\n\n\/\/\/|\nfn office_namespace_map/m' 'w:brandNew maps here'
expect E4-multiline "UNREGISTERED: w:brandNew"

fresh; mutate reader_order_projection.mbt 's/^fn reader_order_atom_span/fn name_escape(name : String) -> Bool {\n  name == "seventhEscape"\n}\n\n\/\/\/|\nfn reader_order_atom_span/m' seventhEscape
expect E5-param-smuggle "possible dispatch"

fresh; printf 'fn new_dispatch(local_name : String) -> Bool {\n  local_name == "brandNew"\n}\n' > "$work/docx/escape_probe.mbt"
expect E6-new-file "UNCLASSIFIED FILE: escape_probe.mbt"

fresh; mutate reader_order_projection.mbt 's/^fn reader_order_atom_span/fn name_escape(name : String) -> Bool {\n  "seventhEscape" == name\n}\n\n\/\/\/|\nfn reader_order_atom_span/m' seventhEscape
expect E7-reversed-comparison "possible dispatch"

fresh; printf 'fn frag_dispatch(n : String) -> Bool {\n  n == "w:" + "seventhEscape"\n}\n' > "$work/docx/escape_probe.mbt"
expect E8-new-file-fragment "UNCLASSIFIED FILE: escape_probe.mbt"

fresh; mutate reader_order_projection.mbt 's/^fn reader_order_atom_span/fn match_escape(name : String) -> Bool {\n  match name {\n    "eighthEscape" => true\n    _ => false\n  }\n}\n\n\/\/\/|\nfn reader_order_atom_span/m' eighthEscape
expect E9-match-arm "possible dispatch"

fresh; mutate write_comments.mbt 's/^pub fn write_docx_with_annotations/fn writer_sneaks_a_read(element : XmlElement) -> Bool {\n  element.name == "w:sneaky"\n}\n\n\/\/\/|\npub fn write_docx_with_annotations/m' sneaky
expect E10-exempt-gains-read "exempt file's function writer_sneaks_a_read"

fresh; mutate write_comments.mbt 's/^pub fn write_docx_with_annotations/fn writer_sneaks_reversed(element : XmlElement) -> Bool {\n  "w:sneaky" == element.name\n}\n\n\/\/\/|\npub fn write_docx_with_annotations/m' sneaky
expect E11-exempt-reversed "exempt file's function writer_sneaks_reversed"

fresh; mutate write_comments.mbt 's/^pub fn write_docx_with_annotations/fn writer_sneaks_ne(element : XmlElement) -> Bool {\n  element.name != "w:sneaky"\n}\n\n\/\/\/|\npub fn write_docx_with_annotations/m' sneaky
expect E12-exempt-not-equal "exempt file's function writer_sneaks_ne"

fresh; mutate reader_order_projection.mbt 's/^fn reader_order_atom_span/fn ne_escape(name : String) -> Bool {\n  name != "neEscape"\n}\n\n\/\/\/|\nfn reader_order_atom_span/m' neEscape
expect E13-not-equal-smuggle "possible dispatch"

fresh; expect final-baseline "names reconciled"

if [ "$fail" -eq 0 ]; then echo "escape suite: 13 escapes + 2 baselines, all as expected"; else exit 1; fi
