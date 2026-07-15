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
  attributes : @sorted_map.SortedMap[String, String]
  children : Array[XmlNode]
} derive(Debug, Eq)

///|
/// Builds an XML element.
pub fn xml_element(
  name : String,
  attributes? : Map[String, String] = Map([]),
  children? : Array[XmlNode] = [],
) -> XmlElement {
  { name, attributes: SortedMap(attributes.to_array()), children }
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
  read_xml_string_with_mode(
    source,
    namespace_map,
    false,
    None,
    false,
    None,
    false,
  )
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
  read_xml_string_with_mode(
    source,
    namespace_map,
    true,
    None,
    false,
    None,
    false,
  )
}

///|
/// The byte encoding used to decode an XML source string. Passing it to
/// `read_xml_string_strict_encoded` makes the XML declaration part of the
/// strict contract instead of treating it as unaudited metadata. BOMless
/// UTF-16LE and UTF-16BE sources require a matching declaration.
pub(all) enum XmlSourceEncoding {
  Utf8
  Utf16LittleEndianWithBom
  Utf16BigEndianWithBom
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
    false,
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
    raise @core.docx_xml_resource_limit_error(DocxXmlSourceUnits)
  }
  self.remaining_source_units -= units
}

///|
fn XmlReadBudget::charge_token(
  self : XmlReadBudget,
  chars : Int,
) -> Unit raise DocxError {
  if chars < 0 || chars > self.max_token_chars {
    raise @core.docx_xml_resource_limit_error(DocxXmlTokenLength)
  }
  if self.remaining_tokens <= 0 {
    raise @core.docx_xml_resource_limit_error(DocxXmlTokens)
  }
  if chars > self.remaining_materialized_chars {
    raise @core.docx_xml_resource_limit_error(DocxXmlMaterializedCharacters)
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
    raise @core.docx_xml_resource_limit_error(DocxXmlMaterializedCharacters)
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
    raise @core.docx_xml_resource_limit_error(DocxXmlTokens)
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
    false,
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
    false,
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
    false,
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
    false,
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
  retain_namespace_declarations : Bool,
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
    retain_namespace_declarations,
    seen_xml_declaration: false,
    namespace_map: build_direct_namespace_lookup(namespace_map),
    namespaces: if strict {
      SortedMap([("xml", XML_NAMESPACE_URI)])
    } else {
      SortedMap([])
    },
  }
  parser.skip_misc(document_start=true)
  match source_encoding {
    Some(encoding) if encoding.requires_declaration() &&
      !parser.seen_xml_declaration =>
      raise InvalidXml(
        message="XML encoding declaration is required for decoded source",
      )
    _ => ()
  }
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
  let writer = XmlWriter::{
    namespaces,
    namespace_lookup: build_namespace_lookup(namespaces),
  }
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
  let writer = XmlWriter::{
    namespaces,
    namespace_lookup: build_namespace_lookup(namespaces),
  }
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
  let (namespace_lookup, remaining_name_work) = build_namespace_lookup_limited(
    namespaces, name_work_limit,
  )
  let sizer = XmlWriteSizer::{
    namespaces,
    namespace_lookup,
    remaining_bytes: limit,
    remaining_name_work,
  }
  sizer.size_element(element, is_root=true, depth=0)
  let output_bytes = limit - sizer.remaining_bytes
  let writer = XmlWriter::{ namespaces, namespace_lookup }
  let builder = StringBuilder(size_hint=output_bytes)
  writer.write_element(builder, element, is_root=true)
  builder.to_string()
}

///|
priv struct XmlWriter {
  namespaces : Map[String, String]
  namespace_lookup : NamespaceLookup
}

///|
/// The strict parser and limited writer share the same conservative recursive
/// depth ceiling, keeping their stack use portable on Wasm as well as native.
let xml_write_max_depth : Int = 256

