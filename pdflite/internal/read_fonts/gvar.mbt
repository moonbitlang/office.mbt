// Port of read-fonts 0.39.2 `src/tables/gvar.rs` and the tuple variation
// parts of `src/tables/variations.rs` (for glyph deltas).

///|
/// The [gvar](https://learn.microsoft.com/en-us/typography/opentype/spec/gvar)
/// table.
pub struct Gvar {
  data : FontData
}

///|
pub fn FontRef::gvar(self : FontRef) -> Gvar raise ReadError {
  let data = self.expect_data_for_tag("gvar")
  // MIN_SIZE: version, axisCount, sharedTupleCount, sharedTuplesOffset,
  // glyphCount, flags, glyphVariationDataArrayOffset
  if data.len() < 20 {
    raise OutOfBounds
  }
  { data, }
}

///|
pub fn Gvar::axis_count(self : Gvar) -> Int {
  self.data.read_u16(4) catch {
    _ => 0
  }
}

///|
fn Gvar::shared_tuple_count(self : Gvar) -> Int {
  self.data.read_u16(6) catch {
    _ => 0
  }
}

///|
fn Gvar::glyph_count(self : Gvar) -> Int {
  self.data.read_u16(12) catch {
    _ => 0
  }
}

///|
fn Gvar::long_offsets(self : Gvar) -> Bool {
  ((self.data.read_u16(14) catch { _ => 0 }) & 1) != 0
}

///|
fn Gvar::glyph_variation_data_array_offset(self : Gvar) -> UInt {
  self.data.read_u32(16) catch {
    _ => 0
  }
}

///|
/// The shared tuples (each `axis_count` F2Dot14 values; empty if out of
/// bounds). A null offset is an error (`Offset32::resolve_with_args`).
fn Gvar::shared_tuples(self : Gvar) -> FontData raise ReadError {
  let offset = self.data.read_u32(8)
  if offset == 0 {
    raise NullOffset
  }
  if offset > self.data.len().reinterpret_as_uint() {
    raise OutOfBounds
  }
  let data = self.data.split_off(offset.reinterpret_as_int()).unwrap()
  data.read_array(0, self.shared_tuple_count(), 2 * self.axis_count()) catch {
    _ => FontData::empty()
  }
}

///|
/// The glyph variation data offset for `idx` (relative to the data array).
fn Gvar::data_offset(self : Gvar, idx : Int) -> UInt raise ReadError {
  let size = if self.long_offsets() { 4 } else { 2 }
  let count = self.glyph_count() + 1
  // `read_with_args(range).unwrap_or_default()`: an out of bounds array is
  // empty.
  if 20 + count * size > self.data.len() || idx >= count {
    raise OutOfBounds
  }
  if self.long_offsets() {
    self.data.read_u32(20 + 4 * idx)
  } else {
    (self.data.read_u16(20 + 2 * idx) * 2).reinterpret_as_uint()
  }
}

///|
/// Return the raw data for this gid, `None` if there is no variation data.
fn Gvar::data_for_gid(self : Gvar, gid : UInt) -> FontData? raise ReadError {
  let start_idx = gid.reinterpret_as_int()
  let data_start = self.glyph_variation_data_array_offset().to_uint64()
  let start = data_start + self.data_offset(start_idx).to_uint64()
  let end = data_start + self.data_offset(start_idx + 1).to_uint64()
  // (`u32::checked_add`)
  if start > 0xFFFFFFFFUL || end > 0xFFFFFFFFUL {
    raise OutOfBounds
  }
  if start >= end {
    return None
  }
  match self.data.slice(start.to_int(), end.to_int()) {
    Some(data) => Some(data)
    None => raise OutOfBounds
  }
}

///|
/// Get the variation data for a specific glyph: `None` if there is no
/// variation data for this glyph; raises if there is data but it is
/// malformed.
pub fn Gvar::glyph_variation_data(
  self : Gvar,
  gid : UInt,
) -> GlyphVariationData? raise ReadError {
  let shared_tuples = self.shared_tuples()
  let axis_count = self.axis_count()
  guard self.data_for_gid(gid) is Some(data) else { return None }
  Some(GlyphVariationData::new(data, axis_count, shared_tuples))
}

