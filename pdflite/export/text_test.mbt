///|
/// Draw `glyphs` (of `text`) at (10, 50) in 10pt with the font.
fn text_page(
  font : @export.Font,
  glyphs : Array[@export.Glyph],
  text : String,
  settings? : @export.SerializeSettings = plain_settings(),
  before? : (@export.Surface) -> Unit = _ => (),
) -> Bytes raise {
  one_page(
    s => {
      before(s)
      s.draw_glyphs(
        @export.Point::from_xy(10.0, 50.0),
        glyphs,
        font,
        text,
        10.0,
      )
    },
    settings~,
  )
}

///|
/// The parsed `/Font` resource `f0` of the first page.
fn Parsed::font0(self : Parsed) -> @syntax.PdfObject raise {
  self.path(self.page(0), ["Resources", "Font", "f0"])
}

///|
/// The text of a ToUnicode CMap without its fixed header and trailer.
fn cmap_body(cmap : String) -> String {
  let start = match cmap.find("endcodespacerange\n") {
    Some(i) => i + "endcodespacerange\n".length()
    None => 0
  }
  let end = cmap.find("endcmap").unwrap_or(cmap.length())
  cmap.unsafe_substring(start~, end~)
}

///|
test "a glyph run embeds a Type0 font with a CIDFontType2 descendant" {
  let font = test_font()
  let p = parse(
    text_page(font, [glyph(1, 0, 1), glyph(2, 1, 2), glyph(1, 2, 3)], "ABA"),
  )
  inspect(
    p.content(p.page(0)),
    content=(
      #|q
      #|1 0 0 -1 0 100 cm
      #|0 0 0 rg
      #|BT
      #|0 Tr
      #|/f0 10 Tf
      #|1 0 0 -1 10 50 Tm
      #|[<000100020001>] TJ
      #|ET
      #|Q
      #|
    ),
  )
  let f0 = p.font0()
  inspect(
    p.show(f0),
    content=(
      #|<</Type /Font /Subtype /Type0 /BaseFont /BKEBSU+TestSans-Bold /Encoding /Identity-H /DescendantFonts [R] /ToUnicode R>>
    ),
  )
  let cid = p.items(p.get(f0, "DescendantFonts"))[0]
  inspect(
    p.show(cid),
    content=(
      #|<</Type /Font /Subtype /CIDFontType2 /BaseFont /BKEBSU+TestSans-Bold /CIDSystemInfo <</Registry (Adobe) /Ordering (Identity) /Supplement 0>> /FontDescriptor R /DW 0 /CIDToGIDMap /Identity /W [0 [500] 1 [600] 2 [550]]>>
    ),
  )
  inspect(
    p.show(p.get(cid, "FontDescriptor")),
    content=(
      #|<</Type /FontDescriptor /FontName /BKEBSU+TestSans-Bold /Flags 131076 /FontBBox [0 -100 600 700] /ItalicAngle 0 /Ascent 900 /Descent -250 /CapHeight 680 /StemV 168.6 /FontFile2 R>>
    ),
  )
  let cmap = latin1(p.stream_data(p.get(f0, "ToUnicode")))
  inspect(
    cmap_body(cmap),
    content=(
      #|2 beginbfchar
      #|<0001> <0041>
      #|<0002> <0042>
      #|endbfchar
      #|
    ),
  )
  inspect(cmap.has_prefix("%!PS-Adobe-3.0 Resource-CMap\n"), content="true")
}

