///|
/// Apply cpdfcontent Type 3 glyph metric operators `d0` and `d1`.
pub fn PdfContentOperatorState::content_apply_type3_metrics_op(
  self : PdfContentOperatorState,
  op : @content.PdfContentOp,
) -> PdfContentOperatorState {
  match op {
    Op_d0(width_x, width_y) => { ..self, type3_d0: Some({ width_x, width_y }) }
    Op_d1(width_x, width_y, llx, lly, urx, ury) =>
      { ..self, type3_d1: Some({ width_x, width_y, llx, lly, urx, ury }) }
    _ => self
  }
}

///|
/// Compatibility wrapper for `PdfContentOperatorState::content_apply_type3_metrics_op`.
pub fn pdf_content_apply_type3_metrics_op(
  state : PdfContentOperatorState,
  op : @content.PdfContentOp,
) -> PdfContentOperatorState {
  state.content_apply_type3_metrics_op(op)
}

///|
fn pdf_content_text_string_of_glyph_bytes(bytes : @core.PdfBytes) -> String {
  @ascii.decode_lossy(bytes)
}

///|
fn pdf_content_extracted_text_of_glyph_bytes(
  font : PdfFont,
  bytes : @core.PdfBytes,
) -> String raise @core.PdfError {
  let utf8 = pdf_utf8_of_codepoints(
    font.text_extractor().codepoints_of_text(bytes),
  )
  @utf8.decode(utf8) catch {
    _ => @utf8.decode_lossy(utf8)
  }
}

///|
/// Return the cpdfcontent JSON entry for one placed text glyph.
pub fn PdfContentOperatorState::content_text_glyph_entry(
  self : PdfContentOperatorState,
  font : PdfFont,
  glyph : PdfContentTextGlyphPlacement,
) -> PdfContentJsonEntry raise @core.PdfError {
  let bytes = font.content_bytes_of_charcode(glyph.charcode)
  {
    object: PdfContentGlyphObject(
      glyph.charcode,
      pdf_content_text_string_of_glyph_bytes(bytes),
      pdf_content_extracted_text_of_glyph_bytes(font, bytes),
    ),
    state: PdfContentStateGlyph(
      self.text_state.content_glyph_state(self.clipping_path),
    ),
    bounding_box: glyph.bounding_box,
  }
}

///|
/// Compatibility wrapper for `PdfContentOperatorState::content_text_glyph_entry`.
pub fn pdf_content_text_glyph_entry(
  state : PdfContentOperatorState,
  font : PdfFont,
  glyph : PdfContentTextGlyphPlacement,
) -> PdfContentJsonEntry raise @core.PdfError {
  state.content_text_glyph_entry(font, glyph)
}

///|
/// Apply a text-showing operator and emit cpdfcontent glyph entries.
pub fn PdfContentOperatorState::content_apply_text_show_op(
  self : PdfContentOperatorState,
  font : PdfFont,
  op : @content.PdfContentOp,
) -> PdfContentOperatorTextResult raise @core.PdfError {
  let text_result = self.text_state.content_apply_text_op(font, self.ctm, op)
  let state = { ..self, text_state: text_result.text_state }
  let entries : Array[PdfContentJsonEntry] = Array::new(
    capacity=text_result.glyphs.length(),
  )
  for glyph in text_result.glyphs {
    entries.push(state.content_text_glyph_entry(font, glyph))
  }
  { state, entries }
}

///|
/// Compatibility wrapper for `PdfContentOperatorState::content_apply_text_show_op`.
pub fn pdf_content_apply_text_show_op(
  state : PdfContentOperatorState,
  font : PdfFont,
  op : @content.PdfContentOp,
) -> PdfContentOperatorTextResult raise @core.PdfError {
  state.content_apply_text_show_op(font, op)
}

///|
/// Apply cpdfcontent text operators that depend on page resources or font data.
pub fn PdfDocument::content_apply_text_resource_op(
  self : PdfDocument,
  state : PdfContentOperatorState,
  resources : @syntax.PdfObject,
  op : @content.PdfContentOp,
) -> PdfContentOperatorTextResult raise @core.PdfError {
  match op {
    Op_Tf(font_name, font_size) =>
      {
        state: self.content_apply_font_resource_op(
          state, resources, font_name, font_size,
        ),
        entries: [],
      }
    Op_Tj(_) | Op_TJ(_) | Op_quote(_) | Op_double_quote(_, _, _) =>
      state.content_apply_text_show_op(state.text_state.current_font, op)
    _ =>
      {
        state: {
          ..state,
          text_state: state.text_state.content_apply_text_state_op(op),
        },
        entries: [],
      }
  }
}

///|
/// Compatibility wrapper for `PdfDocument::content_apply_text_resource_op`.
pub fn pdf_content_apply_text_resource_op(
  document : PdfDocument,
  state : PdfContentOperatorState,
  resources : @syntax.PdfObject,
  op : @content.PdfContentOp,
) -> PdfContentOperatorTextResult raise @core.PdfError {
  document.content_apply_text_resource_op(state, resources, op)
}
