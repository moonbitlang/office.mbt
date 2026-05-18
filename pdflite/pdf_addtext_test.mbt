///|
fn addtext_offset_for_test(
  rotation : @pdflite.PdfAddTextRotation,
  position : @pdflite.PdfPosition,
  justification : @pdflite.PdfAddTextJustification,
) -> Double {
  @pdflite.pdf_addtext_justification_offset(
    rotation, 100.0, 60.0, position, justification,
  )
}

///|
fn addtext_assert_close_for_test(
  actual : Double,
  expected : Double,
) -> Unit raise {
  if (actual - expected).abs() > 0.000000001 {
    fail("addtext values were not close enough")
  }
}

///|
fn addtext_assert_pair_close_for_test(
  actual : (Double, Double),
  expected : (Double, Double),
) -> Unit raise {
  addtext_assert_close_for_test(actual.0, expected.0)
  addtext_assert_close_for_test(actual.1, expected.1)
}

///|
fn addtext_process_time_for_test() -> @pdflite.PdfStrftimeTime {
  {
    tm_sec: 5,
    tm_min: 4,
    tm_hour: 13,
    tm_mday: 3,
    tm_mon: 8,
    tm_year: 123,
    tm_wday: 0,
    tm_yday: 6,
    tm_isdst: false,
  }
}

///|
fn addtext_pdfdoc_text_for_test(text : String) -> @pdflite.PdfBytes {
  try! @pdflite.pdf_pdfdocstring_of_utf8(@utf8.encode(text))
}

///|
fn addtext_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn addtext_bounds_for_test() -> @pdflite.PdfRectangle {
  { min_x: 0.0, min_y: 0.0, max_x: 100.0, max_y: 50.0 }
}

///|
fn addtext_matrix_for_test(
  x : Double,
  y : Double,
  base_rotation : Double,
  horizontal_offset : Double,
  vertical_offset : Double,
  text_rotation : Double,
  rotation_h_offset : Double,
  rotation_v_offset : Double,
) -> @pdflite.TransformMatrix {
  @pdflite.transform_matrix_of_transform([
    Translate(
      x - horizontal_offset + rotation_h_offset,
      y - vertical_offset + rotation_v_offset,
    ),
    Rotate(@pdflite.point2(0.0, 0.0), base_rotation + text_rotation),
  ])
}

///|
fn addtext_content_ops_for_test(
  document : @pdflite.PdfDocument,
  page : @pdflite.PdfPage,
) -> Array[@pdflite.PdfContentOp] {
  try! document.parse_content_ops_with_resources(page.resources, page.content)
}

///|
fn addtext_bookmark_for_test(
  level : Int,
  text : String,
  page_object : Int,
) -> @pdflite.PdfBookmark {
  {
    level,
    text: addtext_pdfdoc_text_for_test(text),
    target: DestFit(TargetPageObject(page_object)),
    is_open: true,
    colour: { red: 0.0, green: 0.0, blue: 0.0 },
    flags: 0,
  }
}

///|
fn addtext_font_descriptor_for_test(
  capheight : Double,
) -> @pdflite.PdfFontDescriptor {
  {
    ascent: 0.0,
    descent: 0.0,
    avgwidth: 0.0,
    maxwidth: 0.0,
    flags: 0,
    fontbbox: { min_x: 0.0, min_y: 0.0, max_x: 0.0, max_y: 0.0 },
    italicangle: 0.0,
    capheight,
    xheight: 0.0,
    stemv: 0.0,
    fontfile: None,
    charset: None,
    tounicode: None,
  }
}

///|
fn addtext_simple_font_for_test(capheight : Double) -> @pdflite.PdfFont {
  PdfFontSimple({
    fonttype: PdfType1,
    basefont: None,
    firstchar: 0,
    lastchar: -1,
    widths: [],
    fontdescriptor: Some(addtext_font_descriptor_for_test(capheight)),
    fontmetrics: None,
    encoding: PdfWinAnsiEncoding,
  })
}

///|
fn addtext_simple_font_with_encoding_for_test(
  encoding : @pdflite.PdfEncoding,
) -> @pdflite.PdfFont {
  PdfFontSimple({
    fonttype: PdfType1,
    basefont: None,
    firstchar: 0,
    lastchar: -1,
    widths: [],
    fontdescriptor: Some(addtext_font_descriptor_for_test(700.0)),
    fontmetrics: None,
    encoding,
  })
}

///|
fn addtext_simple_font_without_descriptor_for_test() -> @pdflite.PdfFont {
  PdfFontSimple({
    fonttype: PdfType1,
    basefont: None,
    firstchar: 0,
    lastchar: -1,
    widths: [],
    fontdescriptor: None,
    fontmetrics: None,
    encoding: PdfWinAnsiEncoding,
  })
}

///|
fn addtext_simple_font_with_metrics_for_test(
  metrics : Array[Double]?,
) -> @pdflite.PdfFont {
  PdfFontSimple({
    fonttype: PdfType1,
    basefont: None,
    firstchar: 0,
    lastchar: 255,
    widths: [],
    fontdescriptor: Some(addtext_font_descriptor_for_test(0.0)),
    fontmetrics: metrics,
    encoding: PdfWinAnsiEncoding,
  })
}

///|
fn addtext_standard_font_for_test() -> @pdflite.PdfFont {
  PdfFontStandard({ font: PdfHelvetica, encoding: PdfWinAnsiEncoding })
}

///|
test "pdf_addtext_colour_op maps fill colours to content operators" {
  @test.assert_eq(
    @pdflite.pdf_addtext_colour_op(PdfContentGrey(0.25)),
    Op_g(0.25),
  )
  @test.assert_eq(
    @pdflite.pdf_addtext_colour_op(PdfContentRGB(0.1, 0.2, 0.3)),
    Op_rg(0.1, 0.2, 0.3),
  )
  @test.assert_eq(
    @pdflite.pdf_addtext_colour_op(PdfContentCMYK(0.0, 0.1, 0.2, 0.3)),
    Op_k(0.0, 0.1, 0.2, 0.3),
  )
}

///|
test "pdf_addtext_colour_op_stroke maps stroke colours to content operators" {
  @test.assert_eq(
    @pdflite.pdf_addtext_colour_op_stroke(PdfContentGrey(0.75)),
    Op_G(0.75),
  )
  @test.assert_eq(
    @pdflite.pdf_addtext_colour_op_stroke(PdfContentRGB(0.4, 0.5, 0.6)),
    Op_RG(0.4, 0.5, 0.6),
  )
  @test.assert_eq(
    @pdflite.pdf_addtext_colour_op_stroke(PdfContentCMYK(0.7, 0.8, 0.9, 1.0)),
    Op_K(0.7, 0.8, 0.9, 1.0),
  )
}

