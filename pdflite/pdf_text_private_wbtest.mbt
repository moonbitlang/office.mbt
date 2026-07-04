// Whitebox tests for text glyph extraction internals.
// Public text behavior belongs in `_test.mbt` files.

///|
fn wbtest_text_bytes(values : ArrayView[Int]) -> @core.PdfBytes {
  try! @core.pdf_bytes_of_int_array(values)
}

///|
fn wbtest_text_name(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn wbtest_text_simple_font(
  encoding : PdfEncoding,
  descriptor : PdfFontDescriptor?,
) -> PdfFont {
  PdfFontSimple({
    fonttype: PdfType1,
    basefont: None,
    firstchar: 0,
    lastchar: 0,
    widths: [],
    fontdescriptor: descriptor,
    fontmetrics: None,
    encoding,
  })
}

///|
test "private text glyph helpers cover fallback and CID ToUnicode branches" {
  let implicit : PdfEncoding = PdfImplicitInFontFile
  @test.assert_eq(implicit.pdf_text_glyphname_of_charcode(65), None)
  let filled : PdfEncoding = PdfFillUndefinedWithStandard(PdfImplicitInFontFile)
  @test.assert_eq(
    filled.pdf_text_glyphname_of_charcode(65),
    Some(wbtest_text_name("/A")),
  )
  let filled_existing : PdfEncoding = PdfFillUndefinedWithStandard(
    PdfWinAnsiEncoding,
  )
  @test.assert_eq(
    filled_existing.pdf_text_glyphname_of_charcode(65),
    Some(wbtest_text_name("/A")),
  )
  let simple = wbtest_text_simple_font(PdfWinAnsiEncoding, None)
  @test.assert_eq(
    simple.pdf_text_glyphname_of_charcode(65),
    Some(wbtest_text_name("/A")),
  )
  @test.assert_eq(simple.pdf_text_uses_symbol_codepoints(), false)

  let fallback_font = wbtest_text_simple_font(
    PdfCustomEncoding(PdfImplicitInFontFile, [
      { name: wbtest_text_name("/unknown"), code: 65 },
    ]),
    None,
  )
  let fallback_extractor = fallback_font.text_extractor()
  @test.assert_eq(fallback_extractor.pdf_text_encoded_glyph_of_charcode(65), {
    glyphname: wbtest_text_name("/unknown"),
    codepoints: [65],
  })

  let invalid_tounicode = [(65, wbtest_text_bytes([0]))]
  let invalid_font = wbtest_text_simple_font(
    PdfWinAnsiEncoding,
    Some({
      ..pdf_text_empty_font_descriptor(),
      tounicode: Some(invalid_tounicode),
    }),
  )
  let invalid_extractor = invalid_font.text_extractor()
  @test.assert_eq(
    try! invalid_extractor.codepoints_of_text(wbtest_text_bytes([65])),
    [65],
  )
  @test.assert_eq(invalid_extractor.charcode_of_codepoint(65), None)

  let tounicode = [(65, wbtest_text_bytes([0x00, 0x41]))]
  let cid_font : PdfFont = PdfFontCIDKeyed({
    basefont: wbtest_text_name("/Top"),
    composite: {
      cid_system_info: {
        registry: wbtest_text_bytes([82]),
        ordering: wbtest_text_bytes([79]),
        supplement: 0,
      },
      cid_basefont: wbtest_text_name("/Descendant"),
      cid_fontdescriptor: pdf_text_empty_font_descriptor(),
      cid_widths: [],
      cid_widths2: [],
      cid_default_width: 1000.0,
      cid_default_width2: [880.0, -1000.0],
    },
    encoding: PdfPredefinedCMap(wbtest_text_name("/Identity-H")),
  })
  let cid_with_tounicode = cid_font.pdf_text_with_tounicode(Some(tounicode))
  @test.assert_eq(cid_with_tounicode.pdf_text_tounicode(), Some(tounicode))
  let standard_font : PdfFont = PdfFontStandard({
    font: PdfHelvetica,
    encoding: PdfWinAnsiEncoding,
  })
  @test.assert_eq(
    standard_font.pdf_text_with_tounicode(Some(tounicode)),
    standard_font,
  )
  @test.assert_eq(pdf_text_cns1_codepoint_of_cid(-1), None)
  @test.assert_eq(pdf_text_cns1_codepoint_of_cid(0), None)
  @test.assert_eq(
    pdf_text_cns1_codepoint_of_cid(
      @cmapdata.pdf_text_cns1_unicode_table.length(),
    ),
    None,
  )
  @test.assert_eq(pdf_text_gb1_codepoint_of_cid(-1), None)
  @test.assert_eq(pdf_text_gb1_codepoint_of_cid(0), None)
  @test.assert_eq(
    pdf_text_gb1_codepoint_of_cid(@cmapdata.pdf_text_gb1_unicode_table.length()),
    None,
  )
  @test.assert_eq(
    pdf_text_predefined_cid_range_charcode_of_cid(
      [(0x81308436, 0x81308436, 1), (0x0000FE51, 0x0000FE51, 1)],
      1,
    ),
    Some(0x0000FE51),
  )
  @test.assert_eq(
    pdf_text_predefined_cid_range_lookup_unsigned(
      [(0x20, 0x7E, 10), (0x8EA2EDA1, 0x8EA2EDA2, 20)],
      0x8EA2EDA2,
    ),
    Some(21),
  )
  @test.assert_eq(
    pdf_text_predefined_cid_range_lookup_unsigned(
      [(0x20, 0x7E, 10), (0x8EA2EDA1, 0x8EA2EDA2, 20)],
      0x80,
    ),
    None,
  )
  @test.assert_eq(
    pdf_text_lower_optional_packed_charcode(Some(0x0000FE51), Some(0x81308436)),
    Some(0x0000FE51),
  )
  @test.assert_eq(
    pdf_text_lower_optional_packed_charcode(Some(0x0000FE51), None),
    Some(0x0000FE51),
  )
  @test.assert_eq(
    pdf_text_predefined_sequence_table_charcode(
      [(3, [0x21]), (1, [0x20]), (2, [0x20, 0xFE00])],
      [(0x81308436, 0x81308436, 1), (0x0000FE51, 0x0000FE51, 1)],
      0x20,
    ),
    Some(0x0000FE51),
  )
  @test.assert_eq(
    pdf_text_predefined_sequence_table_charcode(
      [(3, [0x21])],
      [(0x0000FE51, 0x0000FE51, 1)],
      0x21,
    ),
    None,
  )
  @test.assert_eq(
    pdf_text_predefined_cid_range_charcode_of_cid(
      [(0x81308436, 0x81308436, 1)],
      2,
    ),
    None,
  )
  @test.assert_eq(
    pdf_text_predefined_unicode_table_charcode(
      [0, 0x20, 0x20],
      [(0x81308436, 0x81308436, 1), (0x0000FE51, 0x0000FE51, 2)],
      0x20,
    ),
    Some(0x0000FE51),
  )
  @test.assert_eq(
    pdf_text_predefined_unicode_table_charcode(
      [0, 0x20],
      [(0x0000FE51, 0x0000FE51, 1)],
      0,
    ),
    None,
  )
  @test.assert_eq(
    pdf_text_predefined_codepoint_range_charcode(
      [(1, 1, 0x20)],
      [(0x81308436, 0x81308436, 1), (0x0000FE51, 0x0000FE51, 1)],
      0x20,
    ),
    Some(0x0000FE51),
  )
  @test.assert_eq(
    pdf_text_predefined_codepoint_range_charcode(
      [(1, 1, 0x20)],
      [(0x0000FE51, 0x0000FE51, 1)],
      0x21,
    ),
    None,
  )
  @test.assert_eq(
    pdf_text_predefined_gb1_charcode(
      [(0x81308436, 0x81308436, 1), (0x0000FE51, 0x0000FE51, 1)],
      0x20,
    ),
    Some(0x0000FE51),
  )
  let unknown_vertical_cmap = wbtest_text_name("/Unknown-V")
  guard pdf_text_predefined_gb1_vertical_codepoint_table(unknown_vertical_cmap)
    is None else {
    fail("expected no GB1 vertical table")
  }
  guard pdf_text_predefined_gb1_vertical_charcode_table(unknown_vertical_cmap)
    is None else {
    fail("expected no GB1 vertical reverse table")
  }
  guard pdf_text_predefined_korea1_vertical_codepoint_table(
      unknown_vertical_cmap,
    )
    is None else {
    fail("expected no Korea1 vertical table")
  }
  guard pdf_text_predefined_korea1_vertical_charcode_table(
      unknown_vertical_cmap,
    )
    is None else {
    fail("expected no Korea1 vertical reverse table")
  }
  let japan1_cid_cmaps = [
    "/H", "/V", "/78-H", "/78-V", "/78-EUC-H", "/78-EUC-V", "/78-RKSJ-H", "/78-RKSJ-V",
    "/78ms-RKSJ-H", "/78ms-RKSJ-V", "/83pv-RKSJ-H", "/90ms-RKSJ-H", "/90ms-RKSJ-V",
    "/90msp-RKSJ-H", "/90msp-RKSJ-V", "/90pv-RKSJ-H", "/90pv-RKSJ-V", "/Add-H", "/Add-V",
    "/Add-RKSJ-H", "/Add-RKSJ-V", "/EUC-H", "/EUC-V", "/Ext-H", "/Ext-V", "/Ext-RKSJ-H",
    "/Ext-RKSJ-V", "/Hojo-H", "/Hojo-V", "/Hojo-EUC-H", "/Hojo-EUC-V", "/NWP-H",
    "/NWP-V", "/RKSJ-H", "/RKSJ-V",
  ]
  for cmap in japan1_cid_cmaps {
    guard pdf_text_predefined_japan1_cid_ranges(wbtest_text_name(cmap))
      is Some(_) else {
      fail("expected Japan1 CID ranges for " + cmap)
    }
  }
  guard pdf_text_predefined_japan1_cid_ranges(wbtest_text_name("/Unknown"))
    is None else {
    fail("expected no Japan1 CID ranges for non-oriented CMap")
  }
  guard pdf_text_predefined_japan1_cid_ranges(wbtest_text_name("/Unknown-V"))
    is None else {
    fail("expected no Japan1 CID ranges for unknown vertical CMap")
  }
  guard pdf_text_predefined_japan1_direct_codepoint_ranges(
      wbtest_text_name("/90ms-RKSJ-H"),
    )
    is Some(_) else {
    fail("expected 90ms-RKSJ direct table")
  }
  guard pdf_text_predefined_japan1_direct_codepoint_ranges(
      wbtest_text_name("/90pv-RKSJ-H"),
    )
    is Some(_) else {
    fail("expected 90pv-RKSJ direct table")
  }
  guard pdf_text_predefined_japan1_direct_codepoint_ranges(
      wbtest_text_name("/90ms-RKSJ-V"),
    )
    is None else {
    fail("expected no direct table for vertical RKSJ")
  }
  @test.assert_eq(
    pdf_text_predefined_japan1_direct_codepoint_sequence_table(
      wbtest_text_name("/90ms-RKSJ-H"),
    ).length(),
    0,
  )
  @test.assert_eq(
    pdf_text_predefined_japan1_direct_codepoint_sequence_table(
      wbtest_text_name("/90pv-RKSJ-H"),
    ).length() >
    0,
    true,
  )
  guard pdf_text_predefined_japan1_direct_charcode_ranges(
      wbtest_text_name("/90ms-RKSJ-H"),
    )
    is Some(_) else {
    fail("expected 90ms-RKSJ direct reverse table")
  }
  guard pdf_text_predefined_japan1_direct_charcode_ranges(
      wbtest_text_name("/90pv-RKSJ-H"),
    )
    is Some(_) else {
    fail("expected 90pv-RKSJ direct reverse table")
  }
  guard pdf_text_predefined_japan1_direct_charcode_ranges(
      wbtest_text_name("/90ms-RKSJ-V"),
    )
    is None else {
    fail("expected no direct reverse table for vertical RKSJ")
  }
  @test.assert_eq(
    pdf_text_predefined_cmap_uses_japan1_two_byte_charcodes(
      wbtest_text_name("/H"),
    ),
    true,
  )
  @test.assert_eq(
    pdf_text_predefined_cmap_uses_japan1_two_byte_charcodes(
      wbtest_text_name("/90ms-RKSJ-H"),
    ),
    false,
  )
  @test.assert_eq(
    pdf_text_predefined_cmap_uses_japan1_two_byte_charcodes(
      wbtest_text_name("/EUC-H"),
    ),
    false,
  )
  @test.assert_eq(
    pdf_text_predefined_cmap_uses_hojo_euc_charcodes(
      wbtest_text_name("/Hojo-EUC-H"),
    ),
    true,
  )
  @test.assert_eq(
    pdf_text_predefined_rksj_single_byte_codepoint(0x41),
    Some(0x41),
  )
  @test.assert_eq(
    pdf_text_predefined_rksj_single_byte_codepoint(0xA6),
    Some(0xFF66),
  )
  @test.assert_eq(pdf_text_predefined_rksj_single_byte_codepoint(0x8140), None)
  @test.assert_eq(
    pdf_text_predefined_rksj_single_byte_charcode(0x41),
    Some(0x41),
  )
  @test.assert_eq(
    pdf_text_predefined_rksj_single_byte_charcode(0xFF66),
    Some(0xA6),
  )
  @test.assert_eq(pdf_text_predefined_rksj_single_byte_charcode(0x3000), None)
  @test.assert_eq(pdf_text_japan1_codepoints_of_cid(843), Some([0x3042]))
  @test.assert_eq(pdf_text_japan1_codepoints_of_cid(-1), None)
  guard pdf_text_predefined_japan1_cid_ranges(wbtest_text_name("/H"))
    is Some(jis_ranges) else {
    fail("expected JIS ranges")
  }
  @test.assert_eq(
    pdf_text_predefined_japan1_codepoints(jis_ranges, 0x2422),
    Some([0x3042]),
  )
  @test.assert_eq(pdf_text_predefined_japan1_codepoints(jis_ranges, 0), None)
  @test.assert_eq(
    pdf_text_predefined_japan1_charcode(jis_ranges, 0x3042),
    Some(0x2422),
  )
  @test.assert_eq(
    pdf_text_predefined_japan1_charcode(jis_ranges, 0x1F600),
    None,
  )
  let unknown_rksj_font : PdfFont = PdfFontCIDKeyed({
    basefont: wbtest_text_name("/UnknownRKSJ"),
    composite: {
      cid_system_info: {
        registry: wbtest_text_bytes([82]),
        ordering: wbtest_text_bytes([79]),
        supplement: 0,
      },
      cid_basefont: wbtest_text_name("/Descendant"),
      cid_fontdescriptor: pdf_text_empty_font_descriptor(),
      cid_widths: [],
      cid_widths2: [],
      cid_default_width: 1000.0,
      cid_default_width2: [880.0, -1000.0],
    },
    encoding: PdfPredefinedCMap(wbtest_text_name("/Unknown-RKSJ-H")),
  })
  let unknown_rksj_extractor = unknown_rksj_font.text_extractor()
  @test.assert_eq(
    unknown_rksj_extractor.codepoints_of_text(
      wbtest_text_bytes([0x41, 0xA6, 0x81, 0x40]),
    ),
    [0x41, 0xFF66, 0x8140],
  )
  @test.assert_eq(
    unknown_rksj_extractor.charcode_of_codepoint(0x41),
    Some(0x41),
  )
  @test.assert_eq(
    unknown_rksj_extractor.charcode_of_codepoint(0xFF66),
    Some(0xA6),
  )
  @test.assert_eq(unknown_rksj_extractor.charcode_of_codepoint(0x3000), None)
  @test.assert_eq(pdf_text_hex_int_min2(7), "07")
}
