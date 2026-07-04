///|
/// Parse one coordinate pair using the default A4 page context.
pub fn PdfDocument::parse_coordinate(
  self : PdfDocument,
  text : String,
) -> @geometry.Point2 raise @core.PdfError {
  let values = self.parse_units_string(pdf_coord_default_page(), text)
  match values {
    [x, y] => @geometry.point2(x, y)
    _ => raise BadCoordinateSpecification(text)
  }
}

///|
/// Function wrapper for `PdfDocument::parse_coordinate`.
pub fn pdf_parse_coordinate(
  document : PdfDocument,
  text : String,
) -> @geometry.Point2 raise @core.PdfError {
  document.parse_coordinate(text)
}

///|
fn pdf_coord_point_tuple(point : @geometry.Point2) -> (Double, Double) {
  (point.x, point.y)
}

///|
/// Return cpdfcoord's tuple-shaped `parse_coordinate` result.
pub fn PdfDocument::parse_coordinate_tuple(
  self : PdfDocument,
  text : String,
) -> (Double, Double) raise @core.PdfError {
  pdf_coord_point_tuple(self.parse_coordinate(text))
}

///|
/// Compatibility wrapper matching cpdfcoord's tuple-shaped `parse_coordinate`.
pub fn pdf_parse_coordinate_tuple(
  document : PdfDocument,
  text : String,
) -> (Double, Double) raise @core.PdfError {
  document.parse_coordinate_tuple(text)
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
/// Parse one coordinate pair per page in the document.
pub fn PdfDocument::parse_coordinates(
  self : PdfDocument,
  text : String,
) -> Array[@geometry.Point2] raise @core.PdfError {
  let source = pdf_coord_preprocess_coordinates(text)
  let pages = self.pages_of_pagetree()
  let output : Array[@geometry.Point2] = Array::new(capacity=pages.length())
  for page in pages {
    let values = self.parse_units_string(page, source)
    match values {
      [x, y] => output.push(@geometry.point2(x, y))
      _ => raise BadCoordinateSpecification(source)
    }
  }
  output
}

///|
/// Function wrapper for `PdfDocument::parse_coordinates`.
pub fn pdf_parse_coordinates(
  document : PdfDocument,
  text : String,
) -> Array[@geometry.Point2] raise @core.PdfError {
  document.parse_coordinates(text)
}

///|
/// Return cpdfcoord's tuple-shaped `parse_coordinates` results.
pub fn PdfDocument::parse_coordinates_tuple(
  self : PdfDocument,
  text : String,
) -> Array[(Double, Double)] raise @core.PdfError {
  [
    for point in self.parse_coordinates(text) => pdf_coord_point_tuple(point)
  ]
}

///|
/// Compatibility wrapper matching cpdfcoord's tuple-shaped `parse_coordinates`.
pub fn pdf_parse_coordinates_tuple(
  document : PdfDocument,
  text : String,
) -> Array[(Double, Double)] raise @core.PdfError {
  document.parse_coordinates_tuple(text)
}
