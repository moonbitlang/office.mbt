///|
fn pdf_coord_update_last(
  numbers : Array[Double],
  operation : String,
  value : Double,
) -> Bool {
  if numbers.length() == 0 {
    false
  } else {
    let index = numbers.length() - 1
    match operation {
      "add" => numbers[index] = numbers[index] + value
      "sub" => numbers[index] = numbers[index] - value
      "mul" => numbers[index] = numbers[index] * value
      "div" => numbers[index] = numbers[index] / value
      _ => return false
    }
    true
  }
}

///|
fn pdf_coord_parse_units_tokens(
  document : PdfDocument,
  page : PdfPage,
  source : String,
  tokens : ArrayView[PdfCoordToken],
) -> Array[Double] raise PdfError {
  let numbers : Array[Double] = Array::new(capacity=tokens.length())
  let mut index = 0
  let mut done = false
  while index < tokens.length() && !done {
    match tokens[index] {
      CoordWord(word) =>
        match pdf_coord_paper_size(word) {
          Some(paper) => {
            let (width, height) = pdf_coord_paper_points(paper)
            numbers.push(width)
            numbers.push(height)
            index += 1
          }
          None =>
            if word == "pt" {
              index += 1
            } else if word == "add" ||
              word == "sub" ||
              word == "mul" ||
              word == "div" {
              if index + 1 >= tokens.length() {
                raise BadNumberArgument(source)
              }
              let unit = if index + 2 < tokens.length() {
                match tokens[index + 2] {
                  CoordWord(unit) if pdf_coord_is_unit(unit) => unit
                  _ => "pt"
                }
              } else {
                "pt"
              }
              match
                pdf_coord_token_number(document, page, tokens[index + 1], unit) {
                Some(value) => {
                  if !pdf_coord_update_last(numbers, word, value) {
                    raise BadNumberArgument(source)
                  }
                  index += if unit == "pt" { 2 } else { 3 }
                }
                None => raise BadNumberArgument(source)
              }
            } else {
              match pdf_coord_page_characteristic(document, page, word) {
                Some(value) => {
                  numbers.push(value)
                  index += 1
                }
                None => done = true
              }
            }
        }
      CoordNumber(value) =>
        if index + 1 < tokens.length() {
          match tokens[index + 1] {
            CoordWord(unit) =>
              match pdf_coord_apply_unit(value, unit) {
                Some(converted) => {
                  numbers.push(converted)
                  index += 2
                }
                None => {
                  numbers.push(value)
                  index += 1
                }
              }
            _ => {
              numbers.push(value)
              index += 1
            }
          }
        } else {
          numbers.push(value)
          index += 1
        }
    }
  }
  numbers
}

///|
/// Parse a coordinate expression with page-relative units and variables for the
/// supplied page.
pub fn PdfDocument::parse_units_string(
  self : PdfDocument,
  page : PdfPage,
  text : String,
) -> Array[Double] raise PdfError {
  pdf_coord_parse_units_tokens(self, page, text, pdf_coord_tokenize(text))
}

///|
/// Function wrapper for `PdfDocument::parse_units_string`.
pub fn pdf_parse_units_string(
  document : PdfDocument,
  page : PdfPage,
  text : String,
) -> Array[Double] raise PdfError {
  document.parse_units_string(page, text)
}
