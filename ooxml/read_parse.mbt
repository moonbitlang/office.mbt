///|
pub suberror ParseXmlError {
  InvalidXml(msg~ : String)
} derive(Debug)

///|
fn is_attr_space(ch : UInt16) -> Bool {
  ch == (' ' : UInt16) ||
  ch == ('\t' : UInt16) ||
  ch == ('\n' : UInt16) ||
  ch == ('\r' : UInt16)
}

///|
/// Extract the value of attribute `name` from an XML start-tag body, or `None`
/// if absent. Raises `InvalidXml` on a malformed (unterminated) attribute.
pub fn attr_value(
  tag : StringView,
  name : StringView,
) -> String? raise ParseXmlError {
  let tag_len = tag.length()
  let name_len = name.length()
  let mut i = 0
  while i < tag_len {
    while i < tag_len && is_attr_space(tag[i]) {
      i = i + 1
    }
    if i >= tag_len {
      break
    }
    let name_start = i
    while i < tag_len && !is_attr_space(tag[i]) && tag[i] != ('=' : UInt16) {
      i = i + 1
    }
    let name_end = i
    if name_end == name_start {
      i = i + 1
      continue
    }
    while i < tag_len && is_attr_space(tag[i]) {
      i = i + 1
    }
    if i >= tag_len || tag[i] != ('=' : UInt16) {
      i = name_end
      continue
    }
    i = i + 1
    while i < tag_len && is_attr_space(tag[i]) {
      i = i + 1
    }
    if i >= tag_len || (tag[i] != ('"' : UInt16) && tag[i] != ('\'' : UInt16)) {
      continue
    }
    let quote = tag[i]
    i = i + 1
    let value_start = i
    while i < tag_len && tag[i] != quote {
      i = i + 1
    }
    if i >= tag_len {
      raise InvalidXml(msg="attribute out of range")
    }
    if name_end - name_start == name_len {
      let mut matched = true
      for j in 0..<name_len {
        if tag[name_start + j] != name[j] {
          matched = false
          break
        }
      }
      if matched {
        let value = tag.to_owned().unsafe_substring(start=value_start, end=i)
        return Some(value.to_string())
      }
    }
    i = i + 1
  }
  None
}

///|
fn first_tag_end(text : StringView) -> Int? {
  let mut i = 0
  let mut quote : UInt16? = None
  while i < text.length() {
    let ch = text[i]
    match quote {
      Some(value) => if ch == value { quote = None }
      None =>
        if ch == ('"' : UInt16) || ch == ('\'' : UInt16) {
          quote = Some(ch)
        } else {
          if ch == ('<' : UInt16) {
            return None
          }
          if ch == ('>' : UInt16) {
            return Some(i)
          }
        }
    }
    i = i + 1
  }
  None
}

///|
pub fn parse_relationship_targets(
  xml : StringView,
  rel_type : StringView,
) -> Map[String, String] raise ParseXmlError {
  let targets : Map[String, String] = Map([])
  let mut first = true
  for chunk in xml.split("<Relationship ") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_owned()
    let end = match first_tag_end(text) {
      Some(pos) => pos
      None => raise InvalidXml(msg="relationship tag not closed")
    }
    let tag = text.unsafe_substring(start=0, end~)
    let rel = match attr_value(tag, "Type") {
      Some(value) => value
      None => continue
    }
    if rel != rel_type.to_owned() {
      continue
    }
    let id = match attr_value(tag, "Id") {
      Some(value) => value
      None => raise InvalidXml(msg="relationship id missing")
    }
    let target = match attr_value(tag, "Target") {
      Some(value) => value
      None => raise InvalidXml(msg="relationship target missing")
    }
    targets[id] = target
  }
  targets
}

///|
fn parse_content_type_overrides(
  xml : StringView,
) -> Map[String, String] raise ParseXmlError {
  let overrides : Map[String, String] = Map([])
  let mut first = true
  for chunk in xml.split("<Override ") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_owned()
    let end = match first_tag_end(text) {
      Some(pos) => pos
      None => raise InvalidXml(msg="content type override tag not closed")
    }
    let tag = text.unsafe_substring(start=0, end~)
    let part_name = match attr_value(tag, "PartName") {
      Some(value) => value
      None => raise InvalidXml(msg="content type override part name missing")
    }
    let content_type = match attr_value(tag, "ContentType") {
      Some(value) => value
      None => raise InvalidXml(msg="content type override content type missing")
    }
    overrides[part_name] = content_type
  }
  overrides
}

///|
pub fn find_override_part_by_content_types(
  xml : StringView,
  content_types : ArrayView[String],
) -> String? raise ParseXmlError {
  let overrides = parse_content_type_overrides(xml)
  for wanted in content_types {
    for part_name, content_type in overrides {
      if content_type == wanted {
        return Some(part_name)
      }
    }
  }
  None
}

///|
test "ooxml read_parse wb: attr_value parser branches" {
  debug_inspect(attr_value("   ", "Id"), content="None")
  debug_inspect(
    attr_value("= \"skip\" foo = \"bar\"", "foo"),
    content="Some(\"bar\")",
  )
  debug_inspect(attr_value("foo=bar", "foo"), content="None")
  debug_inspect(attr_value("bar=\"ok\"", "baz"), content="None")
  debug_inspect(
    attr_value("type='whole' sqref = ' A1 '", "sqref"),
    content="Some(\" A1 \")",
  )

  try attr_value("foo=\"unterminated", "foo") catch {
    e => inspect(e is InvalidXml(_), content="true")
  } noraise {
    _ => fail("expected attr_value to raise")
  }
}

///|
test "ooxml read_parse wb: relationship type-missing branch continues" {
  let xml =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    #|  <Relationship Id="rId1" Target="a.xml"/>
    #|</Relationships>
    #|
  let targets = parse_relationship_targets(xml, "t1")
  debug_inspect(targets, content="{}")
}

///|
test "ooxml read_parse wb: content-type override required attrs" {
  let missing_part =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
    #|  <Override ContentType="application/xml"/>
    #|</Types>
    #|
  try parse_content_type_overrides(missing_part) catch {
    InvalidXml(msg~) =>
      inspect(msg, content="content type override part name missing")
  } noraise {
    _ => fail("expected content type override part name missing")
  }

  let missing_content_type =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
    #|  <Override PartName="/xl/workbook.xml"/>
    #|</Types>
    #|
  try parse_content_type_overrides(missing_content_type) catch {
    InvalidXml(msg~) =>
      inspect(msg, content="content type override content type missing")
  } noraise {
    _ => fail("expected content type override content type missing")
  }
}
