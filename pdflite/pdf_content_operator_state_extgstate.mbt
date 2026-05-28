///|
fn pdf_content_extgstate_number(object : PdfObject) -> Double? {
  match object {
    PdfReal(value) => Some(value)
    PdfInteger(value) => Some(value.to_double())
    _ => None
  }
}

///|
fn pdf_content_extgstate_integer(object : PdfObject) -> Int? {
  match object {
    PdfInteger(value) => Some(value)
    _ => None
  }
}

///|
fn PdfDocument::content_extgstate_number(
  self : PdfDocument,
  extgstate : PdfObject,
  key : PdfName,
) -> Double? {
  match self.lookup_direct(key, extgstate) {
    Some(value) => pdf_content_extgstate_number(value)
    None => None
  }
}

///|
fn PdfDocument::content_extgstate_integer(
  self : PdfDocument,
  extgstate : PdfObject,
  key : PdfName,
) -> Int? {
  match self.lookup_direct(key, extgstate) {
    Some(value) => pdf_content_extgstate_integer(value)
    None => None
  }
}

///|
fn PdfDocument::content_extgstate_name_value(
  self : PdfDocument,
  extgstate : PdfObject,
  key : PdfName,
) -> PdfName? {
  match self.lookup_direct(key, extgstate) {
    Some(PdfNameObject(value)) => Some(value)
    _ => None
  }
}

///|
fn PdfDocument::content_extgstate_boolean(
  self : PdfDocument,
  extgstate : PdfObject,
  key : PdfName,
) -> Bool? {
  match self.lookup_direct(key, extgstate) {
    Some(PdfBoolean(value)) => Some(value)
    _ => None
  }
}

///|
/// Apply cpdfcontent scalar graphics parameters from a resolved ExtGState dictionary.
pub fn PdfDocument::content_apply_extgstate_graphics_parameter_op(
  self : PdfDocument,
  state : PdfContentOperatorState,
  extgstate : PdfObject,
) -> PdfContentOperatorState {
  let mut output = state
  match
    self.content_extgstate_number(extgstate, pdf_content_extgstate_lw_name) {
    Some(value) => output = output.content_apply_core_op(Op_w(value))
    None => ()
  }
  match
    self.content_extgstate_integer(extgstate, pdf_content_extgstate_lc_name) {
    Some(value) => output = output.content_apply_core_op(Op_J(value))
    None => ()
  }
  match
    self.content_extgstate_integer(extgstate, pdf_content_extgstate_lj_name) {
    Some(value) => output = output.content_apply_core_op(Op_j(value))
    None => ()
  }
  match
    self.content_extgstate_number(extgstate, pdf_content_extgstate_ml_name) {
    Some(value) => output = output.content_apply_core_op(Op_M(value))
    None => ()
  }
  match
    self.content_extgstate_name_value(extgstate, pdf_content_extgstate_ri_name) {
    Some(value) => output = output.content_apply_core_op(Op_ri(value))
    None => ()
  }
  match
    self.content_extgstate_number(extgstate, pdf_content_extgstate_fl_name) {
    Some(value) => output = output.content_apply_core_op(Op_i(value))
    None => ()
  }
  output
}

///|
/// Compatibility wrapper for `PdfDocument::content_apply_extgstate_graphics_parameter_op`.
pub fn pdf_content_apply_extgstate_graphics_parameter_op(
  document : PdfDocument,
  state : PdfContentOperatorState,
  extgstate : PdfObject,
) -> PdfContentOperatorState {
  document.content_apply_extgstate_graphics_parameter_op(state, extgstate)
}

///|
fn PdfDocument::content_extgstate_dash_array(
  self : PdfDocument,
  object : PdfObject,
) -> Array[Double] raise PdfError {
  match self.direct(object) {
    PdfArray(values) => {
      let output : Array[Double] = Array::new(capacity=values.length())
      for value in values {
        output.push(self.get_number(value))
      }
      output
    }
    _ => []
  }
}

///|
/// Apply cpdfcontent dash parameters from a resolved ExtGState dictionary.
pub fn PdfDocument::content_apply_extgstate_dash_op(
  self : PdfDocument,
  state : PdfContentOperatorState,
  extgstate : PdfObject,
) -> PdfContentOperatorState raise PdfError {
  match self.lookup_direct(pdf_content_extgstate_d_name, extgstate) {
    Some(PdfArray([array, phase])) => {
      let dashes = self.content_extgstate_dash_array(array)
      state.content_apply_core_op(Op_d(dashes, self.get_number(phase)))
    }
    _ => state
  }
}

///|
/// Compatibility wrapper for `PdfDocument::content_apply_extgstate_dash_op`.
pub fn pdf_content_apply_extgstate_dash_op(
  document : PdfDocument,
  state : PdfContentOperatorState,
  extgstate : PdfObject,
) -> PdfContentOperatorState raise PdfError {
  document.content_apply_extgstate_dash_op(state, extgstate)
}

///|
/// Apply cpdfcontent font state from a resolved ExtGState dictionary.
pub fn PdfDocument::content_apply_extgstate_font_op(
  self : PdfDocument,
  state : PdfContentOperatorState,
  extgstate : PdfObject,
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
  extgstate : PdfObject,
) -> PdfContentOperatorState raise PdfError {
  document.content_apply_extgstate_font_op(state, extgstate)
}

