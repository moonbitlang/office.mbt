#!/usr/bin/env bash
# Format-specific CLI and bounded Office read regressions not covered by acceptance.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
# GitHub sets RUNNER_TEMP; local runs use a private directory for repaired fixtures.
export RUNNER_TEMP="${RUNNER_TEMP:-$work}"

moon build --target wasm mbtexcel/cmd/xlsx
moon run --target wasm mbtexcel/cmd/xlsx -- create ci.xlsx --sheet Data
moon run --target wasm mbtexcel/cmd/xlsx -- set ci.xlsx Data A1 Hello
got=$(moon run --target wasm mbtexcel/cmd/xlsx -- get ci.xlsx Data A1 2>/dev/null)
echo "get -> $got"; test "$got" = "Hello"
moon run --target wasm mbtexcel/cmd/xlsx -- view ci.xlsx
# Agent JSON surface: exercise a styled cell and a chart, then
# validate the payloads structurally (not by substring).
moon run --target wasm mbtexcel/cmd/xlsx -- set ci.xlsx Data B1 42
moon run --target wasm mbtexcel/cmd/xlsx -- style ci.xlsx Data A1 --bold --fill 4472C4
moon run --target wasm mbtexcel/cmd/xlsx -- chart ci.xlsx Data D2 --categories A1:A1 --values B1:B1 --name S
o=$(moon run --target wasm mbtexcel/cmd/xlsx -- outline ci.xlsx 2>/dev/null)
echo "$o" | jq -e '.schema == "xlsx.outline/1"
  and (.sheets[0].kind == "worksheet")
  and (.sheets[0].charts | length == 1)
  and (.sheets[0].charts[0].kinds == ["barChart"])
  and (.sheets[0].used_range == "A1:B1")'
j=$(moon run --target wasm mbtexcel/cmd/xlsx -- get ci.xlsx Data A1:B2 --json 2>/dev/null)
echo "$j" | jq -e '.schema == "xlsx.cells/1"
  and (.cells | length == 2)
  and ([.cells[].ref] == ["A1", "B1"])
  and (.styles[.cells[0].style_id | tostring].font.bold == true)
  and (.styles[.cells[0].style_id | tostring].fill.colors == ["4472C4"])'
cat > ci-batch.json <<'JSON'
{"schema": "xlsx.batch/1", "ops": [
  {"op": "set", "params": {"sheet": "Data", "cell": "A2", "value": 7.5}},
  {"op": "formula", "params": {"sheet": "Data", "cell": "A3", "formula": "=A2*2"}},
  {"op": "merge", "params": {"sheet": "Data", "cell_range": "C1:D1"}}
]}
JSON
# The bad param name must fail with the op-indexed error, and the
# file must be byte-identical afterwards (no write on failure).
cp ci.xlsx ci-before.xlsx
out=$(moon run --target wasm mbtexcel/cmd/xlsx -- batch ci.xlsx ci-batch.json 2>&1) && { echo "expected the bad script to fail"; exit 1; } || true
echo "$out" | grep -q "error: op 2 (merge): missing param 'range'"
cmp ci.xlsx ci-before.xlsx
sed -i.bak 's/"cell_range"/"range"/' ci-batch.json
rm ci-batch.json.bak
b=$(moon run --target wasm mbtexcel/cmd/xlsx -- batch ci.xlsx ci-batch.json 2>/dev/null)
echo "batch -> $b"; test "$b" = "applied 3 op(s) to ci.xlsx"
c=$(moon run --target wasm mbtexcel/cmd/xlsx -- calc ci.xlsx Data A3 2>/dev/null)
echo "calc A3 -> $c"; test "$c" = "15"
v=$(moon run --target wasm mbtexcel/cmd/xlsx -- validate ci.xlsx 2>/dev/null)
echo "validate -> $v"; test "$v" = "valid"
# The canonical office CLI dispatches by verified package content,
# not extension alone. Exercise both supported formats under wasm.
moon build --target wasm office-cli
f=$(moon run --target wasm office-cli -- identify ci.xlsx 2>office-wasm.err) || { echo "office xlsx identify failed; stderr:"; cat office-wasm.err; exit 1; }
echo "office identify xlsx -> $f"; test "$f" = "xlsx"
f=$(moon run --target wasm office-cli -- identify docx2html/tests/cram/fixtures/single-paragraph.docx 2>office-wasm.err) || { echo "office docx identify failed; stderr:"; cat office-wasm.err; exit 1; }
echo "office identify docx -> $f"; test "$f" = "docx"
h=$(moon run --target wasm office-cli -- help all --json 2>office-wasm.err) || { echo "office JSON help failed; stderr:"; cat office-wasm.err; exit 1; }
echo "$h" | jq -e '.schema == "office.output/1"
  and .success == true
  and .data.schema == "office.capabilities/2"
  and (.data.fingerprint | test("^crc32:[0-9a-f]{8}$"))
  and ((["docx", "xlsx", "help", "identify", "outline", "get", "text", "query", "find", "replace", "format", "insert-paragraph", "delete-paragraph", "validate", "dump", "replay", "issues", "preview", "render", "create", "template", "edit", "annotate", "batch", "raw"] - [.data.records[].name]) | length == 0)'
