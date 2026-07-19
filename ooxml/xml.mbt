///|
/// Scan for characters that `escape_xml_text`/`escape_xml_attr` would rewrite,
/// so the escape functions can skip allocating when the input needs no
/// escaping. All escapable characters are single code units, so scanning
/// UTF-16 units directly is safe.
pub fn xml_needs_escape(value : StringView, attr~ : Bool) -> Bool {
  for i in 0..<value.length() {
    match value[i] {
      '&' | '<' | '>' => return true
      '"' | '\'' => if attr { return true }
      _ => ()
    }
  }
  false
}

///|
/// Package-local UTF-8-counted XML output used by OOXML manifests. A limited
/// writer stops before appending the fragment that would cross its ceiling, so
/// callers can reject oversized generated metadata without first retaining it.
priv struct XmlOutputBuilder {
  builder : StringBuilder
  maximum : Int?
  mut encoded_bytes : Int
  mut exceeded : Bool
}

///|
fn XmlOutputBuilder::new(maximum : Int?) -> XmlOutputBuilder {
  { builder: StringBuilder::new(), maximum, encoded_bytes: 0, exceeded: false }
}

///|
fn xml_output_utf8_length_within(value : StringView, maximum : Int) -> Int? {
  let mut length = 0
  for character in value {
    let scalar = character.to_int()
    let width = if scalar <= 0x7F {
      1
    } else if scalar <= 0x7FF {
      2
    } else if scalar <= 0xFFFF {
      3
    } else {
      4
    }
    if width > maximum - length {
      return None
    }
    length = length + width
  }
  Some(length)
}

///|
fn XmlOutputBuilder::write_view(
  self : XmlOutputBuilder,
  value : StringView,
) -> Unit {
  if self.exceeded {
    return
  }
  match self.maximum {
    Some(maximum) => {
      let remaining = maximum - self.encoded_bytes
      match xml_output_utf8_length_within(value, remaining) {
        Some(length) => {
          self.builder.write_view(value)
          self.encoded_bytes = self.encoded_bytes + length
        }
        None => self.exceeded = true
      }
    }
    None => self.builder.write_view(value)
  }
}

///|
fn XmlOutputBuilder::write_attr(
  self : XmlOutputBuilder,
  value : StringView,
) -> Unit {
  let mut literal_start = 0
  for index in 0..<value.length() {
    let escaped = match value[index] {
      unit if unit == ('&' : UInt16) => Some("&amp;")
      unit if unit == ('<' : UInt16) => Some("&lt;")
      unit if unit == ('>' : UInt16) => Some("&gt;")
      unit if unit == ('"' : UInt16) => Some("&quot;")
      unit if unit == ('\'' : UInt16) => Some("&apos;")
      _ => None
    }
    match escaped {
      Some(entity) => {
        self.write_view(value[literal_start:index])
        self.write_view(entity)
        literal_start = index + 1
      }
      None => ()
    }
    if self.exceeded {
      return
    }
  }
  self.write_view(value[literal_start:])
}

///|
fn XmlOutputBuilder::finish(self : XmlOutputBuilder) -> String? {
  if self.exceeded {
    None
  } else {
    Some(self.builder.to_string())
  }
}

///|
/// Escape XML text content (`&`, `<`, `>`). Returns the input unchanged when no
/// escaping is needed (a view over a whole string converts back without
/// copying).
pub fn escape_xml_text(value : StringView) -> String {
  if !xml_needs_escape(value, attr=false) {
    return value.to_owned()
  }
  let sb = StringBuilder::new()
  let mut literal_start = 0
  for index in 0..<value.length() {
    let escaped = match value[index] {
      unit if unit == ('&' : UInt16) => Some("&amp;")
      unit if unit == ('<' : UInt16) => Some("&lt;")
      unit if unit == ('>' : UInt16) => Some("&gt;")
      _ => None
    }
    match escaped {
      Some(entity) => {
        sb.write_view(value[literal_start:index])
        sb.write_view(entity)
        literal_start = index + 1
      }
      None => ()
    }
  }
  sb.write_view(value[literal_start:])
  sb.to_string()
}

///|
/// Escape an XML attribute value (`&`, `<`, `>`, `"`, `'`). Returns the input
/// unchanged when no escaping is needed.
pub fn escape_xml_attr(value : StringView) -> String {
  if !xml_needs_escape(value, attr=true) {
    return value.to_owned()
  }
  let sb = StringBuilder::new()
  let mut literal_start = 0
  for index in 0..<value.length() {
    let escaped = match value[index] {
      unit if unit == ('&' : UInt16) => Some("&amp;")
      unit if unit == ('<' : UInt16) => Some("&lt;")
      unit if unit == ('>' : UInt16) => Some("&gt;")
      unit if unit == ('"' : UInt16) => Some("&quot;")
      unit if unit == ('\'' : UInt16) => Some("&apos;")
      _ => None
    }
    match escaped {
      Some(entity) => {
        sb.write_view(value[literal_start:index])
        sb.write_view(entity)
        literal_start = index + 1
      }
      None => ()
    }
  }
  sb.write_view(value[literal_start:])
  sb.to_string()
}
