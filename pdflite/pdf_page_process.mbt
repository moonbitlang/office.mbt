///|
/// Apply a cpdf-style page callback to selected pages.
///
/// The callback returns the replacement page, the page serial whose destinations
/// should be transformed, and the transform matrix. Page numbers outside the
/// document are ignored, matching cpdf's range-membership behavior.
pub fn PdfDocument::process_pages(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  process : (Int, PdfPage) -> (PdfPage, Int, TransformMatrix) raise PdfError,
) -> PdfDocument raise PdfError {
  let pages = self.pages_of_pagetree()
  let selected_pages = @core.pdf_number_set(page_numbers)
  let rewritten : Array[PdfPage] = Array::new(capacity=pages.length())
  let matrices : Array[(Int, TransformMatrix)] = Array::new(
    capacity=pages.length(),
  )
  for index in 0..<pages.length() {
    let page_number = index + 1
    if selected_pages.contains(page_number) {
      pdf_progress_page(page_number)
      let (page, matrix_page, matrix) = process(page_number, pages[index])
      pdf_progress_endpage()
      rewritten.push(page)
      matrices.push((matrix_page, matrix))
    } else {
      rewritten.push(pages[index])
      matrices.push((page_number, transform_identity_matrix))
    }
  }
  pdf_progress_done()
  self.change_pages(rewritten, change_references=true, matrices~)
}

///|
/// Compatibility wrapper for `PdfDocument::process_pages`.
pub fn pdf_process_pages(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  process : (Int, PdfPage) -> (PdfPage, Int, TransformMatrix) raise PdfError,
) -> PdfDocument raise PdfError {
  document.process_pages(page_numbers, process)
}

///|
/// Compatibility wrapper matching cpdfpage's `process_pages` argument order.
pub fn pdf_process_pages_cpdf_order(
  process : (Int, PdfPage) -> (PdfPage, Int, TransformMatrix) raise PdfError,
  document : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  document.process_pages(page_numbers, process)
}

///|
/// Iterate over selected pages in document order.
///
/// Page numbers outside the document are ignored.
pub fn PdfDocument::iter_pages(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  process : (Int, PdfPage) -> Unit raise PdfError,
) -> Unit raise PdfError {
  let pages = self.pages_of_pagetree()
  let selected_pages = @core.pdf_number_set(page_numbers)
  for index in 0..<pages.length() {
    let page_number = index + 1
    if selected_pages.contains(page_number) {
      process(page_number, pages[index])
    }
  }
}

///|
/// Compatibility wrapper for `PdfDocument::iter_pages`.
pub fn pdf_iter_pages(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  process : (Int, PdfPage) -> Unit raise PdfError,
) -> Unit raise PdfError {
  document.iter_pages(page_numbers, process)
}

///|
/// Compatibility wrapper matching cpdfpage's `iter_pages` argument order.
pub fn pdf_iter_pages_cpdf_order(
  process : (Int, PdfPage) -> Unit raise PdfError,
  document : PdfDocument,
  page_numbers : ArrayView[Int],
) -> Unit raise PdfError {
  document.iter_pages(page_numbers, process)
}

///|
/// Map selected pages in document order.
///
/// Page numbers outside the document are ignored.
pub fn[T] PdfDocument::map_pages(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  process : (Int, PdfPage) -> T raise PdfError,
) -> Array[T] raise PdfError {
  let pages = self.pages_of_pagetree()
  let selected_pages = @core.pdf_number_set(page_numbers)
  let output : Array[T] = Array::new(capacity=page_numbers.length())
  for index in 0..<pages.length() {
    let page_number = index + 1
    if selected_pages.contains(page_number) {
      output.push(process(page_number, pages[index]))
    }
  }
  output
}

///|
/// Compatibility wrapper for `PdfDocument::map_pages`.
pub fn[T] pdf_map_pages(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  process : (Int, PdfPage) -> T raise PdfError,
) -> Array[T] raise PdfError {
  document.map_pages(page_numbers, process)
}

///|
/// Compatibility wrapper matching cpdfpage's `map_pages` argument order.
pub fn[T] pdf_map_pages_cpdf_order(
  process : (Int, PdfPage) -> T raise PdfError,
  document : PdfDocument,
  page_numbers : ArrayView[Int],
) -> Array[T] raise PdfError {
  document.map_pages(page_numbers, process)
}
