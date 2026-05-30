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
) -> @core.PdfName {
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
) -> Unit raise @core.PdfError {
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
fn PdfDrawRenderState::set_current_font(
  self : PdfDrawRenderState,
  identifier : String,
  size : Double,
) -> Unit raise @core.PdfError {
  match self.stored_fontpack(identifier) {
    Some(fontpack) => {
      self.current_fontpack_identifier = identifier
      self.current_fontpack = fontpack
      self.font_size = size
    }
    None => raise SoftError("FontPack not found: " + identifier)
  }
}
