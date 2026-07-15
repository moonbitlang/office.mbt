///|
fn opc_ascii_hex_digit(character : Char) -> Bool {
  (character >= '0' && character <= '9') ||
  (character >= 'A' && character <= 'F') ||
  (character >= 'a' && character <= 'f')
}

///|
fn opc_ascii_hex_value(character : Char) -> Int {
  if character >= '0' && character <= '9' {
    character.to_int() - '0'.to_int()
  } else if character >= 'A' && character <= 'F' {
    character.to_int() - 'A'.to_int() + 10
  } else {
    character.to_int() - 'a'.to_int() + 10
  }
}

///|
fn opc_percent_byte(characters : ArrayView[Char], index : Int) -> Int? {
  if index + 2 >= characters.length() ||
    characters[index] != '%' ||
    !opc_ascii_hex_digit(characters[index + 1]) ||
    !opc_ascii_hex_digit(characters[index + 2]) {
    None
  } else {
    Some(
      opc_ascii_hex_value(characters[index + 1]) * 16 +
      opc_ascii_hex_value(characters[index + 2]),
    )
  }
}

///|
fn opc_uri_unreserved(character : Char) -> Bool {
  character.is_ascii_alphabetic() ||
  character.is_ascii_digit() ||
  character == '-' ||
  character == '.' ||
  character == '_' ||
  character == '~'
}

///|
fn opc_uri_unreserved_byte(value : Int) -> Bool {
  (value >= 'A'.to_int() && value <= 'Z'.to_int()) ||
  (value >= 'a'.to_int() && value <= 'z'.to_int()) ||
  (value >= '0'.to_int() && value <= '9'.to_int()) ||
  value == '-'.to_int() ||
  value == '.'.to_int() ||
  value == '_'.to_int() ||
  value == '~'.to_int()
}

///|
fn opc_uri_sub_delimiter(character : Char) -> Bool {
  character == '!' ||
  character == '$' ||
  character == '&' ||
  character.to_int() == 0x27 ||
  character == '(' ||
  character == ')' ||
  character == '*' ||
  character == '+' ||
  character == ',' ||
  character == ';' ||
  character == '='
}

///|
/// RFC 3987 `ucschar`. Private-use characters are deliberately absent: the
/// IRI path grammar permits `ucschar`, while `iprivate` is query-only.
fn opc_iri_ucschar(character : Char) -> Bool {
  let value = character.to_int()
  (value >= 0x00a0 && value <= 0xd7ff) ||
  (value >= 0xf900 && value <= 0xfdcf) ||
  (value >= 0xfdf0 && value <= 0xffef) ||
  (value >= 0x10000 && value <= 0x1fffd) ||
  (value >= 0x20000 && value <= 0x2fffd) ||
  (value >= 0x30000 && value <= 0x3fffd) ||
  (value >= 0x40000 && value <= 0x4fffd) ||
  (value >= 0x50000 && value <= 0x5fffd) ||
  (value >= 0x60000 && value <= 0x6fffd) ||
  (value >= 0x70000 && value <= 0x7fffd) ||
  (value >= 0x80000 && value <= 0x8fffd) ||
  (value >= 0x90000 && value <= 0x9fffd) ||
  (value >= 0xa0000 && value <= 0xafffd) ||
  (value >= 0xb0000 && value <= 0xbfffd) ||
  (value >= 0xc0000 && value <= 0xcfffd) ||
  (value >= 0xd0000 && value <= 0xdfffd) ||
  (value >= 0xe1000 && value <= 0xefffd)
}

///|
fn opc_utf8_percent_length(first : Int) -> Int? {
  if first >= 0xc2 && first <= 0xdf {
    Some(2)
  } else if first >= 0xe0 && first <= 0xef {
    Some(3)
  } else if first >= 0xf0 && first <= 0xf4 {
    Some(4)
  } else {
    None
  }
}

///|
/// Decodes exactly one non-ASCII scalar represented as adjacent `%HH` UTF-8
/// octets. Strict UTF-8 decoding rejects overlong encodings, surrogates, and
/// out-of-range scalars before they reach path normalization.
fn opc_decode_percent_scalar(
  characters : ArrayView[Char],
  index : Int,
) -> (String, Char, Int)? {
  guard opc_percent_byte(characters, index) is Some(first) && first >= 0x80 else {
    return None
  }
  guard opc_utf8_percent_length(first) is Some(length) else { return None }
  let bytes : Array[Byte] = []
  for ordinal in 0..<length {
    guard opc_percent_byte(characters, index + ordinal * 3) is Some(value) else {
      return None
    }
    bytes.push(value.to_byte())
  }
  let decoded = @utf8.decode(Bytes::from_array(bytes)) catch {
    _ => return None
  }
  let decoded_characters = decoded.to_array()
  guard decoded_characters.length() == 1 else { return None }
  Some((decoded, decoded_characters[0], index + length * 3))
}

