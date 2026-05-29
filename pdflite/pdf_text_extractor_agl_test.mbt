///|
fn text_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn text_bytes_for_test(values : ArrayView[Int]) -> @pdflite.PdfBytes {
  try! @pdflite.pdf_bytes_of_int_array(values)
}

///|
fn text_difference_for_test(
  name : String,
  code : Int,
) -> @pdflite.PdfEncodingDifference {
  { name: text_name_for_test(name), code }
}

///|
fn text_standard_font_data_for_test(
  font : @pdflite.PdfStandardFont,
  encoding : @pdflite.PdfEncoding,
) -> @pdflite.PdfStandardFontData {
  { font, encoding }
}

///|
test "PdfTextExtractor decodes Basic Latin AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/A", 65),
    ("/B", 66),
    ("/C", 67),
    ("/D", 68),
    ("/E", 69),
    ("/F", 70),
    ("/G", 71),
    ("/H", 72),
    ("/I", 73),
    ("/J", 74),
    ("/K", 75),
    ("/L", 76),
    ("/M", 77),
    ("/N", 78),
    ("/O", 79),
    ("/P", 80),
    ("/Q", 81),
    ("/R", 82),
    ("/S", 83),
    ("/T", 84),
    ("/U", 85),
    ("/V", 86),
    ("/W", 87),
    ("/X", 88),
    ("/Y", 89),
    ("/Z", 90),
    ("/a", 97),
    ("/b", 98),
    ("/c", 99),
    ("/controlACK", 6),
    ("/controlBEL", 7),
    ("/controlBS", 8),
    ("/controlCAN", 24),
    ("/controlDC1", 17),
    ("/controlDC2", 18),
    ("/controlDC3", 19),
    ("/controlDC4", 20),
    ("/controlDEL", 127),
    ("/controlDLE", 16),
    ("/controlEM", 25),
    ("/controlENQ", 5),
    ("/controlEOT", 4),
    ("/controlESC", 27),
    ("/controlETB", 23),
    ("/controlETX", 3),
    ("/controlFS", 28),
    ("/controlGS", 29),
    ("/controlNAK", 21),
    ("/controlRS", 30),
    ("/controlSI", 15),
    ("/controlSO", 14),
    ("/controlSOT", 2),
    ("/controlSTX", 1),
    ("/controlSUB", 26),
    ("/controlSYN", 22),
    ("/controlUS", 31),
    ("/controlVT", 11),
    ("/d", 100),
    ("/e", 101),
    ("/f", 102),
    ("/g", 103),
    ("/h", 104),
    ("/i", 105),
    ("/j", 106),
    ("/k", 107),
    ("/l", 108),
    ("/m", 109),
    ("/n", 110),
    ("/o", 111),
    ("/p", 112),
    ("/q", 113),
    ("/r", 114),
    ("/s", 115),
    ("/spacehackarabic", 32),
    ("/t", 116),
    ("/u", 117),
    ("/v", 118),
    ("/verticalbar", 124),
    ("/w", 119),
    ("/x", 120),
    ("/y", 121),
    ("/z", 122),
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
  @test.assert_eq(extractor.charcode_of_codepoint(65), Some(1))
  @test.assert_eq(extractor.charcode_of_codepoint(90), Some(26))
  @test.assert_eq(extractor.charcode_of_codepoint(6), Some(30))
  @test.assert_eq(extractor.charcode_of_codepoint(127), Some(38))
  @test.assert_eq(extractor.charcode_of_codepoint(32), Some(74))
  @test.assert_eq(extractor.charcode_of_codepoint(124), Some(78))
  @test.assert_eq(extractor.charcode_of_codepoint(122), Some(82))
}

///|
test "PdfTextExtractor decodes general punctuation AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/afii00208", 0x2015),
    ("/afii299", 0x200E),
    ("/afii300", 0x200F),
    ("/afii301", 0x200D),
    ("/afii61573", 0x202C),
    ("/afii61574", 0x202D),
    ("/afii61575", 0x202E),
    ("/afii61664", 0x200C),
    ("/asterism", 0x2042),
    ("/dbllowline", 0x2017),
    ("/dblverticalbar", 0x2016),
    ("/enspace", 0x2002),
    ("/exclamdbl", 0x203C),
    ("/horizontalbar", 0x2015),
    ("/hyphentwo", 0x2010),
    ("/overline", 0x203E),
    ("/primereversed", 0x2035),
    ("/quoteleftreversed", 0x201B),
    ("/quotereversed", 0x201B),
    ("/referencemark", 0x203B),
    ("/twodotleader", 0x2025),
    ("/underscoredbl", 0x2017),
    ("/zerowidthnonjoiner", 0x200C),
    ("/zerowidthspace", 0x200B),
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
  @test.assert_eq(extractor.charcode_of_codepoint(0x2015), Some(1))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2017), Some(10))
  @test.assert_eq(extractor.charcode_of_codepoint(0x200C), Some(8))
  @test.assert_eq(extractor.charcode_of_codepoint(0x200B), Some(24))
}

///|
test "PdfTextExtractor decodes Latin-1 spacing AGL aliases" {
  let entries : Array[(String, Int)] = [
    ("/blank", 0x2423),
    ("/equalsuperior", 0x207C),
    ("/middot", 0x00B7),
    ("/mu1", 0x00B5),
    ("/nbspace", 0x00A0),
    ("/nonbreakingspace", 0x00A0),
    ("/overscore", 0x00AF),
    ("/plussuperior", 0x207A),
    ("/sfthyphen", 0x00AD),
    ("/softhyphen", 0x00AD),
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
  @test.assert_eq(extractor.charcode_of_codepoint(0x2423), Some(1))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00B7), Some(3))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00A0), Some(5))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00AD), Some(9))
}

