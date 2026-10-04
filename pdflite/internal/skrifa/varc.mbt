// Port of skrifa 0.42.1 `src/outline/varc/mod.rs` with the parts of
// read-fonts 0.39.2 it uses (`src/tables/varc.rs`, the generated VARC and
// condition tables, `PackedDeltas`): drawing of variable composite glyphs.

///|
/// The base outlines of a VARC font.
priv enum VarcBaseOutlines {
  VarcBaseGlyf(GlyfOutlines)
  VarcBaseCff(CffOutlines)
}

///|
/// skrifa's `varc::Outlines`: the VARC table with its coverage, variation
/// store and region list, and the base (glyf or CFF) outlines.
priv struct VarcOutlines {
  varc : FontData
  coverage : FontData
  var_store : FontData?
  regions : FontData?
  base : VarcBaseOutlines
  axis_count : Int
}

///|
/// A VARC outline (`varc::Outline`).
priv struct VarcOutline {
  glyph_id : GlyphId
  coverage_index : Int
  /// The size of the memory buffer for drawing (the maximum memory needed
  /// by the base glyphs of the components): base glyphs that need more
  /// fail to draw with `InsufficientMemory`, like upstream.
  max_component_memory : Int
}

///|
/// `varc::Outlines::new`: `None` (so that the glyf or CFF outlines are used
/// instead) if any of the tables it reads is unreadable.
fn VarcOutlines::new(font : FontRef) -> VarcOutlines? {
  // `font.varc().ok()?` (Varc::MIN_SIZE: version and five offsets)
  guard font.data_for_tag("VARC") is Some(varc) else { return None }
  if varc.len() < 24 {
    return None
  }
  let base = match GlyfOutlines::new(font) {
    Some(glyf) => VarcBaseGlyf(glyf)
    None =>
      match CffOutlines::new(font) {
        Some(cff) => VarcBaseCff(cff)
        None => return None
      }
  }
  // `GlyphHMetrics::new(font)?` and `font.head().ok()?`
  let _ = font.hmtx() catch { _ => return None }
  let _ = font.head() catch { _ => return None }
  // `font.axes().len()`
  let axis_count = match ok(() => font.fvar()) {
    Some(fvar) => fvar.axis_count()
    None => 0
  }
  // `varc.coverage().ok()?`: a non-null `Offset32` to a coverage table of
  // format 1 or 2.
  let coverage = resolve_varc_offset(varc, 4) catch { _ => return None }
  let format = coverage.read_u16(0) catch { _ => return None }
  if (format != 1 && format != 2) || coverage.len() < 4 {
    return None
  }
  // `varc.multi_var_store().transpose().ok()?` (nullable) and the region
  // list of the store.
  let store_offset = varc.read_u32(8) catch { _ => return None }
  let (var_store, regions) = if store_offset != 0 {
    let store = resolve_varc_offset(varc, 8) catch { _ => return None }
    // MultiItemVariationStore::MIN_SIZE
    if store.len() < 8 {
      return None
    }
    let regions = resolve_varc_offset(store, 2) catch { _ => return None }
    // SparseVariationRegionList::MIN_SIZE
    if regions.len() < 2 {
      return None
    }
    (Some(store), Some(regions))
  } else {
    (None, None)
  }
  Some({ varc, coverage, var_store, regions, base, axis_count, })
}

///|
/// `varc::Outlines::outline`: `None` if the glyph is not covered; raises if
/// its components (or those of the covered glyphs it uses) are unreadable.
fn VarcOutlines::outline(
  self : VarcOutlines,
  glyph_id : GlyphId,
) -> VarcOutline? raise ReadError {
  guard self.coverage_index(glyph_id) is Some(coverage_index) else {
    return None
  }
  let max_component_memory = self.max_component_memory_for_glyph(
    glyph_id,
    coverage_index,
    [],
  )
  Some({ glyph_id, coverage_index, max_component_memory, })
}

///|
fn VarcOutlines::max_component_memory_for_glyph(
  self : VarcOutlines,
  glyph_id : GlyphId,
  coverage_index : Int,
  stack : Array[GlyphId],
) -> Int raise ReadError {
  if stack.contains(glyph_id) {
    return 0
  }
  if stack.length() >= GLYF_COMPOSITE_RECURSION_LIMIT {
    return 0
  }
  stack.push(glyph_id)
  let mut max_memory = 0
  let mut cursor = varc_glyph(self.varc, coverage_index).cursor()
  while !cursor.is_empty() {
    let (component, next) = VarcComponent::parse(self.varc, cursor)
    cursor = next
    let component_gid = component.gid
    let component_memory = if component_gid == glyph_id {
      self.base_outline_memory(component_gid)
    } else if self.coverage_index(component_gid) is Some(coverage_index) {
      self.max_component_memory_for_glyph(component_gid, coverage_index, stack)
    } else {
      self.base_outline_memory(component_gid)
    }
    max_memory = @cmp.maximum(max_memory, component_memory)
  }
  stack.pop() |> ignore
  max_memory
}

///|
/// `BaseOutlines::base_outline_memory`.
fn VarcOutlines::base_outline_memory(
  self : VarcOutlines,
  glyph_id : GlyphId,
) -> Int {
  match self.base {
    VarcBaseGlyf(glyf) =>
      glyf_unhinted_buffer_size(glyf.outline(glyph_id)) catch {
        _ => 0
      }
    VarcBaseCff(_) => 0
  }
}

///|
/// `glyf::Outline::required_buffer_size(Hinting::None)`.
fn glyf_unhinted_buffer_size(outline : GlyfOutline) -> Int {
  // Scaled and unscaled points, contour end points and point flags
  let mut size = outline.points * 8 +
    outline.max_other_points * 8 +
    outline.contours * 2 +
    outline.points
  if outline.has_variations {
    // Interpolation and delta buffers, composite deltas
    size += outline.max_simple_points * 8 * 2 +
      outline.max_component_delta_stack * 8
  }
  size
}

///|
/// `varc::Outlines::fallback_outline_kind`.
fn VarcOutlines::fallback_outline_kind(
  self : VarcOutlines,
  glyph_id : GlyphId,
) -> OutlineKind? {
  match self.base {
    VarcBaseGlyf(glyf) => {
      let outline = glyf.outline(glyph_id) catch { _ => return None }
      Some(GlyfKind(glyf, outline))
    }
    VarcBaseCff(cff) =>
      Some(CffKind(cff, glyph_id, cff.subfont_index(glyph_id)))
  }
}

