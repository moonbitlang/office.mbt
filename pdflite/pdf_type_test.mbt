///|
fn type_bytes_for_test(values : ArrayView[Int]) -> @pdflite.PdfBytes {
  try! @pdflite.pdf_bytes_of_int_array(values)
}

///|
fn type_simple_font_with_metrics_for_test() -> @pdflite.PdfFont {
  PdfFontSimple({
    fonttype: PdfType1,
    basefont: None,
    firstchar: 0,
    lastchar: 255,
    widths: [],
    fontdescriptor: None,
    fontmetrics: Some([ for code in 0..<256 => code.to_double() ]),
    encoding: PdfWinAnsiEncoding,
  })
}

///|
fn type_simple_font_without_metrics_for_test() -> @pdflite.PdfFont {
  PdfFontSimple({
    fonttype: PdfType1,
    basefont: None,
    firstchar: 0,
    lastchar: 255,
    widths: [],
    fontdescriptor: None,
    fontmetrics: None,
    encoding: PdfWinAnsiEncoding,
  })
}

///|
fn type_standard_font_for_test() -> @pdflite.PdfFont {
  PdfFontStandard({ font: PdfHelvetica, encoding: PdfWinAnsiEncoding })
}

///|
test "pdf_string_of_type_element preserves cpdftype debug spellings" {
  @test.assert_eq(
    @pdflite.pdf_string_of_type_element(
      PdfTypeText(type_bytes_for_test([65, 0, 255])),
    ),
    type_bytes_for_test([65, 0, 255]),
  )
  @test.assert_eq(
    @pdflite.pdf_string_of_type_element(PdfTypeHGlue(1.0)),
    @ascii.encode("HGLUE1."),
  )
  @test.assert_eq(
    @pdflite.pdf_string_of_type_element(PdfTypeVGlue(12.5)),
    @ascii.encode("VGLUE"),
  )
  @test.assert_eq(
    @pdflite.pdf_string_of_type_element(
      PdfTypeFont("body", type_standard_font_for_test(), 12.0),
    ),
    @ascii.encode("Font"),
  )
  @test.assert_eq(
    @pdflite.pdf_string_of_type_element(
      PdfTypeBeginDest(DestFit(TargetPageObject(1)), Some("chapter")),
    ),
    @ascii.encode("BeginDest"),
  )
  @test.assert_eq(
    @pdflite.pdf_string_of_type_element(PdfTypeTag("P", 7)),
    @ascii.encode("Tag P 7"),
  )
}

///|
test "pdf_string_of_type keeps CamlPDF leading newline format" {
  @test.assert_eq(
    @pdflite.pdf_string_of_type([
      PdfTypeText(@ascii.encode("A")),
      PdfTypeNewLine,
      PdfTypeNewPage,
      PdfTypeBeginDocument,
      PdfTypeEndDest,
      PdfTypeEndTag,
    ]),
    @ascii.encode("\nA\nNewLine\nNewPage\nBeginDocument\nEndDest\nEndTag"),
  )
  @test.assert_eq(@pdflite.pdf_string_of_type([]), @ascii.encode(""))
}

///|
test "pdf_type_font_widths scales standard font charcode widths" {
  let widths = try! @pdflite.pdf_type_font_widths(
    type_standard_font_for_test(),
    12.0,
  )
  @test.assert_eq(widths.length(), 256)
  @test.assert_eq(widths[32], 3.336)
  @test.assert_eq(widths[65], 8.004)
  @test.assert_eq(
    try! @pdflite.pdf_type_width_of_bytes(
      widths,
      type_bytes_for_test([65, 32, 65]),
    ),
    19.344,
  )
}

///|
test "pdf_type_font_widths scales simple font metrics" {
  let widths = try! @pdflite.pdf_type_font_widths(
    type_simple_font_with_metrics_for_test(),
    10.0,
  )
  @test.assert_eq(widths.length(), 256)
  @test.assert_eq(widths[65], 0.65)
  @test.assert_eq(
    try! @pdflite.pdf_type_width_of_bytes(
      widths,
      type_bytes_for_test([1, 2, 65]),
    ),
    0.68,
  )
}

///|
test "pdf_type helpers reject unsupported fonts and short width tables" {
  let missing_metrics : Result[Array[Double], Error] = try? @pdflite.pdf_type_font_widths(
    type_simple_font_without_metrics_for_test(),
    12.0,
  )
  guard missing_metrics is Err(@pdflite.PdfError::FontWidthExpected) else {
    fail("expected missing simple font metrics to fail")
  }
  let short_widths : Result[Double, Error] = try? @pdflite.pdf_type_width_of_bytes(
    [1.0, 2.0],
    type_bytes_for_test([0, 2]),
  )
  guard short_widths is Err(@pdflite.PdfError::FontWidthExpected) else {
    fail("expected short width table to fail")
  }
}
