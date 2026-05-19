///|
pub(all) struct PdfContentOperatorFrame {
  ctm : TransformMatrix
  partial_path : PdfContentPartialPath
  clipping_path : Array[PdfPath]
  path : PdfDrawnPath
  path_state : PdfContentPathState
  text_state : PdfContentTextState
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
  marked_content_point : PdfContentMarkedContent?
  marked_content : Array[PdfContentMarkedContent]
  type3_d0 : PdfContentType3D0?
  type3_d1 : PdfContentType3D1?
  state_stack : Array[PdfContentOperatorFrame]
} derive(Debug, Eq, ToJson)

///|
pub(all) struct PdfContentMarkedContent {
  tag : String
  properties : PdfObject?
} derive(Debug, Eq, ToJson)

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
/// construction/painting, clipping, path drawing state, text state,
/// marked-content state, and Type 3 glyph metrics. Font lookup, glyph emission,
/// shadings, images, XObjects, and graphics-state dictionaries remain separate
/// resource-backed slices.
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
