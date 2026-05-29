///|
fn pdf_cursor_input_next_hex_byte(cursor : ByteCursor) -> Int {
  let mut result = pdf_no_more
  let mut done = false
  while !done {
    let value = cursor.input_byte()
    if value == pdf_no_more || pdf_is_not_whitespace_byte(value) {
      result = value
      done = true
    }
  }
  result
}

///|
fn pdf_cursor_hex_string_output_capacity(cursor : ByteCursor) -> Int {
  let mut index = cursor.absolute_position()
  let mut digits = 0
  let mut done = false
  while index < cursor.length() && !done {
    let value = cursor.byte_int_at_absolute(index)
    index += 1
    if value == 62 {
      done = true
    } else if pdf_is_not_whitespace_byte(value) {
      digits += 1
    }
  }
  (digits + 1) / 2
}

///|
/// Lex a PDF hexadecimal string.
///
/// The opening `<` must not be a dictionary delimiter `<<`. White space inside
/// the hex string is ignored, odd trailing nibbles are padded in the PDF way,
/// and invalid hex digits raise `PdfError::InvalidHexEscape`.
pub fn pdf_cursor_lex_hex_string(
  cursor : ByteCursor,
) -> PdfLexeme raise PdfError {
  let position = cursor.absolute_position()
  if cursor.peek_byte() != 60 || cursor.byte_int_at_absolute(position + 1) == 60 {
    LexNone
  } else {
    cursor.nudge()
    let bytes = Array::make(
      pdf_cursor_hex_string_output_capacity(cursor),
      b'\x00',
    )
    let mut position = 0
    let mut done = false
    while !done {
      let high = pdf_cursor_input_next_hex_byte(cursor)
      if high == pdf_no_more || high == 62 {
        done = true
      } else {
        let low = pdf_cursor_input_next_hex_byte(cursor)
        if low == pdf_no_more {
          done = true
        } else {
          match (pdf_hex_value(high), low) {
            (Some(high), 62) => {
              position = pdf_lexeme_write_byte_at(
                bytes,
                position,
                (high * 16).to_byte(),
              )
              done = true
            }
            (Some(high), low) =>
              match pdf_hex_value(low) {
                Some(low) =>
                  position = pdf_lexeme_write_byte_at(
                    bytes,
                    position,
                    (high * 16 + low).to_byte(),
                  )
                None => raise InvalidHexEscape
              }
            _ => raise InvalidHexEscape
          }
        }
      }
    }
    LexString(Bytes::from_array(bytes[:position]))
  }
}
