///|
pub(all) struct PdfContentOperatorFrame {
  ctm : TransformMatrix
  partial_path : PdfContentPartialPath
  clipping_path : Array[PdfPath]
  path : PdfDrawnPath
  path_state : PdfContentPathState
  text_state : PdfContentTextState
  miter_limit : Double
  flatness : Double
  alpha_constant_stroke : Double
  alpha_constant_non_stroke : Double
  alpha_source : Bool
  smoothness : Double
  stroke_adjustment : Bool
  overprint_stroke : Bool
  overprint_non_stroke : Bool
  overprint_mode : Int
  black_generation : PdfObject
  undercolour_removal : PdfObject
  transfer : PdfObject
  halftone : PdfObject
  blend_mode : PdfObject
  soft_mask : PdfObject
  black_point_compensation : String
  marked_content_point : PdfContentMarkedContent?
  marked_content : Array[PdfContentMarkedContent]
  type3_d0 : PdfContentType3D0?
  type3_d1 : PdfContentType3D1?
} derive(Debug, Eq, ToJson)

///|
pub(all) struct PdfContentOperatorState {
  ctm : TransformMatrix
  partial_path : PdfContentPartialPath
  clipping_path : Array[PdfPath]
  path : PdfDrawnPath
  path_state : PdfContentPathState
  text_state : PdfContentTextState
  miter_limit : Double
  flatness : Double
  alpha_constant_stroke : Double
  alpha_constant_non_stroke : Double
  alpha_source : Bool
  smoothness : Double
  stroke_adjustment : Bool
  overprint_stroke : Bool
  overprint_non_stroke : Bool
  overprint_mode : Int
  black_generation : PdfObject
  undercolour_removal : PdfObject
  transfer : PdfObject
  halftone : PdfObject
  blend_mode : PdfObject
  soft_mask : PdfObject
  black_point_compensation : String
  marked_content_point : PdfContentMarkedContent?
  marked_content : Array[PdfContentMarkedContent]
  type3_d0 : PdfContentType3D0?
  type3_d1 : PdfContentType3D1?
  state_stack : Array[PdfContentOperatorFrame]
} derive(Debug, Eq, ToJson)

///|
pub(all) struct PdfContentOperatorTextResult {
  state : PdfContentOperatorState
  entries : Array[PdfContentJsonEntry]
} derive(Debug, Eq, ToJson)

///|
pub(all) struct PdfContentMarkedContent {
  tag : String
  properties : PdfObject?
} derive(Debug, Eq, ToJson)

///|
fn pdf_content_extgstate_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_content_extgstate_lw_name : PdfName = pdf_content_extgstate_name("/LW")

///|
let pdf_content_extgstate_lc_name : PdfName = pdf_content_extgstate_name("/LC")

///|
let pdf_content_extgstate_lj_name : PdfName = pdf_content_extgstate_name("/LJ")

///|
let pdf_content_extgstate_ml_name : PdfName = pdf_content_extgstate_name("/ML")

///|
let pdf_content_extgstate_d_name : PdfName = pdf_content_extgstate_name("/D")

///|
let pdf_content_extgstate_ri_name : PdfName = pdf_content_extgstate_name("/RI")

///|
let pdf_content_extgstate_resource_name : PdfName = pdf_content_extgstate_name(
  "/ExtGState",
)

///|
let pdf_content_extgstate_font_name : PdfName = pdf_content_extgstate_name(
  "/Font",
)

///|
let pdf_content_extgstate_op_stroke_name : PdfName = pdf_content_extgstate_name(
  "/OP",
)

///|
let pdf_content_extgstate_op_non_stroke_name : PdfName = pdf_content_extgstate_name(
  "/op",
)

///|
let pdf_content_extgstate_bg_name : PdfName = pdf_content_extgstate_name("/BG")

///|
let pdf_content_extgstate_bg2_name : PdfName = pdf_content_extgstate_name(
  "/BG2",
)

///|
let pdf_content_extgstate_ucr_name : PdfName = pdf_content_extgstate_name(
  "/UCR",
)

///|
let pdf_content_extgstate_ucr2_name : PdfName = pdf_content_extgstate_name(
  "/UCR2",
)

///|
let pdf_content_extgstate_tr_name : PdfName = pdf_content_extgstate_name("/TR")

///|
let pdf_content_extgstate_tr2_name : PdfName = pdf_content_extgstate_name(
  "/TR2",
)

///|
let pdf_content_extgstate_ht_name : PdfName = pdf_content_extgstate_name("/HT")

///|
let pdf_content_extgstate_smask_name : PdfName = pdf_content_extgstate_name(
  "/SMask",
)

///|
let pdf_content_extgstate_hto_name : PdfName = pdf_content_extgstate_name(
  "/HTO",
)

///|
let pdf_content_extgstate_bm_name : PdfName = pdf_content_extgstate_name("/BM")

///|
let pdf_content_extgstate_use_black_pt_comp_name : PdfName = pdf_content_extgstate_name(
  "/UseBlackPtComp",
)

///|
let pdf_content_extgstate_normal_name : PdfName = pdf_content_extgstate_name(
  "/Normal",
)

///|
let pdf_content_extgstate_fl_name : PdfName = pdf_content_extgstate_name("/FL")

///|
let pdf_content_extgstate_sm_name : PdfName = pdf_content_extgstate_name("/SM")

///|
let pdf_content_extgstate_sa_name : PdfName = pdf_content_extgstate_name("/SA")

///|
let pdf_content_extgstate_ca_stroke_name : PdfName = pdf_content_extgstate_name(
  "/CA",
)

///|
let pdf_content_extgstate_ca_non_stroke_name : PdfName = pdf_content_extgstate_name(
  "/ca",
)

///|
let pdf_content_extgstate_ais_name : PdfName = pdf_content_extgstate_name(
  "/AIS",
)

///|
let pdf_content_extgstate_tk_name : PdfName = pdf_content_extgstate_name("/TK")

///|
fn pdf_content_extgstate_tk_key() -> PdfName {
  pdf_content_extgstate_tk_name
}

///|
pub(all) struct PdfContentType3D0 {
  width_x : Double
  width_y : Double
} derive(Debug, Eq, ToJson)

///|
pub(all) struct PdfContentType3D1 {
  width_x : Double
  width_y : Double
  llx : Double
  lly : Double
  urx : Double
  ury : Double
} derive(Debug, Eq, ToJson)

