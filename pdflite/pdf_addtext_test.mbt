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
fn addtext_assert_rotation_offset_for_test(
  position : @pdflite.PdfPosition,
  rotation : @pdflite.PdfAddTextRotation,
  expected : (Double, Double),
) -> Unit raise {
  addtext_assert_pair_close_for_test(
    @pdflite.pdf_addtext_rotation_offsets(position, rotation, 40.0),
    expected,
  )
}

///|
fn addtext_assert_point_close_for_test(
  actual : @pdflite.Point2,
  expected : @pdflite.Point2,
) -> Unit raise {
  addtext_assert_close_for_test(actual.x, expected.x)
  addtext_assert_close_for_test(actual.y, expected.y)
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
fn addtext_standard_font_for_test() -> @pdflite.PdfFont {
  PdfFontStandard({ font: PdfHelvetica, encoding: PdfWinAnsiEncoding })
}

///|
test "pdf_addtext_colour_op maps fill colours to content operators" {
  @test.assert_eq(
    @pdflite.pdf_addtext_colour_op(PdfContentGrey(0.25)),
    Op_g(0.25),
  )
  @test.assert_eq(@pdflite.pdf_colour_op(PdfContentGrey(0.25)), Op_g(0.25))
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
    @pdflite.pdf_colour_op_stroke(PdfContentGrey(0.75)),
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
test "PdfDocument addtext_opacity_resources allocates graphics state" {
  let document = @pdflite.pdf_document_empty()
  let extgstate = addtext_name_for_test("/ExtGState")
  let gs0 = addtext_name_for_test("/gs0")
  let gs1 = addtext_name_for_test("/gs1")
  let ca = addtext_name_for_test("/ca")
  let ca_stroke = addtext_name_for_test("/CA")
  let resources : @pdflite.PdfObject = PdfDictionary([
    (extgstate, PdfDictionary([(gs0, PdfInteger(1))])),
  ])
  let (updated, name) = try! document.addtext_opacity_resources(resources, 0.25)
  @test.assert_eq(name, Some(gs1))
  guard updated.lookup_immediate(extgstate) is Some(resource_dictionary) else {
    fail("expected ExtGState resource dictionary")
  }
  @test.assert_eq(
    resource_dictionary.lookup_immediate(gs0),
    Some(PdfInteger(1)),
  )
  guard resource_dictionary.lookup_immediate(gs1) is Some(opacity_dictionary) else {
    fail("expected opacity graphics state")
  }
  @test.assert_eq(opacity_dictionary.lookup_immediate(ca), Some(PdfReal(0.25)))
  @test.assert_eq(
    opacity_dictionary.lookup_immediate(ca_stroke),
    Some(PdfReal(0.25)),
  )
}

///|
test "pdf_addtext_opacity_resources preserves opaque resources" {
  let document = @pdflite.pdf_document_empty()
  let resources : @pdflite.PdfObject = PdfDictionary([
    (addtext_name_for_test("/ProcSet"), PdfArray([])),
  ])
  @test.assert_eq(
    try! @pdflite.pdf_addtext_opacity_resources(document, resources, 1.0),
    (resources, None),
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
  let cases : Array[
    (@pdflite.PdfPosition, @pdflite.PdfAddTextRotation, (Double, Double)),
  ] = [
    (PdfPositionTopLeft(0.0, 0.0), PdfAddTextRot0, (0.0, 0.0)),
    (PdfPositionTopLeft(0.0, 0.0), PdfAddTextRot90, (0.0, 0.0)),
    (PdfPositionTopLeft(0.0, 0.0), PdfAddTextRot180, (40.0, 0.0)),
    (PdfPositionTopLeft(0.0, 0.0), PdfAddTextRot270, (0.0, -40.0)),
    (PdfPositionTop(0.0), PdfAddTextRot0, (0.0, 0.0)),
    (PdfPositionTop(0.0), PdfAddTextRot90, (20.0, 0.0)),
    (PdfPositionTop(0.0), PdfAddTextRot180, (40.0, 0.0)),
    (PdfPositionTop(0.0), PdfAddTextRot270, (20.0, -40.0)),
    (PdfPositionTopRight(0.0, 0.0), PdfAddTextRot0, (0.0, 0.0)),
    (PdfPositionTopRight(0.0, 0.0), PdfAddTextRot90, (40.0, 0.0)),
    (PdfPositionTopRight(0.0, 0.0), PdfAddTextRot180, (40.0, 0.0)),
    (PdfPositionTopRight(0.0, 0.0), PdfAddTextRot270, (40.0, -40.0)),
    (PdfPositionRight(0.0), PdfAddTextRot0, (0.0, 0.0)),
    (PdfPositionPosRight(0.0, 0.0), PdfAddTextRot90, (40.0, 20.0)),
    (PdfPositionRight(0.0), PdfAddTextRot180, (40.0, 0.0)),
    (PdfPositionPosRight(0.0, 0.0), PdfAddTextRot270, (40.0, -20.0)),
    (PdfPositionBottomRight(0.0, 0.0), PdfAddTextRot0, (0.0, 0.0)),
    (PdfPositionBottomRight(0.0, 0.0), PdfAddTextRot90, (40.0, 40.0)),
    (PdfPositionBottomRight(0.0, 0.0), PdfAddTextRot180, (40.0, 0.0)),
    (PdfPositionBottomRight(0.0, 0.0), PdfAddTextRot270, (40.0, 0.0)),
    (PdfPositionBottom(0.0), PdfAddTextRot0, (0.0, 0.0)),
    (PdfPositionBottom(0.0), PdfAddTextRot90, (20.0, 40.0)),
    (PdfPositionBottom(0.0), PdfAddTextRot180, (40.0, 0.0)),
    (PdfPositionBottom(0.0), PdfAddTextRot270, (20.0, 0.0)),
    (PdfPositionBottomLeft(0.0, 0.0), PdfAddTextRot0, (0.0, 0.0)),
    (PdfPositionBottomLeft(0.0, 0.0), PdfAddTextRot90, (0.0, 40.0)),
    (PdfPositionBottomLeft(0.0, 0.0), PdfAddTextRot180, (40.0, 0.0)),
    (PdfPositionBottomLeft(0.0, 0.0), PdfAddTextRot270, (0.0, 0.0)),
    (PdfPositionLeft(0.0), PdfAddTextRot0, (0.0, 0.0)),
    (PdfPositionPosLeft(0.0, 0.0), PdfAddTextRot90, (0.0, 20.0)),
    (PdfPositionLeft(0.0), PdfAddTextRot180, (40.0, 0.0)),
    (PdfPositionPosLeft(0.0, 0.0), PdfAddTextRot270, (0.0, -20.0)),
    (PdfPositionCentre, PdfAddTextRot0, (0.0, 0.0)),
    (PdfPositionPosCentre(0.0, 0.0), PdfAddTextRot90, (20.0, 20.0)),
    (PdfPositionCentre, PdfAddTextRot180, (40.0, 0.0)),
    (PdfPositionPosCentre(0.0, 0.0), PdfAddTextRot270, (20.0, -20.0)),
    (PdfPositionDiagonal, PdfAddTextRot180, (0.0, 0.0)),
    (PdfPositionReverseDiagonal, PdfAddTextRot270, (0.0, 0.0)),
  ]
  for item in cases {
    let (position, rotation, expected) = item
    addtext_assert_rotation_offset_for_test(position, rotation, expected)
  }
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
test "PdfDocument addtext_page_font_dictionary uses empty fallback" {
  let document = @pdflite.pdf_document_empty()
  let page = @pdflite.pdf_page_blank(@pdflite.paper_a4)
  @test.assert_eq(
    document.addtext_page_font_dictionary(page),
    PdfDictionary([]),
  )
}

///|
test "PdfDocument addtext_page_font_dictionary resolves indirect fonts" {
  let document = @pdflite.pdf_document_empty()
  let fonts : @pdflite.PdfObject = PdfDictionary([
    (addtext_name_for_test("/F0"), PdfInteger(1)),
  ])
  let number = document.add_object(fonts)
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    resources: PdfDictionary([
      (addtext_name_for_test("/Font"), PdfIndirect(number)),
    ]),
  }
  @test.assert_eq(
    @pdflite.pdf_addtext_page_font_dictionary(document, page),
    fonts,
  )
}

///|
test "PdfDocument addtext_page_font_dictionary preserves malformed values" {
  let document = @pdflite.pdf_document_empty()
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    resources: PdfDictionary([(addtext_name_for_test("/Font"), PdfInteger(7))]),
  }
  @test.assert_eq(document.addtext_page_font_dictionary(page), PdfInteger(7))
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
test "pdf_addtext_install_font_resource adds selected font dictionary" {
  let font_key = addtext_name_for_test("/Font")
  let procset = addtext_name_for_test("/ProcSet")
  let f0 = addtext_name_for_test("/F0")
  let f1 = addtext_name_for_test("/F1")
  let resources : @pdflite.PdfObject = PdfDictionary([(procset, PdfArray([]))])
  let fontdict : @pdflite.PdfObject = PdfDictionary([(f0, PdfInteger(1))])
  let updated = try! @pdflite.pdf_addtext_install_font_resource(
    resources,
    fontdict,
    f1,
    Some(PdfIndirect(10)),
  )
  @test.assert_eq(updated.lookup_immediate(procset), Some(PdfArray([])))
  guard updated.lookup_immediate(font_key) is Some(fonts) else {
    fail("expected updated font resource dictionary")
  }
  @test.assert_eq(fonts.lookup_immediate(f0), Some(PdfInteger(1)))
  @test.assert_eq(fonts.lookup_immediate(f1), Some(PdfIndirect(10)))
  @test.assert_eq(
    try! @pdflite.pdf_addtext_install_font_resource(
      resources,
      fontdict,
      f1,
      None,
    ),
    resources,
  )
}

///|
test "pdf_addtext_install_fontpack_resources adds embedded font dictionary" {
  let font_key = addtext_name_for_test("/Font")
  let f0 = addtext_name_for_test("/F0")
  let f1 = addtext_name_for_test("/F1")
  let f2 = addtext_name_for_test("/F2")
  let resources : @pdflite.PdfObject = PdfDictionary([])
  let fontdict : @pdflite.PdfObject = PdfDictionary([(f0, PdfInteger(1))])
  let updated = try! @pdflite.pdf_addtext_install_fontpack_resources(
    resources,
    fontdict,
    [f1, f2],
    [10, 11],
  )
  guard updated.lookup_immediate(font_key) is Some(fonts) else {
    fail("expected updated fontpack resource dictionary")
  }
  @test.assert_eq(fonts.lookup_immediate(f0), Some(PdfInteger(1)))
  @test.assert_eq(fonts.lookup_immediate(f1), Some(PdfIndirect(10)))
  @test.assert_eq(fonts.lookup_immediate(f2), Some(PdfIndirect(11)))
}

///|
test "PdfDocument addtext_selected_font_object writes standard fonts" {
  let document = @pdflite.pdf_document_empty()
  let reference = try! document.addtext_selected_font_object(
    Some(addtext_standard_font_for_test()),
  )
  @test.assert_eq(reference, Some(PdfIndirect(1)))
  let font_object = document.lookup_object_or_null(1)
  @test.assert_eq(
    font_object.lookup_immediate(addtext_name_for_test("/BaseFont")),
    Some(PdfNameObject(addtext_name_for_test("/Helvetica"))),
  )
}

///|
test "pdf_addtext_selected_font_object preserves existing-font mode" {
  let document = @pdflite.pdf_document_empty()
  @test.assert_eq(
    try! @pdflite.pdf_addtext_selected_font_object(document, None),
    None,
  )
}

///|
test "PdfDocument addtext_selected_font_object propagates writer errors" {
  let document = @pdflite.pdf_document_empty()
  let result : Result[@pdflite.PdfObject?, Error] = try? document.addtext_selected_font_object(
    Some(addtext_simple_font_for_test(700.0)),
  )
  guard result is Err(@pdflite.PdfError::FontWriteUnsupported) else {
    fail("expected unsupported selected font error")
  }
}

///|
test "PdfDocument addtext_resource_setup installs selected font and opacity" {
  let document = @pdflite.pdf_document_empty()
  let font_key = addtext_name_for_test("/Font")
  let extgstate = addtext_name_for_test("/ExtGState")
  let gs0 = addtext_name_for_test("/gs0")
  let f0 = addtext_name_for_test("/F0")
  let f1 = addtext_name_for_test("/F1")
  let ca = addtext_name_for_test("/ca")
  let ca_stroke = addtext_name_for_test("/CA")
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    resources: PdfDictionary([(font_key, PdfDictionary([(f0, PdfInteger(1))]))]),
  }
  let setup = try! document.addtext_resource_setup(
    page,
    Some(addtext_standard_font_for_test()),
    None,
    addtext_name_for_test("/Helvetica"),
    Some(PdfIndirect(10)),
    [],
    0.5,
  )
  @test.assert_eq(setup.unique_fontname, f1)
  @test.assert_eq(setup.unique_fontnames, [])
  @test.assert_eq(setup.extgstate_name, Some(gs0))
  guard setup.resources.lookup_immediate(font_key) is Some(fonts) else {
    fail("expected prepared font dictionary")
  }
  @test.assert_eq(fonts.lookup_immediate(f0), Some(PdfInteger(1)))
  @test.assert_eq(fonts.lookup_immediate(f1), Some(PdfIndirect(10)))
  guard setup.resources.lookup_immediate(extgstate) is Some(states) else {
    fail("expected prepared ExtGState dictionary")
  }
  guard states.lookup_immediate(gs0) is Some(opacity) else {
    fail("expected opacity resource")
  }
  @test.assert_eq(opacity.lookup_immediate(ca), Some(PdfReal(0.5)))
  @test.assert_eq(opacity.lookup_immediate(ca_stroke), Some(PdfReal(0.5)))
}

///|
test "pdf_addtext_resource_setup installs fontpack resources" {
  let document = @pdflite.pdf_document_empty()
  let font_key = addtext_name_for_test("/Font")
  let f0 = addtext_name_for_test("/F0")
  let f1 = addtext_name_for_test("/F1")
  let f2 = addtext_name_for_test("/F2")
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    resources: PdfDictionary([(font_key, PdfDictionary([(f0, PdfInteger(1))]))]),
  }
  let pack : @pdflite.PdfFontPack = {
    fonts: [
      addtext_standard_font_for_test(),
      addtext_simple_font_for_test(700.0),
    ],
    entries: [],
  }
  let setup = try! @pdflite.pdf_addtext_resource_setup(
    document,
    page,
    None,
    Some(pack),
    addtext_name_for_test("/Fallback"),
    None,
    [20, 21],
    1.0,
  )
  @test.assert_eq(setup.unique_fontname, f1)
  @test.assert_eq(setup.unique_fontnames, [f1, f2])
  @test.assert_eq(setup.extgstate_name, None)
  @test.assert_eq(setup.font_dictionary.lookup_immediate(f1), Some(PdfNull))
  guard setup.resources.lookup_immediate(font_key) is Some(fonts) else {
    fail("expected prepared fontpack dictionary")
  }
  @test.assert_eq(fonts.lookup_immediate(f0), Some(PdfInteger(1)))
  @test.assert_eq(fonts.lookup_immediate(f1), Some(PdfIndirect(20)))
  @test.assert_eq(fonts.lookup_immediate(f2), Some(PdfIndirect(21)))
}

///|
test "PdfDocument addtext_resource_setup preserves existing-font resources" {
  let document = @pdflite.pdf_document_empty()
  let font_key = addtext_name_for_test("/Font")
  let resource_name = addtext_name_for_test("/Fx")
  let fontdict : @pdflite.PdfObject = PdfDictionary([
    (resource_name, PdfIndirect(10)),
  ])
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    resources: PdfDictionary([(font_key, fontdict)]),
  }
  let setup = try! document.addtext_resource_setup(
    page,
    None,
    None,
    resource_name,
    Some(PdfIndirect(99)),
    [],
    0.25,
  )
  @test.assert_eq(setup.resources, page.resources)
  @test.assert_eq(setup.font_dictionary, fontdict)
  @test.assert_eq(setup.unique_fontname, resource_name)
  @test.assert_eq(setup.unique_fontnames, [])
  @test.assert_eq(setup.extgstate_name, None)
}

