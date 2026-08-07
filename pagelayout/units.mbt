///|
// Typed document lengths. All layout math runs in points (Double); these
// wrappers keep OOXML quantities in their authored unit until the boundary
// where they convert, so no bare unit arithmetic leaks into layout code.
// 1 pt = 20 twips = 12700 EMU = 2 half-points; 1 inch = 72 pt = 914400 EMU.

///|
/// Twentieths of a point — OOXML's unit for indents, spacing, margins,
/// page sizes (`w:twip`).
pub(all) struct Twips(Int) derive(Eq, Debug, ToJson)

///|
/// Convert to points (20 twips per point).
pub fn Twips::to_pt(self : Twips) -> Double {
  self.0.to_double() / 20.0
}

///|
/// English Metric Units — OOXML's unit for drawing/image extents
/// (914400 per inch).
pub(all) struct Emu(Int) derive(Eq, Debug, ToJson)

///|
/// Convert to points (12700 EMU per point).
pub fn Emu::to_pt(self : Emu) -> Double {
  self.0.to_double() / 12700.0
}

///|
/// Half-points — OOXML's unit for font sizes (`w:sz`).
pub(all) struct HalfPoints(Int) derive(Eq, Debug, ToJson)

///|
/// Convert to points (2 half-points per point).
pub fn HalfPoints::to_pt(self : HalfPoints) -> Double {
  self.0.to_double() / 2.0
}

///|
/// Eighths of a point — OOXML's unit for border widths (`w:sz` on borders).
pub(all) struct EighthPoints(Int) derive(Eq, Debug, ToJson)

///|
/// Convert to points (8 eighth-points per point).
pub fn EighthPoints::to_pt(self : EighthPoints) -> Double {
  self.0.to_double() / 8.0
}
