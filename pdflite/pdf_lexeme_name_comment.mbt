///|
fn ByteCursor::pdf_name_output_capacity(self : ByteCursor) -> Int {
  let mut index = self.absolute_position()
  let mut capacity = 1
  let mut done = false
  while index < self.data.length() && !done {
    let value = self.data[index].to_int()
    if pdf_is_whitespace_or_delimiter_byte(value) {
      done = true
    } else {
      index += 1
      capacity += 1
      if value == 35 {
        if index < self.data.length() {
          index += 1
        }
        if index < self.data.length() {
          index += 1
        }
      }
    }
  }
  capacity
}

///|
/// Lex a PDF name object.
///
/// Names start with `/` and keep the slash in the stored bytes. `#xx` hex
/// escapes are decoded into raw bytes. Invalid escapes raise `PdfError::InvalidHexEscape`;
/// non-name input returns `LexNone` without consuming it.
pub fn ByteCursor::lex_pdf_name(self : ByteCursor) -> PdfLexeme raise PdfError {
  if self.peek_byte() != 47 {
    LexNone
  } else {
    self.nudge()
    let bytes = Array::make(self.pdf_name_output_capacity(), b'\x00')
    let mut position = pdf_lexeme_write_byte_at(bytes, 0, (47).to_byte())
    let mut done = false
    while !done {
      let value = self.peek_byte()
      if value == pdf_no_more || pdf_is_whitespace_or_delimiter_byte(value) {
        done = true
      } else {
        self.nudge()
        if value == 35 {
          let high = self.input_byte()
          let low = self.input_byte()
          match (pdf_hex_value(high), pdf_hex_value(low)) {
            (Some(high), Some(low)) =>
              position = pdf_lexeme_write_byte_at(
                bytes,
                position,
                (high * 16 + low).to_byte(),
              )
            _ => raise InvalidHexEscape
          }
        } else {
          position = pdf_lexeme_write_byte_at(bytes, position, value.to_byte())
        }
      }
    }
    LexName(pdf_name_of_bytes(Bytes::from_array(bytes[:position])))
  }
}

///|
/// Lex and skip a PDF comment.
///
/// A comment starts with `%` and runs up to but not including the next newline.
/// The comment text is intentionally not retained; this returns an empty
/// `LexComment` payload. Non-comment input returns `LexNone`.
pub fn ByteCursor::lex_pdf_comment(self : ByteCursor) -> PdfLexeme {
  if self.peek_byte() != 37 {
    LexNone
  } else {
    let empty : Array[Byte] = []
    let mut done = false
    while !done {
      let value = self.peek_byte()
      if value == pdf_no_more || pdf_is_newline_byte(value) {
        done = true
      } else {
        self.nudge()
      }
    }
    LexComment(Bytes::from_array(empty))
  }
}
