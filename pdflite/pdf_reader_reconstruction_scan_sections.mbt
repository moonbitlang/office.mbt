///|
fn pdf_cursor_read_reconstructed_xref_stream_section_at(
  cursor : ByteCursor,
  position : Int,
) -> (@reader.PdfXRefSection, Int) raise PdfError {
  cursor.seek_absolute(position)
  let section = pdf_cursor_read_xref_stream_section(cursor)
  (section, cursor.absolute_position())
}

///|
fn pdf_cursor_read_reconstructed_classic_xref_section_at(
  cursor : ByteCursor,
  position : Int,
) -> (@reader.PdfXRefSection, Int) raise PdfError {
  cursor.seek_absolute(position)
  let section = pdf_cursor_read_xref_section(cursor)
  guard section.stream_object_number is None else { raise XRefExpected }
  (section, cursor.absolute_position())
}
