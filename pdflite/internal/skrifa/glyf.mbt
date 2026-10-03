// Port of skrifa 0.42.1 `src/outline/glyf/mod.rs`, `outline.rs`,
// `memory.rs` and `deltas.rs` (the unhinted FreeType style scaler, with
// `gvar` variations; adapted from typst.mbt's port, which only drew the
// default location).

///|
/// Number of phantom points generated at the end of an outline.
pub const PHANTOM_POINT_COUNT : Int = 4

///|
/// Maximum number of points we support in a single outline including
/// composites.
const MAX_POINTS : Int = 65535

///|
/// Scaler state for TrueType outlines.
pub struct GlyfOutlines {
  font : FontRef
  priv hmtx : @read_fonts.Hmtx
  priv loca : @read_fonts.Loca
  priv glyf : @read_fonts.Glyf
  priv gvar : @read_fonts.Gvar?
  fpgm : BytesView
  prep : BytesView
  cvt_len : Int
  max_function_defs : Int
  max_instruction_defs : Int
  max_twilight_points : Int
  max_stack_elements : Int
  max_storage : Int
  glyph_count : Int
  units_per_em : Int
  os2_vmetrics : (Int, Int)
  prefer_interpreter : Bool
  fractional_size_hinting : Bool
}

///|
pub fn GlyfOutlines::new(font : FontRef) -> GlyfOutlines? {
  let head = font.head() catch { _ => return None }
  // If bit 3 of head.flags is set, then we round ppems when scaling
  let fractional_size_hinting = (
      head.flags() & @read_fonts.HEAD_FLAG_FORCE_INTEGER_PPEM
    ) ==
    0
  let loca = font.loca(Some(head.index_to_loc_format() == 1)) catch {
    _ => return None
  }
  let glyf = font.glyf() catch { _ => return None }
  // GlyphHMetrics::new: hmtx is required
  let hmtx = font.hmtx() catch { _ => return None }
  let (
    glyph_count,
    max_function_defs,
    max_instruction_defs,
    max_twilight_points,
    max_stack_elements,
    max_storage,
    max_instructions,
  ) = match res(() => font.maxp()) {
    Ok(maxp) =>
      (
        maxp.num_glyphs(),
        maxp.max_function_defs().unwrap_or(0),
        maxp.max_instruction_defs().unwrap_or(0),
        // Add 4 for phantom points
        sat_u16(maxp.max_twilight_points().unwrap_or(0) + 4),
        // Add 32 to match FreeType's heuristic for buggy fonts
        sat_u16(maxp.max_stack_elements().unwrap_or(0) + 32),
        maxp.max_storage().unwrap_or(0),
        maxp.max_size_of_instructions().unwrap_or(0),
      )
    Err(_) => (0, 0, 0, 0, 0, 0, 0)
  }
  let os2_vmetrics = match res(() => font.os2()) {
    Ok(os2) => (os2.s_typo_ascender(), os2.s_typo_descender())
    Err(_) => (0, 0)
  }
  let fpgm = match font.data_for_tag("fpgm") {
    Some(d) => d.as_bytes()
    None => b""
  }
  let prep = match font.data_for_tag("prep") {
    Some(d) => d.as_bytes()
    None => b""
  }
  // Copy FreeType's logic on whether to use the interpreter
  let prefer_interpreter = !(max_instructions == 0 &&
    fpgm.length() == 0 &&
    prep.length() == 0)
  let cvt_len = match font.data_for_tag("cvt ") {
    Some(d) => if d.len() % 2 == 0 { d.len() / 2 } else { 0 }
    None => 0
  }
  Some({
    font,
    hmtx,
    loca,
    gvar: ok(() => font.gvar()),
    glyf,
    fpgm,
    prep,
    cvt_len,
    max_function_defs,
    max_instruction_defs,
    max_twilight_points,
    max_stack_elements,
    max_storage,
    glyph_count,
    units_per_em: head.units_per_em(),
    os2_vmetrics,
    prefer_interpreter,
    fractional_size_hinting,
  })
}

///|
fn sat_u16(v : Int) -> Int {
  if v > 0xFFFF {
    0xFFFF
  } else {
    v
  }
}

///|
/// Advance width in font units (`GlyphHMetrics::advance_width` at the
/// default location).
fn GlyfOutlines::advance_width(self : GlyfOutlines, gid : GlyphId) -> Int {
  self.hmtx.advance(gid).unwrap_or(0)
}

///|
/// Left side bearing in font units (`GlyphHMetrics::lsb`).
fn GlyfOutlines::lsb(self : GlyfOutlines, gid : GlyphId) -> Int {
  self.hmtx.side_bearing(gid).unwrap_or(0)
}

