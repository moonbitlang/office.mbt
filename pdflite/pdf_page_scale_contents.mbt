///|
/// Scale selected page contents and annotations around a cpdf-style position.
///
/// The transform origin is calculated from `/CropBox` when present, otherwise
/// `/MediaBox`. Destination references for scaled pages are transformed with
/// the same matrix.
pub fn PdfDocument::scale_contents(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  position : @geometry.PdfPosition,
  scale : Double,
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  pdf_page_box_validate_page_numbers(
    page_numbers,
    self.endpage(),
    "scale_contents",
  )
  let pages = self.pages_of_pagetree()
  let selected_pages = @core.pdf_number_set(page_numbers)
  let rewritten : Array[@page.PdfPage] = Array::new(capacity=pages.length())
  let matrices : Array[(Int, @geometry.TransformMatrix)] = Array::new(
    capacity=page_numbers.length(),
  )
  for index in 0..<pages.length() {
    let page_number = index + 1
    if selected_pages.contains(page_number) {
      let matrix = self.pdf_page_scale_matrix(pages[index], position, scale)
      rewritten.push(self.pdf_page_scale_page(pages[index], matrix, fast))
      matrices.push((page_number, matrix))
    } else {
      rewritten.push(pages[index])
    }
  }
  self.change_pages(rewritten, change_references=true, matrices~)
}

///|
/// Compatibility wrapper for `PdfDocument::scale_contents`.
pub fn pdf_scale_contents(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  position : @geometry.PdfPosition,
  scale : Double,
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  document.scale_contents(page_numbers, position, scale, fast~)
}

///|
/// Compatibility wrapper matching cpdfpage's `scale_contents` argument order.
pub fn pdf_scale_contents_cpdf_order(
  position : @geometry.PdfPosition,
  scale : Double,
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  document.scale_contents(page_numbers, position, scale, fast~)
}
