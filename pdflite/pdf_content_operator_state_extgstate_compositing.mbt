///|
/// Apply cpdfcontent blend and black-point-compensation from a resolved ExtGState dictionary.
pub fn PdfDocument::content_apply_extgstate_compositing_op(
  self : PdfDocument,
  state : PdfContentOperatorState,
  extgstate : @syntax.PdfObject,
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
  extgstate : @syntax.PdfObject,
) -> PdfContentOperatorState {
  document.content_apply_extgstate_compositing_op(state, extgstate)
}
