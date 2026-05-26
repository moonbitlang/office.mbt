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
) -> Unit raise PdfError {
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
) -> Unit raise PdfError {
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
fn PdfDocument::pdf_page_stretch_matrix(
  self : PdfDocument,
  page : PdfPage,
  target_width : Double,
  target_height : Double,
) -> TransformMatrix raise PdfError {
  let bounds = self.pdf_page_scale_bounds(page)
  let source_width = bounds.max_x - bounds.min_x
  let source_height = bounds.max_y - bounds.min_y
  if source_width <= 0.0 || source_height <= 0.0 {
    raise BadNumberArgument("stretch_pages: zero-sized pages are invalid")
  }
  transform_scale(
    point2(0.0, 0.0),
    target_width / source_width,
    target_height / source_height,
  )
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
  let selected_pages = @number_set.pdf_number_set(page_numbers)
  let rewritten : Array[PdfPage] = Array::new(capacity=pages.length())
  let matrices : Array[(Int, TransformMatrix)] = Array::new(
    capacity=page_numbers.length(),
  )
  for index in 0..<pages.length() {
    let page_number = index + 1
    if selected_pages.contains(page_number) {
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
/// Compatibility wrapper matching cpdfpage's `scale_contents` argument order.
pub fn pdf_scale_contents_cpdf_order(
  position : PdfPosition,
  scale : Double,
  document : PdfDocument,
  page_numbers : ArrayView[Int],
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
  let page_indexes = pdf_page_scale_pair_index_map(page_numbers)
  let rewritten : Array[PdfPage] = Array::new(capacity=pages.length())
  let matrices : Array[(Int, TransformMatrix)] = Array::new(
    capacity=page_numbers.length(),
  )
  for index in 0..<pages.length() {
    let page_number = index + 1
    match page_indexes.get(page_number) {
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
/// Scale selected pages using cpdf's absolute page-indexed scale list.
///
/// This mirrors cpdfpage's `scale_pdf`: `scales[page - 1]` is used for each
/// selected page, and unselected pages are left untouched.
pub fn PdfDocument::scale_pdf(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  scales : ArrayView[(Double, Double)],
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  let pages = self.pages_of_pagetree()
  pdf_page_box_validate_page_numbers(page_numbers, pages.length(), "scale_pdf")
  pdf_page_scale_validate_page_indexed_pairs(
    "scale_pdf",
    "scale",
    pages.length(),
    scales,
  )
  self.scale_pages(
    page_numbers,
    pdf_page_scale_select_page_indexed_pairs(page_numbers, scales),
    fast~,
  )
}

///|
/// Compatibility wrapper matching cpdfpage's `scale_pdf` value argument order.
pub fn pdf_scale_pdf(
  scales : ArrayView[(Double, Double)],
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  document.scale_pdf(page_numbers, scales, fast~)
}

///|
/// Stretch selected pages to target sizes without preserving aspect ratio.
///
/// This ports cpdfpage's `stretch`: the current `/CropBox` when present,
/// otherwise `/MediaBox`, determines the source width and height. Page boxes,
/// content streams, annotations, pattern matrices, and destination coordinates
/// are transformed by the computed x/y scale.
pub fn PdfDocument::stretch_pages(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  sizes : ArrayView[(Double, Double)],
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  pdf_page_box_validate_page_numbers(
    page_numbers,
    self.endpage(),
    "stretch_pages",
  )
  if page_numbers.length() != sizes.length() {
    raise BadPageSpecification(
      "stretch_pages: size count must match page count",
    )
  }
  let pages = self.pages_of_pagetree()
  let page_indexes = pdf_page_scale_pair_index_map(page_numbers)
  let rewritten : Array[PdfPage] = Array::new(capacity=pages.length())
  let matrices : Array[(Int, TransformMatrix)] = Array::new(
    capacity=page_numbers.length(),
  )
  for index in 0..<pages.length() {
    let page_number = index + 1
    match page_indexes.get(page_number) {
      Some(size_index) => {
        let size = sizes[size_index]
        let matrix = self.pdf_page_stretch_matrix(pages[index], size.0, size.1)
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
/// Compatibility wrapper for `PdfDocument::stretch_pages`.
pub fn pdf_stretch_pages(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  sizes : ArrayView[(Double, Double)],
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  document.stretch_pages(page_numbers, sizes, fast~)
}

///|
/// Stretch selected pages using cpdf's absolute page-indexed size list.
pub fn PdfDocument::stretch(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  sizes : ArrayView[(Double, Double)],
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  let pages = self.pages_of_pagetree()
  pdf_page_box_validate_page_numbers(page_numbers, pages.length(), "stretch")
  pdf_page_scale_validate_page_indexed_pairs(
    "stretch",
    "size",
    pages.length(),
    sizes,
  )
  self.stretch_pages(
    page_numbers,
    pdf_page_scale_select_page_indexed_pairs(page_numbers, sizes),
    fast~,
  )
}

///|
/// Compatibility wrapper matching cpdfpage's `stretch` value argument order.
pub fn pdf_stretch(
  sizes : ArrayView[(Double, Double)],
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  document.stretch(page_numbers, sizes, fast~)
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
  let page_indexes = pdf_page_scale_pair_index_map(page_numbers)
  let rewritten : Array[PdfPage] = Array::new(capacity=pages.length())
  let matrices : Array[(Int, TransformMatrix)] = Array::new(
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
/// Scale selected pages to fit using cpdf's absolute page-indexed size list.
pub fn PdfDocument::scale_to_fit_pdf(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  sizes : ArrayView[(Double, Double)],
  position? : PdfPosition = PdfPositionCentre,
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
  position : PdfPosition,
  input_scale : Double,
  sizes : ArrayView[(Double, Double)],
  _op : T,
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  document.scale_to_fit_pdf(page_numbers, sizes, position~, input_scale~, fast~)
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
  let page_indexes = pdf_page_scale_pair_index_map(page_numbers)
  let rewritten : Array[PdfPage] = Array::new(capacity=pages.length())
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
) -> PdfDocument raise PdfError {
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
) -> PdfDocument raise PdfError {
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
) -> PdfDocument raise PdfError {
  document.scale_to_fit_rotate(page_numbers, sizes, rotation, fast~)
}

///|
fn pdf_page_scale_center_target_boxes(
  sizes : ArrayView[(Double, Double)],
) -> Array[(Double, Double, Double, Double)] {
  let boxes : Array[(Double, Double, Double, Double)] = Array::new(
    capacity=sizes.length(),
  )
  for size in sizes {
    boxes.push((0.0, 0.0, size.0, size.1))
  }
  boxes
}

///|
fn PdfDocument::pdf_page_scale_center_offsets(
  self : PdfDocument,
  target_width : Double,
  target_height : Double,
) -> Array[(Double, Double)] raise PdfError {
  let pages = self.pages_of_pagetree()
  let offsets : Array[(Double, Double)] = Array::new(capacity=pages.length())
  for page in pages {
    let bounds = self.pdf_page_scale_bounds(page)
    offsets.push(
      (
        -((target_width - (bounds.max_x - bounds.min_x)) / 2.0),
        -((target_height - (bounds.max_y - bounds.min_y)) / 2.0),
      ),
    )
  }
  offsets
}

///|
/// Centre selected pages on page-indexed target sizes without scaling content.
///
/// This ports cpdf's `center_to_fit` composition: selected pages receive new
/// media and crop boxes, art and bleed boxes are removed, then all known boxes
/// are shifted by offsets calculated from the original page crop/media bounds.
pub fn PdfDocument::center_to_fit_pages(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  sizes : ArrayView[(Double, Double)],
) -> PdfDocument raise PdfError {
  let pages = self.pages_of_pagetree()
  pdf_page_box_validate_page_numbers(
    page_numbers,
    pages.length(),
    "center_to_fit_pages",
  )
  if sizes.length() != pages.length() || sizes.length() == 0 {
    raise BadPageSpecification(
      "center_to_fit_pages: size count must match page count",
    )
  }
  let target = sizes[0]
  let offsets = self.pdf_page_scale_center_offsets(target.0, target.1)
  let boxes = pdf_page_scale_center_target_boxes(sizes)
  let centered = self
    .set_mediaboxes(page_numbers, boxes)
    .crop_pages(page_numbers, boxes)
    .remove_bleed(page_numbers)
    .remove_art(page_numbers)
    .remove_bleed(page_numbers)
  centered.shift_boxes(page_numbers, offsets)
}

///|
/// Compatibility wrapper for `PdfDocument::center_to_fit_pages`.
pub fn pdf_center_to_fit_pages(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  sizes : ArrayView[(Double, Double)],
) -> PdfDocument raise PdfError {
  document.center_to_fit_pages(page_numbers, sizes)
}

///|
/// Compatibility method using cpdfpage's `center_to_fit` name.
pub fn PdfDocument::center_to_fit(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  sizes : ArrayView[(Double, Double)],
) -> PdfDocument raise PdfError {
  self.center_to_fit_pages(page_numbers, sizes)
}

///|
/// Compatibility wrapper matching cpdfpage's `center_to_fit` value order.
pub fn pdf_center_to_fit(
  sizes : ArrayView[(Double, Double)],
  document : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  document.center_to_fit(page_numbers, sizes)
}