///|
test "PdfTextExtractor decodes IPA extension AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/Gsmallhook", 0x029B),
    ("/Rsmallinverted", 0x0281),
    ("/ascript", 0x0251),
    ("/ascriptturned", 0x0252),
    ("/aturned", 0x0250),
    ("/bhook", 0x0253),
    ("/bilabialclick", 0x0298),
    ("/ccurl", 0x0255),
    ("/cstretched", 0x0297),
    ("/dezh", 0x02A4),
    ("/dhook", 0x0257),
    ("/dotlessjstrokehook", 0x0284),
    ("/dtail", 0x0256),
    ("/dzaltone", 0x02A3),
    ("/dzcurl", 0x02A5),
    ("/eopen", 0x025B),
    ("/eopenclosed", 0x029A),
    ("/eopenreversed", 0x025C),
    ("/eopenreversedclosed", 0x025E),
    ("/eopenreversedhook", 0x025D),
    ("/ereversed", 0x0258),
    ("/esh", 0x0283),
    ("/eshcurl", 0x0286),
    ("/eshsquatreversed", 0x0285),
    ("/ezh", 0x0292),
    ("/ezhcurl", 0x0293),
    ("/gammalatinsmall", 0x0263),
    ("/ghook", 0x0260),
    ("/glottalstop", 0x0294),
    ("/glottalstopinverted", 0x0296),
    ("/glottalstopreversed", 0x0295),
    ("/glottalstopstroke", 0x02A1),
    ("/glottalstopstrokereversed", 0x02A2),
    ("/gscript", 0x0261),
    ("/henghook", 0x0267),
    ("/hhook", 0x0266),
    ("/hturned", 0x0265),
    ("/iotalatin", 0x0269),
    ("/istroke", 0x0268),
    ("/jcrossedtail", 0x029D),
    ("/jdotlessstroke", 0x025F),
    ("/kturned", 0x029E),
    ("/lbelt", 0x026C),
    ("/lezh", 0x026E),
    ("/lhookretroflex", 0x026D),
    ("/lmiddletilde", 0x026B),
    ("/mhook", 0x0271),
    ("/mlonglegturned", 0x0270),
    ("/mturned", 0x026F),
    ("/nhookleft", 0x0272),
    ("/nhookretroflex", 0x0273),
    ("/obarred", 0x0275),
    ("/omegalatinclosed", 0x0277),
    ("/oopen", 0x0254),
    ("/philatin", 0x0278),
    ("/qhook", 0x02A0),
    ("/ramshorn", 0x0264),
    ("/rfishhook", 0x027E),
    ("/rfishhookreversed", 0x027F),
    ("/rhook", 0x027D),
    ("/rhookturned", 0x027B),
    ("/rlongleg", 0x027C),
    ("/rlonglegturned", 0x027A),
    ("/rturned", 0x0279),
    ("/schwa", 0x0259),
    ("/schwahook", 0x025A),
    ("/shook", 0x0282),
    ("/tccurl", 0x02A8),
    ("/tesh", 0x02A7),
    ("/tretroflexhook", 0x0288),
    ("/ts", 0x02A6),
    ("/tturned", 0x0287),
    ("/ubar", 0x0289),
    ("/upsilonlatin", 0x028A),
    ("/vhook", 0x028B),
    ("/vturned", 0x028C),
    ("/wturned", 0x028D),
    ("/yturned", 0x028E),
    ("/zcurl", 0x0291),
    ("/zretroflexhook", 0x0290),
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
  @test.assert_eq(extractor.charcode_of_codepoint(0x029B), Some(1))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0251), Some(3))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0294), Some(29))
  @test.assert_eq(extractor.charcode_of_codepoint(0x02A1), Some(32))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0279), Some(64))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0290), Some(80))
}

///|
test "PdfTextExtractor decodes spacing modifier AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/Rsmallinvertedsuperior", 0x02B6),
    ("/acutelowmod", 0x02CF),
    ("/afii57929", 0x02BC),
    ("/afii64937", 0x02BD),
    ("/apostrophemod", 0x02BC),
    ("/arrowheaddownmod", 0x02C5),
    ("/arrowheadleftmod", 0x02C2),
    ("/arrowheadrightmod", 0x02C3),
    ("/arrowheadupmod", 0x02C4),
    ("/colontriangularhalfmod", 0x02D1),
    ("/colontriangularmod", 0x02D0),
    ("/commareversedmod", 0x02BD),
    ("/commaturnedmod", 0x02BB),
    ("/dblprimemod", 0x02BA),
    ("/downtackmod", 0x02D5),
    ("/firsttonechinese", 0x02C9),
    ("/fourthtonechinese", 0x02CB),
    ("/gammasuperior", 0x02E0),
    ("/glottalstopmod", 0x02C0),
    ("/glottalstopreversedmod", 0x02C1),
    ("/glottalstopreversedsuperior", 0x02E4),
    ("/gravelowmod", 0x02CE),
    ("/hhooksuperior", 0x02B1),
    ("/hsuperior", 0x02B0),
    ("/ilde", 0x02DC),
    ("/jsuperior", 0x02B2),
    ("/macronlowmod", 0x02CD),
    ("/minusmod", 0x02D7),
    ("/plusmod", 0x02D6),
    ("/primemod", 0x02B9),
    ("/rhookturnedsuperior", 0x02B5),
    ("/rhotichookmod", 0x02DE),
    ("/ringhalfleft", 0x02BF),
    ("/ringhalfleftcentered", 0x02D3),
    ("/ringhalfright", 0x02BE),
    ("/ringhalfrightcentered", 0x02D2),
    ("/rturnedsuperior", 0x02B4),
    ("/secondtonechinese", 0x02CA),
    ("/tonebarextrahighmod", 0x02E5),
    ("/tonebarextralowmod", 0x02E9),
    ("/tonebarhighmod", 0x02E6),
    ("/tonebarlowmod", 0x02E8),
    ("/tonebarmidmod", 0x02E7),
    ("/uptackmod", 0x02D4),
    ("/verticallinelowmod", 0x02CC),
    ("/verticallinemod", 0x02C8),
    ("/wsuperior", 0x02B7),
    ("/xsuperior", 0x02E3),
    ("/ysuperior", 0x02B8),
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
  @test.assert_eq(extractor.charcode_of_codepoint(0x02B0), Some(24))
  @test.assert_eq(extractor.charcode_of_codepoint(0x02BC), Some(3))
  @test.assert_eq(extractor.charcode_of_codepoint(0x02BD), Some(4))
  @test.assert_eq(extractor.charcode_of_codepoint(0x02DC), Some(25))
  @test.assert_eq(extractor.charcode_of_codepoint(0x02E9), Some(40))
  @test.assert_eq(extractor.charcode_of_codepoint(0x02B8), Some(49))
}

