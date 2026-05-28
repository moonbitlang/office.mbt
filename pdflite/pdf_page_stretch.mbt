///|
fn PdfDocument::pdf_page_stretch_matrix(
  self : PdfDocument,
  page : PdfPage,
  target_width : Double,
  target_height : Double,
) -> TransformMatrix raise PdfError {
  let bounds = self.pdf_page_scale_bounds(page)
  let source_width = bounds.max_x - bounds.min_x
  let source_height = bounds.max_y - bounds.min_y
  if source_width <= 0.0 || source_height <= 0.0 {
    raise BadNumberArgument("stretch_pages: zero-sized pages are invalid")
  }
  transform_scale(
    point2(0.0, 0.0),
    target_width / source_width,
    target_height / source_height,
  )
}

///|
/// Stretch selected pages to target sizes without preserving aspect ratio.
///
/// This ports cpdfpage's `stretch`: the current `/CropBox` when present,
/// otherwise `/MediaBox`, determines the source width and height. Page boxes,
/// content streams, annotations, pattern matrices, and destination coordinates
/// are transformed by the computed x/y scale.
pub fn PdfDocument::stretch_pages(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  sizes : ArrayView[(Double, Double)],
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  pdf_page_box_validate_page_numbers(
    page_numbers,
    self.endpage(),
    "stretch_pages",
  )
  if page_numbers.length() != sizes.length() {
    raise BadPageSpecification(
      "stretch_pages: size count must match page count",
    )
  }
  let pages = self.pages_of_pagetree()
  let page_indexes = pdf_page_scale_pair_index_map(page_numbers)
  let rewritten : Array[PdfPage] = Array::new(capacity=pages.length())
  let matrices : Array[(Int, TransformMatrix)] = Array::new(
    capacity=page_numbers.length(),
  )
  for index in 0..<pages.length() {
    let page_number = index + 1
    match page_indexes.get(page_number) {
      Some(size_index) => {
        let size = sizes[size_index]
        let matrix = self.pdf_page_stretch_matrix(pages[index], size.0, size.1)
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
/// Compatibility wrapper for `PdfDocument::stretch_pages`.
pub fn pdf_stretch_pages(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  sizes : ArrayView[(Double, Double)],
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  document.stretch_pages(page_numbers, sizes, fast~)
}

///|
/// Stretch selected pages using cpdf's absolute page-indexed size list.
pub fn PdfDocument::stretch(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  sizes : ArrayView[(Double, Double)],
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  let pages = self.pages_of_pagetree()
  pdf_page_box_validate_page_numbers(page_numbers, pages.length(), "stretch")
  pdf_page_scale_validate_page_indexed_pairs(
    "stretch",
    "size",
    pages.length(),
    sizes,
  )
  self.stretch_pages(
    page_numbers,
    pdf_page_scale_select_page_indexed_pairs(page_numbers, sizes),
    fast~,
  )
}

///|
/// Compatibility wrapper matching cpdfpage's `stretch` value argument order.
pub fn pdf_stretch(
  sizes : ArrayView[(Double, Double)],
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  document.stretch(page_numbers, sizes, fast~)
}
