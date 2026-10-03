// Port of subsetter 0.2.6 `src/interjector.rs` and `src/cff2.rs`, with the
// parts of kurbo 0.13.1 (`BezPath`, `CubicBez::to_quads`) and write-fonts
// 0.48.1 (`SimpleGlyph::from_bezpath`, `FontWrite for SimpleGlyph`) the
// interjector uses. Outlines and metrics come from the skrifa port in
// `pdflite/internal/skrifa`.

///|
priv enum Interjector {
  Dummy
  Skrifa(SkrifaInterjector)
}

///|
fn Interjector::is_skrifa(self : Interjector) -> Bool {
  self is Skrifa(_)
}

///|
priv struct SkrifaInterjector {
  font_ref : @read_fonts.FontRef
  location : Array[@font_types.F2Dot14]
  outlines : @skrifa.OutlineGlyphCollection
  metrics : @skrifa.GlyphMetrics
}

///|
fn SkrifaInterjector::new(
  data : Bytes,
  index : Int,
  location : ArrayView[(Tag, Float)],
) -> SkrifaInterjector? {
  let font_ref = @read_fonts.FontRef::from_index(data[:], index) catch {
    _ => return None
  }
  let settings = location.map(entry => {
    let b = entry.0.bytes
    (
      (b[0].to_uint() << 24) |
      (b[1].to_uint() << 16) |
      (b[2].to_uint() << 8) |
      b[3].to_uint(),
      entry.1,
    )
  })
  let location = @skrifa.axes_location(font_ref, settings)
  Some({
    font_ref,
    location,
    outlines: @skrifa.OutlineGlyphCollection::new(font_ref),
    metrics: @skrifa.GlyphMetrics::new(font_ref, location),
  })
}

///|
fn SkrifaInterjector::is_default_location(self : SkrifaInterjector) -> Bool {
  self.location.iter().all(c => c == @font_types.F2Dot14::zero())
}

///|
/// Return the glyph description in the `glyf` outline format, with the
/// advance and left side bearing.
fn SkrifaInterjector::interject(
  self : SkrifaInterjector,
  maxp_data : MaxpData,
  glyph : Int,
) -> (Int, Int, Bytes)? {
  let outline_builder = OutlinePath::new()
  let glyph_id = @font_types.GlyphId::from_int(glyph)
  if self.outlines.get(glyph_id) is Some(outline_glyph) {
    let _ = outline_glyph.draw_unscaled(self.location[:], outline_builder) catch {
      _ => return None
    }
  }
  let path = outline_builder.path
  guard simple_glyph_from_bezpath(path) is Some(simple_glyph) else {
    return None
  }
  guard self.metrics.advance_width(glyph_id) is Some(advance) else {
    return None
  }
  let advance = saturating_u16(round_f32(advance).to_double())

  // We derive the LSB from the resulting bounding box rather than from the
  // font's metrics, because the latter does not always agree with the
  // `xMin` of the fresh outline we've generated.
  //
  // The OpenType spec heavily advises xMin and LSB to match (it actually
  // requires it for variable fonts or when `head.flags` bit 1 is set).
  //
  // If `LSB != xMin`, glyphs get repositioned by PDF readers and the kerning
  // gets very wonky.
  let lsb = simple_glyph.bbox.0
  if path.is_empty() {
    return Some((advance, lsb, b""))
  }
  let mut num_points = 0
  for c in simple_glyph.contours {
    num_points += c.length()
  }
  maxp_data.max_points = @cmp.maximum(maxp_data.max_points, num_points & 0xFFFF)
  maxp_data.max_contours = @cmp.maximum(
    maxp_data.max_contours,
    simple_glyph.contours.length() & 0xFFFF,
  )
  guard simple_glyph.dump() is Some(data) else { return None }
  Some((advance, lsb, data))
}

