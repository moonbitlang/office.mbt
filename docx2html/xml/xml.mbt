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
  read_xml_string_with_mode(source, namespace_map, false, None, false, None)
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
  read_xml_string_with_mode(source, namespace_map, true, None, false, None)
}

///|
/// The byte encoding used to decode an XML source string. Passing it to
/// `read_xml_string_strict_encoded` makes an optional XML declaration part of
/// the strict contract instead of treating it as unaudited metadata.
pub(all) enum XmlSourceEncoding {
  Utf8
  Utf16LittleEndian
  Utf16BigEndian
}

///|
/// Strictly parses an already decoded XML string and rejects an encoding
/// declaration that contradicts the supplied byte encoding.
pub fn read_xml_string_strict_encoded(
  source : String,
  source_encoding : XmlSourceEncoding,
  namespace_map? : Map[String, String] = Map([]),
) -> XmlElement raise DocxError {
  read_xml_string_with_mode(
    source,
    namespace_map,
    true,
    None,
    false,
    Some(source_encoding),
  )
}

///|
/// A cumulative allocation budget shared by one or more XML parses.
///
/// Source storage is charged before decoding, and every materialized XML name,
/// attribute value, text/CDATA segment, and element is charged before the
/// parser copies or appends it. Reusing one budget across package parts bounds
/// the aggregate DOM rather than granting every part an independent ceiling.
pub struct XmlReadBudget {
  priv mut remaining_source_units : Int
  priv mut remaining_tokens : Int
  priv mut remaining_materialized_chars : Int
  priv max_token_chars : Int
}

///|
/// Builds a cumulative XML read budget. Negative ceilings clamp to zero; a
/// zero ceiling is valid and makes the corresponding first charge fail.
pub fn xml_read_budget(
  max_source_units~ : Int,
  max_tokens~ : Int,
  max_materialized_chars~ : Int,
  max_token_chars~ : Int,
) -> XmlReadBudget {
  {
    remaining_source_units: if max_source_units > 0 {
      max_source_units
    } else {
      0
    },
    remaining_tokens: if max_tokens > 0 {
      max_tokens
    } else {
      0
    },
    remaining_materialized_chars: if max_materialized_chars > 0 {
      max_materialized_chars
    } else {
      0
    },
    max_token_chars: if max_token_chars > 0 {
      max_token_chars
    } else {
      0
    },
  }
}

///|
fn XmlReadBudget::charge_source(
  self : XmlReadBudget,
  units : Int,
) -> Unit raise DocxError {
  if units < 0 || units > self.remaining_source_units {
    raise InvalidXml(message="XML source budget exceeded")
  }
  self.remaining_source_units -= units
}

///|
fn XmlReadBudget::charge_token(
  self : XmlReadBudget,
  chars : Int,
) -> Unit raise DocxError {
  if chars < 0 || chars > self.max_token_chars {
    raise InvalidXml(message="XML token length budget exceeded")
  }
  if self.remaining_tokens <= 0 {
    raise InvalidXml(message="XML token budget exceeded")
  }
  if chars > self.remaining_materialized_chars {
    raise InvalidXml(message="XML materialized character budget exceeded")
  }
  self.remaining_tokens -= 1
  self.remaining_materialized_chars -= chars
}

///|
/// Charges a derived string retained by a higher-level XML consumer. Parsers
/// already charge token materialization directly; projections such as indexed
/// structural paths must use this hook before allocating their own copies so
/// they remain inside the same cumulative envelope.
pub fn XmlReadBudget::charge_derived_chars(
  self : XmlReadBudget,
  chars : Int,
) -> Unit raise DocxError {
  if chars < 0 || chars > self.remaining_materialized_chars {
    raise InvalidXml(message="XML materialized character budget exceeded")
  }
  self.remaining_materialized_chars -= chars
}

