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
/// A cpdfcontent drawn path, pairing path geometry with paint flags.
pub(all) struct PdfDrawnPath {
  stroked : Bool
  filled : Bool
  path : PdfPath
} derive(Debug, Eq, ToJson)

///|
fn pdf_path_point_content_json(point : Point2) -> Json {
  Json::object(
    Map::of([("x", Json::number(point.x)), ("y", Json::number(point.y))]),
  )
}

///|
/// Return cpdfcontent's JSON shape for one path segment.
pub fn PdfPathSegment::content_json(self : PdfPathSegment) -> Json {
  match self {
    PdfPathStraight(start, finish) =>
      Json::object(
        Map::of([
          (
            "line",
            Json::array([
              pdf_path_point_content_json(start),
              pdf_path_point_content_json(finish),
            ]),
          ),
        ]),
      )
    PdfPathBezier(start, control1, control2, finish) =>
      Json::object(
        Map::of([
          (
            "bezier",
            Json::array([
              pdf_path_point_content_json(start),
              pdf_path_point_content_json(control1),
              pdf_path_point_content_json(control2),
              pdf_path_point_content_json(finish),
            ]),
          ),
        ]),
      )
  }
}

///|
/// Compatibility wrapper for `PdfPathSegment::content_json`.
pub fn pdf_path_segment_content_json(segment : PdfPathSegment) -> Json {
  segment.content_json()
}

///|
/// Return cpdfcontent's JSON shape for one subpath.
///
/// The hole flag is intentionally not emitted, matching `cpdfcontent.ml`.
pub fn PdfPathSubpath::content_json(self : PdfPathSubpath) -> Json {
  Json::object(
    Map::of([
      ("closed", Json::boolean(self.closure == PdfPathClosed)),
      (
        "segments",
        Json::array([ for segment in self.segments => segment.content_json() ]),
      ),
    ]),
  )
}

///|
/// Compatibility wrapper for `PdfPathSubpath::content_json`.
pub fn pdf_path_subpath_content_json(subpath : PdfPathSubpath) -> Json {
  subpath.content_json()
}

///|
fn pdf_path_winding_rule_content_string(rule : PdfPathWindingRule) -> String {
  match rule {
    PdfPathEvenOdd => "even-odd"
    PdfPathNonZero => "non-zero"
  }
}

///|
/// Return cpdfcontent's JSON shape for a drawn path.
pub fn PdfDrawnPath::content_json(self : PdfDrawnPath) -> Json {
  Json::object(
    Map::of([
      (
        "winding",
        Json::string(
          pdf_path_winding_rule_content_string(self.path.winding_rule),
        ),
      ),
      (
        "subpaths",
        Json::array(
          [
            for subpath in self.path.subpaths => subpath.content_json()
          ],
        ),
      ),
      ("stroked", Json::boolean(self.stroked)),
      ("filled", Json::boolean(self.filled)),
    ]),
  )
}

///|
/// Compatibility wrapper for `PdfDrawnPath::content_json`.
pub fn pdf_drawn_path_content_json(path : PdfDrawnPath) -> Json {
  path.content_json()
}

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
