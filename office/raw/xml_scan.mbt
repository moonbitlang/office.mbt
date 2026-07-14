///|
let raw_max_edit_part_bytes : Int = 16 * 1024 * 1024

///|
let raw_max_xml_nodes = 100_000

///|
let raw_max_path_candidates = 4096

///|
let raw_max_xml_attributes = 400_000

///|
let raw_max_xml_namespace_declarations = 32_768

///|
let raw_max_xml_depth = 256

///|
let raw_max_xml_name_bytes = 1024

///|
let raw_max_xml_attribute_value_bytes : Int = 1024 * 1024

///|
let raw_max_xml_attributes_per_element = 4096

///|
let raw_max_source_namespace_uri_bytes = 2048

///|
let raw_max_in_scope_namespaces = 256

///|
let raw_max_expanded_name_bytes : Int = 16 * 1024 * 1024

///|
let raw_max_namespace_scope_work = 2_000_000

///|
let raw_metadata_max_bytes : Int = 8 * 1024 * 1024

///|
let raw_metadata_max_nodes = 16_384

///|
let raw_metadata_max_attributes = 65_536

///|
let raw_metadata_max_namespace_declarations = 4096

///|
let raw_metadata_max_attribute_value_bytes = 4096

///|
let raw_metadata_max_expanded_name_bytes : Int = 4 * 1024 * 1024

///|
let raw_metadata_max_namespace_scope_work = 500_000

///|
priv struct RawXmlBudget {
  max_nodes : Int
  max_attributes : Int
  max_namespace_declarations : Int
  max_text_bytes : Int
  max_attribute_value_bytes : Int
  max_expanded_name_bytes : Int
  max_namespace_scope_work : Int
}

///|
priv struct RawNamespaceDeclaration {
  prefix : String
  uri : String
}

///|
priv struct RawAttributeSpan {
  expanded : String
  value : String
  value_start : Int
  value_end : Int
}

///|
priv struct RawXmlNode {
  raw_name : String
  expanded : String
  parent : Int
  sibling_position : Int
  start : Int
  start_tag_end : Int
  tag_insert_offset : Int
  self_closing : Bool
  mut end_tag_start : Int
  mut end : Int
  attributes : Array[RawAttributeSpan]
  declarations : Array[RawNamespaceDeclaration]
}

///|
priv struct RawXmlDocument {
  bytes : BytesView
  nodes : Array[RawXmlNode]
}

///|
fn raw_document_uses_strict_ooxml(document : RawXmlDocument) -> Bool {
  for node in document.nodes {
    if node.parent == -1 {
      return node.expanded.has_prefix("{http://purl.oclc.org/ooxml/")
    }
  }
  false
}

///|
priv struct RawLexicalAttribute {
  name : String
  value : String
  value_start : Int
  value_end : Int
}

///|
priv struct RawOpenTag {
  name : String
  attributes : Array[RawLexicalAttribute]
  gt : Int
  insert_at : Int
  self_closing : Bool
}

///|
fn raw_xml_scan_error(name : String, message : String) -> RawError {
  raw_error(
    "office.raw.invalid_xml",
    "cannot safely scan XML part '/\{name}': \{message}",
    details=Json::object({ "part": Json::string("/" + name) }),
  )
}

///|
fn raw_xml_resource_limit(
  part : String,
  kind : String,
  limit : Int,
  actual : Int,
) -> RawError {
  raw_error(
    "office.raw.resource_limit",
    "XML part '/\{part}' exceeds the \{kind} limit of \{limit}",
    details=Json::object({
      "part": Json::string("/" + part),
      "kind": Json::string(kind),
      "limit": Json::number(limit.to_double()),
      "actual": Json::number(actual.to_double()),
    }),
  )
}

///|
fn raw_byte_is_space(value : Byte) -> Bool {
  value == b' ' || value == b'\t' || value == b'\r' || value == b'\n'
}

///|
fn raw_slice_text(
  name : String,
  bytes : BytesView,
  start : Int,
  end : Int,
) -> String raise RawError {
  @utf8.decode(bytes[start:end]) catch {
    _ => raise raw_xml_scan_error(name, "source span is not valid UTF-8")
  }
}

///|
fn raw_xml_character(character : Char) -> Bool {
  let code = character.to_int()
  code == 0x9 ||
  code == 0xa ||
  code == 0xd ||
  (code >= 0x20 && code <= 0xd7ff) ||
  (code >= 0xe000 && code <= 0xfffd) ||
  (code >= 0x10000 && code <= 0x10ffff)
}