///|
fn XmlReadBudget::charge_namespace_bindings(
  self : XmlReadBudget,
  operations : Int,
) -> Unit raise DocxError {
  // Namespace declarations allocate one scope-delta record and later restore
  // one map binding. Charge both operations before recording the declaration.
  if operations < 0 || operations > self.remaining_tokens {
    raise InvalidXml(message="XML token budget exceeded")
  }
  self.remaining_tokens -= operations
}

///|
/// Parses tolerant XML while charging a caller-owned cumulative budget.
/// String input is charged in UTF-16 storage units before parsing.
pub fn read_xml_string_limited(
  source : String,
  budget : XmlReadBudget,
  namespace_map? : Map[String, String] = Map([]),
) -> XmlElement raise DocxError {
  read_xml_string_with_mode(
    source,
    namespace_map,
    false,
    Some(budget),
    false,
    None,
  )
}

///|
/// Parses strict DTD-free XML while charging a caller-owned cumulative budget.
/// String input is charged in UTF-16 storage units before parsing.
pub fn read_xml_string_strict_limited(
  source : String,
  budget : XmlReadBudget,
  namespace_map? : Map[String, String] = Map([]),
) -> XmlElement raise DocxError {
  read_xml_string_with_mode(
    source,
    namespace_map,
    true,
    Some(budget),
    false,
    None,
  )
}

///|
/// Decodes and parses tolerant UTF-8 XML. Source bytes are charged before a
/// String is allocated, so oversized parts fail without a second full payload.
pub fn read_xml_bytes_limited(
  source : BytesView,
  budget : XmlReadBudget,
  namespace_map? : Map[String, String] = Map([]),
) -> XmlElement raise DocxError {
  budget.charge_source(source.length())
  let text = @utf8.decode(source, ignore_bom=true) catch {
    _ => raise InvalidXml(message="XML source is not valid UTF-8")
  }
  read_xml_string_with_mode(
    text,
    namespace_map,
    false,
    Some(budget),
    true,
    Some(Utf8),
  )
}

///|
/// Decodes and parses strict DTD-free UTF-8 XML under a cumulative budget.
pub fn read_xml_bytes_strict_limited(
  source : BytesView,
  budget : XmlReadBudget,
  namespace_map? : Map[String, String] = Map([]),
) -> XmlElement raise DocxError {
  budget.charge_source(source.length())
  let text = @utf8.decode(source, ignore_bom=true) catch {
    _ => raise InvalidXml(message="XML source is not valid UTF-8")
  }
  read_xml_string_with_mode(
    text,
    namespace_map,
    true,
    Some(budget),
    true,
    Some(Utf8),
  )
}

