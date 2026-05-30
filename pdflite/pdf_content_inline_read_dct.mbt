///|
fn pdf_content_read_dct_inline_image_data(
  cursor : ByteCursor,
) -> PdfBytes raise PdfError {
  match cursor.peek_byte() {
    value if pdf_is_whitespace_byte(value) => cursor.nudge()
    _ => ()
  }
  let data = @codec.pdf_cursor_read_jpeg_data(cursor)
  pdf_content_read_inline_image_end(cursor)
  data
}