///|
fn raw_numeric_entity(entity : String, part : String) -> String raise RawError {
  let (base, start) = if entity.has_prefix("#x") {
    (16, 2)
  } else if entity.has_prefix("#") {
    (10, 1)
  } else {
    raise raw_xml_scan_error(part, "encountered an undeclared XML entity")
  }
  if start >= entity.length() {
    raise raw_xml_scan_error(part, "encountered an empty numeric XML entity")
  }
  let mut codepoint = 0
  for index = start; index < entity.length(); index = index + 1 {
    let character = entity[index]
    let digit = if character >= '0' && character <= '9' {
      character.to_int() - '0'.to_int()
    } else if base == 16 && character >= 'A' && character <= 'F' {
      character.to_int() - 'A'.to_int() + 10
    } else if base == 16 && character >= 'a' && character <= 'f' {
      character.to_int() - 'a'.to_int() + 10
    } else {
      raise raw_xml_scan_error(
        part, "encountered a malformed numeric XML entity",
      )
    }
    if codepoint > (0x10ffff - digit) / base {
      raise raw_xml_scan_error(part, "numeric XML entity is out of range")
    }
    codepoint = codepoint * base + digit
  }
  match Int::to_char(codepoint) {
    Some(character) if raw_xml_character(character) => character.to_string()
    _ =>
      raise raw_xml_scan_error(part, "numeric entity is not an XML character")
  }
}

///|
fn raw_decode_entity(entity : String, part : String) -> String raise RawError {
  match entity {
    "amp" => "&"
    "lt" => "<"
    "gt" => ">"
    "quot" => "\""
    "apos" => "'"
    _ => raw_numeric_entity(entity, part)
  }
}

///|
fn raw_decode_attribute_value(
  source : String,
  part : String,
) -> String raise RawError {
  let normalized = StringBuilder::new()
  let mut offset = 0
  while offset < source.length() {
    let character = match source.get_char(offset) {
      Some(value) => value
      None =>
        raise raw_xml_scan_error(part, "attribute contains invalid UTF-16")
    }
    if character == '\r' {
      let next = offset + character.utf16_len()
      if next < source.length() && source[next] == '\n' {
        offset = next
      }
      normalized.write_char(' ') |> ignore
    } else if character == '\t' || character == '\n' {
      normalized.write_char(' ') |> ignore
    } else {
      normalized.write_char(character) |> ignore
    }
    offset = offset + character.utf16_len()
  }
  let value = normalized.to_string()
  let output = StringBuilder::new()
  offset = 0
  while offset < value.length() {
    if value[offset] == '&' {
      let length = match value[offset:].find(";") {
        Some(found) => found
        None =>
          raise raw_xml_scan_error(part, "attribute has an unterminated entity")
      }
      let entity = value[offset + 1:offset + length].to_owned()
      output.write_string(raw_decode_entity(entity, part)) |> ignore
      offset = offset + length + 1
    } else {
      let character = match value.get_char(offset) {
        Some(found) => found
        None =>
          raise raw_xml_scan_error(part, "attribute contains invalid UTF-16")
      }
      output.write_char(character) |> ignore
      offset = offset + character.utf16_len()
    }
  }
  output.to_string()
}