///|
test "pdf_addtext_charcodes_of_utf8 emits font charcode bytes" {
  @test.assert_eq(
    @pdflite.pdf_int_array_of_bytes(
      try! @pdflite.pdf_addtext_charcodes_of_utf8(
        addtext_standard_font_for_test(),
        "AéB",
      ),
    ),
    [65, 233, 66],
  )
}

///|
test "pdf_addtext_charcodes_of_utf8 skips missing font codepoints" {
  @test.assert_eq(
    @pdflite.pdf_int_array_of_bytes(
      try! @pdflite.pdf_addtext_charcodes_of_utf8(
        addtext_standard_font_for_test(),
        "A☃B",
      ),
    ),
    [65, 66],
  )
}

///|
test "pdf_addtext_rectangle_ops builds filled rectangle stamps" {
  @test.assert_eq(
    @pdflite.pdf_addtext_rectangle_ops(
      10.0,
      20.0,
      30.0,
      40.0,
      PdfContentRGB(1.0, 0.0, 0.0),
      false,
      2.0,
      None,
    ),
    [
      @pdflite.pdf_content_begin_artifact(),
      Op_q,
      Op_BMC(addtext_name_for_test("/CPDFSTAMP")),
      Op_rg(1.0, 0.0, 0.0),
      Op_RG(1.0, 0.0, 0.0),
      Op_re(10.0, 20.0, 30.0, 40.0),
      Op_f,
      Op_EMC,
      Op_Q,
      @pdflite.pdf_content_end_artifact(),
    ],
  )
}

///|
test "pdf_addtext_rectangle_ops builds outlined rectangle stamps" {
  let gs = addtext_name_for_test("/gs0")
  @test.assert_eq(
    @pdflite.pdf_addtext_rectangle_ops(
      1.0,
      2.0,
      3.0,
      4.0,
      PdfContentGrey(0.5),
      true,
      1.25,
      Some(gs),
    ),
    [
      @pdflite.pdf_content_begin_artifact(),
      Op_q,
      Op_BMC(addtext_name_for_test("/CPDFSTAMP")),
      Op_g(0.5),
      Op_G(0.5),
      Op_w(1.25),
      Op_gs(gs),
      Op_re(1.0, 2.0, 3.0, 4.0),
      Op_s,
      Op_EMC,
      Op_Q,
      @pdflite.pdf_content_end_artifact(),
    ],
  )
}

///|
test "pdf_addtext_text_ops builds simple font text stamps" {
  let font = addtext_standard_font_for_test()
  let font_name = addtext_name_for_test("/F0")
  let gs = addtext_name_for_test("/gs0")
  @test.assert_eq(
    try! @pdflite.pdf_addtext_text_ops(
      Some(font),
      None,
      100.0,
      200.0,
      0.25,
      10.0,
      20.0,
      true,
      0.5,
      font_name,
      [],
      Some(gs),
      PdfContentRGB(0.1, 0.2, 0.3),
      12.0,
      "Aé☃",
      0.75,
      2.0,
      3.0,
    ),
    [
      @pdflite.pdf_content_begin_artifact(),
      Op_q,
      Op_BMC(addtext_name_for_test("/CPDFSTAMP")),
      Op_cm(
        addtext_matrix_for_test(100.0, 200.0, 0.25, 10.0, 20.0, 0.75, 2.0, 3.0),
      ),
      Op_BT,
      Op_w(0.5),
      Op_Tr(1),
      Op_rg(0.1, 0.2, 0.3),
      Op_RG(0.1, 0.2, 0.3),
      Op_gs(gs),
      Op_Tf(font_name, 12.0),
      Op_Tj(try! @pdflite.pdf_bytes_of_int_array([65, 233])),
      Op_ET,
      Op_EMC,
      Op_Q,
      @pdflite.pdf_content_end_artifact(),
    ],
  )
}

///|
test "pdf_addtext_text_ops switches fontpack runs" {
  let regular = addtext_standard_font_for_test()
  let bold = addtext_simple_font_for_test(700.0)
  let pack : @pdflite.PdfFontPack = {
    fonts: [regular, bold],
    entries: [
      { codepoint: 65, font_index: 0, charcode: 1 },
      { codepoint: 66, font_index: 1, charcode: 2 },
      { codepoint: 67, font_index: 1, charcode: 3 },
      { codepoint: 68, font_index: 0, charcode: 4 },
    ],
  }
  let fallback_font = addtext_name_for_test("/Fallback")
  let regular_name = addtext_name_for_test("/F0")
  let bold_name = addtext_name_for_test("/F1")
  @test.assert_eq(
    try! @pdflite.pdf_addtext_text_ops(
      None,
      Some(pack),
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      false,
      1.0,
      fallback_font,
      [regular_name, bold_name],
      None,
      PdfContentGrey(0.25),
      10.0,
      "ABCDZ",
      0.0,
      0.0,
      0.0,
    ),
    [
      @pdflite.pdf_content_begin_artifact(),
      Op_q,
      Op_BMC(addtext_name_for_test("/CPDFSTAMP")),
      Op_cm(addtext_matrix_for_test(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)),
      Op_BT,
      Op_Tr(0),
      Op_g(0.25),
      Op_G(0.25),
      Op_Tf(regular_name, 10.0),
      Op_Tj(try! @pdflite.pdf_bytes_of_int_array([1])),
      Op_Tf(bold_name, 10.0),
      Op_Tj(try! @pdflite.pdf_bytes_of_int_array([2, 3])),
      Op_Tf(regular_name, 10.0),
      Op_Tj(try! @pdflite.pdf_bytes_of_int_array([4])),
      Op_ET,
      Op_EMC,
      Op_Q,
      @pdflite.pdf_content_end_artifact(),
    ],
  )
}

///|
test "pdf_addtext_rotation_radians mirrors cpdf addtext rotation mapping" {
  addtext_assert_close_for_test(
    @pdflite.pdf_addtext_rotation_radians(PdfAddTextRot0),
    0.0,
  )
  addtext_assert_close_for_test(
    @pdflite.pdf_addtext_rotation_radians(PdfAddTextRot90),
    @math.PI * 1.5,
  )
  addtext_assert_close_for_test(
    @pdflite.pdf_addtext_rotation_radians(PdfAddTextRot180),
    @math.PI,
  )
  addtext_assert_close_for_test(
    @pdflite.pdf_addtext_rotation_radians(PdfAddTextRot270),
    @math.PI / 2.0,
  )
}