///|
test "PdfTextExtractor decodes combining mark AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/acutebelowcmb", 0x0317),
    ("/acutecmb", 0x0301),
    ("/acutecomb", 0x0301),
    ("/acutetonecmb", 0x0341),
    ("/brevebelowcmb", 0x032E),
    ("/brevecmb", 0x0306),
    ("/breveinvertedbelowcmb", 0x032F),
    ("/breveinvertedcmb", 0x0311),
    ("/breveinverteddoublecmb", 0x0361),
    ("/bridgebelowcmb", 0x032A),
    ("/bridgeinvertedbelowcmb", 0x033A),
    ("/candrabinducmb", 0x0310),
    ("/caronbelowcmb", 0x032C),
    ("/caroncmb", 0x030C),
    ("/cedillacmb", 0x0327),
    ("/circumflexbelowcmb", 0x032D),
    ("/circumflexcmb", 0x0302),
    ("/commaabovecmb", 0x0313),
    ("/commaaboverightcmb", 0x0315),
    ("/commareversedabovecmb", 0x0314),
    ("/commaturnedabovecmb", 0x0312),
    ("/dblarchinvertedbelowcmb", 0x032B),
    ("/dblgravecmb", 0x030F),
    ("/dbllowlinecmb", 0x0333),
    ("/dbloverlinecmb", 0x033F),
    ("/dblverticallineabovecmb", 0x030E),
    ("/dialytikatonoscmb", 0x0344),
    ("/dieresisbelowcmb", 0x0324),
    ("/dieresiscmb", 0x0308),
    ("/dotaccentcmb", 0x0307),
    ("/dotbelowcmb", 0x0323),
    ("/dotbelowcomb", 0x0323),
    ("/downtackbelowcmb", 0x031E),
    ("/gravebelowcmb", 0x0316),
    ("/gravecmb", 0x0300),
    ("/gravecomb", 0x0300),
    ("/gravetonecmb", 0x0340),
    ("/hookabovecomb", 0x0309),
    ("/hookcmb", 0x0309),
    ("/hookpalatalizedbelowcmb", 0x0321),
    ("/hookretroflexbelowcmb", 0x0322),
    ("/horncmb", 0x031B),
    ("/hungarumlautcmb", 0x030B),
    ("/koroniscmb", 0x0343),
    ("/leftangleabovecmb", 0x031A),
    ("/lefttackbelowcmb", 0x0318),
    ("/lowlinecmb", 0x0332),
    ("/macronbelowcmb", 0x0331),
    ("/macroncmb", 0x0304),
    ("/minusbelowcmb", 0x0320),
    ("/ogonekcmb", 0x0328),
    ("/overlinecmb", 0x0305),
    ("/perispomenigreekcmb", 0x0342),
    ("/plusbelowcmb", 0x031F),
    ("/righttackbelowcmb", 0x0319),
    ("/ringbelowcmb", 0x0325),
    ("/ringcmb", 0x030A),
    ("/ringhalfleftbelowcmb", 0x031C),
    ("/ringhalfrightbelowcmb", 0x0339),
    ("/seagullbelowcmb", 0x033C),
    ("/soliduslongoverlaycmb", 0x0338),
    ("/solidusshortoverlaycmb", 0x0337),
    ("/squarebelowcmb", 0x033B),
    ("/strokelongoverlaycmb", 0x0336),
    ("/strokeshortoverlaycmb", 0x0335),
    ("/tildebelowcmb", 0x0330),
    ("/tildecmb", 0x0303),
    ("/tildecomb", 0x0303),
    ("/tildedoublecmb", 0x0360),
    ("/tildeoverlaycmb", 0x0334),
    ("/tildeverticalcmb", 0x033E),
    ("/uptackbelowcmb", 0x031D),
    ("/verticallineabovecmb", 0x030D),
    ("/verticallinebelowcmb", 0x0329),
    ("/xabovecmb", 0x033D),
    ("/ypogegrammenigreekcmb", 0x0345),
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
  @test.assert_eq(extractor.charcode_of_codepoint(0x0301), Some(2))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0323), Some(31))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0300), Some(35))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0309), Some(38))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0303), Some(67))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0345), Some(76))
}

///|
test "PdfTextExtractor decodes currency and letterlike AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/afii08941", 0x20A4),
    ("/afii57636", 0x20AA),
    ("/colonsign", 0x20A1),
    ("/cruzeiro", 0x20A2),
    ("/dong", 0x20AB),
    ("/euro", 0x20AC),
    ("/franc", 0x20A3),
    ("/lira", 0x20A4),
    ("/newsheqelsign", 0x20AA),
    ("/peseta", 0x20A7),
    ("/sheqel", 0x20AA),
    ("/sheqelhebrew", 0x20AA),
    ("/won", 0x20A9),
    ("/Ohm", 0x2126),
    ("/afii61248", 0x2105),
    ("/afii61289", 0x2113),
    ("/afii61352", 0x2116),
    ("/angstrom", 0x212B),
    ("/careof", 0x2105),
    ("/centigrade", 0x2103),
    ("/estimated", 0x212E),
    ("/fahrenheit", 0x2109),
    ("/lsquare", 0x2113),
    ("/numero", 0x2116),
    ("/prescription", 0x211E),
    ("/telephone", 0x2121),
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
  @test.assert_eq(extractor.charcode_of_codepoint(0x20A4), Some(1))
  @test.assert_eq(extractor.charcode_of_codepoint(0x20AA), Some(2))
  @test.assert_eq(extractor.charcode_of_codepoint(0x20AC), Some(6))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2105), Some(15))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2113), Some(16))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2116), Some(17))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2121), Some(26))
}

