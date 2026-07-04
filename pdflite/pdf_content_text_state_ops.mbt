///|
fn pdf_content_text_state_name_text(name : @core.PdfName) -> String {
  @ascii.decode_lossy(name.bytes())
}

///|
fn PdfContentTextState::content_text_move(
  self : PdfContentTextState,
  tx : Double,
  ty : Double,
) -> PdfContentTextState {
  let line_matrix = @geometry.transform_matrix_compose(
    self.line_matrix,
    @geometry.transform_translate(tx, ty),
  )
  { ..self, text_matrix: line_matrix, line_matrix }
}

///|
/// Convert text state to the layout input used by cpdfcontent glyph placement.
pub fn PdfContentTextState::content_text_layout(
  self : PdfContentTextState,
  ctm : @geometry.TransformMatrix,
) -> PdfContentTextLayout {
  {
    font_size: self.font_size,
    horizontal_scaling: self.horizontal_scaling,
    character_spacing: self.character_spacing,
    word_spacing: self.word_spacing,
    rise: self.rise,
    ctm,
    text_matrix: self.text_matrix,
  }
}

///|
/// Apply cpdfcontent text-state operators that do not require font resources.
pub fn PdfContentTextState::content_apply_text_state_op(
  self : PdfContentTextState,
  op : @content.PdfContentOp,
) -> PdfContentTextState {
  match op {
    Op_BT =>
      {
        ..self,
        text_matrix: @geometry.transform_identity_matrix,
        line_matrix: @geometry.transform_identity_matrix,
      }
    Op_ET => self
    Op_Tc(spacing) => { ..self, character_spacing: spacing }
    Op_Tw(spacing) => { ..self, word_spacing: spacing }
    Op_Tz(scale) => { ..self, horizontal_scaling: scale / 100.0 }
    Op_TL(leading) => { ..self, leading, }
    Op_Tf(font, size) =>
      { ..self, font: pdf_content_text_state_name_text(font), font_size: size }
    Op_Tr(mode) => { ..self, rendering_mode: mode }
    Op_Ts(rise) => { ..self, rise, }
    Op_Td(tx, ty) => self.content_text_move(tx, ty)
    Op_TD(tx, ty) =>
      self
      .content_apply_text_state_op(Op_TL(-ty))
      .content_apply_text_state_op(Op_Td(tx, ty))
    Op_Tm(matrix) => { ..self, text_matrix: matrix, line_matrix: matrix }
    Op_Tstar => self.content_apply_text_state_op(Op_TD(0.0, -self.leading))
    Op_quote(_) => self.content_apply_text_state_op(Op_Tstar)
    Op_double_quote(word_spacing, character_spacing, _) =>
      self
      .content_apply_text_state_op(Op_Tw(word_spacing))
      .content_apply_text_state_op(Op_Tc(character_spacing))
      .content_apply_text_state_op(Op_Tstar)
    _ => self
  }
}

///|
/// Compatibility wrapper for `PdfContentTextState::content_apply_text_state_op`.
pub fn pdf_content_apply_text_state_op(
  state : PdfContentTextState,
  op : @content.PdfContentOp,
) -> PdfContentTextState {
  state.content_apply_text_state_op(op)
}

///|
fn pdf_content_empty_text_op_result(
  state : PdfContentTextState,
) -> PdfContentTextOpResult {
  { text_state: state, glyphs: [] }
}

///|
fn pdf_content_text_op_with_layout_result(
  state : PdfContentTextState,
  result : PdfContentTextLayoutResult,
) -> PdfContentTextOpResult {
  {
    text_state: { ..state, text_matrix: result.text_matrix },
    glyphs: result.glyphs,
  }
}

///|
/// Apply cpdfcontent text-state and text-showing operators with a known font.
pub fn PdfContentTextState::content_apply_text_op(
  self : PdfContentTextState,
  font : PdfFont,
  ctm : @geometry.TransformMatrix,
  op : @content.PdfContentOp,
) -> PdfContentTextOpResult {
  match op {
    Op_Tj(text) =>
      pdf_content_text_op_with_layout_result(
        self,
        font.content_text_layout_of_bytes(text, self.content_text_layout(ctm)),
      )
    Op_TJ(elements) =>
      pdf_content_text_op_with_layout_result(
        self,
        font.content_text_layout_of_tj_array(
          match elements {
            PdfArray(values) => values
            _ => []
          },
          self.content_text_layout(ctm),
        ),
      )
    Op_quote(text) =>
      self
      .content_apply_text_state_op(Op_Tstar)
      .content_apply_text_op(font, ctm, Op_Tj(text))
    Op_double_quote(word_spacing, character_spacing, text) =>
      self
      .content_apply_text_state_op(Op_Tw(word_spacing))
      .content_apply_text_state_op(Op_Tc(character_spacing))
      .content_apply_text_op(font, ctm, Op_quote(text))
    _ => pdf_content_empty_text_op_result(self.content_apply_text_state_op(op))
  }
}

///|
/// Compatibility wrapper for `PdfContentTextState::content_apply_text_op`.
pub fn pdf_content_apply_text_op(
  state : PdfContentTextState,
  font : PdfFont,
  ctm : @geometry.TransformMatrix,
  op : @content.PdfContentOp,
) -> PdfContentTextOpResult {
  state.content_apply_text_op(font, ctm, op)
}