///|
test "the embedded TrueType font is subset by glyph ID" {
  let font = test_font()
  // Glyph 3 is a composite of glyph 1: both are kept.
  let p = parse(text_page(font, [glyph(3, 0, 1), glyph(2, 1, 2)], "ÄB"))
  let f0 = p.font0()
  let cid = p.items(p.get(f0, "DescendantFonts"))[0]
  // Widths of all kept glyphs, including .notdef.
  inspect(
    p.show(p.get(cid, "W")),
    content=(
      #|[0 [500] 1 [600] 2 [550] 3 [600]]
    ),
  )
  let file = p.path(cid, ["FontDescriptor", "FontFile2"])
  let subset = @export.Font::new(p.stream_data(file), 0).unwrap()
  inspect(subset.num_glyphs, content="6")
  // Re-embedding the subset shows which glyphs still have outlines: the
  // bounding boxes of glyphs 4 (no outline) and 5 (dropped) are gone.
  let p2 = parse(
    text_page(subset, [0, 1, 2, 3, 4, 5].map(g => glyph(g, 0, 1)), "x"),
  )
  let cid2 = p2.items(p2.get(p2.font0(), "DescendantFonts"))[0]
  inspect(
    p2.show(p2.path(cid2, ["FontDescriptor", "FontBBox"])),
    content=(
      #|[0 -100 600 900]
    ),
  )
  // The subset keeps the tables needed for rendering, with a long loca.
  debug_inspect(
    ["OS/2", "glyf", "head", "hhea", "hmtx", "loca", "maxp", "name", "post"].map(t => {
        subset.has_table(t)
      },
    ),
    content=(
      #|[true, true, true, true, true, true, true, false, false]
    ),
  )
}

///|
test "advances that differ from the font are written as TJ adjustments" {
  let font = test_font()
  let p = parse(
    text_page(
      font,
      [
        glyph(1, 0, 1, x_advance=0.65),
        glyph(2, 1, 2, x_offset=0.1),
        glyph(1, 2, 3),
      ],
      "ABA",
    ),
  )
  inspect(
    p.content(p.page(0)),
    content=(
      #|q
      #|1 0 0 -1 0 100 cm
      #|0 0 0 rg
      #|BT
      #|0 Tr
      #|/f0 10 Tf
      #|1 0 0 -1 10 50 Tm
      #|[<0001> -150 <0002> 100 <0001>] TJ
      #|ET
      #|Q
      #|
    ),
  )
}

///|
test "glyphs with a different y offset are shown separately" {
  let font = test_font()
  let p = parse(
    text_page(font, [glyph(1, 0, 1), glyph(2, 1, 2, y_offset=0.2)], "AB"),
  )
  inspect(
    p.content(p.page(0)),
    content=(
      #|q
      #|1 0 0 -1 0 100 cm
      #|0 0 0 rg
      #|BT
      #|0 Tr
      #|/f0 10 Tf
      #|1 0 0 -1 10 50 Tm
      #|<0001> Tj
      #|0 Tr
      #|/f0 10 Tf
      #|1 0 0 -1 16 48 Tm
      #|<0002> Tj
      #|ET
      #|Q
      #|
    ),
  )
}

///|
test "glyph clusters and conflicting mappings use ActualText spans" {
  let font = test_font()
  // Two glyphs for one cluster ("ffi" ligature decomposition).
  let p = parse(
    text_page(font, [glyph(1, 0, 3), glyph(2, 0, 3), glyph(4, 3, 4)], "ffi "),
  )
  inspect(
    p.content(p.page(0)),
    content=(
      #|q
      #|1 0 0 -1 0 100 cm
      #|0 0 0 rg
      #|BT
      #|/Span <</ActualText (ffi)
      #|>> BDC
      #|0 Tr
      #|/f0 10 Tf
      #|1 0 0 -1 10 50 Tm
      #|[<00010002>] TJ
      #|EMC
      #|0 Tr
      #|/f0 10 Tf
      #|1 0 0 -1 21.5 50 Tm
      #|<0004> Tj
      #|ET
      #|Q
      #|
    ),
  )
  // The first glyph of the cluster maps to the whole cluster, the second one
  // has no mapping.
  let cmap = latin1(p.stream_data(p.get(p.font0(), "ToUnicode")))
  inspect(
    cmap_body(cmap),
    content=(
      #|2 beginbfchar
      #|<0001> <006600660069>
      #|<0004> <0020>
      #|endbfchar
      #|
    ),
  )
  // A glyph that is used for different text keeps its first mapping; later
  // uses get an ActualText.
  let p = parse(
    one_page(s => {
      s.draw_glyphs(
        @export.Point::from_xy(0.0, 20.0),
        [glyph(1, 0, 1)],
        font,
        "A",
        10.0,
      )
      s.draw_glyphs(
        @export.Point::from_xy(0.0, 40.0),
        [glyph(1, 0, 1)],
        font,
        "X",
        10.0,
      )
    }),
  )
  inspect(
    p.content(p.page(0)),
    content=(
      #|q
      #|1 0 0 -1 0 100 cm
      #|0 0 0 rg
      #|BT
      #|0 Tr
      #|/f0 10 Tf
      #|1 0 0 -1 0 20 Tm
      #|<0001> Tj
      #|ET
      #|Q
      #|q
      #|1 0 0 -1 0 100 cm
      #|0 0 0 rg
      #|BT
      #|/Span <</ActualText (X)
      #|>> BDC
      #|0 Tr
      #|/f0 10 Tf
      #|1 0 0 -1 0 40 Tm
      #|<0001> Tj
      #|EMC
      #|ET
      #|Q
      #|
    ),
  )
}

