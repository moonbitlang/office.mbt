///|
fn pdf_image_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn pdf_image_image_mask_key() -> PdfName {
  pdf_image_name("/ImageMask")
}

///|
fn pdf_image_im_key() -> PdfName {
  pdf_image_name("/IM")
}

///|
fn pdf_image_colorspace_key() -> PdfName {
  pdf_image_name("/ColorSpace")
}

///|
fn pdf_image_cs_key() -> PdfName {
  pdf_image_name("/CS")
}

///|
fn pdf_image_bits_per_component_key() -> PdfName {
  pdf_image_name("/BitsPerComponent")
}

///|
fn pdf_image_bpc_key() -> PdfName {
  pdf_image_name("/BPC")
}

///|
pub(all) enum PdfPixelLayout {
  PdfBPP1
  PdfBPP8
  PdfBPP24
  PdfBPP48
} derive(Debug, Eq, ToJson)

///|
pub(all) enum PdfImage {
  PdfJPEG(PdfBytes, Array[Double]?)
  PdfJPEG2000(PdfBytes, Array[Double]?)
  PdfJBIG2(PdfBytes, Array[Double]?, Int?)
  PdfRawImage(Int, Int, PdfPixelLayout, PdfBytes)
} derive(Debug, Eq, ToJson)

///|
fn PdfDocument::pdf_image_is_mask(
  self : PdfDocument,
  image : PdfObject,
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
pub fn PdfDocument::image_colour_space(
  self : PdfDocument,
  image : PdfObject,
  resources : PdfObject,
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
pub fn PdfDocument::image_bits_per_component(
  self : PdfDocument,
  image : PdfObject,
) -> PdfObject? {
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
