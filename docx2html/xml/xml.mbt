///|
/// Node in the lightweight XML tree.
pub(all) enum XmlNode {
  XmlElement(XmlElement)
  XmlText(String)
} derive(Debug, Eq)

///|
/// XML element with a name, attributes, and child nodes.
pub(all) struct XmlElement {
  name : String
  attributes : Map[String, String]
  children : Array[XmlNode]
} derive(Debug, Eq)

///|
/// Builds an XML element.
pub fn xml_element(
  name : String,
  attributes? : Map[String, String] = Map([]),
  children? : Array[XmlNode] = [],
) -> XmlElement {
  { name, attributes, children }
}

///|
/// Builds an XML text node.
pub fn xml_text(value : String) -> XmlNode {
  XmlText(value)
}

///|
/// Returns the first child element with the requested tag.
pub fn XmlElement::first(self : XmlElement, name : String) -> XmlElement? {
  for child in self.children {
    match child {
      XmlElement(element) => if element.name == name { return Some(element) }
      _ => ()
    }
  }
  None
}

///|
/// Returns the first matching child text, or an empty string.
pub fn XmlElement::first_or_empty(
  self : XmlElement,
  name : String,
) -> XmlElement {
  match self.first(name) {
    Some(element) => element
    None => xml_element("")
  }
}

///|
/// Returns direct child elements with the requested tag.
pub fn XmlElement::elements_by_tag_name(
  self : XmlElement,
  name : String,
) -> Array[XmlElement] {
  let elements : Array[XmlElement] = []
  for child in self.children {
    match child {
      XmlElement(element) => if element.name == name { elements.push(element) }
      _ => ()
    }
  }
  elements
}

///|
/// Returns descendant elements with the requested tag.
pub fn XmlElement::descendants_by_tag_name(
  self : XmlElement,
  name : String,
) -> Array[XmlElement] {
  let elements : Array[XmlElement] = []
  for child in self.children {
    match child {
      XmlElement(element) => {
        if element.name == name {
          elements.push(element)
        }
        elements.append(element.descendants_by_tag_name(name))
      }
      _ => ()
    }
  }
  elements
}

///|
/// Returns concatenated text content for the XML element.
pub fn XmlElement::text(self : XmlElement) -> String raise DocxError {
  if self.children.length() == 0 {
    ""
  } else if self.children.length() == 1 {
    match self.children[0] {
      XmlText(value) => value
      _ => raise InvalidXml(message="element does not contain simple text")
    }
  } else {
    raise InvalidXml(message="element does not contain simple text")
  }
}

///|
/// Parses XML text into an element.
pub fn read_xml_string(
  source : String,
  namespace_map? : Map[String, String] = Map([]),
) -> XmlElement raise DocxError {
  let parser = XmlParser::{
    source,
    pos: 0,
    depth: 0,
    namespace_map,
    namespaces: Map([]),
  }
  parser.skip_misc()
  let root = parser.parse_element()
  parser.skip_misc()
  if parser.pos < parser.source.length() {
    raise InvalidXml(message="unexpected content after document element")
  }
  root
}

///|
/// Serializes an XML element to text.
pub fn write_xml_string(
  root : XmlElement,
  namespaces? : Map[String, String] = Map([]),
) -> String {
  let writer = XmlWriter::{ namespaces, uri_to_prefix: invert_map(namespaces) }
  let builder = StringBuilder()
  builder.write_string(
    "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>",
  )
  writer.write_element(builder, root, is_root=true)
  builder.to_string()
}

///|
priv struct XmlWriter {
  namespaces : Map[String, String]
  uri_to_prefix : Map[String, String]
}

///|
fn invert_map(map : Map[String, String]) -> Map[String, String] {
  let inverse : Map[String, String] = Map([])
  for item in map {
    let (key, value) = item
    inverse[value] = key
  }
  inverse
}

///|
fn XmlWriter::write_node(
  self : XmlWriter,
  builder : StringBuilder,
  node : XmlNode,
) -> Unit {
  match node {
    XmlElement(element) => self.write_element(builder, element)
    XmlText(value) => builder.write_string(escape_xml_text(value))
  }
}

