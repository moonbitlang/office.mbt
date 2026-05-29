///|
fn text_extractor_encoding_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn text_extractor_encoding_bytes_for_test(
  values : ArrayView[Int],
) -> @pdflite.PdfBytes {
  try! @pdflite.pdf_bytes_of_int_array(values)
}

///|
fn text_extractor_encoding_difference_for_test(
  name : String,
  code : Int,
) -> @pdflite.PdfEncodingDifference {
  { name: text_extractor_encoding_name_for_test(name), code }
}

///|
fn text_extractor_encoding_standard_font_data_for_test(
  font : @pdflite.PdfStandardFont,
  encoding : @pdflite.PdfEncoding,
) -> @pdflite.PdfStandardFontData {
  { font, encoding }
}

///|
test "PdfTextExtractor extracts StandardEncoding Basic Latin glyphs" {
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_extractor_encoding_standard_font_data_for_test(
      PdfHelvetica,
      PdfStandardEncoding,
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(
      text_extractor_encoding_bytes_for_test([65, 39, 96]),
    ),
    [65, 0x2019, 0x2018],
  )
  @test.assert_eq(
    try! extractor.glyphnames_of_text(
      text_extractor_encoding_bytes_for_test([65, 39, 96]),
    ),
    [
      text_extractor_encoding_name_for_test("/A"),
      text_extractor_encoding_name_for_test("/quoteright"),
      text_extractor_encoding_name_for_test("/quoteleft"),
    ],
  )
  @test.assert_eq(
    try! extractor.codepoints_of_text(
      text_extractor_encoding_bytes_for_test([9, 10, 12, 13]),
    ),
    [9, 10, 12, 13],
  )
  @test.assert_eq(
    try! extractor.glyphnames_of_text(
      text_extractor_encoding_bytes_for_test([9, 10, 12, 13]),
    ),
    [
      text_extractor_encoding_name_for_test("/controlHT"),
      text_extractor_encoding_name_for_test("/controlLF"),
      text_extractor_encoding_name_for_test("/controlFF"),
      text_extractor_encoding_name_for_test("/controlCR"),
    ],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(65), Some(65))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2019), Some(39))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2018), Some(96))
  @test.assert_eq(extractor.charcode_of_codepoint(9), Some(9))
  @test.assert_eq(extractor.charcode_of_codepoint(10), Some(10))
  @test.assert_eq(extractor.charcode_of_codepoint(12), Some(12))
  @test.assert_eq(extractor.charcode_of_codepoint(13), Some(13))
  @test.assert_eq(extractor.charcode_of_codepoint(39), Some(0xA9))
  @test.assert_eq(
    try! extractor.codepoints_of_text(
      text_extractor_encoding_bytes_for_test([
        0xA9, 0xAE, 0xAF, 0xB1, 0xB7, 0xBC,
      ]),
    ),
    [39, 0xFB01, 0xFB02, 0x2013, 0x2022, 0x2026],
  )
  @test.assert_eq(
    try! extractor.glyphnames_of_text(
      text_extractor_encoding_bytes_for_test([
        0xA9, 0xAE, 0xAF, 0xB1, 0xB7, 0xBC,
      ]),
    ),
    [
      text_extractor_encoding_name_for_test("/quotesingle"),
      text_extractor_encoding_name_for_test("/fi"),
      text_extractor_encoding_name_for_test("/fl"),
      text_extractor_encoding_name_for_test("/endash"),
      text_extractor_encoding_name_for_test("/bullet"),
      text_extractor_encoding_name_for_test("/ellipsis"),
    ],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0xFB01), Some(0xAE))
  @test.assert_eq(extractor.charcode_of_codepoint(0xFB02), Some(0xAF))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2022), Some(0xB7))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2026), Some(0xBC))
  @test.assert_eq(
    try! extractor.codepoints_of_text(
      text_extractor_encoding_bytes_for_test([
        0xC1, 0xC2, 0xC6, 0xC7, 0xCA, 0xCD, 0xCF, 0xD0, 0xE1, 0xE8, 0xEA, 0xF1, 0xF5,
        0xF8, 0xFA, 0xFB,
      ]),
    ),
    [
      96, 0x00B4, 0x02D8, 0x02D9, 0x02DA, 0x02DD, 0x02C7, 0x2014, 0x00C6, 0x0141,
      0x0152, 0x00E6, 0x0131, 0x0142, 0x0153, 0x00DF,
    ],
  )
  @test.assert_eq(
    try! extractor.glyphnames_of_text(
      text_extractor_encoding_bytes_for_test([
        0xC1, 0xC2, 0xC6, 0xC7, 0xCA, 0xCD, 0xCF, 0xD0, 0xE1, 0xE8, 0xEA, 0xF1, 0xF5,
        0xF8, 0xFA, 0xFB,
      ]),
    ),
    [
      text_extractor_encoding_name_for_test("/grave"),
      text_extractor_encoding_name_for_test("/acute"),
      text_extractor_encoding_name_for_test("/breve"),
      text_extractor_encoding_name_for_test("/dotaccent"),
      text_extractor_encoding_name_for_test("/ring"),
      text_extractor_encoding_name_for_test("/hungarumlaut"),
      text_extractor_encoding_name_for_test("/caron"),
      text_extractor_encoding_name_for_test("/emdash"),
      text_extractor_encoding_name_for_test("/AE"),
      text_extractor_encoding_name_for_test("/Lslash"),
      text_extractor_encoding_name_for_test("/OE"),
      text_extractor_encoding_name_for_test("/ae"),
      text_extractor_encoding_name_for_test("/dotlessi"),
      text_extractor_encoding_name_for_test("/lslash"),
      text_extractor_encoding_name_for_test("/oe"),
      text_extractor_encoding_name_for_test("/germandbls"),
    ],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x02D8), Some(0xC6))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2014), Some(0xD0))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00C6), Some(0xE1))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0141), Some(0xE8))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0131), Some(0xF5))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00DF), Some(0xFB))
}

///|
test "PdfTextExtractor extracts MacRoman accented glyphs" {
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_extractor_encoding_standard_font_data_for_test(
      PdfHelvetica,
      PdfMacRomanEncoding,
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(
      text_extractor_encoding_bytes_for_test([
        0x80, 0x81, 0x82, 0x83, 0x87, 0x8E,
      ]),
    ),
    [0x00C4, 0x00C5, 0x00C7, 0x00C9, 0x00E1, 0x00E9],
  )
  @test.assert_eq(
    try! extractor.glyphnames_of_text(
      text_extractor_encoding_bytes_for_test([
        0x80, 0x81, 0x82, 0x83, 0x87, 0x8E,
      ]),
    ),
    [
      text_extractor_encoding_name_for_test("/Adieresis"),
      text_extractor_encoding_name_for_test("/Aring"),
      text_extractor_encoding_name_for_test("/Ccedilla"),
      text_extractor_encoding_name_for_test("/Eacute"),
      text_extractor_encoding_name_for_test("/aacute"),
      text_extractor_encoding_name_for_test("/eacute"),
    ],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x00C4), Some(0x80))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00C9), Some(0x83))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00E1), Some(0x87))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00E9), Some(0x8E))
  @test.assert_eq(
    try! extractor.codepoints_of_text(
      text_extractor_encoding_bytes_for_test([
        0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9A, 0x9B, 0x9C, 0x9D, 0x9E,
        0x9F,
      ]),
    ),
    [
      0x00ED, 0x00EC, 0x00EE, 0x00EF, 0x00F1, 0x00F3, 0x00F2, 0x00F4, 0x00F6, 0x00F5,
      0x00FA, 0x00F9, 0x00FB, 0x00FC,
    ],
  )
  @test.assert_eq(
    try! extractor.glyphnames_of_text(
      text_extractor_encoding_bytes_for_test([
        0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9A, 0x9B, 0x9C, 0x9D, 0x9E,
        0x9F,
      ]),
    ),
    [
      text_extractor_encoding_name_for_test("/iacute"),
      text_extractor_encoding_name_for_test("/igrave"),
      text_extractor_encoding_name_for_test("/icircumflex"),
      text_extractor_encoding_name_for_test("/idieresis"),
      text_extractor_encoding_name_for_test("/ntilde"),
      text_extractor_encoding_name_for_test("/oacute"),
      text_extractor_encoding_name_for_test("/ograve"),
      text_extractor_encoding_name_for_test("/ocircumflex"),
      text_extractor_encoding_name_for_test("/odieresis"),
      text_extractor_encoding_name_for_test("/otilde"),
      text_extractor_encoding_name_for_test("/uacute"),
      text_extractor_encoding_name_for_test("/ugrave"),
      text_extractor_encoding_name_for_test("/ucircumflex"),
      text_extractor_encoding_name_for_test("/udieresis"),
    ],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x00ED), Some(0x92))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00F1), Some(0x96))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00F3), Some(0x97))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00FA), Some(0x9C))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00FC), Some(0x9F))
}

///|
test "PdfTextExtractor extracts MacRoman punctuation symbols" {
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_extractor_encoding_standard_font_data_for_test(
      PdfHelvetica,
      PdfMacRomanEncoding,
    ),
  )
  let extractor = standard_font.text_extractor()
  let text = text_extractor_encoding_bytes_for_test([
    0xA0, 0xA1, 0xA2, 0xA3, 0xA4, 0xA5, 0xA6, 0xA7, 0xA8, 0xA9, 0xAA, 0xAB, 0xAC,
    0xAE, 0xAF,
  ])
  @test.assert_eq(try! extractor.codepoints_of_text(text), [
    0x2020, 0x00B0, 0x00A2, 0x00A3, 0x00A7, 0x2022, 0x00B6, 0x00DF, 0x00AE, 0x00A9,
    0x2122, 0x00B4, 0x00A8, 0x00C6, 0x00D8,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(text), [
    text_extractor_encoding_name_for_test("/dagger"),
    text_extractor_encoding_name_for_test("/degree"),
    text_extractor_encoding_name_for_test("/cent"),
    text_extractor_encoding_name_for_test("/sterling"),
    text_extractor_encoding_name_for_test("/section"),
    text_extractor_encoding_name_for_test("/bullet"),
    text_extractor_encoding_name_for_test("/paragraph"),
    text_extractor_encoding_name_for_test("/germandbls"),
    text_extractor_encoding_name_for_test("/registered"),
    text_extractor_encoding_name_for_test("/copyright"),
    text_extractor_encoding_name_for_test("/trademark"),
    text_extractor_encoding_name_for_test("/acute"),
    text_extractor_encoding_name_for_test("/dieresis"),
    text_extractor_encoding_name_for_test("/AE"),
    text_extractor_encoding_name_for_test("/Oslash"),
  ])
  @test.assert_eq(extractor.charcode_of_codepoint(0x2020), Some(0xA0))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2022), Some(0xA5))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2122), Some(0xAA))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00C6), Some(0xAE))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00D8), Some(0xAF))
}

///|
test "PdfTextExtractor extracts MacRoman sparse B-range glyphs" {
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_extractor_encoding_standard_font_data_for_test(
      PdfHelvetica,
      PdfMacRomanEncoding,
    ),
  )
  let extractor = standard_font.text_extractor()
  let text = text_extractor_encoding_bytes_for_test([
    0xB1, 0xB4, 0xB5, 0xBB, 0xBC, 0xBE, 0xBF,
  ])
  @test.assert_eq(try! extractor.codepoints_of_text(text), [
    0x00B1, 0x00A5, 0x00B5, 0x00AA, 0x00BA, 0x00E6, 0x00F8,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(text), [
    text_extractor_encoding_name_for_test("/plusminus"),
    text_extractor_encoding_name_for_test("/yen"),
    text_extractor_encoding_name_for_test("/mu"),
    text_extractor_encoding_name_for_test("/ordfeminine"),
    text_extractor_encoding_name_for_test("/ordmasculine"),
    text_extractor_encoding_name_for_test("/ae"),
    text_extractor_encoding_name_for_test("/oslash"),
  ])
  @test.assert_eq(extractor.charcode_of_codepoint(0x00B1), Some(0xB1))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00A5), Some(0xB4))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00B5), Some(0xB5))
  @test.assert_eq(extractor.charcode_of_codepoint(0x03BC), None)
  @test.assert_eq(extractor.charcode_of_codepoint(0x00AA), Some(0xBB))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00F8), Some(0xBF))
}