///|
/// Return cpdfcontent's initial operator state for a page boundary.
pub fn pdf_content_initial_operator_state(
  minx : Double,
  miny : Double,
  maxx : Double,
  maxy : Double,
) -> PdfContentOperatorState {
  let clipping_path = pdf_content_initial_clipping_path(minx, miny, maxx, maxy)
  {
    ctm: transform_identity_matrix,
    partial_path: pdf_content_no_partial_path(),
    clipping_path,
    path: pdf_content_initial_drawn_path(),
    path_state: pdf_content_initial_path_state(minx, miny, maxx, maxy),
    text_state: pdf_content_initial_text_state(),
    miter_limit: 10.0,
    flatness: 1.0,
    alpha_constant_stroke: 1.0,
    alpha_constant_non_stroke: 1.0,
    alpha_source: false,
    smoothness: 0.5,
    stroke_adjustment: false,
    overprint_stroke: false,
    overprint_non_stroke: false,
    overprint_mode: 0,
    black_generation: PdfNull,
    undercolour_removal: PdfNull,
    transfer: PdfNull,
    halftone: PdfNull,
    blend_mode: PdfNameObject(pdf_content_extgstate_normal_name),
    soft_mask: PdfNull,
    black_point_compensation: "/Default",
    marked_content_point: None,
    marked_content: [],
    type3_d0: None,
    type3_d1: None,
    state_stack: [],
  }
}

///|
fn PdfContentOperatorState::content_frame(
  self : PdfContentOperatorState,
) -> PdfContentOperatorFrame {
  {
    ctm: self.ctm,
    partial_path: self.partial_path,
    clipping_path: pdf_content_state_copy_paths(self.clipping_path),
    path: self.path,
    path_state: self.path_state,
    text_state: self.text_state,
    miter_limit: self.miter_limit,
    flatness: self.flatness,
    alpha_constant_stroke: self.alpha_constant_stroke,
    alpha_constant_non_stroke: self.alpha_constant_non_stroke,
    alpha_source: self.alpha_source,
    smoothness: self.smoothness,
    stroke_adjustment: self.stroke_adjustment,
    overprint_stroke: self.overprint_stroke,
    overprint_non_stroke: self.overprint_non_stroke,
    overprint_mode: self.overprint_mode,
    black_generation: self.black_generation,
    undercolour_removal: self.undercolour_removal,
    transfer: self.transfer,
    halftone: self.halftone,
    blend_mode: self.blend_mode,
    soft_mask: self.soft_mask,
    black_point_compensation: self.black_point_compensation,
    marked_content_point: self.marked_content_point,
    marked_content: pdf_content_operator_copy_marked_content(
      self.marked_content,
    ),
    type3_d0: self.type3_d0,
    type3_d1: self.type3_d1,
  }
}

///|
fn pdf_content_operator_copy_stack(
  stack : ArrayView[PdfContentOperatorFrame],
) -> Array[PdfContentOperatorFrame] {
  [
    for frame in stack => frame
  ]
}

///|
fn pdf_content_operator_copy_marked_content(
  marked_content : ArrayView[PdfContentMarkedContent],
) -> Array[PdfContentMarkedContent] {
  [
    for content in marked_content => content
  ]
}

///|
fn pdf_content_operator_marked_content(
  tag : PdfName,
  properties : PdfObject?,
) -> PdfContentMarkedContent {
  { tag: pdf_content_state_name_text(tag), properties }
}

///|
fn pdf_content_operator_prepend_marked_content(
  marked_content : ArrayView[PdfContentMarkedContent],
  content : PdfContentMarkedContent,
) -> Array[PdfContentMarkedContent] {
  let output = [content]
  for existing in marked_content {
    output.push(existing)
  }
  output
}

///|
fn pdf_content_operator_pop_marked_content(
  marked_content : ArrayView[PdfContentMarkedContent],
) -> Array[PdfContentMarkedContent] {
  let length = marked_content.length()
  if length == 0 {
    []
  } else {
    [
      for index in 1..<length => marked_content[index]
    ]
  }
}

///|
fn PdfContentOperatorState::content_push_state(
  self : PdfContentOperatorState,
) -> PdfContentOperatorState {
  let stack = pdf_content_operator_copy_stack(self.state_stack)
  stack.push(self.content_frame())
  { ..self, state_stack: stack }
}

///|
fn PdfContentOperatorState::content_pop_state(
  self : PdfContentOperatorState,
) -> PdfContentOperatorState {
  let length = self.state_stack.length()
  if length == 0 {
    self
  } else {
    let frame = self.state_stack[length - 1]
    {
      ctm: frame.ctm,
      partial_path: frame.partial_path,
      clipping_path: pdf_content_state_copy_paths(frame.clipping_path),
      path: frame.path,
      path_state: frame.path_state,
      text_state: frame.text_state,
      miter_limit: frame.miter_limit,
      flatness: frame.flatness,
      alpha_constant_stroke: frame.alpha_constant_stroke,
      alpha_constant_non_stroke: frame.alpha_constant_non_stroke,
      alpha_source: frame.alpha_source,
      smoothness: frame.smoothness,
      stroke_adjustment: frame.stroke_adjustment,
      overprint_stroke: frame.overprint_stroke,
      overprint_non_stroke: frame.overprint_non_stroke,
      overprint_mode: frame.overprint_mode,
      black_generation: frame.black_generation,
      undercolour_removal: frame.undercolour_removal,
      transfer: frame.transfer,
      halftone: frame.halftone,
      blend_mode: frame.blend_mode,
      soft_mask: frame.soft_mask,
      black_point_compensation: frame.black_point_compensation,
      marked_content_point: frame.marked_content_point,
      marked_content: pdf_content_operator_copy_marked_content(
        frame.marked_content,
      ),
      type3_d0: frame.type3_d0,
      type3_d1: frame.type3_d1,
      state_stack: [
        for index in 0..<(length - 1) => self.state_stack[index]
      ],
    }
  }
}

///|
/// Apply cpdfcontent graphics-state stack and CTM operators.
pub fn PdfContentOperatorState::content_apply_graphics_state_op(
  self : PdfContentOperatorState,
  op : PdfContentOp,
) -> PdfContentOperatorState {
  match op {
    Op_q => self.content_push_state()
    Op_Q => self.content_pop_state()
    Op_cm(matrix) => { ..self, ctm: transform_matrix_compose(self.ctm, matrix) }
    _ => self
  }
}

///|
/// Compatibility wrapper for `PdfContentOperatorState::content_apply_graphics_state_op`.
pub fn pdf_content_apply_graphics_state_op(
  state : PdfContentOperatorState,
  op : PdfContentOp,
) -> PdfContentOperatorState {
  state.content_apply_graphics_state_op(op)
}

