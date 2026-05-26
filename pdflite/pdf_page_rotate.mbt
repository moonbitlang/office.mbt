///|
fn PdfDocument::pdf_page_rotate_rewrite(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  rotate : (PdfPage) -> PdfPageRotation raise PdfError,
  label : String,
) -> PdfDocument raise PdfError {
  pdf_page_box_validate_page_numbers(page_numbers, self.endpage(), label)
  let pages = self.pages_of_pagetree()
  let selected_pages = @number_set.pdf_number_set(page_numbers)
  let rewritten : Array[PdfPage] = Array::new(capacity=pages.length())
  for index in 0..<pages.length() {
    let page_number = index + 1
    let page = pages[index]
    if selected_pages.contains(page_number) {
      rewritten.push({ ..page, rotate: rotate(page) })
    } else {
      rewritten.push(page)
    }
  }
  self.change_pages(rewritten, change_references=true)
}

///|
fn pdf_page_rotate_degrees_to_radians(rotation : Double) -> Double {
  rotation * @math.PI / 180.0
}

///|
fn PdfDocument::pdf_page_rotate_contents_matrix(
  self : PdfDocument,
  page : PdfPage,
  rotation : Double,
) -> TransformMatrix raise PdfError {
  let bounds = self.parse_rectangle(page.mediabox)
  let origin = point2(
    (bounds.min_x + bounds.max_x) / 2.0,
    (bounds.min_y + bounds.max_y) / 2.0,
  )
  transform_rotate(origin, -pdf_page_rotate_degrees_to_radians(rotation))
}

///|
fn PdfDocument::pdf_page_rotate_contents_page(
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
/// Compatibility method using cpdfpage's `rotate_pdf` name.
pub fn PdfDocument::rotate_pdf(
  self : PdfDocument,
  rotation : Int,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  self.rotate_pages(rotation, page_numbers)
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
/// Compatibility method using cpdfpage's `rotate_pdf_by` name.
pub fn PdfDocument::rotate_pdf_by(
  self : PdfDocument,
  rotation : Int,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  self.rotate_pages_by(rotation, page_numbers)
}

///|
/// Rotate selected page contents around each page's `/MediaBox` center.
///
/// This ports cpdfpage's `rotate_contents`: page boxes and `/Rotate` entries are
/// left unchanged, while content streams, annotations, pattern matrices, and
/// destination coordinates are transformed.
pub fn PdfDocument::rotate_contents(
  self : PdfDocument,
  rotation : Double,
  page_numbers : ArrayView[Int],
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  pdf_page_box_validate_page_numbers(
    page_numbers,
    self.endpage(),
    "rotate_contents",
  )
  let pages = self.pages_of_pagetree()
  let selected_pages = @number_set.pdf_number_set(page_numbers)
  let rewritten : Array[PdfPage] = Array::new(capacity=pages.length())
  let matrices : Array[(Int, TransformMatrix)] = Array::new(
    capacity=page_numbers.length(),
  )
  for index in 0..<pages.length() {
    let page_number = index + 1
    if selected_pages.contains(page_number) {
      let matrix = self.pdf_page_rotate_contents_matrix(pages[index], rotation)
      rewritten.push(
        self.pdf_page_rotate_contents_page(pages[index], matrix, fast),
      )
      matrices.push((page_number, matrix))
    } else {
      rewritten.push(pages[index])
    }
  }
  self.change_pages(rewritten, change_references=true, matrices~)
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
/// Compatibility wrapper matching cpdfpage's `rotate_pdf` argument order.
pub fn pdf_rotate_pdf(
  rotation : Int,
  document : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  document.rotate_pdf(rotation, page_numbers)
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

///|
/// Compatibility wrapper matching cpdfpage's `rotate_pdf_by` argument order.
pub fn pdf_rotate_pdf_by(
  rotation : Int,
  document : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  document.rotate_pdf_by(rotation, page_numbers)
}

///|
/// Compatibility wrapper for `PdfDocument::rotate_contents`.
pub fn pdf_rotate_contents(
  document : PdfDocument,
  rotation : Double,
  page_numbers : ArrayView[Int],
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  document.rotate_contents(rotation, page_numbers, fast~)
}

///|
/// Compatibility wrapper preserving cpdfpage's `rotate_contents` argument
/// order without changing the existing document-first `pdf_rotate_contents`.
pub fn pdf_rotate_contents_cpdf_order(
  rotation : Double,
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  document.rotate_contents(rotation, page_numbers, fast~)
}