///|
test "PdfTextExtractor extracts MacRoman C-range glyphs" {
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_extractor_encoding_standard_font_data_for_test(
      PdfHelvetica,
      PdfMacRomanEncoding,
    ),
  )
  let extractor = standard_font.text_extractor()
  let text = text_extractor_encoding_bytes_for_test([
    0xC0, 0xC1, 0xC2, 0xC4, 0xC7, 0xC8, 0xC9, 0xCA, 0xCB, 0xCC, 0xCD, 0xCE, 0xCF,
  ])
  @test.assert_eq(try! extractor.codepoints_of_text(text), [
    0x00BF, 0x00A1, 0x00AC, 0x0192, 0x00AB, 0x00BB, 0x2026, 0x20, 0x00C0, 0x00C3,
    0x00D5, 0x0152, 0x0153,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(text), [
    text_extractor_encoding_name_for_test("/questiondown"),
    text_extractor_encoding_name_for_test("/exclamdown"),
    text_extractor_encoding_name_for_test("/logicalnot"),
    text_extractor_encoding_name_for_test("/florin"),
    text_extractor_encoding_name_for_test("/guillemotleft"),
    text_extractor_encoding_name_for_test("/guillemotright"),
    text_extractor_encoding_name_for_test("/ellipsis"),
    text_extractor_encoding_name_for_test("/space"),
    text_extractor_encoding_name_for_test("/Agrave"),
    text_extractor_encoding_name_for_test("/Atilde"),
    text_extractor_encoding_name_for_test("/Otilde"),
    text_extractor_encoding_name_for_test("/OE"),
    text_extractor_encoding_name_for_test("/oe"),
  ])
  @test.assert_eq(extractor.charcode_of_codepoint(0x00BF), Some(0xC0))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0192), Some(0xC4))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2026), Some(0xC9))
  @test.assert_eq(extractor.charcode_of_codepoint(0x20), Some(0x20))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0153), Some(0xCF))
}

///|
test "PdfTextExtractor extracts MacRoman D-range glyphs" {
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_extractor_encoding_standard_font_data_for_test(
      PdfHelvetica,
      PdfMacRomanEncoding,
    ),
  )
  let extractor = standard_font.text_extractor()
  let text = text_extractor_encoding_bytes_for_test([
    0xD0, 0xD1, 0xD2, 0xD3, 0xD4, 0xD5, 0xD6, 0xD8, 0xD9, 0xDA, 0xDB, 0xDC, 0xDD,
    0xDE, 0xDF,
  ])
  @test.assert_eq(try! extractor.codepoints_of_text(text), [
    0x2013, 0x2014, 0x201C, 0x201D, 0x2018, 0x2019, 0x00F7, 0x00FF, 0x0178, 0x2044,
    0x00A4, 0x2039, 0x203A, 0xFB01, 0xFB02,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(text), [
    text_extractor_encoding_name_for_test("/endash"),
    text_extractor_encoding_name_for_test("/emdash"),
    text_extractor_encoding_name_for_test("/quotedblleft"),
    text_extractor_encoding_name_for_test("/quotedblright"),
    text_extractor_encoding_name_for_test("/quoteleft"),
    text_extractor_encoding_name_for_test("/quoteright"),
    text_extractor_encoding_name_for_test("/divide"),
    text_extractor_encoding_name_for_test("/ydieresis"),
    text_extractor_encoding_name_for_test("/Ydieresis"),
    text_extractor_encoding_name_for_test("/fraction"),
    text_extractor_encoding_name_for_test("/currency"),
    text_extractor_encoding_name_for_test("/guilsinglleft"),
    text_extractor_encoding_name_for_test("/guilsinglright"),
    text_extractor_encoding_name_for_test("/fi"),
    text_extractor_encoding_name_for_test("/fl"),
  ])
  @test.assert_eq(extractor.charcode_of_codepoint(0x2013), Some(0xD0))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00F7), Some(0xD6))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0178), Some(0xD9))
  @test.assert_eq(extractor.charcode_of_codepoint(0xFB01), Some(0xDE))
  @test.assert_eq(extractor.charcode_of_codepoint(0xFB02), Some(0xDF))
}

///|
test "PdfTextExtractor extracts MacRoman EF-range glyphs" {
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_extractor_encoding_standard_font_data_for_test(
      PdfHelvetica,
      PdfMacRomanEncoding,
    ),
  )
  let extractor = standard_font.text_extractor()
  let text = text_extractor_encoding_bytes_for_test([
    0xE0, 0xE1, 0xE2, 0xE3, 0xE4, 0xE5, 0xE6, 0xE7, 0xE8, 0xE9, 0xEA, 0xEB, 0xEC,
    0xED, 0xEE, 0xEF, 0xF1, 0xF2, 0xF3, 0xF4, 0xF5, 0xF6, 0xF7, 0xF8, 0xF9, 0xFA,
    0xFB, 0xFC, 0xFD, 0xFE, 0xFF,
  ])
  @test.assert_eq(try! extractor.codepoints_of_text(text), [
    0x2021, 0x00B7, 0x201A, 0x201E, 0x2030, 0x00C2, 0x00CA, 0x00C1, 0x00CB, 0x00C8,
    0x00CD, 0x00CE, 0x00CF, 0x00CC, 0x00D3, 0x00D4, 0x00D2, 0x00DA, 0x00DB, 0x00D9,
    0x0131, 0x02C6, 0x02DC, 0x00AF, 0x02D8, 0x02D9, 0x02DA, 0x00B8, 0x02DD, 0x02DB,
    0x02C7,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(text), [
    text_extractor_encoding_name_for_test("/daggerdbl"),
    text_extractor_encoding_name_for_test("/periodcentered"),
    text_extractor_encoding_name_for_test("/quotesinglbase"),
    text_extractor_encoding_name_for_test("/quotedblbase"),
    text_extractor_encoding_name_for_test("/perthousand"),
    text_extractor_encoding_name_for_test("/Acircumflex"),
    text_extractor_encoding_name_for_test("/Ecircumflex"),
    text_extractor_encoding_name_for_test("/Aacute"),
    text_extractor_encoding_name_for_test("/Edieresis"),
    text_extractor_encoding_name_for_test("/Egrave"),
    text_extractor_encoding_name_for_test("/Iacute"),
    text_extractor_encoding_name_for_test("/Icircumflex"),
    text_extractor_encoding_name_for_test("/Idieresis"),
    text_extractor_encoding_name_for_test("/Igrave"),
    text_extractor_encoding_name_for_test("/Oacute"),
    text_extractor_encoding_name_for_test("/Ocircumflex"),
    text_extractor_encoding_name_for_test("/Ograve"),
    text_extractor_encoding_name_for_test("/Uacute"),
    text_extractor_encoding_name_for_test("/Ucircumflex"),
    text_extractor_encoding_name_for_test("/Ugrave"),
    text_extractor_encoding_name_for_test("/dotlessi"),
    text_extractor_encoding_name_for_test("/circumflex"),
    text_extractor_encoding_name_for_test("/tilde"),
    text_extractor_encoding_name_for_test("/macron"),
    text_extractor_encoding_name_for_test("/breve"),
    text_extractor_encoding_name_for_test("/dotaccent"),
    text_extractor_encoding_name_for_test("/ring"),
    text_extractor_encoding_name_for_test("/cedilla"),
    text_extractor_encoding_name_for_test("/hungarumlaut"),
    text_extractor_encoding_name_for_test("/ogonek"),
    text_extractor_encoding_name_for_test("/caron"),
  ])
  @test.assert_eq(extractor.charcode_of_codepoint(0x2021), Some(0xE0))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2030), Some(0xE4))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00C2), Some(0xE5))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0131), Some(0xF5))
  @test.assert_eq(extractor.charcode_of_codepoint(0x02DD), Some(0xFD))
  @test.assert_eq(extractor.charcode_of_codepoint(0x02C7), Some(0xFF))
}

///|
test "PdfTextExtractor extracts WinAnsi glyphs" {
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_extractor_encoding_standard_font_data_for_test(
      PdfHelvetica,
      PdfWinAnsiEncoding,
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(
      text_extractor_encoding_bytes_for_test([
        39, 96, 0x80, 0x91, 0x92, 0x96, 0x97, 0xA9, 0xE9,
      ]),
    ),
    [39, 96, 0x20AC, 0x2018, 0x2019, 0x2013, 0x2014, 0x00A9, 0x00E9],
  )
  @test.assert_eq(
    try! extractor.glyphnames_of_text(
      text_extractor_encoding_bytes_for_test([
        39, 96, 0x80, 0x91, 0x92, 0x96, 0x97, 0xA9, 0xE9,
      ]),
    ),
    [
      text_extractor_encoding_name_for_test("/quotesingle"),
      text_extractor_encoding_name_for_test("/grave"),
      text_extractor_encoding_name_for_test("/Euro"),
      text_extractor_encoding_name_for_test("/quoteleft"),
      text_extractor_encoding_name_for_test("/quoteright"),
      text_extractor_encoding_name_for_test("/endash"),
      text_extractor_encoding_name_for_test("/emdash"),
      text_extractor_encoding_name_for_test("/copyright"),
      text_extractor_encoding_name_for_test("/eacute"),
    ],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(39), Some(39))
  @test.assert_eq(extractor.charcode_of_codepoint(96), Some(96))
  @test.assert_eq(extractor.charcode_of_codepoint(0x20AC), Some(0x80))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2018), Some(0x91))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2019), Some(0x92))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2013), Some(0x96))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2014), Some(0x97))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00A9), Some(0xA9))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00E9), Some(0xE9))
  @test.assert_eq(
    try! extractor.codepoints_of_text(
      text_extractor_encoding_bytes_for_test([
        0xA0, 0xA1, 0xA6, 0xAC, 0xAD, 0xAE, 0xB0, 0xB1, 0xB5, 0xBC, 0xC0, 0xC6, 0xD0,
        0xD8, 0xDE, 0xE6, 0xF0, 0xF8, 0xFE, 0xFF,
      ]),
    ),
    [
      0x20, 0x00A1, 0x00A6, 0x00AC, 0x2D, 0x00AE, 0x00B0, 0x00B1, 0x00B5, 0x00BC,
      0x00C0, 0x00C6, 0x00D0, 0x00D8, 0x00DE, 0x00E6, 0x00F0, 0x00F8, 0x00FE, 0x00FF,
    ],
  )
  @test.assert_eq(
    try! extractor.glyphnames_of_text(
      text_extractor_encoding_bytes_for_test([
        0xA0, 0xA1, 0xA6, 0xAC, 0xAD, 0xAE, 0xB0, 0xB1, 0xB5, 0xBC, 0xC0, 0xC6, 0xD0,
        0xD8, 0xDE, 0xE6, 0xF0, 0xF8, 0xFE, 0xFF,
      ]),
    ),
    [
      text_extractor_encoding_name_for_test("/space"),
      text_extractor_encoding_name_for_test("/exclamdown"),
      text_extractor_encoding_name_for_test("/brokenbar"),
      text_extractor_encoding_name_for_test("/logicalnot"),
      text_extractor_encoding_name_for_test("/hyphen"),
      text_extractor_encoding_name_for_test("/registered"),
      text_extractor_encoding_name_for_test("/degree"),
      text_extractor_encoding_name_for_test("/plusminus"),
      text_extractor_encoding_name_for_test("/mu"),
      text_extractor_encoding_name_for_test("/onequarter"),
      text_extractor_encoding_name_for_test("/Agrave"),
      text_extractor_encoding_name_for_test("/AE"),
      text_extractor_encoding_name_for_test("/Eth"),
      text_extractor_encoding_name_for_test("/Oslash"),
      text_extractor_encoding_name_for_test("/Thorn"),
      text_extractor_encoding_name_for_test("/ae"),
      text_extractor_encoding_name_for_test("/eth"),
      text_extractor_encoding_name_for_test("/oslash"),
      text_extractor_encoding_name_for_test("/thorn"),
      text_extractor_encoding_name_for_test("/ydieresis"),
    ],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x20), Some(0x20))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2D), Some(0x2D))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00A6), Some(0xA6))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00AC), Some(0xAC))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00B1), Some(0xB1))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00B5), Some(0xB5))
  @test.assert_eq(extractor.charcode_of_codepoint(0x03BC), None)
  @test.assert_eq(extractor.charcode_of_codepoint(0x00C0), Some(0xC0))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00C6), Some(0xC6))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00F0), Some(0xF0))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00FF), Some(0xFF))
}

