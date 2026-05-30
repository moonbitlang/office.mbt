///|
fn pdf_cursor_read_reconstructed_trailer_at(
  cursor : ByteCursor,
  position : Int,
) -> @syntax.PdfObject raise PdfError {
  cursor.seek_absolute(position)
  @reader.pdf_cursor_read_trailer_dictionary(cursor)
}

///|
fn pdf_cursor_read_reconstructed_xref_stream_trailer_at(
  cursor : ByteCursor,
  position : Int,
) -> @syntax.PdfObject raise PdfError {
  cursor.seek_absolute(position)
  let parsed = pdf_cursor_read_reconstructed_indirect_prefix_at_current(cursor)
  match parsed.object {
    PdfDictionary(_) as dictionary =>
      if @reader.pdf_reader_xref_stream_type_ok(dictionary) {
        @reader.pdf_reader_stream_dictionary_without_xref_keys(dictionary)
      } else {
        raise XRefExpected
      }
    _ => raise XRefExpected
  }
}
