///|
fn pdf_write_string_to(output : Array[Byte], bytes : BytesView) -> Unit {
  pdf_writer_push_byte(output, 40)
  for byte in bytes {
    let value = byte.to_int()
    match value {
      40 => pdf_writer_push_ascii(output, "\\(")
      41 => pdf_writer_push_ascii(output, "\\)")
      92 => pdf_writer_push_ascii(output, "\\\\")
      10 => pdf_writer_push_ascii(output, "\\n")
      13 => pdf_writer_push_ascii(output, "\\r")
      9 => pdf_writer_push_ascii(output, "\\t")
      8 => pdf_writer_push_ascii(output, "\\b")
      12 => pdf_writer_push_ascii(output, "\\f")
      value if value >= 32 && value <= 126 => output.push(byte)
      _ => pdf_writer_push_octal_escape(output, value)
    }
  }
  pdf_writer_push_byte(output, 41)
}

///|
fn pdf_write_literal_string_length(bytes : BytesView) -> Int {
  let mut length = 2
  for byte in bytes {
    let value = byte.to_int()
    match value {
      40 | 41 | 92 | 10 | 13 | 9 | 8 | 12 => length += 2
      value if value >= 32 && value <= 126 => length += 1
      _ => length += 4
    }
  }
  length
}

///|
fn pdf_write_literal_escape_byte(
  output : Array[Byte],
  position : Int,
  value : Byte,
) -> Int {
  output[position] = b'\\'
  output[position + 1] = value
  position + 2
}

///|
/// Serialize bytes as a PDF literal string.
///
/// Delimiters, backslashes, common controls, and non-printable bytes are
/// escaped according to PDF literal-string syntax.
pub fn pdf_write_literal_string(bytes : BytesView) -> @core.PdfBytes {
  let output = Array::make(pdf_write_literal_string_length(bytes), b')')
  output[0] = b'('
  let mut position = 1
  for byte in bytes {
    let value = byte.to_int()
    match value {
      40 => position = pdf_write_literal_escape_byte(output, position, b'(')
      41 => position = pdf_write_literal_escape_byte(output, position, b')')
      92 => position = pdf_write_literal_escape_byte(output, position, b'\\')
      10 => position = pdf_write_literal_escape_byte(output, position, b'n')
      13 => position = pdf_write_literal_escape_byte(output, position, b'r')
      9 => position = pdf_write_literal_escape_byte(output, position, b't')
      8 => position = pdf_write_literal_escape_byte(output, position, b'b')
      12 => position = pdf_write_literal_escape_byte(output, position, b'f')
      value if value >= 32 && value <= 126 => {
        output[position] = byte
        position += 1
      }
      _ => {
        output[position] = b'\\'
        output[position + 1] = (48 + value / 64).to_byte()
        output[position + 2] = (48 + value / 8 % 8).to_byte()
        output[position + 3] = (48 + value % 8).to_byte()
        position += 4
      }
    }
  }
  Bytes::from_array(output)
}

///|
/// Compatibility alias for `pdf_write_literal_string`.
pub fn pdf_make_pdf_string(bytes : BytesView) -> @core.PdfBytes {
  pdf_write_literal_string(bytes)
}

///|
/// Serialize bytes as a lowercase hexadecimal PDF string.
pub fn pdf_write_hex_string(bytes : BytesView) -> @core.PdfBytes {
  let output = Array::make(bytes.length() * 2 + 2, b'>')
  output[0] = b'<'
  let mut position = 1
  for byte in bytes {
    let value = byte.to_int()
    output[position] = pdf_writer_lower_hex_digit(value / 16)
    output[position + 1] = pdf_writer_lower_hex_digit(value % 16)
    position += 2
  }
  Bytes::from_array(output)
}

///|
/// Compatibility alias for `pdf_write_hex_string`.
pub fn pdf_make_hex_pdf_string(bytes : BytesView) -> @core.PdfBytes {
  pdf_write_hex_string(bytes)
}
