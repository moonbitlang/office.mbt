///|
fn addtext_layout_offset_for_test(
  rotation : @addtext.PdfAddTextRotation,
  position : @pdflite.PdfPosition,
  justification : @addtext.PdfAddTextJustification,
) -> Double {
  @addtext.pdf_addtext_justification_offset(
    rotation, 100.0, 60.0, position, justification,
  )
}

///|
fn addtext_layout_assert_close_for_test(
  actual : Double,
  expected : Double,
) -> Unit raise {
  if (actual - expected).abs() > 0.000000001 {
    fail("addtext values were not close enough")
  }
}

///|
fn addtext_layout_process_time_for_test() -> @date.PdfStrftimeTime {
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
fn addtext_layout_pdfdoc_text_for_test(text : String) -> @pdflite.PdfBytes {
  try! @pdflite.pdf_pdfdocstring_of_utf8(@utf8.encode(text))
}

///|
fn addtext_layout_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn addtext_layout_bounds_for_test() -> @pdflite.PdfRectangle {
  { min_x: 0.0, min_y: 0.0, max_x: 100.0, max_y: 50.0 }
}

///|
fn addtext_layout_bookmark_for_test(
  level : Int,
  text : String,
  page_object : Int,
) -> @bookmark.PdfBookmark {
  {
    level,
    text: addtext_layout_pdfdoc_text_for_test(text),
    target: DestFit(TargetPageObject(page_object)),
    is_open: true,
    colour: { red: 0.0, green: 0.0, blue: 0.0 },
    flags: 0,
  }
}

///|
fn addtext_layout_font_descriptor_for_test(
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
fn addtext_layout_simple_font_for_test(capheight : Double) -> @pdflite.PdfFont {
  PdfFontSimple({
    fonttype: PdfType1,
    basefont: None,
    firstchar: 0,
    lastchar: -1,
    widths: [],
    fontdescriptor: Some(addtext_layout_font_descriptor_for_test(capheight)),
    fontmetrics: None,
    encoding: PdfWinAnsiEncoding,
  })
}

///|
fn addtext_layout_simple_font_with_metrics_for_test(
  metrics : Array[Double]?,
) -> @pdflite.PdfFont {
  PdfFontSimple({
    fonttype: PdfType1,
    basefont: None,
    firstchar: 0,
    lastchar: 255,
    widths: [],
    fontdescriptor: Some(addtext_layout_font_descriptor_for_test(0.0)),
    fontmetrics: metrics,
    encoding: PdfWinAnsiEncoding,
  })
}

///|
fn addtext_layout_standard_font_for_test() -> @pdflite.PdfFont {
  PdfFontStandard({ font: PdfHelvetica, encoding: PdfWinAnsiEncoding })
}

///|
test "pdf_addtext_width_of_text sums simple font metrics" {
  let metrics : Array[Double] = [ for _ in 0..<256 => 0.0 ]
  metrics[65] = 500.0
  metrics[66] = 610.0
  let font = addtext_layout_simple_font_with_metrics_for_test(Some(metrics))
  @test.assert_eq(
    @pdflite.pdf_addtext_width_of_text(font, @ascii.encode("ABA")),
    1610.0,
  )
}

///|
test "pdf_addtext_width_of_text mirrors cpdf zero fallbacks" {
  @test.assert_eq(
    @pdflite.pdf_addtext_width_of_text(
      addtext_layout_simple_font_with_metrics_for_test(None),
      @ascii.encode("A"),
    ),
    0.0,
  )
  @test.assert_eq(
    @pdflite.pdf_addtext_width_of_text(
      addtext_layout_simple_font_with_metrics_for_test(Some([100.0])),
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
test "pdf_addtext_width_of_selected_font scales parsed font widths" {
  addtext_layout_assert_close_for_test(
    @pdflite.pdf_addtext_width_of_selected_font(
      addtext_layout_standard_font_for_test(),
      10.0,
      @ascii.encode("AV"),
    ),
    13.34,
  )
  let metrics : Array[Double] = [ for _ in 0..<256 => 0.0 ]
  metrics[65] = 500.0
  metrics[66] = 610.0
  addtext_layout_assert_close_for_test(
    @pdflite.pdf_addtext_width_of_selected_font(
      addtext_layout_simple_font_with_metrics_for_test(Some(metrics)),
      10.0,
      @ascii.encode("AB"),
    ),
    11.1,
  )
  addtext_layout_assert_close_for_test(
    @pdflite.pdf_addtext_width_of_selected_font(
      addtext_layout_simple_font_with_metrics_for_test(None),
      10.0,
      @ascii.encode("AB"),
    ),
    0.0,
  )
}

///|
test "pdf_addtext_width_of_fontpack sums mapped codepoint widths" {
  let metrics : Array[Double] = [ for _ in 0..<256 => 0.0 ]
  metrics[66] = 610.0
  let pack : @pdflite.PdfFontPack = {
    fonts: [
      addtext_layout_standard_font_for_test(),
      addtext_layout_simple_font_with_metrics_for_test(Some(metrics)),
    ],
    entries: [
      { codepoint: 65, font_index: 0, charcode: 65 },
      { codepoint: 66, font_index: 1, charcode: 66 },
    ],
  }
  addtext_layout_assert_close_for_test(
    try! @pdflite.pdf_addtext_width_of_fontpack(pack, 10.0, "ABC"),
    12.77,
  )
  let bad_pack : @pdflite.PdfFontPack = {
    fonts: [addtext_layout_simple_font_with_metrics_for_test(None)],
    entries: [{ codepoint: 65, font_index: 0, charcode: 65 }],
  }
  let result : Result[Double, Error] = try? @pdflite.pdf_addtext_width_of_fontpack(
    bad_pack, 10.0, "A",
  )
  guard result is Err(@pdflite.PdfError::FontWidthExpected) else {
    fail("expected FontWidthExpected for fontpack font without metrics")
  }
}

///|
test "PdfDocument addtext_calc_textwidth measures selected fonts" {
  let document = @pdflite.pdf_document_empty()
  let page = @pdflite.pdf_page_blank(@pdflite.paper_a4)
  addtext_layout_assert_close_for_test(
    try! document.addtext_calc_textwidth(
      page,
      Some(addtext_layout_standard_font_for_test()),
      None,
      addtext_layout_name_for_test("/F0"),
      10.0,
      @ascii.encode("AV"),
    ),
    13.34,
  )
}

///|
test "PdfDocument addtext_calc_textwidth measures fontpacks from UTF-8" {
  let document = @pdflite.pdf_document_empty()
  let page = @pdflite.pdf_page_blank(@pdflite.paper_a4)
  let metrics : Array[Double] = [ for _ in 0..<256 => 0.0 ]
  metrics[66] = 610.0
  let pack : @pdflite.PdfFontPack = {
    fonts: [
      addtext_layout_standard_font_for_test(),
      addtext_layout_simple_font_with_metrics_for_test(Some(metrics)),
    ],
    entries: [
      { codepoint: 65, font_index: 0, charcode: 65 },
      { codepoint: 66, font_index: 1, charcode: 66 },
    ],
  }
  addtext_layout_assert_close_for_test(
    try! @pdflite.pdf_addtext_calc_textwidth(
      document,
      page,
      None,
      Some(pack),
      addtext_layout_name_for_test("/F0"),
      10.0,
      @utf8.encode("ABC"),
    ),
    12.77,
  )
  let bad : Result[Double, Error] = try? document.addtext_calc_textwidth(
    page,
    None,
    Some(pack),
    addtext_layout_name_for_test("/F0"),
    10.0,
    [0xFF],
  )
  guard bad is Err(@pdflite.PdfError::InvalidUTF8) else {
    fail("expected InvalidUTF8 for malformed fontpack text")
  }
}

///|
test "PdfDocument addtext_calc_textwidth measures existing page fonts" {
  let document = @pdflite.pdf_document_empty()
  let resource_name = addtext_layout_name_for_test("/F1")
  let basefont = addtext_layout_name_for_test("/Helvetica")
  let font_object : @pdflite.PdfObject = PdfDictionary([
    (
      addtext_layout_name_for_test("/Subtype"),
      PdfNameObject(addtext_layout_name_for_test("/Type1")),
    ),
    (addtext_layout_name_for_test("/BaseFont"), PdfNameObject(basefont)),
  ])
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    resources: PdfDictionary([
      (
        addtext_layout_name_for_test("/Font"),
        PdfDictionary([(resource_name, font_object)]),
      ),
    ]),
  }
  let expected = try! document.addtext_width_of_existing_font_resource(
    page,
    resource_name,
    10.0,
    @ascii.encode("A"),
  )
  addtext_layout_assert_close_for_test(
    try! document.addtext_calc_textwidth(
      page,
      None,
      None,
      resource_name,
      10.0,
      @ascii.encode("A"),
    ),
    expected.1,
  )
}

///|
test "PdfDocument addtext_line_widths measures selected font paragraphs" {
  let document = @pdflite.pdf_document_empty()
  let page = @pdflite.pdf_page_blank(@pdflite.paper_a4)
  let widths = try! document.addtext_line_widths(
    page,
    Some(addtext_layout_standard_font_for_test()),
    None,
    addtext_layout_name_for_test("/F0"),
    10.0,
    @ascii.encode("A"),
    [@ascii.encode("A"), @ascii.encode("AV")],
  )
  addtext_layout_assert_close_for_test(widths.text_width, 6.67)
  @test.assert_eq(widths.widths.length(), 2)
  addtext_layout_assert_close_for_test(widths.widths[0], 6.67)
  addtext_layout_assert_close_for_test(widths.widths[1], 13.34)
  addtext_layout_assert_close_for_test(widths.longest_width, 13.34)
}

///|
test "pdf_addtext_line_widths wrapper handles fontpacks" {
  let document = @pdflite.pdf_document_empty()
  let page = @pdflite.pdf_page_blank(@pdflite.paper_a4)
  let metrics : Array[Double] = [ for _ in 0..<256 => 0.0 ]
  metrics[66] = 610.0
  let pack : @pdflite.PdfFontPack = {
    fonts: [
      addtext_layout_standard_font_for_test(),
      addtext_layout_simple_font_with_metrics_for_test(Some(metrics)),
    ],
    entries: [
      { codepoint: 65, font_index: 0, charcode: 65 },
      { codepoint: 66, font_index: 1, charcode: 66 },
    ],
  }
  let widths = try! @pdflite.pdf_addtext_line_widths(
    document,
    page,
    None,
    Some(pack),
    addtext_layout_name_for_test("/F0"),
    10.0,
    @utf8.encode("AB"),
    [@utf8.encode("A"), @utf8.encode("AB")],
  )
  addtext_layout_assert_close_for_test(widths.text_width, 12.77)
  addtext_layout_assert_close_for_test(widths.widths[0], 6.67)
  addtext_layout_assert_close_for_test(widths.widths[1], 12.77)
  addtext_layout_assert_close_for_test(widths.longest_width, 12.77)
}

///|
test "PdfDocument addtext_line_widths reports empty expanded lines" {
  let document = @pdflite.pdf_document_empty()
  let page = @pdflite.pdf_page_blank(@pdflite.paper_a4)
  let result : Result[@addtext.PdfAddTextLineWidths, Error] = try? document.addtext_line_widths(
    page,
    Some(addtext_layout_standard_font_for_test()),
    None,
    addtext_layout_name_for_test("/F0"),
    10.0,
    @ascii.encode("A"),
    [],
  )
  guard result is Err(@pdflite.PdfError::SoftError("empty add-text width list")) else {
    fail("expected empty add-text width list error")
  }
}

///|
test "pdf_addtext_measurement_bytes follows cpdf selected-font modes" {
  let font = addtext_layout_standard_font_for_test()
  @test.assert_eq(
    @pdflite.pdf_int_array_of_bytes(
      try! @pdflite.pdf_addtext_measurement_bytes(
        Some(font),
        None,
        false,
        "A☃B",
      ),
    ),
    [65, 66],
  )
  @test.assert_eq(
    @pdflite.pdf_int_array_of_bytes(
      try! @pdflite.pdf_addtext_measurement_bytes(
        Some(font),
        None,
        true,
        "A☃B",
      ),
    ),
    [65, 226, 152, 131, 66],
  )
  @test.assert_eq(
    @pdflite.pdf_int_array_of_bytes(
      try! @pdflite.pdf_addtext_measurement_bytes(None, None, false, "A☃B"),
    ),
    [65, 226, 152, 131, 66],
  )
  let pack : @pdflite.PdfFontPack = { fonts: [font], entries: [] }
  @test.assert_eq(
    try! @pdflite.pdf_addtext_measurement_bytes(
      Some(font),
      Some(pack),
      false,
      "A☃B",
    ),
    @utf8.encode("A☃B"),
  )
}

///|
test "PdfDocument addtext_prepare_line expands URLs widths and placement" {
  let document = try! @pdflite.pdf_blank_document(100.0, 50.0, 1)
  let page = (try! document.pages_of_pagetree())[0]
  let font = addtext_layout_standard_font_for_test()
  let replacements : Array[(String, () -> String)] = [("%Page", fn() { "3" })]
  let prepared = try! document.addtext_prepare_line(
    page,
    addtext_layout_process_time_for_test(),
    ["%Page %URL[A|u]", "Wide"],
    replacements,
    Some(font),
    None,
    addtext_layout_name_for_test("/F0"),
    10.0,
    "%Page %URL[A|u]",
    PdfPositionTopRight(5.0, 6.0),
    horizontal_offset=2.0,
    vertical_offset=3.0,
    justification=PdfAddTextLeftJustify,
  )
  @test.assert_eq(prepared.text, "3 A")
  @test.assert_eq(prepared.urls, [{ url: "u", start: 2, end: 3 }])
  @test.assert_eq(prepared.expanded_lines, ["3 A", "Wide"])
  @test.assert_eq(@pdflite.pdf_int_array_of_bytes(prepared.text_bytes), [
    51, 32, 65,
  ])
  let text_width = @pdflite.pdf_addtext_width_of_selected_font(
    font,
    10.0,
    prepared.text_bytes,
  )
  let wide_width = @pdflite.pdf_addtext_width_of_selected_font(
    font,
    10.0,
    prepared.expanded_line_bytes[1],
  )
  addtext_layout_assert_close_for_test(prepared.widths.text_width, text_width)
  addtext_layout_assert_close_for_test(
    prepared.widths.longest_width,
    wide_width,
  )
  addtext_layout_assert_close_for_test(
    prepared.placement.origin.x,
    95.0 - text_width,
  )
  addtext_layout_assert_close_for_test(prepared.placement.origin.y, 44.0)
  addtext_layout_assert_close_for_test(
    prepared.placement.justification_offset,
    wide_width - text_width,
  )
  addtext_layout_assert_close_for_test(
    prepared.placement.horizontal_offset,
    2.0 + wide_width - text_width,
  )
  addtext_layout_assert_close_for_test(prepared.placement.vertical_offset, 3.0)
}

///|
test "pdf_addtext_prepare_line wrapper honors relative boxes" {
  let document = try! @pdflite.pdf_blank_document(100.0, 50.0, 1)
  let cropbox = addtext_layout_name_for_test("/CropBox")
  let page = {
    ..(try! document.pages_of_pagetree())[0],
    rest: @pdflite.pdf_dictionary([
      (
        cropbox,
        PdfArray([PdfReal(10.0), PdfReal(20.0), PdfReal(70.0), PdfReal(40.0)]),
      ),
    ]),
  }
  let prepared = try! @pdflite.pdf_addtext_prepare_line(
    document,
    page,
    addtext_layout_process_time_for_test(),
    ["A"],
    [],
    Some(addtext_layout_standard_font_for_test()),
    None,
    addtext_layout_name_for_test("/F0"),
    10.0,
    "A",
    PdfPositionCentre,
    relative_to_box=cropbox,
    raw=true,
  )
  @test.assert_eq(prepared.expanded_line_bytes, [@utf8.encode("A")])
  addtext_layout_assert_close_for_test(prepared.placement.origin.y, 30.0)
}

///|
test "pdf_addtext_longest_width selects widest expanded line" {
  @test.assert_eq(@pdflite.pdf_addtext_longest_width([12.0, 7.0, 19.0]), 19.0)
  @test.assert_eq(@pdflite.pdf_addtext_longest_width([-3.0, -1.0]), -1.0)
  let result : Result[Double, Error] = try? @pdflite.pdf_addtext_longest_width([])
  guard result is Err(@pdflite.PdfError::SoftError("empty add-text width list")) else {
    fail("expected SoftError for empty add-text width list")
  }
}

///|
test "pdf_addtext_justification_offset handles horizontal rotations" {
  @test.assert_eq(
    addtext_layout_offset_for_test(
      PdfAddTextRot0,
      PdfPositionTopLeft(0.0, 0.0),
      PdfAddTextLeftJustify,
    ),
    0.0,
  )
  @test.assert_eq(
    addtext_layout_offset_for_test(
      PdfAddTextRot0,
      PdfPositionTop(0.0),
      PdfAddTextLeftJustify,
    ),
    20.0,
  )
  @test.assert_eq(
    addtext_layout_offset_for_test(
      PdfAddTextRot0,
      PdfPositionTopRight(0.0, 0.0),
      PdfAddTextLeftJustify,
    ),
    40.0,
  )
  @test.assert_eq(
    addtext_layout_offset_for_test(
      PdfAddTextRot0,
      PdfPositionTopLeft(0.0, 0.0),
      PdfAddTextRightJustify,
    ),
    -40.0,
  )
  @test.assert_eq(
    addtext_layout_offset_for_test(
      PdfAddTextRot0,
      PdfPositionCentre,
      PdfAddTextRightJustify,
    ),
    -20.0,
  )
  @test.assert_eq(
    addtext_layout_offset_for_test(
      PdfAddTextRot0,
      PdfPositionBottomRight(0.0, 0.0),
      PdfAddTextCentreJustify,
    ),
    20.0,
  )
}

///|
test "pdf_addtext_apply_justification_offset follows cpdf rotation branch" {
  @test.assert_eq(
    @addtext.pdf_addtext_apply_justification_offset(
      PdfAddTextRot0,
      5.0,
      10.0,
      2.0,
    ),
    (7.0, 10.0),
  )
  @test.assert_eq(
    @addtext.pdf_addtext_apply_justification_offset(
      PdfAddTextRot180,
      5.0,
      10.0,
      2.0,
    ),
    (7.0, 10.0),
  )
  @test.assert_eq(
    @addtext.pdf_addtext_apply_justification_offset(
      PdfAddTextRot90,
      5.0,
      10.0,
      2.0,
    ),
    (5.0, 8.0),
  )
  @test.assert_eq(
    @addtext.pdf_addtext_apply_justification_offset(
      PdfAddTextRot270,
      5.0,
      10.0,
      2.0,
    ),
    (5.0, 8.0),
  )
}

///|
test "pdf_addtext_line_placement combines horizontal placement values" {
  let placement = @addtext.pdf_addtext_line_placement(
    addtext_layout_bounds_for_test(),
    PdfPositionTopRight(5.0, 6.0),
    PdfAddTextRot0,
    20.0,
    50.0,
    2.0,
    3.0,
    PdfAddTextLeftJustify,
  )
  @test.assert_eq(placement.origin, @pdflite.point2(75.0, 44.0))
  @test.assert_eq(placement.base_rotation, 0.0)
  @test.assert_eq(placement.text_rotation, 0.0)
  @test.assert_eq(placement.rotation_offset, @pdflite.point2(0.0, 0.0))
  @test.assert_eq(placement.horizontal_offset, 32.0)
  @test.assert_eq(placement.vertical_offset, 3.0)
  @test.assert_eq(placement.justification_offset, 30.0)
}

///|
test "pdf_addtext_line_placement combines vertical rotation values" {
  let placement = @addtext.pdf_addtext_line_placement(
    addtext_layout_bounds_for_test(),
    PdfPositionTop(4.0),
    PdfAddTextRot90,
    20.0,
    50.0,
    2.0,
    3.0,
    PdfAddTextCentreJustify,
  )
  @test.assert_eq(placement.origin, @pdflite.point2(40.0, 46.0))
  @test.assert_eq(placement.base_rotation, 0.0)
  addtext_layout_assert_close_for_test(
    placement.text_rotation,
    @math.PI * 3.0 / 2.0,
  )
  @test.assert_eq(placement.rotation_offset, @pdflite.point2(10.0, 0.0))
  @test.assert_eq(placement.horizontal_offset, 2.0)
  @test.assert_eq(placement.vertical_offset, 18.0)
  @test.assert_eq(placement.justification_offset, -15.0)
}

///|
test "pdf_addtext_justification_offset swaps horizontal justification at 180 degrees" {
  @test.assert_eq(
    addtext_layout_offset_for_test(
      PdfAddTextRot180,
      PdfPositionTopLeft(0.0, 0.0),
      PdfAddTextLeftJustify,
    ),
    -40.0,
  )
  @test.assert_eq(
    addtext_layout_offset_for_test(
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
    addtext_layout_offset_for_test(
      PdfAddTextRot90,
      PdfPositionTop(0.0),
      PdfAddTextLeftJustify,
    ),
    0.0,
  )
  @test.assert_eq(
    addtext_layout_offset_for_test(
      PdfAddTextRot90,
      PdfPositionLeft(0.0),
      PdfAddTextLeftJustify,
    ),
    20.0,
  )
  @test.assert_eq(
    addtext_layout_offset_for_test(
      PdfAddTextRot90,
      PdfPositionBottom(0.0),
      PdfAddTextLeftJustify,
    ),
    40.0,
  )
  @test.assert_eq(
    addtext_layout_offset_for_test(
      PdfAddTextRot90,
      PdfPositionTop(0.0),
      PdfAddTextRightJustify,
    ),
    -40.0,
  )
  @test.assert_eq(
    addtext_layout_offset_for_test(
      PdfAddTextRot90,
      PdfPositionLeft(0.0),
      PdfAddTextRightJustify,
    ),
    -20.0,
  )
  @test.assert_eq(
    addtext_layout_offset_for_test(
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
    addtext_layout_offset_for_test(
      PdfAddTextRot270,
      PdfPositionTop(0.0),
      PdfAddTextLeftJustify,
    ),
    -40.0,
  )
  @test.assert_eq(
    addtext_layout_offset_for_test(
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
    addtext_layout_offset_for_test(
      PdfAddTextRot0,
      PdfPositionDiagonal,
      PdfAddTextRightJustify,
    ),
    0.0,
  )
  @test.assert_eq(
    addtext_layout_offset_for_test(
      PdfAddTextRot90,
      PdfPositionReverseDiagonal,
      PdfAddTextCentreJustify,
    ),
    0.0,
  )
}

///|
test "pdf_addtext_get_urls_line strips one URL marker" {
  let parsed = try! @addtext.pdf_addtext_get_urls_line(
    "pre %URL[label|https://example.test] post",
  )
  @test.assert_eq(parsed.text, "pre label post")
  @test.assert_eq(parsed.urls, [
    { url: "https://example.test", start: 4, end: 9 },
  ])
}

///|
test "pdf_addtext_get_urls_line preserves URL order and visible offsets" {
  let parsed = try! @addtext.pdf_addtext_get_urls_line(
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
  let parsed = try! @addtext.pdf_addtext_get_urls_line("é%URL[ß|u]")
  @test.assert_eq(parsed.text, "éß")
  @test.assert_eq(parsed.urls, [{ url: "u", start: 2, end: 4 }])
}

///|
test "pdf_addtext_get_urls_line reports malformed URL markers" {
  let missing_pipe : Result[@addtext.PdfAddTextUrlLine, Error] = try? @addtext.pdf_addtext_get_urls_line(
    "%URL[text]",
  )
  guard missing_pipe
    is Err(@pdflite.PdfError::SoftError("bad URL syntax in text")) else {
    fail("expected SoftError for URL marker without pipe")
  }
  let missing_close : Result[@addtext.PdfAddTextUrlLine, Error] = try? @addtext.pdf_addtext_get_urls_line(
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
      addtext_layout_process_time_for_test(),
      "page %Page on %Date",
      replacements,
    ),
    "page 7 on 2023-09-03",
  )
  @test.assert_eq(page_calls.val, 1)
  @test.assert_eq(
    @pdflite.pdf_process_text(
      addtext_layout_process_time_for_test(),
      "page %Page on %Date",
      replacements,
    ),
    "page 7 on 2023-09-03",
  )
  @test.assert_eq(page_calls.val, 2)
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
      addtext_layout_process_time_for_test(),
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
      addtext_layout_process_time_for_test(),
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
      addtext_layout_process_time_for_test(),
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
    addtext_layout_process_time_for_test(),
    ["ok", "%URL[broken"],
    [],
  )
  guard result is Err(@pdflite.PdfError::SoftError("bad URL syntax in text")) else {
    fail("expected SoftError for malformed URL marker during line expansion")
  }
}

///|
test "pdf_addtext_used_codepoints collects visible expanded-line codepoints" {
  let expanded = try! @pdflite.pdf_addtext_expand_lines_with_time(
    addtext_layout_process_time_for_test(),
    ["A%URL[é|https://example.test]", "BA"],
    [],
  )
  @test.assert_eq(try! @pdflite.pdf_addtext_used_codepoints(expanded), [
    65, 0xE9, 66,
  ])
}

///|
test "pdf_addtext_used_codepoints handles empty lines" {
  @test.assert_eq(try! @pdflite.pdf_addtext_used_codepoints(["", ""]), [])
}

///|
test "pdf_addtext_bates_number formats optional zero padding" {
  @test.assert_eq(@pdflite.pdf_addtext_bates_number(98, 5, None), "102")
  @test.assert_eq(@pdflite.pdf_addtext_bates_number(98, 5, Some(4)), "0102")
  @test.assert_eq(@pdflite.pdf_addtext_bates_number(12345, 1, Some(3)), "12345")
}

///|
test "pdf_addtext_replacement_pairs builds cpdf addtext fields" {
  let values : @addtext.PdfAddTextReplacementValues = {
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
    addtext_layout_process_time_for_test(),
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
  let bookmarks : Array[@bookmark.PdfBookmark] = [
    addtext_layout_bookmark_for_test(0, "Chapter 1", page_refs[0]),
    addtext_layout_bookmark_for_test(1, "Section 1.1", page_refs[1]),
    addtext_layout_bookmark_for_test(1, "Section 1.2", page_refs[2]),
    addtext_layout_bookmark_for_test(0, "Chapter 2", page_refs[3]),
    addtext_layout_bookmark_for_test(1, "Section 2.1", page_refs[4]),
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
  let bookmarks : Array[@bookmark.PdfBookmark] = [
    addtext_layout_bookmark_for_test(0, "Intro ☃", page_refs[0]),
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
  let bookmarks : Array[@bookmark.PdfBookmark] = [
    addtext_layout_bookmark_for_test(0, "Chapter 1", page_refs[0]),
    addtext_layout_bookmark_for_test(1, "Section 1.1", page_refs[1]),
    addtext_layout_bookmark_for_test(1, "Section 1.2", page_refs[2]),
    addtext_layout_bookmark_for_test(0, "Chapter 2", page_refs[3]),
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
      addtext_layout_process_time_for_test(),
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
test "pdf_replace_pairs wrapper matches derived replacement pairs" {
  let document = try! @pdflite.pdf_blank_document(10.0, 10.0, 2)
  let values = try! document.addtext_replacement_values(
    [],
    2,
    2,
    "input.pdf",
    10,
    Some(3),
  )
  let expected = @pdflite.pdf_addtext_process_text_with_time(
    addtext_layout_process_time_for_test(),
    "%Page|%EndPage|%Label|%Bates",
    @pdflite.pdf_addtext_replacement_pairs(values),
  )
  let actual = @pdflite.pdf_addtext_process_text_with_time(
    addtext_layout_process_time_for_test(),
    "%Page|%EndPage|%Label|%Bates",
    try! @pdflite.pdf_replace_pairs(
      [],
      document,
      2,
      "input.pdf",
      10,
      Some(3),
      2,
    ),
  )
  @test.assert_eq(actual, expected)
  @test.assert_eq(actual, "2|2|2|011")
}

///|
test "pdf_addtext_cap_height prefers simple font descriptors" {
  @test.assert_eq(
    @pdflite.pdf_addtext_cap_height(
      Some(addtext_layout_simple_font_for_test(681.0)),
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
