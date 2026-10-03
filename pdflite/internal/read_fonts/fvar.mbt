// Ports of read-fonts 0.39.2 `src/tables/fvar.rs`, `src/tables/avar.rs` and
// `src/tables/hvar.rs` (with the layouts of their generated code).

///|
/// The [fvar](https://learn.microsoft.com/en-us/typography/opentype/spec/fvar)
/// table.
pub struct Fvar {
  data : FontData
}

///|
pub fn FontRef::fvar(self : FontRef) -> Fvar raise ReadError {
  let data = self.expect_data_for_tag("fvar")
  if data.len() < 16 {
    raise OutOfBounds
  }
  { data, }
}

///|
/// The number of variation axes in the font.
pub fn Fvar::axis_count(self : Fvar) -> Int {
  self.data.read_u16(8) catch {
    _ => 0
  }
}

///|
/// A variation axis record.
pub(all) struct VariationAxisRecord {
  axis_tag : UInt
  min_value : Fixed
  default_value : Fixed
  max_value : Fixed
}

///|
/// Returns the array of variation axis records.
pub fn Fvar::axes(self : Fvar) -> Array[VariationAxisRecord] raise ReadError {
  let offset = self.data.read_u16(4)
  if offset == 0 {
    raise NullOffset
  }
  guard self.data.split_off(offset) is Some(arrays) else { raise OutOfBounds }
  let count = self.axis_count()
  let out = []
  // `read_array(range).ok().unwrap_or_default()`
  if count * 20 > arrays.len() {
    return out
  }
  for i in 0..<count {
    let p = 20 * i
    out.push({
      axis_tag: arrays.read_u32(p),
      min_value: Fixed::from_bits(arrays.read_i32(p + 4)),
      default_value: Fixed::from_bits(arrays.read_i32(p + 8)),
      max_value: Fixed::from_bits(arrays.read_i32(p + 12)),
    })
  }
  out
}

///|
fn fixed_clamp(v : Fixed, lo : Fixed, hi : Fixed) -> Fixed {
  // Rust's `Ord::clamp` (panics if `lo > hi`; callers ensure `lo <= hi`).
  if v < lo {
    lo
  } else if v > hi {
    hi
  } else {
    v
  }
}

///|
/// Returns a normalized coordinate for the given value.
pub fn VariationAxisRecord::normalize(
  self : VariationAxisRecord,
  value : Fixed,
) -> Fixed {
  let min_value = self.min_value
  let default_value = self.default_value
  // Make sure max is >= min to avoid potential panic in clamp.
  let max_value = if self.max_value > min_value {
    self.max_value
  } else {
    min_value
  }
  let value = fixed_clamp(value, min_value, max_value)
  let value = if value < default_value {
    -(default_value.saturating_sub(value) /
    default_value.saturating_sub(min_value))
  } else if value > default_value {
    value.saturating_sub(default_value) /
    max_value.saturating_sub(default_value)
  } else {
    Fixed::zero()
  }
  fixed_clamp(value, Fixed::neg_one(), Fixed::one())
}

///|
fn round_f64_to_i32(value : Double) -> Int {
  let v = if value >= 0.0 { value + 0.5 } else { value - 0.5 }
  // Rust's saturating `as i32` (NaN is 0).
  if v.is_nan() {
    0
  } else if v >= 2147483647.0 {
    2147483647
  } else if v <= -2147483648.0 {
    -2147483648
  } else {
    v.to_int()
  }
}

///|
fn apply_avar2_delta(coord : Fixed, delta_2dot14 : Double) -> Fixed {
  // HarfBuzz keeps the avar1 result in 16.16 through the avar2 add, and
  // converts the avar2 delta from 2.14 units by multiplying by four.
  Fixed::from_bits(coord.to_bits() + round_f64_to_i32(delta_2dot14 * 4.0))
}

