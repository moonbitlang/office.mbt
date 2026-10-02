// CID-keyed fonts (port of krilla's `text::cid` and `text` modules).
//
// Glyphs are addressed by their glyph ID (CID = GID, `/CIDToGIDMap
// /Identity`). TrueType fonts are subset by emptying the glyphs that are not
// used; CFF fonts are embedded as a whole OpenType font program
// (`/FontFile3` with `/Subtype /OpenType`).

///|
/// The number of units per em of CID fonts in PDF.
let pdf_units_per_em : Double = 1000.0

///|
/// A glyph to draw.
pub(all) struct Glyph {
  /// The glyph ID.
  glyph_id : Int
  /// The start of the glyph's cluster in the text (UTF-16 offset).
  text_start : Int
  /// The end of the glyph's cluster in the text (UTF-16 offset).
  text_end : Int
  /// The horizontal advance in em.
  x_advance : Double
  /// The horizontal offset in em.
  x_offset : Double
  /// The vertical advance in em.
  y_advance : Double
  /// The vertical offset in em.
  y_offset : Double
  /// The location of the glyph.
  location : Location?
}

///|
/// A CID-keyed font.
priv struct CIDFont {
  font : Font
  /// The used glyphs in order of first use.
  glyphs : Array[Int]
  used : Map[Int, Unit]
  /// The text of each glyph.
  cmap_entries : Map[Int, (String, Location?)]
}

///|
fn CIDFont::new(font : Font) -> CIDFont {
  { font, glyphs: [], used: {}, cmap_entries: {}, }
}

///|
fn CIDFont::is_empty(self : CIDFont) -> Bool {
  self.glyphs.is_empty()
}

///|
/// Add a glyph and return its CID.
fn CIDFont::add_glyph(self : CIDFont, glyph : Int) -> Int {
  if !self.used.contains(glyph) {
    self.used[glyph] = ()
    self.glyphs.push(glyph)
  }
  glyph
}

///|
fn CIDFont::get_codepoints(self : CIDFont, cid : Int) -> String? {
  match self.cmap_entries.get(cid) {
    Some((s, _)) => Some(s)
    None => None
  }
}

///|
fn CIDFont::set_codepoints(
  self : CIDFont,
  cid : Int,
  text : String,
  location : Location?,
) -> Unit {
  self.cmap_entries[cid] = (text, location)
}

///|
/// All PDF fonts belonging to an OpenType font.
priv struct FontContainer {
  font : Font
  cid_font : CIDFont
  /// The reference of the `Type0` font.
  ref_ : Int
}

///|
fn FontContainer::new(font : Font, ref_ : Int) -> FontContainer {
  { font, cid_font: CIDFont::new(font), ref_, }
}

///|
/// The subset tag of a font (six uppercase letters derived from the font
/// and its glyph set).
fn subset_tag(font : Font, glyphs : Array[Int]) -> String {
  // FNV-1a over the key, the PostScript name and the glyphs.
  let mut h = 0xcbf29ce484222325UL
  let feed = (v : Int) => h = (h ^ (v & 0xFF).to_uint64()) * 0x100000001b3UL
  for c in font.key {
    feed(c.to_int())
  }
  if font.postscript_name is Some(n) {
    for c in n {
      feed(c.to_int())
    }
  }
  let sorted = glyphs.copy()
  sorted.sort()
  for g in sorted {
    feed(g)
    feed(g >> 8)
  }
  let sb = StringBuilder::new()
  for _ in 0..<6 {
    sb.write_char(('A'.to_int() + (h % 26UL).to_int()).unsafe_to_char())
    h = h / 26UL
  }
  sb.to_string()
}

///|
fn hex4(v : Int) -> String {
  let sb = StringBuilder::new()
  for shift in [12, 8, 4, 0] {
    sb.write_char(hex_digits[(v >> shift) & 0xF].unsafe_to_char())
  }
  sb.to_string()
}

