///|
/// Apply the `gs` operator: the ExtGState dictionary `name` in the
/// resources' `/ExtGState`. (cpdfcontent applies the whole `/ExtGState`
/// resource dictionary instead, so its `gs` never takes effect.)
pub fn PdfDocument::content_apply_extgstate_resource_op(
  self : PdfDocument,
  state : PdfContentOperatorState,
  resources : @syntax.PdfObject,
  name : @core.PdfName,
) -> PdfContentOperatorState raise @core.PdfError {
  let extgstate = match
    self
    .lookup_direct(pdf_content_extgstate_resource_name, resources)
    .bind(dictionary => self.lookup_direct(name, dictionary)) {
    Some(PdfDictionary(_) as dictionary) => dictionary
    _ => @syntax.pdf_dictionary([])
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
  resources : @syntax.PdfObject,
  name : @core.PdfName,
) -> PdfContentOperatorState raise @core.PdfError {
  document.content_apply_extgstate_resource_op(state, resources, name)
}
