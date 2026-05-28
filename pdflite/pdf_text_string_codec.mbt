///|
/// Test whether a PDF string starts with the UTF-16BE byte-order mark.
///
/// PDF "Unicode strings" are byte strings beginning with `FE FF`; the input is
/// intentionally a `BytesView` rather than a MoonBit `String`.
pub fn pdf_is_unicode_string(bytes : BytesView) -> Bool {
  bytes.length() >= 2 && bytes[0].to_int() == 0xFE && bytes[1].to_int() == 0xFF
}

///|
fn pdf_text_write_utf16be_unit(
  output : Array[Byte],
  position : Int,
  value : Int,
) -> Int raise PdfError {
  output[position] = pdf_byte_of_int((value >> 8) & 0xFF)
  output[position + 1] = pdf_byte_of_int(value & 0xFF)
  position + 2
}

///|
fn pdf_text_utf16be_codepoint_length(codepoint : Int) -> Int raise PdfError {
  pdf_text_check_unicode_codepoint(codepoint)
  if codepoint < 0x10000 {
    2
  } else {
    4
  }
}

///|
fn pdf_text_write_utf16be_codepoint(
  output : Array[Byte],
  position : Int,
  codepoint : Int,
) -> Int raise PdfError {
  pdf_text_check_unicode_codepoint(codepoint)
  if codepoint < 0x10000 {
    pdf_text_write_utf16be_unit(output, position, codepoint)
  } else {
    let shifted = codepoint - 0x10000
    let current = pdf_text_write_utf16be_unit(
      output,
      position,
      0xD800 | (shifted >> 10),
    )
    pdf_text_write_utf16be_unit(output, current, 0xDC00 | (shifted & 0x3FF))
  }
}

///|
/// Encode Unicode scalar values as a PDF UTF-16BE string with BOM.
///
/// Invalid scalar values, including surrogate codepoints, raise
/// `PdfError::InvalidUnicodeCodepoint`.
pub fn pdf_utf16be_of_codepoints(
  codepoints : ArrayView[Int],
) -> PdfBytes raise PdfError {
  let mut length = 2
  for codepoint in codepoints {
    length += pdf_text_utf16be_codepoint_length(codepoint)
  }
  let output = Array::make(length, b'\x00')
  output[0] = pdf_byte_of_int(0xFE)
  output[1] = pdf_byte_of_int(0xFF)
  let mut position = 2
  for codepoint in codepoints {
    position = pdf_text_write_utf16be_codepoint(output, position, codepoint)
  }
  Bytes::from_array(output)
}

///|
fn pdf_text_utf16be_unit(bytes : BytesView, index : Int) -> Int raise PdfError {
  guard index + 1 < bytes.length() else { raise InvalidUTF16BE }
  (bytes[index].to_int() << 8) | bytes[index + 1].to_int()
}

///|
/// Decode UTF-16BE bytes into Unicode scalar values.
///
/// The input should not include the leading `FE FF` BOM; callers that receive a
/// PDF Unicode string normally pass `bytes[2:]`. Odd lengths, lone surrogates,
/// and malformed pairs raise `PdfError::InvalidUTF16BE`.
pub fn pdf_codepoints_of_utf16be(
  bytes : BytesView,
) -> Array[Int] raise PdfError {
  let codepoints : Array[Int] = Array::new(capacity=bytes.length() / 2)
  let mut index = 0
  while index < bytes.length() {
    let w1 = pdf_text_utf16be_unit(bytes, index)
    index += 2
    if w1 >= 0xD800 && w1 <= 0xDBFF {
      let w2 = pdf_text_utf16be_unit(bytes, index)
      guard w2 >= 0xDC00 && w2 <= 0xDFFF else { raise InvalidUTF16BE }
      index += 2
      codepoints.push((((w1 & 0x3FF) << 10) | (w2 & 0x3FF)) + 0x10000)
    } else if w1 >= 0xDC00 && w1 <= 0xDFFF {
      raise InvalidUTF16BE
    } else {
      codepoints.push(w1)
    }
  }
  codepoints
}

