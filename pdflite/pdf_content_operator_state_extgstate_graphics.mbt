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