moon run --target wasm office-cli -- help all --jsonl 2>office-wasm.err \
  | jq -se 'length >= 25 and all(.[]; .schema == "office.capability/2")'
moon run --target wasm office-cli -- help schemas 2>office-wasm.err \
  | grep -q '^Consumed input contracts$'
hs=$(moon run --target wasm office-cli -- help schemas --json 2>office-wasm.err)
echo "$hs" | jq -e '.success == true and .data.schema == "office.input-contracts/1" and (.data.contracts | length) >= 7'
moon run --target wasm office-cli -- help schemas --jsonl 2>office-wasm.err \
  | jq -e '.schema == "office.input-contracts/1" and (.contracts | length) >= 7'
moon run --target wasm office-cli -- help schema docx.batch/2 2>office-wasm.err \
  | jq -e '.schema == "office.input-contract/1" and .id == "docx.batch/2"'
hc=$(moon run --target wasm office-cli -- help schema docx.batch/2 --json 2>office-wasm.err)
echo "$hc" | jq -e '.success == true and .data.schema == "office.input-contract/1" and .data.id == "docx.batch/2"'
moon run --target wasm office-cli -- help schema docx.batch/2 --jsonl 2>office-wasm.err \
  | jq -e '.schema == "office.input-contract/1" and .id == "docx.batch/2"'
if moon run --target wasm office-cli -- help xlxs --json >office-wasm-error.json 2>office-wasm.err; then
  echo "expected unknown office help format to fail"
  exit 1
fi
jq -e '.schema == "office.output/1"
  and .success == false
  and .error.code == "office.unknown_format"
  and .error.details.suggestions == ["xlsx"]' office-wasm-error.json
# XLSX structured reads share the validated bounded archive and use
# canonical name-keyed paths even when the input selector is positional.
# The third-party Book1 fixture has intersecting shared-formula ranges;
# normalize that unrelated invalid metadata through the raw transaction
# surface before exercising the fixture's original contents.
xlsx_source=mbtexcel/fixtures/excelize/test/Book1.xlsx
xlsx_sheet="$RUNNER_TEMP/office-book1-sheet2.xml"
xlsx_sheet_valid="$RUNNER_TEMP/office-book1-sheet2-valid.xml"
xlsx_fixture="$RUNNER_TEMP/office-Book1-valid.xlsx"
moon run --target wasm office-cli -- raw read "$xlsx_source" /Sheet2 --output "$xlsx_sheet" >/dev/null
sed -e 's/ref="F11:H11"/ref="F11:F11"/' -e 's/<f t="shared" si="0"><\/f>/<f t="shared" si="1"><\/f>/' "$xlsx_sheet" >"$xlsx_sheet_valid"
moon run --target wasm office-cli -- raw replace "$xlsx_source" /Sheet2 --xml-file "$xlsx_sheet_valid" --out "$xlsx_fixture" --json >/dev/null
xo=$(moon run --target wasm office-cli -- outline "$xlsx_fixture" --json 2>office-wasm.err) || { echo "office XLSX outline failed; stderr:"; cat office-wasm.err; exit 1; }
echo "$xo" | jq -e '.success == true
  and .data.schema == "office.xlsx.outline/1"
  and .data.path == "/xlsx/workbook"
  and [.data.sheets[].path] == ["/xlsx/sheet[name=\"Sheet1\"]", "/xlsx/sheet[name=\"Sheet2\"]"]'
