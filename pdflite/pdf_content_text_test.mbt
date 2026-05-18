///|
fn content_text_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn content_text_bytes_for_test(values : ArrayView[Int]) -> @pdflite.PdfBytes {
  try! @pdflite.pdf_bytes_of_int_array(values)
}

///|
fn content_text_assert_close_for_test(
  actual : Double,
  expected : Double,
) -> Unit raise {
  if (actual - expected).abs() > 0.000000001 {
    fail("expected " + expected.to_string() + ", got " + actual.to_string())
  }
}

///|
fn content_text_assert_matrix_close_for_test(
  actual : @pdflite.TransformMatrix,
  expected : @pdflite.TransformMatrix,
) -> Unit raise {
  content_text_assert_close_for_test(actual.a, expected.a)
  content_text_assert_close_for_test(actual.b, expected.b)
  content_text_assert_close_for_test(actual.c, expected.c)
  content_text_assert_close_for_test(actual.d, expected.d)
  content_text_assert_close_for_test(actual.e, expected.e)
  content_text_assert_close_for_test(actual.f, expected.f)
}

///|
fn content_text_assert_bbox_close_for_test(
  actual : @pdflite.PdfContentBoundingBox,
  expected : @pdflite.PdfContentBoundingBox,
) -> Unit raise {
  content_text_assert_close_for_test(actual.x0, expected.x0)
  content_text_assert_close_for_test(actual.y0, expected.y0)
  content_text_assert_close_for_test(actual.x1, expected.x1)
  content_text_assert_close_for_test(actual.y1, expected.y1)
  content_text_assert_close_for_test(actual.x2, expected.x2)
  content_text_assert_close_for_test(actual.y2, expected.y2)
  content_text_assert_close_for_test(actual.x3, expected.x3)
  content_text_assert_close_for_test(actual.y3, expected.y3)
}

