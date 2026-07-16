///|
test "capability registry resolves only DOCX and XLSX aliases" {
  for
    case in [
      ("docx", "docx"),
      ("WORD", "docx"),
      ("xlsx", "xlsx"),
      ("Excel", "xlsx"),
    ] {
    let (alternate, expected) = case
    guard @office.resolve_format_alias(alternate) is Some(format) else {
      fail("expected a format alias: \{alternate}")
    }
    assert_eq(format.name(), expected)
  }
  for unsupported in ["", "ppt", "pptx", "powerpoint", "mcp"] {
    assert_true(@office.resolve_format_alias(unsupported) is None)
  }
}

///|
test "capability registry advertises only implemented commands" {
  let commands = @office.capability_commands()
  let names = commands.map(command => command.name)
  inspect(
    names.join(","),
    content=(
      #|help,identify,outline,get,text,query,raw
    ),
  )
  guard commands[0] is { name: "help", usage, inputs: [query, ..], .. } else {
    fail("expected the declared help command")
  }
  assert_eq(
    usage, "office help [all|<format>|<operation>|<format> <operation>] [--json|--jsonl]",
  )
  assert_eq(query.name, "query")
  assert_false(usage.contains("element"))
  let inventory = @office.capabilities_data().stringify()
  assert_false(inventory.contains("ppt"))
  assert_false(inventory.contains("mcp"))
  assert_false(inventory.contains("watch"))
  assert_false(inventory.contains("\"name\":\"preview\""))
  assert_false(inventory.contains("\"name\":\"mutation\""))
}

///|
test "raw capability variants describe every accepted option and conflict" {
  guard @office.find_capability_command("raw") is Some(raw) else {
    fail("expected raw capability")
  }
  assert_eq(
    raw.variants.map(variant => variant.name).join(","),
    "list,read,replace,edit",
  )
  assert_eq(raw.outputs.length(), 0)
  assert_eq(
    raw.variants.map(variant => variant.result_schema).join(","),
    "office.raw.inventory/1,office.raw.part/1,office.raw.result/1,office.raw.result/1",
  )
  assert_eq(
    raw.variants[0].outputs.map(field => field.name).join(","),
    "format,part_count,parts",
  )
  assert_eq(
    raw.variants[1].outputs.map(field => field.name).join(","),
    "format,part,encoding,content,output",
  )
  for index in [2, 3] {
    assert_eq(
      raw.variants[index].outputs.map(field => field.name).join(","),
      "change,transaction",
    )
    assert_eq(raw.variants[index].outputs[0].type_name, "office.raw.change/1")
    assert_eq(raw.variants[index].outputs[1].type_name, "office.transaction/1")
    assert_true(
      raw.variants[index].constraints.contains(
        "out-extension-must-match-input-format",
      ),
    )
    let mut out_description : String? = None
    for field in raw.variants[index].inputs {
      if field.name == "out" {
        out_description = Some(field.description)
      }
    }
    guard out_description is Some(description) else {
      fail("raw mutation variant must publish its output contract")
    }
    assert_true(description.contains("same .docx or .xlsx extension"))
  }
  assert_eq(
    raw.variants[0].inputs.map(field => field.name).join(","),
    "file,json",
  )
  assert_eq(
    raw.variants[1].inputs.map(field => field.name).join(","),
    "file,part,json,base64,output",
  )
  assert_eq(
    raw.variants[2].inputs.map(field => field.name).join(","),
    "file,part,xml,xml-file,out,dry-run,overwrite,json",
  )
  assert_eq(
    raw.variants[3].inputs.map(field => field.name).join(","),
    "file,part,path,action,xml,xml-file,attribute,value,namespace,all,out,dry-run,overwrite,json",
  )
  assert_true(
    raw.variants[1].constraints.contains("mutually-exclusive(base64,output)"),
  )
  assert_true(raw.variants[2].constraints.contains("exactly-one(xml,xml-file)"))
  assert_true(
    raw.variants[3].constraints.contains(
      "set-attribute-requires(attribute,value)",
    ),
  )
  assert_true(
    raw.variants[3].constraints.contains(
      "flag-looking-values-require-attached-syntax",
    ),
  )
  let actions = raw.variants[3].actions
  assert_eq(
    actions.map(action => action.name).join(","),
    "append,prepend,insert-before,insert-after,replace,remove,set-attribute",
  )
  for index in [0, 1, 2, 3, 4] {
    assert_eq(actions[index].requires, ["exactly-one(xml,xml-file)"])
    assert_eq(actions[index].forbids, ["attribute", "value"])
  }
  assert_eq(actions[5].forbids, ["xml", "xml-file", "attribute", "value"])
  assert_eq(actions[6].requires, ["attribute", "value"])
  assert_eq(actions[6].forbids, ["xml", "xml-file"])
  for index in [2, 3, 5] {
    assert_eq(actions[index].restrictions, [
      "path-must-not-select-document-element",
    ])
  }
  assert_true(
    @office.capabilities_data(operation="raw")
    .stringify()
    .contains("\"result_schema\":\"office.raw.result/1\""),
  )
}

