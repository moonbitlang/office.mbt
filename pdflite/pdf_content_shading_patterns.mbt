///|
/// Read a tiling pattern as the current placeholder representation.
pub fn pdf_content_read_tiling_pattern(
  _pattern : PdfObject,
) -> PdfContentPattern {
  PdfContentColouredTilingPattern(PdfContentTiling)
}

///|
/// Read a `/PatternType 2` shading pattern dictionary.
pub fn PdfDocument::content_read_shading_pattern(
  self : PdfDocument,
  pattern : PdfObject,
) -> PdfContentPattern raise PdfError {
  let matrix = self.parse_matrix(pdf_content_shading_matrix_name, pattern)
  let extgstate = match
    self.lookup_direct(pdf_content_shading_extgstate_name, pattern) {
    Some(PdfDictionary(_) as dictionary) => dictionary
    _ => pdf_dictionary([])
  }
  match self.lookup_direct(pdf_content_shading_shading_name, pattern) {
    Some(shading) =>
      PdfContentShadingPattern(
        self.content_read_shading(matrix, extgstate, shading),
      )
    None => raise SoftError("No shading dictionary")
  }
}

///|
/// Look up and read a named pattern resource.
pub fn PdfDocument::content_read_pattern(
  self : PdfDocument,
  resources : PdfObject,
  name : PdfName,
) -> PdfContentPattern? raise PdfError {
  match self.lookup_direct(pdf_content_shading_pattern_name, resources) {
    Some(pattern_dictionary) =>
      match self.lookup_direct(name, pattern_dictionary) {
        Some(pattern) =>
          match
            self.lookup_direct(pdf_content_shading_pattern_type_name, pattern) {
            Some(PdfInteger(1)) =>
              Some(pdf_content_read_tiling_pattern(pattern))
            Some(PdfInteger(2)) =>
              Some(self.content_read_shading_pattern(pattern))
            _ => None
          }
        None => None
      }
    None => None
  }
}

///|
/// Function wrapper for `PdfDocument::content_read_pattern`.
pub fn pdf_content_read_pattern(
  document : PdfDocument,
  resources : PdfObject,
  name : PdfName,
) -> PdfContentPattern? raise PdfError {
  document.content_read_pattern(resources, name)
}
