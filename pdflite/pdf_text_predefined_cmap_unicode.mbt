///|
fn pdf_text_valid_unicode_codepoint(codepoint : Int) -> Bool {
  codepoint >= 0 &&
  codepoint <= 0x10FFFF &&
  !(codepoint >= 0xD800 && codepoint <= 0xDFFF)
}

///|
fn pdf_text_packed_charcode_length(code : Int) -> Int {
  if code >= 0 && code <= 0xFF {
    1
  } else if code >= 0 && code <= 0xFFFF {
    2
  } else if code >= 0 && code <= 0xFFFFFF {
    3
  } else {
    4
  }
}

///|
fn pdf_text_packed_charcode_bytes(code : Int, length : Int) -> Bytes {
  Bytes::makei(length, fn(index) {
    ((code >> ((length - index - 1) * 8)) & 0xFF).to_byte()
  })
}

///|
fn pdf_text_pack_two_bytes(first : Int, second : Int) -> Int {
  (first << 8) | second
}

///|
fn pdf_text_pack_four_bytes(
  first : Int,
  second : Int,
  third : Int,
  fourth : Int,
) -> Int {
  (((((first << 8) | second) << 8) | third) << 8) | fourth
}

///|
fn pdf_text_pack_bytes_as_charcode(bytes : BytesView) -> Int {
  let mut code = 0
  for byte in bytes {
    code = (code << 8) | byte.to_int()
  }
  code
}

///|
fn pdf_text_predefined_utf8_codepoints(code : Int) -> Array[Int]? {
  let bytes = pdf_text_packed_charcode_bytes(
    code,
    pdf_text_packed_charcode_length(code),
  )
  try pdf_codepoints_of_utf8(bytes) catch {
    _ => None
  } noraise {
    codepoints => Some(codepoints)
  }
}

///|
fn pdf_text_predefined_utf8_charcode(codepoint : Int) -> Int? {
  guard pdf_text_valid_unicode_codepoint(codepoint) else { return None }
  if codepoint <= 0x7F {
    Some(codepoint)
  } else if codepoint <= 0x7FF {
    Some(
      pdf_text_pack_two_bytes(
        0xC0 | (codepoint >> 6),
        0x80 | (codepoint & 0x3F),
      ),
    )
  } else if codepoint <= 0xFFFF {
    Some(
      pdf_text_pack_bytes_as_charcode(
        Bytes::makei(3, fn(index) {
          match index {
            0 => (0xE0 | (codepoint >> 12)).to_byte()
            1 => (0x80 | ((codepoint >> 6) & 0x3F)).to_byte()
            _ => (0x80 | (codepoint & 0x3F)).to_byte()
          }
        }),
      ),
    )
  } else {
    Some(
      pdf_text_pack_four_bytes(
        0xF0 | (codepoint >> 18),
        0x80 | ((codepoint >> 12) & 0x3F),
        0x80 | ((codepoint >> 6) & 0x3F),
        0x80 | (codepoint & 0x3F),
      ),
    )
  }
}

///|
fn pdf_text_predefined_utf16_codepoints(code : Int) -> Array[Int]? {
  if code >= 0 && code <= 0xFFFF {
    if pdf_text_valid_unicode_codepoint(code) {
      Some([code])
    } else {
      None
    }
  } else if pdf_text_packed_charcode_length(code) == 4 {
    let bytes = pdf_text_packed_charcode_bytes(code, 4)
    try pdf_codepoints_of_utf16be(bytes) catch {
      _ => None
    } noraise {
      codepoints => Some(codepoints)
    }
  } else {
    None
  }
}

///|
fn pdf_text_predefined_utf16_charcode(codepoint : Int) -> Int? {
  guard pdf_text_valid_unicode_codepoint(codepoint) else { return None }
  if codepoint <= 0xFFFF {
    Some(codepoint)
  } else {
    let shifted = codepoint - 0x10000
    let high = 0xD800 | (shifted >> 10)
    let low = 0xDC00 | (shifted & 0x3FF)
    Some(pdf_text_pack_four_bytes(high >> 8, high & 0xFF, low >> 8, low & 0xFF))
  }
}

///|
fn pdf_text_predefined_utf32_codepoints(code : Int) -> Array[Int]? {
  if pdf_text_valid_unicode_codepoint(code) {
    Some([code])
  } else {
    None
  }
}

///|
fn pdf_text_predefined_utf32_charcode(codepoint : Int) -> Int? {
  if pdf_text_valid_unicode_codepoint(codepoint) {
    Some(codepoint)
  } else {
    None
  }
}

///|
fn pdf_text_predefined_direct_unicode_codepoints(
  name : PdfName,
  code : Int,
) -> Array[Int]? {
  if pdf_text_predefined_cmap_uses_utf8_charcodes(name) {
    pdf_text_predefined_utf8_codepoints(code)
  } else if pdf_text_predefined_cmap_uses_utf16_charcodes(name) {
    pdf_text_predefined_utf16_codepoints(code)
  } else if pdf_text_predefined_cmap_uses_utf32_charcodes(name) {
    pdf_text_predefined_utf32_codepoints(code)
  } else if pdf_text_predefined_cmap_uses_ucs2_charcodes(name) {
    pdf_text_predefined_utf32_codepoints(code)
  } else {
    None
  }
}

///|
fn pdf_text_predefined_direct_unicode_charcode(
  name : PdfName,
  codepoint : Int,
) -> Int? {
  if pdf_text_predefined_cmap_uses_utf8_charcodes(name) {
    pdf_text_predefined_utf8_charcode(codepoint)
  } else if pdf_text_predefined_cmap_uses_utf16_charcodes(name) {
    pdf_text_predefined_utf16_charcode(codepoint)
  } else if pdf_text_predefined_cmap_uses_utf32_charcodes(name) {
    pdf_text_predefined_utf32_charcode(codepoint)
  } else if pdf_text_predefined_cmap_uses_ucs2_charcodes(name) {
    if codepoint <= 0xFFFF && pdf_text_valid_unicode_codepoint(codepoint) {
      Some(codepoint)
    } else {
      None
    }
  } else {
    None
  }
}
