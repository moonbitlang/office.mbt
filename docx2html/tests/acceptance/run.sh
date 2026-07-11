#!/usr/bin/env bash
# Mechanical harness for the docx authoring acceptance scenario (see
# README.md). Runs the checked-in probe script through the real CLI and
# asserts every structural claim of the scenario. Run from the repo root:
#
#   bash docx2html/tests/acceptance/run.sh
#
# Exits non-zero on the first divergence, printing the diverging output.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
docx() { moon run --target wasm docx2html/cmd/docx -- "$@"; }

work="$(mktemp -d "${TMPDIR:-/tmp}/docx-acceptance.XXXXXX")"
trap 'rm -rf "$work"' EXIT
cp "$here/minutes.json" "$work/minutes.json"

fail() { echo "ACCEPTANCE FAIL: $*" >&2; exit 1; }

# Capture a command's stdout; on failure, surface the diagnostic (wasm has
# no stderr — failures land on stdout) instead of letting set -e eat it.
must() {
  local __out
  if ! __out="$("$@" 2>&1)"; then
    fail "command failed: $* -> $__out"
  fi
  printf '%s' "$__out"
}

# 1. Author the document from the probe's script.
out="$(must docx batch "$work/minutes.docx" "$work/minutes.json")"
[ "$out" = "created $work/minutes.docx (8 op(s))" ] || fail "batch output: $out"

# 2. Structural validity.
[ "$(must docx validate "$work/minutes.docx")" = "valid" ] || fail "validate"

# 3. Content round-trips with the paths the scenario requires. 15 lines: the
# 7 body paragraphs plus one per table-cell paragraph (3 + 2 + 3 cells).
text="$(must docx text "$work/minutes.docx")"
echo "$text" | grep -qx '\[/body/p\[1\]\] Meeting Minutes' || fail "title text"
echo "$text" | grep -q '\[/body/tbl\[1\]/tr\[1\]/tc\[3\]/p\[1\]\] Status' || fail "table header cell"
[ "$(echo "$text" | wc -l)" -eq 15 ] || fail "paragraph count: $(echo "$text" | wc -l)"

# Heading1 title, with the reader's enriched style name.
p1="$(must docx get "$work/minutes.docx" '/body/p[1]' --json)"
echo "$p1" | grep -q '"style_id": "Heading1"' || fail "p1 style_id"
echo "$p1" | grep -q '"style_name": "heading 1"' || fail "p1 enriched style_name"

# The bold run inside the narrative paragraph (run 2 of p[2]).
bold_run="$(must docx get "$work/minutes.docx" '/body/p[2]/r[2]' --json)"
echo "$bold_run" | grep -q '"bold": true' || fail "bold run"
echo "$bold_run" | grep -q '"quarterly budget"' || fail "bold run text"

# The hyperlink and its target.
link="$(must docx get "$work/minutes.docx" '/body/p[2]/hyperlink[1]' --json)"
echo "$link" | grep -q '"href": "https://example.org/agenda"' || fail "hyperlink href"

# All three bulleted items and both ordered items.
for i in 3 4 5; do
  bullet="$(must docx get "$work/minutes.docx" "/body/p[$i]" --json)"
  echo "$bullet" | grep -q '"ordered": false' || fail "p[$i] bullet numbering"
done
for i in 6 7; do
  ordered="$(must docx get "$work/minutes.docx" "/body/p[$i]" --json)"
  echo "$ordered" | grep -q '"ordered": true' || fail "p[$i] ordered numbering"
done

# Header row is marked, and the spanning cell reads back col_span 2.
row1="$(must docx get "$work/minutes.docx" '/body/tbl[1]/tr[1]' --json)"
echo "$row1" | grep -q '"header": true' || fail "header row flag"
cell="$(must docx get "$work/minutes.docx" '/body/tbl[1]/tr[2]/tc[1]' --json)"
echo "$cell" | grep -q '"col_span": 2' || fail "col_span read-back"

# 4. Error probe: unknown op names its index and the known ops, exactly.
printf '{"schema": "docx.batch/1", "ops": [{"op": "pagebreak", "params": {}}]}' > "$work/bad.json"
if err="$(docx batch "$work/never.docx" "$work/bad.json" 2>&1)"; then
  fail "unknown op accepted"
fi
echo "$err" | grep -qx "error: ops\[0\].op 'pagebreak' is unknown (known ops: paragraph, table, comment)" || fail "unknown-op message: $err"
[ ! -e "$work/never.docx" ] || fail "unknown op wrote a file"

# 5. Error probe: fresh-document-only refusal, exact message, and no
# filesystem side effects (file untouched, no temp droppings).
cp "$work/minutes.docx" "$work/minutes.before"
if err="$(docx batch "$work/minutes.docx" "$work/minutes.json" 2>&1)"; then
  fail "existing output overwritten"
fi
echo "$err" | grep -qx "docx: refusing to write '$work/minutes.docx': it already exists (batch creates NEW documents only; it cannot preserve parts of an existing file)" || fail "refusal message: $err"
cmp -s "$work/minutes.docx" "$work/minutes.before" || fail "existing file mutated"
leftovers="$(find "$work" -name '*.tmp-*' | wc -l)"
[ "$leftovers" -eq 0 ] || fail "temp droppings left behind"

echo "ACCEPTANCE PASS: authored, validated, every structural claim round-tripped, both error probes exact"