singleton_fixture=mbtexcel/fixtures/excelize/test/OverflowNumericCell.xlsx
xs=$(moon run --target wasm office-cli -- outline "$singleton_fixture" --json 2>office-wasm.err) || { echo "office XLSX singleton outline failed; stderr:"; cat office-wasm.err; exit 1; }
echo "$xs" | jq -e '.success == true
  and .data.sheets[0].used_range.reference == "A1:A1"
  and .data.sheets[0].used_range.path == "/xlsx/sheet[name=\"Sheet1\"]/range[A1:A1]"'
xsg=$(moon run --target wasm office-cli -- get "$singleton_fixture" '/xlsx/sheet[1]/range[A1:A1]' --json 2>office-wasm.err) || { echo "office XLSX singleton get failed; stderr:"; cat office-wasm.err; exit 1; }
echo "$xsg" | jq -e '.success == true
  and .data.reference == "A1:A1"
  and [.data.cells[].reference] == ["A1"]'
xg=$(moon run --target wasm office-cli -- get "$xlsx_fixture" '/xlsx/sheet[1]/range[A19:B19]' --json 2>office-wasm.err) || { echo "office XLSX get failed; stderr:"; cat office-wasm.err; exit 1; }
echo "$xg" | jq -e '.success == true
  and .data.schema == "office.xlsx.element/1"
  and .data.path == "/xlsx/sheet[name=\"Sheet1\"]/range[A19:B19]"
  and [.data.cells[].reference] == ["A19", "B19"]
  and .data.cells[1].formula == "SUM(Sheet2!D2,Sheet2!D11)"'
xt=$(moon run --target wasm office-cli -- text "$xlsx_fixture" --under '/xlsx/sheet[name="Sheet1"]' --offset 1 --limit 2 --json 2>office-wasm.err) || { echo "office XLSX text failed; stderr:"; cat office-wasm.err; exit 1; }
echo "$xt" | jq -e '.success == true
  and .data.schema == "office.xlsx.text/1"
  and .data.matched_total == 5
  and [.data.entries[].text] == ["237", "Column1"]'
xq=$(moon run --target wasm office-cli -- query "$xlsx_fixture" 'cell[type=formula][formula~=IF]' --under '/xlsx/sheet[name="Sheet2"]' --json 2>office-wasm.err) || { echo "office XLSX query failed; stderr:"; cat office-wasm.err; exit 1; }
echo "$xq" | jq -e '.success == true
  and .data.schema == "office.xlsx.query/1"
  and .data.matched_total == 4
  and [.data.matches[].reference] == ["F11", "G11", "H11", "I11"]'
# Fresh creation and strict batch mutation use the same async,
# bounded transaction path on wasm as native.
xc=$(moon run --target wasm office-cli -- create xlsx ci-office-created.xlsx --sheet Data --json 2>office-wasm.err) || { echo "office XLSX create failed; stderr:"; cat office-wasm.err; exit 1; }
echo "$xc" | jq -e '.success == true
  and .data.schema == "office.xlsx.create/1"
  and .data.sheet == "Data"
  and .data.transaction.committed == true'
cat >ci-office-batch.json <<'JSON'
{"schema":"xlsx.batch/1","ops":[{"op":"set","params":{"sheet":"Data","cell":"A1","value":"wasm"}},{"op":"formula","params":{"sheet":"Data","cell":"B1","formula":"=LEN(A1)"}}]}
JSON
xb=$(moon run --target wasm office-cli -- batch ci-office-created.xlsx ci-office-batch.json --out ci-office-batched.xlsx --json 2>office-wasm.err) || { echo "office XLSX batch failed; stderr:"; cat office-wasm.err; exit 1; }
echo "$xb" | jq -e '.success == true
  and .data.schema == "office.xlsx.batch/1"
  and .data.stats.operation_count == 2
  and .data.stats.touched_cells == 2
  and .data.transaction.committed == true
  and any(.warnings[]; .code == "office.xlsx.full_rewrite")'
