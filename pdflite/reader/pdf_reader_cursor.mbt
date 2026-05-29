///|
/// Consume an exact ASCII byte sequence at the cursor's current absolute
/// position.
///
/// Raises `error` and leaves the cursor unchanged when the sequence is absent.
pub fn pdf_cursor_consume_ascii(
  cursor : @core.ByteCursor,
  values : ArrayView[Int],
  error : @core.PdfError,
) -> Unit raise @core.PdfError {
  let position = cursor.absolute_position()
  if @syntax.pdf_cursor_matches_ascii_at(cursor, position, values) {
    cursor.seek_absolute(position + values.length())
  } else {
    raise error
  }
}