///|
test "pdf_addtext_rotation_offsets follows cpdf position table" {
  @test.assert_eq(
    @pdflite.pdf_addtext_rotation_offsets(
      PdfPositionTopRight(0.0, 0.0),
      PdfAddTextRot90,
      40.0,
    ),
    (40.0, 0.0),
  )
  @test.assert_eq(
    @pdflite.pdf_addtext_rotation_offsets(
      PdfPositionTopRight(0.0, 0.0),
      PdfAddTextRot270,
      40.0,
    ),
    (40.0, -40.0),
  )
  @test.assert_eq(
    @pdflite.pdf_addtext_rotation_offsets(
      PdfPositionCentre,
      PdfAddTextRot270,
      40.0,
    ),
    (20.0, -20.0),
  )
  @test.assert_eq(
    @pdflite.pdf_addtext_rotation_offsets(
      PdfPositionBottomLeft(0.0, 0.0),
      PdfAddTextRot90,
      40.0,
    ),
    (0.0, 40.0),
  )
  @test.assert_eq(
    @pdflite.pdf_addtext_rotation_offsets(
      PdfPositionDiagonal,
      PdfAddTextRot180,
      40.0,
    ),
    (0.0, 0.0),
  )
}

///|
test "pdf_addtext_diagonal_offsets mirrors diagonal and reverse diagonal math" {
  let bounds = addtext_bounds_for_test()
  addtext_assert_pair_close_for_test(
    @pdflite.pdf_addtext_diagonal_offsets(
      bounds,
      PdfPositionDiagonal,
      PdfAddTextRot0,
      20.0,
      5.0,
      10.0,
      0.0,
    ),
    (0.0, 10.0),
  )
  let angle = @math.atan(
    (bounds.max_y - bounds.min_y) / (bounds.max_x - bounds.min_x),
  )
  let dx = @math.cos(angle) * 20.0
  let dy = @math.sin(angle) * 20.0
  addtext_assert_pair_close_for_test(
    @pdflite.pdf_addtext_diagonal_offsets(
      bounds,
      PdfPositionDiagonal,
      PdfAddTextRot180,
      20.0,
      5.0,
      10.0,
      0.0,
    ),
    (-dx, -10.0 - dy),
  )
  addtext_assert_pair_close_for_test(
    @pdflite.pdf_addtext_diagonal_offsets(
      bounds,
      PdfPositionReverseDiagonal,
      PdfAddTextRot180,
      20.0,
      5.0,
      10.0,
      0.0,
    ),
    (-dx, -10.0 + dy),
  )
  @test.assert_eq(
    @pdflite.pdf_addtext_diagonal_offsets(
      bounds,
      PdfPositionTop(0.0),
      PdfAddTextRot180,
      20.0,
      5.0,
      10.0,
      0.0,
    ),
    (5.0, 10.0),
  )
}

///|
test "pdf_addtext_initial_line_offsets matches cpdf multiline alignment" {
  addtext_assert_pair_close_for_test(
    @pdflite.pdf_addtext_initial_line_offsets(
      PdfPositionBottom(0.0),
      3,
      1.2,
      10.0,
    ),
    (0.0, -24.0),
  )
  addtext_assert_pair_close_for_test(
    @pdflite.pdf_addtext_initial_line_offsets(
      PdfPositionBottomLeft(0.0, 0.0),
      3,
      1.2,
      10.0,
    ),
    (0.0, -24.0),
  )
  addtext_assert_pair_close_for_test(
    @pdflite.pdf_addtext_initial_line_offsets(
      PdfPositionBottomRight(0.0, 0.0),
      3,
      1.2,
      10.0,
    ),
    (0.0, -24.0),
  )
  addtext_assert_pair_close_for_test(
    @pdflite.pdf_addtext_initial_line_offsets(
      PdfPositionLeft(0.0),
      3,
      1.2,
      10.0,
    ),
    (0.0, -12.0),
  )
  addtext_assert_pair_close_for_test(
    @pdflite.pdf_addtext_initial_line_offsets(
      PdfPositionRight(0.0),
      3,
      1.2,
      10.0,
    ),
    (0.0, -12.0),
  )
  addtext_assert_pair_close_for_test(
    @pdflite.pdf_addtext_initial_line_offsets(PdfPositionDiagonal, 3, 1.2, 10.0),
    (0.0, -12.0),
  )
  addtext_assert_pair_close_for_test(
    @pdflite.pdf_addtext_initial_line_offsets(
      PdfPositionReverseDiagonal,
      3,
      1.2,
      10.0,
    ),
    (0.0, -12.0),
  )
  addtext_assert_pair_close_for_test(
    @pdflite.pdf_addtext_initial_line_offsets(PdfPositionTop(0.0), 3, 1.2, 10.0),
    (0.0, 0.0),
  )
  addtext_assert_pair_close_for_test(
    @pdflite.pdf_addtext_initial_line_offsets(PdfPositionCentre, 3, 1.2, 10.0),
    (0.0, 0.0),
  )
}

///|
test "pdf_addtext_line_advance follows text rotation" {
  addtext_assert_pair_close_for_test(
    @pdflite.pdf_addtext_line_advance(PdfAddTextRot0, 1.2, 10.0),
    (0.0, 12.0),
  )
  addtext_assert_pair_close_for_test(
    @pdflite.pdf_addtext_line_advance(PdfAddTextRot180, 1.2, 10.0),
    (0.0, 12.0),
  )
  addtext_assert_pair_close_for_test(
    @pdflite.pdf_addtext_line_advance(PdfAddTextRot90, 1.2, 10.0),
    (12.0, 0.0),
  )
  addtext_assert_pair_close_for_test(
    @pdflite.pdf_addtext_line_advance(PdfAddTextRot270, 1.2, 10.0),
    (12.0, 0.0),
  )
}

