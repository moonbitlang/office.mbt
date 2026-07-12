///|
/// XML escaping is shared with the `ooxml` package (the OOXML packaging layer
/// this package builds on) so there is a single implementation to keep
/// correct. These thin wrappers preserve the local names used throughout the
/// writer.
fn escape_xml_text(value : StringView) -> String {
  @ooxml.escape_xml_text(value)
}

///|
fn escape_xml_attr(value : StringView) -> String {
  @ooxml.escape_xml_attr(value)
}

///|
fn unescape_xml_text(value : StringView) -> String {
  value
  .to_owned()
  .replace_all(old="&lt;", new="<")
  .replace_all(old="&gt;", new=">")
  .replace_all(old="&quot;", new="\"")
  .replace_all(old="&apos;", new="'")
  .replace_all(old="&amp;", new="&")
}

///|
fn is_attr_space(ch : Char) -> Bool {
  match ch {
    ' ' | '\t' | '\n' | '\r' => true
    _ => false
  }
}

///|
fn attr_value(tag : StringView, name : StringView) -> String? raise XlsxError {
  @ooxml.attr_value(tag, name) catch {
    InvalidXml(msg~) => raise InvalidXml(msg~)
  }
}

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