///|
fn pdf_text_check_unicode_codepoint(codepoint : Int) -> Unit raise PdfError {
  if codepoint < 0 ||
    codepoint > 0x10FFFF ||
    (codepoint >= 0xD800 && codepoint <= 0xDFFF) {
    raise InvalidUnicodeCodepoint(codepoint)
  }
}

///|
fn pdf_text_utf8_codepoint_length(codepoint : Int) -> Int raise PdfError {
  pdf_text_check_unicode_codepoint(codepoint)
  if codepoint <= 0x7F {
    1
  } else if codepoint <= 0x7FF {
    2
  } else if codepoint <= 0xFFFF {
    3
  } else {
    4
  }
}

///|
fn pdf_text_write_utf8_codepoint(
  output : Array[Byte],
  position : Int,
  codepoint : Int,
) -> Int raise PdfError {
  pdf_text_check_unicode_codepoint(codepoint)
  if codepoint <= 0x7F {
    output[position] = pdf_byte_of_int(codepoint)
    position + 1
  } else if codepoint <= 0x7FF {
    output[position] = pdf_byte_of_int((codepoint >> 6) | 0xC0)
    output[position + 1] = pdf_byte_of_int((codepoint & 0x3F) | 0x80)
    position + 2
  } else if codepoint <= 0xFFFF {
    output[position] = pdf_byte_of_int((codepoint >> 12) | 0xE0)
    output[position + 1] = pdf_byte_of_int(((codepoint >> 6) & 0x3F) | 0x80)
    output[position + 2] = pdf_byte_of_int((codepoint & 0x3F) | 0x80)
    position + 3
  } else {
    output[position] = pdf_byte_of_int((codepoint >> 18) | 0xF0)
    output[position + 1] = pdf_byte_of_int(((codepoint >> 12) & 0x3F) | 0x80)
    output[position + 2] = pdf_byte_of_int(((codepoint >> 6) & 0x3F) | 0x80)
    output[position + 3] = pdf_byte_of_int((codepoint & 0x3F) | 0x80)
    position + 4
  }
}

///|
/// Encode Unicode scalar values as UTF-8 bytes.
///
/// Invalid scalar values, including surrogate codepoints, raise
/// `PdfError::InvalidUnicodeCodepoint`.
pub fn pdf_utf8_of_codepoints(
  codepoints : ArrayView[Int],
) -> PdfBytes raise PdfError {
  let mut length = 0
  for codepoint in codepoints {
    length += pdf_text_utf8_codepoint_length(codepoint)
  }
  let output = Array::make(length, b'\x00')
  let mut position = 0
  for codepoint in codepoints {
    position = pdf_text_write_utf8_codepoint(output, position, codepoint)
  }
  Bytes::from_array(output)
}

///|
fn pdf_text_is_utf8_continuation(byte : Int) -> Bool {
  byte >> 6 == 0b10
}

///|
fn pdf_text_push_utf8_codepoint(
  output : Array[Int],
  codepoint : Int,
  min_codepoint : Int,
) -> Unit raise PdfError {
  pdf_text_check_unicode_codepoint(codepoint)
  guard codepoint >= min_codepoint else { raise InvalidUTF8 }
  output.push(codepoint)
}

