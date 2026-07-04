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
) -> Array[(Double, Double)] raise @core.PdfError {
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
) -> PdfDocument raise @core.PdfError {
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
) -> PdfDocument raise @core.PdfError {
  document.center_to_fit_pages(page_numbers, sizes)
}

///|
/// Compatibility method using cpdfpage's `center_to_fit` name.
pub fn PdfDocument::center_to_fit(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  sizes : ArrayView[(Double, Double)],
) -> PdfDocument raise @core.PdfError {
  self.center_to_fit_pages(page_numbers, sizes)
}

///|
/// Compatibility wrapper matching cpdfpage's `center_to_fit` value order.
pub fn pdf_center_to_fit(
  sizes : ArrayView[(Double, Double)],
  document : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise @core.PdfError {
  document.center_to_fit(page_numbers, sizes)
}
