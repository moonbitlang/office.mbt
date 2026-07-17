///|
let xml_namespace_uri = "http://www.w3.org/XML/1998/namespace"

///|
let xmlns_namespace_uri = "http://www.w3.org/2000/xmlns/"

///|
let max_xml_start_tag_chars : Int = 1024 * 1024

///|
let max_xml_qname_chars : Int = 1024

///|
let max_xml_start_tag_attributes : Int = 4096

///|
let max_xml_namespace_bindings : Int = 4096

///|
let max_xml_element_depth : Int = 256

///|
priv struct XmlNamespaceBinding {
  prefix : String
  uri : String
  depth : Int
}

///|
priv struct XmlAttributeSpan {
  name_start : Int
  name_end : Int
  value_start : Int
  value_end : Int
  next : Int
}

///|
/// A forward-only, allocation-bounded XML start-tag cursor. Element and
/// attribute names are exposed as expanded namespace names while source slices
/// remain borrowed from the caller's XML string.
pub struct XmlStartTagScanner {
  priv xml : StringView
  priv mut index : Int
  priv mut depth : Int
  priv namespace_bindings : Array[XmlNamespaceBinding]
  priv open_name_starts : Array[Int]
  priv open_name_ends : Array[Int]
  priv mut pending_namespace_pop : Int?
  priv mut current_name_start : Int
  priv mut current_name_end : Int
  priv mut current_tag_end : Int
  priv mut current_namespace_uri : String
}

///|
fn is_xml_name_start(unit : UInt16) -> Bool {
  (unit >= ('A' : UInt16) && unit <= ('Z' : UInt16)) ||
  (unit >= ('a' : UInt16) && unit <= ('z' : UInt16)) ||
  unit == ('_' : UInt16) ||
  unit >= 0x80
}

///|
fn is_xml_name_unit(unit : UInt16) -> Bool {
  is_xml_name_start(unit) ||
  (unit >= ('0' : UInt16) && unit <= ('9' : UInt16)) ||
  unit == ('-' : UInt16) ||
  unit == ('.' : UInt16)
}

///|
fn validate_xml_qname(
  xml : StringView,
  start : Int,
  end : Int,
) -> Int? raise ParseXmlError {
  if start >= end {
    raise InvalidXml(msg="XML qualified name is empty")
  }
  if end - start > max_xml_qname_chars {
    raise InvalidXml(msg="XML qualified name is too long")
  }
  let mut colon : Int? = None
  for index in start..<end {
    let unit = xml[index]
    if unit == (':' : UInt16) {
      if colon is Some(_) || index == start || index + 1 == end {
        raise InvalidXml(msg="XML qualified name is invalid")
      }
      colon = Some(index)
    } else {
      let local_start = if index == start {
        true
      } else {
        match colon {
          Some(value) => index == value + 1
          None => false
        }
      }
      if local_start {
        if !is_xml_name_start(unit) {
          raise InvalidXml(msg="XML qualified name is invalid")
        }
      } else if !is_xml_name_unit(unit) {
        raise InvalidXml(msg="XML qualified name is invalid")
      }
    }
  }
  colon
}

///|
fn xml_string_equals_view(value : String, expected : StringView) -> Bool {
  if value.length() != expected.length() {
    return false
  }
  for index in 0..<expected.length() {
    if value[index] != expected[index] {
      return false
    }
  }
  true
}

///|
fn xml_span_equals(
  xml : StringView,
  start : Int,
  end : Int,
  expected : StringView,
) -> Bool {
  if end - start != expected.length() {
    return false
  }
  for offset in 0..<expected.length() {
    if xml[start + offset] != expected[offset] {
      return false
    }
  }
  true
}

///|
fn xml_spans_equal(
  xml : StringView,
  first_start : Int,
  first_end : Int,
  second_start : Int,
  second_end : Int,
) -> Bool {
  if first_end - first_start != second_end - second_start {
    return false
  }
  for offset in 0..<(first_end - first_start) {
    if xml[first_start + offset] != xml[second_start + offset] {
      return false
    }
  }
  true
}

///|
fn find_xml_sequence(
  xml : StringView,
  start : Int,
  sequence : StringView,
) -> Int? {
  if sequence.length() == 0 {
    return Some(start)
  }
  let last = xml.length() - sequence.length()
  let mut index = start
  while index <= last {
    if xml_span_equals(xml, index, index + sequence.length(), sequence) {
      return Some(index)
    }
    index = index + 1
  }
  None
}

