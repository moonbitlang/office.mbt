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
