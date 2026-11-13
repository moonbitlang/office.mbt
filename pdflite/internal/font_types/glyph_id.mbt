// Port of font-types 0.11.3 `src/glyph_id.rs`, `src/point.rs`,
// `src/matrix.rs` (Fixed elements), `src/bbox.rs` and `src/tag.rs` (subset).

///|
/// A 32-bit glyph identifier.
#derive(Eq, Compare, Hash, Debug)
pub(all) struct GlyphId(UInt32)

///|
pub fn GlyphId::new(raw : UInt32) -> GlyphId {
  GlyphId(raw)
}

///|
pub fn GlyphId::from_int(raw : Int32) -> GlyphId {
  GlyphId(raw.reinterpret_as_uint())
}

///|
pub fn GlyphId::notdef() -> GlyphId {
  GlyphId(0)
}

///|
pub fn GlyphId::to_u32(self : GlyphId) -> UInt32 {
  self.0
}

///|
pub fn GlyphId::to_int(self : GlyphId) -> Int32 {
  self.0.reinterpret_as_int()
}

///|
/// Converts to a 16-bit glyph identifier if the value fits.
pub fn GlyphId::to_u16(self : GlyphId) -> Int32? {
  if self.0 <= 0xFFFFU {
    Some(self.0.reinterpret_as_int())
  } else {
    None
  }
}

///|
pub impl Show for GlyphId with fn output(self, logger) {
  logger.write_string("GID_\{self.0}")
}

///|
/// Two dimensional point with fixed point coordinates.
#derive(Eq, Debug)
pub(all) struct Point[T] {
  x : T
  y : T
}

///|
pub fn[T] Point::new(x : T, y : T) -> Point[T] {
  { x, y, }
}

///|
/// Affine matrix with 16.16 fixed point elements.
///
/// ```none
/// | xx xy dx |
/// | yx yy dy |
/// ```
#derive(Eq, Debug)
pub(all) struct FontMatrix {
  xx : Fixed
  yx : Fixed
  xy : Fixed
  yy : Fixed
  dx : Fixed
  dy : Fixed
}

///|
pub fn FontMatrix::identity() -> FontMatrix {
  {
    xx: Fixed::one(),
    yx: Fixed::zero(),
    xy: Fixed::zero(),
    yy: Fixed::one(),
    dx: Fixed::zero(),
    dy: Fixed::zero(),
  }
}

///|
/// Creates a new matrix from elements in the order `[xx, yx, xy, yy, dx, dy]`.
pub fn FontMatrix::from_elements(e : FixedArray[Fixed]) -> FontMatrix {
  { xx: e[0], yx: e[1], xy: e[2], yy: e[3], dx: e[4], dy: e[5], }
}

///|
/// Returns the elements in the order `[xx, yx, xy, yy, dx, dy]`.
pub fn FontMatrix::elements(self : FontMatrix) -> FixedArray[Fixed] {
  [self.xx, self.yx, self.xy, self.yy, self.dx, self.dy]
}

///|
/// Applies the matrix to the given coordinates.
pub fn FontMatrix::transform(
  self : FontMatrix,
  x : Fixed,
  y : Fixed,
) -> (Fixed, Fixed) {
  (self.xx * x + self.xy * y + self.dx, self.yx * x + self.yy * y + self.dy)
}

///|
/// Minimum and maximum extents of a rectangular region.
#derive(Eq, Debug)
pub(all) struct BoundingBox[T] {
  x_min : T
  y_min : T
  x_max : T
  y_max : T
}

///|
/// A 4-byte OpenType tag, stored as a big-endian `UInt`.
#derive(Eq, Compare, Hash, Debug)
pub(all) struct Tag(UInt32)

///|
/// Creates a tag from a 4 character ASCII string.
pub fn Tag::new(s : String) -> Tag {
  let mut v = 0U
  for i in 0..<4 {
    let c = if i < s.length() { s[i].to_int() } else { 0x20 }
    v = (v << 8) | (c & 0xFF).reinterpret_as_uint()
  }
  Tag(v)
}

///|
pub fn Tag::from_u32(v : UInt32) -> Tag {
  Tag(v)
}

///|
pub fn Tag::to_u32(self : Tag) -> UInt32 {
  self.0
}

///|
pub impl Show for Tag with fn output(self, logger) {
  for i in 0..<4 {
    let c = ((self.0 >> ((3 - i) * 8)) & 0xFFU).reinterpret_as_int()
    logger.write_char(Int32::unsafe_to_char(c))
  }
}
