// Port of read-fonts 0.39.2 `src/tables/glyf.rs`, `src/tables/loca.rs` and
// `generated_glyf.rs` (subset needed for outline loading).

///|
/// The [glyf](https://docs.microsoft.com/en-us/typography/opentype/spec/glyf) table.
pub struct Glyf {
  data : FontData
}

///|
pub fn FontRef::glyf(self : FontRef) -> Glyf raise ReadError {
  { data: self.expect_data_for_tag("glyf"), }
}

///|
pub fn Glyf::offset_data(self : Glyf) -> FontData {
  self.data
}

///|
/// The [loca](https://docs.microsoft.com/en-us/typography/opentype/spec/loca) table.
pub enum Loca {
  Short(FontData)
  Long(FontData)
}

///|
/// `is_long` can be optionally provided, if known, otherwise we look it up
/// in head.
pub fn FontRef::loca(self : FontRef, is_long : Bool?) -> Loca raise ReadError {
  let is_long = match is_long {
    Some(v) => v
    None => self.head().index_to_loc_format() == 1
  }
  let data = self.expect_data_for_tag("loca")
  if is_long {
    if data.len() % 4 != 0 {
      raise InvalidArrayLen
    }
    Long(data)
  } else {
    if data.len() % 2 != 0 {
      raise InvalidArrayLen
    }
    Short(data)
  }
}

///|
pub fn Loca::len(self : Loca) -> Int {
  let n = match self {
    Short(d) => d.len() / 2
    Long(d) => d.len() / 4
  }
  if n > 0 {
    n - 1
  } else {
    0
  }
}

///|
pub fn Loca::get_raw(self : Loca, idx : Int) -> UInt? {
  if idx < 0 {
    return None
  }
  match self {
    Short(d) =>
      if idx < d.len() / 2 {
        Some(u16_at(d, idx * 2).reinterpret_as_uint() * 2)
      } else {
        None
      }
    Long(d) => if idx < d.len() / 4 { Some(u32_at(d, idx * 4)) } else { None }
  }
}

///|
pub fn Loca::get_glyf(
  self : Loca,
  gid : GlyphId,
  glyf : Glyf,
) -> Glyph? raise ReadError {
  let idx = gid.to_int()
  guard self.get_raw(idx) is Some(start) else { raise OutOfBounds }
  guard self.get_raw(idx + 1) is Some(end) else { raise OutOfBounds }
  if start == end {
    return None
  }
  let len = glyf.data.len().reinterpret_as_uint()
  if start > end || end > len {
    raise OutOfBounds
  }
  let data = glyf.data
    .slice(start.reinterpret_as_int(), end.reinterpret_as_int())
    .unwrap()
  Some(Glyph::read(data))
}

///|
/// A glyph in the glyf table.
pub enum Glyph {
  Simple(SimpleGlyph)
  Composite(CompositeGlyph)
}

///|
pub fn Glyph::read(data : FontData) -> Glyph raise ReadError {
  let format = data.read_i16(0)
  if format >= 0 {
    if data.len() < 12 {
      raise OutOfBounds
    }
    Simple({ data, })
  } else {
    if data.len() < 10 {
      raise OutOfBounds
    }
    Composite({ data, })
  }
}

///|
fn Glyph::data(self : Glyph) -> FontData {
  match self {
    Simple(g) => g.data
    Composite(g) => g.data
  }
}

///|
pub fn Glyph::number_of_contours(self : Glyph) -> Int {
  i16_at(self.data(), 0)
}

///|
pub fn Glyph::x_min(self : Glyph) -> Int {
  i16_at(self.data(), 2)
}

///|
pub fn Glyph::y_min(self : Glyph) -> Int {
  i16_at(self.data(), 4)
}

///|
pub fn Glyph::x_max(self : Glyph) -> Int {
  i16_at(self.data(), 6)
}

///|
pub fn Glyph::y_max(self : Glyph) -> Int {
  i16_at(self.data(), 8)
}

///|
/// A simple (non-composite) glyph.
pub struct SimpleGlyph {
  data : FontData
}

///|
pub fn SimpleGlyph::number_of_contours(self : SimpleGlyph) -> Int {
  i16_at(self.data, 0)
}

