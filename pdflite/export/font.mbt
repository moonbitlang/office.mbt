// CID-keyed fonts (port of krilla's `text::cid` and `text` modules).
//
// Like krilla, fonts are subset with `pdflite/subsetter` (a port of the
// `subsetter` crate): glyphs get new, consecutive glyph IDs in the order of
// their first use, which are also their CIDs (CFF fonts are converted to
// CID-keyed fonts with an identity charset, `/CIDToGIDMap /Identity` for
// TrueType fonts). CFF subsets are embedded as bare CFF programs
// (`/FontFile3` with `/Subtype /CIDFontType0C`), TrueType subsets (also of
// CFF2 fonts, which the subsetter converts) as `/FontFile2`.

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
  /// The _actual_ underlying OTF font of the CID-keyed font.
  font : Font
  /// A mapper that maps GIDs from the original font to CIDs, i.e. the
  /// corresponding GID in the font subset.
  glyph_remapper : @subsetter.GlyphRemapper
  /// A mapping from CIDs to their string in the original text.
  cmap_entries : Map[Int, (String, Location?)]
  /// The widths of the glyphs, _indexed by their CID_.
  widths : Array[Float]
  mut is_empty : Bool
}

///|
fn CIDFont::new(font : Font) -> CIDFont {
  // Always include the .notdef glyph. Will also always be included by the
  // subsetter in the glyph remapper.
  let widths = [Float::from_double(font.advance_width(0).unwrap_or(0.0))]
  {
    glyph_remapper: @subsetter.GlyphRemapper::new(),
    cmap_entries: {},
    widths,
    font,
    is_empty: true,
  }
}

///|
fn CIDFont::is_empty(self : CIDFont) -> Bool {
  self.is_empty
}

