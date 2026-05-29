///|
fn pdf_view_starts_with_endobj(view : BytesView) -> Bool {
  view.length() > 6 &&
  view[0].to_int() == 101 &&
  view[1].to_int() == 110 &&
  view[2].to_int() == 100 &&
  view[3].to_int() == 111 &&
  view[4].to_int() == 98 &&
  view[5].to_int() == 106
}

///|
/// Check whether `cursor` contains the ASCII byte sequence at an absolute position.
pub fn pdf_cursor_matches_ascii_at(
  cursor : @core.ByteCursor,
  position : Int,
  values : ArrayView[Int],
) -> Bool {
  let view_result : Result[BytesView, Error] = try? cursor.view_at_absolute(
    position,
    values.length(),
  )
  match view_result {
    Ok(view) =>
      for i in 0..<values.length() {
        if view[i].to_int() != values[i] {
          break false
        }
      } nobreak {
        true
      }
    Err(_) => false
  }
}

///|
/// Lex PDF structural keywords.
///
/// Recognized keywords include `obj`, `endobj`, `R`, `null`, and `endstream`.
/// If a token begins with `endobj` followed by extra bytes, only `endobj` is
/// consumed so the suffix can be lexed by later calls.
pub fn pdf_cursor_lex_keyword(
  cursor : @core.ByteCursor,
) -> PdfLexeme raise @core.PdfError {
  pdf_cursor_drop_whitespace(cursor)
  let start = cursor.position()
  let view = pdf_cursor_read_until_whitespace_or_delimiter(cursor)
  match view {
    [111, 98, 106] => LexObj
    [101, 110, 100, 111, 98, 106] => LexEndObj
    [82] => LexR
    [110, 117, 108, 108] => LexNull
    [101, 110, 100, 115, 116, 114, 101, 97, 109] => LexEndStream
    view if pdf_view_starts_with_endobj(view) => {
      cursor.seek(start + 6)
      LexEndObj
    }
    _ => LexNone
  }
}

///|
/// Return whether a byte can start a PDF numeric token.
pub fn pdf_is_number_start_byte(value : Int) -> Bool {
  (value >= 48 && value <= 57) || value == 43 || value == 45 || value == 46
}

///|
fn pdf_is_lowercase_keyword_start_byte(value : Int) -> Bool {
  value >= 97 && value <= 122
}
