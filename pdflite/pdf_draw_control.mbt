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
