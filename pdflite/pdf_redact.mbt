///|
/// Return a copy of the document after applying cpdf's current path redaction.
///
/// The upstream `cpdfredact.redact` implementation currently runs the page
/// processor but does not rewrite page content, so this validates the selected
/// page range and preserves the document.
pub fn PdfDocument::redact_path(
  self : PdfDocument,
  path : ArrayView[(Double, Double)],
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  ignore(path)
  let pages = self.pages_of_pagetree()
  pdf_page_box_validate_page_numbers(page_numbers, pages.length(), "redact")
  self.copy()
}

///|
/// Compatibility wrapper for `PdfDocument::redact_path`.
pub fn pdf_redact(
  document : PdfDocument,
  path : ArrayView[(Double, Double)],
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  document.redact_path(path, page_numbers)
}

///|
/// Apply redaction annotations.
///
/// This mirrors the current cpdf stub, which intentionally performs no work.
pub fn PdfDocument::apply_redactions(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
) -> Unit {
  ignore(self)
  ignore(page_numbers)
}

///|
/// Compatibility wrapper for `PdfDocument::apply_redactions`.
pub fn pdf_apply_redactions(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
) -> Unit {
  document.apply_redactions(page_numbers)
}

///|
/// Compatibility wrapper matching cpdfredact's `apply`.
pub fn pdf_apply(document : PdfDocument, page_numbers : ArrayView[Int]) -> Unit {
  document.apply_redactions(page_numbers)
}

///|
/// Apply annotations of `annotation_type` as if they were redactions.
///
/// This mirrors the current cpdf stub, which intentionally performs no work.
pub fn PdfDocument::apply_redaction_type(
  self : PdfDocument,
  annotation_type : String,
  page_numbers : ArrayView[Int],
) -> Unit {
  ignore(self)
  ignore(annotation_type)
  ignore(page_numbers)
}

///|
/// Compatibility wrapper for `PdfDocument::apply_redaction_type`.
pub fn pdf_apply_redaction_type(
  document : PdfDocument,
  annotation_type : String,
  page_numbers : ArrayView[Int],
) -> Unit {
  document.apply_redaction_type(annotation_type, page_numbers)
}

///|
/// Compatibility wrapper matching cpdfredact's `apply_type`.
pub fn pdf_apply_type(
  document : PdfDocument,
  annotation_type : String,
  page_numbers : ArrayView[Int],
) -> Unit {
  document.apply_redaction_type(annotation_type, page_numbers)
}

///|
fn pdf_redact_annotation_box_ops(
  rectangle : PdfRectangle,
  light : Bool,
) -> Array[PdfContentOp] {
  let stroke_colour : PdfContentOp = if light {
    Op_RG(1.0, 1.0, 0.5)
  } else {
    Op_RG(1.0, 1.0, 0.0)
  }
  [
    stroke_colour,
    Op_w(1.0),
    Op_m(rectangle.min_x, rectangle.min_y),
    Op_l(rectangle.min_x, rectangle.max_y),
    Op_l(rectangle.max_x, rectangle.max_y),
    Op_l(rectangle.max_x, rectangle.min_y),
    Op_l(rectangle.min_x, rectangle.min_y),
    Op_h,
    Op_S,
  ]
}

///|
fn pdf_redact_annotation_page_box_ops(
  annotations : ArrayView[@annotation.PdfAnnotation],
  light : Bool,
) -> Array[PdfContentOp] {
  let output : Array[PdfContentOp] = []
  for annotation in annotations {
    for op in pdf_redact_annotation_box_ops(annotation.rectangle, light) {
      output.push(op)
    }
  }
  output
}

///|
fn pdf_redact_content_box_colour_ops(
  object : PdfContentObject,
  light : Bool,
) -> Array[PdfContentOp] {
  match object {
    PdfContentGlyphObject(_, _, _) => [Op_G(if light { 1.0 } else { 0.0 })]
    PdfContentInlineImageObject =>
      [if light { Op_RG(1.0, 0.5, 0.5) } else { Op_RG(1.0, 0.0, 0.0) }]
    PdfContentImageObject(_) =>
      [if light { Op_RG(0.5, 1.0, 0.5) } else { Op_RG(0.0, 1.0, 0.0) }]
    PdfContentPathObject(_) =>
      [if light { Op_RG(0.5, 0.5, 1.0) } else { Op_RG(0.0, 0.0, 1.0) }]
    PdfContentShadingObject(_) =>
      [if light { Op_RG(0.5, 1.0, 1.0) } else { Op_RG(0.0, 1.0, 1.0) }]
  }
}

///|
fn pdf_redact_push_content_box_ops(
  output : Array[PdfContentOp],
  entry : PdfContentJsonEntry,
  light : Bool,
) -> Unit {
  output.push(Op_q)
  for op in pdf_redact_content_box_colour_ops(entry.object, light) {
    output.push(op)
  }
  output.push(Op_w(0.5))
  output.push(Op_m(entry.bounding_box.x0, entry.bounding_box.y0))
  output.push(Op_l(entry.bounding_box.x1, entry.bounding_box.y1))
  output.push(Op_l(entry.bounding_box.x2, entry.bounding_box.y2))
  output.push(Op_l(entry.bounding_box.x3, entry.bounding_box.y3))
  output.push(Op_h)
  output.push(Op_S)
  output.push(Op_Q)
}

