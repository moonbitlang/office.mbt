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
fn type_simple_font_with_constant_width_for_test(
  width : Double,
) -> @pdflite.PdfFont {
  PdfFontSimple({
    fonttype: PdfType1,
    basefont: None,
    firstchar: 0,
    lastchar: 255,
    widths: [],
    fontdescriptor: None,
    fontmetrics: Some([ for _ in 0..<256 => width ]),
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

///|
test "pdf_type_split_text preserves CamlPDF word splitting edge cases" {
  let widths = Array::make(256, 1.0)
  let (line, needs_newline, rest) = try! @pdflite.pdf_type_split_text(
    8.0,
    widths,
    @ascii.encode("one two three"),
  )
  @test.assert_eq(line, @ascii.encode("one two "))
  @test.assert_eq(needs_newline, true)
  @test.assert_eq(rest, @ascii.encode("three"))
  let (wide_line, wide_needs_newline, wide_rest) = try! @pdflite.pdf_type_split_text(
    2.0,
    widths,
    @ascii.encode("abcdef rest"),
  )
  @test.assert_eq(wide_line, @ascii.encode("abcdef "))
  @test.assert_eq(wide_needs_newline, true)
  @test.assert_eq(wide_rest, @ascii.encode("rest"))
  let (full_line, full_needs_newline, full_rest) = try! @pdflite.pdf_type_split_text(
    20.0,
    widths,
    @ascii.encode("ok now"),
  )
  @test.assert_eq(full_line, @ascii.encode("ok now"))
  @test.assert_eq(full_needs_newline, false)
  @test.assert_eq(full_rest, @ascii.encode(""))
  let (narrow_line, narrow_needs_newline, narrow_rest) = try! @pdflite.pdf_type_split_text(
    2.0,
    [1.0],
    type_bytes_for_test([0]),
  )
  @test.assert_eq(narrow_line, type_bytes_for_test([0]))
  @test.assert_eq(narrow_needs_newline, false)
  @test.assert_eq(narrow_rest, @ascii.encode(""))
}

///|
test "pdf_type_layout wraps text and glue with CamlPDF margin behavior" {
  let font = type_simple_font_with_constant_width_for_test(100.0)
  let paper = @pdflite.paper_size_make(PdfPoint, 10.0, 100.0)
  let laid_out = try! @pdflite.pdf_type_layout(1.0, 1000.0, paper, [
    PdfTypeFont("body", font, 10.0),
    PdfTypeText(@ascii.encode("one two three")),
    PdfTypeHGlue(8.0),
    PdfTypeText(@ascii.encode("x")),
  ])
  @test.assert_eq(laid_out, [
    PdfTypeFont("body", font, 10.0),
    PdfTypeText(@ascii.encode("one two ")),
    PdfTypeNewLine,
    PdfTypeText(@ascii.encode("three")),
    PdfTypeHGlue(8.0),
    PdfTypeNewLine,
    PdfTypeText(@ascii.encode("x")),
  ])
}

///|
test "pdf_type_paginate closes and reopens active tags around breaks" {
  let font = type_standard_font_for_test()
  let paper = @pdflite.paper_size_make(PdfPoint, 100.0, 20.0)
  let paginated = @pdflite.pdf_type_paginate(2.0, 3.0, paper, [
    PdfTypeFont("body", font, 10.0),
    PdfTypeBeginDocument,
    PdfTypeTag("P", 7),
    PdfTypeNewLine,
    PdfTypeVGlue(20.0),
    PdfTypeEndTag,
  ])
  @test.assert_eq(paginated, [
    PdfTypeFont("body", font, 10.0),
    PdfTypeBeginDocument,
    PdfTypeTag("P", 7),
    PdfTypeNewLine,
    PdfTypeEndTag,
    PdfTypeNewPage,
    PdfTypeTag("P", 7),
    PdfTypeVGlue(20.0),
    PdfTypeEndTag,
    PdfTypeNewPage,
    PdfTypeTag("P", 7),
    PdfTypeEndTag,
  ])
}
