///|
test "PdfTextExtractor decodes Cyrillic AFII AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/afii10017", 0x0410),
    ("/afii10018", 0x0411),
    ("/afii10019", 0x0412),
    ("/afii10020", 0x0413),
    ("/afii10021", 0x0414),
    ("/afii10022", 0x0415),
    ("/afii10023", 0x0401),
    ("/afii10024", 0x0416),
    ("/afii10025", 0x0417),
    ("/afii10026", 0x0418),
    ("/afii10027", 0x0419),
    ("/afii10028", 0x041A),
    ("/afii10029", 0x041B),
    ("/afii10030", 0x041C),
    ("/afii10031", 0x041D),
    ("/afii10032", 0x041E),
    ("/afii10033", 0x041F),
    ("/afii10034", 0x0420),
    ("/afii10035", 0x0421),
    ("/afii10036", 0x0422),
    ("/afii10037", 0x0423),
    ("/afii10038", 0x0424),
    ("/afii10039", 0x0425),
    ("/afii10040", 0x0426),
    ("/afii10041", 0x0427),
    ("/afii10042", 0x0428),
    ("/afii10043", 0x0429),
    ("/afii10044", 0x042A),
    ("/afii10045", 0x042B),
    ("/afii10046", 0x042C),
    ("/afii10047", 0x042D),
    ("/afii10048", 0x042E),
    ("/afii10049", 0x042F),
    ("/afii10050", 0x0490),
    ("/afii10051", 0x0402),
    ("/afii10052", 0x0403),
    ("/afii10053", 0x0404),
    ("/afii10054", 0x0405),
    ("/afii10055", 0x0406),
    ("/afii10056", 0x0407),
    ("/afii10057", 0x0408),
    ("/afii10058", 0x0409),
    ("/afii10059", 0x040A),
    ("/afii10060", 0x040B),
    ("/afii10061", 0x040C),
    ("/afii10062", 0x040E),
    ("/afii10065", 0x0430),
    ("/afii10066", 0x0431),
    ("/afii10067", 0x0432),
    ("/afii10068", 0x0433),
    ("/afii10069", 0x0434),
    ("/afii10070", 0x0435),
    ("/afii10071", 0x0451),
    ("/afii10072", 0x0436),
    ("/afii10073", 0x0437),
    ("/afii10074", 0x0438),
    ("/afii10075", 0x0439),
    ("/afii10076", 0x043A),
    ("/afii10077", 0x043B),
    ("/afii10078", 0x043C),
    ("/afii10079", 0x043D),
    ("/afii10080", 0x043E),
    ("/afii10081", 0x043F),
    ("/afii10082", 0x0440),
    ("/afii10083", 0x0441),
    ("/afii10084", 0x0442),
    ("/afii10085", 0x0443),
    ("/afii10086", 0x0444),
    ("/afii10087", 0x0445),
    ("/afii10088", 0x0446),
    ("/afii10089", 0x0447),
    ("/afii10090", 0x0448),
    ("/afii10091", 0x0449),
    ("/afii10092", 0x044A),
    ("/afii10093", 0x044B),
    ("/afii10094", 0x044C),
    ("/afii10095", 0x044D),
    ("/afii10096", 0x044E),
    ("/afii10097", 0x044F),
    ("/afii10098", 0x0491),
    ("/afii10099", 0x0452),
    ("/afii10100", 0x0453),
    ("/afii10101", 0x0454),
    ("/afii10102", 0x0455),
    ("/afii10103", 0x0456),
    ("/afii10104", 0x0457),
    ("/afii10105", 0x0458),
    ("/afii10106", 0x0459),
    ("/afii10107", 0x045A),
    ("/afii10108", 0x045B),
    ("/afii10109", 0x045C),
    ("/afii10110", 0x045E),
    ("/afii10145", 0x040F),
    ("/afii10146", 0x0462),
    ("/afii10147", 0x0472),
    ("/afii10148", 0x0474),
    ("/afii10193", 0x045F),
    ("/afii10194", 0x0463),
    ("/afii10195", 0x0473),
    ("/afii10196", 0x0475),
    ("/afii10846", 0x04D9),
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
  @test.assert_eq(extractor.charcode_of_codepoint(0x0410), Some(1))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0411), Some(2))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0433), Some(50))
  @test.assert_eq(extractor.charcode_of_codepoint(0x044B), Some(75))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0475), Some(100))
  @test.assert_eq(extractor.charcode_of_codepoint(0x04D9), Some(101))
}
