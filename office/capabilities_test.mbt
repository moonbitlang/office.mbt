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
test "capability formats distinguish resolved DOCX reads from XLSX syntax" {
  let formats = @office.capability_formats()
  assert_eq(formats.length(), 2)
  assert_eq(formats[0].selector.schema, "office.selector/1")
  assert_eq(formats[0].selector.root, "/docx")
  assert_eq(formats[1].selector.root, "/xlsx")
  assert_eq(formats[0].selector.status, "read-resolved")
  assert_true(formats[0].selector.description.contains("bounded canonical"))
  assert_eq(formats[1].selector.status, "syntax-only")
  assert_true(formats[1].selector.description.contains("not implemented"))
  assert_true(formats[0].selector.examples.length() >= 2)
  assert_true(formats[1].selector.examples.length() >= 2)
}

///|
test "DOCX read capabilities publish every enforced bound and result schema" {
  for
    case in [
      ("outline", @office.SCHEMA_DOCX_OUTLINE),
      ("get", @office.SCHEMA_DOCX_ELEMENT),
      ("text", @office.SCHEMA_DOCX_TEXT),
      ("query", @office.SCHEMA_DOCX_QUERY),
    ] {
    let (name, schema) = case
    guard @office.find_capability_command(name) is Some(command) else {
      fail("missing command: \{name}")
    }
    assert_eq(command.formats, ["docx"])
    assert_true(command.inputs.any(field => field.name == "max-elements"))
    assert_true(command.inputs.any(field => field.name == "max-output-chars"))
    assert_true(
      command.outputs.any(field => {
        field.name == "schema" && field.type_name.contains(schema)
      }),
    )
  }
  guard @office.find_capability_command("query") is Some(query) else {
    fail("missing query command")
  }
  assert_true(query.inputs.any(field => field.name == "property"))
  assert_true(query.usage.contains("--ignore-case"))
  assert_false(query.usage.to_lower().contains("regex"))
}