///|
test "pdf_addtext_baseline_offsets handles standard font midline and topline" {
  let font = addtext_standard_font_for_test()
  addtext_assert_pair_close_for_test(
    @pdflite.pdf_addtext_baseline_offsets(
      Some(font),
      10.0,
      PdfPositionTop(0.0),
      PdfAddTextRot0,
      true,
      false,
    ),
    (0.0, 3.59),
  )
  addtext_assert_pair_close_for_test(
    @pdflite.pdf_addtext_baseline_offsets(
      Some(font),
      10.0,
      PdfPositionTop(0.0),
      PdfAddTextRot90,
      true,
      false,
    ),
    (3.59, 0.0),
  )
  addtext_assert_pair_close_for_test(
    @pdflite.pdf_addtext_baseline_offsets(
      Some(font),
      10.0,
      PdfPositionTop(0.0),
      PdfAddTextRot180,
      true,
      false,
    ),
    (0.0, -3.59),
  )
  addtext_assert_pair_close_for_test(
    @pdflite.pdf_addtext_baseline_offsets(
      Some(font),
      10.0,
      PdfPositionTop(0.0),
      PdfAddTextRot270,
      true,
      false,
    ),
    (-3.59, 0.0),
  )
  addtext_assert_pair_close_for_test(
    @pdflite.pdf_addtext_baseline_offsets(
      Some(font),
      10.0,
      PdfPositionTop(0.0),
      PdfAddTextRot0,
      false,
      true,
    ),
    (0.0, 7.18),
  )
  addtext_assert_pair_close_for_test(
    @pdflite.pdf_addtext_baseline_offsets(
      Some(font),
      10.0,
      PdfPositionDiagonal,
      PdfAddTextRot270,
      false,
      true,
    ),
    (0.0, 7.18),
  )
  addtext_assert_pair_close_for_test(
    @pdflite.pdf_addtext_baseline_offsets(
      Some(font),
      10.0,
      PdfPositionTop(0.0),
      PdfAddTextRot90,
      true,
      true,
    ),
    (3.59, 0.0),
  )
}

///|
test "pdf_addtext_baseline_offsets handles simple font capheight and fallbacks" {
  let font = addtext_simple_font_for_test(700.0)
  addtext_assert_pair_close_for_test(
    @pdflite.pdf_addtext_baseline_offsets(
      Some(font),
      10.0,
      PdfPositionTop(0.0),
      PdfAddTextRot0,
      true,
      false,
    ),
    (0.0, 3.5),
  )
  addtext_assert_pair_close_for_test(
    @pdflite.pdf_addtext_baseline_offsets(
      Some(font),
      10.0,
      PdfPositionTop(0.0),
      PdfAddTextRot90,
      false,
      true,
    ),
    (7.0, 0.0),
  )
  addtext_assert_pair_close_for_test(
    @pdflite.pdf_addtext_baseline_offsets(
      Some(font),
      10.0,
      PdfPositionDiagonal,
      PdfAddTextRot180,
      false,
      true,
    ),
    (0.0, 7.0),
  )
  addtext_assert_pair_close_for_test(
    @pdflite.pdf_addtext_baseline_offsets(
      Some(addtext_simple_font_without_descriptor_for_test()),
      10.0,
      PdfPositionTop(0.0),
      PdfAddTextRot0,
      true,
      false,
    ),
    (0.0, 0.0),
  )
  addtext_assert_pair_close_for_test(
    @pdflite.pdf_addtext_baseline_offsets(
      None,
      10.0,
      PdfPositionTop(0.0),
      PdfAddTextRot0,
      false,
      true,
    ),
    (0.0, 0.0),
  )
}

///|
test "pdf_addtext_effective_encoding follows selected add-text font" {
  @test.assert_eq(
    @pdflite.pdf_addtext_effective_encoding(
      Some(
        PdfFontStandard({ font: PdfTimesRoman, encoding: PdfMacRomanEncoding }),
      ),
    ),
    PdfMacRomanEncoding,
  )
  @test.assert_eq(
    @pdflite.pdf_addtext_effective_encoding(
      Some(addtext_simple_font_with_encoding_for_test(PdfMacExpertEncoding)),
    ),
    PdfMacExpertEncoding,
  )
  @test.assert_eq(
    @pdflite.pdf_addtext_effective_encoding(None),
    PdfWinAnsiEncoding,
  )
}

///|
test "pdf_addtext_allocate_font_names handles non-fontpack resources" {
  let f0 = addtext_name_for_test("/F0")
  let f1 = addtext_name_for_test("/F1")
  let f2 = addtext_name_for_test("/F2")
  let fontdict : @pdflite.PdfObject = PdfDictionary([
    (f0, PdfInteger(1)),
    (f1, PdfInteger(2)),
  ])
  let allocated = try! @pdflite.pdf_addtext_allocate_font_names(fontdict, None)
  @test.assert_eq(allocated.0, f2)
  @test.assert_eq(allocated.1, fontdict)
  @test.assert_eq(allocated.2, [])
}

///|
test "pdf_addtext_allocate_font_names reserves fontpack placeholders" {
  let f0 = addtext_name_for_test("/F0")
  let f1 = addtext_name_for_test("/F1")
  let f2 = addtext_name_for_test("/F2")
  let fontdict : @pdflite.PdfObject = PdfDictionary([(f0, PdfInteger(1))])
  let pack : @pdflite.PdfFontPack = {
    fonts: [
      addtext_standard_font_for_test(),
      addtext_simple_font_for_test(700.0),
    ],
    entries: [],
  }
  let allocated = try! @pdflite.pdf_addtext_allocate_font_names(
    fontdict,
    Some(pack),
  )
  @test.assert_eq(allocated.0, f1)
  @test.assert_eq(allocated.2, [f1, f2])
  @test.assert_eq(allocated.1.lookup_immediate(f0), Some(PdfInteger(1)))
  @test.assert_eq(allocated.1.lookup_immediate(f1), Some(PdfNull))
  @test.assert_eq(allocated.1.lookup_immediate(f2), Some(PdfNull))
}

///|
test "pdf_addtext_fontpack_resource_dictionary installs embedded font references" {
  let f0 = addtext_name_for_test("/F0")
  let f1 = addtext_name_for_test("/F1")
  let f2 = addtext_name_for_test("/F2")
  let fontdict : @pdflite.PdfObject = PdfDictionary([(f0, PdfInteger(1))])
  let updated = try! @pdflite.pdf_addtext_fontpack_resource_dictionary(
    fontdict,
    [f1, f2],
    [10, 11],
  )
  @test.assert_eq(updated.lookup_immediate(f0), Some(PdfInteger(1)))
  @test.assert_eq(updated.lookup_immediate(f1), Some(PdfIndirect(10)))
  @test.assert_eq(updated.lookup_immediate(f2), Some(PdfIndirect(11)))
  let result : Result[@pdflite.PdfObject, Error] = try? @pdflite.pdf_addtext_fontpack_resource_dictionary(
    fontdict,
    [f1],
    [10, 11],
  )
  guard result
    is Err(@pdflite.PdfError::SoftError("bad add-text fontpack resource list")) else {
    fail("expected SoftError for mismatched fontpack resource lists")
  }
}

