///|
fn pdf_skip_comments(lexemes : ArrayView[PdfLexeme], index : Int) -> Int {
  let mut current = index
  let mut done = false
  while !done && current < lexemes.length() {
    match lexemes[current] {
      LexComment(_) => current += 1
      _ => done = true
    }
  }
  current
}

///|
fn pdf_lexeme_indirect_reference_number(
  lexemes : ArrayView[PdfLexeme],
  index : Int,
) -> Int? {
  if index + 2 < lexemes.length() {
    match (lexemes[index], lexemes[index + 1], lexemes[index + 2]) {
      (LexInt(object_number), LexInt(_), LexR) => Some(object_number)
      _ => None
    }
  } else {
    None
  }
}

///|
fn pdf_parse_array_at(
  lexemes : ArrayView[PdfLexeme],
  index : Int,
) -> (PdfObject, Int) raise PdfError {
  let values : Array[PdfObject] = []
  let mut current = index
  let mut done = false
  while !done && current < lexemes.length() {
    current = pdf_skip_comments(lexemes, current)
    if current >= lexemes.length() {
      done = true
    } else {
      match lexemes[current] {
        LexRightSquare => {
          current += 1
          done = true
        }
        _ => {
          let (value, next) = pdf_parse_value_at(lexemes, current)
          values.push(value)
          current = next
        }
      }
    }
  }
  (PdfArray(values), current)
}

///|
fn pdf_skip_dictionary_tail(lexemes : ArrayView[PdfLexeme], index : Int) -> Int {
  let mut current = index
  let mut depth = 0
  while current < lexemes.length() {
    match lexemes[current] {
      LexLeftDict => depth += 1
      LexRightDict => if depth == 0 { break current + 1 } else { depth -= 1 }
      _ => ()
    }
    current += 1
  } nobreak {
    current
  }
}

///|
fn pdf_parse_dictionary_at(
  lexemes : ArrayView[PdfLexeme],
  index : Int,
) -> (PdfObject, Int) raise PdfError {
  let entries : Array[(PdfName, PdfObject)] = []
  let mut current = index
  let mut malformed = false
  let mut done = false
  while !done && current < lexemes.length() {
    current = pdf_skip_comments(lexemes, current)
    if current >= lexemes.length() {
      done = true
    } else {
      match lexemes[current] {
        LexRightDict => {
          current += 1
          done = true
        }
        _ => {
          let (key, after_key) = pdf_parse_value_at(lexemes, current)
          match key {
            PdfNameObject(name) =>
              if after_key >= lexemes.length() {
                malformed = true
                current = after_key
                done = true
              } else {
                let value_start = pdf_skip_comments(lexemes, after_key)
                if value_start >= lexemes.length() {
                  malformed = true
                  current = value_start
                  done = true
                } else {
                  match lexemes[value_start] {
                    LexRightDict => {
                      malformed = true
                      current = value_start + 1
                      done = true
                    }
                    _ => {
                      let (value, after_value) = pdf_parse_value_at(
                        lexemes, value_start,
                      )
                      entries.push((name, value))
                      current = after_value
                    }
                  }
                }
              }
            _ => {
              malformed = true
              current = pdf_skip_dictionary_tail(lexemes, after_key)
              done = true
            }
          }
        }
      }
    }
  }
  if malformed {
    (PdfDictionary([]), current)
  } else {
    (PdfDictionary(entries), current)
  }
}

///|
fn pdf_parse_value_at(
  lexemes : ArrayView[PdfLexeme],
  index : Int,
) -> (PdfObject, Int) raise PdfError {
  let current = pdf_skip_comments(lexemes, index)
  if current >= lexemes.length() {
    raise ParseObjectExpected
  }
  match pdf_lexeme_indirect_reference_number(lexemes, current) {
    Some(object_number) => (PdfIndirect(object_number), current + 3)
    None =>
      match lexemes[current] {
        LexNull => (PdfNull, current + 1)
        LexBool(value) => (PdfBoolean(value), current + 1)
        LexInt(value) => (PdfInteger(value), current + 1)
        LexReal(value) => (PdfReal(value), current + 1)
        LexString(value) => (PdfString(value), current + 1)
        LexName(value) => (PdfNameObject(value), current + 1)
        LexLeftSquare => pdf_parse_array_at(lexemes, current + 1)
        LexLeftDict => pdf_parse_dictionary_at(lexemes, current + 1)
        _ => raise ParseObjectExpected
      }
  }
}

