///|
/// The document formats supported by the `office` facade.
pub(all) enum DocumentFormat {
  Xlsx
  Docx
} derive(Debug, Eq)

///|
/// A deterministic, lowercase name suitable for CLI and JSON output.
pub fn DocumentFormat::name(self : DocumentFormat) -> String {
  match self {
    Xlsx => "xlsx"
    Docx => "docx"
  }
}

///|
pub impl Show for DocumentFormat with fn output(self, logger) {
  logger.write_string(self.name())
}

///|
/// Errors produced while identifying a supported Office package.
pub(all) suberror OfficeError {
  UnsupportedFileExtension(String)
  InvalidPackage(String)
  FormatMismatch(expected~ : DocumentFormat, actual~ : DocumentFormat)
} derive(Debug, Eq)

///|
pub impl Show for OfficeError with fn output(self, logger) {
  match self {
    UnsupportedFileExtension(path) =>
      logger.write_string(
        "unsupported file extension for '\{path}' (expected .xlsx or .docx)",
      )
    InvalidPackage(message) =>
      logger.write_string("invalid Office package: " + message)
    FormatMismatch(expected~, actual~) =>
      logger.write_string(
        "file extension says \{expected.name()}, but package content is \{actual.name()}",
      )
  }
}

///|
const XLSX_MAIN_CONTENT_TYPE : String = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"

///|
const DOCX_MAIN_CONTENT_TYPE : String = "application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"

///|
const CONTENT_TYPES_ROOT : String = "{http://schemas.openxmlformats.org/package/2006/content-types}Types"

///|
const CONTENT_TYPES_OVERRIDE : String = "{http://schemas.openxmlformats.org/package/2006/content-types}Override"

///|
const CONTENT_TYPES_DEFAULT : String = "{http://schemas.openxmlformats.org/package/2006/content-types}Default"

///|
const RELATIONSHIPS_ROOT : String = "{http://schemas.openxmlformats.org/package/2006/relationships}Relationships"

///|
const RELATIONSHIP_ELEMENT : String = "{http://schemas.openxmlformats.org/package/2006/relationships}Relationship"

///|
const RELATIONSHIPS_CONTENT_TYPE : String = "application/vnd.openxmlformats-package.relationships+xml"

///|
const TRANSITIONAL_OFFICE_DOCUMENT_REL : String = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument"

///|
const STRICT_OFFICE_DOCUMENT_REL : String = "http://purl.oclc.org/ooxml/officeDocument/relationships/officeDocument"

///|
const TRANSITIONAL_WORKBOOK_ROOT : String = "{http://schemas.openxmlformats.org/spreadsheetml/2006/main}workbook"

///|
const STRICT_WORKBOOK_ROOT : String = "{http://purl.oclc.org/ooxml/spreadsheetml/main}workbook"

///|
const TRANSITIONAL_DOCUMENT_ROOT : String = "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}document"

///|
const STRICT_DOCUMENT_ROOT : String = "{http://purl.oclc.org/ooxml/wordprocessingml/main}document"

///|
fn media_type_equal(left : StringView, right : StringView) -> Bool {
  left.to_owned().to_lower() == right.to_owned().to_lower()
}

///|
fn is_media_type_token_char(char : Char) -> Bool {
  char.is_ascii_alphabetic() ||
  char.is_ascii_digit() ||
  char == '!' ||
  char == '#' ||
  char == '$' ||
  char == '%' ||
  char == '&' ||
  char.to_int() == 0x27 ||
  char == '*' ||
  char == '+' ||
  char == '-' ||
  char == '.' ||
  char == '^' ||
  char == '_' ||
  char == '`' ||
  char == '|' ||
  char == '~'
}

///|
fn is_media_type_quoted_char(char : Char) -> Bool {
  let code = char.to_int()
  char == '\t' ||
  char == ' ' ||
  code == 0x21 ||
  (code >= 0x23 && code <= 0x5b) ||
  (code >= 0x5d && code <= 0x7e) ||
  (code >= 0x80 && code <= 0xff)
}

///|
fn is_media_type_quoted_pair_char(char : Char) -> Bool {
  let code = char.to_int()
  char == '\t' ||
  char == ' ' ||
  (code >= 0x21 && code <= 0x7e) ||
  (code >= 0x80 && code <= 0xff)
}

///|
// RFC 7230 token and quoted-string rules, composed as the RFC 7231 media-type
// grammar. OPC uses this syntax for every Default and Override declaration.
fn is_valid_media_type(value : StringView) -> Bool {
  let chars = value.to_array()
  let mut index = 0
  while index < chars.length() && is_media_type_token_char(chars[index]) {
    index = index + 1
  }
  if index == 0 || index >= chars.length() || chars[index] != '/' {
    return false
  }
  index = index + 1
  let subtype_start = index
  while index < chars.length() && is_media_type_token_char(chars[index]) {
    index = index + 1
  }
  if index == subtype_start {
    return false
  }
  while index < chars.length() {
    while index < chars.length() &&
          (chars[index] == ' ' || chars[index] == '\t') {
      index = index + 1
    }
    if index >= chars.length() || chars[index] != ';' {
      return false
    }
    index = index + 1
    while index < chars.length() &&
          (chars[index] == ' ' || chars[index] == '\t') {
      index = index + 1
    }
    let parameter_start = index
    while index < chars.length() && is_media_type_token_char(chars[index]) {
      index = index + 1
    }
    if index == parameter_start ||
      index >= chars.length() ||
      chars[index] != '=' {
      return false
    }
    index = index + 1
    if index < chars.length() && chars[index] == '"' {
      index = index + 1
      let mut closed = false
      while index < chars.length() {
        if chars[index] == '"' {
          closed = true
          index = index + 1
          break
        }
        if chars[index] == '\\' {
          index = index + 1
          if index >= chars.length() ||
            !is_media_type_quoted_pair_char(chars[index]) {
            return false
          }
        } else if !is_media_type_quoted_char(chars[index]) {
          return false
        }
        index = index + 1
      }
      if !closed {
        return false
      }
    } else {
      let value_start = index
      while index < chars.length() && is_media_type_token_char(chars[index]) {
        index = index + 1
      }
      if index == value_start {
        return false
      }
    }
  }
  true
}

