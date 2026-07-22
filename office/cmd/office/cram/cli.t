The canonical office command identifies structurally valid XLSX and DOCX
packages in text or JSON mode.

  $ office.exe identify "$TESTDIR/../../../../fixtures/excelize/test/Book1.xlsx"
  xlsx

  $ office.exe identify "$TESTDIR/../../../../docx2html/tests/cram/fixtures/single-paragraph.docx"
  docx

  $ office.exe identify "$TESTDIR/../../../../docx2html/tests/cram/fixtures/single-paragraph.docx" --json | jq -c '{schema,success,data:{schema:.data.schema,format:.data.format}}'
  {"schema":"office.output/1","success":true,"data":{"schema":"office.identify/1","format":"docx"}}

Help is generated from the same registry that declares the implemented
commands. It supports canonical format aliases and deterministic human, JSON,
and JSONL inventories without deferred PowerPoint or MCP entries.

  $ office.exe help | sed -n '1,8p'
  Office capability registry
    Schema: office.capabilities/2
    Fingerprint: crc32:265a9938
  Formats:
    docx (aliases: word) — WordprocessingML documents
    xlsx (aliases: excel) — SpreadsheetML workbooks
  Commands:
    help — Show the implemented Office capability registry

  $ office.exe help word | sed -n '1,7p'
  Format: docx (aliases: word)
    WordprocessingML documents
    Selector: office.selector/1 /docx (read-resolved)
      bounded canonical resolution for outline, get, text, and declared query predicates
      /docx/body/p[1]/r[2]
      /docx/comments/comment[id="7"]
    Implemented commands:

  $ office.exe help docx --json | jq -c '.data.records[0] | {kind,name,selector}'
  {"kind":"format","name":"docx","selector":{"schema":"office.selector/1","root":"/docx","status":"read-resolved","examples":["/docx/body/p[1]/r[2]","/docx/comments/comment[id=\"7\"]"],"description":"bounded canonical resolution for outline, get, text, and declared query predicates"}}

  $ office.exe help xlsx query --json | jq -c '.data.records[0] | {formats,variants:[.variants[]|{name,result_schema,constraints}]}'
  {"formats":["xlsx"],"variants":[{"name":"xlsx","result_schema":"office.xlsx.query/1","constraints":["format=xlsx"]}]}

  $ office.exe help all --json | jq -c '{schema,success,capability_schema:.data.schema,fingerprint:.data.fingerprint,names:[.data.records[].name]}'
  {"schema":"office.output/1","success":true,"capability_schema":"office.capabilities/2","fingerprint":"crc32:265a9938","names":["docx","xlsx","help","identify","outline","get","text","query","validate","dump","replay","issues","preview","create","template","batch","raw"]}

  $ office.exe help all --jsonl | jq -s -c 'map({schema,fingerprint,kind,name})'
  [{"schema":"office.capability/2","fingerprint":"crc32:265a9938","kind":"format","name":"docx"},{"schema":"office.capability/2","fingerprint":"crc32:265a9938","kind":"format","name":"xlsx"},{"schema":"office.capability/2","fingerprint":"crc32:265a9938","kind":"command","name":"help"},{"schema":"office.capability/2","fingerprint":"crc32:265a9938","kind":"command","name":"identify"},{"schema":"office.capability/2","fingerprint":"crc32:265a9938","kind":"command","name":"outline"},{"schema":"office.capability/2","fingerprint":"crc32:265a9938","kind":"command","name":"get"},{"schema":"office.capability/2","fingerprint":"crc32:265a9938","kind":"command","name":"text"},{"schema":"office.capability/2","fingerprint":"crc32:265a9938","kind":"command","name":"query"},{"schema":"office.capability/2","fingerprint":"crc32:265a9938","kind":"command","name":"validate"},{"schema":"office.capability/2","fingerprint":"crc32:265a9938","kind":"command","name":"dump"},{"schema":"office.capability/2","fingerprint":"crc32:265a9938","kind":"command","name":"replay"},{"schema":"office.capability/2","fingerprint":"crc32:265a9938","kind":"command","name":"issues"},{"schema":"office.capability/2","fingerprint":"crc32:265a9938","kind":"command","name":"preview"},{"schema":"office.capability/2","fingerprint":"crc32:265a9938","kind":"command","name":"create"},{"schema":"office.capability/2","fingerprint":"crc32:265a9938","kind":"command","name":"template"},{"schema":"office.capability/2","fingerprint":"crc32:265a9938","kind":"command","name":"batch"},{"schema":"office.capability/2","fingerprint":"crc32:265a9938","kind":"command","name":"raw"}]

The raw command publishes explicit subcommand schemas, including every edit
input and its conditional constraints.

  $ office.exe help raw --json | jq -c '.data.records[0] | {variants:[.variants[].name],edit_inputs:[.variants[]|select(.name=="edit")|.inputs[].name],safe_value:([.variants[]|select(.name=="edit")|.constraints[]]|index("flag-looking-values-require-attached-syntax")!=null),same_extension:([.variants[]|select(.name=="edit")|.constraints[]]|index("out-extension-must-match-input-format")!=null)}'
  {"variants":["list","read","replace","edit"],"edit_inputs":["file","part","path","action","xml","xml-file","attribute","value","namespace","all","out","dry-run","overwrite","json"],"safe_value":true,"same_extension":true}

  $ office.exe help raw --json | jq -c '[.data.records[0].variants[] | {name,result_schema,outputs:[.outputs[].name]}]'
  [{"name":"list","result_schema":"office.raw.inventory/1","outputs":["format","part_count","parts"]},{"name":"read","result_schema":"office.raw.part/1","outputs":["format","part","encoding","content","output"]},{"name":"replace","result_schema":"office.raw.result/1","outputs":["change","transaction"]},{"name":"edit","result_schema":"office.raw.result/1","outputs":["change","transaction"]}]

  $ office.exe help raw --json | jq -c '[.data.records[0].variants[] | select(.name=="edit") | .actions[] | {name,requires,forbids,restrictions}]'
  [{"name":"append","requires":["exactly-one(xml,xml-file)"],"forbids":["attribute","value"],"restrictions":[]},{"name":"prepend","requires":["exactly-one(xml,xml-file)"],"forbids":["attribute","value"],"restrictions":[]},{"name":"insert-before","requires":["exactly-one(xml,xml-file)"],"forbids":["attribute","value"],"restrictions":["path-must-not-select-document-element"]},{"name":"insert-after","requires":["exactly-one(xml,xml-file)"],"forbids":["attribute","value"],"restrictions":["path-must-not-select-document-element"]},{"name":"replace","requires":["exactly-one(xml,xml-file)"],"forbids":["attribute","value"],"restrictions":[]},{"name":"remove","requires":[],"forbids":["xml","xml-file","attribute","value"],"restrictions":["path-must-not-select-document-element"]},{"name":"set-attribute","requires":["attribute","value"],"forbids":["xml","xml-file"],"restrictions":[]}]

