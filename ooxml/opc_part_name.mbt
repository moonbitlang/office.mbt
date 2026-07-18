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
/// Reports whether one logical OPC PartName segment is canonical under the
/// RFC 3987 mapping required by ECMA-376 Part 2.
pub fn is_valid_opc_part_segment(segment : StringView) -> Bool {
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
/// Maps an ASCII physical ZIP item name to its logical OPC PartName. Literal
/// non-ASCII IRI scalars are restored from their canonical UTF-8 `%HH`
/// projection; opaque legal percent escapes remain unchanged.
pub fn logical_opc_part_name_from_zip_item_name(name : StringView) -> String? {
  if name == "" || name.has_prefix("/") || name.has_suffix("/") {
    return None
  }
  let characters = name.to_array()
  let output = StringBuilder::new(size_hint=name.length())
  let mut index = 0
  while index < characters.length() {
    let character = characters[index]
    if !character.is_ascii() {
      return None
    }
    if character == '%' {
      guard opc_percent_byte(characters, index) is Some(decoded) else {
        return None
      }
      if decoded >= 0x80 {
        match opc_decode_percent_scalar(characters, index) {
          Some((scalar_text, scalar, next)) if opc_iri_ucschar(scalar) => {
            output.write_string(scalar_text)
            index = next
          }
          _ => {
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
    if !is_valid_opc_part_segment(segment) {
      return None
    }
  }
  Some(logical)
}

///|
test "OPC physical names restore Unicode logical identity" {
  debug_inspect(
    logical_opc_part_name_from_zip_item_name("custom/%E6%96%87.xml"),
    content="Some(\"custom/文.xml\")",
  )
  debug_inspect(
    logical_opc_part_name_from_zip_item_name("custom/文.xml"),
    content="None",
  )
}