///|
fn raw_scan_open_tag(
  part : String,
  bytes : BytesView,
  start : Int,
) -> RawOpenTag raise RawError {
  let limit = bytes.length()
  let mut offset = start + 1
  let name_start = offset
  while offset < limit &&
        !raw_byte_is_space(bytes[offset]) &&
        bytes[offset] != b'>' &&
        bytes[offset] != b'/' {
    offset = offset + 1
  }
  if offset == name_start {
    raise raw_xml_scan_error(part, "start tag has no name")
  }
  if offset - name_start > raw_max_xml_name_bytes {
    raise raw_xml_resource_limit(
      part,
      "xml_name_bytes",
      raw_max_xml_name_bytes,
      offset - name_start,
    )
  }
  let tag_name = raw_slice_text(part, bytes, name_start, offset)
  let attributes : Array[RawLexicalAttribute] = []
  for ;; {
    while offset < limit && raw_byte_is_space(bytes[offset]) {
      offset = offset + 1
    }
    if offset >= limit {
      raise raw_xml_scan_error(part, "start tag is unterminated")
    }
    if bytes[offset] == b'>' {
      return {
        name: tag_name,
        attributes,
        gt: offset,
        insert_at: offset,
        self_closing: false,
      }
    }
    if bytes[offset] == b'/' && offset + 1 < limit && bytes[offset + 1] == b'>' {
      return {
        name: tag_name,
        attributes,
        gt: offset + 1,
        insert_at: offset,
        self_closing: true,
      }
    }
    let attribute_start = offset
    while offset < limit &&
          !raw_byte_is_space(bytes[offset]) &&
          bytes[offset] != b'=' &&
          bytes[offset] != b'>' &&
          bytes[offset] != b'/' {
      offset = offset + 1
    }
    if offset == attribute_start {
      raise raw_xml_scan_error(part, "start tag contains a malformed attribute")
    }
    if offset - attribute_start > raw_max_xml_name_bytes {
      raise raw_xml_resource_limit(
        part,
        "xml_name_bytes",
        raw_max_xml_name_bytes,
        offset - attribute_start,
      )
    }
    let attribute_name = raw_slice_text(part, bytes, attribute_start, offset)
    while offset < limit && raw_byte_is_space(bytes[offset]) {
      offset = offset + 1
    }
    if offset >= limit || bytes[offset] != b'=' {
      raise raw_xml_scan_error(part, "attribute is missing '='")
    }
    offset = offset + 1
    while offset < limit && raw_byte_is_space(bytes[offset]) {
      offset = offset + 1
    }
    if offset >= limit || !(bytes[offset] == b'"' || bytes[offset] == b'\'') {
      raise raw_xml_scan_error(part, "attribute value must be quoted")
    }
    let quote = bytes[offset]
    offset = offset + 1
    let value_start = offset
    while offset < limit && bytes[offset] != quote {
      offset = offset + 1
    }
    if offset >= limit {
      raise raw_xml_scan_error(part, "attribute value is unterminated")
    }
    if offset - value_start > raw_max_xml_attribute_value_bytes {
      raise raw_xml_resource_limit(
        part,
        "xml_attribute_value_bytes",
        raw_max_xml_attribute_value_bytes,
        offset - value_start,
      )
    }
    let raw_value = raw_slice_text(part, bytes, value_start, offset)
    if attributes.length() >= raw_max_xml_attributes_per_element {
      raise raw_xml_resource_limit(
        part,
        "xml_attributes_per_element",
        raw_max_xml_attributes_per_element,
        attributes.length() + 1,
      )
    }
    attributes.push({
      name: attribute_name,
      value: raw_decode_attribute_value(raw_value, part),
      value_start,
      value_end: offset,
    })
    offset = offset + 1
  }
}

