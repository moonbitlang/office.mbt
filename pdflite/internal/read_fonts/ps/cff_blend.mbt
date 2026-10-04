// Port of read-fonts 0.39.2 `src/ps/cff/blend.rs`, `src/ps/cff/v2.rs` and
// `Stack::apply_blend` (`src/ps/cff/stack.rs`).

///|
/// The maximum number of region scalars that we precompute.
const MAX_PRECOMPUTED_SCALARS : Int = 16

///|
/// State for processing the blend operator for DICTs and charstrings.
pub struct BlendState {
  store : @read_fonts.ItemVariationStore
  coords : ArrayView[@font_types.F2Dot14]
  mut store_index : Int
  // The following are dependent on the current `store_index`
  mut region_indices : Array[Int]
  scalars : FixedArray[Fixed]
}

///|
pub fn BlendState::new(
  store : @read_fonts.ItemVariationStore,
  coords : ArrayView[@font_types.F2Dot14],
  store_index : Int,
) -> BlendState raise PsError {
  let state : BlendState = {
    store,
    coords,
    store_index,
    region_indices: [],
    scalars: FixedArray::make(MAX_PRECOMPUTED_SCALARS, Fixed::zero()),
  }
  state.update_precomputed_scalars()
  state
}

///|
/// Sets the active variation store index.
pub fn BlendState::set_store_index(
  self : BlendState,
  store_index : Int,
) -> Unit raise PsError {
  if self.store_index != store_index {
    self.store_index = store_index
    self.update_precomputed_scalars()
  }
}

///|
/// Returns the number of variation regions for the currently active
/// variation store index.
pub fn BlendState::region_count(self : BlendState) -> Int {
  self.region_indices.length()
}

///|
/// The scalar of each variation region of the currently active variation
/// store index.
pub fn BlendState::scalar(self : BlendState, i : Int) -> Fixed raise PsError {
  if i < MAX_PRECOMPUTED_SCALARS {
    self.scalars[i]
  } else {
    self.region_scalar(self.region_indices[i])
  }
}

///|
fn BlendState::update_precomputed_scalars(
  self : BlendState,
) -> Unit raise PsError {
  self.region_indices = []
  let data = self.store.item_variation_data(self.store_index) catch {
    e => raise Read(e)
  }
  guard data is Some(data) else {
    raise InvalidVariationStoreIndex(self.store_index)
  }
  let region_indices = data.region_indexes()
  let regions = self.store.variation_region_list() catch { e => raise Read(e) }
  // Precompute scalars for all regions up to MAX_PRECOMPUTED_SCALARS
  for i, region_ix in region_indices {
    if i >= MAX_PRECOMPUTED_SCALARS {
      break
    }
    let region = regions.get(region_ix) catch { e => raise Read(e) }
    self.scalars[i] = region.compute_scalar(self.coords)
  }
  self.region_indices = region_indices
}

///|
fn BlendState::region_scalar(
  self : BlendState,
  index : Int,
) -> Fixed raise PsError {
  let regions = self.store.variation_region_list() catch { e => raise Read(e) }
  let region = regions.get(index) catch { e => raise Read(e) }
  region.compute_scalar(self.coords)
}

///|
/// Applies the blend operator: the stack contains a set of target values,
/// followed by sets of deltas for those values for each variation region,
/// followed by the count of target values.
pub fn Stack::apply_blend(
  self : Stack,
  blend_state : BlendState,
) -> Unit raise PsError {
  let target_value_count = self.pop_i32()
  if target_value_count < 0 || target_value_count > self.top {
    raise StackUnderflow
  }
  let region_count = blend_state.region_count()
  // We expect at least `target_value_count * (region_count + 1)` elements
  // on the stack.
  let operand_count = target_value_count * (region_count + 1)
  if self.len() < operand_count {
    raise StackUnderflow
  }
  // The stack may contain more elements than necessary, so keep track of
  // our active range.
  let start = self.len() - operand_count
  let end = start + operand_count
  // For simplicity, convert all elements to fixed up front.
  for i in start..<end {
    if !self.value_is_fixed[i] {
      self.values[i] = Fixed::from_i32(self.values[i]).to_bits()
      self.value_is_fixed[i] = true
    }
  }
  let deltas_start = start + target_value_count
  // Note: we specifically loop over scalars in the outer loop to avoid
  // computing them more than once in the case that we overflow our
  // precomputed cache.
  for region_ix in 0..<region_count {
    let scalar = blend_state.scalar(region_ix)
    if scalar == Fixed::zero() {
      continue
    }
    for value_ix in 0..<target_value_count {
      let delta_ix = region_count * value_ix + region_ix
      let delta = Fixed::from_bits(self.values[deltas_start + delta_ix])
      let value = Fixed::from_bits(self.values[start + value_ix])
      self.values[start + value_ix] = value
        .wrapping_add(delta * scalar)
        .to_bits()
    }
  }
  self.top = start + target_value_count
}

///|
/// The [Compact Font Format (CFF) version 2](https://learn.microsoft.com/en-us/typography/opentype/spec/cff2)
/// table.
pub struct Cff2 {
  data : BytesView
  top_dict_data : BytesView
  global_subrs : Index
}

///|
/// Read a CFF2 table: header (major, minor, headerSize, topDictLength),
/// the Top DICT and the global subroutine index.
///
/// Like read-fonts' generated `Cff2Header`, the Top DICT starts at
/// `max(headerSize, 5)` and an out-of-bounds Top DICT range reads as empty
/// data (as does the trailing data after it). The global subroutines are
/// read with the CFF2 `Index` table reader, which needs at least 5 bytes.
pub fn Cff2::read(data : BytesView) -> Cff2 raise PsError {
  if data.length() < 5 {
    raise Read(OutOfBounds)
  }
  let header_size = data[2].to_int()
  let top_dict_length = (data[3].to_int() << 8) | data[4].to_int()
  let start = if header_size > 5 { header_size } else { 5 }
  let end = start + top_dict_length
  let (top_dict_data, trailing) = if end <= data.length() {
    (data[start:end], data[end:])
  } else {
    (data[0:0], data[0:0])
  }
  let global_subrs = Index::Format1(Index1::read2(trailing))
  { data, top_dict_data, global_subrs, }
}

///|
pub fn Cff2::offset_data(self : Cff2) -> BytesView {
  self.data
}

///|
pub fn Cff2::top_dict_data(self : Cff2) -> BytesView {
  self.top_dict_data
}

///|
pub fn Cff2::global_subrs(self : Cff2) -> Index {
  self.global_subrs
}
