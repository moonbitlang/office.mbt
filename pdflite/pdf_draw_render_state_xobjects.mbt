///|
fn PdfDrawRenderState::register_xobject(
  self : PdfDrawRenderState,
  source_name : String,
  prefix : String,
  object_number : Int,
) -> @core.PdfName {
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
) -> @core.PdfName {
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
