///|
fn texttopdf_standard_font_for_test() -> @pdflite.PdfFont {
  PdfFontStandard({ font: PdfHelvetica, encoding: PdfWinAnsiEncoding })
}

///|
fn texttopdf_bold_font_for_test() -> @pdflite.PdfFont {
  PdfFontStandard({ font: PdfHelveticaBold, encoding: PdfWinAnsiEncoding })
}

///|
fn texttopdf_standard_pack_for_test() -> @pdflite.PdfFontPack {
  try! @pdflite.pdf_fontpack_of_standard_font(
    texttopdf_standard_font_for_test(),
  )
}

///|
test "pdf_texttopdf_of_utf8_with_newlines maps UTF8 to cpdftype text" {
  let font = texttopdf_standard_font_for_test()
  @test.assert_eq(
    try! @pdflite.pdf_texttopdf_of_utf8_with_newlines(
      texttopdf_standard_pack_for_test(),
      12.0,
      @ascii.encode("A\nB\rC"),
    ),
    [
      PdfTypeFont("0", font, 12.0),
      PdfTypeText(@ascii.encode("A")),
      PdfTypeNewLine,
      PdfTypeText(@ascii.encode("BC")),
    ],
  )
}

///|
test "pdf_texttopdf_of_utf8_with_newlines skips unmapped glyphs" {
  let font = texttopdf_standard_font_for_test()
  @test.assert_eq(
    try! @pdflite.pdf_texttopdf_of_utf8_with_newlines(
      texttopdf_standard_pack_for_test(),
      9.0,
      @utf8.encode("A☃B"),
    ),
    [PdfTypeFont("0", font, 9.0), PdfTypeText(@ascii.encode("AB"))],
  )
}

///|
test "pdf_texttopdf_of_utf8_with_newlines switches font runs" {
  let regular = texttopdf_standard_font_for_test()
  let bold = texttopdf_bold_font_for_test()
  let pack : @pdflite.PdfFontPack = {
    fonts: [regular, bold],
    entries: [
      { codepoint: 65, font_index: 0, charcode: 65 },
      { codepoint: 66, font_index: 1, charcode: 66 },
      { codepoint: 67, font_index: 1, charcode: 67 },
      { codepoint: 68, font_index: 0, charcode: 68 },
    ],
  }
  @test.assert_eq(
    try! @pdflite.pdf_texttopdf_of_utf8_with_newlines(
      pack,
      10.0,
      @ascii.encode("ABCD"),
    ),
    [
      PdfTypeFont("0", regular, 10.0),
      PdfTypeText(@ascii.encode("A")),
      PdfTypeFont("1", bold, 10.0),
      PdfTypeText(@ascii.encode("BC")),
      PdfTypeFont("0", regular, 10.0),
      PdfTypeText(@ascii.encode("D")),
    ],
  )
}

///|
test "pdf_texttopdf_of_utf8_with_newlines rejects invalid charcodes" {
  let font = texttopdf_standard_font_for_test()
  let pack : @pdflite.PdfFontPack = {
    fonts: [font],
    entries: [{ codepoint: 65, font_index: 0, charcode: 300 }],
  }
  let result : Result[Array[@pdflite.PdfTypeElement], Error] = try? @pdflite.pdf_texttopdf_of_utf8_with_newlines(
    pack,
    10.0,
    @ascii.encode("A"),
  )
  guard result is Err(@pdflite.PdfError::BadText) else {
    fail("expected invalid charcode to raise BadText")
  }
}

///|
test "pdf_texttopdf_tag_paragraphs wraps blank-line paragraphs" {
  @test.assert_eq(@pdflite.pdf_texttopdf_tag_paragraphs([]), [
    PdfTypeTag("P", 0),
    PdfTypeEndTag,
  ])
  @test.assert_eq(
    @pdflite.pdf_texttopdf_tag_paragraphs([
      PdfTypeText(@ascii.encode("A")),
      PdfTypeNewLine,
      PdfTypeNewLine,
      PdfTypeText(@ascii.encode("B")),
    ]),
    [
      PdfTypeTag("P", 0),
      PdfTypeText(@ascii.encode("A")),
      PdfTypeEndTag,
      PdfTypeNewLine,
      PdfTypeNewLine,
      PdfTypeTag("P", 0),
      PdfTypeText(@ascii.encode("B")),
      PdfTypeEndTag,
    ],
  )
}
