// Type 3 fonts for color glyphs (port of krilla's `text::type3`), and the
// container of all PDF fonts of an OpenType font (krilla `FontContainer`).
//
// Color glyphs (COLR, SVG, bitmap) cannot be embedded in CID fonts. They
// are drawn by a user-provided [ColorGlyphs] hook into the glyph
// procedures of Type 3 fonts (at most 256 glyphs per font).

///|
/// A hook for drawing color glyphs.
pub(all) struct ColorGlyphs {
  /// Whether the glyph must be drawn as a color glyph (krilla
  /// `!should_outline`).
  is_color : (Int) -> Bool
  /// Draw the glyph in font units (y-up) onto the surface, given the
  /// context color (`0xRRGGBB`); returns whether something was drawn.
  draw : (Int, Int, Surface) -> Bool
}

///|
/// Set the color glyph hook of a font.
pub fn Font::set_color_glyphs(self : Font, hook : ColorGlyphs) -> Unit {
  self.color = Some(hook)
}

///|
/// A Type 3 font.
priv struct Type3Font {
  font : Font
  /// The glyphs (glyph ID and context color) in code order.
  glyphs : Array[(Int, Int)]
  widths : Array[Double]
  cmap_entries : Map[Int, (String, Location?)]
  /// The reference of the font dictionary.
  ref_ : Int
}

///|
fn Type3Font::get_code(self : Type3Font, glyph : (Int, Int)) -> Int? {
  for i, g in self.glyphs {
    if g == glyph {
      return Some(i)
    }
  }
  None
}

///|
/// All PDF fonts belonging to an OpenType font.
priv struct FontContainer {
  font : Font
  cid_font : CIDFont
  /// The reference of the `Type0` font.
  ref_ : Int
  type3 : Array[Type3Font]
  /// The Type 3 font and code of each colored glyph.
  type3_cache : Map[(Int, Int), (Int, Int)]
}

///|
fn FontContainer::new(font : Font, ref_ : Int) -> FontContainer {
  { font, cid_font: CIDFont::new(font), ref_, type3: [], type3_cache: {}, }
}

///|
/// Whether a glyph is drawn as an outline (in the CID font).
fn FontContainer::should_outline(self : FontContainer, glyph : Int) -> Bool {
  match self.font.color {
    Some(hook) => !(hook.is_color)(glyph)
    None => self.font.kind != NoOutlines
  }
}

///|
/// Add a glyph; returns the PDF font (`-1` for the CID font, else the
/// index of the Type 3 font) and the code of the glyph.
fn FontContainer::add_glyph(
  self : FontContainer,
  sc : SerializeContext,
  glyph : Int,
  context_color : Int,
) -> (Int, Int) {
  if self.should_outline(glyph) {
    return (-1, self.cid_font.add_glyph(glyph))
  }
  let key = (glyph, context_color)
  if self.type3_cache.get(key) is Some(r) {
    return r
  }
  let needs_new = match self.type3.last() {
    Some(t) => t.glyphs.length() >= 256
    None => true
  }
  if needs_new {
    self.type3.push({
      font: self.font,
      glyphs: [],
      widths: [],
      cmap_entries: {},
      ref_: sc.new_ref(),
    })
  }
  let index = self.type3.length() - 1
  let t3 = self.type3[index]
  let code = t3.glyphs.length()
  t3.glyphs.push(key)
  t3.widths.push(self.font.advance_width(glyph).unwrap_or(0.0))
  self.type3_cache[key] = (index, code)
  (index, code)
}

///|
fn FontContainer::get_codepoints(
  self : FontContainer,
  fid : Int,
  code : Int,
) -> String? {
  if fid < 0 {
    self.cid_font.get_codepoints(code)
  } else {
    match self.type3[fid].cmap_entries.get(code) {
      Some((s, _)) => Some(s)
      None => None
    }
  }
}

///|
fn FontContainer::set_codepoints(
  self : FontContainer,
  fid : Int,
  code : Int,
  text : String,
  location : Location?,
) -> Unit {
  if fid < 0 {
    self.cid_font.set_codepoints(code, text, location)
  } else {
    self.type3[fid].cmap_entries[code] = (text, location)
  }
}

///|
/// The reference of a PDF font.
fn FontContainer::font_ref(self : FontContainer, fid : Int) -> Int {
  if fid < 0 {
    self.ref_
  } else {
    self.type3[fid].ref_
  }
}

///|
/// The units per em of a PDF font (1000 for CID fonts).
fn FontContainer::units_per_em(self : FontContainer, fid : Int) -> Double {
  if fid < 0 {
    pdf_units_per_em
  } else {
    self.font.units_per_em
  }
}

