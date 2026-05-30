///|
fn pdf_stream_length(object : @syntax.PdfObject) -> Int raise PdfError {
  match object.lookup_immediate(@reader.pdf_length_name()) {
    Some(PdfInteger(length)) if length >= 0 => length
    _ => raise StreamLengthExpected
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
