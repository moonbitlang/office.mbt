///|
fn PdfDocument::pdf_content_shading_domain4(
  self : PdfDocument,
  shading : @syntax.PdfObject,
) -> (Double, Double, Double, Double) raise PdfError {
  match self.lookup_direct(pdf_content_shading_domain_name, shading) {
    Some(PdfArray(values)) if values.length() == 4 =>
      (
        self.get_number(values[0]),
        self.get_number(values[1]),
        self.get_number(values[2]),
        self.get_number(values[3]),
      )
    _ => (0.0, 1.0, 0.0, 1.0)
  }
}

///|
fn PdfDocument::pdf_content_shading_domain2(
  self : PdfDocument,
  shading : @syntax.PdfObject,
) -> (Double, Double) raise PdfError {
  match self.lookup_direct(pdf_content_shading_domain_name, shading) {
    Some(PdfArray(values)) if values.length() == 2 =>
      (self.get_number(values[0]), self.get_number(values[1]))
    _ => (0.0, 1.0)
  }
}

///|
fn PdfDocument::pdf_content_shading_coords4(
  self : PdfDocument,
  shading : @syntax.PdfObject,
) -> (Double, Double, Double, Double) raise PdfError {
  match self.lookup_direct(pdf_content_shading_coords_name, shading) {
    Some(PdfArray(values)) if values.length() == 4 =>
      (
        self.get_number(values[0]),
        self.get_number(values[1]),
        self.get_number(values[2]),
        self.get_number(values[3]),
      )
    _ => (0.0, 0.0, 0.0, 0.0)
  }
}

///|
fn PdfDocument::pdf_content_shading_coords6(
  self : PdfDocument,
  shading : @syntax.PdfObject,
) -> (Double, Double, Double, Double, Double, Double) raise PdfError {
  match self.lookup_direct(pdf_content_shading_coords_name, shading) {
    Some(PdfArray(values)) if values.length() == 6 =>
      (
        self.get_number(values[0]),
        self.get_number(values[1]),
        self.get_number(values[2]),
        self.get_number(values[3]),
        self.get_number(values[4]),
        self.get_number(values[5]),
      )
    _ => (0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
  }
}

///|
fn PdfDocument::pdf_content_shading_extend(
  self : PdfDocument,
  shading : @syntax.PdfObject,
) -> (Bool, Bool) {
  match self.lookup_direct(pdf_content_shading_extend_name, shading) {
    Some(PdfArray([PdfBoolean(first), PdfBoolean(second)])) => (first, second)
    _ => (false, false)
  }
}
