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
      #|<</Type /Font /Subtype /Type0 /BaseFont /ZMYWSZ+TestSans-Bold /Encoding /Identity-H /DescendantFonts [R] /ToUnicode R>>
    ),
  )
  let cid = p.items(p.get(f0, "DescendantFonts"))[0]
  inspect(
    p.show(cid),
    content=(
      #|<</Type /Font /Subtype /CIDFontType2 /BaseFont /ZMYWSZ+TestSans-Bold /CIDSystemInfo <</Registry (Adobe) /Ordering (Identity) /Supplement 0>> /FontDescriptor R /DW 0 /CIDToGIDMap /Identity /W [0 0 500 1 1 600 2 2 550]>>
    ),
  )
  inspect(
    p.show(p.get(cid, "FontDescriptor")),
    content=(
      #|<</Type /FontDescriptor /FontName /ZMYWSZ+TestSans-Bold /Flags 131076 /FontBBox [0 -100 600 700] /ItalicAngle 0 /Ascent 800 /Descent -200 /CapHeight 680 /StemV 168.6 /CIDSet R /FontFile2 R>>
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
test "the embedded TrueType font is subset with new glyph IDs" {
  let font = test_font()
  // Glyph 3 is a composite of glyph 1: both are kept. The CIDs are the new
  // glyph IDs in the order of first use (3 -> 1, 2 -> 2), the component is
  // added last (1 -> 3) by the subsetter.
  let p = parse(text_page(font, [glyph(3, 0, 1), glyph(2, 1, 2)], "ÄB"))
  inspect(contains(p.content(p.page(0)), "[<00010002>] TJ"), content="true")
  let f0 = p.font0()
  let cid = p.items(p.get(f0, "DescendantFonts"))[0]
  // Widths of the used glyphs by CID, including .notdef.
  inspect(
    p.show(p.get(cid, "W")),
    content=(
      #|[0 0 500 1 1 600 2 2 550]
    ),
  )
  let file = p.path(cid, ["FontDescriptor", "FontFile2"])
  // No /Length1 (like krilla).
  inspect(p.has(file, "Length1"), content="false")
  let subset = @export.Font::new(p.stream_data(file), 0).unwrap()
  inspect(subset.num_glyphs, content="4")
  debug_inspect(
    [0, 1, 2, 3].map(g => subset.advance_width(g)),
    content=(
      #|[Some(500), Some(600), Some(550), Some(600)]
    ),
  )
  // The font bounding box is the union of the outlines of the subset.
  inspect(
    p.show(p.path(cid, ["FontDescriptor", "FontBBox"])),
    content=(
      #|[0 -100 600 900]
    ),
  )
  // The CIDSet has the 4 glyphs of the subset.
  let cid_set = p.path(cid, ["FontDescriptor", "CIDSet"])
  inspect(p.stream_data(cid_set) == b"\xF0", content="true")
  // The subset keeps the tables needed for rendering (the cmap, OS/2 and
  // others are dropped).
  debug_inspect(
    [
      "OS/2", "cmap", "glyf", "head", "hhea", "hmtx", "loca", "maxp", "name", "post",
    ].map(t => subset.has_table(t)),
    content=(
      #|[false, false, true, true, true, true, true, true, true, true]
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
      #|<0003> Tj
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
      #|<0003> <0020>
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
      #|[<00010002>] TJ
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
test "name-keyed CFF fonts are embedded as converted CID-keyed CFF programs" {
  let data = test_font_data(outlines="cff")
  let font = @export.Font::new(data, 0).unwrap()
  // Like krilla after subsetting, also in PDF 1.4.
  let p = parse(
    text_page(
      font,
      [glyph(1, 0, 1)],
      "A",
      settings=settings_with(version=Pdf14),
    ),
  )
  let f0 = p.font0()
  inspect(
    p.show(f0),
    content=(
      #|<</Type /Font /Subtype /Type0 /BaseFont /OMMPIC+TestSans-Bold-Identity-H /Encoding /Identity-H /DescendantFonts [R] /ToUnicode R>>
    ),
  )
  let cid = p.items(p.get(f0, "DescendantFonts"))[0]
  inspect(
    p.show(cid),
    content=(
      #|<</Type /Font /Subtype /CIDFontType0 /BaseFont /OMMPIC+TestSans-Bold /CIDSystemInfo <</Registry (Adobe) /Ordering (Identity) /Supplement 0>> /FontDescriptor R /DW 0 /W [0 0 500 1 1 600]>>
    ),
  )
  // CIDs are glyph IDs.
  inspect(contains(p.content(p.page(0)), "<0001> Tj"), content="true")
  let file = p.path(cid, ["FontDescriptor", "FontFile3"])
  inspect(p.show(p.get(file, "Subtype")), content="/CIDFontType0C")
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
      #|0 0.5019608 0 rg
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
test "CID-keyed CFF fonts are subset with identity CIDs" {
  // The charset of the font maps glyphs 1, 2, ... to CIDs 100, 101, ...,
  // the subset's charset is the identity.
  let data = test_font_data(outlines="cid-cff")
  let font = @export.Font::new(data, 0).unwrap()
  let p = parse(text_page(font, [glyph(2, 0, 1), glyph(1, 1, 2)], "BA"))
  // The codes in the content stream are the new glyph IDs ...
  inspect(contains(p.content(p.page(0)), "[<00010002>] TJ"), content="true")
  let f0 = p.font0()
  let cid = p.items(p.get(f0, "DescendantFonts"))[0]
  // ... as are the widths ...
  inspect(
    p.show(p.get(cid, "W")),
    content=(
      #|[0 0 500 1 1 550 2 2 600]
    ),
  )
  inspect(p.has(cid, "CIDToGIDMap"), content="false")
  // ... and the ToUnicode mappings.
  let cmap = latin1(p.stream_data(p.get(f0, "ToUnicode")))
  inspect(
    cmap_body(cmap),
    content=(
      #|2 beginbfchar
      #|<0001> <0042>
      #|<0002> <0041>
      #|endbfchar
      #|
    ),
  )
  // The bare CFF program of the subset is embedded.
  let file = p.path(cid, ["FontDescriptor", "FontFile3"])
  inspect(p.show(p.get(file, "Subtype")), content="/CIDFontType0C")
  let cff = p.stream_data(file)
  inspect(cff[0:4] == b"\x01\x00\x04\x04", content="true")
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
test "CFF2 fonts are converted to TrueType and malformed CFF tables" {
  // The subsetter converts CFF2 fonts to TrueType fonts (/FontFile2).
  let cff2 = test_font(outlines="cff2")
  debug_inspect(cff2.kind, content="Cff2")
  let p = parse(text_page(cff2, [glyph(1, 0, 1)], "A"))
  let f0 = p.font0()
  inspect(
    p.show(p.get(f0, "BaseFont")).has_suffix("-Identity-H"),
    content="false",
  )
  let cid = p.items(p.get(f0, "DescendantFonts"))[0]
  inspect(p.show(p.get(cid, "Subtype")), content="/CIDFontType2")
  let file = p.path(cid, ["FontDescriptor", "FontFile2"])
  let subset = @export.Font::new(p.stream_data(file), 0).unwrap()
  debug_inspect(subset.kind, content="Glyf")
  inspect(
    p.show(p.path(cid, ["FontDescriptor", "FontBBox"])),
    content=(
      #|[0 0 600 700]
    ),
  )
  // A CFF table in a CFF2 font has no outlines.
  let bad = test_font(outlines="bad-cff2")
  debug_inspect(bad.kind, content="NoOutlines")
  // A name-keyed CFF font without a Private DICT is subset with an empty
  // one.
  let data = test_font_data(outlines="cff")
  let cff = table_record(data, "CFF ")
  let cff_at = (data[cff + 8].to_int() << 24) |
    (data[cff + 9].to_int() << 16) |
    (data[cff + 10].to_int() << 8) |
    data[cff + 11].to_int()
  // (The Private operator is the last byte of the Top DICT: 18 -> 13.)
  let top_end = cff_at + 4 + 6 + 2 + 1 + 2 + 17 - 1
  let no_private = @export.Font::new(patch(data, top_end, [13]), 0).unwrap()
  inspect(
    export_result(() => text_page(no_private, [glyph(1, 0, 1)], "A")),
    content="ok",
  )
  // A font with a malformed CFF table has no outlines (like krilla, which
  // checks that the CFF table can be read).
  let data = test_font_data(outlines="cff")
  let rec = table_record(data, "CFF ")
  let at = (data[rec + 8].to_int() << 24) |
    (data[rec + 9].to_int() << 16) |
    (data[rec + 10].to_int() << 8) |
    data[rec + 11].to_int()
  let malformed = @export.Font::new(patch(data, at + 4, [0xFF, 0xFF, 9]), 0)
  debug_inspect(malformed.map(f => f.kind), content="Some(NoOutlines)")
}

///|
test "glyphs composed with seac are rejected like krilla's subsetter does" {
  // `seac` refers to its components by glyph names, which a CID-keyed font
  // doesn't have.
  let font = test_font(outlines="cff-seac")
  let draw = (g : Int) => {
    export_result(() => text_page(font, [glyph(g, 0, 1)], "A"))
  }
  inspect(
    [draw(1), draw(2), draw(3)].join("\n"),
    content=(
      #|FontError: failed to subset font: unsupported feature in font
      #|FontError: failed to subset font: unsupported feature in font
      #|ok
    ),
  )
}

///|
test "cluster ranges outside the text are clamped" {
  let font = test_font()
  // Two glyphs sharing a cluster past the end of the text (an ActualText
  // span), and a reversed run with out-of-range clusters.
  let p = parse(
    text_page(font, [glyph(1, 5, 9), glyph(2, 5, 9), glyph(1, -3, 1)], "AB"),
  )
  inspect(
    p.content(p.page(0)),
    content=(
      #|q
      #|1 0 0 -1 0 100 cm
      #|0 0 0 rg
      #|BT
      #|/Span <</ActualText ()
      #|>> BDC
      #|/ReversedChars BMC
      #|0 Tr
      #|/f0 10 Tf
      #|1 0 0 -1 10 50 Tm
      #|[<00010002>] TJ
      #|EMC
      #|EMC
      #|/Span <</ActualText (A)
      #|>> BDC
      #|/ReversedChars BMC
      #|0 Tr
      #|/f0 10 Tf
      #|1 0 0 -1 21.5 50 Tm
      #|<0001> Tj
      #|EMC
      #|EMC
      #|ET
      #|Q
      #|
    ),
  )
  let p = parse(text_page(font, [glyph(2, 7, 9), glyph(1, 3, 4)], "AB"))
  inspect(
    p.content(p.page(0)),
    content=(
      #|q
      #|1 0 0 -1 0 100 cm
      #|0 0 0 rg
      #|BT
      #|/Span <</ActualText ()
      #|>> BDC
      #|/ReversedChars BMC
      #|0 Tr
      #|/f0 10 Tf
      #|1 0 0 -1 10 50 Tm
      #|[<00010002>] TJ
      #|EMC
      #|EMC
      #|ET
      #|Q
      #|
    ),
  )
}
