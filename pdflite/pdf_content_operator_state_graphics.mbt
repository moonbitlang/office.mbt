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
  properties : @syntax.PdfObject?,
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
  op : @content.PdfContentOp,
) -> PdfContentOperatorState {
  match op {
    Op_q => self.content_push_state()
    Op_Q => self.content_pop_state()
    Op_cm(matrix) =>
      { ..self, ctm: @geometry.transform_matrix_compose(self.ctm, matrix) }
    _ => self
  }
}

///|
/// Compatibility wrapper for `PdfContentOperatorState::content_apply_graphics_state_op`.
pub fn pdf_content_apply_graphics_state_op(
  state : PdfContentOperatorState,
  op : @content.PdfContentOp,
) -> PdfContentOperatorState {
  state.content_apply_graphics_state_op(op)
}

///|
/// Apply cpdfcontent direct graphics-parameter operators.
pub fn PdfContentOperatorState::content_apply_graphics_parameter_op(
  self : PdfContentOperatorState,
  op : @content.PdfContentOp,
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
  op : @content.PdfContentOp,
) -> PdfContentOperatorState {
  state.content_apply_graphics_parameter_op(op)
}

///|
/// Apply cpdfcontent marked-content state operators.
pub fn PdfContentOperatorState::content_apply_marked_content_op(
  self : PdfContentOperatorState,
  op : @content.PdfContentOp,
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
  op : @content.PdfContentOp,
) -> PdfContentOperatorState {
  state.content_apply_marked_content_op(op)
}