///|
/// Reports whether one logical OPC part-name segment is a canonical IRI
/// segment. Literal RFC 3987 `ucschar` values are valid. Percent escapes must
/// be complete, must not encode `/` or `\\`, and must not encode an
/// `iunreserved` character, including a non-ASCII scalar such as `é`.
/// OPC also forbids a segment whose final character is `.`.
pub fn is_valid_part_segment(segment : StringView) -> Bool {
  if segment == "" || segment.has_suffix(".") {
    return false
  }
  let characters = segment.to_array()
  let mut index = 0
  while index < characters.length() {
    let character = characters[index]
    if character == '%' {
      guard opc_percent_byte(characters, index) is Some(decoded) else {
        return false
      }
      if decoded == 0x2f || decoded == 0x5c || opc_uri_unreserved_byte(decoded) {
        return false
      }
      if decoded >= 0x80 {
        match opc_decode_percent_scalar(characters, index) {
          Some((_, scalar, next)) => {
            if opc_iri_ucschar(scalar) {
              return false
            }
            index = next
          }
          // A percent-encoded octet need not itself be UTF-8. It remains a
          // legal IRI `pct-encoded` token, but cannot alias a literal scalar.
          None => index = index + 3
        }
      } else {
        index = index + 3
      }
    } else {
      if !opc_uri_unreserved(character) &&
        !opc_iri_ucschar(character) &&
        !opc_uri_sub_delimiter(character) &&
        character != ':' &&
        character != '@' {
        return false
      }
      index = index + 1
    }
  }
  true
}

///|
/// Returns the OPC logical-identity key. Part and logical-item equivalence is
/// ASCII-case-insensitive only; non-ASCII scalars remain case-sensitive.
pub fn part_name_key(name : StringView) -> String {
  let output = StringBuilder::new(size_hint=name.length())
  for character in name {
    output.write_char(character.to_ascii_lowercase())
  }
  output.to_string()
}

///|
/// Maps an ASCII ZIP item name to its logical OPC part name (without the
/// leading slash used by the abstract syntax). Physical ZIP names percent-
/// encode non-ASCII scalars; logical part names contain those scalars
/// literally. Returns `None` for directory records, reserved metadata, and
/// physical names that do not map to a canonical part name.
pub fn logical_part_name_from_zip_item_name(name : StringView) -> String? {
  if name == "" || name.has_prefix("/") || name.has_suffix("/") {
    return None
  }
  let characters = name.to_array()
  let output = StringBuilder::new(size_hint=name.length())
  let mut index = 0
  while index < characters.length() {
    let character = characters[index]
    if !character.is_ascii() {
      // ECMA-376 Part 2, 7.3.3 requires ASCII ZIP item names.
      return None
    }
    if character == '%' {
      guard opc_percent_byte(characters, index) is Some(decoded) else {
        return None
      }
      if decoded >= 0x80 {
        match opc_decode_percent_scalar(characters, index) {
          Some((scalar_text, scalar, next)) if opc_iri_ucschar(scalar) => {
            // Literal IRI path scalars are percent-encoded only by the
            // physical ZIP projection, so restore their logical spelling.
            output.write_string(scalar_text)
            index = next
          }
          _ => {
            // A legal pct-encoded token need not be UTF-8 (for example %FF),
            // and valid UTF-8 may represent a scalar that is not legal
            // literally in an IRI path (for example U+0080). Such escapes are
            // part of the logical name itself and must round-trip unchanged.
            output.write_char(characters[index])
            output.write_char(characters[index + 1])
            output.write_char(characters[index + 2])
            index = index + 3
          }
        }
      } else {
        output.write_char(characters[index])
        output.write_char(characters[index + 1])
        output.write_char(characters[index + 2])
        index = index + 3
      }
    } else {
      output.write_char(character)
      index = index + 1
    }
  }
  let logical = output.to_string()
  for segment in logical.split("/") {
    if !is_valid_part_segment(segment) {
      return None
    }
  }
  Some(logical)
}

///|
/// Maps a canonical logical OPC part name (without its leading slash) to the
/// ASCII ZIP item spelling required by ECMA-376. Existing legal percent
/// escapes remain intact; every literal non-ASCII scalar is UTF-8 percent-
/// encoded with uppercase hexadecimal digits.
pub fn zip_item_name_from_logical_part_name(name : StringView) -> String? {
  if name == "" || name.has_prefix("/") || name.has_suffix("/") {
    return None
  }
  for segment in name.split("/") {
    if !is_valid_part_segment(segment) {
      return None
    }
  }
  let digits = "0123456789ABCDEF".to_array()
  let output = StringBuilder::new(size_hint=name.length())
  for character in name {
    if character.is_ascii() {
      output.write_char(character)
    } else {
      for byte in @utf8.encode(character.to_string()) {
        let value = byte.to_int()
        output.write_char('%')
        output.write_char(digits[value / 16])
        output.write_char(digits[value % 16])
      }
    }
  }
  Some(output.to_string())
}

///|
/// Resolves an internal OPC relationship target and rejects any result that
/// is not a canonical logical PartName. This boundary deliberately operates
/// on IRIs, not physical ZIP item names.
pub fn resolve_part_target(base : String, target : StringView) -> String? {
  guard resolve_target(base, target.to_owned()) is Some(normalized) else {
    return None
  }
  for segment in normalized.split("/") {
    if !is_valid_part_segment(segment) {
      return None
    }
  }
  Some(normalized)
}