///|
test "capability formats advertise resolved structured reads for DOCX and XLSX" {
  let formats = @office.capability_formats()
  assert_eq(formats.length(), 2)
  assert_eq(formats[0].selector.schema, "office.selector/1")
  assert_eq(formats[0].selector.root, "/docx")
  assert_eq(formats[1].selector.root, "/xlsx")
  assert_eq(formats[0].selector.status, "read-resolved")
  assert_true(formats[0].selector.description.contains("bounded canonical"))
  assert_eq(formats[1].selector.status, "read-resolved")
  assert_true(formats[1].selector.description.contains("bounded canonical"))
  assert_true(formats[0].selector.examples.length() >= 2)
  assert_true(formats[1].selector.examples.length() >= 2)
}

///|
test "structured read capabilities publish both format schemas and enforced bounds" {
  for
    case in [
      ("outline", @office.SCHEMA_DOCX_OUTLINE, @office.SCHEMA_XLSX_OUTLINE),
      ("get", @office.SCHEMA_DOCX_ELEMENT, @office.SCHEMA_XLSX_ELEMENT),
      ("text", @office.SCHEMA_DOCX_TEXT, @office.SCHEMA_XLSX_TEXT),
      ("query", @office.SCHEMA_DOCX_QUERY, @office.SCHEMA_XLSX_QUERY),
    ] {
    let (name, docx_schema, xlsx_schema) = case
    guard @office.find_capability_command(name) is Some(command) else {
      fail("missing command: \{name}")
    }
    assert_eq(command.formats, ["docx", "xlsx"])
    assert_true(command.inputs.any(field => field.name == "max-elements"))
    assert_true(command.inputs.any(field => field.name == "max-output-chars"))
    guard command.outputs.filter(field => field.name == "schema").get(0)
      is Some(schema) else {
      fail("missing schema output: \{name}")
    }
    assert_true(schema.type_name.contains(docx_schema))
    assert_true(schema.type_name.contains(xlsx_schema))
    assert_true(
      command.variants.any(variant => variant.result_schema == docx_schema),
    )
    assert_true(
      command.variants.any(variant => variant.result_schema == xlsx_schema),
    )
  }
  guard @office.find_capability_command("query") is Some(query) else {
    fail("missing query command")
  }
  assert_true(query.inputs.any(field => field.name == "property"))
  assert_true(query.usage.contains("--ignore-case"))
  assert_false(query.usage.to_lower().contains("regex"))
  guard @office.find_capability_command("outline") is Some(outline) else {
    fail("missing outline command")
  }
  for name in ["active_sheet", "sheets", "defined_names", "limits"] {
    assert_true(outline.outputs.any(field => field.name == name))
  }
  guard @office.find_capability_command("get") is Some(get) else {
    fail("missing get command")
  }
  for
    name in [
      "sheet_count", "sheets", "defined_names", "sheet", "cell", "cells", "reference",
      "styles", "scanned_cells", "returned",
    ] {
    assert_true(get.outputs.any(field => field.name == name))
  }
}