///|
fn main_format_from_content_type(content_type : StringView) -> DocumentFormat? {
  if media_type_equal(content_type, XLSX_MAIN_CONTENT_TYPE) {
    Some(Xlsx)
  } else if media_type_equal(content_type, DOCX_MAIN_CONTENT_TYPE) {
    Some(Docx)
  } else {
    None
  }
}

///|
fn xml_element_has_content(element : @xml.XmlElement) -> Bool {
  for child in element.children {
    match child {
      XmlElement(_) => return true
      XmlText(text) => if !text.trim().is_empty() { return true }
    }
  }
  false
}

///|
fn xml_element_has_child_element(element : @xml.XmlElement) -> Bool {
  element.children.any(child => child is XmlElement(_))
}

///|
fn format_from_extension(path : StringView) -> DocumentFormat raise OfficeError {
  let lower = path.to_owned().to_lower()
  if lower.has_suffix(".xlsx") {
    Xlsx
  } else if lower.has_suffix(".docx") {
    Docx
  } else {
    raise UnsupportedFileExtension(path.to_owned())
  }
}

///|
fn opc_part_key(name : StringView) -> String {
  @opc.part_name_key(name)
}

///|
priv struct ArchivePartIndex {
  exact : StableStringMap[BytesView]
  canonical : StableStringMap[BytesView]
}

///|
priv struct DecodedXmlPart {
  text : String
  source_encoding : @xml.XmlSourceEncoding
  source_units : Int
}

///|
fn archive_entry_logical_part_name(name : StringView) -> String? {
  if name == "[Content_Types].xml" {
    Some("[Content_Types].xml")
  } else {
    @opc.logical_part_name_from_zip_item_name(name)
  }
}

///|
fn archive_part_index(archive : @zip.Archive) -> ArchivePartIndex {
  let exact : StableStringMap[BytesView] = SortedMap([])
  let canonical : StableStringMap[BytesView] = SortedMap([])
  for entry in archive.entries() {
    let physical_name = entry.name()
    let logical_name = archive_entry_logical_part_name(physical_name)
    guard logical_name is Some(name) else { continue }
    if !exact.contains(name) {
      exact[name] = entry.data()
    }
    let key = opc_part_key(name)
    if !canonical.contains(key) {
      canonical[key] = entry.data()
    }
  }
  { exact, canonical }
}

///|
fn ArchivePartIndex::find(self : ArchivePartIndex, name : String) -> BytesView? {
  match self.exact.get(name) {
    Some(bytes) => Some(bytes)
    None => self.canonical.get(opc_part_key(name))
  }
}

///|
fn decode_xml_part(
  parts : ArchivePartIndex,
  name : String,
) -> DecodedXmlPart raise OfficeError {
  let bytes = match parts.find(name) {
    Some(bytes) => bytes
    None => raise InvalidPackage("missing required part: \{name}")
  }
  let (text, source_encoding) : (String, @xml.XmlSourceEncoding) = if bytes.length() >=
    2 &&
    bytes[0] == 0xff &&
    bytes[1] == 0xfe {
    (
      @utf16.decode(bytes, ignore_bom=true) catch {
        _ =>
          raise InvalidPackage("\{name} is not valid UTF-8 or UTF-16 XML text")
      },
      Utf16LittleEndianWithBom,
    )
  } else if bytes.length() >= 2 && bytes[0] == 0xfe && bytes[1] == 0xff {
    (
      @utf16.decode(bytes, ignore_bom=true, endianness=Big) catch {
        _ =>
          raise InvalidPackage("\{name} is not valid UTF-8 or UTF-16 XML text")
      },
      Utf16BigEndianWithBom,
    )
  } else if bytes.length() >= 2 && bytes[0] == b'<' && bytes[1] == 0x00 {
    (
      @utf16.decode(bytes) catch {
        _ =>
          raise InvalidPackage("\{name} is not valid UTF-8 or UTF-16 XML text")
      },
      Utf16LittleEndian,
    )
  } else if bytes.length() >= 2 && bytes[0] == 0x00 && bytes[1] == b'<' {
    (
      @utf16.decode(bytes, endianness=Big) catch {
        _ =>
          raise InvalidPackage("\{name} is not valid UTF-8 or UTF-16 XML text")
      },
      Utf16BigEndian,
    )
  } else {
    (
      @utf8.decode(bytes, ignore_bom=true) catch {
        _ =>
          raise InvalidPackage("\{name} is not valid UTF-8 or UTF-16 XML text")
      },
      Utf8,
    )
  }
  { text, source_encoding, source_units: bytes.length() }
}

///|
fn read_xml_part(
  parts : ArchivePartIndex,
  name : String,
) -> @xml.XmlElement raise OfficeError {
  let decoded = decode_xml_part(parts, name)
  @xml.read_xml_string_strict_encoded(decoded.text, decoded.source_encoding) catch {
    _ => raise InvalidPackage("\{name} is not well-formed XML")
  }
}

///|
fn input_linear_xml_budget(decoded : DecodedXmlPart) -> @xml.XmlReadBudget {
  let source_units = if decoded.source_units > decoded.text.length() {
    decoded.source_units
  } else {
    decoded.text.length()
  }
  let scaled = source_units.to_int64() * 32L
  let allowance = if scaled <= 0L {
    1
  } else if scaled > 2147483647L {
    2147483647
  } else {
    scaled.to_int()
  }
  @xml.xml_read_budget(
    max_source_units=source_units,
    max_tokens=allowance,
    max_materialized_chars=allowance,
    max_token_chars=if source_units > 0 { source_units } else { 1 },
  )
}

///|
fn read_relationships_part(
  parts : ArchivePartIndex,
  name : String,
) -> @xml.XmlElement raise OfficeError {
  let decoded = decode_xml_part(parts, name)
  @opc.read_opc_relationships_string_encoded_limited(
    decoded.text,
    decoded.source_encoding,
    input_linear_xml_budget(decoded),
  ) catch {
    _ => raise InvalidPackage("\{name} is not well-formed XML")
  }
}

///|
fn has_uri_scheme(target : StringView) -> Bool {
  let mut index = 0
  for char in target {
    if char == ':' {
      return index > 0
    }
    if char == '/' || char == '?' || char == '#' {
      return false
    }
    let valid = if index == 0 {
      char.is_ascii_alphabetic()
    } else {
      char.is_ascii_alphabetic() ||
      char.is_ascii_digit() ||
      char == '+' ||
      char == '-' ||
      char == '.'
    }
    if !valid {
      return false
    }
    index = index + 1
  }
  false
}

