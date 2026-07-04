///|
/// Apply cpdfcontent overprint parameters from a resolved ExtGState dictionary.
pub fn PdfDocument::content_apply_extgstate_overprint_op(
  self : PdfDocument,
  state : PdfContentOperatorState,
  extgstate : @syntax.PdfObject,
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
  extgstate : @syntax.PdfObject,
) -> PdfContentOperatorState {
  document.content_apply_extgstate_overprint_op(state, extgstate)
}
