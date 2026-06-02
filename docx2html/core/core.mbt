///|
pub(all) enum Message {
  Warning(String)
  Error(String)
} derive(Debug, Eq)

///|
pub fn warning(message : String) -> Message {
  Warning(message)
}

///|
pub fn error(message : String) -> Message {
  Error(message)
}

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
pub fn dedupe_messages(messages : Array[Message]) -> Array[Message] {
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
pub fn ConversionResult::combine(
  self : ConversionResult,
  other : ConversionResult,
) -> ConversionResult {
  combine_results([self, other])
}

///|
pub fn combine_results(results : Array[ConversionResult]) -> ConversionResult {
  let value = StringBuilder()
  let messages : Array[Message] = []
  for result in results {
    value.write_string(result.value)
    messages.append(result.messages)
  }
  { value: value.to_string(), messages: dedupe_messages(messages) }
}
