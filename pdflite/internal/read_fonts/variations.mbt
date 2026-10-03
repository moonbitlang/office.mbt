// Port of read-fonts 0.39.2 `src/tables/variations.rs` (and the generated
// layouts of `generated_variations.rs`): item variation stores, delta set
// index maps and tuple variation data.

///|
/// Outer and inner indices for reading from an [ItemVariationStore].
pub(all) struct DeltaSetIndex {
  /// Outer delta set index.
  outer : Int
  /// Inner delta set index.
  inner : Int
} derive(Eq, Debug)

///|
pub let no_variation_index : DeltaSetIndex = { outer: 0xFFFF, inner: 0xFFFF, }

///|
/// The [DeltaSetIndexMap](https://learn.microsoft.com/en-us/typography/opentype/spec/otvarcommonformats#associating-target-items-to-variation-data)
/// table (formats 0 and 1).
pub struct DeltaSetIndexMap {
  entry_format : Int
  map_count : Int
  map_data : FontData
}

///|
pub fn DeltaSetIndexMap::read(
  data : FontData,
) -> DeltaSetIndexMap raise ReadError {
  let format = data.read_u8(0)
  match format {
    0 => {
      // MIN_SIZE: format, entryFormat, mapCount (u16)
      if data.len() < 4 {
        raise OutOfBounds
      }
      let entry_format = data.read_u8(1)
      let map_count = data.read_u16(2)
      let entry_size = ((entry_format & 0x30) >> 4) + 1
      let map_data = data.read_array(4, map_count, entry_size) catch {
        _ => FontData::empty()
      }
      { entry_format, map_count, map_data, }
    }
    1 => {
      if data.len() < 6 {
        raise OutOfBounds
      }
      let entry_format = data.read_u8(1)
      let map_count = data.read_u32(2).reinterpret_as_int()
      let entry_size = ((entry_format & 0x30) >> 4) + 1
      let map_data = if map_count < 0 {
        FontData::empty()
      } else {
        data.read_array(6, map_count, entry_size) catch {
          _ => FontData::empty()
        }
      }
      { entry_format, map_count, map_data, }
    }
    _ => raise InvalidFormat(format.to_int64())
  }
}

///|
/// Returns the delta set index for the specified value.
pub fn DeltaSetIndexMap::get(
  self : DeltaSetIndexMap,
  index : UInt,
) -> DeltaSetIndex raise ReadError {
  if self.map_count == 0 {
    return {
      outer: ((index >> 16) & 0xFFFF).reinterpret_as_int(),
      inner: (index & 0xFFFF).reinterpret_as_int(),
    }
  }
  let entry_size = ((self.entry_format & 0x30) >> 4) + 1
  // "if an index into the mapping array is used that is greater than or
  // equal to mapCount, then the last logical entry of the mapping array is
  // used."
  let last = (self.map_count - 1).reinterpret_as_uint()
  let index = if index < last { index } else { last }
  let offset = index.reinterpret_as_int() * entry_size
  let entry : UInt = match entry_size {
    1 => self.map_data.read_u8(offset).reinterpret_as_uint()
    2 => self.map_data.read_u16(offset).reinterpret_as_uint()
    3 => self.map_data.read_u24(offset).reinterpret_as_uint()
    4 => self.map_data.read_u32(offset)
    _ => raise MalformedData("invalid entry size in DeltaSetIndexMap")
  }
  let bit_count = (self.entry_format & 0x0F) + 1
  {
    outer: ((entry >> bit_count) & 0xFFFF).reinterpret_as_int(),
    inner: (entry & ((1U << bit_count) - 1U) & 0xFFFF).reinterpret_as_int(),
  }
}

///|
/// The [ItemVariationStore](https://learn.microsoft.com/en-us/typography/opentype/spec/otvarcommonformats#item-variation-store).
pub struct ItemVariationStore {
  data : FontData
}

///|
pub fn ItemVariationStore::read(
  data : FontData,
) -> ItemVariationStore raise ReadError {
  // MIN_SIZE: format (u16), variationRegionListOffset (u32),
  // itemVariationDataCount (u16)
  if data.len() < 8 {
    raise OutOfBounds
  }
  { data, }
}

