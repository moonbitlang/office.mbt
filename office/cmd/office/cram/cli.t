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
    Fingerprint: crc32:3db4baed
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
  {"schema":"office.output/1","success":true,"capability_schema":"office.capabilities/1","fingerprint":"crc32:3db4baed","names":["docx","xlsx","help","identify"]}

  $ office.exe help all --jsonl | jq -s -c 'map({schema,fingerprint,kind,name})'
  [{"schema":"office.capability/1","fingerprint":"crc32:3db4baed","kind":"format","name":"docx"},{"schema":"office.capability/1","fingerprint":"crc32:3db4baed","kind":"format","name":"xlsx"},{"schema":"office.capability/1","fingerprint":"crc32:3db4baed","kind":"command","name":"help"},{"schema":"office.capability/1","fingerprint":"crc32:3db4baed","kind":"command","name":"identify"}]

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
