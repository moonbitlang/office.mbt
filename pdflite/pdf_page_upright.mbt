///|
fn pdf_page_upright_degrees(rotation : PdfPageRotation) -> Double {
  pdf_page_int_of_rotation(rotation).to_double()
}

///|
fn pdf_page_upright_near_zero(value : Double) -> Bool {
  value < 0.001 && value > -0.001
}

///|
fn PdfDocument::pdf_page_upright_is_upright(
  self : PdfDocument,
  page : PdfPage,
) -> Bool raise PdfError {
  let bounds = self.parse_rectangle(page.mediabox)
  page.rotate == Rotate0 &&
  pdf_page_upright_near_zero(bounds.min_x) &&
  pdf_page_upright_near_zero(bounds.min_y)
}

///|
fn PdfDocument::pdf_page_upright_all_upright(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  pages : ArrayView[PdfPage],
) -> Bool raise PdfError {
  for page_number in page_numbers {
    if !self.pdf_page_upright_is_upright(pages[page_number - 1]) {
      break false
    }
  } nobreak {
    true
  }
}

///|
fn PdfDocument::pdf_page_upright_rotation_matrix(
  self : PdfDocument,
  page : PdfPage,
) -> TransformMatrix raise PdfError {
  let bounds = self.parse_rectangle(page.mediabox)
  let center = point2(
    (bounds.min_x + bounds.max_x) / 2.0,
    (bounds.min_y + bounds.max_y) / 2.0,
  )
  transform_rotate(
    center,
    -pdf_page_upright_degrees(page.rotate) * @math.PI / 180.0,
  )
}

///|
fn pdf_page_upright_box_names() -> Array[PdfName] {
  [
    pdf_page_trimbox_key(),
    pdf_page_artbox_key(),
    pdf_page_cropbox_key(),
    pdf_page_bleedbox_key(),
  ]
}

///|
fn PdfDocument::pdf_page_upright_transform_boxes(
  self : PdfDocument,
  page : PdfPage,
  matrix : TransformMatrix,
) -> PdfPage raise PdfError {
  let mut rest = page.rest
  for name in pdf_page_upright_box_names() {
    match self.lookup_direct(name, page.rest) {
      Some(value) =>
        rest = rest.add_dict_entry(name, self.transform_rect(matrix, value))
      None => ()
    }
  }
  { ..page, mediabox: self.transform_rect(matrix, page.mediabox), rest }
}

///|
fn PdfDocument::pdf_page_upright_transform_content(
  self : PdfDocument,
  page : PdfPage,
  matrix : TransformMatrix,
  fast : Bool,
) -> PdfPage raise PdfError {
  if matrix == transform_identity_matrix {
    page
  } else {
    let page = self.pdf_impose_change_pattern_matrices_page(matrix, page)
    self.transform_annotations(matrix, page.rest)
    self.prepend_operators(page, [Op_cm(matrix)], fast~)
  }
}

///|
fn PdfDocument::pdf_page_upright_rectify(
  self : PdfDocument,
  page : PdfPage,
  fast : Bool,
) -> (PdfPage, TransformMatrix) raise PdfError {
  let bounds = self.parse_rectangle(page.mediabox)
  if pdf_page_upright_near_zero(bounds.min_x) &&
    pdf_page_upright_near_zero(bounds.min_y) {
    (page, transform_identity_matrix)
  } else {
    let matrix = transform_translate(-bounds.min_x, -bounds.min_y)
    let page = self.pdf_page_upright_transform_boxes(page, matrix)
    let page = self.pdf_page_shift_page(page, matrix, fast)
    (page, matrix)
  }
}

///|
fn PdfDocument::pdf_page_upright_page(
  self : PdfDocument,
  page : PdfPage,
  fast : Bool,
) -> (PdfPage, TransformMatrix) raise PdfError {
  if self.pdf_page_upright_is_upright(page) {
    (page, transform_identity_matrix)
  } else {
    let rotation_matrix = self.pdf_page_upright_rotation_matrix(page)
    let page = self.pdf_page_upright_transform_boxes(page, rotation_matrix)
    let page = self.pdf_page_upright_transform_content(
      { ..page, rotate: Rotate0 },
      rotation_matrix,
      fast,
    )
    let (page, rectification_matrix) = self.pdf_page_upright_rectify(page, fast)
    (page, transform_matrix_compose(rectification_matrix, rotation_matrix))
  }
}

///|
/// Remove page dictionary rotation from selected pages by transforming page data.
///
/// Page content, annotations, known page boxes, and destinations are transformed
/// into an upright coordinate system. Non-zero `/MediaBox` origins are shifted
/// back to `(0, 0)` after rotation.
pub fn PdfDocument::upright_pages(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  pdf_page_box_validate_page_numbers(
    page_numbers,
    self.endpage(),
    "upright_pages",
  )
  let pages = self.pages_of_pagetree()
  if self.pdf_page_upright_all_upright(page_numbers, pages) {
    self
  } else {
    let rewritten : Array[PdfPage] = []
    let matrices : Array[(Int, TransformMatrix)] = []
    for index in 0..<pages.length() {
      let page_number = index + 1
      if pdf_page_box_contains_page(page_numbers, page_number) {
        let (page, matrix) = self.pdf_page_upright_page(pages[index], fast)
        rewritten.push(page)
        matrices.push((page_number, matrix))
      } else {
        rewritten.push(pages[index])
      }
    }
    self.change_pages(rewritten, change_references=true, matrices~)
  }
}

///|
/// Compatibility wrapper for `PdfDocument::upright_pages`.
pub fn pdf_upright_pages(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  document.upright_pages(page_numbers, fast~)
}
