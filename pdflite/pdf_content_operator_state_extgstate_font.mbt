///|
/// Apply cpdfcontent font state from a resolved ExtGState dictionary.
pub fn PdfDocument::content_apply_extgstate_font_op(
  self : PdfDocument,
  state : PdfContentOperatorState,
  extgstate : @syntax.PdfObject,
) -> PdfContentOperatorState raise PdfError {
  match self.lookup_direct(pdf_content_extgstate_font_name, extgstate) {
    Some(PdfArray([PdfIndirect(font_number), size])) => {
      let font = self.read_font(PdfIndirect(font_number))
      let size_result : Result[Double, Error] = try? self.get_number(size)
      let text_state = match size_result {
        Ok(value) => { ..state.text_state, font_size: value }
        Err(_) => state.text_state
      }
      {
        ..state,
        text_state: {
          ..text_state,
          font: "__EXTGSTATE__" + font_number.to_string(),
          current_font: font,
        },
      }
    }
    _ => state
  }
}

///|
/// Compatibility wrapper for `PdfDocument::content_apply_extgstate_font_op`.
pub fn pdf_content_apply_extgstate_font_op(
  document : PdfDocument,
  state : PdfContentOperatorState,
  extgstate : @syntax.PdfObject,
) -> PdfContentOperatorState raise PdfError {
  document.content_apply_extgstate_font_op(state, extgstate)
}

///|
fn PdfDocument::content_font_resource(
  self : PdfDocument,
  resources : @syntax.PdfObject,
  name : PdfName,
) -> PdfFont? raise PdfError {
  match self.lookup_direct(pdf_page_font_resource_name, resources) {
    Some(font_dictionary) =>
      match self.lookup_direct(name, font_dictionary) {
        Some(font) => Some(self.read_font(font))
        None => None
      }
    None => None
  }
}

///|
/// Apply cpdfcontent's resource-backed `Tf` font lookup and cache update.
pub fn PdfDocument::content_apply_font_resource_op(
  self : PdfDocument,
  state : PdfContentOperatorState,
  resources : @syntax.PdfObject,
  font_name : PdfName,
  font_size : Double,
) -> PdfContentOperatorState raise PdfError {
  let name_text = pdf_content_state_name_text(font_name)
  let text_state = state.text_state.content_apply_text_state_op(
    Op_Tf(font_name, font_size),
  )
  match text_state.content_cached_font(name_text) {
    Some(font) => { ..state, text_state: { ..text_state, current_font: font } }
    None =>
      match self.content_font_resource(resources, font_name) {
        Some(font) =>
          {
            ..state,
            text_state: text_state.content_cache_font(name_text, font),
          }
        None => { ..state, text_state, }
      }
  }
}

///|
/// Compatibility wrapper for `PdfDocument::content_apply_font_resource_op`.
pub fn pdf_content_apply_font_resource_op(
  document : PdfDocument,
  state : PdfContentOperatorState,
  resources : @syntax.PdfObject,
  font_name : PdfName,
  font_size : Double,
) -> PdfContentOperatorState raise PdfError {
  document.content_apply_font_resource_op(
    state, resources, font_name, font_size,
  )
}
