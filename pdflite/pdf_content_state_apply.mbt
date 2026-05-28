///|
/// Apply the cpdfcontent path-state operators that do not require resources.
pub fn PdfContentPathState::content_apply_path_state_op(
  self : PdfContentPathState,
  op : PdfContentOp,
) -> PdfContentPathState {
  match op {
    Op_w(width) => { ..self, line_width: width }
    Op_J(cap) => { ..self, line_cap: cap }
    Op_j(join) => { ..self, line_join: join }
    Op_d(dashes, phase) =>
      {
        ..self,
        dash_pattern: { array: pdf_content_state_copy_doubles(dashes), phase },
      }
    Op_ri(intent) =>
      { ..self, rendering_intent: pdf_content_state_name_text(intent) }
    Op_CS(name) =>
      match pdf_colour_space_of_device_name(name) {
        Some(space) =>
          {
            ..self,
            colourspace_stroke: space,
            colour_stroke: pdf_content_initial_colour_values(space),
          }
        None => self
      }
    Op_cs(name) =>
      match pdf_colour_space_of_device_name(name) {
        Some(space) =>
          {
            ..self,
            colourspace_non_stroke: space,
            colour_non_stroke: pdf_content_initial_colour_values(space),
          }
        None => self
      }
    Op_SC(values) | Op_SCN(values) =>
      {
        ..self,
        colour_stroke: PdfContentColourFloats(
          pdf_content_state_copy_doubles(values),
        ),
      }
    Op_sc(values) | Op_scn(values) =>
      {
        ..self,
        colour_non_stroke: PdfContentColourFloats(
          pdf_content_state_copy_doubles(values),
        ),
      }
    Op_SCNName(name, values) =>
      {
        ..self,
        colour_non_stroke: PdfContentColourNamed(
          pdf_content_state_name_text(name),
          pdf_content_state_copy_doubles(values),
        ),
      }
    Op_scnName(name, values) =>
      {
        ..self,
        colour_stroke: PdfContentColourNamed(
          pdf_content_state_name_text(name),
          pdf_content_state_copy_doubles(values),
        ),
      }
    Op_G(value) =>
      {
        ..self,
        colourspace_stroke: PdfDeviceGray,
        colour_stroke: PdfContentColourFloats([value]),
      }
    Op_g(value) =>
      {
        ..self,
        colourspace_non_stroke: PdfDeviceGray,
        colour_non_stroke: PdfContentColourFloats([value]),
      }
    Op_RG(red, green, blue) =>
      {
        ..self,
        colourspace_stroke: PdfDeviceRGB,
        colour_stroke: PdfContentColourFloats([red, green, blue]),
      }
    Op_rg(red, green, blue) =>
      {
        ..self,
        colourspace_non_stroke: PdfDeviceRGB,
        colour_non_stroke: PdfContentColourFloats([red, green, blue]),
      }
    Op_K(cyan, magenta, yellow, black) =>
      {
        ..self,
        colourspace_stroke: PdfDeviceCMYK,
        colour_stroke: PdfContentColourFloats([cyan, magenta, yellow, black]),
      }
    Op_k(cyan, magenta, yellow, black) =>
      {
        ..self,
        colourspace_non_stroke: PdfDeviceCMYK,
        colour_non_stroke: PdfContentColourFloats([cyan, magenta, yellow, black]),
      }
    _ => self
  }
}

///|
/// Compatibility wrapper for `PdfContentPathState::content_apply_path_state_op`.
pub fn pdf_content_apply_path_state_op(
  state : PdfContentPathState,
  op : PdfContentOp,
) -> PdfContentPathState {
  state.content_apply_path_state_op(op)
}
