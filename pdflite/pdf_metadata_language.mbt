///|
/// Return the catalog `/Lang` value, if present.
pub fn PdfDocument::language(self : PdfDocument) -> @core.PdfBytes? {
  match
    self.lookup_chain(self.trailer_dict(), [
      pdf_metadata_root(),
      pdf_metadata_lang(),
    ]) {
    Some(PdfString(value)) => Some(value)
    _ => None
  }
}

///|
/// Return the catalog `/Lang` value as text for cpdf-style string APIs.
pub fn PdfDocument::language_string(self : PdfDocument) -> String? {
  match self.language() {
    Some(value) => Some(@utf8.decode_lossy(value))
    None => None
  }
}

///|
/// Set the catalog `/Lang` value.
pub fn PdfDocument::set_language(
  self : PdfDocument,
  language : BytesView,
) -> PdfDocument raise @core.PdfError {
  let document = self.copy()
  document.pdf_metadata_update_catalog(fn(catalog) raise @core.PdfError {
    catalog.add_dict_entry(pdf_metadata_lang(), PdfString(language.to_owned()))
  })
  document
}

///|
/// Set the catalog `/Lang` value from a cpdf-style string.
pub fn PdfDocument::set_language_string(
  self : PdfDocument,
  language : String,
) -> PdfDocument raise @core.PdfError {
  self.set_language(@utf8.encode(language))
}