///|
/// Rust's `f32::round` (half away from zero).
fn round_f32(x : Float) -> Float {
  let d = x.to_double()
  if d.is_nan() || d.is_inf() {
    return x
  }
  let t = d.trunc()
  let r = if (d - t).abs() >= 0.5 {
    t + (if d < 0.0 { -1.0 } else { 1.0 })
  } else {
    t
  }
  Float::from_double(r)
}

///|
/// Rust's saturating `as u16` of a float.
fn saturating_u16(d : Double) -> Int {
  if d.is_nan() || d <= 0.0 {
    0
  } else if d >= 65535.0 {
    65535
  } else {
    d.to_int()
  }
}

///|
/// Rust's saturating `as i16` of a float.
fn saturating_i16(d : Double) -> Int {
  if d.is_nan() {
    0
  } else if d >= 32767.0 {
    32767
  } else if d <= -32768.0 {
    -32768
  } else {
    d.to_int()
  }
}

///|
/// A pen building a kurbo `BezPath`; cubic curves are converted to quadratic
/// ones.
priv struct OutlinePath {
  mut last_move_to : (Float, Float)
  mut last_point : (Float, Float)
  path : BezPath
}

///|
fn OutlinePath::new() -> OutlinePath {
  { last_move_to: (0.0, 0.0), last_point: (0.0, 0.0), path: { elements: [], }, }
}

///|
impl @read_fonts.OutlinePen for OutlinePath with fn move_to(self, x, y) {
  self.path.elements.push(MoveTo(pt(x, y)))
  self.last_move_to = (x, y)
  self.last_point = (x, y)
}

///|
impl @read_fonts.OutlinePen for OutlinePath with fn line_to(self, x, y) {
  self.path.elements.push(LineTo(pt(x, y)))
  self.last_point = (x, y)
}

///|
impl @read_fonts.OutlinePen for OutlinePath with fn quad_to(self, cx, cy, x, y) {
  // Only called by TrueType fonts.
  self.path.elements.push(QuadTo(pt(cx, cy), pt(x, y)))
  self.last_point = (x, y)
}

///|
impl @read_fonts.OutlinePen for OutlinePath with fn curve_to(
  self,
  cx0,
  cy0,
  cx1,
  cy1,
  x,
  y,
) {
  // Only called by CFF2 fonts.
  let cubic = CubicBez::{
    p0: pt(self.last_point.0, self.last_point.1),
    p1: pt(cx0, cy0),
    p2: pt(cx1, cy1),
    p3: pt(x, y),
  }

  // It is not entirely clear how small the `accuracy` parameter needs to be
  // to produce sensible results. In `vello_cpu`, a value of around 0.025 is
  // used (0.25 for the flattening accuracy and * 0.1 in the flattening
  // code, so we choose the same value here.
  for quad in cubic.to_quads(0.025) {
    // Note that `quad.p2` is the same as `quad.p0` of the next point in the
    // iterator.
    @read_fonts.OutlinePen::quad_to(
      self,
      Float::from_double(quad.p1.x),
      Float::from_double(quad.p1.y),
      Float::from_double(quad.p2.x),
      Float::from_double(quad.p2.y),
    )
  }
}

///|
impl @read_fonts.OutlinePen for OutlinePath with fn close(self) {
  self.path.elements.push(ClosePath)
  self.last_point = self.last_move_to
}

// --- kurbo ---

///|
priv struct Point {
  x : Double
  y : Double
} derive(Eq)

///|
fn pt(x : Float, y : Float) -> Point {
  { x: x.to_double(), y: y.to_double(), }
}

///|
priv enum PathEl {
  MoveTo(Point)
  LineTo(Point)
  QuadTo(Point, Point)
  CurveTo(Point, Point, Point)
  ClosePath
}

///|
priv struct BezPath {
  elements : Array[PathEl]
}

///|
/// Is this path empty (only `MoveTo` and `ClosePath` elements)?
fn BezPath::is_empty(self : BezPath) -> Bool {
  self.elements.iter().all(el => el is (MoveTo(_) | ClosePath))
}

