///|
/// Transform every point in a path segment.
pub fn PdfPathSegment::transform(
  self : PdfPathSegment,
  matrix : TransformMatrix,
) -> PdfPathSegment {
  match self {
    PdfPathStraight(start, finish) =>
      PdfPathStraight(matrix.apply(start), matrix.apply(finish))
    PdfPathBezier(start, control1, control2, finish) =>
      PdfPathBezier(
        matrix.apply(start),
        matrix.apply(control1),
        matrix.apply(control2),
        matrix.apply(finish),
      )
  }
}

///|
/// Compatibility wrapper for `PdfPathSegment::transform`.
pub fn pdf_path_segment_transform(
  segment : PdfPathSegment,
  matrix : TransformMatrix,
) -> PdfPathSegment {
  segment.transform(matrix)
}

///|
fn pdf_path_subpath_transform(
  subpath : PdfPathSubpath,
  matrix : TransformMatrix,
) -> PdfPathSubpath {
  {
    hole: subpath.hole,
    closure: subpath.closure,
    segments: [
      for segment in subpath.segments => segment.transform(matrix)
    ],
  }
}

///|
/// Transform every point in a path.
pub fn PdfPath::transform(self : PdfPath, matrix : TransformMatrix) -> PdfPath {
  {
    winding_rule: self.winding_rule,
    subpaths: [
      for subpath in self.subpaths => {
        pdf_path_subpath_transform(subpath, matrix)
      }
    ],
  }
}

///|
/// Compatibility wrapper for `PdfPath::transform`.
pub fn pdf_path_transform(path : PdfPath, matrix : TransformMatrix) -> PdfPath {
  path.transform(matrix)
}
