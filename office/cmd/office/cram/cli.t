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
    Fingerprint: crc32:ba12aaf6
  Formats:
    docx (aliases: word) — WordprocessingML documents
    xlsx (aliases: excel) — SpreadsheetML workbooks
  Commands:
    help — Show implemented capabilities or consumed input contracts

  $ office.exe help word | sed -n '1,8p'
  Format: docx (aliases: word)
    WordprocessingML documents
    Selector: office.selector/1 /docx (read-resolved)
      bounded canonical resolution for outline, get, text, and declared query predicates
      /docx/body/p[1]/r[2]
      /docx/body/p[id="1A2B3C4D"]
      /docx/comments/comment[id="7"]
    Implemented commands:

  $ office.exe help docx --json | jq -c '.data.records[0] | {kind,name,selector}'
  {"kind":"format","name":"docx","selector":{"schema":"office.selector/1","root":"/docx","status":"read-resolved","examples":["/docx/body/p[1]/r[2]","/docx/body/p[id=\"1A2B3C4D\"]","/docx/comments/comment[id=\"7\"]"],"description":"bounded canonical resolution for outline, get, text, and declared query predicates"}}

  $ office.exe help xlsx query --json | jq -c '.data.records[0] | {formats,variants:[.variants[]|{name,result_schema,constraints}]}'
  {"formats":["xlsx"],"variants":[{"name":"xlsx","result_schema":"office.xlsx.query/1","constraints":["format=xlsx"]}]}

  $ office.exe help all --json | jq -c '{schema,success,capability_schema:.data.schema,fingerprint:.data.fingerprint,names:[.data.records[].name]}'
  {"schema":"office.output/1","success":true,"capability_schema":"office.capabilities/2","fingerprint":"crc32:ba12aaf6","names":["docx","xlsx","help","identify","outline","get","text","query","find","replace","format","insert-paragraph","delete-paragraph","validate","dump","replay","issues","preview","render","create","template","edit","annotate","batch","raw"]}

  $ office.exe help all --jsonl | jq -s -c 'map({schema,fingerprint,kind,name})'
  [{"schema":"office.capability/2","fingerprint":"crc32:ba12aaf6","kind":"format","name":"docx"},{"schema":"office.capability/2","fingerprint":"crc32:ba12aaf6","kind":"format","name":"xlsx"},{"schema":"office.capability/2","fingerprint":"crc32:ba12aaf6","kind":"command","name":"help"},{"schema":"office.capability/2","fingerprint":"crc32:ba12aaf6","kind":"command","name":"identify"},{"schema":"office.capability/2","fingerprint":"crc32:ba12aaf6","kind":"command","name":"outline"},{"schema":"office.capability/2","fingerprint":"crc32:ba12aaf6","kind":"command","name":"get"},{"schema":"office.capability/2","fingerprint":"crc32:ba12aaf6","kind":"command","name":"text"},{"schema":"office.capability/2","fingerprint":"crc32:ba12aaf6","kind":"command","name":"query"},{"schema":"office.capability/2","fingerprint":"crc32:ba12aaf6","kind":"command","name":"find"},{"schema":"office.capability/2","fingerprint":"crc32:ba12aaf6","kind":"command","name":"replace"},{"schema":"office.capability/2","fingerprint":"crc32:ba12aaf6","kind":"command","name":"format"},{"schema":"office.capability/2","fingerprint":"crc32:ba12aaf6","kind":"command","name":"insert-paragraph"},{"schema":"office.capability/2","fingerprint":"crc32:ba12aaf6","kind":"command","name":"delete-paragraph"},{"schema":"office.capability/2","fingerprint":"crc32:ba12aaf6","kind":"command","name":"validate"},{"schema":"office.capability/2","fingerprint":"crc32:ba12aaf6","kind":"command","name":"dump"},{"schema":"office.capability/2","fingerprint":"crc32:ba12aaf6","kind":"command","name":"replay"},{"schema":"office.capability/2","fingerprint":"crc32:ba12aaf6","kind":"command","name":"issues"},{"schema":"office.capability/2","fingerprint":"crc32:ba12aaf6","kind":"command","name":"preview"},{"schema":"office.capability/2","fingerprint":"crc32:ba12aaf6","kind":"command","name":"render"},{"schema":"office.capability/2","fingerprint":"crc32:ba12aaf6","kind":"command","name":"create"},{"schema":"office.capability/2","fingerprint":"crc32:ba12aaf6","kind":"command","name":"template"},{"schema":"office.capability/2","fingerprint":"crc32:ba12aaf6","kind":"command","name":"edit"},{"schema":"office.capability/2","fingerprint":"crc32:ba12aaf6","kind":"command","name":"annotate"},{"schema":"office.capability/2","fingerprint":"crc32:ba12aaf6","kind":"command","name":"batch"},{"schema":"office.capability/2","fingerprint":"crc32:ba12aaf6","kind":"command","name":"raw"}]

Installed help exposes every consumed JSON input contract without requiring
repository-only documentation. Inventory and individual records are versioned;
an unknown ID fails nonzero with a bounded typed suggestion.

  $ office.exe help schemas
  Consumed input contracts
    Schema: office.input-contracts/1
    xlsx.batch/2 — Strict transactional spreadsheet mutation script
    docx.batch/2 — Strict fresh-DOCX authoring script with comments, notes, header/footer stories, and page fields
    office.template.data/1 — Strict non-executable scalar and repeating-region template data
    docx.edit/1 — Strict preservation-safe literal find & replace, or tracked-change accept/reject, script for an existing DOCX
    docx.edit/2 — Everything docx.edit/1 accepts plus the addressed set_run_text whole-run replacement
    docx.annotation-batch/1 — Strict preservation-safe comment mutation script for an existing DOCX
    docx.paragraph/1 — Resource-free paragraph content for office insert-paragraph
  Use 'office help schema <id> --json' for the exact contract.

  $ office.exe help schemas --json | jq -c '{schema,success,data:{schema:.data.schema,ids:[.data.contracts[].id],fingerprints_valid:all(.data.contracts[];.fingerprint|test("^sha256:[0-9a-f]{64}$"))}}'
  {"schema":"office.output/1","success":true,"data":{"schema":"office.input-contracts/1","ids":["xlsx.batch/2","docx.batch/2","office.template.data/1","docx.edit/1","docx.edit/2","docx.annotation-batch/1","docx.paragraph/1"],"fingerprints_valid":true}}

  $ office.exe help schemas --jsonl | jq -c '{schema,contracts:[.contracts[].id]}'
  {"schema":"office.input-contracts/1","contracts":["xlsx.batch/2","docx.batch/2","office.template.data/1","docx.edit/1","docx.edit/2","docx.annotation-batch/1","docx.paragraph/1"]}

  $ office.exe help schema docx.batch/2 | jq -c '{schema,id,definitions:(.definitions|length)}'
  {"schema":"office.input-contract/1","id":"docx.batch/2","definitions":15}

  $ office.exe help schema docx.batch/2 --json | jq -c '{schema,success,data:{schema:.data.schema,id:.data.id}}'
  {"schema":"office.output/1","success":true,"data":{"schema":"office.input-contract/1","id":"docx.batch/2"}}

  $ office.exe help schema docx.batch/2 --jsonl | jq -c '{schema,id,example_schema:.examples[0].schema,ops:[.operations[].op],limits:{max_ops:.limits.max_ops,max_table_columns:.limits.max_table_columns}}'
  {"schema":"office.input-contract/1","id":"docx.batch/2","example_schema":"docx.batch/2","ops":["paragraph","table","comment","header","footer"],"limits":{"max_ops":10000,"max_table_columns":63}}

  $ office.exe help schema docx.batc/2 --json > unknown-schema.json; echo $?
  1

  $ jq -c '{schema,success,code:.error.code,suggestions:.error.details.suggestions}' unknown-schema.json
  {"schema":"office.output/1","success":false,"code":"office.unknown_schema","suggestions":["docx.batch/2"]}

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
  {"name":"create","formats":["xlsx","docx"],"variants":[{"name":"xlsx","result_schema":"office.xlsx.create/1","inputs":["output","sheet","dry-run","overwrite","json"],"constraints":["format=xlsx","output-extension=.xlsx","create-new-by-default","transactional-publication","bounded-candidate-package","candidate-max-entry-bytes=12582912","candidate-max-uncompressed-bytes=25165824"]},{"name":"docx","result_schema":"office.docx.create/1","inputs":["output","dry-run","overwrite","json"],"constraints":["format=docx","output-extension=.docx","create-new-by-default","transactional-publication","bounded-candidate-package","blank-document-only"]}]}

  $ office.exe help batch --json | jq -c '.data.records[0] | {name,formats,variants:[.variants[]|{name,result_schema,outputs:[.outputs[].name],constraints}]}'
  {"name":"batch","formats":["xlsx","docx"],"variants":[{"name":"xlsx","result_schema":"office.xlsx.batch/1","outputs":["stats","transaction"],"constraints":["format=xlsx","preferred-schema=xlsx.batch/2","accepted-schemas=xlsx.batch/1|xlsx.batch/2","overwrite-requires(out)","out-extension-must-match-input-format","transactional-publication","full-workbook-rewrite-on-change","zero-op-reuses-original","transaction-max-materialized-cells=32768","transaction-max-row-column-lines=32768","read-max-decoded-xml-bytes=16777216","read-max-markup-tokens=262144","read-max-materialized-row-column-dimensions=32768","read-max-row-column-dimension-work=32768","candidate-max-entry-bytes=12582912","candidate-max-uncompressed-bytes=25165824"]},{"name":"docx","result_schema":"office.docx.batch/1","outputs":["ops","comments","footnotes","endnotes","headers","footers","transaction"],"constraints":["format=docx","preferred-schema=docx.batch/2","accepts-schema=docx.batch/1","output-extension=.docx","fresh-authoring-only","create-new-by-default","out-not-accepted","transactional-publication","bounded-candidate-package","comments-and-notes-require=docx.batch/2","headers-footers-require=docx.batch/2","header-footer-variants=default|first|even","header-footer-content=plain-blocks-and-fields","fields=PAGE|NUMPAGES","max-image-bytes=8388608","max-total-image-bytes=33554432"]}]}

  $ office.exe help batch --json | jq -c '.data.records[0].variants[] | select(.name=="xlsx") | .registry | {schema,preferred_schema,accepted_schemas,ops:(.ops|length)}'
  {"schema":"xlsx.capabilities/2","preferred_schema":"xlsx.batch/2","accepted_schemas":["xlsx.batch/1","xlsx.batch/2"],"ops":15}

  $ office.exe create xlsx x3-created.xlsx --sheet Data --json | jq -c '{success,schema:.data.schema,sheet:.data.sheet,transaction_schema:.data.transaction.schema,mode:.data.transaction.mode,input:.data.transaction.input,original_size:.data.transaction.original_size,replaced_existing:.data.transaction.replaced_existing,overwritten_size:.data.transaction.overwritten_size,committed:.data.transaction.committed,validations:[.data.transaction.validations[].name],added:(.data.transaction.preservation.added|length>0)}'
  {"success":true,"schema":"office.xlsx.create/1","sheet":"Data","transaction_schema":"office.transaction/2","mode":"create","input":null,"original_size":null,"replaced_existing":false,"overwritten_size":null,"committed":true,"validations":["office-xlsx-bounded-source","office-portable-opc","office-xlsx-bounded"],"added":true}

  $ office.exe identify x3-created.xlsx
  xlsx

  $ printf '%s\n' '{"schema":"xlsx.batch/2","ops":[{"op":"set","params":{"sheet":"Data","cell":"A1","value":"one"}},{"op":"formula","params":{"sheet":"Data","cell":"B1","formula":"=LEN(A1)"}},{"op":"style","params":{"sheet":"Data","range":"A1:B1","bold":true}}]}' > x3-batch.json
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

