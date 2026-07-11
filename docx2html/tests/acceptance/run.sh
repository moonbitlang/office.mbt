#!/usr/bin/env bash
# Mechanical harness for the docx authoring acceptance scenario (see
# README.md). Runs the checked-in fresh-agent probe script through the real
# CLI and asserts the outcomes the probe verified. Run from the repo root:
#
#   bash docx2html/tests/acceptance/run.sh
#
# Exits non-zero on the first divergence.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
docx() { moon run --target wasm docx2html/cmd/docx -- "$@"; }

work="$(mktemp -d "${TMPDIR:-/tmp}/docx-acceptance.XXXXXX")"
trap 'rm -rf "$work"' EXIT
cp "$here/minutes.json" "$work/minutes.json"

fail() { echo "ACCEPTANCE FAIL: $*" >&2; exit 1; }

# 1. Author the document from the probe's script.
out="$(docx batch "$work/minutes.docx" "$work/minutes.json")"
[ "$out" = "created $work/minutes.docx (8 op(s))" ] || fail "batch output: $out"

# 2. Structural validity.
[ "$(docx validate "$work/minutes.docx")" = "valid" ] || fail "validate"

# 3. Content round-trips with the paths the probe checked. 15 lines: the 7
# body paragraphs plus one per table-cell paragraph (3 + 2 + 3 cells).
text="$(docx text "$work/minutes.docx")"
echo "$text" | grep -qx '\[/body/p\[1\]\] Meeting Minutes' || fail "title text"
echo "$text" | grep -q '\[/body/tbl\[1\]/tr\[1\]/tc\[3\]/p\[1\]\] Status' || fail "table header"
[ "$(echo "$text" | wc -l)" -eq 15 ] || fail "paragraph count: $(echo "$text" | wc -l)"

p1="$(docx get "$work/minutes.docx" '/body/p[1]' --json)"
echo "$p1" | grep -q '"style_id": "Heading1"' || fail "p1 style_id"

p2="$(docx get "$work/minutes.docx" '/body/p[2]/hyperlink[1]' --json)"
echo "$p2" | grep -q '"href": "https://example.org/agenda"' || fail "hyperlink href"

bullet="$(docx get "$work/minutes.docx" '/body/p[3]' --json)"
echo "$bullet" | grep -q '"ordered": false' || fail "bullet numbering"

cell="$(docx get "$work/minutes.docx" '/body/tbl[1]/tr[2]/tc[1]' --json)"
echo "$cell" | grep -q '"col_span": 2' || fail "col_span read-back"

# 4. Error probe: unknown op names its index and the known ops.
printf '{"schema": "docx.batch/1", "ops": [{"op": "pagebreak", "params": {}}]}' > "$work/bad.json"
if err="$(docx batch "$work/never.docx" "$work/bad.json" 2>&1)"; then
  fail "unknown op accepted"
fi
echo "$err" | grep -q "ops\[0\].op 'pagebreak' is unknown (known ops: paragraph, table)" || fail "unknown-op message: $err"
[ ! -e "$work/never.docx" ] || fail "unknown op wrote a file"

# 5. Error probe: fresh-document-only refusal leaves the file untouched.
cp "$work/minutes.docx" "$work/minutes.before"
if err="$(docx batch "$work/minutes.docx" "$work/minutes.json" 2>&1)"; then
  fail "existing output overwritten"
fi
echo "$err" | grep -q "refusing to write" || fail "refusal message: $err"
cmp -s "$work/minutes.docx" "$work/minutes.before" || fail "existing file mutated"

echo "ACCEPTANCE PASS: authored, validated, round-tripped, and both error probes matched"
