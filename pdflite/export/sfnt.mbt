// A minimal OpenType (sfnt) reader: the metrics needed to embed a font
// (krilla's `FontInfo`). Subsetting is done by `pdflite/subsetter`, outlines
// and variable metrics come from the skrifa port in
// `pdflite/internal/skrifa`.

///|
fn rd_u16(data : Bytes, at : Int) -> Int {
  if at < 0 || at > data.length() - 2 {
    return 0
  }
  (data[at].to_int() << 8) | data[at + 1].to_int()
}

///|
fn rd_i16(data : Bytes, at : Int) -> Int {
  let v = rd_u16(data, at)
  if v >= 0x8000 {
    v - 0x10000
  } else {
    v
  }
}

///|
fn rd_u32(data : Bytes, at : Int) -> Int {
  if at < 0 || at > data.length() - 4 {
    return 0
  }
  (data[at].to_int() << 24) |
  (data[at + 1].to_int() << 16) |
  (data[at + 2].to_int() << 8) |
  data[at + 3].to_int()
}

///|
fn rd_tag(data : Bytes, at : Int) -> String {
  let sb = StringBuilder()
  for i in 0..<4 {
    if at + i < data.length() {
      sb.write_char(data[at + i].to_int().unsafe_to_char())
    }
  }
  sb.to_string()
}

///|
/// The outline format of a font.
pub(all) enum OutlineKind {
  Glyf
  Cff
  Cff2
  NoOutlines
} derive(Eq, Debug)

///|
/// An OpenType font face to embed.
pub struct Font {
  /// The font file (possibly a collection).
  data : Bytes
  /// The index of the face in a collection.
  index : Int
  priv font_ref : @read_fonts.FontRef
  /// The number of font units per em.
  units_per_em : Double
  /// The number of glyphs.
  num_glyphs : Int
  /// The ascender in font units.
  ascent : Double
  /// The descender in font units (negative below the baseline).
  descent : Double
  /// The cap height in font units, if known.
  cap_height : Double?
  /// The italic angle in degrees.
  italic_angle : Double
  /// The weight class.
  weight : Double
  /// Whether the font is monospaced.
  is_monospaced : Bool
  /// The PostScript name.
  postscript_name : String?
  /// The global bounding box `(x_min, y_min, x_max, y_max)` in font units.
  bbox : (Double, Double, Double, Double)
  /// The OS/2 `fsType` embedding permissions.
  fs_type : Int
  /// The outline format.
  kind : OutlineKind
  /// An identifier used to derive subset tags.
  key : String
  /// The color glyph hook.
  priv mut color : ColorGlyphs?
  /// The variation coordinates (axis tag and user space value).
  priv variation_coordinates : Array[(@subsetter.Tag, Float)]
  /// The glyph metrics at the location of the variation coordinates, if it
  /// is not the default location.
  priv glyph_metrics : @skrifa.GlyphMetrics
  /// Whether the font has a readable `CFF ` table (krilla's `is_cff`, also
  /// when the font has `glyf` outlines too).
  priv has_cff : Bool
}

///|
/// Parse a font face from a font file and a collection index.
pub fn Font::new(data : Bytes, index : Int, key? : String = "") -> Font? {
  Font::new_variable(data, index, [], key~)
}