Fresh DOCX creation (blank) and fresh authoring (a docx.batch/2 script) publish
through the same validated create transaction. DOCX is fresh-only — there is no
existing-document mutation — so authoring is selected with `--format docx` and
refuses `--out` and an existing destination without `--overwrite`. Capability
help filters both create and batch to the requested format.

  $ office.exe help docx create --json | jq -c '.data.records[0]|{name,formats,variants:[.variants[].name]}'
  {"name":"create","formats":["docx"],"variants":["docx"]}
  $ office.exe help xlsx create --json | jq -c '.data.records[0]|{name,formats,variants:[.variants[].name]}'
  {"name":"create","formats":["xlsx"],"variants":["xlsx"]}
  $ office.exe help xlsx batch --json | jq -c '.data.records[0]|{name,formats,variants:[.variants[].name]}'
  {"name":"batch","formats":["xlsx"],"variants":["xlsx"]}
  $ office.exe help docx batch --json | jq -c '.data.records[0]|{name,formats,variants:[.variants[].name]}'
  {"name":"batch","formats":["docx"],"variants":["docx"]}

  $ office.exe create docx d3-blank.docx --json | jq -c '{success,schema:.data.schema,format:.data.format,mode:.data.transaction.mode,committed:.data.transaction.committed}'
  {"success":true,"schema":"office.docx.create/1","format":"docx","mode":"create","committed":true}
  $ office.exe identify d3-blank.docx
  docx

  $ printf '%s\n' '{"schema":"docx.batch/2","ops":[{"op":"paragraph","params":{"text":"Report","style":"Heading1"}},{"op":"paragraph","params":{"runs":[{"text":"body ","bold":true},{"text":"text"}]}},{"op":"comment","params":{"on":0,"text":"revise","author":"Ada"}}]}' > d3-author.json
  $ office.exe batch --format docx d3-authored.docx d3-author.json --json | jq -c '{success,schema:.data.schema,format:.data.format,ops:.data.ops,comments:.data.comments,committed:.data.transaction.committed}'
  {"success":true,"schema":"office.docx.batch/1","format":"docx","ops":3,"comments":1,"committed":true}
  $ office.exe text d3-authored.docx --json | jq -rc '.data.entries[] | .path + "\t" + .text'
  /docx/body/p[1]	Report
  /docx/body/p[2]	body text
  /docx/comments/comment[id="0"]/p[1]	revise

Header and footer ops author the section's variants (#95): each becomes its own
part, wired through sectPr references, and reads back at its own story path. A
footer page number is a LIVE field (w:fldChar begin/instrText/separate/end),
never static text, so Word repaginates it.

  $ printf '%s\n' '{"schema":"docx.batch/2","ops":[{"op":"paragraph","params":{"text":"Report","style":"Heading1"}},{"op":"header","params":{"text":"Quarterly findings"}},{"op":"footer","params":{"paragraphs":[{"align":"center","runs":[{"text":"Page "},{"field":{"type":"PAGE"}},{"text":" of "},{"field":{"type":"NUMPAGES"}}]}]}}]}' > d3-story.json
  $ office.exe batch --format docx d3-story.docx d3-story.json --json | jq -c '{success,ops:.data.ops,headers:.data.headers,footers:.data.footers,committed:.data.transaction.committed}'
  {"success":true,"ops":3,"headers":1,"footers":1,"committed":true}
  $ office.exe validate d3-story.docx --json | jq -c '{valid:.data.valid,errors:.data.error_count}'
  {"valid":true,"errors":0}
  $ office.exe outline d3-story.docx --json | jq -c '{headers:.data.counts.headers,footers:.data.counts.footers,stories:[.data.stories[].path],sections:.data.sections}'
  {"headers":1,"footers":1,"stories":["/docx/body","/docx/header[1]","/docx/footer[1]","/docx/footnotes","/docx/endnotes","/docx/comments"],"sections":[{"headers":[{"variant":"default","part":1}],"footers":[{"variant":"default","part":1}]}]}
  $ office.exe text d3-story.docx --json | jq -rc '.data.entries[] | .path + "\t" + .text'
  /docx/body/p[1]	Report
  /docx/header[1]/p[1]	Quarterly findings
  /docx/footer[1]/p[1]	Page 1 of 1
  $ office.exe get d3-story.docx '/docx/header[1]/p[1]'
  Quarterly findings
  $ office.exe raw read d3-story.docx /word/footer1.xml | grep -o 'w:fldChar w:fldCharType="[a-z]*"' | sort | uniq -c | tr -s ' ' | sed 's/^ //'
  2 w:fldChar w:fldCharType="begin"
  2 w:fldChar w:fldCharType="end"
  2 w:fldChar w:fldCharType="separate"
  $ office.exe raw read d3-story.docx /word/footer1.xml | grep -c 'w:instrText xml:space="preserve"> PAGE <'
  1

`find` lists every literal candidate with the coordinates a partial edit
consumes, and says whether an edit there is allowed. Offsets are
paragraph-relative UTF-16 over the reader PROJECTION, so a needle spanning
run boundaries still matches — the literal need not exist contiguously in
the XML.

  $ office.exe find "$TESTDIR/../../../../docx2html/tests/cram/fixtures/single-paragraph.docx" --text "on imported"
  1. p[1] [8,19) on imported
  $ office.exe find "$TESTDIR/../../../../docx2html/tests/cram/fixtures/single-paragraph.docx" --text "on imported" --json | jq -c '{schema:.data.schema,total:.data.matches_total,actionable:.data.actionable_returned,unactionable:.data.unactionable_returned}'
  {"schema":"office.docx.matches/1","total":1,"actionable":1,"unactionable":0}
  $ office.exe find "$TESTDIR/../../../../docx2html/tests/cram/fixtures/single-paragraph.docx" --text "on imported" --json | jq -c '.data.matches[0] | {path,range,runs,source_kinds,actionable,reason,para_id,paragraph_anchor_status,physical_para_ids}'
  {"path":"p[1]","range":{"start":8,"end":19,"unit":"utf16"},"runs":["p[1]/r[1]"],"source_kinds":["text"],"actionable":true,"reason":null,"para_id":null,"paragraph_anchor_status":"missing","physical_para_ids":null}

Finding nothing is a fact about the document, not a failed request: a read
exits 0 with an empty list. Only a mutation fails closed on no match.

  $ office.exe find "$TESTDIR/../../../../docx2html/tests/cram/fixtures/single-paragraph.docx" --text "absent"
  no candidates for 'absent'
  $ office.exe find "$TESTDIR/../../../../docx2html/tests/cram/fixtures/single-paragraph.docx" --text "absent" --json | jq -c '{total:.data.matches_total,matches:.data.matches}'
  {"total":0,"matches":[]}