///|
test "right-to-left runs are marked as reversed chars" {
  let font = test_font()
  let p = parse(text_page(font, [glyph(2, 1, 2), glyph(1, 0, 1)], "AB"))
  inspect(
    p.content(p.page(0)),
    content=(
      #|q
      #|1 0 0 -1 0 100 cm
      #|0 0 0 rg
      #|BT
      #|/ReversedChars BMC
      #|0 Tr
      #|/f0 10 Tf
      #|1 0 0 -1 10 50 Tm
      #|[<00020001>] TJ
      #|EMC
      #|ET
      #|Q
      #|
    ),
  )
}

///|
test "text fill, stroke and opacity" {
  let font = test_font()
  let p = parse(
    text_page(font, [glyph(1, 0, 1)], "A", before=s => {
      s.set_fill(Some({ ..@export.Fill::default(), paint: solid(255, 0, 0), }))
      s.set_stroke(Some(stroke_of(solid(0, 0, 255), 0.5)))
    }),
  )
  inspect(
    p.content(p.page(0)),
    content=(
      #|q
      #|1 0 0 -1 0 100 cm
      #|1 0 0 rg
      #|0 0 1 RG
      #|0.5 w
      #|BT
      #|2 Tr
      #|/f0 10 Tf
      #|1 0 0 -1 10 50 Tm
      #|<0001> Tj
      #|ET
      #|Q
      #|
    ),
  )
  let p = parse(
    text_page(font, [glyph(1, 0, 1)], "A", before=s => {
      s.set_fill(None)
      s.set_stroke(Some({ ..stroke_of(solid(0, 0, 255), 1.0), opacity: 0.5, }))
    }),
  )
  inspect(
    p.content(p.page(0)),
    content=(
      #|q
      #|1 0 0 -1 0 100 cm
      #|/g0 gs
      #|0 0 1 RG
      #|BT
      #|1 Tr
      #|/f0 10 Tf
      #|1 0 0 -1 10 50 Tm
      #|<0001> Tj
      #|ET
      #|Q
      #|
    ),
  )
  inspect(
    p.show_deep(p.path(p.page(0), ["Resources", "ExtGState"])),
    content=(
      #|<</g0 <</Type /ExtGState /ca 0.5 /CA 0.5>>>>
    ),
  )
}

///|
test "fonts are shared between runs and pages" {
  let font = test_font()
  let doc = @export.Document::new_with(plain_settings())
  for text in ["A", "B"] {
    let page = doc.start_page_with(
      @export.PageSettings::from_wh(100.0, 100.0).unwrap(),
    )
    let s = page.surface()
    let g = if text == "A" { 1 } else { 2 }
    s.draw_glyphs(
      @export.Point::from_xy(0.0, 10.0),
      [glyph(g, 0, 1)],
      font,
      text,
      12.0,
    )
    s.finish()
    page.finish()
  }
  let p = parse(doc.finish())
  let f_a = p.path(p.page(0), ["Resources", "Font", "f0"])
  let f_b = p.path(p.page(1), ["Resources", "Font", "f0"])
  inspect(p.show(f_a) == p.show(f_b), content="true")
  let cmap = latin1(p.stream_data(p.get(f_a, "ToUnicode")))
  inspect(
    cmap_body(cmap),
    content=(
      #|2 beginbfchar
      #|<0001> <0041>
      #|<0002> <0042>
      #|endbfchar
      #|
    ),
  )
}