///|
fn find_xml_tag_end(
  xml : StringView,
  search_start : Int,
  markup_start : Int,
) -> Int raise ParseXmlError {
  let mut index = search_start
  let mut quote : UInt16? = None
  while index < xml.length() {
    if index - markup_start > max_xml_start_tag_chars {
      raise InvalidXml(msg="XML start tag is too long")
    }
    let unit = xml[index]
    match quote {
      Some(delimiter) => {
        if unit == ('<' : UInt16) {
          raise InvalidXml(msg="XML attribute contains '<'")
        }
        if unit == delimiter {
          quote = None
        }
      }
      None =>
        if unit == ('"' : UInt16) || unit == ('\'' : UInt16) {
          quote = Some(unit)
        } else if unit == ('>' : UInt16) {
          return index
        } else if unit == ('<' : UInt16) {
          raise InvalidXml(msg="XML start tag is not closed")
        }
    }
    index = index + 1
  }
  raise InvalidXml(msg="XML start tag is not closed")
}

///|
fn next_xml_attribute(
  xml : StringView,
  start : Int,
  tag_end : Int,
) -> XmlAttributeSpan? raise ParseXmlError {
  let mut index = start
  while index < tag_end && is_attr_space(xml[index]) {
    index = index + 1
  }
  if index >= tag_end || xml[index] == ('/' : UInt16) {
    return None
  }
  let name_start = index
  while index < tag_end &&
        !is_attr_space(xml[index]) &&
        xml[index] != ('=' : UInt16) &&
        xml[index] != ('/' : UInt16) {
    index = index + 1
  }
  let name_end = index
  ignore(validate_xml_qname(xml, name_start, name_end))
  while index < tag_end && is_attr_space(xml[index]) {
    index = index + 1
  }
  if index >= tag_end || xml[index] != ('=' : UInt16) {
    raise InvalidXml(msg="XML attribute has no value")
  }
  index = index + 1
  while index < tag_end && is_attr_space(xml[index]) {
    index = index + 1
  }
  if index >= tag_end ||
    (xml[index] != ('"' : UInt16) && xml[index] != ('\'' : UInt16)) {
    raise InvalidXml(msg="XML attribute value is not quoted")
  }
  let quote = xml[index]
  index = index + 1
  let value_start = index
  while index < tag_end && xml[index] != quote {
    if xml[index] == ('<' : UInt16) {
      raise InvalidXml(msg="XML attribute contains '<'")
    }
    index = index + 1
  }
  if index >= tag_end {
    raise InvalidXml(msg="XML attribute is not closed")
  }
  let value_end = index
  index = index + 1
  Some({ name_start, name_end, value_start, value_end, next: index })
}

///|
fn is_valid_xml_char_reference(value : Int) -> Bool {
  value == 0x09 ||
  value == 0x0a ||
  value == 0x0d ||
  (value >= 0x20 && value <= 0xd7ff) ||
  (value >= 0xe000 && value <= 0xfffd) ||
  (value >= 0x10000 && value <= 0x10ffff)
}

///|
fn xml_entity_value(entity : StringView) -> Char? {
  match entity {
    "lt" => Some('<')
    "gt" => Some('>')
    "quot" => Some('"')
    "apos" => Some('\'')
    "amp" => Some('&')
    _ => {
      let (digits, base) = if entity.length() >= 2 &&
        entity[0] == ('#' : UInt16) &&
        (entity[1] == ('x' : UInt16) || entity[1] == ('X' : UInt16)) {
        (entity[2:], 16)
      } else if entity.length() >= 1 && entity[0] == ('#' : UInt16) {
        (entity[1:], 10)
      } else {
        return None
      }
      if digits.length() == 0 {
        return None
      }
      for unit in digits {
        let valid = if base == 10 {
          unit >= '0' && unit <= '9'
        } else {
          (unit >= '0' && unit <= '9') ||
          (unit >= 'a' && unit <= 'f') ||
          (unit >= 'A' && unit <= 'F')
        }
        if !valid {
          return None
        }
      }
      let value = @string.parse_int(digits, base~) catch { _ => return None }
      if !is_valid_xml_char_reference(value) {
        return None
      }
      Some(value.unsafe_to_char())
    }
  }
}

