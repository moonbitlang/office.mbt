///|
fn PdfDocument::pdf_page_stamp_transform_overlay(
  self : PdfDocument,
  overlay_page : @page.PdfPage,
  under_page : @page.PdfPage,
  relative_to_box : PdfName,
  position : @geometry.PdfPosition,
  topline : Bool,
  midline : Bool,
  scale_to_fit : Bool,
  fast : Bool,
) -> @page.PdfPage raise PdfError {
  let stamp_box = self.pdf_page_stamp_box(overlay_page, relative_to_box)
  let target_box = self.pdf_page_stamp_box(under_page, relative_to_box)
  let matrix = if scale_to_fit {
    pdf_page_stamp_scale_to_fit_matrix(stamp_box, target_box, relative_to_box)
  } else {
    pdf_page_stamp_position_matrix(
      stamp_box, target_box, relative_to_box, position, topline, midline,
    )
  }
  self.transform_annotations(matrix, overlay_page.rest)
  let transformed = self.prepend_operators(overlay_page, [Op_cm(matrix)], fast~)
  self.pdf_impose_change_pattern_matrices_page(matrix, transformed)
}
