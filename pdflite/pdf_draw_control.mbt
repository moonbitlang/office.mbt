///|
let pdf_draw_control_main_frame = "_MAIN"

///|
let pdf_draw_control_text_frame = "_TEXT"

///|
let pdf_draw_control_push_frame = "_PUSH"

///|
pub(all) struct PdfDrawControlFrame {
  name : String
  ops : Array[PdfDrawOp]
} derive(Debug, Eq, ToJson)

///|
/// Stateful builder for cpdf draw-control operations.
///
/// This ports the frame-stack behavior from `cpdfdrawcontrol.ml`: ordinary
/// operations are appended to the current frame; text sections, pushed graphics
/// groups, and form XObjects collect nested operations and collapse them into
/// `TextSection`, `Qq`, and `FormXObject` operations when closed.
pub struct PdfDrawControl {
  frames : Array[PdfDrawControlFrame]
  mut xobject_bbox : PdfCoordRectangle
} derive(Debug, Eq, ToJson)

///|
fn pdf_draw_control_default_bbox() -> PdfCoordRectangle {
  { x: 0.0, y: 0.0, width: 1000.0, height: 1000.0 }
}

///|
/// Create a fresh cpdf draw-control state with an empty main frame.
pub fn pdf_draw_control_new() -> PdfDrawControl {
  {
    frames: [{ name: pdf_draw_control_main_frame, ops: [] }],
    xobject_bbox: pdf_draw_control_default_bbox(),
  }
}

///|
fn PdfDrawControl::current_frame(
  self : PdfDrawControl,
) -> PdfDrawControlFrame raise PdfError {
  if self.frames.length() == 0 {
    raise SoftError("no drawops")
  }
  self.frames[self.frames.length() - 1]
}

///|
fn pdf_draw_control_copy_ops(ops : ArrayView[PdfDrawOp]) -> Array[PdfDrawOp] {
  [
    for op in ops => op
  ]
}

///|
/// Return the current frame name.
pub fn PdfDrawControl::current_frame_name(
  self : PdfDrawControl,
) -> String raise PdfError {
  self.current_frame().name
}

///|
/// Return the current stack depth.
pub fn PdfDrawControl::depth(self : PdfDrawControl) -> Int {
  self.frames.length()
}

///|
/// Return a copy of the operations collected in the current frame.
pub fn PdfDrawControl::current_ops(
  self : PdfDrawControl,
) -> Array[PdfDrawOp] raise PdfError {
  pdf_draw_control_copy_ops(self.current_frame().ops)
}

///|
/// Return a copy of the operations collected in the main frame.
pub fn PdfDrawControl::ops(self : PdfDrawControl) -> Array[PdfDrawOp] {
  if self.frames.length() == 0 {
    []
  } else {
    pdf_draw_control_copy_ops(self.frames[0].ops)
  }
}

///|
/// Append one operation to the current frame.
pub fn PdfDrawControl::add_op(
  self : PdfDrawControl,
  op : PdfDrawOp,
) -> Unit raise PdfError {
  self.current_frame().ops.push(op)
}

///|
fn pdf_draw_control_split_on_spaces(text : String) -> Array[String] {
  let bytes = @utf8.encode(text)
  let parts : Array[String] = []
  let mut start = 0
  for index in 0..<bytes.length() {
    if bytes[index].to_int() == 32 {
      parts.push(@ascii.decode_lossy(bytes[start:index]))
      start = index + 1
    }
  }
  parts.push(@ascii.decode_lossy(bytes[start:]))
  parts
}

///|
fn pdf_draw_control_read_floats(
  text : String,
  message : String,
) -> Array[Double] raise PdfError {
  let output : Array[Double] = []
  for part in pdf_draw_control_split_on_spaces(text) {
    let parsed : Result[Double, Error] = try? @strconv.from_str(part)
    match parsed {
      Ok(value) => output.push(value)
      Err(_) => raise SoftError(message)
    }
  }
  output
}

///|
fn pdf_draw_control_expect_floats(
  text : String,
  count : Int,
  count_message : String,
  parse_message : String,
) -> Array[Double] raise PdfError {
  let values = pdf_draw_control_read_floats(text, parse_message)
  if values.length() != count {
    raise SoftError(count_message)
  }
  values
}

///|
/// Append a stroke colour operation parsed from a cpdf draw-control argument.
pub fn PdfDrawControl::set_stroke(
  self : PdfDrawControl,
  text : String,
) -> Unit raise PdfError {
  self.add_op(PdfDrawSetStroke(pdf_draw_colour_of_string(text)))
}

