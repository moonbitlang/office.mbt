///|
fn pdf_reader_startxref_uses_xref_stream(
  data : BytesView,
) -> Bool raise PdfError {
  let cursor = byte_cursor_of_view(data)
  ignore(pdf_read_header_from_cursor(cursor))
  cursor.seek_absolute(pdf_read_startxref_position(cursor.view()))
  let section = pdf_cursor_read_xref_section(cursor)
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
  let parsed = pdf_cursor_read_reconstructed_indirect_prefix_at_current(cursor)
  match parsed.object {
    PdfDictionary(_) as dictionary =>
      @reader.pdf_reader_xref_stream_type_ok(dictionary)
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
