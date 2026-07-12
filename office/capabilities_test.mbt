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
  let names = @office.capability_commands().map(command => command.name)
  inspect(names.join(","), content="help,identify")
  let inventory = @office.capabilities_data().stringify()
  assert_false(inventory.contains("ppt"))
  assert_false(inventory.contains("mcp"))
  assert_false(inventory.contains("watch"))
  assert_false(inventory.contains("preview"))
  assert_false(inventory.contains("mutation"))
}

///|
test "capability registry format filters remain truthful" {
  let records = @office.capability_records(format=Docx)
    .map(record => record.stringify())
    .join("\n")
  inspect(
    records,
    content=(
      #|{"schema":"office.capability/1","fingerprint":"crc32:6ba619b7","kind":"format","name":"docx","aliases":["word"],"description":"WordprocessingML documents"}
      #|{"schema":"office.capability/1","fingerprint":"crc32:6ba619b7","kind":"command","name":"identify","summary":"Identify a structurally valid XLSX or DOCX package","usage":"office identify <file> [--json]","formats":["docx","xlsx"],"aliases":[],"inputs":[{"name":"file","type":"path","required":true,"description":"path to an XLSX or DOCX package"},{"name":"json","type":"boolean","required":false,"description":"emit one office.output/1 JSON document"}],"outputs":[{"name":"file","type":"path","required":true,"description":"the input path exactly as supplied"},{"name":"format","type":"enum(docx|xlsx)","required":true,"description":"the structurally verified package format"}],"output_modes":["human","json"]}
    ),
  )
}

///|
test "capability fingerprint and inventory ordering are deterministic" {
  inspect(
    @office.capability_fingerprint(),
    content=(
      #|crc32:6ba619b7
    ),
  )
  let first = @office.capabilities_data().stringify()
  let second = @office.capabilities_data().stringify()
  assert_eq(first, second)
  let parsed = @json.parse(first)
  assert_eq(parsed.stringify(), first)
}