///|
test "PdfTextExtractor extracts MacExpert ligatures" {
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_extractor_encoding_standard_font_data_for_test(
      PdfHelvetica,
      PdfMacExpertEncoding,
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(
      text_extractor_encoding_bytes_for_test([0x56, 0x57, 0x58, 0x59, 0x5A]),
    ),
    [0xFB00, 0xFB01, 0xFB02, 0xFB03, 0xFB04],
  )
  @test.assert_eq(
    try! extractor.glyphnames_of_text(
      text_extractor_encoding_bytes_for_test([0x56, 0x57, 0x58, 0x59, 0x5A]),
    ),
    [
      text_extractor_encoding_name_for_test("/ff"),
      text_extractor_encoding_name_for_test("/fi"),
      text_extractor_encoding_name_for_test("/fl"),
      text_extractor_encoding_name_for_test("/ffi"),
      text_extractor_encoding_name_for_test("/ffl"),
    ],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0xFB00), Some(0x56))
  @test.assert_eq(extractor.charcode_of_codepoint(0xFB01), Some(0x57))
  @test.assert_eq(extractor.charcode_of_codepoint(0xFB02), Some(0x58))
  @test.assert_eq(extractor.charcode_of_codepoint(0xFB03), Some(0x59))
  @test.assert_eq(extractor.charcode_of_codepoint(0xFB04), Some(0x5A))
}

///|
test "PdfTextExtractor extracts MacExpert oldstyle digits" {
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_extractor_encoding_standard_font_data_for_test(
      PdfHelvetica,
      PdfMacExpertEncoding,
    ),
  )
  let extractor = standard_font.text_extractor()
  let text = text_extractor_encoding_bytes_for_test([
    0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39,
  ])
  @test.assert_eq(try! extractor.codepoints_of_text(text), [
    0xF730, 0xF731, 0xF732, 0xF733, 0xF734, 0xF735, 0xF736, 0xF737, 0xF738, 0xF739,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(text), [
    text_extractor_encoding_name_for_test("/zerooldstyle"),
    text_extractor_encoding_name_for_test("/oneoldstyle"),
    text_extractor_encoding_name_for_test("/twooldstyle"),
    text_extractor_encoding_name_for_test("/threeoldstyle"),
    text_extractor_encoding_name_for_test("/fouroldstyle"),
    text_extractor_encoding_name_for_test("/fiveoldstyle"),
    text_extractor_encoding_name_for_test("/sixoldstyle"),
    text_extractor_encoding_name_for_test("/sevenoldstyle"),
    text_extractor_encoding_name_for_test("/eightoldstyle"),
    text_extractor_encoding_name_for_test("/nineoldstyle"),
  ])
  @test.assert_eq(extractor.charcode_of_codepoint(0xF730), Some(0x30))
  @test.assert_eq(extractor.charcode_of_codepoint(0xF735), Some(0x35))
  @test.assert_eq(extractor.charcode_of_codepoint(0xF739), Some(0x39))
}

///|
test "PdfTextExtractor extracts MacExpert superior and inferior digits" {
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_extractor_encoding_standard_font_data_for_test(
      PdfHelvetica,
      PdfMacExpertEncoding,
    ),
  )
  let extractor = standard_font.text_extractor()
  let inferior = text_extractor_encoding_bytes_for_test([
    0xBC, 0xC1, 0xAA, 0xA3, 0xA2, 0xB0, 0xA4, 0xA6, 0xA5, 0xBB,
  ])
  @test.assert_eq(try! extractor.codepoints_of_text(inferior), [
    0x2080, 0x2081, 0x2082, 0x2083, 0x2084, 0x2085, 0x2086, 0x2087, 0x2088, 0x2089,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(inferior), [
    text_extractor_encoding_name_for_test("/zeroinferior"),
    text_extractor_encoding_name_for_test("/oneinferior"),
    text_extractor_encoding_name_for_test("/twoinferior"),
    text_extractor_encoding_name_for_test("/threeinferior"),
    text_extractor_encoding_name_for_test("/fourinferior"),
    text_extractor_encoding_name_for_test("/fiveinferior"),
    text_extractor_encoding_name_for_test("/sixinferior"),
    text_extractor_encoding_name_for_test("/seveninferior"),
    text_extractor_encoding_name_for_test("/eightinferior"),
    text_extractor_encoding_name_for_test("/nineinferior"),
  ])
  let superior = text_extractor_encoding_bytes_for_test([
    0xE2, 0xDA, 0xDB, 0xDC, 0xDD, 0xDE, 0xDF, 0xE0, 0xA1, 0xE1,
  ])
  @test.assert_eq(try! extractor.codepoints_of_text(superior), [
    0x2070, 0x00B9, 0x00B2, 0x00B3, 0x2074, 0x2075, 0x2076, 0x2077, 0x2078, 0x2079,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(superior), [
    text_extractor_encoding_name_for_test("/zerosuperior"),
    text_extractor_encoding_name_for_test("/onesuperior"),
    text_extractor_encoding_name_for_test("/twosuperior"),
    text_extractor_encoding_name_for_test("/threesuperior"),
    text_extractor_encoding_name_for_test("/foursuperior"),
    text_extractor_encoding_name_for_test("/fivesuperior"),
    text_extractor_encoding_name_for_test("/sixsuperior"),
    text_extractor_encoding_name_for_test("/sevensuperior"),
    text_extractor_encoding_name_for_test("/eightsuperior"),
    text_extractor_encoding_name_for_test("/ninesuperior"),
  ])
  @test.assert_eq(extractor.charcode_of_codepoint(0x2080), Some(0xBC))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2085), Some(0xB0))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2089), Some(0xBB))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2070), Some(0xE2))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2075), Some(0xDE))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2079), Some(0xE1))
}

///|
test "PdfTextExtractor extracts MacExpert fractions" {
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_extractor_encoding_standard_font_data_for_test(
      PdfHelvetica,
      PdfMacExpertEncoding,
    ),
  )
  let extractor = standard_font.text_extractor()
  let text = text_extractor_encoding_bytes_for_test([
    0x2F, 0x47, 0x48, 0x49, 0x4A, 0x4B, 0x4C, 0x4D, 0x4E, 0x4F, 0x3D,
  ])
  @test.assert_eq(try! extractor.codepoints_of_text(text), [
    0x2044, 0x00BC, 0x00BD, 0x00BE, 0x215B, 0x215C, 0x215D, 0x215E, 0x2153, 0x2154,
    0xF6DE,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(text), [
    text_extractor_encoding_name_for_test("/fraction"),
    text_extractor_encoding_name_for_test("/onequarter"),
    text_extractor_encoding_name_for_test("/onehalf"),
    text_extractor_encoding_name_for_test("/threequarters"),
    text_extractor_encoding_name_for_test("/oneeighth"),
    text_extractor_encoding_name_for_test("/threeeighths"),
    text_extractor_encoding_name_for_test("/fiveeighths"),
    text_extractor_encoding_name_for_test("/seveneighths"),
    text_extractor_encoding_name_for_test("/onethird"),
    text_extractor_encoding_name_for_test("/twothirds"),
    text_extractor_encoding_name_for_test("/threequartersemdash"),
  ])
  @test.assert_eq(extractor.charcode_of_codepoint(0x2044), Some(0x2F))
  @test.assert_eq(extractor.charcode_of_codepoint(0x215D), Some(0x4C))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2154), Some(0x4F))
  @test.assert_eq(extractor.charcode_of_codepoint(0xF6DE), Some(0x3D))
}

///|
test "PdfTextExtractor extracts MacExpert small capitals" {
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_extractor_encoding_standard_font_data_for_test(
      PdfHelvetica,
      PdfMacExpertEncoding,
    ),
  )
  let extractor = standard_font.text_extractor()
  let text = text_extractor_encoding_bytes_for_test([
    0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6A, 0x6B, 0x6C, 0x6D,
    0x6E, 0x6F, 0x70, 0x71, 0x72, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7A,
  ])
  @test.assert_eq(try! extractor.codepoints_of_text(text), [
    0xF761, 0xF762, 0xF763, 0xF764, 0xF765, 0xF766, 0xF767, 0xF768, 0xF769, 0xF76A,
    0xF76B, 0xF76C, 0xF76D, 0xF76E, 0xF76F, 0xF770, 0xF771, 0xF772, 0xF773, 0xF774,
    0xF775, 0xF776, 0xF777, 0xF778, 0xF779, 0xF77A,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(text), [
    text_extractor_encoding_name_for_test("/Asmall"),
    text_extractor_encoding_name_for_test("/Bsmall"),
    text_extractor_encoding_name_for_test("/Csmall"),
    text_extractor_encoding_name_for_test("/Dsmall"),
    text_extractor_encoding_name_for_test("/Esmall"),
    text_extractor_encoding_name_for_test("/Fsmall"),
    text_extractor_encoding_name_for_test("/Gsmall"),
    text_extractor_encoding_name_for_test("/Hsmall"),
    text_extractor_encoding_name_for_test("/Ismall"),
    text_extractor_encoding_name_for_test("/Jsmall"),
    text_extractor_encoding_name_for_test("/Ksmall"),
    text_extractor_encoding_name_for_test("/Lsmall"),
    text_extractor_encoding_name_for_test("/Msmall"),
    text_extractor_encoding_name_for_test("/Nsmall"),
    text_extractor_encoding_name_for_test("/Osmall"),
    text_extractor_encoding_name_for_test("/Psmall"),
    text_extractor_encoding_name_for_test("/Qsmall"),
    text_extractor_encoding_name_for_test("/Rsmall"),
    text_extractor_encoding_name_for_test("/Ssmall"),
    text_extractor_encoding_name_for_test("/Tsmall"),
    text_extractor_encoding_name_for_test("/Usmall"),
    text_extractor_encoding_name_for_test("/Vsmall"),
    text_extractor_encoding_name_for_test("/Wsmall"),
    text_extractor_encoding_name_for_test("/Xsmall"),
    text_extractor_encoding_name_for_test("/Ysmall"),
    text_extractor_encoding_name_for_test("/Zsmall"),
  ])
  @test.assert_eq(extractor.charcode_of_codepoint(0xF761), Some(0x61))
  @test.assert_eq(extractor.charcode_of_codepoint(0xF76D), Some(0x6D))
  @test.assert_eq(extractor.charcode_of_codepoint(0xF77A), Some(0x7A))
}

