///|
fn type_bytes_for_test(values : ArrayView[Int]) -> @pdflite.PdfBytes {
  try! @pdflite.pdf_bytes_of_int_array(values)
}

///|
fn type_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn type_lookup_for_test(
  object : @pdflite.PdfObject,
  key : String,
) -> @pdflite.PdfObject raise {
  match object.lookup_immediate(type_name_for_test(key)) {
    Some(value) => value
    None => {
      fail("missing dictionary key " + key)
      PdfNull
    }
  }
}

///|
fn type_page_ops_for_test(
  page : @page.PdfPage,
) -> Array[@content.PdfContentOp] raise {
  guard page.content.length() == 1 else {
    fail("expected exactly one content stream")
  }
  match page.content[0] {
    PdfStreamObject(stream) =>
      match stream.data {
        StreamGot(bytes) =>
          try! @pdflite.pdf_parse_content_ops_from_bytes(bytes)
        _ => {
          fail("expected materialized content stream")
          []
        }
      }
    _ => {
      fail("expected content stream object")
      []
    }
  }
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
  let elements : Array[@pdflite.PdfTypeElement] = [
    PdfTypeText(@ascii.encode("A")),
    PdfTypeNewLine,
    PdfTypeNewPage,
    PdfTypeBeginDocument,
    PdfTypeEndDest,
    PdfTypeEndTag,
  ]
  @test.assert_eq(
    @pdflite.pdf_string_of_type(elements),
    @ascii.encode("\nA\nNewLine\nNewPage\nBeginDocument\nEndDest\nEndTag"),
  )
  @test.assert_eq(
    @pdflite.pdf_type_to_string(elements),
    @pdflite.pdf_string_of_type(elements),
  )
  @test.assert_eq(@pdflite.pdf_string_of_type([]), @ascii.encode(""))
  @test.assert_eq(
    @pdflite.pdf_type_add_artifacts([Op_Tj(@ascii.encode("artifact"))]),
    @content.pdf_content_add_artifacts([Op_Tj(@ascii.encode("artifact"))]),
  )
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
  @test.assert_eq(
    try! @pdflite.pdf_type_width_of_string(
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

///|
test "pdf_type_typeset writes page content and font resources" {
  let document = @pdflite.pdf_document_empty()
  let font = type_standard_font_for_test()
  let paper = @pdflite.paper_size_make(PdfPoint, 100.0, 100.0)
  let result = try! document.pdf_type_typeset(
    false,
    10.0,
    0.0,
    20.0,
    10.0,
    paper,
    [
      PdfTypeFont("body", font, 10.0),
      PdfTypeBeginDocument,
      PdfTypeText(@ascii.encode("Hi")),
    ],
  )
  @test.assert_eq(result.pages.length(), 1)
  @test.assert_eq(result.tags, [[]])
  let page = result.pages[0]
  @test.assert_eq(
    page.resources,
    PdfDictionary([
      (
        type_name_for_test("/Font"),
        PdfDictionary([(type_name_for_test("/F1"), PdfIndirect(1))]),
      ),
    ]),
  )
  @test.assert_eq(page.rest, PdfDictionary([]))
  @test.assert_eq(try! type_page_ops_for_test(page), [
    Op_Tf(type_name_for_test("/F1"), 10.0),
    Op_q,
    Op_cm(@pdflite.transform_translate(10.0, 70.0)),
    Op_BT,
    Op_Tj(@ascii.encode("Hi")),
    Op_ET,
    Op_Q,
  ])
}

///|
test "pdf_type_typeset reuses fonts across explicit page breaks" {
  let document = @pdflite.pdf_document_empty()
  let font = type_standard_font_for_test()
  let paper = @pdflite.paper_size_make(PdfPoint, 100.0, 100.0)
  let elements : Array[@pdflite.PdfTypeElement] = [
    PdfTypeFont("body", font, 10.0),
    PdfTypeBeginDocument,
    PdfTypeText(@ascii.encode("A")),
    PdfTypeNewPage,
    PdfTypeText(@ascii.encode("B")),
  ]
  let result = try! @pdflite.pdf_type_typeset(
    document, false, 10.0, 0.0, 20.0, 10.0, paper, elements,
  )
  let source_order = try! @pdflite.pdf_type_typeset_cpdf_order(
    false,
    10.0,
    0.0,
    20.0,
    10.0,
    paper,
    @pdflite.pdf_document_empty(),
    elements,
  )
  @test.assert_eq(result.pages.length(), 2)
  @test.assert_eq(source_order.pages.length(), result.pages.length())
  @test.assert_eq(result.pages[0].resources, result.pages[1].resources)
  @test.assert_eq(source_order.pages[0].resources, result.pages[0].resources)
  @test.assert_eq(try! type_page_ops_for_test(result.pages[1]), [
    Op_Tf(type_name_for_test("/F1"), 10.0),
    Op_q,
    Op_cm(@pdflite.transform_translate(10.0, 70.0)),
    Op_BT,
    Op_Tj(@ascii.encode("B")),
    Op_ET,
    Op_Q,
  ])
  @test.assert_eq(
    try! type_page_ops_for_test(source_order.pages[1]),
    try! type_page_ops_for_test(result.pages[1]),
  )
}

///|
test "pdf_type_typeset creates link annotations and numbered marked content" {
  let document = @pdflite.pdf_document_empty()
  let font = type_standard_font_for_test()
  let paper = @pdflite.paper_size_make(PdfPoint, 100.0, 100.0)
  let link_text = @ascii.encode("Go")
  let widths = try! @pdflite.pdf_type_font_widths(font, 10.0)
  let link_width = try! @pdflite.pdf_type_width_of_bytes(widths, link_text)
  let result = try! document.pdf_type_typeset(
    false,
    10.0,
    0.0,
    20.0,
    10.0,
    paper,
    [
      PdfTypeFont("body", font, 10.0),
      PdfTypeBeginDocument,
      PdfTypeBeginDest(DestFit(TargetPageObject(99)), Some("go")),
      PdfTypeText(link_text),
      PdfTypeEndDest,
      PdfTypeTag("Span", 123),
      PdfTypeText(@ascii.encode("T")),
      PdfTypeEndTag,
    ],
  )
  @test.assert_eq(result.tags, [[("Span", 0)]])
  let page = result.pages[0]
  @test.assert_eq(
    page.rest,
    PdfDictionary([
      (type_name_for_test("/Annots"), PdfArray([PdfIndirect(2)])),
      (type_name_for_test("/Tabs"), PdfNameObject(type_name_for_test("/S"))),
    ]),
  )
  let annotation = document.lookup_object_or_null(2)
  @test.assert_eq(
    try! type_lookup_for_test(annotation, "/Contents"),
    PdfString(@ascii.encode("go")),
  )
  @test.assert_eq(
    try! type_lookup_for_test(annotation, "/Subtype"),
    PdfNameObject(type_name_for_test("/Link")),
  )
  @test.assert_eq(
    try! type_lookup_for_test(annotation, "/Rect"),
    PdfArray([
      PdfReal(10.0),
      PdfReal(70.0),
      PdfReal(10.0 + link_width),
      PdfReal(80.0),
    ]),
  )
  @test.assert_eq(
    try! type_lookup_for_test(annotation, "/Dest"),
    @pdflite.pdf_object_of_destination(DestFit(TargetPageObject(99))),
  )
  @test.assert_eq(try! type_page_ops_for_test(page), [
    Op_Tf(type_name_for_test("/F1"), 10.0),
    Op_q,
    Op_cm(@pdflite.transform_translate(10.0, 70.0)),
    Op_BT,
    Op_Tj(link_text),
    Op_ET,
    Op_Q,
    Op_BDC(
      type_name_for_test("/Span"),
      PdfDictionary([(type_name_for_test("/MCID"), PdfInteger(0))]),
    ),
    Op_q,
    Op_cm(@pdflite.transform_translate(10.0 + link_width, 70.0)),
    Op_BT,
    Op_Tj(@ascii.encode("T")),
    Op_ET,
    Op_Q,
    Op_EMC,
  ])
}
