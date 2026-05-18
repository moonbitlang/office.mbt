///|
fn embed_standard_font_for_test() -> @pdflite.PdfFont {
  PdfFontStandard({ font: PdfHelvetica, encoding: PdfWinAnsiEncoding })
}

///|
fn embed_bold_font_for_test() -> @pdflite.PdfFont {
  PdfFontStandard({ font: PdfHelveticaBold, encoding: PdfWinAnsiEncoding })
}

///|
test "pdf_fontpack_of_standard_font maps Unicode codepoints to charcodes" {
  let font = embed_standard_font_for_test()
  let pack = try! @pdflite.pdf_fontpack_of_standard_font(font)
  @test.assert_eq(pack.fonts, [font])
  @test.assert_eq(pack.entries.length(), 256)
  guard pack.get_char(65) is Some((65, 0, mapped_font)) else {
    fail("expected capital A mapping")
  }
  @test.assert_eq(mapped_font, font)
  @test.assert_eq(@pdflite.pdf_fontpack_get_char(pack, 0x2603), None)
}

///|
test "PdfFontPack::get_char follows cpdf duplicate and missing semantics" {
  let first = embed_standard_font_for_test()
  let second = embed_bold_font_for_test()
  let pack : @pdflite.PdfFontPack = {
    fonts: [first, second],
    entries: [
      { codepoint: 65, font_index: 0, charcode: 41 },
      { codepoint: 66, font_index: 7, charcode: 42 },
      { codepoint: 65, font_index: 1, charcode: 43 },
      { codepoint: 67, font_index: -1, charcode: 44 },
    ],
  }
  @test.assert_eq(pack.get_char(65), Some((43, 1, second)))
  @test.assert_eq(pack.get_char(66), None)
  @test.assert_eq(pack.get_char(67), None)
  @test.assert_eq(pack.get_char(68), None)
}

///|
test "pdf_fontpack_collate_runs groups consecutive equal font numbers" {
  let first = embed_standard_font_for_test()
  let second = embed_bold_font_for_test()
  let runs = [
    (65, 0, first),
    (66, 0, first),
    (67, 1, second),
    (68, 1, second),
    (69, 0, first),
  ]
  @test.assert_eq(@pdflite.pdf_fontpack_collate_runs(runs), [
    [(65, 0, first), (66, 0, first)],
    [(67, 1, second), (68, 1, second)],
    [(69, 0, first)],
  ])
  @test.assert_eq(@pdflite.pdf_fontpack_collate_runs([]), [])
}

///|
test "pdf_standard_font_substitute_filenames mirrors cpdf table" {
  @test.assert_eq(
    @pdflite.pdf_standard_font_substitute_filenames(PdfTimesRoman),
    ["NimbusRoman-Regular.ttf"],
  )
  @test.assert_eq(
    @pdflite.pdf_standard_font_substitute_filenames(PdfHelveticaBoldOblique),
    ["NimbusSans-BoldItalic.ttf"],
  )
  @test.assert_eq(
    @pdflite.pdf_standard_font_substitute_filenames(PdfCourierOblique),
    ["NimbusMonoPS-Italic.ttf"],
  )
  @test.assert_eq(@pdflite.pdf_standard_font_substitute_filenames(PdfSymbol), [
    "StandardSymbolsPS.ttf",
  ])
  @test.assert_eq(
    @pdflite.pdf_standard_font_substitute_filenames(PdfZapfDingbats),
    ["D050000L.ttf"],
  )
}

///|
test "pdf_standard_font_substitute_font_name strips ttf suffix" {
  @test.assert_eq(
    @pdflite.pdf_standard_font_substitute_font_name(PdfHelvetica),
    "NimbusSans-Regular",
  )
  @test.assert_eq(
    @pdflite.pdf_standard_font_substitute_font_name(PdfZapfDingbats),
    "D050000L",
  )
}