///|
/// Append a fill colour operation parsed from a cpdf draw-control argument.
pub fn PdfDrawControl::set_fill(
  self : PdfDrawControl,
  text : String,
) -> Unit raise PdfError {
  self.add_op(PdfDrawSetFill(pdf_draw_colour_of_string(text)))
}

///|
pub fn PdfDrawControl::add_tag(
  self : PdfDrawControl,
  tag : String,
) -> Unit raise PdfError {
  self.add_op(PdfDrawTag(tag))
}

///|
pub fn PdfDrawControl::add_structure_tag(
  self : PdfDrawControl,
  tag : String,
) -> Unit raise PdfError {
  self.add_op(PdfDrawSTag(tag))
}

///|
pub fn PdfDrawControl::end_tag(self : PdfDrawControl) -> Unit raise PdfError {
  self.add_op(PdfDrawEndTag)
}

///|
pub fn PdfDrawControl::end_structure_tag(
  self : PdfDrawControl,
) -> Unit raise PdfError {
  self.add_op(PdfDrawEndSTag)
}

///|
pub fn PdfDrawControl::set_auto_tag(
  self : PdfDrawControl,
  enabled : Bool,
) -> Unit raise PdfError {
  self.add_op(PdfDrawAutoTag(enabled))
}

///|
pub fn PdfDrawControl::begin_artifact(
  self : PdfDrawControl,
) -> Unit raise PdfError {
  self.add_op(PdfDrawBeginArtifact)
}

///|
pub fn PdfDrawControl::end_artifact(
  self : PdfDrawControl,
) -> Unit raise PdfError {
  self.add_op(PdfDrawEndArtifact)
}

///|
pub fn PdfDrawControl::add_namespace(
  self : PdfDrawControl,
  namespace_name : String,
) -> Unit raise PdfError {
  self.add_op(PdfDrawNamespace(namespace_name))
}

///|
pub fn PdfDrawControl::add_element_info(
  self : PdfDrawControl,
  key : String,
  value : PdfObject,
) -> Unit raise PdfError {
  self.add_op(PdfDrawEltInfo(key, value))
}

///|
pub fn PdfDrawControl::end_element_info(
  self : PdfDrawControl,
  key : String,
) -> Unit raise PdfError {
  self.add_op(PdfDrawEndEltInfo(key))
}

///|
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
pub fn PdfDrawControl::use_xobject(
  self : PdfDrawControl,
  name : String,
) -> Unit raise PdfError {
  self.add_op(PdfDrawUse(name))
}

///|
/// Start collecting a named form XObject.
pub fn PdfDrawControl::start_xobject(
  self : PdfDrawControl,
  name : String,
) -> Unit {
  self.frames.push({ name, ops: [] })
}

///|
/// Set the bounding box used for the next closed form XObject.
pub fn PdfDrawControl::set_xobject_bbox(
  self : PdfDrawControl,
  bbox : PdfCoordRectangle,
) -> Unit {
  self.xobject_bbox = bbox
}

///|
/// Finish the current form XObject and append a `PdfDrawFormXObject` op.
pub fn PdfDrawControl::end_xobject(
  self : PdfDrawControl,
) -> Unit raise PdfError {
  match self.frames.pop() {
    Some(frame) if self.frames.length() > 0 => {
      let bbox = self.xobject_bbox
      self.add_op(
        PdfDrawFormXObject(
          bbox.x,
          bbox.y,
          bbox.width,
          bbox.height,
          frame.name,
          pdf_draw_control_copy_ops(frame.ops),
        ),
      )
    }
    Some(frame) => {
      self.frames.push(frame)
      raise SoftError("no drawops")
    }
    None => raise SoftError("too many -end-xobj or -et")
  }
}

///|
/// Start a text-section frame.
pub fn PdfDrawControl::begin_text_section(self : PdfDrawControl) -> Unit {
  self.frames.push({ name: pdf_draw_control_text_frame, ops: [] })
}

///|
/// Finish the current text-section frame and append a `PdfDrawTextSection` op.
pub fn PdfDrawControl::end_text_section(
  self : PdfDrawControl,
) -> Unit raise PdfError {
  match self.frames.pop() {
    Some(frame) if frame.name == pdf_draw_control_text_frame =>
      self.add_op(PdfDrawTextSection(pdf_draw_control_copy_ops(frame.ops)))
    Some(frame) => {
      self.frames.push(frame)
      raise SoftError("not in a text section at -et")
    }
    None => raise SoftError("not in a text section at -et")
  }
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

///|
/// Compatibility wrapper for `pdf_draw_control_new`.
pub fn pdf_draw_control() -> PdfDrawControl {
  pdf_draw_control_new()
}
