///|
fn PdfDrawRenderState::extgstate(
  self : PdfDrawRenderState,
  kind : @core.PdfName,
  value : Double,
) -> @core.PdfName {
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
  resource_name : @core.PdfName,
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
) -> @core.PdfName raise @core.PdfError {
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
) -> @core.PdfName raise @core.PdfError {
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
) -> @core.PdfName raise @core.PdfError {
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
  page_names : ArrayView[@core.PdfName],
  name : @core.PdfName,
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
pub fn PdfDrawRenderState::resources(
  self : PdfDrawRenderState,
) -> @syntax.PdfObject {
  let states : Array[(@core.PdfName, @syntax.PdfObject)] = Array::new(
    capacity=self.extgstates.length(),
  )
  for entry in self.extgstates {
    states.push(
      (entry.name, PdfDictionary([(entry.kind, PdfReal(entry.value))])),
    )
  }
  let xobjects : Array[(@core.PdfName, @syntax.PdfObject)] = Array::new(
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
  let fonts : Array[(@core.PdfName, @syntax.PdfObject)] = Array::new(
    capacity=self.fonts.length(),
  )
  for entry in self.fonts {
    if pdf_draw_resource_is_used(self.page_names, entry.resource_name) {
      fonts.push((entry.resource_name, PdfIndirect(entry.object_number)))
    }
  }
  let resources : Array[(@core.PdfName, @syntax.PdfObject)] = Array::new(
    capacity=3,
  )
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
