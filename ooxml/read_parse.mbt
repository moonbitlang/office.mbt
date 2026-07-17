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
let package_relationships_namespace = "http://schemas.openxmlformats.org/package/2006/relationships"

///|
let package_content_types_namespace = "http://schemas.openxmlformats.org/package/2006/content-types"

///|
/// Reads relationship targets whose decoded `Type` is in `rel_types`. Element
/// names are matched by expanded namespace name, so the package namespace may
/// use either a default namespace or any declared prefix.
pub fn parse_relationship_targets_by_types(
  xml : StringView,
  rel_types : ArrayView[String],
) -> Map[String, String] raise ParseXmlError {
  let max_records = 16_384
  let max_id_chars = 256
  let max_type_chars = 2_048
  let max_target_chars = 4_096
  let max_retained_chars = 8 * 1024 * 1024
  let targets : Map[String, String] = Map([])
  let scanner = XmlStartTagScanner::new(xml)
  let mut records = 0
  let mut retained_chars = 0
  while scanner.next() {
    if scanner.namespace_uri() != package_relationships_namespace ||
      scanner.local_name() != "Relationship" {
      continue
    }
    records = records + 1
    if records > max_records {
      raise InvalidXml(msg="relationship record limit exceeded")
    }
    let rel_view = match scanner.attribute_view("", "Type") {
      Some(value) => value
      None => continue
    }
    if rel_view.length() > max_type_chars {
      raise InvalidXml(msg="relationship type is too long")
    }
    let rel = decode_xml_attribute(rel_view)
    let mut wanted = false
    for rel_type in rel_types {
      if rel == rel_type {
        wanted = true
        break
      }
    }
    if !wanted {
      continue
    }
    let id_view = match scanner.attribute_view("", "Id") {
      Some(value) => value
      None => raise InvalidXml(msg="relationship id missing")
    }
    if id_view.length() > max_id_chars {
      raise InvalidXml(msg="relationship id is too long")
    }
    let target_view = match scanner.attribute_view("", "Target") {
      Some(value) => value
      None => raise InvalidXml(msg="relationship target missing")
    }
    if target_view.length() > max_target_chars {
      raise InvalidXml(msg="relationship target is too long")
    }
    let id = decode_xml_attribute(id_view)
    let target = decode_xml_attribute(target_view)
    let retained = id.length() + target.length()
    if retained > max_retained_chars - retained_chars {
      raise InvalidXml(msg="relationship retained text limit exceeded")
    }
    retained_chars = retained_chars + retained
    if targets.contains(id) {
      raise InvalidXml(msg="duplicate relationship id")
    }
    targets[id] = target
  }
  targets
}

///|
pub fn parse_relationship_targets(
  xml : StringView,
  rel_type : StringView,
) -> Map[String, String] raise ParseXmlError {
  parse_relationship_targets_by_types(xml, [rel_type.to_owned()])
}

///|
fn parse_content_type_overrides(
  xml : StringView,
) -> Map[String, String] raise ParseXmlError {
  let overrides : Map[String, String] = Map([])
  let scanner = XmlStartTagScanner::new(xml)
  while scanner.next() {
    if scanner.namespace_uri() != package_content_types_namespace ||
      scanner.local_name() != "Override" {
      continue
    }
    let part_name = match scanner.attribute("", "PartName") {
      Some(value) => value
      None => raise InvalidXml(msg="content type override part name missing")
    }
    let content_type = match scanner.attribute("", "ContentType") {
      Some(value) => value
      None => raise InvalidXml(msg="content type override content type missing")
    }
    if overrides.contains(part_name) {
      raise InvalidXml(msg="duplicate content type override")
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