///|
/// Resolve an `Offset32` relative to `data` (`OutOfBounds` beyond the end,
/// `NullOffset` for 0).
fn resolve_offset32(data : FontData, offset : UInt) -> FontData raise ReadError {
  if offset == 0 {
    raise NullOffset
  }
  if offset > data.len().reinterpret_as_uint() {
    raise OutOfBounds
  }
  data.split_off(offset.reinterpret_as_int()).unwrap()
}

///|
/// The variation region list.
pub fn ItemVariationStore::variation_region_list(
  self : ItemVariationStore,
) -> VariationRegionList raise ReadError {
  let data = resolve_offset32(self.data, self.data.read_u32(2))
  if data.len() < 4 {
    raise OutOfBounds
  }
  { data, }
}

///|
/// The number of item variation data subtables (as available).
pub fn ItemVariationStore::item_variation_data_count(
  self : ItemVariationStore,
) -> Int {
  let count = self.data.read_u16(6) catch { _ => 0 }
  // `read_array(range).unwrap_or_default()`: an out of bounds array is
  // empty.
  if 8 + 4 * count > self.data.len() {
    0
  } else {
    count
  }
}

///|
/// The item variation data at `index`: `None` if the index is out of range
/// or the offset is null; raises for a malformed subtable.
pub fn ItemVariationStore::item_variation_data(
  self : ItemVariationStore,
  index : Int,
) -> ItemVariationData? raise ReadError {
  if index < 0 || index >= self.item_variation_data_count() {
    return None
  }
  let offset = self.data.read_u32(8 + 4 * index)
  // Nullable offsets: a null offset resolves to nothing.
  if offset == 0 {
    return None
  }
  let data = resolve_offset32(self.data, offset)
  if data.len() < 6 {
    raise OutOfBounds
  }
  Some({ data, })
}

///|
/// Computes the delta value for the specified index and set of normalized
/// variation coordinates.
pub fn ItemVariationStore::compute_delta(
  self : ItemVariationStore,
  index : DeltaSetIndex,
  coords : ArrayView[F2Dot14],
) -> Int raise ReadError {
  if coords.length() == 0 || index == no_variation_index {
    return 0
  }
  guard self.item_variation_data(index.outer) is Some(data) else { return 0 }
  let regions = self.variation_region_list()
  let region_indices = data.region_indexes()
  // Compute deltas with 64-bit precision.
  let mut accum = 0L
  for i, region_delta in data.delta_set(index.inner) {
    if i >= region_indices.length() {
      raise MalformedData("invalid delta sets in ItemVariationStore")
    }
    let region = regions.get(region_indices[i])
    let scalar = region.compute_scalar(coords)
    accum = accum + region_delta.to_int64() * scalar.to_bits().to_int64()
  }
  ((accum + 0x8000L) >> 16).to_int()
}

///|
/// Computes the delta value in floating point for the specified index and
/// set of normalized variation coordinates.
pub fn ItemVariationStore::compute_float_delta(
  self : ItemVariationStore,
  index : DeltaSetIndex,
  coords : ArrayView[F2Dot14],
) -> Double raise ReadError {
  if coords.length() == 0 {
    return 0.0
  }
  guard self.item_variation_data(index.outer) is Some(data) else { return 0.0 }
  let regions = self.variation_region_list()
  let region_indices = data.region_indexes()
  // Compute deltas in 64-bit floating point.
  let mut accum = 0.0
  for i, region_delta in data.delta_set(index.inner) {
    if i >= region_indices.length() {
      raise MalformedData("invalid delta sets in ItemVariationStore")
    }
    let region = regions.get(region_indices[i])
    let scalar = region.compute_scalar_f32(coords)
    accum = accum + region_delta.to_double() * scalar.to_double()
  }
  accum
}

///|
/// The variation region list.
pub struct VariationRegionList {
  data : FontData
}

///|
pub fn VariationRegionList::axis_count(self : VariationRegionList) -> Int {
  self.data.read_u16(0) catch {
    _ => 0
  }
}