///|
fn is_ascii_hex_digit(char : Char) -> Bool {
  (char >= '0' && char <= '9') ||
  (char >= 'A' && char <= 'F') ||
  (char >= 'a' && char <= 'f')
}

///|
fn is_uri_unreserved(char : Char) -> Bool {
  char.is_ascii_alphabetic() ||
  char.is_ascii_digit() ||
  char == '-' ||
  char == '.' ||
  char == '_' ||
  char == '~'
}

///|
fn is_uri_sub_delimiter(char : Char) -> Bool {
  char == '!' ||
  char == '$' ||
  char == '&' ||
  char.to_int() == 0x27 ||
  char == '(' ||
  char == ')' ||
  char == '*' ||
  char == '+' ||
  char == ',' ||
  char == ';' ||
  char == '='
}

///|
fn is_uri_pchar(char : Char) -> Bool {
  is_uri_unreserved(char) ||
  is_uri_sub_delimiter(char) ||
  char == ':' ||
  char == '@'
}

///|
fn is_uri_query_or_fragment_char(char : Char) -> Bool {
  is_uri_pchar(char) || char == '/' || char == '?'
}

///|
fn is_uri_userinfo_char(char : Char) -> Bool {
  is_uri_unreserved(char) || is_uri_sub_delimiter(char) || char == ':'
}

///|
fn is_uri_reg_name_char(char : Char) -> Bool {
  is_uri_unreserved(char) || is_uri_sub_delimiter(char)
}

///|
fn is_iri_ucschar(char : Char) -> Bool {
  let code = char.to_int()
  (code >= 0xa0 && code <= 0xd7ff) ||
  (code >= 0xf900 && code <= 0xfdcf) ||
  (code >= 0xfdf0 && code <= 0xffef) ||
  (code >= 0x10000 && code <= 0x1fffd) ||
  (code >= 0x20000 && code <= 0x2fffd) ||
  (code >= 0x30000 && code <= 0x3fffd) ||
  (code >= 0x40000 && code <= 0x4fffd) ||
  (code >= 0x50000 && code <= 0x5fffd) ||
  (code >= 0x60000 && code <= 0x6fffd) ||
  (code >= 0x70000 && code <= 0x7fffd) ||
  (code >= 0x80000 && code <= 0x8fffd) ||
  (code >= 0x90000 && code <= 0x9fffd) ||
  (code >= 0xa0000 && code <= 0xafffd) ||
  (code >= 0xb0000 && code <= 0xbfffd) ||
  (code >= 0xc0000 && code <= 0xcfffd) ||
  (code >= 0xd0000 && code <= 0xdfffd) ||
  (code >= 0xe1000 && code <= 0xefffd)
}

///|
fn is_iri_private(char : Char) -> Bool {
  let code = char.to_int()
  (code >= 0xe000 && code <= 0xf8ff) ||
  (code >= 0xf0000 && code <= 0xffffd) ||
  (code >= 0x100000 && code <= 0x10fffd)
}

///|
fn is_iri_unreserved(char : Char) -> Bool {
  is_uri_unreserved(char) || is_iri_ucschar(char)
}

///|
fn is_iri_pchar(char : Char) -> Bool {
  is_iri_unreserved(char) ||
  is_uri_sub_delimiter(char) ||
  char == ':' ||
  char == '@'
}

///|
fn is_iri_query_char(char : Char) -> Bool {
  is_iri_pchar(char) || is_iri_private(char) || char == '/' || char == '?'
}

///|
fn is_iri_fragment_char(char : Char) -> Bool {
  is_iri_pchar(char) || char == '/' || char == '?'
}

///|
fn is_iri_userinfo_char(char : Char) -> Bool {
  is_iri_unreserved(char) || is_uri_sub_delimiter(char) || char == ':'
}

///|
fn is_iri_reg_name_char(char : Char) -> Bool {
  is_iri_unreserved(char) || is_uri_sub_delimiter(char)
}

///|
fn is_valid_uri_chars(
  chars : ArrayView[Char],
  start : Int,
  end : Int,
  allowed : (Char) -> Bool,
) -> Bool {
  let mut index = start
  while index < end {
    if chars[index] == '%' {
      if index + 2 >= end ||
        !is_ascii_hex_digit(chars[index + 1]) ||
        !is_ascii_hex_digit(chars[index + 2]) {
        return false
      }
      index = index + 3
    } else {
      if !allowed(chars[index]) {
        return false
      }
      index = index + 1
    }
  }
  true
}

///|
fn is_valid_ipv4_literal(
  chars : ArrayView[Char],
  start : Int,
  end : Int,
) -> Bool {
  let mut index = start
  let mut components = 0
  while index < end {
    if components == 4 {
      return false
    }
    let component_start = index
    let mut value = 0
    while index < end && chars[index].is_ascii_digit() {
      value = value * 10 + chars[index].to_int() - '0'.to_int()
      index = index + 1
    }
    let digits = index - component_start
    if digits == 0 ||
      digits > 3 ||
      value > 255 ||
      (digits > 1 && chars[component_start] == '0') {
      return false
    }
    components = components + 1
    if index == end {
      break
    }
    if chars[index] != '.' {
      return false
    }
    index = index + 1
  }
  components == 4
}

///|
// RFC 3986 IP-literal validation. A compressed `::` must replace at least one
// 16-bit group; an IPv4 tail occupies the final two groups.
fn is_valid_ipv6_literal(
  chars : ArrayView[Char],
  start : Int,
  end : Int,
) -> Bool {
  if start >= end {
    return false
  }
  let mut index = start
  let mut groups = 0
  let mut compressed = false
  if chars[index] == ':' {
    if index + 1 >= end || chars[index + 1] != ':' {
      return false
    }
    compressed = true
    index = index + 2
    if index == end {
      return true
    }
  }
  while index < end {
    let group_start = index
    let mut has_dot = false
    while index < end && chars[index] != ':' {
      if chars[index] == '.' {
        has_dot = true
      }
      index = index + 1
    }
    if has_dot {
      if index != end || !is_valid_ipv4_literal(chars, group_start, end) {
        return false
      }
      groups = groups + 2
    } else {
      let digits = index - group_start
      if digits == 0 || digits > 4 {
        return false
      }
      for digit_index = group_start
          digit_index < index
          digit_index = digit_index + 1 {
        if !is_ascii_hex_digit(chars[digit_index]) {
          return false
        }
      }
      groups = groups + 1
    }
    if index == end {
      break
    }
    if index + 1 < end && chars[index + 1] == ':' {
      if compressed {
        return false
      }
      compressed = true
      index = index + 2
      if index == end {
        break
      }
    } else {
      index = index + 1
      if index == end {
        return false
      }
    }
  }
  if compressed {
    groups < 8
  } else {
    groups == 8
  }
}

