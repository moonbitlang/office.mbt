///|
let xml_namespace_uri = "http://www.w3.org/XML/1998/namespace"

///|
let xmlns_namespace_uri = "http://www.w3.org/2000/xmlns/"

///|
let max_xml_start_tag_chars : Int = 16 * 1024 * 1024

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
  namespace_id : Int
  depth : Int
  previous_index : Int?
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
  priv cancelled : () -> Bool
  priv mut index : Int
  priv mut depth : Int
  priv namespace_bindings : Array[XmlNamespaceBinding]
  priv namespace_prefix_indices : Map[String, Int]
  priv namespace_ids : Map[String, Int]
  priv namespace_ref_counts : Map[Int, Int]
  priv mut next_namespace_id : Int
  priv open_name_starts : Array[Int]
  priv open_name_ends : Array[Int]
  priv open_name_replacements : Array[String?]
  priv open_local_name_starts : Array[Int]
  priv open_local_name_ends : Array[Int]
  priv open_namespace_uris : Array[String]
  priv open_remove_end_tags : Array[Bool]
  priv rewrite_element_prefixes : Map[String, String]
  priv reserved_element_prefixes : Map[String, String]
  priv rewrite_attribute_prefixes : Map[String, String]
  priv reserved_attribute_prefixes : Map[String, String]
  priv rewrite_output : StringBuilder
  priv canonicalize_markup : Bool
  priv rewrite_output_limit : Int
  priv mut rewrite_output_chars : Int
  priv mut rewrite_cursor : Int
  priv mut rewrite_count : Int
  priv mut pending_namespace_pop : Int?
  priv mut root_seen : Bool
  priv mut root_closed : Bool
  priv mut current_name_start : Int
  priv mut current_name_end : Int
  priv mut current_tag_start : Int
  priv mut current_tag_end : Int
  priv mut current_attribute_insert : Int
  priv mut current_self_closing : Bool
  priv mut current_depth : Int
  priv mut current_namespace_uri : String
  priv mut current_namespace_id : Int
  priv mut intervening_character_data_is_whitespace : Bool
  priv capture_element_namespaces : Array[String]
  priv capture_element_local_name : String
  priv retain_element_namespaces : Array[String]
  priv mut capture_start : Int?
  priv mut capture_depth : Int
}

///|
fn check_xml_cancelled(cancelled : () -> Bool) -> Unit raise ParseXmlError {
  if cancelled() {
    raise ReadCancelled
  }
}

///|
fn xml_name_scalar_at(xml : StringView, index : Int, end : Int) -> (Int, Int)? {
  if index >= end {
    return None
  }
  let first = xml[index].to_int()
  if first >= 0xd800 && first <= 0xdbff {
    if index + 1 >= end {
      return None
    }
    let second = xml[index + 1].to_int()
    if second < 0xdc00 || second > 0xdfff {
      return None
    }
    Some((0x10000 + ((first - 0xd800) << 10) + second - 0xdc00, index + 2))
  } else if first >= 0xdc00 && first <= 0xdfff {
    None
  } else {
    Some((first, index + 1))
  }
}

