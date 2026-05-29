///|
/// Lex one PDF delimiter token.
///
/// Recognizes `[`, `]`, `<<`, and `>>`. A single `<` or `>` is left unread and
/// returns `LexNone`.
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
    value if value == 60 && self.byte_int_at_absolute(position + 1) == 60 => {
      self.nudge()
      self.nudge()
      LexLeftDict
    }
    value if value == 62 && self.byte_int_at_absolute(position + 1) == 62 => {
      self.nudge()
      self.nudge()
      LexRightDict
    }
    _ => LexNone
  }
}

///|
/// Lex one token from the current cursor position.
///
/// This dispatcher skips white space, recognizes comments, primitives,
/// delimiters, names, literal and hex strings, and selected keywords. It returns
/// `StopLexing` at end of input and at markers that terminate object scanning,
/// such as `startxref` or inline image data boundaries.
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
/// Lex tokens until a stop marker or unmatched input is reached.
///
/// `StopLexing` and `LexNone` terminate scanning and are not included in the
/// returned token array.
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
/// Lex a single token from a borrowed byte view.
pub fn pdf_lex_single_view(data : BytesView) -> PdfLexeme raise PdfError {
  byte_cursor_of_view(data).lex_pdf_token()
}

///|
/// Lex all tokens from a borrowed byte view.
pub fn pdf_lex_view(data : BytesView) -> Array[PdfLexeme] raise PdfError {
  byte_cursor_of_view(data).lex_pdf_tokens()
}

///|
/// Lex all tokens from owned PDF bytes.
pub fn pdf_lex_bytes(data : PdfBytes) -> Array[PdfLexeme] raise PdfError {
  pdf_lex_view(data)
}