Fresh XLSX creation and strict batch mutation share the validated transaction
boundary. Creation is no-replace by default; batch updates preserve the input
until parsing, application, serialization, and complete candidate validation
all pass.

  $ office.exe help create --json | jq -c '.data.records[0] | {name,formats,variants:[.variants[]|{name,result_schema,inputs:[.inputs[].name],constraints}]}'
  {"name":"create","formats":["xlsx"],"variants":[{"name":"xlsx","result_schema":"office.xlsx.create/1","inputs":["output","sheet","dry-run","overwrite","json"],"constraints":["output-extension=.xlsx","create-new-by-default","transactional-publication","bounded-candidate-package","candidate-max-entry-bytes=12582912","candidate-max-uncompressed-bytes=25165824"]}]}

  $ office.exe help batch --json | jq -c '.data.records[0] | {name,formats,variants:[.variants[]|{name,result_schema,outputs:[.outputs[].name],constraints}]}'
  {"name":"batch","formats":["xlsx"],"variants":[{"name":"xlsx","result_schema":"office.xlsx.batch/1","outputs":["stats","transaction"],"constraints":["schema=xlsx.batch/1","overwrite-requires(out)","out-extension-must-match-input-format","transactional-publication","full-workbook-rewrite-on-change","zero-op-reuses-original","transaction-max-materialized-cells=32768","transaction-max-row-column-lines=32768","read-max-decoded-xml-bytes=16777216","read-max-markup-tokens=262144","read-max-materialized-row-column-dimensions=32768","read-max-row-column-dimension-work=32768","candidate-max-entry-bytes=12582912","candidate-max-uncompressed-bytes=25165824"]}]}

  $ office.exe create xlsx x3-created.xlsx --sheet Data --json | jq -c '{success,schema:.data.schema,sheet:.data.sheet,transaction_schema:.data.transaction.schema,mode:.data.transaction.mode,input:.data.transaction.input,original_size:.data.transaction.original_size,replaced_existing:.data.transaction.replaced_existing,overwritten_size:.data.transaction.overwritten_size,committed:.data.transaction.committed,validations:[.data.transaction.validations[].name],added:(.data.transaction.preservation.added|length>0)}'
  {"success":true,"schema":"office.xlsx.create/1","sheet":"Data","transaction_schema":"office.transaction/2","mode":"create","input":null,"original_size":null,"replaced_existing":false,"overwritten_size":null,"committed":true,"validations":["office-xlsx-bounded-source","office-portable-opc","office-xlsx-bounded"],"added":true}

  $ office.exe identify x3-created.xlsx
  xlsx

  $ printf '%s\n' '{"schema":"xlsx.batch/1","ops":[{"op":"set","params":{"sheet":"Data","cell":"A1","value":"one"}},{"op":"formula","params":{"sheet":"Data","cell":"B1","formula":"=LEN(A1)"}},{"op":"style","params":{"sheet":"Data","range":"A1:B1","bold":true}}]}' > x3-batch.json
  $ office.exe batch x3-created.xlsx x3-batch.json --out x3-batched.xlsx --json | jq -c '{success,schema:.data.schema,stats:.data.stats,committed:.data.transaction.committed,changed:.data.transaction.changed,full_rewrite:any(.warnings[];.code=="office.xlsx.full_rewrite")}'
  {"success":true,"schema":"office.xlsx.batch/1","stats":{"operation_count":3,"touched_cells":4,"style_cells":2,"row_column_lines":0,"new_style_records":1},"committed":true,"changed":true,"full_rewrite":true}

  $ office.exe batch x3-created.xlsx x3-batch.json --out x3-human.xlsx
  committed: 3 operations, 4 touched cells -> x3-human.xlsx
  warning [office.xlsx.full_rewrite]: XLSX batch mutation performs a full workbook serialization; the transaction preservation report is authoritative for changed, added, removed, and unchanged part payloads
  warning [office.transaction.path_based_commit_semantics]: publication uses moonbitlang/async path APIs; atomic rename is guaranteed, but hostile concurrent directory-entry replacement is outside the portable contract

  $ office.exe get x3-batched.xlsx '/xlsx/sheet[name="Data"]/range[A1:B1]' --json | jq -c '{refs:[.data.cells[].reference],raw:[.data.cells[].raw],formulas:[.data.cells[]|(.formula // null)]}'
  {"refs":["A1","B1"],"raw":[{"type":"string","value":"one"},null],"formulas":[null,"LEN(A1)"]}

  $ office.exe text x3-created.xlsx --json | jq -c '{matched_total:.data.matched_total,returned:.data.returned}'
  {"matched_total":0,"returned":0}

Dry-run validates the exact candidate without publishing, while malformed
scripts and application failures leave both source and requested destination
untouched.

  $ office.exe batch x3-created.xlsx x3-batch.json --out x3-dry.xlsx --dry-run --json | jq -c '{dry_run:.data.transaction.dry_run,committed:.data.transaction.committed,changed:.data.transaction.changed}'
  {"dry_run":true,"committed":false,"changed":true}
  $ test ! -e x3-dry.xlsx; echo $?
  0

  $ cp x3-created.xlsx x3-options-before.xlsx
  $ office.exe batch x3-created.xlsx x3-batch.json --overwrite --json > x3-batch-options.json 2>&1; echo $?
  1
  $ jq -c '{success,code:.error.code}' x3-batch-options.json
  {"success":false,"code":"office.invalid_arguments"}
  $ cmp x3-created.xlsx x3-options-before.xlsx; echo $?
  0

  $ office.exe batch x3-created.xlsx missing-script.json --overwrite --json > x3-missing-script-options.json 2>&1; echo $?
  1
  $ jq -c '{success,code:.error.code}' x3-missing-script-options.json
  {"success":false,"code":"office.invalid_arguments"}

  $ printf '%s\n' '{"schema":"xlsx.batch/1","ops":[],"typo":true}' > x3-invalid.json
  $ office.exe batch x3-created.xlsx x3-invalid.json --out x3-invalid.xlsx --json > x3-invalid-result.json 2>&1; echo $?
  1
  $ jq -c '{success,code:.error.code,script:.error.details.script}' x3-invalid-result.json
  {"success":false,"code":"office.xlsx.invalid_batch_script","script":"x3-invalid.json"}
  $ test ! -e x3-invalid.xlsx; echo $?
  0

  $ cp x3-created.xlsx x3-before.xlsx
  $ printf '%s\n' '{"schema":"xlsx.batch/1","ops":[{"op":"set","params":{"sheet":"Missing","cell":"A1","value":"no"}}]}' > x3-operation-error.json
  $ office.exe batch x3-created.xlsx x3-operation-error.json --out x3-operation-error.xlsx --json > x3-operation-result.json 2>&1; echo $?
  1
  $ jq -c '{success,code:.error.code}' x3-operation-result.json
  {"success":false,"code":"office.xlsx.batch_operation_failed"}
  $ cmp x3-created.xlsx x3-before.xlsx; echo $?
  0
  $ test ! -e x3-operation-error.xlsx; echo $?
  0

Creation rejects invalid sheet names and existing destinations without an
explicit overwrite opt-in.

  $ office.exe create xlsx x3-invalid-sheet.xlsx --sheet bad/name --json > x3-invalid-sheet.json 2>&1; echo $?
  1
  $ jq -c '{success,code:.error.code}' x3-invalid-sheet.json
  {"success":false,"code":"office.xlsx.invalid_sheet_name"}
  $ test ! -e x3-invalid-sheet.xlsx; echo $?
  0

  $ office.exe create xlsx '' --json > x3-empty-output.json 2>&1; echo $?
  1
  $ jq -c '{success,code:.error.code}' x3-empty-output.json
  {"success":false,"code":"office.transaction.invalid_options"}

  $ office.exe create xlsx x3-created.xlsx --json > x3-exists.json 2>&1; echo $?
  1
  $ jq -c '{success,code:.error.code}' x3-exists.json
  {"success":false,"code":"office.transaction.output_exists"}

  $ office.exe create xlsx x3-created.xlsx --sheet Replaced --overwrite
  committed: created XLSX sheet "Replaced" -> x3-created.xlsx
  warning [office.transaction.path_based_commit_semantics]: publication uses moonbitlang/async path APIs; atomic rename is guaranteed, but hostile concurrent directory-entry replacement is outside the portable contract