///|
fn read_xml_string_with_mode(
  source : String,
  namespace_map : Map[String, String],
  strict : Bool,
  budget : XmlReadBudget?,
  source_already_charged : Bool,
  source_encoding : XmlSourceEncoding?,
) -> XmlElement raise DocxError {
  match budget {
    Some(budget) =>
      if !source_already_charged {
        budget.charge_source(source.length())
      }
    None => ()
  }
  if strict {
    validate_xml_characters(source)
  }
  let parser = XmlParser::{
    source,
    pos: 0,
    depth: 0,
    strict,
    budget,
    source_encoding,
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
/// Serializes one XML fragment only after an allocation-free sizing pass has
/// proved that its UTF-8 representation fits `max_output_bytes`. The sizing
/// pass accounts for escaping and namespace declarations and rejects excessive
/// nesting before the recursive writer runs.
pub fn write_xml_fragment_limited(
  element : XmlElement,
  max_output_bytes~ : Int,
  namespaces? : Map[String, String] = Map([]),
) -> String raise DocxError {
  let limit = if max_output_bytes > 0 { max_output_bytes } else { 0 }
  let work_scaled = limit.to_int64() * xml_write_name_work_scale.to_int64()
  let name_work_limit = if work_scaled > 2147483647L {
    2147483647
  } else {
    work_scaled.to_int()
  }
  let (uri_to_prefix, remaining_name_work) = invert_map_limited(
    namespaces, name_work_limit,
  )
  let sizer = XmlWriteSizer::{
    namespaces,
    uri_to_prefix,
    remaining_bytes: limit,
    remaining_name_work,
  }
  sizer.size_element(element, is_root=true, depth=0)
  let output_bytes = limit - sizer.remaining_bytes
  let writer = XmlWriter::{ namespaces, uri_to_prefix }
  let builder = StringBuilder(size_hint=output_bytes)
  writer.write_element(builder, element, is_root=true)
  builder.to_string()
}

///|
priv struct XmlWriter {
  namespaces : Map[String, String]
  uri_to_prefix : Map[String, String]
}

///|
/// The strict parser and limited writer share the same conservative recursive
/// depth ceiling, keeping their stack use portable on Wasm as well as native.
let xml_write_max_depth : Int = 256

///|
/// Namespace mapping may inspect a Clark name several times (delimiter scan,
/// owned lookup key, and hashing). Keep that work a fixed multiple of the
/// caller's output ceiling so a reused giant URI cannot turn a small permitted
/// fragment into quadratic serialization work. The multiplier comfortably
/// covers the standard OOXML namespace-to-tag ratio while rejecting hostile
/// amplification.
let xml_write_name_work_scale : Int = 64

///|
/// `Array::sort_by` is worst-case O(n log n). This conservative multiplier
/// covers pivot selection, its small-array bubble-sort path, heap-sort
/// fallback, and the fixed work around every string comparison.
let xml_write_sort_work_scale : Int = 8

///|
priv struct XmlWriteSizer {
  namespaces : Map[String, String]
  uri_to_prefix : Map[String, String]
  mut remaining_bytes : Int
  mut remaining_name_work : Int
}

///|
fn XmlWriteSizer::charge_bytes(
  self : XmlWriteSizer,
  bytes : Int,
) -> Unit raise DocxError {
  if bytes < 0 || bytes > self.remaining_bytes {
    raise InvalidXml(message="XML serialization byte limit exceeded")
  }
  self.remaining_bytes -= bytes
}

///|
fn XmlWriteSizer::charge_name_work(
  self : XmlWriteSizer,
  units : Int,
) -> Unit raise DocxError {
  if units < 0 || units > self.remaining_name_work {
    raise InvalidXml(message="XML serialization name work limit exceeded")
  }
  self.remaining_name_work -= units
}

///|
fn checked_xml_sort_name_work(
  item_count : Int,
  max_name_chars : Int,
  remaining : Int,
) -> Int raise DocxError {
  if item_count <= 1 {
    return 0
  }
  let mut levels = 0
  let mut value = item_count - 1
  while value > 0 {
    levels += 1
    value /= 2
  }
  let mut work = xml_write_sort_work_scale
  if item_count > remaining / work {
    raise InvalidXml(message="XML serialization name work limit exceeded")
  }
  work *= item_count
  if levels > remaining / work {
    raise InvalidXml(message="XML serialization name work limit exceeded")
  }
  work *= levels
  // Adding one charges the terminating comparison even when all names are
  // empty. Check before adding so hostile maximum-length names cannot wrap.
  if max_name_chars >= remaining / work {
    raise InvalidXml(message="XML serialization name work limit exceeded")
  }
  work *= max_name_chars + 1
  work
}

///|
fn XmlWriteSizer::charge_attribute_sort_work(
  self : XmlWriteSizer,
  attributes : Map[String, String],
) -> Unit raise DocxError {
  let mut item_count = 0
  let mut max_name_chars = 0
  for name, _ in attributes {
    // Charge the array materialization and one unit of map traversal before
    // accumulating cardinality for the later sort.
    self.charge_name_work(1)
    item_count += 1
    max_name_chars = max_name_chars.max(name.length())
  }
  self.charge_name_work(
    checked_xml_sort_name_work(
      item_count,
      max_name_chars,
      self.remaining_name_work,
    ),
  )
}

///|
fn XmlWriteSizer::charge_scalar(
  self : XmlWriteSizer,
  character : Char,
) -> Unit raise DocxError {
  let code = character.to_int()
  let bytes = if code <= 0x7F {
    1
  } else if code <= 0x7FF {
    2
  } else if code >= 0xD800 && code <= 0xDFFF {
    raise InvalidXml(message="XML serialization contains invalid Unicode")
  } else if code <= 0xFFFF {
    3
  } else if code <= 0x10FFFF {
    4
  } else {
    raise InvalidXml(message="XML serialization contains invalid Unicode")
  }
  self.charge_bytes(bytes)
}

///|
fn XmlWriteSizer::charge_raw(
  self : XmlWriteSizer,
  value : StringView,
) -> Unit raise DocxError {
  for character in value {
    self.charge_scalar(character)
  }
}

///|
fn XmlWriteSizer::charge_escaped_text(
  self : XmlWriteSizer,
  value : StringView,
) -> Unit raise DocxError {
  for character in value {
    match character {
      '&' => self.charge_bytes(5)
      '<' | '>' => self.charge_bytes(4)
      _ => self.charge_scalar(character)
    }
  }
}

///|
fn XmlWriteSizer::charge_escaped_attribute(
  self : XmlWriteSizer,
  value : StringView,
) -> Unit raise DocxError {
  for character in value {
    match character {
      '&' => self.charge_bytes(5)
      '<' | '>' => self.charge_bytes(4)
      '"' => self.charge_bytes(6)
      _ => self.charge_scalar(character)
    }
  }
}

///|
fn XmlWriteSizer::charge_mapped_name(
  self : XmlWriteSizer,
  name : String,
) -> Unit raise DocxError {
  if !name.has_prefix("{") {
    self.charge_raw(name)
    return
  }
  // Charge before scanning the attacker-controlled Clark name.
  self.charge_name_work(name.length())
  guard name.find("}") is Some(close) else {
    self.charge_raw(name)
    return
  }
  let uri = name[1:close]
  let local_name = name[close + 1:]
  // The owned key and its map hash each traverse the full URI. Charging both
  // here proves the identical unmetered writer pass below stays within the
  // same fixed-linear work envelope.
  self.charge_name_work(uri.length())
  self.charge_name_work(uri.length())
  match self.uri_to_prefix.get(uri.to_owned()) {
    Some("") => self.charge_raw(local_name)
    Some(prefix) => {
      self.charge_raw(prefix)
      self.charge_bytes(1)
      self.charge_raw(local_name)
    }
    None => self.charge_raw(name)
  }
}

///|
fn XmlWriteSizer::size_attribute(
  self : XmlWriteSizer,
  name : StringView,
  value : StringView,
) -> Unit raise DocxError {
  self.charge_bytes(1)
  self.charge_raw(name)
  self.charge_bytes(2)
  self.charge_escaped_attribute(value)
  self.charge_bytes(1)
}

///|
fn XmlWriteSizer::size_node(
  self : XmlWriteSizer,
  node : XmlNode,
  depth~ : Int,
) -> Unit raise DocxError {
  match node {
    XmlElement(element) => self.size_element(element, depth~)
    XmlText(value) => self.charge_escaped_text(value)
  }
}

///|
fn XmlWriteSizer::size_element(
  self : XmlWriteSizer,
  element : XmlElement,
  is_root? : Bool = false,
  depth~ : Int,
) -> Unit raise DocxError {
  if depth >= xml_write_max_depth {
    raise InvalidXml(message="XML serialization nesting limit exceeded")
  }
  self.charge_bytes(1)
  self.charge_mapped_name(element.name)
  if is_root {
    for prefix, uri in self.namespaces {
      if prefix == "" {
        self.size_attribute("xmlns", uri)
      } else {
        self.charge_bytes(1)
        self.charge_bytes(6)
        self.charge_raw(prefix)
        self.charge_bytes(2)
        self.charge_escaped_attribute(uri)
        self.charge_bytes(1)
      }
    }
  }
  self.charge_attribute_sort_work(element.attributes)
  for name, value in element.attributes {
    self.size_attribute(name, value)
  }
  if element.children.is_empty() {
    self.charge_bytes(2)
  } else {
    self.charge_bytes(1)
    for child in element.children {
      self.size_node(child, depth=depth + 1)
    }
    self.charge_bytes(2)
    self.charge_mapped_name(element.name)
    self.charge_bytes(1)
  }
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
/// Builds the namespace writer's URI index without doing work ahead of the
/// limited writer's contract. Every binding has a positive structural cost;
/// URI hashing/equality, prefix handling, array materialization, and a
/// conservative worst-case sort bound are charged before serialization. This
/// covers both many aliases of a large URI and large maps of empty URIs.
fn invert_map_limited(
  map : Map[String, String],
  name_work_limit : Int,
) -> (Map[String, String], Int) raise DocxError {
  let inverse : Map[String, String] = Map([])
  let mut remaining = if name_work_limit > 0 { name_work_limit } else { 0 }
  let mut item_count = 0
  let mut max_prefix_chars = 0
  for item in map {
    let (prefix, uri) = item
    // Every binding has positive cost, including an empty prefix and URI.
    // Prefix materialization, inverse-map hashing/equality, and the later
    // namespace array copy are all charged before touching the inverse map.
    if remaining < 4 {
      raise InvalidXml(message="XML serialization name work limit exceeded")
    }
    remaining -= 4
    if prefix.length() > remaining {
      raise InvalidXml(message="XML serialization name work limit exceeded")
    }
    remaining -= prefix.length()
    if uri.length() > remaining {
      raise InvalidXml(message="XML serialization name work limit exceeded")
    }
    remaining -= uri.length()
    if uri.length() > remaining {
      raise InvalidXml(message="XML serialization name work limit exceeded")
    }
    remaining -= uri.length()
    item_count += 1
    max_prefix_chars = max_prefix_chars.max(prefix.length())
    inverse[uri] = prefix
  }
  remaining -= checked_xml_sort_name_work(
    item_count, max_prefix_chars, remaining,
  )
  (inverse, remaining)
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
    // `xmlns` sorts before `xmlns:<prefix>`, and every non-empty name shares
    // the `xmlns:` stem, so comparing prefixes produces the same order
    // without allocating two derived attribute names per comparison.
    prefix_a.compare(prefix_b)
  })
  for item in namespaces {
    let (prefix, uri) = item
    write_serialized_xml_namespace_attribute(builder, prefix, uri)
  }
}

///|
fn write_serialized_xml_namespace_attribute(
  builder : StringBuilder,
  prefix : String,
  uri : String,
) -> Unit {
  builder.write_string(" xmlns")
  if prefix != "" {
    builder.write_string(":")
    builder.write_string(prefix)
  }
  builder.write_string("=\"")
  builder.write_string(escape_xml_attribute(uri))
  builder.write_string("\"")
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
let xml_diagnostic_token_chars : Int = 160

///|
/// Bounds attacker-controlled text before it participates in an error-message
/// concatenation. Short diagnostics remain byte-for-byte unchanged.
fn xml_diagnostic_token(value : String) -> String {
  if value.length() <= xml_diagnostic_token_chars {
    return value
  }
  let output = StringBuilder::new()
  let mut count = 0
  for character in value {
    if count == xml_diagnostic_token_chars - 1 {
      output.write_string("…") |> ignore
      break
    }
    output.write_char(character) |> ignore
    count += 1
  }
  output.to_string()
}

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
  budget : XmlReadBudget?
  source_encoding : XmlSourceEncoding?
  mut seen_xml_declaration : Bool
  namespace_map : Map[String, String]
  namespaces : Map[String, String]
}

///|
/// One reversible namespace declaration. Scope restoration applies these
/// deltas in reverse order, avoiding full-map snapshots and retained-capacity
/// clear/copy cycles for sibling elements.
priv struct NamespaceBindingChange {
  prefix : String
  previous : String?
}

///|
fn XmlParser::parse_element(self : XmlParser) -> XmlElement raise DocxError {
  let max_depth = if self.strict { strict_xml_max_depth } else { xml_max_depth }
  if self.depth >= max_depth {
    raise InvalidXml(message="XML nesting too deep")
  }
  self.charge_token(0)
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
fn XmlParser::charge_token(
  self : XmlParser,
  chars : Int,
) -> Unit raise DocxError {
  match self.budget {
    Some(budget) => budget.charge_token(chars)
    None => ()
  }
}

///|
/// Charges an owned name derived from already-tokenized source (for example,
/// `{namespace-uri}local`). The charge happens before any builder allocation,
/// so repeatedly reusing a long namespace URI cannot amplify a small source
/// into unbounded derived strings.
fn XmlParser::charge_derived_name(
  self : XmlParser,
  chars : Int,
) -> Unit raise DocxError {
  self.charge_token(chars)
}

///|
fn xml_derived_name_length(
  first : Int,
  second : Int,
  punctuation : Int,
) -> Int raise DocxError {
  let total = first.to_int64() + second.to_int64() + punctuation.to_int64()
  if first < 0 || second < 0 || punctuation < 0 || total > 2147483647L {
    raise InvalidXml(message="XML materialized character budget exceeded")
  }
  total.to_int()
}

///|
fn XmlParser::record_namespace_binding(
  self : XmlParser,
  prefix : String,
  namespace_uri : String,
  changes : Array[NamespaceBindingChange],
) -> Unit raise DocxError {
  match self.budget {
    // One delta allocation and one eventual restore/remove operation.
    Some(budget) => budget.charge_namespace_bindings(2)
    None => ()
  }
  changes.push({ prefix, previous: self.namespaces.get(prefix) })
  self.namespaces[prefix] = namespace_uri
}

///|
fn XmlParser::restore_namespace_bindings(
  self : XmlParser,
  changes : Array[NamespaceBindingChange],
) -> Unit {
  for offset in 0..<changes.length() {
    let change = changes[changes.length() - offset - 1]
    match change.previous {
      Some(previous) => self.namespaces[change.prefix] = previous
      None => self.namespaces.remove(change.prefix)
    }
  }
}

///|
fn XmlParser::parse_element_inner_tolerant(
  self : XmlParser,
) -> XmlElement raise DocxError {
  self.expect("<")
  let raw_name = self.read_name()
  let raw_attributes : Array[(String, String)] = []
  let namespace_changes : Array[NamespaceBindingChange] = []
  while true {
    self.skip_whitespace()
    if self.starts_with("/>") {
      self.pos = self.pos + 2
      let element = self.build_element(raw_name, raw_attributes, [])
      self.restore_namespace_bindings(namespace_changes)
      return element
    } else if self.starts_with(">") {
      self.pos = self.pos + 1
      let children = self.parse_children(raw_name)
      let element = self.build_element(raw_name, raw_attributes, children)
      self.restore_namespace_bindings(namespace_changes)
      return element
    } else {
      let attr_name = self.read_name()
      self.skip_whitespace()
      self.expect("=")
      self.skip_whitespace()
      let attr_value = self.read_quoted_value()
      if attr_name == "xmlns" {
        self.record_namespace_binding("", attr_value, namespace_changes)
      } else if attr_name.has_prefix("xmlns:") {
        self.charge_derived_name(attr_name.length() - 6)
        let prefix = attr_name[6:].to_owned()
        self.record_namespace_binding(prefix, attr_value, namespace_changes)
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
    raise InvalidXml(
      message="invalid XML qualified name: " + xml_diagnostic_token(raw_name),
    )
  }
  let raw_attributes : Array[(String, String)] = []
  let raw_attribute_names : Map[String, Bool] = Map([])
  let namespace_changes : Array[NamespaceBindingChange] = []
  while true {
    let separated = self.skip_whitespace_and_report()
    if self.starts_with("/>") {
      self.pos = self.pos + 2
      let element = self.build_element(raw_name, raw_attributes, [])
      self.restore_namespace_bindings(namespace_changes)
      return element
    } else if self.starts_with(">") {
      self.pos = self.pos + 1
      let children = self.parse_children(raw_name)
      let element = self.build_element(raw_name, raw_attributes, children)
      self.restore_namespace_bindings(namespace_changes)
      return element
    } else {
      if !separated {
        raise InvalidXml(message="attributes must be separated by whitespace")
      }
      let attr_name = self.read_name()
      if !is_xml_qname(attr_name) {
        raise InvalidXml(
          message="invalid XML qualified name: " +
            xml_diagnostic_token(attr_name),
        )
      }
      if raw_attribute_names.contains(attr_name) {
        raise InvalidXml(
          message="duplicate XML attribute: " + xml_diagnostic_token(attr_name),
        )
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
        self.record_namespace_binding("", namespace_uri, namespace_changes)
      } else if attr_name.has_prefix("xmlns:") {
        self.charge_derived_name(attr_name.length() - 6)
        let prefix = attr_name[6:].to_owned()
        let namespace_uri = decode_xml_entities_strict(
          attr_value,
          attribute=true,
        )
        validate_namespace_declaration(prefix, namespace_uri)
        self.record_namespace_binding(prefix, namespace_uri, namespace_changes)
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
        raise InvalidXml(
          message="invalid XML qualified name: " +
            xml_diagnostic_token(close_name),
        )
      }
      if close_name != raw_name {
        raise InvalidXml(
          message="mismatched closing tag: expected " +
            xml_diagnostic_token(raw_name) +
            " got " +
            xml_diagnostic_token(close_name),
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
  raise InvalidXml(message="unclosed tag: " + xml_diagnostic_token(raw_name))
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
          message="duplicate expanded XML attribute: " +
            xml_diagnostic_token(expanded),
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
      self.charge_derived_name(index)
      let prefix = raw_name[:index].to_owned()
      let local_name = raw_name[index + 1:]
      match self.namespaces.get(prefix) {
        Some(uri) => self.map_uri_name(uri, local_name)
        None =>
          if self.strict {
            raise InvalidXml(
              message="unbound XML namespace prefix: " +
                xml_diagnostic_token(prefix),
            )
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
      self.charge_derived_name(index)
      let prefix = raw_name[:index].to_owned()
      let local_name = raw_name[index + 1:]
      match self.namespaces.get(prefix) {
        Some(uri) => self.materialize_braced_name(uri, local_name)
        None =>
          raise InvalidXml(
            message="unbound XML namespace prefix: " +
              xml_diagnostic_token(prefix),
          )
      }
    }
    None =>
      if is_attribute {
        raw_name
      } else {
        match self.namespaces.get("") {
          Some(uri) if uri != "" => self.materialize_braced_name(uri, raw_name)
          _ => raw_name
        }
      }
  }
}

///|
fn XmlParser::materialize_braced_name(
  self : XmlParser,
  uri : String,
  local_name : StringView,
) -> String raise DocxError {
  let chars = xml_derived_name_length(uri.length(), local_name.length(), 2)
  self.charge_derived_name(chars)
  let builder = StringBuilder()
  builder.write_char('{')
  builder.write_string(uri)
  builder.write_char('}')
  builder.write_view(local_name)
  builder.to_string()
}

///|
fn XmlParser::materialize_prefixed_name(
  self : XmlParser,
  prefix : String,
  local_name : StringView,
) -> String raise DocxError {
  let chars = xml_derived_name_length(prefix.length(), local_name.length(), 1)
  self.charge_derived_name(chars)
  let builder = StringBuilder()
  builder.write_string(prefix)
  builder.write_char(':')
  builder.write_view(local_name)
  builder.to_string()
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
  local_name : StringView,
) -> String raise DocxError {
  // Map lookup hashes the complete namespace URI. Charge that reused input
  // before hashing so a single long declaration referenced by many short
  // names cannot hide repeated O(uri.length) work behind tiny source tokens.
  self.charge_derived_name(uri.length())
  match self.namespace_map.get(uri) {
    Some(prefix) =>
      if prefix == "" {
        self.materialize_braced_name(uri, local_name)
      } else {
        self.materialize_prefixed_name(prefix, local_name)
      }
    None => self.materialize_braced_name(uri, local_name)
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
      // Byte-backed parses know the encoding that produced `source`, so even
      // tolerant conversion must inspect an XML declaration instead of
      // treating a contradictory declaration as an arbitrary processing
      // instruction. String-only tolerant parsing keeps its historical
      // xmldom-compatible recovery behavior because no source encoding is
      // available to verify.
      if self.strict || self.source_encoding is Some(_) {
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
fn XmlSourceEncoding::matches_declaration(
  self : XmlSourceEncoding,
  value : String,
) -> Bool {
  let normalized = value.to_lower()
  match self {
    Utf8 => normalized == "utf-8"
    Utf16LittleEndian => normalized == "utf-16" || normalized == "utf-16le"
    Utf16BigEndian => normalized == "utf-16" || normalized == "utf-16be"
  }
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
      raise InvalidXml(
        message="invalid XML declaration attribute: " +
          xml_diagnostic_token(name),
      )
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
          raise InvalidXml(
            message="unsupported XML version: " + xml_diagnostic_token(value),
          )
        }
        has_version = true
      }
      (1, "encoding") =>
        if !is_valid_xml_encoding_name(value) {
          raise InvalidXml(
            message="invalid XML encoding name: " + xml_diagnostic_token(value),
          )
        } else {
          match self.source_encoding {
            Some(encoding) if !encoding.matches_declaration(value) =>
              raise InvalidXml(
                message="XML encoding declaration does not match decoded source",
              )
            _ => ()
          }
        }
      (1, "standalone") | (2, "standalone") =>
        if value != "yes" && value != "no" {
          raise InvalidXml(
            message="invalid XML standalone value: " +
              xml_diagnostic_token(value),
          )
        }
      _ =>
        raise InvalidXml(
          message="misordered XML declaration attribute: " +
            xml_diagnostic_token(name),
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
    self.charge_token(self.pos - start)
    return xml_substring(self.source, start, self.pos)
  }
  while self.pos < self.source.length() {
    let char = match self.source.get_char(self.pos) {
      Some(char) => char
      None => raise InvalidXml(message="invalid UTF-16 in XML content")
    }
    // The compatibility parser remains permissive about the first character
    // (for example, it historically accepted digit-start names), but valid
    // Unicode XML names must not be truncated to their ASCII prefix.
    if !is_xml_name_char(char) {
      break
    }
    self.pos += char.utf16_len()
  }
  if self.pos == start {
    raise InvalidXml(message="expected XML name")
  }
  self.charge_token(self.pos - start)
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
  self.charge_token(self.pos - start)
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
  self.charge_token(self.pos - start)
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
      self.charge_token(self.pos - start)
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
  while self.pos + needle.length() <= self.source.length() {
    if self.starts_with(needle) {
      self.pos += needle.length()
      return
    }
    self.pos += 1
  }
  raise InvalidXml(message="expected `" + needle + "`")
}

///|
fn decode_xml_entities(value : String) -> String raise DocxError {
  let builder = StringBuilder()
  let mut index = 0
  let mut no_remaining_semicolon = false
  while index < value.length() {
    if value[index] == '&' {
      if no_remaining_semicolon {
        builder.write_char('&')
        index += 1
      } else {
        let mut entity_end = index + 1
        while entity_end < value.length() && value[entity_end] != ';' {
          entity_end += 1
        }
        if entity_end < value.length() {
          let entity = xml_substring(value, index + 1, entity_end)
          builder.write_string(decode_xml_entity(entity))
          index = entity_end + 1
        } else {
          // Cache the failed suffix scan. Without this, tolerant parsing of a
          // long run of unterminated ampersands rescans the complete suffix
          // once per ampersand.
          no_remaining_semicolon = true
          builder.write_char('&')
          index += 1
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
    raise InvalidXml(
      message="undeclared XML entity: &" + xml_diagnostic_token(entity) + ";",
    )
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
