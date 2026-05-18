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
fn pdf_redact_annotation_box_ops(
  rectangle : PdfRectangle,
  light : Bool,
) -> Array[PdfContentOp] {
  let stroke_colour = if light {
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
  annotations : ArrayView[PdfAnnotation],
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
  let op_lists : Array[Array[PdfContentOp]] = []
  for index in 0..<pages.length() {
    let page_number = index + 1
    if pdf_tweak_page_selected(page_numbers, page_number) {
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