///|
/// Apply cpdfcontent direct graphics-parameter operators.
pub fn PdfContentOperatorState::content_apply_graphics_parameter_op(
  self : PdfContentOperatorState,
  op : PdfContentOp,
) -> PdfContentOperatorState {
  match op {
    Op_M(limit) => { ..self, miter_limit: limit }
    Op_i(flatness) => { ..self, flatness, }
    _ => self
  }
}

///|
/// Compatibility wrapper for `PdfContentOperatorState::content_apply_graphics_parameter_op`.
pub fn pdf_content_apply_graphics_parameter_op(
  state : PdfContentOperatorState,
  op : PdfContentOp,
) -> PdfContentOperatorState {
  state.content_apply_graphics_parameter_op(op)
}

///|
fn pdf_content_extgstate_number(object : PdfObject) -> Double? {
  match object {
    PdfReal(value) => Some(value)
    PdfInteger(value) => Some(value.to_double())
    _ => None
  }
}

///|
fn pdf_content_extgstate_integer(object : PdfObject) -> Int? {
  match object {
    PdfInteger(value) => Some(value)
    _ => None
  }
}

///|
fn PdfDocument::content_extgstate_number(
  self : PdfDocument,
  extgstate : PdfObject,
  key : PdfName,
) -> Double? {
  match self.lookup_direct(key, extgstate) {
    Some(value) => pdf_content_extgstate_number(value)
    None => None
  }
}

///|
fn PdfDocument::content_extgstate_integer(
  self : PdfDocument,
  extgstate : PdfObject,
  key : PdfName,
) -> Int? {
  match self.lookup_direct(key, extgstate) {
    Some(value) => pdf_content_extgstate_integer(value)
    None => None
  }
}

///|
fn PdfDocument::content_extgstate_name_value(
  self : PdfDocument,
  extgstate : PdfObject,
  key : PdfName,
) -> PdfName? {
  match self.lookup_direct(key, extgstate) {
    Some(PdfNameObject(value)) => Some(value)
    _ => None
  }
}

///|
fn PdfDocument::content_extgstate_boolean(
  self : PdfDocument,
  extgstate : PdfObject,
  key : PdfName,
) -> Bool? {
  match self.lookup_direct(key, extgstate) {
    Some(PdfBoolean(value)) => Some(value)
    _ => None
  }
}

///|
/// Apply cpdfcontent scalar graphics parameters from a resolved ExtGState dictionary.
pub fn PdfDocument::content_apply_extgstate_graphics_parameter_op(
  self : PdfDocument,
  state : PdfContentOperatorState,
  extgstate : PdfObject,
) -> PdfContentOperatorState {
  let mut output = state
  match
    self.content_extgstate_number(extgstate, pdf_content_extgstate_lw_name) {
    Some(value) => output = output.content_apply_core_op(Op_w(value))
    None => ()
  }
  match
    self.content_extgstate_integer(extgstate, pdf_content_extgstate_lc_name) {
    Some(value) => output = output.content_apply_core_op(Op_J(value))
    None => ()
  }
  match
    self.content_extgstate_integer(extgstate, pdf_content_extgstate_lj_name) {
    Some(value) => output = output.content_apply_core_op(Op_j(value))
    None => ()
  }
  match
    self.content_extgstate_number(extgstate, pdf_content_extgstate_ml_name) {
    Some(value) => output = output.content_apply_core_op(Op_M(value))
    None => ()
  }
  match
    self.content_extgstate_name_value(extgstate, pdf_content_extgstate_ri_name) {
    Some(value) => output = output.content_apply_core_op(Op_ri(value))
    None => ()
  }
  match
    self.content_extgstate_number(extgstate, pdf_content_extgstate_fl_name) {
    Some(value) => output = output.content_apply_core_op(Op_i(value))
    None => ()
  }
  output
}

///|
/// Compatibility wrapper for `PdfDocument::content_apply_extgstate_graphics_parameter_op`.
pub fn pdf_content_apply_extgstate_graphics_parameter_op(
  document : PdfDocument,
  state : PdfContentOperatorState,
  extgstate : PdfObject,
) -> PdfContentOperatorState {
  document.content_apply_extgstate_graphics_parameter_op(state, extgstate)
}

///|
fn PdfDocument::content_extgstate_dash_array(
  self : PdfDocument,
  object : PdfObject,
) -> Array[Double] raise PdfError {
  match self.direct(object) {
    PdfArray(values) => {
      let output : Array[Double] = []
      for value in values {
        output.push(self.get_number(value))
      }
      output
    }
    _ => []
  }
}

///|
/// Apply cpdfcontent dash parameters from a resolved ExtGState dictionary.
pub fn PdfDocument::content_apply_extgstate_dash_op(
  self : PdfDocument,
  state : PdfContentOperatorState,
  extgstate : PdfObject,
) -> PdfContentOperatorState raise PdfError {
  match self.lookup_direct(pdf_content_extgstate_d_name, extgstate) {
    Some(PdfArray([array, phase])) => {
      let dashes = self.content_extgstate_dash_array(array)
      state.content_apply_core_op(Op_d(dashes, self.get_number(phase)))
    }
    _ => state
  }
}

///|
/// Compatibility wrapper for `PdfDocument::content_apply_extgstate_dash_op`.
pub fn pdf_content_apply_extgstate_dash_op(
  document : PdfDocument,
  state : PdfContentOperatorState,
  extgstate : PdfObject,
) -> PdfContentOperatorState raise PdfError {
  document.content_apply_extgstate_dash_op(state, extgstate)
}

///|
/// Apply cpdfcontent font state from a resolved ExtGState dictionary.
pub fn PdfDocument::content_apply_extgstate_font_op(
  self : PdfDocument,
  state : PdfContentOperatorState,
  extgstate : PdfObject,
) -> PdfContentOperatorState raise PdfError {
  match self.lookup_direct(pdf_content_extgstate_font_name, extgstate) {
    Some(PdfArray([PdfIndirect(font_number), size])) => {
      ignore(self.read_font(PdfIndirect(font_number)))
      let size_result : Result[Double, Error] = try? self.get_number(size)
      let text_state = match size_result {
        Ok(value) => { ..state.text_state, font_size: value }
        Err(_) => state.text_state
      }
      {
        ..state,
        text_state: {
          ..text_state,
          font: "__EXTGSTATE__" + font_number.to_string(),
        },
      }
    }
    _ => state
  }
}