///|
/// Per-draw state shared by the components (`VarcSharedContext` and the
/// `Scratchpad`).
priv struct VarcContext {
  font_coords : Array[F2Dot14]
  /// The drawing memory buffer (`max_component_memory` bytes, shared by the
  /// components like upstream).
  memory : FixedArray[Byte]
  deltas : Array[Float]
  axis_indices : Array[Int]
  axis_values : Array[Float]
}

///|
/// `varc::Outlines::draw` (unhinted, unscaled).
fn VarcOutlines::draw(
  self : VarcOutlines,
  outline : VarcOutline,
  coords : ArrayView[F2Dot14],
  pen : &OutlinePen,
) -> Unit raise DrawError {
  let font_coords = []
  expand_coords(font_coords, self.axis_count, coords)
  // (`scalar_cache_from_store(..)?.unwrap()`: upstream panics without a
  // variation store.)
  guard self.scalar_cache_from_store() is Some(scalar_cache) else {
    raise Read(NullOffset)
  }
  let ctx : VarcContext = {
    font_coords,
    memory: FixedArray::make(outline.max_component_memory, b'\x00'),
    deltas: [],
    axis_indices: [],
    axis_values: [],
  }
  self.draw_glyph(
    outline.glyph_id,
    outline.coverage_index,
    font_coords,
    Affine::identity(),
    ctx,
    pen,
    [],
    scalar_cache,
  )
}

///|
fn VarcOutlines::draw_glyph(
  self : VarcOutlines,
  glyph_id : GlyphId,
  coverage_index : Int,
  current_coords : Array[F2Dot14],
  parent_matrix : Affine,
  ctx : VarcContext,
  pen : &OutlinePen,
  stack : Array[GlyphId],
  scalar_cache : Array[Float],
) -> Unit raise DrawError {
  if stack.length() >= GLYF_COMPOSITE_RECURSION_LIMIT {
    raise RecursionLimitExceeded(glyph_id)
  }
  let glyph = varc_glyph(self.varc, coverage_index) catch { e => raise Read(e) }
  stack.push(glyph_id)
  let component_coords_buffer = []
  let mut child_scalar_cache : Array[Float]? = None
  let mut cursor = glyph.cursor()
  while !cursor.is_empty() {
    let (component, next) = VarcComponent::parse(self.varc, cursor) catch {
      e => raise Read(e)
    }
    cursor = next
    if !self.component_condition_met(
        component, current_coords, scalar_cache, ctx,
      ) {
      continue
    }
    let component_gid = component.gid
    let flags = component.flags
    let coords_the_same = (flags & HAVE_AXES) == 0 &&
      (flags & RESET_UNSPECIFIED_AXES) == 0
    let component_coords = if coords_the_same {
      current_coords
    } else {
      self.component_coords(
        component, current_coords, component_coords_buffer, scalar_cache, ctx,
      )
      component_coords_buffer
    }
    let transform = component.transform.copy()
    self.apply_transform_variations(
      component, current_coords, transform, scalar_cache, ctx,
    )
    // `ctx.size.linear_scale(units_per_em)` is 1 for unscaled outlines.
    let matrix = parent_matrix * transform.matrix().scale_translation(1.0)
    if component_gid != glyph_id &&
      self.coverage_index(component_gid) is Some(coverage_index) &&
      !stack.contains(component_gid) {
      // Optimization: if coordinates haven't changed, we can reuse the
      // scalar cache.
      if coords_the_same {
        self.draw_glyph(
          component_gid, coverage_index, current_coords, matrix, ctx, pen, stack,
          scalar_cache,
        )
      } else {
        match child_scalar_cache {
          Some(cache) => cache.fill(SCALAR_CACHE_INVALID)
          None => child_scalar_cache = self.scalar_cache_from_store()
        }
        guard child_scalar_cache is Some(cache) else { raise Read(NullOffset) }
        self.draw_glyph(
          component_gid,
          coverage_index,
          component_coords.copy(),
          matrix,
          ctx,
          pen,
          stack,
          cache,
        )
      }
      continue
    }
    let transform_pen = TransformPen::{ pen, matrix, }
    self.draw_base_glyph(
      component_gid,
      component_coords,
      ctx.memory,
      transform_pen,
    )
  }
  stack.pop() |> ignore
}

///|
fn VarcOutlines::draw_base_glyph(
  self : VarcOutlines,
  glyph_id : GlyphId,
  coords : Array[F2Dot14],
  memory : FixedArray[Byte],
  pen : &OutlinePen,
) -> Unit raise DrawError {
  guard self.fallback_outline_kind(glyph_id) is Some(kind) else {
    raise GlyphNotFound(glyph_id)
  }
  match kind {
    // Drawing a glyf outline allocates its buffers from the memory of the
    // VARC outline (`FreeTypeOutlineMemory::new`).
    GlyfKind(glyf, outline) => {
      outline.ensure_point_count_limit()
      if glyf_unhinted_buffer_size(outline) > memory.length() {
        raise InsufficientMemory
      }
      // `LocationRef::effective_coords`
      let coords = if coords.iter().all(c => c == F2Dot14::zero()) {
        coords[0:0]
      } else {
        coords
      }
      let _ = glyf.draw_unscaled(outline, coords, pen, memory~)
    }
    _ => {
      let _ = OutlineGlyph::{ kind, }.draw_unscaled(coords, pen)
    }
  }
}

///|
fn VarcOutlines::component_coords(
  self : VarcOutlines,
  component : VarcComponent,
  current_coords : Array[F2Dot14],
  coords : Array[F2Dot14],
  scalar_cache : Array[Float],
  ctx : VarcContext,
) -> Unit raise DrawError {
  let flags = component.flags
  if (flags & RESET_UNSPECIFIED_AXES) != 0 {
    expand_coords(coords, ctx.font_coords.length(), ctx.font_coords)
  } else {
    expand_coords(coords, current_coords.length(), current_coords)
  }
  if (flags & HAVE_AXES) == 0 {
    return
  }
  guard component.axis_indices_index is Some(axis_indices_index) else {
    raise Read(MalformedData("Missing axisIndicesIndex"))
  }
  let num_axes = self.axis_indices(axis_indices_index, ctx.axis_indices)
  axis_values(component, num_axes, ctx.axis_values)
  if component.axis_values_var_index is Some(var_idx) {
    guard (self.var_store, self.regions) is (Some(store), Some(regions)) else {
      raise Read(NullOffset)
    }
    compute_tuple_deltas(
      store,
      regions,
      var_idx,
      current_coords,
      ctx.axis_indices.length(),
      scalar_cache,
      ctx.deltas,
    ) catch {
      e => raise Read(e)
    }
    let n = @cmp.minimum(ctx.axis_values.length(), ctx.deltas.length())
    for i in 0..<n {
      ctx.axis_values[i] = ctx.axis_values[i] + ctx.deltas[i]
    }
  }
  let n = @cmp.minimum(ctx.axis_indices.length(), ctx.axis_values.length())
  for i in 0..<n {
    let axis_index = ctx.axis_indices[i]
    if axis_index >= coords.length() {
      raise Read(OutOfBounds)
    }
    coords[axis_index] = F2Dot14::from_bits(
      f32_round_to_i16(ctx.axis_values[i]),
    )
  }
}