v1 searches the body only, which `stories_scanned` states rather than
implying. d3-story.docx carries a live PAGE field in its FOOTER; find does
not report it, and says which stories it looked at.

  $ office.exe find d3-story.docx --text "Report" --json | jq -c '{stories:.data.stories_scanned,total:.data.matches_total}'
  {"stories":["/body"],"total":1}

`replace` is the mutation `find` previews: same candidates, same
ordinals, same verdicts. It publishes atomically to a NEW file, re-reads
every affected paragraph before publication, and writes nothing on any
refusal.

  $ office.exe replace "$TESTDIR/../../../../docx2html/tests/cram/fixtures/single-paragraph.docx" fr-out.docx --text "imported" --with "borrowed" --expect 1
  replace: replaced 1 occurrence(s) across 1 paragraph(s) -> fr-out.docx
  $ office.exe text fr-out.docx
  /docx/body/p[1]	Walking on borrowed air
  $ office.exe replace "$TESTDIR/../../../../docx2html/tests/cram/fixtures/single-paragraph.docx" fr-json.docx --text "imported" --with "borrowed" --expect 1 --json | jq -c '{schema:.data.schema,replaced:.data.replaced,selected:.data.selected,affected:.data.affected,affected_paragraphs:.data.affected_paragraphs,changed:.data.changed}'
  {"schema":"office.docx.replace/1","replaced":1,"selected":[1],"affected":["p[1]"],"affected_paragraphs":[{"path":"p[1]","para_id":null,"paragraph_anchor_status":"missing"}],"changed":true}

`--dry-run` runs the identical selection and preflight pipeline, exits as
the real run would, and writes nothing.

  $ office.exe replace "$TESTDIR/../../../../docx2html/tests/cram/fixtures/single-paragraph.docx" fr-dry.docx --text "imported" --with "borrowed" --dry-run --json | jq -c '{replaced:.data.replaced,dry_run:.data.dry_run}'
  {"replaced":1,"dry_run":true}
  $ test -f fr-dry.docx || echo "nothing written"
  nothing written

Zero matches without `--allow-zero` refuses, exits 1, and writes nothing;
`--expect` with `--allow-zero` is rejected as contradictory before any
file is read.

  $ office.exe replace "$TESTDIR/../../../../docx2html/tests/cram/fixtures/single-paragraph.docx" fr-zero.docx --text "absent" --with "x" --json 2>&1 | jq -c '{success,code:.error.code}'
  {"success":false,"code":"office.replace.no_match"}
  $ office.exe replace "$TESTDIR/../../../../docx2html/tests/cram/fixtures/single-paragraph.docx" fr-zero.docx --text "absent" --with "x" 2>/dev/null
  office: no candidate matched the needle; pass allow-zero to treat that as success, or expect 0 to assert it
  [1]
  $ test -f fr-zero.docx || echo "nothing written"
  nothing written
  $ office.exe replace "$TESTDIR/../../../../docx2html/tests/cram/fixtures/single-paragraph.docx" fr-contra.docx --text "imported" --with "x" --expect 1 --allow-zero --json 2>&1 | jq -c '{success,code:.error.code}'
  {"success":false,"code":"office.invalid_arguments"}

A control character in either flag is a request error: a tab in `--text`
would match a structural tab ATOM, and replacing that atom is exactly the
structural mutation v1 forbids from text.

  $ office.exe replace "$TESTDIR/../../../../docx2html/tests/cram/fixtures/single-paragraph.docx" fr-ctl.docx --text "a	b" --with "x"
  office: --text must not contain control characters (found U+9); v1 neither matches nor makes structural breaks and tabs from text — use `office find` to locate atom content
  [1]

Paragraph identity rides every read surface (paraId R1b): text, get,
query, and outline headings report the SAME judgment find does — one
judge, joined to the tree only across a proven correspondence. The
duplicate fixture carries the same id twice (differing by case) plus a
unique heading; both duplicate carriers say so, and neither becomes an
addressable anchor.

  $ office.exe text "$TESTDIR/../../../../docx2html/tests/cram/fixtures/duplicate-para-id.docx" --json | jq -c '[.data.entries[] | {path,para_id,paragraph_anchor_status}]'
  [{"path":"/docx/body/p[1]","para_id":"1A2B3C4D","paragraph_anchor_status":"duplicate"},{"path":"/docx/body/p[2]","para_id":"1A2B3C4D","paragraph_anchor_status":"duplicate"},{"path":"/docx/body/p[3]","para_id":"5E5E5E5E","paragraph_anchor_status":"unique"}]

  $ office.exe get "$TESTDIR/../../../../docx2html/tests/cram/fixtures/duplicate-para-id.docx" "/docx/body/p[1]" --json | jq -c '{path:.data.path,para_id:.data.para_id,status:.data.paragraph_anchor_status}'
  {"path":"/docx/body/p[1]","para_id":"1A2B3C4D","status":"duplicate"}

  $ office.exe query "$TESTDIR/../../../../docx2html/tests/cram/fixtures/duplicate-para-id.docx" --kind p --json | jq -c '[.data.matches[] | {path,para_id,paragraph_anchor_status}]'
  [{"path":"/docx/body/p[1]","para_id":"1A2B3C4D","paragraph_anchor_status":"duplicate"},{"path":"/docx/body/p[2]","para_id":"1A2B3C4D","paragraph_anchor_status":"duplicate"},{"path":"/docx/body/p[3]","para_id":"5E5E5E5E","paragraph_anchor_status":"unique"}]

  $ office.exe outline "$TESTDIR/../../../../docx2html/tests/cram/fixtures/duplicate-para-id.docx" --json | jq -c '.data.headings'
  [{"path":"/docx/body/p[3]","level":1,"text":"Gamma heading","text_truncated":false,"para_id":"5E5E5E5E","paragraph_anchor_status":"unique","physical_para_ids":null}]

Stable addressing (paraId R2a): a soundly-joined unique id IS an
address — `get` resolves it (suffix segments stay positional),
`query --id` finds it, `find --in` scopes by it, and every contested
identity refuses typed: an ambiguous id lists its claimants and never
resolves to the first one.

  $ office.exe get "$TESTDIR/../../../../docx2html/tests/cram/fixtures/duplicate-para-id.docx" "/docx/body/p[id=\"5E5E5E5E\"]" --json | jq -c '{path:.data.path,id:.data.id}'
  {"path":"/docx/body/p[3]","id":"5E5E5E5E"}

  $ office.exe get "$TESTDIR/../../../../docx2html/tests/cram/fixtures/duplicate-para-id.docx" "/docx/body/p[id=\"5E5E5E5E\"]/r[1]" --json | jq -c '{path:.data.path,kind:.data.kind}'
  {"path":"/docx/body/p[3]/r[1]","kind":"r"}

  $ office.exe get "$TESTDIR/../../../../docx2html/tests/cram/fixtures/duplicate-para-id.docx" "/docx/body/p[id=\"1A2B3C4D\"]" --json 2>&1 | jq -c '{code:.error.code,candidates:.error.details.candidates}'
  {"code":"office.docx.para_id_ambiguous","candidates":["/docx/body/p[1]","/docx/body/p[2]"]}

  $ office.exe get "$TESTDIR/../../../../docx2html/tests/cram/fixtures/duplicate-para-id.docx" "/docx/body/p[id=\"33333333\"]" --json > /dev/null
  [1]

  $ office.exe query "$TESTDIR/../../../../docx2html/tests/cram/fixtures/duplicate-para-id.docx" --id 5E5E5E5E --json | jq -c '[.data.matches[] | {path,kind}]'
  [{"path":"/docx/body/p[3]","kind":"p"}]

  $ office.exe find "$TESTDIR/../../../../docx2html/tests/cram/fixtures/duplicate-para-id.docx" --text a --in 'p[id="5E5E5E5E"]' --json | jq -c '[.data.matches[].path] | unique'
  ["p[3]"]

  $ office.exe find "$TESTDIR/../../../../docx2html/tests/cram/fixtures/duplicate-para-id.docx" --text a --in 'p[id="1A2B3C4D"]' --json 2>&1 | jq -c '.error.code'
  "office.docx.para_id_ambiguous"

The write verbs accept the same identity (paraId R2b): replace scoped
by a stable id reports both spellings, and an ambiguous id refuses the
transaction before anything is planned or written.

  $ office.exe replace "$TESTDIR/../../../../docx2html/tests/cram/fixtures/duplicate-para-id.docx" r2b-out.docx --text "heading" --with "title" --in 'p[id="5E5E5E5E"]' --json | jq -c '{replaced:.data.replaced,in:.data.in,resolved_in:.data.resolved_in,affected:.data.affected}'
  {"replaced":1,"in":"p[id=\"5E5E5E5E\"]","resolved_in":"p[3]","affected":["p[3]"]}

  $ office.exe replace "$TESTDIR/../../../../docx2html/tests/cram/fixtures/duplicate-para-id.docx" r2b-dup.docx --text "alpha" --with "x" --in 'p[id="1A2B3C4D"]' --json 2>&1 | jq -c '.error.code'
  "office.docx.para_id_ambiguous"

  $ test -f r2b-dup.docx
  [1]