///|
fn is_valid_ipv_future_literal(
  chars : ArrayView[Char],
  start : Int,
  end : Int,
) -> Bool {
  if start >= end || (chars[start] != 'v' && chars[start] != 'V') {
    return false
  }
  let mut index = start + 1
  let version_start = index
  while index < end && is_ascii_hex_digit(chars[index]) {
    index = index + 1
  }
  if index == version_start || index >= end || chars[index] != '.' {
    return false
  }
  index = index + 1
  let address_start = index
  while index < end &&
        (
          is_uri_unreserved(chars[index]) ||
          is_uri_sub_delimiter(chars[index]) ||
          chars[index] == ':'
        ) {
    index = index + 1
  }
  index == end && index > address_start
}

///|
fn is_valid_uri_authority(
  chars : ArrayView[Char],
  start : Int,
  end : Int,
  allow_iri_chars : Bool,
) -> Bool {
  let mut host_start = start
  let mut userinfo_at = -1
  for index = start; index < end; index = index + 1 {
    if chars[index] == '@' {
      if userinfo_at >= 0 {
        return false
      }
      userinfo_at = index
    }
  }
  if userinfo_at >= 0 {
    let valid_userinfo = if allow_iri_chars {
      is_valid_uri_chars(chars, start, userinfo_at, is_iri_userinfo_char)
    } else {
      is_valid_uri_chars(chars, start, userinfo_at, is_uri_userinfo_char)
    }
    if !valid_userinfo {
      return false
    }
    host_start = userinfo_at + 1
  }
  if host_start < end && chars[host_start] == '[' {
    let mut close = -1
    for index = host_start + 1; index < end; index = index + 1 {
      if chars[index] == ']' {
        close = index
        break
      }
    }
    if close < 0 ||
      (
        !is_valid_ipv6_literal(chars, host_start + 1, close) &&
        !is_valid_ipv_future_literal(chars, host_start + 1, close)
      ) {
      return false
    }
    if close + 1 == end {
      return true
    }
    if chars[close + 1] != ':' {
      return false
    }
    for index = close + 2; index < end; index = index + 1 {
      if !chars[index].is_ascii_digit() {
        return false
      }
    }
    return true
  }
  let mut port_at = -1
  for index = host_start; index < end; index = index + 1 {
    if chars[index] == ':' {
      if port_at >= 0 {
        return false
      }
      port_at = index
    } else if chars[index] == '[' || chars[index] == ']' {
      return false
    }
  }
  let host_end = if port_at >= 0 { port_at } else { end }
  let valid_reg_name = if allow_iri_chars {
    is_valid_uri_chars(chars, host_start, host_end, is_iri_reg_name_char)
  } else {
    is_valid_uri_chars(chars, host_start, host_end, is_uri_reg_name_char)
  }
  if !valid_reg_name {
    return false
  }
  if port_at >= 0 {
    for index = port_at + 1; index < end; index = index + 1 {
      if !chars[index].is_ascii_digit() {
        return false
      }
    }
  }
  true
}

///|
fn is_valid_uri_scheme(chars : ArrayView[Char], start : Int, end : Int) -> Bool {
  if start >= end || !chars[start].is_ascii_alphabetic() {
    return false
  }
  for index = start + 1; index < end; index = index + 1 {
    let char = chars[index]
    if !char.is_ascii_alphabetic() &&
      !char.is_ascii_digit() &&
      char != '+' &&
      char != '-' &&
      char != '.' {
      return false
    }
  }
  true
}

///|
// RFC 3986 URI references and RFC 3987 IRI references have the same component
// structure. IRI mode additionally permits `ucschar` in the components named
// by RFC 3987 and `iprivate` in the query only.
fn is_valid_resource_identifier_reference(
  value : StringView,
  allow_iri_chars : Bool,
) -> Bool {
  if value == "" {
    return false
  }
  let chars = value.to_array()
  let mut query_at = chars.length()
  let mut fragment_at = chars.length()
  for index, char in chars {
    if char == '#' {
      if fragment_at < chars.length() {
        return false
      }
      fragment_at = index
    } else if char == '?' &&
      query_at == chars.length() &&
      fragment_at == chars.length() {
      query_at = index
    }
  }
  let hierarchy_end = if query_at < fragment_at {
    query_at
  } else {
    fragment_at
  }
  let mut scheme_at = -1
  for index = 0; index < hierarchy_end; index = index + 1 {
    if chars[index] == ':' {
      scheme_at = index
      break
    }
    if chars[index] == '/' {
      break
    }
  }
  let mut path_start = 0
  if scheme_at >= 0 {
    if !is_valid_uri_scheme(chars, 0, scheme_at) {
      return false
    }
    path_start = scheme_at + 1
  }
  if path_start + 1 < hierarchy_end &&
    chars[path_start] == '/' &&
    chars[path_start + 1] == '/' {
    let authority_start = path_start + 2
    let mut authority_end = authority_start
    while authority_end < hierarchy_end && chars[authority_end] != '/' {
      authority_end = authority_end + 1
    }
    if !is_valid_uri_authority(
        chars, authority_start, authority_end, allow_iri_chars,
      ) {
      return false
    }
    path_start = authority_end
  }
  let valid_path = if allow_iri_chars {
    is_valid_uri_chars(chars, path_start, hierarchy_end, fn(char) {
      is_iri_pchar(char) || char == '/'
    })
  } else {
    is_valid_uri_chars(chars, path_start, hierarchy_end, fn(char) {
      is_uri_pchar(char) || char == '/'
    })
  }
  if !valid_path {
    return false
  }
  let valid_query = if allow_iri_chars {
    is_valid_uri_chars(chars, query_at + 1, fragment_at, is_iri_query_char)
  } else {
    is_valid_uri_chars(
      chars,
      query_at + 1,
      fragment_at,
      is_uri_query_or_fragment_char,
    )
  }
  if query_at < chars.length() && !valid_query {
    return false
  }
  let valid_fragment = if allow_iri_chars {
    is_valid_uri_chars(
      chars,
      fragment_at + 1,
      chars.length(),
      is_iri_fragment_char,
    )
  } else {
    is_valid_uri_chars(
      chars,
      fragment_at + 1,
      chars.length(),
      is_uri_query_or_fragment_char,
    )
  }
  if fragment_at < chars.length() && !valid_fragment {
    return false
  }
  true
}