///|
test "pdf_addtext_rectangle_origin lowers top positions by rectangle height" {
  let bounds = addtext_bounds_for_test()
  @test.assert_eq(
    @pdflite.pdf_addtext_rectangle_origin(
      bounds,
      PdfPositionTopLeft(3.0, 4.0),
      20.0,
      10.0,
    ),
    (3.0, 36.0),
  )
  @test.assert_eq(
    @pdflite.pdf_addtext_rectangle_origin(
      bounds,
      PdfPositionTop(5.0),
      20.0,
      10.0,
    ),
    (40.0, 35.0),
  )
  @test.assert_eq(
    @pdflite.pdf_addtext_rectangle_origin(
      bounds,
      PdfPositionTopRight(3.0, 4.0),
      20.0,
      10.0,
    ),
    (77.0, 36.0),
  )
}

///|
test "pdf_addtext_rectangle_origin handles center and unchanged positions" {
  let bounds = addtext_bounds_for_test()
  @test.assert_eq(
    @pdflite.pdf_addtext_rectangle_origin(bounds, PdfPositionCentre, 20.0, 10.0),
    (40.0, 20.0),
  )
  @test.assert_eq(
    @pdflite.pdf_addtext_rectangle_origin(
      bounds,
      PdfPositionPosCentre(50.0, 4.0),
      20.0,
      10.0,
    ),
    (40.0, -1.0),
  )
  @test.assert_eq(
    @pdflite.pdf_addtext_rectangle_origin(
      bounds,
      PdfPositionBottomLeft(3.0, 4.0),
      20.0,
      10.0,
    ),
    (3.0, 4.0),
  )
}

///|
test "PdfDocument addtext_rectangle appends selected page rectangle" {
  let document = try! @pdflite.pdf_blank_document(100.0, 50.0, 2)
  let stamped = try! document.addtext_rectangle(
    [2],
    "20 10",
    PdfContentRGB(1.0, 0.0, 0.0),
    PdfPositionTopRight(3.0, 4.0),
  )
  let pages = try! stamped.pages_of_pagetree()
  @test.assert_eq(pages[0].content.length(), 0)
  @test.assert_eq(
    addtext_content_ops_for_test(stamped, pages[1]),
    @pdflite.pdf_addtext_rectangle_ops(
      77.0,
      36.0,
      20.0,
      10.0,
      PdfContentRGB(1.0, 0.0, 0.0),
      false,
      1.0,
      None,
    ),
  )
}

///|
test "PdfDocument addtext_rectangle handles relative box opacity and underneath fast mode" {
  let base = try! @pdflite.pdf_blank_document(100.0, 50.0, 1)
  let pages = try! base.pages_of_pagetree()
  let cropbox = addtext_name_for_test("/CropBox")
  let extgstate = addtext_name_for_test("/ExtGState")
  let gs = addtext_name_for_test("/gs0")
  let ca = addtext_name_for_test("/ca")
  let ca_stroke = addtext_name_for_test("/CA")
  let page = {
    ..pages[0],
    content: [try! @pdflite.pdf_content_stream_of_ops([Op_BT, Op_ET])],
    rest: @pdflite.pdf_dictionary([
      (
        cropbox,
        PdfArray([PdfReal(10.0), PdfReal(20.0), PdfReal(70.0), PdfReal(40.0)]),
      ),
    ]),
  }
  let document = try! base.change_pages([page])
  let stamped = try! @pdflite.pdf_addtext_rectangle(
    document,
    [1],
    "20 10",
    PdfContentGrey(0.5),
    PdfPositionCentre,
    relative_to_box=cropbox,
    outline=true,
    line_width=1.25,
    opacity=0.5,
    underneath=true,
    fast=true,
  )
  let stamped_pages = try! stamped.pages_of_pagetree()
  @test.assert_eq(
    addtext_content_ops_for_test(stamped, stamped_pages[0]),
    [
      ..@pdflite.pdf_addtext_rectangle_ops(
        30.0,
        25.0,
        20.0,
        10.0,
        PdfContentGrey(0.5),
        true,
        1.25,
        Some(gs),
      ),
      Op_BT,
      Op_ET,
    ],
  )
  guard stamped.lookup_direct(extgstate, stamped_pages[0].resources)
    is Some(resource_dictionary) else {
    fail("expected ExtGState resource dictionary")
  }
  guard stamped.lookup_direct(gs, resource_dictionary)
    is Some(opacity_dictionary) else {
    fail("expected generated opacity graphics state")
  }
  @test.assert_eq(
    stamped.lookup_direct(ca, opacity_dictionary),
    Some(PdfReal(0.5)),
  )
  @test.assert_eq(
    stamped.lookup_direct(ca_stroke, opacity_dictionary),
    Some(PdfReal(0.5)),
  )
}

///|
test "PdfDocument addtext_rectangle reports bad coordinate specifications" {
  let document = try! @pdflite.pdf_blank_document(100.0, 50.0, 1)
  let result : Result[@pdflite.PdfDocument, Error] = try? document.addtext_rectangle(
    [1],
    "10 20 30",
    PdfContentGrey(0.0),
    PdfPositionBottomLeft(0.0, 0.0),
  )
  guard result
    is Err(@pdflite.PdfError::SoftError("bad coordinate specification")) else {
    fail("expected SoftError for addtext rectangle coordinate arity")
  }
}

///|
test "PdfDocument addtext_rectangle validates selected pages" {
  let document = try! @pdflite.pdf_blank_document(100.0, 50.0, 1)
  let result : Result[@pdflite.PdfDocument, Error] = try? document.addtext_rectangle(
    [2],
    "10 20",
    PdfContentGrey(0.0),
    PdfPositionBottomLeft(0.0, 0.0),
  )
  guard result
    is Err(
      @pdflite.PdfError::BadPageSpecification(
        "addtext_rectangle: range contains pages not present in pdf"
      )
    ) else {
    fail(
      "expected BadPageSpecification for out-of-range addtext rectangle page",
    )
  }
}

///|
test "pdf_addtext_width_of_text sums simple font metrics" {
  let metrics : Array[Double] = [ for _ in 0..<256 => 0.0 ]
  metrics[65] = 500.0
  metrics[66] = 610.0
  let font = addtext_simple_font_with_metrics_for_test(Some(metrics))
  @test.assert_eq(
    @pdflite.pdf_addtext_width_of_text(font, @ascii.encode("ABA")),
    1610.0,
  )
}

///|
test "pdf_addtext_width_of_text mirrors cpdf zero fallbacks" {
  @test.assert_eq(
    @pdflite.pdf_addtext_width_of_text(
      addtext_simple_font_with_metrics_for_test(None),
      @ascii.encode("A"),
    ),
    0.0,
  )
  @test.assert_eq(
    @pdflite.pdf_addtext_width_of_text(
      addtext_simple_font_with_metrics_for_test(Some([100.0])),
      @ascii.encode("A"),
    ),
    0.0,
  )
  @test.assert_eq(
    @pdflite.pdf_addtext_width_of_text(
      PdfFontStandard({ font: PdfHelvetica, encoding: PdfWinAnsiEncoding }),
      @ascii.encode("A"),
    ),
    0.0,
  )
}

