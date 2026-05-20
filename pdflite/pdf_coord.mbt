///|
priv enum PdfCoordToken {
  CoordNumber(Double)
  CoordWord(String)
}

///|
/// A cpdf coordinate rectangle: origin plus width and height.
pub(all) struct PdfCoordRectangle {
  x : Double
  y : Double
  width : Double
  height : Double
} derive(Debug, Eq, ToJson)

///|
fn pdf_coord_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn pdf_coord_is_digit(value : Int) -> Bool {
  value >= 48 && value <= 57
}

///|
fn pdf_coord_is_number_start(value : Int) -> Bool {
  pdf_coord_is_digit(value) || value == 43 || value == 45 || value == 46
}

///|
fn pdf_coord_is_word_boundary(value : Int) -> Bool {
  pdf_is_whitespace_byte(value)
}

///|
fn pdf_coord_is_unit_pair(first : Int, second : Int) -> Bool {
  (first == 109 && second == 109) ||
  (first == 99 && second == 109) ||
  (first == 105 && second == 110) ||
  (first == 112 && second == 116)
}

///|
fn pdf_coord_space_units(text : String) -> String {
  let bytes = @utf8.encode(text)
  let output : Array[Byte] = []
  let mut index = 0
  while index < bytes.length() {
    if index + 1 < bytes.length() &&
      pdf_coord_is_unit_pair(bytes[index].to_int(), bytes[index + 1].to_int()) {
      output.push(32)
      output.push(bytes[index])
      output.push(bytes[index + 1])
      output.push(32)
      index += 2
    } else {
      output.push(bytes[index])
      index += 1
    }
  }
  @utf8.decode_lossy(Bytes::from_array(output))
}

///|
fn pdf_coord_number_end(bytes : BytesView, start : Int) -> Int {
  let mut index = start
  if index < bytes.length() &&
    (bytes[index].to_int() == 43 || bytes[index].to_int() == 45) {
    index += 1
  }
  while index < bytes.length() && pdf_coord_is_digit(bytes[index].to_int()) {
    index += 1
  }
  if index < bytes.length() && bytes[index].to_int() == 46 {
    index += 1
    while index < bytes.length() && pdf_coord_is_digit(bytes[index].to_int()) {
      index += 1
    }
  }
  if index < bytes.length() &&
    (bytes[index].to_int() == 69 || bytes[index].to_int() == 101) {
    let exponent_start = index
    index += 1
    if index < bytes.length() &&
      (bytes[index].to_int() == 43 || bytes[index].to_int() == 45) {
      index += 1
    }
    let digits_start = index
    while index < bytes.length() && pdf_coord_is_digit(bytes[index].to_int()) {
      index += 1
    }
    if index == digits_start {
      exponent_start
    } else {
      index
    }
  } else {
    index
  }
}

///|
fn pdf_coord_tokenize(text : String) -> Array[PdfCoordToken] {
  let bytes = @utf8.encode(pdf_coord_space_units(text))
  let tokens : Array[PdfCoordToken] = []
  let mut index = 0
  while index < bytes.length() {
    let value = bytes[index].to_int()
    if pdf_is_whitespace_byte(value) {
      index += 1
    } else if pdf_coord_is_number_start(value) {
      let end = pdf_coord_number_end(bytes, index)
      if end > index {
        let number_text = @ascii.decode_lossy(bytes[index:end])
        let parsed : Result[Double, Error] = try? @strconv.from_str(number_text)
        match parsed {
          Ok(number) => {
            tokens.push(CoordNumber(number))
            index = end
          }
          Err(_) => {
            tokens.push(CoordWord(number_text))
            index = end
          }
        }
      } else {
        tokens.push(CoordWord(@ascii.decode_lossy(bytes[index:index + 1])))
        index += 1
      }
    } else {
      let start = index
      while index < bytes.length() &&
            !pdf_coord_is_word_boundary(bytes[index].to_int()) {
        index += 1
      }
      tokens.push(CoordWord(@ascii.decode_lossy(bytes[start:index])))
    }
  }
  tokens
}

///|
fn pdf_coord_mm(value : Double) -> Double {
  value / 10.0 / 2.54 * 72.0
}

///|
fn pdf_coord_cm(value : Double) -> Double {
  value / 2.54 * 72.0
}

///|
fn pdf_coord_in(value : Double) -> Double {
  value * 72.0
}