///|
/// Write the cmap entry of a glyph and register validation errors for
/// invalid mappings.
fn write_cmap_entry(
  sc : SerializeContext,
  font : Font,
  entry : (String, Location?)?,
  g : Int,
  out : Array[(Int, String)],
) -> Unit {
  match entry {
    None => sc.register_validation_error(NoCodepointMapping(font, g, None))
    Some((text, loc)) => {
      let mut invalid_codepoint = text.is_empty()
      let mut invalid_code = None
      let mut private_unicode = None
      for c in text {
        let cp = c.to_int()
        if cp == 0 || cp == 0xFEFF || cp == 0xFFFE {
          invalid_code = Some(c)
          invalid_codepoint = true
        }
        if (cp >= 0xE000 && cp <= 0xF8FF) ||
          (cp >= 0xF0000 && cp <= 0xFFFFD) ||
          (cp >= 0x100000 && cp <= 0x10FFFD) {
          private_unicode = Some(c)
        }
      }
      match invalid_code {
        Some(c) =>
          sc.register_validation_error(InvalidCodepointMapping(font, g, c, loc))
        None =>
          if invalid_codepoint {
            sc.register_validation_error(NoCodepointMapping(font, g, loc))
          }
      }
      if private_unicode is Some(c) {
        sc.register_validation_error(UnicodePrivateArea(font, g, c, loc))
      }
      if !text.is_empty() {
        out.push((g, text))
      }
    }
  }
}

///|
/// Build a ToUnicode CMap stream.
fn to_unicode_cmap(entries : Array[(Int, String)]) -> Bytes {
  let sb = StringBuilder::new()
  sb.write_string(
    "%!PS-Adobe-3.0 Resource-CMap\n%%DocumentNeededResources: procset CIDInit\n%%IncludeResource: procset CIDInit\n%%BeginResource: CMap Custom\n%%Title: (Custom Adobe Identity 0)\n%%Version: 1\n%%EndComments\n/CIDInit /ProcSet findresource begin\n12 dict begin\nbegincmap\n/CIDSystemInfo 3 dict dup begin\n    /Registry (Adobe) def\n    /Ordering (Identity) def\n    /Supplement 0 def\nend def\n/CMapName /Custom def\n/CMapVersion 1 def\n/CMapType 0 def\n/WMode 0 def\n1 begincodespacerange\n<0000> <ffff>\nendcodespacerange\n",
  )
  let mut i = 0
  while i < entries.length() {
    let n = @math.minimum(100.0, (entries.length() - i).to_double()).to_int()
    sb.write_string("\{n} beginbfchar\n")
    for k in i..<(i + n) {
      let (g, text) = entries[k]
      sb.write_string("<\{hex4(g)}> <")
      for j in 0..<text.length() {
        sb.write_string(hex4(text.unsafe_get(j).to_int()))
      }
      sb.write_string(">\n")
    }
    sb.write_string("endbfchar\n")
    i += n
  }
  sb.write_string(
    "endcmap\nCMapName currentdict /CMap defineresource pop\nend\nend\n%%EndResource\n%%EOF",
  )
  utf8_bytes(sb.to_string())
}

