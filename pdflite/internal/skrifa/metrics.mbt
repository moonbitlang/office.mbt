// Ports of skrifa 0.42.1 `src/metrics.rs` (`GlyphMetrics`, unscaled advance
// widths) and `src/variation.rs` (`AxisCollection::location`).

///|
/// Glyph specific metrics at a location in variation space (unscaled).
pub struct GlyphMetrics {
  priv glyph_count : Int
  priv hmtx : @read_fonts.Hmtx?
  priv hvar : @read_fonts.Hvar?
  priv gvar : @read_fonts.Gvar?
  priv loca_glyf : (@read_fonts.Loca, @read_fonts.Glyf)?
  priv coords : Array[F2Dot14]
}

///|
/// Creates new (unscaled) glyph metrics from the given font and location in
/// normalized variation space.
pub fn GlyphMetrics::new(
  font : FontRef,
  location : ArrayView[F2Dot14],
) -> GlyphMetrics {
  let glyph_count = match ok(() => font.maxp()) {
    Some(maxp) => maxp.num_glyphs()
    None => 0
  }
  // `LocationRef::effective_coords`
  let coords = if LocationRef(location.to_array()).is_default() {
    []
  } else {
    location.to_array()
  }
  let loca_glyf = match (ok(() => font.loca(None)), ok(() => font.glyf())) {
    (Some(loca), Some(glyf)) => Some((loca, glyf))
    _ => None
  }
  {
    glyph_count,
    hmtx: ok(() => font.hmtx()),
    hvar: ok(() => font.hvar()),
    gvar: ok(() => font.gvar()),
    loca_glyf,
    coords,
  }
}

///|
/// Returns the advance width for the specified glyph (`None` if `glyph_id
/// >= glyph_count`).
///
/// If normalized coordinates were provided and an `HVAR` table is present,
/// applies the appropriate delta (else uses the `gvar` phantom points).
pub fn GlyphMetrics::advance_width(
  self : GlyphMetrics,
  glyph_id : GlyphId,
) -> Float? {
  if glyph_id.to_int() >= self.glyph_count {
    return None
  }
  let mut advance = match self.hmtx {
    Some(hmtx) => advance_or_default(hmtx, glyph_id)
    None => 0
  }
  match self.hvar {
    Some(hvar) =>
      // FreeType truncates metric deltas...
      advance += match
        (try? hvar.advance_width_delta(glyph_id, self.coords[:])) {
        Ok(delta) => trunc_f64_to_i32(delta.to_f64())
        Err(_) => 0
      }
    None =>
      if self.gvar is Some(_) {
        advance += match self.metric_deltas_from_gvar(glyph_id) {
          Some((_, d)) => d
          None => 0
        }
      }
  }
  // `FixedScaleFactor::apply` with the identity scale.
  Some(
    Fixed::from_bits(0x10000 * 64)
    .mul_div(Fixed::from_bits(advance), Fixed::from_bits(64))
    .to_f32(),
  )
}

///|
/// `h_metrics.get(gid).map(advance).unwrap_or(default_advance_width)`.
fn advance_or_default(hmtx : @read_fonts.Hmtx, glyph_id : GlyphId) -> Int {
  let n = hmtx.num_h_metrics()
  let gid = glyph_id.to_int()
  if gid < n {
    hmtx.h_metric_advance(gid)
  } else if n > 0 {
    hmtx.h_metric_advance(n - 1)
  } else {
    0
  }
}

///|
/// Rust's saturating `f64 as i32`.
fn trunc_f64_to_i32(v : Double) -> Int {
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
/// The `[lsb, advance]` deltas from the `gvar` phantom points.
fn GlyphMetrics::metric_deltas_from_gvar(
  self : GlyphMetrics,
  glyph_id : GlyphId,
) -> (Int, Int)? {
  guard self.loca_glyf is Some((loca, glyf)) else { return None }
  guard self.gvar is Some(gvar) else { return None }
  guard (try? gvar.phantom_point_deltas(glyf, loca, self.coords[:], glyph_id))
    is Ok(Some(deltas)) else {
    return None
  }
  let d0 = deltas[0].0
  let d1 = deltas[1].0 - d0
  Some((Fixed::from_bits(d0).to_i32(), Fixed::from_bits(d1).to_i32()))
}

///|
/// Converts user space variation settings (axis tag and value) to an
/// ordered sequence of normalized coordinates (`font.axes().location(..)`):
/// settings for unknown axes are ignored, values are clamped to the axis
/// range, the last setting for an axis wins and unset axes are at their
/// default (0).
pub fn axes_location(
  font : FontRef,
  settings : ArrayView[(UInt, Float)],
) -> Array[F2Dot14] {
  match ok(() => font.fvar()) {
    Some(fvar) => {
      let location = FixedArray::make(fvar.axis_count(), F2Dot14::zero())
      let avar = ok(() => font.avar())
      let user = settings.map(s => (s.0, Fixed::from_f64(s.1.to_double())))
      fvar.user_to_normalized(avar, user, location)
      location.iter().collect()
    }
    None => []
  }
}
