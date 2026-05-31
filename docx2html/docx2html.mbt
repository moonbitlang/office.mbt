///|
pub(all) enum Message {
  Warning(String)
  Error(String)
} derive(Debug, Eq)

///|
pub(all) suberror DocxError {
  InvalidZip(message~ : String)
  InvalidXml(message~ : String)
  MissingPart(message~ : String)
  Unsupported(message~ : String)
} derive(Debug, Eq)

///|
pub(all) struct ConversionResult {
  value : String
  messages : Array[Message]
} derive(Debug, Eq)

///|
pub fn success(value : String) -> ConversionResult {
  { value, messages: [] }
}

///|
fn dedupe_messages(messages : Array[Message]) -> Array[Message] {
  let result : Array[Message] = []
  for message in messages {
    if !result.contains(message) {
      result.push(message)
    }
  }
  result
}

///|
pub fn ConversionResult::map(
  self : ConversionResult,
  f : (String) -> String raise?,
) -> ConversionResult raise? {
  { value: f(self.value), messages: self.messages }
}

///|
pub fn ConversionResult::combine(
  self : ConversionResult,
  other : ConversionResult,
) -> ConversionResult {
  let messages = []
  messages.append(self.messages)
  messages.append(other.messages)
  { value: self.value + other.value, messages: dedupe_messages(messages) }
}
