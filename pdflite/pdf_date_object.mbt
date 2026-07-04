///|
/// Extracts and parses a PDF date from a `PdfString` object.
///
/// Raises `@core.PdfError::BadDate` if the object is not a string or if the date
/// payload is malformed.
pub fn pdf_date_of_object(
  object : @syntax.PdfObject,
) -> @date.PdfDate raise @core.PdfError {
  match object {
    PdfString(bytes) => @date.pdf_date_of_view(bytes)
    _ => raise BadDate
  }
}

///|
/// Formats a PDF date as a `PdfString` object.
///
/// Raises `@core.PdfError::BadDate` if any field is outside the representable PDF
/// date ranges.
pub fn pdf_object_of_date(
  date : @date.PdfDate,
) -> @syntax.PdfObject raise @core.PdfError {
  PdfString(@date.pdf_bytes_of_date(date))
}
