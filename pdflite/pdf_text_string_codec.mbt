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
