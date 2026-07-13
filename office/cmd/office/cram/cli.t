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
    Schema: office.capabilities/1
    Fingerprint: crc32:aa4ea0be
  Formats:
    docx (aliases: word) — WordprocessingML documents
    xlsx (aliases: excel) — SpreadsheetML workbooks
  Commands:
    help — Show the implemented Office capability registry

  $ office.exe help word | sed -n '1,7p'
  Format: docx (aliases: word)
    WordprocessingML documents
    Selector: office.selector/1 /docx (syntax-only)
      bounded parse/render only; package resolution is not implemented
      /docx/body/p[1]/r[2]
      /docx/comments/comment[id="7"]
    Implemented commands:

  $ office.exe help docx --json | jq -c '.data.records[0] | {kind,name,selector}'
  {"kind":"format","name":"docx","selector":{"schema":"office.selector/1","root":"/docx","status":"syntax-only","examples":["/docx/body/p[1]/r[2]","/docx/comments/comment[id=\"7\"]"],"description":"bounded parse/render only; package resolution is not implemented"}}

  $ office.exe help all --json | jq -c '{schema,success,capability_schema:.data.schema,fingerprint:.data.fingerprint,names:[.data.records[].name]}'
  {"schema":"office.output/1","success":true,"capability_schema":"office.capabilities/1","fingerprint":"crc32:aa4ea0be","names":["docx","xlsx","help","identify","raw"]}

  $ office.exe help all --jsonl | jq -s -c 'map({schema,fingerprint,kind,name})'
  [{"schema":"office.capability/1","fingerprint":"crc32:aa4ea0be","kind":"format","name":"docx"},{"schema":"office.capability/1","fingerprint":"crc32:aa4ea0be","kind":"format","name":"xlsx"},{"schema":"office.capability/1","fingerprint":"crc32:aa4ea0be","kind":"command","name":"help"},{"schema":"office.capability/1","fingerprint":"crc32:aa4ea0be","kind":"command","name":"identify"},{"schema":"office.capability/1","fingerprint":"crc32:aa4ea0be","kind":"command","name":"raw"}]

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
  $ unzip -p edited.docx word/document.xml | rg -o 'w:rsidR="[^"]+"' | head -1
  w:rsidR="DEADBEEF"
  $ cmp before.docx input.docx; echo $?
  0

Whole-part replacement accepts bounded UTF-8 file input. Invalid selector
syntax retains the raw subsystem's stable error code through the transaction.

  $ office.exe raw read input.docx /document > original.xml
  $ sed 's/Walking on imported air/CLI replace/' original.xml > replacement.xml
  $ office.exe raw replace input.docx /document --xml-file replacement.xml --out replaced.docx --json | jq -c '{success,action:.data.change.action,part:.data.change.part,changed:.data.transaction.preservation.changed}'
  {"success":true,"action":"replace-part","part":"/word/document.xml","changed":["word/document.xml"]}
  $ unzip -p replaced.docx word/document.xml | rg -o 'CLI replace'
  CLI replace

  $ office.exe raw edit input.docx /document --path '//w:p' --action remove --dry-run --json > invalid-path.json 2>&1; echo $?
  1
  $ jq -c '{success,code:.error.code}' invalid-path.json
  {"success":false,"code":"office.raw.invalid_path"}
