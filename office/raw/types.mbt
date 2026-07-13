///|
let raw_max_error_message = 512

///|
/// Checks a text boundary in Unicode scalar values without allocating an
/// intermediate character array. Isolated UTF-16 surrogates fail closed.
fn raw_text_within_scalar_limit(value : String, limit : Int) -> Bool {
  if limit < 0 {
    return false
  }
  let mut offset = 0
  let mut scalars = 0
  while offset < value.length() {
    let unit = value[offset]
    if unit.is_leading_surrogate() {
      if offset + 1 >= value.length() ||
        !value[offset + 1].is_trailing_surrogate() {
        return false
      }
      offset = offset + 2
    } else if unit.is_trailing_surrogate() {
      return false
    } else {
      offset = offset + 1
    }
    scalars = scalars + 1
    if scalars > limit {
      return false
    }
  }
  true
}

///|
/// Checks that a string contains only well-formed Unicode scalar values.
fn raw_text_is_well_formed(value : String) -> Bool {
  raw_text_within_scalar_limit(value, value.length())
}

///|
/// A stable failure from the validated raw OOXML boundary.
pub(all) suberror RawError {
  RawError(code~ : String, message~ : String, details~ : Json?)
}

///|
pub impl Show for RawError with fn output(self, logger) {
  match self {
    RawError(code~, message~, ..) =>
      logger.write_string("raw OOXML error \{code}: \{message}")
  }
}

///|
fn bounded_raw_text(value : String, limit : Int) -> String {
  if limit <= 0 {
    return ""
  }
  if !raw_text_is_well_formed(value) {
    return "<invalid UTF-16>"
  }
  let output = StringBuilder::new()
  let mut count = 0
  let mut boundary : Char? = None
  let mut truncated = false
  for character in value {
    if count < limit - 1 {
      output.write_char(character) |> ignore
    } else if count == limit - 1 {
      boundary = Some(character)
    } else {
      truncated = true
      break
    }
    count = count + 1
  }
  if truncated {
    output.write_string("…") |> ignore
  } else {
    match boundary {
      Some(character) => output.write_char(character) |> ignore
      None => ()
    }
  }
  output.to_string()
}

///|
fn raw_error(code : String, message : String, details? : Json) -> RawError {
  RawError(
    code~,
    message=bounded_raw_text(message, raw_max_error_message),
    details~,
  )
}

///|
/// Converts a raw OOXML failure into the shared `office.output/1` error.
pub fn RawError::to_protocol_error(self : RawError) -> @office.ProtocolError {
  match self {
    RawError(code~, message~, details~) =>
      match details {
        Some(value) => @office.protocol_error(code, message, details=value)
        None => @office.protocol_error(code, message)
      }
  }
}

///|
/// One deterministic package-part inventory record.
pub struct RawPartInfo {
  name : String
  content_type : String
  xml : Bool
  size : Int
  aliases : ReadOnlyArray[String]
}

///|
/// Returns the canonical relative ZIP entry name without a leading slash.
pub fn RawPartInfo::part_name(self : RawPartInfo) -> String {
  self.name
}

///|
/// Returns the content type resolved from the package manifest.
pub fn RawPartInfo::media_type(self : RawPartInfo) -> String {
  self.content_type
}

///|
/// Reports whether the manifest content type denotes an XML media type.
pub fn RawPartInfo::is_xml(self : RawPartInfo) -> Bool {
  self.xml
}

///|
/// Returns the uncompressed payload size in bytes.
pub fn RawPartInfo::byte_size(self : RawPartInfo) -> Int {
  self.size
}

///|
/// Returns the relationship-derived aliases for this part.
pub fn RawPartInfo::semantic_aliases(
  self : RawPartInfo,
) -> ReadOnlyArray[String] {
  self.aliases
}

///|
fn json_string_array(values : ReadOnlyArray[String]) -> Json {
  let output = []
  for value in values {
    output.push(Json::string(value))
  }
  Json::array(output)
}

///|
pub fn RawPartInfo::to_json(self : RawPartInfo) -> Json {
  Json::object({
    "name": Json::string("/" + self.name),
    "content_type": Json::string(self.content_type),
    "kind": Json::string(if self.xml { "xml" } else { "binary" }),
    "size": Json::number(self.size.to_double()),
    "aliases": json_string_array(self.aliases),
  })
}

///|
/// A complete, canonically ordered package-part inventory.
pub struct RawInventory {
  format : @office.DocumentFormat
  parts : ReadOnlyArray[RawPartInfo]
}