///|
pub fn pdf_parse_lexemes(
  lexemes : ArrayView[PdfLexeme],
) -> Array[PdfObject] raise PdfError {
  let objects : Array[PdfObject] = []
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
pub fn pdf_parse_object_from_bytes(data : PdfBytes) -> PdfObject raise PdfError {
  pdf_parse_single_lexeme_object(pdf_lex_bytes(data))
}

///|
pub(all) struct PdfParsedIndirectObject {
  number : Int
  generation : Int
  object : PdfObject
} derive(Debug, Eq, ToJson)

///|
fn pdf_parse_indirect_object_at(
  lexemes : ArrayView[PdfLexeme],
  index : Int,
) -> (PdfParsedIndirectObject, Int) raise PdfError {
  let (object, next, complete) = pdf_parse_indirect_object_segment_at(
    lexemes, index,
  )
  if complete {
    (object, next)
  } else {
    raise ParseEndObjectExpected
  }
}

///|
fn pdf_parse_indirect_object_segment_at(
  lexemes : ArrayView[PdfLexeme],
  index : Int,
) -> (PdfParsedIndirectObject, Int, Bool) raise PdfError {
  let first = pdf_skip_comments(lexemes, index)
  if first + 2 >= lexemes.length() {
    raise ParseIndirectObjectExpected
  }
  match (lexemes[first], lexemes[first + 1], lexemes[first + 2]) {
    (LexInt(number), LexInt(generation), LexObj) => {
      let object_start = pdf_skip_comments(lexemes, first + 3)
      let (object, after_object) = pdf_parse_value_at(lexemes, object_start)
      let end_position = pdf_skip_comments(lexemes, after_object)
      if end_position < lexemes.length() && lexemes[end_position] == LexEndObj {
        ({ number, generation, object }, end_position + 1, true)
      } else {
        ({ number, generation, object }, after_object, false)
      }
    }
    _ => raise ParseIndirectObjectExpected
  }
}

///|
fn pdf_parse_indirect_object_prefix_lexemes(
  lexemes : ArrayView[PdfLexeme],
) -> PdfParsedIndirectObject raise PdfError {
  let first = pdf_skip_comments(lexemes, 0)
  if first + 2 >= lexemes.length() {
    raise ParseIndirectObjectExpected
  }
  match (lexemes[first], lexemes[first + 1], lexemes[first + 2]) {
    (LexInt(number), LexInt(generation), LexObj) => {
      let object_start = pdf_skip_comments(lexemes, first + 3)
      let (object, _) = pdf_parse_value_at(lexemes, object_start)
      { number, generation, object }
    }
    _ => raise ParseIndirectObjectExpected
  }
}

///|
pub fn pdf_parse_indirect_object_lexemes(
  lexemes : ArrayView[PdfLexeme],
) -> PdfParsedIndirectObject raise PdfError {
  let (object, _) = pdf_parse_indirect_object_at(lexemes, 0)
  object
}

///|
pub fn pdf_parse_indirect_object_from_bytes(
  data : PdfBytes,
) -> PdfParsedIndirectObject raise PdfError {
  pdf_parse_indirect_object_lexemes(pdf_lex_bytes(data))
}

///|
pub fn pdf_parse_indirect_objects(
  lexemes : ArrayView[PdfLexeme],
) -> Array[PdfParsedIndirectObject] raise PdfError {
  let objects : Array[PdfParsedIndirectObject] = []
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
fn pdf_parse_indirect_object_segments(
  lexemes : ArrayView[PdfLexeme],
) -> (Array[PdfParsedIndirectObject], PdfParsedIndirectObject?) raise PdfError {
  let objects : Array[PdfParsedIndirectObject] = []
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
        prefix = Some(object)
        done = true
      }
    }
  }
  (objects, prefix)
}