///|
test "pdf_addtext_justification_offset handles horizontal rotations" {
  @test.assert_eq(
    addtext_offset_for_test(
      PdfAddTextRot0,
      PdfPositionTopLeft(0.0, 0.0),
      PdfAddTextLeftJustify,
    ),
    0.0,
  )
  @test.assert_eq(
    addtext_offset_for_test(
      PdfAddTextRot0,
      PdfPositionTop(0.0),
      PdfAddTextLeftJustify,
    ),
    20.0,
  )
  @test.assert_eq(
    addtext_offset_for_test(
      PdfAddTextRot0,
      PdfPositionTopRight(0.0, 0.0),
      PdfAddTextLeftJustify,
    ),
    40.0,
  )
  @test.assert_eq(
    addtext_offset_for_test(
      PdfAddTextRot0,
      PdfPositionTopLeft(0.0, 0.0),
      PdfAddTextRightJustify,
    ),
    -40.0,
  )
  @test.assert_eq(
    addtext_offset_for_test(
      PdfAddTextRot0,
      PdfPositionCentre,
      PdfAddTextRightJustify,
    ),
    -20.0,
  )
  @test.assert_eq(
    addtext_offset_for_test(
      PdfAddTextRot0,
      PdfPositionBottomRight(0.0, 0.0),
      PdfAddTextCentreJustify,
    ),
    20.0,
  )
}

///|
test "pdf_addtext_justification_offset swaps horizontal justification at 180 degrees" {
  @test.assert_eq(
    addtext_offset_for_test(
      PdfAddTextRot180,
      PdfPositionTopLeft(0.0, 0.0),
      PdfAddTextLeftJustify,
    ),
    -40.0,
  )
  @test.assert_eq(
    addtext_offset_for_test(
      PdfAddTextRot180,
      PdfPositionTopRight(0.0, 0.0),
      PdfAddTextRightJustify,
    ),
    40.0,
  )
}

///|
test "pdf_addtext_justification_offset handles vertical rotations" {
  @test.assert_eq(
    addtext_offset_for_test(
      PdfAddTextRot90,
      PdfPositionTop(0.0),
      PdfAddTextLeftJustify,
    ),
    0.0,
  )
  @test.assert_eq(
    addtext_offset_for_test(
      PdfAddTextRot90,
      PdfPositionLeft(0.0),
      PdfAddTextLeftJustify,
    ),
    20.0,
  )
  @test.assert_eq(
    addtext_offset_for_test(
      PdfAddTextRot90,
      PdfPositionBottom(0.0),
      PdfAddTextLeftJustify,
    ),
    40.0,
  )
  @test.assert_eq(
    addtext_offset_for_test(
      PdfAddTextRot90,
      PdfPositionTop(0.0),
      PdfAddTextRightJustify,
    ),
    -40.0,
  )
  @test.assert_eq(
    addtext_offset_for_test(
      PdfAddTextRot90,
      PdfPositionLeft(0.0),
      PdfAddTextRightJustify,
    ),
    -20.0,
  )
  @test.assert_eq(
    addtext_offset_for_test(
      PdfAddTextRot90,
      PdfPositionBottomRight(0.0, 0.0),
      PdfAddTextCentreJustify,
    ),
    20.0,
  )
}

///|
test "pdf_addtext_justification_offset swaps vertical justification at 270 degrees" {
  @test.assert_eq(
    addtext_offset_for_test(
      PdfAddTextRot270,
      PdfPositionTop(0.0),
      PdfAddTextLeftJustify,
    ),
    -40.0,
  )
  @test.assert_eq(
    addtext_offset_for_test(
      PdfAddTextRot270,
      PdfPositionBottom(0.0),
      PdfAddTextRightJustify,
    ),
    40.0,
  )
}

///|
test "pdf_addtext_justification_offset leaves diagonal positions unshifted" {
  @test.assert_eq(
    addtext_offset_for_test(
      PdfAddTextRot0,
      PdfPositionDiagonal,
      PdfAddTextRightJustify,
    ),
    0.0,
  )
  @test.assert_eq(
    addtext_offset_for_test(
      PdfAddTextRot90,
      PdfPositionReverseDiagonal,
      PdfAddTextCentreJustify,
    ),
    0.0,
  )
}

///|
test "pdf_addtext_get_urls_line strips one URL marker" {
  let parsed = try! @pdflite.pdf_addtext_get_urls_line(
    "pre %URL[label|https://example.test] post",
  )
  @test.assert_eq(parsed.text, "pre label post")
  @test.assert_eq(parsed.urls, [
    { url: "https://example.test", start: 4, end: 9 },
  ])
}

///|
test "pdf_addtext_get_urls_line preserves URL order and visible offsets" {
  let parsed = try! @pdflite.pdf_addtext_get_urls_line(
    "A%URL[B|u1]C%URL[DE|u2]",
  )
  @test.assert_eq(parsed.text, "ABCDE")
  @test.assert_eq(parsed.urls, [
    { url: "u1", start: 1, end: 2 },
    { url: "u2", start: 3, end: 5 },
  ])
}

///|
test "pdf_addtext_get_urls_line uses byte offsets for UTF-8 text" {
  let parsed = try! @pdflite.pdf_addtext_get_urls_line("é%URL[ß|u]")
  @test.assert_eq(parsed.text, "éß")
  @test.assert_eq(parsed.urls, [{ url: "u", start: 2, end: 4 }])
}

///|
test "pdf_addtext_get_urls_line reports malformed URL markers" {
  let missing_pipe : Result[@pdflite.PdfAddTextUrlLine, Error] = try? @pdflite.pdf_addtext_get_urls_line(
    "%URL[text]",
  )
  guard missing_pipe
    is Err(@pdflite.PdfError::SoftError("bad URL syntax in text")) else {
    fail("expected SoftError for URL marker without pipe")
  }
  let missing_close : Result[@pdflite.PdfAddTextUrlLine, Error] = try? @pdflite.pdf_addtext_get_urls_line(
    "%URL[text|https://example.test",
  )
  guard missing_close
    is Err(@pdflite.PdfError::SoftError("bad URL syntax in text")) else {
    fail("expected SoftError for URL marker without closing bracket")
  }
}

