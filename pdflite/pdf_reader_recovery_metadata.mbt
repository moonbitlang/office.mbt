///|
fn pdf_reader_validate_xref_metadata_for_reconstruction(
  data : BytesView,
) -> Unit raise PdfError {
  let cursor = byte_cursor_of_view(data)
  ignore(pdf_read_header_from_cursor(cursor))
  let mut current_xref = pdf_read_startxref_position(cursor.view())
  let mut done = false
  let mut depth = 0
  while !done {
    if depth >= 1024 {
      raise XRefExpected
    }
    cursor.seek_absolute(current_xref)
    let section = pdf_cursor_read_xref_section(cursor)
    match @reader.pdf_trailer_xref_stream_position(section.trailer) {
      Some(xref_stream_position) => {
        cursor.seek_absolute(xref_stream_position)
        ignore(pdf_cursor_read_xref_stream_section(cursor))
      }
      None => ()
    }
    match @reader.pdf_trailer_prev_position(section.trailer) {
      Some(previous) => current_xref = previous
      None => done = true
    }
    depth += 1
  }
}

///|
fn pdf_reader_xref_entry_error_from_metadata(data : BytesView) -> Bool {
  pdf_reader_xref_metadata_error_allows_reconstruction(data, XRefEntryExpected)
}

///|
fn pdf_reader_xref_metadata_error_allows_reconstruction(
  data : BytesView,
  error : PdfError,
) -> Bool {
  let result : Result[Unit, Error] = try? pdf_reader_validate_xref_metadata_for_reconstruction(
    data,
  )
  match (result, error) {
    (Err(PdfError::XRefEntryExpected), XRefEntryExpected) => true
    (
      Err(PdfError::FilterNotSupported(metadata_filter)),
      FilterNotSupported(filter),
    ) => metadata_filter == filter
    (Err(PdfError::PredictorExpected), PredictorExpected) => true
    (
      Err(PdfError::PredictorNotSupported(metadata_predictor)),
      PredictorNotSupported(predictor),
    ) => metadata_predictor == predictor
    _ => false
  }
}