///|
fn content_text_font_descriptor_for_test() -> @pdflite.PdfFontDescriptor {
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
fn content_text_cid_font_for_test() -> @pdflite.PdfFont {
  content_text_cid_font_with_descriptor_for_test(
    content_text_font_descriptor_for_test(),
  )
}

///|
fn content_text_cid_font_with_descriptor_for_test(
  descriptor : @pdflite.PdfFontDescriptor,
) -> @pdflite.PdfFont {
  PdfFontCIDKeyed({
    basefont: content_text_name_for_test("/Top"),
    composite: {
      cid_system_info: {
        registry: content_text_bytes_for_test([82]),
        ordering: content_text_bytes_for_test([79]),
        supplement: 0,
      },
      cid_basefont: content_text_name_for_test("/Descendant"),
      cid_fontdescriptor: descriptor,
      cid_widths: [],
      cid_widths2: [],
      cid_default_width: 1000.0,
      cid_default_width2: [880.0, -1000.0],
    },
    encoding: PdfCMap(7),
  })
}

///|
test "cpdfcontent charcodes split raw bytes by font kind" {
  let standard : @pdflite.PdfFont = PdfFontStandard({
    font: PdfHelvetica,
    encoding: PdfWinAnsiEncoding,
  })
  let simple : @pdflite.PdfFont = PdfFontSimple({
    fonttype: PdfType1,
    basefont: None,
    firstchar: 0,
    lastchar: 255,
    widths: [],
    fontdescriptor: None,
    fontmetrics: None,
    encoding: PdfWinAnsiEncoding,
  })
  let one_byte_codes = [65, 0, 255]
  let one_byte_text = content_text_bytes_for_test(one_byte_codes)
  @test.assert_eq(
    standard.content_charcodes_of_bytes(one_byte_text),
    one_byte_codes,
  )
  @test.assert_eq(
    simple.content_charcodes_of_bytes(one_byte_text),
    one_byte_codes,
  )
  @test.assert_eq(
    @pdflite.pdf_content_charcodes_of_bytes(one_byte_text, standard),
    one_byte_codes,
  )
  let cid = content_text_cid_font_for_test()
  @test.assert_eq(
    cid.content_charcodes_of_bytes(
      content_text_bytes_for_test([0x01, 0x02, 0x20, 0xAC]),
    ),
    [0x0102, 0x20AC],
  )
  @test.assert_eq(
    cid.content_charcodes_of_bytes(content_text_bytes_for_test([0x01])),
    [],
  )
}

///|
test "cpdfcontent charcode bytes mirror glyph JSON byte construction" {
  let standard : @pdflite.PdfFont = PdfFontStandard({
    font: PdfHelvetica,
    encoding: PdfWinAnsiEncoding,
  })
  @test.assert_eq(
    @pdflite.pdf_int_array_of_bytes(
      try! standard.content_bytes_of_charcode(255),
    ),
    [255],
  )
  @test.assert_eq(
    @pdflite.pdf_int_array_of_bytes(
      try! @pdflite.pdf_content_bytes_of_charcode(standard, 65),
    ),
    [65],
  )
  let cid = content_text_cid_font_for_test()
  @test.assert_eq(
    @pdflite.pdf_int_array_of_bytes(try! cid.content_bytes_of_charcode(0x20AC)),
    [0x20, 0xAC],
  )
  let one_byte_overflow : Result[@pdflite.PdfBytes, Error] = try? standard.content_bytes_of_charcode(
    256,
  )
  guard one_byte_overflow is Err(@pdflite.PdfError::InvalidByte(256)) else {
    fail("expected @pdflite.PdfError::InvalidByte for one-byte charcode")
  }
  let cid_overflow : Result[@pdflite.PdfBytes, Error] = try? cid.content_bytes_of_charcode(
    0x10000,
  )
  guard cid_overflow is Err(@pdflite.PdfError::InvalidByte(256)) else {
    fail("expected @pdflite.PdfError::InvalidByte for CID high byte")
  }
}

///|
test "cpdfcontent extra metrics mirror font-specific fallbacks" {
  let standard : @pdflite.PdfFont = PdfFontStandard({
    font: PdfHelvetica,
    encoding: PdfWinAnsiEncoding,
  })
  @test.assert_eq(standard.content_extra_metrics(), (-225.0, 931.0))
  @test.assert_eq(@pdflite.pdf_content_extra_metrics(standard), (-225.0, 931.0))
  let descriptor = {
    ..content_text_font_descriptor_for_test(),
    ascent: 810.0,
    descent: -190.0,
    fontbbox: { min_x: -20.0, min_y: -210.0, max_x: 520.0, max_y: 730.0 },
  }
  let simple : @pdflite.PdfFont = PdfFontSimple({
    fonttype: PdfTrueType,
    basefont: None,
    firstchar: 0,
    lastchar: 0,
    widths: [],
    fontdescriptor: Some(descriptor),
    fontmetrics: None,
    encoding: PdfWinAnsiEncoding,
  })
  @test.assert_eq(simple.content_extra_metrics(), (-210.0, 730.0))
  let zero_bbox_descriptor = {
    ..content_text_font_descriptor_for_test(),
    ascent: 700.0,
    descent: -180.0,
  }
  let cid = content_text_cid_font_with_descriptor_for_test(zero_bbox_descriptor)
  @test.assert_eq(cid.content_extra_metrics(), (700.0, -180.0))
  let type3 : @pdflite.PdfFont = PdfFontSimple({
    fonttype: PdfType3({
      fontbbox: { min_x: 1.0, min_y: -200.0, max_x: 500.0, max_y: 700.0 },
      fontmatrix: { a: 1.0, b: 0.0, c: 0.0, d: 0.5, e: 2.0, f: 3.0 },
      charprocs: [],
      resources: @pdflite.pdf_dictionary([]),
    }),
    basefont: None,
    firstchar: 0,
    lastchar: 0,
    widths: [],
    fontdescriptor: None,
    fontmetrics: None,
    encoding: PdfWinAnsiEncoding,
  })
  @test.assert_eq(type3.content_extra_metrics(), (353.0, -97.0))
  let missing_descriptor : @pdflite.PdfFont = PdfFontSimple({
    fonttype: PdfType1,
    basefont: None,
    firstchar: 0,
    lastchar: 0,
    widths: [],
    fontdescriptor: None,
    fontmetrics: None,
    encoding: PdfWinAnsiEncoding,
  })
  @test.assert_eq(missing_descriptor.content_extra_metrics(), (0.0, 0.0))
}

///|
test "cpdfcontent vertical predicate mirrors source CMap cases" {
  let standard : @pdflite.PdfFont = PdfFontStandard({
    font: PdfHelvetica,
    encoding: PdfWinAnsiEncoding,
  })
  @test.assert_eq(standard.content_is_vertical(), false)
  let composite = match content_text_cid_font_for_test() {
    PdfFontCIDKeyed(font) => font.composite
    _ => abort("expected CID font")
  }
  let identity_v : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: content_text_name_for_test("/Top"),
    composite,
    encoding: PdfPredefinedCMap(content_text_name_for_test("/Identity-V")),
  })
  @test.assert_eq(identity_v.content_is_vertical(), true)
  @test.assert_eq(@pdflite.pdf_content_is_vertical(identity_v), true)
  let identity_h : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: content_text_name_for_test("/Top"),
    composite,
    encoding: PdfPredefinedCMap(content_text_name_for_test("/Identity-H")),
  })
  @test.assert_eq(identity_h.content_is_vertical(), false)
  let other_predefined_v : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: content_text_name_for_test("/Top"),
    composite,
    encoding: PdfPredefinedCMap(content_text_name_for_test("/CNS-EUC-V")),
  })
  @test.assert_eq(other_predefined_v.content_is_vertical(), false)
  let parsed_vertical : @pdflite.PdfParsedCMap = {
    map: [],
    cid_map: [],
    notdef_map: [],
    codespaces: [],
    usecmap: None,
    wmode: Some(1),
    cmap_name: None,
    cmap_type: None,
    cid_system_info: None,
  }
  let external_vertical : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: content_text_name_for_test("/Top"),
    composite,
    encoding: PdfExternalCMap(7, parsed_vertical),
  })
  @test.assert_eq(external_vertical.content_is_vertical(), true)
  let external_horizontal : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: content_text_name_for_test("/Top"),
    composite,
    encoding: PdfExternalCMap(8, { ..parsed_vertical, wmode: Some(0) }),
  })
  @test.assert_eq(external_horizontal.content_is_vertical(), false)
}

