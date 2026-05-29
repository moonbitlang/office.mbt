///|
fn pdf_reader_password_error_allows_reconstruction(
  data : BytesView,
  error : PdfError,
) -> Bool {
  match error {
    StartXRefExpected
    | XRefExpected
    | TrailerExpected
    | RootExpected
    | NumberExpected
    | ParseIndirectObjectExpected
    | ParseStreamExpected
    | ParseEndStreamExpected
    | ParseEndObjectExpected
    | EndOfInput
    | ParseObjectExpected
    | InvalidHexEscape
    | InvalidCursorPosition(_) => true
    XRefEntryExpected => pdf_reader_xref_entry_error_from_metadata(data)
    FilterNotSupported(_) =>
      pdf_reader_xref_metadata_error_allows_reconstruction(data, error) ||
      pdf_reader_object_stream_error_allows_reconstruction(data)
    PredictorExpected =>
      pdf_reader_xref_metadata_error_allows_reconstruction(data, error) ||
      pdf_reader_object_stream_error_allows_reconstruction(data)
    PredictorNotSupported(_) =>
      pdf_reader_xref_metadata_error_allows_reconstruction(data, error) ||
      pdf_reader_object_stream_error_allows_reconstruction(data)
    _ => false
  }
}
