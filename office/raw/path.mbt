///|
let raw_max_path_length = 2048

///|
let raw_max_path_depth = 32

///|
let raw_max_name_length = 128

///|
let raw_max_namespace_bindings = 32

///|
let raw_max_namespace_uri_length = 1024

///|
let raw_max_namespace_binding_length : Int = raw_max_name_length +
  1 +
  raw_max_namespace_uri_length

///|
let raw_max_fragment_bytes : Int = 1024 * 1024

///|
let raw_max_matches = 256

///|
let raw_max_attribute_value_bytes : Int = 1024 * 1024

///|
priv struct RawExpandedName {
  prefix : String
  local_name : String
  uri : String
  expanded : String
}

///|
priv enum RawPathPredicate {
  Position(Int)
  Attribute(RawExpandedName, String)
}

///|
priv struct RawPathSegment {
  name : RawExpandedName
  predicate : RawPathPredicate?
}

///|
priv struct RawPath {
  source : String
  segments : Array[RawPathSegment]
}

///|
priv struct RawPathParser {
  source : String
  mut offset : Int
  namespaces : Map[String, String]
}

///|
fn raw_path_error(source : String, offset : Int, message : String) -> RawError {
  raw_error(
    "office.raw.invalid_path",
    message,
    details=Json::object({
      "path": Json::string(bounded_raw_text(source, 240)),
      "offset": Json::number(offset.to_double()),
    }),
  )
}

