///|
/// Lex one PDF delimiter token.
///
/// Recognizes `[`, `]`, `<<`, and `>>`. A single `<` or `>` is left unread and
/// returns `LexNone`.
pub fn pdf_cursor_lex_delimiter(cursor : ByteCursor) -> PdfLexeme {
  pdf_cursor_drop_whitespace(cursor)
  let position = cursor.absolute_position()
  match cursor.peek_byte() {
    91 => {
      cursor.nudge()
      LexLeftSquare
    }
    93 => {
      cursor.nudge()
      LexRightSquare
    }
    value if value == 60 && cursor.byte_int_at_absolute(position + 1) == 60 => {
      cursor.nudge()
      cursor.nudge()
      LexLeftDict
    }
    value if value == 62 && cursor.byte_int_at_absolute(position + 1) == 62 => {
      cursor.nudge()
      cursor.nudge()
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
pub fn pdf_cursor_lex_token(cursor : ByteCursor) -> PdfLexeme raise PdfError {
  pdf_cursor_drop_whitespace(cursor)
  let position = cursor.absolute_position()
  let value = cursor.peek_byte()
  match value {
    value if value == pdf_no_more => StopLexing
    37 => pdf_cursor_lex_comment(cursor)
    116 | 102 => pdf_cursor_lex_bool(cursor)
    47 => pdf_cursor_lex_name(cursor)
    value if pdf_is_number_start_byte(value) => pdf_cursor_lex_number(cursor)
    91 | 93 => pdf_cursor_lex_delimiter(cursor)
    40 => pdf_cursor_lex_literal_string(cursor)
    60 =>
      if pdf_cursor_matches_ascii_at(cursor, position, [60, 60]) {
        pdf_cursor_lex_delimiter(cursor)
      } else {
        pdf_cursor_lex_hex_string(cursor)
      }
    62 => pdf_cursor_lex_delimiter(cursor)
    82 => {
      cursor.nudge()
      LexR
    }
    115 =>
      // `startxref` terminates object lexing; any other `s...` marker is left
      // for the stream reader so malformed spellings report stream errors.
      StopLexing
    73 => StopLexing
    value if pdf_is_lowercase_keyword_start_byte(value) =>
      pdf_cursor_lex_keyword(cursor)
    _ => LexNone
  }
}

///|
/// Lex tokens until a stop marker or unmatched input is reached.
///
/// `StopLexing` and `LexNone` terminate scanning and are not included in the
/// returned token array.
pub fn pdf_cursor_lex_tokens(
  cursor : ByteCursor,
) -> Array[PdfLexeme] raise PdfError {
  let tokens : Array[PdfLexeme] = []
  let mut done = false
  while !done {
    match pdf_cursor_lex_token(cursor) {
      StopLexing | LexNone => done = true
      token => tokens.push(token)
    }
  }
  tokens
}

///|
/// Lex a single token from a borrowed byte view.
pub fn pdf_lex_single_view(data : BytesView) -> PdfLexeme raise PdfError {
  pdf_cursor_lex_token(byte_cursor_of_view(data))
}

///|
/// Lex all tokens from a borrowed byte view.
pub fn pdf_lex_view(data : BytesView) -> Array[PdfLexeme] raise PdfError {
  pdf_cursor_lex_tokens(byte_cursor_of_view(data))
}

///|
/// Lex all tokens from owned PDF bytes.
pub fn pdf_lex_bytes(data : PdfBytes) -> Array[PdfLexeme] raise PdfError {
  pdf_lex_view(data)
}
