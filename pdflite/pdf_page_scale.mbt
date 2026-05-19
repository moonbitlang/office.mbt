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
fn pdf_page_scale_pair_index(
  page_numbers : ArrayView[Int],
  page_number : Int,
) -> Int? {
  for index in 0..<page_numbers.length() {
    if page_numbers[index] == page_number {
      break Some(index)
    }
  } nobreak {
    None
  }
}

///|
fn pdf_page_scale_validate_pairs(
  page_numbers : ArrayView[Int],
  scales : ArrayView[(Double, Double)],
) -> Unit raise PdfError {
  if page_numbers.length() != scales.length() {
    raise BadPageSpecification("scale_pages: scale count must match page count")
  }
}

///|
fn PdfDocument::pdf_page_scale_page_data(
  self : PdfDocument,
  page : PdfPage,
  matrix : TransformMatrix,
  fast : Bool,
) -> PdfPage raise PdfError {
  let page = self.pdf_page_upright_transform_boxes(page, matrix)
  let page = self.pdf_impose_change_pattern_matrices_page(matrix, page)
  self.transform_annotations(matrix, page.rest)
  self.prepend_operators(page, [Op_cm(matrix)], fast~)
}

///|
fn pdf_page_scale_to_fit_position_offset(
  position : PdfPosition,
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
  bounds : PdfRectangle,
  target_width : Double,
  target_height : Double,
  position : PdfPosition,
  input_scale : Double,
) -> TransformMatrix raise PdfError {
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
  transform_matrix_compose(
    transform_translate(fixup_trans_x, fixup_trans_y),
    transform_matrix_compose(
      transform_translate(position_offset.0, position_offset.1),
      transform_matrix_compose(
        transform_translate(trans_x, trans_y),
        transform_scale(point2(0.0, 0.0), fit_scale, fit_scale),
      ),
    ),
  )
}

///|
fn PdfDocument::pdf_page_scale_to_fit_matrix(
  self : PdfDocument,
  page : PdfPage,
  target_width : Double,
  target_height : Double,
  position : PdfPosition,
  input_scale : Double,
) -> TransformMatrix raise PdfError {
  pdf_page_scale_to_fit_matrix_from_bounds(
    self.pdf_page_scale_bounds(page),
    target_width,
    target_height,
    position,
    input_scale,
  )
}

///|
fn pdf_page_scale_target_box(width : Double, height : Double) -> PdfObject {
  PdfArray([PdfReal(0.0), PdfReal(0.0), PdfReal(width), PdfReal(height)])
}

///|
fn PdfDocument::pdf_page_scale_to_fit_boxes(
  self : PdfDocument,
  page : PdfPage,
  target_width : Double,
  target_height : Double,
) -> PdfPage raise PdfError {
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
  page : PdfPage,
  target_width : Double,
  target_height : Double,
  matrix : TransformMatrix,
  fast : Bool,
) -> PdfPage raise PdfError {
  let page = self.pdf_page_scale_to_fit_boxes(page, target_width, target_height)
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

///|
/// Scale selected pages by per-page x/y factors, including boxes and content.
///
/// This ports cpdf's `scale_pdf`: selected page boxes, content streams,
/// annotations, pattern matrices, and destination coordinates are transformed
/// by a scale matrix around the origin.
pub fn PdfDocument::scale_pages(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  scales : ArrayView[(Double, Double)],
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  pdf_page_box_validate_page_numbers(
    page_numbers,
    self.endpage(),
    "scale_pages",
  )
  pdf_page_scale_validate_pairs(page_numbers, scales)
  let pages = self.pages_of_pagetree()
  let rewritten : Array[PdfPage] = []
  let matrices : Array[(Int, TransformMatrix)] = []
  for index in 0..<pages.length() {
    let page_number = index + 1
    match pdf_page_scale_pair_index(page_numbers, page_number) {
      Some(scale_index) => {
        let scale = scales[scale_index]
        let matrix = transform_scale(point2(0.0, 0.0), scale.0, scale.1)
        rewritten.push(
          self.pdf_page_scale_page_data(pages[index], matrix, fast),
        )
        matrices.push((page_number, matrix))
      }
      None => rewritten.push(pages[index])
    }
  }
  self.change_pages(rewritten, change_references=true, matrices~)
}

///|
/// Compatibility wrapper for `PdfDocument::scale_pages`.
pub fn pdf_scale_pages(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  scales : ArrayView[(Double, Double)],
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  document.scale_pages(page_numbers, scales, fast~)
}

///|
/// Scale selected pages to fit target page sizes while preserving aspect ratio.
pub fn PdfDocument::scale_to_fit_pages(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  sizes : ArrayView[(Double, Double)],
  position? : PdfPosition = PdfPositionCentre,
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
  let rewritten : Array[PdfPage] = []
  let matrices : Array[(Int, TransformMatrix)] = []
  for index in 0..<pages.length() {
    let page_number = index + 1
    match pdf_page_scale_pair_index(page_numbers, page_number) {
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
  position? : PdfPosition = PdfPositionCentre,
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
fn pdf_page_scale_to_fit_rotate_should_rotate(
  bounds : PdfRectangle,
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
  page : PdfPage,
  target_width : Double,
  target_height : Double,
  rotation : Int,
) -> PdfPage raise PdfError {
  if pdf_page_scale_to_fit_rotate_should_rotate(
      self.pdf_page_scale_bounds(page),
      target_width,
      target_height,
    ) {
    {
      ..page,
      rotate: pdf_page_rotation_of_int(
        pdf_page_int_of_rotation(page.rotate) + rotation,
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
) -> PdfDocument raise PdfError {
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
  let rewritten : Array[PdfPage] = []
  for index in 0..<pages.length() {
    let page_number = index + 1
    match pdf_page_scale_pair_index(page_numbers, page_number) {
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
) -> PdfDocument raise PdfError {
  document.scale_to_fit_rotate_pages(page_numbers, sizes, rotation, fast~)
}