///|
/// Like [Font::new], but for a variable font at the given variation
/// coordinates (axis tags and user space values, like krilla's
/// `Font::new_variable`): metrics and embedded outlines are those of that
/// instance.
pub fn Font::new_variable(
  data : Bytes,
  index : Int,
  variation_coordinates : ArrayView[(@subsetter.Tag, Float)],
  key? : String = "",
) -> Font? {
  // Like krilla's `Font::new_variable`: the font must be readable by
  // read-fonts (`FontRef::from_index`) and have a readable `head` table;
  // other tables are read lazily and may be missing or out of bounds.
  let font_ref = @read_fonts.FontRef::from_index(data, index) catch {
    _ => return None
  }
  let head_table = font_ref.head() catch { _ => return None }
  let units_per_em = head_table.units_per_em()
  // (krilla would divide by zero; such a font is rejected instead.)
  if units_per_em == 0 {
    return None
  }
  let units_per_em = units_per_em.to_double()
  let bbox = (
    head_table.x_min().to_double(),
    head_table.y_min().to_double(),
    head_table.x_max().to_double(),
    head_table.y_max().to_double(),
  )
  let num_glyphs = glyph_names_num_glyphs(font_ref)
  let has_cff = ok(() => font_ref.cff()) is Some(_)
  let kind = if font_ref.data_for_tag("glyf") is Some(_) {
    Glyf
  } else if has_cff {
    Cff
  } else if font_ref.data_for_tag("CFF2") is Some(cff2) &&
    ok(() => @ps.Cff2::read(cff2.as_bytes())) is Some(_) {
    Cff2
  } else {
    NoOutlines
  }
  let settings = variation_coordinates.map(entry => {
    let b = entry.0.get()
    (
      (b[0].to_uint() << 24) |
      (b[1].to_uint() << 16) |
      (b[2].to_uint() << 8) |
      b[3].to_uint(),
      entry.1,
    )
  })
  let location = @skrifa.axes_location(font_ref, settings)
  let is_default = location.iter().all(c => c == @font_types.F2Dot14::zero())
  // krilla: `font_ref.glyph_metrics(Size::unscaled(), &location)` (also at
  // the default location).
  let glyph_metrics = @skrifa.GlyphMetrics::new(font_ref, location)
  // krilla's `FontInfo::new`: the line metrics come from the OS/2 typo
  // metrics, falling back to skrifa's `Metrics` (FreeType's choice of OS/2
  // and hhea metrics, with `MVAR` deltas at non-default locations).
  let coords = if is_default { location[0:0] } else { location }
  let mvar_delta = (tag : String) => {
    if coords.length() == 0 {
      return Float::from_int(0)
    }
    let t = @font_types.Tag::new(tag).to_u32()
    match ok(() => font_ref.mvar()) {
      Some(mvar) =>
        match ok(() => mvar.metric_delta(t, coords)) {
          Some(d) => Float::from_double(d.to_f64())
          None => 0.0
        }
      None => 0.0
    }
  }
  let os2 = ok(() => font_ref.os2())
  let (metrics_ascent, metrics_descent) = {
    let mut ascent : Float = 0.0
    let mut descent : Float = 0.0
    let mut used_typo_metrics = false
    if os2 is Some(os2) &&
      (os2.fs_selection() & @read_fonts.OS2_SELECTION_USE_TYPO_METRICS) != 0 {
      ascent = Float::from_int(os2.s_typo_ascender())
      descent = Float::from_int(os2.s_typo_descender())
      used_typo_metrics = true
    }
    if !used_typo_metrics {
      if ok(() => font_ref.hhea()) is Some(hhea) {
        ascent = Float::from_int(hhea.ascender())
        descent = Float::from_int(hhea.descender())
      }
      if ascent == 0.0 && descent == 0.0 && os2 is Some(os2) {
        if os2.s_typo_ascender() != 0 || os2.s_typo_descender() != 0 {
          ascent = Float::from_int(os2.s_typo_ascender())
          descent = Float::from_int(os2.s_typo_descender())
        } else {
          ascent = Float::from_int(os2.us_win_ascent())
          // Win descent is always positive while other descent values are
          // negative.
          descent = -Float::from_int(os2.us_win_descent())
        }
      }
    }
    (ascent + mvar_delta("hasc"), descent + mvar_delta("hdsc"))
  }
  let ascent = match os2 {
    Some(os2) => Float::from_int(os2.s_typo_ascender())
    None => metrics_ascent
  }
  let descent = match os2 {
    Some(os2) => Float::from_int(os2.s_typo_descender())
    None => metrics_descent
  }
  let cap_height = match os2 {
    Some(os2) =>
      match os2.s_cap_height() {
        Some(c) => Some((Float::from_int(c) + mvar_delta("cpht")).to_double())
        None => None
      }
    None => None
  }
  // skrifa's `Metrics`: from the `post` table (read-fonts requires 32
  // bytes).
  let (italic_angle, is_monospaced) = match font_ref.data_for_tag("post") {
    Some(post) if post.len() >= 32 => {
      let angle = post.read_i32(4) catch { _ => 0 }
      let fixed_pitch = post.read_u32(12) catch { _ => 0 }
      (
        // `Fixed::to_f64() as f32`
        Float::from_double(angle.to_double() / 65536.0).to_double(),
        fixed_pitch != 0,
      )
    }
    _ => (0.0, false)
  }
  // skrifa's `Attributes`: the OS/2 weight class, else the head's macStyle.
  let weight = match os2 {
    Some(os2) => os2.us_weight_class().to_double()
    None => if (head_table.mac_style() & 1) != 0 { 700.0 } else { 400.0 }
  }
  // (OS/2 `fsType`, for the restricted license check.)
  let fs_type = match os2 {
    Some(os2) => os2.fs_type()
    None => 0
  }
  let ascent = ascent.to_double()
  let descent = descent.to_double()
  Some({
    data,
    index,
    font_ref,
    units_per_em,
    num_glyphs,
    ascent,
    descent,
    cap_height,
    italic_angle,
    weight,
    is_monospaced,
    postscript_name: read_postscript_name(font_ref),
    bbox,
    fs_type,
    kind,
    key,
    color: None,
    // krilla stores the coordinates as `FiniteF32`s (non-finite values
    // become 0); the location of the metrics uses the values as given.
    variation_coordinates: variation_coordinates.map(entry => {
      let (tag, value) = entry
      (tag, if value.is_nan() || value.is_inf() { 0.0 } else { value })
    }),
    glyph_metrics,
    has_cff,
  })
}

