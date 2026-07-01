///|
test "ooxml read_parse: parse_relationship_targets supports self-closing and expanded tags" {
  let xml =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    #|  <Relationship Id="rId1" Type="t1" Target="a.xml"/>
    #|  <Relationship Id="rId2" Type="t2" Target="b.xml"></Relationship>
    #|  <Relationship Id="rId3" Type="t1" Target="c.xml"/>
    #|</Relationships>
    #|
  let targets = parse_relationship_targets(xml, "t1")
  debug_inspect(targets, content=(
    #|{ "rId1": "a.xml", "rId3": "c.xml" }
  ))
}

///|
test "ooxml read_parse: parse_relationship_targets reports missing id/target and malformed tag" {
  let missing_id =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    #|  <Relationship Type="t1" Target="a.xml"/>
    #|</Relationships>
    #|
  let result_missing_id = try? parse_relationship_targets(missing_id, "t1")
  match result_missing_id {
    Err(ParseXmlError::InvalidXml(msg~)) =>
      inspect(msg, content="relationship id missing")
    _ => fail("expected relationship id missing")
  }

  let missing_target =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    #|  <Relationship Id="rId1" Type="t1"/>
    #|</Relationships>
    #|
  let result_missing_target = try? parse_relationship_targets(
    missing_target,
    "t1",
  )
  match result_missing_target {
    Err(ParseXmlError::InvalidXml(msg~)) =>
      inspect(msg, content="relationship target missing")
    _ => fail("expected relationship target missing")
  }

  let malformed =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    #|  <Relationship 
    #|</Relationships>
    #|
  let result_malformed = try? parse_relationship_targets(malformed, "t1")
  match result_malformed {
    Err(ParseXmlError::InvalidXml(msg~)) =>
      inspect(msg, content="relationship tag not closed")
    _ => fail("expected relationship tag not closed")
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
    find_override_part_by_content_types(xml, [
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
  let result = try? find_override_part_by_content_types(malformed, [
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml",
  ])
  match result {
    Err(ParseXmlError::InvalidXml(msg~)) =>
      inspect(msg, content="content type override tag not closed")
    _ => fail("expected content type override tag not closed")
  }
}
