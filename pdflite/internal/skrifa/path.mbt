// Port of skrifa 0.42.1 `src/outline/path.rs` (FreeType path style, for
// 26.6 fixed point coordinates).

///|
const POINT_FLAG_ON_CURVE : Int = 0x01

///|
const POINT_FLAG_OFF_CURVE_CUBIC : Int = 0x80

///|
const POINT_FLAG_CURVE_MASK : Int = 0x81

///|
fn is_on_curve(flags : Int) -> Bool {
  (flags & POINT_FLAG_ON_CURVE) != 0
}

///|
fn is_off_curve_quad(flags : Int) -> Bool {
  (flags & POINT_FLAG_CURVE_MASK) == 0
}

///|
fn is_off_curve_cubic(flags : Int) -> Bool {
  (flags & POINT_FLAG_OFF_CURVE_CUBIC) != 0
}

///|
/// Combination of point coordinates (26.6 bits) and flags.
priv struct ContourPoint {
  x : Int
  y : Int
  flags : Int
}

///|
fn f26dot6_to_f32(v : Int) -> Float {
  F26Dot6::from_bits(v).to_f32()
}

///|
/// FreeType uses integer division on 26.6 to compute midpoints.
fn midpoint_i32(a : Int, b : Int) -> Int {
  (a + b) / 2
}

///|
fn ContourPoint::midpoint(
  self : ContourPoint,
  other : ContourPoint,
) -> ContourPoint {
  {
    x: midpoint_i32(self.x, other.x),
    y: midpoint_i32(self.y, other.y),
    flags: other.flags,
  }
}

///|
/// Converts a `glyf` outline described by points, flags and contour end
/// points to a sequence of path elements and invokes the appropriate
/// callback on the given pen for each.
///
/// Coordinates are 26.6 fixed point bit patterns.
fn to_path(
  xs : ArrayView[Int],
  ys : ArrayView[Int],
  flags : ArrayView[Int],
  contours : ArrayView[Int],
  pen : &OutlinePen,
) -> Unit raise ToPathError {
  let num_points = xs.length()
  for contour_ix in 0..<contours.length() {
    let start_ix = if contour_ix > 0 { contours[contour_ix - 1] + 1 } else { 0 }
    let end_ix = contours[contour_ix]
    if end_ix < start_ix || end_ix >= num_points {
      raise ContourOrder(contour_ix)
    }
    let n = end_ix - start_ix + 1
    if end_ix >= flags.length() {
      raise PointFlagMismatch(num_points=n, num_flags=flags.length())
    }
    let point = fn(i : Int) -> ContourPoint {
      { x: xs[start_ix + i], y: ys[start_ix + i], flags: flags[start_ix + i], }
    }
    contour_to_path_freetype(n, point, pen) catch {
      ExpectedCubic(ix) => raise ExpectedCubic(ix + start_ix)
      ExpectedQuad(ix) => raise ExpectedQuad(ix + start_ix)
      ExpectedQuadOrOnCurve(ix) => raise ExpectedQuadOrOnCurve(ix + start_ix)
      e => raise e
    }
  }
}

///|
fn contour_to_path_freetype(
  n : Int,
  point : (Int) -> ContourPoint,
  pen : &OutlinePen,
) -> Unit raise ToPathError {
  let first_point = point(0)
  let last_point = point(n - 1)
  // We don't accept an off curve cubic as the first point
  if is_off_curve_cubic(first_point.flags) {
    raise ExpectedQuadOrOnCurve(0)
  }
  // For FreeType style, we may need to omit the last point if we find the
  // first on curve there
  let mut omit_last = false
  let mut next_ix = 0
  // Find our starting point
  let start_point = if is_off_curve_quad(first_point.flags) {
    if is_on_curve(last_point.flags) {
      // The last point is an on curve, so let's start there
      omit_last = true
      last_point
    } else {
      // It's also an off curve, so take implicit midpoint
      last_point.midpoint(first_point)
    }
  } else {
    // We're starting with an on curve, so consume the point
    next_ix = 1
    first_point
  }
  pen.move_to(f26dot6_to_f32(start_point.x), f26dot6_to_f32(start_point.y))
  let state = PendingState::{ kind: 0, p0: start_point, p1: start_point, }
  if omit_last {
    let end_ix = n - 1
    for ix in next_ix..<n {
      if ix == end_ix {
        break
      }
      state.emit(ix, point(ix), pen)
    }
  } else {
    for ix in next_ix..<n {
      state.emit(ix, point(ix), pen)
    }
  }
  state.finish(0, start_point, pen)
}

///|
/// Pending state: kind 0 = empty, 1 = pending quad (p0), 2 = pending cubic
/// (p0), 3 = two pending cubics (p0, p1).
priv struct PendingState {
  mut kind : Int
  mut p0 : ContourPoint
  mut p1 : ContourPoint
}

///|
fn PendingState::emit(
  self : PendingState,
  ix : Int,
  point : ContourPoint,
  pen : &OutlinePen,
) -> Unit raise ToPathError {
  let flags = point.flags
  match self.kind {
    0 =>
      if is_off_curve_quad(flags) {
        self.kind = 1
        self.p0 = point
      } else if is_off_curve_cubic(flags) {
        self.kind = 2
        self.p0 = point
      } else {
        pen.line_to(f26dot6_to_f32(point.x), f26dot6_to_f32(point.y))
      }
    1 => {
      let quad = self.p0
      if is_off_curve_quad(flags) {
        let p = quad.midpoint(point)
        pen.quad_to(
          f26dot6_to_f32(quad.x),
          f26dot6_to_f32(quad.y),
          f26dot6_to_f32(p.x),
          f26dot6_to_f32(p.y),
        )
        self.kind = 1
        self.p0 = point
      } else if is_off_curve_cubic(flags) {
        raise ExpectedQuadOrOnCurve(ix)
      } else {
        pen.quad_to(
          f26dot6_to_f32(quad.x),
          f26dot6_to_f32(quad.y),
          f26dot6_to_f32(point.x),
          f26dot6_to_f32(point.y),
        )
        self.kind = 0
      }
    }
    2 =>
      if is_off_curve_cubic(flags) {
        self.kind = 3
        self.p1 = point
      } else {
        raise ExpectedCubic(ix)
      }
    _ => {
      let cubic0 = self.p0
      let cubic1 = self.p1
      if is_off_curve_quad(flags) {
        raise ExpectedCubic(ix)
      } else if is_off_curve_cubic(flags) {
        let p = cubic1.midpoint(point)
        pen.curve_to(
          f26dot6_to_f32(cubic0.x),
          f26dot6_to_f32(cubic0.y),
          f26dot6_to_f32(cubic1.x),
          f26dot6_to_f32(cubic1.y),
          f26dot6_to_f32(p.x),
          f26dot6_to_f32(p.y),
        )
        self.kind = 2
        self.p0 = point
      } else {
        pen.curve_to(
          f26dot6_to_f32(cubic0.x),
          f26dot6_to_f32(cubic0.y),
          f26dot6_to_f32(cubic1.x),
          f26dot6_to_f32(cubic1.y),
          f26dot6_to_f32(point.x),
          f26dot6_to_f32(point.y),
        )
        self.kind = 0
      }
    }
  }
}

///|
fn PendingState::finish(
  self : PendingState,
  start_ix : Int,
  start_point : ContourPoint,
  pen : &OutlinePen,
) -> Unit raise ToPathError {
  if self.kind != 0 {
    // We always want to end with an explicit on-curve
    self.emit(start_ix, { ..start_point, flags: POINT_FLAG_ON_CURVE, }, pen)
  }
  pen.close()
}