///|
/// The smallest rectangle that encloses all points of the path:
/// `(x0, y0, x1, y1)`.
fn BezPath::control_box(self : BezPath) -> (Double, Double, Double, Double) {
  let mut cbox : (Double, Double, Double, Double)? = None
  let add = (p : Point) => {
    cbox = Some(
      match cbox {
        Some((x0, y0, x1, y1)) =>
          // (`Rect::union_pt` with `f64::min`/`max`.)
          (fmin(x0, p.x), fmin(y0, p.y), fmax(x1, p.x), fmax(y1, p.y))
        None => (p.x, p.y, p.x, p.y)
      },
    )
  }
  for el in self.elements {
    match el {
      MoveTo(p0) | LineTo(p0) => add(p0)
      QuadTo(p0, p1) => {
        add(p0)
        add(p1)
      }
      CurveTo(p0, p1, p2) => {
        add(p0)
        add(p1)
        add(p2)
      }
      ClosePath => ()
    }
  }
  cbox.unwrap_or((0.0, 0.0, 0.0, 0.0))
}

///|
/// Rust's `f64::min` (NaN is ignored).
fn fmin(a : Double, b : Double) -> Double {
  if a.is_nan() {
    b
  } else if b.is_nan() {
    a
  } else if b < a {
    b
  } else {
    a
  }
}

///|
/// Rust's `f64::max` (NaN is ignored).
fn fmax(a : Double, b : Double) -> Double {
  if a.is_nan() {
    b
  } else if b.is_nan() {
    a
  } else if b > a {
    b
  } else {
    a
  }
}

///|
priv struct CubicBez {
  p0 : Point
  p1 : Point
  p2 : Point
  p3 : Point
}

///|
priv struct QuadBez {
  p0 : Point
  p1 : Point
  p2 : Point
}

///|
fn CubicBez::eval(self : CubicBez, t : Double) -> Point {
  let mt = 1.0 - t
  let a = mt * mt * mt
  let b = mt * mt * 3.0
  let c = mt * 3.0
  {
    x: self.p0.x * a + (self.p1.x * b + (self.p2.x * c + self.p3.x * t) * t) * t,
    y: self.p0.y * a + (self.p1.y * b + (self.p2.y * c + self.p3.y * t) * t) * t,
  }
}

///|
fn QuadBez::eval(self : QuadBez, t : Double) -> Point {
  let mt = 1.0 - t
  let a = mt * mt
  let b = mt * 2.0
  {
    x: self.p0.x * a + (self.p1.x * b + self.p2.x * t) * t,
    y: self.p0.y * a + (self.p1.y * b + self.p2.y * t) * t,
  }
}

///|
fn CubicBez::deriv(self : CubicBez) -> QuadBez {
  {
    p0: { x: (self.p1.x - self.p0.x) * 3.0, y: (self.p1.y - self.p0.y) * 3.0, },
    p1: { x: (self.p2.x - self.p1.x) * 3.0, y: (self.p2.y - self.p1.y) * 3.0, },
    p2: { x: (self.p3.x - self.p2.x) * 3.0, y: (self.p3.y - self.p2.y) * 3.0, },
  }
}

///|
fn CubicBez::subsegment(self : CubicBez, t0 : Double, t1 : Double) -> CubicBez {
  let p0 = self.eval(t0)
  let p3 = self.eval(t1)
  let d = self.deriv()
  let scale = (t1 - t0) * (1.0 / 3.0)
  let d0 = d.eval(t0)
  let d1 = d.eval(t1)
  {
    p0,
    p1: { x: p0.x + d0.x * scale, y: p0.y + d0.y * scale, },
    p2: { x: p3.x - d1.x * scale, y: p3.y - d1.y * scale, },
    p3,
  }
}

