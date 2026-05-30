///|
fn pdf_content_read_flate_inline_image_data(
  cursor : ByteCursor,
) -> PdfBytes raise PdfError {
  match cursor.peek_byte() {
    value if pdf_is_whitespace_byte(value) => cursor.nudge()
    _ => ()
  }
  let (_, length) = @flate.pdf_flate_decode_view_prefix(cursor.remaining_view())
  let data = cursor.read_view(length).to_owned()
  pdf_content_read_inline_image_end(cursor)
  data
}

///|
fn pdf_content_read_flate_inline_image_decoded(
  cursor : ByteCursor,
) -> PdfBytes raise PdfError {
  match cursor.peek_byte() {
    value if pdf_is_whitespace_byte(value) => cursor.nudge()
    _ => ()
  }
  let (decoded, length) = @flate.pdf_flate_decode_view_prefix(
    cursor.remaining_view(),
  )
  ignore(cursor.read_view(length))
  pdf_content_read_inline_image_end(cursor)
  decoded
}

///|
fn pdf_content_read_lzw_inline_image_data(
  cursor : ByteCursor,
  dictionary : PdfObject,
  decode_parms : PdfObject?,
) -> PdfBytes raise PdfError {
  match cursor.peek_byte() {
    value if pdf_is_whitespace_byte(value) => cursor.nudge()
    _ => ()
  }
  let with_decode_parms = match decode_parms {
    Some(value) =>
      dictionary.add_dict_entry(pdf_content_inline_dp_name(), value)
    None => dictionary
  }
  let (_, length) = @codec.pdf_lzw_decode_view_prefix(
    cursor.remaining_view(),
    early_change=pdf_lzw_early_change(with_decode_parms),
  )
  let data = cursor.read_view(length).to_owned()
  pdf_content_read_inline_image_end(cursor)
  data
}

///|
fn pdf_content_read_lzw_inline_image_decoded(
  cursor : ByteCursor,
) -> PdfBytes raise PdfError {
  match cursor.peek_byte() {
    value if pdf_is_whitespace_byte(value) => cursor.nudge()
    _ => ()
  }
  let (decoded, length) = @codec.pdf_lzw_decode_view_prefix(
    cursor.remaining_view(),
  )
  ignore(cursor.read_view(length))
  pdf_content_read_inline_image_end(cursor)
  decoded
}