///|
test "capability registry format filters remain truthful" {
  let records = @office.capability_records(format=Docx)
    .map(record => record.stringify())
    .join("\n")
  inspect(
    records,
    content=(
      #|{"schema":"office.capability/2","fingerprint":"crc32:31aeb371","kind":"format","name":"docx","aliases":["word"],"description":"WordprocessingML documents","selector":{"schema":"office.selector/1","root":"/docx","status":"read-resolved","examples":["/docx/body/p[1]/r[2]","/docx/comments/comment[id=\"7\"]"],"description":"bounded canonical resolution for outline, get, text, and declared query predicates"}}
      #|{"schema":"office.capability/2","fingerprint":"crc32:31aeb371","kind":"command","name":"identify","summary":"Identify a structurally valid XLSX or DOCX package","usage":"office identify <file> [--json]","formats":["docx","xlsx"],"aliases":[],"inputs":[{"name":"file","type":"path","required":true,"description":"path to an XLSX or DOCX package"},{"name":"json","type":"boolean","required":false,"description":"emit one office.output/1 JSON document"}],"outputs":[{"name":"file","type":"path","required":true,"description":"the input path exactly as supplied"},{"name":"format","type":"enum(docx|xlsx)","required":true,"description":"the structurally verified package format"}],"output_modes":["human","json"],"variants":[]}
      #|{"schema":"office.capability/2","fingerprint":"crc32:31aeb371","kind":"command","name":"outline","summary":"Summarize bounded DOCX structure using canonical selectors","usage":"office outline FILE [--max-elements N] [--max-output-chars N] [--json]","formats":["docx"],"aliases":[],"inputs":[{"name":"file","type":"path","required":true,"description":"existing DOCX package"},{"name":"max-elements","type":"integer(1..200000)","required":false,"description":"projection scan ceiling; default 50000"},{"name":"max-output-chars","type":"integer(1..4194304)","required":false,"description":"successful stdout ceiling including trailing LF; failure envelopes are separate; default 1048576"},{"name":"json","type":"boolean","required":false,"description":"emit office.output/1 JSON"}],"outputs":[{"name":"schema","type":"literal(office.docx.outline/1)","required":true,"description":"versioned result schema"},{"name":"file","type":"path","required":true,"description":"the input path exactly as supplied"},{"name":"format","type":"literal(docx)","required":true,"description":"resolved document format"},{"name":"scanned_elements","type":"integer","required":true,"description":"number of elements in the bounded projection"},{"name":"counts","type":"object","required":true,"description":"deterministic structural counts across every DOCX story"},{"name":"stories","type":"array","required":true,"description":"body, header, footer, note, endnote, and comment story roots"},{"name":"headings","type":"array","required":true,"description":"bounded heading previews with canonical paths"},{"name":"styles_in_use","type":"array","required":true,"description":"deduplicated styles referenced by projected elements"},{"name":"images","type":"array","required":true,"description":"image metadata with canonical paths and byte counts"},{"name":"sections","type":"array","required":true,"description":"section boundaries and effective header/footer references"},{"name":"diagnostics","type":"array","required":true,"description":"reader and annotation source diagnostics"}],"output_modes":["human","json"],"variants":[]}
      #|{"schema":"office.capability/2","fingerprint":"crc32:31aeb371","kind":"command","name":"get","summary":"Resolve one canonical DOCX selector","usage":"office get FILE SELECTOR [--max-elements N] [--max-output-chars N] [--json]","formats":["docx"],"aliases":[],"inputs":[{"name":"file","type":"path","required":true,"description":"existing DOCX package"},{"name":"selector","type":"office.selector/1","required":true,"description":"canonical /docx selector"},{"name":"max-elements","type":"integer(1..200000)","required":false,"description":"projection scan ceiling; default 50000"},{"name":"max-output-chars","type":"integer(1..4194304)","required":false,"description":"successful stdout ceiling including trailing LF; failure envelopes are separate; default 1048576"},{"name":"json","type":"boolean","required":false,"description":"emit office.output/1 JSON"}],"outputs":[{"name":"schema","type":"literal(office.docx.element/1)","required":true,"description":"versioned result schema"},{"name":"file","type":"path","required":true,"description":"the input path exactly as supplied"},{"name":"format","type":"literal(docx)","required":true,"description":"resolved document format"},{"name":"path","type":"office.selector/1","required":true,"description":"resolved canonical path"},{"name":"kind","type":"string","required":true,"description":"resolved story, annotation, or element kind"},{"name":"role","type":"enum(story-root|annotation-collection|annotation-item|element)","required":true,"description":"projection role"},{"name":"stability","type":"enum(stable|snapshot-relative)","required":true,"description":"selector stability classification"},{"name":"source","type":"object","required":true,"description":"physical story source metadata"},{"name":"parent","type":"office.selector/1","required":false,"description":"canonical parent path; absent for projection roots"},{"name":"id","type":"string","required":false,"description":"annotation id when the resolved item carries one"},{"name":"children","type":"array","required":true,"description":"addressable direct children with canonical paths"},{"name":"properties","type":"object","required":true,"description":"declared formatting and element summary"},{"name":"metadata","type":"object","required":true,"description":"role-specific annotation or collection metadata"},{"name":"text","type":"string","required":true,"description":"bounded raw text projection"}],"output_modes":["human","json"],"variants":[]}
      #|{"schema":"office.capability/2","fingerprint":"crc32:31aeb371","kind":"command","name":"text","summary":"Extract bounded path-tagged DOCX paragraph text","usage":"office text FILE [--under SELECTOR] [--offset N] [--limit N] [--max-elements N] [--max-output-chars N] [--json]","formats":["docx"],"aliases":[],"inputs":[{"name":"file","type":"path","required":true,"description":"existing DOCX package"},{"name":"under","type":"office.selector/1","required":false,"description":"optional canonical subtree root"},{"name":"offset","type":"integer(0..200000)","required":false,"description":"zero-based paragraph offset; default 0"},{"name":"limit","type":"integer(0..10000)","required":false,"description":"maximum returned paragraphs; default 2000"},{"name":"max-elements","type":"integer(1..200000)","required":false,"description":"projection scan ceiling; default 50000"},{"name":"max-output-chars","type":"integer(1..4194304)","required":false,"description":"successful stdout ceiling including trailing LF; failure envelopes are separate; default 1048576"},{"name":"json","type":"boolean","required":false,"description":"emit office.output/1 JSON"}],"outputs":[{"name":"schema","type":"literal(office.docx.text/1)","required":true,"description":"versioned result schema"},{"name":"file","type":"path","required":true,"description":"the input path exactly as supplied"},{"name":"format","type":"literal(docx)","required":true,"description":"resolved document format"},{"name":"entries","type":"array(object{path,text,stability})","required":true,"description":"paragraphs in deterministic document order"},{"name":"matched_total","type":"integer","required":true,"description":"complete bounded-scan paragraph count"},{"name":"returned","type":"integer","required":true,"description":"number of returned entries"},{"name":"truncated","type":"boolean","required":true,"description":"whether pagination omitted later matches"},{"name":"offset","type":"integer","required":true,"description":"applied zero-based match offset"},{"name":"limit","type":"integer","required":true,"description":"applied page-size ceiling"},{"name":"scanned_elements","type":"integer","required":true,"description":"number of elements in the bounded projection"},{"name":"under","type":"office.selector/1","required":false,"description":"resolved subtree root when one was requested"}],"output_modes":["human","json"],"variants":[]}
      #|{"schema":"office.capability/2","fingerprint":"crc32:31aeb371","kind":"command","name":"query","summary":"Run bounded deterministic predicates over DOCX elements","usage":"office query FILE [--under SELECTOR] [--kind KIND] [--text TEXT] [--id ID] [--property NAME=VALUE]... [--ignore-case] [--offset N] [--limit N] [--max-elements N] [--max-output-chars N] [--json]","formats":["docx"],"aliases":[],"inputs":[{"name":"file","type":"path","required":true,"description":"existing DOCX package"},{"name":"under","type":"office.selector/1","required":false,"description":"optional canonical subtree root"},{"name":"kind","type":"enum(body|header|footer|footnotes|endnotes|comments|note|comment|p|r|tbl|tr|tc|hyperlink|image)","required":false,"description":"exact kind; documented long-name aliases normalize before matching"},{"name":"text","type":"literal-string(1..1048576 chars)","required":false,"description":"literal substring predicate; regular expressions are not accepted"},{"name":"id","type":"string(1..1048576 chars)","required":false,"description":"exact annotation id predicate, including ids outside selector path limits"},{"name":"property","type":"array(NAME=VALUE)","required":false,"description":"up to 16 exact predicates with values capped at 1048576 characters"},{"name":"ignore-case","type":"boolean","required":false,"description":"locale-independent Unicode simple-case --text matching"},{"name":"offset","type":"integer(0..200000)","required":false,"description":"zero-based match offset; default 0"},{"name":"limit","type":"integer(0..1000)","required":false,"description":"maximum returned matches; default 100"},{"name":"max-elements","type":"integer(1..200000)","required":false,"description":"projection scan ceiling; default 50000"},{"name":"max-output-chars","type":"integer(1..4194304)","required":false,"description":"successful stdout ceiling including trailing LF; failure envelopes are separate; default 1048576"},{"name":"json","type":"boolean","required":false,"description":"emit office.output/1 JSON"}],"outputs":[{"name":"schema","type":"literal(office.docx.query/1)","required":true,"description":"versioned result schema"},{"name":"file","type":"path","required":true,"description":"the input path exactly as supplied"},{"name":"format","type":"literal(docx)","required":true,"description":"resolved document format"},{"name":"filters","type":"object","required":true,"description":"normalized predicates applied by this query"},{"name":"matches","type":"array","required":true,"description":"deterministic document-order match records"},{"name":"matched_total","type":"integer","required":true,"description":"complete bounded-scan match count"},{"name":"returned","type":"integer","required":true,"description":"number of returned matches"},{"name":"truncated","type":"boolean","required":true,"description":"whether pagination omitted later matches"},{"name":"offset","type":"integer","required":true,"description":"applied zero-based match offset"},{"name":"limit","type":"integer","required":true,"description":"applied page-size ceiling"},{"name":"scanned_elements","type":"integer","required":true,"description":"number of elements in the bounded projection"},{"name":"under","type":"office.selector/1","required":false,"description":"resolved subtree root when one was requested"}],"output_modes":["human","json"],"variants":[]}
      #|{"schema":"office.capability/2","fingerprint":"crc32:31aeb371","kind":"command","name":"raw","summary":"Inventory, read, and atomically edit validated OOXML parts","usage":"office raw <list|read|replace|edit> ...","formats":["docx","xlsx"],"aliases":[],"inputs":[{"name":"operation","type":"enum(list|read|replace|edit)","required":true,"description":"bounded raw OOXML operation"}],"outputs":[],"output_modes":["human","json","base64","file"],"variants":[{"name":"list","usage":"office raw list FILE [--json]","result_schema":"office.raw.inventory/1","inputs":[{"name":"file","type":"path","required":true,"description":"existing XLSX or DOCX package"},{"name":"json","type":"boolean","required":false,"description":"emit office.output/1 JSON"}],"outputs":[{"name":"format","type":"enum(docx|xlsx)","required":true,"description":"structurally verified package format"},{"name":"part_count","type":"integer","required":true,"description":"number of inventoried package parts"},{"name":"parts","type":"array(object{name:path,content_type:string,kind:enum(xml|binary),size:integer,aliases:array(string)})","required":true,"description":"bounded canonical part inventory records"}],"constraints":[],"actions":[],"output_modes":["human","json"]},{"name":"read","usage":"office raw read FILE PART [--json] [--base64 | --output FILE]","result_schema":"office.raw.part/1","inputs":[{"name":"file","type":"path","required":true,"description":"existing XLSX or DOCX package"},{"name":"part","type":"part-selector","required":true,"description":"/name when unambiguous, alias:/name, or part:/name"},{"name":"json","type":"boolean","required":false,"description":"emit office.output/1 JSON"},{"name":"base64","type":"boolean","required":false,"description":"emit exact payload as base64"},{"name":"output","type":"path","required":false,"description":"create a file with the exact payload"}],"outputs":[{"name":"format","type":"enum(docx|xlsx)","required":true,"description":"structurally verified package format"},{"name":"part","type":"object{name:path,content_type:string,kind:enum(xml|binary),size:integer,aliases:array(string)}","required":true,"description":"resolved package-part metadata"},{"name":"encoding","type":"enum(xml|base64|binary)","required":true,"description":"selected payload representation"},{"name":"content","type":"string","required":false,"description":"decoded XML text or base64 payload"},{"name":"output","type":"path","required":false,"description":"created payload destination"}],"constraints":["mutually-exclusive(base64,output)","binary-requires(base64|output)","output-create-mode(create-new)"],"actions":[],"output_modes":["human","json","base64","file"]},{"name":"replace","usage":"office raw replace FILE PART (--xml XML | --xml-file FILE) [--out FILE] [--dry-run] [--overwrite] [--json]","result_schema":"office.raw.result/1","inputs":[{"name":"file","type":"path","required":true,"description":"existing XLSX or DOCX package"},{"name":"part","type":"part-selector","required":true,"description":"existing XML part selector"},{"name":"xml","type":"utf8-xml","required":false,"description":"complete replacement XML document"},{"name":"xml-file","type":"path","required":false,"description":"bounded UTF-8 replacement XML file"},{"name":"out","type":"path","required":false,"description":"separate destination with the same .docx or .xlsx extension as the input"},{"name":"dry-run","type":"boolean","required":false,"description":"validate without publishing"},{"name":"overwrite","type":"boolean","required":false,"description":"replace an existing separate destination"},{"name":"json","type":"boolean","required":false,"description":"emit office.output/1 JSON"}],"outputs":[{"name":"change","type":"office.raw.change/1","required":true,"description":"validated raw mutation summary"},{"name":"transaction","type":"office.transaction/1","required":true,"description":"transaction validation and publication report"}],"constraints":["exactly-one(xml,xml-file)","overwrite-requires(out)","out-extension-must-match-input-format","transactional-publication"],"actions":[],"output_modes":["human","json"]},{"name":"edit","usage":"office raw edit FILE PART --path PATH --action ACTION [action arguments] [--namespace PREFIX=URI]... [--all] [--out FILE] [--dry-run] [--overwrite] [--json]","result_schema":"office.raw.result/1","inputs":[{"name":"file","type":"path","required":true,"description":"existing XLSX or DOCX package"},{"name":"part","type":"part-selector","required":true,"description":"existing XML part selector"},{"name":"path","type":"office.raw.path/1","required":true,"description":"bounded namespace-aware element selector"},{"name":"action","type":"enum(append|prepend|insert-before|insert-after|replace|remove|set-attribute)","required":true,"description":"bounded edit action"},{"name":"xml","type":"utf8-xml-element","required":false,"description":"one self-contained XML element"},{"name":"xml-file","type":"path","required":false,"description":"bounded UTF-8 XML element file"},{"name":"attribute","type":"qname","required":false,"description":"set-attribute target name"},{"name":"value","type":"string","required":false,"description":"set-attribute exact decoded value"},{"name":"namespace","type":"array(PREFIX=URI)","required":false,"description":"repeatable selector namespace overrides"},{"name":"all","type":"boolean","required":false,"description":"allow multiple bounded matches"},{"name":"out","type":"path","required":false,"description":"separate destination with the same .docx or .xlsx extension as the input"},{"name":"dry-run","type":"boolean","required":false,"description":"validate without publishing"},{"name":"overwrite","type":"boolean","required":false,"description":"replace an existing separate destination"},{"name":"json","type":"boolean","required":false,"description":"emit office.output/1 JSON"}],"outputs":[{"name":"change","type":"office.raw.change/1","required":true,"description":"validated raw mutation summary"},{"name":"transaction","type":"office.transaction/1","required":true,"description":"transaction validation and publication report"}],"constraints":["mutually-exclusive(xml,xml-file)","element-actions-require(exactly-one(xml,xml-file))","set-attribute-requires(attribute,value)","remove-forbids(xml,xml-file,attribute,value)","overwrite-requires(out)","flag-looking-values-require-attached-syntax","out-extension-must-match-input-format","transactional-publication"],"actions":[{"name":"append","requires":["exactly-one(xml,xml-file)"],"forbids":["attribute","value"],"restrictions":[]},{"name":"prepend","requires":["exactly-one(xml,xml-file)"],"forbids":["attribute","value"],"restrictions":[]},{"name":"insert-before","requires":["exactly-one(xml,xml-file)"],"forbids":["attribute","value"],"restrictions":["path-must-not-select-document-element"]},{"name":"insert-after","requires":["exactly-one(xml,xml-file)"],"forbids":["attribute","value"],"restrictions":["path-must-not-select-document-element"]},{"name":"replace","requires":["exactly-one(xml,xml-file)"],"forbids":["attribute","value"],"restrictions":[]},{"name":"remove","requires":[],"forbids":["xml","xml-file","attribute","value"],"restrictions":["path-must-not-select-document-element"]},{"name":"set-attribute","requires":["attribute","value"],"forbids":["xml","xml-file"],"restrictions":[]}],"output_modes":["human","json"]}]}
    ),
  )
}

///|
test "capability fingerprint and inventory ordering are deterministic" {
  inspect(
    @office.capability_fingerprint(),
    content=(
      #|crc32:31aeb371
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
      #|{"schema":"office.capabilities/2","fingerprint":"crc32:31aeb371","records":[{"schema":"office.capability/2","fingerprint":"crc32:31aeb371","kind":"command","name":"identify","summary":"Identify a structurally valid XLSX or DOCX package","usage":"office identify <file> [--json]","formats":["docx","xlsx"],"aliases":[],"inputs":[{"name":"file","type":"path","required":true,"description":"path to an XLSX or DOCX package"},{"name":"json","type":"boolean","required":false,"description":"emit one office.output/1 JSON document"}],"outputs":[{"name":"file","type":"path","required":true,"description":"the input path exactly as supplied"},{"name":"format","type":"enum(docx|xlsx)","required":true,"description":"the structurally verified package format"}],"output_modes":["human","json"],"variants":[]}],"format":"docx","operation":"identify"}
    ),
  )
}
