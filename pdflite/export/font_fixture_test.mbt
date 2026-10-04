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
/// A minimal CFF table with `n` glyphs (all `endchar`). A CID-keyed table
/// has the ROS operator and a charset mapping glyphs 1.. to CIDs 100..
fn cff_table(
  n : Int,
  cid_keyed : Bool,
  seac? : Int = -1,
  seac_in_subr? : Int = -1,
) -> Array[Int] {
  let int32 = (v : Int) => {
    [29, (v >> 24) & 0xFF, (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF]
  }
  let index = (items : Array[Array[Int]]) => {
    let out = FontBytes::new()
    out.u16(items.length())
    if items.length() > 0 {
      out.bytes([1]) // offSize
      let mut off = 1
      out.bytes([off])
      for item in items {
        off += item.length()
        out.bytes([off])
      }
      for item in items {
        out.bytes(item)
      }
    }
    out.out
  }
  let names = index([[0x58]])
  let strings = if cid_keyed {
    index([
      "Adobe".to_array().map(c => c.to_int()),
      "Identity".to_array().map(c => c.to_int()),
    ])
  } else {
    index([])
  }
  let charset = if cid_keyed { [1, 0, 100, n - 2] } else { [] }
  // A name-keyed font has a Private DICT (defaultWidthX 0, local Subrs at
  // offset 4) followed by one local subroutine (`return`).
  let private = if cid_keyed { [] } else { [139, 20, 143, 19] }
  // Subroutine 0 returns, subroutine 1 composes an accented glyph with
  // `seac` (0 0 65 66 endchar).
  let subrs = if cid_keyed {
    []
  } else {
    index([[11], [139, 139, 204, 205, 14]])
  }
  // The size of the Top DICT doesn't depend on the offsets (all int32).
  // A CID-keyed font also has an FDSelect (format 3, one range) and an
  // FDArray with one Font DICT whose Private DICT is empty.
  let dict_size = if cid_keyed { 9 + 12 + 14 } else { 6 + 11 }
  let top_size = 2 + 1 + 2 + dict_size
  let charset_at = 4 + names.length() + top_size + strings.length() + 2
  let fd_select = if cid_keyed { [3, 0, 1, 0, 0, 0, 0, n] } else { [] }
  let fd_select_at = charset_at + charset.length()
  let font_dict_size = 1 + 5 + 1
  let fd_array_size = if cid_keyed { 2 + 1 + 2 + font_dict_size } else { 0 }
  let fd_array_at = fd_select_at + fd_select.length()
  let private_at = fd_array_at + fd_array_size
  let charstrings_at = private_at + private.length() + subrs.length()
  let fd_array = if cid_keyed {
    let font_dict = [139]
    for b in int32(private_at) {
      font_dict.push(b)
    }
    font_dict.push(18)
    index([font_dict])
  } else {
    []
  }
  let dict = []
  if cid_keyed {
    // ROS: Adobe (SID 391), Identity (SID 392), supplement 0.
    for b in [28, 1, 135, 28, 1, 136, 139, 12, 30] {
      dict.push(b)
    }
    for b in int32(charset_at) {
      dict.push(b)
    }
    dict.push(15)
    for b in int32(fd_array_at) {
      dict.push(b)
    }
    dict.push(12)
    dict.push(36)
    for b in int32(fd_select_at) {
      dict.push(b)
    }
    dict.push(12)
    dict.push(37)
  }
  for b in int32(charstrings_at) {
    dict.push(b)
  }
  dict.push(17)
  if !cid_keyed {
    for b in int32(private.length()) {
      dict.push(b)
    }
    for b in int32(private_at) {
      dict.push(b)
    }
    dict.push(18)
  }
  let out = FontBytes::new()
  out.bytes([1, 0, 4, 1])
  out.bytes(names)
  out.bytes(index([dict]))
  out.bytes(strings)
  out.bytes(index([])) // Global Subrs
  out.bytes(charset)
  out.bytes(fd_select)
  out.bytes(fd_array)
  out.bytes(private)
  out.bytes(subrs)
  // Glyph `seac` uses `seac` directly, `seac_in_subr` calls subroutine 1
  // (biased index 1 - 107).
  out.bytes(
    index(
      Array::makei(n, g => {
        if g == seac {
          [139, 139, 204, 205, 14]
        } else if g == seac_in_subr {
          [33, 10]
        } else {
          [14]
        }
      }),
    ),
  )
  out.out
}

///|
/// A minimal CFF2 table: the boxes of the glyf font as charstrings (no
/// variation store).
fn cff2_table() -> Array[Int] {
  let num = (v : Int) => {
    if v >= -107 && v <= 107 {
      [v + 139]
    } else {
      [28, (v >> 8) & 0xFF, v & 0xFF]
    }
  }
  let box_cs = (x0 : Int, y0 : Int, x1 : Int, y1 : Int) => {
    let out = []
    for b in num(x0) + num(y0) + [21] {
      out.push(b) // rmoveto
    }
    for b in num(x1 - x0) + [6] + num(y1 - y0) + [7] + num(x0 - x1) + [6] {
      out.push(b) // hlineto, vlineto, hlineto
    }
    out
  }
  let charstrings = [
    box_cs(50, 0, 450, 700),
    box_cs(0, 0, 600, 700),
    box_cs(100, -100, 500, 700),
    box_cs(0, 0, 600, 900),
    [],
    box_cs(0, 0, 700, 700),
  ]
  // A CFF2 INDEX (32-bit count, 2-byte offsets).
  let index2 = (items : Array[Array[Int]]) => {
    let out = FontBytes::new()
    out.u32(items.length())
    if items.length() > 0 {
      out.bytes([2]) // offSize
      let mut off = 1
      out.u16(off)
      for item in items {
        off += item.length()
        out.u16(off)
      }
      for item in items {
        out.bytes(item)
      }
    }
    out.out
  }
  let int32 = (v : Int) => {
    [29, (v >> 24) & 0xFF, (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF]
  }
  // Top DICT: CharStrings and FDArray offsets (5-byte integers).
  let top_size = 6 + 7
  let global_subrs = index2([])
  let charstrings_at = 5 + top_size + global_subrs.length()
  let charstrings = index2(charstrings)
  let fd_array_at = charstrings_at + charstrings.length()
  // One Font DICT with an empty Private DICT (at the end of the table).
  let font_dict_size = 1 + 5 + 1
  let fd_array_size = 4 + 1 + 2 * 2 + font_dict_size
  let private_at = fd_array_at + fd_array_size
  let font_dict = [139] + int32(private_at) + [18]
  let top = int32(charstrings_at) + [17] + int32(fd_array_at) + [12, 36]
  let out = FontBytes::new()
  out.bytes([2, 0, 5])
  out.u16(top.length())
  out.bytes(top)
  out.bytes(global_subrs)
  out.bytes(charstrings)
  out.bytes(index2([font_dict]))
  out.out
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
    // The exporter embeds CFF fonts as a whole, only reading the charset of
    // CID-keyed fonts.
    "cff" => tables.push(("CFF ", cff_table(n, false)))
    // Glyph 1 uses `seac`, glyph 2 calls a subroutine using it.
    "cff-seac" =>
      tables.push(("CFF ", cff_table(n, false, seac=1, seac_in_subr=2)))
    "cid-cff" => tables.push(("CFF ", cff_table(n, true)))
    "cff2" => tables.push(("CFF2", cff2_table()))
    // A CFF table in a CFF2 font (not a valid CFF2 table).
    "bad-cff2" => tables.push(("CFF2", cff_table(n, true)))
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
  // Table records are sorted by tag (OpenType requires it, and the
  // subsetter looks tables up by binary search).
  tables.sort_by((a, b) => a.0.compare(b.0))
  let out = FontBytes::new()
  out.u32(if outlines is ("glyf" | "none") { 0x00010000 } else { 0x4F54544F })
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
      #|  800,
      #|  -200,
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

///|
/// Patch big-endian bytes of font data.
fn patch(data : Bytes, at : Int, bytes : Array[Int]) -> Bytes {
  let arr = data.to_array()
  for i, b in bytes {
    arr[at + i] = b.to_byte()
  }
  Bytes::from_array(arr)
}

///|
/// The offset of a table record of the synthetic font.
fn table_record(data : Bytes, tag : String) -> Int {
  let n = (data[4].to_int() << 8) | data[5].to_int()
  for i in 0..<n {
    let rec = 12 + 16 * i
    let mut t = ""
    for k in 0..<4 {
      t = t + data[rec + k].to_int().unsafe_to_char().to_string()
    }
    if t == tag {
      return rec
    }
  }
  abort("no table \{tag}")
}

///|
test "Font::new rejects fonts with out-of-bounds or invalid structures" {
  let data = test_font_data()
  let head = table_record(data, "head")
  let glyf = table_record(data, "glyf")
  let rejected = (d : Bytes) => @export.Font::new(d, 0) is None
  let cases = [
    // A table offset with the high bit set (negative as a signed value).
    patch(data, glyf + 8, [0x80, 0, 0, 0]),
    // A table length reaching past the end.
    patch(data, glyf + 12, [0x7F, 0xFF, 0xFF, 0xFF]),
    // More tables than fit into the file.
    patch(data, 4, [0xFF, 0xFF]),
    // A head table that is too short.
    patch(data, head + 12, [0, 0, 0, 20]),
    // Zero units per em.
    patch(
      data,
      (
        (data[head + 8].to_int() << 24) |
        (data[head + 9].to_int() << 16) |
        (data[head + 10].to_int() << 8) |
        data[head + 11].to_int()
      ) +
      18,
      [0, 0],
    ),
    // Truncated data.
    data[0:40].to_owned(),
  ]
  debug_inspect(
    cases.map(rejected),
    content=(
      #|[true, true, true, true, true, true]
    ),
  )
  // Collections: a negative face index, an index past the count, and a face
  // offset past the end.
  let ttc = (offset : Int) => {
    let b = FontBytes::new()
    b.bytes([0x74, 0x74, 0x63, 0x66])
    b.u32(0x00010000)
    b.u32(1)
    b.u32(offset)
    Bytes::from_array(b.out.map(x => x.to_byte()))
  }
  debug_inspect(
    [
      @export.Font::new(ttc(16), -1) is None,
      @export.Font::new(ttc(16), 1) is None,
      @export.Font::new(ttc(0x7FFFFFF0), 0) is None,
      @export.Font::new(ttc(-16), 0) is None,
    ],
    content=(
      #|[true, true, true, true]
    ),
  )
}

///|
test "glyphs with broken outlines make subsetting fail" {
  // A loca entry pointing before the glyf table makes the subsetter fail
  // (like the Rust crate) instead of panicking.
  let data = test_font_data()
  let loca = table_record(data, "loca")
  let loca_at = (data[loca + 8].to_int() << 24) |
    (data[loca + 9].to_int() << 16) |
    (data[loca + 10].to_int() << 8) |
    data[loca + 11].to_int()
  let font = @export.Font::new(
    patch(data, loca_at + 4, [0xFF, 0xFF, 0xFF, 0xF0]),
    0,
  ).unwrap()
  inspect(
    export_result(() => {
      one_page(s => {
        s.draw_glyphs(
          @export.Point::from_xy(0.0, 10.0),
          [glyph(1, 0, 1), glyph(2, 1, 2)],
          font,
          "AB",
          10.0,
        )
      })
    }),
    content="FontError: failed to subset font: malformed font",
  )
}

///|
test "collection indices that overflow the directory size are rejected" {
  let b = FontBytes::new()
  b.bytes([0x74, 0x74, 0x63, 0x66])
  b.u32(0x00010000)
  b.u32(0x7FFFFFFF)
  let data = Bytes::from_array(b.out.map(x => x.to_byte()))
  inspect(@export.Font::new(data, 536870908) is None, content="true")
  inspect(@export.Font::new(data, 0x7FFFFFFE) is None, content="true")
}

///|
test "advance widths come from skrifa's glyph metrics" {
  let data = test_font_data()
  let hmtx = table_record(data, "hmtx")
  let offset = (data[hmtx + 8].to_int() << 24) |
    (data[hmtx + 9].to_int() << 16) |
    (data[hmtx + 10].to_int() << 8) |
    data[hmtx + 11].to_int()
  // An advance of 40000 units (wraps in skrifa's 26.6 fixed point scaling).
  let font = @export.Font::new(patch(data, offset + 4, [0x9C, 0x40]), 0).unwrap()
  debug_inspect(
    [0, 1, 2].map(g => font.advance_width(g)),
    content=(
      #|[Some(500), Some(-25536), Some(550)]
    ),
  )
  // An `hmtx` table too short for its `hMetrics` array: read-fonts reads
  // the array as empty.
  let font = @export.Font::new(patch(data, hmtx + 12, [0, 0, 0, 8]), 0).unwrap()
  debug_inspect(
    [0, 1, 5, 6].map(g => font.advance_width(g)),
    content=(
      #|[Some(0), Some(0), Some(0), None]
    ),
  )
}