The first structural verb (N3a + R3): insert-paragraph MINTS the new
paragraph's stable identity — fresh against the whole package, verified
by readback before publication — and the published document addresses
it immediately. Refusals (an undefined style here) publish nothing.

  $ office.exe insert-paragraph "$TESTDIR/../../../../docx2html/tests/cram/fixtures/duplicate-para-id.docx" ip-out.docx --after 'p[3]' --content '{"runs":[{"text":"fresh paragraph","bold":true}]}' --json | jq -c '{schema:.data.schema,path:.data.path,minted:(.data.para_id|test("^[0-9A-F]{8}$")),side:.data.side,changed:.data.changed}'
  {"schema":"office.docx.insert-paragraph/1","path":"p[4]","minted":true,"side":"after","changed":true}

  $ office.exe text ip-out.docx --json | jq -c '[.data.entries[] | {path,minted:(.para_id!=null and (.para_id|test("^[0-9A-F]{8}$"))),paragraph_anchor_status}] | last'
  {"path":"/docx/body/p[4]","minted":true,"paragraph_anchor_status":"unique"}

  $ office.exe insert-paragraph "$TESTDIR/../../../../docx2html/tests/cram/fixtures/duplicate-para-id.docx" ip-ref.docx --before 'p[1]' --content '{"style":"Ghost","runs":[{"text":"x"}]}' --json 2>&1 | jq -c '.error.code'
  "office.docx.invalid_plan"

  $ test -f ip-ref.docx
  [1]

Its structural inverse (N3b): delete-paragraph removes one direct body
paragraph, guarded by --expect-text and verified by identity readback —
the deleted identity is GONE and the successor answers at the path. The
inverse pair round-trips the document byte-identically. Human mode and
a CLI dry run behave; refusals publish nothing.

  $ office.exe insert-paragraph "$TESTDIR/../../../../docx2html/tests/cram/fixtures/duplicate-para-id.docx" dp-in.docx --before 'p[1]' --content '{"runs":[{"text":"ephemeral"}]}' --json | jq -c '.data.path'
  "p[1]"

  $ office.exe delete-paragraph dp-in.docx dp-dry.docx --at 'p[1]' --expect-text ephemeral --dry-run
  delete-paragraph: would delete p[1] ("ephemeral") -> dp-dry.docx

  $ test -f dp-dry.docx
  [1]

  $ office.exe delete-paragraph dp-in.docx dp-out.docx --at 'p[1]' --expect-text ephemeral
  delete-paragraph: deleted p[1] ("ephemeral") -> dp-out.docx
  warning [office.transaction.path_based_commit_semantics]: publication uses moonbitlang/async path APIs; atomic rename is guaranteed, but hostile concurrent directory-entry replacement is outside the portable contract

  $ unzip -p dp-out.docx word/document.xml > dp-out-doc.xml
  $ unzip -p "$TESTDIR/../../../../docx2html/tests/cram/fixtures/duplicate-para-id.docx" word/document.xml > dp-base-doc.xml
  $ cmp dp-base-doc.xml dp-out-doc.xml

  $ office.exe delete-paragraph dp-in.docx dp-ref.docx --at 'p[1]' --expect-text 'something else' --json 2>&1 | jq -c '.error.code'
  "office.delete.expect_text_mismatch"

  $ test -f dp-ref.docx
  [1]

  $ office.exe delete-paragraph dp-in.docx dp-ref2.docx --at 'tbl[1]' --json 2>&1 | jq -c '.error.code'
  "office.invalid_arguments"

  $ office.exe delete-paragraph dp-in.docx dp-ref3.docx --at 'p[1]' --at 'p[2]' --json 2>&1 | jq -c '.error.code'
  "office.invalid_arguments"

The cross-surface invariant, executable: find agrees with the tree
surfaces on the same document.

  $ office.exe find "$TESTDIR/../../../../docx2html/tests/cram/fixtures/duplicate-para-id.docx" --text alpha --json | jq -c '[.data.matches[] | {path,para_id,paragraph_anchor_status}]'
  [{"path":"p[1]","para_id":"1A2B3C4D","paragraph_anchor_status":"duplicate"}]

A tolerated nested paragraph partitions the tree differently than the
projection, so NO tree paragraph may borrow either projection
judgment: both occurrences refuse with `unjoined`, never a guessed
identity.

  $ office.exe text "$TESTDIR/../../../../docx2html/tests/cram/fixtures/nested-paragraph.docx" --json | jq -c '[.data.entries[] | {path,paragraph_anchor_status}]'
  [{"path":"/docx/body/p[1]","paragraph_anchor_status":"unjoined"},{"path":"/docx/body/p[1]/r[1]/p[1]","paragraph_anchor_status":"unjoined"}]

The payload carries the selected candidates in find's own entry shape
(bounded at 100 entries, `matches_truncated` marking the rest), so a
dry-run prints the matches payload rather than a summary; and
`changed` comes from the TRANSACTION, so replacing text with itself
selects a candidate while changing nothing.

  $ office.exe replace "$TESTDIR/../../../../docx2html/tests/cram/fixtures/single-paragraph.docx" fr-mp.docx --text "imported" --with "borrowed" --dry-run --json | jq -c '{first:(.data.matches[0] | {ordinal,path,range,text,actionable}),matches_truncated:.data.matches_truncated}'
  {"first":{"ordinal":1,"path":"p[1]","range":{"start":11,"end":19,"unit":"utf16"},"text":"imported","actionable":true},"matches_truncated":false}
  $ office.exe replace "$TESTDIR/../../../../docx2html/tests/cram/fixtures/single-paragraph.docx" fr-id.docx --text "imported" --with "imported" --json | jq -c '{replaced:.data.replaced,changed:.data.changed}'
  {"replaced":1,"changed":false}

A malformed request still refuses: the needle is required, and an empty one
would name every position.

  $ office.exe find "$TESTDIR/../../../../docx2html/tests/cram/fixtures/single-paragraph.docx" --text "" --json | jq -c '{success,code:.error.code}'
  {"success":false,"code":"office.invalid_arguments"}

The MUTATION reader is stricter than the tolerant projection: it re-resolves
every section story reference and fails closed. Annotating the authored
document therefore proves the references, relationships, and content types
agree, and the stories survive a byte-preserving mutation.

  $ printf '%s\n' '{"schema":"docx.annotation-batch/1","ops":[{"op":"comment_add","anchor":{"at":"/docx/body/p[1]"},"author":"Ada","body":["check"]}]}' > d3-story-annotate.json
  $ office.exe annotate d3-story.docx d3-story-annotate.json --out d3-story-annotated.docx --json | jq -c '{success,ops:.data.ops_applied}'
  {"success":true,"ops":1}
  $ office.exe outline d3-story-annotated.docx --json | jq -c '{headers:.data.counts.headers,footers:.data.counts.footers,comments:.data.counts.comments}'
  {"headers":1,"footers":1,"comments":1}
  $ office.exe validate d3-story-annotated.docx --json | jq -c '{valid:.data.valid}'
  {"valid":true}

Everything the op vocabulary cannot yet re-express is a VISIBLE residual, not
silent loss: dumping the authored document reports its stories.

  $ office.exe dump d3-story.docx --json | jq -c '{ops:[.ops[].op],residual:[.residual[].code]}'
  {"ops":["paragraph"],"residual":["docx.headers_not_dumped","docx.footers_not_dumped","docx.sections_not_dumped"]}

The `first` and `even` variants carry the OOXML flags that make them take
effect: titlePg in sectPr, and a settings part declaring evenAndOddHeaders.

  $ printf '%s\n' '{"schema":"docx.batch/2","ops":[{"op":"paragraph","params":{"text":"x"}},{"op":"header","params":{"variant":"first","text":"Cover"}},{"op":"header","params":{"variant":"even","text":"Even"}},{"op":"header","params":{"variant":"default","text":"Odd"}}]}' > d3-variants.json
  $ office.exe batch --format docx d3-variants.docx d3-variants.json --json | jq -c '{headers:.data.headers,footers:.data.footers}'
  {"headers":3,"footers":0}
  $ office.exe outline d3-variants.docx --json | jq -c '.data.sections[0].headers'
  [{"variant":"default","part":1},{"variant":"first","part":2},{"variant":"even","part":3}]
  $ office.exe raw list d3-variants.docx --json | jq -c '[.data.parts[].name] | map(select(startswith("/word/header") or . == "/word/settings.xml")) | sort'
  ["/word/header1.xml","/word/header2.xml","/word/header3.xml","/word/settings.xml"]
  $ office.exe raw read d3-variants.docx /word/document.xml | grep -c '<w:titlePg/>'
  1
  $ office.exe raw read d3-variants.docx /word/settings.xml | grep -c '<w:evenAndOddHeaders/>'
  1

