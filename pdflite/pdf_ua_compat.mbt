///|
/// Compatibility wrapper for `PdfDocument::mark_pdfua1`.
pub fn pdf_ua_mark(document : PdfDocument) -> PdfDocument raise PdfError {
  document.mark_pdfua1()
}

///|
/// Compatibility wrapper for `PdfDocument::mark_pdfua2`.
pub fn pdf_ua_mark2(
  year : Int,
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  document.mark_pdfua2(year)
}

///|
/// Compatibility wrapper for `PdfDocument::remove_pdfua_mark`.
pub fn pdf_ua_remove_mark(document : PdfDocument) -> PdfDocument raise PdfError {
  document.remove_pdfua_mark()
}

///|
/// Compatibility wrapper for `PdfDocument::extract_struct_tree`.
pub fn pdf_ua_extract_struct_tree(
  document : PdfDocument,
) -> Json raise PdfError {
  document.extract_struct_tree()
}

///|
/// Compatibility wrapper for `PdfDocument::struct_tree_json_blob`.
pub fn pdf_ua_extract_struct_tree_json_blob(
  document : PdfDocument,
) -> PdfBytes raise PdfError {
  document.struct_tree_json_blob()
}

///|
/// Compatibility wrapper for `PdfDocument::struct_tree_text`.
pub fn pdf_ua_print_struct_tree(
  document : PdfDocument,
) -> PdfBytes raise PdfError {
  document.struct_tree_text()
}

///|
/// Compatibility wrapper for `PdfDocument::replace_struct_tree`.
pub fn pdf_ua_replace_struct_tree(
  document : PdfDocument,
  json : Json,
) -> PdfDocument raise PdfError {
  document.replace_struct_tree(json)
}
