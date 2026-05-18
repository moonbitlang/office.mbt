///|
pub(all) struct PdfContentOperatorFrame {
  ctm : TransformMatrix
  partial_path : PdfContentPartialPath
  clipping_path : Array[PdfPath]
  path : PdfDrawnPath
  path_state : PdfContentPathState
  text_state : PdfContentTextState
} derive(Debug, Eq, ToJson)

///|
pub(all) struct PdfContentOperatorState {
  ctm : TransformMatrix
  partial_path : PdfContentPartialPath
  clipping_path : Array[PdfPath]
  path : PdfDrawnPath
  path_state : PdfContentPathState
  text_state : PdfContentTextState
  state_stack : Array[PdfContentOperatorFrame]
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
/// construction/painting, clipping, path drawing state, and text state. Font
/// lookup, glyph emission, shadings, images, XObjects, marked-content metadata,
/// and graphics-state dictionaries remain separate resource-backed slices.
pub fn PdfContentOperatorState::content_apply_core_op(
  self : PdfContentOperatorState,
  op : PdfContentOp,
) -> PdfContentOperatorState {
  match op {
    Op_q | Op_Q | Op_cm(_) => self.content_apply_graphics_state_op(op)
    Op_W | Op_Wstar => self.content_apply_clipping_state_op(op)
    _ => {
      let state = self.content_apply_path_machine_op(op)
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