///|
/// Compatibility wrapper for `PdfDocument::content_apply_extgstate_font_op`.
pub fn pdf_content_apply_extgstate_font_op(
  document : PdfDocument,
  state : PdfContentOperatorState,
  extgstate : PdfObject,
) -> PdfContentOperatorState raise PdfError {
  document.content_apply_extgstate_font_op(state, extgstate)
}

///|
/// Apply cpdfcontent's source-shaped `gs` ExtGState resource dictionary.
pub fn PdfDocument::content_apply_extgstate_resource_op(
  self : PdfDocument,
  state : PdfContentOperatorState,
  resources : PdfObject,
  _name : PdfName,
) -> PdfContentOperatorState raise PdfError {
  let extgstate = match
    self.lookup_direct(pdf_content_extgstate_resource_name, resources) {
    Some(PdfDictionary(_) as dictionary) => dictionary
    _ => pdf_dictionary([])
  }
  let mut output = state
  output = self.content_apply_extgstate_graphics_parameter_op(output, extgstate)
  output = self.content_apply_extgstate_dash_op(output, extgstate)
  output = self.content_apply_extgstate_font_op(output, extgstate)
  output = self.content_apply_extgstate_overprint_op(output, extgstate)
  output = self.content_apply_extgstate_transfer_op(output, extgstate)
  output = self.content_apply_extgstate_halftone_op(output, extgstate)
  output = self.content_apply_extgstate_rendering_op(output, extgstate)
  output = self.content_apply_extgstate_compositing_op(output, extgstate)
  output = self.content_apply_extgstate_alpha_op(output, extgstate)
  output = self.content_apply_extgstate_text_op(output, extgstate)
  output
}

///|
/// Compatibility wrapper for `PdfDocument::content_apply_extgstate_resource_op`.
pub fn pdf_content_apply_extgstate_resource_op(
  document : PdfDocument,
  state : PdfContentOperatorState,
  resources : PdfObject,
  name : PdfName,
) -> PdfContentOperatorState raise PdfError {
  document.content_apply_extgstate_resource_op(state, resources, name)
}

///|
/// Apply cpdfcontent smoothness and stroke-adjustment from a resolved ExtGState dictionary.
pub fn PdfDocument::content_apply_extgstate_rendering_op(
  self : PdfDocument,
  state : PdfContentOperatorState,
  extgstate : PdfObject,
) -> PdfContentOperatorState {
  let mut output = state
  match
    self.content_extgstate_number(extgstate, pdf_content_extgstate_sm_name) {
    Some(value) => output = { ..output, smoothness: value }
    None => ()
  }
  match
    self.content_extgstate_boolean(extgstate, pdf_content_extgstate_sa_name) {
    Some(value) => output = { ..output, stroke_adjustment: value }
    None => ()
  }
  output
}

///|
/// Compatibility wrapper for `PdfDocument::content_apply_extgstate_rendering_op`.
pub fn pdf_content_apply_extgstate_rendering_op(
  document : PdfDocument,
  state : PdfContentOperatorState,
  extgstate : PdfObject,
) -> PdfContentOperatorState {
  document.content_apply_extgstate_rendering_op(state, extgstate)
}

///|
/// Apply cpdfcontent overprint parameters from a resolved ExtGState dictionary.
pub fn PdfDocument::content_apply_extgstate_overprint_op(
  self : PdfDocument,
  state : PdfContentOperatorState,
  extgstate : PdfObject,
) -> PdfContentOperatorState {
  let mut output = state
  let non_stroke_overprint = self.content_extgstate_boolean(
    extgstate, pdf_content_extgstate_op_non_stroke_name,
  )
  match
    self.content_extgstate_boolean(
      extgstate, pdf_content_extgstate_op_stroke_name,
    ) {
    Some(value) => {
      output = { ..output, overprint_stroke: value }
      match non_stroke_overprint {
        Some(_) => ()
        None => output = { ..output, overprint_non_stroke: value }
      }
    }
    None => ()
  }
  match non_stroke_overprint {
    Some(value) => output = { ..output, overprint_non_stroke: value }
    None => ()
  }
  match
    self.content_extgstate_integer(
      extgstate, pdf_content_extgstate_op_non_stroke_name,
    ) {
    Some(value) => output = { ..output, overprint_mode: value }
    None => ()
  }
  output
}

///|
/// Compatibility wrapper for `PdfDocument::content_apply_extgstate_overprint_op`.
pub fn pdf_content_apply_extgstate_overprint_op(
  document : PdfDocument,
  state : PdfContentOperatorState,
  extgstate : PdfObject,
) -> PdfContentOperatorState {
  document.content_apply_extgstate_overprint_op(state, extgstate)
}

///|
/// Apply cpdfcontent transfer-function objects from a resolved ExtGState dictionary.
pub fn PdfDocument::content_apply_extgstate_transfer_op(
  self : PdfDocument,
  state : PdfContentOperatorState,
  extgstate : PdfObject,
) -> PdfContentOperatorState {
  let mut output = state
  match self.lookup_direct(pdf_content_extgstate_bg_name, extgstate) {
    Some(value) => output = { ..output, black_generation: value }
    None => ()
  }
  match self.lookup_direct(pdf_content_extgstate_bg2_name, extgstate) {
    Some(value) => output = { ..output, black_generation: value }
    None => ()
  }
  match self.lookup_direct(pdf_content_extgstate_ucr_name, extgstate) {
    Some(value) => output = { ..output, undercolour_removal: value }
    None => ()
  }
  match self.lookup_direct(pdf_content_extgstate_ucr2_name, extgstate) {
    Some(value) => output = { ..output, undercolour_removal: value }
    None => ()
  }
  match self.lookup_direct(pdf_content_extgstate_tr_name, extgstate) {
    Some(value) => output = { ..output, transfer: value }
    None => ()
  }
  match self.lookup_direct(pdf_content_extgstate_tr2_name, extgstate) {
    Some(value) => output = { ..output, transfer: value }
    None => ()
  }
  output
}

///|
/// Compatibility wrapper for `PdfDocument::content_apply_extgstate_transfer_op`.
pub fn pdf_content_apply_extgstate_transfer_op(
  document : PdfDocument,
  state : PdfContentOperatorState,
  extgstate : PdfObject,
) -> PdfContentOperatorState {
  document.content_apply_extgstate_transfer_op(state, extgstate)
}