///|
/// Approximate the cubic with a sequence of quadratic Béziers (always at
/// least one).
fn CubicBez::to_quads(self : CubicBez, accuracy : Double) -> Array[QuadBez] {
  // This magic number is the square of 36 / sqrt(3).
  let max_hypot2 = 432.0 * accuracy * accuracy
  let p1x2x = self.p1.x * 3.0 - self.p0.x
  let p1x2y = self.p1.y * 3.0 - self.p0.y
  let p2x2x = self.p2.x * 3.0 - self.p3.x
  let p2x2y = self.p2.y * 3.0 - self.p3.y
  let dx = p2x2x - p1x2x
  let dy = p2x2y - p1x2y
  let err = dx * dx + dy * dy
  let n = @math.pow(err / max_hypot2, 1.0 / 6.0).ceil()
  // `as usize` saturates (NaN is 0), then `.max(1)`.
  let n = if n.is_nan() || n < 1.0 {
    1
  } else if n > 1.0e9 {
    1000000000
  } else {
    n.to_int()
  }
  let out = []
  for i in 0..<n {
    let t0 = i.to_double() / n.to_double()
    let t1 = (i + 1).to_double() / n.to_double()
    let seg = self.subsegment(t0, t1)
    let p1x2x = seg.p1.x * 3.0 - seg.p0.x
    let p1x2y = seg.p1.y * 3.0 - seg.p0.y
    let p2x2x = seg.p2.x * 3.0 - seg.p3.x
    let p2x2y = seg.p2.y * 3.0 - seg.p3.y
    // (`Vec2 / f64` multiplies by the reciprocal.)
    let r = 1.0 / 4.0
    out.push({
      p0: seg.p0,
      p1: { x: (p1x2x + p2x2x) * r, y: (p1x2y + p2x2y) * r, },
      p2: seg.p3,
    })
  }
  out
}

// --- write-fonts ---

///|
/// A point of a contour (before rounding).
priv struct ContourPoint {
  point : Point
  on_curve : Bool
} derive(Eq)

///|
/// A simple glyph: the bounding box `(x_min, y_min, x_max, y_max)` and the
/// contours of rounded points.
priv struct SimpleGlyph {
  bbox : (Int, Int, Int, Int)
  contours : Array[Array[(Int, Int, Bool)]]
}

///|
/// Rust's `OtRound<i16> for f64`: `(v + 0.5).floor() as i16`.
fn ot_round(v : Double) -> Int {
  saturating_i16((v + 0.5).floor())
}

///|
/// Attempt to create a simple glyph from a path of line and quadratic
/// segments (`None` for malformed paths: cubic segments or a missing move).
fn simple_glyph_from_bezpath(path : BezPath) -> SimpleGlyph? {
  let contours : Array[Array[ContourPoint]] = []
  let mut current : Array[ContourPoint]? = None
  for el in path.elements {
    match el {
      MoveTo(p) => {
        // we have a new contour, flush the current one
        if current is Some(prev) {
          contours.push(prev)
        }
        current = Some([{ point: p, on_curve: true, }])
      }
      LineTo(p) => {
        guard current is Some(c) else { return None }
        c.push({ point: p, on_curve: true, })
      }
      QuadTo(p0, p1) => {
        guard current is Some(c) else { return None }
        c.push({ point: p0, on_curve: false, })
        c.push({ point: p1, on_curve: true, })
      }
      CurveTo(_, _, _) => return None
      ClosePath => {
        guard current is Some(c) else { return None }
        // remove last point in closed path if has same coords as the move
        // point
        if c.length() > 1 && c[c.length() - 1] == c[0] {
          c.pop() |> ignore
        }
      }
    }
  }
  if current is Some(c) {
    contours.push(c)
  }
  let glyph_contours = contours.map(points => {
    // Build the contour, dropping any on-curve points that can be implied.
    let out = []
    for i in 0..<points.length() {
      if !is_implicit_on_curve(points, i) {
        let p = points[i]
        out.push((ot_round(p.point.x), ot_round(p.point.y), p.on_curve))
      }
    }
    out
  })
  // We want the control point box, not the tight bbox.
  let (x0, y0, x1, y1) = path.control_box()
  Some({
    bbox: (ot_round(x0), ot_round(y0), ot_round(x1), ot_round(y1)),
    contours: glyph_contours,
  })
}