///|
fn pdf_coord_apply_unit(value : Double, unit : String) -> Double? {
  match unit {
    "pt" => Some(value)
    "mm" => Some(pdf_coord_mm(value))
    "cm" => Some(pdf_coord_cm(value))
    "in" => Some(pdf_coord_in(value))
    _ => None
  }
}

///|
fn pdf_coord_is_unit(text : String) -> Bool {
  text == "pt" || text == "mm" || text == "cm" || text == "in"
}

///|
fn pdf_coord_paper_points(paper : PaperSize) -> (Double, Double) {
  (
    unit_points(paper.width(), paper.unit()),
    unit_points(paper.height(), paper.unit()),
  )
}

///|
fn pdf_coord_paper_size(text : String) -> PaperSize? {
  match text {
    "a0portrait" => Some(paper_a0)
    "a1portrait" => Some(paper_a1)
    "a2portrait" => Some(paper_a2)
    "a3portrait" => Some(paper_a3)
    "a4portrait" => Some(paper_a4)
    "a5portrait" => Some(paper_a5)
    "a6portrait" => Some(paper_a6)
    "a7portrait" => Some(paper_a7)
    "a8portrait" => Some(paper_a8)
    "a9portrait" => Some(paper_a9)
    "a10portrait" => Some(paper_a10)
    "a0landscape" => Some(paper_a0.landscape())
    "a1landscape" => Some(paper_a1.landscape())
    "a2landscape" => Some(paper_a2.landscape())
    "a3landscape" => Some(paper_a3.landscape())
    "a4landscape" => Some(paper_a4.landscape())
    "a5landscape" => Some(paper_a5.landscape())
    "a6landscape" => Some(paper_a6.landscape())
    "a7landscape" => Some(paper_a7.landscape())
    "a8landscape" => Some(paper_a8.landscape())
    "a9landscape" => Some(paper_a9.landscape())
    "a10landscape" => Some(paper_a10.landscape())
    "usletterportrait" => Some(paper_usletter)
    "uslegalportrait" => Some(paper_uslegal)
    "usletterlandscape" => Some(paper_usletter.landscape())
    "uslegallandscape" => Some(paper_uslegal.landscape())
    _ => None
  }
}

///|
fn pdf_coord_box_key(kind : String) -> PdfName? {
  match kind {
    "C" => Some(pdf_coord_name("/CropBox"))
    "A" => Some(pdf_coord_name("/ArtBox"))
    "T" => Some(pdf_coord_name("/TrimBox"))
    "B" => Some(pdf_coord_name("/BleedBox"))
    _ => None
  }
}

///|
fn pdf_coord_box_object(
  document : PdfDocument,
  page : PdfPage,
  kind : String,
) -> PdfObject {
  match pdf_coord_box_key(kind) {
    Some(key) =>
      match document.lookup_direct(key, page.rest) {
        Some(object) => object
        None => page.mediabox
      }
    None => page.mediabox
  }
}

///|
fn pdf_coord_box_rectangle(
  document : PdfDocument,
  page : PdfPage,
  kind : String,
) -> PdfRectangle raise PdfError {
  document.parse_rectangle(pdf_coord_box_object(document, page, kind))
}

///|
fn pdf_coord_page_characteristic(
  document : PdfDocument,
  page : PdfPage,
  name : String,
) -> Double? raise PdfError {
  if name.length() < 2 {
    None
  } else {
    let box_kind = name.unsafe_substring(start=0, end=1)
    let property = name.unsafe_substring(start=1, end=name.length())
    let rectangle = pdf_coord_box_rectangle(document, page, box_kind)
    match property {
      "W" => Some(rectangle.max_x - rectangle.min_x)
      "H" => Some(rectangle.max_y - rectangle.min_y)
      "MINX" => Some(rectangle.min_x)
      "MINY" => Some(rectangle.min_y)
      "MAXX" => Some(rectangle.max_x)
      "MAXY" => Some(rectangle.max_y)
      _ => None
    }
  }
}

///|
fn pdf_coord_token_number(
  document : PdfDocument,
  page : PdfPage,
  token : PdfCoordToken,
  unit : String,
) -> Double? raise PdfError {
  match token {
    CoordNumber(value) => pdf_coord_apply_unit(value, unit)
    CoordWord(name) =>
      match pdf_coord_page_characteristic(document, page, name) {
        Some(value) => pdf_coord_apply_unit(value, unit)
        None => None
      }
  }
}

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
  let numbers : Array[Double] = []
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
pub fn PdfDocument::parse_units_string(
  self : PdfDocument,
  page : PdfPage,
  text : String,
) -> Array[Double] raise PdfError {
  pdf_coord_parse_units_tokens(self, page, text, pdf_coord_tokenize(text))
}

