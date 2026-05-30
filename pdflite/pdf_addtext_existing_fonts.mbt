///|
fn pdf_addtext_font_not_found(fontname : PdfName) -> PdfError {
  SoftError(
    "addtext: font " + @ascii.decode_lossy(fontname.bytes()) + " not found",
  )
}

///|
/// Resolve an existing page font for cpdf add-text.
///
/// The requested name is first treated as a `/Font` resource key. If that is
/// absent, the page font dictionary is scanned for an entry whose `/BaseFont`
/// matches the requested name; the returned `PdfName` is the resource key to
/// use in emitted text operators.
pub fn PdfDocument::addtext_existing_font_resource(
  self : PdfDocument,
  page : @page.PdfPage,
  fontname : PdfName,
) -> (PdfName, @syntax.PdfObject) raise PdfError {
  let fontdict = match
    self.lookup_direct(pdf_addtext_font_key(), page.resources) {
    Some(fontdict) => fontdict
    None => raise SoftError("addtext: font dictionary not present")
  }
  match self.lookup_direct(fontname, fontdict) {
    Some(font) => (fontname, font)
    None =>
      match fontdict {
        PdfDictionary(entries) =>
          for entry in entries {
            match self.lookup_direct(pdf_text_base_font_key_name, entry.1) {
              Some(PdfNameObject(basefont)) if basefont == fontname =>
                break (entry.0, entry.1)
              _ => ()
            }
          } nobreak {
            raise pdf_addtext_font_not_found(fontname)
          }
        _ => raise pdf_addtext_font_not_found(fontname)
      }
  }
}

///|
/// Compatibility wrapper for `PdfDocument::addtext_existing_font_resource`.
pub fn pdf_addtext_existing_font_resource(
  document : PdfDocument,
  page : @page.PdfPage,
  fontname : PdfName,
) -> (PdfName, @syntax.PdfObject) raise PdfError {
  document.addtext_existing_font_resource(page, fontname)
}

///|
/// Measure add-text bytes using an existing page font resource.
pub fn PdfDocument::addtext_width_of_existing_font_resource(
  self : PdfDocument,
  page : @page.PdfPage,
  fontname : PdfName,
  font_size : Double,
  text : BytesView,
) -> (PdfName, Double) raise PdfError {
  let (resource_name, font_object) = self.addtext_existing_font_resource(
    page, fontname,
  )
  let font = self.read_font(font_object)
  (resource_name, pdf_addtext_width_of_selected_font(font, font_size, text))
}

///|
/// Compatibility wrapper for `PdfDocument::addtext_width_of_existing_font_resource`.
pub fn pdf_addtext_width_of_existing_font_resource(
  document : PdfDocument,
  page : @page.PdfPage,
  fontname : PdfName,
  font_size : Double,
  text : BytesView,
) -> (PdfName, Double) raise PdfError {
  document.addtext_width_of_existing_font_resource(
    page, fontname, font_size, text,
  )
}
