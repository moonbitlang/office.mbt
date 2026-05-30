///|
/// Read a shading dictionary and preserve the surrounding pattern matrix and
/// graphics-state dictionary supplied by the caller.
pub fn PdfDocument::content_read_shading(
  self : PdfDocument,
  shading_matrix : @geometry.TransformMatrix,
  shading_extgstate : PdfObject,
  shading : PdfObject,
) -> PdfContentShading raise PdfError {
  let shading_kind = match
    self.lookup_direct(pdf_content_shading_type_name, shading) {
    Some(PdfInteger(1)) => self.content_read_function_shading(shading)
    Some(PdfInteger(2)) => self.content_read_axial_shading(shading)
    Some(PdfInteger(3)) => self.content_read_radial_shading(shading)
    Some(PdfInteger(4)) => PdfContentFreeFormGouraudShading
    Some(PdfInteger(5)) => PdfContentLatticeFormGouraudShading
    Some(PdfInteger(6)) => PdfContentCoonsPatchMesh
    Some(PdfInteger(7)) => PdfContentTensorProductPatchMesh
    _ => PdfContentTensorProductPatchMesh
  }
  {
    shading_colourspace: match
      self.lookup_direct(pdf_content_shading_colourspace_name, shading) {
      Some(colourspace) => colourspace
      None => PdfNull
    },
    shading_background: self.lookup_direct(
      pdf_content_shading_background_name, shading,
    ),
    shading_bbox: self.lookup_direct(pdf_content_shading_bbox_name, shading),
    shading_antialias: match
      self.lookup_direct(pdf_content_shading_bbox_name, shading) {
      Some(PdfBoolean(true)) => true
      _ => false
    },
    shading_matrix,
    shading_extgstate,
    shading: shading_kind,
  }
}