///|
/// Apply cpdfcontent halftone objects from a resolved ExtGState dictionary.
pub fn PdfDocument::content_apply_extgstate_halftone_op(
  self : PdfDocument,
  state : PdfContentOperatorState,
  extgstate : PdfObject,
) -> PdfContentOperatorState {
  let mut output = state
  match self.lookup_direct(pdf_content_extgstate_ht_name, extgstate) {
    Some(value) => output = { ..output, halftone: value }
    None => ()
  }
  match self.lookup_direct(pdf_content_extgstate_smask_name, extgstate) {
    Some(value) => output = { ..output, halftone: value }
    None => ()
  }
  match self.lookup_direct(pdf_content_extgstate_hto_name, extgstate) {
    Some(value) => output = { ..output, halftone: value }
    None => ()
  }
  output
}

///|
/// Compatibility wrapper for `PdfDocument::content_apply_extgstate_halftone_op`.
pub fn pdf_content_apply_extgstate_halftone_op(
  document : PdfDocument,
  state : PdfContentOperatorState,
  extgstate : PdfObject,
) -> PdfContentOperatorState {
  document.content_apply_extgstate_halftone_op(state, extgstate)
}

///|
/// Apply cpdfcontent blend and black-point-compensation from a resolved ExtGState dictionary.
pub fn PdfDocument::content_apply_extgstate_compositing_op(
  self : PdfDocument,
  state : PdfContentOperatorState,
  extgstate : PdfObject,
) -> PdfContentOperatorState {
  let mut output = state
  match self.lookup_direct(pdf_content_extgstate_bm_name, extgstate) {
    Some(value) => output = { ..output, blend_mode: value }
    None => ()
  }
  match
    self.content_extgstate_name_value(
      extgstate, pdf_content_extgstate_use_black_pt_comp_name,
    ) {
    Some(value) =>
      output = {
        ..output,
        black_point_compensation: pdf_content_state_name_text(value),
      }
    None => ()
  }
  output
}

///|
/// Compatibility wrapper for `PdfDocument::content_apply_extgstate_compositing_op`.
pub fn pdf_content_apply_extgstate_compositing_op(
  document : PdfDocument,
  state : PdfContentOperatorState,
  extgstate : PdfObject,
) -> PdfContentOperatorState {
  document.content_apply_extgstate_compositing_op(state, extgstate)
}

///|
/// Apply cpdfcontent alpha parameters from a resolved ExtGState dictionary.
pub fn PdfDocument::content_apply_extgstate_alpha_op(
  self : PdfDocument,
  state : PdfContentOperatorState,
  extgstate : PdfObject,
) -> PdfContentOperatorState {
  let mut output = state
  match
    self.content_extgstate_number(
      extgstate, pdf_content_extgstate_ca_stroke_name,
    ) {
    Some(value) => output = { ..output, alpha_constant_stroke: value }
    None => ()
  }
  match
    self.content_extgstate_number(
      extgstate, pdf_content_extgstate_ca_non_stroke_name,
    ) {
    Some(value) => output = { ..output, alpha_constant_non_stroke: value }
    None => ()
  }
  match
    self.content_extgstate_boolean(extgstate, pdf_content_extgstate_ais_name) {
    Some(value) => output = { ..output, alpha_source: value }
    None => ()
  }
  output
}

///|
/// Compatibility wrapper for `PdfDocument::content_apply_extgstate_alpha_op`.
pub fn pdf_content_apply_extgstate_alpha_op(
  document : PdfDocument,
  state : PdfContentOperatorState,
  extgstate : PdfObject,
) -> PdfContentOperatorState {
  document.content_apply_extgstate_alpha_op(state, extgstate)
}

///|
/// Apply cpdfcontent text-state fields from a resolved ExtGState dictionary.
pub fn PdfDocument::content_apply_extgstate_text_op(
  self : PdfDocument,
  state : PdfContentOperatorState,
  extgstate : PdfObject,
) -> PdfContentOperatorState {
  match self.lookup_direct(pdf_content_extgstate_tk_key(), extgstate) {
    Some(PdfBoolean(knockout)) =>
      { ..state, text_state: { ..state.text_state, knockout, } }
    _ => state
  }
}

///|
/// Compatibility wrapper for `PdfDocument::content_apply_extgstate_text_op`.
pub fn pdf_content_apply_extgstate_text_op(
  document : PdfDocument,
  state : PdfContentOperatorState,
  extgstate : PdfObject,
) -> PdfContentOperatorState {
  document.content_apply_extgstate_text_op(state, extgstate)
}

///|
/// Apply cpdfcontent marked-content state operators.
pub fn PdfContentOperatorState::content_apply_marked_content_op(
  self : PdfContentOperatorState,
  op : PdfContentOp,
) -> PdfContentOperatorState {
  match op {
    Op_MP(tag) =>
      {
        ..self,
        marked_content_point: Some(
          pdf_content_operator_marked_content(tag, None),
        ),
      }
    Op_DP(tag, properties) =>
      {
        ..self,
        marked_content_point: Some(
          pdf_content_operator_marked_content(tag, Some(properties)),
        ),
      }
    Op_BMC(tag) =>
      {
        ..self,
        marked_content: pdf_content_operator_prepend_marked_content(
          self.marked_content,
          pdf_content_operator_marked_content(tag, None),
        ),
      }
    Op_BDC(tag, properties) =>
      {
        ..self,
        marked_content: pdf_content_operator_prepend_marked_content(
          self.marked_content,
          pdf_content_operator_marked_content(tag, Some(properties)),
        ),
      }
    Op_EMC =>
      {
        ..self,
        marked_content: pdf_content_operator_pop_marked_content(
          self.marked_content,
        ),
      }
    _ => self
  }
}

///|
/// Compatibility wrapper for `PdfContentOperatorState::content_apply_marked_content_op`.
pub fn pdf_content_apply_marked_content_op(
  state : PdfContentOperatorState,
  op : PdfContentOp,
) -> PdfContentOperatorState {
  state.content_apply_marked_content_op(op)
}

///|
/// Apply cpdfcontent Type 3 glyph metric operators `d0` and `d1`.
pub fn PdfContentOperatorState::content_apply_type3_metrics_op(
  self : PdfContentOperatorState,
  op : PdfContentOp,
) -> PdfContentOperatorState {
  match op {
    Op_d0(width_x, width_y) => { ..self, type3_d0: Some({ width_x, width_y }) }
    Op_d1(width_x, width_y, llx, lly, urx, ury) =>
      { ..self, type3_d1: Some({ width_x, width_y, llx, lly, urx, ury }) }
    _ => self
  }
}

///|
/// Compatibility wrapper for `PdfContentOperatorState::content_apply_type3_metrics_op`.
pub fn pdf_content_apply_type3_metrics_op(
  state : PdfContentOperatorState,
  op : PdfContentOp,
) -> PdfContentOperatorState {
  state.content_apply_type3_metrics_op(op)
}