///|
fn preflight_raw_xml(
  part : String,
  bytes : BytesView,
  budget : RawXmlBudget,
) -> Unit raise RawError {
  let mut nodes = 0
  let mut attributes = 0
  let mut namespace_declarations = 0
  let mut text_bytes = 0
  let mut expanded_name_bytes = 0
  let mut namespace_scope_work = 0
  let mut depth = 0
  let namespaces : StableStringMap[String] = SortedMap([
    ("xml", "http://www.w3.org/XML/1998/namespace"),
  ])
  let namespace_undo_stack : Array[Array[(String, String?)]] = []
  let mut offset = 0
  while offset < bytes.length() {
    if bytes[offset] != b'<' {
      text_bytes = text_bytes + 1
      if text_bytes > budget.max_text_bytes {
        raise raw_xml_resource_limit(
          part,
          "xml_text_bytes",
          budget.max_text_bytes,
          text_bytes,
        )
      }
      offset = offset + 1
      continue
    }
    if raw_starts_with_at(bytes, offset, b"<!--") {
      let finish = match raw_find_sequence(bytes, offset + 4, b"-->") {
        Some(value) => value
        None => raise raw_xml_scan_error(part, "comment is unterminated")
      }
      offset = finish + 3
      continue
    }
    if raw_starts_with_at(bytes, offset, b"<![CDATA[") {
      let finish = match raw_find_sequence(bytes, offset + 9, b"]]>") {
        Some(value) => value
        None => raise raw_xml_scan_error(part, "CDATA section is unterminated")
      }
      let length = finish - offset - 9
      if length > budget.max_text_bytes - text_bytes {
        raise raw_xml_resource_limit(
          part,
          "xml_text_bytes",
          budget.max_text_bytes,
          budget.max_text_bytes + 1,
        )
      }
      text_bytes = text_bytes + length
      offset = finish + 3
      continue
    }
    if raw_starts_with_at(bytes, offset, b"<?") {
      let finish = match raw_find_sequence(bytes, offset + 2, b"?>") {
        Some(value) => value
        None =>
          raise raw_xml_scan_error(
            part, "processing instruction is unterminated",
          )
      }
      offset = finish + 2
      continue
    }
    if raw_starts_with_at(bytes, offset, b"</") {
      let (_, finish) = raw_scan_closing_tag(part, bytes, offset)
      depth = depth - 1
      if depth < 0 {
        raise raw_xml_scan_error(part, "closing tag has no open element")
      }
      match namespace_undo_stack.pop() {
        Some(undo) => raw_restore_namespaces(namespaces, undo)
        None => raise raw_xml_scan_error(part, "namespace stack is incomplete")
      }
      offset = finish + 1
      continue
    }
    if raw_starts_with_at(bytes, offset, b"<!") {
      raise raw_xml_scan_error(
        part, "DTD and declaration nodes are not supported",
      )
    }
    let tag = raw_scan_open_tag(part, bytes, offset)
    nodes = nodes + 1
    if nodes > budget.max_nodes {
      raise raw_xml_resource_limit(
        part,
        "xml_elements",
        budget.max_nodes,
        nodes,
      )
    }
    if tag.attributes.length() > budget.max_attributes - attributes {
      raise raw_xml_resource_limit(
        part,
        "xml_attributes",
        budget.max_attributes,
        budget.max_attributes + 1,
      )
    }
    attributes = attributes + tag.attributes.length()
    for attribute in tag.attributes {
      let value_bytes = attribute.value_end - attribute.value_start
      if value_bytes > budget.max_attribute_value_bytes {
        raise raw_xml_resource_limit(
          part,
          "xml_attribute_value_bytes",
          budget.max_attribute_value_bytes,
          value_bytes,
        )
      }
      if attribute.name == "xmlns" || attribute.name.has_prefix("xmlns:") {
        namespace_declarations = namespace_declarations + 1
        if namespace_declarations > budget.max_namespace_declarations {
          raise raw_xml_resource_limit(
            part,
            "xml_namespace_declarations",
            budget.max_namespace_declarations,
            namespace_declarations,
          )
        }
        if value_bytes > raw_max_source_namespace_uri_bytes {
          raise raw_xml_resource_limit(
            part, "xml_namespace_uri_bytes", raw_max_source_namespace_uri_bytes,
            value_bytes,
          )
        }
      }
    }
    let (_, namespace_undo) = raw_apply_namespace_declarations(
      part, tag, namespaces,
    )
    let expanded = raw_expand_source_name(
      part,
      tag.name,
      namespaces,
      attribute=false,
    )
    let expanded_bytes = raw_expanded_name_bytes(expanded)
    if expanded_bytes > budget.max_expanded_name_bytes - expanded_name_bytes {
      raise raw_xml_resource_limit(
        part,
        "xml_expanded_name_bytes",
        budget.max_expanded_name_bytes,
        budget.max_expanded_name_bytes + 1,
      )
    }
    expanded_name_bytes = expanded_name_bytes + expanded_bytes
    for attribute in tag.attributes {
      if attribute.name == "xmlns" || attribute.name.has_prefix("xmlns:") {
        continue
      }
      let expanded_attribute = raw_expand_source_name(
        part,
        attribute.name,
        namespaces,
        attribute=true,
      )
      let expanded_attribute_bytes = raw_expanded_name_bytes(expanded_attribute)
      if expanded_attribute_bytes >
        budget.max_expanded_name_bytes - expanded_name_bytes {
        raise raw_xml_resource_limit(
          part,
          "xml_expanded_name_bytes",
          budget.max_expanded_name_bytes,
          budget.max_expanded_name_bytes + 1,
        )
      }
      expanded_name_bytes = expanded_name_bytes + expanded_attribute_bytes
    }
    if namespaces.length() >
      budget.max_namespace_scope_work - namespace_scope_work {
      raise raw_xml_resource_limit(
        part,
        "xml_namespace_scope_work",
        budget.max_namespace_scope_work,
        budget.max_namespace_scope_work + 1,
      )
    }
    namespace_scope_work = namespace_scope_work + namespaces.length()
    if !tag.self_closing {
      depth = depth + 1
      if depth > raw_max_xml_depth {
        raise raw_xml_resource_limit(
          part, "xml_depth", raw_max_xml_depth, depth,
        )
      }
      namespace_undo_stack.push(namespace_undo)
    } else {
      raw_restore_namespaces(namespaces, namespace_undo)
    }
    offset = tag.gt + 1
  }
  if depth != 0 || nodes == 0 {
    raise raw_xml_scan_error(part, "element stack is incomplete")
  }
}

