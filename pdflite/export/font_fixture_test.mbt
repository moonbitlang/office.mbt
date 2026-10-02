// A tiny synthetic TrueType font for the text tests (the repository doesn't
// ship font files). Glyphs (1000 units per em):
//
// - 0 `.notdef`: a box, advance 500
// - 1 `A`: a box, advance 600
// - 2 `B`: a box reaching below the baseline, advance 550
// - 3 `Ä`: a composite glyph referencing glyph 1, advance 600
// - 4 space: no outline, advance 250
// - 5 an unused box, advance 700

///|
priv struct FontBytes {
  out : Array[Int]
}

///|
fn FontBytes::new() -> FontBytes {
  { out: [], }
}

///|
fn FontBytes::u16(self : FontBytes, v : Int) -> Unit {
  self.out.push((v >> 8) & 0xFF)
  self.out.push(v & 0xFF)
}

///|
fn FontBytes::u32(self : FontBytes, v : Int) -> Unit {
  self.u16((v >> 16) & 0xFFFF)
  self.u16(v & 0xFFFF)
}

///|
fn FontBytes::bytes(self : FontBytes, v : ArrayView[Int]) -> Unit {
  for b in v {
    self.out.push(b)
  }
}

///|
fn FontBytes::pad(self : FontBytes, len : Int) -> Unit {
  while self.out.length() < len {
    self.out.push(0)
  }
}

///|
fn FontBytes::align4(self : FontBytes) -> Unit {
  while self.out.length() % 4 != 0 {
    self.out.push(0)
  }
}

///|
/// A simple glyph: one rectangular contour.
fn box_glyph(x0 : Int, y0 : Int, x1 : Int, y1 : Int) -> Array[Int] {
  let g = FontBytes::new()
  g.u16(1) // numberOfContours
  g.u16(x0)
  g.u16(y0)
  g.u16(x1)
  g.u16(y1)
  g.u16(3) // endPtsOfContours
  g.u16(0) // instructionLength
  g.bytes([1, 1, 1, 1]) // flags: on curve, 16-bit deltas
  for dx in [x0, x1 - x0, 0, x0 - x1] {
    g.u16(dx)
  }
  for dy in [y0, 0, y1 - y0, 0] {
    g.u16(dy)
  }
  g.out
}

///|
/// A composite glyph referencing `component`.
fn composite_glyph(component : Int) -> Array[Int] {
  let g = FontBytes::new()
  g.u16(-1) // numberOfContours
  g.u16(0)
  g.u16(0)
  g.u16(600)
  g.u16(900)
  g.u16(0x0003) // ARG_1_AND_2_ARE_WORDS | ARGS_ARE_XY_VALUES
  g.u16(component)
  g.u16(0)
  g.u16(200)
  g.out
}

