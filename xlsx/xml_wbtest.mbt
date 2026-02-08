///|
test "xml wb: escape attr and attr-space branches" {
  inspect(escape_xml_attr("a>b"), content="a&gt;b")
  inspect(is_attr_space('\t'), content="true")
}

///|
test "xml wb: attr_value parser edge branches" {
  inspect(
    attr_value("= \"skip\" foo=   \"bar\"", "foo"),
    content="Some(\"bar\")",
  )
  inspect(attr_value("foo=bar", "foo"), content="None")

  let invalid : Result[String?, Error] = try? attr_value(
    "foo=\"unterminated", "foo",
  )
  inspect(invalid is Err(XlsxError::InvalidXml(_)), content="true")
}