///|
/// Encode a code of a PDF font.
fn encode_code(fid : Int, code : Int) -> Bytes {
  if fid < 0 {
    encode_cid(code)
  } else {
    Bytes::from_array([(code & 0xFF).to_byte()])
  }
}

///|
/// Serialize a Type 3 font.
fn Type3Font::serialize(self : Type3Font, sc : SerializeContext) -> Unit {
  let rd = ResourceDictionary::new()
  let font = self.font
  let mut font_bbox = Rect::{ left: 0.0, top: 0.0, right: 1.0, bottom: 1.0, }
  let char_procs = []
  for index, glyph in self.glyphs {
    let (gid, color) = glyph
    let builder = ContentBuilder::new(Transform::identity(), true)
    let surface = Surface::{
      sc,
      fill: None,
      stroke: None,
      root_builder: builder,
      sub_builders: [],
      push_instructions: [],
      mcid: None,
      kind: StreamSurface,
    }
    if font.color is Some(hook) {
      (hook.draw)(gid, color, surface) |> ignore
    }
    let stream = surface.finish_stream()
    let content = Content::new()
    content.num(self.widths[index])
    content.num(0.0)
    content.op("d0")
    if !stream.is_empty() {
      let x_object = XObject::new(stream, false, false, None)
      font_bbox = font_bbox.union(x_object.bbox())
      let r = sc.register_xobject(x_object)
      let name = rd.register(XObject, r)
      content.name(name)
      content.op("Do")
    }
    let proc_ref = sc.new_ref()
    sc.put_content_stream(proc_ref, [], content.finish())
    char_procs.push(("g\{index}", Ref(proc_ref)))
  }
  let base_font = match font.postscript_name {
    Some(n) => n
    None => "unknown"
  }
  let descriptor_ref = if sc.settings.pdf_version() >= Pdf15 {
    Some(sc.new_ref())
  } else {
    None
  }
  let cmap_ref = sc.new_ref()
  if descriptor_ref is Some(r) {
    let mut flags = 0
    if base_font.contains("Serif") {
      flags = flags | 2
    }
    if font.is_monospaced {
      flags = flags | 1
    }
    if font.italic_angle != 0.0 {
      flags = flags | 64
    }
    flags = flags | 4 | (1 << 17)
    let w = font.weight.to_int()
    let weight = if w >= 150 && w < 250 {
      200
    } else if w >= 250 && w < 350 {
      300
    } else if w >= 350 && w < 450 {
      400
    } else if w >= 450 && w < 550 {
      500
    } else if w >= 550 && w < 650 {
      600
    } else if w >= 650 && w < 750 {
      700
    } else if w >= 750 && w < 850 {
      800
    } else if w < 150 {
      100
    } else {
      900
    }
    sc.put(
      r,
      Dict([
        ("Type", Name("FontDescriptor")),
        ("FontName", Name(base_font)),
        ("Flags", Int(flags)),
        ("FontBBox", font_bbox.to_pdf()),
        ("ItalicAngle", Real(font.italic_angle)),
        ("Ascent", Real(font_bbox.bottom)),
        ("Descent", Real(font_bbox.top)),
        ("FontFamily", Str(utf8_bytes(base_font))),
        ("FontStretch", Name("Normal")),
        ("FontWeight", Int(weight)),
      ]),
    )
  }
  let d = DictBuilder::new()
  d.set("Type", Name("Font"))
  d.set("Subtype", Name("Type3"))
  d.set("Resources", rd.to_pdf())
  d.set("Name", Name(base_font))
  d.set("FontBBox", font_bbox.to_pdf())
  d.set("ToUnicode", Ref(cmap_ref))
  let s = 1.0 / font.units_per_em
  d.set("FontMatrix", Transform::from_scale(s, s).to_pdf())
  d.set("FirstChar", Int(0))
  d.set("LastChar", Int(self.glyphs.length() - 1))
  d.set("Widths", Arr(self.widths.map(w => Real(w))))
  if descriptor_ref is Some(r) {
    d.set("FontDescriptor", Ref(r))
  }
  d.set("CharProcs", Dict(char_procs))
  let differences : Array[Obj] = [Int(0)]
  for i in 0..<self.glyphs.length() {
    differences.push(Name("g\{i}"))
  }
  d.set(
    "Encoding",
    Dict([("Type", Name("Encoding")), ("Differences", Arr(differences))]),
  )
  sc.put(self.ref_, d.finish())
  let entries = []
  for g in 0..<self.glyphs.length() {
    write_cmap_entry(sc, font, self.cmap_entries.get(g), g, entries)
  }
  sc.put_content_stream(cmap_ref, [], to_unicode_cmap(entries, one_byte=true))
}