///|
fn XmlWriter::write_element(
  self : XmlWriter,
  builder : StringBuilder,
  element : XmlElement,
  is_root? : Bool = false,
) -> Unit {
  builder.write_string("<")
  builder.write_string(self.map_element_name(element.name))
  if is_root {
    self.write_namespace_attributes(builder)
  }
  // The root's OWN attributes too — namespace declarations do not
  // replace them (mc:Ignorable on annotation parts lives here).
  write_serialized_xml_attributes(builder, element.attributes)
  if element.children.is_empty() {
    builder.write_string("/>")
  } else {
    builder.write_string(">")
    for child in element.children {
      self.write_node(builder, child)
    }
    builder.write_string("</")
    builder.write_string(self.map_element_name(element.name))
    builder.write_string(">")
  }
}

///|
fn XmlWriter::map_element_name(self : XmlWriter, name : String) -> String {
  if name.has_prefix("{") {
    match name.find("}") {
      Some(close) => {
        let uri = name[1:close].to_owned()
        let local_name = name[close + 1:].to_owned()
        match self.uri_to_prefix.get(uri) {
          Some(prefix) =>
            if prefix == "" {
              local_name
            } else {
              prefix + ":" + local_name
            }
          None => name
        }
      }
      None => name
    }
  } else {
    name
  }
}

///|
fn XmlWriter::write_namespace_attributes(
  self : XmlWriter,
  builder : StringBuilder,
) -> Unit {
  let namespaces = self.namespaces.to_array()
  namespaces.sort_by(fn(a, b) {
    let (prefix_a, _) = a
    let (prefix_b, _) = b
    xml_namespace_attribute_name(prefix_a).compare(
      xml_namespace_attribute_name(prefix_b),
    )
  })
  for item in namespaces {
    let (prefix, uri) = item
    write_serialized_xml_attribute(
      builder,
      xml_namespace_attribute_name(prefix),
      uri,
    )
  }
}

///|
fn xml_namespace_attribute_name(prefix : String) -> String {
  if prefix == "" {
    "xmlns"
  } else {
    "xmlns:" + prefix
  }
}

///|
fn write_serialized_xml_attributes(
  builder : StringBuilder,
  attributes : Map[String, String],
) -> Unit {
  let items = attributes.to_array()
  items.sort_by(fn(a, b) {
    let (key_a, _) = a
    let (key_b, _) = b
    let rank_diff = xml_attribute_rank(key_a) - xml_attribute_rank(key_b)
    if rank_diff != 0 {
      rank_diff
    } else {
      key_a.compare(key_b)
    }
  })
  for item in items {
    let (key, value) = item
    write_serialized_xml_attribute(builder, key, value)
  }
}

///|
fn xml_attribute_rank(key : String) -> Int {
  match key {
    "Id" => 0
    "Extension" => 0
    "PartName" => 0
    "Type" => 1
    "ContentType" => 1
    "Target" => 2
    "TargetMode" => 3
    _ => 10
  }
}

///|
fn write_serialized_xml_attribute(
  builder : StringBuilder,
  name : String,
  value : String,
) -> Unit {
  builder.write_string(" ")
  builder.write_string(name)
  builder.write_string("=\"")
  builder.write_string(escape_xml_attribute(value))
  builder.write_string("\"")
}

///|
/// Maximum element nesting depth accepted by the XML parser. Deeper documents
/// are rejected instead of overflowing the stack on malicious input.
let xml_max_depth : Int = 512

///|
priv struct XmlParser {
  source : String
  mut pos : Int
  mut depth : Int
  namespace_map : Map[String, String]
  namespaces : Map[String, String]
}

///|
fn XmlParser::parse_element(self : XmlParser) -> XmlElement raise DocxError {
  if self.depth >= xml_max_depth {
    raise InvalidXml(message="XML nesting too deep")
  }
  self.depth = self.depth + 1
  let element = self.parse_element_inner()
  self.depth = self.depth - 1
  element
}

