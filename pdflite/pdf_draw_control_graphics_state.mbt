///|
/// Append a stroke colour operation parsed from a cpdf draw-control argument.
pub fn PdfDrawControl::set_stroke(
  self : PdfDrawControl,
  text : String,
) -> Unit raise PdfError {
  self.add_op(PdfDrawSetStroke(@colour.pdf_draw_colour_of_string(text)))
}

///|
/// Append a fill colour operation parsed from a cpdf draw-control argument.
pub fn PdfDrawControl::set_fill(
  self : PdfDrawControl,
  text : String,
) -> Unit raise PdfError {
  self.add_op(PdfDrawSetFill(@colour.pdf_draw_colour_of_string(text)))
}

///|
/// Append a line-thickness operation parsed from a cpdf draw-control argument.
pub fn PdfDrawControl::set_line_thickness(
  self : PdfDrawControl,
  text : String,
) -> Unit raise PdfError {
  let values = pdf_draw_control_expect_floats(
    text, 1, "Thickness must be a number", "Thickness must be a number",
  )
  self.add_op(PdfDrawSetLineThickness(values[0]))
}

///|
/// Append a line-cap operation parsed from a cpdf draw-control argument.
pub fn PdfDrawControl::set_line_cap(
  self : PdfDrawControl,
  text : String,
) -> Unit raise PdfError {
  let value = match text {
    "butt" => 0
    "round" => 1
    "square" => 2
    _ => raise SoftError("Unknown cap type")
  }
  self.add_op(PdfDrawSetLineCap(value))
}

///|
/// Append a line-join operation parsed from a cpdf draw-control argument.
pub fn PdfDrawControl::set_line_join(
  self : PdfDrawControl,
  text : String,
) -> Unit raise PdfError {
  let value = match text {
    "miter" => 0
    "round" => 1
    "bevel" => 2
    _ => raise SoftError("Unknown join type")
  }
  self.add_op(PdfDrawSetLineJoin(value))
}

///|
/// Append a miter-limit operation parsed from a cpdf draw-control argument.
pub fn PdfDrawControl::set_miter_limit(
  self : PdfDrawControl,
  text : String,
) -> Unit raise PdfError {
  let values = pdf_draw_control_expect_floats(
    text, 1, "Miter limit must be a number", "Miter limit must be a number",
  )
  self.add_op(PdfDrawSetMiterLimit(values[0]))
}

///|
/// Append a dash-pattern operation parsed from a cpdf draw-control argument.
pub fn PdfDrawControl::set_dash_pattern(
  self : PdfDrawControl,
  text : String,
) -> Unit raise PdfError {
  let values = pdf_draw_control_read_floats(
    text, "Dash pattern elements must one or more numbers",
  )
  if values.length() == 0 {
    raise SoftError("Dash pattern elements must one or more numbers")
  }
  let dashes : Array[Double] = [
    for value in values[0:values.length() - 1] => value
  ]
  self.add_op(PdfDrawSetDashPattern(dashes, values[values.length() - 1]))
}

///|
/// Append an explicit transformation matrix parsed from six numbers.
pub fn PdfDrawControl::set_matrix(
  self : PdfDrawControl,
  text : String,
) -> Unit raise PdfError {
  let values = pdf_draw_control_expect_floats(
    text, 6, "Matrix must have six numbers", "Matrix elements must be numbers",
  )
  self.add_op(
    PdfDrawMatrix({
      a: values[0],
      b: values[1],
      c: values[2],
      d: values[3],
      e: values[4],
      f: values[5],
    }),
  )
}

///|
/// Append a translation matrix operation parsed from a cpdf argument.
pub fn PdfDrawControl::matrix_translate(
  self : PdfDrawControl,
  text : String,
) -> Unit raise PdfError {
  let values = pdf_draw_control_expect_floats(
    text, 2, "-mtrans takes two numbers", "-mtrans takes two numbers",
  )
  self.add_op(PdfDrawMatrix(transform_translate(values[0], values[1])))
}

///|
/// Append a rotation matrix operation parsed from a cpdf argument.
pub fn PdfDrawControl::matrix_rotate(
  self : PdfDrawControl,
  text : String,
) -> Unit raise PdfError {
  let values = pdf_draw_control_expect_floats(
    text, 3, "-mrot takes three numbers", "-mrot takes three numbers",
  )
  self.add_op(
    PdfDrawMatrix(transform_rotate(point2(values[0], values[1]), values[2])),
  )
}

///|
/// Append a scale matrix operation parsed from a cpdf argument.
pub fn PdfDrawControl::matrix_scale(
  self : PdfDrawControl,
  text : String,
) -> Unit raise PdfError {
  let values = pdf_draw_control_expect_floats(
    text, 4, "-mscale takes four numbers", "-mscale takes four numbers",
  )
  self.add_op(
    PdfDrawMatrix(
      transform_scale(point2(values[0], values[1]), values[2], values[3]),
    ),
  )
}

///|
/// Append an X-shear matrix operation parsed from a cpdf argument.
pub fn PdfDrawControl::matrix_shear_x(
  self : PdfDrawControl,
  text : String,
) -> Unit raise PdfError {
  let values = pdf_draw_control_expect_floats(
    text, 3, "-mshearx takes three numbers", "-mshearx takes three numbers",
  )
  self.add_op(
    PdfDrawMatrix(transform_shear_x(point2(values[0], values[1]), values[2])),
  )
}

///|
/// Append a Y-shear matrix operation parsed from a cpdf argument.
pub fn PdfDrawControl::matrix_shear_y(
  self : PdfDrawControl,
  text : String,
) -> Unit raise PdfError {
  let values = pdf_draw_control_expect_floats(
    text, 3, "-msheary takes three numbers", "-msheary takes three numbers",
  )
  self.add_op(
    PdfDrawMatrix(transform_shear_y(point2(values[0], values[1]), values[2])),
  )
}

///|
/// Append a new-page operation to the current frame.
pub fn PdfDrawControl::add_new_page(
  self : PdfDrawControl,
) -> Unit raise PdfError {
  self.add_op(PdfDrawNewPage)
}

///|
/// Append a fill-opacity operation.
pub fn PdfDrawControl::add_opacity(
  self : PdfDrawControl,
  opacity : Double,
) -> Unit raise PdfError {
  self.add_op(PdfDrawOpacity(opacity))
}

///|
/// Append a stroke-opacity operation.
pub fn PdfDrawControl::add_stroke_opacity(
  self : PdfDrawControl,
  opacity : Double,
) -> Unit raise PdfError {
  self.add_op(PdfDrawSOpacity(opacity))
}

///|
/// Start a pushed graphics-state frame.
pub fn PdfDrawControl::push_group(self : PdfDrawControl) -> Unit {
  self.frames.push({ name: pdf_draw_control_push_frame, ops: [] })
}

///|
/// Finish the current pushed graphics-state frame and append a `PdfDrawQq` op.
pub fn PdfDrawControl::pop_group(self : PdfDrawControl) -> Unit raise PdfError {
  match self.frames.pop() {
    Some(frame) if frame.name == pdf_draw_control_push_frame =>
      self.add_op(PdfDrawQq(pdf_draw_control_copy_ops(frame.ops)))
    Some(frame) => {
      self.frames.push(frame)
      raise SoftError("not in a pushed section at -pop")
    }
    None => raise SoftError("not in a pushed section at -pop")
  }
}