///|
fn pdf_content_text_string_of_glyph_bytes(bytes : PdfBytes) -> String {
  @ascii.decode_lossy(bytes)
}

///|
fn pdf_content_extracted_text_of_glyph_bytes(
  font : PdfFont,
  bytes : PdfBytes,
) -> String raise PdfError {
  let utf8 = pdf_utf8_of_codepoints(
    font.text_extractor().codepoints_of_text(bytes),
  )
  @utf8.decode(utf8) catch {
    _ => @utf8.decode_lossy(utf8)
  }
}

///|
/// Return the cpdfcontent JSON entry for one placed text glyph.
pub fn PdfContentOperatorState::content_text_glyph_entry(
  self : PdfContentOperatorState,
  font : PdfFont,
  glyph : PdfContentTextGlyphPlacement,
) -> PdfContentJsonEntry raise PdfError {
  let bytes = font.content_bytes_of_charcode(glyph.charcode)
  {
    object: PdfContentGlyphObject(
      glyph.charcode,
      pdf_content_text_string_of_glyph_bytes(bytes),
      pdf_content_extracted_text_of_glyph_bytes(font, bytes),
    ),
    state: PdfContentStateGlyph(
      self.text_state.content_glyph_state(self.clipping_path),
    ),
    bounding_box: glyph.bounding_box,
  }
}

///|
/// Compatibility wrapper for `PdfContentOperatorState::content_text_glyph_entry`.
pub fn pdf_content_text_glyph_entry(
  state : PdfContentOperatorState,
  font : PdfFont,
  glyph : PdfContentTextGlyphPlacement,
) -> PdfContentJsonEntry raise PdfError {
  state.content_text_glyph_entry(font, glyph)
}

///|
/// Apply a text-showing operator and emit cpdfcontent glyph entries.
pub fn PdfContentOperatorState::content_apply_text_show_op(
  self : PdfContentOperatorState,
  font : PdfFont,
  op : PdfContentOp,
) -> PdfContentOperatorTextResult raise PdfError {
  let text_result = self.text_state.content_apply_text_op(font, self.ctm, op)
  let state = { ..self, text_state: text_result.text_state }
  let entries : Array[PdfContentJsonEntry] = []
  for glyph in text_result.glyphs {
    entries.push(state.content_text_glyph_entry(font, glyph))
  }
  { state, entries }
}

///|
/// Compatibility wrapper for `PdfContentOperatorState::content_apply_text_show_op`.
pub fn pdf_content_apply_text_show_op(
  state : PdfContentOperatorState,
  font : PdfFont,
  op : PdfContentOp,
) -> PdfContentOperatorTextResult raise PdfError {
  state.content_apply_text_show_op(font, op)
}

///|
fn PdfContentOperatorState::content_clipping_content_state(
  self : PdfContentOperatorState,
) -> PdfContentState {
  PdfContentStateClipping(
    pdf_content_clipping_state_of_paths(self.clipping_path),
  )
}

///|
fn PdfContentOperatorState::content_path_content_state(
  self : PdfContentOperatorState,
) -> PdfContentState {
  PdfContentStatePath(
    self.path_state.content_with_clipping_path(self.clipping_path),
  )
}

///|
/// Return the cpdfcontent JSON entry for the current drawn path, when nonempty.
pub fn PdfContentOperatorState::content_path_entry(
  self : PdfContentOperatorState,
  stroking : Bool,
) -> PdfContentJsonEntry? {
  match
    self.path.path.content_bounding_box(
      self.ctm,
      self.path_state.line_width,
      stroking,
    ) {
    Some(bounding_box) =>
      Some({
        object: PdfContentPathObject(self.path),
        state: self.content_path_content_state(),
        bounding_box,
      })
    None => None
  }
}

///|
/// Compatibility wrapper for `PdfContentOperatorState::content_path_entry`.
pub fn pdf_content_path_entry(
  state : PdfContentOperatorState,
  stroking : Bool,
) -> PdfContentJsonEntry? {
  state.content_path_entry(stroking)
}

///|
fn pdf_content_rectangle_bounding_box(
  rectangle : PdfRectangle,
) -> PdfContentBoundingBox {
  {
    x0: rectangle.min_x,
    y0: rectangle.min_y,
    x1: rectangle.min_x,
    y1: rectangle.max_y,
    x2: rectangle.max_x,
    y2: rectangle.max_y,
    x3: rectangle.max_x,
    y3: rectangle.min_y,
  }
}

///|
fn PdfContentOperatorState::content_unbounded_shading_bounding_box(
  self : PdfContentOperatorState,
) -> PdfContentBoundingBox? {
  if self.clipping_path.length() == 0 {
    None
  } else {
    self.clipping_path[0].content_bounding_box(
      self.ctm,
      self.path_state.line_width,
      false,
    )
  }
}

///|
/// Return the cpdfcontent JSON entry for a shading, when its bbox is valid.
pub fn PdfContentOperatorState::content_shading_entry(
  self : PdfContentOperatorState,
  name : PdfName,
  shading_bbox : PdfRectangle?,
) -> PdfContentJsonEntry? {
  let bounding_box = match shading_bbox {
    Some(rectangle) => Some(pdf_content_rectangle_bounding_box(rectangle))
    None => self.content_unbounded_shading_bounding_box()
  }
  match bounding_box {
    Some(bounding_box) =>
      Some({
        object: PdfContentShadingObject(pdf_content_state_name_text(name)),
        state: self.content_clipping_content_state(),
        bounding_box,
      })
    None => None
  }
}

///|
/// Compatibility wrapper for `PdfContentOperatorState::content_shading_entry`.
pub fn pdf_content_shading_entry(
  state : PdfContentOperatorState,
  name : PdfName,
  shading_bbox : PdfRectangle?,
) -> PdfContentJsonEntry? {
  state.content_shading_entry(name, shading_bbox)
}

///|
/// Look up a named shading resource and return its cpdfcontent JSON entry.
pub fn PdfDocument::content_shading_entry_from_resources(
  self : PdfDocument,
  state : PdfContentOperatorState,
  resources : PdfObject,
  name : PdfName,
) -> PdfContentJsonEntry? {
  match self.lookup_direct(pdf_content_shading_shading_name, resources) {
    Some(shading_dictionary) =>
      match self.lookup_direct(name, shading_dictionary) {
        Some(shading_object) =>
          try
            self.content_read_shading(
              transform_identity_matrix,
              PdfNull,
              shading_object,
            )
          catch {
            _ => None
          } noraise {
            shading =>
              match shading.shading_bbox {
                Some(bbox_object) =>
                  try self.parse_rectangle(bbox_object) catch {
                    _ => None
                  } noraise {
                    rectangle =>
                      state.content_shading_entry(name, Some(rectangle))
                  }
                None => state.content_shading_entry(name, None)
              }
          }
        None => None
      }
    None => None
  }
}

