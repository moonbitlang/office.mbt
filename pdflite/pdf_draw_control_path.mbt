///|
/// Append a rectangle path operation parsed from document coordinates.
pub fn PdfDrawControl::add_rect(
  self : PdfDrawControl,
  document : PdfDocument,
  text : String,
) -> Unit raise PdfError {
  let rect = document.parse_coordinate_rectangle(text)
  self.add_op(PdfDrawRect(rect.x, rect.y, rect.width, rect.height))
}

///|
/// Append a path move operation parsed from document coordinates.
pub fn PdfDrawControl::add_to(
  self : PdfDrawControl,
  document : PdfDocument,
  text : String,
) -> Unit raise PdfError {
  let point = document.parse_coordinate(text)
  self.add_op(PdfDrawTo(point.x, point.y))
}

///|
/// Append a straight line segment parsed from document coordinates.
pub fn PdfDrawControl::add_line(
  self : PdfDrawControl,
  document : PdfDocument,
  text : String,
) -> Unit raise PdfError {
  let point = document.parse_coordinate(text)
  self.add_op(PdfDrawLine(point.x, point.y))
}

///|
/// Append a cubic Bezier segment parsed from six numbers.
pub fn PdfDrawControl::add_bezier(
  self : PdfDrawControl,
  text : String,
) -> Unit raise PdfError {
  let values = pdf_draw_control_expect_floats(
    text, 6, "-bez requires six numbers", "malformed -bez",
  )
  self.add_op(
    PdfDrawBezier(
      values[0],
      values[1],
      values[2],
      values[3],
      values[4],
      values[5],
    ),
  )
}

///|
/// Append a Bezier segment with the first control point inferred.
pub fn PdfDrawControl::add_bezier23(
  self : PdfDrawControl,
  text : String,
) -> Unit raise PdfError {
  let values = pdf_draw_control_expect_floats(
    text, 4, "-bez23 requires four numbers", "malformed -bez23",
  )
  self.add_op(PdfDrawBezier23(values[0], values[1], values[2], values[3]))
}

///|
/// Append a Bezier segment with the second control point inferred.
pub fn PdfDrawControl::add_bezier13(
  self : PdfDrawControl,
  text : String,
) -> Unit raise PdfError {
  let values = pdf_draw_control_expect_floats(
    text, 4, "-bez13 requires four numbers", "malformed -bez13",
  )
  self.add_op(PdfDrawBezier13(values[0], values[1], values[2], values[3]))
}

///|
/// Append a circular path approximation parsed from center and radius.
pub fn PdfDrawControl::add_circle(
  self : PdfDrawControl,
  text : String,
) -> Unit raise PdfError {
  let values = pdf_draw_control_expect_floats(
    text, 3, "-circle requires three numbers", "malformed -circle",
  )
  let path = @shape.pdf_shape_circle(values[0], values[1], values[2])
  match path.subpaths {
    [{ segments: [PdfPathBezier(start, _, _, _), ..] as segments, .. }, ..] => {
      self.add_op(PdfDrawTo(start.x, start.y))
      for segment in segments {
        match segment {
          PdfPathBezier(_, control1, control2, end) =>
            self.add_op(
              PdfDrawBezier(
                control1.x,
                control1.y,
                control2.x,
                control2.y,
                end.x,
                end.y,
              ),
            )
          PdfPathStraight(_, _) => raise SoftError("malformed -circle")
        }
      }
    }
    _ => raise SoftError("malformed -circle")
  }
}

///|
/// Append a stroke operation for the current path.
pub fn PdfDrawControl::stroke(self : PdfDrawControl) -> Unit raise PdfError {
  self.add_op(PdfDrawStroke)
}

///|
/// Append a fill operation for the current path.
pub fn PdfDrawControl::fill(self : PdfDrawControl) -> Unit raise PdfError {
  self.add_op(PdfDrawFill)
}

///|
/// Append an even-odd fill operation for the current path.
pub fn PdfDrawControl::fill_even_odd(
  self : PdfDrawControl,
) -> Unit raise PdfError {
  self.add_op(PdfDrawFillEvenOdd)
}

///|
/// Append a fill-and-stroke operation for the current path.
pub fn PdfDrawControl::stroke_fill(
  self : PdfDrawControl,
) -> Unit raise PdfError {
  self.add_op(PdfDrawFillStroke)
}

///|
/// Append an even-odd fill-and-stroke operation for the current path.
pub fn PdfDrawControl::stroke_fill_even_odd(
  self : PdfDrawControl,
) -> Unit raise PdfError {
  self.add_op(PdfDrawFillStrokeEvenOdd)
}

///|
/// Append a clip operation using the current path.
pub fn PdfDrawControl::clip(self : PdfDrawControl) -> Unit raise PdfError {
  self.add_op(PdfDrawClip)
}

///|
/// Append an even-odd clip operation using the current path.
pub fn PdfDrawControl::clip_even_odd(
  self : PdfDrawControl,
) -> Unit raise PdfError {
  self.add_op(PdfDrawClipEvenOdd)
}

///|
/// Append a close-path operation.
pub fn PdfDrawControl::close_path(self : PdfDrawControl) -> Unit raise PdfError {
  self.add_op(PdfDrawClosePath)
}
