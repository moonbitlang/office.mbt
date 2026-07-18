///|
test "ooxml read_parse: internal relationships support self-closing and expanded tags" {
  let xml =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    #|  <Relationship Id="rId1" Type="t1" Target="a.xml"/>
    #|  <Relationship Id="rId2" Type="t2" Target="b.xml"></Relationship>
    #|  <Relationship Id="rId3" Type="t1" Target="c.xml"/>
    #|</Relationships>
    #|
  let targets = @ooxml.parse_internal_relationship_targets(xml, "t1")
  debug_inspect(
    targets,
    content=(
      #|{ "rId1": "a.xml", "rId3": "c.xml" }
    ),
  )
}

///|
test "ooxml read_parse: internal relationships report missing id/target and malformed tag" {
  let missing_id =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    #|  <Relationship Type="t1" Target="a.xml"/>
    #|</Relationships>
    #|
  try @ooxml.parse_internal_relationship_targets(missing_id, "t1") catch {
    InvalidXml(msg~) => inspect(msg, content="relationship id missing")
    _ => fail("unexpected relationship parse cancellation")
  } noraise {
    _ => fail("expected relationship id missing")
  }

  let missing_target =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    #|  <Relationship Id="rId1" Type="t1"/>
    #|</Relationships>
    #|
  try @ooxml.parse_internal_relationship_targets(missing_target, "t1") catch {
    InvalidXml(msg~) => inspect(msg, content="relationship target missing")
    _ => fail("unexpected relationship parse cancellation")
  } noraise {
    _ => fail("expected relationship target missing")
  }

  let malformed =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    #|  <Relationship 
    #|</Relationships>
    #|
  try @ooxml.parse_internal_relationship_targets(malformed, "t1") catch {
    InvalidXml(msg~) => inspect(msg, content="XML start tag is not closed")
    _ => fail("unexpected relationship parse cancellation")
  } noraise {
    _ => fail("expected relationship tag not closed")
  }
}

///|
test "ooxml read_parse: prefixed relationships decode entities exactly once" {
  let xml =
    #|<pkg:Relationships xmlns:pkg="http://schemas.openxmlformats.org/package/2006/relationships">
    #|  <pkg:Relationship Id="r&amp;1" Type="urn:type&#x31;" Target="custom/a&amp;#x20;b.xml"/>
    #|</pkg:Relationships>
  let targets = @ooxml.parse_internal_relationship_targets(xml, "urn:type1")
  debug_inspect(
    targets,
    content=(
      #|{ "r&1": "custom/a&#x20;b.xml" }
    ),
  )
}

///|
test "ooxml read_parse: relationship schema whitespace is collapsed" {
  let xml =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    #|  <Relationship Id="  r&#x9;1  " Type="  urn:type&#xD;&#xA;one  " Target="  custom/a&#x9;&#x9;b.xml  "/>
    #|</Relationships>
  let targets = @ooxml.parse_internal_relationship_targets(xml, "urn:type one")
  debug_inspect(targets, content="{ \"r 1\": \"custom/a b.xml\" }")
}

///|
test "ooxml read_parse: relationship target modes are explicit and filtered" {
  let xml =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    #|  <Relationship Id="default" Type="wanted" Target="inside.xml"/>
    #|  <Relationship Id="internal" Type="wanted" Target="also-inside.xml" TargetMode=" Internal "/>
    #|  <Relationship Id="external" Type="wanted" Target="https://example.invalid" TargetMode="External"/>
    #|</Relationships>
  debug_inspect(
    @ooxml.parse_internal_relationship_targets(xml, "wanted"),
    content=(
      #|{ "default": "inside.xml", "internal": "also-inside.xml" }
    ),
  )
  debug_inspect(
    @ooxml.parse_external_relationship_targets(xml, "wanted"),
    content=(
      #|{ "external": "https://example.invalid" }
    ),
  )
}