///|
test "PdfTextExtractor extracts MacExpert accented small capitals" {
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_extractor_encoding_standard_font_data_for_test(
      PdfHelvetica,
      PdfMacExpertEncoding,
    ),
  )
  let extractor = standard_font.text_extractor()
  let text = text_extractor_encoding_bytes_for_test([
    0xBE, 0x87, 0x89, 0x8A, 0x88, 0x8C, 0x8B, 0x8D, 0x8E, 0x90, 0x91, 0x8F, 0x44,
    0x92, 0x94, 0x95, 0x93, 0xC2, 0x96, 0xCF, 0x97, 0x99, 0x9A, 0x98, 0xBF, 0x9B,
    0xA7, 0xB9, 0x9C, 0x9E, 0x9F, 0x9D, 0xB4, 0xD8, 0xBD,
  ])
  @test.assert_eq(try! extractor.codepoints_of_text(text), [
    0xF7E6, 0xF7E1, 0xF7E2, 0xF7E4, 0xF7E0, 0xF7E5, 0xF7E3, 0xF7E7, 0xF7E9, 0xF7EA,
    0xF7EB, 0xF7E8, 0xF7F0, 0xF7ED, 0xF7EE, 0xF7EF, 0xF7EC, 0xF6F9, 0xF7F1, 0xF6FA,
    0xF7F3, 0xF7F4, 0xF7F6, 0xF7F2, 0xF7F8, 0xF7F5, 0xF6FD, 0xF7FE, 0xF7FA, 0xF7FB,
    0xF7FC, 0xF7F9, 0xF7FD, 0xF7FF, 0xF6FF,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(text), [
    text_extractor_encoding_name_for_test("/AEsmall"),
    text_extractor_encoding_name_for_test("/Aacutesmall"),
    text_extractor_encoding_name_for_test("/Acircumflexsmall"),
    text_extractor_encoding_name_for_test("/Adieresissmall"),
    text_extractor_encoding_name_for_test("/Agravesmall"),
    text_extractor_encoding_name_for_test("/Aringsmall"),
    text_extractor_encoding_name_for_test("/Atildesmall"),
    text_extractor_encoding_name_for_test("/Ccedillasmall"),
    text_extractor_encoding_name_for_test("/Eacutesmall"),
    text_extractor_encoding_name_for_test("/Ecircumflexsmall"),
    text_extractor_encoding_name_for_test("/Edieresissmall"),
    text_extractor_encoding_name_for_test("/Egravesmall"),
    text_extractor_encoding_name_for_test("/Ethsmall"),
    text_extractor_encoding_name_for_test("/Iacutesmall"),
    text_extractor_encoding_name_for_test("/Icircumflexsmall"),
    text_extractor_encoding_name_for_test("/Idieresissmall"),
    text_extractor_encoding_name_for_test("/Igravesmall"),
    text_extractor_encoding_name_for_test("/Lslashsmall"),
    text_extractor_encoding_name_for_test("/Ntildesmall"),
    text_extractor_encoding_name_for_test("/OEsmall"),
    text_extractor_encoding_name_for_test("/Oacutesmall"),
    text_extractor_encoding_name_for_test("/Ocircumflexsmall"),
    text_extractor_encoding_name_for_test("/Odieresissmall"),
    text_extractor_encoding_name_for_test("/Ogravesmall"),
    text_extractor_encoding_name_for_test("/Oslashsmall"),
    text_extractor_encoding_name_for_test("/Otildesmall"),
    text_extractor_encoding_name_for_test("/Scaronsmall"),
    text_extractor_encoding_name_for_test("/Thornsmall"),
    text_extractor_encoding_name_for_test("/Uacutesmall"),
    text_extractor_encoding_name_for_test("/Ucircumflexsmall"),
    text_extractor_encoding_name_for_test("/Udieresissmall"),
    text_extractor_encoding_name_for_test("/Ugravesmall"),
    text_extractor_encoding_name_for_test("/Yacutesmall"),
    text_extractor_encoding_name_for_test("/Ydieresissmall"),
    text_extractor_encoding_name_for_test("/Zcaronsmall"),
  ])
  @test.assert_eq(extractor.charcode_of_codepoint(0xF7E6), Some(0xBE))
  @test.assert_eq(extractor.charcode_of_codepoint(0xF7F0), Some(0x44))
  @test.assert_eq(extractor.charcode_of_codepoint(0xF6FF), Some(0xBD))
}

///|
test "PdfTextExtractor extracts MacExpert small accent marks" {
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_extractor_encoding_standard_font_data_for_test(
      PdfHelvetica,
      PdfMacExpertEncoding,
    ),
  )
  let extractor = standard_font.text_extractor()
  let text = text_extractor_encoding_bytes_for_test([
    0x27, 0xF3, 0xAE, 0xC9, 0x5E, 0xAC, 0xFA, 0x60, 0x22, 0xF4, 0xF2, 0xFB, 0x7E,
  ])
  @test.assert_eq(try! extractor.codepoints_of_text(text), [
    0xF7B4, 0xF6F4, 0xF6F5, 0xF7B8, 0xF6F6, 0xF7A8, 0xF6F7, 0xF760, 0xF6F8, 0xF7AF,
    0xF6FB, 0xF6FC, 0xF6FE,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(text), [
    text_extractor_encoding_name_for_test("/Acutesmall"),
    text_extractor_encoding_name_for_test("/Brevesmall"),
    text_extractor_encoding_name_for_test("/Caronsmall"),
    text_extractor_encoding_name_for_test("/Cedillasmall"),
    text_extractor_encoding_name_for_test("/Circumflexsmall"),
    text_extractor_encoding_name_for_test("/Dieresissmall"),
    text_extractor_encoding_name_for_test("/Dotaccentsmall"),
    text_extractor_encoding_name_for_test("/Gravesmall"),
    text_extractor_encoding_name_for_test("/Hungarumlautsmall"),
    text_extractor_encoding_name_for_test("/Macronsmall"),
    text_extractor_encoding_name_for_test("/Ogoneksmall"),
    text_extractor_encoding_name_for_test("/Ringsmall"),
    text_extractor_encoding_name_for_test("/Tildesmall"),
  ])
  @test.assert_eq(extractor.charcode_of_codepoint(0xF7B4), Some(0x27))
  @test.assert_eq(extractor.charcode_of_codepoint(0xF6F7), Some(0xFA))
  @test.assert_eq(extractor.charcode_of_codepoint(0xF6FE), Some(0x7E))
}

///|
test "PdfTextExtractor extracts MacExpert small punctuation and currency" {
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_extractor_encoding_standard_font_data_for_test(
      PdfHelvetica,
      PdfMacExpertEncoding,
    ),
  )
  let extractor = standard_font.text_extractor()
  let text = text_extractor_encoding_bytes_for_test([
    0x20, 0x21, 0x23, 0x24, 0x26, 0x2A, 0x2B, 0x2C, 0x2D, 0x2E, 0x3A, 0x3B, 0x3F,
    0x7B, 0x7C, 0x7D, 0xC0, 0xD0, 0xD6,
  ])
  @test.assert_eq(try! extractor.codepoints_of_text(text), [
    0x20, 0xF721, 0xF7A2, 0xF724, 0xF726, 0x2025, 0x2024, 0x2C, 0x2D, 0x2E, 0x3A,
    0x3B, 0xF73F, 0x20A1, 0xF6DC, 0xF6DD, 0xF7BF, 0x2012, 0xF7A1,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(text), [
    text_extractor_encoding_name_for_test("/space"),
    text_extractor_encoding_name_for_test("/exclamsmall"),
    text_extractor_encoding_name_for_test("/centoldstyle"),
    text_extractor_encoding_name_for_test("/dollaroldstyle"),
    text_extractor_encoding_name_for_test("/ampersandsmall"),
    text_extractor_encoding_name_for_test("/twodotenleader"),
    text_extractor_encoding_name_for_test("/onedotenleader"),
    text_extractor_encoding_name_for_test("/comma"),
    text_extractor_encoding_name_for_test("/hyphen"),
    text_extractor_encoding_name_for_test("/period"),
    text_extractor_encoding_name_for_test("/colon"),
    text_extractor_encoding_name_for_test("/semicolon"),
    text_extractor_encoding_name_for_test("/questionsmall"),
    text_extractor_encoding_name_for_test("/colonmonetary"),
    text_extractor_encoding_name_for_test("/onefitted"),
    text_extractor_encoding_name_for_test("/rupiah"),
    text_extractor_encoding_name_for_test("/questiondownsmall"),
    text_extractor_encoding_name_for_test("/figuredash"),
    text_extractor_encoding_name_for_test("/exclamdownsmall"),
  ])
  @test.assert_eq(extractor.charcode_of_codepoint(0xF721), Some(0x21))
  @test.assert_eq(extractor.charcode_of_codepoint(0xF724), Some(0x24))
  @test.assert_eq(extractor.charcode_of_codepoint(0x20A1), Some(0x7B))
  @test.assert_eq(extractor.charcode_of_codepoint(0xF7A1), Some(0xD6))
}

///|
test "PdfTextExtractor extracts MacExpert superior and inferior punctuation and letters" {
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_extractor_encoding_standard_font_data_for_test(
      PdfHelvetica,
      PdfMacExpertEncoding,
    ),
  )
  let extractor = standard_font.text_extractor()
  let text = text_extractor_encoding_bytes_for_test([
    0x28, 0x29, 0x5B, 0x5D, 0x5F, 0x81, 0x82, 0xA9, 0xAF, 0xB2, 0xB3, 0xB6, 0xE4,
    0xE5, 0xE6, 0xE9, 0xEA, 0xEB, 0xF1, 0xF5, 0xF6, 0xF7, 0xF8, 0xF9,
  ])
  @test.assert_eq(try! extractor.codepoints_of_text(text), [
    0x207D, 0x207E, 0x208D, 0x208E, 0xF6E5, 0xF6E9, 0xF6E0, 0xF6DF, 0xF6F0, 0xF6E1,
    0xF6E7, 0xF6E3, 0xF6EC, 0xF6F1, 0xF6F3, 0xF6ED, 0xF6F2, 0xF6EB, 0xF6EE, 0xF6EA,
    0x207F, 0xF6EF, 0xF6E2, 0xF6E8,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(text), [
    text_extractor_encoding_name_for_test("/parenleftsuperior"),
    text_extractor_encoding_name_for_test("/parenrightsuperior"),
    text_extractor_encoding_name_for_test("/parenleftinferior"),
    text_extractor_encoding_name_for_test("/parenrightinferior"),
    text_extractor_encoding_name_for_test("/hypheninferior"),
    text_extractor_encoding_name_for_test("/asuperior"),
    text_extractor_encoding_name_for_test("/centsuperior"),
    text_extractor_encoding_name_for_test("/centinferior"),
    text_extractor_encoding_name_for_test("/osuperior"),
    text_extractor_encoding_name_for_test("/commainferior"),
    text_extractor_encoding_name_for_test("/periodinferior"),
    text_extractor_encoding_name_for_test("/dollarinferior"),
    text_extractor_encoding_name_for_test("/esuperior"),
    text_extractor_encoding_name_for_test("/rsuperior"),
    text_extractor_encoding_name_for_test("/tsuperior"),
    text_extractor_encoding_name_for_test("/isuperior"),
    text_extractor_encoding_name_for_test("/ssuperior"),
    text_extractor_encoding_name_for_test("/dsuperior"),
    text_extractor_encoding_name_for_test("/lsuperior"),
    text_extractor_encoding_name_for_test("/bsuperior"),
    text_extractor_encoding_name_for_test("/nsuperior"),
    text_extractor_encoding_name_for_test("/msuperior"),
    text_extractor_encoding_name_for_test("/commasuperior"),
    text_extractor_encoding_name_for_test("/periodsuperior"),
  ])
  @test.assert_eq(extractor.charcode_of_codepoint(0x207D), Some(0x28))
  @test.assert_eq(extractor.charcode_of_codepoint(0xF6E5), Some(0x5F))
  @test.assert_eq(extractor.charcode_of_codepoint(0xF6E0), Some(0x82))
  @test.assert_eq(extractor.charcode_of_codepoint(0xF6EA), Some(0xF5))
  @test.assert_eq(extractor.charcode_of_codepoint(0xF6E8), Some(0xF9))
}