///|
fn preflight_raw_metadata_xml(
  part : String,
  bytes : BytesView,
) -> Unit raise RawError {
  if bytes.length() == 0 || bytes.length() > raw_metadata_max_bytes {
    raise raw_xml_resource_limit(
      part,
      "metadata_xml_bytes",
      raw_metadata_max_bytes,
      bytes.length(),
    )
  }
  preflight_raw_xml(part, bytes, {
    max_nodes: raw_metadata_max_nodes,
    max_attributes: raw_metadata_max_attributes,
    max_namespace_declarations: raw_metadata_max_namespace_declarations,
    max_text_bytes: raw_metadata_max_bytes,
    max_attribute_value_bytes: raw_metadata_max_attribute_value_bytes,
    max_expanded_name_bytes: raw_metadata_max_expanded_name_bytes,
    max_namespace_scope_work: raw_metadata_max_namespace_scope_work,
  })
}

///|
fn raw_find_sequence(
  bytes : BytesView,
  start : Int,
  sequence : BytesView,
) -> Int? {
  if sequence.length() == 0 {
    return Some(start)
  }
  let mut offset = start
  while offset <= bytes.length() - sequence.length() {
    let mut matched = true
    for index = 0; index < sequence.length(); index = index + 1 {
      if bytes[offset + index] != sequence[index] {
        matched = false
        break
      }
    }
    if matched {
      return Some(offset)
    }
    offset = offset + 1
  }
  None
}

///|
fn raw_starts_with_at(
  bytes : BytesView,
  offset : Int,
  sequence : BytesView,
) -> Bool {
  if offset < 0 || offset + sequence.length() > bytes.length() {
    return false
  }
  for index = 0; index < sequence.length(); index = index + 1 {
    if bytes[offset + index] != sequence[index] {
      return false
    }
  }
  true
}

///|
fn raw_split_qname(value : String) -> (String, String) {
  match value.find(":") {
    Some(at) => (value[:at].to_owned(), value[at + 1:].to_owned())
    None => ("", value)
  }
}

///|
fn raw_expand_source_name(
  part : String,
  value : String,
  namespaces : StableStringMap[String],
  attribute~ : Bool,
) -> String raise RawError {
  let (prefix, local_name) = raw_split_qname(value)
  if prefix == "" {
    if attribute {
      local_name
    } else {
      expanded_xml_name(namespaces.get("").unwrap_or(""), local_name)
    }
  } else {
    match namespaces.get(prefix) {
      Some(uri) => expanded_xml_name(uri, local_name)
      None =>
        raise raw_xml_scan_error(
          part,
          "source name '\{value}' uses an unbound namespace prefix",
        )
    }
  }
}

///|
fn raw_expanded_name_bytes(value : String) -> Int {
  @utf8.encode(value).length()
}

///|
fn raw_intern_expanded_name(
  interned : StableStringMap[String],
  value : String,
) -> String {
  match interned.get(value) {
    Some(existing) => existing
    None => {
      interned[value] = value
      value
    }
  }
}

///|
fn raw_apply_namespace_declarations(
  part : String,
  tag : RawOpenTag,
  namespaces : StableStringMap[String],
) -> (Array[RawNamespaceDeclaration], Array[(String, String?)]) raise RawError {
  let declarations : Array[RawNamespaceDeclaration] = []
  let undo : Array[(String, String?)] = []
  for attribute in tag.attributes {
    let prefix = if attribute.name == "xmlns" {
      Some("")
    } else if attribute.name.has_prefix("xmlns:") {
      Some(attribute.name[6:].to_owned())
    } else {
      None
    }
    match prefix {
      Some(prefix) => {
        if attribute.value.length() > raw_max_source_namespace_uri_bytes {
          raise raw_xml_resource_limit(
            part,
            "xml_namespace_uri_bytes",
            raw_max_source_namespace_uri_bytes,
            attribute.value.length(),
          )
        }
        let previous = namespaces.get(prefix)
        if previous is None &&
          namespaces.length() >= raw_max_in_scope_namespaces {
          raise raw_xml_resource_limit(
            part,
            "xml_in_scope_namespaces",
            raw_max_in_scope_namespaces,
            namespaces.length() + 1,
          )
        }
        undo.push((prefix, previous))
        namespaces[prefix] = attribute.value
        declarations.push({ prefix, uri: attribute.value })
      }
      None => ()
    }
  }
  (declarations, undo)
}