///|
fn is_valid_iri_reference(value : StringView) -> Bool {
  is_valid_resource_identifier_reference(value, true)
}

///|
fn is_valid_office_file_path_chars(
  chars : ArrayView[Char],
  start : Int,
  end : Int,
) -> Bool {
  is_valid_uri_chars(chars, start, end, fn(char) {
    is_iri_pchar(char) || char == '/' || char == '\\'
  })
}

///|
fn is_valid_office_unc_path(chars : ArrayView[Char]) -> Bool {
  if chars.length() < 5 || chars[0] != '\\' || chars[1] != '\\' {
    return false
  }
  let mut server_end = 2
  while server_end < chars.length() &&
        chars[server_end] != '\\' &&
        chars[server_end] != '/' {
    server_end = server_end + 1
  }
  if server_end == 2 ||
    server_end == chars.length() ||
    !is_valid_uri_chars(chars, 2, server_end, is_iri_reg_name_char) {
    return false
  }
  let share_start = server_end + 1
  let mut share_end = share_start
  while share_end < chars.length() &&
        chars[share_end] != '\\' &&
        chars[share_end] != '/' {
    share_end = share_end + 1
  }
  share_end > share_start &&
  is_valid_uri_chars(chars, share_start, share_end, is_iri_pchar) &&
  is_valid_office_file_path_chars(chars, share_end, chars.length())
}

///|
fn is_valid_office_windows_file_iri(value : StringView) -> Bool {
  let owned = value.to_owned()
  if !owned.to_lower().has_prefix("file:///") {
    return false
  }
  let chars = owned["file:///".length():].to_array()
  if chars.length() >= 3 &&
    chars[0].is_ascii_alphabetic() &&
    chars[1] == ':' &&
    (chars[2] == '\\' || chars[2] == '/') {
    return is_valid_office_file_path_chars(chars, 2, chars.length())
  }
  is_valid_office_unc_path(chars)
}

///|
fn is_valid_external_relationship_target(value : StringView) -> Bool {
  is_valid_iri_reference(value) || is_valid_office_windows_file_iri(value)
}

///|
fn is_absolute_relationship_type(value : StringView) -> Bool {
  has_uri_scheme(value) && is_valid_iri_reference(value) && !value.contains("#")
}

