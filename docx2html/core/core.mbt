///|
/// Diagnostic emitted while reading or converting a document.
pub(all) enum Message {
  Warning(String)
  Error(String)
} derive(Debug, Eq)

///|
/// Creates a warning diagnostic.
pub fn warning(message : String) -> Message {
  Warning(message)
}

///|
/// Creates an error diagnostic.
pub fn error(message : String) -> Message {
  Error(message)
}

///|
/// A machine-readable XML work or allocation guard. Keeping this distinct
/// from diagnostic text prevents document-controlled names and identifiers
/// from forging resource-limit status at higher API layers.
pub(all) enum DocxXmlResourceLimit {
  DocxXmlSourceUnits
  DocxXmlTokens
  DocxXmlTokenLength
  DocxXmlMaterializedCharacters
  DocxXmlNestingDepth
} derive(Debug, Eq)

///|
/// Stable human-readable text retained for CLI and validation diagnostics.
pub fn DocxXmlResourceLimit::message(self : DocxXmlResourceLimit) -> String {
  match self {
    DocxXmlSourceUnits => "XML source budget exceeded"
    DocxXmlTokens => "XML token budget exceeded"
    DocxXmlTokenLength => "XML token length budget exceeded"
    DocxXmlMaterializedCharacters =>
      "XML materialized character budget exceeded"
    DocxXmlNestingDepth => "XML nesting too deep"
  }
}

///|
/// Errors raised for invalid archives, invalid XML, missing parts, or unsupported input.
pub(all) suberror DocxError {
  InvalidZip(message~ : String)
  InvalidXml(message~ : String)
  MissingPart(message~ : String)
  Unsupported(message~ : String)
  ResourceLimit(limit~ : DocxXmlResourceLimit, message~ : String)
} derive(Debug, Eq)

///|
/// Constructs a typed XML resource error with its stable default diagnostic.
pub fn docx_xml_resource_limit_error(limit : DocxXmlResourceLimit) -> DocxError {
  ResourceLimit(limit~, message=limit.message())
}

///|
/// Adds trusted operation context while preserving the machine discriminator.
pub fn contextual_docx_xml_resource_limit_error(
  limit : DocxXmlResourceLimit,
  message : String,
) -> DocxError {
  ResourceLimit(limit~, message~)
}

///|
/// Returns the typed XML resource discriminator, if this error represents a
/// bounded parser/scanner guard rather than malformed document content.
pub fn DocxError::xml_resource_limit(self : DocxError) -> DocxXmlResourceLimit? {
  match self {
    ResourceLimit(limit~, ..) => Some(limit)
    _ => None
  }
}

///|
/// Returns the stable caller-facing message for every DOCX error variant.
pub fn DocxError::description(self : DocxError) -> String {
  match self {
    InvalidZip(message~)
    | InvalidXml(message~)
    | MissingPart(message~)
    | Unsupported(message~) => message
    ResourceLimit(message~, ..) => message
  }
}

///|
/// Converted value together with accumulated diagnostics.
pub(all) struct ConversionResult {
  value : String
  messages : Array[Message]
} derive(Debug, Eq)

///|
/// Creates a successful conversion result with no diagnostics.
pub fn success(value : String) -> ConversionResult {
  { value, messages: [] }
}

///|
/// Removes duplicate diagnostics while preserving order.
pub fn dedupe_messages(messages : Array[Message]) -> Array[Message] {
  let result : Array[Message] = []
  // Diagnostic text can contain attacker-controlled XML names. Ordered sets
  // keep deduplication independent of runtime string-hash collisions while
  // `result` continues to preserve first-seen order.
  let warning_texts : @sorted_set.SortedSet[String] = SortedSet([])
  let error_texts : @sorted_set.SortedSet[String] = SortedSet([])
  for message in messages {
    match message {
      Warning(value) =>
        if !warning_texts.contains(value) {
          warning_texts.add(value)
          result.push(message)
        }
      Error(value) =>
        if !error_texts.contains(value) {
          error_texts.add(value)
          result.push(message)
        }
    }
  }
  result
}

///|
/// Maps the converted value while preserving diagnostics.
pub fn ConversionResult::map(
  self : ConversionResult,
  f : (String) -> String raise?,
) -> ConversionResult raise? {
  { value: f(self.value), messages: self.messages }
}

///|
/// Flat-maps the converted value while preserving diagnostics.
pub fn ConversionResult::flat_map(
  self : ConversionResult,
  f : (String) -> ConversionResult raise?,
) -> ConversionResult raise? {
  let next = f(self.value)
  let messages = []
  messages.append(self.messages)
  messages.append(next.messages)
  { value: next.value, messages: dedupe_messages(messages) }
}

///|
/// Combines two conversion results.
pub fn ConversionResult::combine(
  self : ConversionResult,
  other : ConversionResult,
) -> ConversionResult {
  combine_results([self, other])
}

///|
/// Combines conversion results, preserving values and diagnostics.
pub fn combine_results(results : Array[ConversionResult]) -> ConversionResult {
  let value = StringBuilder()
  let messages : Array[Message] = []
  for result in results {
    value.write_string(result.value)
    messages.append(result.messages)
  }
  { value: value.to_string(), messages: dedupe_messages(messages) }
}