///|
test "pdf_addtext_process_text_with_time applies replacements before strftime" {
  let page_calls : Ref[Int] = { val: 0 }
  let replacements : Array[(String, () -> String)] = [
    (
      "%Page",
      fn() {
        page_calls.val += 1
        "7"
      },
    ),
    ("%Date", fn() { "%Y-%m-%d" }),
  ]
  @test.assert_eq(
    @pdflite.pdf_addtext_process_text_with_time(
      addtext_process_time_for_test(),
      "page %Page on %Date",
      replacements,
    ),
    "page 7 on 2023-09-03",
  )
  @test.assert_eq(page_calls.val, 1)
}

///|
test "pdf_addtext_process_text_with_time keeps lazy replacement order" {
  let absent_calls : Ref[Int] = { val: 0 }
  let one_calls : Ref[Int] = { val: 0 }
  let two_calls : Ref[Int] = { val: 0 }
  let replacements : Array[(String, () -> String)] = [
    (
      "%Absent",
      fn() {
        absent_calls.val += 1
        "bad"
      },
    ),
    (
      "%One",
      fn() {
        one_calls.val += 1
        "%Two"
      },
    ),
    (
      "%Two",
      fn() {
        two_calls.val += 1
        "ok"
      },
    ),
  ]
  @test.assert_eq(
    @pdflite.pdf_addtext_process_text_with_time(
      addtext_process_time_for_test(),
      "%One/%One/%Y",
      replacements,
    ),
    "ok/ok/2023",
  )
  @test.assert_eq(absent_calls.val, 0)
  @test.assert_eq(one_calls.val, 2)
  @test.assert_eq(two_calls.val, 2)
}

///|
test "pdf_addtext_process_text_with_time ignores empty replacement markers" {
  let calls : Ref[Int] = { val: 0 }
  let replacements : Array[(String, () -> String)] = [
    (
      "",
      fn() {
        calls.val += 1
        "ignored"
      },
    ),
  ]
  @test.assert_eq(
    @pdflite.pdf_addtext_process_text_with_time(
      addtext_process_time_for_test(),
      "%Y",
      replacements,
    ),
    "2023",
  )
  @test.assert_eq(calls.val, 0)
}

///|
test "pdf_addtext_split_at_newline matches cpdf literal line markers" {
  @test.assert_eq(@pdflite.pdf_addtext_split_at_newline("one\\ntwo\\n"), [
    "one", "two", "",
  ])
  @test.assert_eq(@pdflite.pdf_addtext_split_at_newline("one\\\\ntwo"), [
    "one\\\\ntwo",
  ])
  @test.assert_eq(@pdflite.pdf_addtext_split_at_newline("one\ntwo"), [
    "one\ntwo",
  ])
  @test.assert_eq(@pdflite.pdf_addtext_split_at_newline("é\\nß"), ["é", "ß"])
}

///|
test "pdf_addtext_unescape_string decodes cpdf add-text escapes" {
  @test.assert_eq(
    try! @pdflite.pdf_addtext_unescape_string("A\\101\\040B"),
    "AA B",
  )
  @test.assert_eq(
    try! @pdflite.pdf_addtext_unescape_string("slash\\\\mark"),
    "slash\\mark",
  )
  @test.assert_eq(
    try! @pdflite.pdf_addtext_unescape_string("x\\ty\\8z\\n"),
    "xty8z\\n",
  )
  @test.assert_eq(try! @pdflite.pdf_addtext_unescape_string("\\303\\251"), "é")
}

///|
test "pdf_addtext_unescape_string reports octal escapes outside byte range" {
  let result : Result[String, Error] = try? @pdflite.pdf_addtext_unescape_string(
    "\\777",
  )
  guard result is Err(@pdflite.PdfError::SoftError("bad add-text octal escape")) else {
    fail("expected SoftError for octal escape outside byte range")
  }
}

///|
test "pdf_addtext_lines_for_rotation prepares forward-rotation lines" {
  @test.assert_eq(
    try! @pdflite.pdf_addtext_lines_for_rotation(
      "A\\101\\nB\\\\C",
      PdfAddTextRot0,
    ),
    ["AA", "B\\C"],
  )
  @test.assert_eq(
    try! @pdflite.pdf_addtext_lines_for_rotation("one\\ntwo", PdfAddTextRot90),
    ["one", "two"],
  )
}

///|
test "pdf_addtext_lines_for_rotation reverses upside-down rotations" {
  @test.assert_eq(
    try! @pdflite.pdf_addtext_lines_for_rotation(
      "one\\ntwo\\nthree",
      PdfAddTextRot180,
    ),
    ["three", "two", "one"],
  )
  @test.assert_eq(
    try! @pdflite.pdf_addtext_lines_for_rotation(
      "one\\ntwo\\nthree",
      PdfAddTextRot270,
    ),
    ["three", "two", "one"],
  )
}

///|
test "pdf_addtext_expand_lines_with_time expands replacements and strips URLs" {
  let page_calls : Ref[Int] = { val: 0 }
  let replacements : Array[(String, () -> String)] = [
    (
      "%Page",
      fn() {
        page_calls.val += 1
        "3"
      },
    ),
  ]
  @test.assert_eq(
    try! @pdflite.pdf_addtext_expand_lines_with_time(
      addtext_process_time_for_test(),
      ["%Page %URL[link|https://example.test]", "plain %Y"],
      replacements,
    ),
    ["3 link", "plain 2023"],
  )
  @test.assert_eq(page_calls.val, 1)
}

///|
test "pdf_addtext_expand_lines_with_time reports malformed URL lines" {
  let result : Result[Array[String], Error] = try? @pdflite.pdf_addtext_expand_lines_with_time(
    addtext_process_time_for_test(),
    ["ok", "%URL[broken"],
    [],
  )
  guard result is Err(@pdflite.PdfError::SoftError("bad URL syntax in text")) else {
    fail("expected SoftError for malformed URL marker during line expansion")
  }
}

///|
test "pdf_addtext_bates_number formats optional zero padding" {
  @test.assert_eq(@pdflite.pdf_addtext_bates_number(98, 5, None), "102")
  @test.assert_eq(@pdflite.pdf_addtext_bates_number(98, 5, Some(4)), "0102")
  @test.assert_eq(@pdflite.pdf_addtext_bates_number(12345, 1, Some(3)), "12345")
}

