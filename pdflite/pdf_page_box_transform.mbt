///|
/// Shift `/MediaBox` and known page boxes by page-indexed offsets.
///
/// This ports cpdf's `shift_boxes`: offsets are indexed by absolute page number
/// and content streams, annotations, and destination coordinates are not moved.
pub fn PdfDocument::shift_boxes(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  offsets : ArrayView[(Double, Double)],
) -> PdfDocument raise PdfError {
  let pages = self.pages_of_pagetree()
  pdf_page_box_validate_page_numbers(
    page_numbers,
    pages.length(),
    "shift_boxes",
  )
  pdf_page_box_validate_offsets(offsets, pages.length())
  let selected_pages = @core.pdf_number_set(page_numbers)
  let rewritten : Array[@page.PdfPage] = Array::new(capacity=pages.length())
  for index in 0..<pages.length() {
    let page_number = index + 1
    if selected_pages.contains(page_number) {
      let offset = offsets[page_number - 1]
      rewritten.push(
        self.change_boxes(pages[index], (min_x, min_y, max_x, max_y) => {
          (
            min_x + offset.0,
            min_y + offset.1,
            max_x + offset.0,
            max_y + offset.1,
          )
        }),
      )
    } else {
      rewritten.push(pages[index])
    }
  }
  self.change_pages(rewritten, change_references=true)
}

///|
/// Rectify a page so its media-box origin is `(0, 0)`.
///
/// Known page boxes are shifted by the same amount, and page content,
/// annotations, and pattern matrices receive the compensating translation.
pub fn PdfDocument::rectify_boxes(
  self : PdfDocument,
  page : @page.PdfPage,
  fast? : Bool = false,
) -> @page.PdfPage raise PdfError {
  let bounds = self.parse_rectangle(page.mediabox)
  let page = self.change_boxes(page, (min_x, min_y, max_x, max_y) => {
    (
      min_x - bounds.min_x,
      min_y - bounds.min_y,
      max_x - bounds.min_x,
      max_y - bounds.min_y,
    )
  })
  if bounds.min_x != 0.0 || bounds.min_y != 0.0 {
    self.pdf_page_shift_page(
      page,
      @geometry.transform_translate(-bounds.min_x, -bounds.min_y),
      fast,
    )
  } else {
    page
  }
}

///|
/// Compatibility wrapper for `PdfDocument::rectify_boxes`.
pub fn pdf_rectify_boxes(
  document : PdfDocument,
  page : @page.PdfPage,
  fast? : Bool = false,
) -> @page.PdfPage raise PdfError {
  document.rectify_boxes(page, fast~)
}

///|
/// Compatibility wrapper for `PdfDocument::shift_boxes`.
pub fn pdf_shift_boxes(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  offsets : ArrayView[(Double, Double)],
) -> PdfDocument raise PdfError {
  document.shift_boxes(page_numbers, offsets)
}

///|
/// Compatibility wrapper matching cpdfpage's `shift_boxes` argument order.
pub fn pdf_shift_boxes_cpdf_order(
  offsets : ArrayView[(Double, Double)],
  document : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  document.shift_boxes(page_numbers, offsets)
}
