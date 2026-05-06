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
pub fn pdf_is_newline_byte(value : Int) -> Bool {
  value == 10 || value == 13
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
  try! self.read_until_view(pdf_is_whitespace_or_delimiter_byte)
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
fn pdf_is_octal_digit_byte(value : Int) -> Bool {
  value >= 48 && value <= 55
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
  } else if pdf_number_view_has_real_marker(view) {
    pdf_number_view_real(view)
  } else {
    match pdf_number_view_int(view) {
      Some(value) => LexInt(value)
      None => pdf_number_view_real(view)
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

///|
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
) -> Unit raise PdfError {
  let escaped = self.input_byte()
  match escaped {
    110 => bytes.push((10).to_byte())
    114 => bytes.push((13).to_byte())
    116 => bytes.push((9).to_byte())
    98 => bytes.push((8).to_byte())
    102 => bytes.push((12).to_byte())
    13 => {
      let next = self.input_byte()
      if next != 10 && next != pdf_no_more {
        self.rewind()
      }
    }
    10 => ()
    value if pdf_is_octal_digit_byte(value) =>
      bytes.push(self.read_pdf_octal_escape(value))
    value if value == pdf_no_more => raise EndOfInput
    value => bytes.push(value.to_byte())
  }
}

///|
pub fn ByteCursor::lex_pdf_literal_string(
  self : ByteCursor,
) -> PdfLexeme raise PdfError {
  if self.peek_byte() != 40 {
    LexNone
  } else {
    self.nudge()
    let bytes : Array[Byte] = []
    let mut depth = 1
    while depth > 0 {
      let value = self.input_byte()
      match value {
        40 => {
          depth += 1
          bytes.push((40).to_byte())
        }
        41 => {
          depth -= 1
          if depth > 0 {
            bytes.push((41).to_byte())
          }
        }
        92 => self.read_pdf_string_escape_into(bytes)
        value if value == pdf_no_more => raise EndOfInput
        value => bytes.push(value.to_byte())
      }
    }
    LexString(Bytes::from_array(bytes))
  }
}

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
pub fn ByteCursor::lex_pdf_hex_string(
  self : ByteCursor,
) -> PdfLexeme raise PdfError {
  let position = self.absolute_position()
  if self.peek_byte() != 60 ||
    (
      position + 1 < self.data.length() &&
      self.data[position + 1].to_int() == 60
    ) {
    LexNone
  } else {
    self.nudge()
    let bytes : Array[Byte] = []
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
              bytes.push((high * 16).to_byte())
              done = true
            }
            (Some(high), low) =>
              match pdf_hex_value(low) {
                Some(low) => bytes.push((high * 16 + low).to_byte())
                None => raise InvalidHexEscape
              }
            _ => raise InvalidHexEscape
          }
        }
      }
    }
    LexString(Bytes::from_array(bytes))
  }
}

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
fn ByteCursor::matches_pdf_ascii_at(
  self : ByteCursor,
  position : Int,
  values : ArrayView[Int],
) -> Bool {
  if position < 0 || position + values.length() > self.data.length() {
    false
  } else {
    for i = 0; i < values.length(); i = i + 1 {
      if self.data[position + i].to_int() != values[i] {
        break false
      }
    } nobreak {
      true
    }
  }
}

///|
pub fn ByteCursor::lex_pdf_keyword(
  self : ByteCursor,
) -> PdfLexeme raise PdfError {
  self.drop_pdf_whitespace()
  let start = self.position()
  let view = self.read_until_pdf_whitespace_or_delimiter()
  match view {
    [111, 98, 106] => LexObj
    [101, 110, 100, 111, 98, 106] => LexEndObj
    [82] => LexR
    [110, 117, 108, 108] => LexNull
    [101, 110, 100, 115, 116, 114, 101, 97, 109] => LexEndStream
    view if pdf_view_starts_with_endobj(view) => {
      self.seek(start + 6)
      LexEndObj
    }
    _ => LexNone
  }
}

///|
fn pdf_is_number_start_byte(value : Int) -> Bool {
  (value >= 48 && value <= 57) || value == 43 || value == 45 || value == 46
}

///|
fn pdf_is_lowercase_keyword_start_byte(value : Int) -> Bool {
  value >= 97 && value <= 122
}

///|
pub fn ByteCursor::lex_pdf_delimiter(self : ByteCursor) -> PdfLexeme {
  self.drop_pdf_whitespace()
  let position = self.absolute_position()
  match self.peek_byte() {
    91 => {
      self.nudge()
      LexLeftSquare
    }
    93 => {
      self.nudge()
      LexRightSquare
    }
    value if value == 60 &&
      position + 1 < self.data.length() &&
      self.data[position + 1].to_int() == 60 => {
      self.nudge()
      self.nudge()
      LexLeftDict
    }
    value if value == 62 &&
      position + 1 < self.data.length() &&
      self.data[position + 1].to_int() == 62 => {
      self.nudge()
      self.nudge()
      LexRightDict
    }
    _ => LexNone
  }
}

///|
pub fn ByteCursor::lex_pdf_token(self : ByteCursor) -> PdfLexeme raise PdfError {
  self.drop_pdf_whitespace()
  let position = self.absolute_position()
  let value = self.peek_byte()
  match value {
    value if value == pdf_no_more => StopLexing
    37 => self.lex_pdf_comment()
    116 | 102 => self.lex_pdf_bool()
    47 => self.lex_pdf_name()
    value if pdf_is_number_start_byte(value) => self.lex_pdf_number()
    91 | 93 => self.lex_pdf_delimiter()
    40 => self.lex_pdf_literal_string()
    60 =>
      if self.matches_pdf_ascii_at(position, [60, 60]) {
        self.lex_pdf_delimiter()
      } else {
        self.lex_pdf_hex_string()
      }
    62 => self.lex_pdf_delimiter()
    82 => {
      self.nudge()
      LexR
    }
    115 =>
      // `startxref` terminates object lexing; any other `s...` marker is left
      // for the stream reader so malformed spellings report stream errors.
      StopLexing
    73 => StopLexing
    value if pdf_is_lowercase_keyword_start_byte(value) =>
      self.lex_pdf_keyword()
    _ => LexNone
  }
}

///|
pub fn ByteCursor::lex_pdf_tokens(
  self : ByteCursor,
) -> Array[PdfLexeme] raise PdfError {
  let tokens : Array[PdfLexeme] = []
  let mut done = false
  while !done {
    match self.lex_pdf_token() {
      StopLexing | LexNone => done = true
      token => tokens.push(token)
    }
  }
  tokens
}

///|
pub fn pdf_lex_single_view(data : BytesView) -> PdfLexeme raise PdfError {
  byte_cursor_of_view(data).lex_pdf_token()
}

///|
pub fn pdf_lex_view(data : BytesView) -> Array[PdfLexeme] raise PdfError {
  byte_cursor_of_view(data).lex_pdf_tokens()
}

///|
pub fn pdf_lex_bytes(data : PdfBytes) -> Array[PdfLexeme] raise PdfError {
  pdf_lex_view(data[:])
}
