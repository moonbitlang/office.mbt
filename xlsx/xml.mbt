///|
/// XML escaping is shared with the `ooxml` package (the OOXML packaging layer
/// this package builds on) so there is a single implementation to keep
/// correct. These thin wrappers preserve the local names used throughout the
/// writer.
fn escape_xml_text(value : StringView) -> String {
  @ooxml.escape_xml_text(value)
}

///|
fn escape_xml_attr(value : StringView) -> String {
  @ooxml.escape_xml_attr(value)
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
fn xml_entity_digits_are_valid(digits : StringView, base : Int) -> Bool {
  if digits == "" {
    return false
  }
  for digit in digits {
    let valid = if base == 10 {
      digit.is_ascii_digit()
    } else {
      digit.is_ascii_digit() || digit is ('a'..='f') || digit is ('A'..='F')
    }
    if !valid {
      return false
    }
  }
  true
}

///|
fn decode_xml_entity(entity : StringView) -> Char? {
  match entity {
    "lt" => Some('<')
    "gt" => Some('>')
    "quot" => Some('"')
    "apos" => Some('\'')
    "amp" => Some('&')
    _ => {
      let text = entity.to_owned()
      let (digits, base) = if text.has_prefix("#x") || text.has_prefix("#X") {
        (text[2:], 16)
      } else if text.has_prefix("#") {
        (text[1:], 10)
      } else {
        return None
      }
      if !xml_entity_digits_are_valid(digits, base) {
        return None
      }
      let codepoint = @string.parse_int(digits, base~) catch {
        _ => return None
      }
      if !is_valid_xml_char_reference(codepoint) {
        return None
      }
      Some(codepoint.unsafe_to_char())
    }
  }
}

///|
/// Decode predefined and numeric XML entities in one pass. A one-pass decoder
/// is important here: `&amp;#x20;` denotes the literal text `&#x20;`, not a space.
/// Unknown or malformed entities are preserved for the owning parser to reject
/// according to its field grammar.
fn unescape_xml_text(value : StringView) -> String {
  if !value.contains("&") {
    return value.to_owned()
  }
  let output = StringBuilder::new()
  let mut index = 0
  let mut literal_start = 0
  while index < value.length() {
    if value[index] != ('&' : UInt16) {
      index = index + 1
      continue
    }
    let mut entity_end = index + 1
    // Stop at a nested ampersand or markup opener. This keeps ampersand-heavy
    // malformed input linear while still accepting valid numeric references
    // with arbitrarily many leading zeroes.
    while entity_end < value.length() &&
          value[entity_end] != (';' : UInt16) &&
          value[entity_end] != ('&' : UInt16) &&
          value[entity_end] != ('<' : UInt16) {
      entity_end = entity_end + 1
    }
    if entity_end < value.length() && value[entity_end] == (';' : UInt16) {
      match decode_xml_entity(value[index + 1:entity_end]) {
        Some(character) => {
          output.write_view(value[literal_start:index])
          output.write_char(character)
          index = entity_end + 1
          literal_start = index
          continue
        }
        None => ()
      }
    }
    index = index + 1
  }
  output.write_view(value[literal_start:])
  output.to_string()
}

///|
fn is_attr_space(ch : Char) -> Bool {
  match ch {
    ' ' | '\t' | '\n' | '\r' => true
    _ => false
  }
}

///|
fn attr_value(tag : StringView, name : StringView) -> String? raise XlsxError {
  @ooxml.attr_value(tag, name) catch {
    InvalidXml(msg~) => raise InvalidXml(msg~)
  }
}

///|
test "xml wb: escape attr and attr-space branches" {
  inspect(escape_xml_attr("a>b"), content="a&gt;b")
  inspect(is_attr_space('\t'), content="true")
}

///|
test "xml wb: unescape numeric entities once and preserve invalid entities" {
  inspect(unescape_xml_text("A1&#x20;B1&#32;C1"), content="A1 B1 C1")
  inspect(unescape_xml_text("A1&#0000000032;B1"), content="A1 B1")
  inspect(unescape_xml_text("&#x1f600;"), content="😀")
  inspect(unescape_xml_text("&amp;#x20;"), content="&#x20;")
  inspect(unescape_xml_text("&unknown; &#0;"), content="&unknown; &#0;")
}

///|
test "xml wb: attr_value parser edge branches" {
  debug_inspect(
    attr_value("= \"skip\" foo=   \"bar\"", "foo"),
    content="Some(\"bar\")",
  )
  debug_inspect(attr_value("foo=bar", "foo"), content="None")

  let invalid : Result[String?, Error] = Ok(
    attr_value("foo=\"unterminated", "foo"),
  ) catch {
    e => Err(e)
  }
  inspect(invalid is Err(XlsxError::InvalidXml(_)), content="true")
}
