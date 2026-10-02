// Colors and paints (port of krilla's `graphics::color` and
// `graphics::paint`).

///|
/// A regular (process) color with 8-bit components.
pub(all) enum RegularColor {
  Rgb(Int, Int, Int)
  Luma(Int)
  Cmyk(Int, Int, Int, Int)
} derive(Eq, Debug)

///|
/// The colorant of a separation color space.
pub(all) enum SeparationColorant {
  AllColorants
  NoColorant
  Custom(String)
} derive(Eq, Debug)

///|
/// A separation color space: a colorant with a fallback color.
pub(all) struct SeparationSpace {
  colorant : SeparationColorant
  fallback : RegularColor
} derive(Eq, Debug)

///|
/// A color.
pub(all) enum Color {
  Regular(RegularColor)
  /// A separation (spot) color with an 8-bit tint.
  Separation(Int, SeparationSpace)
} derive(Eq, Debug)

///|
pub fn Color::rgb(r : Int, g : Int, b : Int) -> Color {
  Regular(Rgb(r, g, b))
}

///|
pub fn Color::black() -> Color {
  Regular(Rgb(0, 0, 0))
}

///|
/// The components of the color in its PDF color space.
pub fn Color::to_pdf_color(self : Color) -> Array[Double] {
  match self {
    Regular(c) => c.to_pdf_color()
    Separation(tint, _) => [tint.to_double() / 255.0]
  }
}

///|
pub fn RegularColor::to_pdf_color(self : RegularColor) -> Array[Double] {
  let f = (v : Int) => v.to_double() / 255.0
  match self {
    Rgb(r, g, b) => [f(r), f(g), f(b)]
    Luma(l) => [f(l)]
    Cmyk(c, m, y, k) => [f(c), f(m), f(y), f(k)]
  }
}

///|
/// The rgb value of a color, if it is an rgb color.
pub fn Color::as_rgb(self : Color) -> (Int, Int, Int)? {
  match self {
    Regular(Rgb(r, g, b)) => Some((r, g, b))
    _ => None
  }
}

///|
/// A gradient stop.
pub(all) struct Stop {
  /// The offset of the stop (between 0 and 1).
  offset : Double
  color : Color
  /// The opacity of the stop (between 0 and 1).
  opacity : Double
} derive(Eq, Debug)

///|
/// How to extend a gradient beyond its stops.
pub(all) enum SpreadMethod {
  Pad
  Reflect
  Repeat
} derive(Eq, Debug)

///|
pub(all) struct LinearGradient {
  x1 : Double
  y1 : Double
  x2 : Double
  y2 : Double
  transform : Transform
  spread_method : SpreadMethod
  stops : Array[Stop]
  anti_alias : Bool
} derive(Eq, Debug)

///|
pub(all) struct RadialGradient {
  fx : Double
  fy : Double
  fr : Double
  cx : Double
  cy : Double
  cr : Double
  transform : Transform
  spread_method : SpreadMethod
  stops : Array[Stop]
  anti_alias : Bool
} derive(Eq, Debug)

///|
pub(all) struct SweepGradient {
  cx : Double
  cy : Double
  start_angle : Double
  end_angle : Double
  transform : Transform
  spread_method : SpreadMethod
  stops : Array[Stop]
  anti_alias : Bool
} derive(Eq, Debug)

///|
/// A tiling pattern.
pub(all) struct Pattern {
  /// The content of a single tile.
  stream : Stream
  transform : Transform
  width : Double
  height : Double
}

///|
/// A paint.
pub(all) enum Paint {
  Color(Color)
  LinearGradient(LinearGradient)
  RadialGradient(RadialGradient)
  SweepGradient(SweepGradient)
  Pattern(Pattern)
}

///|
pub fn Paint::as_rgb(self : Paint) -> (Int, Int, Int)? {
  match self {
    Color(c) => c.as_rgb()
    _ => None
  }
}

///|
/// The fill rule.
pub(all) enum FillRule {
  NonZero
  EvenOdd
} derive(Eq, Debug)

///|
/// A fill.
pub(all) struct Fill {
  paint : Paint
  /// The opacity (between 0 and 1).
  opacity : Double
  rule : FillRule
}

///|
pub fn Fill::default() -> Fill {
  { paint: Color(Color::black()), opacity: 1.0, rule: NonZero, }
}

///|
pub(all) enum LineCap {
  Butt
  Round
  Square
} derive(Eq, Debug)

///|
pub(all) enum LineJoin {
  Miter
  Round
  Bevel
} derive(Eq, Debug)

///|
/// A dash pattern.
pub(all) struct StrokeDash {
  array : Array[Double]
  offset : Double
} derive(Eq, Debug)

///|
/// A stroke.
pub(all) struct Stroke {
  paint : Paint
  width : Double
  miter_limit : Double
  line_cap : LineCap
  line_join : LineJoin
  opacity : Double
  dash : StrokeDash?
}

///|
/// Whether the paint is a gradient with a stop that is not fully opaque.
fn paint_has_translucent_stops(paint : Paint) -> Bool {
  match paint {
    LinearGradient(g) => g.stops.iter().any(s => s.opacity != 1.0)
    RadialGradient(g) => g.stops.iter().any(s => s.opacity != 1.0)
    SweepGradient(g) => g.stops.iter().any(s => s.opacity != 1.0)
    _ => false
  }
}