///|
test "pdf_addtext_replacement_pairs builds cpdf addtext fields" {
  let values : @pdflite.PdfAddTextReplacementValues = {
    page_number: 5,
    end_page: 12,
    filename: "input.pdf",
    page_label: "v",
    end_label: "xii",
    bates: 98,
    bates_pad: Some(4),
    bookmarks: ["Intro", "Section"],
  }
  let processed = @pdflite.pdf_addtext_process_text_with_time(
    addtext_process_time_for_test(),
    "%PageDiv2|%Page|%Roman|%roman|%filename|%Label|" +
    "%EndPage|%EndLabel|%Bookmark0|%Bookmark1|%Bookmark4|%Bates",
    @pdflite.pdf_addtext_replacement_pairs(values),
  )
  @test.assert_eq(processed, "3|5|V|v|input.pdf|v|12|xii|Intro|Section||0102")
}

///|
test "PdfDocument addtext_page_label falls back to decimal labels" {
  let document = try! @pdflite.pdf_blank_document(10.0, 10.0, 3)
  @test.assert_eq(try! document.addtext_page_label(2), "2")
  @test.assert_eq(try! @pdflite.pdf_addtext_page_label(document, 3), "3")
}

///|
test "PdfDocument addtext_page_label renders existing page labels" {
  let document = try! @pdflite.pdf_blank_document(10.0, 10.0, 3)
  let labelled = try! document.write_page_labels([
    {
      label_style: PageLabelLowercaseRoman,
      label_prefix: Some(@ascii.encode("intro-")),
      start_page: 1,
      start_value: 1,
    },
  ])
  @test.assert_eq(try! labelled.addtext_page_label(3), "intro-iii")
}

///|
test "PdfDocument addtext_page_label decodes PDFDocString prefixes" {
  let document = try! @pdflite.pdf_blank_document(10.0, 10.0, 2)
  let prefix = try! @pdflite.pdf_pdfdocstring_of_utf8(@utf8.encode("A ☃-"))
  let labelled = try! document.write_page_labels([
    {
      label_style: PageLabelDecimalArabic,
      label_prefix: Some(prefix),
      start_page: 1,
      start_value: 1,
    },
  ])
  @test.assert_eq(try! labelled.addtext_page_label(2), "A ☃-2")
}

///|
test "PdfDocument addtext_bookmark_for_page picks current branch bookmarks" {
  let document = try! @pdflite.pdf_blank_document(10.0, 10.0, 5)
  let page_refs = try! document.page_reference_numbers()
  let bookmarks : Array[@pdflite.PdfBookmark] = [
    addtext_bookmark_for_test(0, "Chapter 1", page_refs[0]),
    addtext_bookmark_for_test(1, "Section 1.1", page_refs[1]),
    addtext_bookmark_for_test(1, "Section 1.2", page_refs[2]),
    addtext_bookmark_for_test(0, "Chapter 2", page_refs[3]),
    addtext_bookmark_for_test(1, "Section 2.1", page_refs[4]),
  ]
  @test.assert_eq(
    try! document.addtext_bookmark_for_page(bookmarks, 0, 3),
    "Chapter 1",
  )
  @test.assert_eq(
    try! document.addtext_bookmark_for_page(bookmarks, 1, 3),
    "Section 1.2",
  )
  @test.assert_eq(try! document.addtext_bookmark_for_page(bookmarks, 1, 4), "")
  @test.assert_eq(
    try! document.addtext_bookmark_for_page(bookmarks, 1, 5),
    "Section 2.1",
  )
}

///|
test "pdf_addtext_bookmark_for_page wrapper preserves lookup behavior" {
  let document = try! @pdflite.pdf_blank_document(10.0, 10.0, 2)
  let page_refs = try! document.page_reference_numbers()
  let bookmarks : Array[@pdflite.PdfBookmark] = [
    addtext_bookmark_for_test(0, "Intro ☃", page_refs[0]),
  ]
  @test.assert_eq(
    try! @pdflite.pdf_addtext_bookmark_for_page(document, bookmarks, 0, 2),
    "Intro ☃",
  )
}

///|
test "PdfDocument addtext_replacement_values derives labels and bookmarks" {
  let document = try! @pdflite.pdf_blank_document(10.0, 10.0, 5)
  let labelled = try! document.write_page_labels([
    {
      label_style: PageLabelDecimalArabic,
      label_prefix: Some(@ascii.encode("p.")),
      start_page: 1,
      start_value: 10,
    },
  ])
  let page_refs = try! labelled.page_reference_numbers()
  let bookmarks : Array[@pdflite.PdfBookmark] = [
    addtext_bookmark_for_test(0, "Chapter 1", page_refs[0]),
    addtext_bookmark_for_test(1, "Section 1.1", page_refs[1]),
    addtext_bookmark_for_test(1, "Section 1.2", page_refs[2]),
    addtext_bookmark_for_test(0, "Chapter 2", page_refs[3]),
  ]
  let values = try! labelled.addtext_replacement_values(
    bookmarks,
    3,
    5,
    "input.pdf",
    98,
    Some(4),
  )
  @test.assert_eq(values.page_label, "p.12")
  @test.assert_eq(values.end_label, "p.14")
  @test.assert_eq(values.bookmarks, ["Chapter 1", "Section 1.2", "", "", ""])
  @test.assert_eq(
    @pdflite.pdf_addtext_process_text_with_time(
      addtext_process_time_for_test(),
      "%Label|%EndLabel|%Bookmark0|%Bookmark1|%Bookmark2|%Bates",
      @pdflite.pdf_addtext_replacement_pairs(values),
    ),
    "p.12|p.14|Chapter 1|Section 1.2||0100",
  )
}

///|
test "pdf_addtext_replacement_values wrapper matches method" {
  let document = try! @pdflite.pdf_blank_document(10.0, 10.0, 1)
  let method_values = try! document.addtext_replacement_values(
    [],
    1,
    1,
    "input.pdf",
    7,
    None,
  )
  let wrapper_values = try! @pdflite.pdf_addtext_replacement_values(
    document,
    [],
    1,
    1,
    "input.pdf",
    7,
    None,
  )
  @test.assert_eq(wrapper_values, method_values)
}

///|
test "pdf_addtext_cap_height prefers simple font descriptors" {
  @test.assert_eq(
    @pdflite.pdf_addtext_cap_height(
      Some(addtext_simple_font_for_test(681.0)),
      "Helvetica",
    ),
    Some(681.0),
  )
}

///|
test "pdf_addtext_cap_height falls back to Standard 14 AFM data" {
  @test.assert_eq(
    @pdflite.pdf_addtext_cap_height(None, "Helvetica"),
    Some(718.0),
  )
  @test.assert_eq(@pdflite.pdf_addtext_cap_height(None, "Courier"), Some(562.0))
  @test.assert_eq(@pdflite.pdf_addtext_cap_height(None, "NotAFont"), None)
  @test.assert_eq(@pdflite.pdf_addtext_cap_height(None, "/Helvetica"), None)
}
