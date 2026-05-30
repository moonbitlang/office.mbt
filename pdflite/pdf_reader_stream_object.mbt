///|
fn pdf_cursor_finish_stream_object(
  cursor : ByteCursor,
  prefix : @syntax.PdfParsedIndirectObject,
) -> @syntax.PdfParsedIndirectObject raise PdfError {
  let length_result : Result[Int, Error] = try? pdf_stream_length(prefix.object)
  match length_result {
    Ok(length) =>
      pdf_cursor_finish_stream_object_with_length(cursor, prefix, length)
    Err(_) => pdf_cursor_finish_malformed_stream_object(cursor, prefix)
  }
}

///|
fn pdf_cursor_finish_stream_object_with_length(
  cursor : ByteCursor,
  prefix : @syntax.PdfParsedIndirectObject,
  length : Int,
  defer_stream_data? : Bool = false,
) -> @syntax.PdfParsedIndirectObject raise PdfError {
  let stream_keyword_position = cursor.absolute_position()
  @reader.pdf_cursor_consume_ascii(
    cursor,
    [115, 116, 114, 101, 97, 109],
    ParseStreamExpected,
  )
  pdf_cursor_consume_stream_start_line_break(cursor)
  let data_position = cursor.position()
  if cursor.absolute_position() + length > cursor.length() {
    raise EndOfInput
  }
  let stream_data = if defer_stream_data {
    cursor.seek_absolute(cursor.absolute_position() + length)
    @syntax.StreamToGet(
      @syntax.stream_to_get(cursor.deep_copy(), data_position, length),
    )
  } else {
    StreamGot(cursor.read_bytes(length))
  }
  if !pdf_reader_stream_end_marker_at(cursor.view(), cursor.absolute_position()) {
    cursor.seek_absolute(stream_keyword_position)
    pdf_cursor_finish_malformed_stream_object(cursor, prefix)
  } else {
    pdf_cursor_consume_stream_line_break(cursor)
    @syntax.pdf_cursor_drop_whitespace(cursor)
    @reader.pdf_cursor_consume_ascii(
      cursor,
      [101, 110, 100, 115, 116, 114, 101, 97, 109],
      ParseEndStreamExpected,
    )
    @syntax.pdf_cursor_drop_whitespace(cursor)
    @reader.pdf_cursor_consume_ascii(
      cursor,
      [101, 110, 100, 111, 98, 106],
      ParseEndObjectExpected,
    )
    {
      number: prefix.number,
      generation: prefix.generation,
      object: @syntax.pdf_stream(prefix.object, stream_data),
    }
  }
}

///|
fn pdf_cursor_finish_malformed_stream_object(
  cursor : ByteCursor,
  prefix : @syntax.PdfParsedIndirectObject,
) -> @syntax.PdfParsedIndirectObject raise PdfError {
  @reader.pdf_cursor_consume_ascii(
    cursor,
    [115, 116, 114, 101, 97, 109],
    ParseStreamExpected,
  )
  pdf_cursor_consume_stream_start_line_break(cursor)
  let data_start = cursor.absolute_position()
  let endstream = pdf_find_ascii_from(cursor.view(), data_start, [
    101, 110, 100, 115, 116, 114, 101, 97, 109,
  ])
  if endstream < 0 {
    raise ParseEndStreamExpected
  }
  let data_end = pdf_reader_stream_data_end_before_marker(
    cursor.view(),
    endstream,
  )
  let stream_data = cursor
    .view_at_absolute(data_start, data_end - data_start)
    .to_owned()
  cursor.seek_absolute(endstream + 9)
  @syntax.pdf_cursor_drop_whitespace(cursor)
  @reader.pdf_cursor_consume_ascii(
    cursor,
    [101, 110, 100, 111, 98, 106],
    ParseEndObjectExpected,
  )
  {
    number: prefix.number,
    generation: prefix.generation,
    object: @syntax.pdf_stream(
      prefix.object.add_dict_entry(
        @reader.pdf_length_name(),
        PdfInteger(stream_data.length()),
      ),
      StreamGot(stream_data),
    ),
  }
}

///|
/// Parse a single indirect stream object from owned bytes.
///
/// The input should contain one indirect-object header, a stream dictionary,
/// stream data, `endstream`, and `endobj`.
pub fn pdf_parse_stream_object_from_bytes(
  data : PdfBytes,
) -> @syntax.PdfParsedIndirectObject raise PdfError {
  pdf_parse_stream_object_from_view(data)
}

///|
/// Parse a single indirect stream object from a borrowed byte view.
///
/// Malformed `/Length` values are recovered by scanning to `endstream` when
/// possible, matching the stream recovery used by the primitive reader.
pub fn pdf_parse_stream_object_from_view(
  data : BytesView,
) -> @syntax.PdfParsedIndirectObject raise PdfError {
  let cursor = byte_cursor_of_view(data)
  let prefix = @syntax.pdf_parse_indirect_object_prefix_lexemes(
    @syntax.pdf_cursor_lex_tokens(cursor),
  )
  pdf_cursor_finish_stream_object(cursor, prefix)
}