Story ops are fail-closed: a repeated variant, a story hyperlink, and an
unknown field type are all refused at parse with the offending op's address,
and nothing is published.

  $ printf '%s\n' '{"schema":"docx.batch/2","ops":[{"op":"header","params":{"text":"a"}},{"op":"header","params":{"text":"b"}}]}' > d3-dup-variant.json
  $ office.exe batch --format docx d3-dupvar.docx d3-dup-variant.json --json > d3-dupvar.json 2>&1; echo $?
  1
  $ jq -rc '{success,code:.error.code,message:.error.message}' d3-dupvar.json
  {"success":false,"code":"office.docx.batch_parse","message":"invalid authoring script: ops[1].params.variant 'default' was already declared by ops[0]; a section declares each header variant at most once"}
  $ test ! -e d3-dupvar.docx; echo $?
  0
  $ printf '%s\n' '{"schema":"docx.batch/2","ops":[{"op":"footer","params":{"paragraphs":[{"runs":[{"link":{"href":"https://example.invalid/","text":"x"}}]}]}}]}' > d3-story-link.json
  $ office.exe batch --format docx d3-storylink.docx d3-story-link.json --json > d3-storylink.json 2>&1; echo $?
  1
  $ jq -rc '.error.message' d3-storylink.json
  invalid authoring script: ops[0].params.paragraphs[0].runs[0]: hyperlinks are not allowed in header/footer stories (plain content only)
  $ printf '%s\n' '{"schema":"docx.batch/2","ops":[{"op":"paragraph","params":{"runs":[{"field":{"type":"TOC"}}]}}]}' > d3-bad-field.json
  $ office.exe batch --format docx d3-badfield.docx d3-bad-field.json --json > d3-badfield.json 2>&1; echo $?
  1
  $ jq -rc '.error.message' d3-badfield.json
  invalid authoring script: ops[0].params.runs[0].field.type 'TOC' is unsupported (known fields: PAGE, NUMPAGES)
  $ printf '%s\n' '{"schema":"docx.batch/1","ops":[{"op":"header","params":{"text":"a"}}]}' > d3-story-v1.json
  $ office.exe batch --format docx d3-storyv1.docx d3-story-v1.json --json > d3-storyv1.json 2>&1; echo $?
  1
  $ jq -rc '.error.message' d3-storyv1.json
  invalid authoring script: ops[0].op 'header' needs "schema": "docx.batch/2" (this script declares docx.batch/1)

Authoring embeds referenced images (bounded per image and in aggregate); the
authored document reads back with the media in place.

  $ cp "$TESTDIR/../../../../fixtures/excelize/logo.png" d3-logo.png
  $ printf '%s\n' '{"schema":"docx.batch/2","ops":[{"op":"paragraph","params":{"runs":[{"image":{"path":"d3-logo.png","alt":"logo"}}]}}]}' > d3-image.json
  $ office.exe batch --format docx d3-image.docx d3-image.json --json | jq -c '{success,ops:.data.ops}'
  {"success":true,"ops":1}
  $ office.exe outline d3-image.docx --json | jq -c '{images:.data.counts.images}'
  {"images":1}
  $ office.exe query d3-image.docx --kind picture --json | jq -c '{pictures:(.data.matches|length)}'
  {"pictures":1}
  $ printf '%s\n' '{"schema":"docx.batch/2","ops":[{"op":"paragraph","params":{"runs":[{"image":{"path":"d3-missing.png"}}]}}]}' > d3-missing-image.json
  $ office.exe batch --format docx d3-miss.docx d3-missing-image.json --json > d3-miss.json 2>&1; echo $?
  1
  $ jq -c '{success,code:.error.code}' d3-miss.json
  {"success":false,"code":"office.docx.author_asset_read_failed"}
  $ test ! -e d3-miss.docx; echo $?
  0

DOCX authoring is fail-closed: --out is rejected, an unsupported style is
refused at parse, and neither publishes anything.

  $ office.exe batch --format docx d3-out.docx d3-author.json --out d3-elsewhere.docx --json > d3-out.json 2>&1; echo $?
  1
  $ jq -c '{success,code:.error.code}' d3-out.json
  {"success":false,"code":"office.invalid_arguments"}
  $ test ! -e d3-out.docx; echo $?
  0
  $ printf '%s\n' '{"schema":"docx.batch/2","ops":[{"op":"paragraph","params":{"text":"x","style":"Title"}}]}' > d3-bad-style.json
  $ office.exe batch --format docx d3-bad.docx d3-bad-style.json --json > d3-bad.json 2>&1; echo $?
  1
  $ jq -c '{success,code:.error.code}' d3-bad.json
  {"success":false,"code":"office.docx.batch_parse"}
  $ test ! -e d3-bad.docx; echo $?
  0
  $ printf '%s\n' '{"schema":"docx.batch/2","schema":"x","ops":[]}' > d3-dup.json
  $ office.exe batch --format docx d3-dup.docx d3-dup.json --json > d3-dup-result.json 2>&1; echo $?
  1
  $ jq -c '{success,code:.error.code}' d3-dup-result.json
  {"success":false,"code":"office.docx.batch_parse"}
  $ test ! -e d3-dup.docx; echo $?
  0

  $ office.exe batch --format docx d3-authored.docx d3-author.json --json > d3-exists.json 2>&1; echo $?
  1
  $ jq -c '{success,code:.error.code}' d3-exists.json
  {"success":false,"code":"office.transaction.output_exists"}

  $ office.exe batch --format docx d3-dry.docx d3-author.json --dry-run --json | jq -c '{dry_run:.data.transaction.dry_run,committed:.data.transaction.committed}'
  {"dry_run":true,"committed":false}
  $ test ! -e d3-dry.docx; echo $?
  0

Structured DOCX reads share one bounded projection. Outline provides the map,
get resolves a canonical path, text emits path-tagged paragraphs, and query
uses deterministic document order and declared predicates.

  $ office.exe outline "$TESTDIR/../../../../docx2html/tests/cram/fixtures/single-paragraph.docx" --json | jq -c '{success,schema:.data.schema,counts:.data.counts,stories:[.data.stories[].path]}'
  {"success":true,"schema":"office.docx.outline/1","counts":{"body_stories":1,"headers":0,"footers":0,"footnotes":0,"endnotes":0,"comments":0,"insertions":0,"deletions":0,"paragraphs":1,"runs":1,"tables":0,"rows":0,"cells":0,"hyperlinks":0,"images":0},"stories":["/docx/body","/docx/footnotes","/docx/endnotes","/docx/comments"]}

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

Tracked changes have no representation in the document model: the reader
flattens w:ins into the accepted text and drops w:del, so author and date are
lost. Outline reports them, and text keeps returning the accepted view — a
review agent must be able to tell "up 18%" is an unaccepted edit that replaced
"flat", not settled fact.

  $ cp "$TESTDIR/../../../../docx2html/tests/cram/fixtures/single-paragraph.docx" tracked.docx
  $ office.exe raw edit tracked.docx /document --path '/w:document/w:body/w:p[1]' --action replace --xml '<w:p xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:r><w:t xml:space="preserve">The revenue was </w:t></w:r><w:del w:id="1" w:author="Reviewer" w:date="2026-01-01T00:00:00Z"><w:r><w:delText xml:space="preserve">flat</w:delText></w:r></w:del><w:ins w:id="2" w:author="Reviewer"><w:r><w:t xml:space="preserve">up 18%</w:t></w:r></w:ins><w:r><w:t xml:space="preserve"> this quarter.</w:t></w:r></w:p>' --json | jq -c '{success,matches:.data.change.match_count}'
  {"success":true,"matches":1}
  $ office.exe outline tracked.docx --json | jq -c '{insertions:.data.counts.insertions,deletions:.data.counts.deletions,revisions:.data.revisions}'
  {"insertions":1,"deletions":1,"revisions":[{"type":"del","path":"/docx/body/p[1]","id":"1","author":"Reviewer","date":"2026-01-01T00:00:00Z"},{"type":"ins","path":"/docx/body/p[1]","id":"2","author":"Reviewer"}]}
  $ office.exe text tracked.docx --json | jq -r '.data.entries[0].text'
  The revenue was up 18% this quarter.

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

The render command lays a DOCX out and draws it as paginated PDF or SVG.
Unlike preview, which produces reflowable HTML, this answers questions about
pages: the report leads with the page counts. The output extension picks the
backend, publication goes through the same atomic create-new path, and XLSX is
refused by name rather than rendered blank.

  $ office.exe render "$TESTDIR/../../../../docx2html/tests/cram/fixtures/single-paragraph.docx" --output rendered.pdf --json | jq -c '{success,data:{schema:.data.schema,backend:.data.backend,rendered:.data.pages_rendered,total:.data.pages_total,w:.data.page_width_pt,h:.data.page_height_pt,det:.data.byte_determinism}}'
  {"success":true,"data":{"schema":"office.render/1","backend":"pdf","rendered":1,"total":1,"w":595.3,"h":841.9,"det":"per-runtime"}}
  $ head -c 8 rendered.pdf
  %PDF-1.7 (no-eol)

SVG is the readable backend: uncompressed, so it is identical on every runtime
and an agent can read the coordinates a glyph was placed at.

  $ office.exe render "$TESTDIR/../../../../docx2html/tests/cram/fixtures/single-paragraph.docx" --output page.svg --json | jq -c '{backend:.data.backend,det:.data.byte_determinism,outs:[.data.outputs[].path]}'
  {"backend":"svg","det":"cross-runtime","outs":["page.svg"]}
  $ head -c 5 page.svg
  <svg  (no-eol)

