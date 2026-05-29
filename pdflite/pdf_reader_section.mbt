///|
fn pdf_cursor_read_xref_section(
  cursor : ByteCursor,
) -> PdfXRefSection raise PdfError {
  let position = cursor.absolute_position()
  if pdf_cursor_matches_ascii_at(cursor, position, [120, 114, 101, 102]) {
    let entries = cursor.read_pdf_classic_xref_entries()
    let trailer = pdf_cursor_read_trailer_dictionary(cursor)
    { entries, trailer, stream_object_number: None, stream_object_offset: None }
  } else {
    pdf_cursor_read_xref_stream_section(cursor)
  }
}

///|
fn pdf_cursor_read_trailer_dictionary(
  cursor : ByteCursor,
) -> PdfObject raise PdfError {
  pdf_cursor_drop_whitespace(cursor)
  cursor.consume_pdf_ascii([116, 114, 97, 105, 108, 101, 114], TrailerExpected)
  pdf_cursor_drop_whitespace(cursor)
  let object = pdf_parse_single_lexeme_object(pdf_cursor_lex_tokens(cursor))
  match object {
    PdfDictionary(_) => object
    _ => raise TrailerExpected
  }
}
