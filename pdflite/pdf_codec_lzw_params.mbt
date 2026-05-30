///|
fn pdf_lzw_early_change(
  dictionary : @syntax.PdfObject,
) -> Int raise @core.PdfError {
  match pdf_first_decodeparms(dictionary) {
    None => 1
    Some(decodeparms) =>
      pdf_decodeparms_int(decodeparms, pdf_early_change_key(), 1)
  }
}

///|
fn PdfDocument::pdf_lzw_early_change_direct(
  self : PdfDocument,
  dictionary : @syntax.PdfObject,
) -> Int raise @core.PdfError {
  match self.pdf_first_decodeparms_direct(dictionary) {
    None => 1
    Some(decodeparms) =>
      self.pdf_decodeparms_int_direct(decodeparms, pdf_early_change_key(), 1)
  }
}
