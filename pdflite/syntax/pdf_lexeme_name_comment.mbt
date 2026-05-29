///|
fn pdf_cursor_name_output_capacity(cursor : @core.ByteCursor) -> Int {
  let mut index = cursor.absolute_position()
  let mut capacity = 1
  let mut done = false
  while index < cursor.length() && !done {
    let value = cursor.byte_int_at_absolute(index)
    if @core.pdf_is_whitespace_or_delimiter_byte(value) {
      done = true
    } else {
      index += 1
      capacity += 1
      if value == 35 {
        if index < cursor.length() {
          index += 1
        }
        if index < cursor.length() {
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
/// escapes are decoded into raw bytes. Invalid escapes raise `@core.PdfError::InvalidHexEscape`;
/// non-name input returns `LexNone` without consuming it.
pub fn pdf_cursor_lex_name(
  cursor : @core.ByteCursor,
) -> PdfLexeme raise @core.PdfError {
  if cursor.peek_byte() != 47 {
    LexNone
  } else {
    cursor.nudge()
    let bytes = Array::make(pdf_cursor_name_output_capacity(cursor), b'\x00')
    let mut position = pdf_lexeme_write_byte_at(bytes, 0, (47).to_byte())
    let mut done = false
    while !done {
      let value = cursor.peek_byte()
      if value == @core.pdf_no_more ||
        @core.pdf_is_whitespace_or_delimiter_byte(value) {
        done = true
      } else {
        cursor.nudge()
        if value == 35 {
          let high = cursor.input_byte()
          let low = cursor.input_byte()
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
    LexName(@core.pdf_name_of_bytes(Bytes::from_array(bytes[:position])))
  }
}

///|
/// Lex and skip a PDF comment.
///
/// A comment starts with `%` and runs up to but not including the next newline.
/// The comment text is intentionally not retained; this returns an empty
/// `LexComment` payload. Non-comment input returns `LexNone`.
pub fn pdf_cursor_lex_comment(cursor : @core.ByteCursor) -> PdfLexeme {
  if cursor.peek_byte() != 37 {
    LexNone
  } else {
    let empty : Array[Byte] = []
    let mut done = false
    while !done {
      let value = cursor.peek_byte()
      if value == @core.pdf_no_more || @core.pdf_is_newline_byte(value) {
        done = true
      } else {
        cursor.nudge()
      }
    }
    LexComment(Bytes::from_array(empty))
  }
}
