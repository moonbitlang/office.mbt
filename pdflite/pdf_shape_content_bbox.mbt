///|
fn pdf_path_content_quad(bounds : PdfRectangle) -> PdfContentBoundingBox {
  {
    x0: bounds.min_x,
    y0: bounds.min_y,
    x1: bounds.min_x,
    y1: bounds.max_y,
    x2: bounds.max_x,
    y2: bounds.max_y,
    x3: bounds.max_x,
    y3: bounds.min_y,
  }
}

///|
fn pdf_path_stroke_expand_bounds(
  bounds : PdfRectangle,
  ctm : TransformMatrix,
  line_width : Double,
) -> PdfRectangle {
  let origin = ctm.apply(point2(0.0, 0.0))
  let stroke = ctm.apply(point2(line_width, line_width))
  let dx = (stroke.x - origin.x).abs()
  let dy = (stroke.y - origin.y).abs()
  {
    min_x: bounds.min_x - dx / 2.0,
    min_y: bounds.min_y - dy / 2.0,
    max_x: bounds.max_x + dx / 2.0,
    max_y: bounds.max_y + dy / 2.0,
  }
}

///|
/// Return cpdfcontent's emitted path bounding-box quad.
///
/// The path is first transformed by the current transformation matrix. When
/// `stroking` is true, the transformed line-width vector expands the box by
/// half its absolute x/y displacement, matching `emit_path_bounding_box`.
pub fn PdfPath::content_bounding_box(
  self : PdfPath,
  ctm : TransformMatrix,
  line_width : Double,
  stroking : Bool,
) -> PdfContentBoundingBox? {
  match self.transform(ctm).pdf_path_bounds_optional() {
    Some(bounds) => {
      let bounds = if stroking {
        pdf_path_stroke_expand_bounds(bounds, ctm, line_width)
      } else {
        bounds
      }
      Some(pdf_path_content_quad(bounds))
    }
    None => None
  }
}

///|
/// Compatibility wrapper for `PdfPath::content_bounding_box`.
pub fn pdf_path_content_bounding_box(
  path : PdfPath,
  ctm : TransformMatrix,
  line_width : Double,
  stroking : Bool,
) -> PdfContentBoundingBox? {
  path.content_bounding_box(ctm, line_width, stroking)
}