///|
/// `value.round().clamp(i16::MIN as f32, i16::MAX as f32) as i16`.
fn f32_round_to_i16(value : Float) -> Int {
  let d = value.to_double()
  if d.is_nan() {
    return 0
  }
  // `f32::round`: half away from zero (exact in `f64`).
  let r = if d >= 0.0 { (d + 0.5).floor() } else { -(-d + 0.5).floor() }
  if r <= -32768.0 {
    -32768
  } else if r >= 32767.0 {
    32767
  } else {
    r.to_int()
  }
}

///|
/// `varc::Outlines::axis_indices`: the axis indices (as `u16`) of entry
/// `nth` of the axis indices list.
fn VarcOutlines::axis_indices(
  self : VarcOutlines,
  nth : UInt,
  out : Array[Int],
) -> Int raise DrawError {
  let packed = varc_axis_indices(self.varc, nth) catch { e => raise Read(e) }
  out.clear()
  let iter = packed.iter()
  while iter.next() is Some(value) {
    out.push(value & 0xFFFF)
  }
  out.length()
}

///|
fn axis_values(
  component : VarcComponent,
  count : Int,
  out : Array[Float],
) -> Unit {
  guard component.axis_values is Some(packed) else {
    out.clear()
    return
  }
  resize_and_fill(out, count, 0.0)
  let iter = packed.iter()
  for i in 0..<count {
    guard iter.next() is Some(value) else { break }
    out[i] = Float::from_int(value)
  }
}

///|
fn VarcOutlines::apply_transform_variations(
  self : VarcOutlines,
  component : VarcComponent,
  coords : Array[F2Dot14],
  transform : DecomposedTransform,
  scalar_cache : Array[Float],
  ctx : VarcContext,
) -> Unit raise DrawError {
  guard component.transform_var_index is Some(var_idx) else { return }
  let flags = component.flags
  let field_count = (flags & TRANSFORM_MASK).popcnt()
  if field_count == 0 {
    return
  }
  guard (self.var_store, self.regions) is (Some(store), Some(regions)) else {
    raise Read(NullOffset)
  }
  compute_tuple_deltas(
    store,
    regions,
    var_idx,
    coords,
    field_count,
    scalar_cache,
    ctx.deltas,
  ) catch {
    e => raise Read(e)
  }
  // Apply deltas in flag order, consuming from the deltas.
  let mut next = 0
  let delta = () => {
    let d = if next < ctx.deltas.length() { ctx.deltas[next] } else { 0.0 }
    next += 1
    d
  }
  if (flags & HAVE_TRANSLATE_X) != 0 {
    transform.translate_x = transform.translate_x + delta()
  }
  if (flags & HAVE_TRANSLATE_Y) != 0 {
    transform.translate_y = transform.translate_y + delta()
  }
  if (flags & HAVE_ROTATION) != 0 {
    transform.rotation = transform.rotation + delta() / 4096.0
  }
  if (flags & HAVE_SCALE_X) != 0 {
    transform.scale_x = transform.scale_x + delta() / 1024.0
  }
  if (flags & HAVE_SCALE_Y) != 0 {
    transform.scale_y = transform.scale_y + delta() / 1024.0
  }
  if (flags & SKEW_OR_CENTER) != 0 {
    if (flags & HAVE_SKEW_X) != 0 {
      transform.skew_x = transform.skew_x + delta() / 4096.0
    }
    if (flags & HAVE_SKEW_Y) != 0 {
      transform.skew_y = transform.skew_y + delta() / 4096.0
    }
    if (flags & HAVE_TCENTER_X) != 0 {
      transform.center_x = transform.center_x + delta()
    }
    if (flags & HAVE_TCENTER_Y) != 0 {
      transform.center_y = transform.center_y + delta()
    }
  }
  if (flags & HAVE_SCALE_Y) == 0 {
    transform.scale_y = transform.scale_x
  }
}

///|
fn VarcOutlines::component_condition_met(
  self : VarcOutlines,
  component : VarcComponent,
  coords : Array[F2Dot14],
  scalar_cache : Array[Float],
  ctx : VarcContext,
) -> Bool raise DrawError {
  guard component.condition_index is Some(condition_index) else { return true }
  let condition = varc_condition(self.varc, condition_index) catch {
    e => raise Read(e)
  }
  guard (self.var_store, self.regions) is (Some(store), Some(regions)) else {
    raise Read(NullOffset)
  }
  eval_condition(condition, coords, store, regions, scalar_cache, ctx, 0) catch {
    e => raise Read(e)
  }
}

///|
/// The maximum nesting of conditions (upstream recurses without a limit and
/// overflows the stack on cyclic conditions).
const CONDITION_NESTING_LIMIT : Int = 256

///|
fn eval_condition(
  condition : FontData,
  coords : Array[F2Dot14],
  var_store : FontData,
  regions : FontData,
  scalar_cache : Array[Float],
  ctx : VarcContext,
  depth : Int,
) -> Bool raise ReadError {
  if depth > CONDITION_NESTING_LIMIT {
    raise MalformedData("condition nesting too deep")
  }
  match condition.read_u16(0) {
    1 => {
      let axis_index = condition.read_u16(2)
      let coord = if axis_index < coords.length() {
        coords[axis_index]
      } else {
        F2Dot14::zero()
      }
      coord >= F2Dot14::from_bits(condition.read_i16(4)) &&
      coord <= F2Dot14::from_bits(condition.read_i16(6))
    }
    2 => {
      let default_value = Float::from_int(condition.read_i16(2))
      let var_idx = condition.read_u32(4)
      compute_tuple_deltas(
        var_store,
        regions,
        var_idx,
        coords,
        1,
        scalar_cache,
        ctx.deltas,
      )
      let delta = if ctx.deltas.length() > 0 { ctx.deltas[0] } else { 0.0 }
      default_value + delta > 0.0
    }
    3 => {
      for nested in condition_offsets24(condition) {
        let nested = resolve_condition(condition, nested)
        if !eval_condition(
            nested,
            coords,
            var_store,
            regions,
            scalar_cache,
            ctx,
            depth + 1,
          ) {
          return false
        }
      }
      true
    }
    4 => {
      for nested in condition_offsets24(condition) {
        let nested = resolve_condition(condition, nested)
        if eval_condition(
            nested,
            coords,
            var_store,
            regions,
            scalar_cache,
            ctx,
            depth + 1,
          ) {
          return true
        }
      }
      false
    }
    _ => {
      // Format 5 (`Condition::read` only accepts formats 1 to 5)
      let nested = resolve_condition(condition, condition.read_u24(2))
      !eval_condition(
        nested,
        coords,
        var_store,
        regions,
        scalar_cache,
        ctx,
        depth + 1,
      )
    }
  }
}