///|
/// Returns the phantom point deltas (`[left, right, top, bottom]` as 16.16
/// bits) for the given variation coordinates and glyph identifier, if
/// variation data exists for the glyph.
pub fn Gvar::phantom_point_deltas(
  self : Gvar,
  glyf : Glyf,
  loca : Loca,
  coords : ArrayView[F2Dot14],
  glyph_id : GlyphId,
) -> Array[(Int, Int)]? raise ReadError {
  let (glyph_id, point_count) = find_glyph_and_point_count(
    glyf, loca, glyph_id, 0,
  )
  let phantom_deltas = Array::make(4, (0, 0))
  guard self.glyph_variation_data(glyph_id.to_u32()) is Some(var_data) else {
    return None
  }
  // Note that phantom points can never belong to a contour so we don't
  // have to handle the IUP case here.
  for entry in var_data.active_tuples_at(coords) {
    let (tuple, scalar) = entry
    for d in tuple.deltas() {
      let ix = d.position
      if ix >= point_count && ix < point_count + 4 {
        let (x, y) = phantom_deltas[ix - point_count]
        let (dx, dy) = d.apply_scalar(scalar)
        phantom_deltas[ix - point_count] = (x + dx, y + dy)
      }
    }
  }
  Some(phantom_deltas)
}

///|
/// Given a glyph identifier, searches for the glyph that contains the
/// actual metrics for rendering, and returns it with its number of points
/// (or components).
fn find_glyph_and_point_count(
  glyf : Glyf,
  loca : Loca,
  glyph_id : GlyphId,
  recurse_depth : Int,
) -> (GlyphId, Int) raise ReadError {
  // Matches HB's nesting limit
  if recurse_depth > 64 {
    raise MalformedData("nesting too deep in composite glyph")
  }
  guard loca.get_glyf(glyph_id, glyf) is Some(glyph) else {
    // Empty glyphs might still contain gvar data that only affects phantom
    // points
    return (glyph_id, 0)
  }
  match glyph {
    // Simple glyphs always use their own metrics
    Simple(simple) => (glyph_id, simple.num_points())
    Composite(composite) => {
      // For composite glyphs, recurse into the glyph referenced by the
      // *last* component that has the USE_MY_METRICS flag set. Otherwise,
      // return the composite glyph itself and the number of components as
      // the point count.
      let (components, _) = composite.component_glyphs_and_flags()
      let mut inherit_metrics = None
      for c in components {
        let (component_id, flags) = c
        if (flags & USE_MY_METRICS) != 0 {
          inherit_metrics = Some(component_id)
        }
      }
      match inherit_metrics {
        Some(component) =>
          find_glyph_and_point_count(
            glyf,
            loca,
            GlyphId::from_int(component),
            recurse_depth + 1,
          )
        None => (glyph_id, components.length())
      }
    }
  }
}

///|
/// Delta information for a single point or component in a glyph.
pub(all) struct GlyphDelta {
  /// The point or component index.
  position : Int
  /// The x delta.
  x_delta : Int
  /// The y delta.
  y_delta : Int
}

///|
/// Applies a tuple scalar to this delta (as 16.16 bits).
pub fn GlyphDelta::apply_scalar(
  self : GlyphDelta,
  scalar : Fixed,
) -> (Int, Int) {
  (
    (Fixed::from_i32(self.x_delta) * scalar).to_bits(),
    (Fixed::from_i32(self.y_delta) * scalar).to_bits(),
  )
}

///|
/// Tuple variation data of a glyph.
pub struct GlyphVariationData {
  axis_count : Int
  shared_tuples : FontData
  shared_point_numbers : FontData?
  tuple_count : Int
  // the data for all the tuple variation headers
  header_data : FontData
  // the data for all the tuple bodies
  serialized_data : FontData
}

///|
fn GlyphVariationData::new(
  data : FontData,
  axis_count : Int,
  shared_tuples : FontData,
) -> GlyphVariationData raise ReadError {
  // GlyphVariationDataHeader: tupleVariationCount, dataOffset
  if data.len() < 4 {
    raise OutOfBounds
  }
  let count = data.read_u16(0)
  let serialized_offset = data.read_u16(2)
  let header_data = data.split_off(4).unwrap()
  if serialized_offset == 0 {
    raise NullOffset
  }
  guard data.split_off(serialized_offset) is Some(serialized) else {
    raise OutOfBounds
  }
  // if there are shared point numbers, get them now
  let (shared_point_numbers, serialized_data) = if (count & 0x8000) != 0 {
    let (packed, rest) = packed_points_split_off_front(serialized)
    (Some(packed), rest)
  } else {
    (None, serialized)
  }
  {
    tuple_count: count & 0x0FFF,
    axis_count,
    shared_tuples,
    shared_point_numbers,
    header_data,
    serialized_data,
  }
}

