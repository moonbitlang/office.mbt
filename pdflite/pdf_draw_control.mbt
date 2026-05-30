///|
let pdf_draw_control_main_frame = "_MAIN"

///|
let pdf_draw_control_text_frame = "_TEXT"

///|
let pdf_draw_control_push_frame = "_PUSH"

///|
/// Named frame of draw operations used by `PdfDrawControl` while nesting.
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
  mut xobject_bbox : @geometry.PdfCoordRectangle
  mut font_name : String
  mut font_size : Double
  mut fontpack : PdfFontPack?
  mut fontpack_initialized : Bool
  mut paragraph_indent : Double?
  mut role_map : String
  mut auto_artifacts : Bool
} derive(Debug, Eq, ToJson)

///|
fn pdf_draw_control_default_bbox() -> @geometry.PdfCoordRectangle {
  { x: 0.0, y: 0.0, width: 1000.0, height: 1000.0 }
}

///|
/// Create a fresh cpdf draw-control state with an empty main frame.
pub fn pdf_draw_control_new() -> PdfDrawControl {
  {
    frames: [{ name: pdf_draw_control_main_frame, ops: [] }],
    xobject_bbox: pdf_draw_control_default_bbox(),
    font_name: "Times-Roman",
    font_size: 12.0,
    fontpack: None,
    fontpack_initialized: false,
    paragraph_indent: None,
    role_map: "",
    auto_artifacts: true,
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
  let parts : Array[String] = Array::new(capacity=bytes.length())
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
  let parts = pdf_draw_control_split_on_spaces(text)
  let output : Array[Double] = Array::new(capacity=parts.length())
  for part in parts {
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
