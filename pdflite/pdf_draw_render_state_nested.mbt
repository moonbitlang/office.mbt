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