///|
/// Compatibility wrapper for `PdfDocument::content_shading_entry_from_resources`.
pub fn pdf_content_shading_entry_from_resources(
  document : PdfDocument,
  state : PdfContentOperatorState,
  resources : PdfObject,
  name : PdfName,
) -> PdfContentJsonEntry? {
  document.content_shading_entry_from_resources(state, resources, name)
}

///|
/// Return the CTM-transformed unit-square bounding box used for image objects.
pub fn PdfContentOperatorState::content_unit_square_bounding_box(
  self : PdfContentOperatorState,
) -> PdfContentBoundingBox {
  let p0 = self.ctm.apply(point2(0.0, 0.0))
  let p1 = self.ctm.apply(point2(0.0, 1.0))
  let p2 = self.ctm.apply(point2(1.0, 1.0))
  let p3 = self.ctm.apply(point2(1.0, 0.0))
  {
    x0: p0.x,
    y0: p0.y,
    x1: p1.x,
    y1: p1.y,
    x2: p2.x,
    y2: p2.y,
    x3: p3.x,
    y3: p3.y,
  }
}

///|
/// Return the cpdfcontent JSON entry for an inline image at the current CTM.
pub fn PdfContentOperatorState::content_inline_image_entry(
  self : PdfContentOperatorState,
) -> PdfContentJsonEntry {
  {
    object: PdfContentInlineImageObject,
    state: self.content_clipping_content_state(),
    bounding_box: self.content_unit_square_bounding_box(),
  }
}

///|
/// Return the cpdfcontent JSON entry for an image XObject at the current CTM.
pub fn PdfContentOperatorState::content_image_entry(
  self : PdfContentOperatorState,
  name : PdfName,
) -> PdfContentJsonEntry {
  {
    object: PdfContentImageObject(pdf_content_state_name_text(name)),
    state: self.content_clipping_content_state(),
    bounding_box: self.content_unit_square_bounding_box(),
  }
}

///|
/// Compatibility wrapper for `PdfContentOperatorState::content_inline_image_entry`.
pub fn pdf_content_inline_image_entry(
  state : PdfContentOperatorState,
) -> PdfContentJsonEntry {
  state.content_inline_image_entry()
}

///|
/// Compatibility wrapper for `PdfContentOperatorState::content_image_entry`.
pub fn pdf_content_image_entry(
  state : PdfContentOperatorState,
  name : PdfName,
) -> PdfContentJsonEntry {
  state.content_image_entry(name)
}

///|
fn PdfDocument::content_xobject_from_resources(
  self : PdfDocument,
  resources : PdfObject,
  name : PdfName,
) -> PdfObject raise PdfError {
  match self.lookup_direct(pdf_xobject_xobject(), resources) {
    Some(xobjects) =>
      match self.lookup_direct(name, xobjects) {
        Some(xobject) => xobject
        None => raise SoftError("Unknown xobject")
      }
    None => raise SoftError("xobject not found")
  }
}

///|
/// Look up a named image XObject resource and return its cpdfcontent JSON entry.
pub fn PdfDocument::content_image_entry_from_resources(
  self : PdfDocument,
  state : PdfContentOperatorState,
  resources : PdfObject,
  name : PdfName,
) -> PdfContentJsonEntry? raise PdfError {
  let xobject = self.content_xobject_from_resources(resources, name)
  match self.lookup_direct(pdf_xobject_subtype_key(), xobject) {
    Some(PdfNameObject(subtype)) if subtype == pdf_image_image_name() =>
      Some(state.content_image_entry(name))
    Some(PdfNameObject(subtype)) if subtype == pdf_xobject_form() => None
    _ => raise SoftError("Unknown kind of xobject")
  }
}

///|
/// Compatibility wrapper for `PdfDocument::content_image_entry_from_resources`.
pub fn pdf_content_image_entry_from_resources(
  document : PdfDocument,
  state : PdfContentOperatorState,
  resources : PdfObject,
  name : PdfName,
) -> PdfContentJsonEntry? raise PdfError {
  document.content_image_entry_from_resources(state, resources, name)
}

///|
fn pdf_content_form_xobject_default_bbox() -> PdfRectangle {
  let min_float = 2.2250738585072014e-308
  let max_float = 1.7976931348623157e308
  { min_x: min_float, min_y: min_float, max_x: max_float, max_y: max_float }
}

///|
fn PdfDocument::content_form_xobject_bbox(
  self : PdfDocument,
  xobject : PdfObject,
) -> PdfRectangle {
  match self.lookup_direct(pdf_xobject_bbox_key(), xobject) {
    Some(bbox) =>
      try self.parse_rectangle(bbox) catch {
        _ => pdf_content_form_xobject_default_bbox()
      } noraise {
        rectangle => rectangle
      }
    None => pdf_content_form_xobject_default_bbox()
  }
}

///|
fn PdfDocument::content_form_xobject_setup_state(
  self : PdfDocument,
  state : PdfContentOperatorState,
  xobject : PdfObject,
) -> PdfContentOperatorState raise PdfError {
  let matrix = self.parse_matrix(pdf_xobject_matrix_key(), xobject)
  let bounds = self.content_form_xobject_bbox(xobject)
  state
  .content_apply_core_op(Op_q)
  .content_apply_core_op(Op_cm(matrix))
  .content_apply_core_op(
    Op_re(
      bounds.min_x,
      bounds.min_y,
      bounds.max_x - bounds.min_x,
      bounds.max_y - bounds.min_y,
    ),
  )
  .content_apply_core_op(Op_W)
  .content_apply_core_op(Op_n)
}

///|
/// Look up a named Form XObject resource and return the state used to enter it.
pub fn PdfDocument::content_form_xobject_enter_state(
  self : PdfDocument,
  state : PdfContentOperatorState,
  resources : PdfObject,
  name : PdfName,
) -> PdfContentOperatorState? raise PdfError {
  let xobject = self.content_xobject_from_resources(resources, name)
  match self.lookup_direct(pdf_xobject_subtype_key(), xobject) {
    Some(PdfNameObject(subtype)) if subtype == pdf_xobject_form() =>
      Some(self.content_form_xobject_setup_state(state, xobject))
    Some(PdfNameObject(subtype)) if subtype == pdf_image_image_name() => None
    _ => raise SoftError("Unknown kind of xobject")
  }
}

