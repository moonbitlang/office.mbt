///|
/// Extracts and parses a PDF date from a `PdfString` object.
///
/// Raises `PdfError::BadDate` if the object is not a string or if the date
/// payload is malformed.
pub fn pdf_date_of_object(object : PdfObject) -> PdfDate raise PdfError {
  match object {
    PdfString(bytes) => pdf_date_of_view(bytes)
    _ => raise PdfError::BadDate
  }
}

///|
/// Formats a PDF date as a `PdfString` object.
///
/// Raises `PdfError::BadDate` if any field is outside the representable PDF
/// date ranges.
pub fn pdf_object_of_date(date : PdfDate) -> PdfObject raise PdfError {
  PdfString(pdf_bytes_of_date(date))
}