///|
/// Decodes one XML attribute value in a single pass. Unknown, malformed, or
/// XML-forbidden entity references are rejected instead of being decoded a
/// second time by a downstream path resolver.
pub fn decode_xml_attribute(value : StringView) -> String raise ParseXmlError {
  let mut needs_decode = false
  for unit in value {
    if unit == '&' || unit == '\t' || unit == '\n' || unit == '\r' {
      needs_decode = true
      break
    }
    if unit == '<' {
      raise InvalidXml(msg="XML attribute contains '<'")
    }
  }
  if !needs_decode {
    return value.to_owned()
  }
  let output = StringBuilder::new()
  let mut index = 0
  let mut literal_start = 0
  while index < value.length() {
    let unit = value[index]
    if unit == ('&' : UInt16) {
      output.write_view(value[literal_start:index])
      let entity_end = match find_xml_sequence(value, index + 1, ";") {
        Some(found) => found
        None => raise InvalidXml(msg="XML entity is not closed")
      }
      let entity = value[index + 1:entity_end]
      let decoded = match xml_entity_value(entity) {
        Some(character) => character
        None => raise InvalidXml(msg="XML entity is invalid")
      }
      output.write_char(decoded)
      index = entity_end + 1
      literal_start = index
      continue
    }
    if unit == ('\t' : UInt16) ||
      unit == ('\n' : UInt16) ||
      unit == ('\r' : UInt16) {
      output.write_view(value[literal_start:index])
      output.write_char(' ')
      index = index + 1
      literal_start = index
      continue
    }
    if unit == ('<' : UInt16) {
      raise InvalidXml(msg="XML attribute contains '<'")
    }
    index = index + 1
  }
  output.write_view(value[literal_start:])
  output.to_string()
}

///|
fn XmlStartTagScanner::pop_namespace_depth(
  self : XmlStartTagScanner,
  depth : Int,
) -> Unit {
  while self.namespace_bindings.length() > 0 {
    let last = self.namespace_bindings.length() - 1
    if self.namespace_bindings[last].depth != depth {
      break
    }
    ignore(self.namespace_bindings.pop())
  }
}

///|
fn XmlStartTagScanner::resolve_prefix(
  self : XmlStartTagScanner,
  prefix : StringView,
  attribute : Bool,
) -> String raise ParseXmlError {
  if prefix == "xml" {
    return xml_namespace_uri
  }
  if prefix.length() == 0 && attribute {
    return ""
  }
  for offset in 0..<self.namespace_bindings.length() {
    let index = self.namespace_bindings.length() - 1 - offset
    let binding = self.namespace_bindings[index]
    if xml_string_equals_view(binding.prefix, prefix) {
      return binding.uri
    }
  }
  if prefix.length() == 0 {
    ""
  } else {
    raise InvalidXml(msg="XML namespace prefix is not declared")
  }
}

///|
fn xml_namespace_declaration_prefix(
  xml : StringView,
  attribute : XmlAttributeSpan,
) -> String? raise ParseXmlError {
  if xml_span_equals(xml, attribute.name_start, attribute.name_end, "xmlns") {
    return Some("")
  }
  let colon = match
    validate_xml_qname(xml, attribute.name_start, attribute.name_end) {
    Some(value) => value
    None => return None
  }
  if !xml_span_equals(xml, attribute.name_start, colon, "xmlns") {
    return None
  }
  Some(xml[colon + 1:attribute.name_end].to_owned())
}

