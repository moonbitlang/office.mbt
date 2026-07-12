///|
/// Find the first occurrence of an opening tag `<tag_name ...>` and return the
/// tag text without the leading `<` and without the closing `>`.
///
/// Example: `<a b="c">` -> `a b="c"`.
fn tag_attributes_in(xml : StringView, tag_name : StringView) -> String? {
  let xml_str = xml.to_owned()
  let needle = "<\{tag_name.to_owned()}"
  let start = match xml_str.find(needle) {
    Some(pos) => pos
    None => return None
  }
  let rest = xml_str[start + 1:]
  let end = match rest.find(">") {
    Some(pos) => pos
    None => return None
  }
  let slice = rest[:end]
  Some(slice.to_owned())
}

///|
/// Extract the body text from the first `<tag_name ...>...</tag_name>` pair.
fn extract_tag_body_from(xml : StringView, tag_name : StringView) -> String? {
  let xml_str = xml.to_owned()
  let open_tag = "<\{tag_name.to_owned()}"
  let close_tag = "</\{tag_name.to_owned()}>"
  let start = match xml_str.find(open_tag) {
    Some(pos) => pos
    None => return None
  }
  let after_start = xml_str[start:]
  let open_end_rel = match after_start.find(">") {
    Some(pos) => pos
    None => return None
  }
  let body_start = start + open_end_rel + 1
  let end = match xml_str.find(close_tag) {
    Some(pos) => pos
    None => return None
  }
  let body = xml_str[body_start:end]
  Some(body.to_owned())
}

///|
/// Extract the body text from the first `<tag_name ...>...</tag_name>` pair.
///
/// This differs from `extract_tag_body_from` only in that it errors (instead of
/// returning `None`) when the tag is found but is malformed (missing close `>`
/// or missing close tag).
fn extract_tag_body(
  xml : StringView,
  tag_name : StringView,
) -> String? raise XlsxError {
  let xml_str = xml.to_owned()
  let open_tag = "<\{tag_name.to_owned()}"
  let close_tag = "</\{tag_name.to_owned()}>"
  let start = match xml_str.find(open_tag) {
    Some(pos) => pos
    None => return None
  }
  let after_start = xml_str[start:]
  let open_end_rel = match after_start.find(">") {
    Some(pos) => pos
    None => raise InvalidXml(msg="tag open not closed")
  }
  let body_start = start + open_end_rel + 1
  let end = match xml_str.find(close_tag) {
    Some(pos) => pos
    None => raise InvalidXml(msg="tag close missing")
  }
  let body = xml_str[body_start:end]
  Some(body.to_owned())
}

///|
/// Replace `attr_name="..."` inside the first open tag in `xml`.
fn replace_attr_value_in_open_tag(
  xml : StringView,
  attr_name : StringView,
  value : String,
) -> String? {
  let text = xml.to_owned()
  let tag_start = match text.find("<") {
    Some(pos) => pos
    None => return None
  }
  let tag_end = match text.find(">") {
    Some(pos) => pos
    None => return None
  }
  let open_tag = text[tag_start:tag_end]
  let needle = "\{attr_name.to_owned()}=\""
  let attr_pos = match open_tag.find(needle) {
    Some(pos) => pos
    None => return None
  }
  let value_start = tag_start + attr_pos + needle.length()
  let rest = text[value_start:]
  let value_end_rel = match rest.find("\"") {
    Some(pos) => pos
    None => return None
  }
  let value_end = value_start + value_end_rel
  let sb = StringBuilder::new()
  sb.write_view(text[:value_start])
  sb.write_view(escape_xml_attr(value))
  sb.write_view(text[value_end:])
  Some(sb.to_string())
}

///|
test "ooxml_utils: tag_attributes_in finds first open tag" {
  let xml = "<root><a b=\"c\"/><a b=\"d\"/></root>"
  debug_inspect(tag_attributes_in(xml, "a"), content="Some(\"a b=\\\"c\\\"/\")")
}

///|
test "ooxml_utils: tag_attributes_in returns None when missing" {
  let xml = "<root/>"
  debug_inspect(tag_attributes_in(xml, "a"), content="None")
}

///|
test "ooxml_utils: extract_tag_body_from extracts body" {
  let xml = "<root><a>hello</a><a>world</a></root>"
  debug_inspect(extract_tag_body_from(xml, "a"), content="Some(\"hello\")")
}

///|
test "ooxml_utils: extract_tag_body_from returns None when missing" {
  let xml = "<root/>"
  debug_inspect(extract_tag_body_from(xml, "a"), content="None")
}

///|
test "ooxml_utils: replace_attr_value_in_open_tag rewrites attribute and escapes" {
  let xml = "<a sqref=\"A1\">x</a>"
  let updated = replace_attr_value_in_open_tag(xml, "sqref", "B2 & \"<\"")
  debug_inspect(
    updated,
    content="Some(\"<a sqref=\\\"B2 &amp; &quot;&lt;&quot;\\\">x</a>\")",
  )
}

///|
test "ooxml_utils: replace_attr_value_in_open_tag returns None when attribute missing" {
  let xml = "<a>nope</a>"
  debug_inspect(
    replace_attr_value_in_open_tag(xml, "sqref", "B2"),
    content="None",
  )
}