///|
test "PdfTextExtractor decodes arrow AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/arrowdashdown", 0x21E3),
    ("/arrowdashleft", 0x21E0),
    ("/arrowdashright", 0x21E2),
    ("/arrowdashup", 0x21E1),
    ("/arrowdownleft", 0x2199),
    ("/arrowdownright", 0x2198),
    ("/arrowdownwhite", 0x21E9),
    ("/arrowleftdbl", 0x21D0),
    ("/arrowleftdblstroke", 0x21CD),
    ("/arrowleftoverright", 0x21C6),
    ("/arrowleftwhite", 0x21E6),
    ("/arrowrightdblstroke", 0x21CF),
    ("/arrowrightoverleft", 0x21C4),
    ("/arrowrightwhite", 0x21E8),
    ("/arrowtableft", 0x21E4),
    ("/arrowtabright", 0x21E5),
    ("/arrowupdn", 0x2195),
    ("/arrowupdnbse", 0x21A8),
    ("/arrowupdownbase", 0x21A8),
    ("/arrowupleft", 0x2196),
    ("/arrowupleftofdown", 0x21C5),
    ("/arrowupright", 0x2197),
    ("/arrowupwhite", 0x21E7),
    ("/capslock", 0x21EA),
    ("/dblarrowleft", 0x21D4),
    ("/dblarrowright", 0x21D2),
    ("/harpoonleftbarbup", 0x21BC),
    ("/harpoonrightbarbup", 0x21C0),
    ("/pagedown", 0x21DF),
    ("/pageup", 0x21DE),
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
  @test.assert_eq(extractor.charcode_of_codepoint(0x21D0), Some(8))
  @test.assert_eq(extractor.charcode_of_codepoint(0x21A8), Some(18))
  @test.assert_eq(extractor.charcode_of_codepoint(0x21D4), Some(25))
  @test.assert_eq(extractor.charcode_of_codepoint(0x21DE), Some(30))
}

///|
test "PdfTextExtractor decodes Greek AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/Alphatonos", 0x0386),
    ("/Deicoptic", 0x03EE),
    ("/Deltagreek", 0x0394),
    ("/Digammagreek", 0x03DC),
    ("/Epsilontonos", 0x0388),
    ("/Etatonos", 0x0389),
    ("/Feicoptic", 0x03E4),
    ("/Gangiacoptic", 0x03EA),
    ("/Horicoptic", 0x03E8),
    ("/Iotadieresis", 0x03AA),
    ("/Iotatonos", 0x038A),
    ("/Kheicoptic", 0x03E6),
    ("/Koppagreek", 0x03DE),
    ("/Omegagreek", 0x03A9),
    ("/Omegatonos", 0x038F),
    ("/Omicrontonos", 0x038C),
    ("/Sampigreek", 0x03E0),
    ("/Sheicoptic", 0x03E2),
    ("/Shimacoptic", 0x03EC),
    ("/Stigmagreek", 0x03DA),
    ("/Upsilonacutehooksymbolgreek", 0x03D3),
    ("/Upsilondieresis", 0x03AB),
    ("/Upsilondieresishooksymbolgreek", 0x03D4),
    ("/Upsilonhooksymbol", 0x03D2),
    ("/Upsilontonos", 0x038E),
    ("/alphatonos", 0x03AC),
    ("/anoteleia", 0x0387),
    ("/betasymbolgreek", 0x03D0),
    ("/deicoptic", 0x03EF),
    ("/dialytikatonos", 0x0385),
    ("/dieresistonos", 0x0385),
    ("/epsilontonos", 0x03AD),
    ("/etatonos", 0x03AE),
    ("/feicoptic", 0x03E5),
    ("/gangiacoptic", 0x03EB),
    ("/horicoptic", 0x03E9),
    ("/iotadieresis", 0x03CA),
    ("/iotadieresistonos", 0x0390),
    ("/iotatonos", 0x03AF),
    ("/kappasymbolgreek", 0x03F0),
    ("/kheicoptic", 0x03E7),
    ("/mugreek", 0x03BC),
    ("/numeralsigngreek", 0x0374),
    ("/numeralsignlowergreek", 0x0375),
    ("/omegatonos", 0x03CE),
    ("/omicrontonos", 0x03CC),
    ("/phisymbolgreek", 0x03D5),
    ("/pisymbolgreek", 0x03D6),
    ("/questiongreek", 0x037E),
    ("/rhosymbolgreek", 0x03F1),
    ("/sheicoptic", 0x03E3),
    ("/shimacoptic", 0x03ED),
    ("/sigmafinal", 0x03C2),
    ("/sigmalunatesymbolgreek", 0x03F2),
    ("/thetasymbolgreek", 0x03D1),
    ("/tonos", 0x0384),
    ("/upsilondieresis", 0x03CB),
    ("/upsilondieresistonos", 0x03B0),
    ("/upsilontonos", 0x03CD),
    ("/yotgreek", 0x03F3),
    ("/ypogegrammeni", 0x037A),
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
  @test.assert_eq(extractor.charcode_of_codepoint(0x0394), Some(3))
  @test.assert_eq(extractor.charcode_of_codepoint(0x03A9), Some(14))
  @test.assert_eq(extractor.charcode_of_codepoint(0x03D2), Some(24))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0385), Some(30))
  @test.assert_eq(extractor.charcode_of_codepoint(0x03BC), Some(42))
  @test.assert_eq(extractor.charcode_of_codepoint(0x037A), Some(61))
}

