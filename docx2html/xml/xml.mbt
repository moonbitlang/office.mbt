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
  read_xml_string_with_mode(source, namespace_map, false)
}

///|
/// Parses DTD-free XML 1.0 with Namespaces well-formedness checks enabled.
///
/// The regular parser intentionally preserves historical xmldom-compatible
/// recovery behavior for document conversion. Package metadata and mutation
/// gates should use this entry point so malformed XML fails closed.
pub fn read_xml_string_strict(
  source : String,
  namespace_map? : Map[String, String] = Map([]),
) -> XmlElement raise DocxError {
  read_xml_string_with_mode(source, namespace_map, true)
}

///|
fn read_xml_string_with_mode(
  source : String,
  namespace_map : Map[String, String],
  strict : Bool,
) -> XmlElement raise DocxError {
  if strict {
    validate_xml_characters(source)
  }
  let parser = XmlParser::{
    source,
    pos: 0,
    depth: 0,
    strict,
    seen_xml_declaration: false,
    namespace_map,
    namespaces: if strict {
      Map([("xml", XML_NAMESPACE_URI)])
    } else {
      Map([])
    },
  }
  parser.skip_misc(document_start=true)
  let root = parser.parse_element()
  parser.skip_misc(document_start=false)
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
/// Serializes one element as a FRAGMENT: no XML declaration, with the
/// given namespace declarations placed on the element itself — the
/// self-contained form the L0 splice contract requires (a fragment's
/// correctness must not depend on the destination document's own
/// bindings).
pub fn write_xml_fragment(
  element : XmlElement,
  namespaces? : Map[String, String] = Map([]),
) -> String {
  let writer = XmlWriter::{ namespaces, uri_to_prefix: invert_map(namespaces) }
  let builder = StringBuilder()
  writer.write_element(builder, element, is_root=true)
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
/// Maximum element nesting depth accepted by the tolerant XML parser. Strict
/// parsing uses a smaller ceiling because its additional namespace and lexical
/// checks require larger stack frames on the Wasm backend.
let xml_max_depth : Int = 512

///|
let strict_xml_max_depth : Int = 256

///|
const XML_NAMESPACE_URI : String = "http://www.w3.org/XML/1998/namespace"

///|
const XMLNS_NAMESPACE_URI : String = "http://www.w3.org/2000/xmlns/"

///|
fn is_xml_character(char : Char) -> Bool {
  let code = char.to_int()
  code == 0x9 ||
  code == 0xa ||
  code == 0xd ||
  (code >= 0x20 && code <= 0xd7ff) ||
  (code >= 0xe000 && code <= 0xfffd) ||
  (code >= 0x10000 && code <= 0x10ffff)
}

///|
fn validate_xml_characters(source : String) -> Unit raise DocxError {
  let mut index = 0
  while index < source.length() {
    let char = match source.get_char(index) {
      Some(char) => char
      None => raise InvalidXml(message="invalid UTF-16 in XML content")
    }
    if !is_xml_character(char) {
      raise InvalidXml(message="illegal XML character")
    }
    index = index + char.utf16_len()
  }
}

///|
fn is_xml_name_start_char(char : Char) -> Bool {
  let code = char.to_int()
  char.is_ascii_alphabetic() ||
  char == ':' ||
  char == '_' ||
  (code >= 0xc0 && code <= 0xd6) ||
  (code >= 0xd8 && code <= 0xf6) ||
  (code >= 0xf8 && code <= 0x2ff) ||
  (code >= 0x370 && code <= 0x37d) ||
  (code >= 0x37f && code <= 0x1fff) ||
  (code >= 0x200c && code <= 0x200d) ||
  (code >= 0x2070 && code <= 0x218f) ||
  (code >= 0x2c00 && code <= 0x2fef) ||
  (code >= 0x3001 && code <= 0xd7ff) ||
  (code >= 0xf900 && code <= 0xfdcf) ||
  (code >= 0xfdf0 && code <= 0xfffd) ||
  (code >= 0x10000 && code <= 0xeffff)
}

///|
fn is_xml_name_char(char : Char) -> Bool {
  let code = char.to_int()
  is_xml_name_start_char(char) ||
  char == '-' ||
  char == '.' ||
  char.is_ascii_digit() ||
  code == 0xb7 ||
  (code >= 0x300 && code <= 0x36f) ||
  (code >= 0x203f && code <= 0x2040)
}

///|
fn is_xml_ncname(value : StringView) -> Bool {
  let chars = value.to_array()
  if chars.length() == 0 || chars[0] == ':' || !is_xml_name_start_char(chars[0]) {
    return false
  }
  for index = 1; index < chars.length(); index = index + 1 {
    if chars[index] == ':' || !is_xml_name_char(chars[index]) {
      return false
    }
  }
  true
}

///|
fn is_xml_qname(value : StringView) -> Bool {
  match value.find(":") {
    Some(colon) => {
      let prefix = value[:colon]
      let local_name = value[colon + 1:]
      is_xml_ncname(prefix) &&
      is_xml_ncname(local_name) &&
      !local_name.contains(":")
    }
    None => is_xml_ncname(value)
  }
}

///|
priv struct XmlParser {
  source : String
  mut pos : Int
  mut depth : Int
  strict : Bool
  mut seen_xml_declaration : Bool
  namespace_map : Map[String, String]
  namespaces : Map[String, String]
}

///|
fn XmlParser::parse_element(self : XmlParser) -> XmlElement raise DocxError {
  let max_depth = if self.strict { strict_xml_max_depth } else { xml_max_depth }
  if self.depth >= max_depth {
    raise InvalidXml(message="XML nesting too deep")
  }
  self.depth = self.depth + 1
  let element = if self.strict {
    self.parse_element_inner_strict()
  } else {
    self.parse_element_inner_tolerant()
  }
  self.depth = self.depth - 1
  element
}

///|
fn XmlParser::parse_element_inner_tolerant(
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
  raise InvalidXml(message="unterminated element")
}

///|
fn XmlParser::parse_element_inner_strict(
  self : XmlParser,
) -> XmlElement raise DocxError {
  self.expect("<")
  let raw_name = self.read_name()
  if !is_xml_qname(raw_name) {
    raise InvalidXml(message="invalid XML qualified name: " + raw_name)
  }
  let raw_attributes : Array[(String, String)] = []
  let raw_attribute_names : Map[String, Bool] = Map([])
  let saved_namespaces = self.namespaces.copy()
  while true {
    let separated = self.skip_whitespace_and_report()
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
      if !separated {
        raise InvalidXml(message="attributes must be separated by whitespace")
      }
      let attr_name = self.read_name()
      if !is_xml_qname(attr_name) {
        raise InvalidXml(message="invalid XML qualified name: " + attr_name)
      }
      if raw_attribute_names.contains(attr_name) {
        raise InvalidXml(message="duplicate XML attribute: " + attr_name)
      }
      raw_attribute_names[attr_name] = true
      self.skip_whitespace()
      self.expect("=")
      self.skip_whitespace()
      let attr_value = self.read_quoted_value()
      if attr_name == "xmlns" {
        let namespace_uri = decode_xml_entities_strict(
          attr_value,
          attribute=true,
        )
        validate_namespace_declaration("", namespace_uri)
        self.namespaces[""] = namespace_uri
      } else if attr_name.has_prefix("xmlns:") {
        let prefix = attr_name[6:].to_owned()
        let namespace_uri = decode_xml_entities_strict(
          attr_value,
          attribute=true,
        )
        validate_namespace_declaration(prefix, namespace_uri)
        self.namespaces[prefix] = namespace_uri
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
      if self.strict && !is_xml_qname(close_name) {
        raise InvalidXml(message="invalid XML qualified name: " + close_name)
      }
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
      self.skip_comment()
    } else if self.starts_with("<![CDATA[") {
      self.pos = self.pos + "<![CDATA[".length()
      let cdata = self.read_until("]]>")
      children.push(
        XmlText(
          if self.strict {
            normalize_xml_source_text(cdata, attribute=false)
          } else {
            cdata
          },
        ),
      )
      self.pos = self.pos + "]]>".length()
    } else if self.starts_with("<?") {
      if self.strict {
        self.skip_processing_instruction(allow_xml_declaration=false)
      } else {
        self.skip_until("?>")
      }
    } else if self.starts_with("<!") {
      if self.strict {
        raise InvalidXml(message="DTD and markup declarations are not allowed")
      } else {
        self.skip_until(">")
      }
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
        children.push(
          XmlText(
            if self.strict {
              decode_xml_entities_strict(text, attribute=false)
            } else {
              decode_xml_entities(text)
            },
          ),
        )
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
  let expanded_attributes : Map[String, Bool] = Map([])
  for item in raw_attributes {
    let (name, value) = item
    if self.strict {
      let expanded = self.expanded_name(name, is_attribute=true)
      if expanded_attributes.contains(expanded) {
        raise InvalidXml(
          message="duplicate expanded XML attribute: " + expanded,
        )
      }
      expanded_attributes[expanded] = true
    }
    attributes[self.map_name(name, is_attribute=true)] = if self.strict {
      decode_xml_entities_strict(value, attribute=true)
    } else {
      decode_xml_entities(value)
    }
  }
  { name: self.map_name(raw_name, is_attribute=false), attributes, children }
}

///|
fn XmlParser::map_name(
  self : XmlParser,
  raw_name : String,
  is_attribute~ : Bool,
) -> String raise DocxError {
  match raw_name.find(":") {
    Some(index) => {
      let prefix = raw_name[:index].to_owned()
      let local_name = raw_name[index + 1:].to_owned()
      match self.namespaces.get(prefix) {
        Some(uri) => self.map_uri_name(uri, local_name)
        None =>
          if self.strict {
            raise InvalidXml(message="unbound XML namespace prefix: " + prefix)
          } else {
            raw_name
          }
      }
    }
    None =>
      if is_attribute {
        raw_name
      } else {
        match self.namespaces.get("") {
          Some("") if self.strict => raw_name
          Some(uri) => self.map_uri_name(uri, raw_name)
          None => raw_name
        }
      }
  }
}

///|
fn XmlParser::expanded_name(
  self : XmlParser,
  raw_name : String,
  is_attribute~ : Bool,
) -> String raise DocxError {
  match raw_name.find(":") {
    Some(index) => {
      let prefix = raw_name[:index].to_owned()
      let local_name = raw_name[index + 1:].to_owned()
      match self.namespaces.get(prefix) {
        Some(uri) => "{" + uri + "}" + local_name
        None =>
          raise InvalidXml(message="unbound XML namespace prefix: " + prefix)
      }
    }
    None =>
      if is_attribute {
        raw_name
      } else {
        match self.namespaces.get("") {
          Some(uri) if uri != "" => "{" + uri + "}" + raw_name
          _ => raw_name
        }
      }
  }
}

///|
fn validate_namespace_declaration(
  prefix : String,
  namespace_uri : String,
) -> Unit raise DocxError {
  for char in namespace_uri {
    if char == ' ' || char == '\t' || char == '\n' || char == '\r' {
      raise InvalidXml(message="a namespace name cannot contain whitespace")
    }
  }
  if prefix == "xmlns" || namespace_uri == XMLNS_NAMESPACE_URI {
    raise InvalidXml(message="invalid xmlns namespace binding")
  }
  if prefix == "xml" {
    if namespace_uri != XML_NAMESPACE_URI {
      raise InvalidXml(message="the xml prefix has an invalid namespace")
    }
  } else if namespace_uri == XML_NAMESPACE_URI {
    raise InvalidXml(message="the XML namespace is reserved for the xml prefix")
  }
  if prefix != "" && namespace_uri == "" {
    raise InvalidXml(message="a namespace prefix cannot be undeclared")
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
fn XmlParser::skip_misc(
  self : XmlParser,
  document_start~ : Bool,
) -> Unit raise DocxError {
  let mut declaration_allowed = document_start && self.pos == 0
  while true {
    if self.skip_whitespace_and_report() {
      declaration_allowed = false
    }
    if self.starts_with("<?") {
      if self.strict {
        self.skip_processing_instruction(
          allow_xml_declaration=declaration_allowed,
        )
      } else {
        self.skip_until("?>")
      }
      declaration_allowed = false
    } else if self.starts_with("<!--") {
      self.skip_comment()
      declaration_allowed = false
    } else if self.strict && self.starts_with("<!") {
      raise InvalidXml(message="DTD and markup declarations are not allowed")
    } else {
      return
    }
  }
}

///|
fn XmlParser::skip_comment(self : XmlParser) -> Unit raise DocxError {
  if !self.strict {
    self.skip_until("-->")
    return
  }
  self.pos = self.pos + "<!--".length()
  while self.pos < self.source.length() {
    if self.starts_with("-->") {
      self.pos = self.pos + "-->".length()
      return
    }
    if self.starts_with("--") {
      raise InvalidXml(message="XML comments cannot contain '--'")
    }
    let char = match self.source.get_char(self.pos) {
      Some(char) => char
      None => raise InvalidXml(message="invalid UTF-16 in XML content")
    }
    self.pos = self.pos + char.utf16_len()
  }
  raise InvalidXml(message="unterminated XML comment")
}

///|
fn is_valid_xml_encoding_name(value : StringView) -> Bool {
  let chars = value.to_array()
  if chars.length() == 0 || !chars[0].is_ascii_alphabetic() {
    return false
  }
  for index = 1; index < chars.length(); index = index + 1 {
    let char = chars[index]
    if !char.is_ascii_alphabetic() &&
      !char.is_ascii_digit() &&
      char != '.' &&
      char != '_' &&
      char != '-' {
      return false
    }
  }
  true
}

///|
fn XmlParser::parse_xml_declaration(self : XmlParser) -> Unit raise DocxError {
  let names : Map[String, Bool] = Map([])
  let mut position = 0
  let mut has_version = false
  while true {
    let separated = self.skip_whitespace_and_report()
    if self.starts_with("?>") {
      if !has_version {
        raise InvalidXml(message="XML declaration has no version")
      }
      self.pos = self.pos + "?>".length()
      self.seen_xml_declaration = true
      return
    }
    if !separated {
      raise InvalidXml(message="malformed XML declaration")
    }
    let name = self.read_name()
    if !is_xml_ncname(name) || names.contains(name) {
      raise InvalidXml(message="invalid XML declaration attribute: " + name)
    }
    names[name] = true
    self.skip_whitespace()
    self.expect("=")
    self.skip_whitespace()
    let value = self.read_quoted_value()
    if value.contains("&") {
      raise InvalidXml(message="entities are not allowed in XML declarations")
    }
    match (position, name) {
      (0, "version") => {
        if value != "1.0" {
          raise InvalidXml(message="unsupported XML version: " + value)
        }
        has_version = true
      }
      (1, "encoding") =>
        if !is_valid_xml_encoding_name(value) {
          raise InvalidXml(message="invalid XML encoding name: " + value)
        }
      (1, "standalone") | (2, "standalone") =>
        if value != "yes" && value != "no" {
          raise InvalidXml(message="invalid XML standalone value: " + value)
        }
      _ =>
        raise InvalidXml(
          message="misordered XML declaration attribute: " + name,
        )
    }
    position = position + 1
  }
}

///|
fn XmlParser::skip_processing_instruction(
  self : XmlParser,
  allow_xml_declaration~ : Bool,
) -> Unit raise DocxError {
  self.pos = self.pos + "<?".length()
  let target = self.read_name()
  if target.to_lower() == "xml" {
    if target != "xml" || !allow_xml_declaration || self.seen_xml_declaration {
      raise InvalidXml(message="misplaced XML declaration")
    }
    self.parse_xml_declaration()
    return
  }
  if self.starts_with("?>") {
    self.pos = self.pos + "?>".length()
    return
  }
  if !self.skip_whitespace_and_report() {
    raise InvalidXml(message="malformed processing instruction")
  }
  self.skip_until("?>")
}

///|
fn XmlParser::skip_whitespace(self : XmlParser) -> Unit {
  ignore(self.skip_whitespace_and_report())
}

///|
fn XmlParser::skip_whitespace_and_report(self : XmlParser) -> Bool {
  let start = self.pos
  while self.pos < self.source.length() &&
        (
          self.source[self.pos] == ' ' ||
          self.source[self.pos] == '\n' ||
          self.source[self.pos] == '\r' ||
          self.source[self.pos] == '\t'
        ) {
    self.pos = self.pos + 1
  }
  self.pos > start
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
  if self.strict {
    let first = match self.source.get_char(self.pos) {
      Some(char) => char
      None => raise InvalidXml(message="expected XML name")
    }
    if !is_xml_name_start_char(first) {
      raise InvalidXml(message="expected XML name")
    }
    self.pos = self.pos + first.utf16_len()
    while self.pos < self.source.length() {
      let char = match self.source.get_char(self.pos) {
        Some(char) => char
        None => raise InvalidXml(message="invalid UTF-16 in XML content")
      }
      if !is_xml_name_char(char) {
        break
      }
      self.pos = self.pos + char.utf16_len()
    }
    return xml_substring(self.source, start, self.pos)
  }
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
    if self.strict && self.source[self.pos] == '<' {
      raise InvalidXml(message="raw '<' is not allowed in an attribute value")
    }
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
    if self.strict && self.starts_with("]]>") {
      raise InvalidXml(message="']]>' is not allowed in XML character data")
    }
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
fn strict_numeric_xml_entity(entity : String) -> String raise DocxError {
  let (base, start) = if entity.has_prefix("#x") {
    (16, 2)
  } else if entity.has_prefix("#") {
    (10, 1)
  } else {
    raise InvalidXml(message="undeclared XML entity: &" + entity + ";")
  }
  if start >= entity.length() {
    raise InvalidXml(message="malformed numeric XML entity")
  }
  let mut codepoint = 0
  for index = start; index < entity.length(); index = index + 1 {
    let char = entity[index]
    let digit = if char >= '0' && char <= '9' {
      char.to_int() - '0'.to_int()
    } else if base == 16 && char >= 'A' && char <= 'F' {
      char.to_int() - 'A'.to_int() + 10
    } else if base == 16 && char >= 'a' && char <= 'f' {
      char.to_int() - 'a'.to_int() + 10
    } else {
      raise InvalidXml(message="malformed numeric XML entity")
    }
    if codepoint > (0x10ffff - digit) / base {
      raise InvalidXml(message="numeric XML entity is out of range")
    }
    codepoint = codepoint * base + digit
  }
  let char = match Int::to_char(codepoint) {
    Some(char) if is_xml_character(char) => char
    _ => raise InvalidXml(message="numeric XML entity is not an XML character")
  }
  char.to_string()
}

///|
fn decode_xml_entity_strict(entity : String) -> String raise DocxError {
  match entity {
    "amp" => "&"
    "lt" => "<"
    "gt" => ">"
    "quot" => "\""
    "apos" => "'"
    _ => strict_numeric_xml_entity(entity)
  }
}

///|
/// Applies XML 1.0 source normalization before entity replacement. Character
/// references are still encoded at this stage, so references such as `&#xD;`
/// retain their referenced value while literal CR and CRLF sequences become LF.
fn normalize_xml_source_text(
  value : String,
  attribute~ : Bool,
) -> String raise DocxError {
  let builder = StringBuilder()
  let mut index = 0
  while index < value.length() {
    let char = match value.get_char(index) {
      Some(char) => char
      None => raise InvalidXml(message="invalid UTF-16 in XML content")
    }
    if char == '\r' {
      let next = index + char.utf16_len()
      if next < value.length() && value[next] == '\n' {
        index = next
      }
      builder.write_char(if attribute { ' ' } else { '\n' })
    } else if attribute && (char == '\t' || char == '\n') {
      builder.write_char(' ')
    } else {
      builder.write_char(char)
    }
    index = index + char.utf16_len()
  }
  builder.to_string()
}

///|
fn decode_xml_entities_strict(
  value : String,
  attribute~ : Bool,
) -> String raise DocxError {
  let normalized = normalize_xml_source_text(value, attribute~)
  let builder = StringBuilder()
  let mut index = 0
  while index < normalized.length() {
    if normalized[index] == '&' {
      let length = match normalized[index:].find(";") {
        Some(length) => length
        None => raise InvalidXml(message="unterminated XML entity")
      }
      let entity = xml_substring(normalized, index + 1, index + length)
      builder.write_string(decode_xml_entity_strict(entity))
      index = index + length + 1
    } else {
      let char = match normalized.get_char(index) {
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