///|
test "PdfDocument addtext_line_page appends text and URL annotations" {
  let document = try! @pdflite.pdf_blank_document(100.0, 50.0, 1)
  let page = (try! document.pages_of_pagetree())[0]
  let font = addtext_standard_font_for_test()
  let stamped = try! document.addtext_line_page(
    page,
    addtext_process_time_for_test(),
    ["%URL[A|https://a.test]"],
    [],
    Some(font),
    None,
    addtext_name_for_test("/Helvetica"),
    Some(PdfIndirect(10)),
    [],
    10.0,
    "%URL[A|https://a.test]",
    PdfContentGrey(0.25),
    PdfPositionBottomLeft(10.0, 20.0),
    shift_x=2.0,
    shift_y=3.0,
    url_border=true,
  )
  @test.assert_eq(
    addtext_content_ops_for_test(document, stamped),
    try! @pdflite.pdf_addtext_text_ops(
      Some(font),
      None,
      12.0,
      23.0,
      0.0,
      0.0,
      0.0,
      false,
      1.0,
      addtext_name_for_test("/F0"),
      [],
      None,
      PdfContentGrey(0.25),
      10.0,
      "A",
      0.0,
      0.0,
      0.0,
    ),
  )
  guard stamped.resources.lookup_immediate(addtext_name_for_test("/Font"))
    is Some(fonts) else {
    fail("expected line-page font resources")
  }
  @test.assert_eq(
    fonts.lookup_immediate(addtext_name_for_test("/F0")),
    Some(PdfIndirect(10)),
  )
  guard stamped.rest.lookup_immediate(addtext_name_for_test("/Annots"))
    is Some(PdfArray([PdfIndirect(annotation_number)])) else {
    fail("expected URL annotation reference")
  }
  let annotation = document.lookup_object_or_null(annotation_number)
  guard annotation.lookup_immediate(addtext_name_for_test("/A")) is Some(action) else {
    fail("expected URL annotation action")
  }
  @test.assert_eq(
    action.lookup_immediate(addtext_name_for_test("/URI")),
    Some(PdfString(@utf8.encode("https://a.test"))),
  )
  @test.assert_eq(
    annotation.lookup_immediate(addtext_name_for_test("/BS")),
    Some(PdfDictionary([(addtext_name_for_test("/W"), PdfInteger(1))])),
  )
}