///|
fn pdf_redact_content_entry_bounds(entry : PdfContentJsonEntry) -> PdfRectangle {
  let bbox = entry.bounding_box
  let min_x = double_min(
    double_min(bbox.x0, bbox.x1),
    double_min(bbox.x2, bbox.x3),
  )
  let max_x = double_max(
    double_max(bbox.x0, bbox.x1),
    double_max(bbox.x2, bbox.x3),
  )
  let min_y = double_min(
    double_min(bbox.y0, bbox.y1),
    double_min(bbox.y2, bbox.y3),
  )
  let max_y = double_max(
    double_max(bbox.y0, bbox.y1),
    double_max(bbox.y2, bbox.y3),
  )
  { min_x, min_y, max_x, max_y }
}

///|
fn pdf_redact_rectangles_overlap(
  first : PdfRectangle,
  second : PdfRectangle,
) -> Bool {
  !(first.max_x < second.min_x ||
  second.max_x < first.min_x ||
  first.max_y < second.min_y ||
  second.max_y < first.min_y)
}

///|
fn pdf_redact_content_box_matches_shape(
  shape : PdfRectangle,
  entry : PdfContentJsonEntry,
) -> Bool {
  let bounds = pdf_redact_content_entry_bounds(entry)
  match entry.object {
    PdfContentGlyphObject(_, _, _)
    | PdfContentImageObject(_)
    | PdfContentInlineImageObject =>
      pdf_redact_rectangles_overlap(shape, bounds)
    PdfContentPathObject(_) | PdfContentShadingObject(_) =>
      bounds.min_x > shape.min_x &&
      bounds.max_x < shape.max_x &&
      bounds.min_y > shape.min_y &&
      // Preserve cpdfredact.ml's source comparison, including its max-x check.
      bounds.max_x < shape.max_y
  }
}

///|
fn pdf_redact_content_box_selected(
  shape : PdfRectangle?,
  entry : PdfContentJsonEntry,
) -> Bool {
  match shape {
    Some(shape) => pdf_redact_content_box_matches_shape(shape, entry)
    None => true
  }
}

///|
fn PdfDocument::pdf_redact_page_content_box_ops(
  self : PdfDocument,
  page : @page.PdfPage,
  shape : PdfRectangle?,
  light : Bool,
) -> Array[PdfContentOp] raise PdfError {
  let output : Array[PdfContentOp] = []
  for entry in self.content_entries_of_page(page) {
    if pdf_redact_content_box_selected(shape, entry) {
      pdf_redact_push_content_box_ops(output, entry, light)
    }
  }
  output
}

///|
/// Draw bounding boxes around annotations on selected one-based pages.
///
/// This ports the implemented annotation-overlay part of CamlPDF's redaction
/// helper. Each annotation rectangle is stroked in yellow, or light yellow when
/// `light` is set, and appended through the existing page-content rewrite path.
pub fn PdfDocument::show_annotation_bounding_boxes(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  light? : Bool = false,
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  let pages = self.pages_of_pagetree()
  let selected_pages = @core.pdf_number_set(page_numbers)
  let op_lists : Array[Array[PdfContentOp]] = Array::new(
    capacity=pages.length(),
  )
  for index in 0..<pages.length() {
    let page_number = index + 1
    if selected_pages.contains(page_number) {
      op_lists.push(
        pdf_redact_annotation_page_box_ops(
          self.annotations_of_page(pages[index]),
          light,
        ),
      )
    } else {
      op_lists.push([])
    }
  }
  self.append_page_content_multiple_ops(op_lists, fast~)
}

///|
/// Compatibility wrapper for `PdfDocument::show_annotation_bounding_boxes`.
pub fn pdf_show_annotation_bounding_boxes(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  light? : Bool = false,
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  document.show_annotation_bounding_boxes(page_numbers, light~, fast~)
}

///|
/// Draw bounding boxes around annotations and selected page-content objects.
pub fn PdfDocument::show_bounding_boxes(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  shape? : PdfRectangle? = None,
  light? : Bool = false,
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  let document = self.show_annotation_bounding_boxes(
    page_numbers,
    light~,
    fast~,
  )
  let pages = document.pages_of_pagetree()
  let selected_pages = @core.pdf_number_set(page_numbers)
  let op_lists : Array[Array[PdfContentOp]] = Array::new(
    capacity=pages.length(),
  )
  for index in 0..<pages.length() {
    let page_number = index + 1
    if selected_pages.contains(page_number) {
      op_lists.push(
        document.pdf_redact_page_content_box_ops(pages[index], shape, light),
      )
    } else {
      op_lists.push([])
    }
  }
  document.append_page_content_multiple_ops(op_lists, fast~)
}

///|
/// Compatibility wrapper for `PdfDocument::show_bounding_boxes`.
pub fn pdf_show_bounding_boxes(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  shape? : PdfRectangle? = None,
  light? : Bool = false,
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  document.show_bounding_boxes(page_numbers, shape~, light~, fast~)
}

///|
/// Compatibility wrapper matching cpdfredact's `show_bounding_boxes` order.
pub fn pdf_show_bounding_boxes_cpdf_order(
  fast : Bool,
  shape : PdfRectangle?,
  light : Bool,
  document : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  document.show_bounding_boxes(page_numbers, shape~, light~, fast~)
}