///|
/// A tuple variation header.
priv struct TupleVariationHeader {
  data : FontData
  variation_data_size : Int
  tuple_index : Int
  axis_count : Int
}

///|
fn TupleVariationHeader::read(
  data : FontData,
  axis_count : Int,
) -> TupleVariationHeader raise ReadError {
  if data.len() < 4 {
    raise OutOfBounds
  }
  let variation_data_size = data.read_u16(0)
  let tuple_index = data.read_u16(2)
  let tuple_len = 2 * axis_count
  let peak_len = if (tuple_index & 0x8000) != 0 { tuple_len } else { 0 }
  let inter_len = if (tuple_index & 0x4000) != 0 { 2 * tuple_len } else { 0 }
  if data.len() < 4 + peak_len + inter_len {
    raise OutOfBounds
  }
  { data, variation_data_size, tuple_index, axis_count, }
}

///|
fn TupleVariationHeader::byte_len(self : TupleVariationHeader) -> Int {
  let tuple_byte_len = 2 * self.axis_count
  4 +
  (if (self.tuple_index & 0x8000) != 0 { tuple_byte_len } else { 0 }) +
  (if (self.tuple_index & 0x4000) != 0 { tuple_byte_len * 2 } else { 0 })
}

///|
/// The embedded peak tuple (offset of its first value).
fn TupleVariationHeader::peak_tuple(self : TupleVariationHeader) -> FontData? {
  if (self.tuple_index & 0x8000) != 0 {
    self.data.slice(4, 4 + 2 * self.axis_count)
  } else {
    None
  }
}

///|
fn TupleVariationHeader::intermediate_tuples(
  self : TupleVariationHeader,
) -> (FontData, FontData)? {
  if (self.tuple_index & 0x4000) != 0 {
    let start = 4 +
      (if (self.tuple_index & 0x8000) != 0 { 2 * self.axis_count } else { 0 })
    let len = 2 * self.axis_count
    Some(
      (
        self.data.slice(start, start + len).unwrap(),
        self.data.slice(start + len, start + 2 * len).unwrap(),
      ),
    )
  } else {
    None
  }
}

///|
fn tuple_get(t : FontData, i : Int) -> F2Dot14 {
  F2Dot14::from_bits(t.read_i16(2 * i) catch { _ => 0 })
}

///|
/// A single set of tuple variation data.
pub struct TupleVariation {
  priv header : TupleVariationHeader
  priv serialized_data : FontData
  priv shared_point_numbers : FontData?
}

///|
/// Returns all of the pairs of (variation tuple, scalar) for this glyph that
/// are active for the given set of normalized coordinates.
pub fn GlyphVariationData::active_tuples_at(
  self : GlyphVariationData,
  coords : ArrayView[F2Dot14],
) -> Array[(TupleVariation, Fixed)] {
  let out = []
  let mut header_data = self.header_data
  let mut data_offset = 0
  for _ in 0..<self.tuple_count {
    // `TupleVariationHeaderIter::next`: a failed read stops the iteration.
    let header = TupleVariationHeader::read(header_data, self.axis_count) catch {
      _ => break
    }
    guard header_data.split_off(header.byte_len()) is Some(next) else { break }
    header_data = next
    let data_len = header.variation_data_size
    let data_start = data_offset
    let data_end = data_start + data_len
    data_offset = data_end
    if compute_tuple_scalar(header, self.axis_count, self.shared_tuples, coords)
      is Some(scalar) {
      guard self.serialized_data.slice(data_start, data_end) is Some(var_data) else {
        break
      }
      out.push(
        (
          {
            header,
            serialized_data: var_data,
            shared_point_numbers: self.shared_point_numbers,
          },
          scalar,
        ),
      )
    }
  }
  out
}

