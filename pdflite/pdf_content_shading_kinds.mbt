///|
/// Read a `/ShadingType 1` function-based shading dictionary.
pub fn PdfDocument::content_read_function_shading(
  self : PdfDocument,
  shading : @syntax.PdfObject,
) -> PdfContentShadingKind raise PdfError {
  PdfContentFunctionShading({
    funshading_domain: self.pdf_content_shading_domain4(shading),
    funshading_matrix: self.parse_matrix(
      pdf_content_shading_matrix_name, shading,
    ),
    funshading_function: self.pdf_content_shading_function_or_default(
      self.lookup_direct(pdf_content_shading_function_name, shading),
    ),
  })
}

///|
/// Read a `/ShadingType 3` radial shading dictionary.
pub fn PdfDocument::content_read_radial_shading(
  self : PdfDocument,
  shading : @syntax.PdfObject,
) -> PdfContentShadingKind raise PdfError {
  PdfContentRadialShading({
    radialshading_coords: self.pdf_content_shading_coords6(shading),
    radialshading_domain: self.pdf_content_shading_domain2(shading),
    radialshading_function: self.pdf_content_shading_functions(shading),
    radialshading_extend: self.pdf_content_shading_extend(shading),
  })
}

///|
/// Read a `/ShadingType 2` axial shading dictionary.
pub fn PdfDocument::content_read_axial_shading(
  self : PdfDocument,
  shading : @syntax.PdfObject,
) -> PdfContentShadingKind raise PdfError {
  PdfContentAxialShading({
    axialshading_coords: self.pdf_content_shading_coords4(shading),
    axialshading_domain: self.pdf_content_shading_domain2(shading),
    axialshading_function: self.pdf_content_shading_functions(shading),
    axialshading_extend: self.pdf_content_shading_extend(shading),
  })
}
