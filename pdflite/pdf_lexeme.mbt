///|
pub(all) enum PdfLexeme {
  LexNull
  LexBool(Bool)
  LexInt(Int)
  LexReal(Double)
  LexString(PdfBytes)
  LexName(PdfName)
  LexLeftSquare
  LexRightSquare
  LexLeftDict
  LexRightDict
  LexStream(PdfStreamData)
  LexEndStream
  LexObj
  LexEndObj
  LexR
  LexComment(PdfBytes)
  StopLexing
  LexNone
} derive(Debug, Eq, ToJson)

///|
pub fn pdf_is_whitespace_byte(value : Int) -> Bool {
  match value {
    0 | 9 | 10 | 12 | 13 | 32 => true
    _ => false
  }
}

///|
pub fn pdf_is_not_whitespace_byte(value : Int) -> Bool {
  !pdf_is_whitespace_byte(value)
}

///|
pub fn pdf_is_delimiter_byte(value : Int) -> Bool {
  match value {
    40 | 41 | 47 | 60 | 62 | 91 | 93 | 123 | 125 | 37 => true
    _ => false
  }
}

///|
pub fn pdf_is_whitespace_or_delimiter_byte(value : Int) -> Bool {
  pdf_is_whitespace_byte(value) || pdf_is_delimiter_byte(value)
}

///|
pub fn ByteCursor::drop_pdf_whitespace(self : ByteCursor) -> Unit {
  let mut done = false
  while !done {
    let value = self.peek_byte()
    if value == pdf_no_more || pdf_is_not_whitespace_byte(value) {
      done = true
    } else {
      self.nudge()
    }
  }
}

///|
pub fn ByteCursor::read_until_pdf_whitespace_or_delimiter(
  self : ByteCursor,
) -> BytesView {
  let start = self.absolute_position()
  let mut done = false
  while !done {
    let value = self.peek_byte()
    if value == pdf_no_more || pdf_is_whitespace_or_delimiter_byte(value) {
      done = true
    } else {
      self.nudge()
    }
  }
  self.data[start:self.absolute_position()]
}

///|
pub fn ByteCursor::read_pdf_regular_token_view(self : ByteCursor) -> BytesView {
  self.drop_pdf_whitespace()
  self.read_until_pdf_whitespace_or_delimiter()
}

///|
pub fn pdf_lexeme_debug_name(lexeme : PdfLexeme) -> String {
  match lexeme {
    LexNull => "LexNull"
    LexBool(_) => "LexBool"
    LexInt(_) => "LexInt"
    LexReal(_) => "LexReal"
    LexString(_) => "LexString"
    LexName(_) => "LexName"
    LexLeftSquare => "LexLeftSquare"
    LexRightSquare => "LexRightSquare"
    LexLeftDict => "LexLeftDict"
    LexRightDict => "LexRightDict"
    LexStream(_) => "LexStream"
    LexEndStream => "LexEndStream"
    LexObj => "LexObj"
    LexEndObj => "LexEndObj"
    LexR => "LexR"
    LexComment(_) => "LexComment"
    StopLexing => "StopLexing"
    LexNone => "LexNone"
  }
}

///|
fn pdf_hex_value(value : Int) -> Int? {
  if value >= 48 && value <= 57 {
    Some(value - 48)
  } else if value >= 65 && value <= 70 {
    Some(value - 55)
  } else if value >= 97 && value <= 102 {
    Some(value - 87)
  } else {
    None
  }
}

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
  for i = 0; i < view.length(); i = i + 1 {
    let value = view[i].to_int()
    if value == 46 || value == 69 || value == 101 {
      break true
    }
  } nobreak {
    false
  }
}

///|
pub fn ByteCursor::lex_pdf_bool(self : ByteCursor) -> PdfLexeme {
  let view = self.read_pdf_regular_token_view()
  match view {
    [116, 114, 117, 101] => LexBool(true)
    [102, 97, 108, 115, 101] => LexBool(false)
    _ => LexNone
  }
}

///|
pub fn ByteCursor::lex_pdf_number(self : ByteCursor) -> PdfLexeme {
  let view = pdf_number_view_without_double_minus(
    self.read_pdf_regular_token_view(),
  )
  if view.length() == 0 {
    LexNone
  } else {
    try @ascii.decode(view) catch {
      _ => LexNone
    } noraise {
      text =>
        if pdf_number_view_has_real_marker(view) {
          let real : Result[Double, Error] = try? @strconv.from_str(text)
          match real {
            Ok(value) => LexReal(value)
            Err(_) => LexNone
          }
        } else {
          let integer : Result[Int, Error] = try? @strconv.from_str(text)
          match integer {
            Ok(value) => LexInt(value)
            Err(_) => {
              let real : Result[Double, Error] = try? @strconv.from_str(text)
              match real {
                Ok(value) => LexReal(value)
                Err(_) => LexNone
              }
            }
          }
        }
    }
  }
}

///|
pub fn ByteCursor::lex_pdf_name(self : ByteCursor) -> PdfLexeme raise PdfError {
  if self.peek_byte() != 47 {
    LexNone
  } else {
    self.nudge()
    let bytes : Array[Byte] = [47]
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
            (Some(high), Some(low)) => bytes.push((high * 16 + low).to_byte())
            _ => raise InvalidHexEscape
          }
        } else {
          bytes.push(value.to_byte())
        }
      }
    }
    LexName(pdf_name_of_bytes(Bytes::from_array(bytes)))
  }
}
