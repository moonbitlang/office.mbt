///|
fn PdfDocument::pdf_page_rotate_rewrite(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  rotate : (PdfPage) -> PdfPageRotation raise PdfError,
  label : String,
) -> PdfDocument raise PdfError {
  pdf_page_box_validate_page_numbers(page_numbers, self.endpage(), label)
  let pages = self.pages_of_pagetree()
  let rewritten : Array[PdfPage] = []
  for index in 0..<pages.length() {
    let page_number = index + 1
    let page = pages[index]
    if pdf_page_box_contains_page(page_numbers, page_number) {
      rewritten.push({ ..page, rotate: rotate(page) })
    } else {
      rewritten.push(page)
    }
  }
  self.change_pages(rewritten, change_references=true)
}

///|
/// Set selected page `/Rotate` entries to an absolute rotation in degrees.
pub fn PdfDocument::rotate_pages(
  self : PdfDocument,
  rotation : Int,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  let normalized = pdf_page_rotation_of_int(rotation)
  self.pdf_page_rotate_rewrite(
    page_numbers,
    fn(_) { normalized },
    "rotate_pages",
  )
}

///|
/// Add `rotation` degrees to selected page `/Rotate` entries.
pub fn PdfDocument::rotate_pages_by(
  self : PdfDocument,
  rotation : Int,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  self.pdf_page_rotate_rewrite(
    page_numbers,
    fn(page) raise PdfError {
      pdf_page_rotation_of_int(pdf_page_int_of_rotation(page.rotate) + rotation)
    },
    "rotate_pages_by",
  )
}

///|
/// Compatibility wrapper for `PdfDocument::rotate_pages`.
pub fn pdf_rotate_pages(
  document : PdfDocument,
  rotation : Int,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  document.rotate_pages(rotation, page_numbers)
}

///|
/// Compatibility wrapper for `PdfDocument::rotate_pages_by`.
pub fn pdf_rotate_pages_by(
  document : PdfDocument,
  rotation : Int,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  document.rotate_pages_by(rotation, page_numbers)
}
