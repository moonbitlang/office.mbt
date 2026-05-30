///|
fn pdf_content_ascii_hex_encoded_length(data : BytesView) -> Int? {
  for index in 0..<data.length() {
    if data[index].to_int() == 62 {
      return Some(index + 1)
    }
  }
  None
}

///|
fn pdf_content_ascii85_encoded_length(data : BytesView) -> Int? {
  let mut index = 0
  while index + 1 < data.length() {
    if data[index].to_int() == 126 && data[index + 1].to_int() == 62 {
      return Some(index + 2)
    }
    index += 1
  }
  None
}

///|
fn pdf_content_text_encoded_inline_image_length(
  data : BytesView,
  filter : PdfContentInlineTextFilter,
) -> Int? {
  match filter {
    PdfContentInlineAsciiHex => pdf_content_ascii_hex_encoded_length(data)
    PdfContentInlineAscii85 => pdf_content_ascii85_encoded_length(data)
  }
}

///|
fn pdf_content_read_text_encoded_inline_image_data(
  cursor : ByteCursor,
  filter : PdfContentInlineTextFilter,
) -> PdfBytes raise PdfError {
  match cursor.peek_byte() {
    value if pdf_is_whitespace_byte(value) => cursor.nudge()
    _ => ()
  }
  match
    pdf_content_text_encoded_inline_image_length(
      cursor.remaining_view(),
      filter,
    ) {
    Some(length) => {
      let data = cursor.read_view(length).to_owned()
      pdf_content_read_inline_image_end(cursor)
      data
    }
    None => raise ParseEndStreamExpected
  }
}

///|
fn pdf_content_read_text_encoded_inline_image_decoded(
  cursor : ByteCursor,
  filter : PdfContentInlineTextFilter,
) -> PdfBytes raise PdfError {
  match cursor.peek_byte() {
    value if pdf_is_whitespace_byte(value) => cursor.nudge()
    _ => ()
  }
  match
    pdf_content_text_encoded_inline_image_length(
      cursor.remaining_view(),
      filter,
    ) {
    Some(length) => {
      let encoded = cursor.read_view(length)
      let decoded = match filter {
        PdfContentInlineAsciiHex => @codec.pdf_ascii_hex_decode_view(encoded)
        PdfContentInlineAscii85 => @codec.pdf_ascii85_decode_view(encoded)
      }
      pdf_content_read_inline_image_end(cursor)
      decoded
    }
    None => raise ParseEndStreamExpected
  }
}