///|
fn test_font_tables(
  fs_type : Int,
  ps_name : String,
  outlines : String,
  italic : Bool,
  monospaced : Bool,
) -> Array[(String, Array[Int])] {
  let advances = [500, 600, 550, 600, 250, 700]
  let n = advances.length()
  let head = FontBytes::new()
  head.u32(0x00010000) // version
  head.u32(0x00010000) // fontRevision
  head.u32(0) // checksumAdjustment
  head.u32(0x5F0F3CF5) // magicNumber
  head.u16(0) // flags
  head.u16(1000) // unitsPerEm
  head.pad(36)
  head.u16(-50) // xMin
  head.u16(-200) // yMin
  head.u16(800) // xMax
  head.u16(900) // yMax
  head.pad(50)
  head.u16(1) // indexToLocFormat: long
  head.u16(0)
  let maxp = FontBytes::new()
  maxp.u32(0x00005000)
  maxp.u16(n)
  let hhea = FontBytes::new()
  hhea.u32(0x00010000)
  hhea.u16(900) // ascender
  hhea.u16(-250) // descender
  hhea.pad(34)
  hhea.u16(n) // numberOfHMetrics
  let hmtx = FontBytes::new()
  for a in advances {
    hmtx.u16(a)
    hmtx.u16(0)
  }
  let os2 = FontBytes::new()
  os2.u16(2) // version
  os2.u16(500) // xAvgCharWidth
  os2.u16(700) // usWeightClass
  os2.u16(5) // usWidthClass
  os2.u16(fs_type)
  os2.pad(62)
  os2.u16(0) // fsSelection
  os2.u16(0x20)
  os2.u16(0x41)
  os2.u16(800) // sTypoAscender
  os2.u16(-200) // sTypoDescender
  os2.pad(88)
  os2.u16(680) // sCapHeight
  os2.pad(96)
  let post = FontBytes::new()
  post.u32(0x00030000)
  post.u32(if italic { -12 * 65536 } else { 0 }) // italicAngle
  post.u16(-100)
  post.u16(50)
  post.u32(if monospaced { 1 } else { 0 })
  post.pad(32)
  let name = FontBytes::new()
  name.u16(0) // format
  name.u16(1) // count
  name.u16(18) // stringOffset
  name.bytes([0, 3, 0, 1, 0x04, 0x09, 0, 6]) // Windows, Unicode BMP, en-US, ID 6
  name.u16(2 * ps_name.length())
  name.u16(0)
  for c in ps_name {
    name.u16(c.to_int())
  }
  let tables = [
    ("OS/2", os2.out),
    ("head", head.out),
    ("hhea", hhea.out),
    ("hmtx", hmtx.out),
    ("maxp", maxp.out),
    ("name", name.out),
    ("post", post.out),
  ]
  match outlines {
    "glyf" => {
      let glyphs = [
        box_glyph(50, 0, 450, 700),
        box_glyph(0, 0, 600, 700),
        box_glyph(100, -100, 500, 700),
        composite_glyph(1),
        [],
        box_glyph(0, 0, 700, 700),
      ]
      let glyf = FontBytes::new()
      let loca = FontBytes::new()
      for g in glyphs {
        loca.u32(glyf.out.length())
        glyf.bytes(g)
        glyf.align4()
      }
      loca.u32(glyf.out.length())
      tables.push(("glyf", glyf.out))
      tables.push(("loca", loca.out))
    }
    // The exporter embeds CFF fonts as a whole without parsing them.
    "cff" => tables.push(("CFF ", [1, 0, 4, 1]))
    _ => ()
  }
  tables
}

///|
/// The bytes of the synthetic font.
fn test_font_data(
  fs_type? : Int = 0,
  ps_name? : String = "TestSans-Bold",
  outlines? : String = "glyf",
  italic? : Bool = false,
  monospaced? : Bool = false,
) -> Bytes {
  let tables = test_font_tables(fs_type, ps_name, outlines, italic, monospaced)
  let out = FontBytes::new()
  out.u32(if outlines == "cff" { 0x4F54544F } else { 0x00010000 })
  out.u16(tables.length())
  out.u16(0)
  out.u16(0)
  out.u16(0)
  let mut offset = 12 + 16 * tables.length()
  for t in tables {
    for c in t.0 {
      out.out.push(c.to_int())
    }
    out.u32(0) // checksum (not checked)
    out.u32(offset)
    out.u32(t.1.length())
    offset += (t.1.length() + 3) / 4 * 4
  }
  for t in tables {
    out.bytes(t.1)
    out.align4()
  }
  Bytes::from_array(out.out.map(b => b.to_byte()))
}

///|
fn test_font(
  fs_type? : Int = 0,
  ps_name? : String = "TestSans-Bold",
  outlines? : String = "glyf",
  italic? : Bool = false,
  monospaced? : Bool = false,
) -> @export.Font {
  @export.Font::new(
    test_font_data(fs_type~, ps_name~, outlines~, italic~, monospaced~),
    0,
    key="test",
  ).unwrap()
}

