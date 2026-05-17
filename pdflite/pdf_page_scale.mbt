///|
fn pdf_page_scale_position_offset(position : PdfPosition) -> (Double, Double) {
  match position {
    PdfPositionTop(distance) => (0.0, -distance)
    PdfPositionTopLeft(x, y) => (x, -y)
    PdfPositionTopRight(x, y) => (-x, -y)
    PdfPositionLeft(distance) => (distance, 0.0)
    PdfPositionBottomLeft(x, y) => (x, y)
    PdfPositionBottom(distance) => (0.0, distance)
    PdfPositionBottomRight(x, y) => (-x, y)
    PdfPositionRight(distance) => (-distance, 0.0)
    _ => (0.0, 0.0)
  }
}

///|
fn PdfDocument::pdf_page_scale_bounds(
  self : PdfDocument,
  page : PdfPage,
) -> PdfRectangle raise PdfError {
  self.parse_rectangle(
    match self.lookup_direct(pdf_page_cropbox_key(), page.rest) {
      Some(cropbox) => cropbox
      None => page.mediabox
    },
  )
}

///|
fn PdfDocument::pdf_page_scale_matrix(
  self : PdfDocument,
  page : PdfPage,
  position : PdfPosition,
  scale : Double,
) -> TransformMatrix raise PdfError {
  let bounds = self.pdf_page_scale_bounds(page)
  let origin = pdf_calculate_position(true, 0.0, bounds, position)
  let offset = pdf_page_scale_position_offset(position)
  transform_matrix_compose(
    transform_translate(offset.0, offset.1),
    transform_scale(point2(origin.x, origin.y), scale, scale),
  )
}

///|
fn PdfDocument::pdf_page_scale_page(
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
/// Scale selected page contents and annotations around a cpdf-style position.
///
/// The transform origin is calculated from `/CropBox` when present, otherwise
/// `/MediaBox`. Destination references for scaled pages are transformed with
/// the same matrix.
pub fn PdfDocument::scale_contents(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  position : PdfPosition,
  scale : Double,
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  pdf_page_box_validate_page_numbers(
    page_numbers,
    self.endpage(),
    "scale_contents",
  )
  let pages = self.pages_of_pagetree()
  let rewritten : Array[PdfPage] = []
  let matrices : Array[(Int, TransformMatrix)] = []
  for index in 0..<pages.length() {
    let page_number = index + 1
    if pdf_page_box_contains_page(page_numbers, page_number) {
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
  position : PdfPosition,
  scale : Double,
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  document.scale_contents(page_numbers, position, scale, fast~)
}
