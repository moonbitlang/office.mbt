///|
fn ByteCursor::input_next_pdf_hex_byte(self : ByteCursor) -> Int {
  let mut result = pdf_no_more
  let mut done = false
  while !done {
    let value = self.input_byte()
    if value == pdf_no_more || pdf_is_not_whitespace_byte(value) {
      result = value
      done = true
    }
  }
  result
}

///|
fn ByteCursor::pdf_hex_string_output_capacity(self : ByteCursor) -> Int {
  let mut index = self.absolute_position()
  let mut digits = 0
  let mut done = false
  while index < self.length() && !done {
    let value = self.byte_int_at_absolute(index)
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
pub fn ByteCursor::lex_pdf_hex_string(
  self : ByteCursor,
) -> PdfLexeme raise PdfError {
  let position = self.absolute_position()
  if self.peek_byte() != 60 || self.byte_int_at_absolute(position + 1) == 60 {
    LexNone
  } else {
    self.nudge()
    let bytes = Array::make(self.pdf_hex_string_output_capacity(), b'\x00')
    let mut position = 0
    let mut done = false
    while !done {
      let high = self.input_next_pdf_hex_byte()
      if high == pdf_no_more || high == 62 {
        done = true
      } else {
        let low = self.input_next_pdf_hex_byte()
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