///|
pub fn VariationRegionList::region_count(self : VariationRegionList) -> Int {
  let count = self.data.read_u16(2) catch { _ => 0 }
  // `read_with_args(range).unwrap_or_default()` (in 64 bits: the product
  // of two `u16` counts overflows an `Int`)
  if 4L + count.to_int64() * self.axis_count().to_int64() * 6L >
    self.data.len().to_int64() {
    0
  } else {
    count
  }
}

///|
/// The region at `index` (`OutOfBounds` if out of range).
pub fn VariationRegionList::get(
  self : VariationRegionList,
  index : Int,
) -> VariationRegion raise ReadError {
  if index < 0 || index >= self.region_count() {
    raise OutOfBounds
  }
  let axis_count = self.axis_count()
  let start = 4 + index * axis_count * 6
  { data: self.data.slice(start, start + axis_count * 6).unwrap(), axis_count, }
}

///|
/// A variation region: a start, peak and end coordinate for each axis.
pub struct VariationRegion {
  data : FontData
  axis_count : Int
}

///|
fn VariationRegion::axis(self : VariationRegion, i : Int) -> (Int, Int, Int) {
  let s = self.data.read_i16(6 * i) catch { _ => 0 }
  let p = self.data.read_i16(6 * i + 2) catch { _ => 0 }
  let e = self.data.read_i16(6 * i + 4) catch { _ => 0 }
  (s, p, e)
}

///|
/// Computes a scalar value for this region and the specified normalized
/// variation coordinates.
pub fn VariationRegion::compute_scalar(
  self : VariationRegion,
  coords : ArrayView[F2Dot14],
) -> Fixed {
  let zero = Fixed::zero()
  let mut scalar = Fixed::one()
  for i in 0..<self.axis_count {
    let (s, p, e) = self.axis(i)
    if p == 0 {
      continue
    }
    let peak = F2Dot14::from_bits(p).to_fixed()
    let start = F2Dot14::from_bits(s).to_fixed()
    let end = F2Dot14::from_bits(e).to_fixed()
    if start > peak || peak > end || (start < zero && end > zero) {
      continue
    }
    let coord = if i < coords.length() { coords[i].to_fixed() } else { zero }
    if coord < start || coord > end {
      return zero
    } else if coord == peak {
      continue
    } else if coord < peak {
      scalar = scalar.mul_div(coord - start, peak - start)
    } else {
      scalar = scalar.mul_div(end - coord, end - peak)
    }
  }
  scalar
}

///|
/// Computes a floating point scalar value for this region and the specified
/// normalized variation coordinates.
pub fn VariationRegion::compute_scalar_f32(
  self : VariationRegion,
  coords : ArrayView[F2Dot14],
) -> Float {
  let mut scalar : Float = 1.0
  for i in 0..<self.axis_count {
    let (s, p, e) = self.axis(i)
    if p == 0 {
      continue
    }
    let peak = F2Dot14::from_bits(p).to_f32()
    let start = F2Dot14::from_bits(s).to_f32()
    let end = F2Dot14::from_bits(e).to_f32()
    if start > peak || peak > end || (start < 0.0 && end > 0.0) {
      continue
    }
    let coord : Float = if i < coords.length() {
      coords[i].to_f32()
    } else {
      0.0
    }
    if coord < start || coord > end {
      return 0.0
    } else if coord == peak {
      continue
    } else if coord < peak {
      scalar = scalar * (coord - start) / (peak - start)
    } else {
      scalar = scalar * (end - coord) / (end - peak)
    }
  }
  scalar
}

///|
/// An item variation data subtable.
pub struct ItemVariationData {
  data : FontData
}

///|
pub fn ItemVariationData::item_count(self : ItemVariationData) -> Int {
  self.data.read_u16(0) catch {
    _ => 0
  }
}

///|
pub fn ItemVariationData::word_delta_count(self : ItemVariationData) -> Int {
  self.data.read_u16(2) catch {
    _ => 0
  }
}

///|
pub fn ItemVariationData::region_index_count(self : ItemVariationData) -> Int {
  self.data.read_u16(4) catch {
    _ => 0
  }
}