///|
test "PdfTextExtractor decodes Armenian AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/Aybarmenian", 0x0531),
    ("/Benarmenian", 0x0532),
    ("/Caarmenian", 0x053E),
    ("/Chaarmenian", 0x0549),
    ("/Cheharmenian", 0x0543),
    ("/Coarmenian", 0x0551),
    ("/Daarmenian", 0x0534),
    ("/Echarmenian", 0x0535),
    ("/Eharmenian", 0x0537),
    ("/Etarmenian", 0x0538),
    ("/Feharmenian", 0x0556),
    ("/Ghadarmenian", 0x0542),
    ("/Gimarmenian", 0x0533),
    ("/Hoarmenian", 0x0540),
    ("/Iniarmenian", 0x053B),
    ("/Jaarmenian", 0x0541),
    ("/Jheharmenian", 0x054B),
    ("/Keharmenian", 0x0554),
    ("/Kenarmenian", 0x053F),
    ("/Liwnarmenian", 0x053C),
    ("/Menarmenian", 0x0544),
    ("/Nowarmenian", 0x0546),
    ("/Oharmenian", 0x0555),
    ("/Peharmenian", 0x054A),
    ("/Piwrarmenian", 0x0553),
    ("/Raarmenian", 0x054C),
    ("/Reharmenian", 0x0550),
    ("/Seharmenian", 0x054D),
    ("/Shaarmenian", 0x0547),
    ("/Tiwnarmenian", 0x054F),
    ("/Toarmenian", 0x0539),
    ("/Vewarmenian", 0x054E),
    ("/Voarmenian", 0x0548),
    ("/Xeharmenian", 0x053D),
    ("/Yiarmenian", 0x0545),
    ("/Yiwnarmenian", 0x0552),
    ("/Zaarmenian", 0x0536),
    ("/Zhearmenian", 0x053A),
    ("/abbreviationmarkarmenian", 0x055F),
    ("/apostrophearmenian", 0x055A),
    ("/aybarmenian", 0x0561),
    ("/benarmenian", 0x0562),
    ("/caarmenian", 0x056E),
    ("/chaarmenian", 0x0579),
    ("/cheharmenian", 0x0573),
    ("/coarmenian", 0x0581),
    ("/commaarmenian", 0x055D),
    ("/daarmenian", 0x0564),
    ("/echarmenian", 0x0565),
    ("/echyiwnarmenian", 0x0587),
    ("/eharmenian", 0x0567),
    ("/emphasismarkarmenian", 0x055B),
    ("/etarmenian", 0x0568),
    ("/exclamarmenian", 0x055C),
    ("/feharmenian", 0x0586),
    ("/ghadarmenian", 0x0572),
    ("/gimarmenian", 0x0563),
    ("/hoarmenian", 0x0570),
    ("/iniarmenian", 0x056B),
    ("/jaarmenian", 0x0571),
    ("/jheharmenian", 0x057B),
    ("/keharmenian", 0x0584),
    ("/kenarmenian", 0x056F),
    ("/liwnarmenian", 0x056C),
    ("/menarmenian", 0x0574),
    ("/nowarmenian", 0x0576),
    ("/oharmenian", 0x0585),
    ("/peharmenian", 0x057A),
    ("/periodarmenian", 0x0589),
    ("/piwrarmenian", 0x0583),
    ("/questionarmenian", 0x055E),
    ("/raarmenian", 0x057C),
    ("/reharmenian", 0x0580),
    ("/ringhalfleftarmenian", 0x0559),
    ("/seharmenian", 0x057D),
    ("/shaarmenian", 0x0577),
    ("/tiwnarmenian", 0x057F),
    ("/toarmenian", 0x0569),
    ("/vewarmenian", 0x057E),
    ("/voarmenian", 0x0578),
    ("/xeharmenian", 0x056D),
    ("/yiarmenian", 0x0575),
    ("/yiwnarmenian", 0x0582),
    ("/zaarmenian", 0x0566),
    ("/zhearmenian", 0x056A),
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
  @test.assert_eq(extractor.charcode_of_codepoint(0x0531), Some(1))
  @test.assert_eq(extractor.charcode_of_codepoint(0x055A), Some(40))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0587), Some(50))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0589), Some(69))
  @test.assert_eq(extractor.charcode_of_codepoint(0x056A), Some(85))
}

///|
test "PdfTextExtractor decodes Devanagari AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/aadeva", 0x0906),
    ("/aavowelsigndeva", 0x093E),
    ("/abbreviationsigndeva", 0x0970),
    ("/acutedeva", 0x0954),
    ("/adeva", 0x0905),
    ("/aideva", 0x0910),
    ("/aivowelsigndeva", 0x0948),
    ("/anudattadeva", 0x0952),
    ("/anusvaradeva", 0x0902),
    ("/audeva", 0x0914),
    ("/auvowelsigndeva", 0x094C),
    ("/avagrahadeva", 0x093D),
    ("/badeva", 0x092C),
    ("/bhadeva", 0x092D),
    ("/cadeva", 0x091A),
    ("/candrabindudeva", 0x0901),
    ("/chadeva", 0x091B),
    ("/dadeva", 0x0926),
    ("/danda", 0x0964),
    ("/dbldanda", 0x0965),
    ("/ddadeva", 0x0921),
    ("/dddhadeva", 0x095C),
    ("/ddhadeva", 0x0922),
    ("/dhadeva", 0x0927),
    ("/ecandradeva", 0x090D),
    ("/ecandravowelsigndeva", 0x0945),
    ("/edeva", 0x090F),
    ("/eightdeva", 0x096E),
    ("/eshortdeva", 0x090E),
    ("/eshortvowelsigndeva", 0x0946),
    ("/evowelsigndeva", 0x0947),
    ("/fadeva", 0x095E),
    ("/fivedeva", 0x096B),
    ("/fourdeva", 0x096A),
    ("/gadeva", 0x0917),
    ("/ghadeva", 0x0918),
    ("/ghhadeva", 0x095A),
    ("/gravedeva", 0x0953),
    ("/hadeva", 0x0939),
    ("/ideva", 0x0907),
    ("/iideva", 0x0908),
    ("/iivowelsigndeva", 0x0940),
    ("/ivowelsigndeva", 0x093F),
    ("/jadeva", 0x091C),
    ("/jhadeva", 0x091D),
    ("/kadeva", 0x0915),
    ("/khadeva", 0x0916),
    ("/khhadeva", 0x0959),
    ("/ladeva", 0x0932),
    ("/lladeva", 0x0933),
    ("/llladeva", 0x0934),
    ("/llvocalicdeva", 0x0961),
    ("/llvocalicvowelsigndeva", 0x0963),
    ("/lvocalicdeva", 0x090C),
    ("/lvocalicvowelsigndeva", 0x0962),
    ("/madeva", 0x092E),
    ("/nadeva", 0x0928),
    ("/ngadeva", 0x0919),
    ("/ninedeva", 0x096F),
    ("/nnadeva", 0x0923),
    ("/nnnadeva", 0x0929),
    ("/nuktadeva", 0x093C),
    ("/nyadeva", 0x091E),
    ("/ocandradeva", 0x0911),
    ("/ocandravowelsigndeva", 0x0949),
    ("/odeva", 0x0913),
    ("/omdeva", 0x0950),
    ("/onedeva", 0x0967),
    ("/oshortdeva", 0x0912),
    ("/oshortvowelsigndeva", 0x094A),
    ("/ovowelsigndeva", 0x094B),
    ("/padeva", 0x092A),
    ("/phadeva", 0x092B),
    ("/qadeva", 0x0958),
    ("/radeva", 0x0930),
    ("/rhadeva", 0x095D),
    ("/rradeva", 0x0931),
    ("/rrvocalicdeva", 0x0960),
    ("/rrvocalicvowelsigndeva", 0x0944),
    ("/rvocalicdeva", 0x090B),
    ("/rvocalicvowelsigndeva", 0x0943),
    ("/sadeva", 0x0938),
    ("/sevendeva", 0x096D),
    ("/shadeva", 0x0936),
    ("/sixdeva", 0x096C),
    ("/ssadeva", 0x0937),
    ("/tadeva", 0x0924),
    ("/thadeva", 0x0925),
    ("/threedeva", 0x0969),
    ("/ttadeva", 0x091F),
    ("/tthadeva", 0x0920),
    ("/twodeva", 0x0968),
    ("/udattadeva", 0x0951),
    ("/udeva", 0x0909),
    ("/uudeva", 0x090A),
    ("/uuvowelsigndeva", 0x0942),
    ("/uvowelsigndeva", 0x0941),
    ("/vadeva", 0x0935),
    ("/viramadeva", 0x094D),
    ("/visargadeva", 0x0903),
    ("/yadeva", 0x092F),
    ("/yyadeva", 0x095F),
    ("/zadeva", 0x095B),
    ("/zerodeva", 0x0966),
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
  @test.assert_eq(extractor.charcode_of_codepoint(0x0906), Some(1))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0970), Some(3))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0964), Some(19))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0950), Some(67))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0966), Some(104))
}

