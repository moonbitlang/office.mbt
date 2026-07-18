///|
/// Find the first occurrence of an opening tag `<tag_name ...>` and return the
/// tag text without the leading `<` and without the closing `>`.
///
/// Example: `<a b="c">` -> `a b="c"`.
fn xml_open_tag_end_from(xml : StringView, start : Int) -> Int? {
  let mut index = start
  let mut quote : UInt16? = None
  while index < xml.length() {
    let unit = xml[index]
    match quote {
      Some(delimiter) => if unit == delimiter { quote = None }
      None =>
        if unit == ('"' : UInt16) || unit == ('\'' : UInt16) {
          quote = Some(unit)
        } else if unit == ('>' : UInt16) {
          return Some(index)
        }
    }
    index = index + 1
  }
  None
}

///|
fn is_xml_open_tag_boundary(unit : UInt16) -> Bool {
  is_xml_attr_space_unit(unit) ||
  unit == ('/' : UInt16) ||
  unit == ('>' : UInt16)
}

///|
fn find_xml_open_tag_start_from(
  xml : StringView,
  tag_name : StringView,
  start_at : Int,
) -> Int? {
  let mut start = start_at.max(0)
  let name_length = tag_name.length()
  while start + 1 + name_length <= xml.length() {
    if xml[start] == ('<' : UInt16) {
      let mut matches = true
      for offset in 0..<name_length {
        if xml[start + 1 + offset] != tag_name[offset] {
          matches = false
          break
        }
      }
      let boundary = start + 1 + name_length
      if matches &&
        (boundary == xml.length() || is_xml_open_tag_boundary(xml[boundary])) {
        return Some(start)
      }
    }
    start = start + 1
  }
  None
}

///|
fn find_xml_open_tag_start(xml : StringView, tag_name : StringView) -> Int? {
  find_xml_open_tag_start_from(xml, tag_name, 0)
}

///|
/// Finds an XML end tag and accepts the XML-permitted whitespace between its
/// QName and `>`, for example `</c >` and `</c\n>`.
fn find_xml_close_tag_from(
  xml : StringView,
  tag_name : StringView,
  start_at : Int,
) -> (Int, Int)? {
  let mut start = start_at.max(0)
  let name_length = tag_name.length()
  while start + 2 + name_length <= xml.length() {
    if xml[start] == ('<' : UInt16) && xml[start + 1] == ('/' : UInt16) {
      let mut matches = true
      for offset in 0..<name_length {
        if xml[start + 2 + offset] != tag_name[offset] {
          matches = false
          break
        }
      }
      if matches {
        let mut end = start + 2 + name_length
        while end < xml.length() && is_xml_attr_space_unit(xml[end]) {
          end = end + 1
        }
        if end < xml.length() && xml[end] == ('>' : UInt16) {
          return Some((start, end))
        }
      }
    }
    start = start + 1
  }
  None
}

///|
fn tag_attributes_in(xml : StringView, tag_name : StringView) -> String? {
  let xml_str = xml.to_owned()
  let start = match find_xml_open_tag_start(xml_str, tag_name) {
    Some(pos) => pos
    None => return None
  }
  let end = match xml_open_tag_end_from(xml_str, start + 1) {
    Some(pos) => pos
    None => return None
  }
  let slice = xml_str[start + 1:end]
  Some(slice.to_owned())
}