///|
test "pdf_addtext_line_page wrapper prepends existing font text without opacity" {
  let document = @pdflite.pdf_document_empty()
  let font_key = addtext_name_for_test("/Font")
  let extgstate = addtext_name_for_test("/ExtGState")
  let resource_name = addtext_name_for_test("/Fx")
  let font_object : @pdflite.PdfObject = PdfDictionary([
    (
      addtext_name_for_test("/Subtype"),
      PdfNameObject(addtext_name_for_test("/Type1")),
    ),
    (
      addtext_name_for_test("/BaseFont"),
      PdfNameObject(addtext_name_for_test("/Helvetica")),
    ),
  ])
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    resources: PdfDictionary([
      (font_key, PdfDictionary([(resource_name, font_object)])),
    ]),
    content: [try! @pdflite.pdf_content_stream_of_ops([Op_BT, Op_ET])],
  }
  let stamped = try! @pdflite.pdf_addtext_line_page(
    document,
    page,
    addtext_process_time_for_test(),
    ["A"],
    [],
    None,
    None,
    resource_name,
    None,
    [],
    10.0,
    "A",
    PdfContentGrey(0.0),
    PdfPositionBottomLeft(1.0, 2.0),
    opacity=0.25,
    underneath=true,
    fast=true,
  )
  @test.assert_eq(stamped.resources.lookup_immediate(extgstate), None)
  @test.assert_eq(
    addtext_content_ops_for_test(document, stamped),
    [
      ..try! @pdflite.pdf_addtext_text_ops(
        None,
        None,
        1.0,
        2.0,
        0.0,
        0.0,
        0.0,
        false,
        1.0,
        resource_name,
        [],
        None,
        PdfContentGrey(0.0),
        10.0,
        "A",
        0.0,
        0.0,
        0.0,
      ),
      Op_BT,
      Op_ET,
    ],
  )
}

