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
  mut font_name : String
  mut font_size : Double
  mut fontpack : PdfFontPack?
  mut fontpack_initialized : Bool
  mut paragraph_indent : Double?
  mut role_map : String
  mut auto_artifacts : Bool
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
/// Set the role-map body used by structured draw output.
///
/// The value follows cpdf's `-rolemap` convention: pass entries such as
/// `"/H1 /H /Aside /Div"` without the surrounding `<< >>`.
pub fn PdfDrawControl::set_role_map(
  self : PdfDrawControl,
  role_map : String,
) -> Unit {
  self.role_map = role_map
}

///|
/// Return the role-map body configured on this draw-control state.
pub fn PdfDrawControl::role_map(self : PdfDrawControl) -> String {
  self.role_map
}

///|
/// Enable or disable automatic artifact wrapping for structured draw output.
pub fn PdfDrawControl::set_auto_artifacts(
  self : PdfDrawControl,
  enabled : Bool,
) -> Unit {
  self.auto_artifacts = enabled
}

///|
/// Return whether automatic artifact wrapping is enabled on this state.
pub fn PdfDrawControl::auto_artifacts(self : PdfDrawControl) -> Bool {
  self.auto_artifacts
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
pub fn PdfDrawControl::add_image(
  self : PdfDrawControl,
  name : String,
) -> Unit raise PdfError {
  self.add_op(PdfDrawImage(name))
}

///|
pub fn PdfDrawControl::add_new_page(
  self : PdfDrawControl,
) -> Unit raise PdfError {
  self.add_op(PdfDrawNewPage)
}

///|
pub fn PdfDrawControl::add_opacity(
  self : PdfDrawControl,
  opacity : Double,
) -> Unit raise PdfError {
  self.add_op(PdfDrawOpacity(opacity))
}

///|
pub fn PdfDrawControl::add_stroke_opacity(
  self : PdfDrawControl,
  opacity : Double,
) -> Unit raise PdfError {
  self.add_op(PdfDrawSOpacity(opacity))
}

///|
pub fn PdfDrawControl::add_leading(
  self : PdfDrawControl,
  leading : Double,
) -> Unit raise PdfError {
  self.add_op(PdfDrawLeading(leading))
}

///|
pub fn PdfDrawControl::add_char_space(
  self : PdfDrawControl,
  spacing : Double,
) -> Unit raise PdfError {
  self.add_op(PdfDrawCharSpace(spacing))
}

///|
pub fn PdfDrawControl::add_word_space(
  self : PdfDrawControl,
  spacing : Double,
) -> Unit raise PdfError {
  self.add_op(PdfDrawWordSpace(spacing))
}

///|
pub fn PdfDrawControl::add_text_scale(
  self : PdfDrawControl,
  scale : Double,
) -> Unit raise PdfError {
  self.add_op(PdfDrawTextScale(scale))
}

///|
pub fn PdfDrawControl::add_render_mode(
  self : PdfDrawControl,
  mode : Int,
) -> Unit raise PdfError {
  self.add_op(PdfDrawRenderMode(mode))
}

///|
pub fn PdfDrawControl::add_rise(
  self : PdfDrawControl,
  rise : Double,
) -> Unit raise PdfError {
  self.add_op(PdfDrawRise(rise))
}

///|
pub fn PdfDrawControl::add_newline(
  self : PdfDrawControl,
) -> Unit raise PdfError {
  self.add_op(PdfDrawNewline)
}

///|
pub fn PdfDrawControl::set_font_name(
  self : PdfDrawControl,
  font_name : String,
) -> Unit {
  self.font_name = font_name
}

///|
pub fn PdfDrawControl::set_font_size(
  self : PdfDrawControl,
  font_size : Double,
) -> Unit {
  self.font_size = font_size
}

///|
pub fn PdfDrawControl::set_font(
  self : PdfDrawControl,
  font_name : String,
  font_size : Double,
) -> Unit {
  self.font_name = font_name
  self.font_size = font_size
}

///|
pub fn PdfDrawControl::set_fontpack(
  self : PdfDrawControl,
  fontpack : PdfFontPack?,
) -> Unit {
  self.fontpack = fontpack
  self.fontpack_initialized = false
}

///|
pub fn PdfDrawControl::set_paragraph_indent(
  self : PdfDrawControl,
  indent : Double?,
) -> Unit {
  self.paragraph_indent = indent
}

///|
fn PdfDrawControl::ensure_text_section(
  self : PdfDrawControl,
  message : String,
) -> Unit raise PdfError {
  if self.depth() < 2 {
    raise SoftError(message)
  }
}

///|
fn PdfDrawControl::add_default_fontpack(
  self : PdfDrawControl,
) -> Unit raise PdfError {
  if !self.fontpack_initialized {
    match self.fontpack {
      Some(fontpack) =>
        self.add_op(PdfDrawFontPack(self.font_name, fontpack, []))
      None => ()
    }
    self.fontpack_initialized = true
  }
}

///|
fn PdfDrawControl::add_current_font(
  self : PdfDrawControl,
) -> Unit raise PdfError {
  self.add_op(PdfDrawFont(self.font_name, self.font_size))
}

///|
pub fn PdfDrawControl::add_text(
  self : PdfDrawControl,
  text : String,
) -> Unit raise PdfError {
  self.ensure_text_section("-text must be in a -bt / -et section")
  self.add_default_fontpack()
  self.add_current_font()
  self.add_op(PdfDrawText(text))
}

///|
pub fn PdfDrawControl::add_special_text(
  self : PdfDrawControl,
  text : String,
) -> Unit raise PdfError {
  self.ensure_text_section("-stext must be in a -bt / -et section")
  self.add_default_fontpack()
  self.add_current_font()
  self.add_op(PdfDrawSpecialText(text))
}

///|
fn pdf_draw_control_utf8_string(bytes : BytesView) -> String {
  @utf8.decode(bytes) catch {
    _ => @utf8.decode_lossy(bytes)
  }
}

///|
fn pdf_draw_control_parse_para_spec(
  document : PdfDocument,
  spec : String,
) -> (PdfDrawJustification, Double, String) raise PdfError {
  let bytes = @utf8.encode(spec)
  if bytes.length() == 0 {
    raise SoftError("Unknown justification specification")
  }
  let justification = match bytes[0].to_int() {
    76 => PdfDrawLeft
    82 => PdfDrawRight
    67 => PdfDrawCentre
    _ => raise SoftError("Unknown justification specification")
  }
  let mut separator = -1
  for index in 1..<bytes.length() {
    if bytes[index].to_int() == 61 {
      if separator >= 0 {
        raise SoftError("addjpeg: bad file specification")
      }
      separator = index
    }
  }
  if separator < 0 {
    raise SoftError("addjpeg: bad file specification")
  }
  let width = document.parse_single_number(
    @ascii.decode_lossy(bytes[1:separator]),
  )
  let text = pdf_draw_control_utf8_string(bytes[separator + 1:])
  (justification, width, text)
}

///|
fn pdf_draw_control_split_escaped_newlines(text : String) -> Array[String] {
  let bytes = @utf8.encode(text)
  let parts : Array[String] = []
  let mut start = 0
  let mut index = 0
  while index < bytes.length() {
    if index + 1 < bytes.length() &&
      bytes[index].to_int() == 92 &&
      bytes[index + 1].to_int() == 110 {
      parts.push(pdf_draw_control_utf8_string(bytes[start:index]))
      index = index + 2
      start = index
    } else {
      index = index + 1
    }
  }
  if start < bytes.length() {
    parts.push(pdf_draw_control_utf8_string(bytes[start:]))
  }
  parts
}

///|
pub fn PdfDrawControl::add_para(
  self : PdfDrawControl,
  document : PdfDocument,
  spec : String,
) -> Unit raise PdfError {
  self.ensure_text_section("-para must be in a -bt / -et section")
  self.add_default_fontpack()
  self.add_current_font()
  let (justification, width, text) = pdf_draw_control_parse_para_spec(
    document, spec,
  )
  self.add_op(PdfDrawPara(None, justification, width, [text]))
}

///|
pub fn PdfDrawControl::add_paras(
  self : PdfDrawControl,
  document : PdfDocument,
  spec : String,
) -> Unit raise PdfError {
  self.ensure_text_section("-paras must be in a -bt / -et section")
  self.add_default_fontpack()
  self.add_current_font()
  let (justification, width, text) = pdf_draw_control_parse_para_spec(
    document, spec,
  )
  self.add_op(
    PdfDrawPara(
      self.paragraph_indent,
      justification,
      width,
      pdf_draw_control_split_escaped_newlines(text),
    ),
  )
}

///|
pub fn PdfDrawControl::add_rect(
  self : PdfDrawControl,
  document : PdfDocument,
  text : String,
) -> Unit raise PdfError {
  let rect = document.parse_coordinate_rectangle(text)
  self.add_op(PdfDrawRect(rect.x, rect.y, rect.width, rect.height))
}

///|
pub fn PdfDrawControl::add_to(
  self : PdfDrawControl,
  document : PdfDocument,
  text : String,
) -> Unit raise PdfError {
  let point = document.parse_coordinate(text)
  self.add_op(PdfDrawTo(point.x, point.y))
}

///|
pub fn PdfDrawControl::add_line(
  self : PdfDrawControl,
  document : PdfDocument,
  text : String,
) -> Unit raise PdfError {
  let point = document.parse_coordinate(text)
  self.add_op(PdfDrawLine(point.x, point.y))
}

///|
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
pub fn PdfDrawControl::add_circle(
  self : PdfDrawControl,
  text : String,
) -> Unit raise PdfError {
  let values = pdf_draw_control_expect_floats(
    text, 3, "-circle requires three numbers", "malformed -circle",
  )
  let path = pdf_shape_circle(values[0], values[1], values[2])
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
pub fn PdfDrawControl::stroke(self : PdfDrawControl) -> Unit raise PdfError {
  self.add_op(PdfDrawStroke)
}

///|
pub fn PdfDrawControl::fill(self : PdfDrawControl) -> Unit raise PdfError {
  self.add_op(PdfDrawFill)
}

///|
pub fn PdfDrawControl::fill_even_odd(
  self : PdfDrawControl,
) -> Unit raise PdfError {
  self.add_op(PdfDrawFillEvenOdd)
}

///|
pub fn PdfDrawControl::stroke_fill(
  self : PdfDrawControl,
) -> Unit raise PdfError {
  self.add_op(PdfDrawFillStroke)
}

///|
pub fn PdfDrawControl::stroke_fill_even_odd(
  self : PdfDrawControl,
) -> Unit raise PdfError {
  self.add_op(PdfDrawFillStrokeEvenOdd)
}

///|
pub fn PdfDrawControl::clip(self : PdfDrawControl) -> Unit raise PdfError {
  self.add_op(PdfDrawClip)
}

///|
pub fn PdfDrawControl::clip_even_odd(
  self : PdfDrawControl,
) -> Unit raise PdfError {
  self.add_op(PdfDrawClipEvenOdd)
}

///|
pub fn PdfDrawControl::close_path(self : PdfDrawControl) -> Unit raise PdfError {
  self.add_op(PdfDrawClosePath)
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
