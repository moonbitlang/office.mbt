///|
test "PdfTextExtractor decodes Hebrew AFII core AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/afii57645", 0x05BE),
    ("/afii57658", 0x05C3),
    ("/afii57664", 0x05D0),
    ("/afii57665", 0x05D1),
    ("/afii57666", 0x05D2),
    ("/afii57667", 0x05D3),
    ("/afii57668", 0x05D4),
    ("/afii57669", 0x05D5),
    ("/afii57670", 0x05D6),
    ("/afii57671", 0x05D7),
    ("/afii57672", 0x05D8),
    ("/afii57673", 0x05D9),
    ("/afii57674", 0x05DA),
    ("/afii57675", 0x05DB),
    ("/afii57676", 0x05DC),
    ("/afii57677", 0x05DD),
    ("/afii57678", 0x05DE),
    ("/afii57679", 0x05DF),
    ("/afii57680", 0x05E0),
    ("/afii57681", 0x05E1),
    ("/afii57682", 0x05E2),
    ("/afii57683", 0x05E3),
    ("/afii57684", 0x05E4),
    ("/afii57685", 0x05E5),
    ("/afii57686", 0x05E6),
    ("/afii57687", 0x05E7),
    ("/afii57688", 0x05E8),
    ("/afii57689", 0x05E9),
    ("/afii57690", 0x05EA),
    ("/afii57716", 0x05F0),
    ("/afii57717", 0x05F1),
    ("/afii57718", 0x05F2),
    ("/afii57793", 0x05B4),
    ("/afii57794", 0x05B5),
    ("/afii57795", 0x05B6),
    ("/afii57796", 0x05BB),
    ("/afii57797", 0x05B8),
    ("/afii57798", 0x05B7),
    ("/afii57799", 0x05B0),
    ("/afii57800", 0x05B2),
    ("/afii57801", 0x05B1),
    ("/afii57802", 0x05B3),
    ("/afii57803", 0x05C2),
    ("/afii57804", 0x05C1),
    ("/afii57806", 0x05B9),
    ("/afii57807", 0x05BC),
    ("/afii57839", 0x05BD),
    ("/afii57841", 0x05BF),
    ("/afii57842", 0x05C0),
  ]
  let differences : Array[@pdflite.PdfEncodingDifference] = []
  let text_codes : Array[Int] = []
  let expected_codepoints : Array[Int] = []
  for index in 0..<entries.length() {
    let entry = entries[index]
    let code = index + 1
    differences.push(text_difference_for_test(entry.0, code))
    text_codes.push(code)
    expected_codepoints.push(entry.1)
  }
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(
      PdfHelvetica,
      PdfCustomEncoding(PdfStandardEncoding, differences),
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(text_bytes_for_test(text_codes)[:]),
    expected_codepoints,
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x05BE), Some(1))
  @test.assert_eq(extractor.charcode_of_codepoint(0x05D0), Some(3))
  @test.assert_eq(extractor.charcode_of_codepoint(0x05EA), Some(29))
  @test.assert_eq(extractor.charcode_of_codepoint(0x05F2), Some(32))
  @test.assert_eq(extractor.charcode_of_codepoint(0x05B0), Some(39))
  @test.assert_eq(extractor.charcode_of_codepoint(0x05C0), Some(49))
}