///|
/// Decode UTF-8 bytes into Unicode scalar values.
///
/// Overlong encodings, invalid continuation bytes, truncated sequences, and
/// surrogate or out-of-range scalar values raise `PdfError::InvalidUTF8` or
/// `PdfError::InvalidUnicodeCodepoint`.
pub fn pdf_codepoints_of_utf8(bytes : BytesView) -> Array[Int] raise PdfError {
  let output : Array[Int] = Array::new(capacity=bytes.length())
  let mut index = 0
  while index < bytes.length() {
    let first = bytes[index].to_int()
    if first >> 7 == 0 {
      output.push(first)
      index += 1
    } else if first >> 5 == 0b110 {
      guard index + 1 < bytes.length() else { raise InvalidUTF8 }
      let b1 = bytes[index + 1].to_int()
      guard pdf_text_is_utf8_continuation(b1) else { raise InvalidUTF8 }
      pdf_text_push_utf8_codepoint(
        output,
        ((first & 0x1F) << 6) | (b1 & 0x3F),
        0x80,
      )
      index += 2
    } else if first >> 4 == 0b1110 {
      guard index + 2 < bytes.length() else { raise InvalidUTF8 }
      let b1 = bytes[index + 1].to_int()
      let b2 = bytes[index + 2].to_int()
      guard pdf_text_is_utf8_continuation(b1) &&
        pdf_text_is_utf8_continuation(b2) else {
        raise InvalidUTF8
      }
      pdf_text_push_utf8_codepoint(
        output,
        ((first & 0x0F) << 12) | ((b1 & 0x3F) << 6) | (b2 & 0x3F),
        0x800,
      )
      index += 3
    } else if first >> 3 == 0b11110 {
      guard index + 3 < bytes.length() else { raise InvalidUTF8 }
      let b1 = bytes[index + 1].to_int()
      let b2 = bytes[index + 2].to_int()
      let b3 = bytes[index + 3].to_int()
      guard pdf_text_is_utf8_continuation(b1) &&
        pdf_text_is_utf8_continuation(b2) &&
        pdf_text_is_utf8_continuation(b3) else {
        raise InvalidUTF8
      }
      pdf_text_push_utf8_codepoint(
        output,
        ((first & 0x07) << 18) |
        ((b1 & 0x3F) << 12) |
        ((b2 & 0x3F) << 6) |
        (b3 & 0x3F),
        0x10000,
      )
      index += 4
    } else {
      raise InvalidUTF8
    }
  }
  output
}

///|
fn pdf_codepoint_of_pdfdocencoding_byte_option(value : Int) -> Int? {
  match value {
    0x09 => Some(0x0009)
    0x0A => Some(0x000A)
    0x0C => Some(0x000C)
    0x0D => Some(0x000D)
    0x18 => Some(0x02D8)
    0x19 => Some(0x02C7)
    0x1A => Some(0x02C6)
    0x1B => Some(0x02D9)
    0x1C => Some(0x02DD)
    0x1D => Some(0x02DB)
    0x1E => Some(0x02DA)
    0x1F => Some(0x02DC)
    0x20..=0x7E => Some(value)
    0x80 => Some(0x2022)
    0x81 => Some(0x2020)
    0x82 => Some(0x2021)
    0x83 => Some(0x2026)
    0x84 => Some(0x2014)
    0x85 => Some(0x2013)
    0x86 => Some(0x0192)
    0x87 => Some(0x2044)
    0x88 => Some(0x2039)
    0x89 => Some(0x203A)
    0x8A => Some(0x2212)
    0x8B => Some(0x2030)
    0x8C => Some(0x201E)
    0x8D => Some(0x201C)
    0x8E => Some(0x201D)
    0x8F => Some(0x2018)
    0x90 => Some(0x2019)
    0x91 => Some(0x201A)
    0x92 => Some(0x2122)
    0x93 => Some(0xFB02)
    0x95 => Some(0x0141)
    0x96 => Some(0x0152)
    0x97 => Some(0x0160)
    0x98 => Some(0x0178)
    0x99 => Some(0x017D)
    0x9A => Some(0x0131)
    0x9B => Some(0x0142)
    0x9C => Some(0x0153)
    0x9D => Some(0x0161)
    0x9E => Some(0x017E)
    0xA0 => Some(0x20AC)
    0xA1..=0xAC => Some(value)
    0xAE..=0xFF => Some(value)
    _ => None
  }
}

///|
/// Decode one PDFDocEncoding byte to a Unicode codepoint.
///
/// Undefined byte values raise `PdfError::InvalidPDFDocEncoding`.
pub fn pdf_codepoint_of_pdfdocencoding_byte(value : Int) -> Int raise PdfError {
  match pdf_codepoint_of_pdfdocencoding_byte_option(value) {
    Some(codepoint) => codepoint
    None => raise InvalidPDFDocEncoding(value)
  }
}