///|
test "PdfTextExtractor decodes Thai AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/angkhankhuthai", 0x0E5A),
    ("/bahtthai", 0x0E3F),
    ("/bobaimaithai", 0x0E1A),
    ("/chochangthai", 0x0E0A),
    ("/chochanthai", 0x0E08),
    ("/chochingthai", 0x0E09),
    ("/chochoethai", 0x0E0C),
    ("/dochadathai", 0x0E0E),
    ("/dodekthai", 0x0E14),
    ("/eightthai", 0x0E58),
    ("/fivethai", 0x0E55),
    ("/fofanthai", 0x0E1F),
    ("/fofathai", 0x0E1D),
    ("/fongmanthai", 0x0E4F),
    ("/fourthai", 0x0E54),
    ("/hohipthai", 0x0E2B),
    ("/honokhukthai", 0x0E2E),
    ("/khokhaithai", 0x0E02),
    ("/khokhonthai", 0x0E05),
    ("/khokhuatthai", 0x0E03),
    ("/khokhwaithai", 0x0E04),
    ("/khomutthai", 0x0E5B),
    ("/khorakhangthai", 0x0E06),
    ("/kokaithai", 0x0E01),
    ("/lakkhangyaothai", 0x0E45),
    ("/lochulathai", 0x0E2C),
    ("/lolingthai", 0x0E25),
    ("/luthai", 0x0E26),
    ("/maichattawathai", 0x0E4B),
    ("/maiekthai", 0x0E48),
    ("/maihanakatthai", 0x0E31),
    ("/maitaikhuthai", 0x0E47),
    ("/maithothai", 0x0E49),
    ("/maitrithai", 0x0E4A),
    ("/maiyamokthai", 0x0E46),
    ("/momathai", 0x0E21),
    ("/ngonguthai", 0x0E07),
    ("/nikhahitthai", 0x0E4D),
    ("/ninethai", 0x0E59),
    ("/nonenthai", 0x0E13),
    ("/nonuthai", 0x0E19),
    ("/oangthai", 0x0E2D),
    ("/onethai", 0x0E51),
    ("/paiyannoithai", 0x0E2F),
    ("/phinthuthai", 0x0E3A),
    ("/phophanthai", 0x0E1E),
    ("/phophungthai", 0x0E1C),
    ("/phosamphaothai", 0x0E20),
    ("/poplathai", 0x0E1B),
    ("/roruathai", 0x0E23),
    ("/ruthai", 0x0E24),
    ("/saraaathai", 0x0E32),
    ("/saraaethai", 0x0E41),
    ("/saraaimaimalaithai", 0x0E44),
    ("/saraaimaimuanthai", 0x0E43),
    ("/saraamthai", 0x0E33),
    ("/saraathai", 0x0E30),
    ("/saraethai", 0x0E40),
    ("/saraiithai", 0x0E35),
    ("/saraithai", 0x0E34),
    ("/saraothai", 0x0E42),
    ("/saraueethai", 0x0E37),
    ("/sarauethai", 0x0E36),
    ("/sarauthai", 0x0E38),
    ("/sarauuthai", 0x0E39),
    ("/seventhai", 0x0E57),
    ("/sixthai", 0x0E56),
    ("/sorusithai", 0x0E29),
    ("/sosalathai", 0x0E28),
    ("/sosothai", 0x0E0B),
    ("/sosuathai", 0x0E2A),
    ("/thanthakhatthai", 0x0E4C),
    ("/thonangmonthothai", 0x0E11),
    ("/thophuthaothai", 0x0E12),
    ("/thothahanthai", 0x0E17),
    ("/thothanthai", 0x0E10),
    ("/thothongthai", 0x0E18),
    ("/thothungthai", 0x0E16),
    ("/threethai", 0x0E53),
    ("/topatakthai", 0x0E0F),
    ("/totaothai", 0x0E15),
    ("/twothai", 0x0E52),
    ("/wowaenthai", 0x0E27),
    ("/yamakkanthai", 0x0E4E),
    ("/yoyakthai", 0x0E22),
    ("/yoyingthai", 0x0E0D),
    ("/zerothai", 0x0E50),
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
  @test.assert_eq(extractor.charcode_of_codepoint(0x0E5A), Some(1))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0E01), Some(24))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0E40), Some(58))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0E50), Some(87))
}