///|
fn raw_restore_namespaces(
  namespaces : StableStringMap[String],
  undo : ArrayView[(String, String?)],
) -> Unit {
  let mut index = undo.length()
  while index > 0 {
    index = index - 1
    let (prefix, previous) = undo[index]
    match previous {
      Some(uri) => namespaces[prefix] = uri
      None => namespaces.remove(prefix)
    }
  }
}

///|
fn raw_scan_closing_tag(
  part : String,
  bytes : BytesView,
  start : Int,
) -> (String, Int) raise RawError {
  let mut offset = start + 2
  let name_start = offset
  while offset < bytes.length() &&
        !raw_byte_is_space(bytes[offset]) &&
        bytes[offset] != b'>' {
    offset = offset + 1
  }
  let name = raw_slice_text(part, bytes, name_start, offset)
  while offset < bytes.length() && raw_byte_is_space(bytes[offset]) {
    offset = offset + 1
  }
  if offset >= bytes.length() || bytes[offset] != b'>' {
    raise raw_xml_scan_error(part, "closing tag is unterminated")
  }
  (name, offset)
}

///|
fn raw_reject_non_utf8_declaration(
  part : String,
  bytes : BytesView,
) -> Unit raise RawError {
  let mut offset = if raw_starts_with_at(bytes, 0, b"\xEF\xBB\xBF") {
    3
  } else {
    0
  }
  if !raw_starts_with_at(bytes, offset, b"<?xml") {
    return
  }
  if offset + 5 >= bytes.length() || !raw_byte_is_space(bytes[offset + 5]) {
    return
  }
  let finish = match raw_find_sequence(bytes, offset + 5, b"?>") {
    Some(value) => value
    None => raise raw_xml_scan_error(part, "XML declaration is unterminated")
  }
  offset = offset + 5
  while offset < finish {
    while offset < finish && raw_byte_is_space(bytes[offset]) {
      offset = offset + 1
    }
    if offset >= finish {
      break
    }
    let name_start = offset
    while offset < finish &&
          !raw_byte_is_space(bytes[offset]) &&
          bytes[offset] != b'=' {
      offset = offset + 1
    }
    let name = raw_slice_text(part, bytes, name_start, offset)
    while offset < finish && raw_byte_is_space(bytes[offset]) {
      offset = offset + 1
    }
    if offset >= finish || bytes[offset] != b'=' {
      raise raw_xml_scan_error(part, "XML declaration is malformed")
    }
    offset = offset + 1
    while offset < finish && raw_byte_is_space(bytes[offset]) {
      offset = offset + 1
    }
    if offset >= finish || !(bytes[offset] == b'"' || bytes[offset] == b'\'') {
      raise raw_xml_scan_error(part, "XML declaration value is not quoted")
    }
    let quote = bytes[offset]
    offset = offset + 1
    let value_start = offset
    while offset < finish && bytes[offset] != quote {
      offset = offset + 1
    }
    if offset >= finish {
      raise raw_xml_scan_error(part, "XML declaration value is unterminated")
    }
    if name == "encoding" {
      let encoding = raw_slice_text(part, bytes, value_start, offset).to_lower()
      if encoding != "utf-8" && encoding != "utf8" {
        raise raw_error(
          "office.raw.unsupported_xml_encoding",
          "part '/\{part}' declares '\{encoding}'; span edits require UTF-8 XML",
        )
      }
    }
    offset = offset + 1
  }
}