///|
/// Add a new glyph (if it has not already been added) and return its CID.
fn CIDFont::add_glyph(self : CIDFont, glyph : Int) -> Int {
  self.is_empty = false
  let new_id = self.glyph_remapper.remap(glyph)
  // This means that the glyph ID has been newly assigned, and thus we need
  // to add its width.
  if new_id >= self.widths.length() {
    self.widths.push(
      Float::from_double(self.font.advance_width(glyph).unwrap_or(0.0)),
    )
  }
  new_id
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
/// The subset tag of a font: six uppercase letters derived from krilla's
/// `stable_hash128` of the glyph remapper (SipHash-1-3 128 of the remapped
/// glyphs as a Rust `Vec<u16>` hash: a `u64` length and the `u16`s, little
/// endian).
fn subset_tag(remapper : @subsetter.GlyphRemapper) -> String {
  let gids = remapper.remapped_gids()
  let bytes = []
  let len = gids.length().to_uint64()
  for i in 0..<8 {
    bytes.push(((len >> (8 * i)) & 0xFFUL).to_byte())
  }
  for g in gids {
    bytes.push((g & 0xFF).to_byte())
    bytes.push(((g >> 8) & 0xFF).to_byte())
  }
  let (h1, h2) = siphash13_128(Bytes::from_array(bytes))
  let mut hash = (@bigint.BigInt::from_uint64(h2) << 64) |
    @bigint.BigInt::from_uint64(h1)
  let base = @bigint.BigInt::from_int(26)
  let sb = StringBuilder()
  for _ in 0..<6 {
    sb.write_char(('A'.to_int() + (hash % base).to_int()).unsafe_to_char())
    hash = hash / base
  }
  sb.to_string()
}

///|
/// SipHash-1-3 with 128-bit output and zero keys (the `siphasher` crate's
/// `sip128::SipHasher13`): `(h1, h2)`.
fn siphash13_128(msg : Bytes) -> (UInt64, UInt64) {
  let mut v0 = 0x736f6d6570736575UL
  let mut v1 = 0x646f72616e646f83UL
  let mut v2 = 0x6c7967656e657261UL
  let mut v3 = 0x7465646279746573UL
  let rotl = (x : UInt64, b : Int) => (x << b) | (x >> (64 - b))
  let round = () => {
    v0 = v0 + v1
    v1 = rotl(v1, 13)
    v1 = v1 ^ v0
    v0 = rotl(v0, 32)
    v2 = v2 + v3
    v3 = rotl(v3, 16)
    v3 = v3 ^ v2
    v0 = v0 + v3
    v3 = rotl(v3, 21)
    v3 = v3 ^ v0
    v2 = v2 + v1
    v1 = rotl(v1, 17)
    v1 = v1 ^ v2
    v2 = rotl(v2, 32)
  }
  let n = msg.length()
  let full = n / 8 * 8
  let mut i = 0
  while i < full {
    let mut m = 0UL
    for k in 0..<8 {
      m = m | (msg[i + k].to_uint64() << (8 * k))
    }
    v3 = v3 ^ m
    round()
    v0 = v0 ^ m
    i += 8
  }
  let mut tail = 0UL
  for k in 0..<(n - full) {
    tail = tail | (msg[full + k].to_uint64() << (8 * k))
  }
  let b = ((n.to_uint64() & 0xFFUL) << 56) | tail
  v3 = v3 ^ b
  round()
  v0 = v0 ^ b
  v2 = v2 ^ 0xeeUL
  round()
  round()
  round()
  let h1 = v0 ^ v1 ^ v2 ^ v3
  v1 = v1 ^ 0xddUL
  round()
  round()
  round()
  let h2 = v0 ^ v1 ^ v2 ^ v3
  (h1, h2)
}

///|
/// The base font name: the subset tag and the (trimmed) PostScript name.
fn base_font_name(font : Font, remapper : @subsetter.GlyphRemapper) -> String {
  let rest_len = 6 + 1 + 1 + 10
  let postscript_name = match font.postscript_name {
    Some(n) => n
    None => "unknown"
  }
  let max_len = 127 - rest_len
  // (Rust slices the UTF-8 bytes; the names are ASCII in practice.)
  let trimmed = if utf8_bytes(postscript_name).length() > max_len {
    let sb = StringBuilder()
    let mut len = 0
    for c in postscript_name {
      let l = utf8_bytes(c.to_string()).length()
      if len + l > max_len {
        break
      }
      sb.write_char(c)
      len += l
    }
    sb.to_string()
  } else {
    postscript_name
  }
  "\{subset_tag(remapper)}+\{trimmed}"
}

///|
fn hex4(v : Int) -> String {
  let sb = StringBuilder()
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
  code? : Int = g,
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
        out.push((code, text))
      }
    }
  }
}