///|
/// Compatibility wrapper for `PdfDocument::content_form_xobject_enter_state`.
pub fn pdf_content_form_xobject_enter_state(
  document : PdfDocument,
  state : PdfContentOperatorState,
  resources : PdfObject,
  name : PdfName,
) -> PdfContentOperatorState? raise PdfError {
  document.content_form_xobject_enter_state(state, resources, name)
}

///|
fn PdfDocument::content_direct_dictionary_object(
  self : PdfDocument,
  object : PdfObject,
) -> PdfObject {
  match self.direct(object) {
    PdfDictionary(entries) => PdfDictionary([ for entry in entries => entry ])
    _ => PdfDictionary([])
  }
}

///|
fn PdfDocument::content_form_xobject_resource_dictionary(
  self : PdfDocument,
  xobject : PdfObject,
) -> PdfObject {
  match self.direct(xobject) {
    PdfStreamObject(stream) =>
      match self.lookup_direct(pdf_xobject_resources_key(), stream.dictionary) {
        Some(PdfDictionary(entries)) =>
          PdfDictionary([ for entry in entries => entry ])
        _ => PdfDictionary([])
      }
    _ => PdfDictionary([])
  }
}

///|
fn PdfDocument::content_form_xobject_merge_resources(
  self : PdfDocument,
  resources : PdfObject,
  xobject : PdfObject,
) -> PdfObject raise PdfError {
  let mut total = self.content_direct_dictionary_object(resources)
  match self.content_form_xobject_resource_dictionary(xobject) {
    PdfDictionary(entries) =>
      for entry in entries {
        total = total.add_dict_entry(entry.0, entry.1)
      }
    _ => ()
  }
  total
}

///|
/// Look up a named Form XObject resource and return the resources used inside it.
pub fn PdfDocument::content_form_xobject_resources(
  self : PdfDocument,
  resources : PdfObject,
  name : PdfName,
) -> PdfObject? raise PdfError {
  let xobject = self.content_xobject_from_resources(resources, name)
  match self.lookup_direct(pdf_xobject_subtype_key(), xobject) {
    Some(PdfNameObject(subtype)) if subtype == pdf_xobject_form() =>
      Some(self.content_form_xobject_merge_resources(resources, xobject))
    Some(PdfNameObject(subtype)) if subtype == pdf_image_image_name() => None
    _ => raise SoftError("Unknown kind of xobject")
  }
}

///|
/// Compatibility wrapper for `PdfDocument::content_form_xobject_resources`.
pub fn pdf_content_form_xobject_resources(
  document : PdfDocument,
  resources : PdfObject,
  name : PdfName,
) -> PdfObject? raise PdfError {
  document.content_form_xobject_resources(resources, name)
}

///|
/// Look up a named Form XObject resource and parse its content operators.
pub fn PdfDocument::content_form_xobject_ops(
  self : PdfDocument,
  resources : PdfObject,
  name : PdfName,
) -> Array[PdfContentOp]? raise PdfError {
  let xobject = self.content_xobject_from_resources(resources, name)
  match self.lookup_direct(pdf_xobject_subtype_key(), xobject) {
    Some(PdfNameObject(subtype)) if subtype == pdf_xobject_form() => {
      let total_resources = self.content_form_xobject_merge_resources(
        resources, xobject,
      )
      Some(self.parse_content_ops_with_resources(total_resources, [xobject]))
    }
    Some(PdfNameObject(subtype)) if subtype == pdf_image_image_name() => None
    _ => raise SoftError("Unknown kind of xobject")
  }
}

///|
/// Compatibility wrapper for `PdfDocument::content_form_xobject_ops`.
pub fn pdf_content_form_xobject_ops(
  document : PdfDocument,
  resources : PdfObject,
  name : PdfName,
) -> Array[PdfContentOp]? raise PdfError {
  document.content_form_xobject_ops(resources, name)
}

///|
fn PdfContentOperatorState::content_with_clipping_path(
  self : PdfContentOperatorState,
  clipping_path : ArrayView[PdfPath],
) -> PdfContentOperatorState {
  let paths = pdf_content_state_copy_paths(clipping_path)
  {
    ..self,
    clipping_path: paths,
    path_state: self.path_state.content_with_clipping_path(paths),
  }
}

///|
fn PdfContentOperatorState::content_apply_path_machine_op(
  self : PdfContentOperatorState,
  op : PdfContentOp,
) -> PdfContentOperatorState {
  let result = self.partial_path.content_apply_path_op(op)
  match result.drawn_path {
    Some(path) => { ..self, partial_path: result.partial_path, path }
    None => { ..self, partial_path: result.partial_path }
  }
}

///|
fn PdfContentOperatorState::content_apply_clipping_state_op(
  self : PdfContentOperatorState,
  op : PdfContentOp,
) -> PdfContentOperatorState {
  let result = self.partial_path.content_apply_clipping_op(
    self.clipping_path,
    op,
  )
  { ..self, partial_path: result.partial_path }.content_with_clipping_path(
    result.clipping_path,
  )
}

///|
/// Apply cpdfcontent operators whose state effects do not require resources.
///
/// This covers graphics-state stack operators, CTM concatenation, path
/// construction/painting, clipping, path drawing state, direct graphics
/// parameters, text state, marked-content state, and Type 3 glyph metrics. Font
/// lookup, glyph emission, shadings, images, XObjects, and graphics-state
/// dictionaries remain separate resource-backed slices.
pub fn PdfContentOperatorState::content_apply_core_op(
  self : PdfContentOperatorState,
  op : PdfContentOp,
) -> PdfContentOperatorState {
  match op {
    Op_q | Op_Q | Op_cm(_) => self.content_apply_graphics_state_op(op)
    Op_W | Op_Wstar => self.content_apply_clipping_state_op(op)
    _ => {
      let state = self
        .content_apply_path_machine_op(op)
        .content_apply_graphics_parameter_op(op)
        .content_apply_marked_content_op(op)
        .content_apply_type3_metrics_op(op)
      {
        ..state,
        path_state: state.path_state.content_apply_path_state_op(op),
        text_state: state.text_state.content_apply_text_state_op(op),
      }
    }
  }
}

///|
/// Compatibility wrapper for `PdfContentOperatorState::content_apply_core_op`.
pub fn pdf_content_apply_core_op(
  state : PdfContentOperatorState,
  op : PdfContentOp,
) -> PdfContentOperatorState {
  state.content_apply_core_op(op)
}