Structured DOCX reads share one bounded projection. Outline provides the map,
get resolves a canonical path, text emits path-tagged paragraphs, and query
uses deterministic document order and declared predicates.

  $ office.exe outline "$TESTDIR/../../../../docx2html/tests/cram/fixtures/single-paragraph.docx" --json | jq -c '{success,schema:.data.schema,counts:.data.counts,stories:[.data.stories[].path]}'
  {"success":true,"schema":"office.docx.outline/1","counts":{"body_stories":1,"headers":0,"footers":0,"footnotes":0,"endnotes":0,"comments":0,"paragraphs":1,"runs":1,"tables":0,"rows":0,"cells":0,"hyperlinks":0,"images":0},"stories":["/docx/body","/docx/footnotes","/docx/endnotes","/docx/comments"]}

  $ office.exe get "$TESTDIR/../../../../docx2html/tests/cram/fixtures/single-paragraph.docx" '/docx/body/p[1]'
  Walking on imported air

  $ office.exe get "$TESTDIR/../../../../docx2html/tests/cram/fixtures/single-paragraph.docx" '/docx/body/p[1]' --json | jq -c '{schema:.data.schema,path:.data.path,kind:.data.kind,stability:.data.stability,text:.data.text,children:[.data.children[].path]}'
  {"schema":"office.docx.element/1","path":"/docx/body/p[1]","kind":"p","stability":"snapshot-relative","text":"Walking on imported air","children":["/docx/body/p[1]/r[1]"]}

  $ office.exe text "$TESTDIR/../../../../docx2html/tests/cram/fixtures/header-footer.docx" --json | jq -c '{schema:.data.schema,paths:[.data.entries[].path],texts:[.data.entries[].text],matched_total:.data.matched_total,returned:.data.returned,truncated:.data.truncated}'
  {"schema":"office.docx.text/1","paths":["/docx/body/p[1]","/docx/body/p[2]","/docx/header[1]/p[1]","/docx/header[2]/p[1]","/docx/footer[1]/p[1]"],"texts":["Body first paragraph","Body second paragraph","Default header text","First page header","Footer text"],"matched_total":5,"returned":5,"truncated":false}

  $ office.exe query "$TESTDIR/../../../../docx2html/tests/cram/fixtures/tiny-picture.docx" --kind picture --json | jq -c '{schema:.data.schema,paths:[.data.matches[].path],kinds:[.data.matches[].kind],matched_total:.data.matched_total,returned:.data.returned,truncated:.data.truncated}'
  {"schema":"office.docx.query/1","paths":["/docx/body/p[1]/r[1]/image[1]"],"kinds":["image"],"matched_total":1,"returned":1,"truncated":false}

Annotation ids are stable when unique; descendants remain snapshot-relative.
Comment metadata includes canonicalized anchors into the body story.

  $ office.exe get "$TESTDIR/../../../../docx2html/tests/cram/fixtures/commented.docx" '/docx/comments/comment[id="0"]' --json | jq -c '{path:.data.path,stability:.data.stability,id:.data.id,author:.data.metadata.author,done:.data.metadata.done,anchor:.data.metadata.anchors[0].start,text:.data.text}'
  {"path":"/docx/comments/comment[id=\"0\"]","stability":"stable","id":"0","author":"Ada Lovelace","done":false,"anchor":"/docx/body/p[2]","text":"Please cite a source here."}

  $ office.exe text "$TESTDIR/../../../../docx2html/tests/cram/fixtures/commented.docx" --under '/docx/comments/comment[id="0"]' --json | jq -c '{under:.data.under,entries:[.data.entries[]|{path,text}],matched_total:.data.matched_total}'
  {"under":"/docx/comments/comment[id=\"0\"]","entries":[{"path":"/docx/comments/comment[id=\"0\"]/p[1]","text":"Please cite a source here."}],"matched_total":1}

The query kind aliases include hyperlinks. This uses the raw editor to make a
valid internal-anchor hyperlink fixture without relying on an external file.

  $ cp "$TESTDIR/../../../../docx2html/tests/cram/fixtures/single-paragraph.docx" hyperlink.docx
  $ office.exe raw edit hyperlink.docx /document --path '/w:document/w:body/w:p[1]/w:r[1]' --action replace --xml '<w:hyperlink xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" w:anchor="target"><w:r><w:t>Jump</w:t></w:r></w:hyperlink>' --json | jq -c '{success,action:.data.change.action,matches:.data.change.match_count}'
  {"success":true,"action":"replace","matches":1}
  $ office.exe query hyperlink.docx --kind link --json | jq -c '{paths:[.data.matches[].path],matched_total:.data.matched_total}'
  {"paths":["/docx/body/p[1]/hyperlink[1]"],"matched_total":1}

Pagination and all user-controlled scan/output ceilings are explicit. Selector
syntax and missing paths retain stable machine-readable codes.

  $ office.exe text "$TESTDIR/../../../../docx2html/tests/cram/fixtures/single-paragraph.docx" --limit 0 --json | jq -c '{matched_total:.data.matched_total,returned:.data.returned,truncated:.data.truncated}'
  {"matched_total":1,"returned":0,"truncated":true}

  $ office.exe get "$TESTDIR/../../../../docx2html/tests/cram/fixtures/single-paragraph.docx" '/docx/body/p[9]' --json > missing-selector.json 2>&1; echo $?
  1
  $ jq -c '{success,code:.error.code,selector:.error.details.selector}' missing-selector.json
  {"success":false,"code":"office.docx.selector_not_found","selector":"/docx/body/p[9]"}

  $ office.exe get "$TESTDIR/../../../../docx2html/tests/cram/fixtures/single-paragraph.docx" '/docx/body/p[@id=0]' --json > malformed-selector.json 2>&1; echo $?
  1
  $ jq -c '{success,code:.error.code}' malformed-selector.json
  {"success":false,"code":"office.selector.unsupported_predicate"}

  $ office.exe outline "$TESTDIR/../../../../docx2html/tests/cram/fixtures/single-paragraph.docx" --max-elements 1 --json > element-limit.json 2>&1; echo $?
  1
  $ jq -c '{success,code:.error.code,resource:.error.details.resource,limit:.error.details.limit}' element-limit.json
  {"success":false,"code":"office.docx.resource_limit","resource":"projection elements","limit":1}

  $ office.exe outline "$TESTDIR/../../../../docx2html/tests/cram/fixtures/single-paragraph.docx" --max-output-chars 40 --json > output-limit.json 2>&1; echo $?
  1
  $ jq -c '{success,code:.error.code,resource:.error.details.resource,limit:.error.details.limit}' output-limit.json
  {"success":false,"code":"office.docx.resource_limit","resource":"successful command output characters","limit":40}