///|
fn scan_raw_xml(
  part : String,
  bytes : BytesView,
) -> RawXmlDocument raise RawError {
  if bytes.length() == 0 || bytes.length() > raw_max_edit_part_bytes {
    raise raw_error(
      "office.raw.resource_limit",
      "XML edit part '/\{part}' must contain 1 to \{raw_max_edit_part_bytes} bytes",
      details=Json::object({
        "kind": Json::string("xml_part_bytes"),
        "limit": Json::number(raw_max_edit_part_bytes.to_double()),
        "actual": Json::number(bytes.length().to_double()),
      }),
    )
  }
  if bytes.length() >= 2 &&
    (
      (bytes[0] == 0xff && bytes[1] == 0xfe) ||
      (bytes[0] == 0xfe && bytes[1] == 0xff) ||
      (bytes[0] == b'<' && bytes[1] == 0x00) ||
      (bytes[0] == 0x00 && bytes[1] == b'<')
    ) {
    raise raw_error(
      "office.raw.unsupported_xml_encoding",
      "part '/\{part}' is UTF-16; span edits require UTF-8 XML",
    )
  }
  preflight_raw_xml(part, bytes, {
    max_nodes: raw_max_xml_nodes,
    max_attributes: raw_max_xml_attributes,
    max_namespace_declarations: raw_max_xml_namespace_declarations,
    max_text_bytes: raw_max_edit_part_bytes,
    max_attribute_value_bytes: raw_max_xml_attribute_value_bytes,
    max_expanded_name_bytes: raw_max_expanded_name_bytes,
    max_namespace_scope_work: raw_max_namespace_scope_work,
  })
  let text = @utf8.decode(bytes, ignore_bom=true) catch {
    _ =>
      raise raw_error(
        "office.raw.invalid_xml_encoding",
        "part '/\{part}' is not valid UTF-8 XML",
      )
  }
  let _ = @xml.read_xml_string_strict(text) catch {
    _ =>
      raise raw_error(
        "office.raw.invalid_xml",
        "part '/\{part}' is not strict DTD-free XML",
      )
  }
  raw_reject_non_utf8_declaration(part, bytes)
  let nodes : Array[RawXmlNode] = []
  let node_stack : Array[Int] = []
  let namespace_undo_stack : Array[Array[(String, String?)]] = []
  let sibling_counts : StableStringMap[Int] = SortedMap([])
  let interned_expanded_names : StableStringMap[String] = SortedMap([])
  let namespaces : StableStringMap[String] = SortedMap([
    ("xml", "http://www.w3.org/XML/1998/namespace"),
  ])
  let mut offset = 0
  while offset < bytes.length() {
    if bytes[offset] != b'<' {
      offset = offset + 1
      continue
    }
    if raw_starts_with_at(bytes, offset, b"<!--") {
      let finish = match raw_find_sequence(bytes, offset + 4, b"-->") {
        Some(value) => value
        None => raise raw_xml_scan_error(part, "comment is unterminated")
      }
      offset = finish + 3
      continue
    }
    if raw_starts_with_at(bytes, offset, b"<![CDATA[") {
      let finish = match raw_find_sequence(bytes, offset + 9, b"]]>") {
        Some(value) => value
        None => raise raw_xml_scan_error(part, "CDATA section is unterminated")
      }
      offset = finish + 3
      continue
    }
    if raw_starts_with_at(bytes, offset, b"<?") {
      let finish = match raw_find_sequence(bytes, offset + 2, b"?>") {
        Some(value) => value
        None =>
          raise raw_xml_scan_error(
            part, "processing instruction is unterminated",
          )
      }
      offset = finish + 2
      continue
    }
    if raw_starts_with_at(bytes, offset, b"</") {
      let (closing_name, gt) = raw_scan_closing_tag(part, bytes, offset)
      let node_index = match node_stack.pop() {
        Some(value) => value
        None =>
          raise raw_xml_scan_error(part, "closing tag has no open element")
      }
      match namespace_undo_stack.pop() {
        Some(undo) => raw_restore_namespaces(namespaces, undo)
        None => raise raw_xml_scan_error(part, "namespace stack is incomplete")
      }
      if nodes[node_index].raw_name != closing_name {
        raise raw_xml_scan_error(
          part, "closing tag does not match open element",
        )
      }
      nodes[node_index].end_tag_start = offset
      nodes[node_index].end = gt + 1
      offset = gt + 1
      continue
    }
    if raw_starts_with_at(bytes, offset, b"<!") {
      raise raw_xml_scan_error(
        part, "DTD and declaration nodes are not supported",
      )
    }
    let tag = raw_scan_open_tag(part, bytes, offset)
    let (declarations, namespace_undo) = raw_apply_namespace_declarations(
      part, tag, namespaces,
    )
    let expanded = raw_intern_expanded_name(
      interned_expanded_names,
      raw_expand_source_name(part, tag.name, namespaces, attribute=false),
    )
    let attributes : Array[RawAttributeSpan] = []
    for attribute in tag.attributes {
      if attribute.name == "xmlns" || attribute.name.has_prefix("xmlns:") {
        continue
      }
      attributes.push({
        expanded: raw_intern_expanded_name(
          interned_expanded_names,
          raw_expand_source_name(
            part,
            attribute.name,
            namespaces,
            attribute=true,
          ),
        ),
        value: attribute.value,
        value_start: attribute.value_start,
        value_end: attribute.value_end,
      })
    }
    let parent = node_stack.last().unwrap_or(-1)
    let sibling_key = "\{parent}\u{0}\{expanded}"
    let sibling_position = sibling_counts.get(sibling_key).unwrap_or(0) + 1
    sibling_counts[sibling_key] = sibling_position
    let end = if tag.self_closing { tag.gt + 1 } else { -1 }
    nodes.push({
      raw_name: tag.name,
      expanded,
      parent,
      sibling_position,
      start: offset,
      start_tag_end: tag.gt + 1,
      tag_insert_offset: tag.insert_at,
      self_closing: tag.self_closing,
      end_tag_start: if tag.self_closing {
        tag.insert_at
      } else {
        -1
      },
      end,
      attributes,
      declarations,
    })
    if nodes.length() > raw_max_xml_nodes {
      raise raw_error(
        "office.raw.resource_limit",
        "XML part '/\{part}' exceeds \{raw_max_xml_nodes} elements",
      )
    }
    if !tag.self_closing {
      node_stack.push(nodes.length() - 1)
      namespace_undo_stack.push(namespace_undo)
    } else {
      raw_restore_namespaces(namespaces, namespace_undo)
    }
    offset = tag.gt + 1
  }
  if !node_stack.is_empty() || nodes.is_empty() {
    raise raw_xml_scan_error(part, "element stack is incomplete")
  }
  { bytes, nodes }
}