///|
fn XmlStartTagScanner::add_namespace_declarations(
  self : XmlStartTagScanner,
  attributes_start : Int,
  tag_end : Int,
  scope_depth : Int,
) -> Unit raise ParseXmlError {
  let declared : Set[String] = Set([])
  let mut next = attributes_start
  let mut count = 0
  while next_xml_attribute(self.xml, next, tag_end) is Some(attribute) {
    count = count + 1
    if count > max_xml_start_tag_attributes {
      raise InvalidXml(msg="XML start tag has too many attributes")
    }
    next = attribute.next
    guard xml_namespace_declaration_prefix(self.xml, attribute) is Some(prefix) else {
      continue
    }
    if declared.contains(prefix) {
      raise InvalidXml(msg="XML namespace prefix is declared twice")
    }
    declared.add(prefix)
    let uri = decode_xml_attribute(
      self.xml[attribute.value_start:attribute.value_end],
    )
    if prefix == "xmlns" || uri == xmlns_namespace_uri {
      raise InvalidXml(msg="XML namespace declaration is reserved")
    }
    if prefix == "xml" && uri != xml_namespace_uri {
      raise InvalidXml(msg="XML namespace declaration for xml is invalid")
    }
    if prefix != "xml" && uri == xml_namespace_uri {
      raise InvalidXml(msg="XML namespace declaration for xml is invalid")
    }
    if prefix != "" && uri == "" {
      raise InvalidXml(msg="XML prefixed namespace cannot be empty")
    }
    if self.namespace_bindings.length() >= max_xml_namespace_bindings {
      raise InvalidXml(msg="XML has too many active namespace bindings")
    }
    self.namespace_bindings.push({ prefix, uri, depth: scope_depth })
  }
}

///|
fn XmlStartTagScanner::validate_attributes(
  self : XmlStartTagScanner,
  attributes_start : Int,
  tag_end : Int,
) -> Unit raise ParseXmlError {
  let expanded_names : Set[String] = Set([])
  let mut next = attributes_start
  let mut count = 0
  while next_xml_attribute(self.xml, next, tag_end) is Some(attribute) {
    count = count + 1
    if count > max_xml_start_tag_attributes {
      raise InvalidXml(msg="XML start tag has too many attributes")
    }
    next = attribute.next
    if xml_namespace_declaration_prefix(self.xml, attribute) is Some(_) {
      continue
    }
    let colon = validate_xml_qname(
      self.xml,
      attribute.name_start,
      attribute.name_end,
    )
    let (prefix, local_name_view) = match colon {
      Some(value) =>
        (
          self.xml[attribute.name_start:value],
          self.xml[value + 1:attribute.name_end],
        )
      None =>
        (
          self.xml[attribute.name_start:attribute.name_start],
          self.xml[attribute.name_start:attribute.name_end],
        )
    }
    let uri = self.resolve_prefix(prefix, true)
    let expanded = "\{uri.length()}:\{uri}\{local_name_view.to_owned()}"
    if expanded_names.contains(expanded) {
      raise InvalidXml(msg="XML attribute is duplicated")
    }
    expanded_names.add(expanded)
  }
}

///|
/// Creates a namespace-aware cursor over `xml`. The source is borrowed; no
/// copy of the full XML part is made.
pub fn XmlStartTagScanner::new(xml : StringView) -> XmlStartTagScanner {
  {
    xml,
    index: 0,
    depth: 0,
    namespace_bindings: [],
    open_name_starts: [],
    open_name_ends: [],
    pending_namespace_pop: None,
    current_name_start: 0,
    current_name_end: 0,
    current_tag_end: 0,
    current_namespace_uri: "",
  }
}

///|
fn XmlStartTagScanner::consume_end_tag(
  self : XmlStartTagScanner,
  start : Int,
) -> Unit raise ParseXmlError {
  if self.depth <= 0 || self.open_name_starts.length() == 0 {
    raise InvalidXml(msg="XML end tag has no matching start tag")
  }
  let name_start = start + 2
  let mut name_end = name_start
  while name_end < self.xml.length() &&
        !is_attr_space(self.xml[name_end]) &&
        self.xml[name_end] != ('>' : UInt16) {
    name_end = name_end + 1
  }
  ignore(validate_xml_qname(self.xml, name_start, name_end))
  let tag_end = find_xml_tag_end(self.xml, name_end, start)
  for index in name_end..<tag_end {
    if !is_attr_space(self.xml[index]) {
      raise InvalidXml(msg="XML end tag is invalid")
    }
  }
  let open_start = self.open_name_starts[self.open_name_starts.length() - 1]
  let open_end = self.open_name_ends[self.open_name_ends.length() - 1]
  if !xml_spans_equal(self.xml, name_start, name_end, open_start, open_end) {
    raise InvalidXml(msg="XML start and end tags do not match")
  }
  ignore(self.open_name_starts.pop())
  ignore(self.open_name_ends.pop())
  self.pop_namespace_depth(self.depth)
  self.depth = self.depth - 1
  self.index = tag_end + 1
}

