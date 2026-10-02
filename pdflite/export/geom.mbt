// Geometric primitives (port of krilla's `geom` module, backed by
// `Double`s instead of tiny-skia's `f32`s).

///|
/// A point.
pub(all) struct Point {
  x : Double
  y : Double
} derive(Eq, Debug)

///|
pub fn Point::from_xy(x : Double, y : Double) -> Point {
  { x, y, }
}

///|
/// A size.
pub(all) struct Size {
  width : Double
  height : Double
} derive(Eq, Debug)

///|
/// Create a new size; `None` unless both dimensions are positive and finite.
pub fn Size::from_wh(width : Double, height : Double) -> Size? {
  if width > 0.0 && height > 0.0 && !width.is_inf() && !height.is_inf() {
    Some({ width, height, })
  } else {
    None
  }
}

///|
/// A rectangle.
pub(all) struct Rect {
  left : Double
  top : Double
  right : Double
  bottom : Double
} derive(Eq, Debug)

///|
/// Create a rectangle from its left, top, right and bottom edges; `None` if
/// it is not well-formed.
pub fn Rect::from_ltrb(
  left : Double,
  top : Double,
  right : Double,
  bottom : Double,
) -> Rect? {
  if left <= right &&
    top <= bottom &&
    !left.is_nan() &&
    !top.is_nan() &&
    !right.is_nan() &&
    !bottom.is_nan() {
    Some({ left, top, right, bottom, })
  } else {
    None
  }
}

///|
pub fn Rect::from_xywh(x : Double, y : Double, w : Double, h : Double) -> Rect? {
  Rect::from_ltrb(x, y, x + w, y + h)
}

///|
pub fn Rect::width(self : Rect) -> Double {
  self.right - self.left
}

///|
pub fn Rect::height(self : Rect) -> Double {
  self.bottom - self.top
}

///|
/// The smallest rectangle containing both rectangles.
pub fn Rect::union(self : Rect, other : Rect) -> Rect {
  {
    left: @cmp.minimum(self.left, other.left),
    top: @cmp.minimum(self.top, other.top),
    right: @cmp.maximum(self.right, other.right),
    bottom: @cmp.maximum(self.bottom, other.bottom),
  }
}

///|
/// The bounding box of the transformed rectangle.
pub fn Rect::transform(self : Rect, ts : Transform) -> Rect {
  let pts : ReadOnlyArray[Point] = [
    ts.apply(self.left, self.top),
    ts.apply(self.right, self.top),
    ts.apply(self.right, self.bottom),
    ts.apply(self.left, self.bottom),
  ]
  bbox_of_points(pts).unwrap()
}

///|
/// The bounding box of some points.
pub fn bbox_of_points(pts : ArrayView[Point]) -> Rect? {
  if pts.is_empty() {
    return None
  }
  let mut l = pts[0].x
  let mut t = pts[0].y
  let mut r = pts[0].x
  let mut b = pts[0].y
  for p in pts {
    l = @cmp.minimum(l, p.x)
    t = @cmp.minimum(t, p.y)
    r = @cmp.maximum(r, p.x)
    b = @cmp.maximum(b, p.y)
  }
  Some({ left: l, top: t, right: r, bottom: b, })
}

///|
/// The PDF array of a rectangle (`[left top right bottom]` in the
/// rectangle's own coordinates).
pub fn Rect::to_pdf(self : Rect) -> Obj {
  pdf_rect(self.left, self.top, self.right, self.bottom)
}

///|
/// An affine transformation `[sx ky kx sy tx ty]`.
pub(all) struct Transform {
  sx : Double
  ky : Double
  kx : Double
  sy : Double
  tx : Double
  ty : Double
} derive(Eq, Debug)

///|
pub fn Transform::identity() -> Transform {
  { sx: 1.0, ky: 0.0, kx: 0.0, sy: 1.0, tx: 0.0, ty: 0.0, }
}

///|
pub fn Transform::from_row(
  sx : Double,
  ky : Double,
  kx : Double,
  sy : Double,
  tx : Double,
  ty : Double,
) -> Transform {
  { sx, ky, kx, sy, tx, ty, }
}

///|
pub fn Transform::from_translate(tx : Double, ty : Double) -> Transform {
  { sx: 1.0, ky: 0.0, kx: 0.0, sy: 1.0, tx, ty, }
}

///|
pub fn Transform::from_scale(sx : Double, sy : Double) -> Transform {
  { sx, ky: 0.0, kx: 0.0, sy, tx: 0.0, ty: 0.0, }
}

///|
pub fn Transform::is_identity(self : Transform) -> Bool {
  self == Transform::identity()
}

///|
/// `self × other`: apply `other` first, then `self` (tiny-skia
/// `pre_concat`).
pub fn Transform::pre_concat(self : Transform, other : Transform) -> Transform {
  concat(self, other)
}

///|
/// `other × self`: apply `self` first, then `other` (tiny-skia
/// `post_concat`).
pub fn Transform::post_concat(self : Transform, other : Transform) -> Transform {
  concat(other, self)
}

///|
fn concat(a : Transform, b : Transform) -> Transform {
  {
    sx: a.sx * b.sx + a.kx * b.ky,
    ky: a.ky * b.sx + a.sy * b.ky,
    kx: a.sx * b.kx + a.kx * b.sy,
    sy: a.ky * b.kx + a.sy * b.sy,
    tx: a.sx * b.tx + a.kx * b.ty + a.tx,
    ty: a.ky * b.tx + a.sy * b.ty + a.ty,
  }
}

///|
pub fn Transform::apply(self : Transform, x : Double, y : Double) -> Point {
  {
    x: self.sx * x + self.kx * y + self.tx,
    y: self.ky * x + self.sy * y + self.ty,
  }
}