///|
test "font descriptor flags" {
  let p = parse(
    text_page(
      test_font(ps_name="TestSerif-Italic", italic=true, monospaced=true),
      [glyph(1, 0, 1)],
      "A",
    ),
  )
  let desc = p.path(p.font0(), ["DescendantFonts"])
  let desc = p.path(p.items(desc)[0], ["FontDescriptor"])
  // FixedPitch | Serif | Symbolic | Italic | SmallCap
  inspect(
    p.show(p.get(desc, "Flags")),
    content=(
      #|131143
    ),
  )
  inspect(p.show(p.get(desc, "ItalicAngle")), content="-12")
}

///|
test "CFF fonts are embedded as OpenType font programs" {
  let data = test_font_data(outlines="cff")
  let font = @export.Font::new(data, 0).unwrap()
  let p = parse(text_page(font, [glyph(1, 0, 1)], "A"))
  let f0 = p.font0()
  inspect(
    p.show(f0),
    content=(
      #|<</Type /Font /Subtype /Type0 /BaseFont /BZDIMV+TestSans-Bold-Identity-H /Encoding /Identity-H /DescendantFonts [R] /ToUnicode R>>
    ),
  )
  let cid = p.items(p.get(f0, "DescendantFonts"))[0]
  inspect(
    p.show(cid),
    content=(
      #|<</Type /Font /Subtype /CIDFontType0 /BaseFont /BZDIMV+TestSans-Bold /CIDSystemInfo <</Registry (Adobe) /Ordering (Identity) /Supplement 0>> /FontDescriptor R /DW 0 /W [0 [500] 1 [600]]>>
    ),
  )
  let file = p.path(cid, ["FontDescriptor", "FontFile3"])
  inspect(
    p.show(file),
    content=(
      #|stream<</Subtype /OpenType /Filter /FlateDecode /Length 248>>
    ),
  )
  // The font program is embedded unchanged.
  inspect(p.stream_data(file) == data, content="true")
}

///|
test "font errors and font validation" {
  // Glyphs of a font without outlines are drawn into Type 3 fonts ...
  let no_outlines = test_font(outlines="none")
  let p = parse(text_page(no_outlines, [glyph(1, 0, 1)], "A"))
  inspect(
    p.show(p.get(p.font0(), "Subtype")),
    content=(
      #|/Type3
    ),
  )
  // ... unless the color glyph hook routes them to the CID font, which can't
  // be embedded without outlines.
  no_outlines.set_color_glyphs({
    is_color: _ => false,
    draw: (_, _, _) => false,
  })
  inspect(
    export_result(() => text_page(no_outlines, [glyph(1, 0, 1)], "A")),
    content=(
      #|FontError: font is missing an outline table
    ),
  )
  // Restricted license embedding.
  inspect(
    export_result(() => {
      text_page(
        test_font(fs_type=2),
        [glyph(1, 0, 1)],
        "A",
        settings=settings_with(a=Some(A2_B)),
      )
    }),
    content=(
      #|Validation: RestrictedLicense by PDF/A-2b
    ),
  )
  inspect(
    export_result(() => text_page(test_font(fs_type=2), [glyph(1, 0, 1)], "A")),
    content="ok",
  )
  // .notdef glyphs and missing or invalid codepoint mappings.
  inspect(
    export_result(() => {
      text_page(
        test_font(),
        [glyph(0, 0, 1), glyph(1, 1, 1), glyph(2, 1, 2)],
        "?\u{0}",
        settings=settings_with(a=Some(A2_U)),
      )
    }),
    content=(
      #|Validation: ContainsNotDefGlyph(?) by PDF/A-2u; NoCodepointMapping(1) by PDF/A-2u; InvalidCodepointMapping(2, U+0) by PDF/A-2u
    ),
  )
  // Private use area codepoints are only forbidden by PDF/A-2a, -3a and -4.
  inspect(
    export_result(() => {
      text_page(
        test_font(),
        [glyph(1, 0, 1)],
        "\u{E000}",
        settings=settings_with(a=Some(A4)),
      )
    }),
    content=(
      #|Validation: UnicodePrivateArea(1, U+e000) by PDF/A-4
    ),
  )
}