///|
test "PdfDocument addtext_line_page emits resolved BaseFont resource names" {
  let document = @pdflite.pdf_document_empty()
  let font_key = addtext_name_for_test("/Font")
  let resource_name = addtext_name_for_test("/Fx")
  let basefont = addtext_name_for_test("/Helvetica")
  let font_object : @pdflite.PdfObject = PdfDictionary([
    (
      addtext_name_for_test("/Subtype"),
      PdfNameObject(addtext_name_for_test("/Type1")),
    ),
    (addtext_name_for_test("/BaseFont"), PdfNameObject(basefont)),
  ])
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    resources: PdfDictionary([
      (font_key, PdfDictionary([(resource_name, font_object)])),
    ]),
  }
  let stamped = try! document.addtext_line_page(
    page,
    addtext_process_time_for_test(),
    ["A"],
    [],
    None,
    None,
    basefont,
    None,
    [],
    10.0,
    "A",
    PdfContentGrey(0.0),
    PdfPositionBottomLeft(1.0, 2.0),
  )
  @test.assert_eq(stamped.resources, page.resources)
  @test.assert_eq(
    addtext_content_ops_for_test(document, stamped),
    try! @pdflite.pdf_addtext_text_ops(
      None,
      None,
      1.0,
      2.0,
      0.0,
      0.0,
      0.0,
      false,
      1.0,
      resource_name,
      [],
      None,
      PdfContentGrey(0.0),
      10.0,
      "A",
      0.0,
      0.0,
      0.0,
    ),
  )
}

///|
test "PdfDocument addtext_line_page encodes existing font text" {
  let document = @pdflite.pdf_document_empty()
  let font_key = addtext_name_for_test("/Font")
  let resource_name = addtext_name_for_test("/Fx")
  let basefont = addtext_name_for_test("/Helvetica")
  let font_object : @pdflite.PdfObject = PdfDictionary([
    (
      addtext_name_for_test("/Subtype"),
      PdfNameObject(addtext_name_for_test("/Type1")),
    ),
    (addtext_name_for_test("/BaseFont"), PdfNameObject(basefont)),
  ])
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    resources: PdfDictionary([
      (font_key, PdfDictionary([(resource_name, font_object)])),
    ]),
  }
  let stamped = try! document.addtext_line_page(
    page,
    addtext_process_time_for_test(),
    ["Aé☃"],
    [],
    None,
    None,
    basefont,
    None,
    [],
    10.0,
    "Aé☃",
    PdfContentGrey(0.0),
    PdfPositionBottomLeft(1.0, 2.0),
  )
  @test.assert_eq(
    addtext_content_ops_for_test(document, stamped),
    try! @pdflite.pdf_addtext_text_ops(
      Some(try! document.read_font(font_object)),
      None,
      1.0,
      2.0,
      0.0,
      0.0,
      0.0,
      false,
      1.0,
      resource_name,
      [],
      None,
      PdfContentGrey(0.0),
      10.0,
      "Aé☃",
      0.0,
      0.0,
      0.0,
    ),
  )
}

///|
test "PdfDocument addtext_page_lines advances selected-font paragraphs" {
  let document = try! @pdflite.pdf_blank_document(100.0, 50.0, 1)
  let page = (try! document.pages_of_pagetree())[0]
  let font = addtext_standard_font_for_test()
  let stamped = try! document.addtext_page_lines(
    page,
    addtext_process_time_for_test(),
    ["A", "B"],
    [],
    Some(font),
    None,
    addtext_name_for_test("/Helvetica"),
    Some(PdfIndirect(10)),
    [],
    10.0,
    1.0,
    PdfContentGrey(0.0),
    PdfPositionBottomLeft(0.0, 0.0),
  )
  @test.assert_eq(
    addtext_content_ops_for_test(document, stamped),
    [
      Op_q,
      ..try! @pdflite.pdf_addtext_text_ops(
        Some(font),
        None,
        0.0,
        0.0,
        0.0,
        0.0,
        -10.0,
        false,
        1.0,
        addtext_name_for_test("/F0"),
        [],
        None,
        PdfContentGrey(0.0),
        10.0,
        "A",
        0.0,
        0.0,
        0.0,
      ),
      Op_Q,
      ..try! @pdflite.pdf_addtext_text_ops(
        Some(font),
        None,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        false,
        1.0,
        addtext_name_for_test("/F1"),
        [],
        None,
        PdfContentGrey(0.0),
        10.0,
        "B",
        0.0,
        0.0,
        0.0,
      ),
    ],
  )
  guard stamped.resources.lookup_immediate(addtext_name_for_test("/Font"))
    is Some(fonts) else {
    fail("expected paragraph font resources")
  }
  @test.assert_eq(
    fonts.lookup_immediate(addtext_name_for_test("/F0")),
    Some(PdfIndirect(10)),
  )
  @test.assert_eq(
    fonts.lookup_immediate(addtext_name_for_test("/F1")),
    Some(PdfIndirect(10)),
  )
}

