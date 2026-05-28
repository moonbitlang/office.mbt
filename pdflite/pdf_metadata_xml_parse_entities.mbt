///|
fn pdf_metadata_xml_entity_digit(byte : Byte, base : Int) -> Int? {
  let value = byte.to_int()
  if value >= 48 && value <= 57 {
    let digit = value - 48
    if digit < base {
      Some(digit)
    } else {
      None
    }
  } else if base == 16 && value >= 65 && value <= 70 {
    Some(value - 55)
  } else if base == 16 && value >= 97 && value <= 102 {
    Some(value - 87)
  } else {
    None
  }
}

///|
fn pdf_metadata_xml_entity_codepoint(entity : BytesView) -> Int? {
  if entity.length() == 3 && pdf_metadata_view_matches_at(entity, 0, b"amp") {
    Some(38)
  } else if entity.length() == 2 &&
    pdf_metadata_view_matches_at(entity, 0, b"lt") {
    Some(60)
  } else if entity.length() == 2 &&
    pdf_metadata_view_matches_at(entity, 0, b"gt") {
    Some(62)
  } else if entity.length() == 4 &&
    pdf_metadata_view_matches_at(entity, 0, b"quot") {
    Some(34)
  } else if entity.length() == 4 &&
    pdf_metadata_view_matches_at(entity, 0, b"apos") {
    Some(39)
  } else if entity.length() >= 2 && entity[0].to_int() == 35 {
    let mut index = 1
    let mut base = 10
    if index < entity.length() &&
      (entity[index].to_int() == 120 || entity[index].to_int() == 88) {
      base = 16
      index += 1
    }
    if index >= entity.length() {
      return None
    }
    let mut codepoint = 0
    while index < entity.length() {
      match pdf_metadata_xml_entity_digit(entity[index], base) {
        Some(digit) => codepoint = codepoint * base + digit
        None => return None
      }
      if codepoint > 0x10FFFF {
        return None
      }
      index += 1
    }
    if codepoint >= 0xD800 && codepoint <= 0xDFFF {
      None
    } else {
      Some(codepoint)
    }
  } else {
    None
  }
}

///|
fn pdf_metadata_write_xml_codepoint(
  output : Array[Byte],
  position : Int,
  codepoint : Int,
) -> Int? {
  let encoded = pdf_utf8_of_codepoints([codepoint]) catch { _ => return None }
  let mut current = position
  for byte in encoded {
    output[current] = byte
    current += 1
  }
  Some(current)
}

///|
fn pdf_metadata_xml_codepoint_is_space(codepoint : Int) -> Bool {
  codepoint == 9 || codepoint == 10 || codepoint == 13 || codepoint == 32
}

///|
fn pdf_metadata_decode_xml_text(value : BytesView) -> String? {
  let trimmed = pdf_metadata_trim_xml_text(value)
  let output = Array::make(trimmed.length(), b'\x00')
  let mut output_position = 0
  let mut pending_space = false
  let mut index = 0
  while index < trimmed.length() {
    if trimmed[index].to_int() == 38 {
      let semicolon = pdf_metadata_find_byte(trimmed, index + 1, 59)
      if semicolon > index {
        match pdf_metadata_xml_entity_codepoint(trimmed[index + 1:semicolon]) {
          Some(codepoint) =>
            if pdf_metadata_xml_codepoint_is_space(codepoint) {
              if output_position > 0 {
                pending_space = true
              }
              index = semicolon + 1
            } else {
              if pending_space {
                output[output_position] = 32
                output_position += 1
                pending_space = false
              }
              match
                pdf_metadata_write_xml_codepoint(
                  output, output_position, codepoint,
                ) {
                Some(position) => {
                  output_position = position
                  index = semicolon + 1
                }
                None => {
                  output[output_position] = trimmed[index]
                  output_position += 1
                  index += 1
                }
              }
            }
          _ => {
            if pending_space {
              output[output_position] = 32
              output_position += 1
              pending_space = false
            }
            output[output_position] = trimmed[index]
            output_position += 1
            index += 1
          }
        }
      } else {
        if pending_space {
          output[output_position] = 32
          output_position += 1
          pending_space = false
        }
        output[output_position] = trimmed[index]
        output_position += 1
        index += 1
      }
    } else if pdf_metadata_is_xml_space(trimmed[index]) {
      if output_position > 0 {
        pending_space = true
      }
      index += 1
    } else {
      if pending_space {
        output[output_position] = 32
        output_position += 1
        pending_space = false
      }
      output[output_position] = trimmed[index]
      output_position += 1
      index += 1
    }
  }
  let text = @utf8.decode(Bytes::from_array(output[:output_position])) catch {
    _ => return None
  }
  Some(text)
}
