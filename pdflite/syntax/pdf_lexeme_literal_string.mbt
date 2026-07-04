///|
fn pdf_cursor_read_octal_escape(
  cursor : @core.ByteCursor,
  first : Int,
) -> Byte raise @core.PdfError {
  let mut value = first - 48
  let second = cursor.input_byte()
  if pdf_is_octal_digit_byte(second) {
    value = value * 8 + second - 48
    let third = cursor.input_byte()
    if pdf_is_octal_digit_byte(third) {
      value = value * 8 + third - 48
    } else if third != @core.pdf_no_more {
      cursor.rewind()
    }
  } else if second != @core.pdf_no_more {
    cursor.rewind()
  }
  @core.pdf_byte_of_int(value)
}

///|
fn pdf_cursor_read_string_escape_into(
  cursor : @core.ByteCursor,
  bytes : Array[Byte],
  position : Int,
) -> Int raise @core.PdfError {
  let escaped = cursor.input_byte()
  match escaped {
    110 => pdf_lexeme_write_byte_at(bytes, position, (10).to_byte())
    114 => pdf_lexeme_write_byte_at(bytes, position, (13).to_byte())
    116 => pdf_lexeme_write_byte_at(bytes, position, (9).to_byte())
    98 => pdf_lexeme_write_byte_at(bytes, position, (8).to_byte())
    102 => pdf_lexeme_write_byte_at(bytes, position, (12).to_byte())
    13 => {
      let next = cursor.input_byte()
      if next != 10 && next != @core.pdf_no_more {
        cursor.rewind()
      }
      position
    }
    10 => position
    value if pdf_is_octal_digit_byte(value) =>
      pdf_lexeme_write_byte_at(
        bytes,
        position,
        pdf_cursor_read_octal_escape(cursor, value),
      )
    value if value == @core.pdf_no_more => raise EndOfInput
    value => pdf_lexeme_write_byte_at(bytes, position, value.to_byte())
  }
}

///|
fn pdf_cursor_literal_string_output_capacity(cursor : @core.ByteCursor) -> Int {
  let mut index = cursor.absolute_position()
  let mut capacity = 0
  let mut depth = 1
  while index < cursor.length() && depth > 0 {
    let value = cursor.byte_int_at_absolute(index)
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
        if index < cursor.length() {
          let escaped = cursor.byte_int_at_absolute(index)
          index += 1
          match escaped {
            13 =>
              if index < cursor.length() &&
                cursor.byte_int_at_absolute(index) == 10 {
                index += 1
              }
            10 => ()
            value if pdf_is_octal_digit_byte(value) => {
              if index < cursor.length() &&
                pdf_is_octal_digit_byte(cursor.byte_int_at_absolute(index)) {
                index += 1
                if index < cursor.length() &&
                  pdf_is_octal_digit_byte(cursor.byte_int_at_absolute(index)) {
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
/// raise `@core.PdfError::EndOfInput`.
pub fn pdf_cursor_lex_literal_string(
  cursor : @core.ByteCursor,
) -> PdfLexeme raise @core.PdfError {
  if cursor.peek_byte() != 40 {
    LexNone
  } else {
    cursor.nudge()
    let bytes = Array::make(
      pdf_cursor_literal_string_output_capacity(cursor),
      b'\x00',
    )
    let mut position = 0
    let mut depth = 1
    while depth > 0 {
      let value = cursor.input_byte()
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
        92 =>
          position = pdf_cursor_read_string_escape_into(cursor, bytes, position)
        value if value == @core.pdf_no_more => raise EndOfInput
        value =>
          position = pdf_lexeme_write_byte_at(bytes, position, value.to_byte())
      }
    }
    LexString(Bytes::from_array(bytes[:position]))
  }
}
