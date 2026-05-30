///|
fn PdfDocument::pdf_image_is_mask(
  self : PdfDocument,
  image : @syntax.PdfObject,
) -> Bool {
  match
    self.lookup_direct_or_else(
      pdf_image_image_mask_key(),
      pdf_image_im_key(),
      image,
    ) {
    Some(PdfBoolean(true)) => true
    _ => false
  }
}

///|
/// Read an image XObject colour space.
///
/// `/ImageMask true` images are treated as `PdfDeviceGray`. Otherwise this
/// reads `/ColorSpace` or `/CS`, resolving named spaces through `resources`.
pub fn PdfDocument::image_colour_space(
  self : PdfDocument,
  image : @syntax.PdfObject,
  resources : @syntax.PdfObject,
) -> PdfColourSpace raise PdfError {
  if self.pdf_image_is_mask(image) {
    PdfDeviceGray
  } else {
    match
      self.lookup_direct_or_else(
        pdf_image_colorspace_key(),
        pdf_image_cs_key(),
        image,
      ) {
      Some(colour_space) =>
        match self.read_colour_space(resources, colour_space) {
          Some(space) => space
          None => raise DictionaryKeyNotFound(pdf_image_colorspace_key())
        }
      None => raise DictionaryKeyNotFound(pdf_image_colorspace_key())
    }
  }
}

///|
/// Compatibility alias for `PdfDocument::image_colour_space`.
pub fn PdfDocument::colspace(
  self : PdfDocument,
  image : @syntax.PdfObject,
  resources : @syntax.PdfObject,
) -> PdfColourSpace raise PdfError {
  self.image_colour_space(image, resources)
}

///|
/// Compatibility wrapper for `PdfDocument::colspace`.
pub fn pdf_image_colspace(
  document : PdfDocument,
  image : @syntax.PdfObject,
  resources : @syntax.PdfObject,
) -> PdfColourSpace raise PdfError {
  document.colspace(image, resources)
}

///|
/// Return an image's `/BitsPerComponent` or abbreviated `/BPC` entry.
///
/// Image masks default to `1` when no explicit value is present. The raw object
/// is returned to preserve the PDF representation.
pub fn PdfDocument::image_bits_per_component(
  self : PdfDocument,
  image : @syntax.PdfObject,
) -> @syntax.PdfObject? {
  match
    self.lookup_direct_or_else(
      pdf_image_bits_per_component_key(),
      pdf_image_bpc_key(),
      image,
    ) {
    Some(bits_per_component) => Some(bits_per_component)
    None =>
      if self.pdf_image_is_mask(image) {
        Some(PdfInteger(1))
      } else {
        None
      }
  }
}

///|
/// Compatibility alias for `PdfDocument::image_bits_per_component`.
pub fn PdfDocument::bpc(
  self : PdfDocument,
  image : @syntax.PdfObject,
) -> @syntax.PdfObject? {
  self.image_bits_per_component(image)
}

///|
/// Compatibility wrapper for `PdfDocument::bpc`.
pub fn pdf_image_bpc(
  document : PdfDocument,
  image : @syntax.PdfObject,
) -> @syntax.PdfObject? {
  document.bpc(image)
}