///|
test "capability registry format filters remain truthful" {
  let records = @office.capability_records(format=Docx)
    .map(record => record.stringify())
    .join("\n")
  inspect(
    records,
    content=(
      #|{"schema":"office.capability/2","fingerprint":"crc32:e9c5b34f","kind":"format","name":"docx","aliases":["word"],"description":"WordprocessingML documents","selector":{"schema":"office.selector/1","root":"/docx","status":"read-resolved","examples":["/docx/body/p[1]/r[2]","/docx/comments/comment[id=\"7\"]"],"description":"bounded canonical resolution for outline, get, text, and declared query predicates"}}
      #|{"schema":"office.capability/2","fingerprint":"crc32:e9c5b34f","kind":"command","name":"identify","summary":"Identify a structurally valid XLSX or DOCX package","usage":"office identify <file> [--json]","formats":["docx","xlsx"],"aliases":[],"inputs":[{"name":"file","type":"path","required":true,"description":"path to an XLSX or DOCX package"},{"name":"json","type":"boolean","required":false,"description":"emit one office.output/1 JSON document"}],"outputs":[{"name":"file","type":"path","required":true,"description":"the input path exactly as supplied"},{"name":"format","type":"enum(docx|xlsx)","required":true,"description":"the structurally verified package format"}],"output_modes":["human","json"],"variants":[]}
      #|{"schema":"office.capability/2","fingerprint":"crc32:e9c5b34f","kind":"command","name":"outline","summary":"Summarize bounded XLSX or DOCX structure using canonical selectors","usage":"office outline FILE [--max-elements N] [--max-output-chars N] [--json]","formats":["docx","xlsx"],"aliases":[],"inputs":[{"name":"file","type":"path","required":true,"description":"existing XLSX or DOCX package"},{"name":"max-elements","type":"integer(1..200000)","required":false,"description":"DOCX projection-node or XLSX cell scan ceiling; default 50000; XLSX effective hard ceiling 100000"},{"name":"max-output-chars","type":"integer(1..4194304)","required":false,"description":"successful stdout ceiling including trailing LF; failure envelopes are separate; default 1048576"},{"name":"json","type":"boolean","required":false,"description":"emit office.output/1 JSON"}],"outputs":[{"name":"schema","type":"enum(office.docx.outline/1|office.xlsx.outline/1)","required":true,"description":"format-specific versioned result schema"},{"name":"file","type":"path","required":true,"description":"the input path exactly as supplied"},{"name":"format","type":"enum(docx|xlsx)","required":true,"description":"resolved document format"},{"name":"scanned_elements","type":"integer","required":false,"description":"DOCX only: number of elements in the bounded projection"},{"name":"counts","type":"object","required":false,"description":"DOCX only: deterministic structural counts across every story"},{"name":"stories","type":"array","required":false,"description":"DOCX only: story roots"},{"name":"headings","type":"array","required":false,"description":"DOCX only: bounded heading previews"},{"name":"styles_in_use","type":"array","required":false,"description":"DOCX only: deduplicated referenced styles"},{"name":"images","type":"array","required":false,"description":"DOCX only: image metadata"},{"name":"sections","type":"array","required":false,"description":"DOCX only: section boundaries and header/footer references"},{"name":"diagnostics","type":"array","required":false,"description":"DOCX only: reader and source diagnostics"},{"name":"path","type":"literal(/xlsx/workbook)","required":false,"description":"XLSX only: canonical workbook selector"},{"name":"sheet_count","type":"integer","required":false,"description":"XLSX only: workbook tab count"},{"name":"active_sheet","type":"object","required":false,"description":"XLSX only: canonical active-sheet summary when the workbook has tabs"},{"name":"sheets","type":"array","required":false,"description":"XLSX only: bounded tab-order sheet summaries with canonical paths and used ranges"},{"name":"defined_names","type":"array","required":false,"description":"XLSX only: bounded workbook defined-name inventory"},{"name":"limits","type":"object","required":false,"description":"XLSX only: effective scan and metadata limits"}],"output_modes":["human","json"],"variants":[{"name":"docx","usage":"office outline FILE","result_schema":"office.docx.outline/1","inputs":[],"outputs":[],"constraints":["format=docx"],"actions":[],"output_modes":["human","json"]},{"name":"xlsx","usage":"office outline FILE","result_schema":"office.xlsx.outline/1","inputs":[],"outputs":[],"constraints":["format=xlsx"],"actions":[],"output_modes":["human","json"]}]}
      #|{"schema":"office.capability/2","fingerprint":"crc32:e9c5b34f","kind":"command","name":"get","summary":"Resolve one canonical XLSX or DOCX selector","usage":"office get FILE SELECTOR [--max-elements N] [--max-output-chars N] [--json]","formats":["docx","xlsx"],"aliases":[],"inputs":[{"name":"file","type":"path","required":true,"description":"existing XLSX or DOCX package"},{"name":"selector","type":"office.selector/1","required":true,"description":"canonical selector matching the validated package format"},{"name":"max-elements","type":"integer(1..200000)","required":false,"description":"DOCX projection-node or XLSX cell scan ceiling; default 50000; XLSX effective hard ceiling 100000"},{"name":"max-output-chars","type":"integer(1..4194304)","required":false,"description":"successful stdout ceiling including trailing LF; failure envelopes are separate; default 1048576"},{"name":"json","type":"boolean","required":false,"description":"emit office.output/1 JSON"}],"outputs":[{"name":"schema","type":"enum(office.docx.element/1|office.xlsx.element/1)","required":true,"description":"format-specific versioned result schema"},{"name":"file","type":"path","required":true,"description":"the input path exactly as supplied"},{"name":"format","type":"enum(docx|xlsx)","required":true,"description":"resolved document format"},{"name":"path","type":"office.selector/1","required":true,"description":"resolved canonical path"},{"name":"kind","type":"string","required":true,"description":"resolved workbook, sheet, coordinate, story, annotation, or element kind"},{"name":"role","type":"enum(story-root|annotation-collection|annotation-item|element)","required":false,"description":"DOCX only: projection role"},{"name":"stability","type":"enum(stable|snapshot-relative)","required":true,"description":"selector stability classification"},{"name":"source","type":"object","required":false,"description":"DOCX only: physical story source metadata"},{"name":"parent","type":"office.selector/1","required":false,"description":"canonical parent path; absent for projection roots"},{"name":"id","type":"string","required":false,"description":"annotation id when the resolved item carries one"},{"name":"children","type":"array","required":false,"description":"DOCX only: addressable direct children"},{"name":"properties","type":"object","required":false,"description":"DOCX only: declared formatting and element summary"},{"name":"metadata","type":"object","required":false,"description":"DOCX only: role-specific metadata"},{"name":"text","type":"string","required":false,"description":"DOCX only: bounded raw text projection"},{"name":"sheet_count","type":"integer","required":false,"description":"XLSX workbook selectors only: workbook tab count"},{"name":"sheets","type":"array","required":false,"description":"XLSX workbook selectors only: bounded tab-order sheet summaries"},{"name":"defined_names","type":"array","required":false,"description":"XLSX workbook selectors only: bounded defined-name inventory"},{"name":"sheet","type":"object","required":false,"description":"XLSX sheet selectors only: bounded sheet summary"},{"name":"cell","type":"object","required":false,"description":"XLSX cell selectors only: typed value, formula, style, and canonical path"},{"name":"cells","type":"array","required":false,"description":"XLSX range selectors only: populated cells in row-major order"},{"name":"reference","type":"a1-range","required":false,"description":"XLSX range selectors only: normalized A1 rectangle"},{"name":"styles","type":"object","required":false,"description":"XLSX coordinate selectors only: deduplicated referenced style definitions"},{"name":"scanned_cells","type":"integer","required":false,"description":"XLSX coordinate selectors only: exact rectangle scan count"},{"name":"returned","type":"integer","required":false,"description":"XLSX range selectors only: populated cell count"}],"output_modes":["human","json"],"variants":[{"name":"docx","usage":"office get FILE /docx/...","result_schema":"office.docx.element/1","inputs":[],"outputs":[],"constraints":["format=docx"],"actions":[],"output_modes":["human","json"]},{"name":"xlsx","usage":"office get FILE /xlsx/...","result_schema":"office.xlsx.element/1","inputs":[],"outputs":[],"constraints":["format=xlsx"],"actions":[],"output_modes":["human","json"]}]}
      #|{"schema":"office.capability/2","fingerprint":"crc32:e9c5b34f","kind":"command","name":"text","summary":"Extract bounded path-tagged XLSX cell or DOCX paragraph text","usage":"office text FILE [--under SELECTOR] [--offset N] [--limit N] [--max-elements N] [--max-output-chars N] [--json]","formats":["docx","xlsx"],"aliases":[],"inputs":[{"name":"file","type":"path","required":true,"description":"existing XLSX or DOCX package"},{"name":"under","type":"office.selector/1","required":false,"description":"optional canonical DOCX subtree or XLSX workbook/sheet/range/cell scope"},{"name":"offset","type":"integer(0..200000)","required":false,"description":"zero-based matching paragraph or cell offset; default 0"},{"name":"limit","type":"integer(0..10000)","required":false,"description":"maximum returned paragraphs or cells; default 2000"},{"name":"max-elements","type":"integer(1..200000)","required":false,"description":"DOCX projection-node or XLSX cell scan ceiling; default 50000; XLSX effective hard ceiling 100000"},{"name":"max-output-chars","type":"integer(1..4194304)","required":false,"description":"successful stdout ceiling including trailing LF; failure envelopes are separate; default 1048576"},{"name":"json","type":"boolean","required":false,"description":"emit office.output/1 JSON"}],"outputs":[{"name":"schema","type":"enum(office.docx.text/1|office.xlsx.text/1)","required":true,"description":"format-specific versioned result schema"},{"name":"file","type":"path","required":true,"description":"the input path exactly as supplied"},{"name":"format","type":"enum(docx|xlsx)","required":true,"description":"resolved document format"},{"name":"entries","type":"array(object{path,text,stability})","required":true,"description":"paragraphs in document order or cells in sheet/row-major order"},{"name":"matched_total","type":"integer","required":true,"description":"complete bounded-scan matching paragraph or cell count"},{"name":"returned","type":"integer","required":true,"description":"number of returned entries"},{"name":"truncated","type":"boolean","required":true,"description":"whether pagination omitted later matches"},{"name":"offset","type":"integer","required":true,"description":"applied zero-based match offset"},{"name":"limit","type":"integer","required":true,"description":"applied page-size ceiling"},{"name":"scanned_elements","type":"integer","required":false,"description":"DOCX only: projected element count"},{"name":"scanned_cells","type":"integer","required":false,"description":"XLSX only: exact bounded cell scan count"},{"name":"under","type":"office.selector/1","required":false,"description":"resolved canonical scope when one was requested"}],"output_modes":["human","json"],"variants":[{"name":"docx","usage":"office text FILE [--under /docx/...]","result_schema":"office.docx.text/1","inputs":[],"outputs":[],"constraints":["format=docx"],"actions":[],"output_modes":["human","json"]},{"name":"xlsx","usage":"office text FILE [--under /xlsx/...]","result_schema":"office.xlsx.text/1","inputs":[],"outputs":[],"constraints":["format=xlsx"],"actions":[],"output_modes":["human","json"]}]}
      #|{"schema":"office.capability/2","fingerprint":"crc32:e9c5b34f","kind":"command","name":"query","summary":"Run bounded deterministic predicates over XLSX cells or DOCX elements","usage":"office query FILE [CELL_SELECTOR] [--under SELECTOR] [--kind KIND] [--text TEXT] [--id ID] [--property NAME=VALUE]... [--ignore-case] [--offset N] [--limit N] [--max-elements N] [--max-output-chars N] [--json]","formats":["docx","xlsx"],"aliases":[],"inputs":[{"name":"file","type":"path","required":true,"description":"existing XLSX or DOCX package"},{"name":"selector","type":"xlsx-cell-selector","required":false,"description":"XLSX only: cell followed by up to 16 bounded type, value, formula, or text predicates; default cell"},{"name":"under","type":"office.selector/1","required":false,"description":"optional canonical DOCX subtree or XLSX workbook/sheet/range/cell scope"},{"name":"kind","type":"enum(body|header|footer|footnotes|endnotes|comments|note|comment|p|r|tbl|tr|tc|hyperlink|image)","required":false,"description":"DOCX only: exact kind; documented aliases normalize before matching"},{"name":"text","type":"literal-string(1..1048576 chars)","required":false,"description":"DOCX only: literal substring predicate; regular expressions are not accepted"},{"name":"id","type":"string(1..1048576 chars)","required":false,"description":"DOCX only: exact annotation id predicate"},{"name":"property","type":"array(NAME=VALUE)","required":false,"description":"DOCX only: up to 16 exact declared-property predicates"},{"name":"ignore-case","type":"boolean","required":false,"description":"DOCX only: locale-independent Unicode simple-case --text matching"},{"name":"offset","type":"integer(0..200000)","required":false,"description":"zero-based match offset; default 0"},{"name":"limit","type":"integer(0..1000)","required":false,"description":"maximum returned matches; default 100"},{"name":"max-elements","type":"integer(1..200000)","required":false,"description":"DOCX projection-node or XLSX cell scan ceiling; default 50000; XLSX effective hard ceiling 100000"},{"name":"max-output-chars","type":"integer(1..4194304)","required":false,"description":"successful stdout ceiling including trailing LF; failure envelopes are separate; default 1048576"},{"name":"json","type":"boolean","required":false,"description":"emit office.output/1 JSON"}],"outputs":[{"name":"schema","type":"enum(office.docx.query/1|office.xlsx.query/1)","required":true,"description":"format-specific versioned result schema"},{"name":"file","type":"path","required":true,"description":"the input path exactly as supplied"},{"name":"format","type":"enum(docx|xlsx)","required":true,"description":"resolved document format"},{"name":"filters","type":"object","required":false,"description":"DOCX only: normalized predicates applied by this query"},{"name":"matches","type":"array","required":true,"description":"deterministic document-order or sheet/row-major match records"},{"name":"matched_total","type":"integer","required":true,"description":"complete bounded-scan match count"},{"name":"returned","type":"integer","required":true,"description":"number of returned matches"},{"name":"truncated","type":"boolean","required":true,"description":"whether pagination omitted later matches"},{"name":"offset","type":"integer","required":true,"description":"applied zero-based match offset"},{"name":"limit","type":"integer","required":true,"description":"applied page-size ceiling"},{"name":"scanned_elements","type":"integer","required":false,"description":"DOCX only: projected element count"},{"name":"selector","type":"xlsx-cell-selector","required":false,"description":"XLSX only: supplied bounded cell selector"},{"name":"styles","type":"object","required":false,"description":"XLSX only: deduplicated styles referenced by returned matches"},{"name":"scanned_cells","type":"integer","required":false,"description":"XLSX only: exact bounded cell scan count"},{"name":"under","type":"office.selector/1","required":false,"description":"resolved canonical scope when one was requested"}],"output_modes":["human","json"],"variants":[{"name":"docx","usage":"office query FILE [DOCX predicates]","result_schema":"office.docx.query/1","inputs":[],"outputs":[],"constraints":["format=docx"],"actions":[],"output_modes":["human","json"]},{"name":"xlsx","usage":"office query FILE [cell[predicate]...]","result_schema":"office.xlsx.query/1","inputs":[],"outputs":[],"constraints":["format=xlsx"],"actions":[],"output_modes":["human","json"]}]}
      #|{"schema":"office.capability/2","fingerprint":"crc32:e9c5b34f","kind":"command","name":"raw","summary":"Inventory, read, and atomically edit validated OOXML parts","usage":"office raw <list|read|replace|edit> ...","formats":["docx","xlsx"],"aliases":[],"inputs":[{"name":"operation","type":"enum(list|read|replace|edit)","required":true,"description":"bounded raw OOXML operation"}],"outputs":[],"output_modes":["human","json","base64","file"],"variants":[{"name":"list","usage":"office raw list FILE [--json]","result_schema":"office.raw.inventory/1","inputs":[{"name":"file","type":"path","required":true,"description":"existing XLSX or DOCX package"},{"name":"json","type":"boolean","required":false,"description":"emit office.output/1 JSON"}],"outputs":[{"name":"format","type":"enum(docx|xlsx)","required":true,"description":"structurally verified package format"},{"name":"part_count","type":"integer","required":true,"description":"number of inventoried package parts"},{"name":"parts","type":"array(object{name:path,content_type:string,kind:enum(xml|binary),size:integer,aliases:array(string)})","required":true,"description":"bounded canonical part inventory records"}],"constraints":[],"actions":[],"output_modes":["human","json"]},{"name":"read","usage":"office raw read FILE PART [--json] [--base64 | --output FILE]","result_schema":"office.raw.part/1","inputs":[{"name":"file","type":"path","required":true,"description":"existing XLSX or DOCX package"},{"name":"part","type":"part-selector","required":true,"description":"/name when unambiguous, alias:/name, or part:/name"},{"name":"json","type":"boolean","required":false,"description":"emit office.output/1 JSON"},{"name":"base64","type":"boolean","required":false,"description":"emit exact payload as base64"},{"name":"output","type":"path","required":false,"description":"create a file with the exact payload"}],"outputs":[{"name":"format","type":"enum(docx|xlsx)","required":true,"description":"structurally verified package format"},{"name":"part","type":"object{name:path,content_type:string,kind:enum(xml|binary),size:integer,aliases:array(string)}","required":true,"description":"resolved package-part metadata"},{"name":"encoding","type":"enum(xml|base64|binary)","required":true,"description":"selected payload representation"},{"name":"content","type":"string","required":false,"description":"decoded XML text or base64 payload"},{"name":"output","type":"path","required":false,"description":"created payload destination"}],"constraints":["mutually-exclusive(base64,output)","binary-requires(base64|output)","output-create-mode(create-new)"],"actions":[],"output_modes":["human","json","base64","file"]},{"name":"replace","usage":"office raw replace FILE PART (--xml XML | --xml-file FILE) [--out FILE] [--dry-run] [--overwrite] [--json]","result_schema":"office.raw.result/1","inputs":[{"name":"file","type":"path","required":true,"description":"existing XLSX or DOCX package"},{"name":"part","type":"part-selector","required":true,"description":"existing XML part selector"},{"name":"xml","type":"utf8-xml","required":false,"description":"complete replacement XML document"},{"name":"xml-file","type":"path","required":false,"description":"bounded UTF-8 replacement XML file"},{"name":"out","type":"path","required":false,"description":"separate destination with the same .docx or .xlsx extension as the input"},{"name":"dry-run","type":"boolean","required":false,"description":"validate without publishing"},{"name":"overwrite","type":"boolean","required":false,"description":"replace an existing separate destination"},{"name":"json","type":"boolean","required":false,"description":"emit office.output/1 JSON"}],"outputs":[{"name":"change","type":"office.raw.change/1","required":true,"description":"validated raw mutation summary"},{"name":"transaction","type":"office.transaction/1","required":true,"description":"transaction validation and publication report"}],"constraints":["exactly-one(xml,xml-file)","overwrite-requires(out)","out-extension-must-match-input-format","transactional-publication"],"actions":[],"output_modes":["human","json"]},{"name":"edit","usage":"office raw edit FILE PART --path PATH --action ACTION [action arguments] [--namespace PREFIX=URI]... [--all] [--out FILE] [--dry-run] [--overwrite] [--json]","result_schema":"office.raw.result/1","inputs":[{"name":"file","type":"path","required":true,"description":"existing XLSX or DOCX package"},{"name":"part","type":"part-selector","required":true,"description":"existing XML part selector"},{"name":"path","type":"office.raw.path/1","required":true,"description":"bounded namespace-aware element selector"},{"name":"action","type":"enum(append|prepend|insert-before|insert-after|replace|remove|set-attribute)","required":true,"description":"bounded edit action"},{"name":"xml","type":"utf8-xml-element","required":false,"description":"one self-contained XML element"},{"name":"xml-file","type":"path","required":false,"description":"bounded UTF-8 XML element file"},{"name":"attribute","type":"qname","required":false,"description":"set-attribute target name"},{"name":"value","type":"string","required":false,"description":"set-attribute exact decoded value"},{"name":"namespace","type":"array(PREFIX=URI)","required":false,"description":"repeatable selector namespace overrides"},{"name":"all","type":"boolean","required":false,"description":"allow multiple bounded matches"},{"name":"out","type":"path","required":false,"description":"separate destination with the same .docx or .xlsx extension as the input"},{"name":"dry-run","type":"boolean","required":false,"description":"validate without publishing"},{"name":"overwrite","type":"boolean","required":false,"description":"replace an existing separate destination"},{"name":"json","type":"boolean","required":false,"description":"emit office.output/1 JSON"}],"outputs":[{"name":"change","type":"office.raw.change/1","required":true,"description":"validated raw mutation summary"},{"name":"transaction","type":"office.transaction/1","required":true,"description":"transaction validation and publication report"}],"constraints":["mutually-exclusive(xml,xml-file)","element-actions-require(exactly-one(xml,xml-file))","set-attribute-requires(attribute,value)","remove-forbids(xml,xml-file,attribute,value)","overwrite-requires(out)","flag-looking-values-require-attached-syntax","out-extension-must-match-input-format","transactional-publication"],"actions":[{"name":"append","requires":["exactly-one(xml,xml-file)"],"forbids":["attribute","value"],"restrictions":[]},{"name":"prepend","requires":["exactly-one(xml,xml-file)"],"forbids":["attribute","value"],"restrictions":[]},{"name":"insert-before","requires":["exactly-one(xml,xml-file)"],"forbids":["attribute","value"],"restrictions":["path-must-not-select-document-element"]},{"name":"insert-after","requires":["exactly-one(xml,xml-file)"],"forbids":["attribute","value"],"restrictions":["path-must-not-select-document-element"]},{"name":"replace","requires":["exactly-one(xml,xml-file)"],"forbids":["attribute","value"],"restrictions":[]},{"name":"remove","requires":[],"forbids":["xml","xml-file","attribute","value"],"restrictions":["path-must-not-select-document-element"]},{"name":"set-attribute","requires":["attribute","value"],"forbids":["xml","xml-file"],"restrictions":[]}],"output_modes":["human","json"]}]}
    ),
  )
}

