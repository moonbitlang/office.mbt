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
      #|help,identify,outline,get,text,query,validate,dump,replay,issues,preview,create,template,annotate,batch,raw
    ),
  )
  guard commands[0] is { name: "help", usage, inputs: [query, ..], .. } else {
    fail("expected the declared help command")
  }
  assert_eq(
    usage, "office help [all|schemas|schema <id>|<format>|<operation>|<format> <operation>] [--json|--jsonl]",
  )
  assert_eq(query.name, "query")
  assert_false(usage.contains("element"))
  let help = commands[0]
  assert_eq(help.outputs.length(), 0)
  assert_eq(
    help.variants.map(variant => variant.name).join(","),
    "capabilities,capability-records,schemas,schema",
  )
  assert_eq(
    help.variants.map(variant => variant.result_schema).join(","),
    "office.capabilities/2,office.capability/2,office.input-contracts/1,office.input-contract/1",
  )
  assert_eq(
    help.variants[0].outputs.map(field => field.name).join(","),
    "schema,fingerprint,records,format,operation",
  )
  assert_eq(
    help.variants[1].outputs.map(field => field.name).join(","),
    "schema,fingerprint,kind,name,aliases,description,selector,summary,usage,formats,inputs,outputs,output_modes,variants",
  )
  assert_eq(
    help.variants[2].outputs.map(field => field.name).join(","),
    "schema,fingerprint,contracts",
  )
  assert_eq(
    help.variants[3].outputs.map(field => field.name).join(","),
    "schema,id,fingerprint,summary,consumed_by,envelope,definitions,operations,constraints,limits,examples",
  )
  let inventory = @office.capabilities_data().stringify()
  assert_false(inventory.contains("ppt"))
  assert_false(inventory.contains("mcp"))
  assert_false(inventory.contains("watch"))
  assert_false(inventory.contains("\"name\":\"mutation\""))
}

///|
test "XLSX batch help embeds the exact parser-owned versioned registry" {
  guard @office.find_capability_command("batch") is Some(command) else {
    fail("batch capability must exist")
  }
  assert_true(!command.variants.is_empty())
  let variant = command.variants[0]
  assert_eq(variant.name, "xlsx")
  guard variant.registry is Some(registry) else {
    fail("XLSX batch capability must carry its parser registry")
  }
  assert_eq(registry.stringify(), @batch.capabilities().stringify())
  guard @office.capability_records(format=Xlsx, operation="batch")
    is [Object(record)] &&
    record.get("variants") is Some(Array([Object(serialized)])) &&
    serialized.get("registry") is Some(serialized_registry) else {
    fail("serialized XLSX batch capability must carry its parser registry")
  }
  assert_eq(serialized_registry.stringify(), @batch.capabilities().stringify())
}

///|
test "help variants declare every field their serializers emit" {
  guard @office.find_capability_command("help") is Some(help) else {
    fail("expected help capability")
  }
  fn assert_declared_shape(
    document : Json,
    declared : Array[String],
    required : Array[String],
  ) -> Unit raise {
    guard document is Object(fields) else { fail("expected an object") }
    for name, _ in fields {
      if !declared.contains(name) {
        fail("undeclared output: " + name)
      }
    }
    for name in required {
      if !fields.contains(name) {
        fail("missing required output: " + name)
      }
    }
  }
  let capability_outputs = help.variants[0].outputs
  let capability_names = capability_outputs.map(field => field.name)
  let capability_required = capability_outputs
    .filter(field => field.required)
    .map(field => field.name)
  assert_declared_shape(
    @office.capabilities_data(),
    capability_names,
    capability_required,
  )
  assert_declared_shape(
    @office.capabilities_data(format=Docx, operation="identify"),
    capability_names,
    capability_required,
  )
  let record_outputs = help.variants[1].outputs
  let record_names = record_outputs.map(field => field.name)
  let record_required = record_outputs
    .filter(field => field.required)
    .map(field => field.name)
  for record in @office.capability_records() {
    assert_declared_shape(record, record_names, record_required)
  }
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
    assert_eq(raw.variants[index].outputs[1].type_name, "office.transaction/2")
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
test "structured capability variants are self-contained and format exact" {
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
    assert_eq(command.variants.length(), 2)
    let docx = command.variants[0]
    let xlsx = command.variants[1]
    assert_eq(docx.name, "docx")
    assert_eq(xlsx.name, "xlsx")
    assert_true(!docx.inputs.is_empty())
    assert_true(!docx.outputs.is_empty())
    assert_true(!xlsx.inputs.is_empty())
    assert_true(!xlsx.outputs.is_empty())
    guard docx.outputs.filter(field => field.name == "schema").get(0)
      is Some(docx_field) else {
      fail("missing DOCX schema field: \{name}")
    }
    guard xlsx.outputs.filter(field => field.name == "schema").get(0)
      is Some(xlsx_field) else {
      fail("missing XLSX schema field: \{name}")
    }
    assert_eq(docx_field.type_name, "literal(\{docx_schema})")
    assert_eq(xlsx_field.type_name, "literal(\{xlsx_schema})")
    assert_false(
      docx.outputs.any(field => field.description.contains("XLSX only")),
    )
    assert_false(
      xlsx.outputs.any(field => field.description.contains("DOCX only")),
    )
    assert_false(
      docx.inputs.any(field => field.description.contains("XLSX only")),
    )
    assert_false(
      xlsx.inputs.any(field => field.description.contains("DOCX only")),
    )
  }
}

