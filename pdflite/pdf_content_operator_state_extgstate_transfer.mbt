///|
/// Apply cpdfcontent transfer-function objects from a resolved ExtGState dictionary.
pub fn PdfDocument::content_apply_extgstate_transfer_op(
  self : PdfDocument,
  state : PdfContentOperatorState,
  extgstate : PdfObject,
) -> PdfContentOperatorState {
  let mut output = state
  match self.lookup_direct(pdf_content_extgstate_bg_name, extgstate) {
    Some(value) => output = { ..output, black_generation: value }
    None => ()
  }
  match self.lookup_direct(pdf_content_extgstate_bg2_name, extgstate) {
    Some(value) => output = { ..output, black_generation: value }
    None => ()
  }
  match self.lookup_direct(pdf_content_extgstate_ucr_name, extgstate) {
    Some(value) => output = { ..output, undercolour_removal: value }
    None => ()
  }
  match self.lookup_direct(pdf_content_extgstate_ucr2_name, extgstate) {
    Some(value) => output = { ..output, undercolour_removal: value }
    None => ()
  }
  match self.lookup_direct(pdf_content_extgstate_tr_name, extgstate) {
    Some(value) => output = { ..output, transfer: value }
    None => ()
  }
  match self.lookup_direct(pdf_content_extgstate_tr2_name, extgstate) {
    Some(value) => output = { ..output, transfer: value }
    None => ()
  }
  output
}

///|
/// Compatibility wrapper for `PdfDocument::content_apply_extgstate_transfer_op`.
pub fn pdf_content_apply_extgstate_transfer_op(
  document : PdfDocument,
  state : PdfContentOperatorState,
  extgstate : PdfObject,
) -> PdfContentOperatorState {
  document.content_apply_extgstate_transfer_op(state, extgstate)
}