The XLSX-specific scan ceiling is rejected from the filename before package
I/O or parsing. A malformed package therefore cannot mask invalid arguments,
while the larger DOCX ceiling remains available.

  $ printf 'not a zip' > malformed.xlsx
  $ office.exe outline malformed.xlsx --max-elements 100001 --json > xlsx-preflight.json 2>&1; echo $?
  1
  $ jq -c '{success,code:.error.code,maximum:.error.details.maximum}' xlsx-preflight.json
  {"success":false,"code":"office.invalid_arguments","maximum":100000}

  $ office.exe outline "$TESTDIR/../../../../docx2html/tests/cram/fixtures/single-paragraph.docx" --max-elements 100001 --json | jq -c '{success,schema:.data.schema}'
  {"success":true,"schema":"office.docx.outline/1"}

Structured XLSX reads use the same commands and envelope. Positional sheet
input canonicalizes to stable name paths; ranges, text, and query scan in
tab/row/column order with exact totals.

The third-party Book1 fixture contains two intersecting shared-formula ranges.
Normalize that unrelated invalid metadata through the raw transaction surface
before exercising its original contents with the strict structured reader.

  $ office.exe raw read "$TESTDIR/../../../../fixtures/excelize/test/Book1.xlsx" /Sheet2 --output book1-sheet2.xml >/dev/null
  $ sed -e 's/ref="F11:H11"/ref="F11:F11"/' -e 's/<f t="shared" si="0"><\/f>/<f t="shared" si="1"><\/f>/' book1-sheet2.xml > book1-sheet2-valid.xml
  $ office.exe raw replace "$TESTDIR/../../../../fixtures/excelize/test/Book1.xlsx" /Sheet2 --xml-file book1-sheet2-valid.xml --out Book1-valid.xlsx --json >/dev/null

  $ office.exe outline Book1-valid.xlsx --json | jq -c '{success,schema:.data.schema,path:.data.path,sheet_count:.data.sheet_count,active:.data.active_sheet.path,sheets:[.data.sheets[]|{path,kind,state,used:.used_range.reference}]}'
  {"success":true,"schema":"office.xlsx.outline/1","path":"/xlsx/workbook","sheet_count":2,"active":"/xlsx/sheet[name=\"Sheet1\"]","sheets":[{"path":"/xlsx/sheet[name=\"Sheet1\"]","kind":"worksheet","state":"visible","used":"A1:D22"},{"path":"/xlsx/sheet[name=\"Sheet2\"]","kind":"worksheet","state":"visible","used":"A1:I11"}]}

Singleton extents retain two endpoints, so every emitted range path parses and
round-trips through the public selector grammar.

  $ office.exe outline "$TESTDIR/../../../../fixtures/excelize/test/OverflowNumericCell.xlsx" --json | jq -c '{reference:.data.sheets[0].used_range.reference,path:.data.sheets[0].used_range.path}'
  {"reference":"A1:A1","path":"/xlsx/sheet[name=\"Sheet1\"]/range[A1:A1]"}
  $ office.exe get "$TESTDIR/../../../../fixtures/excelize/test/OverflowNumericCell.xlsx" '/xlsx/sheet[1]/range[A1:A1]' --json | jq -c '{path:.data.path,reference:.data.reference,refs:[.data.cells[].reference]}'
  {"path":"/xlsx/sheet[name=\"Sheet1\"]/range[A1:A1]","reference":"A1:A1","refs":["A1"]}

  $ office.exe get Book1-valid.xlsx '/xlsx/sheet[1]/range[A19:B19]' --json | jq -c '{schema:.data.schema,path:.data.path,kind:.data.kind,refs:[.data.cells[].reference],raw:[.data.cells[].raw],formulas:[.data.cells[]|(.formula // null)],returned:.data.returned}'
  {"schema":"office.xlsx.element/1","path":"/xlsx/sheet[name=\"Sheet1\"]/range[A19:B19]","kind":"range","refs":["A19","B19"],"raw":[{"type":"string","value":"Total:"},{"type":"number","value":237}],"formulas":[null,"SUM(Sheet2!D2,Sheet2!D11)"],"returned":2}

  $ office.exe text Book1-valid.xlsx --under '/xlsx/sheet[name="Sheet1"]' --offset 1 --limit 2 --json | jq -c '{schema:.data.schema,under:.data.under,paths:[.data.entries[].path],texts:[.data.entries[].text],matched_total:.data.matched_total,returned:.data.returned,truncated:.data.truncated,scanned:.data.scanned_cells}'
  {"schema":"office.xlsx.text/1","under":"/xlsx/sheet[name=\"Sheet1\"]","paths":["/xlsx/sheet[name=\"Sheet1\"]/cell[B19]","/xlsx/sheet[name=\"Sheet1\"]/cell[C21]"],"texts":["237","Column1"],"matched_total":5,"returned":2,"truncated":true,"scanned":88}

  $ office.exe query Book1-valid.xlsx 'cell[type=formula][formula~=IF]' --under '/xlsx/sheet[name="Sheet2"]' --json | jq -c '{schema:.data.schema,selector:.data.selector,under:.data.under,paths:[.data.matches[].path],matched_total:.data.matched_total,returned:.data.returned,truncated:.data.truncated,scanned:.data.scanned_cells}'
  {"schema":"office.xlsx.query/1","selector":"cell[type=formula][formula~=IF]","under":"/xlsx/sheet[name=\"Sheet2\"]","paths":["/xlsx/sheet[name=\"Sheet2\"]/cell[F11]","/xlsx/sheet[name=\"Sheet2\"]/cell[G11]","/xlsx/sheet[name=\"Sheet2\"]/cell[H11]","/xlsx/sheet[name=\"Sheet2\"]/cell[I11]"],"matched_total":4,"returned":4,"truncated":false,"scanned":99}

Exact text predicates preserve whitespace through the real command-line path;
JSON quoting also keeps selector delimiters unambiguous.

  $ xlsx.exe create whitespace.xlsx --sheet Data >/dev/null
  $ xlsx.exe set whitespace.xlsx Data A1 ' leading and trailing ' >/dev/null
  $ office.exe query whitespace.xlsx 'cell[text= leading and trailing ]' --json | jq -c '{selector:.data.selector,values:[.data.matches[].raw.value],matched_total:.data.matched_total}'
  {"selector":"cell[text= leading and trailing ]","values":[" leading and trailing "],"matched_total":1}
  $ office.exe query whitespace.xlsx 'cell[text=" leading and trailing "]' --json | jq -c '{selector:.data.selector,values:[.data.matches[].raw.value],matched_total:.data.matched_total}'
  {"selector":"cell[text=\" leading and trailing \"]","values":[" leading and trailing "],"matched_total":1}

Cross-format selectors and DOCX-only XLSX query flags fail with XLSX-specific,
machine-correctable codes.

  $ office.exe get Book1-valid.xlsx '/docx/body' --json > xlsx-selector-mismatch.json 2>&1; echo $?
  1
  $ jq -c '{success,code:.error.code,expected:.error.details.expected_format,actual:.error.details.actual_format}' xlsx-selector-mismatch.json
  {"success":false,"code":"office.xlsx.selector_format_mismatch","expected":"xlsx","actual":"docx"}

  $ office.exe query Book1-valid.xlsx --kind cell --json > xlsx-query-options.json 2>&1; echo $?
  1
  $ jq -c '{success,code:.error.code,options:.error.details.options}' xlsx-query-options.json
  {"success":false,"code":"office.xlsx.unsupported_query_options","options":["--kind"]}

