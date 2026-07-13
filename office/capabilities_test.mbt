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
      #|{"schema":"office.capability/1","fingerprint":"crc32:aa4ea0be","kind":"format","name":"docx","aliases":["word"],"description":"WordprocessingML documents","selector":{"schema":"office.selector/1","root":"/docx","status":"syntax-only","examples":["/docx/body/p[1]/r[2]","/docx/comments/comment[id=\"7\"]"],"description":"bounded parse/render only; package resolution is not implemented"}}
      #|{"schema":"office.capability/1","fingerprint":"crc32:aa4ea0be","kind":"command","name":"identify","summary":"Identify a structurally valid XLSX or DOCX package","usage":"office identify <file> [--json]","formats":["docx","xlsx"],"aliases":[],"inputs":[{"name":"file","type":"path","required":true,"description":"path to an XLSX or DOCX package"},{"name":"json","type":"boolean","required":false,"description":"emit one office.output/1 JSON document"}],"outputs":[{"name":"file","type":"path","required":true,"description":"the input path exactly as supplied"},{"name":"format","type":"enum(docx|xlsx)","required":true,"description":"the structurally verified package format"}],"output_modes":["human","json"]}
      #|{"schema":"office.capability/1","fingerprint":"crc32:aa4ea0be","kind":"command","name":"raw","summary":"Inventory, read, and atomically edit validated OOXML parts","usage":"office raw <list|read|replace|edit> ...","formats":["docx","xlsx"],"aliases":[],"inputs":[{"name":"operation","type":"enum(list|read|replace|edit)","required":true,"description":"bounded raw OOXML operation"},{"name":"file","type":"path","required":true,"description":"path to an existing XLSX or DOCX package"},{"name":"part","type":"alias|absolute-part","required":false,"description":"relationship-derived alias or absolute package part"},{"name":"path","type":"office.raw.path/1","required":false,"description":"bounded namespace-aware element selector"},{"name":"json","type":"boolean","required":false,"description":"emit one office.output/1 JSON document"}],"outputs":[{"name":"inventory","type":"office.raw.inventory/1","required":false,"description":"canonical package-part inventory"},{"name":"part","type":"office.raw.part/1","required":false,"description":"resolved part metadata and explicitly selected content"},{"name":"change","type":"office.raw.result/1","required":false,"description":"validated mutation and transaction report"}],"output_modes":["human","json","base64","file"]}
    ),
  )
}

///|
test "capability fingerprint and inventory ordering are deterministic" {
  inspect(
    @office.capability_fingerprint(),
    content=(
      #|crc32:aa4ea0be
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
      #|{"schema":"office.capabilities/1","fingerprint":"crc32:aa4ea0be","records":[{"schema":"office.capability/1","fingerprint":"crc32:aa4ea0be","kind":"command","name":"identify","summary":"Identify a structurally valid XLSX or DOCX package","usage":"office identify <file> [--json]","formats":["docx","xlsx"],"aliases":[],"inputs":[{"name":"file","type":"path","required":true,"description":"path to an XLSX or DOCX package"},{"name":"json","type":"boolean","required":false,"description":"emit one office.output/1 JSON document"}],"outputs":[{"name":"file","type":"path","required":true,"description":"the input path exactly as supplied"},{"name":"format","type":"enum(docx|xlsx)","required":true,"description":"the structurally verified package format"}],"output_modes":["human","json"]}],"format":"docx","operation":"identify"}
    ),
  )
}
