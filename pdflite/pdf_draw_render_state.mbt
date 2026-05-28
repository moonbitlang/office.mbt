///|
fn PdfDrawRenderState::fresh_name(
  self : PdfDrawRenderState,
  prefix : String,
) -> PdfName {
  self.resource_number += 1
  pdf_draw_name(prefix + self.resource_number.to_string())
}

///|
fn PdfDrawRenderState::fresh_mcid(self : PdfDrawRenderState) -> Int {
  self.marked_content_id += 1
  self.marked_content_id
}

///|
fn PdfDrawRenderState::set_minimum_resource_number(
  self : PdfDrawRenderState,
  minimum : Int,
) -> Unit {
  if self.resource_number < minimum {
    self.resource_number = minimum
  }
}

///|
fn PdfDrawRenderState::reset_for_page_chunk(self : PdfDrawRenderState) -> Unit {
  self.extgstates.clear()
  self.marked_content_id = -1
}

///|
fn PdfDrawRenderState::set_structure_tree_enabled(
  self : PdfDrawRenderState,
  enabled : Bool,
) -> Unit {
  self.structure_tree_enabled = enabled
}

///|
fn PdfDrawRenderState::set_structure_page_number(
  self : PdfDrawRenderState,
  page_number : Int,
) -> Unit {
  self.structure_page_number = page_number
}

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
fn PdfDrawRenderState::register_xobject(
  self : PdfDrawRenderState,
  source_name : String,
  prefix : String,
  object_number : Int,
) -> PdfName {
  let resource_name = self.fresh_name(prefix)
  for index in 0..<self.xobjects.length() {
    if self.xobjects[index].source_name == source_name {
      self.xobjects[index] = { source_name, resource_name, object_number }
      return resource_name
    }
  }
  self.xobjects.push({ source_name, resource_name, object_number })
  resource_name
}

///|
fn PdfDrawRenderState::register_form_xobject(
  self : PdfDrawRenderState,
  source_name : String,
  object_number : Int,
) -> PdfName {
  let resource_name = self.fresh_name("/X")
  for index in 0..<self.form_xobjects.length() {
    if self.form_xobjects[index].source_name == source_name {
      self.form_xobjects[index] = { source_name, resource_name, object_number }
      return resource_name
    }
  }
  self.form_xobjects.push({ source_name, resource_name, object_number })
  resource_name
}

///|
fn PdfDrawRenderState::stored_fontpack(
  self : PdfDrawRenderState,
  identifier : String,
) -> PdfFontPack? {
  for entry in self.fontpacks {
    if entry.identifier == identifier {
      return Some(entry.fontpack)
    }
  }
  None
}

///|
fn PdfDrawRenderState::ensure_fontpack(
  self : PdfDrawRenderState,
  identifier : String,
  fontpack : PdfFontPack,
) -> PdfFontPack {
  match self.stored_fontpack(identifier) {
    Some(stored) => stored
    None => {
      self.fontpacks.push({ identifier, fontpack })
      fontpack
    }
  }
}

///|
fn PdfDrawRenderState::stored_font_resource(
  self : PdfDrawRenderState,
  identifier : String,
  font_index : Int,
) -> PdfDrawFontResource? {
  for resource in self.fonts {
    if resource.identifier == identifier && resource.font_index == font_index {
      return Some(resource)
    }
  }
  None
}

///|
fn PdfDrawRenderState::register_font_resource(
  self : PdfDrawRenderState,
  identifier : String,
  font_index : Int,
  object_number : Int,
) -> PdfName {
  let resource_name = self.fresh_name("/F")
  self.fonts.push({ identifier, font_index, resource_name, object_number })
  resource_name
}

///|
fn PdfDrawRenderState::register_fontpack_resources(
  self : PdfDrawRenderState,
  identifier : String,
  fontpack : PdfFontPack,
  document : PdfDocument,
) -> Unit raise PdfError {
  let stored = self.ensure_fontpack(identifier, fontpack)
  for index in 0..<stored.fonts.length() {
    let resource = match self.stored_font_resource(identifier, index) {
      Some(resource) => resource
      None => {
        let object_number = document.write_font(stored.fonts[index])
        let resource_name = self.register_font_resource(
          identifier, index, object_number,
        )
        { identifier, font_index: index, resource_name, object_number }
      }
    }
    self.mark_page_resource(resource.resource_name)
  }
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
fn PdfDrawRenderState::set_current_font(
  self : PdfDrawRenderState,
  identifier : String,
  size : Double,
) -> Unit raise PdfError {
  match self.stored_fontpack(identifier) {
    Some(fontpack) => {
      self.current_fontpack_identifier = identifier
      self.current_fontpack = fontpack
      self.font_size = size
    }
    None => raise SoftError("FontPack not found: " + identifier)
  }
}

///|
fn pdf_draw_copy_xobject_resources(
  resources : ArrayView[PdfDrawXObjectResource],
) -> Array[PdfDrawXObjectResource] {
  let output : Array[PdfDrawXObjectResource] = Array::new(
    capacity=resources.length(),
  )
  for entry in resources {
    output.push(entry)
  }
  output
}

///|
fn pdf_draw_copy_font_resources(
  resources : ArrayView[PdfDrawFontResource],
) -> Array[PdfDrawFontResource] {
  let output : Array[PdfDrawFontResource] = Array::new(
    capacity=resources.length(),
  )
  for entry in resources {
    output.push(entry)
  }
  output
}

///|
fn pdf_draw_copy_fontpacks(
  fontpacks : ArrayView[PdfDrawFontPackState],
) -> Array[PdfDrawFontPackState] {
  let output : Array[PdfDrawFontPackState] = Array::new(
    capacity=fontpacks.length(),
  )
  for entry in fontpacks {
    output.push(entry)
  }
  output
}

///|
fn pdf_draw_copy_page_names(names : ArrayView[PdfName]) -> Array[PdfName] {
  let output : Array[PdfName] = Array::new(capacity=names.length())
  for name in names {
    output.push(name)
  }
  output
}

///|
fn PdfDrawRenderState::nested_form_state(
  self : PdfDrawRenderState,
) -> PdfDrawRenderState {
  {
    resource_number: self.resource_number,
    marked_content_id: self.marked_content_id,
    extgstates: [],
    xobjects: pdf_draw_copy_xobject_resources(self.xobjects),
    form_xobjects: pdf_draw_copy_xobject_resources(self.form_xobjects),
    fonts: pdf_draw_copy_font_resources(self.fonts),
    fontpacks: pdf_draw_copy_fontpacks(self.fontpacks),
    current_fontpack_identifier: self.current_fontpack_identifier,
    current_fontpack: self.current_fontpack,
    font_size: self.font_size,
    structure_tree_enabled: self.structure_tree_enabled,
    auto_tag: self.auto_tag,
    structure_page_number: self.structure_page_number,
    structure_data: self.structure_data,
    page_names: pdf_draw_copy_page_names(self.page_names),
  }
}

///|
fn PdfDrawRenderState::adopt_resource_number(
  self : PdfDrawRenderState,
  child : PdfDrawRenderState,
) -> Unit {
  if child.resource_number > self.resource_number {
    self.resource_number = child.resource_number
  }
  if child.marked_content_id > self.marked_content_id {
    self.marked_content_id = child.marked_content_id
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
