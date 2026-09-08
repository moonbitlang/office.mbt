///|
fn pdf_page_scale_to_fit_rotate_should_rotate(
  bounds : @geometry.PdfRectangle,
  target_width : Double,
  target_height : Double,
) -> Bool {
  // cpdf uses max_x - min_y for this historical orientation test.
  let page_width = bounds.max_x - bounds.min_y
  let page_height = bounds.max_y - bounds.min_y
  (page_width < page_height && target_width > target_height) ||
  (page_width > page_height && target_width < target_height)
}

///|
fn PdfDocument::pdf_page_scale_to_fit_rotate_page(
  self : PdfDocument,
  page : @page.PdfPage,
  target_width : Double,
  target_height : Double,
  rotation : Int,
) -> @page.PdfPage raise @core.PdfError {
  if pdf_page_scale_to_fit_rotate_should_rotate(
      self.pdf_page_scale_bounds(page),
      target_width,
      target_height,
    ) {
    {
      ..page,
      rotate: @page.pdf_page_rotation_of_int(
        @page.pdf_page_int_of_rotation(page.rotate) + rotation,
      ),
    }
  } else {
    page
  }
}

///|
/// Conditionally rotate selected pages to better fit target sizes, then upright
/// the same pages.
///
/// This ports cpdf's `scale_to_fit_rotate`: if a page and its target size have
/// opposite orientation, the page dictionary rotation is adjusted by `rotation`;
/// `upright_pages` is then applied to the selected range.
pub fn PdfDocument::scale_to_fit_rotate_pages(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  sizes : ArrayView[(Double, Double)],
  rotation : Int,
  fast? : Bool = false,
) -> PdfDocument raise @core.PdfError {
  pdf_page_box_validate_page_numbers(
    page_numbers,
    self.endpage(),
    "scale_to_fit_rotate_pages",
  )
  if page_numbers.length() != sizes.length() {
    raise BadPageSpecification(
      "scale_to_fit_rotate_pages: size count must match page count",
    )
  }
  let pages = self.pages_of_pagetree()
  let page_indexes = pdf_page_scale_pair_index_map(page_numbers)
  let rewritten : Array[@page.PdfPage] = Array::new(capacity=pages.length())
  for index in 0..<pages.length() {
    let page_number = index + 1
    match page_indexes.get(page_number) {
      Some(size_index) => {
        let size = sizes[size_index]
        rewritten.push(
          self.pdf_page_scale_to_fit_rotate_page(
            pages[index],
            size.0,
            size.1,
            rotation,
          ),
        )
      }
      None => rewritten.push(pages[index])
    }
  }
  let rotated = self.change_pages(rewritten, change_references=true)
  rotated.upright_pages(page_numbers, fast~)
}

///|
/// Compatibility wrapper for `PdfDocument::scale_to_fit_rotate_pages`.
pub fn pdf_scale_to_fit_rotate_pages(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  sizes : ArrayView[(Double, Double)],
  rotation : Int,
  fast? : Bool = false,
) -> PdfDocument raise @core.PdfError {
  document.scale_to_fit_rotate_pages(page_numbers, sizes, rotation, fast~)
}

///|
/// Conditionally rotate selected pages using cpdf's absolute page-indexed size
/// list, then upright the same pages.
pub fn PdfDocument::scale_to_fit_rotate(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  sizes : ArrayView[(Double, Double)],
  rotation : Int,
  fast? : Bool = false,
) -> PdfDocument raise @core.PdfError {
  let pages = self.pages_of_pagetree()
  pdf_page_box_validate_page_numbers(
    page_numbers,
    pages.length(),
    "scale_to_fit_rotate",
  )
  pdf_page_scale_validate_page_indexed_pairs(
    "scale_to_fit_rotate",
    "size",
    pages.length(),
    sizes,
  )
  self.scale_to_fit_rotate_pages(
    page_numbers,
    pdf_page_scale_select_page_indexed_pairs(page_numbers, sizes),
    rotation,
    fast~,
  )
}

///|
/// Compatibility wrapper matching cpdfpage's `scale_to_fit_rotate` order.
pub fn pdf_scale_to_fit_rotate(
  sizes : ArrayView[(Double, Double)],
  rotation : Int,
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  fast? : Bool = false,
) -> PdfDocument raise @core.PdfError {
  document.scale_to_fit_rotate(page_numbers, sizes, rotation, fast~)
}
