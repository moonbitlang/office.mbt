// Port of subsetter 0.2.6 `src/interjector.rs` and `src/cff2.rs`.

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
  data : Bytes
  index : Int
  coords : Array[(Tag, Float)]
}

///|
fn SkrifaInterjector::new(
  data : Bytes,
  index : Int,
  location : ArrayView[(Tag, Float)],
) -> SkrifaInterjector? {
  Some({ data, index, coords: location.to_array(), })
}

///|
fn SkrifaInterjector::is_default_location(self : SkrifaInterjector) -> Bool {
  self.coords.is_empty()
}

///|
/// Return the glyph description in the `glyf` outline format.
fn SkrifaInterjector::interject(
  self : SkrifaInterjector,
  maxp_data : MaxpData,
  glyph : Int,
) -> (Int, Int, Bytes)? {
  ignore((self, glyph))
  maxp_data.max_points = maxp_data.max_points
  maxp_data.max_contours = maxp_data.max_contours
  None
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
