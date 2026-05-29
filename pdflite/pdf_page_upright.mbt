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
/// Return whether selected pages are rotation-free and have a near-zero origin.
///
/// This ports cpdf's `allupright` predicate. Like the source, page numbers
/// outside the document are ignored rather than treated as a range error.
pub fn PdfDocument::all_pages_upright(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
) -> Bool raise PdfError {
  let pages = self.pages_of_pagetree()
  for page_number in page_numbers {
    if page_number >= 1 && page_number <= pages.length() {
      if !self.pdf_page_upright_is_upright(pages[page_number - 1]) {
        break false
      }
    }
  } nobreak {
    true
  }
}

///|
/// Compatibility wrapper for `PdfDocument::all_pages_upright`.
pub fn pdf_allupright(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
) -> Bool raise PdfError {
  document.all_pages_upright(page_numbers)
}

///|
/// Compatibility wrapper matching cpdfpage's `allupright` argument order.
pub fn pdf_allupright_cpdf_order(
  page_numbers : ArrayView[Int],
  document : PdfDocument,
) -> Bool raise PdfError {
  document.all_pages_upright(page_numbers)
}

///|
/// Return whether selected pages have no page dictionary rotation.
///
/// This ports cpdf's `alluprightonly`, which intentionally does not require a
/// `(0, 0)` media-box origin and ignores out-of-range page numbers.
pub fn PdfDocument::all_pages_upright_only(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
) -> Bool raise PdfError {
  let pages = self.pages_of_pagetree()
  for page_number in page_numbers {
    if page_number >= 1 && page_number <= pages.length() {
      if pages[page_number - 1].rotate != Rotate0 {
        break false
      }
    }
  } nobreak {
    true
  }
}

///|
/// Compatibility wrapper for `PdfDocument::all_pages_upright_only`.
pub fn pdf_alluprightonly(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
) -> Bool raise PdfError {
  document.all_pages_upright_only(page_numbers)
}

///|
/// Compatibility wrapper matching cpdfpage's `alluprightonly` argument order.
pub fn pdf_alluprightonly_cpdf_order(
  page_numbers : ArrayView[Int],
  document : PdfDocument,
) -> Bool raise PdfError {
  document.all_pages_upright_only(page_numbers)
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
    let selected_pages = @core.pdf_number_set(page_numbers)
    let rewritten : Array[PdfPage] = Array::new(capacity=pages.length())
    let matrices : Array[(Int, TransformMatrix)] = Array::new(
      capacity=page_numbers.length(),
    )
    for index in 0..<pages.length() {
      let page_number = index + 1
      if selected_pages.contains(page_number) {
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

///|
/// Compatibility alias for `PdfDocument::upright_pages`.
pub fn PdfDocument::upright(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  self.upright_pages(page_numbers, fast~)
}

///|
/// Compatibility wrapper matching cpdfpage's `upright` argument order.
pub fn pdf_upright(
  page_numbers : ArrayView[Int],
  document : PdfDocument,
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  document.upright_pages(page_numbers, fast~)
}