///|
/// Converts user space coordinates provided by an unordered sequence of
/// `(tag, value)` pairs to normalized coordinates in axis list order, stored
/// in `normalized_coords`.
pub fn Fvar::user_to_normalized(
  self : Fvar,
  avar : Avar?,
  user_coords : ArrayView[(UInt, Fixed)],
  normalized_coords : FixedArray[F2Dot14],
) -> Unit {
  normalized_coords.fill(F2Dot14::zero())
  let axes = self.axes() catch { _ => [] }
  let actual_len = if axes.length() < normalized_coords.length() {
    axes.length()
  } else {
    normalized_coords.length()
  }
  let fixed_coords = FixedArray::make(actual_len, Fixed::zero())
  // normalize_user_coords: to permit non-linear interpolation, iterate over
  // all axes to ensure we match multiple axes with the same tag.
  for user_coord in user_coords {
    for i in 0..<actual_len {
      if axes[i].axis_tag == user_coord.0 {
        fixed_coords[i] = axes[i].normalize(user_coord.1)
      }
    }
  }
  // apply_avar_mappings
  match avar {
    Some(avar) =>
      for i in 0..<actual_len {
        if avar.segment_maps(i) is Some(mapping) {
          fixed_coords[i] = mapping.apply(fixed_coords[i])
        }
      }
    None => ()
  }
  let to_normalized = () => {
    for i in 0..<actual_len {
      normalized_coords[i] = fixed_coords[i].to_f2dot14()
    }
  }
  guard avar is Some(avar) else { return to_normalized() }
  if avar.major_version() == 1 && avar.minor_version() == 0 {
    return to_normalized()
  }
  let coords_2dot14 = FixedArray::makei(actual_len, i => {
    fixed_coords[i].to_f2dot14()
  })
  match avar.var_store() {
    Some(Ok(varstore)) =>
      for i in 0..<actual_len {
        let var_index = match avar.axis_index_map() {
          Some(Ok(map)) =>
            map.get(i.reinterpret_as_uint()) catch {
              _ => continue
            }
          _ => { outer: 0, inner: i & 0xFFFF, }
        }
        let delta = varstore.compute_float_delta(var_index, coords_2dot14) catch {
          _ => continue
        }
        fixed_coords[i] = fixed_clamp(
          apply_avar2_delta(fixed_coords[i], delta),
          Fixed::neg_one(),
          Fixed::one(),
        )
      }
    _ => ()
  }
  to_normalized()
}

///|
/// The [avar](https://learn.microsoft.com/en-us/typography/opentype/spec/avar)
/// table.
pub struct Avar {
  data : FontData
}

///|
pub fn FontRef::avar(self : FontRef) -> Avar raise ReadError {
  let data = self.expect_data_for_tag("avar")
  if data.len() < 8 {
    raise OutOfBounds
  }
  // (Version 2 tables have two more offsets after the segment maps.)
  { data, }
}

///|
fn Avar::major_version(self : Avar) -> Int {
  self.data.read_u16(0) catch {
    _ => 0
  }
}

///|
fn Avar::minor_version(self : Avar) -> Int {
  self.data.read_u16(2) catch {
    _ => 0
  }
}

///|
/// The segment maps of axis `i` (`None` if missing or malformed).
fn Avar::segment_maps(self : Avar, i : Int) -> SegmentMaps? {
  let axis_count = self.data.read_u16(6) catch { _ => return None }
  if i >= axis_count {
    return None
  }
  let mut pos = 8
  for k in 0..<i {
    ignore(k)
    let n = self.data.read_u16(pos) catch { _ => return None }
    pos += 2 + 4 * n
  }
  let n = self.data.read_u16(pos) catch { _ => return None }
  match self.data.slice(pos + 2, pos + 2 + 4 * n) {
    Some(maps) => Some({ maps, len: n, })
    None => None
  }
}

///|
/// The end of the segment maps (where version 2 fields start).
fn Avar::segment_maps_end(self : Avar) -> Int? {
  let axis_count = self.data.read_u16(6) catch { _ => return None }
  let mut pos = 8
  for _ in 0..<axis_count {
    let n = self.data.read_u16(pos) catch { _ => return None }
    pos += 2 + 4 * n
  }
  Some(pos)
}

///|
fn Avar::axis_index_map(self : Avar) -> Result[DeltaSetIndexMap, ReadError]? {
  guard self.segment_maps_end() is Some(pos) else { return None }
  let offset = self.data.read_u32(pos) catch { _ => return None }
  if offset == 0 {
    return None
  }
  Some(
    capture(() => DeltaSetIndexMap::read(resolve_offset32(self.data, offset))),
  )
}

///|
fn Avar::var_store(self : Avar) -> Result[ItemVariationStore, ReadError]? {
  guard self.segment_maps_end() is Some(pos) else { return None }
  let offset = self.data.read_u32(pos + 4) catch { _ => return None }
  if offset == 0 {
    return None
  }
  Some(
    capture(() => ItemVariationStore::read(resolve_offset32(self.data, offset))),
  )
}

///|
/// The segment maps of an axis.
priv struct SegmentMaps {
  maps : FontData
  len : Int
}

///|
fn SegmentMaps::from_(self : SegmentMaps, i : Int) -> Fixed {
  F2Dot14::from_bits(self.maps.read_i16(4 * i) catch { _ => 0 }).to_fixed()
}

///|
fn SegmentMaps::to_(self : SegmentMaps, i : Int) -> Fixed {
  F2Dot14::from_bits(self.maps.read_i16(4 * i + 2) catch { _ => 0 }).to_fixed()
}

