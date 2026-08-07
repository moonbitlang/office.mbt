///|
// The page-model IR: the layout engine's output and the backends' only
// input. Pages hold positioned items in painter's order; coordinates are
// points, y-down, origin at the page's top-left corner; text is positioned
// by its baseline. Glyph runs carry their own advances so backends never
// re-measure text.

///|
/// A font face a glyph run references, by index into `PageModel::fonts`.
/// `family` is the resolved (post font-mapping) family name; `bold` and
/// `italic` select the face within it.
pub(all) struct FontSpec {
  family : String
  bold : Bool
  italic : Bool
} derive(Eq, Debug, ToJson)

///|
/// Solid sRGB color. No alpha in v1: solid colors keep the SVG output
/// inside svgdiff's deterministic subset and match common document text.
pub(all) struct Color {
  r : Int
  g : Int
  b : Int
} derive(Eq, Debug, ToJson)

///|
/// Default document text color.
pub let black : Color = { r: 0, g: 0, b: 0 }

///|
/// Lowercase `#rrggbb`, the form both the SVG emitter and tests use.
pub fn Color::to_hex(self : Color) -> String {
  let sb = StringBuilder()
  sb <+ "#"
  for v in [self.r, self.g, self.b] {
    let clamped = if v < 0 { 0 } else if v > 255 { 255 } else { v }
    let digits = "0123456789abcdef"
    sb <+ "\{digits.get_char(clamped / 16).unwrap()}"
    sb <+ "\{digits.get_char(clamped % 16).unwrap()}"
  }
  sb.to_string()
}

///|
/// A run of text on one baseline in one font/size/color. `advances_pt[i]`
/// is the horizontal advance of the char at index `i` of `text` (UTF-16
/// code units; the trailing surrogate of a pair carries advance 0).
pub(all) struct GlyphRun {
  font : Int
  size_pt : Double
  x_pt : Double
  baseline_pt : Double
  text : String
  advances_pt : Array[Double]
  color : Color
} derive(Eq, Debug, ToJson)

///|
/// Total advance of the run: where the next run on the same baseline starts.
pub fn GlyphRun::width_pt(self : GlyphRun) -> Double {
  let mut w = 0.0
  for a in self.advances_pt {
    w += a
  }
  w
}

///|
/// Axis-aligned filled and/or stroked rectangle. Doubles as underlines,
/// table borders, and shading (thin or filled).
pub(all) struct RectItem {
  x_pt : Double
  y_pt : Double
  w_pt : Double
  h_pt : Double
  fill : Color?
  stroke : Color?
  stroke_w_pt : Double
} derive(Eq, Debug, ToJson)

///|
/// A placed raster image; `data` is the encoded file, not pixels.
pub(all) struct ImageItem {
  x_pt : Double
  y_pt : Double
  w_pt : Double
  h_pt : Double
  data : Bytes
  mime : String
} derive(Eq, Debug, ToJson)

///|
/// An interactive region (hyperlink); geometry only, painted by nothing.
pub(all) struct LinkRegion {
  x_pt : Double
  y_pt : Double
  w_pt : Double
  h_pt : Double
  target : String
} derive(Eq, Debug, ToJson)

///|
/// One positioned item on a page, in painter's order.
pub(all) enum PageItem {
  Text(GlyphRun)
  Rect(RectItem)
  Image(ImageItem)
  Link(LinkRegion)
} derive(Eq, Debug, ToJson)

///|
/// A single laid-out page: physical size plus its positioned items.
pub(all) struct Page {
  width_pt : Double
  height_pt : Double
  items : Array[PageItem]
} derive(Eq, Debug, ToJson)

///|
/// The layout engine's complete output: interned fonts plus pages.
pub(all) struct PageModel {
  fonts : Array[FontSpec]
  pages : Array[Page]
} derive(Eq, Debug, ToJson)

///|
/// Intern `spec`, returning its index for `GlyphRun::font`.
pub fn PageModel::add_font(self : PageModel, spec : FontSpec) -> Int {
  for i, existing in self.fonts {
    if existing == spec {
      return i
    }
  }
  self.fonts.push(spec)
  self.fonts.length() - 1
}

///|
/// An empty model to accumulate fonts and pages into.
pub fn PageModel::new() -> PageModel {
  { fonts: [], pages: [] }
}
