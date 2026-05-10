///|
test "PdfTextExtractor decodes Gurmukhi AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/aagurmukhi", 0x0A06),
    ("/aamatragurmukhi", 0x0A3E),
    ("/addakgurmukhi", 0x0A71),
    ("/agurmukhi", 0x0A05),
    ("/aigurmukhi", 0x0A10),
    ("/aimatragurmukhi", 0x0A48),
    ("/augurmukhi", 0x0A14),
    ("/aumatragurmukhi", 0x0A4C),
    ("/bagurmukhi", 0x0A2C),
    ("/bhagurmukhi", 0x0A2D),
    ("/bindigurmukhi", 0x0A02),
    ("/cagurmukhi", 0x0A1A),
    ("/chagurmukhi", 0x0A1B),
    ("/dagurmukhi", 0x0A26),
    ("/ddagurmukhi", 0x0A21),
    ("/ddhagurmukhi", 0x0A22),
    ("/dhagurmukhi", 0x0A27),
    ("/eegurmukhi", 0x0A0F),
    ("/eematragurmukhi", 0x0A47),
    ("/eightgurmukhi", 0x0A6E),
    ("/ekonkargurmukhi", 0x0A74),
    ("/fagurmukhi", 0x0A5E),
    ("/fivegurmukhi", 0x0A6B),
    ("/fourgurmukhi", 0x0A6A),
    ("/gagurmukhi", 0x0A17),
    ("/ghagurmukhi", 0x0A18),
    ("/ghhagurmukhi", 0x0A5A),
    ("/hagurmukhi", 0x0A39),
    ("/halantgurmukhi", 0x0A4D),
    ("/igurmukhi", 0x0A07),
    ("/iigurmukhi", 0x0A08),
    ("/iimatragurmukhi", 0x0A40),
    ("/imatragurmukhi", 0x0A3F),
    ("/irigurmukhi", 0x0A72),
    ("/jagurmukhi", 0x0A1C),
    ("/jhagurmukhi", 0x0A1D),
    ("/kagurmukhi", 0x0A15),
    ("/khagurmukhi", 0x0A16),
    ("/khhagurmukhi", 0x0A59),
    ("/lagurmukhi", 0x0A32),
    ("/magurmukhi", 0x0A2E),
    ("/nagurmukhi", 0x0A28),
    ("/ngagurmukhi", 0x0A19),
    ("/ninegurmukhi", 0x0A6F),
    ("/nnagurmukhi", 0x0A23),
    ("/nuktagurmukhi", 0x0A3C),
    ("/nyagurmukhi", 0x0A1E),
    ("/onegurmukhi", 0x0A67),
    ("/oogurmukhi", 0x0A13),
    ("/oomatragurmukhi", 0x0A4B),
    ("/pagurmukhi", 0x0A2A),
    ("/phagurmukhi", 0x0A2B),
    ("/ragurmukhi", 0x0A30),
    ("/rragurmukhi", 0x0A5C),
    ("/sagurmukhi", 0x0A38),
    ("/sevengurmukhi", 0x0A6D),
    ("/shagurmukhi", 0x0A36),
    ("/sixgurmukhi", 0x0A6C),
    ("/tagurmukhi", 0x0A24),
    ("/thagurmukhi", 0x0A25),
    ("/threegurmukhi", 0x0A69),
    ("/tippigurmukhi", 0x0A70),
    ("/ttagurmukhi", 0x0A1F),
    ("/tthagurmukhi", 0x0A20),
    ("/twogurmukhi", 0x0A68),
    ("/ugurmukhi", 0x0A09),
    ("/umatragurmukhi", 0x0A41),
    ("/uragurmukhi", 0x0A73),
    ("/uugurmukhi", 0x0A0A),
    ("/uumatragurmukhi", 0x0A42),
    ("/vagurmukhi", 0x0A35),
    ("/yagurmukhi", 0x0A2F),
    ("/zagurmukhi", 0x0A5B),
    ("/zerogurmukhi", 0x0A66),
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
  @test.assert_eq(extractor.charcode_of_codepoint(0x0A06), Some(1))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0A6E), Some(20))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0A32), Some(40))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0A25), Some(60))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0A66), Some(74))
}
