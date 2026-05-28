///|
fn PdfDrawRenderState::extgstate(
  self : PdfDrawRenderState,
  kind : PdfName,
  value : Double,
) -> PdfName {
  for entry in self.extgstates {
    if entry.kind == kind && entry.value == value {
      return entry.name
    }
  }
  let name = self.fresh_name("/G")
  self.extgstates.push({ kind, value, name })
  name
}

///|
fn PdfDrawRenderState::mark_page_resource(
  self : PdfDrawRenderState,
  resource_name : PdfName,
) -> Unit {
  for name in self.page_names {
    if name == resource_name {
      return
    }
  }
  self.page_names.push(resource_name)
}

///|
fn PdfDrawRenderState::image_resource_name(
  self : PdfDrawRenderState,
  source_name : String,
) -> PdfName raise PdfError {
  for entry in self.xobjects {
    if entry.source_name == source_name {
      self.mark_page_resource(entry.resource_name)
      return entry.resource_name
    }
  }
  raise SoftError("Image not found: " + source_name)
}

///|
fn PdfDrawRenderState::form_resource_name(
  self : PdfDrawRenderState,
  source_name : String,
) -> PdfName raise PdfError {
  for entry in self.form_xobjects {
    if entry.source_name == source_name {
      self.mark_page_resource(entry.resource_name)
      return entry.resource_name
    }
  }
  raise SoftError("Form XObject not found: " + source_name)
}

///|
fn PdfDrawRenderState::font_resource_name(
  self : PdfDrawRenderState,
  identifier : String,
  font_index : Int,
) -> PdfName raise PdfError {
  match self.stored_font_resource(identifier, font_index) {
    Some(resource) => {
      self.mark_page_resource(resource.resource_name)
      resource.resource_name
    }
    None => raise SoftError("Font resource not found: " + identifier)
  }
}

///|
fn pdf_draw_resource_is_used(
  page_names : ArrayView[PdfName],
  name : PdfName,
) -> Bool {
  for page_name in page_names {
    if page_name == name {
      return true
    }
  }
  false
}

///|
/// Return the resource dictionary needed by the operations rendered so far.
pub fn PdfDrawRenderState::resources(self : PdfDrawRenderState) -> PdfObject {
  let states : Array[(PdfName, PdfObject)] = Array::new(
    capacity=self.extgstates.length(),
  )
  for entry in self.extgstates {
    states.push(
      (entry.name, PdfDictionary([(entry.kind, PdfReal(entry.value))])),
    )
  }
  let xobjects : Array[(PdfName, PdfObject)] = Array::new(
    capacity=self.xobjects.length() + self.form_xobjects.length(),
  )
  for entry in self.xobjects {
    if pdf_draw_resource_is_used(self.page_names, entry.resource_name) {
      xobjects.push((entry.resource_name, PdfIndirect(entry.object_number)))
    }
  }
  for entry in self.form_xobjects {
    if pdf_draw_resource_is_used(self.page_names, entry.resource_name) {
      xobjects.push((entry.resource_name, PdfIndirect(entry.object_number)))
    }
  }
  let fonts : Array[(PdfName, PdfObject)] = Array::new(
    capacity=self.fonts.length(),
  )
  for entry in self.fonts {
    if pdf_draw_resource_is_used(self.page_names, entry.resource_name) {
      fonts.push((entry.resource_name, PdfIndirect(entry.object_number)))
    }
  }
  let resources : Array[(PdfName, PdfObject)] = Array::new(capacity=3)
  if xobjects.length() > 0 {
    resources.push((pdf_draw_xobject_key(), PdfDictionary(xobjects)))
  }
  if states.length() > 0 {
    resources.push((pdf_draw_extgstate_key(), PdfDictionary(states)))
  }
  if fonts.length() > 0 {
    resources.push((pdf_draw_font_key(), PdfDictionary(fonts)))
  }
  PdfDictionary(resources)
}
