///|
test "PdfTextExtractor decodes Gujarati AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/aagujarati", 0x0A86),
    ("/aavowelsigngujarati", 0x0ABE),
    ("/agujarati", 0x0A85),
    ("/aigujarati", 0x0A90),
    ("/aivowelsigngujarati", 0x0AC8),
    ("/anusvaragujarati", 0x0A82),
    ("/augujarati", 0x0A94),
    ("/auvowelsigngujarati", 0x0ACC),
    ("/bagujarati", 0x0AAC),
    ("/bhagujarati", 0x0AAD),
    ("/cagujarati", 0x0A9A),
    ("/candrabindugujarati", 0x0A81),
    ("/chagujarati", 0x0A9B),
    ("/dagujarati", 0x0AA6),
    ("/ddagujarati", 0x0AA1),
    ("/ddhagujarati", 0x0AA2),
    ("/dhagujarati", 0x0AA7),
    ("/ecandragujarati", 0x0A8D),
    ("/ecandravowelsigngujarati", 0x0AC5),
    ("/egujarati", 0x0A8F),
    ("/eightgujarati", 0x0AEE),
    ("/evowelsigngujarati", 0x0AC7),
    ("/fivegujarati", 0x0AEB),
    ("/fourgujarati", 0x0AEA),
    ("/gagujarati", 0x0A97),
    ("/ghagujarati", 0x0A98),
    ("/hagujarati", 0x0AB9),
    ("/igujarati", 0x0A87),
    ("/iigujarati", 0x0A88),
    ("/iivowelsigngujarati", 0x0AC0),
    ("/ivowelsigngujarati", 0x0ABF),
    ("/jagujarati", 0x0A9C),
    ("/jhagujarati", 0x0A9D),
    ("/kagujarati", 0x0A95),
    ("/khagujarati", 0x0A96),
    ("/lagujarati", 0x0AB2),
    ("/llagujarati", 0x0AB3),
    ("/magujarati", 0x0AAE),
    ("/nagujarati", 0x0AA8),
    ("/ngagujarati", 0x0A99),
    ("/ninegujarati", 0x0AEF),
    ("/nnagujarati", 0x0AA3),
    ("/nuktagujarati", 0x0ABC),
    ("/nyagujarati", 0x0A9E),
    ("/ocandragujarati", 0x0A91),
    ("/ocandravowelsigngujarati", 0x0AC9),
    ("/ogujarati", 0x0A93),
    ("/omgujarati", 0x0AD0),
    ("/onegujarati", 0x0AE7),
    ("/ovowelsigngujarati", 0x0ACB),
    ("/pagujarati", 0x0AAA),
    ("/phagujarati", 0x0AAB),
    ("/ragujarati", 0x0AB0),
    ("/rrvocalicgujarati", 0x0AE0),
    ("/rrvocalicvowelsigngujarati", 0x0AC4),
    ("/rvocalicgujarati", 0x0A8B),
    ("/rvocalicvowelsigngujarati", 0x0AC3),
    ("/sagujarati", 0x0AB8),
    ("/sevengujarati", 0x0AED),
    ("/shagujarati", 0x0AB6),
    ("/sixgujarati", 0x0AEC),
    ("/ssagujarati", 0x0AB7),
    ("/tagujarati", 0x0AA4),
    ("/thagujarati", 0x0AA5),
    ("/threegujarati", 0x0AE9),
    ("/ttagujarati", 0x0A9F),
    ("/tthagujarati", 0x0AA0),
    ("/twogujarati", 0x0AE8),
    ("/ugujarati", 0x0A89),
    ("/uugujarati", 0x0A8A),
    ("/uuvowelsigngujarati", 0x0AC2),
    ("/uvowelsigngujarati", 0x0AC1),
    ("/vagujarati", 0x0AB5),
    ("/viramagujarati", 0x0ACD),
    ("/visargagujarati", 0x0A83),
    ("/yagujarati", 0x0AAF),
    ("/zerogujarati", 0x0AE6),
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
  @test.assert_eq(extractor.charcode_of_codepoint(0x0A86), Some(1))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0A8F), Some(20))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0AEF), Some(41))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0AB6), Some(60))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0AE6), Some(77))
}
