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
# The checker exiting 1 is the EXPECTED outcome for every escape case, so the
# status is captured explicitly rather than being allowed to meet `set -e` --
# and it is ASSERTED: a checker that starts exiting 0 on failure (or printing
# the right message with the wrong status) must not pass its own suite.
# chk writes its result to files rather than returning it: a function called
# through command substitution runs in a subshell, and a status assigned there
# never reaches the parent -- the first version of this assertion passed
# vacuously because of exactly that.
chk() {
  set +e
  python3 "$here/check_dispatch_registry.py" --docx-dir "$work/docx" > "$work/chk.out" 2>&1
  echo $? > "$work/chk.status"
  set -e
}

fail=0
expect() { # expect <case> <needle> -- message must match AND status must agree
  local case="$1" needle="$2" got status
  chk
  got="$(head -n1 "$work/chk.out")"
  status="$(cat "$work/chk.status")"
  if [[ "$got" != *"$needle"* ]]; then
    echo "ESCAPE SUITE FAIL [$case]: wanted '$needle', got '$got'" >&2; fail=1
  fi
  if [[ "$needle" == *"reconciled"* ]]; then
    [ "$status" -eq 0 ] || { echo "ESCAPE SUITE FAIL [$case]: baseline exited $status" >&2; fail=1; }
  else
    [ "$status" -ne 0 ] || { echo "ESCAPE SUITE FAIL [$case]: escape exited 0" >&2; fail=1; }
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
expect E5-param-smuggle "UNREGISTERED: seventhEscape"

fresh; printf 'fn new_dispatch(local_name : String) -> Bool {\n  local_name == "brandNew"\n}\n' > "$work/docx/escape_probe.mbt"
expect E6-new-file "UNCLASSIFIED FILE: escape_probe.mbt"

fresh; mutate reader_order_projection.mbt 's/^fn reader_order_atom_span/fn name_escape(name : String) -> Bool {\n  "seventhEscape" == name\n}\n\n\/\/\/|\nfn reader_order_atom_span/m' seventhEscape
expect E7-reversed-comparison "UNREGISTERED: seventhEscape"

fresh; printf 'fn frag_dispatch(n : String) -> Bool {\n  n == "w:" + "seventhEscape"\n}\n' > "$work/docx/escape_probe.mbt"
expect E8-new-file-fragment "UNCLASSIFIED FILE: escape_probe.mbt"

fresh; mutate reader_order_projection.mbt 's/^fn reader_order_atom_span/fn match_escape(name : String) -> Bool {\n  match name {\n    "eighthEscape" => true\n    _ => false\n  }\n}\n\n\/\/\/|\nfn reader_order_atom_span/m' eighthEscape
expect E9-match-arm "UNREGISTERED: eighthEscape"

fresh; mutate write_comments.mbt 's/^pub fn write_docx_with_annotations/fn writer_sneaks_a_read(element : XmlElement) -> Bool {\n  element.name == "w:sneaky"\n}\n\n\/\/\/|\npub fn write_docx_with_annotations/m' sneaky
expect E10-exempt-gains-read "exempt file's function writer_sneaks_a_read"

fresh; mutate write_comments.mbt 's/^pub fn write_docx_with_annotations/fn writer_sneaks_reversed(element : XmlElement) -> Bool {\n  "w:sneaky" == element.name\n}\n\n\/\/\/|\npub fn write_docx_with_annotations/m' sneaky
expect E11-exempt-reversed "exempt file's function writer_sneaks_reversed"

fresh; mutate write_comments.mbt 's/^pub fn write_docx_with_annotations/fn writer_sneaks_ne(element : XmlElement) -> Bool {\n  element.name != "w:sneaky"\n}\n\n\/\/\/|\npub fn write_docx_with_annotations/m' sneaky
expect E12-exempt-not-equal "exempt file's function writer_sneaks_ne"

fresh; mutate reader_order_projection.mbt 's/^fn reader_order_atom_span/fn ne_escape(name : String) -> Bool {\n  name != "neEscape"\n}\n\n\/\/\/|\nfn reader_order_atom_span/m' neEscape
expect E13-not-equal-smuggle "UNREGISTERED: neEscape"

fresh; mutate reader_order_projection.mbt 's/^fn reader_order_atom_span/fn paren_escape(name : String) -> Bool {\n  name == ("parenEscape")\n}\n\n\/\/\/|\nfn reader_order_atom_span/m' parenEscape
expect E14-paren-comparison "UNREGISTERED: parenEscape"

fresh; mutate docx_reader.mbt 's/"w:tab" => \[tab\(\)\]/"w:tab" => [tab()]\n    _ if element.name == "w" + ":" + "threePiece" => [tab()]/' threePiece
expect E15-three-piece-concat "UNREGISTERED: "

fresh; printf 'fn bare_dispatch(name : String) -> Bool {\n  name == "bareEscape"\n}\n' > "$work/docx/escape_probe.mbt"
expect E16-new-file-bare-comparison "UNCLASSIFIED FILE: escape_probe.mbt"

fresh; mutate write_comments.mbt 's/^pub fn write_docx_with_annotations/fn writer_paren_read(element : XmlElement) -> Bool {\n  (element.name) == "w:sneaky"\n}\n\n\/\/\/|\npub fn write_docx_with_annotations/m' sneaky
expect E17-exempt-paren-read "exempt file's function writer_paren_read"

fresh; printf '\nlet post_test_probe : String = "postTestEscape"\n' >> "$work/docx/annotation_scan.mbt"
grep -q postTestEscape "$work/docx/annotation_scan.mbt" || { echo "ESCAPE SUITE FAIL: E18 mutation missing" >&2; fail=1; }
expect E18-after-last-test "UNREGISTERED: postTestEscape"

fresh; printf 'fn nested_paren(name : String) -> Bool {\n  name == (("bareEscape"))\n}\n' > "$work/docx/escape_probe.mbt"
expect E19-nested-parens "UNCLASSIFIED FILE: escape_probe.mbt"

fresh; mutate write_comments.mbt 's/^pub fn write_docx_with_annotations/fn writer_destructure(element : XmlElement) -> Bool {\n  let { name, .. } = element\n  name == "w:sneaky"\n}\n\n\/\/\/|\npub fn write_docx_with_annotations/m' sneaky
expect E20-exempt-destructure "exempt file's function writer_destructure"

fresh; mutate reader_order_projection.mbt 's/^fn reader_order_atom_span/fn assembled_escape(name : String) -> Bool {\n  name == "\\u{62}randNew"\n}\n\n\/\/\/|\nfn reader_order_atom_span/m' randNew
expect E21-escape-assembled "UNREGISTERED: randNew"

fresh; printf 'fn is_custom_element(tag : String) -> Bool {\n  tag == "custom-name"\n}\n' > "$work/docx/escape_probe.mbt"
expect E22-hyphenated-new-file "UNCLASSIFIED FILE: escape_probe.mbt"

fresh; mutate dingbat_to_unicode.mbt 's/"WINGDINGS 3"/"BOOKSHELF SYMBOL 7" | "WINGDINGS 3"/' 'BOOKSHELF SYMBOL 7'
expect E23-multiword-font "UNREGISTERED: BOOKSHELF SYMBOL 7"

fresh; mutate docx_reader.mbt 's/^fn office_namespace_map/let toplevel_probe : String = "toplevelEscape"\n\n\/\/\/|\nfn office_namespace_map/m' toplevelEscape
expect E24-toplevel-binding "UNREGISTERED: toplevelEscape"

fresh; printf 'fn table_dispatch(tag : String) -> Bool {\n  ["custom-name"].contains(tag)\n}\n' > "$work/docx/escape_probe.mbt"
expect E25-table-driven-new-file "UNCLASSIFIED FILE: escape_probe.mbt"

fresh; printf 'fn clark_dispatch(n : String) -> Bool {\n  n == "{http://example.com/ns}Custom"\n}\n' > "$work/docx/escape_probe.mbt"
expect E26-clark-new-file "UNCLASSIFIED FILE: escape_probe.mbt"

fresh; mutate reader_order_projection.mbt 's/^fn reader_order_atom_span/fn long_name(name : String) -> Bool {\n  name == "OrdinaryExtensionElementNameLongerThanFortyCharacters"\n}\n\n\/\/\/|\nfn reader_order_atom_span/m' OrdinaryExtension
expect E27-long-name "UNREGISTERED: OrdinaryExtension"

fresh; mutate token_map.mbt 's/^fn token_map_error/fn const_use_probe(n : String) -> Bool {\n  n == PACKAGE_RELATIONSHIPS_ROOT\n}\n\n\/\/\/|\nfn token_map_error/m' const_use_probe
expect E28-const-use-cross-file "UNREGISTERED: "

fresh; mutate annotation_scan.mbt 's/impl Show for ScanMarkerKind with fn output\(self, logger\) \{/impl Show for ScanMarkerKind with fn output(self, logger) {\n  let _probe : String = "implProbe"/' implProbe
expect E29-impl-attribution "UNREGISTERED: implProbe dispatched in annotation_scan.mbt (ScanMarkerKind::impl:output)"

fresh; expect final-baseline "names reconciled"

if [ "$fail" -eq 0 ]; then echo "escape suite: 29 escapes + 2 baselines, all as expected"; else exit 1; fi