///|
test "PdfTextExtractor decodes math operator AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/allequal", 0x224C),
    ("/approaches", 0x2250),
    ("/approxequalorimage", 0x2252),
    ("/approximatelyequal", 0x2245),
    ("/asteriskmath", 0x2217),
    ("/asymptoticallyequal", 0x2243),
    ("/because", 0x2235),
    ("/bulletoperator", 0x2219),
    ("/circleot", 0x2299),
    ("/contourintegral", 0x222E),
    ("/curlyand", 0x22CF),
    ("/curlyor", 0x22CE),
    ("/dblintegral", 0x222C),
    ("/divides", 0x2223),
    ("/divisionslash", 0x2215),
    ("/ellipsisvertical", 0x22EE),
    ("/forall", 0x2200),
    ("/geometricallyequal", 0x2251),
    ("/greaterequalorless", 0x22DB),
    ("/greaterorequivalent", 0x2273),
    ("/greaterorless", 0x2277),
    ("/greateroverequal", 0x2267),
    ("/imageorapproximatelyequal", 0x2253),
    ("/increment", 0x2206),
    ("/lessequalorgreater", 0x22DA),
    ("/lessorequivalent", 0x2272),
    ("/lessorgreater", 0x2276),
    ("/lessoverequal", 0x2266),
    ("/minus", 0x2212),
    ("/minuscircle", 0x2296),
    ("/minusplus", 0x2213),
    ("/muchgreater", 0x226B),
    ("/muchless", 0x226A),
    ("/nabla", 0x2207),
    ("/notcontains", 0x220C),
    ("/notelementof", 0x2209),
    ("/notgreater", 0x226F),
    ("/notgreaternorequal", 0x2271),
    ("/notgreaternorless", 0x2279),
    ("/notidentical", 0x2262),
    ("/notless", 0x226E),
    ("/notlessnorequal", 0x2270),
    ("/notparallel", 0x2226),
    ("/notprecedes", 0x2280),
    ("/notsucceeds", 0x2281),
    ("/notsuperset", 0x2285),
    ("/orthogonal", 0x221F),
    ("/parallel", 0x2225),
    ("/pluscircle", 0x2295),
    ("/precedes", 0x227A),
    ("/proportion", 0x2237),
    ("/ratio", 0x2236),
    ("/reversedtilde", 0x223D),
    ("/rightangle", 0x221F),
    ("/righttriangle", 0x22BF),
    ("/subset", 0x2282),
    ("/subsetnotequal", 0x228A),
    ("/subsetorequal", 0x2286),
    ("/succeeds", 0x227B),
    ("/superset", 0x2283),
    ("/supersetnotequal", 0x228B),
    ("/supersetorequal", 0x2287),
    ("/tackdown", 0x22A4),
    ("/tackleft", 0x22A3),
    ("/thereexists", 0x2203),
    ("/tildeoperator", 0x223C),
    ("/timescircle", 0x2297),
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
  @test.assert_eq(extractor.charcode_of_codepoint(0x2206), Some(24))
  @test.assert_eq(extractor.charcode_of_codepoint(0x221F), Some(47))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2282), Some(56))
  @test.assert_eq(extractor.charcode_of_codepoint(0x22A3), Some(64))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2297), Some(67))
}

///|
test "PdfTextExtractor decodes Roman numeral AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/Oneroman", 0x2160),
    ("/Tworoman", 0x2161),
    ("/Threeroman", 0x2162),
    ("/Fourroman", 0x2163),
    ("/Fiveroman", 0x2164),
    ("/Sixroman", 0x2165),
    ("/Sevenroman", 0x2166),
    ("/Eightroman", 0x2167),
    ("/Nineroman", 0x2168),
    ("/Tenroman", 0x2169),
    ("/Elevenroman", 0x216A),
    ("/Twelveroman", 0x216B),
    ("/oneroman", 0x2170),
    ("/tworoman", 0x2171),
    ("/threeroman", 0x2172),
    ("/fourroman", 0x2173),
    ("/fiveroman", 0x2174),
    ("/sixroman", 0x2175),
    ("/sevenroman", 0x2176),
    ("/eightroman", 0x2177),
    ("/nineroman", 0x2178),
    ("/tenroman", 0x2179),
    ("/elevenroman", 0x217A),
    ("/twelveroman", 0x217B),
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
  @test.assert_eq(extractor.charcode_of_codepoint(0x2160), Some(1))
  @test.assert_eq(extractor.charcode_of_codepoint(0x216B), Some(12))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2170), Some(13))
  @test.assert_eq(extractor.charcode_of_codepoint(0x217B), Some(24))
}

///|
test "PdfTextExtractor decodes technical AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/arc", 0x2312),
    ("/clear", 0x2327),
    ("/control", 0x2303),
    ("/deleteleft", 0x232B),
    ("/deleteright", 0x2326),
    ("/house", 0x2302),
    ("/integralbottom", 0x2321),
    ("/integraltop", 0x2320),
    ("/logicalnotreversed", 0x2310),
    ("/option", 0x2325),
    ("/projective", 0x2305),
    ("/propellor", 0x2318),
    ("/revlogicalnot", 0x2310),
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
  @test.assert_eq(extractor.charcode_of_codepoint(0x2302), Some(6))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2310), Some(9))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2320), Some(8))
  @test.assert_eq(extractor.charcode_of_codepoint(0x232B), Some(4))
}

