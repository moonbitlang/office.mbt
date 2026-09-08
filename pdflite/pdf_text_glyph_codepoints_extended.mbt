///|
fn pdf_text_glyphname_base_bytes(name : @core.PdfName) -> BytesView {
  let bytes = name.bytes()
  let mut end = bytes.length()
  let mut index = 0
  while index < bytes.length() {
    if bytes[index].to_int() == 46 {
      end = index
      break
    }
    index += 1
  }
  bytes[:end]
}

///|
fn pdf_text_valid_unicode_scalar(codepoint : Int) -> Bool {
  codepoint >= 0 &&
  codepoint <= 0x10FFFF &&
  !(codepoint >= 0xD800 && codepoint <= 0xDFFF)
}

///|
fn pdf_text_parse_hex_codepoint(
  bytes : BytesView,
  start : Int,
  stop : Int,
) -> Int? {
  guard stop > start else { return None }
  let mut value = 0
  for index in start..<stop {
    match pdf_text_hex_digit_value(bytes[index]) {
      Some(digit) => value = value * 16 + digit
      None => return None
    }
  }
  if pdf_text_valid_unicode_scalar(value) {
    Some(value)
  } else {
    None
  }
}

///|
fn pdf_text_uni_glyphname_codepoints(base : BytesView) -> Array[Int]? {
  guard base.length() > 4 &&
    base[0].to_int() == 47 &&
    base[1].to_int() == 117 &&
    base[2].to_int() == 110 &&
    base[3].to_int() == 105 &&
    (base.length() - 4) % 4 == 0 else {
    return None
  }
  let output : Array[Int] = Array::new(capacity=(base.length() - 4) / 4)
  let mut index = 4
  while index < base.length() {
    match pdf_text_parse_hex_codepoint(base, index, index + 4) {
      Some(codepoint) => output.push(codepoint)
      None => return None
    }
    index += 4
  }
  Some(output)
}

///|
fn pdf_text_u_glyphname_codepoints(base : BytesView) -> Array[Int]? {
  guard base.length() >= 6 &&
    base.length() <= 8 &&
    base[0].to_int() == 47 &&
    base[1].to_int() == 117 else {
    return None
  }
  match pdf_text_parse_hex_codepoint(base, 2, base.length()) {
    Some(codepoint) => Some([codepoint])
    None => None
  }
}

///|
fn pdf_text_upper_hex_letter(byte : Byte) -> Bool {
  let value = byte.to_int()
  value >= 65 && value <= 70
}

///|
fn pdf_text_truetype_control_high_byte(value : Int) -> Bool {
  value == 0x8A ||
  value == 0x8B ||
  value == 0x8C ||
  value == 0x9A ||
  value == 0x9B ||
  value == 0x9C
}

///|
fn pdf_text_truetype_windows_high_byte_table() -> Array[(Int, Int)] {
  [
    (0x82, 0x201A),
    (0x83, 0x0192),
    (0x84, 0x201E),
    (0x85, 0x2026),
    (0x86, 0x2020),
    (0x87, 0x2021),
    (0x88, 0x02C6),
    (0x89, 0x2030),
    (0x8A, 0x0160),
    (0x8B, 0x2039),
    (0x8C, 0x0152),
    (0x91, 0x2018),
    (0x92, 0x2019),
    (0x93, 0x201C),
    (0x94, 0x201D),
    (0x95, 0x2022),
    (0x96, 0x2013),
    (0x97, 0x2014),
    (0x98, 0x02DC),
    (0x99, 0x2122),
    (0x9A, 0x0161),
    (0x9B, 0x203A),
    (0x9C, 0x0153),
    (0x9F, 0x0178),
  ]
}

///|
fn pdf_text_truetype_high_byte_codepoint(value : Int, low_hex : Byte) -> Int? {
  if pdf_text_upper_hex_letter(low_hex) &&
    pdf_text_truetype_control_high_byte(value) {
    Some(value)
  } else {
    for entry in pdf_text_truetype_windows_high_byte_table() {
      if entry.0 == value {
        break Some(entry.1)
      }
    } nobreak {
      None
    }
  }
}

///|
fn pdf_text_truetype_glyphname_codepoints(base : BytesView) -> Array[Int]? {
  guard base.length() == 4 && base[0].to_int() == 47 && base[1].to_int() == 71 else {
    return None
  }
  let high = match pdf_text_hex_digit_value(base[2]) {
    Some(value) => value
    None => return None
  }
  let low = match pdf_text_hex_digit_value(base[3]) {
    Some(value) => value
    None => return None
  }
  let value = high * 16 + low
  if base[2].to_int() == 65 && base[3].to_int() == 54 {
    Some([0x00B6])
  } else if value == 0x6D && pdf_text_upper_hex_letter(base[3]) {
    Some([0x002D])
  } else if (value >= 0x20 && value <= 0x7E) || (value >= 0xA0 && value <= 0xFF) {
    Some([value])
  } else {
    match pdf_text_truetype_high_byte_codepoint(value, base[3]) {
      Some(codepoint) => Some([codepoint])
      None => None
    }
  }
}

///|
fn pdf_text_glyphname_base_name(
  name : @core.PdfName,
  base : BytesView,
) -> @core.PdfName {
  if base.length() == name.byte_length() {
    name
  } else {
    @core.pdf_name_of_bytes(base.to_owned())
  }
}