///|
pub fn Transform::invert(self : Transform) -> Transform? {
  let det = self.sx * self.sy - self.ky * self.kx
  if det == 0.0 || det.is_nan() {
    return None
  }
  let inv = 1.0 / det
  let sx = self.sy * inv
  let ky = -self.ky * inv
  let kx = -self.kx * inv
  let sy = self.sx * inv
  Some({
    sx,
    ky,
    kx,
    sy,
    tx: -(sx * self.tx + kx * self.ty),
    ty: -(ky * self.tx + sy * self.ty),
  })
}

///|
/// The PDF matrix array.
pub fn Transform::to_pdf(self : Transform) -> Obj {
  Arr([
    Real(self.sx),
    Real(self.ky),
    Real(self.kx),
    Real(self.sy),
    Real(self.tx),
    Real(self.ty),
  ])
}

///|
/// A path segment.
pub(all) enum PathSegment {
  MoveTo(Point)
  LineTo(Point)
  QuadTo(Point, Point)
  CubicTo(Point, Point, Point)
  Close
} derive(Eq, Debug)

///|
/// A path.
pub(all) struct Path {
  segments : Array[PathSegment]
} derive(Eq, Debug)

///|
/// The bounding box of the points of the path (control points included),
/// like tiny-skia's `Path::bounds`.
pub fn Path::bounds(self : Path) -> Rect? {
  let pts = []
  for seg in self.segments {
    match seg {
      MoveTo(p) | LineTo(p) => pts.push(p)
      QuadTo(p1, p2) => {
        pts.push(p1)
        pts.push(p2)
      }
      CubicTo(p1, p2, p3) => {
        pts.push(p1)
        pts.push(p2)
        pts.push(p3)
      }
      Close => ()
    }
  }
  bbox_of_points(pts)
}

///|
pub fn Path::transform(self : Path, ts : Transform) -> Path {
  let f = (p : Point) => ts.apply(p.x, p.y)
  {
    segments: self.segments.map(seg => {
      match seg {
        MoveTo(p) => MoveTo(f(p))
        LineTo(p) => LineTo(f(p))
        QuadTo(p1, p2) => QuadTo(f(p1), f(p2))
        CubicTo(p1, p2, p3) => CubicTo(f(p1), f(p2), f(p3))
        Close => Close
      }
    }),
  }
}

///|
/// A path builder (like tiny-skia's: `finish` returns `None` for paths
/// without any drawing segments).
pub struct PathBuilder {
  segments : Array[PathSegment]
  mut move_pending : Bool
}

///|
pub fn PathBuilder::new() -> PathBuilder {
  { segments: [], move_pending: false, }
}

///|
pub fn PathBuilder::move_to(self : PathBuilder, x : Double, y : Double) -> Unit {
  // Consecutive move-tos replace each other.
  if self.segments.length() > 0 &&
    self.segments[self.segments.length() - 1] is MoveTo(_) {
    self.segments[self.segments.length() - 1] = MoveTo({ x, y, })
  } else {
    self.segments.push(MoveTo({ x, y, }))
  }
  self.move_pending = false
}

///|
fn PathBuilder::last_point(self : PathBuilder) -> Point {
  // The start of the last subpath after a close, else the last point.
  let mut start = Point::{ x: 0.0, y: 0.0, }
  let mut last = Point::{ x: 0.0, y: 0.0, }
  for seg in self.segments {
    match seg {
      MoveTo(p) => {
        start = p
        last = p
      }
      LineTo(p) | QuadTo(_, p) | CubicTo(_, _, p) => last = p
      Close => last = start
    }
  }
  last
}

///|
fn PathBuilder::inject_move(self : PathBuilder) -> Unit {
  if self.segments.is_empty() {
    self.segments.push(MoveTo({ x: 0.0, y: 0.0, }))
  } else if self.segments[self.segments.length() - 1] is Close {
    self.segments.push(MoveTo(self.last_point()))
  }
}

///|
pub fn PathBuilder::line_to(self : PathBuilder, x : Double, y : Double) -> Unit {
  self.inject_move()
  self.segments.push(LineTo({ x, y, }))
}

///|
pub fn PathBuilder::quad_to(
  self : PathBuilder,
  x1 : Double,
  y1 : Double,
  x : Double,
  y : Double,
) -> Unit {
  self.inject_move()
  self.segments.push(QuadTo({ x: x1, y: y1, }, { x, y, }))
}

///|
pub fn PathBuilder::cubic_to(
  self : PathBuilder,
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
  x : Double,
  y : Double,
) -> Unit {
  self.inject_move()
  self.segments.push(CubicTo({ x: x1, y: y1, }, { x: x2, y: y2, }, { x, y, }))
}

///|
pub fn PathBuilder::close(self : PathBuilder) -> Unit {
  if self.segments.length() > 0 &&
    !(self.segments[self.segments.length() - 1] is Close) {
    self.segments.push(Close)
  }
}

///|
pub fn PathBuilder::push_rect(self : PathBuilder, rect : Rect) -> Unit {
  self.move_to(rect.left, rect.top)
  self.line_to(rect.right, rect.top)
  self.line_to(rect.right, rect.bottom)
  self.line_to(rect.left, rect.bottom)
  self.close()
}

///|
pub fn PathBuilder::finish(self : PathBuilder) -> Path? {
  // Drop a trailing move-to.
  let segments = self.segments.copy()
  if segments.length() > 0 && segments[segments.length() - 1] is MoveTo(_) {
    segments.pop() |> ignore
  }
  if segments.length() <= 1 {
    return None
  }
  Some({ segments, })
}