///|
/// Decode a PDFDocEncoding byte string to Unicode codepoints.
pub fn pdf_codepoints_of_pdfdocencoding(
  bytes : BytesView,
) -> Array[Int] raise PdfError {
  let codepoints : Array[Int] = Array::new(capacity=bytes.length())
  for byte in bytes {
    codepoints.push(pdf_codepoint_of_pdfdocencoding_byte(byte.to_int()))
  }
  codepoints
}

///|
/// Return the PDFDocEncoding byte for a Unicode codepoint, if representable.
///
/// The lookup preserves CamlPDF compatibility for the `fi` ligature by mapping
/// U+FB01 to byte `0x93`.
pub fn pdf_pdfdocencoding_byte_of_codepoint(codepoint : Int) -> Byte? {
  if codepoint == 0xFB01 {
    Some(0x93)
  } else {
    for value in 0..<=255 {
      match pdf_codepoint_of_pdfdocencoding_byte_option(value) {
        Some(decoded) if decoded == codepoint => break Some(value.to_byte())
        _ => ()
      }
    } nobreak {
      None
    }
  }
}

///|
/// Encode codepoints as PDFDocEncoding when every scalar is representable.
///
/// Returns `None` instead of falling back to UTF-16BE; use
/// `pdf_pdfdocstring_of_codepoints` for the PDF string policy fallback.
pub fn pdf_pdfdocencoding_of_codepoints(
  codepoints : ArrayView[Int],
) -> PdfBytes? {
  let output = Array::make(codepoints.length(), b'\x00')
  for index in 0..<codepoints.length() {
    match pdf_pdfdocencoding_byte_of_codepoint(codepoints[index]) {
      Some(byte) => output[index] = byte
      None => return None
    }
  }
  Some(Bytes::from_array(output))
}

///|
/// Encode codepoints as a PDF string.
///
/// PDFDocEncoding is used when all codepoints are representable; otherwise the
/// result is a BOM-prefixed UTF-16BE string.
pub fn pdf_pdfdocstring_of_codepoints(
  codepoints : ArrayView[Int],
) -> PdfBytes raise PdfError {
  match pdf_pdfdocencoding_of_codepoints(codepoints) {
    Some(encoded) => encoded
    None => pdf_utf16be_of_codepoints(codepoints)
  }
}

///|
/// Decode a PDF string to Unicode codepoints.
///
/// BOM-prefixed strings are treated as UTF-16BE. Other byte strings are
/// decoded as PDFDocEncoding.
pub fn pdf_codepoints_of_pdfdocstring(
  bytes : BytesView,
) -> Array[Int] raise PdfError {
  if pdf_is_unicode_string(bytes) {
    pdf_codepoints_of_utf16be(bytes[2:])
  } else {
    pdf_codepoints_of_pdfdocencoding(bytes)
  }
}

///|
/// Convert a PDF string byte sequence to UTF-8 bytes.
pub fn pdf_utf8_of_pdfdocstring(bytes : BytesView) -> PdfBytes raise PdfError {
  pdf_utf8_of_codepoints(pdf_codepoints_of_pdfdocstring(bytes))
}

///|
/// Convert UTF-8 bytes to the compact PDF string representation.
///
/// The result uses PDFDocEncoding when possible and UTF-16BE otherwise.
pub fn pdf_pdfdocstring_of_utf8(bytes : BytesView) -> PdfBytes raise PdfError {
  pdf_pdfdocstring_of_codepoints(pdf_codepoints_of_utf8(bytes))
}

///|
/// Re-encode a UTF-16BE PDF string using PDFDocEncoding when possible.
///
/// Non-Unicode input is returned as an owned copy. Malformed UTF-16BE raises
/// `PdfError::InvalidUTF16BE`.
pub fn pdf_simplify_utf16be(bytes : BytesView) -> PdfBytes raise PdfError {
  if pdf_is_unicode_string(bytes) {
    pdf_pdfdocstring_of_codepoints(pdf_codepoints_of_pdfdocstring(bytes))
  } else {
    bytes.to_owned()
  }
}
