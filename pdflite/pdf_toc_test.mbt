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
fn toc_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn toc_rectangle_for_test(
  min_x : Double,
  min_y : Double,
  max_x : Double,
  max_y : Double,
) -> @pdflite.PdfObject {
  PdfArray([PdfReal(min_x), PdfReal(min_y), PdfReal(max_x), PdfReal(max_y)])
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
fn toc_append_elements_for_test(
  output : Array[@pdflite.PdfTypeElement],
  elements : ArrayView[@pdflite.PdfTypeElement],
) -> Unit {
  for element in elements {
    output.push(element)
  }
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
  let labels : Array[@label.PdfPageLabel] = [
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
  let bookmarks : Array[@bookmark.PdfBookmark] = [
    {
      level: 0,
      text: toc_pdfdoc_for_test("Go"),
      target: DestFit(TargetPageObject(page_refs[1])),
      is_open: true,
      colour: @bookmark.pdf_bookmark_black,
      flags: 0,
    },
    {
      level: 0,
      text: toc_pdfdoc_for_test("Zero"),
      target: DestNull,
      is_open: false,
      colour: @bookmark.pdf_bookmark_black,
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

///|
test "PdfDocument toc_type_elements builds untagged TOC runs" {
  let document = try! @pdflite.pdf_blank_document(100.0, 100.0, 1)
  let page_refs = try! document.page_reference_numbers()
  let font = toc_standard_font_for_test()
  let pack = toc_standard_pack_for_test()
  let target : @destination.PdfDestination = DestFit(
    TargetPageObject(page_refs[0]),
  )
  let bookmark : @bookmark.PdfBookmark = {
    level: 0,
    text: toc_pdfdoc_for_test("Chapter"),
    target,
    is_open: true,
    colour: @bookmark.pdf_bookmark_black,
    flags: 0,
  }
  let title_runs = try! @pdflite.pdf_toc_of_utf8(
    pack,
    20.0,
    toc_bytes_for_test("Contents"),
  )
  let text_runs = try! @pdflite.pdf_toc_of_pdfdocencoding(
    pack,
    10.0,
    toc_pdfdoc_for_test("Chapter"),
  )
  let label_runs = try! @pdflite.pdf_toc_of_pdfdocencoding(
    pack,
    10.0,
    toc_bytes_for_test("1"),
  )
  let label_width = try! @pdflite.pdf_toc_width_of_runs(label_runs)
  let text_width = try! @pdflite.pdf_toc_width_of_runs(text_runs)
  let textgap = 200.0 - 20.0 - label_width
  let space = textgap - text_width
  let expected : Array[@pdflite.PdfTypeElement] = [
    title_runs[0],
    PdfTypeBeginDocument,
  ]
  toc_append_elements_for_test(expected, title_runs)
  expected.push(PdfTypeNewLine)
  expected.push(PdfTypeVGlue(20.0))
  expected.push(PdfTypeBeginDest(target, Some("Chapter")))
  expected.push(PdfTypeHGlue(0.0))
  toc_append_elements_for_test(expected, text_runs)
  expected.push(PdfTypeHGlue(space))
  toc_append_elements_for_test(expected, label_runs)
  expected.push(PdfTypeEndDest)
  expected.push(PdfTypeNewLine)
  @test.assert_eq(
    try! document.toc_type_elements(
      pack,
      10.0,
      toc_bytes_for_test("Contents"),
      false,
      false,
      [],
      [bookmark],
      200.0,
      10.0,
    ),
    expected,
  )
  @test.assert_eq(
    try! @pdflite.pdf_toc_type_elements(
      document,
      pack,
      10.0,
      toc_bytes_for_test("Contents"),
      false,
      false,
      [],
      [bookmark],
      200.0,
      10.0,
    ),
    expected,
  )
  @test.assert_eq(expected[0], PdfTypeFont("0", font, 20.0))
}

///|
test "PdfDocument toc_type_elements adds structure tags and dot leaders" {
  let document = try! @pdflite.pdf_blank_document(100.0, 100.0, 1)
  let page_refs = try! document.page_reference_numbers()
  let font = toc_standard_font_for_test()
  let pack = toc_standard_pack_for_test()
  let target : @destination.PdfDestination = DestFit(
    TargetPageObject(page_refs[0]),
  )
  let bookmark : @bookmark.PdfBookmark = {
    level: 1,
    text: toc_pdfdoc_for_test("A"),
    target,
    is_open: true,
    colour: @bookmark.pdf_bookmark_black,
    flags: 0,
  }
  let title_runs = try! @pdflite.pdf_toc_of_utf8(
    pack,
    20.0,
    toc_bytes_for_test("T"),
  )
  let text_runs = try! @pdflite.pdf_toc_of_pdfdocencoding(
    pack,
    10.0,
    toc_pdfdoc_for_test("A"),
  )
  let label_runs = try! @pdflite.pdf_toc_of_pdfdocencoding(
    pack,
    10.0,
    toc_bytes_for_test("1"),
  )
  let label_width = try! @pdflite.pdf_toc_width_of_runs(label_runs)
  let text_width = try! @pdflite.pdf_toc_width_of_runs(text_runs)
  let textgap = 100.0 - 20.0 - 20.0 - label_width
  let space = textgap - text_width
  let leader = try! @pdflite.pdf_toc_make_dots(space, pack, 10.0)
  let expected : Array[@pdflite.PdfTypeElement] = [
    title_runs[0],
    PdfTypeBeginDocument,
    PdfTypeTag("P", 0),
  ]
  toc_append_elements_for_test(expected, title_runs)
  expected.push(PdfTypeNewLine)
  expected.push(PdfTypeEndTag)
  expected.push(PdfTypeVGlue(20.0))
  expected.push(PdfTypeBeginDest(target, Some("A")))
  expected.push(PdfTypeHGlue(20.0))
  expected.push(PdfTypeTag("Link", 0))
  toc_append_elements_for_test(expected, text_runs)
  expected.push(PdfTypeEndTag)
  toc_append_elements_for_test(expected, leader)
  expected.push(PdfTypeTag("Link", 0))
  toc_append_elements_for_test(expected, label_runs)
  expected.push(PdfTypeEndTag)
  expected.push(PdfTypeEndDest)
  expected.push(PdfTypeNewLine)
  @test.assert_eq(
    try! document.toc_type_elements(
      pack,
      10.0,
      toc_bytes_for_test("T"),
      true,
      true,
      [],
      [bookmark],
      100.0,
      10.0,
    ),
    expected,
  )
  @test.assert_eq(expected[0], PdfTypeFont("0", font, 20.0))
}

///|
test "PdfDocument toc_typeset_pages uses first-page cropbox geometry" {
  let cropbox_key = toc_name_for_test("/CropBox")
  let cropbox = toc_rectangle_for_test(10.0, 20.0, 160.0, 80.0)
  let base = try! @pdflite.pdf_blank_document(200.0, 100.0, 1)
  let source_pages = try! base.pages_of_pagetree()
  let source_page = {
    ..source_pages[0],
    rest: try! source_pages[0].rest.add_dict_entry(cropbox_key, cropbox),
  }
  let document = try! base.change_pages([source_page])
  let page_refs = try! document.page_reference_numbers()
  let pack = toc_standard_pack_for_test()
  let target : @destination.PdfDestination = DestFit(
    TargetPageObject(page_refs[0]),
  )
  let bookmark : @bookmark.PdfBookmark = {
    level: 0,
    text: toc_pdfdoc_for_test("Chapter"),
    target,
    is_open: true,
    colour: @bookmark.pdf_bookmark_black,
    flags: 0,
  }
  let expected_document = document.copy()
  let expected_elements = try! expected_document.toc_type_elements(
    pack,
    10.0,
    toc_bytes_for_test("Contents"),
    false,
    false,
    [],
    [bookmark],
    150.0,
    10.0,
  )
  let expected_raw = try! expected_document.pdf_type_typeset(
    false,
    20.0,
    50.0,
    30.0,
    30.0,
    @geometry.paper_size_make(PdfPoint, 200.0, 100.0),
    expected_elements,
  )
  let expected_pages = [
    for page in expected_raw.pages => {
      { ..page, rest: try! page.rest.add_dict_entry(cropbox_key, cropbox) }
    }
  ]
  let expected = { ..expected_raw, pages: expected_pages }
  let result = try! document
    .copy()
    .toc_typeset_pages(
      pack,
      10.0,
      toc_bytes_for_test("Contents"),
      false,
      false,
      [],
      [bookmark],
    )
  @test.assert_eq(result, expected)
  @test.assert_eq(
    try! @pdflite.pdf_toc_typeset_pages(
      document.copy(),
      pack,
      10.0,
      toc_bytes_for_test("Contents"),
      false,
      false,
      [],
      [bookmark],
    ),
    expected,
  )
  guard result.pages.length() > 0 else { fail("expected TOC page") }
  @test.assert_eq(
    document.lookup_direct(cropbox_key, result.pages[0].rest),
    Some(cropbox),
  )
}

///|
test "PdfDocument toc_insert_pages prepends pages and shifts labels" {
  let base = try! @pdflite.pdf_blank_document(100.0, 100.0, 2)
  let page_refs = try! base.page_reference_numbers()
  let bookmark : @bookmark.PdfBookmark = {
    level: 0,
    text: toc_pdfdoc_for_test("Second"),
    target: DestFit(TargetPageObject(page_refs[1])),
    is_open: true,
    colour: @bookmark.pdf_bookmark_black,
    flags: 0,
  }
  let document = try! base.add_bookmarks([bookmark])
  let labels : Array[@label.PdfPageLabel] = [
    {
      label_style: PageLabelDecimalArabic,
      label_prefix: Some(toc_pdfdoc_for_test("P-")),
      start_page: 2,
      start_value: 5,
    },
  ]
  let toc_page = @page.pdf_page_blank(
    @geometry.paper_size_make(PdfPoint, 50.0, 50.0),
  )
  let expected_labels : Array[@label.PdfPageLabel] = [
    {
      label_style: PageLabelNoLabelPrefixOnly,
      label_prefix: None,
      start_page: 1,
      start_value: 1,
    },
    { ..labels[0], start_page: 3 },
  ]
  @test.assert_eq(
    @pdflite.pdf_toc_shift_page_labels(1, labels),
    expected_labels,
  )
  let inserted = try! document.toc_insert_pages([toc_page], labels)
  let inserted_pages = try! inserted.pages_of_pagetree()
  @test.assert_eq(inserted_pages.length(), 3)
  @test.assert_eq(try! inserted.read_page_labels(), expected_labels)
  let inserted_bookmarks = try! inserted.read_bookmarks(preserve_actions=true)
  @test.assert_eq(
    try! inserted.page_number_of_target(inserted_bookmarks[0].target),
    3,
  )
  let wrapped = try! @pdflite.pdf_toc_insert_pages(document, [toc_page], labels)
  @test.assert_eq(try! wrapped.read_page_labels(), expected_labels)
  @test.assert_eq(
    try! wrapped.page_number_of_target(
      (try! wrapped.read_bookmarks(preserve_actions=true))[0].target,
    ),
    3,
  )
}

///|
test "PdfDocument toc_add_bookmark prepends generated bookmark" {
  let base = try! @pdflite.pdf_blank_document(100.0, 100.0, 2)
  let page_refs = try! base.page_reference_numbers()
  let existing : @bookmark.PdfBookmark = {
    level: 0,
    text: toc_pdfdoc_for_test("Existing"),
    target: DestFit(TargetPageObject(page_refs[1])),
    is_open: true,
    colour: @bookmark.pdf_bookmark_black,
    flags: 0,
  }
  let document = try! base.add_bookmarks([existing])
  let title = toc_bytes_for_test("Contents\\nLine")
  let expected_title = toc_pdfdoc_for_test("Contents\nLine")
  @test.assert_eq(try! @pdflite.pdf_toc_bookmark_text(title), expected_title)
  let updated = try! document.toc_add_bookmark(title)
  let bookmarks = try! updated.read_bookmarks(preserve_actions=true)
  @test.assert_eq(bookmarks.length(), 2)
  @test.assert_eq(bookmarks[0].text, expected_title)
  @test.assert_eq(bookmarks[0].level, 0)
  @test.assert_eq(bookmarks[0].is_open, false)
  @test.assert_eq(try! updated.page_number_of_target(bookmarks[0].target), 1)
  @test.assert_eq(bookmarks[1].level, 0)
  @test.assert_eq(bookmarks[1].text, existing.text)
  @test.assert_eq(try! updated.page_number_of_target(bookmarks[1].target), 2)
  let wrapped = try! @pdflite.pdf_toc_add_bookmark(document, title)
  @test.assert_eq(try! wrapped.read_bookmarks(preserve_actions=true), bookmarks)
}

///|
test "PdfDocument toc_with_fontpack composes non-structured TOC" {
  let base = try! @pdflite.pdf_blank_document(100.0, 100.0, 2)
  let page_refs = try! base.page_reference_numbers()
  let source_bookmark : @bookmark.PdfBookmark = {
    level: 0,
    text: toc_pdfdoc_for_test("Second"),
    target: DestFit(TargetPageObject(page_refs[1])),
    is_open: true,
    colour: @bookmark.pdf_bookmark_black,
    flags: 0,
  }
  let labels : Array[@label.PdfPageLabel] = [
    {
      label_style: PageLabelDecimalArabic,
      label_prefix: Some(toc_pdfdoc_for_test("P-")),
      start_page: 2,
      start_value: 5,
    },
  ]
  let source = try! (try! base.add_bookmarks([source_bookmark])).write_page_labels(
    labels,
  )
  let pack = toc_standard_pack_for_test()
  let title = toc_bytes_for_test("Contents\\nLine")
  let updated = try! source.toc_with_fontpack(pack, 10.0, title, bookmark=true)
  let updated_pages = try! updated.pages_of_pagetree()
  let toc_page_count = updated_pages.length() - 2
  guard toc_page_count > 0 else { fail("expected inserted TOC pages") }
  @test.assert_eq(try! updated.read_page_labels(), [
    {
      label_style: PageLabelNoLabelPrefixOnly,
      label_prefix: None,
      start_page: 1,
      start_value: 1,
    },
    { ..labels[0], start_page: labels[0].start_page + toc_page_count },
  ])
  let bookmarks = try! updated.read_bookmarks(preserve_actions=true)
  @test.assert_eq(bookmarks.length(), 2)
  @test.assert_eq(bookmarks[0].text, toc_pdfdoc_for_test("Contents\nLine"))
  @test.assert_eq(try! updated.page_number_of_target(bookmarks[0].target), 1)
  @test.assert_eq(bookmarks[1].text, source_bookmark.text)
  @test.assert_eq(
    try! updated.page_number_of_target(bookmarks[1].target),
    2 + toc_page_count,
  )

  let wrapped = try! @pdflite.pdf_toc_with_fontpack(
    source,
    pack,
    10.0,
    title,
    bookmark=true,
  )
  let wrapped_bookmarks = try! wrapped.read_bookmarks(preserve_actions=true)
  @test.assert_eq(wrapped_bookmarks.length(), 2)
  @test.assert_eq(wrapped_bookmarks[0].text, bookmarks[0].text)
  @test.assert_eq(
    try! wrapped.page_number_of_target(wrapped_bookmarks[0].target),
    1,
  )
  @test.assert_eq(wrapped_bookmarks[1].text, bookmarks[1].text)
  @test.assert_eq(
    try! wrapped.page_number_of_target(wrapped_bookmarks[1].target),
    2 + toc_page_count,
  )

  let no_bookmarks = try! @pdflite.pdf_blank_document(100.0, 100.0, 1)
  let unchanged = try! no_bookmarks.toc_with_fontpack(pack, 10.0, title)
  @test.assert_eq((try! unchanged.pages_of_pagetree()).length(), 1)
  @test.assert_eq(try! unchanged.read_bookmarks(), [])
}

///|
test "PdfDocument toc_with_source handles cpdftoc font-source dispatch" {
  let base = try! @pdflite.pdf_blank_document(100.0, 100.0, 2)
  let page_refs = try! base.page_reference_numbers()
  let source_bookmark : @bookmark.PdfBookmark = {
    level: 0,
    text: toc_pdfdoc_for_test("Second"),
    target: DestFit(TargetPageObject(page_refs[1])),
    is_open: true,
    colour: @bookmark.pdf_bookmark_black,
    flags: 0,
  }
  let document = try! base.add_bookmarks([source_bookmark])
  let pack = toc_standard_pack_for_test()
  let title = toc_bytes_for_test("Contents")
  let updated = try! document.toc_with_source(
    PdfTocPreMadeFontPack(pack),
    10.0,
    title,
  )
  let toc_page_count = (try! updated.pages_of_pagetree()).length() - 2
  guard toc_page_count > 0 else { fail("expected inserted TOC pages") }
  let bookmarks = try! updated.read_bookmarks(preserve_actions=true)
  @test.assert_eq(bookmarks.length(), 1)
  @test.assert_eq(
    try! updated.page_number_of_target(bookmarks[0].target),
    2 + toc_page_count,
  )
  let wrapped = try! @pdflite.pdf_toc_with_source(
    document,
    PdfTocPreMadeFontPack(pack),
    10.0,
    title,
  )
  @test.assert_eq(
    (try! wrapped.pages_of_pagetree()).length(),
    2 + toc_page_count,
  )
  let rejected : Result[@pdflite.PdfDocument, Error] = try? document.toc_with_source(
    PdfTocExistingNamedFont,
    10.0,
    title,
  )
  guard rejected
    is Err(
      @pdflite.PdfError::SoftError(
        "Cannot use existing font with -table-of-contents"
      )
    ) else {
    fail("expected existing named font rejection")
  }
}

///|
test "pdf_typeset_table_of_contents preserves cpdftoc argument order" {
  let base = try! @pdflite.pdf_blank_document(100.0, 100.0, 2)
  let page_refs = try! base.page_reference_numbers()
  let source_bookmark : @bookmark.PdfBookmark = {
    level: 0,
    text: toc_pdfdoc_for_test("Second"),
    target: DestFit(TargetPageObject(page_refs[1])),
    is_open: true,
    colour: @bookmark.pdf_bookmark_black,
    flags: 0,
  }
  let document = try! base.add_bookmarks([source_bookmark])
  let pack = toc_standard_pack_for_test()
  let title = toc_bytes_for_test("Contents")
  let from_method = try! document.typeset_table_of_contents(
    PdfTocPreMadeFontPack(pack),
    10.0,
    title,
    true,
    true,
    false,
  )
  let wrapped = try! @pdflite.pdf_typeset_table_of_contents(
    PdfTocPreMadeFontPack(pack),
    10.0,
    title,
    true,
    true,
    false,
    document,
  )
  let method_pages = try! from_method.pages_of_pagetree()
  let wrapped_pages = try! wrapped.pages_of_pagetree()
  @test.assert_eq(wrapped_pages.length(), method_pages.length())
  let method_bookmarks = try! from_method.read_bookmarks(preserve_actions=true)
  let wrapped_bookmarks = try! wrapped.read_bookmarks(preserve_actions=true)
  @test.assert_eq(wrapped_bookmarks.length(), method_bookmarks.length())
  @test.assert_eq(wrapped_bookmarks[0].text, method_bookmarks[0].text)
  @test.assert_eq(
    try! wrapped.page_number_of_target(wrapped_bookmarks[0].target),
    try! from_method.page_number_of_target(method_bookmarks[0].target),
  )
  @test.assert_eq(wrapped_bookmarks[1].text, method_bookmarks[1].text)
  @test.assert_eq(
    try! wrapped.page_number_of_target(wrapped_bookmarks[1].target),
    try! from_method.page_number_of_target(method_bookmarks[1].target),
  )

  let structured : Result[@pdflite.PdfDocument, Error] = try? document.typeset_table_of_contents(
    PdfTocPreMadeFontPack(pack),
    10.0,
    title,
    false,
    false,
    true,
  )
  guard structured
    is Err(
      @pdflite.PdfError::SoftError(
        "typeset_table_of_contents: structured TOC output is not implemented"
      )
    ) else {
    fail("expected structured TOC rejection")
  }
  let pdfua : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_typeset_table_of_contents(
    PdfTocPreMadeFontPack(pack),
    10.0,
    title,
    false,
    false,
    false,
    document,
    subformat=Some(PdfUA1),
  )
  guard pdfua
    is Err(
      @pdflite.PdfError::SoftError(
        "typeset_table_of_contents: structured TOC output is not implemented"
      )
    ) else {
    fail("expected PDF/UA TOC rejection")
  }
}
