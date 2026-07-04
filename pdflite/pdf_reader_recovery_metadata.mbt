///|
fn pdf_reader_validate_xref_metadata_for_reconstruction(
  data : BytesView,
) -> Unit raise @core.PdfError {
  let cursor = @core.byte_cursor_of_view(data)
  ignore(@reader.pdf_read_header_from_cursor(cursor))
  let mut current_xref = @reader.pdf_read_startxref_position(cursor.view())
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
  error : @core.PdfError,
) -> Bool {
  let result : Result[Unit, Error] = try
    pdf_reader_validate_xref_metadata_for_reconstruction(data)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  match (result, error) {
    (Err(@core.PdfError::XRefEntryExpected), XRefEntryExpected) => true
    (
      Err(@core.PdfError::FilterNotSupported(metadata_filter)),
      FilterNotSupported(filter),
    ) => metadata_filter == filter
    (Err(@core.PdfError::PredictorExpected), PredictorExpected) => true
    (
      Err(@core.PdfError::PredictorNotSupported(metadata_predictor)),
      PredictorNotSupported(predictor),
    ) => metadata_predictor == predictor
    _ => false
  }
}
