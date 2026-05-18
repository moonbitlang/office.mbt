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