///|
test "pdf_addtext_page_lines wrapper applies baseline offsets" {
  let document = try! @pdflite.pdf_blank_document(100.0, 50.0, 1)
  let page = (try! document.pages_of_pagetree())[0]
  let font = addtext_standard_font_for_test()
  let stamped = try! @pdflite.pdf_addtext_page_lines(
    document,
    page,
    addtext_process_time_for_test(),
    ["A"],
    [],
    Some(font),
    None,
    addtext_name_for_test("/Helvetica"),
    Some(PdfIndirect(10)),
    [],
    10.0,
    1.0,
    PdfContentGrey(0.0),
    PdfPositionBottomLeft(0.0, 0.0),
    midline=true,
  )
  @test.assert_eq(
    addtext_content_ops_for_test(document, stamped),
    try! @pdflite.pdf_addtext_text_ops(
      Some(font),
      None,
      0.0,
      0.0,
      0.0,
      0.0,
      3.59,
      false,
      1.0,
      addtext_name_for_test("/F0"),
      [],
      None,
      PdfContentGrey(0.0),
      10.0,
      "A",
      0.0,
      0.0,
      0.0,
    ),
  )
}

///|
test "PdfDocument addtext_pages_with_font stamps selected pages with replacements" {
  let document = try! @pdflite.pdf_blank_document(100.0, 50.0, 2)
  let font = addtext_standard_font_for_test()
  let stamped = try! document.addtext_pages_with_font(
    [2],
    ["%Page"],
    addtext_process_time_for_test(),
    [],
    Some(font),
    None,
    addtext_name_for_test("/Helvetica"),
    Some(PdfIndirect(10)),
    [],
    10.0,
    1.0,
    PdfContentGrey(0.0),
    PdfPositionBottomLeft(1.0, 2.0),
    shift="2 3",
  )
  let pages = try! stamped.pages_of_pagetree()
  @test.assert_eq(pages[0].content.length(), 0)
  @test.assert_eq(
    addtext_content_ops_for_test(stamped, pages[1]),
    try! @pdflite.pdf_addtext_text_ops(
      Some(font),
      None,
      3.0,
      5.0,
      0.0,
      0.0,
      0.0,
      false,
      1.0,
      addtext_name_for_test("/F0"),
      [],
      None,
      PdfContentGrey(0.0),
      10.0,
      "2",
      0.0,
      0.0,
      0.0,
    ),
  )
}

///|
test "pdf_addtext_pages_with_font wrapper validates selected pages" {
  let document = try! @pdflite.pdf_blank_document(100.0, 50.0, 1)
  let result : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_addtext_pages_with_font(
    document,
    [2],
    ["A"],
    addtext_process_time_for_test(),
    [],
    Some(addtext_standard_font_for_test()),
    None,
    addtext_name_for_test("/Helvetica"),
    Some(PdfIndirect(10)),
    [],
    10.0,
    1.0,
    PdfContentGrey(0.0),
    PdfPositionBottomLeft(0.0, 0.0),
  )
  guard result
    is Err(
      @pdflite.PdfError::BadPageSpecification(
        "addtext_pages_with_font: range contains pages not present in pdf"
      )
    ) else {
    fail("expected BadPageSpecification for out-of-range addtext page")
  }
}

///|
test "PdfDocument addtexts_with_font prepares selected-font input" {
  let document = try! @pdflite.pdf_blank_document(100.0, 50.0, 2)
  let font = addtext_standard_font_for_test()
  let stamped = try! document.addtexts_with_font(
    [2],
    "%Page",
    addtext_process_time_for_test(),
    [],
    Some(font),
    None,
    addtext_name_for_test("/Helvetica"),
    10.0,
    1.0,
    PdfContentGrey(0.0),
    PdfPositionBottomLeft(1.0, 2.0),
    shift="2 3",
  )
  let pages = try! stamped.pages_of_pagetree()
  @test.assert_eq(pages[0].content.length(), 0)
  @test.assert_eq(
    addtext_content_ops_for_test(stamped, pages[1]),
    try! @pdflite.pdf_addtext_text_ops(
      Some(font),
      None,
      3.0,
      5.0,
      0.0,
      0.0,
      0.0,
      false,
      1.0,
      addtext_name_for_test("/F0"),
      [],
      None,
      PdfContentGrey(0.0),
      10.0,
      "2",
      0.0,
      0.0,
      0.0,
    ),
  )
}

///|
test "pdf_addtexts_with_font skips empty visible text before writing fonts" {
  let document = try! @pdflite.pdf_blank_document(100.0, 50.0, 1)
  let before = document.object_count()
  let stamped = try! @pdflite.pdf_addtexts_with_font(
    document,
    [1],
    "%URL[|https://example.test]",
    addtext_process_time_for_test(),
    [],
    Some(addtext_standard_font_for_test()),
    None,
    addtext_name_for_test("/Helvetica"),
    10.0,
    1.0,
    PdfContentGrey(0.0),
    PdfPositionBottomLeft(1.0, 2.0),
  )
  let pages = try! stamped.pages_of_pagetree()
  @test.assert_eq(stamped.object_count(), before)
  @test.assert_eq(pages[0].content.length(), 0)
}

///|
test "PdfDocument addtexts_with_source uses first premade fontpack font" {
  let document = try! @pdflite.pdf_blank_document(100.0, 50.0, 1)
  let first = addtext_standard_font_for_test()
  let second : @pdflite.PdfFont = PdfFontStandard({
    font: PdfTimesRoman,
    encoding: PdfWinAnsiEncoding,
  })
  let pack : @pdflite.PdfFontPack = { fonts: [first, second], entries: [] }
  let stamped = try! document.addtexts_with_source(
    [1],
    "A",
    addtext_process_time_for_test(),
    [],
    PdfAddTextPreMadeFontPack(pack),
    addtext_name_for_test("/Helvetica"),
    10.0,
    1.0,
    PdfContentGrey(0.0),
    PdfPositionBottomLeft(1.0, 2.0),
  )
  let page = (try! stamped.pages_of_pagetree())[0]
  @test.assert_eq(
    addtext_content_ops_for_test(stamped, page),
    try! @pdflite.pdf_addtext_text_ops(
      Some(first),
      None,
      1.0,
      2.0,
      0.0,
      0.0,
      0.0,
      false,
      1.0,
      addtext_name_for_test("/F0"),
      [],
      None,
      PdfContentGrey(0.0),
      10.0,
      "A",
      0.0,
      0.0,
      0.0,
    ),
  )
}