///|
fn is_implicit_on_curve(points : Array[ContourPoint], idx : Int) -> Bool {
  let p1 = points[idx]
  if !p1.on_curve {
    return false
  }
  let n = points.length()
  let p0 = points[if idx == 0 { n - 1 } else { idx - 1 }]
  let p2 = points[if idx == n - 1 { 0 } else { idx + 1 }]
  if p0.on_curve || p0.on_curve != p2.on_curve {
    return false
  }
  // drop p1 if halfway between p0 and p2
  is_mid_point(p0.point, p1.point, p2.point)
}

///|
/// True if p1 is the midpoint of p0 and p2 (checked both before and after
/// rounding to integers).
fn is_mid_point(p0 : Point, p1 : Point, p2 : Point) -> Bool {
  let mx = 0.5 * (p0.x + p2.x)
  let my = 0.5 * (p0.y + p2.y)
  let r = (v : Double) => (v + 0.5).floor()
  (isclose(mx, p1.x) && isclose(my, p1.y)) ||
  (r(p0.x) + r(p2.x) == r(p1.x) * 2.0 && r(p0.y) + r(p2.y) == r(p1.y) * 2.0)
}

///|
/// write-fonts' `isclose` with `rel_tol=1e-9` and `abs_tol=0.0`.
fn isclose(a : Double, b : Double) -> Bool {
  if a == b {
    return true
  }
  if a.is_nan() || a.is_inf() || b.is_nan() || b.is_inf() {
    return false
  }
  let rel_tol = 1.0e-9
  let diff = (a - b).abs()
  diff <= (rel_tol * b).abs() || diff <= (rel_tol * a).abs() || diff <= 0.0
}

///|
/// Serialize the glyph (`FontWrite for SimpleGlyph`; empty for a glyph
/// without contours).
fn SimpleGlyph::dump(self : SimpleGlyph) -> Bytes? {
  let w = Writer::new()
  let n_contours = self.contours.length()
  if n_contours >= 32767 {
    // (Upstream asserts.)
    return None
  }
  if n_contours == 0 {
    // we don't bother writing empty glyphs
    return Some(b"")
  }
  w.write_i16(n_contours)
  let (x_min, y_min, x_max, y_max) = self.bbox
  w.write_i16(x_min)
  w.write_i16(y_min)
  w.write_i16(x_max)
  w.write_i16(y_max)
  // now write end points of contours:
  let mut cur = 0
  for contour in self.contours {
    cur += contour.length()
    w.write_u16(((cur & 0xFFFF) - 1) & 0xFFFF)
  }
  // no instructions
  w.write_u16(0)
  // the flags and deltas of the points
  let flags = []
  let xs = []
  let ys = []
  let mut last_x = 0
  let mut last_y = 0
  for contour in self.contours {
    for p in contour {
      let (x, y, on_curve) = p
      let mut flag = 0
      // (`i16` arithmetic wraps.)
      let d_x = wrap_i16(x - last_x)
      let d_y = wrap_i16(y - last_y)
      last_x = x
      last_y = y
      if on_curve {
        flag = flag | 0x01
      }
      let (x_flag, x_data) = flag_and_delta(d_x, 0x02, 0x10)
      let (y_flag, y_data) = flag_and_delta(d_y, 0x04, 0x20)
      flags.push(flag | x_flag | y_flag)
      xs.push(x_data)
      ys.push(y_data)
    }
  }
  for f in repeatable_flags(flags) {
    let (flag, repeat) = f
    w.write_u8(flag)
    if (flag & 0x08) != 0 {
      w.write_u8(repeat)
    }
  }
  for d in xs {
    write_coord_delta(w, d)
  }
  for d in ys {
    write_coord_delta(w, d)
  }
  w.align(2)
  Some(w.finish())
}

