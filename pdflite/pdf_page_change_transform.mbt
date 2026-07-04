///|
fn PdfDocument::pdf_page_transform_matrix_destinations(
  self : PdfDocument,
  matrices : ArrayView[(Int, @geometry.TransformMatrix)],
  page_reference_numbers : ArrayView[Int],
  transform_bookmarks : Bool,
) -> PdfDocument raise @core.PdfError {
  let pdf = if transform_bookmarks {
    self.pdf_page_transform_bookmarks_for_matrices(
      matrices, page_reference_numbers,
    )
  } else {
    self
  }
  pdf.pdf_page_transform_link_annotations_for_matrices(
    matrices, page_reference_numbers,
  )
  pdf.pdf_page_transform_open_action_for_matrices(
    matrices, page_reference_numbers,
  )
  pdf.pdf_page_transform_catalog_destinations_for_matrices(
    matrices, page_reference_numbers,
  )
  pdf.pdf_page_transform_destination_name_tree_for_matrices(
    matrices, page_reference_numbers,
  )
  pdf
}
