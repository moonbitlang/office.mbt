///|
fn pdf_coord_default_page() -> @page.PdfPage {
  @page.pdf_page_blank(@geometry.paper_a4)
}

///|
fn pdf_coord_rectangle(
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> @geometry.PdfCoordRectangle {
  { x, y, width, height }
}

///|
/// Parse one coordinate rectangle. A leading `?` treats the third and fourth
/// numbers as absolute upper-right coordinates.
pub fn PdfDocument::parse_coordinate_rectangle(
  self : PdfDocument,
  text : String,
) -> @geometry.PdfCoordRectangle raise @core.PdfError {
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
/// Function wrapper for `PdfDocument::parse_coordinate_rectangle`.
pub fn pdf_parse_coordinate_rectangle(
  document : PdfDocument,
  text : String,
) -> @geometry.PdfCoordRectangle raise @core.PdfError {
  document.parse_coordinate_rectangle(text)
}

///|
fn pdf_coord_rectangle_tuple(
  rectangle : @geometry.PdfCoordRectangle,
) -> (Double, Double, Double, Double) {
  (rectangle.x, rectangle.y, rectangle.width, rectangle.height)
}

///|
/// Compatibility wrapper matching cpdfcoord's `parse_rectangle`.
pub fn pdf_parse_rectangle(
  document : PdfDocument,
  text : String,
) -> (Double, Double, Double, Double) raise @core.PdfError {
  pdf_coord_rectangle_tuple(document.parse_coordinate_rectangle(text))
}

///|
/// Parse one coordinate rectangle per page in the document.
pub fn PdfDocument::parse_coordinate_rectangles(
  self : PdfDocument,
  text : String,
) -> Array[@geometry.PdfCoordRectangle] raise @core.PdfError {
  let (source, absolute) = if text.has_prefix("?") {
    (text.unsafe_substring(start=1, end=text.length()), true)
  } else {
    (text, false)
  }
  let pages = self.pages_of_pagetree()
  let output : Array[@geometry.PdfCoordRectangle] = Array::new(
    capacity=pages.length(),
  )
  for page in pages {
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
/// Function wrapper for `PdfDocument::parse_coordinate_rectangles`.
pub fn pdf_parse_coordinate_rectangles(
  document : PdfDocument,
  text : String,
) -> Array[@geometry.PdfCoordRectangle] raise @core.PdfError {
  document.parse_coordinate_rectangles(text)
}

///|
/// Compatibility wrapper matching cpdfcoord's `parse_rectangles`.
pub fn pdf_parse_rectangles(
  document : PdfDocument,
  text : String,
) -> Array[(Double, Double, Double, Double)] raise @core.PdfError {
  [
    for rectangle in document.parse_coordinate_rectangles(text) => {
      pdf_coord_rectangle_tuple(rectangle)
    }
  ]
}