///|
fn XmlParser::parse_element_inner(
  self : XmlParser,
) -> XmlElement raise DocxError {
  self.expect("<")
  let raw_name = self.read_name()
  let raw_attributes : Array[(String, String)] = []
  let saved_namespaces = self.namespaces.copy()
  while true {
    self.skip_whitespace()
    if self.starts_with("/>") {
      self.pos = self.pos + 2
      let element = self.build_element(raw_name, raw_attributes, [])
      self.namespaces.clear()
      self.namespaces.merge_in_place(saved_namespaces)
      return element
    } else if self.starts_with(">") {
      self.pos = self.pos + 1
      let children = self.parse_children(raw_name)
      let element = self.build_element(raw_name, raw_attributes, children)
      self.namespaces.clear()
      self.namespaces.merge_in_place(saved_namespaces)
      return element
    } else {
      let attr_name = self.read_name()
      self.skip_whitespace()
      self.expect("=")
      self.skip_whitespace()
      let attr_value = self.read_quoted_value()
      if attr_name == "xmlns" {
        self.namespaces[""] = attr_value
      } else if attr_name.has_prefix("xmlns:") {
        self.namespaces[attr_name[6:].to_owned()] = attr_value
      } else {
        raw_attributes.push((attr_name, attr_value))
      }
    }
  }
  // Defensive: the loop above always returns or raises.
  raise InvalidXml(message="unterminated element")
}

///|
fn XmlParser::parse_children(
  self : XmlParser,
  raw_name : String,
) -> Array[XmlNode] raise DocxError {
  let children : Array[XmlNode] = []
  while self.pos < self.source.length() {
    if self.starts_with("</") {
      self.pos = self.pos + 2
      let close_name = self.read_name()
      if close_name != raw_name {
        raise InvalidXml(
          message="mismatched closing tag: expected " +
            raw_name +
            " got " +
            close_name,
        )
      }
      self.skip_whitespace()
      self.expect(">")
      return children
    } else if self.starts_with("<!--") {
      self.skip_until("-->")
    } else if self.starts_with("<![CDATA[") {
      self.pos = self.pos + "<![CDATA[".length()
      children.push(XmlText(self.read_until("]]>")))
      self.pos = self.pos + "]]>".length()
    } else if self.starts_with("<?") {
      self.skip_until("?>")
    } else if self.starts_with("<!") {
      self.skip_until(">")
    } else if self.starts_with("<") {
      let element = self.parse_element()
      if element.name == "mc:AlternateContent" {
        children.append(element.first_or_empty("mc:Fallback").children)
      } else {
        children.push(XmlElement(element))
      }
    } else {
      let text = self.read_text()
      if text != "" {
        children.push(XmlText(decode_xml_entities(text)))
      }
    }
  }
  raise InvalidXml(message="unclosed tag: " + raw_name)
}

///|
fn XmlParser::build_element(
  self : XmlParser,
  raw_name : String,
  raw_attributes : Array[(String, String)],
  children : Array[XmlNode],
) -> XmlElement raise DocxError {
  let attributes : Map[String, String] = Map([])
  for item in raw_attributes {
    let (name, value) = item
    attributes[self.map_name(name, is_attribute=true)] = decode_xml_entities(
      value,
    )
  }
  { name: self.map_name(raw_name, is_attribute=false), attributes, children }
}

///|
fn XmlParser::map_name(
  self : XmlParser,
  raw_name : String,
  is_attribute~ : Bool,
) -> String {
  match raw_name.find(":") {
    Some(index) => {
      let prefix = raw_name[:index].to_owned()
      let local_name = raw_name[index + 1:].to_owned()
      match self.namespaces.get(prefix) {
        Some(uri) => self.map_uri_name(uri, local_name)
        None => raw_name
      }
    }
    None =>
      if is_attribute {
        raw_name
      } else {
        match self.namespaces.get("") {
          Some(uri) => self.map_uri_name(uri, raw_name)
          None => raw_name
        }
      }
  }
}

///|
fn XmlParser::map_uri_name(
  self : XmlParser,
  uri : String,
  local_name : String,
) -> String {
  match self.namespace_map.get(uri) {
    Some(prefix) =>
      if prefix == "" {
        "{" + uri + "}" + local_name
      } else {
        prefix + ":" + local_name
      }
    None => "{" + uri + "}" + local_name
  }
}

///|
fn XmlParser::skip_misc(self : XmlParser) -> Unit raise DocxError {
  while true {
    self.skip_whitespace()
    if self.starts_with("<?") {
      self.skip_until("?>")
    } else if self.starts_with("<!--") {
      self.skip_until("-->")
    } else {
      return
    }
  }
}