///|
test "PdfTextExtractor decodes MacExpert hyphensuperior glyph names" {
  let base_font : @pdflite.PdfFont = PdfFontStandard(
    text_extractor_encoding_standard_font_data_for_test(
      PdfHelvetica,
      PdfMacExpertEncoding,
    ),
  )
  let base_extractor = base_font.text_extractor()
  @test.assert_eq(
    try! base_extractor.codepoints_of_text(
      text_extractor_encoding_bytes_for_test([0x5F]),
    ),
    [0xF6E5],
  )
  @test.assert_eq(base_extractor.charcode_of_codepoint(0xF6E6), Some(0x5F))
  let standard_base_font : @pdflite.PdfFont = PdfFontStandard(
    text_extractor_encoding_standard_font_data_for_test(
      PdfHelvetica,
      PdfStandardEncoding,
    ),
  )
  @test.assert_eq(
    standard_base_font.text_extractor().charcode_of_codepoint(0xF6E6),
    None,
  )
  let custom_base_font : @pdflite.PdfFont = PdfFontStandard(
    text_extractor_encoding_standard_font_data_for_test(
      PdfHelvetica,
      PdfCustomEncoding(PdfMacExpertEncoding, []),
    ),
  )
  @test.assert_eq(
    custom_base_font.text_extractor().charcode_of_codepoint(0xF6E6),
    Some(0x5F),
  )
  let filled_base_font : @pdflite.PdfFont = PdfFontStandard(
    text_extractor_encoding_standard_font_data_for_test(
      PdfHelvetica,
      PdfFillUndefinedWithStandard(PdfMacExpertEncoding),
    ),
  )
  @test.assert_eq(
    filled_base_font.text_extractor().charcode_of_codepoint(0xF6E6),
    Some(0x5F),
  )
  let simple_base_font : @pdflite.PdfFont = PdfFontSimple({
    fonttype: PdfType1,
    basefont: None,
    firstchar: 0,
    lastchar: 0,
    widths: [],
    fontdescriptor: None,
    fontmetrics: None,
    encoding: PdfMacExpertEncoding,
  })
  @test.assert_eq(
    simple_base_font.text_extractor().charcode_of_codepoint(0xF6E6),
    Some(0x5F),
  )
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_extractor_encoding_standard_font_data_for_test(
      PdfHelvetica,
      PdfCustomEncoding(PdfMacExpertEncoding, [
        text_extractor_encoding_difference_for_test("/hyphensuperior", 0x41),
      ]),
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(
      text_extractor_encoding_bytes_for_test([0x41, 0x5F]),
    ),
    [0xF6E6, 0xF6E5],
  )
  @test.assert_eq(
    try! extractor.glyphnames_of_text(
      text_extractor_encoding_bytes_for_test([0x41, 0x5F]),
    ),
    [
      text_extractor_encoding_name_for_test("/hyphensuperior"),
      text_extractor_encoding_name_for_test("/hypheninferior"),
    ],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0xF6E6), Some(0x41))
}

///|
test "PdfTextExtractor uses built-in Standard14 encodings when implicit" {
  let helvetica : @pdflite.PdfFont = PdfFontStandard(
    text_extractor_encoding_standard_font_data_for_test(
      PdfHelvetica,
      PdfImplicitInFontFile,
    ),
  )
  let helvetica_extractor = helvetica.text_extractor()
  @test.assert_eq(
    try! helvetica_extractor.codepoints_of_text(
      text_extractor_encoding_bytes_for_test([65, 39, 96, 0xAE]),
    ),
    [65, 0x2019, 0x2018, 0xFB01],
  )
  @test.assert_eq(
    try! helvetica_extractor.glyphnames_of_text(
      text_extractor_encoding_bytes_for_test([65, 39, 96, 0xAE]),
    ),
    [
      text_extractor_encoding_name_for_test("/A"),
      text_extractor_encoding_name_for_test("/quoteright"),
      text_extractor_encoding_name_for_test("/quoteleft"),
      text_extractor_encoding_name_for_test("/fi"),
    ],
  )
  @test.assert_eq(helvetica_extractor.charcode_of_codepoint(65), Some(65))
  @test.assert_eq(helvetica_extractor.charcode_of_codepoint(0xFB01), Some(0xAE))
}

///|
test "PdfTextExtractor extracts implicit Symbol glyphs" {
  let symbol_font : @pdflite.PdfFont = PdfFontStandard(
    text_extractor_encoding_standard_font_data_for_test(
      PdfSymbol,
      PdfImplicitInFontFile,
    ),
  )
  let extractor = symbol_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(
      text_extractor_encoding_bytes_for_test([
        0x41, 0x44, 0x57, 0x61, 0x6D, 0xA5, 0xAE, 0xB3, 0xD6,
      ]),
    ),
    [0x0391, 0x0394, 0x03A9, 0x03B1, 0x03BC, 0x221E, 0x2192, 0x2265, 0x221A],
  )
  @test.assert_eq(
    try! extractor.glyphnames_of_text(
      text_extractor_encoding_bytes_for_test([
        0x41, 0x44, 0x57, 0x61, 0x6D, 0xA5, 0xAE, 0xB3, 0xD6,
      ]),
    ),
    [
      text_extractor_encoding_name_for_test("/Alpha"),
      text_extractor_encoding_name_for_test("/Delta"),
      text_extractor_encoding_name_for_test("/Omega"),
      text_extractor_encoding_name_for_test("/alpha"),
      text_extractor_encoding_name_for_test("/mu"),
      text_extractor_encoding_name_for_test("/infinity"),
      text_extractor_encoding_name_for_test("/arrowright"),
      text_extractor_encoding_name_for_test("/greaterequal"),
      text_extractor_encoding_name_for_test("/radical"),
    ],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x0391), Some(0x41))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0394), Some(0x44))
  @test.assert_eq(extractor.charcode_of_codepoint(0x03A9), Some(0x57))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2206), None)
  @test.assert_eq(extractor.charcode_of_codepoint(0x2126), None)
  @test.assert_eq(extractor.charcode_of_codepoint(0x03B1), Some(0x61))
  @test.assert_eq(extractor.charcode_of_codepoint(0x03BC), Some(0x6D))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00B5), None)
  @test.assert_eq(extractor.charcode_of_codepoint(0x221E), Some(0xA5))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2192), Some(0xAE))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2265), Some(0xB3))
  @test.assert_eq(extractor.charcode_of_codepoint(0x221A), Some(0xD6))
}

///|
test "PdfTextExtractor extracts implicit Symbol set and logic glyphs" {
  let symbol_font : @pdflite.PdfFont = PdfFontStandard(
    text_extractor_encoding_standard_font_data_for_test(
      PdfSymbol,
      PdfImplicitInFontFile,
    ),
  )
  let extractor = symbol_font.text_extractor()
  let text = text_extractor_encoding_bytes_for_test([
    0x40, 0x5C, 0x5E, 0x7E, 0xC0, 0xC4, 0xC5, 0xC6, 0xC7, 0xC8, 0xCE, 0xCF, 0xD0,
    0xD1, 0xD5, 0xD8, 0xD9, 0xDA, 0xDB, 0xDC, 0xDE, 0xDF, 0xE5,
  ])
  @test.assert_eq(try! extractor.codepoints_of_text(text), [
    0x2245, 0x2234, 0x22A5, 0x223C, 0x2135, 0x2297, 0x2295, 0x2205, 0x2229, 0x222A,
    0x2208, 0x2209, 0x2220, 0x2207, 0x220F, 0x00AC, 0x2227, 0x2228, 0x21D4, 0x21D0,
    0x21D2, 0x21D3, 0x2211,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(text), [
    text_extractor_encoding_name_for_test("/congruent"),
    text_extractor_encoding_name_for_test("/therefore"),
    text_extractor_encoding_name_for_test("/perpendicular"),
    text_extractor_encoding_name_for_test("/similar"),
    text_extractor_encoding_name_for_test("/aleph"),
    text_extractor_encoding_name_for_test("/circlemultiply"),
    text_extractor_encoding_name_for_test("/circleplus"),
    text_extractor_encoding_name_for_test("/emptyset"),
    text_extractor_encoding_name_for_test("/intersection"),
    text_extractor_encoding_name_for_test("/union"),
    text_extractor_encoding_name_for_test("/element"),
    text_extractor_encoding_name_for_test("/notelement"),
    text_extractor_encoding_name_for_test("/angle"),
    text_extractor_encoding_name_for_test("/gradient"),
    text_extractor_encoding_name_for_test("/product"),
    text_extractor_encoding_name_for_test("/logicalnot"),
    text_extractor_encoding_name_for_test("/logicaland"),
    text_extractor_encoding_name_for_test("/logicalor"),
    text_extractor_encoding_name_for_test("/arrowdblboth"),
    text_extractor_encoding_name_for_test("/arrowdblleft"),
    text_extractor_encoding_name_for_test("/arrowdblright"),
    text_extractor_encoding_name_for_test("/arrowdbldown"),
    text_extractor_encoding_name_for_test("/summation"),
  ])
  @test.assert_eq(extractor.charcode_of_codepoint(0x2245), Some(0x40))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2205), Some(0xC6))
  @test.assert_eq(extractor.charcode_of_codepoint(0x222A), Some(0xC8))
  @test.assert_eq(extractor.charcode_of_codepoint(0x21D4), Some(0xDB))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2211), Some(0xE5))
}

