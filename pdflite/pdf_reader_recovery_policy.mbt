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
    let section = cursor.read_pdf_xref_section()
    match pdf_trailer_xref_stream_position(section.trailer) {
      Some(xref_stream_position) => {
        cursor.seek_absolute(xref_stream_position)
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
  ignore(pdf_read_header_from_cursor(cursor))
  cursor.seek_absolute(pdf_read_startxref_position(cursor.view()))
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
fn pdf_reader_startxref_object_stream_root_unusable(
  data : BytesView,
) -> Bool raise PdfError {
  let cursor = byte_cursor_of_view(data)
  ignore(pdf_read_header_from_cursor(cursor))
  cursor.seek_absolute(pdf_read_startxref_position(cursor.view()))
  let section = cursor.read_pdf_xref_section()
  match section.trailer.lookup_immediate(pdf_reader_root_name()) {
    Some(PdfIndirect(root)) =>
      match pdf_classic_xref_lookup(section.entries, root) {
        Some(entry) =>
          match entry.object_stream {
            Some(root_reference) =>
              match
                pdf_classic_xref_lookup(
                  section.entries,
                  root_reference.object_stream_number,
                ) {
                Some(entry) =>
                  match entry.object_stream {
                    Some(_) => true
                    None => {
                      let object_stream_xref = entry
                      let xref_index = pdf_classic_xref_index(section.entries)
                      cursor.seek_absolute(object_stream_xref.offset)
                      let parsed = cursor.read_first_indirect_object_at_current(
                        section.entries,
                        xref_index=Some(xref_index),
                      )
                      if parsed.number != root_reference.object_stream_number ||
                        parsed.generation != object_stream_xref.generation {
                        true
                      } else {
                        let document = pdf_document_empty()
                        document.load_object_given_number(
                          parsed.number,
                          parsed.object,
                          generation=parsed.generation,
                        )
                        let context = document.read_object_stream_context(
                          root_reference.object_stream_number,
                        )
                        let root_object = context.read_reference(root_reference)
                        root_object.0 != root
                      }
                    }
                  }
                None => true
              }
            None => false
          }
        None => false
      }
    _ => false
  }
}

///|
fn pdf_reader_startxref_object_stream_root_unusable_or_true(
  data : BytesView,
) -> Bool {
  try pdf_reader_startxref_object_stream_root_unusable(data) catch {
    _ => true
  } noraise {
    value => value
  }
}

///|
fn pdf_reader_object_stream_error_allows_reconstruction(
  data : BytesView,
) -> Bool {
  if pdf_reader_startxref_root_uses_object_stream_or_false(data) {
    !pdf_reader_startxref_object_stream_root_unusable_or_true(data)
  } else {
    true
  }
}

///|
fn pdf_reader_startxref_uses_xref_stream(
  data : BytesView,
) -> Bool raise PdfError {
  let cursor = byte_cursor_of_view(data)
  ignore(pdf_read_header_from_cursor(cursor))
  cursor.seek_absolute(pdf_read_startxref_position(cursor.view()))
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
fn pdf_reader_startxref_has_xref_stream_prefix(
  data : BytesView,
) -> Bool raise PdfError {
  let cursor = byte_cursor_of_view(data)
  ignore(pdf_read_header_from_cursor(cursor))
  cursor.seek_absolute(pdf_read_startxref_position(cursor.view()))
  let parsed = cursor.read_reconstructed_indirect_prefix_at_current()
  match parsed.object {
    PdfDictionary(_) as dictionary => pdf_reader_xref_stream_type_ok(dictionary)
    _ => false
  }
}

///|
fn pdf_reader_startxref_has_xref_stream_prefix_or_false(
  data : BytesView,
) -> Bool {
  try pdf_reader_startxref_has_xref_stream_prefix(data) catch {
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