Rendering the same document twice on one runtime is byte-identical, which is
the determinism the report advertises.

  $ office.exe render "$TESTDIR/../../../../docx2html/tests/cram/fixtures/single-paragraph.docx" --output again.pdf --json >/dev/null
  $ cmp rendered.pdf again.pdf && echo identical
  identical

An existing destination is refused with the shared transaction code unless
--overwrite is given.

  $ office.exe render "$TESTDIR/../../../../docx2html/tests/cram/fixtures/single-paragraph.docx" --output rendered.pdf --json > render-exists.json 2>&1; echo $?
  1
  $ jq -c '{success,code:.error.code}' render-exists.json
  {"success":false,"code":"office.transaction.output_exists"}
  $ office.exe render "$TESTDIR/../../../../docx2html/tests/cram/fixtures/single-paragraph.docx" --output rendered.pdf --overwrite --jsonl | jq -c '{success,schema:.data.schema}'
  {"success":true,"schema":"office.render/1"}

A workbook is refused by name, and a destination whose extension names no
backend is refused before any work happens.

  $ office.exe render "$TESTDIR/../../../../fixtures/excelize/test/Book1.xlsx" --output book.pdf --json > render-xlsx.json 2>&1; echo $?
  1
  $ jq -c '{success,code:.error.code}' render-xlsx.json
  {"success":false,"code":"office.xlsx.unsupported"}
  $ office.exe render "$TESTDIR/../../../../docx2html/tests/cram/fixtures/single-paragraph.docx" --output rendered.txt --json > render-ext.json 2>&1; echo $?
  1
  $ jq -c '{success,code:.error.code}' render-ext.json
  {"success":false,"code":"office.invalid_arguments"}

--pages selects a subset. A spec is normalized to ascending order with
duplicates removed, so a page cannot be published twice by writing it twice,
and SVG names each file after the document page it holds rather than its
position in the selection.

  $ office.exe render "$TESTDIR/../../../../docx2html/tests/stress/fixtures/docxcorp-reports-en-015012bf8890.docx" --output sel.svg --pages 3,1-2,3 --json | jq -c '{rendered:.data.pages_rendered,total:.data.pages_total,outs:[.data.outputs[].path]}'
  {"rendered":3,"total":11,"outs":["sel-1.svg","sel-2.svg","sel-3.svg"]}
  $ office.exe render "$TESTDIR/../../../../docx2html/tests/stress/fixtures/docxcorp-reports-en-015012bf8890.docx" --output pair.pdf --pages 2-3 --json | jq -c '{rendered:.data.pages_rendered,total:.data.pages_total,outs:[.data.outputs[].path]}'
  {"rendered":2,"total":11,"outs":["pair.pdf"]}

Page zero, a reversed range, and a page past the end are all refused with the
same message, because all three are the same mistake from the caller's side.

  $ for spec in 0 5-2 99; do office.exe render "$TESTDIR/../../../../docx2html/tests/stress/fixtures/docxcorp-reports-en-015012bf8890.docx" --output bad.pdf --pages "$spec" --json 2>&1 | jq -c '{code:.error.code}'; done
  {"code":"office.invalid_arguments"}
  {"code":"office.invalid_arguments"}
  {"code":"office.invalid_arguments"}

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

The template data document may carry repeating regions: a marked row is
cloned once per record. XLSX clones a marked sheet row through the atomic
grid-bounded insert; a formula-bearing workbook is refused wholesale.

  $ xlsx.exe create rep.xlsx --sheet Items >/dev/null
  $ xlsx.exe set rep.xlsx Items A1 'Invoice {{company}}' >/dev/null
  $ xlsx.exe set rep.xlsx Items A2 '{{item}}' >/dev/null
  $ xlsx.exe set rep.xlsx Items B2 '{{qty}}' >/dev/null
  $ xlsx.exe set rep.xlsx Items A3 footer >/dev/null
  $ cat > rep-data.json <<'DATA'
  > {"schema":"office.template.data/1","values":{"company":"ACME"},"regions":{"items":{"sheet":"Items","row":2,"records":[{"item":"Widget","qty":2},{"item":"Gadget","qty":3}]}}}
  > DATA
  $ office.exe template rep.xlsx rep-data.json --out rep-out.xlsx --json | jq -c '{success,replaced:.data.replaced,regions:[.data.regions[]|{name,records,replaced,rows:.output_rows}],total:.data.regions_total}'
  {"success":true,"replaced":5,"regions":[{"name":"items","records":2,"replaced":4,"rows":{"start":2,"count":2}}],"total":1}
  $ xlsx.exe get rep-out.xlsx Items A2
  Widget
  $ xlsx.exe get rep-out.xlsx Items A3
  Gadget
  $ xlsx.exe get rep-out.xlsx Items A4
  footer

A formula anywhere in the workbook refuses row repetition, since cloned
and shifted formula text is never rewritten.

  $ xlsx.exe create rep-f.xlsx --sheet Items >/dev/null
  $ xlsx.exe set rep-f.xlsx Items A2 '{{item}}' >/dev/null
  $ xlsx.exe formula rep-f.xlsx Items C1 '1+1' >/dev/null
  $ cat > rep-f-data.json <<'DATA'
  > {"schema":"office.template.data/1","values":{},"regions":{"items":{"sheet":"Items","row":2,"records":[{"item":"x"}]}}}
  > DATA
  $ office.exe template rep-f.xlsx rep-f-data.json --out rep-f-out.xlsx --json 2>&1 | jq -c '{success,code:.error.code}'
  {"success":false,"code":"office.template.unsupported_context"}
  $ test -f rep-f-out.xlsx || echo not published
  not published

DOCX repetition clones a marked table row through a fail-closed
element/attribute whitelist, addressed by its dump-grammar path.

  $ cat > docx-rep-script.json <<'SCRIPT'
  > {"schema":"docx.batch/2","ops":[
  >  {"op":"table","params":{"rows":[
  >    [{"text":"Item"},{"text":"Qty"}],
  >    [{"text":"{{item}}"},{"text":"{{qty}} pcs"}]
  >  ]}}
  > ]}
  > SCRIPT
  $ docx.exe batch docx-rep.docx docx-rep-script.json >/dev/null
  $ cat > docx-rep-data.json <<'DATA'
  > {"schema":"office.template.data/1","values":{},"regions":{"rows":{"path":"/docx/body/tbl[1]/tr[2]","records":[{"item":"Widget","qty":2},{"item":"Gadget","qty":3}]}}}
  > DATA
  $ office.exe template docx-rep.docx docx-rep-data.json --out docx-rep-out.docx --json | jq -c '{success,replaced:.data.replaced,regions:[.data.regions[]|{name,records,replaced,loc:.source_location}],total:.data.regions_total}'
  {"success":true,"replaced":4,"regions":[{"name":"rows","records":2,"replaced":4,"loc":"/docx/body/tbl[1]/tr[2]"}],"total":1}
  $ docx.exe text docx-rep-out.docx
  [/body/tbl[1]/tr[1]/tc[1]/p[1]] Item
  [/body/tbl[1]/tr[1]/tc[2]/p[1]] Qty
  [/body/tbl[1]/tr[2]/tc[1]/p[1]] Widget
  [/body/tbl[1]/tr[2]/tc[2]/p[1]] 2 pcs
  [/body/tbl[1]/tr[3]/tc[1]/p[1]] Gadget
  [/body/tbl[1]/tr[3]/tc[2]/p[1]] 3 pcs

The edit command replaces LITERAL text in an EXISTING DOCX through a strict
docx.edit/1 script. Word splits text freely, so the base document below puts
"draft" across three runs, the first of them bold: the match still lands as
one replacement, and the surviving runs keep their formatting.

  $ cat > edit-base-script.json <<'SCRIPT'
  > {"schema":"docx.batch/2","ops":[
  >  {"op":"paragraph","params":{"runs":[{"text":"The dr","bold":true},{"text":"aft","bold":true},{"text":" report is a draft","bold":true}]}},
  >  {"op":"paragraph","params":{"text":"Q3 then Q3 then Q3"}}
  > ]}
  > SCRIPT
  $ docx.exe batch edit-base.docx edit-base-script.json >/dev/null
  $ office.exe text edit-base.docx
  /docx/body/p[1]\tThe draft report is a draft (esc)
  /docx/body/p[2]\tQ3 then Q3 then Q3 (esc)

  $ cat > edit-script.json <<'SCRIPT'
  > {"schema":"docx.edit/1","ops":[
  >  {"op":"replace_text","params":{"find":"draft","replace":"final"}},
  >  {"op":"replace_text","params":{"find":"Q3","replace":"Q4","occurrence":2}}
  > ]}
  > SCRIPT
  $ office.exe edit edit-base.docx edit-script.json --out edit-out.docx
  edit: 3 replacement(s) across 2 op(s) -> edit-out.docx

The replaced text reads back through the ordinary text projection, the
published package validates, and the bold runs survive the rewrite.

  $ office.exe text edit-out.docx
  /docx/body/p[1]\tThe final report is a final (esc)
  /docx/body/p[2]\tQ3 then Q4 then Q3 (esc)
  $ office.exe validate edit-out.docx
  valid docx
  $ office.exe raw read edit-out.docx /word/document.xml | grep -o '<w:p><w:r><w:rPr><w:b/></w:rPr><w:t xml:space="preserve">The final</w:t></w:r>'
  <w:p><w:r><w:rPr><w:b/></w:rPr><w:t xml:space="preserve">The final</w:t></w:r>
  $ office.exe raw read edit-out.docx /word/document.xml | grep -o '<w:b/>' | wc -l | tr -d ' '
  2

