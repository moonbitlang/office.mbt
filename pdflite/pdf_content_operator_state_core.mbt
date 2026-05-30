///|
fn PdfContentOperatorState::content_with_clipping_path(
  self : PdfContentOperatorState,
  clipping_path : ArrayView[@shape.PdfPath],
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

///|
fn pdf_content_path_paint_stroking(op : PdfContentOp) -> Bool? {
  match op {
    Op_S | Op_s | Op_B | Op_Bstar | Op_b | Op_bstar => Some(true)
    Op_f | Op_F | Op_fstar => Some(false)
    _ => None
  }
}

///|
fn pdf_content_entries_of_optional(
  entry : PdfContentJsonEntry?,
) -> Array[PdfContentJsonEntry] {
  match entry {
    Some(entry) => [entry]
    None => []
  }
}

///|
/// Apply one cpdfcontent operator with resource-backed entry emission.
pub fn PdfDocument::content_apply_resource_op(
  self : PdfDocument,
  state : PdfContentOperatorState,
  resources : PdfObject,
  op : PdfContentOp,
) -> PdfContentOperatorResourceResult raise PdfError {
  match op {
    Op_BT
    | Op_ET
    | Op_Tc(_)
    | Op_Tw(_)
    | Op_Tz(_)
    | Op_TL(_)
    | Op_Tf(_, _)
    | Op_Tr(_)
    | Op_Ts(_)
    | Op_Td(_, _)
    | Op_TD(_, _)
    | Op_Tm(_)
    | Op_Tstar
    | Op_Tj(_)
    | Op_TJ(_)
    | Op_quote(_)
    | Op_double_quote(_, _, _) => {
      let result = self.content_apply_text_resource_op(state, resources, op)
      { state: result.state, entries: result.entries }
    }
    Op_gs(name) =>
      {
        state: self.content_apply_extgstate_resource_op(state, resources, name),
        entries: [],
      }
    Op_sh(name) =>
      {
        state,
        entries: pdf_content_entries_of_optional(
          self.content_shading_entry_from_resources(state, resources, name),
        ),
      }
    Op_InlineImage(_, _, _) =>
      { state, entries: [state.content_inline_image_entry()] }
    Op_Do(name) =>
      {
        state,
        entries: pdf_content_entries_of_optional(
          self.content_image_entry_from_resources(state, resources, name),
        ),
      }
    _ => {
      let next = state.content_apply_core_op(op)
      let entries = match pdf_content_path_paint_stroking(op) {
        Some(stroking) =>
          pdf_content_entries_of_optional(next.content_path_entry(stroking))
        None => []
      }
      { state: next, entries }
    }
  }
}

///|
/// Compatibility wrapper for `PdfDocument::content_apply_resource_op`.
pub fn pdf_content_apply_resource_op(
  document : PdfDocument,
  state : PdfContentOperatorState,
  resources : PdfObject,
  op : PdfContentOp,
) -> PdfContentOperatorResourceResult raise PdfError {
  document.content_apply_resource_op(state, resources, op)
}
