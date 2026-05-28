///|
/// Apply cpdfcontent's source-shaped `gs` ExtGState resource dictionary.
pub fn PdfDocument::content_apply_extgstate_resource_op(
  self : PdfDocument,
  state : PdfContentOperatorState,
  resources : PdfObject,
  _name : PdfName,
) -> PdfContentOperatorState raise PdfError {
  let extgstate = match
    self.lookup_direct(pdf_content_extgstate_resource_name, resources) {
    Some(PdfDictionary(_) as dictionary) => dictionary
    _ => pdf_dictionary([])
  }
  let mut output = state
  output = self.content_apply_extgstate_graphics_parameter_op(output, extgstate)
  output = self.content_apply_extgstate_dash_op(output, extgstate)
  output = self.content_apply_extgstate_font_op(output, extgstate)
  output = self.content_apply_extgstate_overprint_op(output, extgstate)
  output = self.content_apply_extgstate_transfer_op(output, extgstate)
  output = self.content_apply_extgstate_halftone_op(output, extgstate)
  output = self.content_apply_extgstate_rendering_op(output, extgstate)
  output = self.content_apply_extgstate_compositing_op(output, extgstate)
  output = self.content_apply_extgstate_alpha_op(output, extgstate)
  output = self.content_apply_extgstate_text_op(output, extgstate)
  output
}

///|
/// Compatibility wrapper for `PdfDocument::content_apply_extgstate_resource_op`.
pub fn pdf_content_apply_extgstate_resource_op(
  document : PdfDocument,
  state : PdfContentOperatorState,
  resources : PdfObject,
  name : PdfName,
) -> PdfContentOperatorState raise PdfError {
  document.content_apply_extgstate_resource_op(state, resources, name)
}
