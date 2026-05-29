///|
fn ByteCursor::read_pdf_xref_section(
  self : ByteCursor,
) -> PdfXRefSection raise PdfError {
  let position = self.absolute_position()
  if pdf_cursor_matches_ascii_at(self, position, [120, 114, 101, 102]) {
    let entries = self.read_pdf_classic_xref_entries()
    let trailer = self.read_pdf_trailer_dictionary()
    { entries, trailer, stream_object_number: None, stream_object_offset: None }
  } else {
    self.read_pdf_xref_stream_section()
  }
}

///|
fn ByteCursor::read_pdf_trailer_dictionary(
  self : ByteCursor,
) -> PdfObject raise PdfError {
  pdf_cursor_drop_whitespace(self)
  self.consume_pdf_ascii([116, 114, 97, 105, 108, 101, 114], TrailerExpected)
  pdf_cursor_drop_whitespace(self)
  let object = pdf_parse_single_lexeme_object(pdf_cursor_lex_tokens(self))
  match object {
    PdfDictionary(_) => object
    _ => raise TrailerExpected
  }
}
