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
