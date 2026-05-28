///|
/// Advance the cursor past PDF white space.
///
/// The first non-whitespace byte, delimiter, or end of input is left unread.
pub fn ByteCursor::drop_pdf_whitespace(self : ByteCursor) -> Unit {
  let mut done = false
  while !done {
    let value = self.peek_byte()
    if value == pdf_no_more || pdf_is_not_whitespace_byte(value) {
      done = true
    } else {
      self.nudge()
    }
  }
}

///|
/// Read a borrowed view up to PDF white space or a delimiter.
///
/// The terminating byte is left unread so higher-level lexers can dispatch on
/// delimiters after reading a regular token.
pub fn ByteCursor::read_until_pdf_whitespace_or_delimiter(
  self : ByteCursor,
) -> BytesView {
  try! self.read_until_view(pdf_is_whitespace_or_delimiter_byte)
}

///|
/// Skip PDF white space and read a regular token as a borrowed byte view.
pub fn ByteCursor::read_pdf_regular_token_view(self : ByteCursor) -> BytesView {
  self.drop_pdf_whitespace()
  self.read_until_pdf_whitespace_or_delimiter()
}
