///|
/// Return the text encoding cpdf add-text uses for the selected font.
pub fn pdf_addtext_effective_encoding(font : PdfFont?) -> PdfEncoding {
  match font {
    Some(PdfFontStandard({ encoding, .. })) => encoding
    Some(PdfFontSimple({ encoding, .. })) => encoding
    _ => PdfWinAnsiEncoding
  }
}

///|
/// Return the page font resource object used by cpdf add-text setup.
///
/// Missing `/Font` resources are treated as an empty dictionary. Present values
/// are resolved through the document and returned as-is, matching cpdf's
/// `Pdf.lookup_direct` setup before unique font-name allocation.
pub fn PdfDocument::addtext_page_font_dictionary(
  self : PdfDocument,
  page : PdfPage,
) -> PdfObject {
  match self.lookup_direct(pdf_addtext_font_key(), page.resources) {
    Some(fontdict) => fontdict
    None => PdfDictionary([])
  }
}

///|
/// Compatibility wrapper for `PdfDocument::addtext_page_font_dictionary`.
pub fn pdf_addtext_page_font_dictionary(
  document : PdfDocument,
  page : PdfPage,
) -> PdfObject {
  document.addtext_page_font_dictionary(page)
}

///|
/// Allocate cpdf add-text font resource names for the selected font and
/// optional font pack.
pub fn pdf_addtext_allocate_font_names(
  fontdict : PdfObject,
  fontpack : PdfFontPack?,
) -> (PdfName, PdfObject, Array[PdfName]) raise PdfError {
  let unique_fontname = fontdict.unique_key("F")
  let mut updated = fontdict
  let unique_fontnames : Array[PdfName] = match fontpack {
    Some(pack) => Array::new(capacity=pack.fonts.length())
    None => []
  }
  match fontpack {
    Some(pack) =>
      for _ in pack.fonts {
        let key = updated.unique_key("F")
        updated = updated.add_dict_entry(key, PdfNull)
        unique_fontnames.push(key)
      }
    None => ()
  }
  (unique_fontname, updated, unique_fontnames)
}

///|
/// Replace cpdf add-text fontpack placeholders with embedded font references.
pub fn pdf_addtext_fontpack_resource_dictionary(
  fontdict : PdfObject,
  unique_fontnames : ArrayView[PdfName],
  font_objects : ArrayView[Int],
) -> PdfObject raise PdfError {
  if font_objects.length() != unique_fontnames.length() {
    raise SoftError("bad add-text fontpack resource list")
  }
  let mut updated = fontdict
  for index in 0..<font_objects.length() {
    updated = updated.add_dict_entry(
      unique_fontnames[index],
      PdfIndirect(font_objects[index]),
    )
  }
  updated
}

///|
/// Install one selected add-text font resource into a page resource dictionary.
pub fn pdf_addtext_install_font_resource(
  resources : PdfObject,
  fontdict : PdfObject,
  unique_fontname : PdfName,
  font_object : PdfObject?,
) -> PdfObject raise PdfError {
  match font_object {
    Some(font_object) =>
      resources.add_dict_entry(
        pdf_addtext_font_key(),
        fontdict.add_dict_entry(unique_fontname, font_object),
      )
    None => resources
  }
}

///|
/// Install cpdf add-text fontpack resources into a page resource dictionary.
pub fn pdf_addtext_install_fontpack_resources(
  resources : PdfObject,
  fontdict : PdfObject,
  unique_fontnames : ArrayView[PdfName],
  font_objects : ArrayView[Int],
) -> PdfObject raise PdfError {
  resources.add_dict_entry(
    pdf_addtext_font_key(),
    pdf_addtext_fontpack_resource_dictionary(
      fontdict, unique_fontnames, font_objects,
    ),
  )
}

///|
/// Write the selected cpdf add-text font and return its indirect reference.
///
/// Existing-named-font mode has no selected font to write, so `None` is
/// preserved for callers that later reuse the page's current font resource.
pub fn PdfDocument::addtext_selected_font_object(
  self : PdfDocument,
  font : PdfFont?,
) -> PdfObject? raise PdfError {
  match font {
    Some(font) => Some(PdfIndirect(self.write_font(font)))
    None => None
  }
}

///|
/// Compatibility wrapper for `PdfDocument::addtext_selected_font_object`.
pub fn pdf_addtext_selected_font_object(
  document : PdfDocument,
  font : PdfFont?,
) -> PdfObject? raise PdfError {
  document.addtext_selected_font_object(font)
}

///|
/// Prepare page resources for one cpdf add-text line.
///
/// Selected-font and fontpack modes install new `/Font` entries and optional
/// opacity resources. Existing-named-font mode reuses the page resources
/// unchanged and suppresses opacity graphics state selection, matching cpdf's
/// `font = None` branch.
pub fn PdfDocument::addtext_resource_setup(
  self : PdfDocument,
  page : PdfPage,
  font : PdfFont?,
  fontpack : PdfFontPack?,
  fontname : PdfName,
  font_object : PdfObject?,
  fontpack_font_objects : ArrayView[Int],
  opacity : Double,
) -> PdfAddTextResourceSetup raise PdfError {
  let fontdict = self.addtext_page_font_dictionary(page)
  match (font, fontpack) {
    (None, None) =>
      {
        resources: page.resources,
        font_dictionary: fontdict,
        unique_fontname: fontname,
        unique_fontnames: [],
        extgstate_name: None,
      }
    (_, Some(fontpack)) => {
      let (resources, extgstate_name) = self.addtext_opacity_resources(
        page.resources,
        opacity,
      )
      let (unique_fontname, reserved_fontdict, unique_fontnames) = pdf_addtext_allocate_font_names(
        fontdict,
        Some(fontpack),
      )
      {
        resources: pdf_addtext_install_fontpack_resources(
          resources, reserved_fontdict, unique_fontnames, fontpack_font_objects,
        ),
        font_dictionary: reserved_fontdict,
        unique_fontname,
        unique_fontnames,
        extgstate_name,
      }
    }
    (Some(_), None) => {
      let (resources, extgstate_name) = self.addtext_opacity_resources(
        page.resources,
        opacity,
      )
      let (unique_fontname, fontdict, unique_fontnames) = pdf_addtext_allocate_font_names(
        fontdict,
        None,
      )
      {
        resources: pdf_addtext_install_font_resource(
          resources, fontdict, unique_fontname, font_object,
        ),
        font_dictionary: fontdict,
        unique_fontname,
        unique_fontnames,
        extgstate_name,
      }
    }
  }
}

///|
/// Compatibility wrapper for `PdfDocument::addtext_resource_setup`.
pub fn pdf_addtext_resource_setup(
  document : PdfDocument,
  page : PdfPage,
  font : PdfFont?,
  fontpack : PdfFontPack?,
  fontname : PdfName,
  font_object : PdfObject?,
  fontpack_font_objects : ArrayView[Int],
  opacity : Double,
) -> PdfAddTextResourceSetup raise PdfError {
  document.addtext_resource_setup(
    page, font, fontpack, fontname, font_object, fontpack_font_objects, opacity,
  )
}