xbg=$(moon run --target wasm office-cli -- get ci-office-batched.xlsx '/xlsx/sheet[name="Data"]/range[A1:B1]' --json 2>office-wasm.err) || { echo "office XLSX batch readback failed; stderr:"; cat office-wasm.err; exit 1; }
echo "$xbg" | jq -e '.success == true
  and .data.cells[0].raw.value == "wasm"
  and .data.cells[1].formula == "LEN(A1)"'
# Fresh DOCX creation and authoring (D3) run through the same wasm
# async transaction path.
dc=$(moon run --target wasm office-cli -- create docx ci-office-created.docx --json 2>office-wasm.err) || { echo "office DOCX create failed; stderr:"; cat office-wasm.err; exit 1; }
echo "$dc" | jq -e '.success == true
  and .data.schema == "office.docx.create/1"
  and .data.format == "docx"
  and .data.transaction.committed == true'
printf '{"schema": "docx.batch/2", "ops": [{"op": "paragraph", "params": {"text": "Heading", "style": "Heading1"}}, {"op": "paragraph", "params": {"runs": [{"text": "body", "bold": true}]}}, {"op": "comment", "params": {"on": 0, "text": "note", "author": "CI"}}]}' > ci-office-author.json
db=$(moon run --target wasm office-cli -- batch --format docx ci-office-authored.docx ci-office-author.json --json 2>office-wasm.err) || { echo "office DOCX authoring failed; stderr:"; cat office-wasm.err; exit 1; }
echo "$db" | jq -e '.success == true
  and .data.schema == "office.docx.batch/1"
  and .data.ops == 3
  and .data.comments == 1
  and .data.transaction.committed == true'
dbt=$(moon run --target wasm office-cli -- text ci-office-authored.docx --json 2>office-wasm.err) || { echo "office DOCX authoring readback failed; stderr:"; cat office-wasm.err; exit 1; }
echo "$dbt" | jq -e '.success == true
  and (.data.entries[0].text == "Heading")
  and (.data.entries[1].text == "body")'
# DOCX structured reads share one canonical bounded projection.
# Drive every command through the wasm async filesystem path.
o=$(moon run --target wasm office-cli -- outline docx2html/tests/cram/fixtures/single-paragraph.docx --json 2>office-wasm.err) || { echo "office DOCX outline failed; stderr:"; cat office-wasm.err; exit 1; }
echo "$o" | jq -e '.success == true
  and .data.schema == "office.docx.outline/1"
  and .data.counts.paragraphs == 1
  and [.data.stories[].path] == ["/docx/body", "/docx/footnotes", "/docx/endnotes", "/docx/comments"]'
g=$(moon run --target wasm office-cli -- get docx2html/tests/cram/fixtures/commented.docx '/docx/comments/comment[id="0"]' --json 2>office-wasm.err) || { echo "office DOCX get failed; stderr:"; cat office-wasm.err; exit 1; }
echo "$g" | jq -e '.success == true
  and .data.schema == "office.docx.element/1"
  and .data.stability == "stable"
  and .data.metadata.author == "Ada Lovelace"'
t=$(moon run --target wasm office-cli -- text docx2html/tests/cram/fixtures/header-footer.docx --json 2>office-wasm.err) || { echo "office DOCX text failed; stderr:"; cat office-wasm.err; exit 1; }
echo "$t" | jq -e '.success == true
  and .data.schema == "office.docx.text/1"
  and [.data.entries[].path] == ["/docx/body/p[1]", "/docx/body/p[2]", "/docx/header[1]/p[1]", "/docx/header[2]/p[1]", "/docx/footer[1]/p[1]"]'
q=$(moon run --target wasm office-cli -- query docx2html/tests/cram/fixtures/tiny-picture.docx --kind picture --json 2>office-wasm.err) || { echo "office DOCX query failed; stderr:"; cat office-wasm.err; exit 1; }
echo "$q" | jq -e '.success == true
  and .data.schema == "office.docx.query/1"
  and .data.matched_total == 1
  and .data.matches[0].path == "/docx/body/p[1]/r[1]/image[1]"'