///|
/// skrifa's `GlyphNames::num_glyphs`: the `maxp` glyph count (or 0), unless
/// the `post` table has no glyph names and the font has a name-keyed CFF
/// table, whose charset gives the count.
fn glyph_names_num_glyphs(font_ref : @read_fonts.FontRef) -> Int {
  let num_glyphs = match ok(() => font_ref.maxp()) {
    Some(maxp) => maxp.num_glyphs()
    None => 0
  }
  // `post.num_names()` (read-fonts' `post` requires 32 bytes; upstream
  // panics for a version 2.0 table without its glyph count, which counts as
  // no names here)
  let post_names = match font_ref.data_for_tag("post") {
    Some(post) if post.len() >= 32 => {
      let version = post.read_u32(0) catch { _ => 0 }
      match version {
        0x00010000U => 258
        0x00020000U => post.read_u16(32) catch { _ => 0 }
        _ => 0
      }
    }
    _ => 0
  }
  if post_names != 0 {
    return num_glyphs
  }
  match ok(() => font_ref.cff()) {
    Some(cff) => {
      let charset = @ps.Cff::read(cff.offset_data()).charset(0) catch {
        _ => None
      }
      match charset {
        Some(charset) => charset.num_glyphs()
        None => num_glyphs
      }
    }
    None => num_glyphs
  }
}

///|
/// The variation coordinates of the font.
pub fn Font::variation_coordinates(
  self : Font,
) -> ArrayView[(@subsetter.Tag, Float)] {
  self.variation_coordinates
}

///|
/// The advance width of a glyph in font units (at the location of the
/// variation coordinates).
pub fn Font::advance_width(self : Font, glyph : Int) -> Double? {
  if glyph < 0 {
    return None
  }
  match self.glyph_metrics.advance_width(@font_types.GlyphId::from_int(glyph)) {
    Some(w) => Some(w.to_double())
    None => None
  }
}

///|
/// Whether the font has a table.
pub fn Font::has_table(self : Font, tag : String) -> Bool {
  self.font_ref.data_for_tag(tag) is Some(_)
}

///|
/// The PostScript name like krilla reads it: the first name record with
/// name ID 6 whose string is in bounds.
fn read_postscript_name(font_ref : @read_fonts.FontRef) -> String? {
  guard ok(() => font_ref.name()) is Some(name) else { return None }
  for record in name.name_record() {
    if record.name_id == 6 {
      if ok(() => record.string(name.string_data())) is Some(string) {
        return Some(string.to_string())
      }
    }
  }
  None
}

///|
/// Runs `f`, returning `None` on error (Rust's `.ok()`).
fn[T] ok(f : () -> T raise) -> T? {
  try f() catch {
    _ => None
  } noraise {
    v => Some(v)
  }
}
