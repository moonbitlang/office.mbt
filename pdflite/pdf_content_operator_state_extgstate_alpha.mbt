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