///|
test "capability fingerprint and inventory ordering are deterministic" {
  inspect(
    @office.capability_fingerprint(),
    content=(
      #|crc32:e9c5b34f
    ),
  )
  let first = @office.capabilities_data().stringify()
  let second = @office.capabilities_data().stringify()
  assert_eq(first, second)
  let parsed = @json.parse(first)
  assert_eq(parsed.stringify(), first)
}

///|
test "capability operation queries do not leak unrelated records" {
  let data = @office.capabilities_data(format=Docx, operation="IDENTIFY")
  inspect(
    data.stringify(),
    content=(
      #|{"schema":"office.capabilities/2","fingerprint":"crc32:e9c5b34f","records":[{"schema":"office.capability/2","fingerprint":"crc32:e9c5b34f","kind":"command","name":"identify","summary":"Identify a structurally valid XLSX or DOCX package","usage":"office identify <file> [--json]","formats":["docx","xlsx"],"aliases":[],"inputs":[{"name":"file","type":"path","required":true,"description":"path to an XLSX or DOCX package"},{"name":"json","type":"boolean","required":false,"description":"emit one office.output/1 JSON document"}],"outputs":[{"name":"file","type":"path","required":true,"description":"the input path exactly as supplied"},{"name":"format","type":"enum(docx|xlsx)","required":true,"description":"the structurally verified package format"}],"output_modes":["human","json"],"variants":[]}],"format":"docx","operation":"identify"}
    ),
  )
}
