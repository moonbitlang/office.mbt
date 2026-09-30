///|
// Vector graphics in the page model: a `GraphicItem` is a small display list
// of paths, clips, transforms, text and images, drawn in a coordinate space
// of its own. It is what vector image formats (SVG) lower to, and what
// anything else that needs more than axis-aligned rectangles can use.
//
// A graphic's space starts out as the page's (points, y down) translated to
// the item's `(x_pt, y_pt)`; `Transform` ops change it for the ops after
// them, and `Save`/`Restore` bracket such changes together with clips and
// transparency, in the manner of PDF's `q`/`Q`.

///|
/// An affine transformation `[a b c d e f]`, mapping `(x, y)` to
/// `(a*x + c*y + e, b*x + d*y + f)` (PDF's and SVG's convention).
pub(all) struct Matrix {
  a : Double
  b : Double
  c : Double
  d : Double
  e : Double
  f : Double
} derive(Eq, Debug, ToJson)

///|
/// The identity transformation.
pub let identity : Matrix = { a: 1, b: 0, c: 0, d: 1, e: 0, f: 0, }

///|
/// `self` applied after `other`: the transformation that maps a point
/// through `other` first, then through `self`.
pub fn Matrix::after(self : Matrix, other : Matrix) -> Matrix {
  {
    a: self.a * other.a + self.c * other.b,
    b: self.b * other.a + self.d * other.b,
    c: self.a * other.c + self.c * other.d,
    d: self.b * other.c + self.d * other.d,
    e: self.a * other.e + self.c * other.f + self.e,
    f: self.b * other.e + self.d * other.f + self.f,
  }
}

///|
/// Map a point.
pub fn Matrix::apply(self : Matrix, x : Double, y : Double) -> (Double, Double) {
  (self.a * x + self.c * y + self.e, self.b * x + self.d * y + self.f)
}

///|
/// One segment of a path. A path is a sequence of subpaths, each starting
/// with `MoveTo`; `Close` joins a subpath's end to its start.
pub(all) enum PathSegment {
  MoveTo(Double, Double)
  LineTo(Double, Double)
  /// A cubic Bézier curve: two control points, then the end point.
  CurveTo(Double, Double, Double, Double, Double, Double)
  /// An axis-aligned rectangle subpath: x, y (top-left), width, height.
  Rectangle(Double, Double, Double, Double)
  Close
} derive(Eq, Debug, ToJson)

///|
/// Which regions of a self-intersecting path are inside.
pub(all) enum FillRule {
  NonZero
  EvenOdd
} derive(Eq, Debug, ToJson)

///|
/// How the ends of an open stroked subpath are drawn.
pub(all) enum LineCap {
  ButtCap
  RoundCap
  SquareCap
} derive(Eq, Debug, ToJson)

///|
/// How the corners of a stroked path are drawn.
pub(all) enum LineJoin {
  MiterJoin
  RoundJoin
  BevelJoin
} derive(Eq, Debug, ToJson)

///|
/// How a path is stroked. `dash` is the dash pattern (lengths of dashes and
/// gaps, alternately; empty for a solid line) starting `dash_phase` into it.
pub(all) struct StrokeStyle {
  width : Double
  cap : LineCap
  join : LineJoin
  miter_limit : Double
  dash : Array[Double]
  dash_phase : Double
} derive(Eq, Debug, ToJson)

///|
/// A solid line one point wide with butt caps and miter joins (limit 10),
/// the initial stroke state of PDF.
pub fn StrokeStyle::default() -> StrokeStyle {
  {
    width: 1.0,
    cap: ButtCap,
    join: MiterJoin,
    miter_limit: 10.0,
    dash: [],
    dash_phase: 0.0,
  }
}

///|
/// A colour at a position (0 to 1) along a gradient.
pub(all) struct GradientStop {
  offset : Double
  color : Color
} derive(Eq, Debug, ToJson)

///|
/// A gradient: its colours vary along the line from `(x1, y1)` to
/// `(x2, y2)` (`Linear`), or between the circle of radius `r1` around
/// `(x1, y1)` and the one of radius `r2` around `(x2, y2)` (`Radial`); in
/// gradient space, which `transform` maps to the painted path's space.
/// Beyond its ends it keeps its end colours (SVG's `pad`). Stops are in
/// ascending order of offset, the first at 0 and the last at 1.
pub(all) struct Gradient {
  radial : Bool
  x1 : Double
  y1 : Double
  r1 : Double
  x2 : Double
  y2 : Double
  r2 : Double
  stops : Array[GradientStop]
  transform : Matrix
} derive(Eq, Debug, ToJson)

///|
/// What fills or strokes a path.
pub(all) enum Paint {
  Solid(Color)
  GradientPaint(Gradient)
} derive(Eq, Debug, ToJson)

///|
/// A path painted with an optional fill (by `fill_rule`) and an optional
/// stroke (in `stroke_style`); the fill goes first. A path with neither
/// paints nothing.
pub(all) struct PathItem {
  segments : Array[PathSegment]
  fill : Paint?
  fill_rule : FillRule
  stroke : Paint?
  stroke_style : StrokeStyle
} derive(Eq, Debug, ToJson)

///|
/// How `PaintedText` paints its glyphs (PDF's text rendering modes): filled
/// in the run's colour or not, and outlined `stroke_width` wide in
/// `stroke` or not. A run neither filled nor stroked is invisible but
/// still text (it extracts and searches).
pub(all) struct TextPaint {
  fill : Bool
  stroke : Color?
  stroke_width : Double
} derive(Eq, Debug, ToJson)

///|
/// One operation of a graphic, in order.
pub(all) enum GraphicOp {
  /// Remember the transformation, clip and alpha, for `Restore`.
  Save
  /// Return to the state of the matching `Save`.
  Restore
  /// Transform the space of the ops that follow: their coordinates are
  /// mapped through the matrix, then through the space before it.
  Transform(Matrix)
  /// Clip the ops that follow to the inside of the path.
  Clip(Array[PathSegment], FillRule)
  /// Constant opacity (0 to 1) of the fills and of the strokes that
  /// follow, text and images counting as fills.
  Alpha(Double, Double)
  Path(PathItem)
  /// A glyph run in the graphic's space (its baseline running along the
  /// space's x axis), filled in its colour.
  Text(GlyphRun)
  /// A glyph run painted otherwise: see `TextPaint`.
  PaintedText(GlyphRun, TextPaint)
  /// An image filling the rectangle at `(x_pt, y_pt)` (its top-left
  /// corner) `w_pt` by `h_pt` in the graphic's space.
  Image(ImageItem)
} derive(Eq, Debug, ToJson)

///|
/// A vector graphic whose space has its origin at `(x_pt, y_pt)` on the
/// page. Its ops draw in painter's order. Every `Save` has a matching
/// `Restore` (checked by `PageModel::validate`).
pub(all) struct GraphicItem {
  x_pt : Double
  y_pt : Double
  ops : Array[GraphicOp]
} derive(Eq, Debug, ToJson)
