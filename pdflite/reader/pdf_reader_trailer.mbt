///|
/// Read a classic `trailer << ... >>` dictionary from the current cursor.
pub fn pdf_cursor_read_trailer_dictionary(
  cursor : @core.ByteCursor,
) -> @syntax.PdfObject raise @core.PdfError {
  @syntax.pdf_cursor_drop_whitespace(cursor)
  pdf_cursor_consume_ascii(
    cursor,
    [116, 114, 97, 105, 108, 101, 114],
    TrailerExpected,
  )
  @syntax.pdf_cursor_drop_whitespace(cursor)
  let object = @syntax.pdf_parse_single_lexeme_object(
    @syntax.pdf_cursor_lex_tokens(cursor),
  )
  match object {
    PdfDictionary(_) => object
    _ => raise TrailerExpected
  }
}

///|
/// Read a non-negative `/Prev` trailer offset, if present.
pub fn pdf_trailer_prev_position(
  trailer : @syntax.PdfObject,
) -> Int? raise @core.PdfError {
  match trailer.lookup_immediate(pdf_reader_prev_name()) {
    Some(PdfInteger(position)) if position >= 0 => Some(position)
    Some(_) => raise TrailerExpected
    None => None
  }
}

///|
/// Read a non-negative `/XRefStm` trailer offset, if present.
pub fn pdf_trailer_xref_stream_position(
  trailer : @syntax.PdfObject,
) -> Int? raise @core.PdfError {
  match trailer.lookup_immediate(pdf_reader_xrefstm_name()) {
    Some(PdfInteger(position)) if position >= 0 => Some(position)
    Some(PdfInteger(_)) => raise XRefExpected
    _ => None
  }
}

///|
/// Return the persistent trailer dictionary after transient reader keys are removed.
pub fn pdf_reader_sanitize_trailer(
  trailer : @syntax.PdfObject,
  size : Int,
) -> @syntax.PdfObject raise @core.PdfError {
  trailer
  .add_dict_entry(pdf_reader_size_name(), PdfInteger(size))
  .remove_dict_entry(pdf_reader_w_name())
  .remove_dict_entry(pdf_reader_type_name())
  .remove_dict_entry(pdf_reader_index_name())
  .remove_dict_entry(pdf_reader_prev_name())
  .remove_dict_entry(pdf_reader_xrefstm_name())
  .remove_dict_entry(pdf_reader_filter_name())
  .remove_dict_entry(pdf_reader_decodeparms_name())
}