///|
test "PdfTextExtractor extracts implicit Symbol punctuation and variant glyphs" {
  let symbol_font : @pdflite.PdfFont = PdfFontStandard(
    text_extractor_encoding_standard_font_data_for_test(
      PdfSymbol,
      PdfImplicitInFontFile,
    ),
  )
  let extractor = symbol_font.text_extractor()
  let text = text_extractor_encoding_bytes_for_test([
    0x3A, 0x3B, 0x3C, 0x3E, 0x3F, 0x4A, 0x56, 0x5B, 0x5D, 0x5F, 0x60, 0x6A, 0x76,
    0x7B, 0x7C, 0x7D, 0xA1,
  ])
  @test.assert_eq(try! extractor.codepoints_of_text(text), [
    58, 59, 60, 62, 63, 0x03D1, 0x03C2, 91, 93, 95, 0xF8E5, 0x03D5, 0x03D6, 123,
    124, 125, 0x03D2,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(text), [
    text_extractor_encoding_name_for_test("/colon"),
    text_extractor_encoding_name_for_test("/semicolon"),
    text_extractor_encoding_name_for_test("/less"),
    text_extractor_encoding_name_for_test("/greater"),
    text_extractor_encoding_name_for_test("/question"),
    text_extractor_encoding_name_for_test("/theta1"),
    text_extractor_encoding_name_for_test("/sigma1"),
    text_extractor_encoding_name_for_test("/bracketleft"),
    text_extractor_encoding_name_for_test("/bracketright"),
    text_extractor_encoding_name_for_test("/underscore"),
    text_extractor_encoding_name_for_test("/radicalex"),
    text_extractor_encoding_name_for_test("/phi1"),
    text_extractor_encoding_name_for_test("/omega1"),
    text_extractor_encoding_name_for_test("/braceleft"),
    text_extractor_encoding_name_for_test("/bar"),
    text_extractor_encoding_name_for_test("/braceright"),
    text_extractor_encoding_name_for_test("/Upsilon1"),
  ])
  @test.assert_eq(extractor.charcode_of_codepoint(0x03D1), Some(0x4A))
  @test.assert_eq(extractor.charcode_of_codepoint(0x03C2), Some(0x56))
  @test.assert_eq(extractor.charcode_of_codepoint(0xF8E5), Some(0x60))
  @test.assert_eq(extractor.charcode_of_codepoint(0x03D5), Some(0x6A))
  @test.assert_eq(extractor.charcode_of_codepoint(0x03D6), Some(0x76))
  @test.assert_eq(extractor.charcode_of_codepoint(0x03D2), Some(0xA1))
}

///|
test "PdfTextExtractor extracts implicit Symbol special glyphs" {
  let symbol_font : @pdflite.PdfFont = PdfFontStandard(
    text_extractor_encoding_standard_font_data_for_test(
      PdfSymbol,
      PdfImplicitInFontFile,
    ),
  )
  let extractor = symbol_font.text_extractor()
  let text = text_extractor_encoding_bytes_for_test([
    0xA2, 0xA4, 0xA6, 0xAF, 0xBD, 0xBE, 0xBF, 0xD2, 0xD3, 0xD4, 0xDD, 0xE1, 0xE2,
    0xE3, 0xE4, 0xF1,
  ])
  @test.assert_eq(try! extractor.codepoints_of_text(text), [
    0x2032, 0x2044, 0x0192, 0x2193, 0xF8E6, 0xF8E7, 0x21B5, 0xF6DA, 0xF6D9, 0xF6DB,
    0x21D1, 0x2329, 0xF8E8, 0xF8E9, 0xF8EA, 0x232A,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(text), [
    text_extractor_encoding_name_for_test("/minute"),
    text_extractor_encoding_name_for_test("/fraction"),
    text_extractor_encoding_name_for_test("/florin"),
    text_extractor_encoding_name_for_test("/arrowdown"),
    text_extractor_encoding_name_for_test("/arrowvertex"),
    text_extractor_encoding_name_for_test("/arrowhorizex"),
    text_extractor_encoding_name_for_test("/carriagereturn"),
    text_extractor_encoding_name_for_test("/registerserif"),
    text_extractor_encoding_name_for_test("/copyrightserif"),
    text_extractor_encoding_name_for_test("/trademarkserif"),
    text_extractor_encoding_name_for_test("/arrowdblup"),
    text_extractor_encoding_name_for_test("/angleleft"),
    text_extractor_encoding_name_for_test("/registersans"),
    text_extractor_encoding_name_for_test("/copyrightsans"),
    text_extractor_encoding_name_for_test("/trademarksans"),
    text_extractor_encoding_name_for_test("/angleright"),
  ])
  @test.assert_eq(extractor.charcode_of_codepoint(0x2032), Some(0xA2))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2193), Some(0xAF))
  @test.assert_eq(extractor.charcode_of_codepoint(0xF8E6), Some(0xBD))
  @test.assert_eq(extractor.charcode_of_codepoint(0x21D1), Some(0xDD))
  @test.assert_eq(extractor.charcode_of_codepoint(0x232A), Some(0xF1))
}

///|
test "PdfTextExtractor extracts implicit Symbol assembly glyphs" {
  let symbol_font : @pdflite.PdfFont = PdfFontStandard(
    text_extractor_encoding_standard_font_data_for_test(
      PdfSymbol,
      PdfImplicitInFontFile,
    ),
  )
  let extractor = symbol_font.text_extractor()
  let text = text_extractor_encoding_bytes_for_test([
    0xE6, 0xE7, 0xE8, 0xE9, 0xEA, 0xEB, 0xEC, 0xED, 0xEE, 0xEF, 0xF2, 0xF3, 0xF4,
    0xF5, 0xF6, 0xF7, 0xF8, 0xF9, 0xFA, 0xFB, 0xFC, 0xFD, 0xFE,
  ])
  @test.assert_eq(try! extractor.codepoints_of_text(text), [
    0xF8EB, 0xF8EC, 0xF8ED, 0xF8EE, 0xF8EF, 0xF8F0, 0xF8F1, 0xF8F2, 0xF8F3, 0xF8F4,
    0x222B, 0x2320, 0xF8F5, 0x2321, 0xF8F6, 0xF8F7, 0xF8F8, 0xF8F9, 0xF8FA, 0xF8FB,
    0xF8FC, 0xF8FD, 0xF8FE,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(text), [
    text_extractor_encoding_name_for_test("/parenlefttp"),
    text_extractor_encoding_name_for_test("/parenleftex"),
    text_extractor_encoding_name_for_test("/parenleftbt"),
    text_extractor_encoding_name_for_test("/bracketlefttp"),
    text_extractor_encoding_name_for_test("/bracketleftex"),
    text_extractor_encoding_name_for_test("/bracketleftbt"),
    text_extractor_encoding_name_for_test("/bracelefttp"),
    text_extractor_encoding_name_for_test("/braceleftmid"),
    text_extractor_encoding_name_for_test("/braceleftbt"),
    text_extractor_encoding_name_for_test("/braceex"),
    text_extractor_encoding_name_for_test("/integral"),
    text_extractor_encoding_name_for_test("/integraltp"),
    text_extractor_encoding_name_for_test("/integralex"),
    text_extractor_encoding_name_for_test("/integralbt"),
    text_extractor_encoding_name_for_test("/parenrighttp"),
    text_extractor_encoding_name_for_test("/parenrightex"),
    text_extractor_encoding_name_for_test("/parenrightbt"),
    text_extractor_encoding_name_for_test("/bracketrighttp"),
    text_extractor_encoding_name_for_test("/bracketrightex"),
    text_extractor_encoding_name_for_test("/bracketrightbt"),
    text_extractor_encoding_name_for_test("/bracerighttp"),
    text_extractor_encoding_name_for_test("/bracerightmid"),
    text_extractor_encoding_name_for_test("/bracerightbt"),
  ])
  @test.assert_eq(extractor.charcode_of_codepoint(0xF8EB), Some(0xE6))
  @test.assert_eq(extractor.charcode_of_codepoint(0x222B), Some(0xF2))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2321), Some(0xF5))
  @test.assert_eq(extractor.charcode_of_codepoint(0xF8FE), Some(0xFE))
}

///|
test "PdfTextExtractor extracts implicit ZapfDingbats glyphs" {
  let dingbat_font : @pdflite.PdfFont = PdfFontStandard(
    text_extractor_encoding_standard_font_data_for_test(
      PdfZapfDingbats,
      PdfImplicitInFontFile,
    ),
  )
  let extractor = dingbat_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(
      text_extractor_encoding_bytes_for_test([0x21, 0x22, 0x23, 0x48, 0xA1]),
    ),
    [0x2701, 0x2702, 0x2703, 0x2605, 0x2761],
  )
  @test.assert_eq(
    try! extractor.glyphnames_of_text(
      text_extractor_encoding_bytes_for_test([0x21, 0x22, 0x23, 0x48, 0xA1]),
    ),
    [
      text_extractor_encoding_name_for_test("/a1"),
      text_extractor_encoding_name_for_test("/a2"),
      text_extractor_encoding_name_for_test("/a202"),
      text_extractor_encoding_name_for_test("/a35"),
      text_extractor_encoding_name_for_test("/a101"),
    ],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x2701), Some(0x21))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2702), Some(0x22))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2703), Some(0x23))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2605), Some(0x48))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2761), Some(0xA1))
}

///|
test "PdfTextExtractor extracts implicit ZapfDingbats cross and star glyphs" {
  let dingbat_font : @pdflite.PdfFont = PdfFontStandard(
    text_extractor_encoding_standard_font_data_for_test(
      PdfZapfDingbats,
      PdfImplicitInFontFile,
    ),
  )
  let extractor = dingbat_font.text_extractor()
  let text = text_extractor_encoding_bytes_for_test([
    0x3A, 0x3B, 0x3C, 0x3D, 0x3E, 0x3F, 0x40, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46,
    0x47,
  ])
  @test.assert_eq(try! extractor.codepoints_of_text(text), [
    0x271A, 0x271B, 0x271C, 0x271D, 0x271E, 0x271F, 0x2720, 0x2721, 0x2722, 0x2723,
    0x2724, 0x2725, 0x2726, 0x2727,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(text), [
    text_extractor_encoding_name_for_test("/a26"),
    text_extractor_encoding_name_for_test("/a27"),
    text_extractor_encoding_name_for_test("/a28"),
    text_extractor_encoding_name_for_test("/a6"),
    text_extractor_encoding_name_for_test("/a7"),
    text_extractor_encoding_name_for_test("/a8"),
    text_extractor_encoding_name_for_test("/a9"),
    text_extractor_encoding_name_for_test("/a10"),
    text_extractor_encoding_name_for_test("/a29"),
    text_extractor_encoding_name_for_test("/a30"),
    text_extractor_encoding_name_for_test("/a31"),
    text_extractor_encoding_name_for_test("/a32"),
    text_extractor_encoding_name_for_test("/a33"),
    text_extractor_encoding_name_for_test("/a34"),
  ])
  @test.assert_eq(extractor.charcode_of_codepoint(0x271A), Some(0x3A))
  @test.assert_eq(extractor.charcode_of_codepoint(0x271D), Some(0x3D))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2721), Some(0x41))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2727), Some(0x47))
}

///|
test "PdfTextExtractor extracts implicit ZapfDingbats starburst glyphs" {
  let dingbat_font : @pdflite.PdfFont = PdfFontStandard(
    text_extractor_encoding_standard_font_data_for_test(
      PdfZapfDingbats,
      PdfImplicitInFontFile,
    ),
  )
  let extractor = dingbat_font.text_extractor()
  let text = text_extractor_encoding_bytes_for_test([
    0x4D, 0x4E, 0x4F, 0x50, 0x51, 0x52, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59,
    0x5A,
  ])
  @test.assert_eq(try! extractor.codepoints_of_text(text), [
    0x272D, 0x272E, 0x272F, 0x2730, 0x2731, 0x2732, 0x2733, 0x2734, 0x2735, 0x2736,
    0x2737, 0x2738, 0x2739, 0x273A,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(text), [
    text_extractor_encoding_name_for_test("/a40"),
    text_extractor_encoding_name_for_test("/a41"),
    text_extractor_encoding_name_for_test("/a42"),
    text_extractor_encoding_name_for_test("/a43"),
    text_extractor_encoding_name_for_test("/a44"),
    text_extractor_encoding_name_for_test("/a45"),
    text_extractor_encoding_name_for_test("/a46"),
    text_extractor_encoding_name_for_test("/a47"),
    text_extractor_encoding_name_for_test("/a48"),
    text_extractor_encoding_name_for_test("/a49"),
    text_extractor_encoding_name_for_test("/a50"),
    text_extractor_encoding_name_for_test("/a51"),
    text_extractor_encoding_name_for_test("/a52"),
    text_extractor_encoding_name_for_test("/a53"),
  ])
  @test.assert_eq(extractor.charcode_of_codepoint(0x272D), Some(0x4D))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2730), Some(0x50))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2737), Some(0x57))
  @test.assert_eq(extractor.charcode_of_codepoint(0x273A), Some(0x5A))
}

