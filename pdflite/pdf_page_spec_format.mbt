///|
/// Format selected document pages as a compact cpdf page specification.
pub fn PdfDocument::string_of_pagespec(
  self : PdfDocument,
  pages : ArrayView[Int],
) -> String raise @core.PdfError {
  @spec.pdf_string_of_pagespec_for_count(self.endpage(), pages)
}

///|
/// Source-spelled wrapper for `PdfDocument::string_of_pagespec`.
pub fn pdf_string_of_pagespec(
  document : PdfDocument,
  pages : ArrayView[Int],
) -> String raise @core.PdfError {
  document.string_of_pagespec(pages)
}
