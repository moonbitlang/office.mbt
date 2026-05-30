///|
fn pdf_write_name_to(output : Array[Byte], name : @core.PdfName) -> Unit {
  let bytes = name.bytes()
  let mut start = 0
  pdf_writer_push_byte(output, 47)
  if bytes.length() > 0 && bytes[0].to_int() == 47 {
    start = 1
  }
  for i in start..<bytes.length() {
    let value = bytes[i].to_int()
    if value < 33 ||
      value > 126 ||
      @core.pdf_is_delimiter_byte(value) ||
      value == 35 {
      pdf_writer_push_hex_escape(output, value)
    } else {
      output.push(bytes[i])
    }
  }
}

///|
fn pdf_write_name_start(bytes : BytesView) -> Int {
  if bytes.length() > 0 && bytes[0].to_int() == 47 {
    1
  } else {
    0
  }
}

///|
fn pdf_write_name_length(bytes : BytesView, start : Int) -> Int {
  let mut length = 1
  for i in start..<bytes.length() {
    let value = bytes[i].to_int()
    if value < 33 ||
      value > 126 ||
      @core.pdf_is_delimiter_byte(value) ||
      value == 35 {
      length += 3
    } else {
      length += 1
    }
  }
  length
}

///|
fn pdf_writer_hex_escape_at(
  output : Array[Byte],
  position : Int,
  value : Int,
) -> Int {
  output[position] = b'#'
  output[position + 1] = pdf_writer_hex_digit(value / 16)
  output[position + 2] = pdf_writer_hex_digit(value % 16)
  position + 3
}

///|
/// Serialize a PDF name object with required delimiter and hex escaping.
///
/// The returned bytes include the leading slash.
pub fn pdf_write_name(name : @core.PdfName) -> @core.PdfBytes {
  let bytes = name.bytes()
  let start = pdf_write_name_start(bytes)
  let output = Array::make(pdf_write_name_length(bytes, start), b'\x00')
  output[0] = b'/'
  let mut position = 1
  for i in start..<bytes.length() {
    let value = bytes[i].to_int()
    if value < 33 ||
      value > 126 ||
      @core.pdf_is_delimiter_byte(value) ||
      value == 35 {
      position = pdf_writer_hex_escape_at(output, position, value)
    } else {
      output[position] = bytes[i]
      position += 1
    }
  }
  Bytes::from_array(output)
}