Extension/content mismatches and malformed input fail non-zero.

  $ office.exe identify > missing-file.out 2>&1; echo $?
  1
  $ head -1 missing-file.out
  office: 'file' requires at least 1 values but only 0 were provided

  $ office.exe identify --json > missing-file.json 2>&1; echo $?
  1
  $ jq -c '{schema,success,code:.error.code}' missing-file.json
  {"schema":"office.output/1","success":false,"code":"office.invalid_arguments"}

  $ cp "$TESTDIR/../../../../docx2html/tests/cram/fixtures/single-paragraph.docx" report.xlsx
  $ office.exe identify report.xlsx
  office: file extension says xlsx, but package content is docx
  [1]

  $ printf 'not zip' > broken.docx; office.exe identify broken.docx
  office: invalid Office package: archive is not a readable bounded ZIP
  [1]

JSON business and operational failures are one parseable envelope and retain a
non-zero process status.

  $ office.exe identify report.xlsx --json > mismatch.json 2>&1; echo $?
  1
  $ jq -c '{success,code:.error.code,expected:.error.details.expected,actual:.error.details.actual}' mismatch.json
  {"success":false,"code":"office.format_mismatch","expected":"xlsx","actual":"docx"}

  $ office.exe identify absent.docx --json > absent.json 2>&1; echo $?
  1
  $ jq -c '{success,code:.error.code,file:.error.details.file}' absent.json
  {"success":false,"code":"office.file_read_failed","file":"absent.docx"}

Help token errors are bounded and include stable codes and suggestions.

  $ office.exe help identfy --json > unknown-first-operation.json 2>&1; echo $?
  1
  $ jq -c '{code:.error.code,suggestions:.error.details.suggestions}' unknown-first-operation.json
  {"code":"office.unknown_operation","suggestions":["identify"]}

  $ office.exe help xlxs --json > unknown-format.json 2>&1; echo $?
  1
  $ jq -c '{code:.error.code,suggestions:.error.details.suggestions}' unknown-format.json
  {"code":"office.unknown_format","suggestions":["xlsx"]}

  $ office.exe help docx identfy --json > unknown-operation.json 2>&1; echo $?
  1
  $ jq -c '{code:.error.code,suggestions:.error.details.suggestions}' unknown-operation.json
  {"code":"office.unknown_operation","suggestions":["identify"]}

  $ office.exe help docx identify paragraph --json > unknown-element.json 2>&1; echo $?
  1
  $ jq -c '{code:.error.code,suggestions:.error.details.suggestions}' unknown-element.json
  {"code":"office.unknown_element","suggestions":[]}

  $ office.exe help all --json --jsonl > conflict.json 2>&1; echo $?
  1
  $ jq -c '{success,code:.error.code}' conflict.json
  {"success":false,"code":"office.output_mode_conflict"}

Raw OOXML inventory and reads resolve parts from relationships for both
supported formats. Structured output stays inside the shared envelope.

  $ office.exe raw list "$TESTDIR/../../../../docx2html/tests/cram/fixtures/single-paragraph.docx" --json | jq -c '{success,schema:.data.schema,format:.data.format,document:[.data.parts[]|select(.aliases|index("/document"))|.name]}'
  {"success":true,"schema":"office.raw.inventory/1","format":"docx","document":["/word/document.xml"]}

  $ office.exe raw list "$TESTDIR/../../../../fixtures/excelize/test/Book1.xlsx" --json | jq -c '{format:.data.format,sheets:[.data.parts[]|select(.aliases|index("/sheet[1]"))|.name],named:[.data.parts[]|select(.aliases|index("/Sheet1"))|.name]}'
  {"format":"xlsx","sheets":["/xl/worksheets/sheet1.xml"],"named":["/xl/worksheets/sheet1.xml"]}

  $ office.exe raw read "$TESTDIR/../../../../docx2html/tests/cram/fixtures/single-paragraph.docx" /document --json | jq -c '{success,schema:.data.schema,name:.data.part.name,encoding:.data.encoding,contains:(.data.content|contains("Walking on imported air"))}'
  {"success":true,"schema":"office.raw.part/1","name":"/word/document.xml","encoding":"xml","contains":true}

Binary reads require an explicit mode. Base64 is machine-safe, while file
output is exact and create-new.

  $ office.exe raw read "$TESTDIR/../../../../fixtures/excelize/test/Book1.xlsx" /xl/media/image1.jpeg --json > binary.json 2>&1; echo $?
  1
  $ jq -c '{success,code:.error.code}' binary.json
  {"success":false,"code":"office.raw.binary_requires_explicit_mode"}

  $ office.exe raw read "$TESTDIR/../../../../fixtures/excelize/test/Book1.xlsx" /xl/media/image1.jpeg --base64 --json | jq -c '{success,encoding:.data.encoding,bytes:.data.part.size,nonempty:(.data.content|length>100)}'
  {"success":true,"encoding":"base64","bytes":2376,"nonempty":true}

  $ office.exe raw read "$TESTDIR/../../../../fixtures/excelize/test/Book1.xlsx" /xl/media/image1.jpeg --output image.jpeg --json | jq -c '{success,encoding:.data.encoding,output:.data.output}'
  {"success":true,"encoding":"binary","output":"image.jpeg"}
  $ unzip -p "$TESTDIR/../../../../fixtures/excelize/test/Book1.xlsx" xl/media/image1.jpeg | cmp - image.jpeg; echo $?
  0
  $ office.exe raw read "$TESTDIR/../../../../fixtures/excelize/test/Book1.xlsx" /xl/media/image1.jpeg --output image.jpeg --json > exists.json 2>&1; echo $?
  1
  $ jq -c '{success,code:.error.code}' exists.json
  {"success":false,"code":"office.raw.output_write_failed"}

Raw edits use the A4 transaction. Dry runs report the one-part preservation
manifest without changing the source; separate output commits are validated.

  $ cp "$TESTDIR/../../../../docx2html/tests/cram/fixtures/single-paragraph.docx" input.docx
  $ cp input.docx before.docx
  $ office.exe raw edit input.docx /document --path '/w:document/w:body/w:p[1]' --action set-attribute --attribute w:rsidR --value DEADBEEF --dry-run --json | jq -c '{success,action:.data.change.action,matches:.data.change.match_count,dry_run:.data.transaction.dry_run,committed:.data.transaction.committed,changed:.data.transaction.preservation.changed}'
  {"success":true,"action":"set-attribute","matches":1,"dry_run":true,"committed":false,"changed":["word/document.xml"]}
  $ cmp before.docx input.docx; echo $?
  0

A missing option value must never consume a publish-control flag. The command
fails before opening a transaction, and the in-place input remains byte-exact.

  $ cp before.docx missing-value.docx
  $ cp missing-value.docx missing-value-before.docx
  $ office.exe raw edit missing-value.docx /document --path '/w:document/w:body/w:p[1]' --action set-attribute --attribute test --value --dry-run --json > missing-value.json 2>&1; echo $?
  1
  $ jq -c '{success,code:.error.code}' missing-value.json
  {"success":false,"code":"office.invalid_arguments"}
  $ cmp missing-value-before.docx missing-value.docx; echo $?
  0

  $ office.exe raw edit input.docx /document --path '/w:document/w:body/w:p[1]' --action set-attribute --attribute w:rsidR --value DEADBEEF --out edited.docx --json | jq -c '{success,action:.data.change.action,committed:.data.transaction.committed,changed:.data.transaction.preservation.changed}'
  {"success":true,"action":"set-attribute","committed":true,"changed":["word/document.xml"]}
  $ unzip -p edited.docx word/document.xml | grep -o 'w:rsidR="[^"]*"' | head -1
  w:rsidR="DEADBEEF"
  $ cmp before.docx input.docx; echo $?
  0

