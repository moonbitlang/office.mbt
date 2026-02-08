///|
test "ooxml read_parse wb: attr_value parser branches" {
  inspect(attr_value("   ", "Id"), content="None")
  inspect(
    attr_value("= \"skip\" foo = \"bar\"", "foo"),
    content="Some(\"bar\")",
  )
  inspect(attr_value("foo=bar", "foo"), content="None")
  inspect(attr_value("bar=\"ok\"", "baz"), content="None")

  let bad_attr : Result[String?, Error] = try? attr_value(
    "foo=\"unterminated", "foo",
  )
  inspect(bad_attr is Err(ParseXmlError::InvalidXml(_)), content="true")
}

///|
test "ooxml read_parse wb: relationship type-missing branch continues" {
  let xml =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    #|  <Relationship Id="rId1" Target="a.xml"/>
    #|</Relationships>
    #|
  let targets = parse_relationship_targets(xml[:], "t1")
  inspect(targets, content="{}")
}

///|
test "ooxml read_parse wb: content-type override required attrs" {
  let missing_part =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
    #|  <Override ContentType="application/xml"/>
    #|</Types>
    #|
  let result_missing_part = try? parse_content_type_overrides(missing_part[:])
  match result_missing_part {
    Err(ParseXmlError::InvalidXml(msg~)) =>
      inspect(msg, content="content type override part name missing")
    _ => fail("expected content type override part name missing")
  }

  let missing_content_type =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
    #|  <Override PartName="/xl/workbook.xml"/>
    #|</Types>
    #|
  let result_missing_content = try? parse_content_type_overrides(
    missing_content_type[:],
  )
  match result_missing_content {
    Err(ParseXmlError::InvalidXml(msg~)) =>
      inspect(msg, content="content type override content type missing")
    _ => fail("expected content type override content type missing")
  }
}
