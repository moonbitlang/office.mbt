///|
fn PdfDocument::pdf_page_vertical_flip_matrix(
  self : PdfDocument,
  page : PdfPage,
) -> TransformMatrix raise PdfError {
  let bounds = self.parse_rectangle(page.mediabox)
  transform_scale(point2(0.0, (bounds.min_y + bounds.max_y) / 2.0), 1.0, -1.0)
}

///|
fn PdfDocument::pdf_page_horizontal_flip_matrix(
  self : PdfDocument,
  page : PdfPage,
) -> TransformMatrix raise PdfError {
  let bounds = self.parse_rectangle(page.mediabox)
  transform_scale(point2((bounds.min_x + bounds.max_x) / 2.0, 0.0), -1.0, 1.0)
}

///|
fn PdfDocument::pdf_page_flip_pages(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  context : String,
  fast : Bool,
  matrix_of_page : (PdfPage) -> TransformMatrix raise PdfError,
) -> PdfDocument raise PdfError {
  pdf_page_box_validate_page_numbers(page_numbers, self.endpage(), context)
  let pages = self.pages_of_pagetree()
  let selected_pages = @core.pdf_number_set(page_numbers)
  let rewritten : Array[PdfPage] = Array::new(capacity=pages.length())
  let matrices : Array[(Int, TransformMatrix)] = Array::new(
    capacity=page_numbers.length(),
  )
  for index in 0..<pages.length() {
    let page_number = index + 1
    if selected_pages.contains(page_number) {
      let matrix = matrix_of_page(pages[index])
      rewritten.push(self.pdf_page_scale_page(pages[index], matrix, fast))
      matrices.push((page_number, matrix))
    } else {
      rewritten.push(pages[index])
    }
  }
  self.change_pages(rewritten, change_references=true, matrices~)
}

///|
/// Flip selected pages vertically around the vertical centre of each page's
/// `/MediaBox`.
///
/// This ports cpdf's `vflip_pdf`: page content, annotations, pattern matrices,
/// and destination coordinates are transformed, while page boxes are left
/// unchanged.
pub fn PdfDocument::flip_pages_vertically(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  self.pdf_page_flip_pages(page_numbers, "flip_pages_vertically", fast, page => {
    self.pdf_page_vertical_flip_matrix(page)
  })
}

///|
/// Compatibility method using cpdfpage's `vflip_pdf` name.
pub fn PdfDocument::vflip_pdf(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  self.flip_pages_vertically(page_numbers, fast~)
}

///|
/// Compatibility wrapper for `PdfDocument::flip_pages_vertically`.
pub fn pdf_vflip_pdf(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  document.vflip_pdf(page_numbers, fast~)
}

///|
/// Flip selected pages horizontally around the horizontal centre of each page's
/// `/MediaBox`.
///
/// This ports cpdf's `hflip_pdf`: page content, annotations, pattern matrices,
/// and destination coordinates are transformed, while page boxes are left
/// unchanged.
pub fn PdfDocument::flip_pages_horizontally(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  self.pdf_page_flip_pages(page_numbers, "flip_pages_horizontally", fast, page => {
    self.pdf_page_horizontal_flip_matrix(page)
  })
}

///|
/// Compatibility method using cpdfpage's `hflip_pdf` name.
pub fn PdfDocument::hflip_pdf(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  self.flip_pages_horizontally(page_numbers, fast~)
}

///|
/// Compatibility wrapper for `PdfDocument::flip_pages_horizontally`.
pub fn pdf_hflip_pdf(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  document.hflip_pdf(page_numbers, fast~)
}