///|
test "PdfTextExtractor extracts implicit ZapfDingbats sparkle glyphs" {
  let dingbat_font : @pdflite.PdfFont = PdfFontStandard(
    text_extractor_encoding_standard_font_data_for_test(
      PdfZapfDingbats,
      PdfImplicitInFontFile,
    ),
  )
  let extractor = dingbat_font.text_extractor()
  let text = text_extractor_encoding_bytes_for_test([
    0x5B, 0x5C, 0x5D, 0x5E, 0x5F, 0x60, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67,
    0x68, 0x69, 0x6A, 0x6B,
  ])
  @test.assert_eq(try! extractor.codepoints_of_text(text), [
    0x273B, 0x273C, 0x273D, 0x273E, 0x273F, 0x2740, 0x2741, 0x2742, 0x2743, 0x2744,
    0x2745, 0x2746, 0x2747, 0x2748, 0x2749, 0x274A, 0x274B,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(text), [
    text_extractor_encoding_name_for_test("/a54"),
    text_extractor_encoding_name_for_test("/a55"),
    text_extractor_encoding_name_for_test("/a56"),
    text_extractor_encoding_name_for_test("/a57"),
    text_extractor_encoding_name_for_test("/a58"),
    text_extractor_encoding_name_for_test("/a59"),
    text_extractor_encoding_name_for_test("/a60"),
    text_extractor_encoding_name_for_test("/a61"),
    text_extractor_encoding_name_for_test("/a62"),
    text_extractor_encoding_name_for_test("/a63"),
    text_extractor_encoding_name_for_test("/a64"),
    text_extractor_encoding_name_for_test("/a65"),
    text_extractor_encoding_name_for_test("/a66"),
    text_extractor_encoding_name_for_test("/a67"),
    text_extractor_encoding_name_for_test("/a68"),
    text_extractor_encoding_name_for_test("/a69"),
    text_extractor_encoding_name_for_test("/a70"),
  ])
  @test.assert_eq(extractor.charcode_of_codepoint(0x273B), Some(0x5B))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2744), Some(0x64))
  @test.assert_eq(extractor.charcode_of_codepoint(0x274B), Some(0x6B))
}

///|
test "PdfTextExtractor extracts implicit ZapfDingbats geometric glyphs" {
  let dingbat_font : @pdflite.PdfFont = PdfFontStandard(
    text_extractor_encoding_standard_font_data_for_test(
      PdfZapfDingbats,
      PdfImplicitInFontFile,
    ),
  )
  let extractor = dingbat_font.text_extractor()
  let text = text_extractor_encoding_bytes_for_test([
    0x6C, 0x6D, 0x6E, 0x6F, 0x70, 0x71, 0x72, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78,
    0x79, 0x7A, 0x7B, 0x7C, 0x7D, 0x7E,
  ])
  @test.assert_eq(try! extractor.codepoints_of_text(text), [
    0x25CF, 0x274D, 0x25A0, 0x274F, 0x2750, 0x2751, 0x2752, 0x25B2, 0x25BC, 0x25C6,
    0x2756, 0x25D7, 0x2758, 0x2759, 0x275A, 0x275B, 0x275C, 0x275D, 0x275E,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(text), [
    text_extractor_encoding_name_for_test("/a71"),
    text_extractor_encoding_name_for_test("/a72"),
    text_extractor_encoding_name_for_test("/a73"),
    text_extractor_encoding_name_for_test("/a74"),
    text_extractor_encoding_name_for_test("/a203"),
    text_extractor_encoding_name_for_test("/a75"),
    text_extractor_encoding_name_for_test("/a204"),
    text_extractor_encoding_name_for_test("/a76"),
    text_extractor_encoding_name_for_test("/a77"),
    text_extractor_encoding_name_for_test("/a78"),
    text_extractor_encoding_name_for_test("/a79"),
    text_extractor_encoding_name_for_test("/a81"),
    text_extractor_encoding_name_for_test("/a82"),
    text_extractor_encoding_name_for_test("/a83"),
    text_extractor_encoding_name_for_test("/a84"),
    text_extractor_encoding_name_for_test("/a97"),
    text_extractor_encoding_name_for_test("/a98"),
    text_extractor_encoding_name_for_test("/a99"),
    text_extractor_encoding_name_for_test("/a100"),
  ])
  @test.assert_eq(extractor.charcode_of_codepoint(0x25CF), Some(0x6C))
  @test.assert_eq(extractor.charcode_of_codepoint(0x25B2), Some(0x73))
  @test.assert_eq(extractor.charcode_of_codepoint(0x275E), Some(0x7E))
}

///|
test "PdfTextExtractor extracts implicit ZapfDingbats card suit glyphs" {
  let dingbat_font : @pdflite.PdfFont = PdfFontStandard(
    text_extractor_encoding_standard_font_data_for_test(
      PdfZapfDingbats,
      PdfImplicitInFontFile,
    ),
  )
  let extractor = dingbat_font.text_extractor()
  let text = text_extractor_encoding_bytes_for_test([
    0xA6, 0xA7, 0xA8, 0xA9, 0xAA, 0xAB,
  ])
  @test.assert_eq(try! extractor.codepoints_of_text(text), [
    0x2766, 0x2767, 0x2663, 0x2666, 0x2665, 0x2660,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(text), [
    text_extractor_encoding_name_for_test("/a107"),
    text_extractor_encoding_name_for_test("/a108"),
    text_extractor_encoding_name_for_test("/a112"),
    text_extractor_encoding_name_for_test("/a111"),
    text_extractor_encoding_name_for_test("/a110"),
    text_extractor_encoding_name_for_test("/a109"),
  ])
  @test.assert_eq(extractor.charcode_of_codepoint(0x2766), Some(0xA6))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2663), Some(0xA8))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2660), Some(0xAB))
}

///|
test "PdfTextExtractor extracts implicit ZapfDingbats circled digits" {
  let dingbat_font : @pdflite.PdfFont = PdfFontStandard(
    text_extractor_encoding_standard_font_data_for_test(
      PdfZapfDingbats,
      PdfImplicitInFontFile,
    ),
  )
  let extractor = dingbat_font.text_extractor()
  let text = text_extractor_encoding_bytes_for_test([
    0xAC, 0xAD, 0xAE, 0xAF, 0xB0, 0xB1, 0xB2, 0xB3, 0xB4, 0xB5,
  ])
  @test.assert_eq(try! extractor.codepoints_of_text(text), [
    0x2460, 0x2461, 0x2462, 0x2463, 0x2464, 0x2465, 0x2466, 0x2467, 0x2468, 0x2469,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(text), [
    text_extractor_encoding_name_for_test("/a120"),
    text_extractor_encoding_name_for_test("/a121"),
    text_extractor_encoding_name_for_test("/a122"),
    text_extractor_encoding_name_for_test("/a123"),
    text_extractor_encoding_name_for_test("/a124"),
    text_extractor_encoding_name_for_test("/a125"),
    text_extractor_encoding_name_for_test("/a126"),
    text_extractor_encoding_name_for_test("/a127"),
    text_extractor_encoding_name_for_test("/a128"),
    text_extractor_encoding_name_for_test("/a129"),
  ])
  @test.assert_eq(extractor.charcode_of_codepoint(0x2460), Some(0xAC))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2465), Some(0xB1))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2469), Some(0xB5))
}

///|
test "PdfTextExtractor extracts implicit ZapfDingbats filled circled digits" {
  let dingbat_font : @pdflite.PdfFont = PdfFontStandard(
    text_extractor_encoding_standard_font_data_for_test(
      PdfZapfDingbats,
      PdfImplicitInFontFile,
    ),
  )
  let extractor = dingbat_font.text_extractor()
  let text = text_extractor_encoding_bytes_for_test([
    0xB6, 0xB7, 0xB8, 0xB9, 0xBA, 0xBB, 0xBC, 0xBD, 0xBE, 0xBF,
  ])
  @test.assert_eq(try! extractor.codepoints_of_text(text), [
    0x2776, 0x2777, 0x2778, 0x2779, 0x277A, 0x277B, 0x277C, 0x277D, 0x277E, 0x277F,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(text), [
    text_extractor_encoding_name_for_test("/a130"),
    text_extractor_encoding_name_for_test("/a131"),
    text_extractor_encoding_name_for_test("/a132"),
    text_extractor_encoding_name_for_test("/a133"),
    text_extractor_encoding_name_for_test("/a134"),
    text_extractor_encoding_name_for_test("/a135"),
    text_extractor_encoding_name_for_test("/a136"),
    text_extractor_encoding_name_for_test("/a137"),
    text_extractor_encoding_name_for_test("/a138"),
    text_extractor_encoding_name_for_test("/a139"),
  ])
  @test.assert_eq(extractor.charcode_of_codepoint(0x2776), Some(0xB6))
  @test.assert_eq(extractor.charcode_of_codepoint(0x277B), Some(0xBB))
  @test.assert_eq(extractor.charcode_of_codepoint(0x277F), Some(0xBF))
}

///|
test "PdfTextExtractor extracts implicit ZapfDingbats circled sans-serif digits" {
  let dingbat_font : @pdflite.PdfFont = PdfFontStandard(
    text_extractor_encoding_standard_font_data_for_test(
      PdfZapfDingbats,
      PdfImplicitInFontFile,
    ),
  )
  let extractor = dingbat_font.text_extractor()
  let text = text_extractor_encoding_bytes_for_test([
    0xC0, 0xC1, 0xC2, 0xC3, 0xC4, 0xC5, 0xC6, 0xC7, 0xC8, 0xC9,
  ])
  @test.assert_eq(try! extractor.codepoints_of_text(text), [
    0x2780, 0x2781, 0x2782, 0x2783, 0x2784, 0x2785, 0x2786, 0x2787, 0x2788, 0x2789,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(text), [
    text_extractor_encoding_name_for_test("/a140"),
    text_extractor_encoding_name_for_test("/a141"),
    text_extractor_encoding_name_for_test("/a142"),
    text_extractor_encoding_name_for_test("/a143"),
    text_extractor_encoding_name_for_test("/a144"),
    text_extractor_encoding_name_for_test("/a145"),
    text_extractor_encoding_name_for_test("/a146"),
    text_extractor_encoding_name_for_test("/a147"),
    text_extractor_encoding_name_for_test("/a148"),
    text_extractor_encoding_name_for_test("/a149"),
  ])
  @test.assert_eq(extractor.charcode_of_codepoint(0x2780), Some(0xC0))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2785), Some(0xC5))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2789), Some(0xC9))
}

///|
test "PdfTextExtractor extracts implicit ZapfDingbats negative circled sans-serif digits" {
  let dingbat_font : @pdflite.PdfFont = PdfFontStandard(
    text_extractor_encoding_standard_font_data_for_test(
      PdfZapfDingbats,
      PdfImplicitInFontFile,
    ),
  )
  let extractor = dingbat_font.text_extractor()
  let text = text_extractor_encoding_bytes_for_test([
    0xCA, 0xCB, 0xCC, 0xCD, 0xCE, 0xCF, 0xD0, 0xD1, 0xD2, 0xD3,
  ])
  @test.assert_eq(try! extractor.codepoints_of_text(text), [
    0x278A, 0x278B, 0x278C, 0x278D, 0x278E, 0x278F, 0x2790, 0x2791, 0x2792, 0x2793,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(text), [
    text_extractor_encoding_name_for_test("/a150"),
    text_extractor_encoding_name_for_test("/a151"),
    text_extractor_encoding_name_for_test("/a152"),
    text_extractor_encoding_name_for_test("/a153"),
    text_extractor_encoding_name_for_test("/a154"),
    text_extractor_encoding_name_for_test("/a155"),
    text_extractor_encoding_name_for_test("/a156"),
    text_extractor_encoding_name_for_test("/a157"),
    text_extractor_encoding_name_for_test("/a158"),
    text_extractor_encoding_name_for_test("/a159"),
  ])
  @test.assert_eq(extractor.charcode_of_codepoint(0x278A), Some(0xCA))
  @test.assert_eq(extractor.charcode_of_codepoint(0x278F), Some(0xCF))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2793), Some(0xD3))
}