///|
fn is_raw_ncname_start(character : Char) -> Bool {
  let code = character.to_int()
  character.is_ascii_alphabetic() ||
  character == '_' ||
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
fn is_raw_ncname_character(character : Char) -> Bool {
  let code = character.to_int()
  is_raw_ncname_start(character) ||
  character == '-' ||
  character == '.' ||
  character.is_ascii_digit() ||
  code == 0xb7 ||
  (code >= 0x300 && code <= 0x36f) ||
  (code >= 0x203f && code <= 0x2040)
}

///|
fn is_raw_ncname(value : StringView) -> Bool {
  let mut first = true
  for character in value {
    if first {
      if !is_raw_ncname_start(character) {
        return false
      }
      first = false
    } else if !is_raw_ncname_character(character) {
      return false
    }
  }
  !first
}

///|
fn expanded_xml_name(uri : String, local_name : String) -> String {
  if uri == "" {
    local_name
  } else {
    "{\{uri}}\{local_name}"
  }
}

///|
fn RawPathParser::peek(self : RawPathParser) -> Char? {
  self.source.get_char(self.offset)
}

///|
fn RawPathParser::take(self : RawPathParser) -> Char? {
  match self.peek() {
    Some(character) => {
      self.offset = self.offset + character.utf16_len()
      Some(character)
    }
    None => None
  }
}

///|
fn RawPathParser::expect(
  self : RawPathParser,
  expected : Char,
) -> Unit raise RawError {
  match self.take() {
    Some(actual) if actual == expected => ()
    _ =>
      raise raw_path_error(
        self.source,
        self.offset,
        "expected '\{expected}' in raw XML path",
      )
  }
}

///|
fn RawPathParser::parse_ncname(self : RawPathParser) -> String raise RawError {
  let start = self.offset
  let first = match self.peek() {
    Some(character) => character
    None =>
      raise raw_path_error(
        self.source,
        self.offset,
        "expected an XML name in raw XML path",
      )
  }
  if !is_raw_ncname_start(first) {
    raise raw_path_error(
      self.source,
      self.offset,
      "raw XML path names must be namespace NCNames",
    )
  }
  ignore(self.take())
  for ;; {
    match self.peek() {
      Some(character) if is_raw_ncname_character(character) =>
        ignore(self.take())
      _ => break
    }
  }
  let value = self.source[start:self.offset].to_owned()
  if !raw_text_within_scalar_limit(value, raw_max_name_length) {
    raise raw_path_error(
      self.source,
      start,
      "raw XML path name exceeds \{raw_max_name_length} characters",
    )
  }
  value
}

///|
fn RawPathParser::parse_qname(
  self : RawPathParser,
) -> RawExpandedName raise RawError {
  let first = self.parse_ncname()
  let (prefix, local_name) = if self.peek() is Some(':') {
    ignore(self.take())
    (first, self.parse_ncname())
  } else {
    ("", first)
  }
  let uri = if prefix == "" {
    ""
  } else {
    match self.namespaces.get(prefix) {
      Some(value) => value
      None =>
        raise raw_path_error(
          self.source,
          self.offset,
          "raw XML path uses unknown namespace prefix '\{prefix}'",
        )
    }
  }
  { prefix, local_name, uri, expanded: expanded_xml_name(uri, local_name) }
}

///|
fn RawPathParser::parse_json_string(
  self : RawPathParser,
) -> String raise RawError {
  let start = self.offset
  self.expect('"')
  let mut escaped = false
  for ;; {
    match self.take() {
      Some(_) if escaped => escaped = false
      Some('\\') => escaped = true
      Some('"') => break
      Some(character) if character.to_int() >= 0x20 => ()
      _ =>
        raise raw_path_error(
          self.source,
          self.offset,
          "attribute predicates require a terminated JSON string",
        )
    }
  }
  let literal = self.source[start:self.offset].to_owned()
  let parsed = @json.parse(literal) catch {
    _ =>
      raise raw_path_error(
        self.source,
        start,
        "attribute predicate contains an invalid JSON string",
      )
  }
  match parsed {
    String(value) => value
    _ =>
      raise raw_path_error(
        self.source,
        start,
        "attribute predicate value must be a JSON string",
      )
  }
}

///|
fn RawPathParser::parse_predicate(
  self : RawPathParser,
) -> RawPathPredicate raise RawError {
  self.expect('[')
  if self.peek() is Some('@') {
    ignore(self.take())
    let name = self.parse_qname()
    self.expect('=')
    let value = self.parse_json_string()
    self.expect(']')
    return Attribute(name, value)
  }
  let start = self.offset
  let mut value = 0
  let mut digits = 0
  for ;; {
    match self.peek() {
      Some(character) if character.is_ascii_digit() => {
        ignore(self.take())
        value = value * 10 + character.to_int() - '0'.to_int()
        digits = digits + 1
        if value > raw_max_matches {
          raise raw_path_error(
            self.source,
            start,
            "positional predicate exceeds the \{raw_max_matches} sibling bound",
          )
        }
      }
      _ => break
    }
  }
  if digits == 0 || value == 0 {
    raise raw_path_error(
      self.source,
      start,
      "positional predicates must be positive integers",
    )
  }
  self.expect(']')
  Position(value)
}

///|
fn parse_raw_path(
  source : String,
  namespaces : Map[String, String],
) -> RawPath raise RawError {
  if source.length() == 0 || source.length() > raw_max_path_length {
    raise raw_path_error(
      source,
      0,
      "raw XML path must contain 1 to \{raw_max_path_length} UTF-16 code units",
    )
  }
  let parser = RawPathParser::{ source, offset: 0, namespaces }
  let segments : Array[RawPathSegment] = []
  for ;; {
    parser.expect('/')
    if parser.peek() is None {
      raise raw_path_error(
        source,
        parser.offset,
        "raw XML path cannot end with '/'",
      )
    }
    let name = parser.parse_qname()
    let predicate = if parser.peek() is Some('[') {
      Some(parser.parse_predicate())
    } else {
      None
    }
    segments.push({ name, predicate })
    if segments.length() > raw_max_path_depth {
      raise raw_path_error(
        source,
        parser.offset,
        "raw XML path exceeds \{raw_max_path_depth} segments",
      )
    }
    if !(parser.peek() is Some('/')) {
      break
    }
  }
  if parser.offset != source.length() {
    raise raw_path_error(
      source,
      parser.offset,
      "raw XML path contains unsupported syntax",
    )
  }
  { source, segments }
}

///|
fn standard_raw_namespaces(
  format : @office.DocumentFormat,
  strict : Bool,
) -> Map[String, String] {
  let namespaces : Map[String, String] = {
    "xml": "http://www.w3.org/XML/1998/namespace",
    "mc": "http://schemas.openxmlformats.org/markup-compatibility/2006",
  }
  if strict {
    namespaces["r"] = "http://purl.oclc.org/ooxml/officeDocument/relationships"
    namespaces["a"] = "http://purl.oclc.org/ooxml/drawingml/main"
  } else {
    namespaces["r"] = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
    namespaces["a"] = "http://schemas.openxmlformats.org/drawingml/2006/main"
  }
  match format {
    Docx => {
      if strict {
        namespaces["w"] = "http://purl.oclc.org/ooxml/wordprocessingml/main"
        namespaces["wp"] = "http://purl.oclc.org/ooxml/drawingml/wordprocessingDrawing"
        namespaces["pic"] = "http://purl.oclc.org/ooxml/drawingml/picture"
      } else {
        namespaces["w"] = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
        namespaces["wp"] = "http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"
        namespaces["pic"] = "http://schemas.openxmlformats.org/drawingml/2006/picture"
      }
      namespaces["w14"] = "http://schemas.microsoft.com/office/word/2010/wordml"
      namespaces["w15"] = "http://schemas.microsoft.com/office/word/2012/wordml"
      namespaces["v"] = "urn:schemas-microsoft-com:vml"
    }
    Xlsx => {
      namespaces["x"] = if strict {
        "http://purl.oclc.org/ooxml/spreadsheetml/main"
      } else {
        "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
      }
      namespaces["x14"] = "http://schemas.microsoft.com/office/spreadsheetml/2009/9/main"
      namespaces["x15"] = "http://schemas.microsoft.com/office/spreadsheetml/2010/11/main"
    }
  }
  namespaces
}

///|
fn checked_namespace_bindings(
  values : Array[(String, String)],
) -> ReadOnlyArray[(String, String)] raise RawError {
  if values.length() > raw_max_namespace_bindings {
    raise raw_error(
      "office.raw.invalid_namespace",
      "raw edit exceeds \{raw_max_namespace_bindings} namespace bindings",
    )
  }
  let seen : Map[String, Bool] = Map([])
  let output : Array[(String, String)] = []
  for binding in values {
    let (prefix, uri) = binding
    if !raw_text_within_scalar_limit(prefix, raw_max_name_length) ||
      !is_raw_ncname(prefix) ||
      prefix == "xmlns" {
      raise raw_error(
        "office.raw.invalid_namespace",
        "namespace prefix '\{bounded_raw_text(prefix, 128)}' must be a valid NCName of at most \{raw_max_name_length} characters",
      )
    }
    if uri == "" ||
      !raw_text_within_scalar_limit(uri, raw_max_namespace_uri_length) {
      raise raw_error(
        "office.raw.invalid_namespace",
        "namespace URI for '\{prefix}' must contain 1 to \{raw_max_namespace_uri_length} characters",
      )
    }
    for character in uri {
      if character == ' ' ||
        character == '\t' ||
        character == '\r' ||
        character == '\n' {
        raise raw_error(
          "office.raw.invalid_namespace",
          "namespace URI for '\{prefix}' cannot contain whitespace",
        )
      }
    }
    if seen.contains(prefix) {
      raise raw_error(
        "office.raw.invalid_namespace",
        "namespace prefix '\{prefix}' is declared more than once",
      )
    }
    if prefix == "xml" && uri != "http://www.w3.org/XML/1998/namespace" {
      raise raw_error(
        "office.raw.invalid_namespace", "the xml prefix has a fixed namespace URI",
      )
    }
    seen[prefix] = true
    output.push((prefix, uri))
  }
  ReadOnlyArray::from_array(output)
}

///|
/// Parses one CLI namespace binding in the form `PREFIX=URI`.
pub fn raw_namespace_binding(value : String) -> (String, String) raise RawError {
  if !raw_text_within_scalar_limit(value, raw_max_namespace_binding_length) {
    raise raw_error(
      "office.raw.invalid_namespace",
      "namespace binding exceeds \{raw_max_namespace_binding_length} characters",
    )
  }
  match value.find("=") {
    Some(at) if at > 0 && at + 1 < value.length() => {
      let pair = (value[:at].to_owned(), value[at + 1:].to_owned())
      let checked = checked_namespace_bindings([pair])
      checked[0]
    }
    _ =>
      raise raw_error(
        "office.raw.invalid_namespace", "namespace bindings must use PREFIX=URI",
      )
  }
}

///|
fn edit_path_namespaces(
  format : @office.DocumentFormat,
  request : RawEditRequest,
  document : RawXmlDocument,
) -> Map[String, String] {
  let output = standard_raw_namespaces(
    format,
    raw_document_uses_strict_ooxml(document),
  )
  for binding in request.namespaces {
    let (prefix, uri) = binding
    output[prefix] = uri
  }
  output
}

///|
fn checked_optional_fragment(value : String?) -> String? raise RawError {
  match value {
    Some(xml) => {
      let bytes = @utf8.encode(xml)
      if bytes.length() == 0 || bytes.length() > raw_max_fragment_bytes {
        raise raw_error(
          "office.raw.invalid_fragment",
          "XML input must contain 1 to \{raw_max_fragment_bytes} UTF-8 bytes",
        )
      }
      Some(xml)
    }
    None => None
  }
}

///|
/// Builds one checked raw XML edit request.
pub fn raw_edit_request(
  part : String,
  path : String,
  action : RawAction,
  xml? : String,
  attribute? : String,
  value? : String,
  namespaces? : Array[(String, String)] = [],
  all? : Bool = false,
) -> RawEditRequest raise RawError {
  validate_part_selector(part)
  if path.length() == 0 || path.length() > raw_max_path_length {
    raise raw_path_error(
      path,
      0,
      "raw XML path must contain 1 to \{raw_max_path_length} UTF-16 code units",
    )
  }
  let xml = checked_optional_fragment(xml)
  match value {
    Some(attribute_value) => {
      let value_bytes = @utf8.encode(attribute_value).length()
      if value_bytes > raw_max_attribute_value_bytes {
        raise raw_error(
          "office.raw.resource_limit",
          "raw attribute value exceeds the \{raw_max_attribute_value_bytes}-byte limit",
          details=Json::object({
            "kind": Json::string("attribute_value_bytes"),
            "limit": Json::number(raw_max_attribute_value_bytes.to_double()),
            "actual": Json::number(value_bytes.to_double()),
          }),
        )
      }
    }
    None => ()
  }
  match action {
    Append | Prepend | InsertBefore | InsertAfter | Replace =>
      if xml is None || attribute is Some(_) || value is Some(_) {
        raise raw_error(
          "office.raw.invalid_request",
          "\{action.name()} requires XML and does not accept attribute arguments",
        )
      }
    Remove =>
      if xml is Some(_) || attribute is Some(_) || value is Some(_) {
        raise raw_error(
          "office.raw.invalid_request", "remove does not accept XML or attribute arguments",
        )
      }
    SetAttribute =>
      if xml is Some(_) || attribute is None || value is None {
        raise raw_error(
          "office.raw.invalid_request", "set-attribute requires --attribute and --value and does not accept XML",
        )
      }
  }
  {
    part,
    path,
    action,
    xml,
    attribute,
    value,
    namespaces: checked_namespace_bindings(namespaces),
    all,
  }
}