///|
test "PdfDocument addtexts_with_source delegates existing named fonts" {
  let base = try! @pdflite.pdf_blank_document(100.0, 50.0, 1)
  let pages = try! base.pages_of_pagetree()
  let font_key = addtext_name_for_test("/Font")
  let resource_name = addtext_name_for_test("/Fx")
  let basefont = addtext_name_for_test("/Helvetica")
  let font_object : @pdflite.PdfObject = PdfDictionary([
    (
      addtext_name_for_test("/Subtype"),
      PdfNameObject(addtext_name_for_test("/Type1")),
    ),
    (addtext_name_for_test("/BaseFont"), PdfNameObject(basefont)),
  ])
  let page = {
    ..pages[0],
    resources: PdfDictionary([
      (font_key, PdfDictionary([(resource_name, font_object)])),
    ]),
  }
  let document = try! base.change_pages([page])
  let stamped = try! document.addtexts_with_source(
    [1],
    "Aé☃",
    addtext_process_time_for_test(),
    [],
    PdfAddTextExistingNamedFont,
    basefont,
    10.0,
    1.0,
    PdfContentGrey(0.0),
    PdfPositionBottomLeft(1.0, 2.0),
  )
  let stamped_page = (try! stamped.pages_of_pagetree())[0]
  @test.assert_eq(
    addtext_content_ops_for_test(stamped, stamped_page),
    try! @pdflite.pdf_addtext_text_ops(
      Some(try! document.read_font(font_object)),
      None,
      1.0,
      2.0,
      0.0,
      0.0,
      0.0,
      false,
      1.0,
      resource_name,
      [],
      None,
      PdfContentGrey(0.0),
      10.0,
      "Aé☃",
      0.0,
      0.0,
      0.0,
    ),
  )
}

///|
test "pdf_addtexts_with_source skips empty visible text before resolving sources" {
  let document = try! @pdflite.pdf_blank_document(100.0, 50.0, 1)
  let before = document.object_count()
  let empty_pack : @pdflite.PdfFontPack = { fonts: [], entries: [] }
  let stamped = try! @pdflite.pdf_addtexts_with_source(
    document,
    [1],
    "%URL[|https://example.test]",
    addtext_process_time_for_test(),
    [],
    PdfAddTextPreMadeFontPack(empty_pack),
    addtext_name_for_test("/Helvetica"),
    10.0,
    1.0,
    PdfContentGrey(0.0),
    PdfPositionBottomLeft(1.0, 2.0),
  )
  let pages = try! stamped.pages_of_pagetree()
  @test.assert_eq(stamped.object_count(), before)
  @test.assert_eq(pages[0].content.length(), 0)
}

///|
test "pdf_addtexts_with_source rejects empty premade fontpacks" {
  let document = try! @pdflite.pdf_blank_document(100.0, 50.0, 1)
  let empty_pack : @pdflite.PdfFontPack = { fonts: [], entries: [] }
  let result : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_addtexts_with_source(
    document,
    [1],
    "A",
    addtext_process_time_for_test(),
    [],
    PdfAddTextPreMadeFontPack(empty_pack),
    addtext_name_for_test("/Helvetica"),
    10.0,
    1.0,
    PdfContentGrey(0.0),
    PdfPositionBottomLeft(1.0, 2.0),
  )
  guard result
    is Err(@pdflite.PdfError::SoftError("addtexts: fontpack is empty")) else {
    fail("expected empty premade fontpack diagnostic")
  }
}

///|
test "PdfDocument addtext_existing_font_resource finds direct resource keys" {
  let document = @pdflite.pdf_document_empty()
  let resource_name = addtext_name_for_test("/F1")
  let font_object : @pdflite.PdfObject = PdfDictionary([
    (
      addtext_name_for_test("/BaseFont"),
      PdfNameObject(addtext_name_for_test("/Helvetica")),
    ),
  ])
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    resources: PdfDictionary([
      (
        addtext_name_for_test("/Font"),
        PdfDictionary([(resource_name, font_object)]),
      ),
    ]),
  }
  @test.assert_eq(
    try! document.addtext_existing_font_resource(page, resource_name),
    (resource_name, font_object),
  )
}

///|
test "PdfDocument addtext_existing_font_resource falls back to BaseFont names" {
  let document = @pdflite.pdf_document_empty()
  let resource_name = addtext_name_for_test("/F1")
  let basefont = addtext_name_for_test("/Helvetica")
  document.add_object_given_number(
    10,
    PdfDictionary([
      (addtext_name_for_test("/BaseFont"), PdfNameObject(basefont)),
    ]),
  )
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    resources: PdfDictionary([
      (
        addtext_name_for_test("/Font"),
        PdfDictionary([(resource_name, PdfIndirect(10))]),
      ),
    ]),
  }
  @test.assert_eq(
    try! @pdflite.pdf_addtext_existing_font_resource(document, page, basefont),
    (resource_name, PdfIndirect(10)),
  )
}

///|
test "PdfDocument addtext_existing_font_resource reports missing fonts" {
  let document = @pdflite.pdf_document_empty()
  let basefont = addtext_name_for_test("/Helvetica")
  let missing_dictionary : Result[(@pdflite.PdfName, @pdflite.PdfObject), Error] = try? document.addtext_existing_font_resource(
    @pdflite.pdf_page_blank(@pdflite.paper_a4),
    basefont,
  )
  guard missing_dictionary
    is Err(@pdflite.PdfError::SoftError("addtext: font dictionary not present")) else {
    fail("expected missing font dictionary error")
  }
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    resources: PdfDictionary([
      (addtext_name_for_test("/Font"), PdfDictionary([])),
    ]),
  }
  let missing_font : Result[(@pdflite.PdfName, @pdflite.PdfObject), Error] = try? document.addtext_existing_font_resource(
    page, basefont,
  )
  guard missing_font
    is Err(@pdflite.PdfError::SoftError("addtext: font /Helvetica not found")) else {
    fail("expected missing font error")
  }
}

///|
test "PdfDocument addtext_width_of_existing_font_resource measures direct keys" {
  let document = @pdflite.pdf_document_empty()
  let resource_name = addtext_name_for_test("/F1")
  let font_object : @pdflite.PdfObject = PdfDictionary([
    (
      addtext_name_for_test("/Subtype"),
      PdfNameObject(addtext_name_for_test("/Type1")),
    ),
    (
      addtext_name_for_test("/BaseFont"),
      PdfNameObject(addtext_name_for_test("/Helvetica")),
    ),
  ])
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    resources: PdfDictionary([
      (
        addtext_name_for_test("/Font"),
        PdfDictionary([(resource_name, font_object)]),
      ),
    ]),
  }
  let result = try! document.addtext_width_of_existing_font_resource(
    page,
    resource_name,
    12.0,
    @ascii.encode("ABC"),
  )
  let expected = @pdflite.pdf_addtext_width_of_selected_font(
    try! document.read_font(font_object),
    12.0,
    @ascii.encode("ABC"),
  )
  @test.assert_eq(result.0, resource_name)
  addtext_assert_close_for_test(result.1, expected)
}

