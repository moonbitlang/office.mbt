///|
fn pdf_page_shift_offset_index(
  page_numbers : ArrayView[Int],
  page_number : Int,
) -> Int? {
  for index in 0..<page_numbers.length() {
    if page_numbers[index] == page_number {
      break Some(index)
    }
  } nobreak {
    None
  }
}

///|
fn pdf_page_shift_validate_offsets(
  page_numbers : ArrayView[Int],
  offsets : ArrayView[(Double, Double)],
) -> Unit raise PdfError {
  if page_numbers.length() != offsets.length() {
    raise BadPageSpecification(
      "shift_pages: offset count must match page count",
    )
  }
}

///|
fn pdf_page_shift_validate_page_indexed_offsets(
  context : String,
  page_count : Int,
  offsets : ArrayView[(Double, Double)],
) -> Unit raise PdfError {
  if offsets.length() != page_count {
    raise BadPageSpecification(context + ": offset count must match page count")
  }
}

///|
fn pdf_page_shift_select_page_indexed_offsets(
  page_numbers : ArrayView[Int],
  offsets : ArrayView[(Double, Double)],
) -> Array[(Double, Double)] {
  let selected : Array[(Double, Double)] = []
  for page_number in page_numbers {
    selected.push(offsets[page_number - 1])
  }
  selected
}

///|
fn PdfDocument::pdf_page_shift_page(
  self : PdfDocument,
  page : PdfPage,
  matrix : TransformMatrix,
  fast : Bool,
) -> PdfPage raise PdfError {
  let page = self.pdf_impose_change_pattern_matrices_page(matrix, page)
  self.transform_annotations(matrix, page.rest)
  self.prepend_operators(page, [Op_cm(matrix)], fast~)
}

///|
/// Shift selected page contents and annotations by per-page offsets.
///
/// `page_numbers` are 1-based and `offsets` must contain one `(dx, dy)` pair
/// for each selected page. Destination references for shifted pages are
/// transformed with the same matrix.
pub fn PdfDocument::shift_pages(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  offsets : ArrayView[(Double, Double)],
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  pdf_page_box_validate_page_numbers(
    page_numbers,
    self.endpage(),
    "shift_pages",
  )
  pdf_page_shift_validate_offsets(page_numbers, offsets)
  let pages = self.pages_of_pagetree()
  let rewritten : Array[PdfPage] = []
  let matrices : Array[(Int, TransformMatrix)] = []
  for index in 0..<pages.length() {
    let page_number = index + 1
    match pdf_page_shift_offset_index(page_numbers, page_number) {
      Some(offset_index) => {
        let offset = offsets[offset_index]
        let matrix = transform_translate(offset.0, offset.1)
        rewritten.push(self.pdf_page_shift_page(pages[index], matrix, fast))
        matrices.push((page_number, matrix))
      }
      None => rewritten.push(pages[index])
    }
  }
  self.change_pages(rewritten, change_references=true, matrices~)
}

///|
/// Compatibility wrapper for `PdfDocument::shift_pages`.
pub fn pdf_shift_pages(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  offsets : ArrayView[(Double, Double)],
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  document.shift_pages(page_numbers, offsets, fast~)
}

///|
/// Shift selected pages using cpdf's absolute page-indexed offset list.
///
/// This mirrors cpdfpage's `shift_pdf`: `offsets[page - 1]` is used for each
/// selected page, while unselected pages are left untouched.
pub fn PdfDocument::shift_pdf(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  offsets : ArrayView[(Double, Double)],
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  let pages = self.pages_of_pagetree()
  pdf_page_box_validate_page_numbers(page_numbers, pages.length(), "shift_pdf")
  pdf_page_shift_validate_page_indexed_offsets(
    "shift_pdf",
    pages.length(),
    offsets,
  )
  self.shift_pages(
    page_numbers,
    pdf_page_shift_select_page_indexed_offsets(page_numbers, offsets),
    fast~,
  )
}

///|
/// Compatibility wrapper matching cpdfpage's `shift_pdf` value argument order.
pub fn pdf_shift_pdf(
  offsets : ArrayView[(Double, Double)],
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  document.shift_pdf(page_numbers, offsets, fast~)
}