///|
/// The indices into the variation region list (empty if out of bounds).
pub fn ItemVariationData::region_indexes(
  self : ItemVariationData,
) -> Array[Int] {
  let n = self.region_index_count()
  let out = []
  if 6 + 2 * n > self.data.len() {
    return out
  }
  for i in 0..<n {
    out.push(self.data.read_u16(6 + 2 * i) catch { _ => 0 })
  }
  out
}

///|
/// The length of one delta set.
pub fn ItemVariationData::delta_row_len(
  word_delta_count : Int,
  region_index_count : Int,
) -> Int {
  let long_words = (word_delta_count & 0x8000) != 0
  let (word_size, small_size) = if long_words { (4, 2) } else { (2, 1) }
  let long_delta_count = word_delta_count & 0x7FFF
  let short_delta_count = if region_index_count > long_delta_count {
    region_index_count - long_delta_count
  } else {
    0
  }
  long_delta_count * word_size + short_delta_count * small_size
}

///|
/// The per-region delta values for the specified inner index.
pub fn ItemVariationData::delta_set(
  self : ItemVariationData,
  inner_index : Int,
) -> Array[Int] {
  let word_delta_count = self.word_delta_count()
  let region_count = self.region_index_count()
  let bytes_per_row = ItemVariationData::delta_row_len(
    word_delta_count, region_count,
  )
  let long_words = (word_delta_count & 0x8000) != 0
  let word_delta_count = word_delta_count & 0x7FFF
  // `delta_sets()` is empty if the rows don't fit into the data.
  // (In 64 bits, like Rust's `usize`.)
  let sets_start = 6 + 2 * region_count
  let sets_end = sets_start.to_int64() +
    bytes_per_row.to_int64() * self.item_count().to_int64()
  let sets = if sets_end <= self.data.len().to_int64() {
    self.data.slice(sets_start, sets_end.to_int()).unwrap_or(FontData::empty())
  } else {
    FontData::empty()
  }
  let offset = bytes_per_row.to_int64() * inner_index.to_int64()
  let cursor = if offset <= sets.len().to_int64() {
    sets.split_off(offset.to_int()).unwrap_or(FontData::empty()).cursor()
  } else {
    FontData::empty().cursor()
  }
  let out = []
  for pos in 0..<region_count {
    let value = try {
      if pos >= word_delta_count {
        if long_words {
          cursor.read_i16()
        } else {
          cursor.read_i8()
        }
      } else if long_words {
        cursor.read_i32()
      } else {
        cursor.read_i16()
      }
    } catch {
      _ => break
    }
    out.push(value)
  }
  out
}

///|
/// Applies `HVAR`-style advance deltas: an index map is optional.
pub fn advance_delta(
  dsim : Result[DeltaSetIndexMap, ReadError]?,
  ivs : Result[ItemVariationStore, ReadError],
  glyph_id : UInt,
  coords : ArrayView[F2Dot14],
) -> Fixed raise ReadError {
  if coords.length() == 0 {
    return Fixed::zero()
  }
  let ix = match dsim {
    Some(Ok(dsim)) => dsim.get(glyph_id)
    _ => { outer: 0, inner: (glyph_id & 0xFFFF).reinterpret_as_int(), }
  }
  let ivs = match ivs {
    Ok(ivs) => ivs
    Err(e) => raise e
  }
  Fixed::from_i32(ivs.compute_delta(ix, coords))
}

///|
/// Applies an item delta whose index map is required.
pub fn item_delta(
  dsim : Result[DeltaSetIndexMap, ReadError]?,
  ivs : Result[ItemVariationStore, ReadError],
  glyph_id : UInt,
  coords : ArrayView[F2Dot14],
) -> Fixed raise ReadError {
  if coords.length() == 0 {
    return Fixed::zero()
  }
  let ix = match dsim {
    Some(Ok(dsim)) => dsim.get(glyph_id)
    _ => raise NullOffset
  }
  let ivs = match ivs {
    Ok(ivs) => ivs
    Err(e) => raise e
  }
  Fixed::from_i32(ivs.compute_delta(ix, coords))
}
