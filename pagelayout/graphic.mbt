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
/// with `MoveTo` or `Rectangle`; `LineTo`, `CurveTo` and `Close` continue
/// from the current point, so they need one before them (checked by
/// `PageModel::validate`). `Close` joins a subpath's end to its start, which
/// becomes the current point.
pub(all) enum PathSegment {
  MoveTo(Double, Double)
  LineTo(Double, Double)
  /// A cubic Bézier curve: two control points, then the end point.
  CurveTo(Double, Double, Double, Double, Double, Double)
  /// An axis-aligned rectangle, a closed subpath of its own: x, y (its
  /// top-left corner), width, height. It starts at the bottom-left corner
  /// `(x, y + height)` and runs to the bottom-right, top-right and top-left
  /// corners before closing, counter-clockwise as seen on the page when
  /// the width and height are positive (as PDF's `re` does with positive
  /// extents in its y-up space). Its start is the current point after it.
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
/// How wide a stroke is. PDF and SVG disagree about a width of 0 (the
/// thinnest line a device can draw in PDF, nothing at all in SVG), so a
/// `Width` must be positive (checked by `PageModel::validate`) and the
/// thinnest line is asked for explicitly.
pub(all) enum StrokeWidth {
  /// This many units of the space the stroke is drawn in.
  Width(Double)
  /// The thinnest line the device can draw, whatever the transformation:
  /// PDF's line width 0; in SVG a non-scaling stroke one pixel wide. Its
  /// dashes, like any stroke's, are measured in the space it is drawn in
  /// (not the device's), so SVG draws a dashed hairline as its dashes,
  /// each a solid hairline; glyph outlines cannot be drawn so, and text is
  /// not outlined with a dashed hairline (checked by `PageModel::validate`).
  Hairline
} derive(Eq, Debug, ToJson)

///|
/// How a path is stroked. `dash` is the dash pattern (lengths of dashes and
/// gaps, alternately, at least one of them positive; empty for a solid
/// line) starting `dash_phase` into it. The miter limit is at least 1.
pub(all) struct StrokeStyle {
  width : StrokeWidth
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
    width: Width(1.0),
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
/// Where a gradient's colours vary, in gradient space: offset 0 is at its
/// start and offset 1 at its end.
pub(all) enum GradientShape {
  /// Along the line from `(x1, y1)` to `(x2, y2)`, constant across it
  /// (PDF's axial shading, SVG's `<linearGradient>`).
  Linear(x1~ : Double, y1~ : Double, x2~ : Double, y2~ : Double)
  /// From the circle of radius `r1` around `(x1, y1)` to the one of radius
  /// `r2` around `(x2, y2)` (PDF's radial shading; SVG's `<radialGradient>`
  /// with focal circle `fx fy fr` = `x1 y1 r1` and end circle `cx cy r` =
  /// `x2 y2 r2`).
  Radial(
    x1~ : Double,
    y1~ : Double,
    r1~ : Double,
    x2~ : Double,
    y2~ : Double,
    r2~ : Double
  )
} derive(Eq, Debug, ToJson)

///|
/// A gradient: its colours vary over `shape`, in gradient space, which
/// `transform` maps to the painted path's space. Beyond its ends it keeps
/// its end colours (SVG's `pad`). Stops are in ascending order of offset,
/// the first at 0 and the last at 1. Stops at the same offset change the
/// colour sharply there, the later one taking over at the offset itself;
/// at offset 0 that leaves only the last of them to count, and at offset
/// 1 only the first.
///
/// A gradient whose shape has no extent paints its last stop's colour
/// everywhere (see `Gradient::degenerate_color`).
pub(all) struct Gradient {
  shape : GradientShape
  stops : Array[GradientStop]
  transform : Matrix
} derive(Eq, Debug, ToJson)

///|
/// The one colour a gradient without extent paints, its last stop's: a
/// linear gradient whose ends coincide, a radial one whose end circle has
/// radius 0 (both as SVG specifies), or one whose circles coincide. `None`
/// for any other gradient (or one without stops). PDF's shadings leave
/// such shapes undefined, and renderers disagree about them, so both
/// backends paint the colour, not a shading.
pub fn Gradient::degenerate_color(self : Gradient) -> Color? {
  let degenerate = match self.shape {
    Linear(x1~, y1~, x2~, y2~) => x1 == x2 && y1 == y2
    Radial(x1~, y1~, r1~, x2~, y2~, r2~) =>
      r2 == 0.0 || (x1 == x2 && y1 == y2 && r1 == r2)
  }
  if degenerate && !self.stops.is_empty() {
    Some(self.stops[self.stops.length() - 1].color)
  } else {
    None
  }
}

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
/// in the run's colour or not, and outlined in `stroke` or not. An outline
/// is stroked in `stroke_style` as a path would be, wholly: nothing of the
/// stroke style of the paths before it carries over. A run neither filled
/// nor stroked is invisible but still text (it extracts and searches).
pub(all) struct TextPaint {
  fill : Bool
  stroke : Color?
  stroke_style : StrokeStyle
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
  /// follow; text and images count as fills, text outlines as strokes.
  Alpha(Double, Double)
  Path(PathItem)
  /// A glyph run in the graphic's space (its baseline running along the
  /// space's x axis), filled in its colour.
  Text(GlyphRun)
  /// A glyph run painted otherwise: see `TextPaint`.
  PaintedText(GlyphRun, TextPaint)
  /// An image stretched to fill the rectangle at `(x_pt, y_pt)` (its
  /// top-left corner) `w_pt` by `h_pt` in the graphic's space, whatever
  /// its own aspect ratio.
  Image(ImageItem)
} derive(Eq, Debug, ToJson)

///|
/// A vector graphic whose space has its origin at `(x_pt, y_pt)` on the
/// page. Its ops draw in painter's order. Every `Save` has a matching
/// `Restore`, and every number is finite (checked, with the rest of the
/// ops' requirements, by `PageModel::validate`).
///
/// Every number is also within the range a PDF reader is sure to hold in
/// a real, ±3.403e38 (PDF 32000-1, Annex C), and so are the
/// transformations as they compose from the page and where each gradient
/// lands on it (also checked by `validate`). Annex C has more limits a
/// graphic cannot be checked against: reals nearer 0 than about 1.175e-38
/// read as 0, older readers keep only about five significant digits, and
/// integers are sure only up to 2147483647 in magnitude. The PDF backend
/// writes a graphic's numbers exactly (an integral one beyond 2147483647
/// with a decimal point, so that it reads as a real), leaving precision
/// beyond five digits to the readers that keep it.
pub(all) struct GraphicItem {
  x_pt : Double
  y_pt : Double
  ops : Array[GraphicOp]
} derive(Eq, Debug, ToJson)