///|
/// Build a ToUnicode CMap stream.
fn to_unicode_cmap(
  entries : Array[(Int, String)],
  one_byte? : Bool = false,
) -> Bytes {
  let sb = StringBuilder()
  sb.write_string(
    "%!PS-Adobe-3.0 Resource-CMap\n%%DocumentNeededResources: procset CIDInit\n%%IncludeResource: procset CIDInit\n%%BeginResource: CMap Custom\n%%Title: (Custom Adobe Identity 0)\n%%Version: 1\n%%EndComments\n/CIDInit /ProcSet findresource begin\n12 dict begin\nbegincmap\n/CIDSystemInfo 3 dict dup begin\n    /Registry (Adobe) def\n    /Ordering (Identity) def\n    /Supplement 0 def\nend def\n/CMapName /Custom def\n/CMapVersion 1 def\n/CMapType 0 def\n/WMode 0 def\n",
  )
  sb.write_string(
    if one_byte {
      "1 begincodespacerange\n<00> <FF>\nendcodespacerange\n"
    } else {
      "1 begincodespacerange\n<0000> <FFFF>\nendcodespacerange\n"
    },
  )
  let mut i = 0
  while i < entries.length() {
    let n = @cmp.minimum(100.0, (entries.length() - i).to_double()).to_int()
    sb.write_string("\{n} beginbfchar\n")
    for k in i..<(i + n) {
      let (g, text) = entries[k]
      sb.write_string(
        if one_byte {
          "<\{hex4(g).unsafe_substring(start=2, end=4)}> <"
        } else {
          "<\{hex4(g)}> <"
        },
      )
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
/// A pen that records the points of a path like tiny-skia's `PathBuilder`
/// (krilla's `OutlineBuilder`) to compute its bounds.
priv struct BoundsPen {
  xs : Array[Float]
  ys : Array[Float]
  /// The number of verbs and whether the last one is a move.
  mut verbs : Int
  mut last_is_move : Bool
  mut last_is_close : Bool
  mut move_to_required : Bool
  mut last_move_to_index : Int
}

///|
fn BoundsPen::new() -> BoundsPen {
  {
    xs: [],
    ys: [],
    verbs: 0,
    last_is_move: false,
    last_is_close: false,
    move_to_required: true,
    last_move_to_index: 0,
  }
}

///|
fn BoundsPen::push_verb(self : BoundsPen, is_move : Bool) -> Unit {
  self.verbs += 1
  self.last_is_move = is_move
  self.last_is_close = false
}

///|
fn BoundsPen::inject_move_to_if_needed(self : BoundsPen) -> Unit {
  if self.move_to_required {
    let i = self.last_move_to_index
    if i < self.xs.length() {
      @read_fonts.OutlinePen::move_to(self, self.xs[i], self.ys[i])
    } else {
      @read_fonts.OutlinePen::move_to(self, 0.0, 0.0)
    }
  }
}

///|
fn BoundsPen::push_point(self : BoundsPen, x : Float, y : Float) -> Unit {
  self.xs.push(x)
  self.ys.push(y)
}

///|
impl @read_fonts.OutlinePen for BoundsPen with fn move_to(self, x, y) {
  if self.last_is_move {
    self.xs[self.xs.length() - 1] = x
    self.ys[self.ys.length() - 1] = y
  } else {
    self.last_move_to_index = self.xs.length()
    self.move_to_required = false
    self.push_verb(true)
    self.push_point(x, y)
  }
}

///|
impl @read_fonts.OutlinePen for BoundsPen with fn line_to(self, x, y) {
  self.inject_move_to_if_needed()
  self.push_verb(false)
  self.push_point(x, y)
}

///|
impl @read_fonts.OutlinePen for BoundsPen with fn quad_to(self, x1, y1, x, y) {
  self.inject_move_to_if_needed()
  self.push_verb(false)
  self.push_point(x1, y1)
  self.push_point(x, y)
}

///|
impl @read_fonts.OutlinePen for BoundsPen with fn curve_to(
  self,
  x1,
  y1,
  x2,
  y2,
  x,
  y,
) {
  self.inject_move_to_if_needed()
  self.push_verb(false)
  self.push_point(x1, y1)
  self.push_point(x2, y2)
  self.push_point(x, y)
}

///|
impl @read_fonts.OutlinePen for BoundsPen with fn close(self) {
  // don't add a close if it's the first verb or a repeat
  if self.verbs > 0 && !self.last_is_close {
    self.verbs += 1
    self.last_is_move = false
    self.last_is_close = true
  }
  self.move_to_required = true
}

///|
/// The bounds `(left, top, right, bottom)` of the path (`PathBuilder::finish`
/// and `Path::bounds`): `None` for a path without segments or with
/// non-finite points.
fn BoundsPen::bounds(self : BoundsPen) -> (Float, Float, Float, Float)? {
  if self.verbs <= 1 || self.xs.length() == 0 {
    return None
  }
  let mut l = self.xs[0]
  let mut t = self.ys[0]
  let mut r = self.xs[0]
  let mut b = self.ys[0]
  for i in 0..<self.xs.length() {
    let x = self.xs[i]
    let y = self.ys[i]
    if x.is_nan() || x.is_inf() || y.is_nan() || y.is_inf() {
      return None
    }
    if x < l {
      l = x
    }
    if x > r {
      r = x
    }
    if y < t {
      t = y
    }
    if y > b {
      b = y
    }
  }
  Some((l, t, r, b))
}

///|
/// Subset the font like krilla's `subset_font` and compute the bounding box
/// of all glyphs of the subset: the subset data, its number of glyphs and
/// the bbox `(left, top, right, bottom)` in font units.
fn subset_font(
  font : Font,
  glyph_remapper : @subsetter.GlyphRemapper,
) -> (Bytes, Int, (Float, Float, Float, Float)) raise ExportError {
  let data = @subsetter.subset_with_variations(
    font.data,
    font.index,
    font.variation_coordinates(),
    glyph_remapper,
  ) catch {
    e => raise FontError(font, "failed to subset font: \{e}")
  }
  // `Font::new(subset, 0)`
  guard Font::new(data, 0) is Some(subset) else {
    raise FontError(font, "failed to subset font")
  }
  let font_ref = @read_fonts.FontRef::from_index(data, 0) catch {
    _ => raise FontError(font, "failed to subset font")
  }
  let global_bbox = {
    let (x0, y0, x1, y1) = subset.bbox
    let (x0, y0, x1, y1) = (
      Float::from_double(x0),
      Float::from_double(y0),
      Float::from_double(x1),
      Float::from_double(y1),
    )
    if x0 <= x1 && y0 <= y1 {
      (x0, y0, x1, y1)
    } else {
      let upem = Float::from_double(subset.units_per_em)
      (0.0, 0.0, upem, upem)
    }
  }
  let outlines = @skrifa.OutlineGlyphCollection::new(font_ref)
  let mut bbox : (Float, Float, Float, Float)? = None
  for g in 0..<subset.num_glyphs {
    guard outlines.get(@font_types.GlyphId::from_int(g)) is Some(outline) else {
      continue
    }
    let pen = BoundsPen::new()
    // (Errors are ignored: the points drawn so far count.)
    (outline.draw_unscaled([], pen) |> ignore) catch {
      _ => ()
    }
    if pen.bounds() is Some((l, t, r, b)) {
      bbox = Some(
        match bbox {
          Some((pl, pt, pr, pb)) =>
            (
              if l < pl {
                l
              } else {
                pl
              },
              if t < pt {
                t
              } else {
                pt
              },
              if r > pr {
                r
              } else {
                pr
              },
              if b > pb {
                b
              } else {
                pb
              },
            )
          None => (l, t, r, b)
        },
      )
    }
  }
  (data, subset.num_glyphs, bbox.unwrap_or(global_bbox))
}

///|
/// Serialize a CID font as a `Type0` font at `root_ref`.
fn CIDFont::serialize(
  self : CIDFont,
  sc : SerializeContext,
  root_ref : Int,
) -> Unit raise ExportError {
  let font = self.font
  let cid_ref = sc.new_ref()
  let descriptor_ref = sc.new_ref()
  let cmap_ref = sc.new_ref()
  let cid_set_ref = sc.new_ref()
  let data_ref = sc.new_ref()
  let glyph_remapper = self.glyph_remapper
  // (Like krilla: a font with a readable CFF table is embedded as a CFF
  // font even if the subsetter chose its glyf outlines.)
  let is_cff = font.has_cff
  if font.kind == NoOutlines {
    raise FontError(font, "font is missing an outline table")
  }
  // OS/2 fsType has a few bits that describe which kind of license the font
  // has. Of particular interest is bit 2 "Restricted License embedding". The
  // OpenType spec was adjusted to require mutual exclusion of the bits:
  // "For Restricted License embedding to take effect, the Embedding
  // permissions sub-field must have the value 2 (that is, only bit 1 is
  // set)." Hence `fsType & 0xF == 2`.
  if (font.fs_type & 0xF) == 2 {
    sc.register_validation_error(RestrictedLicense(font))
  }
  let (subsetted_data, num_glyphs, global_bbox) = subset_font(
    font, glyph_remapper,
  )
  let font_stream = {
    // If we have a CFF font, only embed the standalone CFF program.
    let subsetted_ref = @read_fonts.FontRef::new(subsetted_data) catch {
      _ => raise FontError(font, "failed to read font subset")
    }
    match subsetted_ref.data_for_tag("CFF ") {
      Some(cff) => cff.as_bytes().to_owned()
      None => subsetted_data
    }
  }
  let base_font = base_font_name(font, glyph_remapper)
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
  // In CID fonts, a upem value of 1000 is assumed for all fonts, so we need
  // to convert (in `f32`, like krilla).
  let upem = Float::from_double(font.units_per_em)
  let to_pdf_units = (v : Float) => {
    v / upem * Float::from_double(pdf_units_per_em)
  }
  let widths : Array[Obj] = []
  let mut first = 0
  while first < self.widths.length() {
    let w = self.widths[first]
    let mut end = first + 1
    while end < self.widths.length() && self.widths[end] == w {
      end += 1
    }
    if w != 0.0 {
      let last = end - 1
      widths.push(Int(first & 0xFFFF))
      widths.push(Int(last & 0xFFFF))
      widths.push(Real(to_pdf_units(w).to_double()))
    }
    first = end
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
  // The only reason we write this in the first place is that PDF/A-1b
  // requires a CIDSet.
  let write_cid_set = sc.settings.pdf_version() < Pdf20
  if write_cid_set {
    // It's always guaranteed by the subsetter that CIDs start from 0 and
    // are consecutive, so this encoding is very straight-forward.
    let bytes = Array::make(num_glyphs / 8, b'\xFF')
    let padding = num_glyphs % 8
    if padding != 0 {
      bytes.push((0xFF ^ (0xFF >> padding)).to_byte())
    }
    sc.put_stream(cid_set_ref, [], Bytes::from_array(bytes))
  }
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
  let (l, t, r, b) = global_bbox
  let (l, t, r, b) = (
    to_pdf_units(l),
    to_pdf_units(t),
    to_pdf_units(r),
    to_pdf_units(b),
  )
  // `Rect::to_pdf_rect`: `right` and `bottom` are recomputed from the width
  // and height.
  let font_bbox = Arr([
    Real(l.to_double()),
    Real(t.to_double()),
    Real((l + (r - l)).to_double()),
    Real((t + (b - t)).to_double()),
  ])
  let italic_angle = font.italic_angle
  let ascender = to_pdf_units(Float::from_double(font.ascent))
  let descender = to_pdf_units(Float::from_double(font.descent))
  let cap_height = match font.cap_height {
    Some(c) => to_pdf_units(Float::from_double(c))
    None => ascender
  }
  let stem_v = Float::from_double(10.0) +
    Float::from_double(0.244) *
    (Float::from_double(font.weight) - Float::from_double(50.0))
  let descriptor = DictBuilder::new()
  descriptor.set("Type", Name("FontDescriptor"))
  descriptor.set("FontName", Name(base_font))
  descriptor.set("Flags", Int(flags))
  descriptor.set("FontBBox", font_bbox)
  descriptor.set("ItalicAngle", Real(italic_angle))
  descriptor.set("Ascent", Real(ascender.to_double()))
  descriptor.set("Descent", Real(descender.to_double()))
  descriptor.set("CapHeight", Real(cap_height.to_double()))
  descriptor.set("StemV", Real(stem_v.to_double()))
  if write_cid_set {
    descriptor.set("CIDSet", Ref(cid_set_ref))
  }
  descriptor.set(if is_cff { "FontFile3" } else { "FontFile2" }, Ref(data_ref))
  sc.put(descriptor_ref, descriptor.finish())
  // The ToUnicode CMap. For the .notdef glyph, it's fine if no mapping
  // exists, since it is included even if it was not referenced in the text.
  let entries = []
  for g in 1..<glyph_remapper.num_gids() {
    write_cmap_entry(sc, font, self.cmap_entries.get(g), g, entries)
  }
  sc.put_content_stream(
    cmap_ref,
    [("Type", Name("CMap")), ("WMode", Int(0))],
    to_unicode_cmap(entries),
  )
  // The font program.
  if is_cff {
    sc.put_stream(data_ref, [("Subtype", Name("CIDFontType0C"))], font_stream)
  } else {
    sc.put_stream(data_ref, [], font_stream)
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