///|
test "ooxml read_parse: relationships apply OPC Markup Compatibility" {
  let process_content =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" xmlns:v="urn:vendor" mc:Ignorable="v" mc:ProcessContent="v:Wrapper"><v:Ignored/><v:Wrapper><Relationship Id="processed" Type="wanted" Target="processed.xml"/></v:Wrapper></Relationships>
  let selected_choice =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships" xmlns:r="http://schemas.openxmlformats.org/package/2006/relationships" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" xmlns:v="urn:vendor"><mc:AlternateContent><mc:Choice Requires="v"><v:Unsupported/></mc:Choice><mc:Choice Requires="r"><Relationship Id="choice" Type="wanted" Target="choice.xml"/></mc:Choice><mc:Fallback><Relationship Id="fallback" Type="wanted" Target="fallback.xml"/></mc:Fallback></mc:AlternateContent></Relationships>
  let selected_fallback =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" xmlns:v="urn:vendor"><mc:AlternateContent><mc:Choice Requires="v"><v:Unsupported/></mc:Choice><mc:Fallback><Relationship Id="fallback" Type="wanted" Target="fallback.xml"/></mc:Fallback></mc:AlternateContent></Relationships>
  let processed = @ooxml.parse_internal_relationship_targets(
    process_content, "wanted",
  )
  assert_eq(processed.get("processed"), Some("processed.xml"))
  assert_eq(processed.length(), 1)
  let choice = @ooxml.parse_internal_relationship_targets(
    selected_choice, "wanted",
  )
  assert_eq(choice.get("choice"), Some("choice.xml"))
  assert_eq(choice.length(), 1)
  let fallback = @ooxml.parse_internal_relationship_targets(
    selected_fallback, "wanted",
  )
  assert_eq(fallback.get("fallback"), Some("fallback.xml"))
  assert_eq(fallback.length(), 1)
}

///|
test "ooxml read_parse: MCE names retain one copy of a long namespace URI" {
  let names = StringBuilder::new()
  for index in 0..<4096 {
    if index > 0 {
      names.write_char(' ')
    }
    names.write_string("v:n\{index}")
  }
  let namespace_uri = "urn:" + "v".repeat(100_000)
  let xml = "<Relationships xmlns=\"" +
    "http://schemas.openxmlformats.org/package/2006/relationships" +
    "\" xmlns:mc=\"" +
    "http://schemas.openxmlformats.org/markup-compatibility/2006" +
    "\" xmlns:v=\"" +
    namespace_uri +
    "\" mc:Ignorable=\"v\" mc:ProcessContent=\"" +
    names.to_string() +
    "\"/>"
  let targets = @ooxml.parse_internal_relationship_targets(xml, "wanted")
  assert_eq(targets.length(), 0)
}

///|
test "ooxml read_parse: invalid relationship MCE fails closed" {
  let cases : Array[(String, String)] = [
    (
      (
        #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"><mc:AlternateContent><mc:Fallback/></mc:AlternateContent></Relationships>
      ),
      "MCE AlternateContent has no Choice element",
    ),
    (
      (
        #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" xmlns:v="urn:vendor"><mc:AlternateContent><mc:Choice Requires="v"/><mc:Fallback/><mc:Choice Requires="v"/></mc:AlternateContent></Relationships>
      ),
      "MCE Choice follows Fallback",
    ),
    (
      (
        #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" xmlns:v="urn:vendor"><mc:AlternateContent><mc:Choice Requires="v"/><mc:Fallback/><mc:Fallback/></mc:AlternateContent></Relationships>
      ),
      "MCE AlternateContent has multiple Fallback elements",
    ),
    (
      (
        #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" xmlns:v="urn:vendor" mc:MustUnderstand="v"/>
      ),
      "MCE MustUnderstand namespace is unsupported",
    ),
    (
      (
        #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" xmlns:v="urn:vendor" mc:Ignorable="v" mc:ProcessContent="v:*"/>
      ),
      "MCE ProcessContent wildcard is invalid",
    ),
    (
      (
        #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" xmlns:v="urn:vendor" mc:Ignorable="v" mc:ProcessContent="v:Wrapper"><v:Wrapper xml:base="elsewhere"><Relationship Id="bad" Type="wanted" Target="bad.xml"/></v:Wrapper></Relationships>
      ),
      "MCE ProcessContent element has an unsafe xml attribute",
    ),
    (
      (
        #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Unknown/></Relationships>
      ),
      "relationships effective content is invalid",
    ),
  ]
  for case in cases {
    let (xml, expected) = case
    try @ooxml.parse_internal_relationship_targets(xml, "wanted") catch {
      InvalidXml(msg~) => assert_eq(msg, expected)
      _ => fail("unexpected relationship parse cancellation")
    } noraise {
      _ => fail("expected invalid relationship MCE")
    }
  }
}

