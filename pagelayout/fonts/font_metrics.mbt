///|
// Deterministic font metrics for the layout engine, parsed from the bundled
// metrics-only sfnt data in data_*.mbt (regenerate with
// tools/font-metrics/gen_font_metrics.py). Only metric tables are bundled;
// glyph outlines arrive with the PDF backend milestone, behind this same API.

///|
/// Metrics of one bundled face. Vertical metrics come from `hhea`; advances
/// are raw font units scaled by `units_per_em` on lookup.
pub struct FaceMetrics {
  family : String
  bold : Bool
  italic : Bool
  units_per_em : Int
  ascender : Int
  descender : Int
  line_gap : Int
  advances : Array[Int]
  cmap : Map[Int, Int]
}

///|
/// Horizontal advance of `codepoint` at `size_pt`, in points. Codepoints
/// missing from the face use the `.notdef` (glyph 0) advance; glyphs past
/// `numberOfHMetrics` share the table's final advance, per TrueType.
pub fn FaceMetrics::advance_pt(
  self : FaceMetrics,
  codepoint : Int,
  size_pt : Double,
) -> Double {
  let glyph = self.cmap.get(codepoint).unwrap_or(0)
  let index = if glyph >= self.advances.length() {
    self.advances.length() - 1
  } else {
    glyph
  }
  self.advances[index].to_double() * size_pt / self.units_per_em.to_double()
}

///|
/// Whether the face maps `codepoint` to a real glyph.
pub fn FaceMetrics::has_char(self : FaceMetrics, codepoint : Int) -> Bool {
  self.cmap.get(codepoint) is Some(glyph) && glyph != 0
}

///|
/// Baseline-to-top extent at `size_pt`, in points (positive).
pub fn FaceMetrics::ascent_pt(self : FaceMetrics, size_pt : Double) -> Double {
  self.ascender.to_double() * size_pt / self.units_per_em.to_double()
}

///|
/// Baseline-to-bottom extent at `size_pt`, in points (negative, per hhea).
pub fn FaceMetrics::descent_pt(self : FaceMetrics, size_pt : Double) -> Double {
  self.descender.to_double() * size_pt / self.units_per_em.to_double()
}

///|
/// Single line spacing at `size_pt`: ascender − descender + line gap.
pub fn FaceMetrics::line_height_pt(
  self : FaceMetrics,
  size_pt : Double,
) -> Double {
  (self.ascender - self.descender + self.line_gap).to_double() *
  size_pt /
  self.units_per_em.to_double()
}

///|
fn parse_face(
  family : String,
  bold : Bool,
  italic : Bool,
  chunks : Array[Bytes],
) -> FaceMetrics raise {
  let joined = Buffer()
  for chunk in chunks {
    joined.write_bytes(chunk)
  }
  let data : Bytes = @flate.pdf_flate_decode_view(joined.contents())
  let metrics = @pdflite.pdf_truetype_metrics(data)
  let cmap : Map[Int, Int] = Map([])
  // later subtables replace earlier mappings, matching cpdf's reader
  for entry in @pdflite.pdf_truetype_cmap_glyphs(data) {
    cmap[entry.codepoint] = entry.glyph_index
  }
  guard @pdflite.pdf_truetype_table(data, "hhea") is Some(hhea) else {
    fail("bundled face \{family} lacks an hhea table")
  }
  let ascender = read_i16(data, hhea.offset + 4)
  let descender = read_i16(data, hhea.offset + 6)
  let line_gap = read_i16(data, hhea.offset + 8)
  {
    family,
    bold,
    italic,
    units_per_em: metrics.units_per_em,
    ascender,
    descender,
    line_gap,
    advances: metrics.advance_widths,
    cmap,
  }
}

///|
fn read_i16(data : Bytes, offset : Int) -> Int {
  let hi = data[offset].to_int()
  let lo = data[offset + 1].to_int()
  let value = (hi << 8) | lo
  if value >= 0x8000 {
    value - 0x10000
  } else {
    value
  }
}

///|
let face_cache : Map[String, FaceMetrics] = Map([])

///|
fn face_key(family : String, bold : Bool, italic : Bool) -> String {
  "\{family}|\{bold}|\{italic}"
}

///|
fn load_faces() -> Unit {
  if face_cache.is_empty() {
    for entry in bundled_faces() {
      let (family, bold, italic, chunks) = entry
      let face = try! parse_face(family, bold, italic, chunks)
      face_cache[face_key(family, bold, italic)] = face
    }
  }
}

///|
/// Every bundled family, in registry order (deduplicated).
pub fn bundled_families() -> Array[String] {
  load_faces()
  let seen : Map[String, Unit] = Map([])
  let families : Array[String] = []
  for entry in bundled_faces() {
    let (family, _, _, _) = entry
    if !seen.contains(family) {
      seen[family] = ()
      families.push(family)
    }
  }
  families
}

///|
/// The bundled face for a *resolved* family name (see `resolve_family`).
/// Falls back to the family's regular face when the exact bold/italic face
/// is not bundled (Noto Sans SC ships regular only), then to Carlito.
pub fn face(
  family : String,
  bold? : Bool = false,
  italic? : Bool = false,
) -> FaceMetrics {
  load_faces()
  match face_cache.get(face_key(family, bold, italic)) {
    Some(found) => found
    None =>
      match face_cache.get(face_key(family, false, false)) {
        Some(regular) => regular
        None =>
          match face_cache.get(face_key("Carlito", bold, italic)) {
            Some(default_face) => default_face
            None => try! fail("bundled font registry is empty")
          }
      }
  }
}

///|
/// The face used for CJK codepoints the Latin faces lack.
pub fn cjk_fallback() -> FaceMetrics {
  face("Noto Sans SC")
}
