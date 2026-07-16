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
    Fingerprint: crc32:e9c5b34f
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
  {"formats":["docx","xlsx"],"variants":[{"name":"docx","result_schema":"office.docx.query/1","constraints":["format=docx"]},{"name":"xlsx","result_schema":"office.xlsx.query/1","constraints":["format=xlsx"]}]}

  $ office.exe help all --json | jq -c '{schema,success,capability_schema:.data.schema,fingerprint:.data.fingerprint,names:[.data.records[].name]}'
  {"schema":"office.output/1","success":true,"capability_schema":"office.capabilities/2","fingerprint":"crc32:e9c5b34f","names":["docx","xlsx","help","identify","outline","get","text","query","raw"]}

  $ office.exe help all --jsonl | jq -s -c 'map({schema,fingerprint,kind,name})'
  [{"schema":"office.capability/2","fingerprint":"crc32:e9c5b34f","kind":"format","name":"docx"},{"schema":"office.capability/2","fingerprint":"crc32:e9c5b34f","kind":"format","name":"xlsx"},{"schema":"office.capability/2","fingerprint":"crc32:e9c5b34f","kind":"command","name":"help"},{"schema":"office.capability/2","fingerprint":"crc32:e9c5b34f","kind":"command","name":"identify"},{"schema":"office.capability/2","fingerprint":"crc32:e9c5b34f","kind":"command","name":"outline"},{"schema":"office.capability/2","fingerprint":"crc32:e9c5b34f","kind":"command","name":"get"},{"schema":"office.capability/2","fingerprint":"crc32:e9c5b34f","kind":"command","name":"text"},{"schema":"office.capability/2","fingerprint":"crc32:e9c5b34f","kind":"command","name":"query"},{"schema":"office.capability/2","fingerprint":"crc32:e9c5b34f","kind":"command","name":"raw"}]

The raw command publishes explicit subcommand schemas, including every edit
input and its conditional constraints.

  $ office.exe help raw --json | jq -c '.data.records[0] | {variants:[.variants[].name],edit_inputs:[.variants[]|select(.name=="edit")|.inputs[].name],safe_value:([.variants[]|select(.name=="edit")|.constraints[]]|index("flag-looking-values-require-attached-syntax")!=null),same_extension:([.variants[]|select(.name=="edit")|.constraints[]]|index("out-extension-must-match-input-format")!=null)}'
  {"variants":["list","read","replace","edit"],"edit_inputs":["file","part","path","action","xml","xml-file","attribute","value","namespace","all","out","dry-run","overwrite","json"],"safe_value":true,"same_extension":true}

  $ office.exe help raw --json | jq -c '[.data.records[0].variants[] | {name,result_schema,outputs:[.outputs[].name]}]'
  [{"name":"list","result_schema":"office.raw.inventory/1","outputs":["format","part_count","parts"]},{"name":"read","result_schema":"office.raw.part/1","outputs":["format","part","encoding","content","output"]},{"name":"replace","result_schema":"office.raw.result/1","outputs":["change","transaction"]},{"name":"edit","result_schema":"office.raw.result/1","outputs":["change","transaction"]}]

  $ office.exe help raw --json | jq -c '[.data.records[0].variants[] | select(.name=="edit") | .actions[] | {name,requires,forbids,restrictions}]'
  [{"name":"append","requires":["exactly-one(xml,xml-file)"],"forbids":["attribute","value"],"restrictions":[]},{"name":"prepend","requires":["exactly-one(xml,xml-file)"],"forbids":["attribute","value"],"restrictions":[]},{"name":"insert-before","requires":["exactly-one(xml,xml-file)"],"forbids":["attribute","value"],"restrictions":["path-must-not-select-document-element"]},{"name":"insert-after","requires":["exactly-one(xml,xml-file)"],"forbids":["attribute","value"],"restrictions":["path-must-not-select-document-element"]},{"name":"replace","requires":["exactly-one(xml,xml-file)"],"forbids":["attribute","value"],"restrictions":[]},{"name":"remove","requires":[],"forbids":["xml","xml-file","attribute","value"],"restrictions":["path-must-not-select-document-element"]},{"name":"set-attribute","requires":["attribute","value"],"forbids":["xml","xml-file"],"restrictions":[]}]

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

