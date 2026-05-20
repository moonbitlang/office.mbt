///|
fn pdf_reader_validate_xref_metadata_for_reconstruction(
  data : BytesView,
) -> Unit raise PdfError {
  let cursor = byte_cursor_of_view(data)
  ignore(cursor.read_pdf_header())
  let mut current_xref = pdf_read_startxref_position(cursor.data)
  let mut done = false
  let mut depth = 0
  while !done {
    if depth >= 1024 {
      raise XRefExpected
    }
    cursor.seek_pdf_absolute(current_xref)
    let section = cursor.read_pdf_xref_section()
    match pdf_trailer_xref_stream_position(section.trailer) {
      Some(xref_stream_position) => {
        cursor.seek_pdf_absolute(xref_stream_position)
        ignore(cursor.read_pdf_xref_stream_section())
      }
      None => ()
    }
    match pdf_trailer_prev_position(section.trailer) {
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
fn pdf_reader_startxref_root_uses_object_stream(
  data : BytesView,
) -> Bool raise PdfError {
  let cursor = byte_cursor_of_view(data)
  ignore(cursor.read_pdf_header())
  cursor.seek_pdf_absolute(pdf_read_startxref_position(cursor.data))
  let section = cursor.read_pdf_xref_section()
  let root = match section.trailer.lookup_immediate(pdf_reader_root_name()) {
    Some(PdfIndirect(root)) => root
    _ => -1
  }
  for entry in section.entries {
    if entry.object_number == root && entry.in_use {
      match entry.object_stream {
        Some(_) => break true
        None => ()
      }
    }
  } nobreak {
    false
  }
}

///|
fn pdf_reader_startxref_root_uses_object_stream_or_false(
  data : BytesView,
) -> Bool {
  try pdf_reader_startxref_root_uses_object_stream(data) catch {
    _ => false
  } noraise {
    value => value
  }
}

///|
fn pdf_reader_startxref_uses_xref_stream(
  data : BytesView,
) -> Bool raise PdfError {
  let cursor = byte_cursor_of_view(data)
  ignore(cursor.read_pdf_header())
  cursor.seek_pdf_absolute(pdf_read_startxref_position(cursor.data))
  let section = cursor.read_pdf_xref_section()
  section.stream_object_number is Some(_)
}

///|
fn pdf_reader_startxref_uses_xref_stream_or_false(data : BytesView) -> Bool {
  try pdf_reader_startxref_uses_xref_stream(data) catch {
    _ => false
  } noraise {
    value => value
  }
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
      pdf_reader_xref_metadata_error_allows_reconstruction(data, error)
    PredictorExpected =>
      pdf_reader_xref_metadata_error_allows_reconstruction(data, error)
    PredictorNotSupported(_) =>
      pdf_reader_xref_metadata_error_allows_reconstruction(data, error)
    _ => false
  }
}
