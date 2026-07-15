///|
/// A shared diagnostic sink for bounded DOCX reads. Reader messages may
/// contain attacker-controlled XML names and relationship targets, so both
/// retained message count and retained text are bounded before insertion into
/// the stable deduplication sets.
priv struct ReaderDiagnosticCollector {
  messages : Array[Message]
  warning_texts : StableStringSet
  error_texts : StableStringSet
  max_messages : Int
  max_chars : Int
  mut received_count : Int
  mut truncated : Bool
}

///|
priv enum ReaderDiagnosticSeverity {
  ReaderWarning
  ReaderError
}

///|
fn ReaderDiagnosticCollector::new(
  max_messages : Int,
  max_chars : Int,
) -> ReaderDiagnosticCollector {
  {
    messages: [],
    warning_texts: SortedSet([]),
    error_texts: SortedSet([]),
    max_messages: max_messages.max(0),
    max_chars: max_chars.max(0),
    received_count: 0,
    truncated: false,
  }
}

///|
fn bounded_reader_diagnostic_text(value : String, maximum : Int) -> String {
  bounded_reader_diagnostic_parts([value], maximum)
}

///|
/// Concatenates diagnostic fragments while retaining at most `maximum`
/// Unicode scalars. The input is traversed only until the bound plus one
/// character is known, so a large relationship target or XML token is never
/// copied in full merely to truncate it afterward.
fn bounded_reader_diagnostic_parts(
  parts : ArrayView[String],
  maximum : Int,
) -> String {
  if maximum <= 0 {
    return ""
  }
  let retained : Array[Char] = []
  let mut truncated = false
  for part in parts {
    if truncated {
      break
    }
    for character in part {
      if retained.length() >= maximum {
        truncated = true
        break
      }
      retained.push(character)
    }
  }
  let output = StringBuilder::new()
  let content_length = if truncated { maximum - 1 } else { retained.length() }
  for index in 0..<content_length {
    output.write_char(retained[index]) |> ignore
  }
  if truncated {
    output.write_string("…") |> ignore
  }
  output.to_string()
}

///|
fn reader_diagnostic_text(parts : ArrayView[String]) -> String {
  let output = StringBuilder::new()
  for part in parts {
    output.write_string(part) |> ignore
  }
  output.to_string()
}

///|
fn ReaderDiagnosticCollector::add_parts(
  self : ReaderDiagnosticCollector,
  severity : ReaderDiagnosticSeverity,
  parts : ArrayView[String],
) -> Unit {
  // Count attempted diagnostics, including duplicates and messages rejected by
  // the retention cap. Callers can then tell whether a nested operation
  // already diagnosed its own failure without depending on retained arrays.
  self.received_count += 1
  let bounded = bounded_reader_diagnostic_parts(parts, self.max_chars)
  let seen = match severity {
    ReaderWarning => self.warning_texts
    ReaderError => self.error_texts
  }
  if seen.contains(bounded) {
    return
  }
  if self.max_messages <= 0 || self.messages.length() >= self.max_messages - 1 {
    self.truncated = true
    return
  }
  // Only accepted diagnostics enter a set, keeping set growth under the same
  // cardinality bound as the retained message array.
  seen.add(bounded)
  self.messages.push(
    match severity {
      ReaderWarning => Warning(bounded)
      ReaderError => Error(bounded)
    },
  )
}

///|
fn push_reader_message_parts(
  target : Array[Message],
  collector : ReaderDiagnosticCollector?,
  severity : ReaderDiagnosticSeverity,
  parts : ArrayView[String],
) -> Unit {
  match collector {
    Some(value) => value.add_parts(severity, parts)
    None => {
      let text = reader_diagnostic_text(parts)
      target.push(
        match severity {
          ReaderWarning => Warning(text)
          ReaderError => Error(text)
        },
      )
    }
  }
}

///|
fn push_reader_warning_parts(
  target : Array[Message],
  collector : ReaderDiagnosticCollector?,
  parts : ArrayView[String],
) -> Unit {
  push_reader_message_parts(target, collector, ReaderWarning, parts)
}

///|
fn push_reader_error_parts(
  target : Array[Message],
  collector : ReaderDiagnosticCollector?,
  parts : ArrayView[String],
) -> Unit {
  push_reader_message_parts(target, collector, ReaderError, parts)
}

///|
fn ReaderDiagnosticCollector::received(self : ReaderDiagnosticCollector) -> Int {
  self.received_count
}

///|
fn ReaderDiagnosticCollector::finish(
  self : ReaderDiagnosticCollector,
) -> Array[Message] {
  if self.truncated && self.messages.length() < self.max_messages {
    self.messages.push(
      Warning(
        bounded_reader_diagnostic_text(
          "additional DOCX diagnostics were omitted",
          self.max_chars,
        ),
      ),
    )
  }
  self.messages
}

///|
fn push_reader_message(
  target : Array[Message],
  collector : ReaderDiagnosticCollector?,
  message : Message,
) -> Unit {
  match message {
    Warning(value) => push_reader_warning_parts(target, collector, [value])
    Error(value) => push_reader_error_parts(target, collector, [value])
  }
}
