///|
fn PdfDocument::pdf_space_named_components(
  self : PdfDocument,
  resources : @syntax.PdfObject,
  name : PdfName,
) -> Int raise PdfError {
  if name == pdf_space_calgray_name ||
    name == pdf_space_device_gray_name ||
    name == pdf_space_g_name {
    1
  } else if name == pdf_space_calrgb_name ||
    name == pdf_space_device_rgb_name ||
    name == pdf_space_rgb_name {
    3
  } else if name == pdf_space_calcmyk_name ||
    name == pdf_space_device_cmyk_name ||
    name == pdf_space_cmyk_name {
    4
  } else if name == pdf_space_pattern_name {
    raise ColourSpaceExpected
  } else {
    match self.lookup_direct(pdf_space_colorspace_key(), resources) {
      Some(colour_spaces) =>
        match self.lookup_direct(name, colour_spaces) {
          Some(resolved) => self.colour_space_components(resources, resolved)
          None => raise DictionaryKeyNotFound(name)
        }
      None => raise DictionaryKeyNotFound(pdf_space_colorspace_key())
    }
  }
}

///|
/// Return the number of components required by a colour-space object.
///
/// Resource names are resolved through the supplied `resources` dictionary.
/// Pattern spaces without a base colour space are rejected because their paint
/// operators do not consume ordinary colour components.
pub fn PdfDocument::colour_space_components(
  self : PdfDocument,
  resources : @syntax.PdfObject,
  object : @syntax.PdfObject,
) -> Int raise PdfError {
  match self.direct(object) {
    PdfNameObject(name) => self.pdf_space_named_components(resources, name)
    PdfArray([PdfNameObject(kind), alternate]) if kind == pdf_space_pattern_name =>
      self.colour_space_components(resources, alternate)
    PdfArray([PdfNameObject(kind), _]) if kind == pdf_space_lab_name ||
      kind == pdf_space_calrgb_name => 3
    PdfArray([PdfNameObject(kind), _]) if kind == pdf_space_calcmyk_name => 4
    PdfArray([PdfNameObject(kind), _]) if kind == pdf_space_calgray_name => 1
    PdfArray([PdfNameObject(kind), stream_object]) if kind ==
      pdf_space_iccbased_name =>
      match self.lookup_direct(pdf_space_n_key(), stream_object) {
        Some(PdfInteger(components)) => components
        _ => raise ColourSpaceExpected
      }
    PdfArray([PdfNameObject(kind), _, _, _]) if kind ==
      pdf_space_separation_name => 1
    PdfArray([PdfNameObject(kind), _, _, ..]) if kind == pdf_space_indexed_name ||
      kind == pdf_space_i_name => 1
    PdfArray([PdfNameObject(kind), PdfArray(names), _, ..]) if kind ==
      pdf_space_device_n_name => names.length()
    PdfArray([single]) => self.colour_space_components(resources, single)
    _ => raise ColourSpaceExpected
  }
}

///|
/// Compatibility wrapper for `PdfDocument::colour_space_components`.
pub fn pdf_colour_space_components(
  document : PdfDocument,
  resources : @syntax.PdfObject,
  object : @syntax.PdfObject,
) -> Int raise PdfError {
  document.colour_space_components(resources, object)
}
