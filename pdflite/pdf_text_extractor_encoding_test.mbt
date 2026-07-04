///|
fn text_extractor_encoding_name_for_test(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn text_extractor_encoding_bytes_for_test(
  values : ArrayView[Int],
) -> @core.PdfBytes {
  try! @core.pdf_bytes_of_int_array(values)
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