Structured XLSX reads use the same commands and envelope. Positional sheet
input canonicalizes to stable name paths; ranges, text, and query scan in
tab/row/column order with exact totals.

  $ office.exe outline "$TESTDIR/../../../../fixtures/excelize/test/Book1.xlsx" --json | jq -c '{success,schema:.data.schema,path:.data.path,sheet_count:.data.sheet_count,active:.data.active_sheet.path,sheets:[.data.sheets[]|{path,kind,state,used:.used_range.reference}]}'
  {"success":true,"schema":"office.xlsx.outline/1","path":"/xlsx/workbook","sheet_count":2,"active":"/xlsx/sheet[name=\"Sheet1\"]","sheets":[{"path":"/xlsx/sheet[name=\"Sheet1\"]","kind":"worksheet","state":"visible","used":"A1:D22"},{"path":"/xlsx/sheet[name=\"Sheet2\"]","kind":"worksheet","state":"visible","used":"A1:I11"}]}

  $ office.exe get "$TESTDIR/../../../../fixtures/excelize/test/Book1.xlsx" '/xlsx/sheet[1]/range[A19:B19]' --json | jq -c '{schema:.data.schema,path:.data.path,kind:.data.kind,refs:[.data.cells[].reference],raw:[.data.cells[].raw],formulas:[.data.cells[]|(.formula // null)],returned:.data.returned}'
  {"schema":"office.xlsx.element/1","path":"/xlsx/sheet[name=\"Sheet1\"]/range[A19:B19]","kind":"range","refs":["A19","B19"],"raw":[{"type":"string","value":"Total:"},{"type":"number","value":237}],"formulas":[null,"SUM(Sheet2!D2,Sheet2!D11)"],"returned":2}

  $ office.exe text "$TESTDIR/../../../../fixtures/excelize/test/Book1.xlsx" --under '/xlsx/sheet[name="Sheet1"]' --offset 1 --limit 2 --json | jq -c '{schema:.data.schema,under:.data.under,paths:[.data.entries[].path],texts:[.data.entries[].text],matched_total:.data.matched_total,returned:.data.returned,truncated:.data.truncated,scanned:.data.scanned_cells}'
  {"schema":"office.xlsx.text/1","under":"/xlsx/sheet[name=\"Sheet1\"]","paths":["/xlsx/sheet[name=\"Sheet1\"]/cell[B19]","/xlsx/sheet[name=\"Sheet1\"]/cell[C21]"],"texts":["237","Column1"],"matched_total":5,"returned":2,"truncated":true,"scanned":88}

  $ office.exe query "$TESTDIR/../../../../fixtures/excelize/test/Book1.xlsx" 'cell[type=formula][formula~=IF]' --under '/xlsx/sheet[name="Sheet2"]' --json | jq -c '{schema:.data.schema,selector:.data.selector,under:.data.under,paths:[.data.matches[].path],matched_total:.data.matched_total,returned:.data.returned,truncated:.data.truncated,scanned:.data.scanned_cells}'
  {"schema":"office.xlsx.query/1","selector":"cell[type=formula][formula~=IF]","under":"/xlsx/sheet[name=\"Sheet2\"]","paths":["/xlsx/sheet[name=\"Sheet2\"]/cell[F11]","/xlsx/sheet[name=\"Sheet2\"]/cell[G11]"],"matched_total":2,"returned":2,"truncated":false,"scanned":99}

Cross-format selectors and DOCX-only XLSX query flags fail with XLSX-specific,
machine-correctable codes.

  $ office.exe get "$TESTDIR/../../../../fixtures/excelize/test/Book1.xlsx" '/docx/body' --json > xlsx-selector-mismatch.json 2>&1; echo $?
  1
  $ jq -c '{success,code:.error.code,expected:.error.details.expected_format,actual:.error.details.actual_format}' xlsx-selector-mismatch.json
  {"success":false,"code":"office.xlsx.selector_format_mismatch","expected":"xlsx","actual":"docx"}

  $ office.exe query "$TESTDIR/../../../../fixtures/excelize/test/Book1.xlsx" --kind cell --json > xlsx-query-options.json 2>&1; echo $?
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
  office: invalid Office package: archive is not a readable ZIP
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