///|
fn wrap_i16(v : Int) -> Int {
  let v = v & 0xFFFF
  if v >= 0x8000 {
    v - 0x10000
  } else {
    v
  }
}

///|
/// A coordinate delta: `Skip`, a short (one byte) or a long (two byte)
/// value.
priv enum CoordDelta {
  Skip
  Short(Int)
  Long(Int)
}

///|
fn write_coord_delta(w : Writer, d : CoordDelta) -> Unit {
  match d {
    Skip => ()
    Short(v) => w.write_u8(v)
    Long(v) => w.write_i16(v)
  }
}

///|
fn flag_and_delta(
  value : Int,
  short_flag : Int,
  same_or_pos : Int,
) -> (Int, CoordDelta) {
  if value == 0 {
    (same_or_pos, Skip)
  } else if value >= -255 && value <= -1 {
    (short_flag, Short(-value))
  } else if value >= 1 && value <= 255 {
    (short_flag | same_or_pos, Short(value))
  } else {
    (0, Long(value))
  }
}

///|
/// Flags with 'repeat' counts (`RepeatableFlag::iter_from_flags`): a flag
/// repeated exactly once is written twice instead of with a repeat count
/// of 1, like fontmake does.
fn repeatable_flags(flags : Array[Int]) -> Array[(Int, Int)] {
  let out = []
  let mut prev : (Int, Int)? = None
  let mut decompose_single_repeat : (Int, Int)? = None
  let mut i = 0
  for ;; {
    if decompose_single_repeat is Some(repeat) {
      decompose_single_repeat = None
      out.push(repeat)
      continue
    }
    let next = if i < flags.length() {
      i += 1
      Some(flags[i - 1])
    } else {
      None
    }
    let p = prev
    prev = None
    match (next, p) {
      (None, Some((flag, 1))) => {
        let flag = flag & 0xF7
        decompose_single_repeat = Some((flag, 0))
        out.push((flag, 0))
        // (The stashed copy is emitted at the top of the loop.)
      }
      (None, Some(last)) => {
        out.push(last)
        break
      }
      (None, None) => break
      (Some(flag), None) => prev = Some((flag, 0))
      (Some(flag), Some((last_flag, last_repeat))) =>
        if (last_flag & 0xF7) == flag && last_repeat < 255 {
          prev = Some((last_flag | 0x08, last_repeat + 1))
        } else {
          // split a single repeat into two non-repeat flags
          let mut last = (last_flag, last_repeat)
          if last_repeat == 1 {
            last = (last_flag & 0xF7, 0)
            // stash the extra flag, which we'll use at the top of the next
            // pass of the loop
            decompose_single_repeat = Some(last)
          }
          prev = Some((flag, 0))
          out.push(last)
        }
    }
  }
  out
}

///|
/// CFF2 fonts will currently be converted into TTF fonts.
fn cff2_subset(ctx : Context) -> Unit raise SubsetError {
  let maxp_data = MaxpData::default()
  let hmtx_data = []
  glyf_subset_with(ctx, old_gid => {
    match ctx.interjector {
      // We reject CFF2 fonts earlier if `variable-fonts` feature is not
      // enabled.
      Dummy => abort("unreachable")
      Skrifa(s) => {
        guard s.interject(maxp_data, old_gid) is Some((advance, lsb, data)) else {
          raise MalformedFont
        }
        hmtx_data.push((advance, lsb))
        data[:]
      }
    }
  })
  ctx.custom_maxp_data = Some(maxp_data)
  ctx.custom_hmtx_data = Some(hmtx_data)
}