///|
/// The contour end points (empty if out of bounds).
pub fn SimpleGlyph::end_pts_of_contours(self : SimpleGlyph) -> Array[Int] {
  let n = self.number_of_contours()
  let arr = self.data.read_array(10, n, 2) catch { _ => return [] }
  [
    for i in 0..<n => u16_at(arr, i * 2)
  ]
}

///|
fn SimpleGlyph::instruction_length_offset(self : SimpleGlyph) -> Int {
  10 + self.number_of_contours() * 2
}

///|
pub fn SimpleGlyph::instruction_length(self : SimpleGlyph) -> Int {
  u16_at(self.data, self.instruction_length_offset())
}

///|
pub fn SimpleGlyph::instructions(self : SimpleGlyph) -> BytesView {
  let start = self.instruction_length_offset() + 2
  match self.data.get(start, start + self.instruction_length()) {
    Some(v) => v
    None => b""
  }
}

///|
pub fn SimpleGlyph::glyph_data(self : SimpleGlyph) -> BytesView {
  let start = self.instruction_length_offset() + 2 + self.instruction_length()
  match self.data.get(start, self.data.len()) {
    Some(v) => v
    None => b""
  }
}

///|
/// Returns the total number of points.
pub fn SimpleGlyph::num_points(self : SimpleGlyph) -> Int {
  let pts = self.end_pts_of_contours()
  match pts.last() {
    Some(last) => last + 1
    None => 0
  }
}

///|
/// Returns true if the contours in the simple glyph may overlap.
pub fn SimpleGlyph::has_overlapping_contours(self : SimpleGlyph) -> Bool {
  let d = self.glyph_data()
  d.length() > 0 && (d[0].to_int() & 0x40) != 0
}

///|
/// Reads points and flags into the provided buffers (which must have
/// exactly `num_points` entries). Flags are reduced to the on-curve bit.
pub fn SimpleGlyph::read_points_fast(
  self : SimpleGlyph,
  xs : FixedArray[Int],
  ys : FixedArray[Int],
  flags : FixedArray[Int],
  base : Int,
) -> Unit raise ReadError {
  let n_points = self.num_points()
  let data = FontData::new(self.glyph_data())
  let cursor = data.cursor()
  // We'll need at most n_points flags, but fewer if there are repeats
  let n_flags = if n_points < cursor.remaining_bytes() {
    n_points
  } else {
    cursor.remaining_bytes()
  }
  let flags_data = cursor.read_array(n_flags, 1).as_bytes()
  let mut read_flags_bytes = 0
  let mut i = 0
  let mut fi = 0
  while fi < flags_data.length() {
    let flag_bits = flags_data[fi].to_int()
    fi += 1
    read_flags_bytes += 1
    if (flag_bits & 0x08) != 0 {
      if fi >= flags_data.length() {
        raise OutOfBounds
      }
      let rep = flags_data[fi].to_int()
      fi += 1
      let count = if rep + 1 < n_points - i { rep + 1 } else { n_points - i }
      read_flags_bytes += 1
      for j in i..<(i + count) {
        flags[base + j] = flag_bits
      }
      i += count
    } else {
      flags[base + i] = flag_bits
      i += 1
    }
    if i == n_points {
      break
    }
  }
  let cursor = data.cursor()
  cursor.advance_by(read_flags_bytes)
  let mut x = 0
  for k in 0..<n_points {
    let flag = flags[base + k]
    let mut delta = 0
    if (flag & 0x02) != 0 {
      delta = cursor.read_u8()
      if (flag & 0x10) == 0 {
        delta = -delta
      }
    } else if (flag & 0x10) == 0 {
      delta = cursor.read_i16()
    }
    x = x + delta
    xs[base + k] = x
  }
  let mut y = 0
  for k in 0..<n_points {
    let flag = flags[base + k]
    let mut delta = 0
    if (flag & 0x04) != 0 {
      delta = cursor.read_u8()
      if (flag & 0x20) == 0 {
        delta = -delta
      }
    } else if (flag & 0x20) == 0 {
      delta = cursor.read_i16()
    }
    y = y + delta
    ys[base + k] = y
    // Drop the cubic bit (the spec_next feature is not enabled)
    flags[base + k] = flag & 0x01
  }
}

///|
/// A composite glyph.
pub struct CompositeGlyph {
  data : FontData
}