Whole-part replacement accepts bounded UTF-8 file input. Invalid selector
syntax retains the raw subsystem's stable error code through the transaction.

  $ unzip -p input.docx word/document.xml > same.xml
  $ office.exe raw replace input.docx /document --xml-file same.xml
  validated no-op: whole-part replacement for /word/document.xml -> input.docx
  $ cmp before.docx input.docx; echo $?
  0

  $ office.exe raw read input.docx /document > original.xml
  $ sed 's/Walking on imported air/CLI replace/' original.xml > replacement.xml
  $ office.exe raw replace input.docx /document --xml-file replacement.xml --out replaced.docx --json | jq -c '{success,action:.data.change.action,part:.data.change.part,changed:.data.transaction.preservation.changed}'
  {"success":true,"action":"replace-part","part":"/word/document.xml","changed":["word/document.xml"]}
  $ unzip -p replaced.docx word/document.xml | grep -o 'CLI replace'
  CLI replace

  $ office.exe raw edit input.docx /document --path '//w:p' --action remove --dry-run --json > invalid-path.json 2>&1; echo $?
  1
  $ jq -c '{success,code:.error.code}' invalid-path.json
  {"success":false,"code":"office.raw.invalid_path"}

A separate output must retain the package format's supported extension. The
candidate fails before publication, so neither input nor destination changes.

  $ office.exe raw edit input.docx /document --path '/w:document/w:body/w:p[1]' --action set-attribute --attribute test --value true --out wrong.xlsx --json > wrong-extension.json 2>&1; echo $?
  1
  $ jq -c '{success,code:.error.code}' wrong-extension.json
  {"success":false,"code":"office.raw.invalid_package"}
  $ test ! -e wrong.xlsx; echo $?
  0
  $ cmp before.docx input.docx; echo $?
  0

Oversized optional error details are dropped at the transaction boundary
without replacing the raw subsystem's stable error code.

  $ segment=x; i=0; while [ "$i" -lt 120 ]; do segment="$segment"x; i=$((i + 1)); done
  $ long_path=/w:document; i=0; while [ "$i" -lt 10 ]; do long_path="$long_path/w:$segment"; i=$((i + 1)); done
  $ office.exe raw edit input.docx /document --path "$long_path" --action remove --dry-run --json > long-path.json 2>&1; echo $?
  1
  $ jq -c '{success,code:.error.code,has_details:(.error|has("details"))}' long-path.json
  {"success":false,"code":"office.raw.path_not_found","has_details":false}

The cross-format validate command shares the exact pre-commit mutation gate
and reports a machine-checkable verdict: exit zero with a bounded result for
valid packages, non-zero with a complete findings envelope otherwise.

  $ office.exe validate "$TESTDIR/../../../../fixtures/excelize/test/Book1.xlsx"
  valid xlsx

  $ office.exe validate "$TESTDIR/../../../../docx2html/tests/cram/fixtures/single-paragraph.docx" --json | jq -c '{success,data:{schema:.data.schema,format:.data.format,valid:.data.valid,error_count:.data.error_count}}'
  {"success":true,"data":{"schema":"office.validate/1","format":"docx","valid":true,"error_count":0}}

  $ printf 'not a zip archive' > corrupt.xlsx
  $ office.exe validate corrupt.xlsx --json > corrupt-validate.json 2>&1; echo $?
  1
  $ jq -c '{success,code:.error.code}' corrupt-validate.json
  {"success":false,"code":"office.invalid_package"}

An uncovered extra part is rejected by the structural detector before the
gate even runs. A package whose sheet XML is broken is rejected either by
the strict detector or by the shared parse gate: which layer fires depends
on the byte layout the local zip tool produced, but the verdict is always a
deterministic non-zero rejection.

  $ cp "$TESTDIR/../../../../fixtures/excelize/test/Book1.xlsx" tampered.xlsx
  $ printf 'binary' > extra.bin
  $ zip -q tampered.xlsx extra.bin
  $ office.exe validate tampered.xlsx --json > tampered-validate.json 2>&1; echo $?
  1
  $ jq -c '{success,code:.error.code}' tampered-validate.json
  {"success":false,"code":"office.invalid_package"}

  $ cp "$TESTDIR/../../../../fixtures/excelize/test/Book1.xlsx" broken-sheet.xlsx
  $ mkdir -p xl/worksheets && printf '<worksheet' > xl/worksheets/sheet1.xml
  $ zip -q broken-sheet.xlsx xl/worksheets/sheet1.xml
  $ office.exe validate broken-sheet.xlsx --json > broken-validate.json 2>&1; echo $?
  1
  $ jq -c '{success,rejected:(.error.code == "office.xlsx.validation_failed" or .error.code == "office.invalid_package")}' broken-validate.json
  {"success":false,"rejected":true}

The issues command reports bounded actionable findings without conflating
warnings with fatal invalidity: cached XLSX formula error values are
warnings with cell locations, and the exit status stays zero.

  $ office.exe issues "$TESTDIR/../../../../docx2html/tests/cram/fixtures/single-paragraph.docx" --json | jq -c '{success,data:{schema:.data.schema,error_count:.data.error_count}}'
  {"success":true,"data":{"schema":"office.issues/1","error_count":0}}

  $ office.exe create xlsx issues-probe.xlsx --json > /dev/null
  $ office.exe issues issues-probe.xlsx
  xlsx: 0 error(s), 0 warning(s)

The preview command publishes one deterministic self-contained HTML document
through the atomic create-new path: charts render as inline SVG, an existing
destination is refused with the shared transaction code unless --overwrite is
given, and the report is truthful about what was rendered.

  $ xlsx.exe create preview.xlsx --sheet Data >/dev/null
  $ xlsx.exe set preview.xlsx Data A1 Region >/dev/null
  $ xlsx.exe set preview.xlsx Data B1 Sales >/dev/null
  $ xlsx.exe set preview.xlsx Data A2 East >/dev/null
  $ xlsx.exe set preview.xlsx Data B2 30 >/dev/null
  $ xlsx.exe set preview.xlsx Data A3 West >/dev/null
  $ xlsx.exe set preview.xlsx Data B3 70 >/dev/null
  $ xlsx.exe chart preview.xlsx Data D2 --type col --categories A2:A3 --values B2:B3 --name 'Data!B1' >/dev/null
  $ office.exe preview preview.xlsx --output preview.html --json | jq -c '{success,data:{schema:.data.schema,format:.data.format,charts_rendered:.data.charts_rendered,charts_placeholder:.data.charts_placeholder,truncated:.data.truncation.truncated_sheets}}'
  {"success":true,"data":{"schema":"office.preview/1","format":"xlsx","charts_rendered":1,"charts_placeholder":0,"truncated":[]}}
  $ grep -c '<figure class="chart"' preview.html
  1
  $ grep -c 'aria-label="barChart with 1 series; Sales (2 points)"' preview.html
  1

  $ office.exe preview preview.xlsx --output preview.html --json > preview-exists.json 2>&1; echo $?
  1
  $ jq -c '{success,code:.error.code}' preview-exists.json
  {"success":false,"code":"office.transaction.output_exists"}
  $ office.exe preview preview.xlsx --output preview.html --overwrite --jsonl | jq -c '{success,schema:.data.schema}'
  {"success":true,"schema":"office.preview/1"}

  $ office.exe preview preview.xlsx --output preview.txt --json > preview-ext.json 2>&1; echo $?
  1
  $ jq -c '{success,code:.error.code}' preview-ext.json
  {"success":false,"code":"office.invalid_arguments"}