///|
test "ooxml read_parse: unselected MCE choices remain opaque" {
  let xml =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" xmlns:r="http://schemas.openxmlformats.org/package/2006/relationships" xmlns:v="urn:vendor"><mc:AlternateContent><mc:Choice Requires="v"><v:Unsupported mc:MustUnderstand="missing"><Relationship/></v:Unsupported></mc:Choice><mc:Choice Requires="r"><Relationship Id="selected" Type="wanted" Target="selected.xml"/></mc:Choice></mc:AlternateContent></Relationships>
  let targets = @ooxml.parse_internal_relationship_targets(xml, "wanted")
  assert_eq(targets.get("selected"), Some("selected.xml"))
  assert_eq(targets.length(), 1)
}

///|
test "ooxml read_parse: invalid target modes fail closed" {
  let xml =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="bad" Type="wanted" Target="inside.xml" TargetMode="Remote"/></Relationships>
  for external in [false, true] {
    try {
      if external {
        ignore(@ooxml.parse_external_relationship_targets(xml, "wanted"))
      } else {
        ignore(@ooxml.parse_internal_relationship_targets(xml, "wanted"))
      }
    } catch {
      InvalidXml(msg~) =>
        inspect(msg, content="relationship target mode invalid")
      _ => fail("unexpected relationship parse cancellation")
    } noraise {
      _ => fail("expected invalid relationship target mode")
    }
  }
}

///|
test "ooxml read_parse: unwanted relationships remain schema-valid and ids stay unique" {
  for
    xml in [
      (
        #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="bad" Type="other"/></Relationships>
      ),
      (
        #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="same" Type="other" Target="a"/><Relationship Id="same" Type="wanted" Target="b"/></Relationships>
      ),
    ] {
    try @ooxml.parse_internal_relationship_targets(xml, "wanted") catch {
      InvalidXml(_) => ()
      _ => fail("unexpected relationship parse cancellation")
    } noraise {
      _ => fail("expected invalid relationship document")
    }
  }
}

///|
test "ooxml read_parse: relationship limits accept writer boundaries" {
  let xml = StringBuilder::new()
  xml.write_string(
    "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">",
  )
  for index in 0..<16_385 {
    xml.write_string(
      "<Relationship Id=\"r\{index}\" Type=\"other\" Target=\"x\"/>",
    )
  }
  let long_target = "x".repeat(4097)
  xml.write_string(
    "<Relationship Id=\"wanted\" Type=\"wanted\" Target=\"\{long_target}\"/>",
  )
  xml.write_string("</Relationships>")
  let targets = @ooxml.parse_internal_relationship_targets(
    xml.to_string(),
    "wanted",
  )
  assert_eq(targets.get("wanted"), Some(long_target))
}

///|
test "ooxml read_parse: relationship scans poll cancellation internally" {
  let xml = StringBuilder::new()
  xml.write_string(
    "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">",
  )
  for index in 0..<2048 {
    xml.write_string(
      "<Relationship Id=\"r\{index}\" Type=\"other\" Target=\"x\"/>",
    )
  }
  xml.write_string("</Relationships>")
  let checks = [0]
  try
    @ooxml.parse_internal_relationship_targets(xml.to_string(), "wanted", cancelled=() => {
      checks[0] += 1
      checks[0] >= 4
    })
  catch {
    ReadCancelled => assert_true(checks[0] >= 4)
    _ => fail("expected relationship scan cancellation")
  } noraise {
    _ => fail("expected relationship scan cancellation")
  }
}