///|
/// Compute the fixed point scalar for this tuple at the given location in
/// variation space (`None` if the tuple is not applicable).
fn compute_tuple_scalar(
  header : TupleVariationHeader,
  axis_count : Int,
  shared_tuples : FontData,
  coords : ArrayView[F2Dot14],
) -> Fixed? {
  let mut scalar = Fixed::one()
  let peak = if (header.tuple_index & 0x8000) == 0 {
    let shared_index = header.tuple_index & 0x0FFF
    let len = 2 * axis_count
    guard shared_tuples.slice(shared_index * len, shared_index * len + len)
      is Some(t) else {
      return None
    }
    t
  } else {
    guard header.peak_tuple() is Some(t) else { return None }
    t
  }
  if peak.len() / 2 != axis_count {
    return None
  }
  let intermediate = header.intermediate_tuples()
  for i in 0..<axis_count {
    let peak = tuple_get(peak, i)
    if peak == F2Dot14::zero() {
      continue
    }
    let coord = if i < coords.length() { coords[i] } else { F2Dot14::zero() }
    if coord == F2Dot14::zero() {
      return None
    }
    if peak == coord {
      continue
    }
    match intermediate {
      Some((inter_start, inter_end)) => {
        let start = tuple_get(inter_start, i)
        let end = tuple_get(inter_end, i)
        if coord <= start || coord >= end {
          return None
        }
        let coord = coord.to_fixed()
        let peak = peak.to_fixed()
        if coord < peak {
          let start = start.to_fixed()
          scalar = scalar.mul_div(coord - start, peak - start)
        } else {
          let end = end.to_fixed()
          scalar = scalar.mul_div(end - coord, end - peak)
        }
      }
      None => {
        let zero = F2Dot14::zero()
        let lo = if peak < zero { peak } else { zero }
        let hi = if peak > zero { peak } else { zero }
        if coord < lo || coord > hi {
          return None
        }
        scalar = scalar.mul_div(coord.to_fixed(), peak.to_fixed())
      }
    }
  }
  if scalar == Fixed::zero() {
    None
  } else {
    Some(scalar)
  }
}

///|
fn TupleVariation::point_numbers_and_packed_deltas(
  self : TupleVariation,
) -> (FontData, FontData) {
  if (self.header.tuple_index & 0x2000) != 0 {
    packed_points_split_off_front(self.serialized_data)
  } else {
    (
      match self.shared_point_numbers {
        Some(p) => p
        None => FontData::empty()
      },
      self.serialized_data,
    )
  }
}

///|
/// Returns true if this tuple provides deltas for all points in a glyph.
pub fn TupleVariation::has_deltas_for_all_points(self : TupleVariation) -> Bool {
  if (self.header.tuple_index & 0x2000) != 0 {
    packed_points_count(self.serialized_data).0 == 0
  } else {
    match self.shared_point_numbers {
      Some(shared) => packed_points_count(shared).0 == 0
      None => false
    }
  }
}

///|
/// The explicitly encoded deltas of this tuple (not accounting for
/// scaling).
pub fn TupleVariation::deltas(self : TupleVariation) -> Array[GlyphDelta] {
  let (point_numbers, packed_deltas) = self.point_numbers_and_packed_deltas()
  let count = packed_points_count(point_numbers).0
  let (xs, ys) = if count == 0 {
    // `PackedDeltas::consume_all`: the count is computed from the data.
    let total = count_all_deltas(packed_deltas)
    (
      delta_run_values(packed_deltas, 0, total / 2),
      delta_run_values(packed_deltas, total / 2, total),
    )
  } else {
    (
      delta_run_values(packed_deltas, 0, count),
      delta_run_values(packed_deltas, count, 2 * count),
    )
  }
  let out = []
  if count == 0 {
    // no points, every point has a delta.
    let n = if xs.length() < ys.length() { xs.length() } else { ys.length() }
    for i in 0..<n {
      out.push({ position: i, x_delta: xs[i], y_delta: ys[i], })
    }
  } else {
    let points = packed_points_iter(point_numbers)
    // `TupleDeltaIter`: walk the (sorted) point numbers.
    let mut cur = 0
    let mut pi = 0
    let mut di = 0
    guard pi < points.length() else { return out }
    let mut next_point = points[pi]
    pi += 1
    for ;; {
      if cur > next_point {
        guard pi < points.length() else { break }
        next_point = points[pi]
        pi += 1
      }
      let position = next_point
      if position == cur {
        guard di < xs.length() && di < ys.length() else { break }
        out.push({ position, x_delta: xs[di], y_delta: ys[di], })
        di += 1
        cur += 1
      } else {
        cur += 1
      }
    }
  }
  out
}