///|
/// Applies the piecewise linear mapping to the specified coordinate,
/// matching HarfBuzz's extended avar behavior.
fn SegmentMaps::apply(self : SegmentMaps, coord : Fixed) -> Fixed {
  let len = self.len
  // Special-cases (error-recovery / robustness), as in HB:
  if len < 2 {
    return if len == 0 {
      coord
    } else {
      // len == 1: shift by the single mapping delta
      coord - self.from_(0) + self.to_(0)
    }
  }
  // Now we have at least two mappings. Trim "duplicate" -1/+1 caps in the
  // wild (CoreText quirks), like HB:
  let neg1 = Fixed::from_i32(-1)
  let pos1 = Fixed::from_i32(1)
  let mut start = 0
  let mut end = len
  if self.from_(start) == neg1 &&
    self.to_(start) == neg1 &&
    self.from_(start + 1) == neg1 {
    start += 1
  }
  if self.from_(end - 1) == pos1 &&
    self.to_(end - 1) == pos1 &&
    self.from_(end - 2) == pos1 {
    end -= 1
  }
  // Look for exact match first; handle multiple identical "from" entries.
  let mut i = start
  while i < end {
    if coord == self.from_(i) {
      break
    }
    i += 1
  }
  if i < end {
    // Found at least one exact match; check if there are consecutive
    // equals.
    let mut j = i
    while j + 1 < end && coord == self.from_(j + 1) {
      j += 1
    }
    // Spec-compliant case: exactly one -> return its 'to'.
    if i == j {
      return self.to_(i)
    }
    // Exactly three -> return the middle one.
    if i + 2 == j {
      return self.to_(i + 1)
    }
    // Otherwise, ignore the middle ones. Return the mapping closer to 0 on
    // the *from* side, following HB:
    if coord < Fixed::zero() {
      return self.to_(j)
    }
    if coord > Fixed::zero() {
      return self.to_(i)
    }
    // coord == 0: choose the one with smaller |to|.
    let ti = self.to_(i)
    let tj = self.to_(j)
    return if ti.abs() < tj.abs() { ti } else { tj }
  }
  // Not an exact match: find the segment for interpolation.
  let mut k = start
  while k < end {
    if coord < self.from_(k) {
      break
    }
    k += 1
  }
  if k == 0 {
    // Before all segments: shift by first mapping delta
    return coord - self.from_(0) + self.to_(0)
  }
  if k == end {
    // After all segments: shift by last mapping delta
    return coord - self.from_(end - 1) + self.to_(end - 1)
  }
  // Interpolate between maps[k-1] and maps[k].
  let bf = self.from_(k - 1)
  let bt = self.to_(k - 1)
  let af = self.from_(k)
  let at = self.to_(k)
  let denom = af - bf
  bt + (at - bt).mul_div(coord - bf, denom)
}

///|
/// The [HVAR](https://docs.microsoft.com/en-us/typography/opentype/spec/hvar)
/// table.
pub struct Hvar {
  data : FontData
}

///|
pub fn FontRef::hvar(self : FontRef) -> Hvar raise ReadError {
  let data = self.expect_data_for_tag("HVAR")
  if data.len() < 20 {
    raise OutOfBounds
  }
  { data, }
}

///|
fn Hvar::item_variation_store(
  self : Hvar,
) -> Result[ItemVariationStore, ReadError] {
  capture(() => {
    let offset = self.data.read_u32(4)
    ItemVariationStore::read(resolve_offset32(self.data, offset))
  })
}

///|
fn Hvar::mapping(self : Hvar, at : Int) -> Result[DeltaSetIndexMap, ReadError]? {
  let offset = self.data.read_u32(at) catch { _ => return None }
  if offset == 0 {
    return None
  }
  Some(
    capture(() => DeltaSetIndexMap::read(resolve_offset32(self.data, offset))),
  )
}

///|
/// Returns the advance width delta for the specified glyph identifier and
/// normalized variation coordinates.
pub fn Hvar::advance_width_delta(
  self : Hvar,
  glyph_id : GlyphId,
  coords : ArrayView[F2Dot14],
) -> Fixed raise ReadError {
  advance_delta(
    self.mapping(8),
    self.item_variation_store(),
    glyph_id.to_u32(),
    coords,
  )
}

///|
/// Returns the left side bearing delta for the specified glyph identifier
/// and normalized variation coordinates.
pub fn Hvar::lsb_delta(
  self : Hvar,
  glyph_id : GlyphId,
  coords : ArrayView[F2Dot14],
) -> Fixed raise ReadError {
  item_delta(
    self.mapping(12),
    self.item_variation_store(),
    glyph_id.to_u32(),
    coords,
  )
}

///|
/// Runs `f`, capturing the result (Rust's `Result`).
fn[T] capture(f : () -> T raise ReadError) -> Result[T, ReadError] {
  try f() catch {
    e => Err(e)
  } noraise {
    v => Ok(v)
  }
}
