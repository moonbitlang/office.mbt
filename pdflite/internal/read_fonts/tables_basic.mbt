// Ports of read-fonts 0.39.2 tables `head`, `maxp`, `hhea`, `hmtx`, `OS/2`
// (`src/tables/*.rs` and `generated/generated_*.rs`, subset of fields).
//
// Like read-fonts, tables are validated lazily: only the minimum size is
// checked when a table is read.

///|
fn u16_at(d : FontData, p : Int) -> Int {
  d.read_u16(p) catch {
    _ => 0
  }
}

///|
fn i16_at(d : FontData, p : Int) -> Int {
  d.read_i16(p) catch {
    _ => 0
  }
}

///|
fn u32_at(d : FontData, p : Int) -> UInt {
  d.read_u32(p) catch {
    _ => 0
  }
}

///|
/// A 16.16 version number (`Version16Dot16`).
pub(all) struct Version16Dot16(UInt) derive(Eq, Debug)

///|
/// Returns the separate major & minor version numbers.
pub fn Version16Dot16::to_major_minor(self : Version16Dot16) -> (Int, Int) {
  let major = (self.0 >> 16).reinterpret_as_int()
  let minor = ((self.0 & 0xFFFFU) >> 12).reinterpret_as_int()
  (major, minor)
}

///|
/// 'same major version, greater than or equal minor version'
fn Version16Dot16::compatible(
  self : Version16Dot16,
  major : Int,
  minor : Int,
) -> Bool {
  let (a, b) = self.to_major_minor()
  a == major && b >= minor
}

// ---------------------------------------------------------------------------
// head

///|
/// The [head](https://docs.microsoft.com/en-us/typography/opentype/spec/head) table.
pub struct Head {
  data : FontData
}

///|
pub fn FontRef::head(self : FontRef) -> Head raise ReadError {
  let data = self.expect_data_for_tag("head")
  if data.len() < 54 {
    raise OutOfBounds
  }
  { data, }
}

///|
pub fn Head::flags(self : Head) -> Int {
  u16_at(self.data, 16)
}

///|
pub fn Head::units_per_em(self : Head) -> Int {
  u16_at(self.data, 18)
}

///|
pub fn Head::x_min(self : Head) -> Int {
  i16_at(self.data, 36)
}

///|
pub fn Head::y_min(self : Head) -> Int {
  i16_at(self.data, 38)
}

///|
pub fn Head::x_max(self : Head) -> Int {
  i16_at(self.data, 40)
}

///|
pub fn Head::y_max(self : Head) -> Int {
  i16_at(self.data, 42)
}

///|
pub fn Head::mac_style(self : Head) -> Int {
  u16_at(self.data, 44)
}

///|
pub fn Head::index_to_loc_format(self : Head) -> Int {
  i16_at(self.data, 50)
}

///|
/// head flags bit 3: force integer ppem.
pub const HEAD_FLAG_FORCE_INTEGER_PPEM : Int = 0x0008

///|
/// macStyle bits.
pub const MAC_STYLE_BOLD : Int = 0x0001

///|
pub const MAC_STYLE_ITALIC : Int = 0x0002

// ---------------------------------------------------------------------------
// maxp

///|
/// The [maxp](https://docs.microsoft.com/en-us/typography/opentype/spec/maxp) table.
pub struct Maxp {
  data : FontData
}

///|
pub fn FontRef::maxp(self : FontRef) -> Maxp raise ReadError {
  let data = self.expect_data_for_tag("maxp")
  if data.len() < 6 {
    raise OutOfBounds
  }
  { data, }
}

///|
pub fn Maxp::version(self : Maxp) -> Version16Dot16 {
  Version16Dot16(u32_at(self.data, 0))
}

///|
pub fn Maxp::num_glyphs(self : Maxp) -> Int {
  u16_at(self.data, 4)
}

///|
/// Version 1.0 field at the given byte offset.
fn Maxp::v1_field(self : Maxp, offset : Int) -> Int? {
  if !self.version().compatible(1, 0) {
    return None
  }
  try self.data.read_u16(offset) catch {
    _ => None
  } noraise {
    v => Some(v)
  }
}

///|
pub fn Maxp::max_twilight_points(self : Maxp) -> Int? {
  self.v1_field(16)
}

///|
pub fn Maxp::max_storage(self : Maxp) -> Int? {
  self.v1_field(18)
}

///|
pub fn Maxp::max_function_defs(self : Maxp) -> Int? {
  self.v1_field(20)
}

///|
pub fn Maxp::max_instruction_defs(self : Maxp) -> Int? {
  self.v1_field(22)
}

///|
pub fn Maxp::max_stack_elements(self : Maxp) -> Int? {
  self.v1_field(24)
}

///|
pub fn Maxp::max_size_of_instructions(self : Maxp) -> Int? {
  self.v1_field(26)
}

// ---------------------------------------------------------------------------
// hhea

///|
/// The [hhea](https://docs.microsoft.com/en-us/typography/opentype/spec/hhea) table.
pub struct Hhea {
  data : FontData
}

///|
pub fn FontRef::hhea(self : FontRef) -> Hhea raise ReadError {
  let data = self.expect_data_for_tag("hhea")
  if data.len() < 36 {
    raise OutOfBounds
  }
  { data, }
}

///|
pub fn Hhea::ascender(self : Hhea) -> Int {
  i16_at(self.data, 4)
}

///|
pub fn Hhea::descender(self : Hhea) -> Int {
  i16_at(self.data, 6)
}

///|
pub fn Hhea::line_gap(self : Hhea) -> Int {
  i16_at(self.data, 8)
}

///|
pub fn Hhea::advance_width_max(self : Hhea) -> Int {
  u16_at(self.data, 10)
}

