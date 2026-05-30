///|
fn pdf_read_linearized_marker(
  cursor : @core.ByteCursor,
) -> Bool raise @core.PdfError {
  ignore(@reader.pdf_read_header_from_cursor(cursor))
  let parsed = pdf_cursor_read_plain_indirect_object_at_current(cursor)
  match parsed.object.lookup_immediate(@reader.pdf_reader_linearized_name()) {
    Some(PdfInteger(_)) | Some(PdfReal(_)) => true
    _ => false
  }
}

///|
fn pdf_read_was_linearized(data : BytesView) -> Bool {
  let result : Result[Bool, Error] = try? pdf_read_linearized_marker(
    @core.byte_cursor_of_view(data),
  )
  match result {
    Ok(value) => value
    Err(_) => false
  }
}

///|
/// Return whether the input appears to be a linearized PDF.
///
/// The check reads the first indirect object after the header and looks for a
/// numeric `/Linearized` entry. Parse failures are treated as `false`.
pub fn pdf_is_linearized(data : BytesView) -> Bool {
  pdf_read_was_linearized(data)
}

///|
/// Count document revisions by following xref `/Prev` links.
///
/// Revision `1` is the newest revision referenced by `startxref`; larger numbers
/// walk backward through older revisions. Linearized hint-table revisions are
/// excluded from the returned count.
pub fn pdf_revisions_from_view(data : BytesView) -> Int raise @core.PdfError {
  let cursor = @core.byte_cursor_of_view(data)
  ignore(@reader.pdf_read_header_from_cursor(cursor))
  let mut current_xref = @reader.pdf_read_startxref_position(data)
  let mut revisions = 0
  let mut done = false
  while !done {
    if revisions >= 1024 {
      raise XRefExpected
    }
    cursor.seek_absolute(current_xref)
    let section = pdf_cursor_read_xref_section(cursor)
    revisions += 1
    match @reader.pdf_trailer_prev_position(section.trailer) {
      Some(previous) => current_xref = previous
      None => done = true
    }
  }
  if pdf_is_linearized(data) && revisions > 1 {
    revisions - 1
  } else {
    revisions
  }
}

///|
/// Count document revisions from owned PDF bytes.
pub fn pdf_revisions_from_bytes(
  data : @core.PdfBytes,
) -> Int raise @core.PdfError {
  pdf_revisions_from_view(data)
}