///|
fn XmlParser::skip_whitespace(self : XmlParser) -> Unit {
  while self.pos < self.source.length() &&
        (
          self.source[self.pos] == ' ' ||
          self.source[self.pos] == '\n' ||
          self.source[self.pos] == '\r' ||
          self.source[self.pos] == '\t'
        ) {
    self.pos = self.pos + 1
  }
}

///|
fn xml_boundary_splits_pair(source : String, boundary : Int) -> Bool {
  if boundary <= 0 || boundary >= source.length() {
    return false
  }
  let unit = source[boundary].to_int()
  let previous = source[boundary - 1].to_int()
  unit >= 0xDC00 && unit <= 0xDFFF && previous >= 0xD800 && previous <= 0xDBFF
}

///|
/// Extract a substring by UTF-16 code-unit range. Core string slicing aborts
/// when a boundary splits a surrogate pair, so malicious input could crash
/// the parser; raise the parser's typed error instead of aborting or of
/// silently emitting an invalid-UTF-16 slice. Slices whose boundaries fall on
/// valid positions are copied verbatim (exactly what core slicing produced
/// historically), so well-formed documents are unaffected.
fn xml_substring(
  source : String,
  start : Int,
  end : Int,
) -> String raise DocxError {
  if xml_boundary_splits_pair(source, start) ||
    xml_boundary_splits_pair(source, end) {
    raise InvalidXml(message="invalid UTF-16 in XML content")
  }
  let builder = StringBuilder()
  for index in start..<end {
    builder.write_char(Int::unsafe_to_char(source[index].to_int()))
  }
  builder.to_string()
}

///|
fn XmlParser::read_name(self : XmlParser) -> String raise DocxError {
  let start = self.pos
  while self.pos < self.source.length() {
    let c = self.source[self.pos]
    if (c >= 'a' && c <= 'z') ||
      (c >= 'A' && c <= 'Z') ||
      (c >= '0' && c <= '9') ||
      c == ':' ||
      c == '_' ||
      c == '-' ||
      c == '.' {
      self.pos = self.pos + 1
    } else {
      break
    }
  }
  if self.pos == start {
    raise InvalidXml(message="expected XML name")
  }
  xml_substring(self.source, start, self.pos)
}

///|
fn XmlParser::read_quoted_value(self : XmlParser) -> String raise DocxError {
  if self.pos >= self.source.length() {
    raise InvalidXml(message="expected quoted attribute value")
  }
  let quote = self.source[self.pos]
  if quote != '"' && quote != '\'' {
    raise InvalidXml(message="expected quoted attribute value")
  }
  self.pos = self.pos + 1
  let start = self.pos
  while self.pos < self.source.length() && self.source[self.pos] != quote {
    self.pos = self.pos + 1
  }
  if self.pos >= self.source.length() {
    raise InvalidXml(message="unterminated attribute value")
  }
  let value = xml_substring(self.source, start, self.pos)
  self.pos = self.pos + 1
  value
}

///|
fn XmlParser::read_text(self : XmlParser) -> String raise DocxError {
  let start = self.pos
  while self.pos < self.source.length() && self.source[self.pos] != '<' {
    self.pos = self.pos + 1
  }
  xml_substring(self.source, start, self.pos)
}

///|
fn XmlParser::expect(self : XmlParser, value : String) -> Unit raise DocxError {
  if self.starts_with(value) {
    self.pos = self.pos + value.length()
  } else {
    raise InvalidXml(message="expected `" + value + "`")
  }
}

///|
fn XmlParser::starts_with(self : XmlParser, value : String) -> Bool {
  let value_length = value.length()
  if self.pos + value_length > self.source.length() {
    return false
  }
  for index in 0..<value_length {
    if self.source[self.pos + index] != value[index] {
      return false
    }
  }
  true
}

///|
fn XmlParser::read_until(
  self : XmlParser,
  needle : String,
) -> String raise DocxError {
  let start = self.pos
  while self.pos + needle.length() <= self.source.length() {
    if self.starts_with(needle) {
      return xml_substring(self.source, start, self.pos)
    }
    self.pos = self.pos + 1
  }
  raise InvalidXml(message="expected `" + needle + "`")
}

///|
fn XmlParser::skip_until(
  self : XmlParser,
  needle : String,
) -> Unit raise DocxError {
  ignore(self.read_until(needle))
  self.pos = self.pos + needle.length()
}