///|
test "Type 3 fonts for color glyphs" {
  let font = test_font()
  let drawn = []
  font.set_color_glyphs({
    is_color: g => g == 3,
    draw: (g, color, s) => {
      drawn.push((g, color))
      s.set_fill(Some({ ..@export.Fill::default(), paint: solid(0, 128, 0), }))
      s.draw_path(rect_path(0.0, 0.0, 600.0, 700.0))
      true
    },
  })
  let p = parse(
    text_page(font, [glyph(1, 0, 1), glyph(3, 1, 2), glyph(3, 2, 3)], "AÄÄ", before=s => {
      s.set_fill(Some({ ..@export.Fill::default(), paint: solid(255, 0, 0), }))
    }),
  )
  // Glyphs are drawn once per context color.
  debug_inspect(
    drawn,
    content=(
      #|[(3, 16711680)]
    ),
  )
  inspect(
    p.content(p.page(0)),
    content=(
      #|q
      #|1 0 0 -1 0 100 cm
      #|1 0 0 rg
      #|BT
      #|0 Tr
      #|/f0 10 Tf
      #|1 0 0 -1 10 50 Tm
      #|<0001> Tj
      #|0 Tr
      #|/f1 10 Tf
      #|1 0 0 -1 16 50 Tm
      #|[<0000>] TJ
      #|ET
      #|Q
      #|
    ),
  )
  let t3 = p.path(p.page(0), ["Resources", "Font", "f1"])
  inspect(
    p.show(t3),
    content=(
      #|<</Type /Font /Subtype /Type3 /Resources <</XObject <</x0 R>>>> /Name /TestSans-Bold /FontBBox [0 0 600 700] /ToUnicode R /FontMatrix [0.001 0 0 0.001 0 0] /FirstChar 0 /LastChar 0 /Widths [600] /FontDescriptor R /CharProcs <</g0 R>> /Encoding <</Type /Encoding /Differences [0 /g0]>>>>
    ),
  )
  inspect(
    p.show(p.get(t3, "FontDescriptor")),
    content=(
      #|<</Type /FontDescriptor /FontName /TestSans-Bold /Flags 131076 /FontBBox [0 0 600 700] /ItalicAngle 0 /Ascent 700 /Descent 0 /FontFamily (TestSans-Bold) /FontStretch /Normal /FontWeight 700>>
    ),
  )
  let proc = p.path(t3, ["CharProcs", "g0"])
  inspect(
    p.content(proc),
    content=(
      #|600 0 d0
      #|/x0 Do
      #|
    ),
  )
  let cmap = latin1(p.stream_data(p.get(t3, "ToUnicode")))
  inspect(
    cmap_body(cmap),
    content=(
      #|1 beginbfchar
      #|<00> <00C4>
      #|endbfchar
      #|
    ),
  )
  // The glyph drawing is a form XObject in the font's resources.
  let x0 = p.path(t3, ["Resources", "XObject", "x0"])
  inspect(
    p.content(x0),
    content=(
      #|q
      #|0 0.50196 0 rg
      #|0 0 m
      #|600 0 l
      #|600 700 l
      #|0 700 l
      #|h
      #|f
      #|Q
      #|
    ),
  )
}

///|
test "Type 3 fonts are only described in PDF 1.5 and later" {
  let font = test_font()
  font.set_color_glyphs({ is_color: _ => true, draw: (_, _, _) => false, })
  let p = parse(
    text_page(
      font,
      [glyph(1, 0, 1)],
      "A",
      settings=settings_with(version=Pdf14),
    ),
  )
  let t3 = p.font0()
  inspect(
    p.keys(t3).join(" "),
    content=(
      #|Type Subtype Resources Name FontBBox ToUnicode FontMatrix FirstChar LastChar Widths CharProcs Encoding
    ),
  )
  // Nothing was drawn: the glyph procedure only sets the width.
  inspect(
    p.content(p.path(t3, ["CharProcs", "g0"])),
    content=(
      #|600 0 d0
      #|
    ),
  )
}

