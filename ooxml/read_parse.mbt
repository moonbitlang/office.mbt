///|
pub suberror ParseXmlError {
  InvalidXml(msg~ : String)
  ReadCancelled
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
let markup_compatibility_namespace = "http://schemas.openxmlformats.org/markup-compatibility/2006"

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
/// Streaming state for the MCE-effective projection of an OPC Relationships
/// part. Each raw XML depth owns one state; wrapper elements selected by
/// `ProcessContent`, `Choice`, or `Fallback` retain their parent's effective
/// depth so their application children are promoted without materializing a
/// second XML tree.
priv struct RelationshipMceState {
  active : Bool
  included_in_effective_tree : Bool
  element_effective_depth : Int
  children_effective_parent_depth : Int
  ignorable_namespaces : Set[String]
  process_content_names : Set[String]
  is_alternate_content : Bool
  mut alternate_choice_seen : Bool
  mut alternate_fallback_seen : Bool
  mut alternate_selected : Bool
}

///|
fn clone_relationship_mce_set(source : Set[String]) -> Set[String] {
  let cloned : Set[String] = Set([])
  for value in source {
    cloned.add(value)
  }
  cloned
}

///|
fn relationship_mce_tokens(
  value : StringView,
  label : StringView,
) -> Array[String] raise ParseXmlError {
  let normalized = collapse_schema_whitespace(value)
  if normalized == "" {
    raise InvalidXml(msg="MCE \{label.to_owned()} is empty")
  }
  let tokens : Array[String] = []
  for token in normalized.split(" ") {
    if token == "" || token.length() > max_relationship_id_chars {
      raise InvalidXml(msg="MCE \{label.to_owned()} is invalid")
    }
    if tokens.length() >= 4096 {
      raise InvalidXml(msg="MCE \{label.to_owned()} token limit exceeded")
    }
    tokens.push(token.to_owned())
  }
  tokens
}

///|
fn relationship_mce_resolve_prefix(
  scanner : XmlStartTagScanner,
  prefix : StringView,
  label : StringView,
) -> String raise ParseXmlError {
  if prefix == "" || prefix.contains(":") {
    raise InvalidXml(msg="MCE \{label.to_owned()} prefix is invalid")
  }
  scanner.resolve_prefix(prefix, false)
}

///|
fn relationship_mce_expanded_name_key(
  scanner : XmlStartTagScanner,
  token : StringView,
  label : StringView,
) -> (String, String) raise ParseXmlError {
  let parts = token.split(":").collect()
  if parts.length() != 2 || parts[0] == "" || parts[1] == "" {
    raise InvalidXml(msg="MCE \{label.to_owned()} name is invalid")
  }
  let namespace_uri = relationship_mce_resolve_prefix(scanner, parts[0], label)
  (namespace_uri, namespace_uri + "\u{0}" + parts[1].to_owned())
}

///|
fn relationship_mce_scope(
  scanner : XmlStartTagScanner,
  parent : RelationshipMceState?,
) -> (Set[String], Set[String]) raise ParseXmlError {
  let ignorable_attribute = scanner.attribute(
    markup_compatibility_namespace, "Ignorable",
  )
  let ignorable = match (parent, ignorable_attribute) {
    (Some(value), None) => value.ignorable_namespaces
    (Some(value), Some(_)) =>
      clone_relationship_mce_set(value.ignorable_namespaces)
    (None, _) => Set([])
  }
  match ignorable_attribute {
    Some(value) =>
      for prefix in relationship_mce_tokens(value, "Ignorable") {
        let namespace_uri = relationship_mce_resolve_prefix(
          scanner, prefix, "Ignorable",
        )
        if namespace_uri == "" ||
          namespace_uri == markup_compatibility_namespace ||
          namespace_uri == package_relationships_namespace {
          raise InvalidXml(msg="MCE Ignorable namespace is invalid")
        }
        ignorable.add(namespace_uri)
      }
    None => ()
  }
  let process_content_attribute = scanner.attribute(
    markup_compatibility_namespace, "ProcessContent",
  )
  let process_content = match (parent, process_content_attribute) {
    (Some(value), None) => value.process_content_names
    (Some(value), Some(_)) =>
      clone_relationship_mce_set(value.process_content_names)
    (None, _) => Set([])
  }
  match process_content_attribute {
    Some(value) =>
      for token in relationship_mce_tokens(value, "ProcessContent") {
        let (namespace_uri, key) = relationship_mce_expanded_name_key(
          scanner, token, "ProcessContent",
        )
        if !ignorable.contains(namespace_uri) {
          raise InvalidXml(msg="MCE ProcessContent namespace is not ignorable")
        }
        if token.has_suffix(":*") {
          raise InvalidXml(msg="MCE ProcessContent wildcard is invalid")
        }
        process_content.add(key)
      }
    None => ()
  }
  match scanner.attribute(markup_compatibility_namespace, "MustUnderstand") {
    Some(value) =>
      for prefix in relationship_mce_tokens(value, "MustUnderstand") {
        if relationship_mce_resolve_prefix(scanner, prefix, "MustUnderstand") !=
          package_relationships_namespace {
          raise InvalidXml(msg="MCE MustUnderstand namespace is unsupported")
        }
      }
    None => ()
  }
  for directive in ["PreserveElements", "PreserveAttributes"] {
    match scanner.attribute(markup_compatibility_namespace, directive) {
      Some(value) =>
        for token in relationship_mce_tokens(value, directive) {
          let (namespace_uri, _) = relationship_mce_expanded_name_key(
            scanner, token, directive,
          )
          if !ignorable.contains(namespace_uri) {
            raise InvalidXml(msg="MCE \{directive} namespace is not ignorable")
          }
        }
      None => ()
    }
  }
  (ignorable, process_content)
}

///|
fn relationship_mce_choice_supported(
  scanner : XmlStartTagScanner,
) -> Bool raise ParseXmlError {
  let requires = match scanner.attribute("", "Requires") {
    Some(value) => value
    None => raise InvalidXml(msg="MCE Choice is missing Requires")
  }
  let mut supported = true
  for prefix in relationship_mce_tokens(requires, "Choice Requires") {
    if relationship_mce_resolve_prefix(scanner, prefix, "Choice Requires") !=
      package_relationships_namespace {
      supported = false
    }
  }
  supported
}

///|
fn trim_relationship_mce_states(
  states : Array[RelationshipMceState],
  next_depth : Int,
) -> Unit raise ParseXmlError {
  while states.length() >= next_depth {
    let state = states.pop().unwrap()
    if state.is_alternate_content && !state.alternate_choice_seen {
      raise InvalidXml(msg="MCE AlternateContent has no Choice element")
    }
  }
}

///|
fn relationship_mce_state_for_current_element(
  scanner : XmlStartTagScanner,
  states : Array[RelationshipMceState],
) -> RelationshipMceState raise ParseXmlError {
  let depth = scanner.depth()
  trim_relationship_mce_states(states, depth)
  let parent = if depth > 1 {
    if states.length() != depth - 1 {
      raise InvalidXml(msg="relationships document nesting is invalid")
    }
    Some(states[depth - 2])
  } else {
    None
  }
  match parent {
    Some(parent_state) if !parent_state.active =>
      return {
        active: false,
        included_in_effective_tree: false,
        element_effective_depth: parent_state.children_effective_parent_depth,
        children_effective_parent_depth: parent_state.children_effective_parent_depth,
        ignorable_namespaces: parent_state.ignorable_namespaces,
        process_content_names: parent_state.process_content_names,
        is_alternate_content: false,
        alternate_choice_seen: false,
        alternate_fallback_seen: false,
        alternate_selected: false,
      }
    _ => ()
  }
  let (ignorable, process_content) = relationship_mce_scope(scanner, parent)
  if depth == 1 {
    if scanner.namespace_uri() != package_relationships_namespace ||
      scanner.local_name() != "Relationships" {
      raise InvalidXml(msg="relationships document element invalid")
    }
    return {
      active: true,
      included_in_effective_tree: true,
      element_effective_depth: 1,
      children_effective_parent_depth: 1,
      ignorable_namespaces: ignorable,
      process_content_names: process_content,
      is_alternate_content: false,
      alternate_choice_seen: false,
      alternate_fallback_seen: false,
      alternate_selected: false,
    }
  }
  let parent_state = parent.unwrap()
  let namespace_uri = scanner.namespace_uri().to_owned()
  let local_name = scanner.local_name().to_owned()
  let parent_effective_depth = parent_state.children_effective_parent_depth
  let mut active = parent_state.active
  let mut included_in_effective_tree = false
  let mut element_effective_depth = parent_effective_depth
  let mut children_effective_parent_depth = parent_effective_depth
  let mut is_alternate_content = false

  if parent_state.is_alternate_content {
    if namespace_uri == markup_compatibility_namespace && local_name == "Choice" {
      if parent_state.alternate_fallback_seen {
        raise InvalidXml(msg="MCE Choice follows Fallback")
      }
      parent_state.alternate_choice_seen = true
      let supported = relationship_mce_choice_supported(scanner)
      active = parent_state.active &&
        !parent_state.alternate_selected &&
        supported
      if active {
        parent_state.alternate_selected = true
      }
    } else if namespace_uri == markup_compatibility_namespace &&
      local_name == "Fallback" {
      if parent_state.alternate_fallback_seen {
        raise InvalidXml(
          msg="MCE AlternateContent has multiple Fallback elements",
        )
      }
      parent_state.alternate_fallback_seen = true
      active = parent_state.active && !parent_state.alternate_selected
      if active {
        parent_state.alternate_selected = true
      }
    } else if ignorable.contains(namespace_uri) {
      active = false
    } else {
      raise InvalidXml(msg="MCE AlternateContent child is invalid")
    }
  } else if namespace_uri == markup_compatibility_namespace {
    if local_name != "AlternateContent" {
      raise InvalidXml(msg="MCE element is misplaced")
    }
    active = parent_state.active
    is_alternate_content = true
  } else if ignorable.contains(namespace_uri) &&
    namespace_uri != package_relationships_namespace {
    let key = namespace_uri + "\u{0}" + local_name
    if process_content.contains(key) {
      if scanner.attribute(xml_namespace_uri, "base") is Some(_) ||
        scanner.attribute(xml_namespace_uri, "lang") is Some(_) ||
        scanner.attribute(xml_namespace_uri, "space") is Some(_) {
        raise InvalidXml(
          msg="MCE ProcessContent element has an unsafe xml attribute",
        )
      }
      active = parent_state.active
    } else {
      active = false
    }
  } else {
    active = parent_state.active
    included_in_effective_tree = true
    element_effective_depth = parent_effective_depth + 1
    children_effective_parent_depth = element_effective_depth
  }
  {
    active,
    included_in_effective_tree,
    element_effective_depth,
    children_effective_parent_depth,
    ignorable_namespaces: ignorable,
    process_content_names: process_content,
    is_alternate_content,
    alternate_choice_seen: false,
    alternate_fallback_seen: false,
    alternate_selected: false,
  }
}

///|
/// Reads relationship targets whose decoded `Type` is in `rel_types`. Element
/// names are matched by expanded namespace name, so the package namespace may
/// use either a default namespace or any declared prefix.
fn parse_relationship_targets_by_types_selected(
  xml : StringView,
  rel_types : ArrayView[String],
  selection : RelationshipTargetSelection,
  cancelled? : () -> Bool = () => false,
) -> Map[String, String] raise ParseXmlError {
  let targets : Map[String, String] = Map([])
  let ids : Set[String] = Set([])
  let scanner = XmlStartTagScanner::new(xml, cancelled~)
  let mce_states : Array[RelationshipMceState] = []
  let mut records = 0
  let mut retained_chars = 0
  while scanner.next() {
    let mce_state = relationship_mce_state_for_current_element(
      scanner, mce_states,
    )
    mce_states.push(mce_state)
    if mce_state.element_effective_depth == 1 {
      continue
    }
    if !mce_state.active || !mce_state.included_in_effective_tree {
      continue
    }
    if scanner.namespace_uri() != package_relationships_namespace ||
      scanner.local_name() != "Relationship" ||
      mce_state.element_effective_depth != 2 {
      raise InvalidXml(msg="relationships effective content is invalid")
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
  trim_relationship_mce_states(mce_states, 1)
  targets
}

///|
/// Reads internal relationship targets whose decoded `Type` is in
/// `rel_types`. Explicitly external records are validated but excluded.
pub fn parse_internal_relationship_targets_by_types(
  xml : StringView,
  rel_types : ArrayView[String],
  cancelled? : () -> Bool = () => false,
) -> Map[String, String] raise ParseXmlError {
  parse_relationship_targets_by_types_selected(
    xml,
    rel_types,
    InternalTargets,
    cancelled~,
  )
}

///|
/// Reads internal relationship targets whose decoded `Type` is `rel_type`.
pub fn parse_internal_relationship_targets(
  xml : StringView,
  rel_type : StringView,
  cancelled? : () -> Bool = () => false,
) -> Map[String, String] raise ParseXmlError {
  parse_internal_relationship_targets_by_types(
    xml,
    [rel_type.to_owned()],
    cancelled~,
  )
}

///|
/// Reads explicitly external relationship targets whose decoded `Type` is in
/// `rel_types`. Internal records are validated but excluded.
pub fn parse_external_relationship_targets_by_types(
  xml : StringView,
  rel_types : ArrayView[String],
  cancelled? : () -> Bool = () => false,
) -> Map[String, String] raise ParseXmlError {
  parse_relationship_targets_by_types_selected(
    xml,
    rel_types,
    ExternalTargets,
    cancelled~,
  )
}

///|
/// Reads explicitly external relationship targets whose decoded `Type` is
/// `rel_type`.
pub fn parse_external_relationship_targets(
  xml : StringView,
  rel_type : StringView,
  cancelled? : () -> Bool = () => false,
) -> Map[String, String] raise ParseXmlError {
  parse_external_relationship_targets_by_types(
    xml,
    [rel_type.to_owned()],
    cancelled~,
  )
}

///|
priv struct PackageContentTypes {
  overrides : Map[String, String]
  override_part_names : Map[String, String]
  defaults : Map[String, String]
}

///|
/// Returns the ASCII-case-insensitive identity key used for OPC part names.
/// The leading slash, when present, remains part of the key.
pub fn package_part_name_key(name : StringView) -> String {
  try! package_part_name_key_cancellable(name)
}

///|
/// Cancellation-aware form of `package_part_name_key`. It performs the same
/// ASCII-only case fold while polling at least once per 4,096 UTF-16 code
/// units.
pub fn package_part_name_key_cancellable(
  name : StringView,
  cancelled? : () -> Bool = () => false,
) -> String raise ParseXmlError {
  if cancelled() {
    raise ReadCancelled
  }
  let output = StringBuilder::new(size_hint=name.length())
  let mut offset = 0
  for character in name {
    if offset % 4096 == 0 && cancelled() {
      raise ReadCancelled
    }
    output.write_char(character.to_ascii_lowercase())
    offset = offset + (if character.to_int() > 0xffff { 2 } else { 1 })
  }
  output.to_string()
}

///|
fn parse_content_types(
  xml : StringView,
  cancelled? : () -> Bool = () => false,
) -> PackageContentTypes raise ParseXmlError {
  let overrides : Map[String, String] = Map([])
  let override_part_names : Map[String, String] = Map([])
  let defaults : Map[String, String] = Map([])
  let scanner = XmlStartTagScanner::new(xml, cancelled~)
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
        let part_name_key = package_part_name_key(part_name)
        if overrides.contains(part_name_key) {
          raise InvalidXml(msg="duplicate content type override")
        }
        overrides[part_name_key] = content_type
        override_part_names[part_name_key] = part_name
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
  { overrides, override_part_names, defaults }
}

///|
pub fn find_override_part_by_content_types(
  xml : StringView,
  content_types : ArrayView[String],
  cancelled? : () -> Bool = () => false,
) -> String? raise ParseXmlError {
  let content_types_value = parse_content_types(xml, cancelled~)
  for wanted in content_types {
    for part_name_key, content_type in content_types_value.overrides {
      if content_type == wanted {
        return content_types_value.override_part_names.get(part_name_key)
      }
    }
  }
  None
}

///|
/// Returns the declared content type for `part_name`. An ASCII-case-insensitive
/// OPC part-name override wins; otherwise the case-insensitive extension
/// default is used.
pub fn find_part_content_type(
  xml : StringView,
  part_name : StringView,
  cancelled? : () -> Bool = () => false,
) -> String? raise ParseXmlError {
  let content_types_value = parse_content_types(xml, cancelled~)
  let normalized = if part_name.has_prefix("/") {
    part_name.to_owned()
  } else {
    "/" + part_name.to_owned()
  }
  match content_types_value.overrides.get(package_part_name_key(normalized)) {
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
    _ => fail("unexpected relationship parse cancellation")
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
    _ => fail("unexpected content type parse cancellation")
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
    _ => fail("unexpected content type parse cancellation")
  } noraise {
    _ => fail("expected content type override content type missing")
  }
}
