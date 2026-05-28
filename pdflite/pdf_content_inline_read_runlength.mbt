///|
fn pdf_content_run_length_encoded_length(data : BytesView) -> Int? {
  let mut index = 0
  while index < data.length() {
    let control = data[index].to_int()
    index += 1
    if control < 128 {
      index += control + 1
    } else if control > 128 {
      index += 1
    } else {
      return Some(index)
    }
  }
  None
}

///|
fn pdf_content_read_run_length_inline_image_data(
  cursor : ByteCursor,
) -> PdfBytes raise PdfError {
  match cursor.peek_byte() {
    value if pdf_is_whitespace_byte(value) => cursor.nudge()
    _ => ()
  }
  match pdf_content_run_length_encoded_length(cursor.remaining_view()) {
    Some(length) => {
      let data = cursor.read_view(length).to_owned()
      pdf_content_read_inline_image_end(cursor)
      data
    }
    None => raise ParseEndStreamExpected
  }
}

///|
fn pdf_content_run_length_decode_view_prefix(
  data : BytesView,
) -> (PdfBytes, Int) raise PdfError {
  let (output_length, consumed) = pdf_content_run_length_decoded_prefix_length(
    data,
  )
  let output = Array::make(output_length, b'\x00')
  let mut output_index = 0
  let mut index = 0
  while output_index < output_length {
    let control = data[index].to_int()
    index += 1
    if control < 128 {
      let wanted = control + 1
      for i in 0..<wanted {
        output[output_index] = data[index + i]
        output_index += 1
      }
      index += wanted
    } else {
      let value = data[index]
      index += 1
      for _ in 0..<(257 - control) {
        output[output_index] = value
        output_index += 1
      }
    }
  }
  (Bytes::from_array(output), consumed)
}

///|
fn pdf_content_run_length_decoded_prefix_length(
  data : BytesView,
) -> (Int, Int) raise PdfError {
  let mut output_length = 0
  let mut index = 0
  while index < data.length() {
    let control = data[index].to_int()
    index += 1
    if control < 128 {
      let wanted = control + 1
      if index + wanted > data.length() {
        raise ParseEndStreamExpected
      }
      output_length += wanted
      index += wanted
    } else if control > 128 {
      if index >= data.length() {
        raise ParseEndStreamExpected
      }
      index += 1
      output_length += 257 - control
    } else {
      return (output_length, index)
    }
  }
  raise ParseEndStreamExpected
}

///|
fn pdf_content_read_run_length_inline_image_decoded(
  cursor : ByteCursor,
) -> PdfBytes raise PdfError {
  match cursor.peek_byte() {
    value if pdf_is_whitespace_byte(value) => cursor.nudge()
    _ => ()
  }
  let (decoded, length) = pdf_content_run_length_decode_view_prefix(
    cursor.remaining_view(),
  )
  ignore(cursor.read_view(length))
  pdf_content_read_inline_image_end(cursor)
  decoded
}