///|
pub fn CompositeGlyph::component_data(self : CompositeGlyph) -> FontData {
  self.data.split_off(10).unwrap_or(FontData::empty())
}

///|
/// Composite glyph flags.
pub const ARG_1_AND_2_ARE_WORDS : Int = 0x0001

///|
pub const ARGS_ARE_XY_VALUES : Int = 0x0002

///|
pub const ROUND_XY_TO_GRID : Int = 0x0004

///|
pub const WE_HAVE_A_SCALE : Int = 0x0008

///|
pub const MORE_COMPONENTS : Int = 0x0020

///|
pub const WE_HAVE_AN_X_AND_Y_SCALE : Int = 0x0040

///|
pub const WE_HAVE_A_TWO_BY_TWO : Int = 0x0080

///|
pub const WE_HAVE_INSTRUCTIONS : Int = 0x0100

///|
pub const USE_MY_METRICS : Int = 0x0200

///|
pub const OVERLAP_COMPOUND : Int = 0x0400

///|
pub const SCALED_COMPONENT_OFFSET : Int = 0x0800

///|
pub const UNSCALED_COMPONENT_OFFSET : Int = 0x1000

///|
/// Anchor position for a composite component.
pub(all) enum Anchor {
  Offset(x~ : Int, y~ : Int)
  Point(base~ : Int, component~ : Int)
} derive(Eq, Debug)

///|
/// Transform for a composite component (2.14 values).
pub(all) struct ComponentTransform {
  xx : F2Dot14
  yx : F2Dot14
  xy : F2Dot14
  yy : F2Dot14
} derive(Eq, Debug)

///|
/// A reference to another glyph. Part of [CompositeGlyph].
pub(all) struct Component {
  flags : Int
  glyph : Int
  anchor : Anchor
  transform : ComponentTransform
} derive(Eq, Debug)

///|
/// Returns the components of the composite glyph.
pub fn CompositeGlyph::components(self : CompositeGlyph) -> Array[Component] {
  let result = []
  let cursor = self.component_data().cursor()
  let one = F2Dot14::from_f32(1.0)
  let zero = F2Dot14::from_f32(0.0)
  while true {
    let comp = try {
      let flags = cursor.read_u16()
      let glyph = cursor.read_u16()
      let args_are_words = (flags & ARG_1_AND_2_ARE_WORDS) != 0
      let args_are_xy_values = (flags & ARGS_ARE_XY_VALUES) != 0
      let anchor = match (args_are_xy_values, args_are_words) {
        (true, true) => {
          let x = cursor.read_i16()
          let y = cursor.read_i16()
          Offset(x~, y~)
        }
        (true, false) => {
          let x = cursor.read_i8()
          let y = cursor.read_i8()
          Offset(x~, y~)
        }
        (false, true) => {
          let base = cursor.read_u16()
          let component = cursor.read_u16()
          Point(base~, component~)
        }
        (false, false) => {
          let base = cursor.read_u8()
          let component = cursor.read_u8()
          Point(base~, component~)
        }
      }
      let mut xx = one
      let mut yx = zero
      let mut xy = zero
      let mut yy = one
      if (flags & WE_HAVE_A_SCALE) != 0 {
        xx = F2Dot14::from_bits(cursor.read_i16())
        yy = xx
      } else if (flags & WE_HAVE_AN_X_AND_Y_SCALE) != 0 {
        xx = F2Dot14::from_bits(cursor.read_i16())
        yy = F2Dot14::from_bits(cursor.read_i16())
      } else if (flags & WE_HAVE_A_TWO_BY_TWO) != 0 {
        xx = F2Dot14::from_bits(cursor.read_i16())
        yx = F2Dot14::from_bits(cursor.read_i16())
        xy = F2Dot14::from_bits(cursor.read_i16())
        yy = F2Dot14::from_bits(cursor.read_i16())
      }
      Component::{ flags, glyph, anchor, transform: { xx, yx, xy, yy, }, }
    } catch {
      _ => break
    }
    result.push(comp)
    if (comp.flags & MORE_COMPONENTS) == 0 {
      break
    }
  }
  result
}