///|
/// Represents the information necessary to scale a glyph outline.
pub struct GlyfOutline {
  glyph_id : GlyphId
  /// The associated top-level glyph for the outline.
  glyph : @read_fonts.Glyph?
  /// Sum of the point counts of all simple glyphs in an outline.
  mut points : Int
  /// Sum of the contour counts of all simple glyphs in an outline.
  mut contours : Int
  /// Maximum number of points in a single simple glyph.
  mut max_simple_points : Int
  /// "Other" points are the unscaled or original scaled points.
  mut max_other_points : Int
  /// Maximum size of the component delta stack.
  mut max_component_delta_stack : Int
  /// Number of entries in the hinting value stack.
  mut max_stack : Int
  /// Number of CVT entries for copy-on-write support.
  mut cvt_count : Int
  /// Number of storage area entries for copy-on-write support.
  mut storage_count : Int
  /// Maximum number of points in the twilight zone for hinting.
  mut max_twilight_points : Int
  /// True if any component of a glyph has bytecode instructions.
  mut has_hinting : Bool
  /// True if the glyph requires variation delta processing.
  has_variations : Bool
  /// True if the glyph contains any simple or compound overlap flags.
  mut has_overlaps : Bool
}

///|
pub fn GlyfOutlines::outline(
  self : GlyfOutlines,
  glyph_id : GlyphId,
) -> GlyfOutline raise DrawError {
  let glyph = self.loca.get_glyf(glyph_id, self.glyf) catch {
    e => raise Read(e)
  }
  let outline : GlyfOutline = {
    glyph_id,
    glyph,
    points: 0,
    contours: 0,
    max_simple_points: 0,
    max_other_points: 0,
    max_component_delta_stack: 0,
    max_stack: 0,
    cvt_count: 0,
    storage_count: 0,
    max_twilight_points: 0,
    has_hinting: false,
    has_variations: self.gvar is Some(_),
    has_overlaps: false,
  }
  if glyph is Some(g) {
    self.outline_rec(g, outline, 0, 0)
  }
  outline.points += PHANTOM_POINT_COUNT
  outline.max_stack = self.max_stack_elements
  outline.cvt_count = self.cvt_len
  outline.storage_count = self.max_storage
  outline.max_twilight_points = self.max_twilight_points
  outline
}

