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
let max_relationship_records = 1_000_000

///|
let max_relationship_id_chars = 1024

///|
let max_relationship_type_chars : Int = 16 * 1024

///|
let max_relationship_target_chars : Int = 16 * 1024 * 1024

///|
let max_relationship_retained_chars : Int = 16 * 1024 * 1024

///|
fn collapse_schema_whitespace(value : StringView) -> String {
  let output = StringBuilder::new()
  let mut pending_space = false
  let mut wrote = false
  for unit in value {
    if unit == ' ' || unit == '\t' || unit == '\n' || unit == '\r' {
      if wrote {
        pending_space = true
      }
    } else {
      if pending_space {
        output.write_char(' ')
        pending_space = false
      }
      output.write_char(unit)
      wrote = true
    }
  }
  output.to_string()
}

///|
fn relationship_attribute(
  scanner : XmlStartTagScanner,
  name : StringView,
) -> String raise ParseXmlError {
  let value = match scanner.attribute("", name) {
    Some(value) => collapse_schema_whitespace(value)
    None =>
      raise InvalidXml(msg="relationship \{name.to_owned().to_lower()} missing")
  }
  if value == "" {
    raise InvalidXml(msg="relationship \{name.to_owned().to_lower()} is empty")
  }
  value
}

///|
priv enum ParsedRelationshipTargetMode {
  InternalTarget
  ExternalTarget
}

///|
fn relationship_target_mode(
  scanner : XmlStartTagScanner,
) -> ParsedRelationshipTargetMode raise ParseXmlError {
  match scanner.attribute("", "TargetMode") {
    None => InternalTarget
    Some(value) =>
      match collapse_schema_whitespace(value) {
        "Internal" => InternalTarget
        "External" => ExternalTarget
        _ => raise InvalidXml(msg="relationship target mode invalid")
      }
  }
}

///|
priv enum RelationshipTargetSelection {
  InternalTargets
  ExternalTargets
}

///|
/// Reads relationship targets whose decoded `Type` is in `rel_types`. Element
/// names are matched by expanded namespace name, so the package namespace may
/// use either a default namespace or any declared prefix.
fn parse_relationship_targets_by_types_selected(
  xml : StringView,
  rel_types : ArrayView[String],
  selection : RelationshipTargetSelection,
) -> Map[String, String] raise ParseXmlError {
  let targets : Map[String, String] = Map([])
  let ids : Set[String] = Set([])
  let scanner = XmlStartTagScanner::new(xml)
  if !scanner.next() ||
    scanner.depth() != 1 ||
    scanner.namespace_uri() != package_relationships_namespace ||
    scanner.local_name() != "Relationships" {
    raise InvalidXml(msg="relationships document element invalid")
  }
  let mut records = 0
  let mut retained_chars = 0
  while scanner.next() {
    if scanner.namespace_uri() != package_relationships_namespace ||
      scanner.local_name() != "Relationship" {
      continue
    }
    if scanner.depth() != 2 {
      raise InvalidXml(msg="relationship element is not a direct child")
    }
    records = records + 1
    if records > max_relationship_records {
      raise InvalidXml(msg="relationship record limit exceeded")
    }
    let rel = relationship_attribute(scanner, "Type")
    let id = relationship_attribute(scanner, "Id")
    let target = relationship_attribute(scanner, "Target")
    let target_mode = relationship_target_mode(scanner)
    if rel.length() > max_relationship_type_chars {
      raise InvalidXml(msg="relationship type is too long")
    }
    if id.length() > max_relationship_id_chars {
      raise InvalidXml(msg="relationship id is too long")
    }
    if target.length() > max_relationship_target_chars {
      raise InvalidXml(msg="relationship target is too long")
    }
    if ids.contains(id) {
      raise InvalidXml(msg="duplicate relationship id")
    }
    ids.add(id)
    let retained = id.length() + target.length()
    if retained > max_relationship_retained_chars - retained_chars {
      raise InvalidXml(msg="relationship retained text limit exceeded")
    }
    retained_chars = retained_chars + retained
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
    let selected = match (selection, target_mode) {
      (InternalTargets, InternalTarget) | (ExternalTargets, ExternalTarget) =>
        true
      _ => false
    }
    if !selected {
      continue
    }
    targets[id] = target
  }
  targets
}

///|
/// Reads internal relationship targets whose decoded `Type` is in
/// `rel_types`. Explicitly external records are validated but excluded.
pub fn parse_internal_relationship_targets_by_types(
  xml : StringView,
  rel_types : ArrayView[String],
) -> Map[String, String] raise ParseXmlError {
  parse_relationship_targets_by_types_selected(xml, rel_types, InternalTargets)
}

///|
pub fn parse_internal_relationship_targets(
  xml : StringView,
  rel_type : StringView,
) -> Map[String, String] raise ParseXmlError {
  parse_internal_relationship_targets_by_types(xml, [rel_type.to_owned()])
}

