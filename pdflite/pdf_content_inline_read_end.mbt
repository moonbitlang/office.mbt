///|
fn pdf_content_skip_whitespace(cursor : @core.ByteCursor) -> Unit {
  while @core.pdf_is_whitespace_byte(cursor.peek_byte()) {
    cursor.nudge()
  }
}

///|
fn pdf_content_consume_next_inline_image_end(
  cursor : @core.ByteCursor,
) -> Bool raise @core.PdfError {
  let remaining = cursor.remaining_view()
  if remaining.length() < 2 {
    false
  } else {
    let limit = remaining.length() - 1
    for index in 0..<limit {
      if remaining[index].to_int() == 69 && remaining[index + 1].to_int() == 73 {
        ignore(cursor.read_view(index + 2))
        return true
      }
    }
    false
  }
}

///|
fn pdf_content_read_inline_image_end(
  cursor : @core.ByteCursor,
) -> Unit raise @core.PdfError {
  pdf_content_skip_whitespace(cursor)
  let marker_start = cursor.position()
  match (cursor.read_byte(), cursor.read_byte()) {
    (Some(first), Some(second)) if first.to_int() == 69 && second.to_int() == 73 =>
      ()
    _ => {
      try! cursor.seek(marker_start)
      if !pdf_content_consume_next_inline_image_end(cursor) {
        raise ParseEndStreamExpected
      }
    }
  }
}
