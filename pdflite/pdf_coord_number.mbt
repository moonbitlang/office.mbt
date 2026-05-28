///|
/// Parse a single numeric coordinate expression using the default A4 page
/// context.
pub fn PdfDocument::parse_single_number(
  self : PdfDocument,
  text : String,
) -> Double raise PdfError {
  let values = self.parse_units_string(pdf_coord_default_page(), text)
  match values {
    [value] => value
    _ => raise BadNumberArgument(text)
  }
}

///|
/// Function wrapper for `PdfDocument::parse_single_number`.
pub fn pdf_parse_single_number(
  document : PdfDocument,
  text : String,
) -> Double raise PdfError {
  document.parse_single_number(text)
}
