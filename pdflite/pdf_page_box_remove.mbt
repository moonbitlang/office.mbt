///|
/// Remove one page-box dictionary entry from selected pages.
pub fn PdfDocument::remove_page_box(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  box_name : @core.PdfName,
) -> PdfDocument raise @core.PdfError {
  self.pdf_page_box_rewrite_pages(page_numbers, "remove_page_box", (_, _, page) => {
    self.pdf_page_remove_box_page(page, box_name)
  })
}

///|
/// Compatibility wrapper for `PdfDocument::remove_page_box`.
pub fn pdf_remove_page_box(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  box_name : @core.PdfName,
) -> PdfDocument raise @core.PdfError {
  document.remove_page_box(page_numbers, box_name)
}

///|
/// Remove `/CropBox` entries from selected pages.
pub fn PdfDocument::remove_cropping(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise @core.PdfError {
  self.remove_page_box(page_numbers, pdf_page_cropbox_key())
}

///|
/// Compatibility wrapper for `PdfDocument::remove_cropping`.
pub fn pdf_remove_cropping_pdf(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise @core.PdfError {
  document.remove_cropping(page_numbers)
}

///|
/// Remove `/TrimBox` entries from selected pages.
pub fn PdfDocument::remove_trim(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise @core.PdfError {
  self.remove_page_box(page_numbers, pdf_page_trimbox_key())
}

///|
/// Compatibility wrapper for `PdfDocument::remove_trim`.
pub fn pdf_remove_trim_pdf(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise @core.PdfError {
  document.remove_trim(page_numbers)
}

///|
/// Remove `/ArtBox` entries from selected pages.
pub fn PdfDocument::remove_art(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise @core.PdfError {
  self.remove_page_box(page_numbers, pdf_page_artbox_key())
}

///|
/// Compatibility wrapper for `PdfDocument::remove_art`.
pub fn pdf_remove_art_pdf(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise @core.PdfError {
  document.remove_art(page_numbers)
}

///|
/// Remove `/BleedBox` entries from selected pages.
pub fn PdfDocument::remove_bleed(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise @core.PdfError {
  self.remove_page_box(page_numbers, pdf_page_bleedbox_key())
}

///|
/// Compatibility wrapper for `PdfDocument::remove_bleed`.
pub fn pdf_remove_bleed_pdf(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise @core.PdfError {
  document.remove_bleed(page_numbers)
}