///|
pub fn Hhea::number_of_h_metrics(self : Hhea) -> Int {
  u16_at(self.data, 34)
}

// ---------------------------------------------------------------------------
// hmtx

///|
/// The [hmtx](https://docs.microsoft.com/en-us/typography/opentype/spec/hmtx) table.
pub struct Hmtx {
  /// Long metrics (advance u16, lsb i16), 4 bytes each.
  h_metrics : FontData
  /// Trailing left side bearings, 2 bytes each.
  left_side_bearings : FontData
}

///|
pub fn FontRef::hmtx(self : FontRef) -> Hmtx raise ReadError {
  let number_of_h_metrics = self.hhea().number_of_h_metrics()
  let data = self.expect_data_for_tag("hmtx")
  let hm_end = number_of_h_metrics * 4
  let h_metrics = data.slice(0, hm_end).unwrap_or(FontData::empty())
  let lsb_len = data.len() - hm_end
  let lsb_len = if lsb_len < 0 { 0 } else { lsb_len / 2 * 2 }
  let left_side_bearings = data
    .slice(hm_end, hm_end + lsb_len)
    .unwrap_or(FontData::empty())
  { h_metrics, left_side_bearings, }
}

///|
/// Number of long metrics.
pub fn Hmtx::num_h_metrics(self : Hmtx) -> Int {
  self.h_metrics.len() / 4
}

///|
pub fn Hmtx::h_metric_advance(self : Hmtx, index : Int) -> Int {
  u16_at(self.h_metrics, index * 4)
}

///|
pub fn Hmtx::h_metric_side_bearing(self : Hmtx, index : Int) -> Int {
  i16_at(self.h_metrics, index * 4 + 2)
}

///|
pub fn Hmtx::num_left_side_bearings(self : Hmtx) -> Int {
  self.left_side_bearings.len() / 2
}

///|
pub fn Hmtx::left_side_bearing(self : Hmtx, index : Int) -> Int {
  i16_at(self.left_side_bearings, index * 2)
}

///|
/// Returns the advance width for the given glyph (falling back to the last
/// long metric).
pub fn Hmtx::advance(self : Hmtx, glyph_id : GlyphId) -> Int? {
  let n = self.num_h_metrics()
  if n == 0 {
    return None
  }
  let gid = glyph_id.to_u32()
  if gid < n.reinterpret_as_uint() {
    Some(self.h_metric_advance(gid.reinterpret_as_int()))
  } else {
    Some(self.h_metric_advance(n - 1))
  }
}

///|
/// Returns the left side bearing for the given glyph.
pub fn Hmtx::side_bearing(self : Hmtx, glyph_id : GlyphId) -> Int? {
  let n = self.num_h_metrics()
  let gid = glyph_id.to_u32()
  if gid < n.reinterpret_as_uint() {
    return Some(self.h_metric_side_bearing(gid.reinterpret_as_int()))
  }
  let ix = gid - n.reinterpret_as_uint()
  if ix < self.num_left_side_bearings().reinterpret_as_uint() {
    Some(self.left_side_bearing(ix.reinterpret_as_int()))
  } else {
    None
  }
}

// ---------------------------------------------------------------------------
// OS/2

///|
/// The [OS/2](https://docs.microsoft.com/en-us/typography/opentype/spec/os2) table.
pub struct Os2 {
  data : FontData
}

///|
pub fn FontRef::os2(self : FontRef) -> Os2 raise ReadError {
  let data = self.expect_data_for_tag("OS/2")
  if data.len() < 78 {
    raise OutOfBounds
  }
  { data, }
}

///|
pub fn Os2::version(self : Os2) -> Int {
  u16_at(self.data, 0)
}

///|
pub fn Os2::x_avg_char_width(self : Os2) -> Int {
  i16_at(self.data, 2)
}

///|
pub fn Os2::us_weight_class(self : Os2) -> Int {
  u16_at(self.data, 4)
}

///|
pub fn Os2::us_width_class(self : Os2) -> Int {
  u16_at(self.data, 6)
}

///|
pub fn Os2::y_strikeout_size(self : Os2) -> Int {
  i16_at(self.data, 26)
}

///|
pub fn Os2::y_strikeout_position(self : Os2) -> Int {
  i16_at(self.data, 28)
}

///|
pub fn Os2::fs_selection(self : Os2) -> Int {
  u16_at(self.data, 62)
}

///|
pub fn Os2::s_typo_ascender(self : Os2) -> Int {
  i16_at(self.data, 68)
}

///|
pub fn Os2::s_typo_descender(self : Os2) -> Int {
  i16_at(self.data, 70)
}

///|
pub fn Os2::s_typo_line_gap(self : Os2) -> Int {
  i16_at(self.data, 72)
}

///|
pub fn Os2::us_win_ascent(self : Os2) -> Int {
  u16_at(self.data, 74)
}

///|
pub fn Os2::us_win_descent(self : Os2) -> Int {
  u16_at(self.data, 76)
}

///|
/// Version >= 2 fields.
fn Os2::v2_i16(self : Os2, offset : Int) -> Int? {
  if self.version() < 2 {
    return None
  }
  try self.data.read_i16(offset) catch {
    _ => None
  } noraise {
    v => Some(v)
  }
}

///|
pub fn Os2::sx_height(self : Os2) -> Int? {
  self.v2_i16(86)
}

///|
pub fn Os2::s_cap_height(self : Os2) -> Int? {
  self.v2_i16(88)
}

///|
/// fsSelection bits.
pub const OS2_SELECTION_ITALIC : Int = 0x0001

///|
pub const OS2_SELECTION_USE_TYPO_METRICS : Int = 0x0080

///|
pub const OS2_SELECTION_OBLIQUE : Int = 0x0200
