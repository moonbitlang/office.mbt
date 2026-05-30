///|
fn PdfDocument::pdf_font_remove_descriptor_files(
  self : PdfDocument,
  object : @syntax.PdfObject,
) -> @syntax.PdfObject raise @core.PdfError {
  match object {
    PdfDictionary(_) =>
      match self.lookup_direct(pdf_text_type_key_name, object) {
        Some(PdfNameObject(kind)) if kind == pdf_text_font_name =>
          match self.lookup_direct(pdf_text_font_descriptor_key_name, object) {
            Some(PdfDictionary(_) | PdfStreamObject(_) as descriptor) => {
              let stripped = descriptor
                .remove_dict_entry(pdf_text_font_file_key_name)
                .remove_dict_entry(pdf_text_font_file2_key_name)
                .remove_dict_entry(pdf_text_font_file3_key_name)
              object.add_dict_entry(
                pdf_text_font_descriptor_key_name,
                PdfIndirect(self.add_object(stripped)),
              )
            }
            _ => object
          }
        _ => object
      }
    _ => object
  }
}

///|
/// Return a copy of the document with embedded font-file references removed.
///
/// This ports cpdf's `remove_fonts`: every parsed `/Type /Font` dictionary with
/// a `/FontDescriptor` receives a new descriptor object with `/FontFile`,
/// `/FontFile2`, and `/FontFile3` removed. The original document and original
/// descriptor objects are left untouched.
pub fn PdfDocument::remove_embedded_fonts(
  self : PdfDocument,
) -> PdfDocument raise @core.PdfError {
  let pdf = self.copy()
  let entries = pdf.parsed_object_entries()
  for entry in entries {
    pdf.add_object_given_number(
      entry.0,
      pdf.pdf_font_remove_descriptor_files(entry.2),
      generation=entry.1,
    )
  }
  pdf
}

///|
/// Compatibility wrapper for `PdfDocument::remove_embedded_fonts`.
pub fn pdf_remove_fonts(
  document : PdfDocument,
) -> PdfDocument raise @core.PdfError {
  document.remove_embedded_fonts()
}
