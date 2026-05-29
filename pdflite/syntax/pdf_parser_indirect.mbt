///|
/// A parsed indirect object with object number, generation, and payload.
pub(all) struct PdfParsedIndirectObject {
  number : Int
  generation : Int
  object : PdfObject
} derive(Debug, Eq, ToJson)

///|
fn pdf_parse_indirect_object_at(
  lexemes : ArrayView[PdfLexeme],
  index : Int,
) -> (PdfParsedIndirectObject, Int) raise @core.PdfError {
  let (object, next, complete) = pdf_parse_indirect_object_segment_at(
    lexemes, index,
  )
  ignore(complete)
  (object, next)
}

///|
/// Parse an indirect-object segment and report whether `endobj` was consumed.
pub fn pdf_parse_indirect_object_segment_at(
  lexemes : ArrayView[PdfLexeme],
  index : Int,
) -> (PdfParsedIndirectObject, Int, Bool) raise @core.PdfError {
  let first = pdf_skip_comments(lexemes, index)
  if first + 2 >= lexemes.length() {
    raise ParseIndirectObjectExpected
  }
  match (lexemes[first], lexemes[first + 1], lexemes[first + 2]) {
    (LexInt(number), LexInt(generation), LexObj) => {
      let object_start = pdf_skip_comments(lexemes, first + 3)
      if object_start < lexemes.length() && lexemes[object_start] == LexEndObj {
        ({ number, generation, object: PdfNull }, object_start + 1, true)
      } else {
        let (object, after_object) = pdf_parse_value_at(lexemes, object_start)
        let end_position = pdf_skip_comments(lexemes, after_object)
        if end_position < lexemes.length() && lexemes[end_position] == LexEndObj {
          ({ number, generation, object }, end_position + 1, true)
        } else {
          ({ number, generation, object }, after_object, false)
        }
      }
    }
    _ => raise ParseIndirectObjectExpected
  }
}

///|
/// Parse an indirect-object prefix, tolerating a missing trailing `endobj`.
pub fn pdf_parse_indirect_object_prefix_lexemes(
  lexemes : ArrayView[PdfLexeme],
) -> PdfParsedIndirectObject raise @core.PdfError {
  let first = pdf_skip_comments(lexemes, 0)
  if first + 2 >= lexemes.length() {
    raise ParseIndirectObjectExpected
  }
  match (lexemes[first], lexemes[first + 1], lexemes[first + 2]) {
    (LexInt(number), LexInt(generation), LexObj) => {
      let object_start = pdf_skip_comments(lexemes, first + 3)
      let object = if object_start < lexemes.length() &&
        lexemes[object_start] == LexEndObj {
        PdfNull
      } else {
        let (object, _) = pdf_parse_value_at(lexemes, object_start)
        object
      }
      { number, generation, object }
    }
    _ => raise ParseIndirectObjectExpected
  }
}

///|
/// Parses one indirect object from lexemes.
///
/// Raises `@core.PdfError::ParseIndirectObjectExpected` if the input does not start
/// with an indirect object header.
pub fn pdf_parse_indirect_object_lexemes(
  lexemes : ArrayView[PdfLexeme],
) -> PdfParsedIndirectObject raise @core.PdfError {
  let (object, _) = pdf_parse_indirect_object_at(lexemes, 0)
  object
}

///|
/// Parses one indirect object from owned PDF bytes.
pub fn pdf_parse_indirect_object_from_bytes(
  data : @core.PdfBytes,
) -> PdfParsedIndirectObject raise @core.PdfError {
  pdf_parse_indirect_object_from_view(data)
}

///|
/// Parses one indirect object from a byte view.
pub fn pdf_parse_indirect_object_from_view(
  data : BytesView,
) -> PdfParsedIndirectObject raise @core.PdfError {
  pdf_parse_indirect_object_lexemes(pdf_lex_view(data))
}

///|
/// Parses every complete indirect object from a lexeme sequence.
///
/// Raises `@core.PdfError::ParseIndirectObjectExpected` when an expected indirect
/// object header is malformed.
pub fn pdf_parse_indirect_objects(
  lexemes : ArrayView[PdfLexeme],
) -> Array[PdfParsedIndirectObject] raise @core.PdfError {
  let objects : Array[PdfParsedIndirectObject] = Array::new(
    capacity=(lexemes.length() + 3) / 4,
  )
  let mut current = 0
  while current < lexemes.length() {
    current = pdf_skip_comments(lexemes, current)
    if current < lexemes.length() {
      let (object, next) = pdf_parse_indirect_object_at(lexemes, current)
      objects.push(object)
      current = next
    }
  }
  objects
}

///|
/// Parse complete indirect-object segments and return a trailing prefix if present.
pub fn pdf_parse_indirect_object_segments(
  lexemes : ArrayView[PdfLexeme],
) -> (Array[PdfParsedIndirectObject], PdfParsedIndirectObject?) raise @core.PdfError {
  let objects : Array[PdfParsedIndirectObject] = Array::new(
    capacity=(lexemes.length() + 3) / 4,
  )
  let mut prefix : PdfParsedIndirectObject? = None
  let mut current = 0
  let mut done = false
  while !done && current < lexemes.length() {
    current = pdf_skip_comments(lexemes, current)
    if current < lexemes.length() {
      let (object, next, complete) = pdf_parse_indirect_object_segment_at(
        lexemes, current,
      )
      if complete {
        objects.push(object)
        current = next
      } else {
        let next_object = pdf_skip_comments(lexemes, next)
        if pdf_lexeme_indirect_object_header_at(lexemes, next_object) {
          objects.push(object)
          current = next_object
        } else {
          prefix = Some(object)
          done = true
        }
      }
    }
  }
  (objects, prefix)
}