# Raw OOXML uses the same async filesystem and A4 transaction on
# wasm. Exercise relationship-derived aliases, dry-run preservation,
# atomic separate-output publication, and both Office formats.
r=$(moon run --target wasm office-cli -- raw list ci.xlsx --json 2>office-wasm.err) || { echo "office raw list failed; stderr:"; cat office-wasm.err; exit 1; }
echo "$r" | jq -e '.schema == "office.output/1"
  and .success == true
  and .data.schema == "office.raw.inventory/1"
  and any(.data.parts[]; .aliases | index("/Data"))'
r=$(moon run --target wasm office-cli -- raw read docx2html/tests/cram/fixtures/single-paragraph.docx /document --json 2>office-wasm.err) || { echo "office raw DOCX read failed; stderr:"; cat office-wasm.err; exit 1; }
echo "$r" | jq -e '.success == true
  and .data.schema == "office.raw.part/1"
  and (.data.content | contains("Walking on imported air"))'
cp ci.xlsx ci-raw-before.xlsx
r=$(moon run --target wasm office-cli -- raw edit ci.xlsx /Data --path '/x:worksheet/x:sheetData/x:row[1]' --action set-attribute --attribute ht --value 15 --dry-run --json 2>office-wasm.err) || { echo "office raw dry-run failed; stderr:"; cat office-wasm.err; exit 1; }
echo "$r" | jq -e '.success == true
  and .data.change.action == "set-attribute"
  and .data.transaction.dry_run == true
  and .data.transaction.committed == false
  and .data.transaction.preservation.changed == ["xl/worksheets/sheet1.xml"]'
cmp ci.xlsx ci-raw-before.xlsx
r=$(moon run --target wasm office-cli -- raw edit ci.xlsx /Data --path '/x:worksheet/x:sheetData/x:row[1]' --action set-attribute --attribute ht --value 15 --out ci-raw.xlsx --json 2>office-wasm.err) || { echo "office raw commit failed; stderr:"; cat office-wasm.err; exit 1; }
echo "$r" | jq -e '.success == true
  and .data.transaction.committed == true
  and .data.transaction.preservation.changed == ["xl/worksheets/sheet1.xml"]'
r=$(moon run --target wasm office-cli -- raw read ci-raw.xlsx /Data --json 2>office-wasm.err) || { echo "office raw readback failed; stderr:"; cat office-wasm.err; exit 1; }
echo "$r" | jq -e '.success == true and (.data.content | contains("ht=\"15\""))'
# The docx agent CLI also targets wasm end to end: build it and
# drive its convert subcommand over a committed fixture. Keep the
# captured stderr and print it on failure — discarding it makes a
# red run undebuggable.
moon build --target wasm docx2html/cmd/docx
d=$(moon run --target wasm docx2html/cmd/docx -- convert docx2html/tests/cram/fixtures/single-paragraph.docx 2>docx-wasm.err) || { echo "docx convert failed; stderr:"; cat docx-wasm.err; exit 1; }
echo "docx convert -> $d"
test "$d" = "<p>Walking on imported air</p>" || { echo "unexpected output; stderr:"; cat docx-wasm.err; exit 1; }
# Agent JSON surface: validate the outline payload structurally.
o=$(moon run --target wasm docx2html/cmd/docx -- outline docx2html/tests/cram/fixtures/tiny-picture.docx 2>docx-wasm.err) || { echo "docx outline failed; stderr:"; cat docx-wasm.err; exit 1; }
echo "$o" | jq -e '.schema == "docx.outline/1"
  and (.counts.paragraphs == 1)
  and (.counts.images == 1)
  and (.images[0].content_type == "image/png")'
g=$(moon run --target wasm docx2html/cmd/docx -- get docx2html/tests/cram/fixtures/tiny-picture.docx '/body/p[1]/r[1]/image[1]' --json 2>docx-wasm.err) || { echo "docx get failed; stderr:"; cat docx-wasm.err; exit 1; }
echo "$g" | jq -e '.schema == "docx.element/1"
  and (.kind == "image")
  and (.path == "/body/p[1]/r[1]/image[1]")'