///|
test "PdfDocument addtext_width_of_existing_font_resource returns fallback resource name" {
  let document = @pdflite.pdf_document_empty()
  let resource_name = addtext_name_for_test("/Fx")
  let basefont = addtext_name_for_test("/Helvetica")
  let font_object : @pdflite.PdfObject = PdfDictionary([
    (
      addtext_name_for_test("/Subtype"),
      PdfNameObject(addtext_name_for_test("/Type1")),
    ),
    (addtext_name_for_test("/BaseFont"), PdfNameObject(basefont)),
  ])
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    resources: PdfDictionary([
      (
        addtext_name_for_test("/Font"),
        PdfDictionary([(resource_name, font_object)]),
      ),
    ]),
  }
  let result = try! @pdflite.pdf_addtext_width_of_existing_font_resource(
    document,
    page,
    basefont,
    10.0,
    @ascii.encode("A"),
  )
  @test.assert_eq(result.0, resource_name)
  @test.assert_eq(result.1 > 0.0, true)
}

///|
test "pdf_addtext_url_annotation builds cpdf link annotation objects" {
  let annotation = @pdflite.pdf_addtext_url_annotation(
    @pdflite.point2(1.0, 2.0),
    @pdflite.point2(3.0, 4.0),
    @pdflite.point2(5.0, 6.0),
    @pdflite.point2(7.0, 8.0),
    { min_x: 1.0, min_y: 2.0, max_x: 7.0, max_y: 8.0 },
    "https://example.test",
    true,
  )
  let expected : @pdflite.PdfObject = PdfDictionary([
    (
      addtext_name_for_test("/Subtype"),
      PdfNameObject(addtext_name_for_test("/Link")),
    ),
    (
      addtext_name_for_test("/QuadPoints"),
      PdfArray([
        PdfReal(1.0),
        PdfReal(2.0),
        PdfReal(7.0),
        PdfReal(8.0),
        PdfReal(3.0),
        PdfReal(4.0),
        PdfReal(5.0),
        PdfReal(6.0),
      ]),
    ),
    (
      addtext_name_for_test("/Rect"),
      PdfArray([PdfReal(1.0), PdfReal(2.0), PdfReal(7.0), PdfReal(8.0)]),
    ),
    (
      addtext_name_for_test("/BS"),
      PdfDictionary([(addtext_name_for_test("/W"), PdfInteger(1))]),
    ),
    (
      addtext_name_for_test("/A"),
      PdfDictionary([
        (
          addtext_name_for_test("/URI"),
          PdfString(@utf8.encode("https://example.test")),
        ),
        (
          addtext_name_for_test("/Type"),
          PdfNameObject(addtext_name_for_test("/Action")),
        ),
        (
          addtext_name_for_test("/S"),
          PdfNameObject(addtext_name_for_test("/URI")),
        ),
      ]),
    ),
  ])
  @test.assert_eq(annotation, expected)
  let hidden_border = @pdflite.pdf_addtext_url_annotation(
    @pdflite.point2(1.0, 2.0),
    @pdflite.point2(3.0, 4.0),
    @pdflite.point2(5.0, 6.0),
    @pdflite.point2(7.0, 8.0),
    addtext_bounds_for_test(),
    "https://example.test",
    false,
  )
  guard hidden_border.lookup_immediate(addtext_name_for_test("/BS")) is Some(bs) else {
    fail("expected URL border dictionary")
  }
  @test.assert_eq(
    bs.lookup_immediate(addtext_name_for_test("/W")),
    Some(PdfInteger(0)),
  )
}

///|
test "pdf_addtext_url_annotation_height uses cap height and font-size fallback" {
  addtext_assert_close_for_test(
    @pdflite.pdf_addtext_url_annotation_height(None, "Helvetica", 10.0),
    7.18,
  )
  @test.assert_eq(
    @pdflite.pdf_addtext_url_annotation_height(None, "NotAFont", 10.0),
    10.0,
  )
}

///|
test "pdf_addtext_url_annotation_geometry builds unrotated quads and bounds" {
  let geometry = @pdflite.pdf_addtext_url_annotation_geometry(
    @pdflite.point2(100.0, 200.0),
    10.0,
    20.0,
    5.0,
    0.0,
    @pdflite.point2(0.0, 0.0),
    0.0,
    3.0,
    13.0,
    7.0,
  )
  @test.assert_eq(geometry.p0, @pdflite.point2(88.0, 180.0))
  @test.assert_eq(geometry.p1, @pdflite.point2(98.0, 187.0))
  @test.assert_eq(geometry.p2, @pdflite.point2(88.0, 187.0))
  @test.assert_eq(geometry.p3, @pdflite.point2(98.0, 180.0))
  @test.assert_eq(geometry.rectangle, {
    min_x: 88.0,
    min_y: 180.0,
    max_x: 98.0,
    max_y: 187.0,
  })
}

///|
test "pdf_addtext_url_annotation_geometry applies rotation before offset" {
  let geometry = @pdflite.pdf_addtext_url_annotation_geometry(
    @pdflite.point2(10.0, 20.0),
    0.0,
    0.0,
    0.0,
    @math.PI / 2.0,
    @pdflite.point2(1.0, 2.0),
    0.0,
    0.0,
    4.0,
    2.0,
  )
  addtext_assert_point_close_for_test(geometry.p0, @pdflite.point2(11.0, 22.0))
  addtext_assert_point_close_for_test(geometry.p1, @pdflite.point2(9.0, 26.0))
  addtext_assert_point_close_for_test(geometry.p2, @pdflite.point2(9.0, 22.0))
  addtext_assert_point_close_for_test(geometry.p3, @pdflite.point2(11.0, 26.0))
  addtext_assert_close_for_test(geometry.rectangle.min_x, 9.0)
  addtext_assert_close_for_test(geometry.rectangle.min_y, 22.0)
  addtext_assert_close_for_test(geometry.rectangle.max_x, 11.0)
  addtext_assert_close_for_test(geometry.rectangle.max_y, 26.0)
}

///|
test "pdf_addtext_url_annotation_widths measures span prefixes" {
  let span : @pdflite.PdfAddTextUrl = { url: "u", start: 1, end: 4 }
  @test.assert_eq(
    try! @pdflite.pdf_addtext_url_annotation_widths("abcde", span, fn(prefix) {
      prefix.length().to_double() * 2.0
    }),
    (2.0, 8.0),
  )
}

