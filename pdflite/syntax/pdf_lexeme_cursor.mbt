///|
/// Advance the cursor past PDF white space.
///
/// The first non-whitespace byte, delimiter, or end of input is left unread.
pub fn pdf_cursor_drop_whitespace(cursor : @core.ByteCursor) -> Unit {
  let mut done = false
  while !done {
    let value = cursor.peek_byte()
    if value == @core.pdf_no_more || @core.pdf_is_not_whitespace_byte(value) {
      done = true
    } else {
      cursor.nudge()
    }
  }
}

///|
/// Read a borrowed view up to PDF white space or a delimiter.
///
/// The terminating byte is left unread so higher-level lexers can dispatch on
/// delimiters after reading a regular token.
pub fn pdf_cursor_read_until_whitespace_or_delimiter(
  cursor : @core.ByteCursor,
) -> BytesView {
  try! cursor.read_until_view(@core.pdf_is_whitespace_or_delimiter_byte)
}

///|
/// Skip PDF white space and read a regular token as a borrowed byte view.
pub fn pdf_cursor_read_regular_token_view(
  cursor : @core.ByteCursor,
) -> BytesView {
  pdf_cursor_drop_whitespace(cursor)
  pdf_cursor_read_until_whitespace_or_delimiter(cursor)
}
