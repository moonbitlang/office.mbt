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