///|
test "cpdfcontent width of charcode mirrors font metric branches" {
  let simple : @pdflite.PdfFont = PdfFontSimple({
    fonttype: PdfTrueType,
    basefont: None,
    firstchar: 0,
    lastchar: 2,
    widths: [],
    fontdescriptor: None,
    fontmetrics: Some([10.0, 20.0, 30.0]),
    encoding: PdfWinAnsiEncoding,
  })
  @test.assert_eq(simple.content_width_of_charcode(1), (20.0, 0.0, 0.0))
  @test.assert_eq(simple.content_width_of_charcode(3), (0.0, 0.0, 0.0))
  let type3 : @pdflite.PdfFont = PdfFontSimple({
    fonttype: PdfType3({
      fontbbox: { min_x: 0.0, min_y: 0.0, max_x: 0.0, max_y: 0.0 },
      fontmatrix: { a: 0.5, b: 0.0, c: 0.0, d: 1.0, e: 0.0, f: 0.0 },
      charprocs: [],
      resources: @pdflite.pdf_dictionary([]),
    }),
    basefont: None,
    firstchar: 0,
    lastchar: 0,
    widths: [],
    fontdescriptor: None,
    fontmetrics: Some([400.0]),
    encoding: PdfWinAnsiEncoding,
  })
  @test.assert_eq(type3.content_width_of_charcode(0), (200.0, 0.0, 0.0))
  let no_metrics : @pdflite.PdfFont = PdfFontSimple({
    fonttype: PdfType1,
    basefont: Some(content_text_name_for_test("/Helvetica")),
    firstchar: 0,
    lastchar: 0,
    widths: [],
    fontdescriptor: None,
    fontmetrics: None,
    encoding: PdfWinAnsiEncoding,
  })
  @test.assert_eq(no_metrics.content_width_of_charcode(65), (0.0, 0.0, 0.0))
  let standard : @pdflite.PdfFont = PdfFontStandard({
    font: PdfHelvetica,
    encoding: PdfWinAnsiEncoding,
  })
  @test.assert_eq(standard.content_width_of_charcode(65), (667.0, 0.0, 0.0))
  @test.assert_eq(
    @pdflite.pdf_content_width_of_charcode(standard, 65),
    (667.0, 0.0, 0.0),
  )
  let descriptor = content_text_font_descriptor_for_test()
  let horizontal_cid = content_text_cid_font_with_descriptor_for_test(
    descriptor,
  )
  @test.assert_eq(
    horizontal_cid.content_width_of_charcode(6),
    (1000.0, 0.0, 0.0),
  )
  let composite = match horizontal_cid {
    PdfFontCIDKeyed(font) =>
      {
        ..font.composite,
        cid_widths: [(5, 600.0), (6, 640.0)],
        cid_widths2: [(5, { width: 700.0, vx: 11.0, vy: 12.0 })],
        cid_default_width2: [880.0, -1000.0],
      }
    _ => abort("expected CID font")
  }
  let vertical_cid : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: content_text_name_for_test("/Top"),
    composite,
    encoding: PdfPredefinedCMap(content_text_name_for_test("/Identity-V")),
  })
  @test.assert_eq(
    vertical_cid.content_width_of_charcode(5),
    (700.0, 11.0, 12.0),
  )
  @test.assert_eq(
    vertical_cid.content_width_of_charcode(6),
    (320.0, 880.0, -1000.0),
  )
  @test.assert_eq(vertical_cid.content_width_of_charcode(7), (0.0, 0.0, 0.0))
}

