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