///|
/// Namespace mapping may inspect a Clark name several times (delimiter scan and
/// comparison-based lookup in both sizing and writing). Keep that work a fixed
/// multiple of the caller's output ceiling so a reused giant URI cannot turn a
/// small permitted fragment into excessive serialization work. The multiplier
/// comfortably covers the standard OOXML namespace-to-tag ratio while rejecting
/// hostile amplification.
let xml_write_name_work_scale : Int = 64

///|
/// `Array::sort_by` is worst-case O(n log n). This conservative multiplier
/// covers pivot selection, its small-array bubble-sort path, heap-sort
/// fallback, and the fixed work around every string comparison.
let xml_write_sort_work_scale : Int = 8

///|
/// Binary lookup is performed once by the sizing pass and once by the writer.
/// This multiplier also covers loop/index overhead around every comparison.
let xml_write_lookup_work_scale : Int = 4

///|
/// A collision-independent URI-to-prefix index. Entries are sorted by URI and
/// contain at most one prefix for each URI, preserving the historical rule that
/// the last namespace binding wins when aliases share a URI.
priv struct NamespaceLookup {
  entries : Array[(String, String)]
  max_uri_chars : Int
}

///|
priv struct XmlWriteSizer {
  namespaces : Map[String, String]
  namespace_lookup : NamespaceLookup
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
fn checked_xml_lookup_name_work(
  item_count : Int,
  max_name_chars : Int,
  remaining : Int,
) -> Int raise DocxError {
  if item_count <= 0 {
    return 0
  }
  let mut levels = 0
  let mut value = item_count
  while value > 0 {
    levels += 1
    value /= 2
  }
  let mut work = xml_write_lookup_work_scale
  if levels > remaining / work {
    raise InvalidXml(message="XML serialization name work limit exceeded")
  }
  work *= levels
  if max_name_chars >= remaining / work {
    raise InvalidXml(message="XML serialization name work limit exceeded")
  }
  work *= max_name_chars + 1
  work
}

///|
fn XmlWriteSizer::charge_attribute_sort_work(
  self : XmlWriteSizer,
  attributes : @sorted_map.SortedMap[String, String],
) -> Unit raise DocxError {
  let mut item_count = 0
  let mut max_name_chars = 0
  for name, _ in attributes {
    // Charge the array materialization and one unit of container traversal before
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
  // The comparison-based lookup has a deterministic logarithmic ceiling. The
  // charge covers this lookup and the identical unmetered writer pass below.
  self.charge_name_work(
    checked_xml_lookup_name_work(
      self.namespace_lookup.entries.length(),
      self.namespace_lookup.max_uri_chars.max(uri.length()),
      self.remaining_name_work,
    ),
  )
  match self.namespace_lookup.lookup(uri) {
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
fn NamespaceLookup::lookup(self : NamespaceLookup, uri : StringView) -> String? {
  let mut low = 0
  let mut high = self.entries.length()
  while low < high {
    let middle = low + (high - low) / 2
    let (candidate, prefix) = self.entries[middle]
    let ordering = uri.compare(candidate)
    if ordering == 0 {
      return Some(prefix)
    } else if ordering < 0 {
      high = middle
    } else {
      low = middle + 1
    }
  }
  None
}

///|
fn build_namespace_lookup(map : Map[String, String]) -> NamespaceLookup {
  let indexed : Array[(String, String, Int)] = []
  let mut ordinal = 0
  let mut max_uri_chars = 0
  for prefix, uri in map {
    indexed.push((uri, prefix, ordinal))
    ordinal += 1
    max_uri_chars = max_uri_chars.max(uri.length())
  }
  finish_namespace_lookup(indexed, max_uri_chars)
}

///|
/// Parser namespace maps are already URI-to-prefix mappings, unlike writer
/// namespace declarations, which are prefix-to-URI and require inversion.
fn build_direct_namespace_lookup(map : Map[String, String]) -> NamespaceLookup {
  let indexed : Array[(String, String, Int)] = []
  let mut ordinal = 0
  let mut max_uri_chars = 0
  for uri, prefix in map {
    indexed.push((uri, prefix, ordinal))
    ordinal += 1
    max_uri_chars = max_uri_chars.max(uri.length())
  }
  finish_namespace_lookup(indexed, max_uri_chars)
}

///|
fn finish_namespace_lookup(
  indexed : Array[(String, String, Int)],
  max_uri_chars : Int,
) -> NamespaceLookup {
  indexed.sort_by(fn(a, b) {
    let (uri_a, _, ordinal_a) = a
    let (uri_b, _, ordinal_b) = b
    let ordering = uri_a.compare(uri_b)
    if ordering != 0 {
      ordering
    } else {
      ordinal_a.compare(ordinal_b)
    }
  })
  let entries : Array[(String, String)] = []
  let mut previous_uri : String? = None
  for item in indexed {
    let (uri, prefix, _) = item
    match previous_uri {
      Some(previous) if previous == uri =>
        entries[entries.length() - 1] = (uri, prefix)
      _ => entries.push((uri, prefix))
    }
    previous_uri = Some(uri)
  }
  { entries, max_uri_chars }
}

///|
/// Builds the namespace writer's collision-independent URI index without doing
/// work ahead of the limited writer's contract. Every binding has a positive
/// structural cost; prefix/URI handling, array materialization, and both URI
/// and output-prefix sorts are charged before serialization.
fn build_namespace_lookup_limited(
  map : Map[String, String],
  name_work_limit : Int,
) -> (NamespaceLookup, Int) raise DocxError {
  let indexed : Array[(String, String, Int)] = []
  let mut remaining = if name_work_limit > 0 { name_work_limit } else { 0 }
  let mut item_count = 0
  let mut max_prefix_chars = 0
  let mut max_uri_chars = 0
  for prefix, uri in map {
    // Every binding has positive cost, including an empty prefix and URI.
    // Prefix/URI materialization and the later namespace array copies are all
    // charged before sorting or indexing the bindings.
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
    max_uri_chars = max_uri_chars.max(uri.length())
    indexed.push((uri, prefix, item_count - 1))
  }
  remaining -= checked_xml_sort_name_work(item_count, max_uri_chars, remaining)
  remaining -= checked_xml_sort_name_work(
    item_count, max_prefix_chars, remaining,
  )
  (finish_namespace_lookup(indexed, max_uri_chars), remaining)
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
        let uri = name[1:close]
        let local_name = name[close + 1:].to_owned()
        match self.namespace_lookup.lookup(uri) {
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
  attributes : @sorted_map.SortedMap[String, String],
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
/// Maximum element nesting depth accepted by the tolerant XML parser. Keep it
/// aligned with strict parsing and serialization so every recursive XML path
/// reaches its typed guard before exhausting the Wasm stack.
let xml_max_depth : Int = 256

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
/// Pre-sizes the native/Wasm UTF-16 builder exactly when the byte-sized hint
/// fits in `Int`. Exact sizing lets `to_string()` transfer the completed buffer
/// without retaining a second token-sized allocation.
fn xml_string_builder_for_units(units : Int) -> StringBuilder {
  let bytes = units.to_int64() * 2L
  if units > 0 && bytes <= 2147483647L {
    StringBuilder(size_hint=bytes.to_int())
  } else {
    StringBuilder()
  }
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
  retain_namespace_declarations : Bool
  mut seen_xml_declaration : Bool
  namespace_map : NamespaceLookup
  namespaces : @sorted_map.SortedMap[String, String]
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
    raise @core.docx_xml_resource_limit_error(DocxXmlNestingDepth)
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
    raise @core.docx_xml_resource_limit_error(DocxXmlMaterializedCharacters)
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
      let element = self.build_element(raw_name, raw_attributes, [], [])
      self.restore_namespace_bindings(namespace_changes)
      return element
    } else if self.starts_with(">") {
      self.pos = self.pos + 1
      let children = self.parse_children(raw_name)
      let element = self.build_element(raw_name, raw_attributes, children, [])
      self.restore_namespace_bindings(namespace_changes)
      return element
    } else {
      let attr_name = self.read_name()
      self.skip_whitespace()
      self.expect("=")
      self.skip_whitespace()
      let attr_value = self.read_quoted_value_tolerant_decoded()
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
  let raw_attribute_names : @sorted_map.SortedMap[String, Bool] = SortedMap([])
  let namespace_changes : Array[NamespaceBindingChange] = []
  let namespace_declarations : Array[(String, String)] = []
  while true {
    let separated = self.skip_whitespace_and_report()
    if self.starts_with("/>") {
      self.pos = self.pos + 2
      let element = self.build_element(
        raw_name,
        raw_attributes,
        [],
        namespace_declarations,
      )
      self.restore_namespace_bindings(namespace_changes)
      return element
    } else if self.starts_with(">") {
      self.pos = self.pos + 1
      let children = self.parse_children(raw_name)
      let element = self.build_element(
        raw_name, raw_attributes, children, namespace_declarations,
      )
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
      let attr_value = self.read_quoted_value_strict_decoded()
      if attr_name == "xmlns" {
        validate_namespace_declaration("", attr_value)
        self.record_namespace_binding("", attr_value, namespace_changes)
        if self.retain_namespace_declarations {
          namespace_declarations.push(("", attr_value))
        }
      } else if attr_name.has_prefix("xmlns:") {
        self.charge_derived_name(attr_name.length() - 6)
        let prefix = attr_name[6:].to_owned()
        validate_namespace_declaration(prefix, attr_value)
        self.record_namespace_binding(prefix, attr_value, namespace_changes)
        if self.retain_namespace_declarations {
          namespace_declarations.push((prefix, attr_value))
        }
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
      let cdata = if self.strict {
        self.read_until_strict_normalized("]]>")
      } else {
        self.read_until("]]>")
      }
      children.push(XmlText(cdata))
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
      let text = if self.strict {
        self.read_text_strict_decoded()
      } else {
        self.read_text_tolerant_decoded()
      }
      if text != "" {
        children.push(XmlText(text))
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
  namespace_declarations : Array[(String, String)],
) -> XmlElement raise DocxError {
  let attributes : @sorted_map.SortedMap[String, String] = SortedMap([])
  let expanded_attributes : @sorted_map.SortedMap[String, Bool] = SortedMap([])
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
    attributes[self.map_name(name, is_attribute=true)] = value
  }
  for declaration in namespace_declarations {
    let (prefix, namespace_uri) = declaration
    let local_name = if prefix == "" { "xmlns" } else { prefix }
    attributes[self.materialize_braced_name(XMLNS_NAMESPACE_URI, local_name)] = namespace_uri
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
  match self.namespace_map.lookup(uri) {
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
    Utf16LittleEndianWithBom | Utf16BigEndianWithBom => normalized == "utf-16"
    Utf16LittleEndian => normalized == "utf-16le"
    Utf16BigEndian => normalized == "utf-16be"
  }
}

///|
fn XmlSourceEncoding::requires_declaration(self : XmlSourceEncoding) -> Bool {
  match self {
    Utf16LittleEndian | Utf16BigEndian => true
    Utf8 | Utf16LittleEndianWithBom | Utf16BigEndianWithBom => false
  }
}

///|
fn XmlParser::parse_xml_declaration(self : XmlParser) -> Unit raise DocxError {
  let names : @sorted_map.SortedMap[String, Bool] = SortedMap([])
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
  let builder = xml_string_builder_for_units(end - start)
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
/// Reads one tolerant element attribute directly into its retained,
/// entity-decoded value. Keeping the parser source borrowed avoids retaining a
/// raw token, an entity substring, and growable decoder buffers concurrently.
fn XmlParser::read_quoted_value_tolerant_decoded(
  self : XmlParser,
) -> String raise DocxError {
  if self.pos >= self.source.length() {
    raise InvalidXml(message="expected quoted attribute value")
  }
  let quote = self.source[self.pos]
  if quote != '"' && quote != '\'' {
    raise InvalidXml(message="expected quoted attribute value")
  }
  self.pos += 1
  let start = self.pos
  while self.pos < self.source.length() && self.source[self.pos] != quote {
    self.pos += 1
  }
  if self.pos >= self.source.length() {
    raise InvalidXml(message="unterminated attribute value")
  }
  self.charge_token(self.pos - start)
  let value = decode_tolerant_xml_range(self.source, start, self.pos)
  self.pos += 1
  value
}

///|
/// Reads one strict element attribute directly into its retained normalized,
/// entity-decoded value. The parser source remains borrowed throughout; no raw
/// or separately normalized token-sized strings are materialized.
fn XmlParser::read_quoted_value_strict_decoded(
  self : XmlParser,
) -> String raise DocxError {
  if self.pos >= self.source.length() {
    raise InvalidXml(message="expected quoted attribute value")
  }
  let quote = self.source[self.pos]
  if quote != '"' && quote != '\'' {
    raise InvalidXml(message="expected quoted attribute value")
  }
  self.pos += 1
  let start = self.pos
  while self.pos < self.source.length() && self.source[self.pos] != quote {
    if self.source[self.pos] == '<' {
      raise InvalidXml(message="raw '<' is not allowed in an attribute value")
    }
    self.pos += 1
  }
  if self.pos >= self.source.length() {
    raise InvalidXml(message="unterminated attribute value")
  }
  self.charge_token(self.pos - start)
  let value = decode_strict_xml_range(
    self.source,
    start,
    self.pos,
    attribute=true,
    entities=true,
  )
  self.pos += 1
  value
}

///|
/// Reads tolerant character data into one retained decoded string. Entity
/// decoding is fused over the borrowed parser source just as it is for
/// tolerant attributes.
fn XmlParser::read_text_tolerant_decoded(
  self : XmlParser,
) -> String raise DocxError {
  let start = self.pos
  while self.pos < self.source.length() && self.source[self.pos] != '<' {
    self.pos += 1
  }
  self.charge_token(self.pos - start)
  decode_tolerant_xml_range(self.source, start, self.pos)
}

///|
/// Reads strict character data into one retained decoded string, fusing XML
/// line-ending normalization and entity replacement over the borrowed source.
fn XmlParser::read_text_strict_decoded(
  self : XmlParser,
) -> String raise DocxError {
  let start = self.pos
  while self.pos < self.source.length() && self.source[self.pos] != '<' {
    if self.starts_with("]]>") {
      raise InvalidXml(message="']]>' is not allowed in XML character data")
    }
    self.pos += 1
  }
  self.charge_token(self.pos - start)
  decode_strict_xml_range(
    self.source,
    start,
    self.pos,
    attribute=false,
    entities=true,
  )
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
/// Reads strict CDATA content while normalizing literal line endings directly
/// from the borrowed source. Entity-looking text remains literal in CDATA.
fn XmlParser::read_until_strict_normalized(
  self : XmlParser,
  needle : String,
) -> String raise DocxError {
  let start = self.pos
  while self.pos + needle.length() <= self.source.length() {
    if self.starts_with(needle) {
      self.charge_token(self.pos - start)
      return decode_strict_xml_range(
        self.source,
        start,
        self.pos,
        attribute=false,
        entities=false,
      )
    }
    self.pos += 1
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
fn xml_source_range_equals(
  source : String,
  start : Int,
  end : Int,
  expected : String,
) -> Bool {
  if end - start != expected.length() {
    return false
  }
  for offset in 0..<expected.length() {
    if source[start + offset] != expected[offset] {
      return false
    }
  }
  true
}

///|
/// Decodes one tolerant entity from a borrowed source range. Unknown or
/// malformed references return `None` and are retained verbatim by the caller.
fn tolerant_xml_entity_char(source : String, start : Int, end : Int) -> Char? {
  if xml_source_range_equals(source, start, end, "amp") {
    return Some('&')
  }
  if xml_source_range_equals(source, start, end, "lt") {
    return Some('<')
  }
  if xml_source_range_equals(source, start, end, "gt") {
    return Some('>')
  }
  if xml_source_range_equals(source, start, end, "quot") {
    return Some('"')
  }
  if xml_source_range_equals(source, start, end, "apos") {
    return Some('\'')
  }
  if end - start < 2 || source[start] != '#' {
    return None
  }
  let text_start = start + 1
  let mut first_lower_x = -1
  for index in text_start..<end {
    let char = source[index]
    if !((char >= '0' && char <= '9') ||
      (char >= 'A' && char <= 'Z') ||
      (char >= 'a' && char <= 'z') ||
      char == '_') {
      return None
    }
    if first_lower_x < 0 && char == 'x' {
      first_lower_x = index
    }
  }
  match parse_xmldom_numeric_xml_range(source, text_start, end, first_lower_x) {
    None => Some('\u{0}')
    Some(codepoint) => codepoint.to_char()
  }
}

///|
/// Returns one code unit from xmldom's historical transformed numeric token:
/// the first lowercase `x` is replaced with `0x`. The virtual view preserves
/// those compatibility semantics without allocating the transformed suffix.
fn xmldom_numeric_virtual_unit(
  source : String,
  text_start : Int,
  first_lower_x : Int,
  virtual_index : Int,
) -> UInt16 {
  if first_lower_x < 0 {
    return source[text_start + virtual_index]
  }
  let prefix_length = first_lower_x - text_start
  if virtual_index < prefix_length {
    source[text_start + virtual_index]
  } else if virtual_index == prefix_length {
    '0'
  } else if virtual_index == prefix_length + 1 {
    'x'
  } else {
    source[text_start + virtual_index - 1]
  }
}

///|
/// Allocation-free equivalent of xmldom's `parseInt(text.replace('x','0x'))`.
/// `None` means no leading digit (decoded historically as NUL); the sentinel
/// U+110000 distinguishes overflow so the caller preserves the entity raw.
fn parse_xmldom_numeric_xml_range(
  source : String,
  text_start : Int,
  text_end : Int,
  first_lower_x : Int,
) -> Int? {
  let virtual_length = text_end -
    text_start +
    (if first_lower_x >= 0 { 1 } else { 0 })
  let mut index = 0
  let mut radix = 10
  if virtual_length >= 2 &&
    xmldom_numeric_virtual_unit(source, text_start, first_lower_x, 0) == '0' &&
    (
      xmldom_numeric_virtual_unit(source, text_start, first_lower_x, 1) == 'x' ||
      xmldom_numeric_virtual_unit(source, text_start, first_lower_x, 1) == 'X'
    ) {
    radix = 16
    index = 2
  }
  let mut value = 0
  let mut saw_digit = false
  while index < virtual_length {
    let char = xmldom_numeric_virtual_unit(
      source, text_start, first_lower_x, index,
    )
    match xml_entity_digit_value(char, radix) {
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
/// Computes the exact retained size of a tolerant token without allocating an
/// entity substring. A failed semicolon search is cached so unterminated runs
/// remain linear.
fn tolerant_xml_decoded_shape(
  source : String,
  start : Int,
  end : Int,
) -> (Int, Bool) raise DocxError {
  let mut index = start
  let mut output_units = 0
  let mut changed = false
  let mut no_remaining_semicolon = false
  while index < end {
    if source[index] == '&' && !no_remaining_semicolon {
      let mut entity_end = index + 1
      while entity_end < end && source[entity_end] != ';' {
        entity_end += 1
      }
      if entity_end < end {
        match tolerant_xml_entity_char(source, index + 1, entity_end) {
          Some(char) => {
            output_units += char.utf16_len()
            changed = true
          }
          None => output_units += entity_end - index + 1
        }
        index = entity_end + 1
        continue
      }
      no_remaining_semicolon = true
    }
    let char = match source.get_char(index) {
      Some(char) => char
      None => raise InvalidXml(message="invalid UTF-16 in XML content")
    }
    output_units += char.utf16_len()
    index += char.utf16_len()
  }
  (output_units, changed)
}

///|
fn write_xml_source_range(
  output : StringBuilder,
  source : String,
  start : Int,
  end : Int,
) -> Unit raise DocxError {
  let mut index = start
  while index < end {
    let char = match source.get_char(index) {
      Some(char) => char
      None => raise InvalidXml(message="invalid UTF-16 in XML content")
    }
    output.write_char(char)
    index += char.utf16_len()
  }
}

///|
fn write_tolerant_xml_decoded_range(
  output : StringBuilder,
  source : String,
  start : Int,
  end : Int,
) -> Unit raise DocxError {
  let mut index = start
  let mut no_remaining_semicolon = false
  while index < end {
    if source[index] == '&' && !no_remaining_semicolon {
      let mut entity_end = index + 1
      while entity_end < end && source[entity_end] != ';' {
        entity_end += 1
      }
      if entity_end < end {
        match tolerant_xml_entity_char(source, index + 1, entity_end) {
          Some(char) => output.write_char(char)
          None => write_xml_source_range(output, source, index, entity_end + 1)
        }
        index = entity_end + 1
        continue
      }
      no_remaining_semicolon = true
    }
    let char = match source.get_char(index) {
      Some(char) => char
      None => raise InvalidXml(message="invalid UTF-16 in XML content")
    }
    output.write_char(char)
    index += char.utf16_len()
  }
}

///|
/// Fuses tolerant entity decoding over a borrowed parser range. The unchanged
/// fast path makes one exact copy; transformed tokens use a size pass and one
/// exactly-sized output allocation.
fn decode_tolerant_xml_range(
  source : String,
  start : Int,
  end : Int,
) -> String raise DocxError {
  let (output_units, changed) = tolerant_xml_decoded_shape(source, start, end)
  if output_units == 0 {
    return ""
  }
  if !changed {
    return xml_substring(source, start, end)
  }
  let output = xml_string_builder_for_units(output_units)
  write_tolerant_xml_decoded_range(output, source, start, end)
  output.to_string()
}

///|
/// Bounds a source range before it participates in an error message without
/// first copying an attacker-sized entity token.
fn xml_diagnostic_range(
  source : String,
  start : Int,
  end : Int,
) -> String raise DocxError {
  if end - start <= xml_diagnostic_token_chars {
    return xml_substring(source, start, end)
  }
  let output = xml_string_builder_for_units(xml_diagnostic_token_chars)
  let mut index = start
  let mut count = 0
  while index < end && count < xml_diagnostic_token_chars - 1 {
    let char = match source.get_char(index) {
      Some(char) => char
      None => raise InvalidXml(message="invalid UTF-16 in XML content")
    }
    output.write_char(char)
    index += char.utf16_len()
    count += 1
  }
  if index < end {
    output.write_string("…")
  }
  output.to_string()
}

///|
/// Decodes one strict entity directly from the parser's borrowed source range.
/// No entity-sized substring is allocated, including on error paths.
fn strict_xml_entity_char(
  source : String,
  start : Int,
  end : Int,
) -> Char raise DocxError {
  if xml_source_range_equals(source, start, end, "amp") {
    return '&'
  }
  if xml_source_range_equals(source, start, end, "lt") {
    return '<'
  }
  if xml_source_range_equals(source, start, end, "gt") {
    return '>'
  }
  if xml_source_range_equals(source, start, end, "quot") {
    return '"'
  }
  if xml_source_range_equals(source, start, end, "apos") {
    return '\''
  }
  if start >= end || source[start] != '#' {
    raise InvalidXml(
      message="undeclared XML entity: &" +
        xml_diagnostic_range(source, start, end) +
        ";",
    )
  }
  let (base, digits_start) = if start + 1 < end && source[start + 1] == 'x' {
    (16, start + 2)
  } else {
    (10, start + 1)
  }
  if digits_start >= end {
    raise InvalidXml(message="malformed numeric XML entity")
  }
  let mut codepoint = 0
  for index in digits_start..<end {
    let char = source[index]
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
  match Int::to_char(codepoint) {
    Some(char) if is_xml_character(char) => char
    _ => raise InvalidXml(message="numeric XML entity is not an XML character")
  }
}

///|
/// First pass over a borrowed strict token: validates every entity and computes
/// the exact UTF-16 output size without allocating raw or normalized copies.
fn strict_xml_decoded_shape(
  source : String,
  start : Int,
  end : Int,
  attribute~ : Bool,
  entities~ : Bool,
) -> (Int, Bool) raise DocxError {
  let mut index = start
  let mut output_units = 0
  let mut changed = false
  while index < end {
    if entities && source[index] == '&' {
      let mut entity_end = index + 1
      while entity_end < end && source[entity_end] != ';' {
        entity_end += 1
      }
      if entity_end >= end {
        raise InvalidXml(message="unterminated XML entity")
      }
      output_units += strict_xml_entity_char(source, index + 1, entity_end).utf16_len()
      changed = true
      index = entity_end + 1
    } else {
      let char = match source.get_char(index) {
        Some(char) => char
        None => raise InvalidXml(message="invalid UTF-16 in XML content")
      }
      let next = index + char.utf16_len()
      if char == '\r' {
        changed = true
        output_units += 1
        index = if next < end && source[next] == '\n' { next + 1 } else { next }
      } else if attribute && (char == '\t' || char == '\n') {
        changed = true
        output_units += 1
        index = next
      } else {
        output_units += char.utf16_len()
        index = next
      }
    }
  }
  (output_units, changed)
}

///|
/// Second pass writes directly from the borrowed source into one exactly-sized
/// result buffer. Character references are decoded before literal line-ending
/// normalization, preserving values such as `&#xD;` as required by XML 1.0.
fn write_strict_xml_decoded_range(
  output : StringBuilder,
  source : String,
  start : Int,
  end : Int,
  attribute~ : Bool,
  entities~ : Bool,
) -> Unit raise DocxError {
  let mut index = start
  while index < end {
    if entities && source[index] == '&' {
      let mut entity_end = index + 1
      while entity_end < end && source[entity_end] != ';' {
        entity_end += 1
      }
      output.write_char(strict_xml_entity_char(source, index + 1, entity_end))
      index = entity_end + 1
    } else {
      let char = match source.get_char(index) {
        Some(char) => char
        None => raise InvalidXml(message="invalid UTF-16 in XML content")
      }
      let next = index + char.utf16_len()
      if char == '\r' {
        output.write_char(if attribute { ' ' } else { '\n' })
        index = if next < end && source[next] == '\n' { next + 1 } else { next }
      } else if attribute && (char == '\t' || char == '\n') {
        output.write_char(' ')
        index = next
      } else {
        output.write_char(char)
        index = next
      }
    }
  }
}

///|
/// Fuses strict source normalization and entity decoding over a borrowed range.
/// The unchanged fast path makes one exact copy; transformed tokens use a
/// validation/size pass followed by one exactly-sized output allocation.
fn decode_strict_xml_range(
  source : String,
  start : Int,
  end : Int,
  attribute~ : Bool,
  entities~ : Bool,
) -> String raise DocxError {
  let (output_units, changed) = strict_xml_decoded_shape(
    source,
    start,
    end,
    attribute~,
    entities~,
  )
  if output_units == 0 {
    return ""
  }
  if !changed {
    return xml_substring(source, start, end)
  }
  let output = xml_string_builder_for_units(output_units)
  write_strict_xml_decoded_range(
    output,
    source,
    start,
    end,
    attribute~,
    entities~,
  )
  output.to_string()
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