///|
test "PdfTextExtractor decodes enclosed alphanumeric AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/Acircle", 0x24B6),
    ("/Bcircle", 0x24B7),
    ("/Ccircle", 0x24B8),
    ("/Dcircle", 0x24B9),
    ("/Ecircle", 0x24BA),
    ("/Fcircle", 0x24BB),
    ("/Gcircle", 0x24BC),
    ("/Hcircle", 0x24BD),
    ("/Icircle", 0x24BE),
    ("/Jcircle", 0x24BF),
    ("/Kcircle", 0x24C0),
    ("/Lcircle", 0x24C1),
    ("/Mcircle", 0x24C2),
    ("/Ncircle", 0x24C3),
    ("/Ocircle", 0x24C4),
    ("/Pcircle", 0x24C5),
    ("/Qcircle", 0x24C6),
    ("/Rcircle", 0x24C7),
    ("/Scircle", 0x24C8),
    ("/Tcircle", 0x24C9),
    ("/Ucircle", 0x24CA),
    ("/Vcircle", 0x24CB),
    ("/Wcircle", 0x24CC),
    ("/Xcircle", 0x24CD),
    ("/Ycircle", 0x24CE),
    ("/Zcircle", 0x24CF),
    ("/acircle", 0x24D0),
    ("/aparen", 0x249C),
    ("/bcircle", 0x24D1),
    ("/bparen", 0x249D),
    ("/ccircle", 0x24D2),
    ("/cparen", 0x249E),
    ("/dcircle", 0x24D3),
    ("/dparen", 0x249F),
    ("/ecircle", 0x24D4),
    ("/eightcircle", 0x2467),
    ("/eighteencircle", 0x2471),
    ("/eighteenparen", 0x2485),
    ("/eighteenperiod", 0x2499),
    ("/eightparen", 0x247B),
    ("/eightperiod", 0x248F),
    ("/elevencircle", 0x246A),
    ("/elevenparen", 0x247E),
    ("/elevenperiod", 0x2492),
    ("/eparen", 0x24A0),
    ("/fcircle", 0x24D5),
    ("/fifteencircle", 0x246E),
    ("/fifteenparen", 0x2482),
    ("/fifteenperiod", 0x2496),
    ("/fivecircle", 0x2464),
    ("/fiveparen", 0x2478),
    ("/fiveperiod", 0x248C),
    ("/fourcircle", 0x2463),
    ("/fourparen", 0x2477),
    ("/fourperiod", 0x248B),
    ("/fourteencircle", 0x246D),
    ("/fourteenparen", 0x2481),
    ("/fourteenperiod", 0x2495),
    ("/fparen", 0x24A1),
    ("/gcircle", 0x24D6),
    ("/gparen", 0x24A2),
    ("/hcircle", 0x24D7),
    ("/hparen", 0x24A3),
    ("/icircle", 0x24D8),
    ("/iparen", 0x24A4),
    ("/jcircle", 0x24D9),
    ("/jparen", 0x24A5),
    ("/kcircle", 0x24DA),
    ("/kparen", 0x24A6),
    ("/lcircle", 0x24DB),
    ("/lparen", 0x24A7),
    ("/mcircle", 0x24DC),
    ("/mparen", 0x24A8),
    ("/ncircle", 0x24DD),
    ("/ninecircle", 0x2468),
    ("/nineparen", 0x247C),
    ("/nineperiod", 0x2490),
    ("/nineteencircle", 0x2472),
    ("/nineteenparen", 0x2486),
    ("/nineteenperiod", 0x249A),
    ("/nparen", 0x24A9),
    ("/ocircle", 0x24DE),
    ("/onecircle", 0x2460),
    ("/oneparen", 0x2474),
    ("/oneperiod", 0x2488),
    ("/oparen", 0x24AA),
    ("/pcircle", 0x24DF),
    ("/pparen", 0x24AB),
    ("/qcircle", 0x24E0),
    ("/qparen", 0x24AC),
    ("/rcircle", 0x24E1),
    ("/rparen", 0x24AD),
    ("/scircle", 0x24E2),
    ("/sevencircle", 0x2466),
    ("/sevenparen", 0x247A),
    ("/sevenperiod", 0x248E),
    ("/seventeencircle", 0x2470),
    ("/seventeenparen", 0x2484),
    ("/seventeenperiod", 0x2498),
    ("/sixcircle", 0x2465),
    ("/sixparen", 0x2479),
    ("/sixperiod", 0x248D),
    ("/sixteencircle", 0x246F),
    ("/sixteenparen", 0x2483),
    ("/sixteenperiod", 0x2497),
    ("/sparen", 0x24AE),
    ("/tcircle", 0x24E3),
    ("/tencircle", 0x2469),
    ("/tenparen", 0x247D),
    ("/tenperiod", 0x2491),
    ("/thirteencircle", 0x246C),
    ("/thirteenparen", 0x2480),
    ("/thirteenperiod", 0x2494),
    ("/threecircle", 0x2462),
    ("/threeparen", 0x2476),
    ("/threeperiod", 0x248A),
    ("/tparen", 0x24AF),
    ("/twelvecircle", 0x246B),
    ("/twelveparen", 0x247F),
    ("/twelveperiod", 0x2493),
    ("/twentycircle", 0x2473),
    ("/twentyparen", 0x2487),
    ("/twentyperiod", 0x249B),
    ("/twocircle", 0x2461),
    ("/twoparen", 0x2475),
    ("/twoperiod", 0x2489),
    ("/ucircle", 0x24E4),
    ("/uparen", 0x24B0),
    ("/vcircle", 0x24E5),
    ("/vparen", 0x24B1),
    ("/wcircle", 0x24E6),
    ("/wparen", 0x24B2),
    ("/xcircle", 0x24E7),
    ("/xparen", 0x24B3),
    ("/ycircle", 0x24E8),
    ("/yparen", 0x24B4),
    ("/zcircle", 0x24E9),
    ("/zparen", 0x24B5),
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
  @test.assert_eq(extractor.charcode_of_codepoint(0x24B6), Some(1))
  @test.assert_eq(extractor.charcode_of_codepoint(0x24CF), Some(26))
  @test.assert_eq(extractor.charcode_of_codepoint(0x249C), Some(28))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2460), Some(83))
  @test.assert_eq(extractor.charcode_of_codepoint(0x249B), Some(123))
  @test.assert_eq(extractor.charcode_of_codepoint(0x24E9), Some(137))
  @test.assert_eq(extractor.charcode_of_codepoint(0x24B5), Some(138))
}
