///|
/// Apply cpdfcontent text-state fields from a resolved ExtGState dictionary.
pub fn PdfDocument::content_apply_extgstate_text_op(
  self : PdfDocument,
  state : PdfContentOperatorState,
  extgstate : @syntax.PdfObject,
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
  extgstate : @syntax.PdfObject,
) -> PdfContentOperatorState {
  document.content_apply_extgstate_text_op(state, extgstate)
}
