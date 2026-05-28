///|
fn pdf_number_view_without_double_minus(view : BytesView) -> BytesView {
  if view.length() > 1 && view[0].to_int() == 45 && view[1].to_int() == 45 {
    view[1:]
  } else {
    view
  }
}

///|
fn pdf_number_view_has_real_marker(view : BytesView) -> Bool {
  for i in 0..<view.length() {
    let value = view[i].to_int()
    if value == 46 || value == 69 || value == 101 {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn pdf_number_view_int(view : BytesView) -> Int? {
  if view.length() == 0 {
    None
  } else {
    let mut index = 0
    let mut negative = false
    match view[0].to_int() {
      43 => index = 1
      45 => {
        negative = true
        index = 1
      }
      _ => ()
    }
    if index >= view.length() {
      None
    } else {
      let limit : Int64 = if negative { 2147483648L } else { 2147483647L }
      let mut value : Int64 = 0L
      let mut valid = true
      while valid && index < view.length() {
        let byte = view[index].to_int()
        if byte < 48 || byte > 57 {
          valid = false
        } else {
          value = value * 10L + (byte - 48).to_int64()
          if value > limit {
            valid = false
          }
          index += 1
        }
      }
      if !valid {
        None
      } else if negative {
        Some((-value).to_int())
      } else {
        Some(value.to_int())
      }
    }
  }
}

///|
fn pdf_number_view_real(view : BytesView) -> PdfLexeme {
  try @ascii.decode(view) catch {
    _ => LexNone
  } noraise {
    text => {
      let real : Result[Double, Error] = try? @strconv.from_str(text)
      match real {
        Ok(value) => LexReal(value)
        Err(_) => LexNone
      }
    }
  }
}

///|
/// Lex `true` or `false` at the current cursor position.
///
/// The cursor first reads one regular token. Non-boolean tokens produce
/// `LexNone`.
pub fn ByteCursor::lex_pdf_bool(self : ByteCursor) -> PdfLexeme {
  let view = self.read_pdf_regular_token_view()
  match view {
    [116, 114, 117, 101] => LexBool(true)
    [102, 97, 108, 115, 101] => LexBool(false)
    _ => LexNone
  }
}

///|
/// Lex a PDF integer or real number.
///
/// Integers are limited to MoonBit `Int` range; oversized integer-looking
/// tokens fall back to real-number parsing. A leading doubled minus is accepted
/// compatibly by dropping one minus sign.
pub fn ByteCursor::lex_pdf_number(self : ByteCursor) -> PdfLexeme {
  let view = pdf_number_view_without_double_minus(
    self.read_pdf_regular_token_view(),
  )
  if view.length() == 0 {
    LexNone
  } else if pdf_number_view_has_real_marker(view) {
    pdf_number_view_real(view)
  } else {
    match pdf_number_view_int(view) {
      Some(value) => LexInt(value)
      None => pdf_number_view_real(view)
    }
  }
}
