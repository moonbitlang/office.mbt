///|
fn pdf_cursor_read_xref_section(
  cursor : @core.ByteCursor,
) -> @reader.PdfXRefSection raise @core.PdfError {
  let position = cursor.absolute_position()
  if @syntax.pdf_cursor_matches_ascii_at(cursor, position, [120, 114, 101, 102]) {
    let entries = @reader.pdf_cursor_read_classic_xref_entries(cursor)
    let trailer = @reader.pdf_cursor_read_trailer_dictionary(cursor)
    { entries, trailer, stream_object_number: None, stream_object_offset: None }
  } else {
    pdf_cursor_read_xref_stream_section(cursor)
  }
}
