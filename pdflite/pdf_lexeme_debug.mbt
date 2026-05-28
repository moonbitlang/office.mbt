///|
/// Return the constructor name of a lexeme for diagnostics and snapshots.
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
fn pdf_lexeme_debug_bytes_text(bytes : BytesView) -> String {
  @ascii.decode_lossy(bytes)
}

///|
/// Return CamlPDF-style debug text for a single lexeme.
///
/// Only numbers, strings, names, and null get value-specific rendering; other
/// token kinds are rendered as `GenLexNone`.
pub fn pdf_string_of_lexeme(lexeme : PdfLexeme) -> String {
  match lexeme {
    LexInt(value) => "Int " + value.to_string()
    LexReal(value) => "Float " + value.to_string()
    LexString(value) => "String " + pdf_lexeme_debug_bytes_text(value)
    LexName(value) => "Ident " + pdf_lexeme_debug_bytes_text(value.bytes())
    LexNull => "Nothing"
    _ => "GenLexNone"
  }
}

///|
/// Return CamlPDF-style debug text for a sequence of lexemes.
///
/// Each lexeme is placed on its own line with a leading space.
pub fn pdf_string_of_lexemes(lexemes : ArrayView[PdfLexeme]) -> String {
  let mut text = ""
  for lexeme in lexemes {
    text = text + "\n " + pdf_string_of_lexeme(lexeme)
  }
  text
}