///|
fn raw_node_has_attribute(
  node : RawXmlNode,
  name : String,
  value : String,
) -> Bool {
  for attribute in node.attributes {
    if attribute.expanded == name && attribute.value == value {
      return true
    }
  }
  false
}

///|
fn raw_node_matches_segment(
  node : RawXmlNode,
  segment : RawPathSegment,
) -> Bool {
  if node.expanded != segment.name.expanded {
    return false
  }
  match segment.predicate {
    Some(Position(position)) => node.sibling_position == position
    Some(Attribute(name, value)) =>
      raw_node_has_attribute(node, name.expanded, value)
    None => true
  }
}

///|
fn select_raw_nodes(
  document : RawXmlDocument,
  path : RawPath,
  allow_multiple : Bool,
) -> Array[Int] raise RawError {
  let mut candidates : Set[Int] = Set([])
  for segment_index, segment in path.segments {
    let next : Set[Int] = Set([])
    for node_index, node in document.nodes {
      let parent_matches = if segment_index == 0 {
        node.parent == -1
      } else {
        candidates.contains(node.parent)
      }
      if parent_matches && raw_node_matches_segment(node, segment) {
        next.add(node_index)
        if next.length() > raw_max_path_candidates {
          raise raw_error(
            "office.raw.too_many_matches",
            "raw XML path expands beyond \{raw_max_path_candidates} intermediate candidates",
            details=Json::object({ "path": Json::string(path.source) }),
          )
        }
      }
    }
    candidates = next
    if candidates.is_empty() {
      break
    }
  }
  let selected = candidates.to_array()
  selected.sort()
  if selected.is_empty() {
    raise raw_error(
      "office.raw.path_not_found",
      "raw XML path matched no elements",
      details=Json::object({ "path": Json::string(path.source) }),
    )
  }
  if selected.length() > raw_max_matches {
    raise raw_error(
      "office.raw.too_many_matches",
      "raw XML path matched \{selected.length()} elements, above the \{raw_max_matches} limit",
      details=Json::object({ "path": Json::string(path.source) }),
    )
  }
  if selected.length() > 1 && !allow_multiple {
    raise raw_error(
      "office.raw.ambiguous_path",
      "raw XML path matched \{selected.length()} elements; use --all explicitly",
      details=Json::object({
        "path": Json::string(path.source),
        "match_count": Json::number(selected.length().to_double()),
      }),
    )
  }
  selected
}

///|
fn raw_effective_namespaces(
  document : RawXmlDocument,
  node_index : Int,
) -> Map[String, String] {
  let chain : Array[Int] = []
  let mut current = node_index
  while current >= 0 {
    chain.push(current)
    current = document.nodes[current].parent
  }
  let output : Map[String, String] = {
    "xml": "http://www.w3.org/XML/1998/namespace",
  }
  let mut chain_index = chain.length() - 1
  while chain_index >= 0 {
    for declaration in document.nodes[chain[chain_index]].declarations {
      output[declaration.prefix] = declaration.uri
    }
    chain_index = chain_index - 1
  }
  output
}
