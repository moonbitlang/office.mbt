///|
fn pdf_content_state_copy_paths(
  paths : ArrayView[@shape.PdfPath],
) -> Array[@shape.PdfPath] {
  [
    for path in paths => path
  ]
}

///|
/// Return a clipping-only content state from the current clipping path stack.
pub fn pdf_content_clipping_state_of_paths(
  clipping_path : ArrayView[@shape.PdfPath],
) -> PdfContentClippingState {
  { clipping_path: pdf_content_state_copy_paths(clipping_path) }
}

///|
/// Return this path state with a replaced clipping path stack.
pub fn PdfContentPathState::content_with_clipping_path(
  self : PdfContentPathState,
  clipping_path : ArrayView[@shape.PdfPath],
) -> PdfContentPathState {
  { ..self, clipping_path: pdf_content_state_copy_paths(clipping_path) }
}

///|
/// Compatibility wrapper for `PdfContentPathState::content_with_clipping_path`.
pub fn pdf_content_path_state_with_clipping_path(
  state : PdfContentPathState,
  clipping_path : ArrayView[@shape.PdfPath],
) -> PdfContentPathState {
  state.content_with_clipping_path(clipping_path)
}

///|
/// Return the JSON-facing glyph state for a text state and clipping path.
pub fn PdfContentTextState::content_glyph_state(
  self : PdfContentTextState,
  clipping_path : ArrayView[@shape.PdfPath],
) -> PdfContentGlyphState {
  {
    rendering_mode: self.rendering_mode,
    knockout: self.knockout,
    font: self.font,
    font_size: self.font_size,
    clipping_path: pdf_content_state_copy_paths(clipping_path),
  }
}

///|
/// Compatibility wrapper for `PdfContentTextState::content_glyph_state`.
pub fn pdf_content_glyph_state_of_text_state(
  state : PdfContentTextState,
  clipping_path : ArrayView[@shape.PdfPath],
) -> PdfContentGlyphState {
  state.content_glyph_state(clipping_path)
}

///|
fn pdf_content_state_copy_doubles(values : ArrayView[Double]) -> Array[Double] {
  [
    for value in values => value
  ]
}

///|
fn pdf_content_state_name_text(name : PdfName) -> String {
  @ascii.decode_lossy(name.bytes())
}
