///|
/// Fill rule for a cpdf-style path.
pub(all) enum PdfPathWindingRule {
  PdfPathEvenOdd
  PdfPathNonZero
} derive(Debug, Eq, ToJson)

///|
/// One straight or Bezier path segment.
pub(all) enum PdfPathSegment {
  PdfPathStraight(Point2, Point2)
  PdfPathBezier(Point2, Point2, Point2, Point2)
} derive(Debug, Eq, ToJson)

///|
/// Whether a subpath is a hole in the containing path.
pub(all) enum PdfPathHole {
  PdfPathHole
  PdfPathNotHole
} derive(Debug, Eq, ToJson)

///|
/// Whether a subpath is open or closed.
pub(all) enum PdfPathClosure {
  PdfPathClosed
  PdfPathOpen
} derive(Debug, Eq, ToJson)

///|
/// A cpdf-style subpath.
pub(all) struct PdfPathSubpath {
  hole : PdfPathHole
  closure : PdfPathClosure
  segments : Array[PdfPathSegment]
} derive(Debug, Eq, ToJson)

///|
/// A cpdf-style path.
pub(all) struct PdfPath {
  winding_rule : PdfPathWindingRule
  subpaths : Array[PdfPathSubpath]
} derive(Debug, Eq, ToJson)

///|
/// Bezier control-line factor used by cpdf for circular arcs.
pub let pdf_shape_kappa : Double = (2.0.sqrt() - 1.0) / 3.0 * 4.0

///|
fn pdf_shape_mod_float(value : Double, modulus : Double) -> Double {
  value - (value / modulus).floor() * modulus
}

///|
/// Restrict an angle to the closest multiple of `step`, modulo `2 * pi`.
pub fn pdf_restrict_angle(step : Double, angle : Double) -> Double {
  let full = 2.0 * @math.PI
  let lower = pdf_shape_mod_float((angle / step).floor() * step, full)
  let upper = pdf_shape_mod_float(lower + step, full)
  if (lower - angle).abs() < (upper - angle).abs() {
    lower
  } else {
    upper
  }
}

///|
fn pdf_shape_transform_point(
  center_x : Double,
  center_y : Double,
  radius : Double,
  angle : Double,
  point : Point2,
) -> Point2 {
  let x = point.x * radius
  let y = point.y * radius
  point2(
    center_x + x * @math.cos(angle) - y * @math.sin(angle),
    center_y + x * @math.sin(angle) + y * @math.cos(angle),
  )
}

///|
fn pdf_shape_quarter(
  angle : Double,
  center_x : Double,
  center_y : Double,
  radius : Double,
) -> PdfPathSegment {
  PdfPathBezier(
    pdf_shape_transform_point(
      center_x,
      center_y,
      radius,
      angle,
      point2(1.0, 0.0),
    ),
    pdf_shape_transform_point(
      center_x,
      center_y,
      radius,
      angle,
      point2(1.0, pdf_shape_kappa),
    ),
    pdf_shape_transform_point(
      center_x,
      center_y,
      radius,
      angle,
      point2(pdf_shape_kappa, 1.0),
    ),
    pdf_shape_transform_point(
      center_x,
      center_y,
      radius,
      angle,
      point2(0.0, 1.0),
    ),
  )
}

///|
fn pdf_path_segment_end(segment : PdfPathSegment) -> Point2 {
  match segment {
    PdfPathStraight(_, end) => end
    PdfPathBezier(_, _, _, end) => end
  }
}

///|
fn pdf_path_segment_with_start(
  segment : PdfPathSegment,
  start : Point2,
) -> PdfPathSegment {
  match segment {
    PdfPathStraight(_, end) => PdfPathStraight(start, end)
    PdfPathBezier(_, control1, control2, end) =>
      PdfPathBezier(start, control1, control2, end)
  }
}

///|
fn pdf_shape_join_segments(
  segments : ArrayView[PdfPathSegment],
) -> Array[PdfPathSegment] {
  if segments.length() <= 1 {
    segments.to_owned()
  } else {
    let output : Array[PdfPathSegment] = [segments[0]]
    let mut previous_end = pdf_path_segment_end(segments[0])
    for index in 1..<segments.length() {
      let adjusted = pdf_path_segment_with_start(segments[index], previous_end)
      output.push(adjusted)
      previous_end = pdf_path_segment_end(adjusted)
    }
    output
  }
}

///|
fn pdf_path_subpath(
  hole : PdfPathHole,
  closure : PdfPathClosure,
  segments : ArrayView[PdfPathSegment],
) -> PdfPathSubpath {
  { hole, closure, segments: segments.to_owned() }
}

///|
fn pdf_path(
  winding_rule : PdfPathWindingRule,
  subpaths : ArrayView[PdfPathSubpath],
) -> PdfPath {
  { winding_rule, subpaths: subpaths.to_owned() }
}

///|
/// Build a cpdf-style circular path from four Bezier quarter arcs.
pub fn pdf_shape_circle(
  center_x : Double,
  center_y : Double,
  radius : Double,
) -> PdfPath {
  let segments = pdf_shape_join_segments([
    pdf_shape_quarter(0.0, center_x, center_y, radius),
    pdf_shape_quarter(@math.PI / 2.0, center_x, center_y, radius),
    pdf_shape_quarter(@math.PI, center_x, center_y, radius),
    pdf_shape_quarter(3.0 * @math.PI / 2.0, center_x, center_y, radius),
  ])
  pdf_path(PdfPathNonZero, [
    pdf_path_subpath(PdfPathNotHole, PdfPathClosed, segments),
  ])
}

///|
/// Build a cpdf-style rectangle path from a top-left point, width, and height.
pub fn pdf_shape_rectangle(
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> PdfPath {
  pdf_path(PdfPathEvenOdd, [
    pdf_path_subpath(PdfPathNotHole, PdfPathClosed, [
      PdfPathStraight(point2(x, y), point2(x + width, y)),
      PdfPathStraight(point2(x + width, y), point2(x + width, y + height)),
      PdfPathStraight(point2(x + width, y + height), point2(x, y + height)),
      PdfPathStraight(point2(x, y + height), point2(x, y)),
    ]),
  ])
}