///|
/// Reads the dense set of deltas from this tuple variation into `xs`/`ys`
/// (16.16 bits), multiplied by `scalar` (`accumulate_dense_deltas`).
pub fn TupleVariation::accumulate_dense_deltas(
  self : TupleVariation,
  xs : FixedArray[Int],
  ys : FixedArray[Int],
  n : Int,
  scalar : Fixed,
) -> Unit raise ReadError {
  let (_, packed_deltas) = self.point_numbers_and_packed_deltas()
  let cursor = packed_deltas.cursor()
  let one = scalar == Fixed::one()
  let f = (new_delta : Int) => {
    if one {
      Fixed::from_i32(new_delta).to_bits()
    } else {
      (Fixed::from_i32(new_delta) * scalar).to_bits()
    }
  }
  read_dense_deltas(cursor, n, (i, d) => xs[i] = xs[i] + f(d))
  read_dense_deltas(cursor, n, (i, d) => ys[i] = ys[i] + f(d))
}

///|
/// Reads the sparse set of deltas from this tuple variation into `xs`/`ys`
/// (16.16 bits), marking `HAS_DELTA` in `flags`
/// (`accumulate_sparse_deltas`).
pub fn TupleVariation::accumulate_sparse_deltas(
  self : TupleVariation,
  xs : FixedArray[Int],
  ys : FixedArray[Int],
  flags : FixedArray[Int],
  n : Int,
  scalar : Fixed,
) -> Unit raise ReadError {
  let (point_numbers, packed_deltas) = self.point_numbers_and_packed_deltas()
  let cursor = packed_deltas.cursor()
  let count = packed_points_count(point_numbers).0
  let points = packed_points_iter(point_numbers)
  let one = scalar == Fixed::one()
  let f = (new_delta : Int) => {
    if one {
      Fixed::from_i32(new_delta).to_bits()
    } else {
      (Fixed::from_i32(new_delta) * scalar).to_bits()
    }
  }
  read_sparse_deltas(cursor, points, count, (ix, d) => {
    if ix < n {
      xs[ix] = xs[ix] + f(d)
      flags[ix] = flags[ix] | 0x4
    }
  })
  read_sparse_deltas(cursor, points, count, (ix, d) => {
    if ix < n {
      ys[ix] = ys[ix] + f(d)
    }
  })
}

///|
fn read_dense_deltas(
  cursor : Cursor,
  count : Int,
  f : (Int, Int) -> Unit,
) -> Unit raise ReadError {
  let mut cur = 0
  while cur < count {
    let control = cursor.read_u8()
    let run_count = (control & 0x3F) + 1
    if cur + run_count > count {
      raise OutOfBounds
    }
    match delta_run_type(control) {
      0 => ()
      size => {
        // `read_array` fails before any delta of the run is applied.
        let start = cursor.pos
        cursor.read_array(run_count, size) |> ignore
        let data = cursor.data
        for k in 0..<run_count {
          let p = start + k * size
          let v = match size {
            1 => data.read_i8(p)
            2 => data.read_i16(p)
            _ => data.read_i32(p)
          }
          f(cur + k, v)
        }
      }
    }
    cur += run_count
  }
}

///|
fn read_sparse_deltas(
  cursor : Cursor,
  points : Array[Int],
  count : Int,
  f : (Int, Int) -> Unit,
) -> Unit raise ReadError {
  let mut cur = 0
  let mut pi = 0
  while cur < count {
    let control = cursor.read_u8()
    let run_count = (control & 0x3F) + 1
    match delta_run_type(control) {
      0 =>
        for _ in 0..<run_count {
          guard pi < points.length() else { raise OutOfBounds }
          f(points[pi], 0)
          pi += 1
        }
      size => {
        let start = cursor.pos
        cursor.read_array(run_count, size) |> ignore
        let data = cursor.data
        for k in 0..<run_count {
          // (`zip` with the remaining point numbers.)
          guard pi < points.length() else { break }
          let p = start + k * size
          let v = match size {
            1 => data.read_i8(p)
            2 => data.read_i16(p)
            _ => data.read_i32(p)
          }
          f(points[pi], v)
          pi += 1
        }
      }
    }
    cur += run_count
  }
}

