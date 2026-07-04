///|
fn pdf_writer_push_byte(output : Array[Byte], value : Int) -> Unit {
  output.push(value.to_byte())
}

///|
fn pdf_writer_push_view(output : Array[Byte], view : BytesView) -> Unit {
  for byte in view {
    output.push(byte)
  }
}

///|
fn pdf_writer_push_ascii(output : Array[Byte], text : String) -> Unit {
  pdf_writer_push_view(output, @ascii.encode(text))
}

///|
fn pdf_writer_hex_digit(value : Int) -> Byte {
  if value < 10 {
    (48 + value).to_byte()
  } else {
    (55 + value).to_byte()
  }
}

///|
fn pdf_writer_lower_hex_digit(value : Int) -> Byte {
  if value < 10 {
    (48 + value).to_byte()
  } else {
    (87 + value).to_byte()
  }
}

///|
fn pdf_writer_push_hex_escape(output : Array[Byte], value : Int) -> Unit {
  pdf_writer_push_byte(output, 35)
  output.push(pdf_writer_hex_digit(value / 16))
  output.push(pdf_writer_hex_digit(value % 16))
}

///|
fn pdf_writer_push_octal_escape(output : Array[Byte], value : Int) -> Unit {
  pdf_writer_push_byte(output, 92)
  pdf_writer_push_byte(output, 48 + value / 64)
  pdf_writer_push_byte(output, 48 + value / 8 % 8)
  pdf_writer_push_byte(output, 48 + value % 8)
}