///|
test "cpdfcontent text layout mirrors horizontal process_tj placement" {
  let font : @pdflite.PdfFont = PdfFontSimple({
    fonttype: PdfTrueType,
    basefont: None,
    firstchar: 0,
    lastchar: 255,
    widths: [],
    fontdescriptor: Some({
      ..content_text_font_descriptor_for_test(),
      fontbbox: { min_x: 0.0, min_y: -200.0, max_x: 600.0, max_y: 800.0 },
    }),
    fontmetrics: Some(
      [
        for code in 0..<256 => if code == 32 { 250.0 } else { 500.0 }
      ],
    ),
    encoding: PdfWinAnsiEncoding,
  })
  let layout : @pdflite.PdfContentTextLayout = {
    font_size: 10.0,
    horizontal_scaling: 0.8,
    character_spacing: 1.0,
    word_spacing: 2.0,
    rise: 3.0,
    ctm: @pdflite.transform_translate(100.0, 200.0),
    text_matrix: @pdflite.transform_translate(10.0, 20.0),
  }
  let result = font.content_text_layout_of_bytes(
    content_text_bytes_for_test([65, 32]),
    layout,
  )
  @test.assert_eq(result.glyphs.length(), 2)
  let first = result.glyphs[0]
  @test.assert_eq(first.charcode, 65)
  content_text_assert_matrix_close_for_test(
    first.text_matrix,
    @pdflite.transform_translate(10.0, 20.0),
  )
  content_text_assert_close_for_test(first.width, 0.5)
  content_text_assert_close_for_test(first.advance_x, 4.8)
  content_text_assert_close_for_test(first.advance_y, 0.0)
  content_text_assert_bbox_close_for_test(first.bounding_box, {
    x0: 110.0,
    y0: 231.0,
    x1: 110.0,
    y1: 221.0,
    x2: 114.0,
    y2: 221.0,
    x3: 114.0,
    y3: 231.0,
  })
  let second = result.glyphs[1]
  @test.assert_eq(second.charcode, 32)
  content_text_assert_matrix_close_for_test(
    second.text_matrix,
    @pdflite.transform_translate(14.8, 20.0),
  )
  content_text_assert_close_for_test(second.width, 0.25)
  content_text_assert_close_for_test(second.advance_x, 4.4)
  content_text_assert_bbox_close_for_test(second.bounding_box, {
    x0: 114.8,
    y0: 231.0,
    x1: 114.8,
    y1: 221.0,
    x2: 116.8,
    y2: 221.0,
    x3: 116.8,
    y3: 231.0,
  })
  content_text_assert_matrix_close_for_test(
    result.text_matrix,
    @pdflite.transform_translate(19.2, 20.0),
  )
  let wrapped = @pdflite.pdf_content_text_layout_of_bytes(
    font,
    content_text_bytes_for_test([65]),
    layout,
  )
  @test.assert_eq(wrapped.glyphs.length(), 1)
  @test.assert_eq(wrapped.glyphs[0].charcode, 65)
}

///|
test "cpdfcontent text layout mirrors vertical process_tj placement" {
  let descriptor = {
    ..content_text_font_descriptor_for_test(),
    ascent: 800.0,
    descent: -200.0,
  }
  let base = content_text_cid_font_with_descriptor_for_test(descriptor)
  let composite = match base {
    PdfFontCIDKeyed(font) =>
      {
        ..font.composite,
        cid_widths2: [(0x0102, { width: 700.0, vx: 20.0, vy: 30.0 })],
      }
    _ => abort("expected CID font")
  }
  let font : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: content_text_name_for_test("/Top"),
    composite,
    encoding: PdfPredefinedCMap(content_text_name_for_test("/Identity-V")),
  })
  let layout : @pdflite.PdfContentTextLayout = {
    font_size: 10.0,
    horizontal_scaling: 0.25,
    character_spacing: 1.0,
    word_spacing: 2.0,
    rise: 0.0,
    ctm: @pdflite.transform_identity_matrix,
    text_matrix: @pdflite.transform_identity_matrix,
  }
  let result = font.content_text_layout_of_bytes(
    content_text_bytes_for_test([0x01, 0x02]),
    layout,
  )
  @test.assert_eq(result.glyphs.length(), 1)
  let glyph = result.glyphs[0]
  @test.assert_eq(glyph.charcode, 0x0102)
  content_text_assert_close_for_test(glyph.width, 0.7)
  content_text_assert_close_for_test(glyph.pvx, 0.02)
  content_text_assert_close_for_test(glyph.pvy, 0.03)
  content_text_assert_close_for_test(glyph.advance_x, 0.0)
  content_text_assert_close_for_test(glyph.advance_y, 10.0)
  content_text_assert_bbox_close_for_test(glyph.bounding_box, {
    x0: 0.05,
    y0: -2.3,
    x1: 0.05,
    y1: 7.7,
    x2: 1.8,
    y2: 7.7,
    x3: 1.8,
    y3: -2.3,
  })
  content_text_assert_matrix_close_for_test(
    result.text_matrix,
    @pdflite.transform_translate(0.0, 10.0),
  )
}