///|
/// The size of the values of a delta run (0 for zero runs).
fn delta_run_type(control : Int) -> Int {
  let are_zero = (control & 0x80) != 0
  let are_words = (control & 0x40) != 0
  match (are_zero, are_words) {
    (false, false) => 1
    (false, true) => 2
    (true, false) => 0
    (true, true) => 4
  }
}

///|
/// Counts the number of deltas available in the given data.
fn count_all_deltas(data : FontData) -> Int {
  let mut count = 0
  let mut offset = 0
  while offset < data.len() {
    let control = data.read_u8(offset) catch { _ => break }
    let run_count = (control & 0x3F) + 1
    count += run_count
    offset += run_count * delta_run_type(control) + 1
  }
  count
}

///|
/// The packed delta values with index `skip..limit` (`DeltaRunIter` with a
/// limit, after `skip_fast(skip)`); stops early at the end of the data.
fn delta_run_values(data : FontData, skip : Int, limit : Int) -> Array[Int] {
  let out = []
  let mut offset = 0
  let mut index = 0
  while index < limit && offset < data.len() {
    let control = data.read_u8(offset) catch { _ => break }
    offset += 1
    let run_count = (control & 0x3F) + 1
    let size = delta_run_type(control)
    for _ in 0..<run_count {
      if index >= limit {
        break
      }
      if index >= skip {
        let v = match size {
          0 => Some(0)
          1 => Some(data.read_i8(offset)) catch { _ => None }
          2 => Some(data.read_i16(offset)) catch { _ => None }
          _ => Some(data.read_i32(offset)) catch { _ => None }
        }
        guard v is Some(v) else { return out }
        out.push(v)
      }
      offset += size
      index += 1
    }
  }
  out
}

///|
/// The count of packed point numbers and the number of bytes used to store
/// it.
fn packed_points_count(data : FontData) -> (Int, Int) {
  let first = data.read_u8(0) catch { _ => 0 }
  match first {
    0 => (0, 1)
    count if count <= 127 => (count, 1)
    _ => {
      let count = (data.read_u16(0) catch { _ => 0 }) & 0x7FFF
      // a weird case where I'm following fonttools: if the 'use words' bit
      // is set, but the total count is still 0, treat it like 0 first byte
      if count == 0 {
        (0, 2)
      } else {
        (count, 2)
      }
    }
  }
}

///|
/// Read point numbers off the front of this data, returning the remaining
/// data.
fn packed_points_split_off_front(data : FontData) -> (FontData, FontData) {
  let (n_points, n_bytes) = packed_points_count(data)
  let mut n_bytes = n_bytes
  if n_points != 0 {
    let mut pos = n_bytes
    let mut n_seen = 0
    while n_seen < n_points {
      let control = data.read_u8(pos) catch { _ => break }
      pos += 1
      let two_bytes = (control & 0x80) != 0
      let count = (control & 0x7F) + 1
      let run_size = (if two_bytes { 2 } else { 1 }) * count
      n_bytes += run_size + 1
      pos += run_size
      n_seen = (n_seen + count) & 0xFFFF
    }
  }
  let rest = match data.split_off(n_bytes) {
    Some(d) => d
    None => FontData::empty()
  }
  (data, rest)
}

///|
/// The packed point numbers (`PackedPointNumbersIter` for a non-zero
/// count).
fn packed_points_iter(data : FontData) -> Array[Int] {
  let (count, n_bytes) = packed_points_count(data)
  let out = []
  let mut pos = n_bytes
  let mut last_val = 0
  let mut remaining = 0
  let mut two_bytes = false
  for _ in 0..<count {
    while remaining == 0 {
      let control = data.read_u8(pos) catch { _ => return out }
      pos += 1
      two_bytes = (control & 0x80) != 0
      remaining = (control & 0x7F) + 1
    }
    remaining -= 1
    let v = try {
      if two_bytes {
        data.read_u16(pos)
      } else {
        data.read_u8(pos)
      }
    } catch {
      _ => return out
    }
    pos += if two_bytes { 2 } else { 1 }
    last_val = last_val + v
    if last_val > 0xFFFF {
      return out
    }
    out.push(last_val)
  }
  out
}