The JSON record reports per-op counts, the occurrence selector, and the
authoritative preservation manifest: only the document part changed.

  $ office.exe edit edit-base.docx edit-script.json --out edit-json.docx --json | jq -c '{success,data:{schema:.data.schema,replacements:.data.replacements,results:[.data.results[]|{find,occurrence,matched,replacements}],stories:.data.stories_scanned,changed:.data.transaction.preservation.changed}}'
  {"success":true,"data":{"schema":"office.docx.edit/1","replacements":3,"results":[{"find":"draft","occurrence":null,"matched":2,"replacements":2},{"find":"Q3","occurrence":2,"matched":3,"replacements":1}],"stories":["/body"],"changed":["word/document.xml"]}}

A dry run performs the whole edit and validation without publishing, and
leaves the input byte-identical.

  $ cp edit-base.docx edit-before.docx
  $ office.exe edit edit-base.docx edit-script.json --out edit-dry.docx --dry-run
  edit: 3 replacement(s) across 2 op(s) -> edit-dry.docx
  $ test -f edit-dry.docx || echo not published
  not published
  $ cmp -s edit-base.docx edit-before.docx && echo input unchanged
  input unchanged

An addressed replacement (docx.edit/2) names one run by its query path
and sets its WHOLE text. The expectation is required: addresses are
snapshot-relative, and a stale one refuses without publishing.

  $ cat > setrun-script.json <<'SCRIPT'
  > {"schema":"docx.edit/2","ops":[
  >  {"op":"set_run_text","params":{"at":"p[2]/r[1]","expect":"Q3 then Q3 then Q3","text":"Quarterly"}}
  > ]}
  > SCRIPT
  $ office.exe edit edit-base.docx setrun-script.json --out setrun-out.docx
  edit: 1 replacement(s) across 1 op(s) -> setrun-out.docx
  $ office.exe text setrun-out.docx
  /docx/body/p[1]\tThe draft report is a draft (esc)
  /docx/body/p[2]\tQuarterly (esc)
  $ office.exe validate setrun-out.docx
  valid docx
  $ office.exe edit edit-base.docx setrun-script.json --out setrun-json.docx --json | jq -c '{success,data:{schema:.data.schema,results:[.data.results[]|{op,at,expect,text,find,matched,replacements}],changed:.data.transaction.preservation.changed}}'
  {"success":true,"data":{"schema":"office.docx.edit/2","results":[{"op":"set_run_text","at":"p[2]/r[1]","expect":"Q3 then Q3 then Q3","text":"Quarterly","find":null,"matched":1,"replacements":1}],"changed":["word/document.xml"]}}

  $ cat > setrun-stale.json <<'SCRIPT'
  > {"schema":"docx.edit/2","ops":[
  >  {"op":"set_run_text","params":{"at":"p[2]/r[1]","expect":"something else","text":"X"}}
  > ]}
  > SCRIPT
  $ office.exe edit edit-base.docx setrun-stale.json --out setrun-stale.docx
  office: the run at 'p[2]/r[1]' in 'word/document.xml' does not carry the expected text; re-read the document and retry with a fresh address
  [1]
  $ test -f setrun-stale.docx || echo not published
  not published

A needle that matches nothing refuses by default with a typed code and
publishes nothing, so a typo can never masquerade as a finished edit.

  $ cat > edit-miss.json <<'SCRIPT'
  > {"schema":"docx.edit/1","ops":[
  >  {"op":"replace_text","params":{"find":"nowhere","replace":"x"}}
  > ]}
  > SCRIPT
  $ office.exe edit edit-base.docx edit-miss.json --out edit-never.docx --json 2>&1 | jq -c '{success,code:.error.code,unmatched:[.error.details.unmatched[].detail]}'
  {"success":false,"code":"office.edit.unmatched_find","unmatched":["\"nowhere\" occurs 0 time(s); 1 required"]}
  $ test -f edit-never.docx || echo not published
  not published

With --allow-unmatched the same script is a no-op that republishes the
exact input bytes.

  $ office.exe edit edit-base.docx edit-miss.json --out edit-noop.docx --allow-unmatched --json | jq -c '{success,replacements:.data.replacements,changed:(.data.transaction.preservation.changed|length)}'
  {"success":true,"replacements":0,"changed":0}
  $ cmp -s edit-noop.docx edit-base.docx && echo byte-identical
  byte-identical

Two operations that match overlapping text are ambiguous, so the whole
transaction refuses rather than letting op order decide silently.

  $ cat > edit-clash.json <<'SCRIPT'
  > {"schema":"docx.edit/1","ops":[
  >  {"op":"replace_text","params":{"find":"draft report","replace":"a"}},
  >  {"op":"replace_text","params":{"find":"report is","replace":"b"}}
  > ]}
  > SCRIPT
  $ office.exe edit edit-base.docx edit-clash.json --out edit-clash.docx --json 2>&1 | jq -c '{success,code:.error.code,conflicts:[.error.details.conflicts[].detail]}'
  {"success":false,"code":"office.edit.overlapping_matches","conflicts":["matches for \"draft report\" and \"report is\" overlap"]}
  $ test -f edit-clash.docx || echo not published
  not published

The needle is literal, never a pattern: a regex-looking find matches only
itself, and unknown script members are rejected outright.

  $ cat > edit-literal.json <<'SCRIPT'
  > {"schema":"docx.edit/1","ops":[
  >  {"op":"replace_text","params":{"find":"dr.ft","replace":"x"}}
  > ]}
  > SCRIPT
  $ office.exe edit edit-base.docx edit-literal.json --out edit-literal.docx --json 2>&1 | jq -c '{success,code:.error.code}'
  {"success":false,"code":"office.edit.unmatched_find"}
  $ cat > edit-bad.json <<'SCRIPT'
  > {"schema":"docx.edit/1","ops":[
  >  {"op":"replace_text","params":{"find":"a","replace":"b","regex":true}}
  > ]}
  > SCRIPT
  $ office.exe edit edit-base.docx edit-bad.json --out edit-bad.docx --json 2>&1 | jq -c '{success,code:.error.code,message:.error.message}'
  {"success":false,"code":"office.edit.invalid_script","message":"invalid edit script: ops[0].params has unknown member \"regex\""}

The same command RESOLVES tracked changes. `office outline` reports what is
pending and `office text` keeps returning the accepted view; accept_revision
and reject_revision are how an agent turns either view into settled text. The
fixture below is the OOXML worked example: a deletion and the insertion that
replaced it, side by side in one paragraph.

  $ cp "$TESTDIR/../../../../docx2html/tests/cram/fixtures/single-paragraph.docx" rev-base.docx
  $ office.exe raw edit rev-base.docx /document --path '/w:document/w:body/w:p[1]' --action replace --xml '<w:p xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:r><w:t xml:space="preserve">The revenue was </w:t></w:r><w:del w:id="1" w:author="Reviewer" w:date="2026-01-01T00:00:00Z"><w:r><w:delText xml:space="preserve">flat</w:delText></w:r></w:del><w:ins w:id="2" w:author="Reviewer" w:date="2026-01-01T00:00:00Z"><w:r><w:t xml:space="preserve">up 18%</w:t></w:r></w:ins><w:r><w:t xml:space="preserve"> this quarter.</w:t></w:r></w:p>' >/dev/null
  $ office.exe outline rev-base.docx --json | jq -c '{insertions:.data.counts.insertions,deletions:.data.counts.deletions,ids:[.data.revisions[]|"\(.type)#\(.id)"]}'
  {"insertions":1,"deletions":1,"ids":["del#1","ins#2"]}

Accepting everything unwraps the insertion and removes the deletion with its
content: the reviewer's sentence becomes the settled text, and the outline
reports no pending revision at all.

  $ cat > rev-accept.json <<'SCRIPT'
  > {"schema":"docx.edit/1","ops":[{"op":"accept_revision","params":{"all":true}}]}
  > SCRIPT
  $ office.exe edit rev-base.docx rev-accept.json --out rev-accepted.docx
  edit: 2 revision(s) resolved across 1 op(s) -> rev-accepted.docx
  $ office.exe text rev-accepted.docx
  /docx/body/p[1]\tThe revenue was up 18% this quarter. (esc)
  $ office.exe outline rev-accepted.docx --json | jq -c '{insertions:.data.counts.insertions,deletions:.data.counts.deletions,revisions:.data.revisions}'
  {"insertions":0,"deletions":0,"revisions":[]}
  $ office.exe validate rev-accepted.docx
  valid docx

