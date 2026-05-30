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
  page : @page.PdfPage,
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
  page : @page.PdfPage,
  kind : String,
) -> PdfRectangle raise PdfError {
  document.parse_rectangle(pdf_coord_box_object(document, page, kind))
}

///|
fn pdf_coord_page_characteristic(
  document : PdfDocument,
  page : @page.PdfPage,
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
  page : @page.PdfPage,
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