///|
test "ooxml read_parse: parse_content_type_overrides and find workbook part" {
  let xml =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
    #|  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
    #|  <Default Extension="xml" ContentType="application/xml"/>
    #|  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.ms-excel.sheet.macroEnabled.main+xml"/>
    #|  <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
    #|</Types>
    #|
  debug_inspect(
    @ooxml.find_override_part_by_content_types(xml, [
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml",
      "application/vnd.ms-excel.sheet.macroEnabled.main+xml",
    ]),
    content="Some(\"/xl/workbook.xml\")",
  )
}

///|
test "ooxml read_parse: parse_content_type_overrides reports malformed override tags" {
  let malformed =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
    #|  <Override PartName="/xl/workbook.xml" 
    #|</Types>
    #|
  try
    @ooxml.find_override_part_by_content_types(malformed, [
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml",
    ])
  catch {
    InvalidXml(msg~) => inspect(msg, content="XML start tag is not closed")
    _ => fail("unexpected content type parse cancellation")
  } noraise {
    _ => fail("expected content type override tag not closed")
  }
}

///|
test "ooxml read_parse: prefixed content types decode names and media types" {
  let xml =
    #|<ct:Types xmlns:ct="http://schemas.openxmlformats.org/package/2006/content-types">
    #|  <ct:Override PartName="/xl/a&amp;b.xml" ContentType="application/vnd.example&#43;xml"/>
    #|</ct:Types>
  debug_inspect(
    @ooxml.find_override_part_by_content_types(xml, [
      "application/vnd.example+xml",
    ]),
    content="Some(\"/xl/a&b.xml\")",
  )
}

///|
test "ooxml read_parse: content type lookup honors part identity then default" {
  let xml =
    #|<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
    #|  <Default Extension="XML" ContentType="application/default+xml"/>
    #|  <Override PartName="/custom/book.xml" ContentType="application/workbook+xml"/>
    #|</Types>
  assert_eq(
    @ooxml.find_part_content_type(xml, "CUSTOM/BOOK.XML"),
    Some("application/workbook+xml"),
  )
  assert_eq(
    @ooxml.find_part_content_type(xml, "custom/other.Xml"),
    Some("application/default+xml"),
  )
}

///|
test "ooxml read_parse: content type scans poll cancellation internally" {
  let xml = StringBuilder::new()
  xml.write_string(
    "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">",
  )
  for index in 0..<2048 {
    xml.write_string(
      "<Override PartName=\"/custom/p\{index}.xml\" ContentType=\"application/xml\"/>",
    )
  }
  xml.write_string("</Types>")
  let checks = [0]
  try
    @ooxml.find_part_content_type(xml.to_string(), "custom/missing.xml", cancelled=() => {
      checks[0] += 1
      checks[0] >= 4
    })
  catch {
    ReadCancelled => assert_true(checks[0] >= 4)
    _ => fail("expected content type scan cancellation")
  } noraise {
    _ => fail("expected content type scan cancellation")
  }
}

///|
test "ooxml read_parse: content type overrides reject case-variant duplicates" {
  let xml =
    #|<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
    #|  <Override PartName="/custom/book.xml" ContentType="application/first+xml"/>
    #|  <Override PartName="/CUSTOM/BOOK.XML" ContentType="application/second+xml"/>
    #|</Types>
  try @ooxml.find_part_content_type(xml, "custom/book.xml") catch {
    InvalidXml(msg~) => inspect(msg, content="duplicate content type override")
    _ => fail("unexpected content type parse cancellation")
  } noraise {
    _ => fail("expected case-variant duplicate override rejection")
  }
}