///|
/// The `Offset24` array of a condition of format 3 or 4 (empty if out of
/// bounds).
fn condition_offsets24(condition : FontData) -> Array[Int] {
  let count = condition.read_u8(2) catch { _ => 0 }
  if 3 + 3 * count > condition.len() {
    return []
  }
  Array::makei(count, i => condition.read_u24(3 + 3 * i) catch { _ => 0 })
}

///|
/// `Condition::read` at an offset from `data` (`ResolveOffset::resolve`).
fn resolve_condition(data : FontData, offset : Int) -> FontData raise ReadError {
  if offset == 0 {
    raise NullOffset
  }
  guard data.split_off(offset) is Some(condition) else { raise OutOfBounds }
  let format = condition.read_u16(0)
  let min_size = match format {
    1 | 2 => 8
    3 | 4 => 3
    5 => 5
    _ => raise InvalidFormat(format.to_int64())
  }
  if condition.len() < min_size {
    raise OutOfBounds
  }
  condition
}

///|
/// `varc.condition_list()` (nullable) and `conditions().get(index)`.
fn varc_condition(varc : FontData, index : UInt) -> FontData raise ReadError {
  let offset = varc.read_u32(12)
  if offset == 0 {
    raise NullOffset
  }
  let list = resolve_varc_offset(varc, 12)
  // ConditionList::MIN_SIZE
  if list.len() < 4 {
    raise OutOfBounds
  }
  let count = list.read_u32(0).to_uint64()
  // `condition_offsets()`: empty if out of bounds
  let count = if 4UL + 4UL * count > list.len().to_uint64() {
    0UL
  } else {
    count
  }
  if index.to_uint64() >= count {
    raise InvalidCollectionIndex(index)
  }
  let offset = list.read_u32(4 + 4 * index.reinterpret_as_int())
  if offset == 0 {
    raise NullOffset
  }
  if offset > list.len().reinterpret_as_uint() {
    raise OutOfBounds
  }
  resolve_condition(list, offset.reinterpret_as_int())
}

///|
/// `scalar_cache_from_store`: `None` without a variation store.
fn VarcOutlines::scalar_cache_from_store(self : VarcOutlines) -> Array[Float]? {
  guard self.regions is Some(regions) else { return None }
  let region_count = regions.read_u16(0) catch { _ => 0 }
  Some(Array::make(region_count, SCALAR_CACHE_INVALID))
}

///|
/// Scalars are in [0,1], so 2.0 means "not cached".
const SCALAR_CACHE_INVALID : Float = 2.0

///|
fn expand_coords(
  out : Array[F2Dot14],
  axis_count : Int,
  coords : ArrayView[F2Dot14],
) -> Unit {
  resize_and_fill(out, axis_count, F2Dot14::zero())
  let n = @cmp.minimum(axis_count, coords.length())
  for i in 0..<n {
    out[i] = coords[i]
  }
}

///|
/// `SmallVec::resize_and_fill`: `len` copies of `value`.
fn[T] resize_and_fill(out : Array[T], len : Int, value : T) -> Unit {
  out.clear()
  for _ in 0..<len {
    out.push(value)
  }
}

///|
/// Adds the deltas of the delta set `var_idx` of the multi item variation
/// store, scaled by the region scalars at `coords`, to `out` (of
/// `tuple_len` zeros).
fn compute_tuple_deltas(
  store : FontData,
  regions : FontData,
  var_idx : UInt,
  coords : Array[F2Dot14],
  tuple_len : Int,
  cache : Array[Float],
  out : Array[Float],
) -> Unit raise ReadError {
  resize_and_fill(out, tuple_len, 0.0)
  if tuple_len == 0 || var_idx == 0xFFFFFFFFU {
    return
  }
  let outer = (var_idx >> 16).reinterpret_as_int()
  let inner = (var_idx & 0xFFFF).reinterpret_as_int()
  // `store.variation_data().get(outer)`
  let data = multi_variation_data(store, outer) catch {
    _ => raise InvalidCollectionIndex(outer.reinterpret_as_uint())
  }
  let region_count = data.read_u16(1) catch { _ => 0 }
  // `region_indices()`: empty if out of bounds
  let region_count = if 3 + 2 * region_count > data.len() {
    0
  } else {
    region_count
  }
  // `delta_set(inner)`: an `Index2` over the rest of the data.
  let raw_delta_sets = data.split_off(3 + 2 * region_count).unwrap()
  let deltas = PackedDeltaFetcher::new(index2_get(raw_delta_sets, inner), None)
  let mut skip = 0
  for i in 0..<region_count {
    let region_idx = data.read_u16(3 + 2 * i)
    let mut scalar = if region_idx < cache.length() {
      cache[region_idx]
    } else {
      SCALAR_CACHE_INVALID
    }
    if scalar >= 2.0 {
      scalar = sparse_region(regions, region_idx).compute_scalar_f32(coords)
      if region_idx < cache.length() {
        cache[region_idx] = scalar
      }
    }
    // We skip lazily. Reduces work at the tail end.
    if scalar == 0.0 {
      skip += out.length()
    } else {
      if skip != 0 {
        deltas.skip(skip)
        skip = 0
      }
      deltas.add_to_f32_scaled(out, scalar)
    }
  }
}

///|
/// `MultiItemVariationStore::variation_data().get(index)`.
fn multi_variation_data(
  store : FontData,
  index : Int,
) -> FontData raise ReadError {
  let count = store.read_u16(6)
  // `variation_data_offsets()`: empty if out of bounds
  let count = if 8 + 4 * count > store.len() { 0 } else { count }
  if index >= count {
    raise InvalidCollectionIndex(index.reinterpret_as_uint())
  }
  let data = resolve_varc_offset(store, 8 + 4 * index)
  // MultiItemVariationData::MIN_SIZE
  if data.len() < 3 {
    raise OutOfBounds
  }
  data
}