///|
fn imax(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn GlyfOutlines::outline_rec(
  self : GlyfOutlines,
  glyph : @read_fonts.Glyph,
  outline : GlyfOutline,
  component_depth : Int,
  recurse_depth : Int,
) -> Unit raise DrawError {
  if recurse_depth > GLYF_COMPOSITE_RECURSION_LIMIT {
    raise RecursionLimitExceeded(outline.glyph_id)
  }
  match glyph {
    Simple(simple) => {
      let num_points = simple.num_points()
      let num_points_with_phantom = num_points + PHANTOM_POINT_COUNT
      outline.max_simple_points = imax(
        outline.max_simple_points,
        num_points_with_phantom,
      )
      outline.points += num_points
      outline.contours += simple.end_pts_of_contours().length()
      outline.has_hinting = outline.has_hinting ||
        simple.instruction_length() != 0
      outline.max_other_points = imax(
        outline.max_other_points,
        num_points_with_phantom,
      )
      outline.has_overlaps = outline.has_overlaps ||
        simple.has_overlapping_contours()
    }
    Composite(composite) => {
      let (components, instructions) = composite.component_glyphs_and_flags()
      let count = components.length() + PHANTOM_POINT_COUNT
      let point_base = outline.points
      for item in components {
        let (component, flags) = item
        if (flags & @read_fonts.OVERLAP_COMPOUND) != 0 {
          outline.has_overlaps = true
        }
        let component_glyph = self.loca.get_glyf(
          GlyphId::from_int(component),
          self.glyf,
        ) catch {
          e => raise Read(e)
        }
        guard component_glyph is Some(component_glyph) else { continue }
        self.outline_rec(
          component_glyph,
          outline,
          component_depth + count,
          recurse_depth + 1,
        )
      }
      let has_hinting = match instructions {
        Some(ins) => ins.length() != 0
        None => false
      }
      if has_hinting {
        // We only need the "other points" buffers if the
        // composite glyph has instructions.
        let num_points_in_composite = outline.points -
          point_base +
          PHANTOM_POINT_COUNT
        outline.max_other_points = imax(
          outline.max_other_points,
          num_points_in_composite,
        )
      }
      outline.max_component_delta_stack = imax(
        outline.max_component_delta_stack,
        component_depth + count,
      )
      outline.has_hinting = outline.has_hinting || has_hinting
    }
  }
}

///|
fn GlyfOutline::ensure_point_count_limit(
  self : GlyfOutline,
) -> Unit raise DrawError {
  if self.points > MAX_POINTS {
    raise TooManyPoints(self.glyph_id)
  }
}

///|
/// Returns (is_scaled, scale) for the given size.
pub fn GlyfOutlines::compute_scale(
  self : GlyfOutlines,
  ppem : Float?,
) -> (Bool, F26Dot6) {
  if ppem is Some(ppem) && self.units_per_em > 0 {
    return (
      true,
      F26Dot6::from_bits((ppem * 64.0).to_int()) /
      F26Dot6::from_bits(self.units_per_em),
    )
  }
  (false, F26Dot6::from_bits(0x10000))
}

///|
/// Buffers used during glyph scaling (structure of arrays; zero
/// initialized like upstream's temporary memory).
priv struct FreeTypeOutlineMemory {
  unscaled_x : FixedArray[Int]
  unscaled_y : FixedArray[Int]
  scaled_x : FixedArray[Int]
  scaled_y : FixedArray[Int]
  contours : FixedArray[Int]
  flags : FixedArray[Int]
  /// Point deltas (16.16 bits).
  deltas_x : FixedArray[Int]
  deltas_y : FixedArray[Int]
  /// Interpolation buffer for delta IUP (16.16 bits).
  iup_x : FixedArray[Int]
  iup_y : FixedArray[Int]
  /// Delta buffer for composite components (16.16 bits).
  composite_deltas_x : FixedArray[Int]
  composite_deltas_y : FixedArray[Int]
}

///|
fn FreeTypeOutlineMemory::new(outline : GlyfOutline) -> FreeTypeOutlineMemory {
  let (simple, component) = if outline.has_variations {
    (outline.max_simple_points, outline.max_component_delta_stack)
  } else {
    (0, 0)
  }
  {
    scaled_x: FixedArray::make(outline.points, 0),
    scaled_y: FixedArray::make(outline.points, 0),
    unscaled_x: FixedArray::make(outline.max_other_points, 0),
    unscaled_y: FixedArray::make(outline.max_other_points, 0),
    contours: FixedArray::make(outline.contours, 0),
    flags: FixedArray::make(outline.points, 0),
    deltas_x: FixedArray::make(simple, 0),
    deltas_y: FixedArray::make(simple, 0),
    iup_x: FixedArray::make(simple, 0),
    iup_y: FixedArray::make(simple, 0),
    composite_deltas_x: FixedArray::make(component, 0),
    composite_deltas_y: FixedArray::make(component, 0),
  }
}

///|
/// The unhinted FreeType style scaler (unscaled outlines only: skrifa's
/// `Size::unscaled()`, in font units stored as 26.6).
priv struct FreeTypeScaler {
  outlines : GlyfOutlines
  memory : FreeTypeOutlineMemory
  coords : ArrayView[F2Dot14]
  mut point_count : Int
  mut contour_count : Int
  mut component_delta_count : Int
  /// Phantom points (26.6 bits, or raw font units while loading).
  phantom_x : FixedArray[Int]
  phantom_y : FixedArray[Int]
}

///|
fn FreeTypeScaler::unhinted(
  outlines : GlyfOutlines,
  outline : GlyfOutline,
  coords : ArrayView[F2Dot14],
) -> FreeTypeScaler raise DrawError {
  outline.ensure_point_count_limit()
  {
    outlines,
    memory: FreeTypeOutlineMemory::new(outline),
    coords,
    point_count: 0,
    contour_count: 0,
    component_delta_count: 0,
    phantom_x: FixedArray::make(4, 0),
    phantom_y: FixedArray::make(4, 0),
  }
}

///|
/// The result of scaling: points, flags and contours plus phantom points.
priv struct ScaledOutline {
  xs : ArrayView[Int]
  ys : ArrayView[Int]
  flags : ArrayView[Int]
  contours : ArrayView[Int]
  phantom_x : FixedArray[Int]
}

///|
fn FreeTypeScaler::scale(
  self : FreeTypeScaler,
  glyph : @read_fonts.Glyph?,
  glyph_id : GlyphId,
) -> ScaledOutline raise DrawError {
  self.load(glyph, glyph_id, 0)
  let n = self.point_count
  let xs = self.memory.scaled_x
  let x_shift = self.phantom_x[0]
  if x_shift != 0 {
    for i in 0..<n {
      xs[i] = xs[i] - x_shift
    }
  }
  {
    xs: xs[0:n],
    ys: self.memory.scaled_y[0:n],
    flags: self.memory.flags[0:n],
    contours: self.memory.contours[0:self.contour_count],
    phantom_x: self.phantom_x,
  }
}

///|
fn ScaledOutline::adjusted_lsb(self : ScaledOutline) -> Int {
  self.phantom_x[0]
}

///|
fn ScaledOutline::adjusted_advance_width(self : ScaledOutline) -> Int {
  self.phantom_x[1] - self.phantom_x[0]
}

///|
fn FreeTypeScaler::has_variations(self : FreeTypeScaler) -> Bool {
  self.outlines.gvar is Some(_) && self.coords.length() != 0
}

///|
fn FreeTypeScaler::load(
  self : FreeTypeScaler,
  glyph : @read_fonts.Glyph?,
  glyph_id : GlyphId,
  recurse_depth : Int,
) -> Unit raise DrawError {
  if recurse_depth > GLYF_COMPOSITE_RECURSION_LIMIT {
    raise RecursionLimitExceeded(glyph_id)
  }
  let (x_min, y_max) = match glyph {
    Some(g) => (g.x_min(), g.y_max())
    None => (0, 0)
  }
  let outlines = self.outlines
  let lsb = outlines.lsb(glyph_id)
  let advance = outlines.advance_width(glyph_id)
  let (ascent, descent) = outlines.os2_vmetrics
  let tsb = ascent - y_max
  let vadvance = ascent - descent
  // The four "phantom" points as computed by FreeType.
  // horizontal:
  self.phantom_x[0] = x_min - lsb
  self.phantom_y[0] = 0
  self.phantom_x[1] = self.phantom_x[0] + advance
  self.phantom_y[1] = 0
  // vertical:
  self.phantom_x[2] = 0
  self.phantom_y[2] = y_max + tsb
  self.phantom_x[3] = 0
  self.phantom_y[3] = self.phantom_y[2] - vadvance
  match glyph {
    Some(Simple(simple)) => self.load_simple(simple, glyph_id)
    Some(Composite(composite)) =>
      self.load_composite(composite, glyph_id, recurse_depth)
    None => self.load_empty(glyph_id)
  }
}

///|
fn FreeTypeScaler::load_empty(
  self : FreeTypeScaler,
  glyph_id : GlyphId,
) -> Unit {
  // Roughly corresponds to the FreeType code for empty glyphs.
  if self.has_variations() {
    let gvar = self.outlines.gvar.unwrap()
    let deltas = ok(() => {
      gvar.phantom_point_deltas(
        self.outlines.glyf,
        self.outlines.loca,
        self.coords,
        glyph_id,
      )
    })
    if deltas is Some(Some(deltas)) {
      for i in 0..<2 {
        let (dx, dy) = deltas[i]
        self.phantom_x[i] = self.phantom_x[i] + Fixed::from_bits(dx).to_i32()
        self.phantom_y[i] = self.phantom_y[i] + Fixed::from_bits(dy).to_i32()
      }
    }
  }
  for i in 0..<4 {
    self.phantom_x[i] = self.phantom_x[i] << 6
    self.phantom_y[i] = self.phantom_y[i] << 6
  }
}

///|
fn FreeTypeScaler::load_simple(
  self : FreeTypeScaler,
  glyph : @read_fonts.SimpleGlyph,
  glyph_id : GlyphId,
) -> Unit raise DrawError {
  let mem = self.memory
  // Compute the ranges for our point/flag buffers.
  let points_start = self.point_count
  let point_count = glyph.num_points()
  let phantom_start = point_count
  let points_end = points_start + point_count + PHANTOM_POINT_COUNT
  let other_points_end = point_count + PHANTOM_POINT_COUNT
  if points_end > mem.scaled_x.length() ||
    points_end > mem.flags.length() ||
    other_points_end > mem.unscaled_x.length() {
    raise InsufficientMemory
  }
  // Read our unscaled points and flags (up to point_count which does not
  // include phantom points).
  read_points_into(glyph, mem, points_start, point_count) catch {
    e => raise Read(e)
  }
  // Compute the range for our contour end point buffer.
  let contours_start = self.contour_count
  let contour_end_pts = glyph.end_pts_of_contours()
  let contour_count = contour_end_pts.length()
  let contours_end = contours_start + contour_count
  if contours_end > mem.contours.length() {
    raise InsufficientMemory
  }
  // Read the contour end points, ensuring that they are properly ordered.
  let mut last_end_pt = 0
  for i, end_pt in contour_end_pts {
    if end_pt < last_end_pt {
      raise Read(
        MalformedData("unordered contour end points in TrueType glyph"),
      )
    }
    last_end_pt = end_pt
    mem.contours[contours_start + i] = end_pt
  }
  // Adjust the running point/contour total counts
  self.point_count += point_count
  self.contour_count += contour_count
  // Append phantom points to the outline.
  for i in 0..<4 {
    mem.unscaled_x[phantom_start + i] = self.phantom_x[i]
    mem.unscaled_y[phantom_start + i] = self.phantom_y[i]
    mem.flags[points_start + phantom_start + i] = 0
  }
  let mut have_deltas = false
  if self.has_variations() {
    let n = point_count + PHANTOM_POINT_COUNT
    if n > mem.deltas_x.length() || n > mem.iup_x.length() {
      raise InsufficientMemory
    }
    let contours = FixedArray::makei(contour_count, i => {
      mem.contours[contours_start + i]
    })
    let ok = simple_glyph_deltas(
      self.outlines.gvar.unwrap(),
      glyph_id,
      self.coords,
      mem,
      points_start,
      n,
      contours,
    )
    if ok {
      have_deltas = true
    }
  }
  if have_deltas {
    // Round off deltas for unscaled outlines.
    for i in 0..<other_points_end {
      mem.unscaled_x[i] = mem.unscaled_x[i] +
        Fixed::from_bits(mem.deltas_x[i]).to_i32()
      mem.unscaled_y[i] = mem.unscaled_y[i] +
        Fixed::from_bits(mem.deltas_y[i]).to_i32()
    }
  }
  // Unlike FreeType, we also store unscaled outlines in 26.6.
  for i in 0..<other_points_end {
    mem.scaled_x[points_start + i] = mem.unscaled_x[i] << 6
    mem.scaled_y[points_start + i] = mem.unscaled_y[i] << 6
  }
  // Commit our potentially modified phantom points.
  for i in 0..<4 {
    self.phantom_x[i] = mem.scaled_x[points_start + phantom_start + i]
    self.phantom_y[i] = mem.scaled_y[points_start + phantom_start + i]
  }
  if points_start != 0 {
    // If we're not the first component, shift our contour end points.
    for i in contours_start..<contours_end {
      mem.contours[i] = (mem.contours[i] + points_start) & 0xFFFF
    }
  }
}

///|
/// `SimpleGlyph::read_points_fast` into the scaler memory: unscaled points
/// at the base of the unscaled buffer and flags at `points_start`.
fn read_points_into(
  glyph : @read_fonts.SimpleGlyph,
  mem : FreeTypeOutlineMemory,
  points_start : Int,
  point_count : Int,
) -> Unit raise ReadError {
  // Flags are written relative to `points_start` while the unscaled points
  // start at 0, so read into temporaries first.
  let xs = FixedArray::make(point_count, 0)
  let ys = FixedArray::make(point_count, 0)
  let flags = FixedArray::make(point_count, 0)
  for i in 0..<point_count {
    flags[i] = mem.flags[points_start + i]
  }
  glyph.read_points_fast(xs, ys, flags, 0)
  for i in 0..<point_count {
    mem.unscaled_x[i] = xs[i]
    mem.unscaled_y[i] = ys[i]
    mem.flags[points_start + i] = flags[i]
  }
}

///|
fn scale_component(x : F2Dot14) -> F26Dot6 {
  F26Dot6::from_bits(x.to_bits() * 4)
}

///|
fn FreeTypeScaler::load_composite(
  self : FreeTypeScaler,
  glyph : @read_fonts.CompositeGlyph,
  glyph_id : GlyphId,
  recurse_depth : Int,
) -> Unit raise DrawError {
  let mem = self.memory
  // The base indices of the points and contours for the current glyph.
  let point_base = self.point_count
  // Compute the per component deltas. Since composites can be nested, we
  // use a stack and keep track of the base.
  let mut have_deltas = false
  let delta_base = self.component_delta_count
  let components = glyph.components()
  if self.has_variations() {
    let count = components.length() + PHANTOM_POINT_COUNT
    if delta_base + count > mem.composite_deltas_x.length() {
      raise InsufficientMemory
    }
    let ok = composite_glyph_deltas(
      self.outlines.gvar.unwrap(),
      glyph_id,
      self.coords,
      mem,
      delta_base,
      count,
    )
    if ok {
      // Apply deltas to phantom points.
      for i in 0..<4 {
        let k = delta_base + count - PHANTOM_POINT_COUNT + i
        self.phantom_x[i] = self.phantom_x[i] +
          Fixed::from_bits(mem.composite_deltas_x[k]).to_i32()
        self.phantom_y[i] = self.phantom_y[i] +
          Fixed::from_bits(mem.composite_deltas_y[k]).to_i32()
      }
      have_deltas = true
    }
    self.component_delta_count += count
  }
  for i in 0..<4 {
    self.phantom_x[i] = self.phantom_x[i] << 6
    self.phantom_y[i] = self.phantom_y[i] << 6
  }
  for i, component in components {
    // Loading a component glyph will override phantom points so save a
    // copy. We'll restore them unless the USE_MY_METRICS flag is set.
    let saved_x = self.phantom_x.copy()
    let saved_y = self.phantom_y.copy()
    // Load the component glyph and keep track of the points range.
    let start_point = self.point_count
    let component_gid = GlyphId::from_int(component.glyph)
    let component_glyph = self.outlines.loca.get_glyf(
      component_gid,
      self.outlines.glyf,
    ) catch {
      e => raise Read(e)
    }
    self.load(component_glyph, component_gid, recurse_depth + 1)
    let end_point = self.point_count
    if (component.flags & @read_fonts.USE_MY_METRICS) == 0 {
      // If the USE_MY_METRICS flag is missing, we restore the phantom
      // points we saved at the start of the loop.
      for k in 0..<4 {
        self.phantom_x[k] = saved_x[k]
        self.phantom_y[k] = saved_y[k]
      }
    }
    // Prepares the transform components for our conversion math below.
    let xform = component.transform
    let xx = scale_component(xform.xx)
    let yx = scale_component(xform.yx)
    let xy = scale_component(xform.xy)
    let yy = scale_component(xform.yy)
    let have_xform = (
        component.flags &
        (
          @read_fonts.WE_HAVE_A_SCALE |
          @read_fonts.WE_HAVE_AN_X_AND_Y_SCALE |
          @read_fonts.WE_HAVE_A_TWO_BY_TWO
        )
      ) !=
      0
    if have_xform {
      for k in start_point..<end_point {
        let px = F26Dot6::from_bits(mem.scaled_x[k])
        let py = F26Dot6::from_bits(mem.scaled_y[k])
        // This juggling is necessary because, unlike FreeType, we also
        // return unscaled outlines in 26.6 format for a consistent
        // interface.
        let ux = F26Dot6::from_bits(px.to_i32())
        let uy = F26Dot6::from_bits(py.to_i32())
        let x = ux * xx + uy * xy
        let y = ux * yx + uy * yy
        mem.scaled_x[k] = x.to_bits() << 6
        mem.scaled_y[k] = y.to_bits() << 6
      }
    }
    let (ox, oy) = match component.anchor {
      Offset(x~, y~) => {
        let mut x = x
        let mut y = y
        if have_xform &&
          (
            component.flags &
            (
              @read_fonts.SCALED_COMPONENT_OFFSET |
              @read_fonts.UNSCALED_COMPONENT_OFFSET
            )
          ) ==
          @read_fonts.SCALED_COMPONENT_OFFSET {
          // According to FreeType, this algorithm is a "guess"
          // and works better than the one documented by Apple.
          let hypot = fn(a : F26Dot6, b : F26Dot6) -> Fixed {
            let a = a.abs().to_bits()
            let b = b.abs().to_bits()
            Fixed::from_bits(
              if a > b {
                a + ((3 * b) >> 3)
              } else {
                b + ((3 * a) >> 3)
              },
            )
          }
          // FreeType uses a fixed point multiplication here.
          x = (Fixed::from_bits(x) * hypot(xx, xy)).to_bits()
          y = (Fixed::from_bits(y) * hypot(yy, yx)).to_bits()
        }
        if have_deltas {
          let k = delta_base + i
          let (dx, dy) = if k < mem.composite_deltas_x.length() {
            (mem.composite_deltas_x[k], mem.composite_deltas_y[k])
          } else {
            (0, 0)
          }
          // For composite glyphs, we copy FreeType and round off the
          // fractional parts of deltas.
          x += Fixed::from_bits(dx).to_i32()
          y += Fixed::from_bits(dy).to_i32()
        }
        (x << 6, y << 6)
      }
      Point(base~, component=comp) => {
        let bi = point_base + base
        let ci = start_point + comp
        if bi >= mem.scaled_x.length() {
          raise InvalidAnchorPoint(glyph_id, base)
        }
        if ci >= mem.scaled_x.length() {
          raise InvalidAnchorPoint(glyph_id, comp)
        }
        (
          mem.scaled_x[bi] - mem.scaled_x[ci],
          mem.scaled_y[bi] - mem.scaled_y[ci],
        )
      }
    }
    if ox != 0 || oy != 0 {
      for k in start_point..<end_point {
        mem.scaled_x[k] = mem.scaled_x[k] + ox
        mem.scaled_y[k] = mem.scaled_y[k] + oy
      }
    }
  }
  if have_deltas {
    self.component_delta_count = delta_base
  }
}

// --- deltas.rs ---

///|
/// Compute a set of deltas for the points in a simple glyph (into
/// `mem.deltas`), interpolating missing deltas for tuples that contain sparse
/// sets. The points are `mem.unscaled[..n]`, the flags `mem.flags` from
/// `flags_base`. Returns whether the computation succeeded (upstream
/// `Result::is_ok`).
fn simple_glyph_deltas(
  gvar : @read_fonts.Gvar,
  glyph_id : GlyphId,
  coords : ArrayView[F2Dot14],
  mem : FreeTypeOutlineMemory,
  flags_base : Int,
  n : Int,
  contours : FixedArray[Int],
) -> Bool {
  if n < PHANTOM_POINT_COUNT {
    return false
  }
  // Empty variation data for a glyph is not an error (upstream returns
  // early without clearing the delta buffer).
  guard ok(() => gvar.glyph_variation_data(glyph_id.to_u32())) is Some(var_data) else {
    return true
  }
  for i in 0..<n {
    mem.deltas_x[i] = 0
    mem.deltas_y[i] = 0
  }
  guard var_data is Some(var_data) else { return true }
  let flags = FixedArray::makei(n, i => mem.flags[flags_base + i])
  let result = ok(() => {
    for entry in var_data.active_tuples_at(coords) {
      let (tuple, scalar) = entry
      // Fast path: tuple contains all points, we can simply accumulate the
      // deltas directly.
      if tuple.has_deltas_for_all_points() {
        tuple.accumulate_dense_deltas(mem.deltas_x, mem.deltas_y, n, scalar)
      } else {
        // Infer missing deltas by interpolation. Prepare our working
        // buffer by converting the points to 16.16 and clearing the
        // HAS_DELTA flags.
        for i in 0..<n {
          mem.iup_x[i] = Fixed::from_i32(mem.unscaled_x[i]).to_bits()
          mem.iup_y[i] = Fixed::from_i32(mem.unscaled_y[i]).to_bits()
          flags[i] = flags[i] & 0xFB
        }
        tuple.accumulate_sparse_deltas(mem.iup_x, mem.iup_y, flags, n, scalar)
        guard interpolate_deltas(mem, n, flags, contours) else {
          raise @read_fonts.ReadError::OutOfBounds
        }
        for i in 0..<n {
          mem.deltas_x[i] = mem.deltas_x[i] +
            (mem.iup_x[i] - Fixed::from_i32(mem.unscaled_x[i]).to_bits())
          mem.deltas_y[i] = mem.deltas_y[i] +
            (mem.iup_y[i] - Fixed::from_i32(mem.unscaled_y[i]).to_bits())
        }
      }
    }
  })
  // The markers of the (shared) flags buffer are updated like upstream.
  for i in 0..<n {
    mem.flags[flags_base + i] = flags[i]
  }
  result is Some(_)
}

///|
/// Compute a set of deltas for the component offsets of a composite glyph
/// (into `mem.composite_deltas[base..base + count]`).
fn composite_glyph_deltas(
  gvar : @read_fonts.Gvar,
  glyph_id : GlyphId,
  coords : ArrayView[F2Dot14],
  mem : FreeTypeOutlineMemory,
  base : Int,
  count : Int,
) -> Bool {
  for i in 0..<count {
    mem.composite_deltas_x[base + i] = 0
    mem.composite_deltas_y[base + i] = 0
  }
  // Errors when reading the variation data are ignored (zero deltas).
  guard ok(() => gvar.glyph_variation_data(glyph_id.to_u32()))
    is Some(Some(var_data)) else {
    return true
  }
  let result = ok(() => {
    let xs = FixedArray::make(count, 0)
    let ys = FixedArray::make(count, 0)
    for entry in var_data.active_tuples_at(coords) {
      let (tuple, scalar) = entry
      if tuple.has_deltas_for_all_points() {
        tuple.accumulate_dense_deltas(xs, ys, count, scalar)
      } else {
        for d in tuple.deltas() {
          let ix = d.position
          if ix < count {
            let (dx, dy) = d.apply_scalar(scalar)
            xs[ix] = xs[ix] + dx
            ys[ix] = ys[ix] + dy
          }
        }
      }
    }
    for i in 0..<count {
      mem.composite_deltas_x[base + i] = xs[i]
      mem.composite_deltas_y[base + i] = ys[i]
    }
  })
  result is Some(_)
}

///|
/// Interpolate points without delta values, similar to the IUP hinting
/// instruction (modeled after the FreeType implementation). Returns `false`
/// for out of bounds accesses.
fn interpolate_deltas(
  mem : FreeTypeOutlineMemory,
  n : Int,
  flags : FixedArray[Int],
  contours : FixedArray[Int],
) -> Bool {
  let has_delta = (i : Int) => (flags[i] & 0x4) != 0
  let mut point_ix = 0
  for end_point_ix in contours {
    let first_point_ix = point_ix
    // Search for first point that has a delta.
    while point_ix <= end_point_ix {
      if point_ix >= n {
        return false
      }
      if has_delta(point_ix) {
        break
      }
      point_ix += 1
    }
    // If we didn't find any deltas, no variations in the current tuple
    // apply, so skip it.
    if point_ix > end_point_ix {
      continue
    }
    let first_delta_ix = point_ix
    let mut cur_delta_ix = point_ix
    point_ix += 1
    // Search for next point that has a delta...
    while point_ix <= end_point_ix {
      if point_ix >= n {
        return false
      }
      if has_delta(point_ix) {
        // ... and interpolate intermediate points.
        if !iup_interpolate(
            mem,
            n,
            cur_delta_ix + 1,
            point_ix - 1,
            cur_delta_ix,
            point_ix,
          ) {
          return false
        }
        cur_delta_ix = point_ix
      }
      point_ix += 1
    }
    // If we only have a single delta, shift the contour.
    if cur_delta_ix == first_delta_ix {
      if !iup_shift(mem, n, first_point_ix, end_point_ix, cur_delta_ix) {
        return false
      }
    } else {
      // Otherwise, handle remaining points at beginning and end of contour.
      if !iup_interpolate(
          mem,
          n,
          cur_delta_ix + 1,
          end_point_ix,
          cur_delta_ix,
          first_delta_ix,
        ) {
        return false
      }
      if first_delta_ix > 0 {
        if !iup_interpolate(
            mem,
            n,
            first_point_ix,
            first_delta_ix - 1,
            cur_delta_ix,
            first_delta_ix,
          ) {
          return false
        }
      }
    }
  }
  true
}

///|
/// Shift the coordinates of all points in `start..=end` using the
/// difference given by the point at `ref_ix`.
fn iup_shift(
  mem : FreeTypeOutlineMemory,
  n : Int,
  start : Int,
  end : Int,
  ref_ix : Int,
) -> Bool {
  if ref_ix >= n {
    return false
  }
  let dx = mem.iup_x[ref_ix] - Fixed::from_i32(mem.unscaled_x[ref_ix]).to_bits()
  let dy = mem.iup_y[ref_ix] - Fixed::from_i32(mem.unscaled_y[ref_ix]).to_bits()
  if dx == 0 && dy == 0 {
    return true
  }
  // Apply the reference point delta to the entire range excluding the
  // reference point itself which would apply the delta twice.
  if start > ref_ix || end >= n {
    return false
  }
  for i in start..<ref_ix {
    mem.iup_x[i] = mem.iup_x[i] + dx
    mem.iup_y[i] = mem.iup_y[i] + dy
  }
  for i in (ref_ix + 1)..<=end {
    mem.iup_x[i] = mem.iup_x[i] + dx
    mem.iup_y[i] = mem.iup_y[i] + dy
  }
  true
}

///|
/// Interpolate the coordinates of all points in `start..=end` using `ref1`
/// and `ref2` as the reference point indices.
fn iup_interpolate(
  mem : FreeTypeOutlineMemory,
  n : Int,
  start : Int,
  end : Int,
  ref1 : Int,
  ref2 : Int,
) -> Bool {
  if start > end {
    return true
  }
  if ref1 >= n || ref2 >= n || end >= n {
    return false
  }
  interp_coord(mem.unscaled_x, mem.iup_x, start, end, ref1, ref2)
  interp_coord(mem.unscaled_y, mem.iup_y, start, end, ref1, ref2)
  true
}

///|
fn interp_coord(
  points : FixedArray[Int],
  out_points : FixedArray[Int],
  start : Int,
  end : Int,
  ref1 : Int,
  ref2 : Int,
) -> Unit {
  let (ref1, ref2) = if points[ref1] > points[ref2] {
    (ref2, ref1)
  } else {
    (ref1, ref2)
  }
  let in1 = Fixed::from_i32(points[ref1])
  let in2 = Fixed::from_i32(points[ref2])
  let out1 = Fixed::from_bits(out_points[ref1])
  let out2 = Fixed::from_bits(out_points[ref2])
  // If the reference points have the same coordinate but different delta,
  // inferred delta is zero. Otherwise interpolate.
  if in1 != in2 || out1 == out2 {
    let scale = if in1 != in2 {
      (out2 - out1) / (in2 - in1)
    } else {
      Fixed::zero()
    }
    let d1 = out1 - in1
    let d2 = out2 - in2
    for i in start..<=end {
      let mut out = Fixed::from_i32(points[i])
      if out <= in1 {
        out = out + d1
      } else if out >= in2 {
        out = out + d2
      } else {
        out = out1 + (out - in1) * scale
      }
      out_points[i] = out.to_bits()
    }
  }
}

///|
/// Draws an unscaled, unhinted outline (in font units) to the pen and
/// returns the adjusted `(lsb, advance width)`.
pub fn GlyfOutlines::draw_unscaled(
  self : GlyfOutlines,
  outline : GlyfOutline,
  coords : ArrayView[F2Dot14],
  pen : &OutlinePen,
) -> (Float, Float) raise DrawError {
  let scaled = FreeTypeScaler::unhinted(self, outline, coords).scale(
    outline.glyph,
    outline.glyph_id,
  )
  to_path(scaled.xs, scaled.ys, scaled.flags, scaled.contours, pen) catch {
    e => raise ToPath(e)
  }
  (
    F26Dot6::from_bits(scaled.adjusted_lsb()).to_f32(),
    F26Dot6::from_bits(scaled.adjusted_advance_width()).to_f32(),
  )
}
