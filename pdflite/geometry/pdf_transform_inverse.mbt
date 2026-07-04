///|
/// Returns the inverse of this matrix.
///
/// Raises `PdfError::MatrixNotInvertable` when the matrix determinant is zero
/// or too small to produce a finite inverse.
pub fn TransformMatrix::invert(
  self : TransformMatrix,
) -> TransformMatrix raise PdfError {
  let divisor = self.a * self.d - self.b * self.c
  if divisor == 0.0 {
    raise MatrixNotInvertable
  }
  let scale = 1.0 / divisor
  if scale == 0.0 {
    raise MatrixNotInvertable
  }
  {
    a: scale * self.d,
    b: scale * -self.b,
    c: scale * -self.c,
    d: scale * self.a,
    e: scale * (self.c * self.f - self.d * self.e),
    f: scale * (self.b * self.e - self.a * self.f),
  }
}

///|
/// Returns the inverse of a matrix.
///
/// Raises `PdfError::MatrixNotInvertable` when the matrix cannot be inverted.
pub fn transform_matrix_invert(
  matrix : TransformMatrix,
) -> TransformMatrix raise PdfError {
  matrix.invert()
}
