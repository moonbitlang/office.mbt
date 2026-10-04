// Port of skrifa 0.42.1 `src/instance.rs`, `src/outline/error.rs` and the
// public re-exports used by consumers.

///|
pub using @read_fonts {
  type FontRef,
  trait OutlinePen,
  type FontData,
  type ReadError,
}

///|
pub using @font_types {type GlyphId, type Fixed, type F26Dot6, type F2Dot14}

///|
/// Font size in pixels per em (or unscaled).
pub(all) struct Size(Float?) derive(Eq, Debug)

///|
/// Creates a new font size from the given value in pixels per em units.
pub fn Size::new(ppem : Float) -> Size {
  Size(Some(ppem))
}

///|
/// Creates a new font size for generating unscaled metrics or outlines in
/// font units.
pub fn Size::unscaled() -> Size {
  Size(None)
}

///|
/// Returns the raw size in pixels per em units.
pub fn Size::ppem(self : Size) -> Float? {
  self.0
}

///|
/// Computes a linear scale factor for this font size and the given units
/// per em value.
pub fn Size::linear_scale(self : Size, units_per_em : Int) -> Float {
  match self.0 {
    Some(ppem) if units_per_em != 0 => ppem / Float::from_int(units_per_em)
    _ => 1.0
  }
}

///|
/// Reference to an ordered sequence of normalized variation coordinates.
pub(all) struct LocationRef(Array[F2Dot14])

///|
pub fn LocationRef::default() -> LocationRef {
  LocationRef([])
}

///|
pub fn LocationRef::coords(self : LocationRef) -> Array[F2Dot14] {
  self.0
}

///|
/// Returns true if this represents the default location in variation
/// space.
pub fn LocationRef::is_default(self : LocationRef) -> Bool {
  for c in self.0 {
    if c != F2Dot14::zero() {
      return false
    }
  }
  true
}

///|
/// Errors that may occur when drawing glyphs.
pub(all) suberror DrawError {
  /// No viable sources were available.
  NoSources
  /// The requested glyph was not present in the font.
  GlyphNotFound(GlyphId)
  /// Exceeded memory limits when loading a glyph.
  InsufficientMemory
  /// Exceeded a recursion limit when loading a glyph.
  RecursionLimitExceeded(GlyphId)
  /// Glyph outline contains too many points.
  TooManyPoints(GlyphId)
  /// Error occurred during hinting.
  HintingFailed(String)
  /// An anchor point had invalid indices.
  InvalidAnchorPoint(GlyphId, Int)
  /// Error occurred while loading a PostScript (CFF/CFF2) glyph.
  PostScript(@ps.PsError)
  /// Conversion from outline to path failed.
  ToPath(ToPathError)
  /// Error occurred when reading font data.
  Read(ReadError)
  /// HarfBuzz style drawing with hints is not supported
  HarfBuzzHintingUnsupported
}

///|
/// Maximum recursion depth for composite glyphs.
pub const GLYF_COMPOSITE_RECURSION_LIMIT : Int = 32

///|
pub impl Show for DrawError with fn output(self, f) {
  match self {
    NoSources =>
      f.write_string("No glyph sources are available for the given font")
    GlyphNotFound(gid) =>
      f.write_string("Glyph \{gid} was not found in the given font")
    InsufficientMemory => f.write_string("exceeded memory limits")
    RecursionLimitExceeded(gid) =>
      f.write_string(
        "Recursion limit (\{GLYF_COMPOSITE_RECURSION_LIMIT}) exceeded when loading composite component \{gid}",
      )
    TooManyPoints(gid) =>
      f.write_string("Glyph \{gid} contains more than 64k points")
    HintingFailed(e) => f.write_string(e)
    InvalidAnchorPoint(gid, index) =>
      f.write_string(
        "Invalid anchor point index (\{index}) for composite glyph \{gid}",
      )
    PostScript(e) => f.write_string(e.to_string())
    ToPath(e) => f.write_string(e.to_string())
    Read(e) => f.write_string(e.to_string())
    HarfBuzzHintingUnsupported =>
      f.write_string(
        "HarfBuzz style paths with hinting is not (yet?) supported",
      )
  }
}

///|
/// Errors that can occur when converting an outline to a path.
pub(all) suberror ToPathError {
  /// Contour end point at this index was less than its preceding end point.
  ContourOrder(Int)
  /// Expected a quadratic off-curve point at this index.
  ExpectedQuad(Int)
  /// Expected a quadratic off-curve or on-curve point at this index.
  ExpectedQuadOrOnCurve(Int)
  /// Expected a cubic off-curve point at this index.
  ExpectedCubic(Int)
  /// Expected number of points to == number of flags
  PointFlagMismatch(num_points~ : Int, num_flags~ : Int)
}

///|
pub impl Show for ToPathError with fn output(self, f) {
  match self {
    ContourOrder(ix) =>
      f.write_string(
        "Contour end point at index \{ix} was less than preceding end point",
      )
    ExpectedQuad(ix) =>
      f.write_string("Expected quadatic off-curve point at index \{ix}")
    ExpectedQuadOrOnCurve(ix) =>
      f.write_string(
        "Expected quadatic off-curve or on-curve point at index \{ix}",
      )
    ExpectedCubic(ix) =>
      f.write_string("Expected cubic off-curve point at index \{ix}")
    PointFlagMismatch(num_points~, num_flags~) =>
      f.write_string(
        "Number of points (\{num_points}) and flags (\{num_flags}) must match",
      )
  }
}

///|
/// Runs `f`, returning `None` on error (Rust `.ok()`).
fn[T] ok(f : () -> T raise) -> T? {
  try f() catch {
    _ => None
  } noraise {
    v => Some(v)
  }
}

///|
/// Runs `f`, capturing the result.
fn[T] res(f : () -> T raise ReadError) -> Result[T, ReadError] {
  try f() catch {
    e => Err(e)
  } noraise {
    v => Ok(v)
  }
}
