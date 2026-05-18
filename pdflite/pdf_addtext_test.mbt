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