///|
/// `SparseVariationRegionList::regions().get(index)`: the region axes of
/// the region (`(axis index, start, peak, end)` records, empty if out of
/// bounds).
fn sparse_region(
  regions : FontData,
  index : Int,
) -> SparseRegion raise ReadError {
  let count = regions.read_u16(0)
  let count = if 2 + 4 * count > regions.len() { 0 } else { count }
  if index >= count {
    raise InvalidCollectionIndex(index.reinterpret_as_uint())
  }
  let region = resolve_varc_offset(regions, 2 + 4 * index)
  // SparseVariationRegion::MIN_SIZE
  if region.len() < 2 {
    raise OutOfBounds
  }
  let axis_count = region.read_u16(0)
  let axes = region.read_array(2, axis_count, 8) catch {
    _ => FontData::empty()
  }
  { axes, }
}

///|
priv struct SparseRegion {
  axes : FontData
}

///|
/// Computes a floating point scalar value for this sparse region and the
/// specified normalized variation coordinates.
fn SparseRegion::compute_scalar_f32(
  self : SparseRegion,
  coords : Array[F2Dot14],
) -> Float {
  let mut scalar : Float = 1.0
  for i in 0..<(self.axes.len() / 8) {
    let at = (k : Int) => self.axes.read_i16(8 * i + k) catch { _ => 0 }
    let peak = at(4)
    if peak == 0 {
      continue
    }
    let axis_index = self.axes.read_u16(8 * i) catch { _ => 0 }
    let coord = if axis_index < coords.length() {
      coords[axis_index].to_bits()
    } else {
      0
    }
    if coord == peak {
      continue
    }
    if coord == 0 {
      return 0.0
    }
    let start = at(2)
    let end = at(6)
    if start > peak || peak > end || (start < 0 && end > 0) {
      continue
    }
    if coord < start || coord > end {
      return 0.0
    } else if coord < peak {
      // Use raw bits - scale factors cancel in the ratio (`i16`
      // arithmetic, wrapping as in release builds).
      let numerat = wrap_i16(coord - start)
      if numerat == 0 {
        return 0.0
      }
      let denom = wrap_i16(peak - start)
      scalar = scalar * (Float::from_int(numerat) / Float::from_int(denom))
    } else {
      let numerat = wrap_i16(end - coord)
      if numerat == 0 {
        return 0.0
      }
      let denom = wrap_i16(end - peak)
      scalar = scalar * (Float::from_int(numerat) / Float::from_int(denom))
    }
  }
  scalar
}

///|
fn wrap_i16(v : Int) -> Int {
  v << 16 >> 16
}

///|
/// `Index2::read(data)?.get(nth)` (errors are `OutOfBounds`).
fn index2_get(data : FontData, nth : Int) -> FontData raise ReadError {
  let index = @ps.Index1::read2(data.as_bytes()) catch {
    _ => raise OutOfBounds
  }
  FontData::new(index.get(nth)) catch {
    _ => raise OutOfBounds
  }
}

///|
/// `Varc::glyph(nth)`: the components of a VARC glyph.
fn varc_glyph(varc : FontData, nth : Int) -> FontData raise ReadError {
  index2_get(resolve_varc_offset(varc, 20), nth)
}

///|
/// `Varc::axis_indices(nth)`.
fn varc_axis_indices(
  varc : FontData,
  nth : UInt,
) -> PackedDeltas raise ReadError {
  if varc.read_u32(16) == 0 {
    raise NullOffset
  }
  let list = resolve_varc_offset(varc, 16)
  let nth = if nth > 0x7FFFFFFFU { -1 } else { nth.reinterpret_as_int() }
  if nth < 0 {
    raise OutOfBounds
  }
  { data: index2_get(list, nth), count: None, }
}

///|
/// Resolves the `Offset32` at `at` in `data` (`ResolveOffset::resolve`).
fn resolve_varc_offset(data : FontData, at : Int) -> FontData raise ReadError {
  let offset = data.read_u32(at)
  if offset == 0 {
    raise NullOffset
  }
  if offset > data.len().reinterpret_as_uint() {
    raise OutOfBounds
  }
  data.split_off(offset.reinterpret_as_int()).unwrap()
}

///|
/// `CoverageTable::get`: the coverage index of a glyph, if covered.
fn VarcOutlines::coverage_index(
  self : VarcOutlines,
  glyph_id : GlyphId,
) -> Int? {
  let gid = glyph_id.to_u32()
  // `GlyphId16::try_from`
  if gid > 0xFFFF {
    return None
  }
  let gid = gid.reinterpret_as_int()
  let data = self.coverage
  let format = data.read_u16(0) catch { _ => return None }
  let count = data.read_u16(2) catch { _ => return None }
  if format == 1 {
    // `glyph_array()`: empty if out of bounds
    let count = if 4 + 2 * count > data.len() { 0 } else { count }
    let at = (i : Int) => data.read_u16(4 + 2 * i) catch { _ => 0 }
    match rust_binary_search_by(count, i => at(i).compare(gid)) {
      Ok(i) => Some(i)
      Err(_) => None
    }
  } else {
    // `range_records()`: (start, end, start coverage index) records
    let count = if 4 + 6 * count > data.len() { 0 } else { count }
    let at = (i : Int, k : Int) => {
      data.read_u16(4 + 6 * i + 2 * k) catch {
        _ => 0
      }
    }
    match
      rust_binary_search_by(count, i => {
        if at(i, 1) < gid {
          -1
        } else if at(i, 0) > gid {
          1
        } else {
          0
        }
      }) {
      // (`u16` arithmetic, wrapping as in release builds)
      Ok(i) => Some((at(i, 2) + gid - at(i, 0)) & 0xFFFF)
      Err(_) => None
    }
  }
}

///|
/// Rust's `slice::binary_search_by` (std 1.89) over indices `0..len`: the
/// probed indices depend only on the length, which matters for unsorted or
/// duplicate entries.
fn rust_binary_search_by(len : Int, f : (Int) -> Int) -> Result[Int, Int] {
  let mut size = len
  if size == 0 {
    return Err(0)
  }
  let mut base = 0
  while size > 1 {
    let half = size / 2
    let mid = base + half
    let cmp = f(mid)
    base = if cmp > 0 { base } else { mid }
    size -= half
  }
  let cmp = f(base)
  if cmp == 0 {
    Ok(base)
  } else {
    Err(base + (if cmp < 0 { 1 } else { 0 }))
  }
}

///|
const RESET_UNSPECIFIED_AXES : UInt = 0x0001

///|
const HAVE_AXES : UInt = 0x0002