///|
/// Returns the glyph identifier and flags of each component and the
/// TrueType instructions (in a single pass, like
/// `count_and_instructions`).
pub fn CompositeGlyph::component_glyphs_and_flags(
  self : CompositeGlyph,
) -> (Array[(Int, Int)], BytesView?) {
  let result = []
  let cursor = self.component_data().cursor()
  let mut cur_flags = 0
  while true {
    let flags = cursor.read_u16() catch { _ => break }
    cur_flags = flags
    let glyph = cursor.read_u16() catch { _ => break }
    if (flags & ARG_1_AND_2_ARE_WORDS) != 0 {
      cursor.advance_by(4)
    } else {
      cursor.advance_by(2)
    }
    if (flags & WE_HAVE_A_SCALE) != 0 {
      cursor.advance_by(2)
    } else if (flags & WE_HAVE_AN_X_AND_Y_SCALE) != 0 {
      cursor.advance_by(4)
    } else if (flags & WE_HAVE_A_TWO_BY_TWO) != 0 {
      cursor.advance_by(8)
    }
    result.push((glyph, flags))
    if (flags & MORE_COMPONENTS) == 0 {
      break
    }
  }
  let instructions = if (cur_flags & WE_HAVE_INSTRUCTIONS) != 0 {
    let len = cursor.read_u16() catch { _ => -1 }
    if len < 0 {
      None
    } else {
      try cursor.read_array(len, 1) catch {
        _ => None
      } noraise {
        d => Some(d.as_bytes())
      }
    }
  } else {
    None
  }
  (result, instructions)
}

///|
/// Returns the TrueType interpreter instructions.
pub fn CompositeGlyph::instructions(self : CompositeGlyph) -> BytesView? {
  self.component_glyphs_and_flags().1
}

///|
/// Computes a table checksum.
pub fn compute_checksum(table : BytesView) -> UInt {
  let mut sum = 0U
  let n = table.length() / 4
  for i in 0..<n {
    let p = i * 4
    let v = (table[p].to_uint() << 24) |
      (table[p + 1].to_uint() << 16) |
      (table[p + 2].to_uint() << 8) |
      table[p + 3].to_uint()
    sum = sum + v
  }
  let rem = table.length() % 4
  let p = n * 4
  let r = match rem {
    1 => table[p].to_uint() << 24
    2 => (table[p].to_uint() << 24) | (table[p + 1].to_uint() << 16)
    3 =>
      (table[p].to_uint() << 24) |
      (table[p + 1].to_uint() << 16) |
      (table[p + 2].to_uint() << 8)
    _ => 0U
  }
  sum + r
}

///|
/// The `CFF ` table: validated like read-fonts' `Cff::read` (header and
/// the four leading INDEX structures).
pub struct CffTable {
  data : FontData
}

///|
pub fn CffTable::offset_data(self : CffTable) -> BytesView {
  self.data.as_bytes()
}

///|
pub fn FontRef::cff(self : FontRef) -> CffTable raise ReadError {
  let data = self.expect_data_for_tag("CFF ")
  if data.len() < 4 {
    raise OutOfBounds
  }
  let hdr_size = u16_at(data, 2) >> 8
  let start = 4 + (if hdr_size > 4 { hdr_size - 4 } else { 0 })
  let mut d = data.split_off(start).unwrap_or(FontData::empty())
  for _ in 0..<3 {
    let size = cff_index_size(d)
    guard d.split_off(size) is Some(rest) else { raise OutOfBounds }
    d = rest
  }
  // Index::read of the global subroutines only checks the minimum size
  if d.len() < 3 {
    raise OutOfBounds
  }
  { data, }
}

///|
/// Reads a CFF INDEX header and returns its total size in bytes.
fn cff_index_size(d : FontData) -> Int raise ReadError {
  if d.len() < 3 {
    raise OutOfBounds
  }
  let count = u16_at(d, 0)
  if count == 0 {
    return 2
  }
  let off_size = d.read_u8(2)
  let offsets_len = (count + 1) * off_size
  let offsets = d.slice(3, 3 + offsets_len).unwrap_or(FontData::empty())
  // get_offset(count)
  let p = count * off_size
  let off = match off_size {
    1 => offsets.read_u8(p)
    2 => offsets.read_u16(p)
    3 => offsets.read_u24(p)
    4 => {
      let v = offsets.read_i32(p)
      if v < 0 {
        2147483647
      } else {
        v
      }
    }
    _ => raise OutOfBounds
  }
  if off == 0 {
    raise OutOfBounds
  }
  3 + offsets.len() + (off - 1)
}
