///|
fn pdf_length_name() -> PdfName {
  pdf_length_key_name
}

///|
fn pdf_stream_length(object : PdfObject) -> Int raise PdfError {
  match object.lookup_immediate(pdf_length_name()) {
    Some(PdfInteger(length)) if length >= 0 => length
    _ => raise StreamLengthExpected
  }
}

///|
fn pdf_cursor_consume_ascii(
  cursor : ByteCursor,
  values : ArrayView[Int],
  error : PdfError,
) -> Unit raise PdfError {
  let position = cursor.absolute_position()
  if pdf_cursor_matches_ascii_at(cursor, position, values) {
    cursor.seek_absolute(position + values.length())
  } else {
    raise error
  }
}

///|
fn pdf_cursor_consume_stream_line_break(cursor : ByteCursor) -> Unit {
  let value = cursor.peek_byte()
  if value == 13 {
    cursor.nudge()
    if cursor.peek_byte() == 10 {
      cursor.nudge()
    }
  } else if value == 10 {
    cursor.nudge()
  }
}

///|
fn pdf_stream_start_padding_byte(value : Int) -> Bool {
  value == 32 || value == 0 || value == 12 || value == 9
}

///|
fn pdf_cursor_consume_stream_start_line_break(cursor : ByteCursor) -> Unit {
  while pdf_stream_start_padding_byte(cursor.peek_byte()) {
    cursor.nudge()
  }
  pdf_cursor_consume_stream_line_break(cursor)
}

///|
fn pdf_reader_stream_end_marker_at(data : BytesView, position : Int) -> Bool {
  pdf_view_matches_ascii_at(data, position, [
    101, 110, 100, 115, 116, 114, 101, 97, 109,
  ]) ||
  pdf_view_matches_ascii_at(data, position, [
    10, 101, 110, 100, 115, 116, 114, 101, 97, 109,
  ]) ||
  pdf_view_matches_ascii_at(data, position, [
    13, 101, 110, 100, 115, 116, 114, 101, 97, 109,
  ]) ||
  pdf_view_matches_ascii_at(data, position, [
    13, 10, 101, 110, 100, 115, 116, 114, 101, 97, 109,
  ])
}

///|
fn pdf_cursor_finish_stream_object(
  cursor : ByteCursor,
  prefix : PdfParsedIndirectObject,
) -> PdfParsedIndirectObject raise PdfError {
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
  prefix : PdfParsedIndirectObject,
  length : Int,
  defer_stream_data? : Bool = false,
) -> PdfParsedIndirectObject raise PdfError {
  let stream_keyword_position = cursor.absolute_position()
  pdf_cursor_consume_ascii(
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
    StreamToGet(stream_to_get(cursor.deep_copy(), data_position, length))
  } else {
    StreamGot(cursor.read_bytes(length))
  }
  if !pdf_reader_stream_end_marker_at(cursor.view(), cursor.absolute_position()) {
    cursor.seek_absolute(stream_keyword_position)
    pdf_cursor_finish_malformed_stream_object(cursor, prefix)
  } else {
    pdf_cursor_consume_stream_line_break(cursor)
    pdf_cursor_drop_whitespace(cursor)
    pdf_cursor_consume_ascii(
      cursor,
      [101, 110, 100, 115, 116, 114, 101, 97, 109],
      ParseEndStreamExpected,
    )
    pdf_cursor_drop_whitespace(cursor)
    pdf_cursor_consume_ascii(
      cursor,
      [101, 110, 100, 111, 98, 106],
      ParseEndObjectExpected,
    )
    {
      number: prefix.number,
      generation: prefix.generation,
      object: pdf_stream(prefix.object, stream_data),
    }
  }
}

///|
fn pdf_reader_stream_data_end_before_marker(
  data : BytesView,
  marker_position : Int,
) -> Int {
  if marker_position > 1 &&
    data[marker_position - 1].to_int() == 10 &&
    data[marker_position - 2].to_int() == 13 {
    marker_position - 2
  } else if marker_position > 0 &&
    (
      data[marker_position - 1].to_int() == 10 ||
      data[marker_position - 1].to_int() == 13
    ) {
    marker_position - 1
  } else {
    marker_position
  }
}

///|
fn pdf_cursor_finish_malformed_stream_object(
  cursor : ByteCursor,
  prefix : PdfParsedIndirectObject,
) -> PdfParsedIndirectObject raise PdfError {
  pdf_cursor_consume_ascii(
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
  pdf_cursor_drop_whitespace(cursor)
  pdf_cursor_consume_ascii(
    cursor,
    [101, 110, 100, 111, 98, 106],
    ParseEndObjectExpected,
  )
  {
    number: prefix.number,
    generation: prefix.generation,
    object: pdf_stream(
      prefix.object.add_dict_entry(
        pdf_length_name(),
        PdfInteger(stream_data.length()),
      ),
      StreamGot(stream_data),
    ),
  }
}

///|
fn pdf_cursor_finish_object_stream_member_with_length(
  cursor : ByteCursor,
  prefix : PdfParsedIndirectObject,
  length : Int,
) -> PdfParsedIndirectObject raise PdfError {
  let stream_keyword_position = cursor.absolute_position()
  pdf_cursor_consume_ascii(
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
    pdf_cursor_consume_ascii(
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
  pdf_cursor_consume_ascii(
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
        pdf_length_name(),
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

///|
/// Parse a single indirect stream object from owned bytes.
///
/// The input should contain one indirect-object header, a stream dictionary,
/// stream data, `endstream`, and `endobj`.
pub fn pdf_parse_stream_object_from_bytes(
  data : PdfBytes,
) -> PdfParsedIndirectObject raise PdfError {
  pdf_parse_stream_object_from_view(data)
}

///|
/// Parse a single indirect stream object from a borrowed byte view.
///
/// Malformed `/Length` values are recovered by scanning to `endstream` when
/// possible, matching the stream recovery used by the primitive reader.
pub fn pdf_parse_stream_object_from_view(
  data : BytesView,
) -> PdfParsedIndirectObject raise PdfError {
  let cursor = byte_cursor_of_view(data)
  let prefix = pdf_parse_indirect_object_prefix_lexemes(
    pdf_cursor_lex_tokens(cursor),
  )
  pdf_cursor_finish_stream_object(cursor, prefix)
}
