///|
/// Scale selected pages by per-page x/y factors, including boxes and content.
///
/// This ports cpdf's `scale_pdf`: selected page boxes, content streams,
/// annotations, pattern matrices, and destination coordinates are transformed
/// by a scale matrix around the origin.
pub fn PdfDocument::scale_pages(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  scales : ArrayView[(Double, Double)],
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  pdf_page_box_validate_page_numbers(
    page_numbers,
    self.endpage(),
    "scale_pages",
  )
  pdf_page_scale_validate_pairs(page_numbers, scales)
  let pages = self.pages_of_pagetree()
  let page_indexes = pdf_page_scale_pair_index_map(page_numbers)
  let rewritten : Array[@page.PdfPage] = Array::new(capacity=pages.length())
  let matrices : Array[(Int, TransformMatrix)] = Array::new(
    capacity=page_numbers.length(),
  )
  for index in 0..<pages.length() {
    let page_number = index + 1
    match page_indexes.get(page_number) {
      Some(scale_index) => {
        let scale = scales[scale_index]
        let matrix = transform_scale(point2(0.0, 0.0), scale.0, scale.1)
        rewritten.push(
          self.pdf_page_scale_page_data(pages[index], matrix, fast),
        )
        matrices.push((page_number, matrix))
      }
      None => rewritten.push(pages[index])
    }
  }
  self.change_pages(rewritten, change_references=true, matrices~)
}

///|
/// Compatibility wrapper for `PdfDocument::scale_pages`.
pub fn pdf_scale_pages(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  scales : ArrayView[(Double, Double)],
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  document.scale_pages(page_numbers, scales, fast~)
}

///|
/// Scale selected pages using cpdf's absolute page-indexed scale list.
///
/// This mirrors cpdfpage's `scale_pdf`: `scales[page - 1]` is used for each
/// selected page, and unselected pages are left untouched.
pub fn PdfDocument::scale_pdf(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  scales : ArrayView[(Double, Double)],
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  let pages = self.pages_of_pagetree()
  pdf_page_box_validate_page_numbers(page_numbers, pages.length(), "scale_pdf")
  pdf_page_scale_validate_page_indexed_pairs(
    "scale_pdf",
    "scale",
    pages.length(),
    scales,
  )
  self.scale_pages(
    page_numbers,
    pdf_page_scale_select_page_indexed_pairs(page_numbers, scales),
    fast~,
  )
}

///|
/// Compatibility wrapper matching cpdfpage's `scale_pdf` value argument order.
pub fn pdf_scale_pdf(
  scales : ArrayView[(Double, Double)],
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  document.scale_pdf(page_numbers, scales, fast~)
}
