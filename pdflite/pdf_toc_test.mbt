///|
fn toc_bytes_for_test(text : String) -> @pdflite.PdfBytes {
  @ascii.encode(text)
}

///|
fn toc_raw_bytes_for_test(values : ArrayView[Int]) -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  for value in values {
    output.push(value.to_byte())
  }
  Bytes::from_array(output)
}

///|
fn toc_standard_font_for_test() -> @pdflite.PdfFont {
  PdfFontStandard({ font: PdfHelvetica, encoding: PdfWinAnsiEncoding })
}

///|
fn toc_bold_font_for_test() -> @pdflite.PdfFont {
  PdfFontStandard({ font: PdfHelveticaBold, encoding: PdfWinAnsiEncoding })
}

///|
fn toc_standard_pack_for_test() -> @pdflite.PdfFontPack {
  try! @pdflite.pdf_fontpack_of_standard_font(toc_standard_font_for_test())
}

///|
fn toc_pdfdoc_for_test(text : String) -> @pdflite.PdfBytes {
  try! @pdflite.pdf_pdfdocstring_of_utf8(@utf8.encode(text))
}

///|
test "pdf_toc_split_title and real_newlines mirror cpdf title escaping" {
  @test.assert_eq(
    @pdflite.pdf_toc_split_title(toc_bytes_for_test("A\\nB\\n")),
    [toc_bytes_for_test("A"), toc_bytes_for_test("B"), toc_bytes_for_test("")],
  )
  @test.assert_eq(@pdflite.pdf_toc_split_title(toc_bytes_for_test("\\nA")), [
    toc_bytes_for_test(""),
    toc_bytes_for_test("A"),
  ])
  @test.assert_eq(
    @pdflite.pdf_toc_title_real_newlines(toc_bytes_for_test("A\\nB\\\\nC")),
    toc_raw_bytes_for_test([65, 10, 66, 92, 10, 67]),
  )
}

///|
test "pdf_toc_of_utf8 builds cpdftoc font text runs" {
  let font = toc_standard_font_for_test()
  let pack = toc_standard_pack_for_test()
  @test.assert_eq(
    try! @pdflite.pdf_toc_of_utf8(pack, 10.0, toc_bytes_for_test("AB")),
    [PdfTypeFont("0", font, 10.0), PdfTypeText(toc_bytes_for_test("AB"))],
  )
  @test.assert_eq(
    try! @pdflite.pdf_toc_of_utf8(pack, 10.0, @utf8.encode("A☃B")),
    [PdfTypeFont("0", font, 10.0), PdfTypeText(toc_bytes_for_test("AB"))],
  )
}

///|
test "pdf_toc_of_utf8 collates consecutive fontpack runs" {
  let first = toc_standard_font_for_test()
  let second = toc_bold_font_for_test()
  let pack : @pdflite.PdfFontPack = {
    fonts: [first, second],
    entries: [
      { codepoint: 65, font_index: 0, charcode: 1 },
      { codepoint: 66, font_index: 0, charcode: 2 },
      { codepoint: 67, font_index: 1, charcode: 3 },
      { codepoint: 68, font_index: 1, charcode: 4 },
      { codepoint: 69, font_index: 0, charcode: 5 },
    ],
  }
  @test.assert_eq(
    try! @pdflite.pdf_toc_of_utf8(pack, 9.0, toc_bytes_for_test("ABCDE")),
    [
      PdfTypeFont("0", first, 9.0),
      PdfTypeText(toc_raw_bytes_for_test([1, 2])),
      PdfTypeFont("1", second, 9.0),
      PdfTypeText(toc_raw_bytes_for_test([3, 4])),
      PdfTypeFont("0", first, 9.0),
      PdfTypeText(toc_raw_bytes_for_test([5])),
    ],
  )
}

///|
test "pdf_toc_of_pdfdocencoding decodes PDFDocString text" {
  let font = toc_standard_font_for_test()
  let pack = toc_standard_pack_for_test()
  let pdfdoc = try! @pdflite.pdf_pdfdocstring_of_utf8(@utf8.encode("A"))
  @test.assert_eq(try! @pdflite.pdf_toc_of_pdfdocencoding(pack, 11.0, pdfdoc), [
    PdfTypeFont("0", font, 11.0),
    PdfTypeText(toc_bytes_for_test("A")),
  ])
}