///|
test "PdfTextExtractor extracts implicit ZapfDingbats high-byte arrow glyphs" {
  let dingbat_font : @pdflite.PdfFont = PdfFontStandard(
    text_extractor_encoding_standard_font_data_for_test(
      PdfZapfDingbats,
      PdfImplicitInFontFile,
    ),
  )
  let extractor = dingbat_font.text_extractor()
  let text = text_extractor_encoding_bytes_for_test([
    0xD4, 0xD5, 0xD6, 0xD7, 0xD8, 0xD9, 0xDA, 0xDB, 0xDC, 0xDD, 0xDE, 0xDF,
  ])
  @test.assert_eq(try! extractor.codepoints_of_text(text), [
    0x2794, 0x2192, 0x2194, 0x2195, 0x2798, 0x2799, 0x279A, 0x279B, 0x279C, 0x279D,
    0x279E, 0x279F,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(text), [
    text_extractor_encoding_name_for_test("/a160"),
    text_extractor_encoding_name_for_test("/a161"),
    text_extractor_encoding_name_for_test("/a163"),
    text_extractor_encoding_name_for_test("/a164"),
    text_extractor_encoding_name_for_test("/a196"),
    text_extractor_encoding_name_for_test("/a165"),
    text_extractor_encoding_name_for_test("/a192"),
    text_extractor_encoding_name_for_test("/a166"),
    text_extractor_encoding_name_for_test("/a167"),
    text_extractor_encoding_name_for_test("/a168"),
    text_extractor_encoding_name_for_test("/a169"),
    text_extractor_encoding_name_for_test("/a170"),
  ])
  @test.assert_eq(extractor.charcode_of_codepoint(0x2794), Some(0xD4))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2195), Some(0xD7))
  @test.assert_eq(extractor.charcode_of_codepoint(0x279F), Some(0xDF))
}

///|
test "PdfTextExtractor extracts implicit ZapfDingbats extended arrow glyphs" {
  let dingbat_font : @pdflite.PdfFont = PdfFontStandard(
    text_extractor_encoding_standard_font_data_for_test(
      PdfZapfDingbats,
      PdfImplicitInFontFile,
    ),
  )
  let extractor = dingbat_font.text_extractor()
  let text = text_extractor_encoding_bytes_for_test([
    0xE0, 0xE1, 0xE2, 0xE3, 0xE4, 0xE5, 0xE6, 0xE7, 0xE8, 0xE9, 0xEA, 0xEB, 0xEC,
    0xED, 0xEE, 0xEF,
  ])
  @test.assert_eq(try! extractor.codepoints_of_text(text), [
    0x27A0, 0x27A1, 0x27A2, 0x27A3, 0x27A4, 0x27A5, 0x27A6, 0x27A7, 0x27A8, 0x27A9,
    0x27AA, 0x27AB, 0x27AC, 0x27AD, 0x27AE, 0x27AF,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(text), [
    text_extractor_encoding_name_for_test("/a171"),
    text_extractor_encoding_name_for_test("/a172"),
    text_extractor_encoding_name_for_test("/a173"),
    text_extractor_encoding_name_for_test("/a162"),
    text_extractor_encoding_name_for_test("/a174"),
    text_extractor_encoding_name_for_test("/a175"),
    text_extractor_encoding_name_for_test("/a176"),
    text_extractor_encoding_name_for_test("/a177"),
    text_extractor_encoding_name_for_test("/a178"),
    text_extractor_encoding_name_for_test("/a179"),
    text_extractor_encoding_name_for_test("/a193"),
    text_extractor_encoding_name_for_test("/a180"),
    text_extractor_encoding_name_for_test("/a199"),
    text_extractor_encoding_name_for_test("/a181"),
    text_extractor_encoding_name_for_test("/a200"),
    text_extractor_encoding_name_for_test("/a182"),
  ])
  @test.assert_eq(extractor.charcode_of_codepoint(0x27A0), Some(0xE0))
  @test.assert_eq(extractor.charcode_of_codepoint(0x27A8), Some(0xE8))
  @test.assert_eq(extractor.charcode_of_codepoint(0x27AF), Some(0xEF))
}

///|
test "PdfTextExtractor extracts implicit ZapfDingbats final arrow glyphs" {
  let dingbat_font : @pdflite.PdfFont = PdfFontStandard(
    text_extractor_encoding_standard_font_data_for_test(
      PdfZapfDingbats,
      PdfImplicitInFontFile,
    ),
  )
  let extractor = dingbat_font.text_extractor()
  let text = text_extractor_encoding_bytes_for_test([
    0xF1, 0xF2, 0xF3, 0xF4, 0xF5, 0xF6, 0xF7, 0xF8, 0xF9, 0xFA, 0xFB, 0xFC, 0xFD,
    0xFE,
  ])
  @test.assert_eq(try! extractor.codepoints_of_text(text), [
    0x27B1, 0x27B2, 0x27B3, 0x27B4, 0x27B5, 0x27B6, 0x27B7, 0x27B8, 0x27B9, 0x27BA,
    0x27BB, 0x27BC, 0x27BD, 0x27BE,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(text), [
    text_extractor_encoding_name_for_test("/a201"),
    text_extractor_encoding_name_for_test("/a183"),
    text_extractor_encoding_name_for_test("/a184"),
    text_extractor_encoding_name_for_test("/a197"),
    text_extractor_encoding_name_for_test("/a185"),
    text_extractor_encoding_name_for_test("/a194"),
    text_extractor_encoding_name_for_test("/a198"),
    text_extractor_encoding_name_for_test("/a186"),
    text_extractor_encoding_name_for_test("/a195"),
    text_extractor_encoding_name_for_test("/a187"),
    text_extractor_encoding_name_for_test("/a188"),
    text_extractor_encoding_name_for_test("/a189"),
    text_extractor_encoding_name_for_test("/a190"),
    text_extractor_encoding_name_for_test("/a191"),
  ])
  @test.assert_eq(
    try! extractor.glyphnames_of_text(
      text_extractor_encoding_bytes_for_test([0xF0]),
    ),
    [text_extractor_encoding_name_for_test(".notdef")],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x27B0), None)
  @test.assert_eq(extractor.charcode_of_codepoint(0x27B1), Some(0xF1))
  @test.assert_eq(extractor.charcode_of_codepoint(0x27B8), Some(0xF8))
  @test.assert_eq(extractor.charcode_of_codepoint(0x27BE), Some(0xFE))
}

///|
test "PdfTextExtractor extracts custom ZapfDingbats bracket glyph names" {
  let dingbat_font : @pdflite.PdfFont = PdfFontStandard(
    text_extractor_encoding_standard_font_data_for_test(
      PdfZapfDingbats,
      PdfCustomEncoding(PdfStandardEncoding, [
        text_extractor_encoding_difference_for_test("/a89", 65),
        text_extractor_encoding_difference_for_test("/a90", 66),
        text_extractor_encoding_difference_for_test("/a93", 67),
        text_extractor_encoding_difference_for_test("/a94", 68),
        text_extractor_encoding_difference_for_test("/a91", 69),
        text_extractor_encoding_difference_for_test("/a92", 70),
        text_extractor_encoding_difference_for_test("/a205", 71),
        text_extractor_encoding_difference_for_test("/a85", 72),
        text_extractor_encoding_difference_for_test("/a206", 73),
        text_extractor_encoding_difference_for_test("/a86", 74),
        text_extractor_encoding_difference_for_test("/a87", 75),
        text_extractor_encoding_difference_for_test("/a88", 76),
        text_extractor_encoding_difference_for_test("/a95", 77),
        text_extractor_encoding_difference_for_test("/a96", 78),
      ]),
    ),
  )
  let extractor = dingbat_font.text_extractor()
  let text = text_extractor_encoding_bytes_for_test([
    65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78,
  ])
  @test.assert_eq(try! extractor.codepoints_of_text(text), [
    0x2768, 0x2769, 0x276A, 0x276B, 0x276C, 0x276D, 0x276E, 0x276F, 0x2770, 0x2771,
    0x2772, 0x2773, 0x2774, 0x2775,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(text), [
    text_extractor_encoding_name_for_test("/a89"),
    text_extractor_encoding_name_for_test("/a90"),
    text_extractor_encoding_name_for_test("/a93"),
    text_extractor_encoding_name_for_test("/a94"),
    text_extractor_encoding_name_for_test("/a91"),
    text_extractor_encoding_name_for_test("/a92"),
    text_extractor_encoding_name_for_test("/a205"),
    text_extractor_encoding_name_for_test("/a85"),
    text_extractor_encoding_name_for_test("/a206"),
    text_extractor_encoding_name_for_test("/a86"),
    text_extractor_encoding_name_for_test("/a87"),
    text_extractor_encoding_name_for_test("/a88"),
    text_extractor_encoding_name_for_test("/a95"),
    text_extractor_encoding_name_for_test("/a96"),
  ])
  @test.assert_eq(extractor.charcode_of_codepoint(0x2768), Some(65))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2770), Some(73))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2775), Some(78))
}

///|
test "PdfTextExtractor uses custom encoding differences before base encoding" {
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_extractor_encoding_standard_font_data_for_test(
      PdfHelvetica,
      PdfCustomEncoding(PdfStandardEncoding, [
        text_extractor_encoding_difference_for_test("/Euro", 65),
        text_extractor_encoding_difference_for_test("/A.alt", 66),
        text_extractor_encoding_difference_for_test("/uni20AC", 67),
        text_extractor_encoding_difference_for_test("/u00A9", 68),
        text_extractor_encoding_difference_for_test("/uni00410042", 69),
        text_extractor_encoding_difference_for_test("/Delta", 71),
        text_extractor_encoding_difference_for_test("/Omega", 72),
      ]),
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(
      text_extractor_encoding_bytes_for_test([65, 66, 67, 68, 69, 70, 71, 72]),
    ),
    [0x20AC, 65, 0x20AC, 0x00A9, 65, 66, 70, 0x2206, 0x2126],
  )
  @test.assert_eq(
    try! extractor.glyphnames_of_text(
      text_extractor_encoding_bytes_for_test([65, 66, 67, 68, 69, 70, 71, 72]),
    ),
    [
      text_extractor_encoding_name_for_test("/Euro"),
      text_extractor_encoding_name_for_test("/A.alt"),
      text_extractor_encoding_name_for_test("/uni20AC"),
      text_extractor_encoding_name_for_test("/u00A9"),
      text_extractor_encoding_name_for_test("/uni00410042"),
      text_extractor_encoding_name_for_test("/F"),
      text_extractor_encoding_name_for_test("/Delta"),
      text_extractor_encoding_name_for_test("/Omega"),
    ],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x20AC), Some(65))
  @test.assert_eq(extractor.charcode_of_codepoint(65), Some(66))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00A9), Some(68))
  @test.assert_eq(extractor.charcode_of_codepoint(66), None)
  @test.assert_eq(extractor.charcode_of_codepoint(70), Some(70))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2206), Some(71))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2126), Some(72))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0394), None)
  @test.assert_eq(extractor.charcode_of_codepoint(0x03A9), None)
}