///|
const AXIS_VALUES_HAVE_VARIATION : UInt = 0x0004

///|
const TRANSFORM_HAS_VARIATION : UInt = 0x0008

///|
const HAVE_TRANSLATE_X : UInt = 0x0010

///|
const HAVE_TRANSLATE_Y : UInt = 0x0020

///|
const HAVE_ROTATION : UInt = 0x0040

///|
const HAVE_CONDITION : UInt = 0x0080

///|
const HAVE_SCALE_X : UInt = 0x0100

///|
const HAVE_SCALE_Y : UInt = 0x0200

///|
const HAVE_TCENTER_X : UInt = 0x0400

///|
const HAVE_TCENTER_Y : UInt = 0x0800

///|
const GID_IS_24BIT : UInt = 0x1000

///|
const HAVE_SKEW_X : UInt = 0x2000

///|
const HAVE_SKEW_Y : UInt = 0x4000

///|
const RESERVED_MASK : UInt = 0xFFFF8000

///|
const TRANSFORM_MASK : UInt = 0x7F70

///|
const SKEW_OR_CENTER : UInt = 0x6C00

///|
/// A variable component record of a VARC glyph.
priv struct VarcComponent {
  flags : UInt
  gid : GlyphId
  condition_index : UInt?
  axis_indices_index : UInt?
  axis_values : PackedDeltas?
  axis_values_var_index : UInt?
  transform_var_index : UInt?
  transform : DecomposedTransform
}

///|
/// Parses a component at the cursor; returns it with the cursor after it
/// (which may be a new cursor over the remaining data, like upstream).
fn VarcComponent::parse(
  varc : FontData,
  cursor : @read_fonts.Cursor,
) -> (VarcComponent, @read_fonts.Cursor) raise ReadError {
  let mut cursor = cursor
  let raw_flags = read_u32_var(cursor)
  // (`from_bits_truncate` keeps every bit: `all()` includes the reserved
  // mask.)
  let flags = raw_flags
  let gid = if (flags & GID_IS_24BIT) != 0 {
    GlyphId::new(cursor.read_u24().reinterpret_as_uint())
  } else {
    GlyphId::new(cursor.read_u16().reinterpret_as_uint())
  }
  let condition_index = if (flags & HAVE_CONDITION) != 0 {
    Some(read_u32_var(cursor))
  } else {
    None
  }
  let (axis_indices_index, axis_values) = if (flags & HAVE_AXES) != 0 {
    let axis_indices_index = read_u32_var(cursor)
    let num_axis_values = varc_axis_indices(varc, axis_indices_index).count_or_compute()
    // we need to consume num_axis_values entries in packed delta format
    let deltas = if num_axis_values > 0 {
      guard cursor.remaining() is Some(data) else { raise OutOfBounds }
      let deltas : PackedDeltas = { data, count: Some(num_axis_values), }
      // jump past the packed deltas
      cursor = deltas.iter().end()
      Some(deltas)
    } else {
      None
    }
    (Some(axis_indices_index), deltas)
  } else {
    (None, None)
  }
  let axis_values_var_index = if (flags & AXIS_VALUES_HAVE_VARIATION) != 0 {
    Some(read_u32_var(cursor))
  } else {
    None
  }
  let transform_var_index = if (flags & TRANSFORM_HAS_VARIATION) != 0 {
    Some(read_u32_var(cursor))
  } else {
    None
  }
  let transform = DecomposedTransform::default()
  if (flags & (HAVE_TRANSLATE_X | HAVE_TRANSLATE_Y)) != 0 {
    if (flags & HAVE_TRANSLATE_X) != 0 {
      transform.translate_x = Float::from_int(cursor.read_i16())
    }
    if (flags & HAVE_TRANSLATE_Y) != 0 {
      transform.translate_y = Float::from_int(cursor.read_i16())
    }
  }
  if (flags & HAVE_ROTATION) != 0 {
    transform.rotation = Float::from_int(cursor.read_i16()) / 4096.0
  }
  if (flags & (HAVE_SCALE_X | HAVE_SCALE_Y)) != 0 {
    if (flags & HAVE_SCALE_X) != 0 {
      transform.scale_x = Float::from_int(cursor.read_i16()) / 1024.0
    }
    transform.scale_y = if (flags & HAVE_SCALE_Y) != 0 {
      Float::from_int(cursor.read_i16()) / 1024.0
    } else {
      transform.scale_x
    }
  }
  if (flags & (HAVE_TCENTER_X | HAVE_TCENTER_Y)) != 0 {
    if (flags & HAVE_TCENTER_X) != 0 {
      transform.center_x = Float::from_int(cursor.read_i16())
    }
    if (flags & HAVE_TCENTER_Y) != 0 {
      transform.center_y = Float::from_int(cursor.read_i16())
    }
  }
  if (flags & (HAVE_SKEW_X | HAVE_SKEW_Y)) != 0 {
    if (flags & HAVE_SKEW_X) != 0 {
      transform.skew_x = Float::from_int(cursor.read_i16()) / 4096.0
    }
    if (flags & HAVE_SKEW_Y) != 0 {
      transform.skew_y = Float::from_int(cursor.read_i16()) / 4096.0
    }
  }
  // Optional, process and discard one uint32var per each set bit in
  // RESERVED_MASK.
  let reserved = raw_flags & RESERVED_MASK
  for _ in 0..<reserved.popcnt() {
    read_u32_var(cursor) |> ignore
  }
  (
    {
      flags,
      gid,
      condition_index,
      axis_indices_index,
      axis_values,
      axis_values_var_index,
      transform_var_index,
      transform,
    },
    cursor,
  )
}

///|
/// Reads a variable length `u32` (`Cursor::read_u32_var`).
fn read_u32_var(cursor : @read_fonts.Cursor) -> UInt raise ReadError {
  let b0 = cursor.read_u8().reinterpret_as_uint()
  if b0 < 0x80 {
    b0
  } else if b0 < 0xC0 {
    ((b0 - 0x80) << 8) | cursor.read_u8().reinterpret_as_uint()
  } else if b0 < 0xE0 {
    let b1 = cursor.read_u8().reinterpret_as_uint()
    let b2 = cursor.read_u8().reinterpret_as_uint()
    ((b0 - 0xC0) << 16) | (b1 << 8) | b2
  } else if b0 < 0xF0 {
    let b1 = cursor.read_u8().reinterpret_as_uint()
    let b2 = cursor.read_u8().reinterpret_as_uint()
    let b3 = cursor.read_u8().reinterpret_as_uint()
    ((b0 - 0xE0) << 24) | (b1 << 16) | (b2 << 8) | b3
  } else {
    // 0xF0 is a dedicated 5-byte prefix; high bits are carried entirely by
    // the following 4 bytes.
    let b1 = cursor.read_u8().reinterpret_as_uint()
    let b2 = cursor.read_u8().reinterpret_as_uint()
    let b3 = cursor.read_u8().reinterpret_as_uint()
    let b4 = cursor.read_u8().reinterpret_as_uint()
    (b1 << 24) | (b2 << 16) | (b3 << 8) | b4
  }
}