///|
fn is_xml_ncname_start(char : Char) -> Bool {
  let code = char.to_int()
  char.is_ascii_alphabetic() ||
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
fn is_xml_ncname_char(char : Char) -> Bool {
  let code = char.to_int()
  is_xml_ncname_start(char) ||
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
  if chars.length() == 0 || !is_xml_ncname_start(chars[0]) {
    return false
  }
  for index = 1; index < chars.length(); index = index + 1 {
    if !is_xml_ncname_char(chars[index]) {
      return false
    }
  }
  true
}

///|
fn normalize_internal_target(target : StringView) -> String? {
  @opc.resolve_part_target("", target)
}

///|
fn normalize_declared_part_name(part_name : StringView) -> String? {
  guard part_name.has_prefix("/") else { return None }
  guard normalize_internal_target(part_name) is Some(normalized) else {
    return None
  }
  if part_name[1:] == normalized {
    Some(normalized)
  } else {
    None
  }
}

///|
fn part_extension(name : String) -> String? {
  match name.rev_find(".") {
    Some(dot) =>
      match name.rev_find("/") {
        Some(slash) if slash > dot => None
        _ if dot + 1 < name.length() =>
          Some(name[dot + 1:].to_owned().to_lower())
        _ => None
      }
    None => None
  }
}

///|
fn relationships_base_dir(part : String) -> String? {
  match @opc.relationship_source_part_name(part) {
    Some("") => Some("")
    Some(source) =>
      match source.rev_find("/") {
        Some(slash) => Some(source[:slash + 1].to_owned())
        None => Some("")
      }
    None => None
  }
}

///|
fn resolve_relationship_target(base : String, target : StringView) -> String? {
  @opc.resolve_part_target(base, target)
}

///|
fn validate_package_structure(
  archive : @zip.Archive,
  part_index : ArchivePartIndex,
  main_part : String,
  require_main_relationships : Bool,
) -> Array[String] raise OfficeError {
  let findings : Array[String] = []
  let parts : StableStringMap[Int] = SortedMap([])
  let part_names : StableStringMap[String] = SortedMap([])
  let package_parts : StableStringMap[Bool] = SortedMap([])
  let document_parts : StableStringMap[Bool] = SortedMap([])
  let part_name_registry = @opc.PartNameRegistry::new()
  for entry in archive.entries() {
    let physical_name = entry.name()
    let is_directory = physical_name.has_suffix("/")
    let item_path = if is_directory && physical_name.length() > 0 {
      physical_name[:physical_name.length() - 1]
    } else {
      physical_name
    }
    let logical_item = if !is_directory {
      archive_entry_logical_part_name(physical_name)
    } else {
      @opc.logical_part_name_from_zip_item_name(item_path)
    }
    match logical_item {
      Some(logical_name) if !is_directory => {
        let key = opc_part_key(logical_name)
        if key != opc_part_key("[Content_Types].xml") {
          match part_name_registry.register(logical_name, physical_name) {
            Some(Derivable(existing)) =>
              findings.push(
                "part name is derivable from another part name: \{existing} and \{physical_name}",
              )
            _ => ()
          }
        }
        parts[key] = parts.get(key).unwrap_or(0) + 1
        if !part_names.contains(key) {
          part_names[key] = physical_name
        }
        if key != opc_part_key("[Content_Types].xml") {
          package_parts[key] = true
          if !@opc.is_relationship_part_name(logical_name) {
            document_parts[key] = true
          }
        }
      }
      Some(_) => ()
      None => {
        if physical_name == "" {
          findings.push("empty entry name")
          continue
        }
        if physical_name.has_prefix("/") {
          findings.push("entry name must not start with '/': \{physical_name}")
        }
        if physical_name.contains("\\") {
          findings.push("entry name contains a backslash: \{physical_name}")
        }
        let mut structural_error = false
        for segment in item_path.split("/") {
          if segment == "" {
            findings.push(
              "entry name contains an empty segment: \{physical_name}",
            )
            structural_error = true
            break
          } else if segment == "." || segment == ".." {
            findings.push(
              "entry name contains a '\{segment}' segment: \{physical_name}",
            )
            structural_error = true
            break
          }
        }
        if !structural_error {
          findings.push(
            "entry name is not a valid OPC URI path: \{physical_name}",
          )
        }
      }
    }
  }
  for key, count in parts {
    if count > 1 {
      findings.push("duplicate entry name: \{part_names[key]}")
    }
  }
  if !document_parts.contains(opc_part_key(main_part)) {
    findings.push("missing required part: \{main_part}")
  }
  let main_relationships = @opc.relationships_part_name_for_source(main_part)
  if require_main_relationships &&
    !parts.contains(opc_part_key(main_relationships)) {
    findings.push("missing required part: \{main_relationships}")
  }

  let defaults : StableStringMap[String] = SortedMap([])
  let overrides : StableStringMap[String] = SortedMap([])
  let content_types = read_xml_part(part_index, "[Content_Types].xml")
  for child in content_types.children {
    match child {
      XmlText(text) =>
        if !text.trim().is_empty() {
          findings.push("[Content_Types].xml contains unexpected text")
        }
      XmlElement(_) => ()
    }
  }
  for child in content_types.children {
    guard child is XmlElement(element) else { continue }
    if element.name == CONTENT_TYPES_DEFAULT {
      if xml_element_has_content(element) {
        findings.push("[Content_Types].xml: Default element is not empty")
      }
      match
        (
          element.attributes.get("Extension"),
          element.attributes.get("ContentType"),
        ) {
        (Some(extension), Some(content_type)) if extension != "" &&
          content_type != "" => {
          if !is_valid_media_type(content_type) {
            findings.push(
              "[Content_Types].xml: Default has an invalid ContentType: \{content_type}",
            )
            continue
          }
          let extension = extension.to_lower()
          if extension == "rels" &&
            !media_type_equal(content_type, RELATIONSHIPS_CONTENT_TYPE) {
            findings.push(
              "relationship parts have an invalid default content type: \{content_type}",
            )
          }
          if defaults.contains(extension) {
            findings.push("duplicate content-type default: \{extension}")
          } else {
            defaults[extension] = content_type
          }
        }
        _ =>
          findings.push(
            "[Content_Types].xml: Default missing Extension or ContentType",
          )
      }
    } else if element.name == CONTENT_TYPES_OVERRIDE {
      if xml_element_has_content(element) {
        findings.push("[Content_Types].xml: Override element is not empty")
      }
      match
        (
          element.attributes.get("PartName"),
          element.attributes.get("ContentType"),
        ) {
        (Some(part_name), Some(content_type)) if content_type != "" => {
          if !is_valid_media_type(content_type) {
            findings.push(
              "[Content_Types].xml: Override has an invalid ContentType: \{content_type}",
            )
            continue
          }
          if part_name.has_prefix("/") &&
            opc_part_key(part_name[1:]) == opc_part_key("[Content_Types].xml") {
            findings.push(
              "content-type override names the reserved manifest: \{part_name}",
            )
            continue
          }
          match normalize_declared_part_name(part_name) {
            Some(target) => {
              let target_key = opc_part_key(target)
              if overrides.contains(target_key) {
                findings.push("duplicate content-type override: \{part_name}")
              } else {
                overrides[target_key] = content_type
              }
              if !package_parts.contains(target_key) {
                findings.push(
                  "content-type override names a missing part: \{part_name}",
                )
              }
            }
            None =>
              findings.push(
                "content-type override has an invalid PartName: \{part_name}",
              )
          }
        }
        _ =>
          findings.push(
            "[Content_Types].xml: Override missing PartName or ContentType",
          )
      }
    } else {
      findings.push(
        "[Content_Types].xml contains an unexpected element: \{element.name}",
      )
    }
  }
  for entry in archive.entries() {
    let physical_name = entry.name()
    guard archive_entry_logical_part_name(physical_name) is Some(name) else {
      continue
    }
    if opc_part_key(name) == opc_part_key("[Content_Types].xml") {
      continue
    }
    let key = opc_part_key(name)
    let content_type = match overrides.get(key) {
      Some(content_type) => Some(content_type)
      None =>
        match part_extension(name) {
          Some(extension) => defaults.get(extension)
          None => None
        }
    }
    match content_type {
      None => findings.push("part has no declared content type: \{name}")
      Some(content_type) =>
        if @opc.is_relationship_part_name(name) &&
          !media_type_equal(content_type, RELATIONSHIPS_CONTENT_TYPE) {
          findings.push(
            "relationship part has an invalid content type: \{name} -> \{content_type}",
          )
        }
    }
  }

  for entry in archive.entries() {
    guard archive_entry_logical_part_name(entry.name())
      is Some(relationship_part) else {
      continue
    }
    let relationship_key = opc_part_key(relationship_part)
    if !@opc.is_relationship_part_name(relationship_part) {
      continue
    }
    let base = match relationships_base_dir(relationship_key) {
      Some(base) => base
      None => {
        findings.push(
          "relationship part is not under an _rels directory: \{relationship_part}",
        )
        continue
      }
    }
    match @opc.relationship_source_part_name(relationship_part) {
      Some("") => ()
      Some(source) =>
        if !document_parts.contains(opc_part_key(source)) {
          findings.push(
            "relationship part has no source part: \{relationship_part} -> \{source}",
          )
        }
      None => {
        findings.push(
          "relationship part does not identify a source part: \{relationship_part}",
        )
        continue
      }
    }
    let relationships = read_relationships_part(part_index, relationship_part)
    if relationships.name != RELATIONSHIPS_ROOT {
      findings.push("\{relationship_part} root element is not Relationships")
      continue
    }
    for attribute, _ in relationships.attributes {
      findings.push(
        "\{relationship_part} Relationships has an undeclared attribute: \{attribute}",
      )
    }
    for child in relationships.children {
      match child {
        XmlText(text) =>
          if !text.trim().is_empty() {
            findings.push("\{relationship_part} contains unexpected text")
          }
        XmlElement(_) => ()
      }
    }
    let ids : StableStringMap[Bool] = SortedMap([])
    for child in relationships.children {
      guard child is XmlElement(element) else { continue }
      if element.name != RELATIONSHIP_ELEMENT {
        findings.push(
          "\{relationship_part} contains an unexpected element: \{element.name}",
        )
        continue
      }
      for attribute, _ in element.attributes {
        if attribute != "Id" &&
          attribute != "Type" &&
          attribute != "Target" &&
          attribute != "TargetMode" {
          findings.push(
            "relationship in \{relationship_part} has an undeclared attribute: \{attribute}",
          )
        }
      }
      // CT_Relationship is simpleContent extending xsd:string, so text is
      // schema-valid. Only nested elements violate its content model.
      if xml_element_has_child_element(element) {
        findings.push(
          "relationship in \{relationship_part} contains a child element",
        )
      }
      let id = @xml.collapse_xml_schema_whitespace(
        element.attributes.get("Id").unwrap_or(""),
      )
      if id != "" {
        if !is_xml_ncname(id) {
          findings.push(
            "relationship in \{relationship_part} has an invalid Id: \{id}",
          )
        } else if ids.contains(id) {
          findings.push(
            "duplicate relationship Id in \{relationship_part}: \{id}",
          )
        } else {
          ids[id] = true
        }
      } else {
        findings.push("relationship in \{relationship_part} has no Id")
      }
      let rel_type = @xml.collapse_xml_schema_whitespace(
        element.attributes.get("Type").unwrap_or(""),
      )
      if is_absolute_relationship_type(rel_type) {
        ()
      } else if rel_type != "" && has_uri_scheme(rel_type) {
        findings.push(
          "relationship in \{relationship_part} has an invalid Type IRI: \{rel_type}",
        )
      } else if rel_type != "" {
        findings.push(
          "relationship in \{relationship_part} has a non-absolute Type: \{rel_type}",
        )
      } else {
        findings.push("relationship in \{relationship_part} has no Type")
      }
      let target = @xml.collapse_xml_schema_whitespace(
        element.attributes.get("Target").unwrap_or(""),
      )
      if target == "" {
        findings.push("relationship in \{relationship_part} has no Target")
        continue
      }
      let internal = match element.attributes.get("TargetMode") {
        None | Some("Internal") => true
        Some("External") => false
        Some(mode) => {
          findings.push(
            "relationship in \{relationship_part} has invalid TargetMode: \{mode}",
          )
          false
        }
      }
      if internal {
        match resolve_relationship_target(base, target) {
          Some(resolved) => {
            let resolved_key = opc_part_key(resolved)
            if document_parts.contains(resolved_key) {
              ()
            } else if parts.contains(resolved_key) {
              findings.push(
                "relationship in \{relationship_part} points to package metadata: \{target} -> \{resolved}",
              )
            } else {
              findings.push(
                "relationship in \{relationship_part} points to a missing part: \{target} -> \{resolved}",
              )
            }
          }
          None =>
            findings.push(
              "relationship in \{relationship_part} has an invalid Target: \{target}",
            )
        }
      } else if !is_valid_external_relationship_target(target) {
        findings.push(
          "relationship in \{relationship_part} has an invalid external Target: \{target}",
        )
      }
    }
  }
  findings
}

///|
fn is_office_document_relationship(rel_type : StringView) -> Bool {
  rel_type == TRANSITIONAL_OFFICE_DOCUMENT_REL ||
  rel_type == STRICT_OFFICE_DOCUMENT_REL
}

///|
fn validate_main_identity(
  part_index : ArchivePartIndex,
  format : DocumentFormat,
  declared_main_part : String,
) -> Unit raise OfficeError {
  let label = if format is Xlsx { "XLSX" } else { "DOCX" }
  let root_rels = read_relationships_part(part_index, "_rels/.rels")
  if root_rels.name != RELATIONSHIPS_ROOT {
    raise InvalidPackage("_rels/.rels root element is not Relationships")
  }
  let main_targets : Array[(String, String)] = []
  for child in root_rels.children {
    guard child is XmlElement(element) && element.name == RELATIONSHIP_ELEMENT else {
      continue
    }
    let rel_type = @xml.collapse_xml_schema_whitespace(
      element.attributes.get("Type").unwrap_or(""),
    )
    guard is_office_document_relationship(rel_type) else { continue }
    match element.attributes.get("TargetMode") {
      None | Some("Internal") => ()
      Some(_) =>
        raise InvalidPackage(
          "\{label} officeDocument relationship is not internal",
        )
    }
    let id = @xml.collapse_xml_schema_whitespace(
      element.attributes.get("Id").unwrap_or(""),
    )
    if id == "" {
      raise InvalidPackage("\{label} officeDocument relationship has no Id")
    }
    let target = @xml.collapse_xml_schema_whitespace(
      element.attributes.get("Target").unwrap_or(""),
    )
    if target == "" {
      raise InvalidPackage("\{label} officeDocument relationship has no Target")
    }
    let normalized = match normalize_internal_target(target) {
      Some(target) => target
      None =>
        raise InvalidPackage(
          "\{label} officeDocument relationship has an invalid Target",
        )
    }
    main_targets.push((normalized, rel_type))
  }
  let (main_target, main_relationship_type) = match main_targets {
    [] =>
      raise InvalidPackage(
        "\{label} root relationships do not declare an officeDocument relationship",
      )
    [target] => target
    _ =>
      raise InvalidPackage(
        "\{label} root relationships declare multiple officeDocument relationships",
      )
  }
  if opc_part_key(main_target) != opc_part_key(declared_main_part) {
    raise InvalidPackage(
      "\{label} officeDocument relationship targets '\{main_target}', but content types declare '\{declared_main_part}'",
    )
  }
  let main = read_xml_part(part_index, main_target)
  let expected_main_relationship = match (format, main.name) {
    (Xlsx, TRANSITIONAL_WORKBOOK_ROOT) | (Docx, TRANSITIONAL_DOCUMENT_ROOT) =>
      Some(TRANSITIONAL_OFFICE_DOCUMENT_REL)
    (Xlsx, STRICT_WORKBOOK_ROOT) | (Docx, STRICT_DOCUMENT_ROOT) =>
      Some(STRICT_OFFICE_DOCUMENT_REL)
    _ => None
  }
  match expected_main_relationship {
    None => {
      let expected = if format is Xlsx { "workbook" } else { "document" }
      raise InvalidPackage("\{label} main part root element is not \{expected}")
    }
    Some(expected) if main_relationship_type != expected =>
      raise InvalidPackage(
        "\{label} officeDocument relationship dialect does not match the main OOXML namespace",
      )
    Some(_) => ()
  }
}

///|
fn default_main_target_from_root(
  part_index : ArchivePartIndex,
) -> String? raise OfficeError {
  let root_rels = read_relationships_part(part_index, "_rels/.rels")
  if root_rels.name != RELATIONSHIPS_ROOT {
    return None
  }
  let targets : Array[String] = []
  for child in root_rels.children {
    guard child is XmlElement(element) && element.name == RELATIONSHIP_ELEMENT else {
      continue
    }
    let rel_type = @xml.collapse_xml_schema_whitespace(
      element.attributes.get("Type").unwrap_or(""),
    )
    guard is_office_document_relationship(rel_type) else { continue }
    let internal = match element.attributes.get("TargetMode") {
      None | Some("Internal") => true
      _ => false
    }
    guard internal else { continue }
    let target = @xml.collapse_xml_schema_whitespace(
      element.attributes.get("Target").unwrap_or(""),
    )
    guard target != "" else { continue }
    guard normalize_internal_target(target) is Some(normalized) else {
      continue
    }
    targets.push(normalized)
  }
  match targets {
    [target] => Some(target)
    _ => None
  }
}

///|
fn format_from_archive(
  archive : @zip.Archive,
  part_index : ArchivePartIndex,
) -> (DocumentFormat, String) raise OfficeError {
  for entry in archive.entries() {
    if entry.crc32() != @zip.crc32(entry.data()) {
      raise InvalidPackage(
        "entry data does not match its stored CRC-32: \{entry.name()}",
      )
    }
  }
  let content_types = read_xml_part(part_index, "[Content_Types].xml")
  if content_types.name != CONTENT_TYPES_ROOT {
    raise InvalidPackage("[Content_Types].xml root element is not Types")
  }
  let xlsx_main_parts : Array[String] = []
  let docx_main_parts : Array[String] = []
  let overridden_parts : StableStringMap[Bool] = SortedMap([])
  let main_defaults : StableStringMap[DocumentFormat] = SortedMap([])
  for child in content_types.children {
    guard child is XmlElement(element) else { continue }
    if element.name == CONTENT_TYPES_DEFAULT {
      let format = match element.attributes.get("ContentType") {
        Some(content_type) => main_format_from_content_type(content_type)
        None => None
      }
      guard format is Some(format) else { continue }
      guard element.attributes.get("Extension") is Some(extension) &&
        extension != "" else {
        raise InvalidPackage("main content type default has no Extension")
      }
      main_defaults[extension.to_lower()] = format
    } else if element.name == CONTENT_TYPES_OVERRIDE {
      let format = match element.attributes.get("ContentType") {
        Some(content_type) => main_format_from_content_type(content_type)
        None => None
      }
      let part_name = match element.attributes.get("PartName") {
        Some(part_name) => part_name
        None =>
          if format is Some(_) {
            raise InvalidPackage("main content type override has no PartName")
          } else {
            continue
          }
      }
      let normalized = match normalize_declared_part_name(part_name) {
        Some(part_name) => part_name
        None =>
          if format is Some(_) {
            raise InvalidPackage(
              "main content type override has an invalid PartName",
            )
          } else {
            continue
          }
      }
      overridden_parts[opc_part_key(normalized)] = true
      match format {
        Some(Xlsx) => xlsx_main_parts.push(normalized)
        Some(Docx) => docx_main_parts.push(normalized)
        None => ()
      }
    }
  }
  if !main_defaults.is_empty() {
    match default_main_target_from_root(part_index) {
      Some(target) if !overridden_parts.contains(opc_part_key(target)) =>
        match part_extension(target) {
          Some(extension) =>
            match main_defaults.get(extension) {
              Some(Xlsx) => xlsx_main_parts.push(target)
              Some(Docx) => docx_main_parts.push(target)
              None => ()
            }
          None => ()
        }
      _ => ()
    }
  }
  let (format, main_part) = match (xlsx_main_parts, docx_main_parts) {
    ([xlsx], []) => (Xlsx, xlsx)
    ([], [docx]) => (Docx, docx)
    ([], []) =>
      raise InvalidPackage(
        "content types do not declare an XLSX or DOCX main part",
      )
    ([_, ..], [_, ..]) =>
      raise InvalidPackage(
        "content types declare both XLSX and DOCX main parts",
      )
    ([_, _, ..], []) =>
      raise InvalidPackage("content types declare multiple XLSX main parts")
    ([], [_, _, ..]) =>
      raise InvalidPackage("content types declare multiple DOCX main parts")
  }
  (format, main_part)
}

///|
fn structural_findings(
  format : DocumentFormat,
  archive : @zip.Archive,
  part_index : ArchivePartIndex,
  main_part : String,
) -> Array[String] raise OfficeError {
  validate_package_structure(archive, part_index, main_part, format is Xlsx)
}

///|
/// Identifies a structurally valid XLSX or DOCX package.
///
/// The file extension and the OOXML main-part content type must agree. The
/// corresponding portable package validator then checks the package before the
/// format is returned.
pub fn detect_format(
  path : StringView,
  data : BytesView,
) -> DocumentFormat raise OfficeError {
  // Preserve the fail-fast extension contract before parsing package bytes.
  ignore(format_from_extension(path))
  let archive = @zip.read(data) catch {
    _ => raise InvalidPackage("archive is not a readable ZIP")
  }
  detect_archive_format(path, archive)
}

///|
/// Identifies a structurally valid XLSX or DOCX package from an archive that
/// the caller has already materialized. This lets resource-constrained callers
/// parse with their own ZIP limits without parsing the package a second time.
pub fn detect_archive_format(
  path : StringView,
  archive : @zip.Archive,
) -> DocumentFormat raise OfficeError {
  let expected = format_from_extension(path)
  let part_index = archive_part_index(archive)
  let (actual, main_part) = format_from_archive(archive, part_index)
  if expected != actual {
    raise FormatMismatch(expected~, actual~)
  }
  validate_main_identity(part_index, actual, main_part)
  let findings = structural_findings(actual, archive, part_index, main_part)
  if findings.length() > 0 {
    let first = findings[0]
    let suffix = if findings.length() == 1 {
      ""
    } else {
      " (and \{findings.length() - 1} more finding(s))"
    }
    raise InvalidPackage(first + suffix)
  }
  actual
}
