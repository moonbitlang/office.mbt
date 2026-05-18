///|
fn pdf_content_two_byte_charcodes_or_empty(bytes : BytesView) -> Array[Int] {
  if bytes.length() % 2 != 0 {
    []
  } else {
    let output : Array[Int] = []
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