///|
/// Extract the body text from the first `<tag_name ...>...</tag_name>` pair.
fn extract_tag_body_from(xml : StringView, tag_name : StringView) -> String? {
  let xml_str = xml.to_owned()
  let start = match find_xml_open_tag_start(xml_str, tag_name) {
    Some(pos) => pos
    None => return None
  }
  let open_end = match xml_open_tag_end_from(xml_str, start + 1) {
    Some(pos) => pos
    None => return None
  }
  let body_start = open_end + 1
  let end = match find_xml_close_tag_from(xml_str, tag_name, body_start) {
    Some((pos, _)) => pos
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
  let start = match find_xml_open_tag_start(xml_str, tag_name) {
    Some(pos) => pos
    None => return None
  }
  let open_end = match xml_open_tag_end_from(xml_str, start + 1) {
    Some(pos) => pos
    None => raise InvalidXml(msg="tag open not closed")
  }
  if xml_str[start + 1:open_end].trim().has_suffix("/") {
    return Some("")
  }
  let body_start = open_end + 1
  let end = match find_xml_close_tag_from(xml_str, tag_name, body_start) {
    Some((pos, _)) => pos
    None => raise InvalidXml(msg="tag close missing")
  }
  let body = xml_str[body_start:end]
  Some(body.to_owned())
}

///|
fn is_xml_attr_space_unit(ch : UInt16) -> Bool {
  ch == (' ' : UInt16) ||
  ch == ('\t' : UInt16) ||
  ch == ('\n' : UInt16) ||
  ch == ('\r' : UInt16)
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
  let mut pos = tag_start + 1
  while pos < text.length() &&
        !is_xml_attr_space_unit(text[pos]) &&
        text[pos] != '>' {
    pos = pos + 1
  }
  let mut value_start = -1
  let mut value_end = -1
  while pos < text.length() {
    while pos < text.length() && is_xml_attr_space_unit(text[pos]) {
      pos = pos + 1
    }
    if pos >= text.length() || text[pos] == '>' || text[pos] == '/' {
      break
    }
    let name_start = pos
    while pos < text.length() &&
          !is_xml_attr_space_unit(text[pos]) &&
          text[pos] != '=' &&
          text[pos] != '>' &&
          text[pos] != '/' {
      pos = pos + 1
    }
    let name_end = pos
    while pos < text.length() && is_xml_attr_space_unit(text[pos]) {
      pos = pos + 1
    }
    if pos >= text.length() || text[pos] != '=' {
      return None
    }
    pos = pos + 1
    while pos < text.length() && is_xml_attr_space_unit(text[pos]) {
      pos = pos + 1
    }
    if pos >= text.length() || (text[pos] != '"' && text[pos] != '\'') {
      return None
    }
    let quote = text[pos]
    pos = pos + 1
    let current_value_start = pos
    while pos < text.length() && text[pos] != quote {
      pos = pos + 1
    }
    if pos >= text.length() {
      return None
    }
    if text[name_start:name_end] == attr_name {
      value_start = current_value_start
      value_end = pos
      break
    }
    pos = pos + 1
  }
  if value_start < 0 {
    return None
  }
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
test "ooxml_utils: opening-tag scanners ignore delimiters inside either quote" {
  let xml = "<root><a prompt='1 > 0' title=\"x > y\" sqref='A1'>ok</a></root>"
  debug_inspect(
    tag_attributes_in(xml, "a"),
    content="Some(\"a prompt='1 > 0' title=\\\"x > y\\\" sqref='A1'\")",
  )
  debug_inspect(extract_tag_body_from(xml, "a"), content="Some(\"ok\")")
  debug_inspect(extract_tag_body(xml, "a"), content="Some(\"ok\")")
}

///|
test "ooxml_utils: tag_attributes_in returns None when missing" {
  let xml = "<root/>"
  debug_inspect(tag_attributes_in(xml, "a"), content="None")
}

///|
test "ooxml_utils: opening-tag lookup requires an exact name boundary" {
  let xml = "<root><abbr sqref='wrong'/><a sqref='A1'/></root>"
  debug_inspect(tag_attributes_in(xml, "a"), content="Some(\"a sqref='A1'/\")")
}

///|
test "ooxml_utils: extract_tag_body_from extracts body" {
  let xml = "<root><a>hello</a><a>world</a></root>"
  debug_inspect(extract_tag_body_from(xml, "a"), content="Some(\"hello\")")
}

///|
test "ooxml_utils: extract_tag_body accepts an empty self-closing container" {
  debug_inspect(
    extract_tag_body("<root><items/></root>", "items"),
    content="Some(\"\")",
  )
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

///|
test "ooxml_utils: replace_attr_value_in_open_tag accepts spaces around equals" {
  let xml = "<a sqref = \" A1\">x</a>"
  debug_inspect(
    replace_attr_value_in_open_tag(xml, "sqref", "B2"),
    content="Some(\"<a sqref = \\\"B2\\\">x</a>\")",
  )
}

///|
test "ooxml_utils: replace_attr_value_in_open_tag ignores prefixed names" {
  let xml = "<a x:sqref=\"keep\" sqref = \" A1\">x</a>"
  debug_inspect(
    replace_attr_value_in_open_tag(xml, "sqref", "B2"),
    content="Some(\"<a x:sqref=\\\"keep\\\" sqref = \\\"B2\\\">x</a>\")",
  )
}

///|
test "ooxml_utils: replace_attr_value_in_open_tag supports mixed quotes" {
  let xml = "<a type='whole' x:sqref='keep' sqref = ' A1'>x</a>"
  debug_inspect(
    replace_attr_value_in_open_tag(xml, "sqref", "B2"),
    content="Some(\"<a type='whole' x:sqref='keep' sqref = 'B2'>x</a>\")",
  )
}
