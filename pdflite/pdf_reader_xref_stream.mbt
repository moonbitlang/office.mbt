///|
fn pdf_cursor_read_xref_stream_section(
  cursor : @core.ByteCursor,
) -> @reader.PdfXRefSection raise @core.PdfError {
  let stream_object_offset = cursor.absolute_position()
  if !@core.pdf_is_digit_byte(cursor.peek_byte()) {
    raise XRefExpected
  }
  let parsed = pdf_cursor_read_first_indirect_object_at_current(cursor, [])
  guard parsed.object is PdfStreamObject(stream) else { raise XRefExpected }
  if !@reader.pdf_reader_xref_stream_type_ok(stream.dictionary) {
    raise XRefExpected
  }
  let decoded_stream = pdf_decode_stream_value(stream)
  let widths = @reader.pdf_xref_stream_widths(decoded_stream.dictionary)
  let index_pairs = @reader.pdf_xref_stream_index_pairs(
    decoded_stream.dictionary,
  )
  let data = @syntax.pdf_stream_data_bytes(decoded_stream.data)
  {
    entries: @reader.pdf_xref_stream_entries(data, widths, index_pairs),
    trailer: @reader.pdf_reader_stream_dictionary_without_xref_keys(
      decoded_stream.dictionary,
    ),
    stream_object_number: Some(parsed.number),
    stream_object_offset: Some(stream_object_offset),
  }
}
