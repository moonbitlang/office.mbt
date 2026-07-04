///|
fn pdf_page_scale_position_offset(
  position : @geometry.PdfPosition,
) -> (Double, Double) {
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
  page : @page.PdfPage,
) -> @geometry.PdfRectangle raise @core.PdfError {
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
  page : @page.PdfPage,
  position : @geometry.PdfPosition,
  scale : Double,
) -> @geometry.TransformMatrix raise @core.PdfError {
  let bounds = self.pdf_page_scale_bounds(page)
  let origin = @geometry.pdf_calculate_position(true, 0.0, bounds, position)
  let offset = pdf_page_scale_position_offset(position)
  @geometry.transform_matrix_compose(
    @geometry.transform_translate(offset.0, offset.1),
    @geometry.transform_scale(
      @geometry.point2(origin.x, origin.y),
      scale,
      scale,
    ),
  )
}

///|
fn PdfDocument::pdf_page_scale_page(
  self : PdfDocument,
  page : @page.PdfPage,
  matrix : @geometry.TransformMatrix,
  fast : Bool,
) -> @page.PdfPage raise @core.PdfError {
  let page = self.pdf_impose_change_pattern_matrices_page(matrix, page)
  self.transform_annotations(matrix, page.rest)
  self.prepend_operators(page, [Op_cm(matrix)], fast~)
}

///|
fn pdf_page_scale_pair_index_map(
  page_numbers : ArrayView[Int],
) -> @hashmap.HashMap[Int, Int] {
  let indexes : @hashmap.HashMap[Int, Int] = HashMap([])
  for index in 0..<page_numbers.length() {
    if !indexes.contains(page_numbers[index]) {
      indexes[page_numbers[index]] = index
    }
  }
  indexes
}

///|
fn pdf_page_scale_validate_pairs(
  page_numbers : ArrayView[Int],
  scales : ArrayView[(Double, Double)],
) -> Unit raise @core.PdfError {
  if page_numbers.length() != scales.length() {
    raise BadPageSpecification("scale_pages: scale count must match page count")
  }
}

///|
fn pdf_page_scale_validate_page_indexed_pairs(
  context : String,
  label : String,
  page_count : Int,
  values : ArrayView[(Double, Double)],
) -> Unit raise @core.PdfError {
  if values.length() != page_count {
    raise BadPageSpecification(
      context + ": " + label + " count must match page count",
    )
  }
}

///|
fn pdf_page_scale_select_page_indexed_pairs(
  page_numbers : ArrayView[Int],
  values : ArrayView[(Double, Double)],
) -> Array[(Double, Double)] {
  let selected : Array[(Double, Double)] = Array::new(
    capacity=page_numbers.length(),
  )
  for page_number in page_numbers {
    selected.push(values[page_number - 1])
  }
  selected
}

///|
fn PdfDocument::pdf_page_scale_page_data(
  self : PdfDocument,
  page : @page.PdfPage,
  matrix : @geometry.TransformMatrix,
  fast : Bool,
) -> @page.PdfPage raise @core.PdfError {
  let page = self.pdf_page_upright_transform_boxes(page, matrix)
  let page = self.pdf_impose_change_pattern_matrices_page(matrix, page)
  self.transform_annotations(matrix, page.rest)
  self.prepend_operators(page, [Op_cm(matrix)], fast~)
}