///|
/// A decomposed transform (fontTools' `DecomposedTransform`).
priv struct DecomposedTransform {
  mut translate_x : Float
  mut translate_y : Float
  // multiples of Pi, counter-clockwise
  mut rotation : Float
  mut scale_x : Float
  mut scale_y : Float
  // multiples of Pi, clockwise
  mut skew_x : Float
  // multiples of Pi, counter-clockwise
  mut skew_y : Float
  mut center_x : Float
  mut center_y : Float
}

///|
fn DecomposedTransform::default() -> DecomposedTransform {
  {
    translate_x: 0.0,
    translate_y: 0.0,
    rotation: 0.0,
    scale_x: 1.0,
    scale_y: 1.0,
    skew_x: 0.0,
    skew_y: 0.0,
    center_x: 0.0,
    center_y: 0.0,
  }
}

///|
fn DecomposedTransform::copy(self : DecomposedTransform) -> DecomposedTransform {
  { ..self, }
}

///|
/// `core::f32::consts::PI`
const PI_F32 : Float = 3.14159265358979323846

///|
/// Convert decomposed form to 2x3 matrix form.
fn DecomposedTransform::matrix(self : DecomposedTransform) -> Affine {
  // Python: t.translate(self.translateX + self.tCenterX, self.translateY + self.tCenterY)
  let mut transform = Affine::identity()
  transform = {
    ..transform,
    dx: self.translate_x + self.center_x,
    dy: self.translate_y + self.center_y,
  }
  // Python: t = t.rotate(self.rotation * math.pi)
  if self.rotation != 0.0 {
    let (s, c) = sin_cos_f32(self.rotation * PI_F32)
    transform = transform * { xx: c, yx: s, xy: -s, yy: c, dx: 0.0, dy: 0.0, }
  }
  // Python: t = t.scale(self.scaleX, self.scaleY)
  if self.scale_x != 1.0 || self.scale_y != 1.0 {
    transform = transform *
      {
        xx: self.scale_x,
        yx: 0.0,
        xy: 0.0,
        yy: self.scale_y,
        dx: 0.0,
        dy: 0.0,
      }
  }
  // Python: t = t.skew(-self.skewX * math.pi, self.skewY * math.pi)
  if self.skew_x != 0.0 || self.skew_y != 0.0 {
    transform = transform *
      {
        xx: 1.0,
        yx: tan_f32(self.skew_y * PI_F32),
        xy: tan_f32(-self.skew_x * PI_F32),
        yy: 1.0,
        dx: 0.0,
        dy: 0.0,
      }
  }
  // Python: t = t.translate(-self.tCenterX, -self.tCenterY)
  if self.center_x != 0.0 || self.center_y != 0.0 {
    transform = transform *
      {
        xx: 1.0,
        yx: 0.0,
        xy: 0.0,
        yy: 1.0,
        dx: -self.center_x,
        dy: -self.center_y,
      }
  }
  transform
}

///|
/// font-types' `Matrix<f32>`.
priv struct Affine {
  xx : Float
  yx : Float
  xy : Float
  yy : Float
  dx : Float
  dy : Float
}

///|
fn Affine::identity() -> Affine {
  { xx: 1.0, yx: 0.0, xy: 0.0, yy: 1.0, dx: 0.0, dy: 0.0, }
}

///|
impl Mul for Affine with fn mul(self, rhs) {
  {
    xx: self.xx * rhs.xx + self.xy * rhs.yx,
    yx: self.yx * rhs.xx + self.yy * rhs.yx,
    xy: self.xx * rhs.xy + self.xy * rhs.yy,
    yy: self.yx * rhs.xy + self.yy * rhs.yy,
    dx: self.xx * rhs.dx + self.xy * rhs.dy + self.dx,
    dy: self.yx * rhs.dx + self.yy * rhs.dy + self.dy,
  }
}

///|
/// `scale_matrix`: scales the translation.
fn Affine::scale_translation(self : Affine, s : Float) -> Affine {
  { ..self, dx: self.dx * s, dy: self.dy * s, }
}

///|
fn Affine::transform(self : Affine, x : Float, y : Float) -> (Float, Float) {
  (self.xx * x + self.xy * y + self.dx, self.yx * x + self.yy * y + self.dy)
}

///|
/// A pen that transforms the points by a matrix.
priv struct TransformPen {
  pen : &OutlinePen
  matrix : Affine
}

///|
impl OutlinePen for TransformPen with fn move_to(self, x, y) {
  let (x, y) = self.matrix.transform(x, y)
  self.pen.move_to(x, y)
}

///|
impl OutlinePen for TransformPen with fn line_to(self, x, y) {
  let (x, y) = self.matrix.transform(x, y)
  self.pen.line_to(x, y)
}

///|
impl OutlinePen for TransformPen with fn quad_to(self, cx0, cy0, x, y) {
  let (cx0, cy0) = self.matrix.transform(cx0, cy0)
  let (x, y) = self.matrix.transform(x, y)
  self.pen.quad_to(cx0, cy0, x, y)
}

///|
impl OutlinePen for TransformPen with fn curve_to(
  self,
  cx0,
  cy0,
  cx1,
  cy1,
  x,
  y,
) {
  let (cx0, cy0) = self.matrix.transform(cx0, cy0)
  let (cx1, cy1) = self.matrix.transform(cx1, cy1)
  let (x, y) = self.matrix.transform(x, y)
  self.pen.curve_to(cx0, cy0, cx1, cy1, x, y)
}

///|
impl OutlinePen for TransformPen with fn close(self) {
  self.pen.close()
}

///|
/// Packed deltas (read-fonts' `PackedDeltas`): `count` values, or all
/// available values.
priv struct PackedDeltas {
  data : FontData
  count : Int?
}

///|
fn PackedDeltas::count_or_compute(self : PackedDeltas) -> Int {
  match self.count {
    Some(count) => count
    None => {
      // `count_all_deltas`
      let mut count = 0
      let mut offset = 0
      while true {
        let control = self.data.read_u8(offset) catch { _ => break }
        let run_count = (control & 0x3F) + 1
        count += run_count
        offset += run_count * delta_run_type(control) + 1
      }
      count
    }
  }
}

