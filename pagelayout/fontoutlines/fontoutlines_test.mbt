///|
// Every expectation here is a fact about the *source* font, read out of
// NotoSansSC-VF.ttf with fonttools — not a value this package produced.
// A bundle that decoded to something self-consistent but wrong would
// still have to disagree with these.

///|
fn read_u16(data : Bytes, offset : Int) -> Int {
  (data[offset].to_int() << 8) | data[offset + 1].to_int()
}

///|
test "the bundled program carries outlines, not just metrics" {
  guard @fontoutlines.outline_sfnt("Noto Sans SC") is Some(sfnt) else {
    fail("Noto Sans SC has no bundled outlines")
  }
  // sfnt version 0x00010000: TrueType outlines
  inspect(read_u16(sfnt, 0), content="1")
  inspect(read_u16(sfnt, 2), content="0")
  // the metrics bundle stops at `post`; a program a PDF can embed has to
  // carry the glyph descriptions and the index that finds them
  inspect(@pdflite.pdf_truetype_table(sfnt, "glyf") is Some(_), content="true")
  inspect(@pdflite.pdf_truetype_table(sfnt, "loca") is Some(_), content="true")
  inspect(sfnt.length(), content="10416220")
}

///|
test "the bundled program is the regular weight, not the thin default" {
  // NotoSansSC-VF's fvar default is wght=100, so the default master's
  // outlines are Thin. The generator instances at 400; if that step were
  // dropped the text would render visibly hairline.
  guard @fontoutlines.outline_sfnt("Noto Sans SC") is Some(sfnt) else {
    fail("Noto Sans SC has no bundled outlines")
  }
  guard @pdflite.pdf_truetype_table(sfnt, "OS/2") is Some(os2) else {
    fail("bundled program lacks an OS/2 table")
  }
  // usWeightClass follows version and xAvgCharWidth
  inspect(read_u16(sfnt, os2.offset + 4), content="400")
}

///|
test "glyph ids match the source font" {
  // Identity-H uses the glyph index as the CID, so an off-by-anything here
  // renders the wrong characters rather than failing loudly. fonttools
  // reports these ids for the instanced font.
  guard @fontoutlines.outline_sfnt("Noto Sans SC") is Some(sfnt) else {
    fail("Noto Sans SC has no bundled outlines")
  }
  let cmap : Map[Int, Int] = Map([])
  for entry in @pdflite.pdf_truetype_cmap_glyphs(sfnt) {
    cmap[entry.codepoint] = entry.glyph_index
  }
  debug_inspect(cmap.get(0x4E2D), content="Some(8805)") // 中
  debug_inspect(cmap.get(0x6587), content="Some(14750)") // 文
  debug_inspect(cmap.get(0x0041), content="Some(34)") // A
  debug_inspect(cmap.get(0x3002), content="Some(1142)") // 。
}

///|
test "outline lookup falls back within a family but never across" {
  // Noto Sans SC bundles a regular face only; a bold request has to get
  // the program the metrics were measured from, not nothing.
  inspect(
    @fontoutlines.outline_sfnt("Noto Sans SC", bold=true) is Some(_),
    content="true",
  )
  // a family with no bundled program embeds nothing rather than something
  // wrong under the right name
  inspect(@fontoutlines.outline_sfnt("Carlito") is None, content="true")
  debug_inspect(
    @fontoutlines.outlined_families(),
    content=(
      #|["Noto Sans SC"]
    ),
  )
}
