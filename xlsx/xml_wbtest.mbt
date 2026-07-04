///|
test "xml wb: escape attr and attr-space branches" {
  inspect(escape_xml_attr("a>b"), content="a&gt;b")
  inspect(is_attr_space('\t'), content="true")
}

///|
test "xml wb: attr_value parser edge branches" {
  debug_inspect(
    attr_value("= \"skip\" foo=   \"bar\"", "foo"),
    content="Some(\"bar\")",
  )
  debug_inspect(attr_value("foo=bar", "foo"), content="None")

  let invalid : Result[String?, Error] = Ok(
    attr_value("foo=\"unterminated", "foo"),
  ) catch {
    e => Err(e)
  }
  inspect(invalid is Err(XlsxError::InvalidXml(_)), content="true")
}
