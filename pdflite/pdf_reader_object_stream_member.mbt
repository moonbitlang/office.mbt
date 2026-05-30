///|
fn pdf_cursor_finish_object_stream_member_with_length(
  cursor : ByteCursor,
  prefix : PdfParsedIndirectObject,
  length : Int,
) -> PdfParsedIndirectObject raise PdfError {
  let stream_keyword_position = cursor.absolute_position()
  @reader.pdf_cursor_consume_ascii(
    cursor,
    [115, 116, 114, 101, 97, 109],
    ParseStreamExpected,
  )
  pdf_cursor_consume_stream_start_line_break(cursor)
  if cursor.absolute_position() + length > cursor.length() {
    raise EndOfInput
  }
  let stream_data = cursor.read_bytes(length)
  if !pdf_reader_stream_end_marker_at(cursor.view(), cursor.absolute_position()) {
    cursor.seek_absolute(stream_keyword_position)
    pdf_cursor_finish_malformed_object_stream_member(cursor, prefix)
  } else {
    pdf_cursor_consume_stream_line_break(cursor)
    pdf_cursor_drop_whitespace(cursor)
    @reader.pdf_cursor_consume_ascii(
      cursor,
      [101, 110, 100, 115, 116, 114, 101, 97, 109],
      ParseEndStreamExpected,
    )
    {
      number: prefix.number,
      generation: prefix.generation,
      object: pdf_stream(prefix.object, StreamGot(stream_data)),
    }
  }
}

///|
fn pdf_cursor_finish_malformed_object_stream_member(
  cursor : ByteCursor,
  prefix : PdfParsedIndirectObject,
) -> PdfParsedIndirectObject raise PdfError {
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
  {
    number: prefix.number,
    generation: prefix.generation,
    object: pdf_stream(
      prefix.object.add_dict_entry(
        @reader.pdf_length_name(),
        PdfInteger(stream_data.length()),
      ),
      StreamGot(stream_data),
    ),
  }
}

///|
fn pdf_cursor_finish_object_stream_member(
  cursor : ByteCursor,
  prefix : PdfParsedIndirectObject,
) -> PdfParsedIndirectObject raise PdfError {
  let stream_position = cursor.absolute_position()
  let length_result : Result[Int, Error] = try? pdf_stream_length(prefix.object)
  match length_result {
    Ok(length) =>
      pdf_cursor_finish_object_stream_member_with_length(cursor, prefix, length) catch {
        _ => {
          cursor.seek_absolute(stream_position)
          pdf_cursor_finish_malformed_object_stream_member(cursor, prefix)
        }
      }
    Err(_) => pdf_cursor_finish_malformed_object_stream_member(cursor, prefix)
  }
}

///|
fn pdf_parse_object_stream_member_from_view(
  data : BytesView,
) -> PdfObject raise PdfError {
  let cursor = byte_cursor_of_view(data)
  let object = pdf_parse_single_lexeme_object(pdf_cursor_lex_tokens(cursor))
  if pdf_cursor_stopped_at_stream_candidate(cursor) {
    match object {
      PdfDictionary(_) =>
        pdf_cursor_finish_object_stream_member(cursor, {
          number: 0,
          generation: 0,
          object,
        }).object
      _ => raise ParseSingleObjectExpected
    }
  } else {
    object
  }
}