v=$(moon run --target wasm docx2html/cmd/docx -- validate docx2html/tests/cram/fixtures/single-paragraph.docx 2>docx-wasm.err) || { echo "docx validate failed; stderr:"; cat docx-wasm.err; exit 1; }
echo "docx validate -> $v"; test "$v" = "valid"
# Write foundation: create a blank document on wasm and gate it
# with the portable validator.
moon run --target wasm docx2html/cmd/docx -- create ci-blank.docx 2>docx-wasm.err || { echo "docx create failed; stderr:"; cat docx-wasm.err; exit 1; }
c=$(moon run --target wasm docx2html/cmd/docx -- validate ci-blank.docx 2>docx-wasm.err) || { echo "blank validate failed; stderr:"; cat docx-wasm.err; exit 1; }
echo "blank validate -> $c"; test "$c" = "valid"
# Authoring surface: batch a document from an op script on wasm —
# docx.batch/2 with a comment (Phase-2 K1), read back through the
# annotation surface of the same build.
printf '{"schema": "docx.batch/2", "ops": [{"op": "paragraph", "params": {"runs": [{"text": "Hi"}, {"footnote": {"text": "a wasm footnote"}}], "style": "Heading1"}}, {"op": "comment", "params": {"on": 0, "text": "wasm note", "author": "CI"}}, {"op": "comment", "params": {"reply_to": 1, "done": true, "text": "resolved", "author": "CI2"}}]}' > ci-batch.json
moon run --target wasm docx2html/cmd/docx -- batch ci-batch.docx ci-batch.json 2>docx-wasm.err || { echo "docx batch failed; stderr:"; cat docx-wasm.err; exit 1; }
b=$(moon run --target wasm docx2html/cmd/docx -- validate ci-batch.docx 2>docx-wasm.err) || { echo "batch validate failed; stderr:"; cat docx-wasm.err; exit 1; }
echo "batch validate -> $b"; test "$b" = "valid"
w=$(moon run --target wasm docx2html/cmd/docx -- outline ci-batch.docx 2>docx-wasm.err | jq -r '.comments[0].author + " " + .comments[1].parent_id + " " + (.comments[1].done | tostring) + " " + (.counts.footnotes | tostring)') || { echo "batch outline failed; stderr:"; cat docx-wasm.err; exit 1; }
echo "written thread -> $w"; test "$w" = "CI 0 true 1"
# Annotate an EXISTING document on wasm (Phase-2 L1): byte-span
# surgery through the same build, read back via its outline.
moon run --target wasm docx2html/cmd/docx -- annotate add ci-batch.docx ci-annotated.docx --at /body/p[1] --text "wasm annotate" --author L1 2>docx-wasm.err || { echo "annotate failed; stderr:"; cat docx-wasm.err; exit 1; }
n=$(moon run --target wasm docx2html/cmd/docx -- outline ci-annotated.docx 2>docx-wasm.err | jq -r '.comments | length') || { echo "annotated outline failed; stderr:"; cat docx-wasm.err; exit 1; }
echo "annotated comments -> $n"; test "$n" = "3"
# The L2 verbs on wasm: reply to the fresh comment, resolve it.
moon run --target wasm docx2html/cmd/docx -- annotate reply ci-annotated.docx ci-replied.docx --comment 2 --text "wasm reply" --author L2 2>docx-wasm.err || { echo "reply failed; stderr:"; cat docx-wasm.err; exit 1; }
moon run --target wasm docx2html/cmd/docx -- annotate resolve ci-replied.docx ci-resolved.docx --comment 2 2>docx-wasm.err || { echo "resolve failed; stderr:"; cat docx-wasm.err; exit 1; }
t=$(moon run --target wasm docx2html/cmd/docx -- outline ci-resolved.docx 2>docx-wasm.err | jq -r '[.comments[] | select(.id == "2" or .parent_id == "2")] | map(.done) | tostring') || { echo "resolved outline failed; stderr:"; cat docx-wasm.err; exit 1; }
echo "thread done flags -> $t"; test "$t" = "[true,false]"
# Annotation read surface on wasm (Phase-2 J2).
a=$(moon run --target wasm docx2html/cmd/docx -- outline docx2html/tests/cram/fixtures/commented.docx 2>docx-wasm.err | jq -r '.comments[1].parent_id') || { echo "annotated outline failed; stderr:"; cat docx-wasm.err; exit 1; }
echo "comment parent_id -> $a"; test "$a" = "0"
# The checked-in authoring acceptance scenario (see
# docx2html/tests/acceptance/README.md) — same wasm build.
bash docx2html/tests/acceptance/run.sh
