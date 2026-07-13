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
      #|help,identify,raw
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
  assert_false(inventory.contains("preview"))
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
}

///|
test "capability formats expose selector syntax without claiming resolution" {
  let formats = @office.capability_formats()
  assert_eq(formats.length(), 2)
  assert_eq(formats[0].selector.schema, "office.selector/1")
  assert_eq(formats[0].selector.root, "/docx")
  assert_eq(formats[1].selector.root, "/xlsx")
  for format in formats {
    assert_eq(format.selector.status, "syntax-only")
    assert_true(format.selector.description.contains("not implemented"))
    assert_true(format.selector.examples.length() >= 2)
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
      #|{"schema":"office.capability/1","fingerprint":"crc32:a38a3f42","kind":"format","name":"docx","aliases":["word"],"description":"WordprocessingML documents","selector":{"schema":"office.selector/1","root":"/docx","status":"syntax-only","examples":["/docx/body/p[1]/r[2]","/docx/comments/comment[id=\"7\"]"],"description":"bounded parse/render only; package resolution is not implemented"}}
      #|{"schema":"office.capability/1","fingerprint":"crc32:a38a3f42","kind":"command","name":"identify","summary":"Identify a structurally valid XLSX or DOCX package","usage":"office identify <file> [--json]","formats":["docx","xlsx"],"aliases":[],"inputs":[{"name":"file","type":"path","required":true,"description":"path to an XLSX or DOCX package"},{"name":"json","type":"boolean","required":false,"description":"emit one office.output/1 JSON document"}],"outputs":[{"name":"file","type":"path","required":true,"description":"the input path exactly as supplied"},{"name":"format","type":"enum(docx|xlsx)","required":true,"description":"the structurally verified package format"}],"output_modes":["human","json"],"variants":[]}
      #|{"schema":"office.capability/1","fingerprint":"crc32:a38a3f42","kind":"command","name":"raw","summary":"Inventory, read, and atomically edit validated OOXML parts","usage":"office raw <list|read|replace|edit> ...","formats":["docx","xlsx"],"aliases":[],"inputs":[{"name":"operation","type":"enum(list|read|replace|edit)","required":true,"description":"bounded raw OOXML operation"}],"outputs":[{"name":"inventory","type":"office.raw.inventory/1","required":false,"description":"canonical package-part inventory"},{"name":"part","type":"office.raw.part/1","required":false,"description":"resolved part metadata and explicitly selected content"},{"name":"change","type":"office.raw.result/1","required":false,"description":"validated mutation and transaction report"}],"output_modes":["human","json","base64","file"],"variants":[{"name":"list","usage":"office raw list FILE [--json]","inputs":[{"name":"file","type":"path","required":true,"description":"existing XLSX or DOCX package"},{"name":"json","type":"boolean","required":false,"description":"emit office.output/1 JSON"}],"outputs":[{"name":"inventory","type":"office.raw.inventory/1","required":true,"description":"bounded canonical part inventory"}],"constraints":[],"output_modes":["human","json"]},{"name":"read","usage":"office raw read FILE PART [--json] [--base64 | --output FILE]","inputs":[{"name":"file","type":"path","required":true,"description":"existing XLSX or DOCX package"},{"name":"part","type":"part-selector","required":true,"description":"/name when unambiguous, alias:/name, or part:/name"},{"name":"json","type":"boolean","required":false,"description":"emit office.output/1 JSON"},{"name":"base64","type":"boolean","required":false,"description":"emit exact payload as base64"},{"name":"output","type":"path","required":false,"description":"create a file with the exact payload"}],"outputs":[{"name":"part","type":"office.raw.part/1","required":true,"description":"resolved metadata and selected content"}],"constraints":["mutually-exclusive(base64,output)","binary-requires(base64|output)","output-create-mode(create-new)"],"output_modes":["human","json","base64","file"]},{"name":"replace","usage":"office raw replace FILE PART (--xml XML | --xml-file FILE) [--out FILE] [--dry-run] [--overwrite] [--json]","inputs":[{"name":"file","type":"path","required":true,"description":"existing XLSX or DOCX package"},{"name":"part","type":"part-selector","required":true,"description":"existing XML part selector"},{"name":"xml","type":"utf8-xml","required":false,"description":"complete replacement XML document"},{"name":"xml-file","type":"path","required":false,"description":"bounded UTF-8 replacement XML file"},{"name":"out","type":"path","required":false,"description":"separate transaction destination"},{"name":"dry-run","type":"boolean","required":false,"description":"validate without publishing"},{"name":"overwrite","type":"boolean","required":false,"description":"replace an existing separate destination"},{"name":"json","type":"boolean","required":false,"description":"emit office.output/1 JSON"}],"outputs":[{"name":"change","type":"office.raw.result/1","required":true,"description":"validated mutation and transaction report"}],"constraints":["exactly-one(xml,xml-file)","overwrite-requires(out)","transactional-publication"],"output_modes":["human","json"]},{"name":"edit","usage":"office raw edit FILE PART --path PATH --action ACTION [action arguments] [--namespace PREFIX=URI]... [--all] [--out FILE] [--dry-run] [--overwrite] [--json]","inputs":[{"name":"file","type":"path","required":true,"description":"existing XLSX or DOCX package"},{"name":"part","type":"part-selector","required":true,"description":"existing XML part selector"},{"name":"path","type":"office.raw.path/1","required":true,"description":"bounded namespace-aware element selector"},{"name":"action","type":"enum(append|prepend|insert-before|insert-after|replace|remove|set-attribute)","required":true,"description":"bounded edit action"},{"name":"xml","type":"utf8-xml-element","required":false,"description":"one self-contained XML element"},{"name":"xml-file","type":"path","required":false,"description":"bounded UTF-8 XML element file"},{"name":"attribute","type":"qname","required":false,"description":"set-attribute target name"},{"name":"value","type":"string","required":false,"description":"set-attribute exact decoded value"},{"name":"namespace","type":"array(PREFIX=URI)","required":false,"description":"repeatable selector namespace overrides"},{"name":"all","type":"boolean","required":false,"description":"allow multiple bounded matches"},{"name":"out","type":"path","required":false,"description":"separate transaction destination"},{"name":"dry-run","type":"boolean","required":false,"description":"validate without publishing"},{"name":"overwrite","type":"boolean","required":false,"description":"replace an existing separate destination"},{"name":"json","type":"boolean","required":false,"description":"emit office.output/1 JSON"}],"outputs":[{"name":"change","type":"office.raw.result/1","required":true,"description":"validated mutation and transaction report"}],"constraints":["mutually-exclusive(xml,xml-file)","element-actions-require(exactly-one(xml,xml-file))","set-attribute-requires(attribute,value)","remove-forbids(xml,xml-file,attribute,value)","overwrite-requires(out)","flag-looking-values-require-attached-syntax","transactional-publication"],"output_modes":["human","json"]}]}
    ),
  )
}

///|
test "capability fingerprint and inventory ordering are deterministic" {
  inspect(
    @office.capability_fingerprint(),
    content=(
      #|crc32:a38a3f42
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
      #|{"schema":"office.capabilities/1","fingerprint":"crc32:a38a3f42","records":[{"schema":"office.capability/1","fingerprint":"crc32:a38a3f42","kind":"command","name":"identify","summary":"Identify a structurally valid XLSX or DOCX package","usage":"office identify <file> [--json]","formats":["docx","xlsx"],"aliases":[],"inputs":[{"name":"file","type":"path","required":true,"description":"path to an XLSX or DOCX package"},{"name":"json","type":"boolean","required":false,"description":"emit one office.output/1 JSON document"}],"outputs":[{"name":"file","type":"path","required":true,"description":"the input path exactly as supplied"},{"name":"format","type":"enum(docx|xlsx)","required":true,"description":"the structurally verified package format"}],"output_modes":["human","json"],"variants":[]}],"format":"docx","operation":"identify"}
    ),
  )
}
