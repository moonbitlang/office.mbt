///|
/// Collect cpdfcontent JSON entries for one non-recursive content-operator list.
pub fn PdfDocument::content_entries_of_ops(
  self : PdfDocument,
  mediabox : PdfRectangle,
  resources : PdfObject,
  ops : ArrayView[PdfContentOp],
) -> Array[PdfContentJsonEntry] raise PdfError {
  let mut state = pdf_content_initial_operator_state(
    mediabox.min_x,
    mediabox.min_y,
    mediabox.max_x,
    mediabox.max_y,
  )
  let entries : Array[PdfContentJsonEntry] = Array::new(capacity=ops.length())
  for op in ops {
    let result = self.content_apply_resource_op(state, resources, op)
    entries.append(result.entries)
    state = result.state
  }
  entries
}

///|
/// Compatibility wrapper for `PdfDocument::content_entries_of_ops`.
pub fn pdf_content_entries_of_ops(
  document : PdfDocument,
  mediabox : PdfRectangle,
  resources : PdfObject,
  ops : ArrayView[PdfContentOp],
) -> Array[PdfContentJsonEntry] raise PdfError {
  document.content_entries_of_ops(mediabox, resources, ops)
}

///|
fn PdfContentOperatorState::content_without_font_cache(
  self : PdfContentOperatorState,
) -> PdfContentOperatorState {
  { ..self, text_state: { ..self.text_state, font_cache: [] } }
}

///|
fn PdfDocument::content_entries_of_xobject_recursive(
  self : PdfDocument,
  state : PdfContentOperatorState,
  resources : PdfObject,
  name : PdfName,
) -> Array[PdfContentJsonEntry] raise PdfError {
  let xobject = self.content_xobject_from_resources(resources, name)
  match self.lookup_direct(pdf_xobject_subtype_key(), xobject) {
    Some(PdfNameObject(subtype)) if subtype == pdf_image_image_name() =>
      [state.content_image_entry(name)]
    Some(PdfNameObject(subtype)) if subtype == pdf_xobject_form() => {
      let form_state = self.content_form_xobject_setup_state(state, xobject)
      let form_resources = self.content_form_xobject_merge_resources(
        resources, xobject,
      )
      let form_ops = self.parse_content_ops_with_resources(form_resources, [
        xobject,
      ])
      self.content_entries_of_ops_recursive_from_state(
        form_state.content_without_font_cache(),
        form_resources,
        form_ops,
      ).entries
    }
    _ => raise SoftError("Unknown kind of xobject")
  }
}

///|
fn PdfDocument::content_entries_of_ops_recursive_from_state(
  self : PdfDocument,
  initial : PdfContentOperatorState,
  resources : PdfObject,
  ops : ArrayView[PdfContentOp],
) -> PdfContentOperatorResourceResult raise PdfError {
  let mut state = initial
  let entries : Array[PdfContentJsonEntry] = Array::new(capacity=ops.length())
  for op in ops {
    match op {
      Op_Do(name) =>
        entries.append(
          self.content_entries_of_xobject_recursive(state, resources, name),
        )
      _ => {
        let result = self.content_apply_resource_op(state, resources, op)
        entries.append(result.entries)
        state = result.state
      }
    }
  }
  { state, entries }
}

///|
/// Collect cpdfcontent JSON entries for content operators, recursively walking Forms.
pub fn PdfDocument::content_entries_of_ops_recursive(
  self : PdfDocument,
  mediabox : PdfRectangle,
  resources : PdfObject,
  ops : ArrayView[PdfContentOp],
) -> Array[PdfContentJsonEntry] raise PdfError {
  let state = pdf_content_initial_operator_state(
    mediabox.min_x,
    mediabox.min_y,
    mediabox.max_x,
    mediabox.max_y,
  )
  self.content_entries_of_ops_recursive_from_state(state, resources, ops).entries
}

///|
/// Compatibility wrapper for `PdfDocument::content_entries_of_ops_recursive`.
pub fn pdf_content_entries_of_ops_recursive(
  document : PdfDocument,
  mediabox : PdfRectangle,
  resources : PdfObject,
  ops : ArrayView[PdfContentOp],
) -> Array[PdfContentJsonEntry] raise PdfError {
  document.content_entries_of_ops_recursive(mediabox, resources, ops)
}