Rejecting everything is the mirror image, and it is the subtler direction:
the deleted text has to come BACK, which means every w:delText is renamed to
w:t in place — the run keeps its xml:space and everything else it had.

  $ cat > rev-reject.json <<'SCRIPT'
  > {"schema":"docx.edit/1","ops":[{"op":"reject_revision","params":{"all":true}}]}
  > SCRIPT
  $ office.exe edit rev-base.docx rev-reject.json --out rev-rejected.docx
  edit: 2 revision(s) resolved across 1 op(s) -> rev-rejected.docx
  $ office.exe text rev-rejected.docx
  /docx/body/p[1]\tThe revenue was flat this quarter. (esc)
  $ office.exe outline rev-rejected.docx --json | jq -c '{insertions:.data.counts.insertions,deletions:.data.counts.deletions,revisions:.data.revisions}'
  {"insertions":0,"deletions":0,"revisions":[]}
  $ office.exe raw read rev-rejected.docx /word/document.xml | grep -q 'delText' && echo still deleted || echo no delText left
  no delText left
  $ office.exe raw read rev-rejected.docx /word/document.xml | grep -o '<w:t xml:space="preserve">flat</w:t>'
  <w:t xml:space="preserve">flat</w:t>
  $ office.exe validate rev-rejected.docx
  valid docx

Selection is by the stable w:id, by author, by type, or all — never by
ordinal position. Rejecting revision 1 alone leaves revision 2 pending, so
the document is still under review and the outline still says so.

  $ cat > rev-one.json <<'SCRIPT'
  > {"schema":"docx.edit/1","ops":[{"op":"reject_revision","params":{"id":"1"}}]}
  > SCRIPT
  $ office.exe edit rev-base.docx rev-one.json --out rev-one.docx --json | jq -c '{success,resolved:.data.revisions_resolved,selector:.data.results[0].selector,matched:.data.results[0].matched,find:.data.results[0].find,locations:[.data.locations[].detail],changed:.data.transaction.preservation.changed}'
  {"success":true,"resolved":1,"selector":{"id":"1","author":null,"type":null,"all":false},"matched":1,"find":null,"locations":["reject w:del id=\"1\" author=\"Reviewer\""],"changed":["word/document.xml"]}
  $ office.exe outline rev-one.docx --json | jq -c '[.data.revisions[]|"\(.type)#\(.id)"]'
  ["ins#2"]
  $ office.exe text rev-one.docx
  /docx/body/p[1]\tThe revenue was flatup 18% this quarter. (esc)

A dry run resolves, validates, and publishes nothing, leaving the input
byte-identical.

  $ cp rev-base.docx rev-before.docx
  $ office.exe edit rev-base.docx rev-accept.json --out rev-dry.docx --dry-run
  edit: 2 revision(s) resolved across 1 op(s) -> rev-dry.docx
  $ test -f rev-dry.docx || echo not published
  not published
  $ cmp -s rev-base.docx rev-before.docx && echo input unchanged
  input unchanged

A selector that matches nothing refuses: a mistyped author must never look
like a finished review.

  $ cat > rev-miss.json <<'SCRIPT'
  > {"schema":"docx.edit/1","ops":[{"op":"accept_revision","params":{"author":"Nobody"}}]}
  > SCRIPT
  $ office.exe edit rev-base.docx rev-miss.json --out rev-never.docx --json 2>&1 | jq -c '{success,code:.error.code,unmatched:[.error.details.unmatched[].detail]}'
  {"success":false,"code":"office.edit.unmatched_revision","unmatched":["the selector matched no tracked change"]}
  $ test -f rev-never.docx || echo not published
  not published

Property revisions, moves, and every *PrChange are OUT OF SCOPE — and a
selection that reaches one refuses rather than resolving the rest. Leaving a
paragraph-mark insertion behind would mean "accept everything" quietly
returned a document still under review.

  $ cp "$TESTDIR/../../../../docx2html/tests/cram/fixtures/single-paragraph.docx" rev-excluded.docx
  $ office.exe raw edit rev-excluded.docx /document --path '/w:document/w:body/w:p[1]' --action replace --xml '<w:p xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:pPr><w:rPr><w:ins w:id="4" w:author="Reviewer"/></w:rPr></w:pPr><w:r><w:t>body</w:t></w:r></w:p>' >/dev/null
  $ office.exe edit rev-excluded.docx rev-accept.json --out rev-excluded-out.docx --json 2>&1 | jq -c '{success,code:.error.code,unsupported:[.error.details.unsupported[].detail]}'
  {"success":false,"code":"office.edit.unsupported_revision","unsupported":["w:ins id=\"4\" author=\"Reviewer\": w:ins is a property, move, or structure revision, which this build does not resolve"]}
  $ test -f rev-excluded-out.docx || echo not published
  not published

  $ cp "$TESTDIR/../../../../docx2html/tests/cram/fixtures/single-paragraph.docx" rev-move.docx
  $ office.exe raw edit rev-move.docx /document --path '/w:document/w:body/w:p[1]' --action replace --xml '<w:p xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:moveFrom w:id="5" w:author="Reviewer"><w:r><w:t>moved</w:t></w:r></w:moveFrom></w:p>' >/dev/null
  $ office.exe edit rev-move.docx rev-accept.json --out rev-move-out.docx --json 2>&1 | jq -c '{success,code:.error.code,unsupported:[.error.details.unsupported[].detail]}'
  {"success":false,"code":"office.edit.unsupported_revision","unsupported":["w:moveFrom id=\"5\" author=\"Reviewer\": w:moveFrom is a property, move, or structure revision, which this build does not resolve"]}

One script never mixes the two op families: their byte spans are resolved
against the same snapshot, and a replacement landing inside a revision the
same script removes has no defined outcome.

  $ cat > rev-mixed.json <<'SCRIPT'
  > {"schema":"docx.edit/1","ops":[
  >  {"op":"replace_text","params":{"find":"a","replace":"b"}},
  >  {"op":"accept_revision","params":{"all":true}}
  > ]}
  > SCRIPT
  $ office.exe edit rev-base.docx rev-mixed.json --out rev-mixed.docx --json 2>&1 | jq -c '{success,code:.error.code,message:.error.message}'
  {"success":false,"code":"office.edit.invalid_script","message":"invalid edit script: ops[1] mixes \"accept_revision\" with replace_text; a script resolves revisions or replaces text, never both"}


The annotate command mutates the comments of an EXISTING DOCX through a
strict docx.annotation-batch/1 script folded over the preservation-safe
edit session: add/reply/resolve/unresolve add only the narrow
comment-anchor markers to the document part (the body text is never
wholesale-rewritten) while updating the comment, content-type, and
relationship parts as the comments require.

  $ cat > ann-base-script.json <<'SCRIPT'
  > {"schema":"docx.batch/2","ops":[
  >  {"op":"paragraph","params":{"text":"A paragraph to review."}}
  > ]}
  > SCRIPT
  $ docx.exe batch ann-base.docx ann-base-script.json >/dev/null
  $ cat > ann-script.json <<'SCRIPT'
  > {"schema":"docx.annotation-batch/1","ops":[
  >  {"op":"comment_add","anchor":{"at":"/docx/body/p[1]"},"author":"Ada","body":["Please revise"],"label":"root"},
  >  {"op":"comment_reply","parent":{"label":"root"},"author":"Bob","body":["Done"],"label":"answer"},
  >  {"op":"comment_resolve","target":{"label":"root"}}
  > ]}
  > SCRIPT
  $ office.exe annotate ann-base.docx ann-script.json --out ann-out.docx
  annotate: 3 op(s) -> ann-out.docx
  $ office.exe annotate ann-base.docx ann-script.json --out ann-json.docx --json | jq -c '{success,data:{schema:.data.schema,ops:.data.ops_applied,labels:(.data.labels|length),changed:(.data.changed_parts|sort)}}'
  {"success":true,"data":{"schema":"office.docx.annotation-batch/1","ops":3,"labels":2,"changed":["[Content_Types].xml","word/_rels/document.xml.rels","word/comments.xml","word/commentsExtended.xml","word/document.xml"]}}

The per-op results surface the resolved anchor (comment_add) and the
referenced target id (reply's parent, resolve's acted-on comment).

  $ office.exe annotate ann-base.docx ann-script.json --out ann-shape.docx --json | jq -c '[.data.results[] | {op,anchor,target}]'
  [{"op":"comment_add","anchor":"/docx/body/p[1]","target":null},{"op":"comment_reply","anchor":null,"target":"0"},{"op":"comment_resolve","anchor":null,"target":"0"}]

An empty ops array is a valid no-op that republishes nothing changed.

  $ cat > ann-noop.json <<'SCRIPT'
  > {"schema":"docx.annotation-batch/1","ops":[]}
  > SCRIPT
  $ office.exe annotate ann-base.docx ann-noop.json --out ann-noop.docx --json | jq -c '{success,ops:.data.ops_applied,changed:(.data.changed_parts|length)}'
  {"success":true,"ops":0,"changed":0}

A reply to a comment id that does not exist refuses and publishes nothing.

  $ cat > ann-miss.json <<'SCRIPT'
  > {"schema":"docx.annotation-batch/1","ops":[
  >  {"op":"comment_reply","parent":{"comment_id":"9999"},"author":"A","body":["x"]}
  > ]}
  > SCRIPT
  $ office.exe annotate ann-base.docx ann-miss.json --out ann-never.docx --json 2>&1 | jq -c '{success,office_code:(.error.code|startswith("office.docx"))}'
  {"success":false,"office_code":true}
  $ test -f ann-never.docx || echo not published
  not published

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