///|
/// Serialize a CID font as a `Type0` font at `root_ref`.
fn CIDFont::serialize(
  self : CIDFont,
  sc : SerializeContext,
  root_ref : Int,
) -> Unit raise ExportError {
  let font = self.font
  let is_cff = font.kind == Cff || font.kind == Cff2
  if font.kind == NoOutlines {
    raise FontError(font, "font is missing an outline table")
  }
  // Restricted license embedding (see krilla for why `& 0xF == 2`).
  if (font.fs_type & 0xF) == 2 {
    sc.register_validation_error(RestrictedLicense(font))
  }
  let cid_ref = sc.new_ref()
  let descriptor_ref = sc.new_ref()
  let cmap_ref = sc.new_ref()
  let data_ref = sc.new_ref()
  let glyphs = self.glyphs.copy()
  glyphs.push(0)
  let keep = font.glyph_closure(glyphs)
  let base_font = {
    let ps = match font.postscript_name {
      Some(n) => n
      None => "unknown"
    }
    let max_len = 127 - (6 + 1 + 1 + 10)
    let ps = if ps.length() > max_len {
      ps.unsafe_substring(start=0, end=max_len)
    } else {
      ps
    }
    "\{subset_tag(font, self.glyphs)}+\{ps}"
  }
  let base_font_type0 = if is_cff {
    "\{base_font}-Identity-H"
  } else {
    base_font
  }
  sc.put(
    root_ref,
    Dict([
      ("Type", Name("Font")),
      ("Subtype", Name("Type0")),
      ("BaseFont", Name(base_font_type0)),
      ("Encoding", Name("Identity-H")),
      ("DescendantFonts", Arr([Ref(cid_ref)])),
      ("ToUnicode", Ref(cmap_ref)),
    ]),
  )
  // CID fonts assume 1000 units per em.
  let to_pdf_units = (v : Double) => v / font.units_per_em * pdf_units_per_em
  let sorted = keep.keys().collect()
  sorted.sort()
  let widths = []
  for g in sorted {
    let w = font.advance_width(g).unwrap_or(0.0)
    if w != 0.0 {
      widths.push(Int(g))
      widths.push(Arr([Real(to_pdf_units(w))]))
    }
  }
  let cid = DictBuilder::new()
  cid.set("Type", Name("Font"))
  cid.set("Subtype", Name(if is_cff { "CIDFontType0" } else { "CIDFontType2" }))
  cid.set("BaseFont", Name(base_font))
  cid.set(
    "CIDSystemInfo",
    Dict([
      ("Registry", Str(utf8_bytes("Adobe"))),
      ("Ordering", Str(utf8_bytes("Identity"))),
      ("Supplement", Int(0)),
    ]),
  )
  cid.set("FontDescriptor", Ref(descriptor_ref))
  cid.set("DW", Int(0))
  if !is_cff {
    cid.set("CIDToGIDMap", Name("Identity"))
  }
  cid.set("W", Arr(widths))
  sc.put(cid_ref, cid.finish())
  // The font descriptor.
  let mut flags = 0
  if font.postscript_name is Some(n) && n.contains("Serif") {
    flags = flags | 2
  }
  if font.is_monospaced {
    flags = flags | 1
  }
  if font.italic_angle != 0.0 {
    flags = flags | 64
  }
  flags = flags | 4 // symbolic
  flags = flags | (1 << 17) // small cap
  let (x0, y0, x1, y1) = if font.kind == Glyf {
    let mut b = None
    for g in sorted {
      if font.glyph_bbox(g) is Some((a, c, d, e)) &&
        (a != 0.0 || c != 0.0 || d != 0.0 || e != 0.0) {
        b = Some(
          match b {
            None => (a, c, d, e)
            Some((p, q, r, s)) =>
              (
                @math.minimum(p, a),
                @math.minimum(q, c),
                @math.maximum(r, d),
                @math.maximum(s, e),
              )
          },
        )
      }
    }
    b.unwrap_or(font.bbox)
  } else {
    font.bbox
  }
  let ascent = to_pdf_units(font.ascent)
  let descent = to_pdf_units(font.descent)
  let cap_height = match font.cap_height {
    Some(c) => to_pdf_units(c)
    None => ascent
  }
  let stem_v = 10.0 + 0.244 * (font.weight - 50.0)
  sc.put(
    descriptor_ref,
    Dict([
      ("Type", Name("FontDescriptor")),
      ("FontName", Name(base_font)),
      ("Flags", Int(flags)),
      (
        "FontBBox",
        pdf_rect(
          to_pdf_units(x0),
          to_pdf_units(y0),
          to_pdf_units(x1),
          to_pdf_units(y1),
        ),
      ),
      ("ItalicAngle", Real(font.italic_angle)),
      ("Ascent", Real(ascent)),
      ("Descent", Real(descent)),
      ("CapHeight", Real(cap_height)),
      ("StemV", Real(stem_v)),
      (if is_cff { "FontFile3" } else { "FontFile2" }, Ref(data_ref)),
    ]),
  )
  // The ToUnicode CMap. For the .notdef glyph, it's fine if no mapping
  // exists, since it is included even if it was not referenced in the text.
  let entries = []
  for g in sorted {
    if g == 0 || !self.used.contains(g) {
      continue
    }
    write_cmap_entry(sc, font, self.cmap_entries.get(g), g, entries)
  }
  sc.put_content_stream(cmap_ref, [], to_unicode_cmap(entries))
  // The font program.
  if is_cff {
    sc.put_stream(data_ref, [("Subtype", Name("OpenType"))], font.face_data())
  } else {
    sc.put_stream(data_ref, [], font.subset_glyf(keep))
  }
}

///|
/// An error that aborts the export.
pub(all) suberror ExportError {
  /// A font could not be processed.
  FontError(Font, String)
  /// The document violates the validators.
  Validation(Array[(ValidationError, Validators)])
  /// An image could not be processed.
  ImageError(Location?, String)
  /// A tag ID was used twice.
  DuplicateTagId(Bytes, Location?)
  /// A tag ID was referenced but does not exist.
  UnknownTagId(Bytes, Location?)
  /// Two named destinations have the same name.
  DuplicateNamedDestination(String)
}
