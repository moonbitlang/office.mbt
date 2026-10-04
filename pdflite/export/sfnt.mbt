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
  priv tables : Map[String, (Int, Int)]
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
  // Offsets and lengths are validated up front, so that all later reads and
  // slices stay in bounds (reads past the end of a table only see bytes of
  // the file, never panic).
  let mut base = 0
  if data.length() >= 12 && rd_tag(data, 0) == "ttcf" {
    let count = rd_u32(data, 8)
    if index < 0 ||
      count < 0 ||
      index >= count ||
      // (Without multiplying `index`, which could overflow.)
      index > (data.length() - 16) / 4 {
      return None
    }
    base = rd_u32(data, 12 + 4 * index)
  } else if index != 0 {
    return None
  }
  if base < 0 || base > data.length() - 12 {
    return None
  }
  let num_tables = rd_u16(data, base + 4)
  if base + 12 + 16 * num_tables > data.length() {
    return None
  }
  let tables : Map[String, (Int, Int)] = Map([])
  for i in 0..<num_tables {
    let rec = base + 12 + 16 * i
    let tag = rd_tag(data, rec)
    // `rd_u32` returns negative values for offsets and lengths >= 2^31.
    let offset = rd_u32(data, rec + 8)
    let length = rd_u32(data, rec + 12)
    if offset < 0 || length < 0 || offset > data.length() - length {
      return None
    }
    tables[tag] = (offset, length)
  }
  // The tables that are read without further length checks.
  // (`head`, `hhea` and `maxp` are required, like in ttf-parser.)
  for entry in [("head", 54), ("hhea", 36), ("maxp", 6)] {
    match tables.get(entry.0) {
      Some((_, len)) => if len < entry.1 { return None }
      None => return None
    }
  }
  guard tables.get("head") is Some((head, _)) else { return None }
  // Like ttf-parser, which rejects other values.
  let units_per_em = rd_u16(data, head + 18)
  if units_per_em < 16 || units_per_em > 16384 {
    return None
  }
  let units_per_em = units_per_em.to_double()
  let bbox = (
    rd_i16(data, head + 36).to_double(),
    rd_i16(data, head + 38).to_double(),
    rd_i16(data, head + 40).to_double(),
    rd_i16(data, head + 42).to_double(),
  )
  let num_glyphs = match tables.get("maxp") {
    Some((maxp, _)) => rd_u16(data, maxp + 4)
    None => 0
  }
  if num_glyphs == 0 {
    return None
  }
  // krilla checks that the outline tables can be read.
  let font_ref = @read_fonts.FontRef::from_index(data, index) catch {
    _ => return None
  }
  let has_cff = ok(() => font_ref.cff()) is Some(_)
  let kind = if tables.contains("glyf") {
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
  let (italic_angle, is_monospaced) = match tables.get("post") {
    // read-fonts' `post` requires 32 bytes.
    Some((post, len)) if len >= 32 =>
      (
        // `Fixed::to_f64() as f32`
        Float::from_double(rd_u32(data, post + 4).to_double() / 65536.0).to_double(),
        rd_u32(data, post + 12) != 0,
      )
    _ => (0.0, false)
  }
  // skrifa's `Attributes`: the OS/2 weight class, else the head's macStyle.
  let weight = match os2 {
    Some(os2) => os2.us_weight_class().to_double()
    None => if (rd_u16(data, head + 44) & 1) != 0 { 700.0 } else { 400.0 }
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
    tables,
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
    variation_coordinates: variation_coordinates.to_owned(),
    glyph_metrics,
    has_cff,
  })
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
  self.tables.contains(tag)
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