///|
/// A glyph with the font's advance (in em).
fn glyph(
  id : Int,
  start : Int,
  end : Int,
  x_advance? : Double,
  x_offset? : Double = 0.0,
  y_offset? : Double = 0.0,
) -> @export.Glyph {
  let advances : ReadOnlyArray[Double] = [0.5, 0.6, 0.55, 0.6, 0.25, 0.7]
  {
    glyph_id: id,
    text_start: start,
    text_end: end,
    x_advance: x_advance.unwrap_or(advances[id]),
    x_offset,
    y_advance: 0.0,
    y_offset,
    location: None,
  }
}

///|
test "the synthetic font parses" {
  let font = test_font()
  debug_inspect(
    (
      font.units_per_em,
      font.num_glyphs,
      font.ascent,
      font.descent,
      font.cap_height,
      font.italic_angle,
      font.weight,
      font.is_monospaced,
      font.postscript_name,
      font.bbox,
      font.fs_type,
      font.kind,
    ),
    content=(
      #|(
      #|  1000,
      #|  6,
      #|  900,
      #|  -250,
      #|  Some(680),
      #|  0,
      #|  700,
      #|  false,
      #|  Some("TestSans-Bold"),
      #|  (-50, -200, 800, 900),
      #|  0,
      #|  Glyf,
      #|)
    ),
  )
  debug_inspect(
    [0, 1, 2, 3, 4, 5, 6].map(g => font.advance_width(g)),
    content=(
      #|[
      #|  Some(500),
      #|  Some(600),
      #|  Some(550),
      #|  Some(600),
      #|  Some(250),
      #|  Some(700),
      #|  None,
      #|]
    ),
  )
  inspect(font.has_table("glyf"), content="true")
  inspect(font.has_table("CFF "), content="false")
  debug_inspect(
    test_font(outlines="cff").kind,
    content=(
      #|Cff
    ),
  )
  debug_inspect(
    test_font(outlines="none").kind,
    content=(
      #|NoOutlines
    ),
  )
  let f = test_font(italic=true, monospaced=true)
  debug_inspect(
    (f.italic_angle, f.is_monospaced),
    content=(
      #|(-12, true)
    ),
  )
}

///|
test "Font::new rejects malformed data" {
  inspect(@export.Font::new(b"", 0) is None, content="true")
  // Only collections have faces besides 0.
  inspect(@export.Font::new(test_font_data(), 1) is None, content="true")
  // A font without a head table.
  inspect(
    @export.Font::new(b"\x00\x01\x00\x00\x00\x00", 0) is None,
    content="true",
  )
}

///|
test "font collections" {
  // Wrap the font into a collection with one face (offsets are absolute, so
  // shift the table offsets by the size of the collection header).
  let face = test_font_data().to_array().map(b => b.to_int())
  let header = 16
  let num_tables = (face[4] << 8) | face[5]
  for i in 0..<num_tables {
    let at = 12 + 16 * i + 8
    let off = (face[at] << 24) |
      (face[at + 1] << 16) |
      (face[at + 2] << 8) |
      face[at + 3]
    let off = off + header
    face[at] = (off >> 24) & 0xFF
    face[at + 1] = (off >> 16) & 0xFF
    face[at + 2] = (off >> 8) & 0xFF
    face[at + 3] = off & 0xFF
  }
  let ttc = FontBytes::new()
  ttc.bytes([0x74, 0x74, 0x63, 0x66]) // ttcf
  ttc.u32(0x00010000)
  ttc.u32(1)
  ttc.u32(header)
  ttc.bytes(face)
  let data = Bytes::from_array(ttc.out.map(b => b.to_byte()))
  let font = @export.Font::new(data, 0).unwrap()
  debug_inspect(
    (font.num_glyphs, font.postscript_name),
    content=(
      #|(6, Some("TestSans-Bold"))
    ),
  )
  inspect(@export.Font::new(data, 1) is None, content="true")
}