///|
test "format-filtered capability records remove cross-format unions" {
  let docx_records = @office.capability_records(format=Docx).map(record => {
    record.stringify()
  })
  let joined = docx_records.join("\n")
  assert_false(joined.contains("\"formats\":[\"docx\",\"xlsx\"]"))
  assert_false(joined.contains("\"name\":\"xlsx\",\"usage\":"))
  assert_false(joined.contains("XLSX only"))
  assert_true(joined.contains("\"type\":\"literal(docx)\""))
  for record in docx_records {
    if record.contains("\"kind\":\"command\"") {
      assert_true(record.contains("\"formats\":[\"docx\"]"))
    }
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
      #|{"schema":"office.capability/2","fingerprint":"crc32:9dac1240","kind":"format","name":"docx","aliases":["word"],"description":"WordprocessingML documents","selector":{"schema":"office.selector/1","root":"/docx","status":"read-resolved","examples":["/docx/body/p[1]/r[2]","/docx/comments/comment[id=\"7\"]"],"description":"bounded canonical resolution for outline, get, text, and declared query predicates"}}
      #|{"schema":"office.capability/2","fingerprint":"crc32:9dac1240","kind":"command","name":"identify","summary":"Identify a structurally valid XLSX or DOCX package","usage":"office identify <file> [--json]","formats":["docx"],"aliases":[],"inputs":[{"name":"file","type":"path","required":true,"description":"path to an XLSX or DOCX package"},{"name":"json","type":"boolean","required":false,"description":"emit one office.output/1 JSON document"}],"outputs":[{"name":"file","type":"path","required":true,"description":"the input path exactly as supplied"},{"name":"format","type":"literal(docx)","required":true,"description":"the structurally verified package format"}],"output_modes":["human","json"],"variants":[]}
      #|{"schema":"office.capability/2","fingerprint":"crc32:9dac1240","kind":"command","name":"outline","summary":"Summarize bounded XLSX or DOCX structure using canonical selectors","usage":"office outline FILE [--max-elements N] [--max-output-chars N] [--json]","formats":["docx"],"aliases":[],"inputs":[{"name":"file","type":"path","required":true,"description":"existing XLSX or DOCX package"},{"name":"max-elements","type":"integer(1..200000)","required":false,"description":"DOCX projection-node or XLSX cell scan ceiling; default 50000; XLSX effective hard ceiling 100000"},{"name":"max-output-chars","type":"integer(1..4194304)","required":false,"description":"successful stdout ceiling including trailing LF; failure envelopes are separate; default 1048576"},{"name":"json","type":"boolean","required":false,"description":"emit office.output/1 JSON"}],"outputs":[{"name":"schema","type":"literal(office.docx.outline/1)","required":true,"description":"format-specific versioned result schema"},{"name":"file","type":"path","required":true,"description":"the input path exactly as supplied"},{"name":"format","type":"literal(docx)","required":true,"description":"resolved document format"},{"name":"scanned_elements","type":"integer","required":false,"description":"DOCX only: number of elements in the bounded projection"},{"name":"counts","type":"object","required":false,"description":"DOCX only: deterministic structural counts across every story"},{"name":"stories","type":"array","required":false,"description":"DOCX only: story roots"},{"name":"headings","type":"array","required":false,"description":"DOCX only: bounded heading previews"},{"name":"styles_in_use","type":"array","required":false,"description":"DOCX only: deduplicated referenced styles"},{"name":"images","type":"array","required":false,"description":"DOCX only: image metadata"},{"name":"sections","type":"array","required":false,"description":"DOCX only: section boundaries and header/footer references"},{"name":"diagnostics","type":"array","required":false,"description":"DOCX only: reader and source diagnostics"}],"output_modes":["human","json"],"variants":[{"name":"docx","usage":"office outline FILE","result_schema":"office.docx.outline/1","inputs":[{"name":"file","type":"path","required":true,"description":"existing XLSX or DOCX package"},{"name":"max-elements","type":"integer(1..200000)","required":false,"description":"DOCX projection-node or XLSX cell scan ceiling; default 50000; XLSX effective hard ceiling 100000"},{"name":"max-output-chars","type":"integer(1..4194304)","required":false,"description":"successful stdout ceiling including trailing LF; failure envelopes are separate; default 1048576"},{"name":"json","type":"boolean","required":false,"description":"emit office.output/1 JSON"}],"outputs":[{"name":"schema","type":"literal(office.docx.outline/1)","required":true,"description":"format-specific versioned result schema"},{"name":"file","type":"path","required":true,"description":"the input path exactly as supplied"},{"name":"format","type":"literal(docx)","required":true,"description":"resolved document format"},{"name":"scanned_elements","type":"integer","required":false,"description":"DOCX only: number of elements in the bounded projection"},{"name":"counts","type":"object","required":false,"description":"DOCX only: deterministic structural counts across every story"},{"name":"stories","type":"array","required":false,"description":"DOCX only: story roots"},{"name":"headings","type":"array","required":false,"description":"DOCX only: bounded heading previews"},{"name":"styles_in_use","type":"array","required":false,"description":"DOCX only: deduplicated referenced styles"},{"name":"images","type":"array","required":false,"description":"DOCX only: image metadata"},{"name":"sections","type":"array","required":false,"description":"DOCX only: section boundaries and header/footer references"},{"name":"diagnostics","type":"array","required":false,"description":"DOCX only: reader and source diagnostics"}],"constraints":["format=docx"],"actions":[],"output_modes":["human","json"]}]}
      #|{"schema":"office.capability/2","fingerprint":"crc32:9dac1240","kind":"command","name":"get","summary":"Resolve one canonical XLSX or DOCX selector","usage":"office get FILE SELECTOR [--max-elements N] [--max-output-chars N] [--json]","formats":["docx"],"aliases":[],"inputs":[{"name":"file","type":"path","required":true,"description":"existing XLSX or DOCX package"},{"name":"selector","type":"office.selector/1","required":true,"description":"canonical selector matching the validated package format"},{"name":"max-elements","type":"integer(1..200000)","required":false,"description":"DOCX projection-node or XLSX cell scan ceiling; default 50000; XLSX effective hard ceiling 100000"},{"name":"max-output-chars","type":"integer(1..4194304)","required":false,"description":"successful stdout ceiling including trailing LF; failure envelopes are separate; default 1048576"},{"name":"json","type":"boolean","required":false,"description":"emit office.output/1 JSON"}],"outputs":[{"name":"schema","type":"literal(office.docx.element/1)","required":true,"description":"format-specific versioned result schema"},{"name":"file","type":"path","required":true,"description":"the input path exactly as supplied"},{"name":"format","type":"literal(docx)","required":true,"description":"resolved document format"},{"name":"path","type":"office.selector/1","required":true,"description":"resolved canonical path"},{"name":"kind","type":"string","required":true,"description":"resolved workbook, sheet, coordinate, story, annotation, or element kind"},{"name":"role","type":"enum(story-root|annotation-collection|annotation-item|element)","required":false,"description":"DOCX only: projection role"},{"name":"stability","type":"enum(stable|snapshot-relative)","required":true,"description":"selector stability classification"},{"name":"source","type":"object","required":false,"description":"DOCX only: physical story source metadata"},{"name":"parent","type":"office.selector/1","required":false,"description":"canonical parent path; absent for projection roots"},{"name":"id","type":"string","required":false,"description":"annotation id when the resolved item carries one"},{"name":"children","type":"array","required":false,"description":"DOCX only: addressable direct children"},{"name":"properties","type":"object","required":false,"description":"DOCX only: declared formatting and element summary"},{"name":"metadata","type":"object","required":false,"description":"DOCX only: role-specific metadata"},{"name":"text","type":"string","required":false,"description":"DOCX only: bounded raw text projection"}],"output_modes":["human","json"],"variants":[{"name":"docx","usage":"office get FILE /docx/...","result_schema":"office.docx.element/1","inputs":[{"name":"file","type":"path","required":true,"description":"existing XLSX or DOCX package"},{"name":"selector","type":"office.selector/1","required":true,"description":"canonical selector matching the validated package format"},{"name":"max-elements","type":"integer(1..200000)","required":false,"description":"DOCX projection-node or XLSX cell scan ceiling; default 50000; XLSX effective hard ceiling 100000"},{"name":"max-output-chars","type":"integer(1..4194304)","required":false,"description":"successful stdout ceiling including trailing LF; failure envelopes are separate; default 1048576"},{"name":"json","type":"boolean","required":false,"description":"emit office.output/1 JSON"}],"outputs":[{"name":"schema","type":"literal(office.docx.element/1)","required":true,"description":"format-specific versioned result schema"},{"name":"file","type":"path","required":true,"description":"the input path exactly as supplied"},{"name":"format","type":"literal(docx)","required":true,"description":"resolved document format"},{"name":"path","type":"office.selector/1","required":true,"description":"resolved canonical path"},{"name":"kind","type":"string","required":true,"description":"resolved workbook, sheet, coordinate, story, annotation, or element kind"},{"name":"role","type":"enum(story-root|annotation-collection|annotation-item|element)","required":false,"description":"DOCX only: projection role"},{"name":"stability","type":"enum(stable|snapshot-relative)","required":true,"description":"selector stability classification"},{"name":"source","type":"object","required":false,"description":"DOCX only: physical story source metadata"},{"name":"parent","type":"office.selector/1","required":false,"description":"canonical parent path; absent for projection roots"},{"name":"id","type":"string","required":false,"description":"annotation id when the resolved item carries one"},{"name":"children","type":"array","required":false,"description":"DOCX only: addressable direct children"},{"name":"properties","type":"object","required":false,"description":"DOCX only: declared formatting and element summary"},{"name":"metadata","type":"object","required":false,"description":"DOCX only: role-specific metadata"},{"name":"text","type":"string","required":false,"description":"DOCX only: bounded raw text projection"}],"constraints":["format=docx"],"actions":[],"output_modes":["human","json"]}]}
      #|{"schema":"office.capability/2","fingerprint":"crc32:9dac1240","kind":"command","name":"text","summary":"Extract bounded path-tagged XLSX cell or DOCX paragraph text","usage":"office text FILE [--under SELECTOR] [--offset N] [--limit N] [--max-elements N] [--max-output-chars N] [--json]","formats":["docx"],"aliases":[],"inputs":[{"name":"file","type":"path","required":true,"description":"existing XLSX or DOCX package"},{"name":"under","type":"office.selector/1","required":false,"description":"optional canonical DOCX subtree or XLSX workbook/sheet/range/cell scope"},{"name":"offset","type":"integer(0..200000)","required":false,"description":"zero-based matching paragraph or cell offset; default 0"},{"name":"limit","type":"integer(0..10000)","required":false,"description":"maximum returned paragraphs or cells; default 2000"},{"name":"max-elements","type":"integer(1..200000)","required":false,"description":"DOCX projection-node or XLSX cell scan ceiling; default 50000; XLSX effective hard ceiling 100000"},{"name":"max-output-chars","type":"integer(1..4194304)","required":false,"description":"successful stdout ceiling including trailing LF; failure envelopes are separate; default 1048576"},{"name":"json","type":"boolean","required":false,"description":"emit office.output/1 JSON"}],"outputs":[{"name":"schema","type":"literal(office.docx.text/1)","required":true,"description":"format-specific versioned result schema"},{"name":"file","type":"path","required":true,"description":"the input path exactly as supplied"},{"name":"format","type":"literal(docx)","required":true,"description":"resolved document format"},{"name":"entries","type":"array(object{path,text,stability})","required":true,"description":"paragraphs in document order or cells in sheet/row-major order"},{"name":"matched_total","type":"integer","required":true,"description":"complete bounded-scan matching paragraph or cell count"},{"name":"returned","type":"integer","required":true,"description":"number of returned entries"},{"name":"truncated","type":"boolean","required":true,"description":"whether pagination omitted later matches"},{"name":"offset","type":"integer","required":true,"description":"applied zero-based match offset"},{"name":"limit","type":"integer","required":true,"description":"applied page-size ceiling"},{"name":"scanned_elements","type":"integer","required":false,"description":"DOCX only: projected element count"},{"name":"under","type":"office.selector/1","required":false,"description":"resolved canonical scope when one was requested"}],"output_modes":["human","json"],"variants":[{"name":"docx","usage":"office text FILE [--under /docx/...]","result_schema":"office.docx.text/1","inputs":[{"name":"file","type":"path","required":true,"description":"existing XLSX or DOCX package"},{"name":"under","type":"office.selector/1","required":false,"description":"optional canonical DOCX subtree or XLSX workbook/sheet/range/cell scope"},{"name":"offset","type":"integer(0..200000)","required":false,"description":"zero-based matching paragraph or cell offset; default 0"},{"name":"limit","type":"integer(0..10000)","required":false,"description":"maximum returned paragraphs or cells; default 2000"},{"name":"max-elements","type":"integer(1..200000)","required":false,"description":"DOCX projection-node or XLSX cell scan ceiling; default 50000; XLSX effective hard ceiling 100000"},{"name":"max-output-chars","type":"integer(1..4194304)","required":false,"description":"successful stdout ceiling including trailing LF; failure envelopes are separate; default 1048576"},{"name":"json","type":"boolean","required":false,"description":"emit office.output/1 JSON"}],"outputs":[{"name":"schema","type":"literal(office.docx.text/1)","required":true,"description":"format-specific versioned result schema"},{"name":"file","type":"path","required":true,"description":"the input path exactly as supplied"},{"name":"format","type":"literal(docx)","required":true,"description":"resolved document format"},{"name":"entries","type":"array(object{path,text,stability})","required":true,"description":"paragraphs in document order or cells in sheet/row-major order"},{"name":"matched_total","type":"integer","required":true,"description":"complete bounded-scan matching paragraph or cell count"},{"name":"returned","type":"integer","required":true,"description":"number of returned entries"},{"name":"truncated","type":"boolean","required":true,"description":"whether pagination omitted later matches"},{"name":"offset","type":"integer","required":true,"description":"applied zero-based match offset"},{"name":"limit","type":"integer","required":true,"description":"applied page-size ceiling"},{"name":"scanned_elements","type":"integer","required":false,"description":"DOCX only: projected element count"},{"name":"under","type":"office.selector/1","required":false,"description":"resolved canonical scope when one was requested"}],"constraints":["format=docx"],"actions":[],"output_modes":["human","json"]}]}
      #|{"schema":"office.capability/2","fingerprint":"crc32:9dac1240","kind":"command","name":"query","summary":"Run bounded deterministic predicates over XLSX cells or DOCX elements","usage":"office query FILE [CELL_SELECTOR] [--under SELECTOR] [--kind KIND] [--text TEXT] [--id ID] [--property NAME=VALUE]... [--ignore-case] [--offset N] [--limit N] [--max-elements N] [--max-output-chars N] [--json]","formats":["docx"],"aliases":[],"inputs":[{"name":"file","type":"path","required":true,"description":"existing XLSX or DOCX package"},{"name":"under","type":"office.selector/1","required":false,"description":"optional canonical DOCX subtree or XLSX workbook/sheet/range/cell scope"},{"name":"kind","type":"enum(body|header|footer|footnotes|endnotes|comments|note|comment|p|r|tbl|tr|tc|hyperlink|image)","required":false,"description":"DOCX only: exact kind; documented aliases normalize before matching"},{"name":"text","type":"literal-string(1..1048576 chars)","required":false,"description":"DOCX only: literal substring predicate; regular expressions are not accepted"},{"name":"id","type":"string(1..1048576 chars)","required":false,"description":"DOCX only: exact annotation id predicate"},{"name":"property","type":"array(NAME=VALUE)","required":false,"description":"DOCX only: up to 16 exact declared-property predicates"},{"name":"ignore-case","type":"boolean","required":false,"description":"DOCX only: locale-independent Unicode simple-case --text matching"},{"name":"offset","type":"integer(0..200000)","required":false,"description":"zero-based match offset; default 0"},{"name":"limit","type":"integer(0..1000)","required":false,"description":"maximum returned matches; default 100"},{"name":"max-elements","type":"integer(1..200000)","required":false,"description":"DOCX projection-node or XLSX cell scan ceiling; default 50000; XLSX effective hard ceiling 100000"},{"name":"max-output-chars","type":"integer(1..4194304)","required":false,"description":"successful stdout ceiling including trailing LF; failure envelopes are separate; default 1048576"},{"name":"json","type":"boolean","required":false,"description":"emit office.output/1 JSON"}],"outputs":[{"name":"schema","type":"literal(office.docx.query/1)","required":true,"description":"format-specific versioned result schema"},{"name":"file","type":"path","required":true,"description":"the input path exactly as supplied"},{"name":"format","type":"literal(docx)","required":true,"description":"resolved document format"},{"name":"filters","type":"object","required":false,"description":"DOCX only: normalized predicates applied by this query"},{"name":"matches","type":"array","required":true,"description":"deterministic document-order or sheet/row-major match records"},{"name":"matched_total","type":"integer","required":true,"description":"complete bounded-scan match count"},{"name":"returned","type":"integer","required":true,"description":"number of returned matches"},{"name":"truncated","type":"boolean","required":true,"description":"whether pagination omitted later matches"},{"name":"offset","type":"integer","required":true,"description":"applied zero-based match offset"},{"name":"limit","type":"integer","required":true,"description":"applied page-size ceiling"},{"name":"scanned_elements","type":"integer","required":false,"description":"DOCX only: projected element count"},{"name":"under","type":"office.selector/1","required":false,"description":"resolved canonical scope when one was requested"}],"output_modes":["human","json"],"variants":[{"name":"docx","usage":"office query FILE [DOCX predicates]","result_schema":"office.docx.query/1","inputs":[{"name":"file","type":"path","required":true,"description":"existing XLSX or DOCX package"},{"name":"under","type":"office.selector/1","required":false,"description":"optional canonical DOCX subtree or XLSX workbook/sheet/range/cell scope"},{"name":"kind","type":"enum(body|header|footer|footnotes|endnotes|comments|note|comment|p|r|tbl|tr|tc|hyperlink|image)","required":false,"description":"DOCX only: exact kind; documented aliases normalize before matching"},{"name":"text","type":"literal-string(1..1048576 chars)","required":false,"description":"DOCX only: literal substring predicate; regular expressions are not accepted"},{"name":"id","type":"string(1..1048576 chars)","required":false,"description":"DOCX only: exact annotation id predicate"},{"name":"property","type":"array(NAME=VALUE)","required":false,"description":"DOCX only: up to 16 exact declared-property predicates"},{"name":"ignore-case","type":"boolean","required":false,"description":"DOCX only: locale-independent Unicode simple-case --text matching"},{"name":"offset","type":"integer(0..200000)","required":false,"description":"zero-based match offset; default 0"},{"name":"limit","type":"integer(0..1000)","required":false,"description":"maximum returned matches; default 100"},{"name":"max-elements","type":"integer(1..200000)","required":false,"description":"DOCX projection-node or XLSX cell scan ceiling; default 50000; XLSX effective hard ceiling 100000"},{"name":"max-output-chars","type":"integer(1..4194304)","required":false,"description":"successful stdout ceiling including trailing LF; failure envelopes are separate; default 1048576"},{"name":"json","type":"boolean","required":false,"description":"emit office.output/1 JSON"}],"outputs":[{"name":"schema","type":"literal(office.docx.query/1)","required":true,"description":"format-specific versioned result schema"},{"name":"file","type":"path","required":true,"description":"the input path exactly as supplied"},{"name":"format","type":"literal(docx)","required":true,"description":"resolved document format"},{"name":"filters","type":"object","required":false,"description":"DOCX only: normalized predicates applied by this query"},{"name":"matches","type":"array","required":true,"description":"deterministic document-order or sheet/row-major match records"},{"name":"matched_total","type":"integer","required":true,"description":"complete bounded-scan match count"},{"name":"returned","type":"integer","required":true,"description":"number of returned matches"},{"name":"truncated","type":"boolean","required":true,"description":"whether pagination omitted later matches"},{"name":"offset","type":"integer","required":true,"description":"applied zero-based match offset"},{"name":"limit","type":"integer","required":true,"description":"applied page-size ceiling"},{"name":"scanned_elements","type":"integer","required":false,"description":"DOCX only: projected element count"},{"name":"under","type":"office.selector/1","required":false,"description":"resolved canonical scope when one was requested"}],"constraints":["format=docx"],"actions":[],"output_modes":["human","json"]}]}
      #|{"schema":"office.capability/2","fingerprint":"crc32:9dac1240","kind":"command","name":"validate","summary":"Validate an XLSX or DOCX package with the shared mutation gate","usage":"office validate FILE [--json|--jsonl]","formats":["docx"],"aliases":[],"inputs":[{"name":"file","type":"path","required":true,"description":"existing XLSX or DOCX package"},{"name":"json","type":"boolean","required":false,"description":"emit one office.output/1 JSON document"},{"name":"jsonl","type":"boolean","required":false,"description":"emit one office.output/1 line"}],"outputs":[{"name":"schema","type":"literal(office.validate/1)","required":true,"description":"versioned validate result schema"},{"name":"file","type":"path","required":true,"description":"the input path, bounded"},{"name":"format","type":"literal(docx)","required":true,"description":"the structurally verified package format"},{"name":"valid","type":"boolean","required":true,"description":"true when the shared package gate reported no errors"},{"name":"findings","type":"array(office.finding/1)","required":true,"description":"bounded office.finding/1 records with severity, code, and message"},{"name":"error_count","type":"integer","required":true,"description":"number of error findings"},{"name":"warning_count","type":"integer","required":true,"description":"number of warning findings"}],"output_modes":["human","json","jsonl"],"variants":[]}
      #|{"schema":"office.capability/2","fingerprint":"crc32:9dac1240","kind":"command","name":"dump","summary":"Dump an XLSX or DOCX package as a replayable office.dump/1 op stream","usage":"office dump FILE [--json|--jsonl]","formats":["docx"],"aliases":[],"inputs":[{"name":"file","type":"path","required":true,"description":"existing XLSX or DOCX package"},{"name":"json","type":"boolean","required":false,"description":"emit the office.dump/1 JSON document"},{"name":"jsonl","type":"boolean","required":false,"description":"emit the streaming office.dump/1 JSONL form"}],"outputs":[{"name":"schema","type":"literal(office.dump/1)","required":true,"description":"versioned replayable dump schema"},{"name":"format","type":"literal(docx)","required":true,"description":"the structurally verified package format"},{"name":"source","type":"object","required":true,"description":"bounded input path, byte count, and sha256 digest (excluded from fixpoint comparison)"},{"name":"replay","type":"object","required":true,"description":"batch schema, create parameters, and engine limits for replay"},{"name":"ops","type":"array","required":true,"description":"ordered canonical versioned batch ops in engine JSON shapes"},{"name":"assets","type":"object","required":true,"description":"content-addressed binaries: sha256-<hex> id to {content_type, size, data} inline base64 under per-asset and total allowances"},{"name":"residual","type":"array","required":true,"description":"ordered machine-readable records of content not expressible as ops"},{"name":"warnings","type":"array","required":true,"description":"bounded dump diagnostics"},{"name":"stats","type":"object","required":true,"description":"op/asset/residual/warning counts"}],"output_modes":["human","json","jsonl"],"variants":[]}
      #|{"schema":"office.capability/2","fingerprint":"crc32:9dac1240","kind":"command","name":"replay","summary":"Replay an office.dump/1 document into an XLSX or DOCX package","usage":"office replay FILE --output OUT [--overwrite] [--json|--jsonl]","formats":["docx"],"aliases":[],"inputs":[{"name":"file","type":"path","required":true,"description":"existing office.dump/1 JSON document"},{"name":"output","type":"path","required":true,"description":"destination file matching the dump format (.xlsx or .docx); created atomically, refused when present unless --overwrite"},{"name":"overwrite","type":"boolean","required":false,"description":"replace an existing destination (remove-then-stage; not a single atomic swap)"},{"name":"json","type":"boolean","required":false,"description":"emit one office.output/1 JSON document"},{"name":"jsonl","type":"boolean","required":false,"description":"emit one office.output/1 line"}],"outputs":[{"name":"schema","type":"literal(office.replay/1)","required":true,"description":"versioned replay result schema"},{"name":"format","type":"literal(docx)","required":true,"description":"the replayed package format"},{"name":"output","type":"path","required":true,"description":"the published workbook path, bounded"},{"name":"bytes_written","type":"integer","required":true,"description":"exact published byte count"},{"name":"ops_applied","type":"integer","required":true,"description":"number of dump ops replayed"}],"output_modes":["human","json","jsonl"],"variants":[]}
      #|{"schema":"office.capability/2","fingerprint":"crc32:9dac1240","kind":"command","name":"issues","summary":"Report bounded actionable findings for an XLSX or DOCX package","usage":"office issues FILE [--json|--jsonl]","formats":["docx"],"aliases":[],"inputs":[{"name":"file","type":"path","required":true,"description":"existing XLSX or DOCX package"},{"name":"json","type":"boolean","required":false,"description":"emit one office.output/1 JSON document"},{"name":"jsonl","type":"boolean","required":false,"description":"emit one office.output/1 line"}],"outputs":[{"name":"schema","type":"literal(office.issues/1)","required":true,"description":"versioned issues result schema"},{"name":"file","type":"path","required":true,"description":"the input path, bounded"},{"name":"format","type":"literal(docx)","required":true,"description":"the structurally verified package format"},{"name":"valid","type":"boolean","required":true,"description":"true when the shared package gate reported no errors"},{"name":"findings","type":"array(office.finding/1)","required":true,"description":"bounded office.finding/1 records; XLSX cached formula errors and DOCX reader diagnostics are warnings"},{"name":"error_count","type":"integer","required":true,"description":"number of error findings"},{"name":"warning_count","type":"integer","required":true,"description":"number of warning findings"}],"output_modes":["human","json","jsonl"],"variants":[]}
      #|{"schema":"office.capability/2","fingerprint":"crc32:9dac1240","kind":"command","name":"preview","summary":"Render a deterministic offline HTML preview with inline assets","usage":"office preview FILE --output OUT.html [--overwrite] [--json|--jsonl]","formats":["docx"],"aliases":[],"inputs":[{"name":"file","type":"path","required":true,"description":"existing XLSX or DOCX package"},{"name":"output","type":"path","required":true,"description":"destination .html file; created atomically, refused when present unless --overwrite"},{"name":"overwrite","type":"boolean","required":false,"description":"replace an existing destination (remove-then-stage; not a single atomic swap)"},{"name":"json","type":"boolean","required":false,"description":"emit one office.output/1 JSON document"},{"name":"jsonl","type":"boolean","required":false,"description":"emit one office.output/1 line"}],"outputs":[{"name":"schema","type":"literal(office.preview/1)","required":true,"description":"versioned preview result schema"},{"name":"file","type":"path","required":true,"description":"the input path, bounded"},{"name":"format","type":"literal(docx)","required":true,"description":"the structurally verified package format"},{"name":"output","type":"path","required":true,"description":"the published preview path, bounded"},{"name":"bytes_written","type":"integer","required":true,"description":"exact published byte count"},{"name":"charts_rendered","type":"integer","required":true,"description":"charts rendered as inline SVG"},{"name":"charts_placeholder","type":"integer","required":true,"description":"charts kept as labeled placeholders"},{"name":"images_embedded","type":"integer","required":true,"description":"images embedded as data URIs"},{"name":"truncation","type":"object","required":true,"description":"row/column caps, truncated sheet names, and omitted image count"},{"name":"warnings","type":"array","required":false,"description":"bounded converter warnings"}],"output_modes":["human","json","jsonl"],"variants":[]}
      #|{"schema":"office.capability/2","fingerprint":"crc32:9dac1240","kind":"command","name":"create","summary":"Create a validated Office document atomically","usage":"office create (xlsx OUTPUT [--sheet NAME] | docx OUTPUT) [--dry-run] [--overwrite] [--json]","formats":["docx"],"aliases":[],"inputs":[{"name":"format","type":"literal(docx)","required":true,"description":"document format subcommand"}],"outputs":[],"output_modes":["human","json"],"variants":[{"name":"docx","usage":"office create docx OUTPUT [--dry-run] [--overwrite] [--json]","result_schema":"office.docx.create/1","inputs":[{"name":"output","type":"path","required":true,"description":"new .docx destination"},{"name":"dry-run","type":"boolean","required":false,"description":"validate without publishing"},{"name":"overwrite","type":"boolean","required":false,"description":"atomically replace an existing regular-file destination"},{"name":"json","type":"boolean","required":false,"description":"emit office.output/1 JSON"}],"outputs":[{"name":"transaction","type":"office.transaction/2","required":true,"description":"validation, preservation, and publication report"}],"constraints":["format=docx","output-extension=.docx","create-new-by-default","transactional-publication","bounded-candidate-package","blank-document-only"],"actions":[],"output_modes":["human","json"]}]}
      #|{"schema":"office.capability/2","fingerprint":"crc32:9dac1240","kind":"command","name":"template","summary":"Merge strict template data into an XLSX or DOCX document","usage":"office template FILE DATA.json --out OUT [--dry-run] [--overwrite] [--allow-missing] [--json|--jsonl]","formats":["docx"],"aliases":[],"inputs":[{"name":"file","type":"path","required":true,"description":"existing XLSX or DOCX template package (never modified)"},{"name":"data","type":"path","required":true,"description":"office.template.data/1 JSON document: flat `values` (string/number/bool) plus an optional `regions` map cloning a marked template row once per record; XLSX accepts {sheet,row}, while DOCX accepts only a body-table {path}"},{"name":"out","type":"path","required":true,"description":"destination matching the template format; created atomically, refused when present unless --overwrite"},{"name":"dry-run","type":"boolean","required":false,"description":"run the full merge and validation without publishing"},{"name":"overwrite","type":"boolean","required":false,"description":"replace an existing destination"},{"name":"allow-missing","type":"boolean","required":false,"description":"keep unresolved placeholders as literals instead of failing"},{"name":"json","type":"boolean","required":false,"description":"emit one office.output/1 JSON document"},{"name":"jsonl","type":"boolean","required":false,"description":"emit one office.output/1 line"}],"outputs":[{"name":"schema","type":"literal(office.template/1)","required":true,"description":"versioned template merge result schema"},{"name":"replaced","type":"number","required":true,"description":"placeholders substituted"},{"name":"missing","type":"array(finding)","required":true,"description":"unresolved keys with canonical locations (Sheet1!B2 or /docx/body/p[3]; bounded)"},{"name":"unused","type":"array(string)","required":true,"description":"data keys the template never used (bounded)"},{"name":"regions","type":"array(object)","required":true,"description":"per repeated region: name, source_location, records, replaced (bounded). XLSX clones a marked row through the atomic grid-bounded insert and refuses any formula-bearing workbook; DOCX clones a marked table row through a fail-closed element/attribute whitelist, stripping w14 paragraph ids. Empty when the data document declares no regions"},{"name":"transaction","type":"object","required":true,"description":"office.transaction/2 report; preservation is authoritative. XLSX: values land through literal cell setters (a leading = can never become a formula), formula and rich-text cells are refused contexts, whole-cell placeholders keep the data value's type. DOCX: byte-span run rewrites preserve all unrelated OOXML; values inherit the starting run's formatting; body, header, and footer stories are scanned"}],"output_modes":["human","json","jsonl"],"variants":[]}
      #|{"schema":"office.capability/2","fingerprint":"crc32:9dac1240","kind":"command","name":"annotate","summary":"Mutate DOCX comments through a strict annotation script","usage":"office annotate FILE SCRIPT.json --out OUT.docx [--dry-run] [--overwrite] [--json|--jsonl]","formats":["docx"],"aliases":[],"inputs":[{"name":"file","type":"path","required":true,"description":"existing .docx package (never modified in place)"},{"name":"script","type":"docx.annotation-batch/1-file","required":true,"description":"strict comment add/reply/resolve/unresolve script; body is plain paragraphs, anchors are /docx/body/p[K], references are tagged {label} or {comment_id}"},{"name":"out","type":"path","required":true,"description":"destination .docx; created atomically, refused when present unless --overwrite"},{"name":"dry-run","type":"boolean","required":false,"description":"run the full fold and validation without publishing"},{"name":"overwrite","type":"boolean","required":false,"description":"replace an existing destination"},{"name":"json","type":"boolean","required":false,"description":"emit one office.output/1 JSON document"},{"name":"jsonl","type":"boolean","required":false,"description":"emit one office.output/1 line"}],"outputs":[{"name":"schema","type":"literal(office.docx.annotation-batch/1)","required":true,"description":"versioned annotation-batch result schema"},{"name":"ops_applied","type":"number","required":true,"description":"comment ops folded"},{"name":"results","type":"array(object)","required":true,"description":"per op: op, comment_id, done, anchor + anchor_to (comment_add; anchor_to only on a paragraph range), target (reply/resolve/unresolve) — all bounded"},{"name":"labels","type":"array(object)","required":true,"description":"same-script label -> minted comment_id map"},{"name":"changed_parts","type":"array(string)","required":true,"description":"the union changed-part manifest across every op"},{"name":"transaction","type":"object","required":true,"description":"office.transaction/2 report; preservation is authoritative. Comment ops fold over the source-pinned D1 edit session one snapshot at a time; the document part gains only the narrow comment-anchor markers (the body text is never wholesale-rewritten), while the comment, content-type, and relationship parts are added or updated as the comments require; nothing is published on any refusal"}],"output_modes":["human","json","jsonl"],"variants":[]}
      #|{"schema":"office.capability/2","fingerprint":"crc32:9dac1240","kind":"command","name":"batch","summary":"Apply a strict operation script transactionally (XLSX mutate, DOCX fresh author)","usage":"office batch TARGET SCRIPT [--format xlsx|docx] [--out FILE] [--dry-run] [--overwrite] [--json]","formats":["docx"],"aliases":[],"inputs":[],"outputs":[],"output_modes":["human","json"],"variants":[{"name":"docx","usage":"office batch --format docx TARGET SCRIPT [--dry-run] [--overwrite] [--json]","result_schema":"office.docx.batch/1","inputs":[{"name":"target","type":"path","required":true,"description":"new .docx destination (fresh authoring; never mutates an existing file)"},{"name":"script","type":"docx.batch/2-file","required":true,"description":"strict bounded UTF-8 authoring script"},{"name":"dry-run","type":"boolean","required":false,"description":"validate without publishing"},{"name":"overwrite","type":"boolean","required":false,"description":"replace an existing destination"},{"name":"json","type":"boolean","required":false,"description":"emit office.output/1 JSON"}],"outputs":[{"name":"ops","type":"number","required":true,"description":"authoring ops applied"},{"name":"comments","type":"number","required":true,"description":"comment ops applied"},{"name":"footnotes","type":"number","required":true,"description":"footnote refs authored"},{"name":"endnotes","type":"number","required":true,"description":"endnote refs authored"},{"name":"transaction","type":"office.transaction/2","required":true,"description":"validation, preservation, and publication report"}],"constraints":["format=docx","preferred-schema=docx.batch/2","accepts-schema=docx.batch/1","output-extension=.docx","fresh-authoring-only","create-new-by-default","out-not-accepted","transactional-publication","bounded-candidate-package","comments-and-notes-require=docx.batch/2","max-image-bytes=8388608","max-total-image-bytes=33554432"],"actions":[],"output_modes":["human","json"]}]}
      #|{"schema":"office.capability/2","fingerprint":"crc32:9dac1240","kind":"command","name":"raw","summary":"Inventory, read, and atomically edit validated OOXML parts","usage":"office raw <list|read|replace|edit> ...","formats":["docx"],"aliases":[],"inputs":[{"name":"operation","type":"enum(list|read|replace|edit)","required":true,"description":"bounded raw OOXML operation"}],"outputs":[],"output_modes":["human","json","base64","file"],"variants":[{"name":"list","usage":"office raw list FILE [--json]","result_schema":"office.raw.inventory/1","inputs":[{"name":"file","type":"path","required":true,"description":"existing XLSX or DOCX package"},{"name":"json","type":"boolean","required":false,"description":"emit office.output/1 JSON"}],"outputs":[{"name":"format","type":"literal(docx)","required":true,"description":"structurally verified package format"},{"name":"part_count","type":"integer","required":true,"description":"number of inventoried package parts"},{"name":"parts","type":"array(object{name:path,content_type:string,kind:enum(xml|binary),size:integer,aliases:array(string)})","required":true,"description":"bounded canonical part inventory records"}],"constraints":[],"actions":[],"output_modes":["human","json"]},{"name":"read","usage":"office raw read FILE PART [--json] [--base64 | --output FILE]","result_schema":"office.raw.part/1","inputs":[{"name":"file","type":"path","required":true,"description":"existing XLSX or DOCX package"},{"name":"part","type":"part-selector","required":true,"description":"/name when unambiguous, alias:/name, or part:/name"},{"name":"json","type":"boolean","required":false,"description":"emit office.output/1 JSON"},{"name":"base64","type":"boolean","required":false,"description":"emit exact payload as base64"},{"name":"output","type":"path","required":false,"description":"create a file with the exact payload"}],"outputs":[{"name":"format","type":"literal(docx)","required":true,"description":"structurally verified package format"},{"name":"part","type":"object{name:path,content_type:string,kind:enum(xml|binary),size:integer,aliases:array(string)}","required":true,"description":"resolved package-part metadata"},{"name":"encoding","type":"enum(xml|base64|binary)","required":true,"description":"selected payload representation"},{"name":"content","type":"string","required":false,"description":"decoded XML text or base64 payload"},{"name":"output","type":"path","required":false,"description":"created payload destination"}],"constraints":["mutually-exclusive(base64,output)","binary-requires(base64|output)","output-create-mode(create-new)"],"actions":[],"output_modes":["human","json","base64","file"]},{"name":"replace","usage":"office raw replace FILE PART (--xml XML | --xml-file FILE) [--out FILE] [--dry-run] [--overwrite] [--json]","result_schema":"office.raw.result/1","inputs":[{"name":"file","type":"path","required":true,"description":"existing XLSX or DOCX package"},{"name":"part","type":"part-selector","required":true,"description":"existing XML part selector"},{"name":"xml","type":"utf8-xml","required":false,"description":"complete replacement XML document"},{"name":"xml-file","type":"path","required":false,"description":"bounded UTF-8 replacement XML file"},{"name":"out","type":"path","required":false,"description":"separate destination with the same .docx or .xlsx extension as the input"},{"name":"dry-run","type":"boolean","required":false,"description":"validate without publishing"},{"name":"overwrite","type":"boolean","required":false,"description":"replace an existing separate destination"},{"name":"json","type":"boolean","required":false,"description":"emit office.output/1 JSON"}],"outputs":[{"name":"change","type":"office.raw.change/1","required":true,"description":"validated raw mutation summary"},{"name":"transaction","type":"office.transaction/2","required":true,"description":"transaction validation and publication report"}],"constraints":["exactly-one(xml,xml-file)","overwrite-requires(out)","out-extension-must-match-input-format","transactional-publication"],"actions":[],"output_modes":["human","json"]},{"name":"edit","usage":"office raw edit FILE PART --path PATH --action ACTION [action arguments] [--namespace PREFIX=URI]... [--all] [--out FILE] [--dry-run] [--overwrite] [--json]","result_schema":"office.raw.result/1","inputs":[{"name":"file","type":"path","required":true,"description":"existing XLSX or DOCX package"},{"name":"part","type":"part-selector","required":true,"description":"existing XML part selector"},{"name":"path","type":"office.raw.path/1","required":true,"description":"bounded namespace-aware element selector"},{"name":"action","type":"enum(append|prepend|insert-before|insert-after|replace|remove|set-attribute)","required":true,"description":"bounded edit action"},{"name":"xml","type":"utf8-xml-element","required":false,"description":"one self-contained XML element"},{"name":"xml-file","type":"path","required":false,"description":"bounded UTF-8 XML element file"},{"name":"attribute","type":"qname","required":false,"description":"set-attribute target name"},{"name":"value","type":"string","required":false,"description":"set-attribute exact decoded value"},{"name":"namespace","type":"array(PREFIX=URI)","required":false,"description":"repeatable selector namespace overrides"},{"name":"all","type":"boolean","required":false,"description":"allow multiple bounded matches"},{"name":"out","type":"path","required":false,"description":"separate destination with the same .docx or .xlsx extension as the input"},{"name":"dry-run","type":"boolean","required":false,"description":"validate without publishing"},{"name":"overwrite","type":"boolean","required":false,"description":"replace an existing separate destination"},{"name":"json","type":"boolean","required":false,"description":"emit office.output/1 JSON"}],"outputs":[{"name":"change","type":"office.raw.change/1","required":true,"description":"validated raw mutation summary"},{"name":"transaction","type":"office.transaction/2","required":true,"description":"transaction validation and publication report"}],"constraints":["mutually-exclusive(xml,xml-file)","element-actions-require(exactly-one(xml,xml-file))","set-attribute-requires(attribute,value)","remove-forbids(xml,xml-file,attribute,value)","overwrite-requires(out)","flag-looking-values-require-attached-syntax","out-extension-must-match-input-format","transactional-publication"],"actions":[{"name":"append","requires":["exactly-one(xml,xml-file)"],"forbids":["attribute","value"],"restrictions":[]},{"name":"prepend","requires":["exactly-one(xml,xml-file)"],"forbids":["attribute","value"],"restrictions":[]},{"name":"insert-before","requires":["exactly-one(xml,xml-file)"],"forbids":["attribute","value"],"restrictions":["path-must-not-select-document-element"]},{"name":"insert-after","requires":["exactly-one(xml,xml-file)"],"forbids":["attribute","value"],"restrictions":["path-must-not-select-document-element"]},{"name":"replace","requires":["exactly-one(xml,xml-file)"],"forbids":["attribute","value"],"restrictions":[]},{"name":"remove","requires":[],"forbids":["xml","xml-file","attribute","value"],"restrictions":["path-must-not-select-document-element"]},{"name":"set-attribute","requires":["attribute","value"],"forbids":["xml","xml-file"],"restrictions":[]}],"output_modes":["human","json"]}]}
    ),
  )
}

///|
test "capability fingerprint and inventory ordering are deterministic" {
  inspect(
    @office.capability_fingerprint(),
    content=(
      #|crc32:9dac1240
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
      #|{"schema":"office.capabilities/2","fingerprint":"crc32:9dac1240","records":[{"schema":"office.capability/2","fingerprint":"crc32:9dac1240","kind":"command","name":"identify","summary":"Identify a structurally valid XLSX or DOCX package","usage":"office identify <file> [--json]","formats":["docx"],"aliases":[],"inputs":[{"name":"file","type":"path","required":true,"description":"path to an XLSX or DOCX package"},{"name":"json","type":"boolean","required":false,"description":"emit one office.output/1 JSON document"}],"outputs":[{"name":"file","type":"path","required":true,"description":"the input path exactly as supplied"},{"name":"format","type":"literal(docx)","required":true,"description":"the structurally verified package format"}],"output_modes":["human","json"],"variants":[]}],"format":"docx","operation":"identify"}
    ),
  )
}
