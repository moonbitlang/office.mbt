///|
/// Apply cpdfcontent smoothness and stroke-adjustment from a resolved ExtGState dictionary.
pub fn PdfDocument::content_apply_extgstate_rendering_op(
  self : PdfDocument,
  state : PdfContentOperatorState,
  extgstate : @syntax.PdfObject,
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
  extgstate : @syntax.PdfObject,
) -> PdfContentOperatorState {
  document.content_apply_extgstate_rendering_op(state, extgstate)
}