///|
/// Reads explicitly external relationship targets whose decoded `Type` is in
/// `rel_types`. Internal records are validated but excluded.
pub fn parse_external_relationship_targets_by_types(
  xml : StringView,
  rel_types : ArrayView[String],
) -> Map[String, String] raise ParseXmlError {
  parse_relationship_targets_by_types_selected(xml, rel_types, ExternalTargets)
}

///|
pub fn parse_external_relationship_targets(
  xml : StringView,
  rel_type : StringView,
) -> Map[String, String] raise ParseXmlError {
  parse_external_relationship_targets_by_types(xml, [rel_type.to_owned()])
}

///|
priv struct PackageContentTypes {
  overrides : Map[String, String]
  defaults : Map[String, String]
}

///|
fn parse_content_types(
  xml : StringView,
) -> PackageContentTypes raise ParseXmlError {
  let overrides : Map[String, String] = Map([])
  let defaults : Map[String, String] = Map([])
  let scanner = XmlStartTagScanner::new(xml)
  if !scanner.next() ||
    scanner.depth() != 1 ||
    scanner.namespace_uri() != package_content_types_namespace ||
    scanner.local_name() != "Types" {
    raise InvalidXml(msg="content types document element invalid")
  }
  while scanner.next() {
    if scanner.namespace_uri() != package_content_types_namespace {
      continue
    }
    if scanner.depth() != 2 {
      raise InvalidXml(msg="content type record is not a direct child")
    }
    match scanner.local_name() {
      "Override" => {
        let part_name = match scanner.attribute("", "PartName") {
          Some(value) => collapse_schema_whitespace(value)
          None =>
            raise InvalidXml(msg="content type override part name missing")
        }
        let content_type = match scanner.attribute("", "ContentType") {
          Some(value) => collapse_schema_whitespace(value)
          None =>
            raise InvalidXml(msg="content type override content type missing")
        }
        if part_name == "" || content_type == "" {
          raise InvalidXml(msg="content type override value is empty")
        }
        if overrides.contains(part_name) {
          raise InvalidXml(msg="duplicate content type override")
        }
        overrides[part_name] = content_type
      }
      "Default" => {
        let extension = match scanner.attribute("", "Extension") {
          Some(value) => collapse_schema_whitespace(value).to_lower()
          None => raise InvalidXml(msg="content type default extension missing")
        }
        let content_type = match scanner.attribute("", "ContentType") {
          Some(value) => collapse_schema_whitespace(value)
          None =>
            raise InvalidXml(msg="content type default content type missing")
        }
        if extension == "" || content_type == "" {
          raise InvalidXml(msg="content type default value is empty")
        }
        if defaults.contains(extension) {
          raise InvalidXml(msg="duplicate content type default")
        }
        defaults[extension] = content_type
      }
      _ => raise InvalidXml(msg="content types element is invalid")
    }
  }
  { overrides, defaults }
}

///|
pub fn find_override_part_by_content_types(
  xml : StringView,
  content_types : ArrayView[String],
) -> String? raise ParseXmlError {
  let content_types_value = parse_content_types(xml)
  for wanted in content_types {
    for part_name, content_type in content_types_value.overrides {
      if content_type == wanted {
        return Some(part_name)
      }
    }
  }
  None
}

///|
/// Returns the declared content type for `part_name`. An exact override wins;
/// otherwise the case-insensitive extension default is used.
pub fn find_part_content_type(
  xml : StringView,
  part_name : StringView,
) -> String? raise ParseXmlError {
  let content_types_value = parse_content_types(xml)
  let normalized = if part_name.has_prefix("/") {
    part_name.to_owned()
  } else {
    "/" + part_name.to_owned()
  }
  match content_types_value.overrides.get(normalized) {
    Some(value) => Some(value)
    None => {
      let filename = match normalized.rev_find("/") {
        Some(index) => normalized[index + 1:]
        None => normalized
      }
      let extension = match filename.rev_find(".") {
        Some(index) if index + 1 < filename.length() =>
          filename[index + 1:].to_owned().to_lower()
        _ => return None
      }
      content_types_value.defaults.get(extension)
    }
  }
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
test "ooxml read_parse wb: every relationship record is validated" {
  let xml =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    #|  <Relationship Id="rId1" Target="a.xml"/>
    #|</Relationships>
    #|
  try parse_internal_relationship_targets(xml, "t1") catch {
    InvalidXml(msg~) => inspect(msg, content="relationship type missing")
  } noraise {
    _ => fail("expected relationship type missing")
  }
}

///|
test "ooxml read_parse wb: content-type override required attrs" {
  let missing_part =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
    #|  <Override ContentType="application/xml"/>
    #|</Types>
    #|
  try parse_content_types(missing_part) catch {
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
  try parse_content_types(missing_content_type) catch {
    InvalidXml(msg~) =>
      inspect(msg, content="content type override content type missing")
  } noraise {
    _ => fail("expected content type override content type missing")
  }
}