///|
fn decode_xml_entities(value : String) -> String raise DocxError {
  let builder = StringBuilder()
  let mut index = 0
  while index < value.length() {
    if value[index] == '&' {
      match value[index:].find(";") {
        Some(length) => {
          let entity = xml_substring(value, index + 1, index + length)
          builder.write_string(decode_xml_entity(entity))
          index = index + length + 1
        }
        None => {
          builder.write_char('&')
          index = index + 1
        }
      }
    } else {
      let char = match value.get_char(index) {
        Some(char) => char
        None => raise InvalidXml(message="invalid UTF-16 in XML content")
      }
      builder.write_char(char)
      index = index + char.utf16_len()
    }
  }
  builder.to_string()
}

///|
fn decode_xml_entity(entity : String) -> String {
  match entity {
    "amp" => "&"
    "lt" => "<"
    "gt" => ">"
    "quot" => "\""
    "apos" => "'"
    _ =>
      match decode_numeric_xml_entity(entity) {
        Some(value) => value
        None => "&" + entity + ";"
      }
  }
}

///|
fn decode_numeric_xml_entity(entity : String) -> String? {
  if entity.length() < 2 || entity[0] != '#' || !is_xmldom_entity_word(entity) {
    return None
  }
  match parse_xmldom_numeric_entity(entity[1:].to_owned()) {
    None => Some("\u{0}")
    Some(codepoint) =>
      match Int::to_char(codepoint) {
        Some(char) => Some(char.to_string())
        None => None
      }
  }
}

///|
fn is_xmldom_entity_word(entity : String) -> Bool {
  for index in 1..<entity.length() {
    let char = entity[index]
    if !((char >= '0' && char <= '9') ||
      (char >= 'A' && char <= 'Z') ||
      (char >= 'a' && char <= 'z') ||
      char == '_') {
      return false
    }
  }
  true
}

///|
fn parse_xmldom_numeric_entity(text : String) -> Int? {
  js_parse_int(replace_first_lower_x_with_hex_prefix(text))
}

///|
fn replace_first_lower_x_with_hex_prefix(text : String) -> String {
  let builder = StringBuilder()
  let mut replaced = false
  for index in 0..<text.length() {
    if !replaced && text[index] == 'x' {
      builder.write_string("0x")
      replaced = true
    } else {
      builder.write_string(text[index:index + 1].to_owned())
    }
  }
  builder.to_string()
}

///|
fn js_parse_int(text : String) -> Int? {
  let mut index = 0
  let mut radix = 10
  if text.length() >= 2 && text[0] == '0' && (text[1] == 'x' || text[1] == 'X') {
    radix = 16
    index = 2
  }
  let mut value = 0
  let mut saw_digit = false
  while index < text.length() {
    match xml_entity_digit_value(text[index], radix) {
      Some(digit) => {
        saw_digit = true
        if value > (0x10FFFF - digit) / radix {
          return Some(0x110000)
        }
        value = value * radix + digit
        index += 1
      }
      None => break
    }
  }
  if saw_digit {
    Some(value)
  } else {
    None
  }
}

///|
fn xml_entity_digit_value(char : UInt16, radix : Int) -> Int? {
  let value = if char >= '0' && char <= '9' {
    Some(char.to_int() - '0'.to_int())
  } else if char >= 'A' && char <= 'F' {
    Some(char.to_int() - 'A'.to_int() + 10)
  } else if char >= 'a' && char <= 'f' {
    Some(char.to_int() - 'a'.to_int() + 10)
  } else {
    None
  }
  match value {
    Some(digit) => if digit < radix { Some(digit) } else { None }
    None => None
  }
}

///|
fn escape_xml_text(value : String) -> String {
  let builder = StringBuilder()
  for char in value {
    match char {
      '&' => builder.write_string("&amp;")
      '<' => builder.write_string("&lt;")
      '>' => builder.write_string("&gt;")
      _ => builder.write_char(char)
    }
  }
  builder.to_string()
}

///|
fn escape_xml_attribute(value : String) -> String {
  let builder = StringBuilder()
  for char in value {
    match char {
      '&' => builder.write_string("&amp;")
      '<' => builder.write_string("&lt;")
      '>' => builder.write_string("&gt;")
      '"' => builder.write_string("&quot;")
      _ => builder.write_char(char)
    }
  }
  builder.to_string()
}