///|
pub fn pdf_parse_units_string(
  document : PdfDocument,
  page : PdfPage,
  text : String,
) -> Array[Double] raise PdfError {
  document.parse_units_string(page, text)
}

///|
fn pdf_coord_default_page() -> PdfPage {
  pdf_page_blank(paper_a4)
}

///|
fn pdf_coord_rectangle(
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> PdfCoordRectangle {
  { x, y, width, height }
}

///|
pub fn PdfDocument::parse_coordinate_rectangle(
  self : PdfDocument,
  text : String,
) -> PdfCoordRectangle raise PdfError {
  let (source, absolute) = if text.has_prefix("?") {
    (text.unsafe_substring(start=1, end=text.length()), true)
  } else {
    (text, false)
  }
  let values = self.parse_units_string(pdf_coord_default_page(), source)
  match values {
    [x, y, width, height] =>
      if absolute {
        pdf_coord_rectangle(x, y, width - x, height - y)
      } else {
        pdf_coord_rectangle(x, y, width, height)
      }
    _ => raise BadRectangleSpecification(source)
  }
}

///|
pub fn pdf_parse_coordinate_rectangle(
  document : PdfDocument,
  text : String,
) -> PdfCoordRectangle raise PdfError {
  document.parse_coordinate_rectangle(text)
}

///|
pub fn PdfDocument::parse_coordinate_rectangles(
  self : PdfDocument,
  text : String,
) -> Array[PdfCoordRectangle] raise PdfError {
  let (source, absolute) = if text.has_prefix("?") {
    (text.unsafe_substring(start=1, end=text.length()), true)
  } else {
    (text, false)
  }
  let output : Array[PdfCoordRectangle] = []
  for page in self.pages_of_pagetree() {
    let values = self.parse_units_string(page, source)
    match values {
      [x, y, width, height] =>
        if absolute {
          output.push(pdf_coord_rectangle(x, y, width - x, height - y))
        } else {
          output.push(pdf_coord_rectangle(x, y, width, height))
        }
      _ => raise BadRectangleSpecification(source)
    }
  }
  output
}

///|
pub fn pdf_parse_coordinate_rectangles(
  document : PdfDocument,
  text : String,
) -> Array[PdfCoordRectangle] raise PdfError {
  document.parse_coordinate_rectangles(text)
}

///|
pub fn PdfDocument::parse_coordinate(
  self : PdfDocument,
  text : String,
) -> Point2 raise PdfError {
  let values = self.parse_units_string(pdf_coord_default_page(), text)
  match values {
    [x, y] => point2(x, y)
    _ => raise BadCoordinateSpecification(text)
  }
}

///|
pub fn pdf_parse_coordinate(
  document : PdfDocument,
  text : String,
) -> Point2 raise PdfError {
  document.parse_coordinate(text)
}

///|
fn pdf_coord_preprocess_coordinates(text : String) -> String {
  if text.has_prefix("* ") {
    let rest = text.unsafe_substring(start=2, end=text.length())
    rest + " div CH mul CW " + rest
  } else if text.has_suffix(" *") {
    let rest = text.unsafe_substring(start=0, end=text.length() - 2)
    rest + " " + rest + " div CW mul CH"
  } else {
    text
  }
}

///|
pub fn PdfDocument::parse_coordinates(
  self : PdfDocument,
  text : String,
) -> Array[Point2] raise PdfError {
  let source = pdf_coord_preprocess_coordinates(text)
  let output : Array[Point2] = []
  for page in self.pages_of_pagetree() {
    let values = self.parse_units_string(page, source)
    match values {
      [x, y] => output.push(point2(x, y))
      _ => raise BadCoordinateSpecification(source)
    }
  }
  output
}

///|
pub fn pdf_parse_coordinates(
  document : PdfDocument,
  text : String,
) -> Array[Point2] raise PdfError {
  document.parse_coordinates(text)
}

///|
pub fn PdfDocument::parse_single_number(
  self : PdfDocument,
  text : String,
) -> Double raise PdfError {
  let values = self.parse_units_string(pdf_coord_default_page(), text)
  match values {
    [value] => value
    _ => raise BadNumberArgument(text)
  }
}

///|
pub fn pdf_parse_single_number(
  document : PdfDocument,
  text : String,
) -> Double raise PdfError {
  document.parse_single_number(text)
}
