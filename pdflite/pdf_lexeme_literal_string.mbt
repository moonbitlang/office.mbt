///|
fn ByteCursor::read_pdf_octal_escape(
  self : ByteCursor,
  first : Int,
) -> Byte raise PdfError {
  let mut value = first - 48
  let second = self.input_byte()
  if pdf_is_octal_digit_byte(second) {
    value = value * 8 + second - 48
    let third = self.input_byte()
    if pdf_is_octal_digit_byte(third) {
      value = value * 8 + third - 48
    } else if third != pdf_no_more {
      self.rewind()
    }
  } else if second != pdf_no_more {
    self.rewind()
  }
  pdf_byte_of_int(value)
}

///|
fn ByteCursor::read_pdf_string_escape_into(
  self : ByteCursor,
  bytes : Array[Byte],
  position : Int,
) -> Int raise PdfError {
  let escaped = self.input_byte()
  match escaped {
    110 => pdf_lexeme_write_byte_at(bytes, position, (10).to_byte())
    114 => pdf_lexeme_write_byte_at(bytes, position, (13).to_byte())
    116 => pdf_lexeme_write_byte_at(bytes, position, (9).to_byte())
    98 => pdf_lexeme_write_byte_at(bytes, position, (8).to_byte())
    102 => pdf_lexeme_write_byte_at(bytes, position, (12).to_byte())
    13 => {
      let next = self.input_byte()
      if next != 10 && next != pdf_no_more {
        self.rewind()
      }
      position
    }
    10 => position
    value if pdf_is_octal_digit_byte(value) =>
      pdf_lexeme_write_byte_at(
        bytes,
        position,
        self.read_pdf_octal_escape(value),
      )
    value if value == pdf_no_more => raise EndOfInput
    value => pdf_lexeme_write_byte_at(bytes, position, value.to_byte())
  }
}

///|
fn ByteCursor::pdf_literal_string_output_capacity(self : ByteCursor) -> Int {
  let mut index = self.absolute_position()
  let mut capacity = 0
  let mut depth = 1
  while index < self.data.length() && depth > 0 {
    let value = self.data[index].to_int()
    index += 1
    match value {
      40 => {
        depth += 1
        capacity += 1
      }
      41 => {
        depth -= 1
        if depth > 0 {
          capacity += 1
        }
      }
      92 =>
        if index < self.data.length() {
          let escaped = self.data[index].to_int()
          index += 1
          match escaped {
            13 =>
              if index < self.data.length() && self.data[index].to_int() == 10 {
                index += 1
              }
            10 => ()
            value if pdf_is_octal_digit_byte(value) => {
              if index < self.data.length() &&
                pdf_is_octal_digit_byte(self.data[index].to_int()) {
                index += 1
                if index < self.data.length() &&
                  pdf_is_octal_digit_byte(self.data[index].to_int()) {
                  index += 1
                }
              }
              capacity += 1
            }
            _ => capacity += 1
          }
        }
      _ => capacity += 1
    }
  }
  capacity
}

///|
/// Lex a PDF literal string.
///
/// Literal strings are enclosed in parentheses, may contain balanced nested
/// parentheses, and support the PDF backslash escapes for control characters,
/// octal bytes, escaped parentheses, and line continuation. Unterminated strings
/// raise `PdfError::EndOfInput`.
pub fn ByteCursor::lex_pdf_literal_string(
  self : ByteCursor,
) -> PdfLexeme raise PdfError {
  if self.peek_byte() != 40 {
    LexNone
  } else {
    self.nudge()
    let bytes = Array::make(self.pdf_literal_string_output_capacity(), b'\x00')
    let mut position = 0
    let mut depth = 1
    while depth > 0 {
      let value = self.input_byte()
      match value {
        40 => {
          depth += 1
          position = pdf_lexeme_write_byte_at(bytes, position, (40).to_byte())
        }
        41 => {
          depth -= 1
          if depth > 0 {
            position = pdf_lexeme_write_byte_at(bytes, position, (41).to_byte())
          }
        }
        92 => position = self.read_pdf_string_escape_into(bytes, position)
        value if value == pdf_no_more => raise EndOfInput
        value =>
          position = pdf_lexeme_write_byte_at(bytes, position, value.to_byte())
      }
    }
    LexString(Bytes::from_array(bytes[:position]))
  }
}
