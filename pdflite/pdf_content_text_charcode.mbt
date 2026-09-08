///|
fn pdf_content_two_byte_charcodes_or_empty(bytes : BytesView) -> Array[Int] {
  if bytes.length() % 2 != 0 {
    []
  } else {
    let output : Array[Int] = Array::new(capacity=bytes.length() / 2)
    let mut index = 0
    while index < bytes.length() {
      let high = bytes[index].to_int()
      let low = bytes[index + 1].to_int()
      output.push((high << 8) | low)
      index += 2
    }
    output
  }
}

///|
/// Split raw PDF string bytes into cpdfcontent character codes for `self`.
///
/// Standard and simple fonts use one byte per character code. CID-keyed fonts
/// use fixed two-byte big-endian character codes, and malformed odd-length
/// inputs return an empty array to match cpdf's `charcodes_of_string`.
pub fn PdfFont::content_charcodes_of_bytes(
  self : PdfFont,
  bytes : BytesView,
) -> Array[Int] {
  match self {
    PdfFontCIDKeyed(_) => pdf_content_two_byte_charcodes_or_empty(bytes)
    _ => [ for byte in bytes => byte.to_int() ]
  }
}

///|
/// Compatibility wrapper for `PdfFont::content_charcodes_of_bytes`.
pub fn pdf_content_charcodes_of_bytes(
  bytes : BytesView,
  font : PdfFont,
) -> Array[Int] {
  font.content_charcodes_of_bytes(bytes)
}

///|
/// Convert a cpdfcontent glyph character code back to raw PDF string bytes.
///
/// CID-keyed fonts write the code as two big-endian bytes. Standard and simple
/// fonts write a single byte. Out-of-range bytes raise `@core.PdfError::InvalidByte`,
/// matching the source helper's `char_of_int` failure cases.
pub fn PdfFont::content_bytes_of_charcode(
  self : PdfFont,
  charcode : Int,
) -> @core.PdfBytes raise @core.PdfError {
  match self {
    PdfFontCIDKeyed(_) =>
      Bytes::from_array([
        @core.pdf_byte_of_int(charcode >> 8),
        @core.pdf_byte_of_int(charcode & 0xFF),
      ])
    _ => Bytes::from_array([@core.pdf_byte_of_int(charcode)])
  }
}

///|
/// Compatibility wrapper for `PdfFont::content_bytes_of_charcode`.
pub fn pdf_content_bytes_of_charcode(
  font : PdfFont,
  charcode : Int,
) -> @core.PdfBytes raise @core.PdfError {
  font.content_bytes_of_charcode(charcode)
}
