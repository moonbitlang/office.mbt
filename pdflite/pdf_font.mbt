///|
fn PdfDocument::pdf_font_name_field(
  self : PdfDocument,
  font : PdfObject,
  key : PdfName,
) -> String raise PdfError {
  match self.lookup_direct(key, font) {
    Some(PdfNameObject(name)) => pdf_util_string_from_name(name)
    _ => ""
  }
}