///|
/// Advances to the next start tag. Returns `false` at end of input and raises
/// `InvalidXml` for malformed namespace or tag structure.
pub fn XmlStartTagScanner::next(
  self : XmlStartTagScanner,
) -> Bool raise ParseXmlError {
  match self.pending_namespace_pop {
    Some(depth) => {
      self.pop_namespace_depth(depth)
      self.pending_namespace_pop = None
    }
    None => ()
  }
  while self.index < self.xml.length() {
    while self.index < self.xml.length() &&
          self.xml[self.index] != ('<' : UInt16) {
      self.index = self.index + 1
    }
    if self.index >= self.xml.length() {
      break
    }
    let start = self.index
    if start + 1 >= self.xml.length() {
      raise InvalidXml(msg="XML markup is not closed")
    }
    if self.xml[start + 1] == ('?' : UInt16) {
      let end = match find_xml_sequence(self.xml, start + 2, "?>") {
        Some(value) => value
        None => raise InvalidXml(msg="XML processing instruction is not closed")
      }
      self.index = end + 2
      continue
    }
    if self.xml[start + 1] == ('!' : UInt16) {
      if start + 4 <= self.xml.length() &&
        xml_span_equals(self.xml, start, start + 4, "<!--") {
        let end = match find_xml_sequence(self.xml, start + 4, "-->") {
          Some(value) => value
          None => raise InvalidXml(msg="XML comment is not closed")
        }
        self.index = end + 3
        continue
      }
      if start + 9 <= self.xml.length() &&
        xml_span_equals(self.xml, start, start + 9, "<![CDATA[") {
        let end = match find_xml_sequence(self.xml, start + 9, "]]>") {
          Some(value) => value
          None => raise InvalidXml(msg="XML CDATA section is not closed")
        }
        self.index = end + 3
        continue
      }
      raise InvalidXml(msg="XML declarations are not allowed")
    }
    if self.xml[start + 1] == ('/' : UInt16) {
      self.consume_end_tag(start)
      continue
    }
    let name_start = start + 1
    let mut name_end = name_start
    while name_end < self.xml.length() &&
          !is_attr_space(self.xml[name_end]) &&
          self.xml[name_end] != ('/' : UInt16) &&
          self.xml[name_end] != ('>' : UInt16) {
      name_end = name_end + 1
    }
    let colon = validate_xml_qname(self.xml, name_start, name_end)
    let tag_end = find_xml_tag_end(self.xml, name_end, start)
    let mut before_end = tag_end
    while before_end > name_end && is_attr_space(self.xml[before_end - 1]) {
      before_end = before_end - 1
    }
    let self_closing = before_end > name_end &&
      self.xml[before_end - 1] == ('/' : UInt16)
    let scope_depth = self.depth + 1
    if scope_depth > max_xml_element_depth {
      raise InvalidXml(msg="XML element nesting is too deep")
    }
    self.add_namespace_declarations(name_end, tag_end, scope_depth)
    self.validate_attributes(name_end, tag_end)
    let prefix = match colon {
      Some(value) => self.xml[name_start:value]
      None => self.xml[name_start:name_start]
    }
    self.current_namespace_uri = self.resolve_prefix(prefix, false)
    self.current_name_start = match colon {
      Some(value) => value + 1
      None => name_start
    }
    self.current_name_end = name_end
    self.current_tag_end = tag_end
    self.index = tag_end + 1
    if self_closing {
      self.pending_namespace_pop = Some(scope_depth)
    } else {
      self.depth = scope_depth
      self.open_name_starts.push(name_start)
      self.open_name_ends.push(name_end)
    }
    return true
  }
  if self.depth != 0 {
    raise InvalidXml(msg="XML start tag has no matching end tag")
  }
  false
}

///|
/// Returns the local name of the current start tag.
pub fn XmlStartTagScanner::local_name(self : XmlStartTagScanner) -> StringView {
  self.xml[self.current_name_start:self.current_name_end]
}

///|
/// Returns the namespace URI of the current start tag, or `""` when the tag
/// is not namespace-qualified.
pub fn XmlStartTagScanner::namespace_uri(
  self : XmlStartTagScanner,
) -> StringView {
  self.current_namespace_uri
}

