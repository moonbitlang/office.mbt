///|
fn pdf_content_form_xobject_default_bbox() -> @geometry.PdfRectangle {
  let min_float = 2.2250738585072014e-308
  let max_float = 1.7976931348623157e308
  { min_x: min_float, min_y: min_float, max_x: max_float, max_y: max_float }
}

///|
fn PdfDocument::content_form_xobject_bbox(
  self : PdfDocument,
  xobject : @syntax.PdfObject,
) -> @geometry.PdfRectangle {
  match self.lookup_direct(pdf_xobject_bbox_key(), xobject) {
    Some(bbox) =>
      try self.parse_rectangle(bbox) catch {
        _ => pdf_content_form_xobject_default_bbox()
      } noraise {
        rectangle => rectangle
      }
    None => pdf_content_form_xobject_default_bbox()
  }
}

///|
fn PdfDocument::content_form_xobject_setup_state(
  self : PdfDocument,
  state : PdfContentOperatorState,
  xobject : @syntax.PdfObject,
) -> PdfContentOperatorState raise PdfError {
  let matrix = self.parse_matrix(pdf_xobject_matrix_key(), xobject)
  let bounds = self.content_form_xobject_bbox(xobject)
  state
  .content_apply_core_op(Op_q)
  .content_apply_core_op(Op_cm(matrix))
  .content_apply_core_op(
    Op_re(
      bounds.min_x,
      bounds.min_y,
      bounds.max_x - bounds.min_x,
      bounds.max_y - bounds.min_y,
    ),
  )
  .content_apply_core_op(Op_W)
  .content_apply_core_op(Op_n)
}

///|
/// Look up a named Form XObject resource and return the state used to enter it.
pub fn PdfDocument::content_form_xobject_enter_state(
  self : PdfDocument,
  state : PdfContentOperatorState,
  resources : @syntax.PdfObject,
  name : PdfName,
) -> PdfContentOperatorState? raise PdfError {
  let xobject = self.content_xobject_from_resources(resources, name)
  match self.lookup_direct(pdf_xobject_subtype_key(), xobject) {
    Some(PdfNameObject(subtype)) if subtype == pdf_xobject_form() =>
      Some(self.content_form_xobject_setup_state(state, xobject))
    Some(PdfNameObject(subtype)) if subtype == pdf_image_image_name() => None
    _ => raise SoftError("Unknown kind of xobject")
  }
}

///|
/// Compatibility wrapper for `PdfDocument::content_form_xobject_enter_state`.
pub fn pdf_content_form_xobject_enter_state(
  document : PdfDocument,
  state : PdfContentOperatorState,
  resources : @syntax.PdfObject,
  name : PdfName,
) -> PdfContentOperatorState? raise PdfError {
  document.content_form_xobject_enter_state(state, resources, name)
}

///|
fn PdfDocument::content_direct_dictionary_object(
  self : PdfDocument,
  object : @syntax.PdfObject,
) -> @syntax.PdfObject {
  match self.direct(object) {
    PdfDictionary(entries) => PdfDictionary([ for entry in entries => entry ])
    _ => PdfDictionary([])
  }
}

///|
fn PdfDocument::content_form_xobject_resource_dictionary(
  self : PdfDocument,
  xobject : @syntax.PdfObject,
) -> @syntax.PdfObject {
  match self.direct(xobject) {
    PdfStreamObject(stream) =>
      match self.lookup_direct(pdf_xobject_resources_key(), stream.dictionary) {
        Some(PdfDictionary(entries)) =>
          PdfDictionary([ for entry in entries => entry ])
        _ => PdfDictionary([])
      }
    _ => PdfDictionary([])
  }
}

///|
fn PdfDocument::content_form_xobject_merge_resources(
  self : PdfDocument,
  resources : @syntax.PdfObject,
  xobject : @syntax.PdfObject,
) -> @syntax.PdfObject raise PdfError {
  let mut total = self.content_direct_dictionary_object(resources)
  match self.content_form_xobject_resource_dictionary(xobject) {
    PdfDictionary(entries) =>
      for entry in entries {
        total = total.add_dict_entry(entry.0, entry.1)
      }
    _ => ()
  }
  total
}

///|
/// Look up a named Form XObject resource and return the resources used inside it.
pub fn PdfDocument::content_form_xobject_resources(
  self : PdfDocument,
  resources : @syntax.PdfObject,
  name : PdfName,
) -> @syntax.PdfObject? raise PdfError {
  let xobject = self.content_xobject_from_resources(resources, name)
  match self.lookup_direct(pdf_xobject_subtype_key(), xobject) {
    Some(PdfNameObject(subtype)) if subtype == pdf_xobject_form() =>
      Some(self.content_form_xobject_merge_resources(resources, xobject))
    Some(PdfNameObject(subtype)) if subtype == pdf_image_image_name() => None
    _ => raise SoftError("Unknown kind of xobject")
  }
}

///|
/// Compatibility wrapper for `PdfDocument::content_form_xobject_resources`.
pub fn pdf_content_form_xobject_resources(
  document : PdfDocument,
  resources : @syntax.PdfObject,
  name : PdfName,
) -> @syntax.PdfObject? raise PdfError {
  document.content_form_xobject_resources(resources, name)
}

///|
/// Look up a named Form XObject resource and parse its content operators.
pub fn PdfDocument::content_form_xobject_ops(
  self : PdfDocument,
  resources : @syntax.PdfObject,
  name : PdfName,
) -> Array[@content.PdfContentOp]? raise PdfError {
  let xobject = self.content_xobject_from_resources(resources, name)
  match self.lookup_direct(pdf_xobject_subtype_key(), xobject) {
    Some(PdfNameObject(subtype)) if subtype == pdf_xobject_form() => {
      let total_resources = self.content_form_xobject_merge_resources(
        resources, xobject,
      )
      Some(self.parse_content_ops_with_resources(total_resources, [xobject]))
    }
    Some(PdfNameObject(subtype)) if subtype == pdf_image_image_name() => None
    _ => raise SoftError("Unknown kind of xobject")
  }
}

///|
/// Compatibility wrapper for `PdfDocument::content_form_xobject_ops`.
pub fn pdf_content_form_xobject_ops(
  document : PdfDocument,
  resources : @syntax.PdfObject,
  name : PdfName,
) -> Array[@content.PdfContentOp]? raise PdfError {
  document.content_form_xobject_ops(resources, name)
}
