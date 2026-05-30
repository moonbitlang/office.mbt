///|
fn text_cmap_predefined_name_for_test(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn text_cmap_predefined_bytes_for_test(
  values : ArrayView[Int],
) -> @core.PdfBytes {
  try! @core.pdf_bytes_of_int_array(values)
}

///|
fn text_cmap_predefined_font_descriptor_for_test() -> @pdflite.PdfFontDescriptor {
  {
    ascent: 0.0,
    descent: 0.0,
    avgwidth: 0.0,
    maxwidth: 0.0,
    flags: 0,
    fontbbox: { min_x: 0.0, min_y: 0.0, max_x: 0.0, max_y: 0.0 },
    italicangle: 0.0,
    capheight: 0.0,
    xheight: 0.0,
    stemv: 0.0,
    fontfile: None,
    charset: None,
    tounicode: None,
  }
}

///|
test "PdfTextExtractor reads identity CMap text as two-byte character codes" {
  let composite : @pdflite.PdfCompositeCIDFont = {
    cid_system_info: {
      registry: text_cmap_predefined_bytes_for_test([65]),
      ordering: text_cmap_predefined_bytes_for_test([73]),
      supplement: 0,
    },
    cid_basefont: text_cmap_predefined_name_for_test("/Descendant"),
    cid_fontdescriptor: text_cmap_predefined_font_descriptor_for_test(),
    cid_widths: [],
    cid_widths2: [],
    cid_default_width: 1000.0,
    cid_default_width2: [880.0, -1000.0],
  }
  let cid_font_h : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_predefined_name_for_test("/Top"),
    composite,
    encoding: PdfPredefinedCMap(
      text_cmap_predefined_name_for_test("/Identity-H"),
    ),
  })
  let extractor = cid_font_h.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(
      text_cmap_predefined_bytes_for_test([0x00, 0x41, 0x20, 0xAC]),
    ),
    [0x41, 0x20AC],
  )
  @test.assert_eq(
    try! extractor.glyphnames_of_text(
      text_cmap_predefined_bytes_for_test([0x00, 0x41]),
    ),
    [text_cmap_predefined_name_for_test(".notdef")],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x41), None)
  @test.assert_eq(extractor.charcode_of_codepoint(0xF6E6), None)
  let odd = try? extractor.codepoints_of_text(
    text_cmap_predefined_bytes_for_test([0x00]),
  )
  guard odd is Err(BadText) else { fail("expected @core.PdfError::BadText") }
  let cid_font_v_data : @pdflite.PdfCIDKeyedFont = {
    basefont: text_cmap_predefined_name_for_test("/TopVertical"),
    composite,
    encoding: PdfPredefinedCMap(
      text_cmap_predefined_name_for_test("/Identity-V"),
    ),
  }
  @test.assert_eq(cid_font_v_data.is_identity_v(), true)
  @test.assert_eq(cid_font_v_data.uses_two_byte_codes(), true)
  let cid_font_v : @pdflite.PdfFont = PdfFontCIDKeyed(cid_font_v_data)
  @test.assert_eq(cid_font_v.is_identity_h(), false)
  @test.assert_eq(cid_font_v.is_identity_v(), true)
  @test.assert_eq(cid_font_v.uses_two_byte_codes(), true)
  let vertical_extractor = cid_font_v.text_extractor()
  @test.assert_eq(
    try! vertical_extractor.codepoints_of_text(
      text_cmap_predefined_bytes_for_test([0x00, 0x42, 0x4E, 0x00]),
    ),
    [0x42, 0x4E00],
  )
  @test.assert_eq(
    try! vertical_extractor.glyphnames_of_text(
      text_cmap_predefined_bytes_for_test([0x4E, 0x00]),
    ),
    [text_cmap_predefined_name_for_test(".notdef")],
  )
  let vertical_odd = try? vertical_extractor.codepoints_of_text(
    text_cmap_predefined_bytes_for_test([0x4E]),
  )
  guard vertical_odd is Err(BadText) else {
    fail("expected @core.PdfError::BadText")
  }
  let ucs2_cmap_font_h : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_predefined_name_for_test("/TopUCS2"),
    composite,
    encoding: PdfPredefinedCMap(
      text_cmap_predefined_name_for_test("/UniJIS-UCS2-H"),
    ),
  })
  @test.assert_eq(ucs2_cmap_font_h.is_identity_h(), false)
  @test.assert_eq(ucs2_cmap_font_h.is_identity_v(), false)
  @test.assert_eq(ucs2_cmap_font_h.uses_two_byte_codes(), true)
  let ucs2_h_extractor = ucs2_cmap_font_h.text_extractor()
  @test.assert_eq(
    try! ucs2_h_extractor.codepoints_of_text(
      text_cmap_predefined_bytes_for_test([0x00, 0x41, 0x4E, 0x00]),
    ),
    [0x41, 0x4E00],
  )
  @test.assert_eq(ucs2_h_extractor.charcode_of_codepoint(0x4E00), Some(0x4E00))
  let ucs2_odd = try? ucs2_h_extractor.codepoints_of_text(
    text_cmap_predefined_bytes_for_test([0x00, 0x41, 0x4E]),
  )
  guard ucs2_odd is Err(_) else { fail("expected malformed UCS2 text error") }
  let ucs2_cmap_font_v : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_predefined_name_for_test("/TopUCS2Vertical"),
    composite,
    encoding: PdfPredefinedCMap(
      text_cmap_predefined_name_for_test("/UniCNS-UCS2-V"),
    ),
  })
  @test.assert_eq(ucs2_cmap_font_v.uses_two_byte_codes(), true)
  @test.assert_eq(
    try! ucs2_cmap_font_v
    .text_extractor()
    .codepoints_of_text(
      text_cmap_predefined_bytes_for_test([0x00, 0x42, 0x4E, 0x8C]),
    ),
    [0x42, 0x4E8C],
  )
  let utf16_cmap_font_h : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_predefined_name_for_test("/TopUTF16"),
    composite,
    encoding: PdfPredefinedCMap(
      text_cmap_predefined_name_for_test("/UniJIS-UTF16-H"),
    ),
  })
  @test.assert_eq(utf16_cmap_font_h.uses_two_byte_codes(), true)
  @test.assert_eq(
    utf16_cmap_font_h
    .text_extractor()
    .codepoints_of_text(
      text_cmap_predefined_bytes_for_test([0x30, 0x42, 0x30, 0xA2]),
    ),
    [0x3042, 0x30A2],
  )
  @test.assert_eq(
    utf16_cmap_font_h
    .text_extractor()
    .codepoints_of_text(
      text_cmap_predefined_bytes_for_test([0xD8, 0x34, 0xDD, 0x1E]),
    ),
    [0x1D11E],
  )
  @test.assert_eq(
    utf16_cmap_font_h.text_extractor().charcode_of_codepoint(0x3042),
    Some(0x3042),
  )
  @test.assert_eq(
    utf16_cmap_font_h.text_extractor().charcode_of_codepoint(0x1D11E),
    Some(0xD834DD1E),
  )
  let utf16_unpaired = try? utf16_cmap_font_h
    .text_extractor()
    .codepoints_of_text(
      text_cmap_predefined_bytes_for_test([0xD8, 0x34, 0x30, 0x42]),
    )
  guard utf16_unpaired is Err(_) else {
    fail("expected malformed UTF16 predefined CMap text error")
  }
  let utf16_cmap_font_v : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_predefined_name_for_test("/TopUTF16Vertical"),
    composite,
    encoding: PdfPredefinedCMap(
      text_cmap_predefined_name_for_test("/UniCNS-UTF16-V"),
    ),
  })
  @test.assert_eq(utf16_cmap_font_v.uses_two_byte_codes(), true)
  @test.assert_eq(
    utf16_cmap_font_v
    .text_extractor()
    .codepoints_of_text(
      text_cmap_predefined_bytes_for_test([0x4E, 0x00, 0x4E, 0x8C]),
    ),
    [0x4E00, 0x4E8C],
  )
  let utf8_cmap_font_h : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_predefined_name_for_test("/TopUTF8"),
    composite,
    encoding: PdfPredefinedCMap(
      text_cmap_predefined_name_for_test("/UniJIS-UTF8-H"),
    ),
  })
  @test.assert_eq(utf8_cmap_font_h.uses_two_byte_codes(), false)
  @test.assert_eq(
    utf8_cmap_font_h
    .text_extractor()
    .codepoints_of_text(
      text_cmap_predefined_bytes_for_test([
        0x41, 0xE3, 0x81, 0x82, 0xF0, 0x9D, 0x84, 0x9E,
      ]),
    ),
    [0x41, 0x3042, 0x1D11E],
  )
  @test.assert_eq(
    utf8_cmap_font_h.text_extractor().charcode_of_codepoint(0x3042),
    Some(0xE38182),
  )
  @test.assert_eq(
    utf8_cmap_font_h.text_extractor().charcode_of_codepoint(0x1D11E),
    Some(0xF09D849E),
  )
  let utf8_bad = try? utf8_cmap_font_h
    .text_extractor()
    .codepoints_of_text(text_cmap_predefined_bytes_for_test([0xE3, 0x81]))
  guard utf8_bad is Err(_) else {
    fail("expected malformed UTF8 predefined CMap text error")
  }
  let utf8_tounicode_descriptor : @pdflite.PdfFontDescriptor = {
    ..text_cmap_predefined_font_descriptor_for_test(),
    tounicode: Some([
      (0xE38182, text_cmap_predefined_bytes_for_test([0x26, 0x03])),
      (0xF09D849E, text_cmap_predefined_bytes_for_test([0x03, 0xA9])),
    ]),
  }
  let utf8_tounicode_font : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_predefined_name_for_test("/TopUTF8ToUnicode"),
    composite: { ..composite, cid_fontdescriptor: utf8_tounicode_descriptor },
    encoding: PdfPredefinedCMap(
      text_cmap_predefined_name_for_test("/UniJIS-UTF8-H"),
    ),
  })
  let utf8_tounicode_extractor = utf8_tounicode_font.text_extractor()
  @test.assert_eq(
    utf8_tounicode_extractor.codepoints_of_text(
      text_cmap_predefined_bytes_for_test([
        0xE3, 0x81, 0x82, 0xF0, 0x9D, 0x84, 0x9E,
      ]),
    ),
    [0x2603, 0x03A9],
  )
  @test.assert_eq(
    utf8_tounicode_extractor.charcode_of_codepoint(0x2603),
    Some(0xE38182),
  )
  @test.assert_eq(
    utf8_tounicode_extractor.charcode_of_codepoint(0x03A9),
    Some(0xF09D849E),
  )
  let utf32_cmap_font_v : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_predefined_name_for_test("/TopUTF32Vertical"),
    composite,
    encoding: PdfPredefinedCMap(
      text_cmap_predefined_name_for_test("/UniCNS-UTF32-V"),
    ),
  })
  @test.assert_eq(utf32_cmap_font_v.uses_two_byte_codes(), false)
  @test.assert_eq(
    utf32_cmap_font_v
    .text_extractor()
    .codepoints_of_text(
      text_cmap_predefined_bytes_for_test([
        0x00, 0x00, 0x00, 0x41, 0x00, 0x01, 0xD1, 0x1E,
      ]),
    ),
    [0x41, 0x1D11E],
  )
  @test.assert_eq(
    utf32_cmap_font_v.text_extractor().charcode_of_codepoint(0x1D11E),
    Some(0x1D11E),
  )
  let utf32_bad = try? utf32_cmap_font_v
    .text_extractor()
    .codepoints_of_text(
      text_cmap_predefined_bytes_for_test([0x00, 0x00, 0xD8, 0x00]),
    )
  guard utf32_bad is Err(_) else {
    fail("expected malformed UTF32 predefined CMap text error")
  }
  let direct_unicode_predefined_cases : Array[
    (String, Array[Int], Array[Int], Int, Int),
  ] = [
    (
      "/UniAKR-UTF8-H",
      [0x41, 0xEA, 0xB0, 0x80],
      [0x41, 0xAC00],
      0xAC00,
      0xEAB080,
    ),
    ("/UniAKR-UTF16-H", [0xAC, 0x00], [0xAC00], 0xAC00, 0xAC00),
    ("/UniAKR-UTF32-H", [0x00, 0x00, 0xAC, 0x00], [0xAC00], 0xAC00, 0xAC00),
    ("/UniGB-UTF16-H", [0x4E, 0x00], [0x4E00], 0x4E00, 0x4E00),
    ("/UniGB-UTF16-V", [0x56, 0xFD], [0x56FD], 0x56FD, 0x56FD),
    ("/UniGB-UCS32-H", [0x00, 0x00, 0x4E, 0x00], [0x4E00], 0x4E00, 0x4E00),
    ("/UniGB-UCS32-V", [0x00, 0x00, 0x56, 0xFD], [0x56FD], 0x56FD, 0x56FD),
    ("/UniKS-UCS2-H", [0xAC, 0x00], [0xAC00], 0xAC00, 0xAC00),
    ("/UniKS-UCS2-V", [0xB0, 0x98], [0xB098], 0xB098, 0xB098),
    ("/UniJIS-UCS2-HW-H", [0x00, 0x41], [0x41], 0x41, 0x41),
    ("/UniJIS-UCS2-HW-V", [0xFF, 0x76], [0xFF76], 0xFF76, 0xFF76),
  ]
  for case in direct_unicode_predefined_cases {
    let direct_unicode_font : @pdflite.PdfFont = PdfFontCIDKeyed({
      basefont: text_cmap_predefined_name_for_test("/TopDirectUnicode"),
      composite,
      encoding: PdfPredefinedCMap(text_cmap_predefined_name_for_test(case.0)),
    })
    let direct_unicode_extractor = direct_unicode_font.text_extractor()
    @test.assert_eq(
      direct_unicode_extractor.codepoints_of_text(
        text_cmap_predefined_bytes_for_test(case.1),
      ),
      case.2,
    )
    @test.assert_eq(
      direct_unicode_extractor.charcode_of_codepoint(case.3),
      Some(case.4),
    )
  }
  let non_ucs2_predefined_font : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_predefined_name_for_test("/TopGBEUC"),
    composite,
    encoding: PdfPredefinedCMap(text_cmap_predefined_name_for_test("/GB-EUC-H")),
  })
  @test.assert_eq(non_ucs2_predefined_font.uses_two_byte_codes(), false)
  @test.assert_eq(
    try! non_ucs2_predefined_font
    .text_extractor()
    .codepoints_of_text(text_cmap_predefined_bytes_for_test([0x41, 0x81, 0x40])),
    [0x41, 0x8140],
  )
  let gb_euc_tounicode_descriptor : @pdflite.PdfFontDescriptor = {
    ..text_cmap_predefined_font_descriptor_for_test(),
    tounicode: Some([
      (0x41, text_cmap_predefined_bytes_for_test([0x00, 0x41])),
      (0x8140, text_cmap_predefined_bytes_for_test([0x4E, 0x00])),
    ]),
  }
  let gb_euc_tounicode_font : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_predefined_name_for_test("/TopGBEUCToUnicode"),
    composite: { ..composite, cid_fontdescriptor: gb_euc_tounicode_descriptor },
    encoding: PdfPredefinedCMap(text_cmap_predefined_name_for_test("/GB-EUC-H")),
  })
  @test.assert_eq(
    try! gb_euc_tounicode_font
    .text_extractor()
    .codepoints_of_text(text_cmap_predefined_bytes_for_test([0x41, 0x81, 0x40])),
    [0x41, 0x4E00],
  )
  let gb_euc_truncated = try? gb_euc_tounicode_font
    .text_extractor()
    .codepoints_of_text(text_cmap_predefined_bytes_for_test([0x81]))
  guard gb_euc_truncated is Err(BadText) else {
    fail("expected @core.PdfError::BadText for truncated GB-EUC charcode")
  }
  let gb_euc_builtin_font : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_predefined_name_for_test("/TopGBEUCBuiltin"),
    composite,
    encoding: PdfPredefinedCMap(text_cmap_predefined_name_for_test("/GB-EUC-H")),
  })
  let gb_euc_builtin_extractor = gb_euc_builtin_font.text_extractor()
  @test.assert_eq(
    gb_euc_builtin_extractor.codepoints_of_text(
      text_cmap_predefined_bytes_for_test([
        0x41, 0xC4, 0xE3, 0xBA, 0xC3, 0xA1, 0xA1, 0xA3, 0xC1,
      ]),
    ),
    [0x41, 0x4F60, 0x597D, 0x3000, 0xFF21],
  )
  @test.assert_eq(
    gb_euc_builtin_extractor.charcode_of_codepoint(0x41),
    Some(0x41),
  )
  @test.assert_eq(
    gb_euc_builtin_extractor.charcode_of_codepoint(0x4F60),
    Some(0xC4E3),
  )
  @test.assert_eq(
    gb_euc_builtin_extractor.charcode_of_codepoint(0x597D),
    Some(0xBAC3),
  )
  @test.assert_eq(
    gb_euc_builtin_extractor.charcode_of_codepoint(0x3000),
    Some(0xA1A1),
  )
  @test.assert_eq(
    gb_euc_builtin_extractor.charcode_of_codepoint(0xFF21),
    Some(0xA3C1),
  )
  @test.assert_eq(gb_euc_builtin_extractor.charcode_of_codepoint(0x20AC), None)
  let gbpc_euc_builtin_font : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_predefined_name_for_test("/TopGBpcEUCBuiltin"),
    composite,
    encoding: PdfPredefinedCMap(
      text_cmap_predefined_name_for_test("/GBpc-EUC-H"),
    ),
  })
  let gbpc_euc_builtin_extractor = gbpc_euc_builtin_font.text_extractor()
  @test.assert_eq(
    gbpc_euc_builtin_extractor.codepoints_of_text(
      text_cmap_predefined_bytes_for_test([
        0x41, 0x80, 0x83, 0xA0, 0xFD, 0xFE, 0xFF, 0xA1, 0xA1, 0xA1, 0xAB, 0xA8, 0xBF,
        0xC4, 0xE3, 0xBA, 0xC3,
      ]),
    ),
    [
      0x41, 0x00FC, 0x83, 0x00A0, 0x00A9, 0x2122, 0x2026, 0x3000, 0x301C, 0x006E,
      0x0300, 0x4F60, 0x597D,
    ],
  )
  @test.assert_eq(
    gbpc_euc_builtin_extractor.codepoints_of_text(
      text_cmap_predefined_bytes_for_test([0x81, 0x40]),
    ),
    [0x8140],
  )
  @test.assert_eq(
    gbpc_euc_builtin_extractor.charcode_of_codepoint(0x41),
    Some(0x41),
  )
  @test.assert_eq(
    gbpc_euc_builtin_extractor.charcode_of_codepoint(0x00FC),
    Some(0x80),
  )
  @test.assert_eq(
    gbpc_euc_builtin_extractor.charcode_of_codepoint(0x00A9),
    Some(0xFD),
  )
  @test.assert_eq(
    gbpc_euc_builtin_extractor.charcode_of_codepoint(0x2122),
    Some(0xFE),
  )
  @test.assert_eq(
    gbpc_euc_builtin_extractor.charcode_of_codepoint(0x2026),
    Some(0xFF),
  )
  @test.assert_eq(
    gbpc_euc_builtin_extractor.charcode_of_codepoint(0x301C),
    Some(0xA1AB),
  )
  @test.assert_eq(
    gbpc_euc_builtin_extractor.charcode_of_codepoint(0x4F60),
    Some(0xC4E3),
  )
  @test.assert_eq(
    gbpc_euc_builtin_extractor.charcode_of_codepoint(0x597D),
    Some(0xBAC3),
  )
  @test.assert_eq(
    gbpc_euc_builtin_extractor.charcode_of_codepoint(0x0300),
    None,
  )
  let gbpc_euc_truncated = try? gbpc_euc_builtin_extractor.codepoints_of_text(
    text_cmap_predefined_bytes_for_test([0xA1]),
  )
  guard gbpc_euc_truncated is Err(BadText) else {
    fail("expected @core.PdfError::BadText for truncated GBpc-EUC charcode")
  }
  let big5_builtin_font : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_predefined_name_for_test("/TopBig5Builtin"),
    composite,
    encoding: PdfPredefinedCMap(
      text_cmap_predefined_name_for_test("/ETen-B5-H"),
    ),
  })
  let big5_builtin_extractor = big5_builtin_font.text_extractor()
  @test.assert_eq(
    big5_builtin_extractor.codepoints_of_text(
      text_cmap_predefined_bytes_for_test([
        0x41, 0xA7, 0x41, 0xA6, 0x6E, 0xA4, 0x40, 0xA4, 0xA4, 0xA1, 0x40,
      ]),
    ),
    [0x41, 0x4F60, 0x597D, 0x4E00, 0x4E2D, 0x3000],
  )
  @test.assert_eq(
    big5_builtin_extractor.codepoints_of_text(
      text_cmap_predefined_bytes_for_test([0x81, 0x40]),
    ),
    [0x8140],
  )
  @test.assert_eq(
    big5_builtin_extractor.charcode_of_codepoint(0x41),
    Some(0x41),
  )
  @test.assert_eq(
    big5_builtin_extractor.charcode_of_codepoint(0x4F60),
    Some(0xA741),
  )
  @test.assert_eq(
    big5_builtin_extractor.charcode_of_codepoint(0x597D),
    Some(0xA66E),
  )
  @test.assert_eq(
    big5_builtin_extractor.charcode_of_codepoint(0x3000),
    Some(0xA140),
  )
  @test.assert_eq(big5_builtin_extractor.charcode_of_codepoint(0x20AC), None)
  let big5_truncated = try? big5_builtin_extractor.codepoints_of_text(
    text_cmap_predefined_bytes_for_test([0xA7]),
  )
  guard big5_truncated is Err(BadText) else {
    fail("expected @core.PdfError::BadText for truncated Big5 charcode")
  }
  let b5pc_builtin_font : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_predefined_name_for_test("/TopB5pcBuiltin"),
    composite,
    encoding: PdfPredefinedCMap(text_cmap_predefined_name_for_test("/B5pc-H")),
  })
  let b5pc_builtin_extractor = b5pc_builtin_font.text_extractor()
  @test.assert_eq(
    b5pc_builtin_extractor.codepoints_of_text(
      text_cmap_predefined_bytes_for_test([
        0x41, 0x80, 0x83, 0xA0, 0xFD, 0xFE, 0xFF, 0xA1, 0x40, 0xA7, 0x41, 0xA6, 0x6E,
        0xA1, 0x4B, 0xA1, 0x51,
      ]),
    ),
    [
      0x41, 0x005C, 0x83, 0x00A0, 0x00A9, 0x2122, 0x2026, 0x3000, 0x4F60, 0x597D,
      0x22EF, 0xFE54,
    ],
  )
  @test.assert_eq(
    b5pc_builtin_extractor.codepoints_of_text(
      text_cmap_predefined_bytes_for_test([0x81, 0x40]),
    ),
    [0x8140],
  )
  @test.assert_eq(
    b5pc_builtin_extractor.charcode_of_codepoint(0x005C),
    Some(0x5C),
  )
  @test.assert_eq(
    b5pc_builtin_extractor.charcode_of_codepoint(0x00A9),
    Some(0xFD),
  )
  @test.assert_eq(
    b5pc_builtin_extractor.charcode_of_codepoint(0x2122),
    Some(0xFE),
  )
  @test.assert_eq(
    b5pc_builtin_extractor.charcode_of_codepoint(0x2026),
    Some(0xFF),
  )
  @test.assert_eq(
    b5pc_builtin_extractor.charcode_of_codepoint(0x22EF),
    Some(0xA14B),
  )
  @test.assert_eq(
    b5pc_builtin_extractor.charcode_of_codepoint(0xFE54),
    Some(0xA151),
  )
  @test.assert_eq(
    b5pc_builtin_extractor.charcode_of_codepoint(0x4F60),
    Some(0xA741),
  )
  @test.assert_eq(
    b5pc_builtin_extractor.charcode_of_codepoint(0x597D),
    Some(0xA66E),
  )
  @test.assert_eq(b5pc_builtin_extractor.charcode_of_codepoint(0x20AC), None)
  let b5pc_truncated = try? b5pc_builtin_extractor.codepoints_of_text(
    text_cmap_predefined_bytes_for_test([0xA1]),
  )
  guard b5pc_truncated is Err(BadText) else {
    fail("expected @core.PdfError::BadText for truncated B5pc charcode")
  }
  let hkscs_builtin_font : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_predefined_name_for_test("/TopHKscsBuiltin"),
    composite,
    encoding: PdfPredefinedCMap(
      text_cmap_predefined_name_for_test("/HKscs-B5-H"),
    ),
  })
  let hkscs_builtin_extractor = hkscs_builtin_font.text_extractor()
  @test.assert_eq(
    hkscs_builtin_extractor.codepoints_of_text(
      text_cmap_predefined_bytes_for_test([
        0x41, 0x87, 0x40, 0x87, 0x45, 0x89, 0x43, 0xA1, 0x40, 0xA7, 0x41, 0xA6, 0x6E,
        0xC6, 0xE4, 0xFE, 0xFE, 0x80,
      ]),
    ),
    [
      0x41, 0x43F0, 0x27267, 0x650A, 0x3000, 0x4F60, 0x597D, 0xFF3B, 0x79D4, 0x80,
    ],
  )
  @test.assert_eq(
    hkscs_builtin_extractor.codepoints_of_text(
      text_cmap_predefined_bytes_for_test([0x81, 0x40]),
    ),
    [0x8140],
  )
  @test.assert_eq(
    hkscs_builtin_extractor.charcode_of_codepoint(0x41),
    Some(0x41),
  )
  @test.assert_eq(
    hkscs_builtin_extractor.charcode_of_codepoint(0x43F0),
    Some(0x8740),
  )
  @test.assert_eq(
    hkscs_builtin_extractor.charcode_of_codepoint(0x27267),
    Some(0x8745),
  )
  @test.assert_eq(
    hkscs_builtin_extractor.charcode_of_codepoint(0x650A),
    Some(0x8943),
  )
  @test.assert_eq(
    hkscs_builtin_extractor.charcode_of_codepoint(0x3000),
    Some(0xA140),
  )
  @test.assert_eq(
    hkscs_builtin_extractor.charcode_of_codepoint(0x4F60),
    Some(0xA741),
  )
  @test.assert_eq(
    hkscs_builtin_extractor.charcode_of_codepoint(0x597D),
    Some(0xA66E),
  )
  @test.assert_eq(
    hkscs_builtin_extractor.charcode_of_codepoint(0xFF3B),
    Some(0xC6E4),
  )
  @test.assert_eq(
    hkscs_builtin_extractor.charcode_of_codepoint(0x79D4),
    Some(0xFEFE),
  )
  @test.assert_eq(hkscs_builtin_extractor.charcode_of_codepoint(0x1F600), None)
  let hkscs_truncated = try? hkscs_builtin_extractor.codepoints_of_text(
    text_cmap_predefined_bytes_for_test([0x87]),
  )
  guard hkscs_truncated is Err(BadText) else {
    fail("expected @core.PdfError::BadText for truncated HKSCS charcode")
  }
  let etenms_b5_builtin_font : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_predefined_name_for_test("/TopETenmsBuiltin"),
    composite,
    encoding: PdfPredefinedCMap(
      text_cmap_predefined_name_for_test("/ETenms-B5-H"),
    ),
  })
  let etenms_b5_builtin_extractor = etenms_b5_builtin_font.text_extractor()
  @test.assert_eq(
    etenms_b5_builtin_extractor.codepoints_of_text(
      text_cmap_predefined_bytes_for_test([
        0x41, 0xA1, 0xC2, 0xA2, 0x41, 0xC7, 0xFD, 0x80,
      ]),
    ),
    [0x41, 0x00AF, 0x2215, 0x0419, 0x80],
  )
  @test.assert_eq(
    etenms_b5_builtin_extractor.codepoints_of_text(
      text_cmap_predefined_bytes_for_test([0x81, 0x40]),
    ),
    [0x8140],
  )
  @test.assert_eq(
    etenms_b5_builtin_extractor.charcode_of_codepoint(0x00AF),
    Some(0xA1C2),
  )
  @test.assert_eq(
    etenms_b5_builtin_extractor.charcode_of_codepoint(0x2215),
    Some(0xA241),
  )
  @test.assert_eq(
    etenms_b5_builtin_extractor.charcode_of_codepoint(0x0419),
    Some(0xC7FD),
  )
  @test.assert_eq(
    etenms_b5_builtin_extractor.charcode_of_codepoint(0x1F600),
    None,
  )
  let etenms_b5_truncated = try? etenms_b5_builtin_extractor.codepoints_of_text(
    text_cmap_predefined_bytes_for_test([0xA1]),
  )
  guard etenms_b5_truncated is Err(BadText) else {
    fail("expected @core.PdfError::BadText for truncated ETenms-B5 charcode")
  }
  let hk_b5_cases : Array[(String, Array[Int], Array[Int], Int, Int)] = [
    (
      "/HKdla-B5-H",
      [0x41, 0xFA, 0x41, 0x80],
      [0x41, 0x5F0D, 0x80],
      0x5F0D,
      0xFA41,
    ),
    (
      "/HKdlb-B5-H",
      [0x41, 0x8E, 0x40, 0x80],
      [0x41, 0x99C4, 0x80],
      0x99C4,
      0x8E40,
    ),
    (
      "/HKgccs-B5-H",
      [0x41, 0x8A, 0x43, 0x80],
      [0x41, 0x20C42, 0x80],
      0x20C42,
      0x8A43,
    ),
    (
      "/HKm314-B5-H",
      [0x41, 0xC7, 0x40, 0x80],
      [0x41, 0x4E21, 0x80],
      0x4E21,
      0xC740,
    ),
    (
      "/HKm471-B5-H",
      [0x41, 0xFA, 0x40, 0x80],
      [0x41, 0x4E21, 0x80],
      0x4E21,
      0xFA40,
    ),
  ]
  for case in hk_b5_cases {
    let hk_b5_font : @pdflite.PdfFont = PdfFontCIDKeyed({
      basefont: text_cmap_predefined_name_for_test("/TopHKB5Builtin"),
      composite,
      encoding: PdfPredefinedCMap(text_cmap_predefined_name_for_test(case.0)),
    })
    let hk_b5_extractor = hk_b5_font.text_extractor()
    @test.assert_eq(
      hk_b5_extractor.codepoints_of_text(
        text_cmap_predefined_bytes_for_test(case.1),
      ),
      case.2,
    )
    @test.assert_eq(hk_b5_extractor.charcode_of_codepoint(case.3), Some(case.4))
  }
  let hkgccs_b5_builtin_font : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_predefined_name_for_test("/TopHKgccsBuiltin"),
    composite,
    encoding: PdfPredefinedCMap(
      text_cmap_predefined_name_for_test("/HKgccs-B5-H"),
    ),
  })
  let hkgccs_b5_builtin_extractor = hkgccs_b5_builtin_font.text_extractor()
  @test.assert_eq(
    hkgccs_b5_builtin_extractor.codepoints_of_text(
      text_cmap_predefined_bytes_for_test([0x81, 0x40]),
    ),
    [0x8140],
  )
  @test.assert_eq(
    hkgccs_b5_builtin_extractor.charcode_of_codepoint(0x1F600),
    None,
  )
  let hkgccs_b5_truncated = try? hkgccs_b5_builtin_extractor.codepoints_of_text(
    text_cmap_predefined_bytes_for_test([0x8A]),
  )
  guard hkgccs_b5_truncated is Err(BadText) else {
    fail("expected @core.PdfError::BadText for truncated HKgccs-B5 charcode")
  }
  let cns_euc_builtin_font : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_predefined_name_for_test("/TopCNSEUCBuiltin"),
    composite,
    encoding: PdfPredefinedCMap(
      text_cmap_predefined_name_for_test("/CNS-EUC-H"),
    ),
  })
  let cns_euc_builtin_extractor = cns_euc_builtin_font.text_extractor()
  @test.assert_eq(
    cns_euc_builtin_extractor.codepoints_of_text(
      text_cmap_predefined_bytes_for_test([
        0x20, 0x80, 0xA1, 0xA1, 0xA1, 0xAC, 0x8E, 0xA2, 0xA1, 0xA1,
      ]),
    ),
    [0x20, 0x80, 0x3000, 0x2026, 0x4E42],
  )
  @test.assert_eq(
    cns_euc_builtin_extractor.charcode_of_codepoint(0x20),
    Some(0x20),
  )
  @test.assert_eq(
    cns_euc_builtin_extractor.charcode_of_codepoint(0x3000),
    Some(0xA1A1),
  )
  @test.assert_eq(
    cns_euc_builtin_extractor.charcode_of_codepoint(0x2026),
    Some(0xA1AC),
  )
  @test.assert_eq(
    cns_euc_builtin_extractor.charcode_of_codepoint(0x4E42),
    Some(0x8EA2A1A1),
  )
  @test.assert_eq(
    cns_euc_builtin_extractor.charcode_of_codepoint(0x1F600),
    None,
  )
  let cns_euc_vertical_font : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_predefined_name_for_test("/TopCNSEUCVerticalBuiltin"),
    composite,
    encoding: PdfPredefinedCMap(
      text_cmap_predefined_name_for_test("/CNS-EUC-V"),
    ),
  })
  let cns_euc_vertical_extractor = cns_euc_vertical_font.text_extractor()
  @test.assert_eq(
    cns_euc_vertical_extractor.codepoints_of_text(
      text_cmap_predefined_bytes_for_test([0xA1, 0xAC, 0x8E, 0xA1, 0xA1, 0xAC]),
    ),
    [0xFE19, 0xFE19],
  )
  @test.assert_eq(
    cns_euc_vertical_extractor.charcode_of_codepoint(0xFE19),
    Some(0xA1AC),
  )
  let cns_euc_truncated = try? cns_euc_builtin_extractor.codepoints_of_text(
    text_cmap_predefined_bytes_for_test([0x8E, 0xA1, 0xA1]),
  )
  guard cns_euc_truncated is Err(BadText) else {
    fail("expected @core.PdfError::BadText for truncated CNS-EUC charcode")
  }
  let uhc_builtin_font : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_predefined_name_for_test("/TopUHCBuiltin"),
    composite,
    encoding: PdfPredefinedCMap(
      text_cmap_predefined_name_for_test("/KSCms-UHC-H"),
    ),
  })
  let uhc_builtin_extractor = uhc_builtin_font.text_extractor()
  @test.assert_eq(
    uhc_builtin_extractor.codepoints_of_text(
      text_cmap_predefined_bytes_for_test([
        0x41, 0xB0, 0xA1, 0xC7, 0xD1, 0xB1, 0xDB, 0x81, 0x41, 0xA4, 0xD4,
      ]),
    ),
    [0x41, 0xAC00, 0xD55C, 0xAE00, 0xAC02, 0x3164],
  )
  @test.assert_eq(
    uhc_builtin_extractor.codepoints_of_text(
      text_cmap_predefined_bytes_for_test([0x81, 0x40]),
    ),
    [0x8140],
  )
  @test.assert_eq(uhc_builtin_extractor.charcode_of_codepoint(0x41), Some(0x41))
  @test.assert_eq(
    uhc_builtin_extractor.charcode_of_codepoint(0xAC00),
    Some(0xB0A1),
  )
  @test.assert_eq(
    uhc_builtin_extractor.charcode_of_codepoint(0xD55C),
    Some(0xC7D1),
  )
  @test.assert_eq(
    uhc_builtin_extractor.charcode_of_codepoint(0xAC02),
    Some(0x8141),
  )
  @test.assert_eq(
    uhc_builtin_extractor.charcode_of_codepoint(0x3164),
    Some(0xA4D4),
  )
  @test.assert_eq(uhc_builtin_extractor.charcode_of_codepoint(0x1F600), None)
  let uhc_truncated = try? uhc_builtin_extractor.codepoints_of_text(
    text_cmap_predefined_bytes_for_test([0x81]),
  )
  guard uhc_truncated is Err(BadText) else {
    fail("expected @core.PdfError::BadText for truncated UHC charcode")
  }
  let uhc_hw_builtin_font : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_predefined_name_for_test("/TopUHCHWBuiltin"),
    composite,
    encoding: PdfPredefinedCMap(
      text_cmap_predefined_name_for_test("/KSCms-UHC-HW-H"),
    ),
  })
  let uhc_hw_builtin_extractor = uhc_hw_builtin_font.text_extractor()
  @test.assert_eq(
    uhc_hw_builtin_extractor.codepoints_of_text(
      text_cmap_predefined_bytes_for_test([0xB0, 0xA1, 0xA4, 0xD4]),
    ),
    [0xAC00, 0x3164],
  )
  @test.assert_eq(
    uhc_hw_builtin_extractor.charcode_of_codepoint(0xAC00),
    Some(0xB0A1),
  )
  @test.assert_eq(
    uhc_hw_builtin_extractor.charcode_of_codepoint(0x3164),
    Some(0xA4D4),
  )
  let gbk_builtin_font : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_predefined_name_for_test("/TopGBKBuiltin"),
    composite,
    encoding: PdfPredefinedCMap(
      text_cmap_predefined_name_for_test("/GBK-EUC-H"),
    ),
  })
  let gbk_builtin_extractor = gbk_builtin_font.text_extractor()
  @test.assert_eq(
    gbk_builtin_extractor.codepoints_of_text(
      text_cmap_predefined_bytes_for_test([
        0x41, 0x80, 0x81, 0x40, 0xC4, 0xE3, 0xBA, 0xC3, 0xA1, 0xA1, 0xA3, 0xC1, 0xA1,
        0x40, 0xA8, 0xBC, 0xFE, 0xFE, 0xFF,
      ]),
    ),
    [
      0x41, 0x80, 0x4E02, 0x4F60, 0x597D, 0x3000, 0xFF21, 0xE4C6, 0x1E3F, 0xE4C5,
      0xF8F5,
    ],
  )
  @test.assert_eq(
    gbk_builtin_extractor.codepoints_of_text(
      text_cmap_predefined_bytes_for_test([0x81, 0x39]),
    ),
    [0x8139],
  )
  @test.assert_eq(gbk_builtin_extractor.charcode_of_codepoint(0x41), Some(0x41))
  @test.assert_eq(gbk_builtin_extractor.charcode_of_codepoint(0x80), Some(0x80))
  @test.assert_eq(
    gbk_builtin_extractor.charcode_of_codepoint(0x4E02),
    Some(0x8140),
  )
  @test.assert_eq(
    gbk_builtin_extractor.charcode_of_codepoint(0x4F60),
    Some(0xC4E3),
  )
  @test.assert_eq(
    gbk_builtin_extractor.charcode_of_codepoint(0x597D),
    Some(0xBAC3),
  )
  @test.assert_eq(
    gbk_builtin_extractor.charcode_of_codepoint(0xE4C6),
    Some(0xA140),
  )
  @test.assert_eq(
    gbk_builtin_extractor.charcode_of_codepoint(0x1E3F),
    Some(0xA8BC),
  )
  @test.assert_eq(
    gbk_builtin_extractor.charcode_of_codepoint(0xE4C5),
    Some(0xFEFE),
  )
  @test.assert_eq(
    gbk_builtin_extractor.charcode_of_codepoint(0xF8F5),
    Some(0xFF),
  )
  @test.assert_eq(gbk_builtin_extractor.charcode_of_codepoint(0x1F600), None)
  let gbk_truncated = try? gbk_builtin_extractor.codepoints_of_text(
    text_cmap_predefined_bytes_for_test([0x81]),
  )
  guard gbk_truncated is Err(BadText) else {
    fail("expected @core.PdfError::BadText for truncated GBK charcode")
  }
  let gbkp_builtin_font : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_predefined_name_for_test("/TopGBKpBuiltin"),
    composite,
    encoding: PdfPredefinedCMap(
      text_cmap_predefined_name_for_test("/GBKp-EUC-H"),
    ),
  })
  let gbkp_builtin_extractor = gbkp_builtin_font.text_extractor()
  @test.assert_eq(
    gbkp_builtin_extractor.codepoints_of_text(
      text_cmap_predefined_bytes_for_test([
        0x41, 0x80, 0x81, 0x40, 0xC4, 0xE3, 0xFF, 0x81, 0x39,
      ]),
    ),
    [0x41, 0x80, 0x4E02, 0x4F60, 0xF8F5, 0x8139],
  )
  @test.assert_eq(
    gbkp_builtin_extractor.charcode_of_codepoint(0x4E02),
    Some(0x8140),
  )
  @test.assert_eq(
    gbkp_builtin_extractor.charcode_of_codepoint(0x4F60),
    Some(0xC4E3),
  )
  @test.assert_eq(
    gbkp_builtin_extractor.charcode_of_codepoint(0xF8F5),
    Some(0xFF),
  )
  @test.assert_eq(gbkp_builtin_extractor.charcode_of_codepoint(0x1F600), None)
  let gbkp_truncated = try? gbkp_builtin_extractor.codepoints_of_text(
    text_cmap_predefined_bytes_for_test([0x81]),
  )
  guard gbkp_truncated is Err(BadText) else {
    fail("expected @core.PdfError::BadText for truncated GBKp charcode")
  }
  let gbk2k_builtin_font : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_predefined_name_for_test("/TopGBK2KBuiltin"),
    composite,
    encoding: PdfPredefinedCMap(text_cmap_predefined_name_for_test("/GBK2K-H")),
  })
  let gbk2k_builtin_extractor = gbk2k_builtin_font.text_extractor()
  @test.assert_eq(
    gbk2k_builtin_extractor.codepoints_of_text(
      text_cmap_predefined_bytes_for_test([
        0x41, 0x81, 0x40, 0xC4, 0xE3, 0xBA, 0xC3, 0xFE, 0x51, 0x81, 0x30, 0x84, 0x36,
        0x82, 0x36, 0x94, 0x35,
      ]),
    ),
    [0x41, 0x4E02, 0x4F60, 0x597D, 0x20087, 0x00A5, 0xA4C6],
  )
  @test.assert_eq(
    gbk2k_builtin_extractor.codepoints_of_text(
      text_cmap_predefined_bytes_for_test([0x81, 0x30, 0x81, 0x30]),
    ),
    [0x81308130],
  )
  @test.assert_eq(
    gbk2k_builtin_extractor.codepoints_of_text(
      text_cmap_predefined_bytes_for_test([0x80, 0x40]),
    ),
    [0x8040],
  )
  @test.assert_eq(
    gbk2k_builtin_extractor.charcode_of_codepoint(0x41),
    Some(0x41),
  )
  @test.assert_eq(
    gbk2k_builtin_extractor.charcode_of_codepoint(0x4E02),
    Some(0x8140),
  )
  @test.assert_eq(
    gbk2k_builtin_extractor.charcode_of_codepoint(0x4F60),
    Some(0xC4E3),
  )
  @test.assert_eq(
    gbk2k_builtin_extractor.charcode_of_codepoint(0x597D),
    Some(0xBAC3),
  )
  @test.assert_eq(
    gbk2k_builtin_extractor.charcode_of_codepoint(0x20087),
    Some(0xFE51),
  )
  @test.assert_eq(
    gbk2k_builtin_extractor.charcode_of_codepoint(0x00A5),
    Some(0x81308436),
  )
  @test.assert_eq(
    gbk2k_builtin_extractor.charcode_of_codepoint(0xA4C6),
    Some(0x82369435),
  )
  @test.assert_eq(gbk2k_builtin_extractor.charcode_of_codepoint(0x1F600), None)
  let gbk2k_truncated = try? gbk2k_builtin_extractor.codepoints_of_text(
    text_cmap_predefined_bytes_for_test([0x81, 0x30, 0x81]),
  )
  guard gbk2k_truncated is Err(BadText) else {
    fail("expected @core.PdfError::BadText for truncated GBK2K charcode")
  }
  let ksc_euc_builtin_font : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_predefined_name_for_test("/TopKSCEUCBuiltin"),
    composite,
    encoding: PdfPredefinedCMap(
      text_cmap_predefined_name_for_test("/KSC-EUC-H"),
    ),
  })
  let ksc_euc_builtin_extractor = ksc_euc_builtin_font.text_extractor()
  @test.assert_eq(
    ksc_euc_builtin_extractor.codepoints_of_text(
      text_cmap_predefined_bytes_for_test([
        0x41, 0x7E, 0xA1, 0xA1, 0xB0, 0xA1, 0xC7, 0xD1, 0x80,
      ]),
    ),
    [0x41, 0x203E, 0x3000, 0xAC00, 0xD55C, 0x80],
  )
  @test.assert_eq(
    ksc_euc_builtin_extractor.codepoints_of_text(
      text_cmap_predefined_bytes_for_test([0xA4, 0xD4]),
    ),
    [0xA4D4],
  )
  @test.assert_eq(
    ksc_euc_builtin_extractor.charcode_of_codepoint(0x41),
    Some(0x41),
  )
  @test.assert_eq(
    ksc_euc_builtin_extractor.charcode_of_codepoint(0x203E),
    Some(0x7E),
  )
  @test.assert_eq(
    ksc_euc_builtin_extractor.charcode_of_codepoint(0x3000),
    Some(0xA1A1),
  )
  @test.assert_eq(
    ksc_euc_builtin_extractor.charcode_of_codepoint(0xAC00),
    Some(0xB0A1),
  )
  @test.assert_eq(
    ksc_euc_builtin_extractor.charcode_of_codepoint(0xD55C),
    Some(0xC7D1),
  )
  @test.assert_eq(
    ksc_euc_builtin_extractor.charcode_of_codepoint(0x4E0D),
    Some(0xDCF4),
  )
  @test.assert_eq(ksc_euc_builtin_extractor.charcode_of_codepoint(0x3164), None)
  let ksc_euc_truncated = try? ksc_euc_builtin_extractor.codepoints_of_text(
    text_cmap_predefined_bytes_for_test([0xA1]),
  )
  guard ksc_euc_truncated is Err(BadText) else {
    fail("expected @core.PdfError::BadText for truncated KSC-EUC charcode")
  }
  let kscpc_euc_builtin_font : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_predefined_name_for_test("/TopKSCpcEUCBuiltin"),
    composite,
    encoding: PdfPredefinedCMap(
      text_cmap_predefined_name_for_test("/KSCpc-EUC-H"),
    ),
  })
  let kscpc_euc_builtin_extractor = kscpc_euc_builtin_font.text_extractor()
  @test.assert_eq(
    kscpc_euc_builtin_extractor.codepoints_of_text(
      text_cmap_predefined_bytes_for_test([
        0x41, 0x80, 0x81, 0x84, 0x9F, 0xFE, 0xFF, 0xA1, 0x41, 0xA1, 0x51, 0xA2, 0xE6,
        0xA2, 0xEF, 0xB0, 0xA1, 0xC7, 0xD1,
      ]),
    ),
    [
      0x41, 0x00A0, 0x20A9, 0xFF3F, 0x9F, 0x2122, 0x22EF, 0x300C, 0x28, 0x28, 0x31,
      0x20DE, 0x5B, 0x31, 0x30, 0x5D, 0xAC00, 0xD55C,
    ],
  )
  @test.assert_eq(
    kscpc_euc_builtin_extractor.codepoints_of_text(
      text_cmap_predefined_bytes_for_test([0xA1, 0x40]),
    ),
    [0xA140],
  )
  @test.assert_eq(
    kscpc_euc_builtin_extractor.charcode_of_codepoint(0x28),
    Some(0x28),
  )
  @test.assert_eq(
    kscpc_euc_builtin_extractor.charcode_of_codepoint(0x20A9),
    Some(0x81),
  )
  @test.assert_eq(
    kscpc_euc_builtin_extractor.charcode_of_codepoint(0xFF3F),
    Some(0x84),
  )
  @test.assert_eq(
    kscpc_euc_builtin_extractor.charcode_of_codepoint(0x2122),
    Some(0xFE),
  )
  @test.assert_eq(
    kscpc_euc_builtin_extractor.charcode_of_codepoint(0x22EF),
    Some(0xFF),
  )
  @test.assert_eq(
    kscpc_euc_builtin_extractor.charcode_of_codepoint(0x300C),
    Some(0xA141),
  )
  @test.assert_eq(
    kscpc_euc_builtin_extractor.charcode_of_codepoint(0xAC00),
    Some(0xB0A1),
  )
  @test.assert_eq(
    kscpc_euc_builtin_extractor.charcode_of_codepoint(0x20DE),
    None,
  )
  let kscpc_euc_truncated = try? kscpc_euc_builtin_extractor.codepoints_of_text(
    text_cmap_predefined_bytes_for_test([0xA1]),
  )
  guard kscpc_euc_truncated is Err(BadText) else {
    fail("expected @core.PdfError::BadText for truncated KSCpc-EUC charcode")
  }
  let vertical_builtin_cases : Array[(String, Array[Int], Array[Int], Int, Int)] = [
    ("/GB-EUC-V", [0xA1, 0xA2], [0x3001], 0x3001, 0xA1A2),
    ("/GBpc-EUC-V", [0xA1, 0xA2], [0x3001], 0x3001, 0xA1A2),
    ("/GBK-EUC-V", [0xA1, 0xA2], [0x3001], 0x3001, 0xA1A2),
    ("/GBKp-EUC-V", [0xA1, 0xA2], [0x3001], 0x3001, 0xA1A2),
    ("/GBK2K-V", [0xA4, 0xC3], [0x3064], 0x3064, 0xA4C3),
    ("/B5-V", [0xA1, 0x4B], [0xFE19], 0xFE19, 0xA14B),
    ("/B5pc-V", [0xA1, 0x4B], [0xFE19], 0xFE19, 0xA14B),
    ("/ETen-B5-V", [0xA1, 0x4B], [0xFE19], 0xFE19, 0xA14B),
    ("/ETenms-B5-V", [0xA1, 0x4C], [0xFE30], 0xFE30, 0xA14C),
    ("/HKdla-B5-V", [0xA1, 0x4B], [0xFE19], 0xFE19, 0xA14B),
    ("/HKdlb-B5-V", [0xA1, 0x4B], [0xFE19], 0xFE19, 0xA14B),
    ("/HKgccs-B5-V", [0xA1, 0x4B], [0xFE19], 0xFE19, 0xA14B),
    ("/HKm314-B5-V", [0xA1, 0x4B], [0xFE19], 0xFE19, 0xA14B),
    ("/HKm471-B5-V", [0xA1, 0x4B], [0xFE19], 0xFE19, 0xA14B),
    ("/HKscs-B5-V", [0xA1, 0x4B], [0xFE19], 0xFE19, 0xA14B),
    ("/KSC-EUC-V", [0xA1, 0xA6], [0x22EF], 0x22EF, 0xA1A6),
    ("/KSCpc-EUC-V", [0xA1, 0xA6], [0x22EF], 0x22EF, 0xA1A6),
    ("/KSCms-UHC-V", [0xA1, 0xA6], [0x22EF], 0x22EF, 0xA1A6),
    ("/KSCms-UHC-HW-V", [0xA1, 0xA6], [0x22EF], 0x22EF, 0xA1A6),
  ]
  for case in vertical_builtin_cases {
    let vertical_builtin_font : @pdflite.PdfFont = PdfFontCIDKeyed({
      basefont: text_cmap_predefined_name_for_test("/TopVerticalBuiltin"),
      composite,
      encoding: PdfPredefinedCMap(text_cmap_predefined_name_for_test(case.0)),
    })
    let vertical_builtin_extractor = vertical_builtin_font.text_extractor()
    @test.assert_eq(
      vertical_builtin_extractor.codepoints_of_text(
        text_cmap_predefined_bytes_for_test(case.1),
      ),
      case.2,
    )
    @test.assert_eq(
      vertical_builtin_extractor.charcode_of_codepoint(case.3),
      Some(case.4),
    )
  }
  let rksj_tounicode_descriptor : @pdflite.PdfFontDescriptor = {
    ..text_cmap_predefined_font_descriptor_for_test(),
    tounicode: Some([
      (0x8140, text_cmap_predefined_bytes_for_test([0x4E, 0x8C])),
      (0xA6, text_cmap_predefined_bytes_for_test([0xFF, 0x66])),
    ]),
  }
  let rksj_tounicode_font : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_predefined_name_for_test("/TopRKSJToUnicode"),
    composite: { ..composite, cid_fontdescriptor: rksj_tounicode_descriptor },
    encoding: PdfPredefinedCMap(
      text_cmap_predefined_name_for_test("/90ms-RKSJ-H"),
    ),
  })
  @test.assert_eq(
    try! rksj_tounicode_font
    .text_extractor()
    .codepoints_of_text(text_cmap_predefined_bytes_for_test([0x81, 0x40, 0xA6])),
    [0x4E8C, 0xFF66],
  )
  let rksj_builtin_font : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_predefined_name_for_test("/TopRKSJBuiltin"),
    composite,
    encoding: PdfPredefinedCMap(
      text_cmap_predefined_name_for_test("/90ms-RKSJ-H"),
    ),
  })
  let rksj_builtin_extractor = rksj_builtin_font.text_extractor()
  @test.assert_eq(
    rksj_builtin_extractor.codepoints_of_text(
      text_cmap_predefined_bytes_for_test([0x41, 0xA6, 0x81, 0x40]),
    ),
    [0x41, 0xFF66, 0x3000],
  )
  @test.assert_eq(
    rksj_builtin_extractor.charcode_of_codepoint(0x41),
    Some(0x41),
  )
  @test.assert_eq(
    rksj_builtin_extractor.charcode_of_codepoint(0xFF66),
    Some(0xA6),
  )
  @test.assert_eq(
    rksj_builtin_extractor.charcode_of_codepoint(0x20AC),
    Some(0x80),
  )
  @test.assert_eq(
    rksj_builtin_extractor.charcode_of_codepoint(0x3000),
    Some(0x8140),
  )
  @test.assert_eq(
    rksj_builtin_extractor.charcode_of_codepoint(0x4E8C),
    Some(0x93F1),
  )
  let rksj_truncated = try? rksj_builtin_extractor.codepoints_of_text(
    text_cmap_predefined_bytes_for_test([0x81]),
  )
  guard rksj_truncated is Err(_) else {
    fail("expected malformed RKSJ charcode")
  }
  let pv_rksj_builtin_font : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_predefined_name_for_test("/Top90pvRKSJBuiltin"),
    composite,
    encoding: PdfPredefinedCMap(
      text_cmap_predefined_name_for_test("/90pv-RKSJ-H"),
    ),
  })
  let pv_rksj_builtin_extractor = pv_rksj_builtin_font.text_extractor()
  @test.assert_eq(
    pv_rksj_builtin_extractor.codepoints_of_text(
      text_cmap_predefined_bytes_for_test([
        0x5C, 0x80, 0xA0, 0x81, 0x7C, 0x85, 0x91,
      ]),
    ),
    [0x00A5, 0x005C, 0x00A0, 0x2212, 0xF860, 0x0030, 0x002E],
  )
  @test.assert_eq(
    pv_rksj_builtin_extractor.charcode_of_codepoint(0x00A5),
    Some(0x5C),
  )
  @test.assert_eq(
    pv_rksj_builtin_extractor.charcode_of_codepoint(0x005C),
    Some(0x80),
  )
  @test.assert_eq(
    pv_rksj_builtin_extractor.charcode_of_codepoint(0x2212),
    Some(0x817C),
  )
  @test.assert_eq(pv_rksj_builtin_extractor.charcode_of_codepoint(0xF860), None)
  let jis_builtin_font : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_predefined_name_for_test("/TopJISBuiltin"),
    composite,
    encoding: PdfPredefinedCMap(text_cmap_predefined_name_for_test("/H")),
  })
  @test.assert_eq(jis_builtin_font.uses_two_byte_codes(), true)
  let jis_builtin_extractor = jis_builtin_font.text_extractor()
  @test.assert_eq(
    jis_builtin_extractor.codepoints_of_text(
      text_cmap_predefined_bytes_for_test([0x21, 0x21, 0x24, 0x22]),
    ),
    [0x3000, 0x3042],
  )
  @test.assert_eq(
    jis_builtin_extractor.charcode_of_codepoint(0x3042),
    Some(0x2422),
  )
  let jis_truncated = try? jis_builtin_extractor.codepoints_of_text(
    text_cmap_predefined_bytes_for_test([0x21]),
  )
  guard jis_truncated is Err(BadText) else {
    fail("expected @core.PdfError::BadText for truncated JIS charcode")
  }
  let japan_euc_builtin_font : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_predefined_name_for_test("/TopJapanEUCBuiltin"),
    composite,
    encoding: PdfPredefinedCMap(text_cmap_predefined_name_for_test("/EUC-H")),
  })
  let japan_euc_builtin_extractor = japan_euc_builtin_font.text_extractor()
  @test.assert_eq(
    japan_euc_builtin_extractor.codepoints_of_text(
      text_cmap_predefined_bytes_for_test([0xA1, 0xA1, 0xA4, 0xA2]),
    ),
    [0x3000, 0x3042],
  )
  @test.assert_eq(
    japan_euc_builtin_extractor.charcode_of_codepoint(0x3042),
    Some(0xA4A2),
  )
  let hojo_euc_builtin_font : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_predefined_name_for_test("/TopHojoEUCBuiltin"),
    composite,
    encoding: PdfPredefinedCMap(
      text_cmap_predefined_name_for_test("/Hojo-EUC-H"),
    ),
  })
  let hojo_euc_builtin_extractor = hojo_euc_builtin_font.text_extractor()
  @test.assert_eq(
    hojo_euc_builtin_extractor.codepoints_of_text(
      text_cmap_predefined_bytes_for_test([0x8F, 0xB4, 0xAE]),
    ),
    [0x4EDD],
  )
  @test.assert_eq(
    hojo_euc_builtin_extractor.charcode_of_codepoint(0x4EDD),
    Some(0x8FB4AE),
  )
  let hojo_euc_truncated = try? hojo_euc_builtin_extractor.codepoints_of_text(
    text_cmap_predefined_bytes_for_test([0x8F, 0xB4]),
  )
  guard hojo_euc_truncated is Err(BadText) else {
    fail("expected @core.PdfError::BadText for truncated Hojo-EUC charcode")
  }
  let rare_japan1_predefined_cases = [
    ("/78-H", [0x21, 0x21, 0x24, 0x22], [0x3000, 0x3042], 0x3042, 0x2422, true),
    ("/78-V", [0x21, 0x21, 0x24, 0x21], [0x3000, 0x3041], 0x3041, 0x2421, true),
    (
      "/78-RKSJ-H",
      [0x81, 0x40, 0x82, 0xA0],
      [0x3000, 0x3042],
      0x3042,
      0x82A0,
      false,
    ),
    (
      "/78-RKSJ-V",
      [0x81, 0x40, 0x82, 0x9F],
      [0x3000, 0x3041],
      0x3041,
      0x829F,
      false,
    ),
    (
      "/78ms-RKSJ-H",
      [0x81, 0x40, 0x82, 0xA0],
      [0x3000, 0x3042],
      0x3042,
      0x82A0,
      false,
    ),
    (
      "/78ms-RKSJ-V",
      [0x81, 0x40, 0x82, 0x9F],
      [0x3000, 0x3041],
      0x3041,
      0x829F,
      false,
    ),
    (
      "/83pv-RKSJ-H",
      [0x80, 0x81, 0x40, 0x82, 0xA0],
      [0x005C, 0x3000, 0x3042],
      0x005C,
      0x80,
      false,
    ),
    (
      "/90ms-RKSJ-V",
      [0x81, 0x40, 0x82, 0x9F],
      [0x3000, 0x3041],
      0x3041,
      0x829F,
      false,
    ),
    (
      "/90msp-RKSJ-H",
      [0x41, 0x5C, 0xA6, 0x81, 0x40, 0x93, 0xF1],
      [0x41, 0x00A5, 0xFF66, 0x3000, 0x4E8C],
      0x00A5,
      0x5C,
      false,
    ),
    (
      "/90msp-RKSJ-V",
      [0x41, 0x5C, 0xA6, 0x81, 0x40, 0x82, 0x9F, 0x93, 0xF1],
      [0x41, 0x00A5, 0xFF66, 0x3000, 0x3041, 0x4E8C],
      0x3041,
      0x829F,
      false,
    ),
    (
      "/90pv-RKSJ-V",
      [0x80, 0x81, 0x40, 0x82, 0x9F],
      [0x005C, 0x3000, 0x3041],
      0x005C,
      0x80,
      false,
    ),
    (
      "/RKSJ-H",
      [0x81, 0x40, 0x82, 0xA0],
      [0x3000, 0x3042],
      0x3042,
      0x82A0,
      false,
    ),
    (
      "/RKSJ-V",
      [0x81, 0x40, 0x82, 0x9F],
      [0x3000, 0x3041],
      0x3041,
      0x829F,
      false,
    ),
    (
      "/78-EUC-H",
      [0xA1, 0xA1, 0xA4, 0xA2],
      [0x3000, 0x3042],
      0x3042,
      0xA4A2,
      false,
    ),
    (
      "/78-EUC-V",
      [0xA1, 0xA1, 0xA4, 0xA1],
      [0x3000, 0x3041],
      0x3041,
      0xA4A1,
      false,
    ),
    (
      "/EUC-V",
      [0xA1, 0xA1, 0xA4, 0xA1],
      [0x3000, 0x3041],
      0x3041,
      0xA4A1,
      false,
    ),
    ("/Add-H", [0x28, 0x21, 0x24, 0x22], [0x2500, 0x3042], 0x2500, 0x2821, true),
    ("/Add-V", [0x28, 0x21, 0x24, 0x21], [0x2500, 0x3041], 0x3041, 0x2421, true),
    (
      "/Add-RKSJ-H",
      [0x84, 0x9F, 0x82, 0xA0],
      [0x2500, 0x3042],
      0x2500,
      0x849F,
      false,
    ),
    (
      "/Add-RKSJ-V",
      [0x84, 0x9F, 0x82, 0x9F],
      [0x2500, 0x3041],
      0x3041,
      0x829F,
      false,
    ),
    ("/Ext-H", [0x2C, 0x24, 0x24, 0x22], [0x2500, 0x3042], 0x3042, 0x2422, true),
    ("/Ext-V", [0x2C, 0x24, 0x24, 0x21], [0x2500, 0x3041], 0x3041, 0x2421, true),
    (
      "/Ext-RKSJ-H",
      [0x86, 0xA2, 0x82, 0xA0],
      [0x2500, 0x3042],
      0x3042,
      0x82A0,
      false,
    ),
    (
      "/Ext-RKSJ-V",
      [0x86, 0xA2, 0x82, 0x9F],
      [0x2500, 0x3041],
      0x3041,
      0x829F,
      false,
    ),
    ("/Hojo-H", [0x34, 0x2E], [0x4EDD], 0x4EDD, 0x342E, true),
    ("/Hojo-V", [0x34, 0x2E], [0x4EDD], 0x4EDD, 0x342E, true),
    ("/Hojo-EUC-V", [0x8F, 0xB4, 0xAE], [0x4EDD], 0x4EDD, 0x8FB4AE, false),
    (
      "/NWP-H",
      [0x2E, 0x21, 0x2C, 0x24, 0x24, 0x22],
      [0xFF01, 0x2500, 0x3042],
      0x3042,
      0x2422,
      true,
    ),
    ("/NWP-V", [0x2E, 0x21, 0x24, 0x21], [0xFF01, 0x3041], 0x3041, 0x2421, true),
  ]
  for case in rare_japan1_predefined_cases {
    let rare_japan1_font : @pdflite.PdfFont = PdfFontCIDKeyed({
      basefont: text_cmap_predefined_name_for_test("/TopRareJapan1Builtin"),
      composite,
      encoding: PdfPredefinedCMap(text_cmap_predefined_name_for_test(case.0)),
    })
    @test.assert_eq(rare_japan1_font.uses_two_byte_codes(), case.5)
    let rare_japan1_extractor = rare_japan1_font.text_extractor()
    @test.assert_eq(
      rare_japan1_extractor.codepoints_of_text(
        text_cmap_predefined_bytes_for_test(case.1),
      ),
      case.2,
    )
    @test.assert_eq(
      rare_japan1_extractor.charcode_of_codepoint(case.3),
      Some(case.4),
    )
    @test.assert_eq(rare_japan1_extractor.charcode_of_codepoint(0x1F600), None)
  }
  let external_cmap_font : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_predefined_name_for_test("/ExternalCMap"),
    composite,
    encoding: PdfCMap(7),
  })
  let external_extractor = external_cmap_font.text_extractor()
  @test.assert_eq(
    try! external_extractor.codepoints_of_text(
      text_cmap_predefined_bytes_for_test([0x00, 0x42]),
    ),
    [0x00, 0x42],
  )
  @test.assert_eq(external_extractor.charcode_of_codepoint(0x42), None)
}