///|
test "pdf_addtext_url_annotation_widths uses UTF-8 byte offsets" {
  let span : @pdflite.PdfAddTextUrl = { url: "u", start: 2, end: 3 }
  @test.assert_eq(
    try! @pdflite.pdf_addtext_url_annotation_widths("éx", span, fn(prefix) {
      @utf8.encode(prefix).length().to_double()
    }),
    (2.0, 3.0),
  )
  let bad : Result[(Double, Double), Error] = try? @pdflite.pdf_addtext_url_annotation_widths(
    "é",
    { url: "u", start: 1, end: 2 },
    fn(prefix) { prefix.length().to_double() },
  )
  guard bad is Err(@pdflite.PdfError::SoftError("bad add-text URL byte offset")) else {
    fail("expected invalid UTF-8 span offset to raise SoftError")
  }
}

///|
test "PdfDocument addtext_url_annotation_references creates indirect links" {
  let document = @pdflite.pdf_document_empty()
  let urls : Array[@pdflite.PdfAddTextUrl] = [
    { url: "https://a.test", start: 1, end: 3 },
    { url: "https://b.test", start: 0, end: 4 },
  ]
  let refs = try! document.addtext_url_annotation_references(
    "abcd",
    urls,
    fn(prefix) { prefix.length().to_double() * 2.0 },
    @pdflite.point2(100.0, 200.0),
    10.0,
    20.0,
    5.0,
    0.0,
    @pdflite.point2(0.0, 0.0),
    0.0,
    None,
    "NotAFont",
    7.0,
    true,
  )
  @test.assert_eq(refs.length(), 2)
  guard refs[0] is PdfIndirect(first_number) else {
    fail("expected first annotation reference")
  }
  let first = document.lookup_object_or_null(first_number)
  guard first is PdfDictionary(_) else {
    fail("expected first annotation object")
  }
  @test.assert_eq(
    first.lookup_immediate(addtext_name_for_test("/Rect")),
    Some(
      PdfArray([PdfReal(87.0), PdfReal(180.0), PdfReal(91.0), PdfReal(187.0)]),
    ),
  )
  @test.assert_eq(
    first.lookup_immediate(addtext_name_for_test("/QuadPoints")),
    Some(
      PdfArray([
        PdfReal(87.0),
        PdfReal(180.0),
        PdfReal(91.0),
        PdfReal(180.0),
        PdfReal(91.0),
        PdfReal(187.0),
        PdfReal(87.0),
        PdfReal(187.0),
      ]),
    ),
  )
  guard first.lookup_immediate(addtext_name_for_test("/A")) is Some(action) else {
    fail("expected link action")
  }
  @test.assert_eq(
    action.lookup_immediate(addtext_name_for_test("/URI")),
    Some(PdfString(@utf8.encode("https://a.test"))),
  )
}

///|
test "pdf_addtext_url_annotation_references wrapper propagates measure errors" {
  let document = @pdflite.pdf_document_empty()
  let urls : Array[@pdflite.PdfAddTextUrl] = [
    { url: "https://a.test", start: 0, end: 2 },
  ]
  let result : Result[Array[@pdflite.PdfObject], Error] = try? @pdflite.pdf_addtext_url_annotation_references(
    document,
    "ab",
    urls,
    fn(prefix) raise @pdflite.PdfError {
      if prefix.length() == 2 {
        raise SoftError("measure failed")
      }
      prefix.length().to_double()
    },
    @pdflite.point2(0.0, 0.0),
    0.0,
    0.0,
    0.0,
    0.0,
    @pdflite.point2(0.0, 0.0),
    0.0,
    Some(addtext_simple_font_for_test(500.0)),
    "Ignored",
    10.0,
    false,
  )
  guard result is Err(@pdflite.PdfError::SoftError("measure failed")) else {
    fail("expected measure error")
  }
}

///|
test "pdf_addtext_page_rest_with_annotations preserves empty annotation updates" {
  let document = @pdflite.pdf_document_empty()
  let rest : @pdflite.PdfObject = PdfInteger(7)
  let annotations : Array[@pdflite.PdfObject] = []
  @test.assert_eq(
    try! document.addtext_page_rest_with_annotations(rest, annotations),
    rest,
  )
}

///|
test "pdf_addtext_page_rest_with_annotations prepends resolved existing arrays" {
  let document = @pdflite.pdf_document_empty()
  let existing_number = document.add_object(PdfArray([PdfIndirect(30)]))
  let key_annots = addtext_name_for_test("/Annots")
  let key_other = addtext_name_for_test("/Other")
  let rest : @pdflite.PdfObject = PdfDictionary([
    (key_annots, PdfIndirect(existing_number)),
    (key_other, PdfInteger(5)),
  ])
  let annotations : Array[@pdflite.PdfObject] = [
    PdfIndirect(10),
    PdfIndirect(11),
  ]
  let updated = try! document.addtext_page_rest_with_annotations(
    rest, annotations,
  )
  @test.assert_eq(
    updated.lookup_immediate(key_annots),
    Some(PdfArray([PdfIndirect(10), PdfIndirect(11), PdfIndirect(30)])),
  )
  @test.assert_eq(updated.lookup_immediate(key_other), Some(PdfInteger(5)))
}

///|
test "pdf_addtext_page_rest_with_annotations treats malformed annots as empty" {
  let document = @pdflite.pdf_document_empty()
  let key_annots = addtext_name_for_test("/Annots")
  let rest : @pdflite.PdfObject = PdfDictionary([(key_annots, PdfInteger(99))])
  let annotations : Array[@pdflite.PdfObject] = [PdfIndirect(20)]
  let updated = try! @pdflite.pdf_addtext_page_rest_with_annotations(
    document, rest, annotations,
  )
  @test.assert_eq(
    updated.lookup_immediate(key_annots),
    Some(PdfArray([PdfIndirect(20)])),
  )
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
  let source_order = try! @pdflite.pdf_addrectangle(
    true,
    "20 10",
    PdfContentGrey(0.5),
    true,
    1.25,
    0.5,
    PdfPositionCentre,
    "/CropBox",
    true,
    [1],
    document,
  )
  let stamped_pages = try! stamped.pages_of_pagetree()
  let source_order_pages = try! source_order.pages_of_pagetree()
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
  @test.assert_eq(
    addtext_content_ops_for_test(source_order, source_order_pages[0]),
    addtext_content_ops_for_test(stamped, stamped_pages[0]),
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
