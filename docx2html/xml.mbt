///|
pub(all) enum XmlNode {
  XmlElement(XmlElement)
  XmlText(String)
} derive(Debug, Eq)

///|
pub(all) struct XmlElement {
  name : String
  attributes : Map[String, String]
  children : Array[XmlNode]
} derive(Debug, Eq)

///|
pub fn xml_element(
  name : String,
  attributes? : Map[String, String] = {},
  children? : Array[XmlNode] = [],
) -> XmlElement {
  { name, attributes, children }
}

///|
pub fn xml_text(value : String) -> XmlNode {
  XmlText(value)
}

///|
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
pub fn read_xml_string(
  source : String,
  namespace_map? : Map[String, String] = {},
) -> XmlElement raise DocxError {
  let parser = XmlParser::{ source, pos: 0, namespace_map, namespaces: {} }
  parser.skip_misc()
  let root = parser.parse_element()
  parser.skip_misc()
  if parser.pos < parser.source.length() {
    raise InvalidXml(message="unexpected content after document element")
  }
  root
}

///|
pub fn write_xml_string(
  root : XmlElement,
  namespaces? : Map[String, String] = {},
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
  let inverse : Map[String, String] = {}
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
priv struct XmlParser {
  source : String
  mut pos : Int
  namespace_map : Map[String, String]
  namespaces : Map[String, String]
}

///|
fn XmlParser::parse_element(self : XmlParser) -> XmlElement raise DocxError {
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
  abort("unreachable")
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
) -> XmlElement {
  let attributes : Map[String, String] = {}
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
  self.source[start:self.pos].to_owned()
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
  let value = self.source[start:self.pos].to_owned()
  self.pos = self.pos + 1
  value
}

///|
fn XmlParser::read_text(self : XmlParser) -> String {
  let start = self.pos
  while self.pos < self.source.length() && self.source[self.pos] != '<' {
    self.pos = self.pos + 1
  }
  self.source[start:self.pos].to_owned()
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
  self.pos + value.length() <= self.source.length() &&
  self.source[self.pos:self.pos + value.length()] == value
}

///|
fn XmlParser::read_until(
  self : XmlParser,
  needle : String,
) -> String raise DocxError {
  let start = self.pos
  while self.pos + needle.length() <= self.source.length() {
    if self.starts_with(needle) {
      return self.source[start:self.pos].to_owned()
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
fn decode_xml_entities(value : String) -> String {
  let builder = StringBuilder()
  let mut index = 0
  while index < value.length() {
    if value[index] == '&' {
      match value[index:].find(";") {
        Some(length) => {
          let entity = value[index + 1:index + length].to_owned()
          builder.write_string(decode_xml_entity(entity))
          index = index + length + 1
        }
        None => {
          builder.write_char('&')
          index = index + 1
        }
      }
    } else {
      builder.write_char(value.get_char(index).unwrap())
      index = index + 1
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
    _ => "&" + entity + ";"
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