///|
/// Returns the raw, borrowed value of an attribute selected by expanded name.
/// The default namespace never applies to unprefixed attributes.
pub fn XmlStartTagScanner::attribute_view(
  self : XmlStartTagScanner,
  namespace_uri : StringView,
  local_name : StringView,
) -> StringView? raise ParseXmlError {
  let mut next = self.current_name_end
  while next_xml_attribute(self.xml, next, self.current_tag_end)
        is Some(attribute) {
    next = attribute.next
    if xml_namespace_declaration_prefix(self.xml, attribute) is Some(_) {
      continue
    }
    let colon = validate_xml_qname(
      self.xml,
      attribute.name_start,
      attribute.name_end,
    )
    let (prefix, local_start) = match colon {
      Some(value) => (self.xml[attribute.name_start:value], value + 1)
      None =>
        (
          self.xml[attribute.name_start:attribute.name_start],
          attribute.name_start,
        )
    }
    if !xml_span_equals(self.xml, local_start, attribute.name_end, local_name) {
      continue
    }
    if xml_string_equals_view(self.resolve_prefix(prefix, true), namespace_uri) {
      return Some(self.xml[attribute.value_start:attribute.value_end])
    }
  }
  None
}

///|
/// Returns a decoded attribute selected by expanded name. Entity references
/// are decoded exactly once.
pub fn XmlStartTagScanner::attribute(
  self : XmlStartTagScanner,
  namespace_uri : StringView,
  local_name : StringView,
) -> String? raise ParseXmlError {
  match self.attribute_view(namespace_uri, local_name) {
    Some(value) => Some(decode_xml_attribute(value))
    None => None
  }
}

///|
test "start tag scanner resolves namespaces and decodes attributes once" {
  let xml =
    #|<p:root xmlns:p="urn:root" xmlns:r="urn:rel"><p:item r:id="a&amp;b" plain="x&#x20;y"/></p:root>
  let scanner = XmlStartTagScanner::new(xml)
  assert_true(scanner.next())
  inspect(scanner.namespace_uri(), content="urn:root")
  inspect(scanner.local_name(), content="root")
  assert_true(scanner.next())
  inspect(scanner.namespace_uri(), content="urn:root")
  inspect(scanner.local_name(), content="item")
  debug_inspect(scanner.attribute("urn:rel", "id"), content="Some(\"a&b\")")
  debug_inspect(scanner.attribute("", "plain"), content="Some(\"x y\")")
  assert_false(scanner.next())
}

///|
test "start tag scanner rejects undeclared and duplicate expanded attributes" {
  for
    xml in [
      "<p:root/>", "<root xmlns:a='urn:x' xmlns:b='urn:x' a:id='1' b:id='2'/>",
    ] {
    let scanner = XmlStartTagScanner::new(xml)
    try scanner.next() catch {
      InvalidXml(_) => ()
    } noraise {
      _ => fail("expected invalid namespace-qualified XML")
    }
  }
}

///|
test "start tag scanner restores namespace scopes after self-closing tags" {
  let scanner = XmlStartTagScanner::new(
    "<root xmlns='urn:outer'><child xmlns='urn:inner'/><sibling/></root>",
  )
  assert_true(scanner.next())
  inspect(scanner.namespace_uri(), content="urn:outer")
  assert_true(scanner.next())
  inspect(scanner.namespace_uri(), content="urn:inner")
  assert_true(scanner.next())
  inspect(scanner.namespace_uri(), content="urn:outer")
  assert_false(scanner.next())
}

///|
test "XML attributes decode once and reject invalid entities" {
  inspect(decode_xml_attribute("a&amp;#x20;b"), content="a&#x20;b")
  for value in ["&unknown;", "&#0;", "&#xD800;", "&amp"] {
    try decode_xml_attribute(value) catch {
      InvalidXml(_) => ()
    } noraise {
      _ => fail("expected invalid XML entity")
    }
  }
}

///|
test "start tag scanner bounds qualified names" {
  let scanner = XmlStartTagScanner::new("<" + "a".repeat(1025) + "/>")
  try scanner.next() catch {
    InvalidXml(msg~) => inspect(msg, content="XML qualified name is too long")
  } noraise {
    _ => fail("expected qualified-name limit")
  }
}
