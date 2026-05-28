///|
/// Parses all top-level PDF objects from lexemes.
///
/// Comments are skipped. Arrays and dictionaries are parsed recursively, and
/// indirect-reference triples are collapsed into `PdfIndirect` objects.
pub fn pdf_parse_lexemes(
  lexemes : ArrayView[PdfLexeme],
) -> Array[PdfObject] raise PdfError {
  let objects : Array[PdfObject] = Array::new(capacity=lexemes.length())
  let mut current = 0
  while current < lexemes.length() {
    current = pdf_skip_comments(lexemes, current)
    if current < lexemes.length() {
      let (object, next) = pdf_parse_value_at(lexemes, current)
      objects.push(object)
      current = next
    }
  }
  objects
}

///|
/// Parses exactly one top-level PDF object from lexemes.
///
/// Raises `PdfError::ParseSingleObjectExpected` if the input contains zero or
/// more than one object.
pub fn pdf_parse_single_lexeme_object(
  lexemes : ArrayView[PdfLexeme],
) -> PdfObject raise PdfError {
  let objects = pdf_parse_lexemes(lexemes)
  if objects.length() == 1 {
    objects[0]
  } else {
    raise ParseSingleObjectExpected
  }
}

///|
/// Lexes and parses exactly one PDF object from a byte view.
pub fn pdf_parse_object_from_view(data : BytesView) -> PdfObject raise PdfError {
  pdf_parse_single_lexeme_object(pdf_lex_view(data))
}

///|
/// Lexes and parses exactly one PDF object from owned PDF bytes.
pub fn pdf_parse_object_from_bytes(data : PdfBytes) -> PdfObject raise PdfError {
  pdf_parse_object_from_view(data)
}
