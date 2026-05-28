///|
fn pdf_path_min_double(left : Double, right : Double) -> Double {
  if left < right {
    left
  } else {
    right
  }
}

///|
fn pdf_path_max_double(left : Double, right : Double) -> Double {
  if left > right {
    left
  } else {
    right
  }
}

///|
fn pdf_path_bounds_of_points(
  p0 : Point2,
  p1 : Point2,
  p2 : Point2,
  p3 : Point2,
) -> PdfRectangle {
  {
    min_x: pdf_path_min_double(
      pdf_path_min_double(p0.x, p1.x),
      pdf_path_min_double(p2.x, p3.x),
    ),
    min_y: pdf_path_min_double(
      pdf_path_min_double(p0.y, p1.y),
      pdf_path_min_double(p2.y, p3.y),
    ),
    max_x: pdf_path_max_double(
      pdf_path_max_double(p0.x, p1.x),
      pdf_path_max_double(p2.x, p3.x),
    ),
    max_y: pdf_path_max_double(
      pdf_path_max_double(p0.y, p1.y),
      pdf_path_max_double(p2.y, p3.y),
    ),
  }
}

///|
fn pdf_path_union_bounds(
  left : PdfRectangle,
  right : PdfRectangle,
) -> PdfRectangle {
  {
    min_x: pdf_path_min_double(left.min_x, right.min_x),
    min_y: pdf_path_min_double(left.min_y, right.min_y),
    max_x: pdf_path_max_double(left.max_x, right.max_x),
    max_y: pdf_path_max_double(left.max_y, right.max_y),
  }
}

///|
/// Return cpdfcontent's control-point bounding box for a path segment.
///
/// Bezier bounds intentionally include the two control points rather than
/// solving for curve extrema, matching `cpdfcontent.ml`'s `bbox_of_segment`.
pub fn PdfPathSegment::bounds(self : PdfPathSegment) -> PdfRectangle {
  match self {
    PdfPathStraight(start, finish) =>
      pdf_path_bounds_of_points(start, finish, start, finish)
    PdfPathBezier(start, control1, control2, finish) =>
      pdf_path_bounds_of_points(start, control1, control2, finish)
  }
}

///|
/// Compatibility wrapper for `PdfPathSegment::bounds`.
pub fn pdf_path_segment_bounds(segment : PdfPathSegment) -> PdfRectangle {
  segment.bounds()
}

///|
fn pdf_path_empty_bounds() -> PdfRectangle {
  { min_x: 0.0, min_y: 0.0, max_x: 0.0, max_y: 0.0 }
}

///|
/// Return cpdfcontent's axis-aligned bounding box for a path.
///
/// Empty paths return a zero rectangle, matching `cpdfcontent.ml`.
pub fn PdfPath::bounds(self : PdfPath) -> PdfRectangle {
  let mut found = false
  let mut bounds = pdf_path_empty_bounds()
  for subpath in self.subpaths {
    for segment in subpath.segments {
      let segment_bounds = segment.bounds()
      if found {
        bounds = pdf_path_union_bounds(bounds, segment_bounds)
      } else {
        bounds = segment_bounds
        found = true
      }
    }
  }
  bounds
}

///|
/// Compatibility wrapper for `PdfPath::bounds`.
pub fn pdf_path_bounds(path : PdfPath) -> PdfRectangle {
  path.bounds()
}

///|
fn PdfPath::pdf_path_bounds_optional(self : PdfPath) -> PdfRectangle? {
  let mut found = false
  let mut bounds = pdf_path_empty_bounds()
  for subpath in self.subpaths {
    for segment in subpath.segments {
      let segment_bounds = segment.bounds()
      if found {
        bounds = pdf_path_union_bounds(bounds, segment_bounds)
      } else {
        bounds = segment_bounds
        found = true
      }
    }
  }
  if found {
    Some(bounds)
  } else {
    None
  }
}