///|
fn PdfDocument::content_font_resource(
  self : PdfDocument,
  resources : PdfObject,
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
  resources : PdfObject,
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
  resources : PdfObject,
  font_name : PdfName,
  font_size : Double,
) -> PdfContentOperatorState raise PdfError {
  document.content_apply_font_resource_op(
    state, resources, font_name, font_size,
  )
}

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

///|
/// Apply cpdfcontent smoothness and stroke-adjustment from a resolved ExtGState dictionary.
pub fn PdfDocument::content_apply_extgstate_rendering_op(
  self : PdfDocument,
  state : PdfContentOperatorState,
  extgstate : PdfObject,
) -> PdfContentOperatorState {
  let mut output = state
  match
    self.content_extgstate_number(extgstate, pdf_content_extgstate_sm_name) {
    Some(value) => output = { ..output, smoothness: value }
    None => ()
  }
  match
    self.content_extgstate_boolean(extgstate, pdf_content_extgstate_sa_name) {
    Some(value) => output = { ..output, stroke_adjustment: value }
    None => ()
  }
  output
}

///|
/// Compatibility wrapper for `PdfDocument::content_apply_extgstate_rendering_op`.
pub fn pdf_content_apply_extgstate_rendering_op(
  document : PdfDocument,
  state : PdfContentOperatorState,
  extgstate : PdfObject,
) -> PdfContentOperatorState {
  document.content_apply_extgstate_rendering_op(state, extgstate)
}

///|
/// Apply cpdfcontent overprint parameters from a resolved ExtGState dictionary.
pub fn PdfDocument::content_apply_extgstate_overprint_op(
  self : PdfDocument,
  state : PdfContentOperatorState,
  extgstate : PdfObject,
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
  extgstate : PdfObject,
) -> PdfContentOperatorState {
  document.content_apply_extgstate_overprint_op(state, extgstate)
}

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

///|
/// Apply cpdfcontent blend and black-point-compensation from a resolved ExtGState dictionary.
pub fn PdfDocument::content_apply_extgstate_compositing_op(
  self : PdfDocument,
  state : PdfContentOperatorState,
  extgstate : PdfObject,
) -> PdfContentOperatorState {
  let mut output = state
  match self.lookup_direct(pdf_content_extgstate_bm_name, extgstate) {
    Some(value) => output = { ..output, blend_mode: value }
    None => ()
  }
  match
    self.content_extgstate_name_value(
      extgstate, pdf_content_extgstate_use_black_pt_comp_name,
    ) {
    Some(value) =>
      output = {
        ..output,
        black_point_compensation: pdf_content_state_name_text(value),
      }
    None => ()
  }
  output
}

///|
/// Compatibility wrapper for `PdfDocument::content_apply_extgstate_compositing_op`.
pub fn pdf_content_apply_extgstate_compositing_op(
  document : PdfDocument,
  state : PdfContentOperatorState,
  extgstate : PdfObject,
) -> PdfContentOperatorState {
  document.content_apply_extgstate_compositing_op(state, extgstate)
}

///|
/// Apply cpdfcontent alpha parameters from a resolved ExtGState dictionary.
pub fn PdfDocument::content_apply_extgstate_alpha_op(
  self : PdfDocument,
  state : PdfContentOperatorState,
  extgstate : PdfObject,
) -> PdfContentOperatorState {
  let mut output = state
  match
    self.content_extgstate_number(
      extgstate, pdf_content_extgstate_ca_stroke_name,
    ) {
    Some(value) => output = { ..output, alpha_constant_stroke: value }
    None => ()
  }
  match
    self.content_extgstate_number(
      extgstate, pdf_content_extgstate_ca_non_stroke_name,
    ) {
    Some(value) => output = { ..output, alpha_constant_non_stroke: value }
    None => ()
  }
  match
    self.content_extgstate_boolean(extgstate, pdf_content_extgstate_ais_name) {
    Some(value) => output = { ..output, alpha_source: value }
    None => ()
  }
  output
}

///|
/// Compatibility wrapper for `PdfDocument::content_apply_extgstate_alpha_op`.
pub fn pdf_content_apply_extgstate_alpha_op(
  document : PdfDocument,
  state : PdfContentOperatorState,
  extgstate : PdfObject,
) -> PdfContentOperatorState {
  document.content_apply_extgstate_alpha_op(state, extgstate)
}

///|
/// Apply cpdfcontent text-state fields from a resolved ExtGState dictionary.
pub fn PdfDocument::content_apply_extgstate_text_op(
  self : PdfDocument,
  state : PdfContentOperatorState,
  extgstate : PdfObject,
) -> PdfContentOperatorState {
  match self.lookup_direct(pdf_content_extgstate_tk_key(), extgstate) {
    Some(PdfBoolean(knockout)) =>
      { ..state, text_state: { ..state.text_state, knockout, } }
    _ => state
  }
}

///|
/// Compatibility wrapper for `PdfDocument::content_apply_extgstate_text_op`.
pub fn pdf_content_apply_extgstate_text_op(
  document : PdfDocument,
  state : PdfContentOperatorState,
  extgstate : PdfObject,
) -> PdfContentOperatorState {
  document.content_apply_extgstate_text_op(state, extgstate)
}
