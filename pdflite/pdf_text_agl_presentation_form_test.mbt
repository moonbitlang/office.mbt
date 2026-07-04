///|
test "PdfTextExtractor decodes presentation-form AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/anglebracketleftvertical", 0xFE3F),
    ("/anglebracketrightvertical", 0xFE40),
    ("/asterisksmall", 0xFE61),
    ("/atsmall", 0xFE6B),
    ("/blacklenticularbracketleftvertical", 0xFE3B),
    ("/blacklenticularbracketrightvertical", 0xFE3C),
    ("/braceleftsmall", 0xFE5B),
    ("/braceleftvertical", 0xFE37),
    ("/bracerightsmall", 0xFE5C),
    ("/bracerightvertical", 0xFE38),
    ("/colonsmall", 0xFE55),
    ("/commasmall", 0xFE50),
    ("/cornerbracketleftvertical", 0xFE41),
    ("/cornerbracketrightvertical", 0xFE42),
    ("/dblanglebracketleftvertical", 0xFE3D),
    ("/dblanglebracketrightvertical", 0xFE3E),
    ("/dollarsmall", 0xFE69),
    ("/emdashvertical", 0xFE31),
    ("/endashvertical", 0xFE32),
    ("/equalsmall", 0xFE66),
    ("/greatersmall", 0xFE65),
    ("/hyphensmall", 0xFE63),
    ("/lesssmall", 0xFE64),
    ("/lowlinecenterline", 0xFE4E),
    ("/lowlinedashed", 0xFE4D),
    ("/numbersignsmall", 0xFE5F),
    ("/overlinecenterline", 0xFE4A),
    ("/overlinedashed", 0xFE49),
    ("/overlinedblwavy", 0xFE4C),
    ("/overlinewavy", 0xFE4B),
    ("/parenleftsmall", 0xFE59),
    ("/parenleftvertical", 0xFE35),
    ("/parenrightsmall", 0xFE5A),
    ("/parenrightvertical", 0xFE36),
    ("/percentsmall", 0xFE6A),
    ("/periodsmall", 0xFE52),
    ("/plussmall", 0xFE62),
    ("/semicolonsmall", 0xFE54),
    ("/tortoiseshellbracketleftsmall", 0xFE5D),
    ("/tortoiseshellbracketleftvertical", 0xFE39),
    ("/tortoiseshellbracketrightsmall", 0xFE5E),
    ("/tortoiseshellbracketrightvertical", 0xFE3A),
    ("/twodotleadervertical", 0xFE30),
    ("/underscorevertical", 0xFE33),
    ("/underscorewavy", 0xFE4F),
    ("/wavyunderscorevertical", 0xFE34),
    ("/whitecornerbracketleftvertical", 0xFE43),
    ("/whitecornerbracketrightvertical", 0xFE44),
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
    try! extractor.codepoints_of_text(text_bytes_for_test(text_codes)),
    expected_codepoints,
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0xFE3F), Some(1))
  @test.assert_eq(extractor.charcode_of_codepoint(0xFE66), Some(20))
  @test.assert_eq(extractor.charcode_of_codepoint(0xFE59), Some(31))
  @test.assert_eq(extractor.charcode_of_codepoint(0xFE30), Some(43))
  @test.assert_eq(extractor.charcode_of_codepoint(0xFE44), Some(48))
}