///|
/// Returns the structurally identified package format.
pub fn RawInventory::document_format(
  self : RawInventory,
) -> @office.DocumentFormat {
  self.format
}

///|
/// Returns the canonically ordered immutable part inventory.
pub fn RawInventory::part_records(
  self : RawInventory,
) -> ReadOnlyArray[RawPartInfo] {
  self.parts
}

///|
pub fn RawInventory::to_json(self : RawInventory) -> Json {
  let parts = []
  for part in self.parts {
    parts.push(part.to_json())
  }
  Json::object({
    "schema": Json::string(@office.SCHEMA_RAW_INVENTORY),
    "format": Json::string(self.format.name()),
    "part_count": Json::number(self.parts.length().to_double()),
    "parts": Json::array(parts),
  })
}

///|
/// One resolved package part and its original uncompressed payload.
pub struct RawPartData {
  format : @office.DocumentFormat
  info : RawPartInfo
  bytes : Bytes
}

///|
/// Returns the structurally identified package format.
pub fn RawPartData::document_format(
  self : RawPartData,
) -> @office.DocumentFormat {
  self.format
}

///|
/// Returns the resolved metadata for this part.
pub fn RawPartData::part_info(self : RawPartData) -> RawPartInfo {
  self.info
}

///|
/// Returns the exact uncompressed package-part payload. Callers that retain
/// the bytes must treat them as immutable.
pub fn RawPartData::payload_bytes(self : RawPartData) -> Bytes {
  self.bytes
}

///|
/// Decodes an XML part as UTF-8 or UTF-16 after strict package validation.
pub fn RawPartData::xml_text(self : RawPartData) -> String raise RawError {
  if !self.info.xml {
    raise raw_error(
      "office.raw.binary_requires_explicit_mode",
      "part '/\{self.info.name}' is binary; select base64 or file output",
      details=Json::object({
        "part": Json::string("/" + self.info.name),
        "size": Json::number(self.info.size.to_double()),
      }),
    )
  }
  decode_xml_bytes(self.info.name, self.bytes)
}

///|
/// The deliberately bounded raw XML edit operations.
pub(all) enum RawAction {
  Append
  Prepend
  InsertBefore
  InsertAfter
  Replace
  Remove
  SetAttribute
}

///|
pub fn RawAction::name(self : RawAction) -> String {
  match self {
    Append => "append"
    Prepend => "prepend"
    InsertBefore => "insert-before"
    InsertAfter => "insert-after"
    Replace => "replace"
    Remove => "remove"
    SetAttribute => "set-attribute"
  }
}

///|
pub fn resolve_raw_action(value : StringView) -> RawAction? {
  match value.to_owned().to_lower() {
    "append" => Some(Append)
    "prepend" => Some(Prepend)
    "insert-before" => Some(InsertBefore)
    "insert-after" => Some(InsertAfter)
    "replace" => Some(Replace)
    "remove" => Some(Remove)
    "set-attribute" => Some(SetAttribute)
    _ => None
  }
}

///|
/// A checked edit request. Build with `raw_edit_request`.
pub struct RawEditRequest {
  part : String
  path : String
  action : RawAction
  xml : String?
  attribute : String?
  value : String?
  namespaces : ReadOnlyArray[(String, String)]
  all : Bool
}

///|
/// Pure candidate package bytes and deterministic edit metadata.
pub struct RawMutation {
  bytes : Bytes
  part : String
  action : String
  match_count : Int
}

///|
/// Returns the validated candidate package produced by this mutation.
pub fn RawMutation::candidate_bytes(self : RawMutation) -> Bytes {
  self.bytes
}

///|
/// Returns the canonical relative ZIP entry changed by this mutation.
pub fn RawMutation::part_name(self : RawMutation) -> String {
  self.part
}

///|
/// Returns the stable action name recorded for this mutation.
pub fn RawMutation::action_name(self : RawMutation) -> String {
  self.action
}

///|
/// Returns the number of selected elements, or one for a whole-part replace.
pub fn RawMutation::selected_count(self : RawMutation) -> Int {
  self.match_count
}

///|
pub fn RawMutation::to_json(self : RawMutation) -> Json {
  Json::object({
    "schema": Json::string(@office.SCHEMA_RAW_CHANGE),
    "part": Json::string("/" + self.part),
    "action": Json::string(self.action),
    "match_count": Json::number(self.match_count.to_double()),
  })
}
