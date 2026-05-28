///|
fn pdf_content_read_inline_image_data(
  cursor : ByteCursor,
) -> PdfBytes raise PdfError {
  match cursor.peek_byte() {
    value if pdf_is_whitespace_byte(value) => cursor.nudge()
    _ => ()
  }
  let view = cursor.remaining_view()
  let mut found = false
  let mut index = 0
  let mut data_length = 0
  let mut skip_before_marker = 0
  while !found && index + 1 < view.length() {
    let is_marker = view[index].to_int() == 69 && view[index + 1].to_int() == 73
    let before_ok = index == 0 ||
      pdf_is_whitespace_byte(view[index - 1].to_int())
    let after_index = index + 2
    let after_ok = after_index >= view.length() ||
      pdf_is_whitespace_byte(view[after_index].to_int())
    if is_marker && before_ok && after_ok {
      found = true
      if index > 0 && pdf_is_whitespace_byte(view[index - 1].to_int()) {
        data_length = index - 1
        skip_before_marker = 1
      } else {
        data_length = index
        skip_before_marker = 0
      }
    } else {
      index += 1
    }
  }
  if !found {
    raise ParseEndStreamExpected
  }
  let data = cursor.read_view(data_length).to_owned()
  if skip_before_marker > 0 {
    ignore(cursor.read_view(skip_before_marker))
  }
  ignore(cursor.read_view(2))
  data
}
