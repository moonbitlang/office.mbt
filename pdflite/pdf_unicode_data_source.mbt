///|
/// Return cpdf's compressed UnicodeData source bytes.
pub fn pdf_unicode_data_source() -> PdfBytes raise PdfError {
  @unicodedata.pdf_unicode_data_source()
}

///|
/// Source-spelled compatibility wrapper for cpdfunicodedata's `unicodedata_source`.
pub fn pdf_unicodedata_source() -> PdfBytes raise PdfError {
  @unicodedata.pdf_unicodedata_source()
}
