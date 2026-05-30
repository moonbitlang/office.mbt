///|
fn pdf_page_scale_to_fit_position_offset(
  position : @geometry.PdfPosition,
  target_width : Double,
  target_height : Double,
  source_width : Double,
  source_height : Double,
  scale : Double,
) -> (Double, Double) {
  let dx = (target_width - source_width * scale) / 2.0
  let dy = (target_height - source_height * scale) / 2.0
  let x = match position {
    PdfPositionLeft(_) => -dx
    PdfPositionRight(_) => dx
    _ => 0.0
  }
  let y = match position {
    PdfPositionTop(_) => dy
    PdfPositionBottom(_) => -dy
    _ => 0.0
  }
  (x, y)
}

///|
fn pdf_page_scale_to_fit_matrix_from_bounds(
  bounds : @geometry.PdfRectangle,
  target_width : Double,
  target_height : Double,
  position : @geometry.PdfPosition,
  input_scale : Double,
) -> @geometry.TransformMatrix raise PdfError {
  let source_width = bounds.max_x - bounds.min_x
  let source_height = bounds.max_y - bounds.min_y
  if source_width <= 0.0 || source_height <= 0.0 {
    raise BadNumberArgument("scale_to_fit_pages: zero-sized pages are invalid")
  }
  let fx = target_width / source_width
  let fy = target_height / source_height
  let fit = if fx < fy { fx } else { fy }
  let fit_scale = fit * input_scale
  let trans_x = (target_width - bounds.max_x * fit_scale) / 2.0
  let trans_y = (target_height - bounds.max_y * fit_scale) / 2.0
  let fixup_trans_x = -(bounds.min_x * fit_scale) / 2.0
  let fixup_trans_y = -(bounds.min_y * fit_scale) / 2.0
  let position_offset = pdf_page_scale_to_fit_position_offset(
    position, target_width, target_height, source_width, source_height, fit_scale,
  )
  @geometry.transform_matrix_compose(
    @geometry.transform_translate(fixup_trans_x, fixup_trans_y),
    @geometry.transform_matrix_compose(
      @geometry.transform_translate(position_offset.0, position_offset.1),
      @geometry.transform_matrix_compose(
        @geometry.transform_translate(trans_x, trans_y),
        @geometry.transform_scale(
          @geometry.point2(0.0, 0.0),
          fit_scale,
          fit_scale,
        ),
      ),
    ),
  )
}

///|
fn PdfDocument::pdf_page_scale_to_fit_matrix(
  self : PdfDocument,
  page : @page.PdfPage,
  target_width : Double,
  target_height : Double,
  position : @geometry.PdfPosition,
  input_scale : Double,
) -> @geometry.TransformMatrix raise PdfError {
  pdf_page_scale_to_fit_matrix_from_bounds(
    self.pdf_page_scale_bounds(page),
    target_width,
    target_height,
    position,
    input_scale,
  )
}

///|
fn pdf_page_scale_target_box(
  width : Double,
  height : Double,
) -> @syntax.PdfObject {
  PdfArray([PdfReal(0.0), PdfReal(0.0), PdfReal(width), PdfReal(height)])
}

///|
fn PdfDocument::pdf_page_scale_to_fit_boxes(
  self : PdfDocument,
  page : @page.PdfPage,
  target_width : Double,
  target_height : Double,
) -> @page.PdfPage raise PdfError {
  let target = pdf_page_scale_target_box(target_width, target_height)
  let mut rest = page.rest
  for name in pdf_page_upright_box_names() {
    match self.lookup_direct(name, page.rest) {
      Some(_) => rest = rest.add_dict_entry(name, target)
      None => ()
    }
  }
  { ..page, mediabox: target, rest }
}

///|
fn PdfDocument::pdf_page_scale_to_fit_page(
  self : PdfDocument,
  page : @page.PdfPage,
  target_width : Double,
  target_height : Double,
  matrix : @geometry.TransformMatrix,
  fast : Bool,
) -> @page.PdfPage raise PdfError {
  let page = self.pdf_page_scale_to_fit_boxes(page, target_width, target_height)
  let page = self.pdf_impose_change_pattern_matrices_page(matrix, page)
  self.transform_annotations(matrix, page.rest)
  self.prepend_operators(page, [Op_cm(matrix)], fast~)
}

///|
/// Scale selected pages to fit target page sizes while preserving aspect ratio.
pub fn PdfDocument::scale_to_fit_pages(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  sizes : ArrayView[(Double, Double)],
  position? : @geometry.PdfPosition = PdfPositionCentre,
  input_scale? : Double = 1.0,
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  pdf_page_box_validate_page_numbers(
    page_numbers,
    self.endpage(),
    "scale_to_fit_pages",
  )
  if page_numbers.length() != sizes.length() {
    raise BadPageSpecification(
      "scale_to_fit_pages: size count must match page count",
    )
  }
  let pages = self.pages_of_pagetree()
  let page_indexes = pdf_page_scale_pair_index_map(page_numbers)
  let rewritten : Array[@page.PdfPage] = Array::new(capacity=pages.length())
  let matrices : Array[(Int, @geometry.TransformMatrix)] = Array::new(
    capacity=page_numbers.length(),
  )
  for index in 0..<pages.length() {
    let page_number = index + 1
    match page_indexes.get(page_number) {
      Some(size_index) => {
        let size = sizes[size_index]
        let matrix = self.pdf_page_scale_to_fit_matrix(
          pages[index],
          size.0,
          size.1,
          position,
          input_scale,
        )
        rewritten.push(
          self.pdf_page_scale_to_fit_page(
            pages[index],
            size.0,
            size.1,
            matrix,
            fast,
          ),
        )
        matrices.push((page_number, matrix))
      }
      None => rewritten.push(pages[index])
    }
  }
  self.change_pages(rewritten, change_references=true, matrices~)
}

///|
/// Compatibility wrapper for `PdfDocument::scale_to_fit_pages`.
pub fn pdf_scale_to_fit_pages(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  sizes : ArrayView[(Double, Double)],
  position? : @geometry.PdfPosition = PdfPositionCentre,
  input_scale? : Double = 1.0,
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  document.scale_to_fit_pages(
    page_numbers,
    sizes,
    position~,
    input_scale~,
    fast~,
  )
}

///|
/// Scale selected pages to fit using cpdf's absolute page-indexed size list.
pub fn PdfDocument::scale_to_fit_pdf(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  sizes : ArrayView[(Double, Double)],
  position? : @geometry.PdfPosition = PdfPositionCentre,
  input_scale? : Double = 1.0,
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  let pages = self.pages_of_pagetree()
  pdf_page_box_validate_page_numbers(
    page_numbers,
    pages.length(),
    "scale_to_fit_pdf",
  )
  pdf_page_scale_validate_page_indexed_pairs(
    "scale_to_fit_pdf",
    "size",
    pages.length(),
    sizes,
  )
  self.scale_to_fit_pages(
    page_numbers,
    pdf_page_scale_select_page_indexed_pairs(page_numbers, sizes),
    position~,
    input_scale~,
    fast~,
  )
}

///|
/// Compatibility wrapper matching cpdfpage's `scale_to_fit_pdf` argument order.
pub fn[T] pdf_scale_to_fit_pdf(
  position : @geometry.PdfPosition,
  input_scale : Double,
  sizes : ArrayView[(Double, Double)],
  _op : T,
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  document.scale_to_fit_pdf(page_numbers, sizes, position~, input_scale~, fast~)
}
