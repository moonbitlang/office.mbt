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
/// Return whether lexemes at `index` start an indirect-object header.
pub fn pdf_lexeme_indirect_object_header_at(
  lexemes : ArrayView[PdfLexeme],
  index : Int,
) -> Bool {
  if index + 2 < lexemes.length() {
    match (lexemes[index], lexemes[index + 1], lexemes[index + 2]) {
      (LexInt(_), LexInt(_), LexObj) => true
      _ => false
    }
  } else {
    false
  }
}

///|
fn pdf_parse_array_capacity(lexemes : ArrayView[PdfLexeme], index : Int) -> Int {
  let mut current = index
  let mut array_depth = 0
  let mut dictionary_depth = 0
  while current < lexemes.length() {
    match lexemes[current] {
      LexLeftSquare => array_depth += 1
      LexRightSquare =>
        if array_depth == 0 && dictionary_depth == 0 {
          break current - index
        } else if array_depth > 0 {
          array_depth -= 1
        }
      LexLeftDict => dictionary_depth += 1
      LexRightDict => if dictionary_depth > 0 { dictionary_depth -= 1 }
      _ => ()
    }
    current += 1
  } nobreak {
    current - index
  }
}

///|
fn pdf_parse_dictionary_capacity(
  lexemes : ArrayView[PdfLexeme],
  index : Int,
) -> Int {
  let mut current = index
  let mut array_depth = 0
  let mut dictionary_depth = 0
  while current < lexemes.length() {
    match lexemes[current] {
      LexLeftSquare => array_depth += 1
      LexRightSquare => if array_depth > 0 { array_depth -= 1 }
      LexLeftDict => dictionary_depth += 1
      LexRightDict =>
        if array_depth == 0 && dictionary_depth == 0 {
          break (current - index + 1) / 2
        } else if dictionary_depth > 0 {
          dictionary_depth -= 1
        }
      _ => ()
    }
    current += 1
  } nobreak {
    (current - index + 1) / 2
  }
}

///|
fn pdf_parse_array_at(
  lexemes : ArrayView[PdfLexeme],
  index : Int,
) -> (PdfObject, Int) raise @core.PdfError {
  let values : Array[PdfObject] = Array::new(
    capacity=pdf_parse_array_capacity(lexemes, index),
  )
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
) -> (PdfObject, Int) raise @core.PdfError {
  let entries : Array[(@core.PdfName, PdfObject)] = Array::new(
    capacity=pdf_parse_dictionary_capacity(lexemes, index),
  )
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
) -> (PdfObject, Int) raise @core.PdfError {
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