///|
fn is_xml_name_start_scalar(code : Int) -> Bool {
  (code >= 'A'.to_int() && code <= 'Z'.to_int()) ||
  (code >= 'a'.to_int() && code <= 'z'.to_int()) ||
  code == '_'.to_int() ||
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
fn is_xml_name_scalar(code : Int) -> Bool {
  is_xml_name_start_scalar(code) ||
  (code >= '0'.to_int() && code <= '9'.to_int()) ||
  code == '-'.to_int() ||
  code == '.'.to_int() ||
  code == 0xb7 ||
  (code >= 0x300 && code <= 0x36f) ||
  (code >= 0x203f && code <= 0x2040)
}

///|
/// Validates an XML NCName using the same Unicode scalar rules as the scanner's
/// QName validation. MCE directive tokens are attribute *values*, so they do
/// not pass through `validate_xml_qname` automatically.
fn is_xml_ncname(value : StringView) -> Bool {
  if value.length() == 0 {
    return false
  }
  let mut index = 0
  while index < value.length() {
    guard xml_name_scalar_at(value, index, value.length()) is Some((code, next)) else {
      return false
    }
    if index == 0 {
      if !is_xml_name_start_scalar(code) {
        return false
      }
    } else if !is_xml_name_scalar(code) {
      return false
    }
    index = next
  }
  true
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
  let mut index = start
  while index < end {
    let unit = xml[index]
    if unit == (':' : UInt16) {
      if colon is Some(_) || index == start || index + 1 == end {
        raise InvalidXml(msg="XML qualified name is invalid")
      }
      colon = Some(index)
      index += 1
    } else {
      let local_start = if index == start {
        true
      } else {
        match colon {
          Some(value) => index == value + 1
          None => false
        }
      }
      guard xml_name_scalar_at(xml, index, end) is Some((code, next)) else {
        raise InvalidXml(msg="XML qualified name is invalid")
      }
      if local_start {
        if !is_xml_name_start_scalar(code) {
          raise InvalidXml(msg="XML qualified name is invalid")
        }
      } else if !is_xml_name_scalar(code) {
        raise InvalidXml(msg="XML qualified name is invalid")
      }
      index = next
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
  cancelled? : () -> Bool = () => false,
) -> Int? raise ParseXmlError {
  check_xml_cancelled(cancelled)
  if sequence.length() == 0 {
    return Some(start)
  }
  let last = xml.length() - sequence.length()
  let mut index = start
  let mut next_checkpoint = start
  while index <= last {
    if index >= next_checkpoint {
      check_xml_cancelled(cancelled)
      next_checkpoint = index + 4096
    }
    if xml_span_equals(xml, index, index + sequence.length(), sequence) {
      return Some(index)
    }
    index = index + 1
  }
  None
}

///|
fn xml_span_equals_ascii_case_insensitive(
  xml : StringView,
  start : Int,
  end : Int,
  expected : StringView,
) -> Bool {
  if end - start != expected.length() {
    return false
  }
  for offset in 0..<expected.length() {
    let actual = xml[start + offset].to_int()
    let wanted = expected[offset].to_int()
    let actual_lower = if actual >= ('A' : UInt16).to_int() &&
      actual <= ('Z' : UInt16).to_int() {
      actual + 32
    } else {
      actual
    }
    let wanted_lower = if wanted >= ('A' : UInt16).to_int() &&
      wanted <= ('Z' : UInt16).to_int() {
      wanted + 32
    } else {
      wanted
    }
    if actual_lower != wanted_lower {
      return false
    }
  }
  true
}

///|
fn validate_xml_character_span(
  xml : StringView,
  start : Int,
  end : Int,
  cancelled : () -> Bool,
) -> Unit raise ParseXmlError {
  let mut index = start
  let mut next_checkpoint = start
  while index < end {
    if index >= next_checkpoint {
      check_xml_cancelled(cancelled)
      next_checkpoint = index + 4096
    }
    let unit = xml[index]
    if unit < 0x20 &&
      unit != ('\t' : UInt16) &&
      unit != ('\n' : UInt16) &&
      unit != ('\r' : UInt16) {
      raise InvalidXml(msg="XML markup contains an invalid character")
    }
    if unit == 0xfffe || unit == 0xffff || unit.is_trailing_surrogate() {
      raise InvalidXml(msg="XML markup contains an invalid character")
    }
    if unit.is_leading_surrogate() {
      if index + 1 >= end || !xml[index + 1].is_trailing_surrogate() {
        raise InvalidXml(msg="XML markup contains an invalid character")
      }
      index = index + 2
    } else {
      index = index + 1
    }
  }
  check_xml_cancelled(cancelled)
}

///|
fn validate_xml_encoding_name(value : StringView) -> Bool {
  if value.length() == 0 ||
    !((value[0] >= ('A' : UInt16) && value[0] <= ('Z' : UInt16)) ||
    (value[0] >= ('a' : UInt16) && value[0] <= ('z' : UInt16))) {
    return false
  }
  for unit in value[1:] {
    let valid = (unit >= 'A' && unit <= 'Z') ||
      (unit >= 'a' && unit <= 'z') ||
      (unit >= '0' && unit <= '9') ||
      unit == '.' ||
      unit == '_' ||
      unit == '-'
    if !valid {
      return false
    }
  }
  true
}

///|
fn validate_xml_declaration(
  xml : StringView,
  attributes_start : Int,
  end : Int,
  cancelled : () -> Bool,
) -> Unit raise ParseXmlError {
  if attributes_start >= end || !is_attr_space(xml[attributes_start]) {
    raise InvalidXml(msg="XML declaration version is missing")
  }
  let mut content_end = end
  while content_end > attributes_start && is_attr_space(xml[content_end - 1]) {
    content_end = content_end - 1
  }
  if content_end > attributes_start && xml[content_end - 1] == ('/' : UInt16) {
    raise InvalidXml(msg="XML declaration cannot be self-closing")
  }
  let mut next = attributes_start
  let mut position = 0
  let mut saw_encoding = false
  let mut saw_standalone = false
  while next_xml_attribute(xml, next, end, cancelled~) is Some(attribute) {
    validate_xml_character_span(
      xml,
      attribute.value_start,
      attribute.value_end,
      cancelled,
    )
    if position == 0 {
      if !xml_span_equals(
          xml,
          attribute.name_start,
          attribute.name_end,
          "version",
        ) ||
        (
          !xml_span_equals(
            xml,
            attribute.value_start,
            attribute.value_end,
            "1.0",
          ) &&
          !xml_span_equals(
            xml,
            attribute.value_start,
            attribute.value_end,
            "1.1",
          )
        ) {
        raise InvalidXml(msg="XML declaration version is invalid")
      }
    } else if xml_span_equals(
        xml,
        attribute.name_start,
        attribute.name_end,
        "encoding",
      ) {
      if saw_encoding ||
        saw_standalone ||
        !validate_xml_encoding_name(
          xml[attribute.value_start:attribute.value_end],
        ) {
        raise InvalidXml(msg="XML declaration encoding is invalid")
      }
      saw_encoding = true
    } else if xml_span_equals(
        xml,
        attribute.name_start,
        attribute.name_end,
        "standalone",
      ) {
      if saw_standalone ||
        (
          !xml_span_equals(
            xml,
            attribute.value_start,
            attribute.value_end,
            "yes",
          ) &&
          !xml_span_equals(
            xml,
            attribute.value_start,
            attribute.value_end,
            "no",
          )
        ) {
        raise InvalidXml(msg="XML declaration standalone value is invalid")
      }
      saw_standalone = true
    } else {
      raise InvalidXml(msg="XML declaration attribute is invalid")
    }
    position = position + 1
    next = attribute.next
  }
  if position == 0 {
    raise InvalidXml(msg="XML declaration version is missing")
  }
}

///|
fn XmlStartTagScanner::validate_processing_instruction(
  self : XmlStartTagScanner,
  start : Int,
  end : Int,
) -> Unit raise ParseXmlError {
  let target_start = start + 2
  let mut target_end = target_start
  while target_end < end && !is_attr_space(self.xml[target_end]) {
    target_end = target_end + 1
  }
  ignore(validate_xml_qname(self.xml, target_start, target_end))
  let reserved = xml_span_equals_ascii_case_insensitive(
    self.xml,
    target_start,
    target_end,
    "xml",
  )
  if reserved {
    if start != 0 ||
      !xml_span_equals(self.xml, target_start, target_end, "xml") ||
      self.depth != 0 ||
      self.root_seen ||
      self.root_closed {
      raise InvalidXml(msg="XML declaration is misplaced")
    }
    validate_xml_declaration(self.xml, target_end, end, self.cancelled)
  } else {
    validate_xml_character_span(self.xml, target_end, end, self.cancelled)
  }
}

///|
fn XmlStartTagScanner::validate_comment(
  self : XmlStartTagScanner,
  start : Int,
  end : Int,
) -> Unit raise ParseXmlError {
  let content_start = start + 4
  validate_xml_character_span(self.xml, content_start, end, self.cancelled)
  for index in content_start..<end {
    if self.xml[index] == ('-' : UInt16) &&
      (index + 1 == end || self.xml[index + 1] == ('-' : UInt16)) {
      raise InvalidXml(msg="XML comment contains an invalid hyphen sequence")
    }
  }
}

///|
fn find_xml_tag_end(
  xml : StringView,
  search_start : Int,
  markup_start : Int,
  cancelled? : () -> Bool = () => false,
) -> Int raise ParseXmlError {
  check_xml_cancelled(cancelled)
  let mut index = search_start
  let mut next_checkpoint = search_start
  let mut quote : UInt16? = None
  while index < xml.length() {
    if index >= next_checkpoint {
      check_xml_cancelled(cancelled)
      next_checkpoint = index + 4096
    }
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
  cancelled? : () -> Bool = () => false,
) -> XmlAttributeSpan? raise ParseXmlError {
  check_xml_cancelled(cancelled)
  let mut index = start
  let mut next_checkpoint = start + 4096
  let mut separated = false
  while index < tag_end && is_attr_space(xml[index]) {
    separated = true
    if index >= next_checkpoint {
      check_xml_cancelled(cancelled)
      next_checkpoint = index + 4096
    }
    index = index + 1
  }
  if index >= tag_end {
    return None
  }
  if xml[index] == ('/' : UInt16) {
    if index + 1 != tag_end {
      raise InvalidXml(msg="XML self-closing slash is misplaced")
    }
    return None
  }
  if !separated {
    raise InvalidXml(msg="XML attribute is not separated by whitespace")
  }
  let name_start = index
  while index < tag_end &&
        !is_attr_space(xml[index]) &&
        xml[index] != ('=' : UInt16) &&
        xml[index] != ('/' : UInt16) {
    if index >= next_checkpoint {
      check_xml_cancelled(cancelled)
      next_checkpoint = index + 4096
    }
    index = index + 1
  }
  let name_end = index
  ignore(validate_xml_qname(xml, name_start, name_end))
  while index < tag_end && is_attr_space(xml[index]) {
    if index >= next_checkpoint {
      check_xml_cancelled(cancelled)
      next_checkpoint = index + 4096
    }
    index = index + 1
  }
  if index >= tag_end || xml[index] != ('=' : UInt16) {
    raise InvalidXml(msg="XML attribute has no value")
  }
  index = index + 1
  while index < tag_end && is_attr_space(xml[index]) {
    if index >= next_checkpoint {
      check_xml_cancelled(cancelled)
      next_checkpoint = index + 4096
    }
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
    if index >= next_checkpoint {
      check_xml_cancelled(cancelled)
      next_checkpoint = index + 4096
    }
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
        entity[1] == ('x' : UInt16) {
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
pub fn decode_xml_attribute(
  value : StringView,
  cancelled? : () -> Bool = () => false,
) -> String raise ParseXmlError {
  check_xml_cancelled(cancelled)
  validate_xml_character_span(value, 0, value.length(), cancelled)
  let mut needs_decode = false
  for index, unit in value {
    if (index & 4095) == 0 {
      check_xml_cancelled(cancelled)
    }
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
  let mut next_checkpoint = 0
  while index < value.length() {
    if index >= next_checkpoint {
      check_xml_cancelled(cancelled)
      next_checkpoint = index + 4096
    }
    let unit = value[index]
    if unit == ('&' : UInt16) {
      output.write_view(value[literal_start:index])
      let entity_end = match
        find_xml_sequence(value, index + 1, ";", cancelled~) {
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
      if unit == ('\r' : UInt16) &&
        index + 1 < value.length() &&
        value[index + 1] == ('\n' : UInt16) {
        index = index + 2
      } else {
        index = index + 1
      }
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
/// Checks an attribute value without retaining a decoded copy. This is used
/// for attributes a caller does not select: malformed entities must never be
/// hidden merely because an attribute is semantically irrelevant.
fn validate_xml_attribute_value(
  value : StringView,
  cancelled : () -> Bool,
) -> Unit raise ParseXmlError {
  check_xml_cancelled(cancelled)
  validate_xml_character_span(value, 0, value.length(), cancelled)
  let mut index = 0
  let mut next_checkpoint = 0
  while index < value.length() {
    if index >= next_checkpoint {
      check_xml_cancelled(cancelled)
      next_checkpoint = index + 4096
    }
    let unit = value[index]
    if unit == ('&' : UInt16) {
      let entity_end = match
        find_xml_sequence(value, index + 1, ";", cancelled~) {
        Some(found) => found
        None => raise InvalidXml(msg="XML entity is not closed")
      }
      if xml_entity_value(value[index + 1:entity_end]) is None {
        raise InvalidXml(msg="XML entity is invalid")
      }
      index = entity_end + 1
      continue
    }
    if unit == ('<' : UInt16) {
      raise InvalidXml(msg="XML attribute contains '<'")
    }
    if unit < 0x20 &&
      unit != ('\t' : UInt16) &&
      unit != ('\n' : UInt16) &&
      unit != ('\r' : UInt16) {
      raise InvalidXml(msg="XML attribute contains an invalid character")
    }
    index = index + 1
  }
}

///|
fn XmlStartTagScanner::namespace_identity(
  self : XmlStartTagScanner,
  uri : String,
) -> Int {
  if uri == "" {
    return 0
  }
  if uri == xml_namespace_uri {
    return 1
  }
  match self.namespace_ids.get(uri) {
    Some(namespace_id) => {
      self.namespace_ref_counts[namespace_id] = self.namespace_ref_counts.get_or_default(
          namespace_id, 0,
        ) +
        1
      namespace_id
    }
    None => {
      let namespace_id = self.next_namespace_id
      self.next_namespace_id = self.next_namespace_id + 1
      self.namespace_ids[uri] = namespace_id
      self.namespace_ref_counts[namespace_id] = 1
      namespace_id
    }
  }
}

///|
fn XmlStartTagScanner::release_namespace_identity(
  self : XmlStartTagScanner,
  binding : XmlNamespaceBinding,
) -> Unit {
  if binding.namespace_id < 2 {
    return
  }
  let remaining = self.namespace_ref_counts.get_or_default(
      binding.namespace_id,
      0,
    ) -
    1
  if remaining <= 0 {
    ignore(self.namespace_ref_counts.remove(binding.namespace_id))
    ignore(self.namespace_ids.remove(binding.uri))
  } else {
    self.namespace_ref_counts[binding.namespace_id] = remaining
  }
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
    let binding = self.namespace_bindings[last]
    ignore(self.namespace_bindings.pop())
    match binding.previous_index {
      Some(index) => self.namespace_prefix_indices[binding.prefix] = index
      None => ignore(self.namespace_prefix_indices.remove(binding.prefix))
    }
    self.release_namespace_identity(binding)
  }
}

///|
fn XmlStartTagScanner::resolve_prefix_identity(
  self : XmlStartTagScanner,
  prefix : StringView,
  attribute : Bool,
) -> (String, Int) raise ParseXmlError {
  if prefix == "xml" {
    return (xml_namespace_uri, 1)
  }
  if prefix.length() == 0 && attribute {
    return ("", 0)
  }
  match self.namespace_prefix_indices.get(prefix.to_owned()) {
    Some(index) => {
      let binding = self.namespace_bindings[index]
      return (binding.uri, binding.namespace_id)
    }
    None => ()
  }
  if prefix.length() == 0 {
    ("", 0)
  } else {
    raise InvalidXml(msg="XML namespace prefix is not declared")
  }
}

///|
fn XmlStartTagScanner::resolve_prefix(
  self : XmlStartTagScanner,
  prefix : StringView,
  attribute : Bool,
) -> String raise ParseXmlError {
  let (uri, _) = self.resolve_prefix_identity(prefix, attribute)
  uri
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
  while next_xml_attribute(self.xml, next, tag_end, cancelled=self.cancelled)
        is Some(attribute) {
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
      cancelled=self.cancelled,
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
    let namespace_id = self.namespace_identity(uri)
    let previous_index = self.namespace_prefix_indices.get(prefix)
    let binding_index = self.namespace_bindings.length()
    self.namespace_bindings.push({
      prefix,
      uri,
      namespace_id,
      depth: scope_depth,
      previous_index,
    })
    self.namespace_prefix_indices[prefix] = binding_index
  }
}

///|
fn XmlStartTagScanner::validate_attributes(
  self : XmlStartTagScanner,
  attributes_start : Int,
  tag_end : Int,
) -> Unit raise ParseXmlError {
  let expanded_names : Map[Int, Set[String]] = Map([])
  let canonical_names : Set[String] = Set([])
  let mut next = attributes_start
  let mut count = 0
  while next_xml_attribute(self.xml, next, tag_end, cancelled=self.cancelled)
        is Some(attribute) {
    count = count + 1
    if count > max_xml_start_tag_attributes {
      raise InvalidXml(msg="XML start tag has too many attributes")
    }
    next = attribute.next
    validate_xml_attribute_value(
      self.xml[attribute.value_start:attribute.value_end],
      self.cancelled,
    )
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
    let (uri, namespace_id) = self.resolve_prefix_identity(prefix, true)
    let local_names = match expanded_names.get(namespace_id) {
      Some(values) => values
      None => {
        let values : Set[String] = Set([])
        expanded_names[namespace_id] = values
        values
      }
    }
    let local_name = local_name_view.to_owned()
    if local_names.contains(local_name) {
      raise InvalidXml(msg="XML attribute is duplicated")
    }
    local_names.add(local_name)
    let replacement = match self.rewrite_attribute_prefixes.get(uri) {
      Some(canonical_prefix) =>
        if canonical_prefix == "" {
          local_name
        } else {
          canonical_prefix + ":" + local_name
        }
      None =>
        match self.reserved_attribute_prefixes.get(prefix.to_owned()) {
          Some(expected_uri) if expected_uri != uri =>
            "_foreign_" + prefix.to_owned() + "_" + local_name
          _ => self.xml[attribute.name_start:attribute.name_end].to_owned()
        }
    }
    if canonical_names.contains(replacement) {
      raise InvalidXml(msg="XML canonical attribute name collision")
    }
    canonical_names.add(replacement)
    if !xml_span_equals(
        self.xml,
        attribute.name_start,
        attribute.name_end,
        replacement,
      ) {
      self.record_rewrite(attribute.name_start, attribute.name_end, replacement)
    }
  }
}

///|
fn XmlStartTagScanner::record_rewrite(
  self : XmlStartTagScanner,
  start : Int,
  end : Int,
  replacement : String,
) -> Unit raise ParseXmlError {
  if start < self.rewrite_cursor || end < start {
    raise InvalidXml(msg="XML canonical rewrites overlap")
  }
  self.charge_rewrite_output(start - self.rewrite_cursor)
  self.charge_rewrite_output(replacement.length())
  self.write_rewrite_source(self.rewrite_cursor, start)
  self.rewrite_output.write_string(replacement)
  check_xml_cancelled(self.cancelled)
  self.rewrite_cursor = end
  self.rewrite_count = self.rewrite_count + 1
}

///|
fn XmlStartTagScanner::write_rewrite_source(
  self : XmlStartTagScanner,
  start : Int,
  end : Int,
) -> Unit raise ParseXmlError {
  let mut index = start
  while index < end {
    check_xml_cancelled(self.cancelled)
    let next = (index + 4096).min(end)
    self.rewrite_output.write_view(self.xml[index:next])
    index = next
  }
  check_xml_cancelled(self.cancelled)
}

///|
fn XmlStartTagScanner::charge_rewrite_output(
  self : XmlStartTagScanner,
  count : Int,
) -> Unit raise ParseXmlError {
  if count < 0 || count > self.rewrite_output_limit - self.rewrite_output_chars {
    raise InvalidXml(msg="XML canonical output limit exceeded")
  }
  self.rewrite_output_chars += count
}

///|
fn XmlStartTagScanner::escaped_character_data(
  self : XmlStartTagScanner,
  rewrite_start : Int,
  value_start : Int,
  end : Int,
) -> String raise ParseXmlError {
  let unchanged = rewrite_start - self.rewrite_cursor
  if unchanged < 0 ||
    unchanged > self.rewrite_output_limit - self.rewrite_output_chars {
    raise InvalidXml(msg="XML canonical output limit exceeded")
  }
  let available = self.rewrite_output_limit -
    self.rewrite_output_chars -
    unchanged
  let value = self.xml[value_start:end]
  let output = StringBuilder::new(size_hint=value.length().min(available))
  let mut used = 0
  for index, unit in value {
    if (index & 4095) == 0 {
      check_xml_cancelled(self.cancelled)
    }
    let needed = if unit == '&' { 5 } else if unit == '<' { 4 } else { 1 }
    if needed > available - used {
      raise InvalidXml(msg="XML canonical output limit exceeded")
    }
    used += needed
    if unit == '&' {
      output.write_string("&amp;")
    } else if unit == '<' {
      output.write_string("&lt;")
    } else {
      output.write_char(unit)
    }
  }
  check_xml_cancelled(self.cancelled)
  output.to_string()
}

///|
fn XmlStartTagScanner::canonical_element_replacement(
  self : XmlStartTagScanner,
  namespace_uri : StringView,
  prefix : StringView,
  local_name : StringView,
) -> String? {
  match self.rewrite_element_prefixes.get(namespace_uri.to_owned()) {
    Some(canonical_prefix) =>
      if canonical_prefix == "" {
        Some(local_name.to_owned())
      } else {
        Some(canonical_prefix + ":" + local_name.to_owned())
      }
    None =>
      match self.reserved_element_prefixes.get(prefix.to_owned()) {
        Some(expected_uri) if expected_uri != namespace_uri.to_owned() =>
          Some("_foreign_" + prefix.to_owned() + "_" + local_name.to_owned())
        _ => None
      }
  }
}

///|
fn xml_start_tag_scanner_with_rewrites(
  xml : StringView,
  element_prefixes : Map[String, String],
  reserved_element_prefixes : Map[String, String],
  attribute_prefixes : Map[String, String],
  reserved_attribute_prefixes : Map[String, String],
  canonicalize_markup : Bool,
  rewrite_output_limit : Int,
  capture_element_namespaces? : Array[String] = [],
  capture_element_local_name? : String = "",
  retain_element_namespaces? : Array[String] = [],
  cancelled? : () -> Bool = () => false,
) -> XmlStartTagScanner {
  {
    xml,
    cancelled,
    index: 0,
    depth: 0,
    namespace_bindings: [],
    namespace_prefix_indices: Map([]),
    namespace_ids: Map([]),
    namespace_ref_counts: Map([]),
    next_namespace_id: 2,
    open_name_starts: [],
    open_name_ends: [],
    open_name_replacements: [],
    open_local_name_starts: [],
    open_local_name_ends: [],
    open_namespace_uris: [],
    open_remove_end_tags: [],
    rewrite_element_prefixes: element_prefixes,
    reserved_element_prefixes,
    rewrite_attribute_prefixes: attribute_prefixes,
    reserved_attribute_prefixes,
    rewrite_output: StringBuilder::new(),
    canonicalize_markup,
    rewrite_output_limit,
    rewrite_output_chars: 0,
    rewrite_cursor: 0,
    rewrite_count: 0,
    pending_namespace_pop: None,
    root_seen: false,
    root_closed: false,
    current_name_start: 0,
    current_name_end: 0,
    current_tag_start: 0,
    current_tag_end: 0,
    current_attribute_insert: 0,
    current_self_closing: false,
    current_depth: 0,
    current_namespace_uri: "",
    current_namespace_id: 0,
    intervening_character_data_is_whitespace: true,
    capture_element_namespaces,
    capture_element_local_name,
    retain_element_namespaces,
    capture_start: None,
    capture_depth: 0,
  }
}

///|
/// Creates a namespace-aware cursor over `xml`. The source is borrowed; no
/// copy of the full XML part is made.
pub fn XmlStartTagScanner::new(
  xml : StringView,
  cancelled? : () -> Bool = () => false,
) -> XmlStartTagScanner {
  xml_start_tag_scanner_with_rewrites(
    xml,
    Map([]),
    Map([]),
    Map([]),
    Map([]),
    false,
    0,
    cancelled~,
  )
}

///|
fn XmlStartTagScanner::consume_end_tag(
  self : XmlStartTagScanner,
  start : Int,
) -> Unit raise ParseXmlError {
  check_xml_cancelled(self.cancelled)
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
  let tag_end = find_xml_tag_end(
    self.xml,
    name_end,
    start,
    cancelled=self.cancelled,
  )
  let mut next_checkpoint = name_end
  for index in name_end..<tag_end {
    if index >= next_checkpoint {
      check_xml_cancelled(self.cancelled)
      next_checkpoint = index + 4096
    }
    if !is_attr_space(self.xml[index]) {
      raise InvalidXml(msg="XML end tag is invalid")
    }
  }
  let open_start = self.open_name_starts[self.open_name_starts.length() - 1]
  let open_end = self.open_name_ends[self.open_name_ends.length() - 1]
  if !xml_spans_equal(self.xml, name_start, name_end, open_start, open_end) {
    raise InvalidXml(msg="XML start and end tags do not match")
  }
  let stack_index = self.open_name_replacements.length() - 1
  let replacement = self.open_name_replacements[stack_index]
  let remove_end_tag = self.open_remove_end_tags[stack_index]
  match self.capture_start {
    Some(capture_start) if self.capture_depth == self.depth => {
      self.record_rewrite(capture_start, tag_end + 1, "")
      self.capture_start = None
      self.capture_depth = 0
    }
    _ =>
      if remove_end_tag {
        self.record_rewrite(start, tag_end + 1, "")
      } else {
        match replacement {
          Some(value) => self.record_rewrite(name_start, name_end, value)
          None => ()
        }
      }
  }
  ignore(self.open_name_starts.pop())
  ignore(self.open_name_ends.pop())
  ignore(self.open_name_replacements.pop())
  ignore(self.open_local_name_starts.pop())
  ignore(self.open_local_name_ends.pop())
  ignore(self.open_namespace_uris.pop())
  ignore(self.open_remove_end_tags.pop())
  self.pop_namespace_depth(self.depth)
  self.depth = self.depth - 1
  if self.depth == 0 {
    self.root_closed = true
  }
  self.index = tag_end + 1
}

///|
/// Advances to the next start tag. Returns `false` at end of input and raises
/// `InvalidXml` for malformed namespace or tag structure.
pub fn XmlStartTagScanner::next(
  self : XmlStartTagScanner,
) -> Bool raise ParseXmlError {
  check_xml_cancelled(self.cancelled)
  self.intervening_character_data_is_whitespace = true
  match self.pending_namespace_pop {
    Some(depth) => {
      self.pop_namespace_depth(depth)
      self.pending_namespace_pop = None
    }
    None => ()
  }
  let mut next_checkpoint = self.index
  while self.index < self.xml.length() {
    while self.index < self.xml.length() &&
          self.xml[self.index] != ('<' : UInt16) {
      if self.index >= next_checkpoint {
        check_xml_cancelled(self.cancelled)
        next_checkpoint = self.index + 4096
      }
      if self.depth == 0 && !is_attr_space(self.xml[self.index]) {
        raise InvalidXml(msg="XML text is outside the document element")
      }
      let unit = self.xml[self.index]
      if unit == ('&' : UInt16) {
        let entity_end = match
          find_xml_sequence(
            self.xml,
            self.index + 1,
            ";",
            cancelled=self.cancelled,
          ) {
          Some(found) => found
          None => raise InvalidXml(msg="XML entity is not closed")
        }
        let character = match
          xml_entity_value(self.xml[self.index + 1:entity_end]) {
          Some(value) => value
          None => raise InvalidXml(msg="XML entity is invalid")
        }
        if character != ' ' &&
          character != '\t' &&
          character != '\n' &&
          character != '\r' {
          self.intervening_character_data_is_whitespace = false
        }
        self.index = entity_end + 1
        continue
      }
      if !is_attr_space(unit) {
        self.intervening_character_data_is_whitespace = false
      }
      if unit == (']' : UInt16) &&
        self.index + 2 < self.xml.length() &&
        self.xml[self.index + 1] == (']' : UInt16) &&
        self.xml[self.index + 2] == ('>' : UInt16) {
        raise InvalidXml(msg="XML character data contains ']]>'")
      }
      if unit < 0x20 &&
        unit != ('\t' : UInt16) &&
        unit != ('\n' : UInt16) &&
        unit != ('\r' : UInt16) {
        raise InvalidXml(msg="XML character data contains an invalid character")
      }
      if unit == 0xfffe || unit == 0xffff || unit.is_trailing_surrogate() {
        raise InvalidXml(msg="XML character data contains an invalid character")
      }
      if unit.is_leading_surrogate() {
        if self.index + 1 >= self.xml.length() ||
          !self.xml[self.index + 1].is_trailing_surrogate() {
          raise InvalidXml(
            msg="XML character data contains an invalid character",
          )
        }
        self.index = self.index + 2
        continue
      }
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
      let end = match
        find_xml_sequence(self.xml, start + 2, "?>", cancelled=self.cancelled) {
        Some(value) => value
        None => raise InvalidXml(msg="XML processing instruction is not closed")
      }
      self.validate_processing_instruction(start, end)
      if self.canonicalize_markup {
        self.record_rewrite(start, end + 2, "")
      }
      self.index = end + 2
      continue
    }
    if self.xml[start + 1] == ('!' : UInt16) {
      if start + 4 <= self.xml.length() &&
        xml_span_equals(self.xml, start, start + 4, "<!--") {
        let end = match
          find_xml_sequence(
            self.xml,
            start + 4,
            "-->",
            cancelled=self.cancelled,
          ) {
          Some(value) => value
          None => raise InvalidXml(msg="XML comment is not closed")
        }
        self.validate_comment(start, end)
        if self.canonicalize_markup {
          self.record_rewrite(start, end + 3, "")
        }
        self.index = end + 3
        continue
      }
      if start + 9 <= self.xml.length() &&
        xml_span_equals(self.xml, start, start + 9, "<![CDATA[") {
        if self.depth == 0 {
          raise InvalidXml(msg="XML CDATA is outside the document element")
        }
        let end = match
          find_xml_sequence(
            self.xml,
            start + 9,
            "]]>",
            cancelled=self.cancelled,
          ) {
          Some(value) => value
          None => raise InvalidXml(msg="XML CDATA section is not closed")
        }
        validate_xml_character_span(self.xml, start + 9, end, self.cancelled)
        let mut character_index = start + 9
        while character_index < end {
          if !is_attr_space(self.xml[character_index]) {
            self.intervening_character_data_is_whitespace = false
            break
          }
          character_index = character_index + 1
        }
        if self.canonicalize_markup {
          self.record_rewrite(
            start,
            end + 3,
            self.escaped_character_data(start, start + 9, end),
          )
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
    if self.depth == 0 {
      if self.root_seen || self.root_closed {
        raise InvalidXml(msg="XML has multiple document elements")
      }
      self.root_seen = true
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
    let tag_end = find_xml_tag_end(
      self.xml,
      name_end,
      start,
      cancelled=self.cancelled,
    )
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
    let prefix = match colon {
      Some(value) => self.xml[name_start:value]
      None => self.xml[name_start:name_start]
    }
    let (current_namespace_uri, current_namespace_id) = self.resolve_prefix_identity(
      prefix, false,
    )
    self.current_namespace_uri = current_namespace_uri
    self.current_namespace_id = current_namespace_id
    let local_name_start = match colon {
      Some(value) => value + 1
      None => name_start
    }
    let replacement = match
      self.canonical_element_replacement(
        self.current_namespace_uri,
        prefix,
        self.xml[local_name_start:name_end],
      ) {
      Some(value) if !xml_span_equals(self.xml, name_start, name_end, value) =>
        Some(value)
      _ => None
    }
    match replacement {
      Some(value) => self.record_rewrite(name_start, name_end, value)
      None => ()
    }
    self.validate_attributes(name_end, tag_end)
    self.current_name_start = local_name_start
    self.current_name_end = name_end
    self.current_tag_start = start
    self.current_tag_end = tag_end
    self.current_attribute_insert = if self_closing {
      before_end - 1
    } else {
      before_end
    }
    self.current_self_closing = self_closing
    self.current_depth = scope_depth
    if self.capture_start is None &&
      self.capture_element_local_name != "" &&
      self.local_name() == self.capture_element_local_name {
      for wanted in self.capture_element_namespaces {
        if xml_string_equals_view(wanted, self.current_namespace_uri) {
          self.capture_start = Some(start)
          self.capture_depth = scope_depth
          break
        }
      }
    }
    if self.capture_start is None &&
      self.retain_element_namespaces.length() > 0 &&
      scope_depth > 1 {
      let mut retained = false
      for wanted in self.retain_element_namespaces {
        if xml_string_equals_view(wanted, self.current_namespace_uri) {
          retained = true
          break
        }
      }
      if !retained {
        self.capture_start = Some(start)
        self.capture_depth = scope_depth
      }
    }
    self.index = tag_end + 1
    if self_closing {
      match self.capture_start {
        Some(capture_start) =>
          if self.capture_depth == scope_depth {
            self.record_rewrite(capture_start, tag_end + 1, "")
            self.capture_start = None
            self.capture_depth = 0
          }
        None => ()
      }
      self.pending_namespace_pop = Some(scope_depth)
      if self.depth == 0 {
        self.root_closed = true
      }
    } else {
      self.depth = scope_depth
      self.open_name_starts.push(name_start)
      self.open_name_ends.push(name_end)
      self.open_name_replacements.push(replacement)
      self.open_local_name_starts.push(self.current_name_start)
      self.open_local_name_ends.push(self.current_name_end)
      self.open_namespace_uris.push(self.current_namespace_uri)
      self.open_remove_end_tags.push(false)
    }
    return true
  }
  if self.depth != 0 {
    raise InvalidXml(msg="XML start tag has no matching end tag")
  }
  if !self.root_seen {
    raise InvalidXml(msg="XML document element is missing")
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
/// Returns the scanner-local structural identity of the current element's
/// namespace. The identity is stable for the lifetime of the in-scope
/// namespace binding and avoids copying long namespace URIs into parser keys.
fn XmlStartTagScanner::current_namespace_identity(
  self : XmlStartTagScanner,
) -> Int {
  self.current_namespace_id
}

///|
/// Returns the one-based nesting depth of the current start tag.
pub fn XmlStartTagScanner::depth(self : XmlStartTagScanner) -> Int {
  self.current_depth
}

///|
/// Reports whether character data consumed since the preceding start-tag
/// result consists only of XML whitespace. After `next` returns `false`, this
/// reports on the trailing character data since the final start tag. Comments
/// and processing instructions are markup rather than character data.
pub fn XmlStartTagScanner::intervening_character_data_is_whitespace(
  self : XmlStartTagScanner,
) -> Bool {
  self.intervening_character_data_is_whitespace
}

///|
/// Returns the local name of the current element's parent, or `None` for the
/// document element.
pub fn XmlStartTagScanner::parent_local_name(
  self : XmlStartTagScanner,
) -> StringView? {
  let index = self.current_depth - 2
  if index < 0 || index >= self.open_local_name_starts.length() {
    None
  } else {
    Some(
      self.xml[self.open_local_name_starts[index]:self.open_local_name_ends[index]],
    )
  }
}

///|
/// Returns the namespace URI of the current element's parent, or `None` for
/// the document element.
pub fn XmlStartTagScanner::parent_namespace_uri(
  self : XmlStartTagScanner,
) -> String? {
  let index = self.current_depth - 2
  if index < 0 || index >= self.open_namespace_uris.length() {
    None
  } else {
    Some(self.open_namespace_uris[index])
  }
}

///|
/// Removes every outermost subtree selected by expanded element name. `None`
/// means the document was valid but contained no matching subtree. Namespace
/// resolution and nesting are handled by the same bounded scanner used for
/// canonicalization, so markup-looking text cannot create a removal span.
pub fn remove_xml_expanded_name_subtrees(
  xml : StringView,
  element_namespaces : ArrayView[String],
  local_name : String,
  cancelled? : () -> Bool = () => false,
) -> String? raise ParseXmlError {
  check_xml_cancelled(cancelled)
  if local_name == "" {
    raise InvalidXml(msg="XML removal local name is empty")
  }
  let namespaces : Array[String] = []
  namespaces.append(element_namespaces)
  let scanner = xml_start_tag_scanner_with_rewrites(
    xml,
    Map([]),
    Map([]),
    Map([]),
    Map([]),
    false,
    xml.length(),
    capture_element_namespaces=namespaces,
    capture_element_local_name=local_name,
    cancelled~,
  )
  while scanner.next() {

  }
  if scanner.rewrite_count == 0 {
    return None
  }
  scanner.charge_rewrite_output(xml.length() - scanner.rewrite_cursor)
  scanner.write_rewrite_source(scanner.rewrite_cursor, xml.length())
  Some(scanner.rewrite_output.to_string())
}

///|
/// Removes outermost descendant subtrees whose expanded element namespace is
/// not in `element_namespaces`. The document element itself must be in the
/// retained set. This creates a safe namespace-oblivious core view while the
/// caller may retain the original XML separately for extension round-tripping.
pub fn remove_xml_foreign_namespace_subtrees(
  xml : StringView,
  element_namespaces : ArrayView[String],
  cancelled? : () -> Bool = () => false,
) -> String? raise ParseXmlError {
  check_xml_cancelled(cancelled)
  if element_namespaces.length() == 0 {
    raise InvalidXml(msg="XML retained namespace set is empty")
  }
  let namespaces : Array[String] = []
  namespaces.append(element_namespaces)
  let scanner = xml_start_tag_scanner_with_rewrites(
    xml,
    Map([]),
    Map([]),
    Map([]),
    Map([]),
    false,
    xml.length(),
    retain_element_namespaces=namespaces,
    cancelled~,
  )
  if !scanner.next() {
    raise InvalidXml(msg="XML document element is missing")
  }
  let mut root_retained = false
  for wanted in namespaces {
    if xml_string_equals_view(wanted, scanner.namespace_uri()) {
      root_retained = true
      break
    }
  }
  if !root_retained {
    raise InvalidXml(msg="XML document element namespace is invalid")
  }
  while scanner.next() {

  }
  if scanner.rewrite_count == 0 {
    return None
  }
  scanner.charge_rewrite_output(xml.length() - scanner.rewrite_cursor)
  scanner.write_rewrite_source(scanner.rewrite_cursor, xml.length())
  Some(scanner.rewrite_output.to_string())
}

///|
/// Validates `xml` and rewrites selected expanded names into lexical forms
/// expected by a namespace-oblivious parser. Elements in `element_namespaces`
/// lose their prefix. Additional element namespaces in `element_prefixes` and
/// attributes in `attribute_prefixes` receive their mapped canonical prefix.
/// A source name that uses one of those reserved prefixes for another namespace
/// is defanged so a lexical parser cannot mistake it for a supported extension.
/// Comments and processing instructions are removed, while CDATA is converted
/// to escaped character data so namespace-oblivious parsers cannot interpret
/// markup-looking content as elements. Values and unselected names are
/// unchanged.
pub fn canonicalize_xml_expanded_names(
  xml : StringView,
  element_namespaces : ArrayView[String],
  attribute_prefixes : ArrayView[(String, String)],
  max_output_chars? : Int = max_xml_start_tag_chars,
  cancelled? : () -> Bool = () => false,
  element_prefixes? : ArrayView[(String, String)] = [],
) -> String raise ParseXmlError {
  check_xml_cancelled(cancelled)
  if max_output_chars < 0 {
    raise InvalidXml(msg="XML canonical output limit is invalid")
  }
  let elements : Map[String, String] = Map([])
  for namespace_uri in element_namespaces {
    elements[namespace_uri] = ""
  }
  let reserved_elements : Map[String, String] = Map([])
  for pair in element_prefixes {
    let (namespace_uri, prefix) = pair
    elements[namespace_uri] = prefix
    if prefix != "" {
      reserved_elements[prefix] = namespace_uri
    }
  }
  let attributes : Map[String, String] = Map([])
  let reserved_attributes : Map[String, String] = Map([])
  for pair in attribute_prefixes {
    let (namespace_uri, prefix) = pair
    attributes[namespace_uri] = prefix
    if prefix != "" {
      reserved_attributes[prefix] = namespace_uri
    }
  }
  let scanner = xml_start_tag_scanner_with_rewrites(
    xml,
    elements,
    reserved_elements,
    attributes,
    reserved_attributes,
    true,
    max_output_chars,
    cancelled~,
  )
  while scanner.next() {

  }
  if scanner.rewrite_count == 0 {
    if xml.length() > max_output_chars {
      raise InvalidXml(msg="XML canonical output limit exceeded")
    }
    scanner.charge_rewrite_output(xml.length())
    scanner.write_rewrite_source(0, xml.length())
    return scanner.rewrite_output.to_string()
  }
  scanner.charge_rewrite_output(xml.length() - scanner.rewrite_cursor)
  scanner.write_rewrite_source(scanner.rewrite_cursor, xml.length())
  scanner.rewrite_output.to_string()
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
  while next_xml_attribute(
          self.xml,
          next,
          self.current_tag_end,
          cancelled=self.cancelled,
        )
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
    Some(value) => Some(decode_xml_attribute(value, cancelled=self.cancelled))
    None => None
  }
}

///|
/// Returns decoded values for every attribute in `namespace_uri` on the
/// current element. Namespace declarations are excluded and source order is
/// retained. This is useful for extensible XML vocabularies whose relationship
/// attribute local names are not known ahead of time.
pub fn XmlStartTagScanner::attribute_values_in_namespace(
  self : XmlStartTagScanner,
  namespace_uri : StringView,
) -> Array[String] raise ParseXmlError {
  let values : Array[String] = []
  let mut next = self.current_name_end
  while next_xml_attribute(
          self.xml,
          next,
          self.current_tag_end,
          cancelled=self.cancelled,
        )
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
    let prefix = match colon {
      Some(value) => self.xml[attribute.name_start:value]
      None => self.xml[attribute.name_start:attribute.name_start]
    }
    if xml_string_equals_view(self.resolve_prefix(prefix, true), namespace_uri) {
      values.push(
        decode_xml_attribute(
          self.xml[attribute.value_start:attribute.value_end],
          cancelled=self.cancelled,
        ),
      )
    }
  }
  values
}

///|
/// Returns decoded attribute values, aligned with `expected`, when the current
/// element has exactly those expanded attribute names. Namespace declarations
/// are ignored. Duplicate expected expanded names, extra source attributes,
/// or missing source attributes return `None`; duplicate source expanded names
/// have already been rejected by `next`.
pub fn XmlStartTagScanner::exact_attribute_values(
  self : XmlStartTagScanner,
  expected : ArrayView[(String, String)],
) -> Array[String]? raise ParseXmlError {
  let expected_indices : Map[String, Map[String, Int]] = Map([])
  for index, entry in expected {
    let (namespace_uri, local_name) = entry
    let namespace_indices = match expected_indices.get(namespace_uri) {
      Some(indices) => indices
      None => {
        let indices : Map[String, Int] = Map([])
        expected_indices[namespace_uri] = indices
        indices
      }
    }
    if namespace_indices.contains(local_name) {
      return None
    }
    namespace_indices[local_name] = index
  }
  let values : Array[String] = Array::make(expected.length(), "")
  let mut matched = 0
  let mut next = self.current_name_end
  while next_xml_attribute(
          self.xml,
          next,
          self.current_tag_end,
          cancelled=self.cancelled,
        )
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
    let namespace_uri = self.resolve_prefix(prefix, true)
    let local_name = self.xml[local_start:attribute.name_end]
    guard expected_indices.get(namespace_uri) is Some(namespace_indices) &&
      namespace_indices.get(local_name.to_owned()) is Some(index) else {
      return None
    }
    values[index] = decode_xml_attribute(
      self.xml[attribute.value_start:attribute.value_end],
      cancelled=self.cancelled,
    )
    matched += 1
  }
  if matched == expected.length() {
    Some(values)
  } else {
    None
  }
}

///|
priv struct XmlExpandedAttributeName {
  namespace_uri : String
  namespace_id : Int
  local_name : String
}

///|
/// Enumerates non-namespace-declaration attributes by expanded name. Scanner
/// validation has already bounded the start-tag attribute count and rejected
/// duplicate expanded names before this helper is called.
fn XmlStartTagScanner::expanded_attribute_names(
  self : XmlStartTagScanner,
) -> Array[XmlExpandedAttributeName] raise ParseXmlError {
  let output : Array[XmlExpandedAttributeName] = []
  let mut next = self.current_name_end
  while next_xml_attribute(
          self.xml,
          next,
          self.current_tag_end,
          cancelled=self.cancelled,
        )
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
    let (namespace_uri, namespace_id) = self.resolve_prefix_identity(
      prefix, true,
    )
    output.push({
      namespace_uri,
      namespace_id,
      local_name: self.xml[local_start:attribute.name_end].to_owned(),
    })
  }
  output
}

///|
/// Reports whether the current element has no element or non-whitespace text
/// content. The scanner still performs the authoritative closing-tag and XML
/// validation as iteration continues; this helper only enforces schema
/// declarations whose content model is empty.
fn XmlStartTagScanner::current_element_content_is_empty(
  self : XmlStartTagScanner,
) -> Bool raise ParseXmlError {
  if self.current_self_closing {
    return true
  }
  let mut index = self.current_tag_end + 1
  let mut next_checkpoint = index
  while index < self.xml.length() {
    if index >= next_checkpoint {
      check_xml_cancelled(self.cancelled)
      next_checkpoint = index + 4096
    }
    let unit = self.xml[index]
    if is_attr_space(unit) {
      index = index + 1
      continue
    }
    if unit == ('&' : UInt16) {
      let entity_end = match
        find_xml_sequence(self.xml, index + 1, ";", cancelled=self.cancelled) {
        Some(value) => value
        None => raise InvalidXml(msg="XML entity is not closed")
      }
      let character = match xml_entity_value(self.xml[index + 1:entity_end]) {
        Some(value) => value
        None => raise InvalidXml(msg="XML entity is invalid")
      }
      if character != ' ' &&
        character != '\t' &&
        character != '\n' &&
        character != '\r' {
        return false
      }
      index = entity_end + 1
      continue
    }
    if unit != ('<' : UInt16) || index + 1 >= self.xml.length() {
      return false
    }
    if self.xml[index + 1] == ('/' : UInt16) {
      return true
    }
    if index + 4 <= self.xml.length() &&
      xml_span_equals(self.xml, index, index + 4, "<!--") {
      let comment_end = match
        find_xml_sequence(self.xml, index + 4, "-->", cancelled=self.cancelled) {
        Some(value) => value
        None => raise InvalidXml(msg="XML comment is not closed")
      }
      index = comment_end + 3
      continue
    }
    if self.xml[index + 1] == ('?' : UInt16) {
      let instruction_end = match
        find_xml_sequence(self.xml, index + 2, "?>", cancelled=self.cancelled) {
        Some(value) => value
        None => raise InvalidXml(msg="XML processing instruction is not closed")
      }
      index = instruction_end + 2
      continue
    }
    if index + 9 <= self.xml.length() &&
      xml_span_equals(self.xml, index, index + 9, "<![CDATA[") {
      let cdata_end = match
        find_xml_sequence(self.xml, index + 9, "]]>", cancelled=self.cancelled) {
        Some(value) => value
        None => raise InvalidXml(msg="XML CDATA section is not closed")
      }
      for character in self.xml[index + 9:cdata_end] {
        if character != ' ' &&
          character != '\t' &&
          character != '\n' &&
          character != '\r' {
          return false
        }
      }
      index = cdata_end + 3
      continue
    }
    return false
  }
  false
}

///|
fn XmlStartTagScanner::current_namespace_declarations(
  self : XmlStartTagScanner,
) -> Array[(String, String)] {
  let output : Array[(String, String)] = []
  for binding in self.namespace_bindings {
    if binding.depth == self.current_depth {
      output.push((binding.prefix, binding.uri))
    }
  }
  output
}

///|
fn XmlStartTagScanner::remove_current_subtree(
  self : XmlStartTagScanner,
) -> Unit raise ParseXmlError {
  if self.capture_start is Some(_) {
    return
  }
  if self.current_self_closing {
    self.record_rewrite(self.current_tag_start, self.current_tag_end + 1, "")
  } else {
    self.capture_start = Some(self.current_tag_start)
    self.capture_depth = self.current_depth
  }
}

///|
fn XmlStartTagScanner::unwrap_current_element(
  self : XmlStartTagScanner,
) -> Unit raise ParseXmlError {
  self.record_rewrite(self.current_tag_start, self.current_tag_end + 1, "")
  if !self.current_self_closing {
    let index = self.open_remove_end_tags.length() - 1
    if index < 0 {
      raise InvalidXml(msg="XML unwrap state is invalid")
    }
    self.open_remove_end_tags[index] = true
  }
}

///|
fn XmlStartTagScanner::insert_current_attributes(
  self : XmlStartTagScanner,
  attributes : String,
) -> Unit raise ParseXmlError {
  if attributes != "" {
    self.record_rewrite(
      self.current_attribute_insert,
      self.current_attribute_insert,
      attributes,
    )
  }
}

///|
fn XmlStartTagScanner::finish_rewritten_xml(
  self : XmlStartTagScanner,
) -> String raise ParseXmlError {
  if self.rewrite_count == 0 {
    if self.xml.length() > self.rewrite_output_limit {
      raise InvalidXml(msg="XML canonical output limit exceeded")
    }
    return self.xml.to_owned()
  }
  self.charge_rewrite_output(self.xml.length() - self.rewrite_cursor)
  self.write_rewrite_source(self.rewrite_cursor, self.xml.length())
  self.rewrite_output.to_string()
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
test "start tag scanner exposes expanded parent names" {
  let scanner = XmlStartTagScanner::new(
    (
      #|<s:root xmlns:s="urn:sheet"><s:items><s:item/><s:item><s:value/></s:item></s:items></s:root>
    ),
  )
  assert_true(scanner.next())
  assert_true(scanner.parent_local_name() is None)
  assert_true(scanner.next())
  assert_true(scanner.parent_local_name() is Some("root"))
  debug_inspect(scanner.parent_namespace_uri(), content="Some(\"urn:sheet\")")
  assert_true(scanner.next())
  assert_true(scanner.parent_local_name() is Some("items"))
  assert_true(scanner.next())
  assert_true(scanner.parent_local_name() is Some("items"))
  assert_true(scanner.next())
  assert_true(scanner.parent_local_name() is Some("item"))
}

///|
test "expanded-name subtree removal preserves text and other namespaces" {
  let xml =
    #|<s:root xmlns:s="urn:sheet" xmlns:x="urn:extension"><![CDATA[<s:extLst/>]]><x:extLst><s:value/></x:extLst><s:extLst><s:extLst><s:ignored/></s:extLst></s:extLst><s:value/></s:root>
  debug_inspect(
    remove_xml_expanded_name_subtrees(xml, ["urn:sheet"], "extLst"),
    content=(
      #|Some("<s:root xmlns:s=\"urn:sheet\" xmlns:x=\"urn:extension\"><![CDATA[<s:extLst/>]]><x:extLst><s:value/></x:extLst><s:value/></s:root>")
    ),
  )
  let without_extension =
    #|<s:root xmlns:s="urn:sheet"><s:value/></s:root>
  debug_inspect(
    remove_xml_expanded_name_subtrees(
      without_extension,
      ["urn:sheet"],
      "extLst",
    ),
    content="None",
  )
}

///|
test "foreign namespace subtree removal preserves only the core dialect" {
  let xml =
    #|<s:root xmlns:s="urn:sheet" xmlns:x="urn:extension"><s:value>core</s:value><x:value><s:value>nested</s:value></x:value><value xmlns="urn:other">foreign</value></s:root>
  debug_inspect(
    remove_xml_foreign_namespace_subtrees(xml, ["urn:sheet"]),
    content=(
      #|Some("<s:root xmlns:s=\"urn:sheet\" xmlns:x=\"urn:extension\"><s:value>core</s:value></s:root>")
    ),
  )
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
      _ => fail("unexpected scanner cancellation")
    } noraise {
      _ => fail("expected invalid namespace-qualified XML")
    }
  }
}

///|
test "start tag scanner rejects malformed character data" {
  for xml in ["<root>&bogus;</root>", "<root>bad]]></root>"] {
    let scanner = XmlStartTagScanner::new(xml)
    try {
      while scanner.next() {

      }
    } catch {
      InvalidXml(_) => ()
      _ => fail("unexpected character-data cancellation")
    } noraise {
      _ => fail("expected malformed character data rejection")
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
  inspect(decode_xml_attribute("a\r\nb"), content="a b")
  for value in ["&unknown;", "&#0;", "&#xD800;", "&#X31;", "&amp"] {
    try decode_xml_attribute(value) catch {
      InvalidXml(_) => ()
      _ => fail("unexpected attribute cancellation")
    } noraise {
      _ => fail("expected invalid XML entity")
    }
  }
}

///|
test "start tag scanner validates unused attributes and document structure" {
  for
    xml in [
      "<root unused='&bogus;'/>", "<root/ garbage>", "<root/><second/>", "text<root/>",
      "<![CDATA[text]]><root/>", "<root first='1'second='2'/>",
    ] {
    let scanner = XmlStartTagScanner::new(xml)
    try {
      while scanner.next() {

      }
    } catch {
      InvalidXml(_) => ()
      _ => fail("unexpected scanner cancellation")
    } noraise {
      _ => fail("expected malformed XML document")
    }
  }
}

///|
test "start tag scanner validates declarations, PI targets, and comments" {
  let valid = XmlStartTagScanner::new(
    "<?xml version='1.0' encoding='UTF-8' standalone='yes'?><root><?probe ok?></root>",
  )
  assert_true(valid.next())
  assert_false(valid.next())

  for
    xml in [
      "<root><?xml version='1.0'?></root>", "<?XML version='1.0'?><root/>", "<?xml encoding='UTF-8'?><root/>",
      "<?xml version='1.0'encoding='UTF-8'?><root/>", "<?1probe?><root/>", "<?xml version=\"1.0\"/?><root/>",
      "<root><!--a--b--></root>", "<root><!--a---></root>",
    ] {
    let scanner = XmlStartTagScanner::new(xml)
    try {
      while scanner.next() {

      }
    } catch {
      InvalidXml(_) => ()
      _ => fail("unexpected markup validation cancellation")
    } noraise {
      _ => fail("expected invalid XML markup")
    }
  }
}

///|
test "start tag scanner rejects a misplaced self-closing slash" {
  let scanner = XmlStartTagScanner::new("<root / bad='1'>x</root>")
  try scanner.next() catch {
    InvalidXml(msg~) =>
      inspect(msg, content="XML self-closing slash is misplaced")
    _ => fail("unexpected scanner cancellation")
  } noraise {
    _ => fail("expected misplaced self-closing slash")
  }
}

///|
test "namespace duplicate checks retain namespace identities once" {
  let attributes = StringBuilder::new()
  for index in 0..<4095 {
    attributes.write_string(" p:a\{index}='v'")
  }
  let scanner = XmlStartTagScanner::new(
    "<root xmlns:p='" +
    "u".repeat(100_000) +
    "'" +
    attributes.to_string() +
    "/>",
  )
  assert_true(scanner.next())
  assert_eq(scanner.depth(), 1)
  assert_false(scanner.next())
}

///|
test "start tag scanner extracts exact expanded attributes" {
  let scanner = XmlStartTagScanner::new(
    "<root xmlns:p='urn:rel'><p:item id='7' p:name='A&amp;B'/></root>",
  )
  assert_true(scanner.next())
  assert_true(scanner.next())
  guard scanner.exact_attribute_values([("", "id"), ("urn:rel", "name")])
    is Some(values) else {
    fail("expected exact expanded attributes")
  }
  assert_eq(values, ["7", "A&B"])
  assert_true(scanner.exact_attribute_values([("", "id")]) is None)
  assert_true(scanner.exact_attribute_values([("", "id"), ("", "id")]) is None)
}

///|
test "start tag scanner reports intervening character data" {
  let scanner = XmlStartTagScanner::new(
    "<root><first> \t<![CDATA[\n]]></first><second/>text<third/></root>",
  )
  assert_true(scanner.next())
  assert_true(scanner.intervening_character_data_is_whitespace())
  assert_true(scanner.next())
  assert_true(scanner.intervening_character_data_is_whitespace())
  assert_true(scanner.next())
  assert_true(scanner.intervening_character_data_is_whitespace())
  assert_true(scanner.next())
  assert_false(scanner.intervening_character_data_is_whitespace())
  assert_false(scanner.next())
  assert_true(scanner.intervening_character_data_is_whitespace())
}

///|
test "namespace lookup stays bounded with many bindings and prefixed elements" {
  let xml = StringBuilder::new()
  xml.write_string("<root xmlns:p0='urn:sheet'")
  for index in 1..<4095 {
    xml.write_string(" xmlns:p\{index}='urn:unused:\{index}'")
  }
  xml.write_char('>')
  for _ in 0..<20_000 {
    xml.write_string("<p0:item/>")
  }
  xml.write_string("</root>")
  let scanner = XmlStartTagScanner::new(xml.to_string())
  let mut elements = 0
  while scanner.next() {
    elements += 1
  }
  assert_eq(elements, 20_001)
}

///|
test "expanded-name canonicalization neutralizes non-element markup" {
  let xml =
    #|<?probe fake="<s:item/>"?><s:root xmlns:s="urn:sheet" xmlns:q="urn:rel"><!-- <s:item/> --><s:item q:id="r1"><![CDATA[<s:literal/>&value]]></s:item></s:root>
  let canonical = canonicalize_xml_expanded_names(xml, ["urn:sheet"], [
    ("urn:rel", "r"),
  ])
  inspect(
    canonical,
    content=(
      #|<root xmlns:s="urn:sheet" xmlns:q="urn:rel"><item r:id="r1">&lt;s:literal/>&amp;value</item></root>
    ),
  )
}

///|
test "expanded-name canonicalization rejects lexical attribute collisions" {
  let xml =
    #|<s:root xmlns:s="urn:sheet" xmlns:p="urn:rel:one" xmlns:q="urn:rel:two" p:id="one" q:id="two"/>
  try
    canonicalize_xml_expanded_names(xml, ["urn:sheet"], [
      ("urn:rel:one", "r"),
      ("urn:rel:two", "r"),
    ])
  catch {
    InvalidXml(msg~) =>
      inspect(msg, content="XML canonical attribute name collision")
    _ => fail("unexpected canonicalization cancellation")
  } noraise {
    _ => fail("expected canonical attribute collision")
  }
}

///|
test "expanded-name canonicalization maps extensions and defangs reserved prefix aliases" {
  let xml =
    #|<s:root xmlns:s="urn:sheet" xmlns:e="urn:extension" xmlns:m="urn:math" xmlns:x14="urn:foreign" xmlns:q="urn:rel" xmlns:r="urn:foreign-rel"><e:item q:id="office" r:id="foreign"><m:f>1</m:f></e:item><x14:item/></s:root>
  inspect(
    canonicalize_xml_expanded_names(xml, ["urn:sheet"], [("urn:rel", "r")], element_prefixes=[
      ("urn:extension", "x14"),
      ("urn:math", "xm"),
    ]),
    content=(
      #|<root xmlns:s="urn:sheet" xmlns:e="urn:extension" xmlns:m="urn:math" xmlns:x14="urn:foreign" xmlns:q="urn:rel" xmlns:r="urn:foreign-rel"><x14:item r:id="office" _foreign_r_id="foreign"><xm:f>1</xm:f></x14:item><_foreign_x14_item/></root>
    ),
  )
}

///|
test "expanded-name canonicalization bounds escaped CDATA output" {
  try
    canonicalize_xml_expanded_names(
      "<root><![CDATA[&&&&]]></root>",
      [],
      [],
      max_output_chars=20,
    )
  catch {
    InvalidXml(msg~) =>
      inspect(msg, content="XML canonical output limit exceeded")
    _ => fail("unexpected canonicalization cancellation")
  } noraise {
    _ => fail("expected canonical output limit")
  }
}

///|
test "strict start-tag scanning rejects XML-invalid controls in CDATA" {
  let xml = "<root><![CDATA[ok\u{1}bad]]></root>"
  let scanner = XmlStartTagScanner::new(xml)
  try {
    while scanner.next() {

    }
  } catch {
    InvalidXml(msg~) =>
      assert_eq(msg, "XML markup contains an invalid character")
    _ => fail("unexpected CDATA validation error")
  } noraise {
    _ => fail("XML-invalid CDATA control was accepted")
  }
}

///|
test "start tag scanner bounds qualified names" {
  let scanner = XmlStartTagScanner::new("<" + "a".repeat(1025) + "/>")
  try scanner.next() catch {
    InvalidXml(msg~) => inspect(msg, content="XML qualified name is too long")
    _ => fail("unexpected scanner cancellation")
  } noraise {
    _ => fail("expected qualified-name limit")
  }
}

///|
test "start tag scanner enforces XML Unicode name ranges" {
  for xml in ["<·bad/>", "<‿bad/>"] {
    let scanner = XmlStartTagScanner::new(xml)
    try scanner.next() catch {
      InvalidXml(msg~) => inspect(msg, content="XML qualified name is invalid")
      _ => fail("unexpected scanner cancellation")
    } noraise {
      _ => fail("expected invalid XML qualified name")
    }
  }
  for xml in ["<é/>", "<𐀀/>", "<a·b/>"] {
    let scanner = XmlStartTagScanner::new(xml)
    assert_true(scanner.next())
    assert_false(scanner.next())
  }
}

///|
test "expanded-name canonicalization polls cancellation inside long XML" {
  let checks = [0]
  let xml = "<root>" + "x".repeat(32 * 1024) + "</root>"
  try
    canonicalize_xml_expanded_names(xml, [], [], cancelled=() => {
      checks[0] += 1
      checks[0] >= 12
    })
  catch {
    ReadCancelled => assert_true(checks[0] >= 12)
    _ => fail("expected canonicalization cancellation")
  } noraise {
    _ => fail("expected canonicalization cancellation")
  }
}