///|
/// The size of the values of a delta run (0 for zero runs).
fn delta_run_type(control : Int) -> Int {
  match ((control & 0x80) != 0, (control & 0x40) != 0) {
    (false, false) => 1
    (false, true) => 2
    (true, false) => 0
    (true, true) => 4
  }
}

///|
fn PackedDeltas::iter(self : PackedDeltas) -> DeltaRunIter {
  {
    limit: self.count,
    remaining_in_run: 0,
    value_type: 1,
    cursor: self.data.cursor(),
  }
}

///|
/// An iterator over packed deltas (`DeltaRunIter`).
priv struct DeltaRunIter {
  // when None, consume all available data
  mut limit : Int?
  mut remaining_in_run : Int
  mut value_type : Int
  cursor : @read_fonts.Cursor
}

///|
fn DeltaRunIter::read_next_control(self : DeltaRunIter) -> Bool {
  self.remaining_in_run = 0
  let control = self.cursor.read_u8() catch { _ => return false }
  self.value_type = delta_run_type(control)
  self.remaining_in_run = (control & 0x3F) + 1
  true
}

///|
fn DeltaRunIter::next(self : DeltaRunIter) -> Int? {
  if self.limit is Some(limit) {
    if limit == 0 {
      return None
    }
    self.limit = Some(limit - 1)
  }
  if self.remaining_in_run == 0 && !self.read_next_control() {
    return None
  }
  self.remaining_in_run -= 1
  match self.value_type {
    0 => Some(0)
    1 => Some(self.cursor.read_i8()) catch { _ => None }
    2 => Some(self.cursor.read_i16()) catch { _ => None }
    _ => Some(self.cursor.read_i32()) catch { _ => None }
  }
}

///|
fn DeltaRunIter::skip_fast(self : DeltaRunIter, n : Int) -> Unit {
  let mut wanted = n
  let mut remaining = self.remaining_in_run
  let mut value_type = self.value_type
  while true {
    if wanted > remaining {
      // Consume the rest of this run and move to the next.
      self.cursor.advance_by(remaining * value_type)
      wanted -= remaining
      if !self.read_next_control() {
        self.limit = Some(0)
        break
      }
      remaining = self.remaining_in_run
      value_type = self.value_type
      continue
    }
    let consumed = wanted
    self.remaining_in_run -= consumed
    self.cursor.advance_by(consumed * value_type)
    if self.limit is Some(limit) {
      self.limit = Some(if limit > n { limit - n } else { 0 })
    }
    break
  }
}

///|
/// The cursor after the deltas (`DeltaRunIter::end`).
fn DeltaRunIter::end(self : DeltaRunIter) -> @read_fonts.Cursor {
  if self.limit is Some(limit) {
    self.skip_fast(limit)
    return self.cursor
  }
  // No limit: jump over runs without decoding values.
  if self.remaining_in_run != 0 {
    if self.value_type != 0 {
      self.cursor.advance_by(self.remaining_in_run * self.value_type)
    }
    self.remaining_in_run = 0
  }
  while self.read_next_control() {
    if self.value_type != 0 {
      self.cursor.advance_by(self.remaining_in_run * self.value_type)
    }
    self.remaining_in_run = 0
  }
  self.cursor
}

///|
/// `PackedDeltaFetcher`.
priv struct PackedDeltaFetcher {
  data : BytesView
  mut pos : Int
  end : Int
  mut run_count : Int
  mut value_type : Int
  mut remaining_total : Int?
}

///|
fn PackedDeltaFetcher::new(data : FontData, count : Int?) -> PackedDeltaFetcher {
  let data = data.as_bytes()
  {
    data,
    pos: 0,
    end: data.length(),
    run_count: 0,
    value_type: 1,
    remaining_total: count,
  }
}

///|
fn PackedDeltaFetcher::ensure_run(
  self : PackedDeltaFetcher,
) -> Unit raise ReadError {
  if self.run_count > 0 {
    return
  }
  if self.pos >= self.end {
    raise OutOfBounds
  }
  let control = self.data[self.pos].to_int()
  self.pos += 1
  self.run_count = (control & 0x3F) + 1
  self.value_type = delta_run_type(control)
  let needed = self.run_count * self.value_type
  if self.pos + needed > self.end {
    raise OutOfBounds
  }
}

///|
fn PackedDeltaFetcher::skip(
  self : PackedDeltaFetcher,
  n : Int,
) -> Unit raise ReadError {
  let mut n = n
  if self.remaining_total is Some(remaining_total) {
    if n > remaining_total {
      raise OutOfBounds
    }
    self.remaining_total = Some(remaining_total - n)
  }
  while n > 0 {
    self.ensure_run()
    let take = @cmp.minimum(n, self.run_count)
    self.pos += take * self.value_type
    self.run_count -= take
    n -= take
  }
}

///|
fn PackedDeltaFetcher::add_to_f32_scaled(
  self : PackedDeltaFetcher,
  out : Array[Float],
  scale : Float,
) -> Unit raise ReadError {
  let mut remaining = out.length()
  if self.remaining_total is Some(remaining_total) {
    if remaining > remaining_total {
      raise OutOfBounds
    }
    self.remaining_total = Some(remaining_total - remaining)
  }
  let mut idx = 0
  while remaining > 0 {
    self.ensure_run()
    let take = @cmp.minimum(remaining, self.run_count)
    match self.value_type {
      // nothing to add
      0 => idx += take
      1 => {
        for k in 0..<take {
          let b = self.data[self.pos + k].to_int()
          let delta = Float::from_int(if b >= 0x80 { b - 0x100 } else { b })
          out[idx] = out[idx] + delta * scale
          idx += 1
        }
        self.pos += take
      }
      2 => {
        for k in 0..<take {
          let p = self.pos + 2 * k
          let v = (self.data[p].to_int() << 8) | self.data[p + 1].to_int()
          let delta = Float::from_int(if v >= 0x8000 { v - 0x10000 } else { v })
          out[idx] = out[idx] + delta * scale
          idx += 1
        }
        self.pos += take * 2
      }
      _ => {
        for k in 0..<take {
          let p = self.pos + 4 * k
          let v = (self.data[p].to_int() << 24) |
            (self.data[p + 1].to_int() << 16) |
            (self.data[p + 2].to_int() << 8) |
            self.data[p + 3].to_int()
          out[idx] = out[idx] + Float::from_int(v) * scale
          idx += 1
        }
        self.pos += take * 4
      }
    }
    self.run_count -= take
    remaining -= take
  }
}