///|
test "CID-keyed CFF fonts address glyphs by the CIDs of their charset" {
  // The charset maps glyphs 1, 2, ... to CIDs 100, 101, ...
  let data = test_font_data(outlines="cid-cff")
  let font = @export.Font::new(data, 0).unwrap()
  let p = parse(text_page(font, [glyph(1, 0, 1), glyph(2, 1, 2)], "AB"))
  // The codes in the content stream are CIDs (0x64 = 100) ...
  inspect(contains(p.content(p.page(0)), "[<00640065>] TJ"), content="true")
  let f0 = p.font0()
  let cid = p.items(p.get(f0, "DescendantFonts"))[0]
  // ... as are the widths ...
  inspect(
    p.show(p.get(cid, "W")),
    content=(
      #|[0 [500] 100 [600] 101 [550]]
    ),
  )
  inspect(p.has(cid, "CIDToGIDMap"), content="false")
  // ... and the ToUnicode mappings.
  let cmap = latin1(p.stream_data(p.get(f0, "ToUnicode")))
  inspect(
    cmap_body(cmap),
    content=(
      #|2 beginbfchar
      #|<0064> <0041>
      #|<0065> <0042>
      #|endbfchar
      #|
    ),
  )
  // The bare CFF program is embedded (like krilla does after subsetting).
  let file = p.path(cid, ["FontDescriptor", "FontFile3"])
  inspect(p.show(p.get(file, "Subtype")), content="/CIDFontType0C")
  let cff = cff_table(6, true)
  inspect(
    p.stream_data(file) == Bytes::from_array(cff.map(b => b.to_byte())),
    content="true",
  )
  // CID-keyed CFF fonts work in PDF 1.4.
  inspect(
    export_result(() => {
      text_page(
        font,
        [glyph(1, 0, 1)],
        "A",
        settings=settings_with(version=Pdf14),
      )
    }),
    content="ok",
  )
}

///|
test "unsupported CFF fonts" {
  // CFF2 can't be embedded without conversion.
  let cff2 = test_font(outlines="cff2")
  debug_inspect(cff2.kind, content="Cff2")
  inspect(
    export_result(() => text_page(cff2, [glyph(1, 0, 1)], "A")),
    content=(
      #|FontError: CFF2 fonts are not supported
    ),
  )
  // Name-keyed CFF fonts are embedded as OpenType font programs (PDF 1.6).
  let cff = test_font(outlines="cff")
  inspect(
    export_result(() => {
      text_page(
        cff,
        [glyph(1, 0, 1)],
        "A",
        settings=settings_with(version=Pdf15),
      )
    }),
    content=(
      #|FontError: embedding a CFF font that is not CID-keyed requires PDF 1.6 or later
    ),
  )
  inspect(
    export_result(() => {
      text_page(
        cff,
        [glyph(1, 0, 1)],
        "A",
        settings=settings_with(version=Pdf16),
      )
    }),
    content="ok",
  )
  // A malformed CFF table is rejected.
  let data = test_font_data(outlines="cff")
  let rec = table_record(data, "CFF ")
  let at = (data[rec + 8].to_int() << 24) |
    (data[rec + 9].to_int() << 16) |
    (data[rec + 10].to_int() << 8) |
    data[rec + 11].to_int()
  inspect(
    @export.Font::new(patch(data, at + 4, [0xFF, 0xFF, 9]), 0) is None,
    content="true",
  )
}

///|
test "TrueType font programs have a Length1" {
  let p = parse(text_page(test_font(), [glyph(1, 0, 1)], "A"))
  let cid = p.items(p.get(p.font0(), "DescendantFonts"))[0]
  let file = p.path(cid, ["FontDescriptor", "FontFile2"])
  inspect(
    p.show(p.get(file, "Length1")) == p.stream_data(file).length().to_string(),
    content="true",
  )
}