///|
test "pdf_toc_width_of_runs sums alternating font text runs" {
  let font = toc_standard_font_for_test()
  let pack = toc_standard_pack_for_test()
  let runs = try! @pdflite.pdf_toc_of_utf8(pack, 12.0, toc_bytes_for_test("A."))
  let widths = try! @pdflite.pdf_type_font_widths(font, 12.0)
  @test.assert_eq(
    try! @pdflite.pdf_toc_width_of_runs(runs),
    try! @pdflite.pdf_type_width_of_bytes(widths, toc_bytes_for_test("A.")),
  )
  let malformed : Result[Double, Error] = try? @pdflite.pdf_toc_width_of_runs([
    PdfTypeText(toc_bytes_for_test("A")),
  ])
  guard malformed is Err(@pdflite.PdfError::SoftError("width_of_runs")) else {
    fail("expected width_of_runs SoftError")
  }
}

///|
test "pdf_toc_shorten_text trims final text run and appends ellipsis" {
  let font = toc_standard_font_for_test()
  let pack = toc_standard_pack_for_test()
  let runs = try! @pdflite.pdf_toc_of_utf8(
    pack,
    10.0,
    toc_bytes_for_test("ABCDE"),
  )
  let limit = try! @pdflite.pdf_toc_width_of_runs(
    try! @pdflite.pdf_toc_of_utf8(pack, 10.0, toc_bytes_for_test("ABC")),
  )
  @test.assert_eq(try! @pdflite.pdf_toc_shorten_text(pack, 10.0, limit, runs), [
    PdfTypeFont("0", font, 10.0),
    PdfTypeText(toc_bytes_for_test("ABC")),
    PdfTypeFont("0", font, 10.0),
    PdfTypeText(toc_bytes_for_test("...")),
  ])
  @test.assert_eq(
    try! @pdflite.pdf_toc_shorten_text(
      pack,
      10.0,
      try! @pdflite.pdf_toc_width_of_runs(runs),
      runs,
    ),
    runs,
  )
}

///|
test "pdf_toc_make_dots creates cpdf dot leader with remainder glue" {
  let font = toc_standard_font_for_test()
  let pack = toc_standard_pack_for_test()
  let dot_width = try! @pdflite.pdf_toc_width_of_runs(
    try! @pdflite.pdf_toc_of_utf8(pack, 8.0, toc_bytes_for_test(".")),
  )
  @test.assert_eq(
    try! @pdflite.pdf_toc_make_dots(dot_width * 3.0 + 1.0, pack, 8.0),
    [
      PdfTypeHGlue(1.0),
      PdfTypeFont("0", font, 8.0),
      PdfTypeText(toc_bytes_for_test(".")),
      PdfTypeFont("0", font, 8.0),
      PdfTypeText(toc_bytes_for_test(".")),
      PdfTypeFont("0", font, 8.0),
      PdfTypeText(toc_bytes_for_test(".")),
    ],
  )
  @test.assert_eq(try! @pdflite.pdf_toc_make_dots(-1.0, pack, 8.0), [
    PdfTypeHGlue(-1.0),
  ])
}

///|
test "PdfDocument toc_used_codepoints scans title bookmarks and labels" {
  let document = try! @pdflite.pdf_blank_document(100.0, 100.0, 2)
  let page_refs = try! document.page_reference_numbers()
  let labels : Array[@pdflite.PdfPageLabel] = [
    {
      label_style: PageLabelDecimalArabic,
      label_prefix: None,
      start_page: 1,
      start_value: 1,
    },
    {
      label_style: PageLabelDecimalArabic,
      label_prefix: Some(toc_pdfdoc_for_test("P-")),
      start_page: 2,
      start_value: 5,
    },
  ]
  let bookmarks : Array[@pdflite.PdfBookmark] = [
    {
      level: 0,
      text: toc_pdfdoc_for_test("Go"),
      target: DestFit(TargetPageObject(page_refs[1])),
      is_open: true,
      colour: @pdflite.pdf_bookmark_black,
      flags: 0,
    },
    {
      level: 0,
      text: toc_pdfdoc_for_test("Zero"),
      target: DestNull,
      is_open: false,
      colour: @pdflite.pdf_bookmark_black,
      flags: 0,
    },
  ]
  let expected = [46, 84, 79, 67, 71, 111, 80, 45, 53, 90, 101, 114, 48]
  @test.assert_eq(
    try! document.toc_used_codepoints(
      labels,
      toc_bytes_for_test("TOC"),
      bookmarks,
    ),
    expected,
  )
  @test.assert_eq(
    try! @pdflite.pdf_toc_used_codepoints(
      document,
      labels,
      toc_bytes_for_test("TOC"),
      bookmarks,
    ),
    expected,
  )
}