DOCX previews inline the shared HTML converter output in one page shell.

  $ office.exe preview "$TESTDIR/../../../../docx2html/tests/cram/fixtures/single-paragraph.docx" --output para.html --json | jq -c '{success,data:{schema:.data.schema,format:.data.format,images_embedded:.data.images_embedded}}'
  {"success":true,"data":{"schema":"office.preview/1","format":"docx","images_embedded":0}}
  $ grep -c '<!DOCTYPE html>' para.html
  1

The template command merges strict office.template.data/1 values into a
workbook: {{key}} placeholders substitute (whole-cell placeholders keep
the data value's type), \{{ escapes yield literals, missing keys refuse
by default, and formula cells are refused contexts. The template file is
never modified.

  $ xlsx.exe create tpl.xlsx --sheet Data >/dev/null
  $ xlsx.exe set tpl.xlsx Data A1 'Customer: {{customer}}' >/dev/null
  $ xlsx.exe set tpl.xlsx Data B1 '{{total}}' >/dev/null
  $ xlsx.exe set tpl.xlsx Data C1 '\{{literal}} and {{paid}}' >/dev/null
  $ cat > tpl-data.json <<'DATA'
  > {"schema":"office.template.data/1","values":{"customer":"Ada Lovelace","total":1234.5,"paid":true,"fax":"unused"}}
  > DATA
  $ office.exe template tpl.xlsx tpl-data.json --out filled.xlsx
  template: 3 replaced, 0 missing, 1 unused -> filled.xlsx
  $ xlsx.exe get filled.xlsx Data A1
  Customer: Ada Lovelace
  $ xlsx.exe get filled.xlsx Data B1
  1234.5
  $ xlsx.exe get filled.xlsx Data C1
  {{literal}} and true
  $ office.exe template tpl.xlsx tpl-data.json --out filled-json.xlsx --json | jq -c '{success,data:{schema:.data.schema,replaced:.data.replaced,escapes:.data.escapes_applied,unused:.data.unused}}'
  {"success":true,"data":{"schema":"office.template/1","replaced":3,"escapes":1,"unused":["fax"]}}

Missing keys refuse publication with the report in the failure details;
--allow-missing keeps the literal placeholders and publishes.

  $ cat > tpl-missing.json <<'DATA'
  > {"schema":"office.template.data/1","values":{"customer":"Ada"}}
  > DATA
  $ office.exe template tpl.xlsx tpl-missing.json --out refused.xlsx --json 2>&1 | jq -c '{success,code:.error.code,missing:[.error.details.missing[].detail]}'
  {"success":false,"code":"office.template.missing_keys","missing":["total","paid"]}
  $ test -f refused.xlsx || echo not published
  not published
  $ office.exe template tpl.xlsx tpl-missing.json --out partial.xlsx --allow-missing --json | jq -c '{success,replaced:.data.replaced,missing:[.data.missing[].detail]}'
  {"success":true,"replaced":1,"missing":["total","paid"]}
  $ xlsx.exe get partial.xlsx Data B1
  {{total}}

Malformed placeholders and formula-cell contexts are typed refusals; a
dry run reports without publishing; a no-op merge publishes a validated
copy; invalid data fails before the document opens.

  $ xlsx.exe create tpl-bad.xlsx --sheet Data >/dev/null
  $ xlsx.exe set tpl-bad.xlsx Data A1 'oops {{9bad}}' >/dev/null
  $ office.exe template tpl-bad.xlsx tpl-data.json --out bad-out.xlsx --json 2>&1 | jq -c '{success,code:.error.code}'
  {"success":false,"code":"office.template.malformed_placeholder"}
  $ xlsx.exe create tpl-formula.xlsx --sheet Data >/dev/null
  $ xlsx.exe formula tpl-formula.xlsx Data A1 'CONCAT("{{x}}","y")' >/dev/null
  $ office.exe template tpl-formula.xlsx tpl-data.json --out f-out.xlsx --json 2>&1 | jq -c '{success,code:.error.code,loc:.error.details.unsupported[0].location}'
  {"success":false,"code":"office.template.unsupported_context","loc":"Data!A1"}
  $ office.exe template tpl.xlsx tpl-data.json --out dry.xlsx --dry-run --json | jq -c '{success,replaced:.data.replaced}'
  {"success":true,"replaced":3}
  $ test -f dry.xlsx || echo not published
  not published
  $ xlsx.exe create tpl-plain.xlsx --sheet Data >/dev/null
  $ xlsx.exe set tpl-plain.xlsx Data A1 'no placeholders here' >/dev/null
  $ cat > tpl-empty.json <<'DATA'
  > {"schema":"office.template.data/1","values":{}}
  > DATA
  $ office.exe template tpl-plain.xlsx tpl-empty.json --out plain-out.xlsx --json | jq -c '{success,replaced:.data.replaced,changed_parts:(.data.transaction.preservation.changed|length)}'
  {"success":true,"replaced":0,"changed_parts":0}
  $ cat > tpl-null.json <<'DATA'
  > {"schema":"office.template.data/1","values":{"a":null}}
  > DATA
  $ office.exe template tpl.xlsx tpl-null.json --out never.xlsx --json 2>&1 | jq -c '{success,code:.error.code}'
  {"success":false,"code":"office.template.invalid_data"}

DOCX templates merge through the preservation-safe edit session: run
text rewrites by byte span, placeholders may cross run boundaries, and
only touched parts change. The template file is never modified.

  $ cat > docx-tpl-script.json <<'SCRIPT'
  > {"schema":"docx.batch/2","ops":[
  >  {"op":"paragraph","params":{"runs":[
  >    {"text":"Dear ","bold":true},
  >    {"text":"{{cus"},
  >    {"text":"tomer}}, balance "},
  >    {"text":"{{total}}."}
  >  ]}},
  >  {"op":"paragraph","params":{"text":"Escaped: \\{{literal}} end"}}
  > ]}
  > SCRIPT
  $ docx.exe batch docx-tpl.docx docx-tpl-script.json >/dev/null
  $ cat > docx-tpl-data.json <<'DATA'
  > {"schema":"office.template.data/1","values":{"customer":"Ada Lovelace","total":1234.5}}
  > DATA
  $ office.exe template docx-tpl.docx docx-tpl-data.json --out docx-filled.docx
  template: 2 replaced, 0 missing, 0 unused -> docx-filled.docx
  $ docx.exe text docx-filled.docx
  [/body/p[1]] Dear Ada Lovelace, balance 1234.5.
  [/body/p[2]] Escaped: {{literal}} end
  $ office.exe template docx-tpl.docx docx-tpl-data.json --out docx-filled2.docx --json | jq -c '{success,data:{format:.data.format,replaced:.data.replaced,escapes:.data.escapes_applied,stories:.data.stories_scanned,changed:[.data.transaction.preservation.changed[]]}}'
  {"success":true,"data":{"format":"docx","replaced":2,"escapes":1,"stories":["/body"],"changed":["word/document.xml"]}}
  $ cat > docx-missing.json <<'DATA'
  > {"schema":"office.template.data/1","values":{"customer":"Ada"}}
  > DATA
  $ office.exe template docx-tpl.docx docx-missing.json --out docx-never.docx --json 2>&1 | jq -c '{success,code:.error.code,missing:[.error.details.missing[].detail],loc:.error.details.missing[0].location}'
  {"success":false,"code":"office.template.missing_keys","missing":["total"],"loc":"/docx/body/p[1]"}
  $ test -f docx-never.docx || echo not published
  not published
  $ office.exe template docx-tpl.docx docx-missing.json --out docx-part.docx --allow-missing >/dev/null
  $ docx.exe text docx-part.docx | head -1
  [/body/p[1]] Dear Ada, balance {{total}}.

The dump command emits a replayable office.dump/1 op stream: canonical
ordered batch ops in JSON and the streaming JSONL form with an integrity
digest, for XLSX and DOCX packages alike.

  $ xlsx.exe create dump.xlsx --sheet Data >/dev/null
  $ xlsx.exe set dump.xlsx Data A1 Region >/dev/null
  $ xlsx.exe set dump.xlsx Data B1 42 >/dev/null
  $ office.exe dump dump.xlsx --json | jq -c '{schema,format,ops:[.ops[].op],residual:(.residual|length)}'
  {"schema":"office.dump/1","format":"xlsx","ops":["set","set"],"residual":0}
  $ office.exe dump dump.xlsx --jsonl | jq -c '.record' | sort -u
  "end"
  "header"
  "op"
  $ office.exe dump dump.xlsx --jsonl | jq -rc 'select(.record=="end") | (.ops_sha256 | test("^[0-9a-f]{64}$"))'
  true
  $ office.exe dump dump.xlsx
  xlsx dump: 2 op(s), 0 residual, 0 warning(s)

A DOCX package dumps to docx.batch/2 ops; the writer's default section
is disclosed as a residual rather than silently regenerated.

  $ office.exe dump "$TESTDIR/../../../../docx2html/tests/cram/fixtures/single-paragraph.docx"
  docx dump: 1 op(s), 1 residual, 0 warning(s)
  $ office.exe dump "$TESTDIR/../../../../docx2html/tests/cram/fixtures/single-paragraph.docx" --json | jq -c '{schema,format,batch:.replay.batch_schema,ops:[.ops[].op],residual:[.residual[].code]}'
  {"schema":"office.dump/1","format":"docx","batch":"docx.batch/2","ops":["paragraph"],"residual":["docx.sections_not_dumped"]}
  $ office.exe dump "$TESTDIR/../../../../docx2html/tests/cram/fixtures/single-paragraph.docx" --jsonl | jq -rc 'select(.record=="end") | (.ops_sha256 | test("^[0-9a-f]{64}$"))'
  true

Comments become comment ops threaded to their anchors, and pictures ride
as content-addressed assets referenced by their image specs. The replay
command rebuilds a DOCX from the dump through the same batch build path,
and dump then replay then dump is stable.

  $ office.exe dump "$TESTDIR/../../../../docx2html/tests/cram/fixtures/commented.docx" --json > commented.dump.json
  $ office.exe replay commented.dump.json --output replayed-comments.docx --json | jq -c '{success,data:{schema:.data.schema,format:.data.format,ops:.data.ops_applied}}'
  {"success":true,"data":{"schema":"office.replay/1","format":"docx","ops":5}}
  $ office.exe dump replayed-comments.docx --json | jq -c '{ops:[.ops[].op]}'
  {"ops":["paragraph","paragraph","paragraph","comment","comment"]}
  $ office.exe dump "$TESTDIR/../../../../docx2html/tests/cram/fixtures/tiny-picture.docx" --json > picture.dump.json
  $ office.exe replay picture.dump.json --output replayed-picture.docx >/dev/null
  $ office.exe dump replayed-picture.docx --json | jq -c '{ops:[.ops[].op],assets:(.assets|length)}'
  {"ops":["paragraph"],"assets":1}
  $ jq -c '.ops' picture.dump.json > before.ops.json
  $ office.exe dump replayed-picture.docx --json | jq -c '.ops' > after.ops.json
  $ cmp before.ops.json after.ops.json && echo identical
  identical
  $ office.exe replay commented.dump.json --output wrong-extension.xlsx --json 2>&1 | jq -c '{success,code:.error.code}'
  {"success":false,"code":"office.invalid_arguments"}

  $ office.exe dump "$TESTDIR/../../../../docx2html/tests/cram/fixtures/commented.docx" --json | jq -c '{ops:[.ops[].op],residual:[.residual[].code]}'
  {"ops":["paragraph","paragraph","paragraph","comment","comment"],"residual":["docx.sections_not_dumped","docx.run_style_dropped"]}
  $ office.exe dump "$TESTDIR/../../../../docx2html/tests/cram/fixtures/tiny-picture.docx" --json | jq -c '{ops:[.ops[].op],assets:(.assets|length),residual:[.residual[].code]}'
  {"ops":["paragraph"],"assets":1,"residual":["docx.sections_not_dumped"]}

The replay command reconstructs an XLSX workbook from an office.dump/1
document by applying its ops through the same engine, then publishes it
through the atomic create-new path. dump then replay then dump is stable.

  $ xlsx.exe create replay-src.xlsx --sheet Data >/dev/null
  $ xlsx.exe set replay-src.xlsx Data A1 Region >/dev/null
  $ xlsx.exe set replay-src.xlsx Data B1 42 >/dev/null
  $ xlsx.exe formula replay-src.xlsx Data C1 'B1*2' >/dev/null
  $ office.exe dump replay-src.xlsx --json > replay-src.dump.json
  $ office.exe replay replay-src.dump.json --output replayed.xlsx --json | jq -c '{success,data:{schema:.data.schema,format:.data.format,ops:.data.ops_applied}}'
  {"success":true,"data":{"schema":"office.replay/1","format":"xlsx","ops":3}}
  $ office.exe identify replayed.xlsx
  xlsx
  $ office.exe dump replayed.xlsx --json | jq -c '.ops' > round.ops.json
  $ office.exe dump replay-src.xlsx --json | jq -c '.ops' > orig.ops.json
  $ diff -q orig.ops.json round.ops.json && echo stable
  stable

  $ before=$(shasum -a 256 replayed.xlsx | cut -d' ' -f1)
  $ office.exe replay replay-src.dump.json --output replayed.xlsx --json > replay-exists.json 2>&1; echo $?
  1
  $ jq -c '{success,code:.error.code}' replay-exists.json
  {"success":false,"code":"office.transaction.output_exists"}
  $ test "$before" = "$(shasum -a 256 replayed.xlsx | cut -d' ' -f1)" && echo unchanged
  unchanged

  $ office.exe replay replay-src.dump.json --output replayed.txt --json > replay-ext.json 2>&1; echo $?
  1
  $ jq -c '{success,code:.error.code}' replay-ext.json
  {"success":false,"code":"office.invalid_arguments"}
  $ test ! -e replayed.txt && echo no-write
  no-write

  $ printf 'not json' > bad.dump.json
  $ office.exe replay bad.dump.json --output out.xlsx --json > replay-bad.json 2>&1; echo $?
  1
  $ jq -c '{success,code:.error.code}' replay-bad.json
  {"success":false,"code":"office.replay.invalid_dump"}
  $ test ! -e out.xlsx && echo no-write
  no-write

  $ jq '.stats.ops = 999' replay-src.dump.json > padded.dump.json
  $ office.exe replay padded.dump.json --output padded.xlsx --json > replay-padded.json 2>&1; echo $?
  1
  $ jq -c '{success,code:.error.code}' replay-padded.json
  {"success":false,"code":"office.replay.invalid_dump"}
  $ test ! -e padded.xlsx && echo no-write
  no-write
