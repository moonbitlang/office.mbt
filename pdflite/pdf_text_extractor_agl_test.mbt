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

///|
test "PdfTextExtractor decodes CJK symbol AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/anglebracketleft", 0x3008),
    ("/anglebracketright", 0x3009),
    ("/blacklenticularbracketleft", 0x3010),
    ("/blacklenticularbracketright", 0x3011),
    ("/circlepostalmark", 0x3036),
    ("/cornerbracketleft", 0x300C),
    ("/cornerbracketright", 0x300D),
    ("/dblanglebracketleft", 0x300A),
    ("/dblanglebracketright", 0x300B),
    ("/dittomark", 0x3003),
    ("/eighthangzhou", 0x3028),
    ("/fivehangzhou", 0x3025),
    ("/fourhangzhou", 0x3024),
    ("/getamark", 0x3013),
    ("/ideographicclose", 0x3006),
    ("/ideographiccomma", 0x3001),
    ("/ideographiciterationmark", 0x3005),
    ("/ideographicperiod", 0x3002),
    ("/ideographicspace", 0x3000),
    ("/ideographiczero", 0x3007),
    ("/jis", 0x3004),
    ("/ninehangzhou", 0x3029),
    ("/onehangzhou", 0x3021),
    ("/postalmark", 0x3012),
    ("/postalmarkface", 0x3020),
    ("/quotedblprime", 0x301E),
    ("/quotedblprimereversed", 0x301D),
    ("/sevenhangzhou", 0x3027),
    ("/sixhangzhou", 0x3026),
    ("/threehangzhou", 0x3023),
    ("/tortoiseshellbracketleft", 0x3014),
    ("/tortoiseshellbracketright", 0x3015),
    ("/twentyhangzhou", 0x5344),
    ("/twohangzhou", 0x3022),
    ("/wavedash", 0x301C),
    ("/whitecornerbracketleft", 0x300E),
    ("/whitecornerbracketright", 0x300F),
    ("/whitelenticularbracketleft", 0x3016),
    ("/whitelenticularbracketright", 0x3017),
    ("/whitetortoiseshellbracketleft", 0x3018),
    ("/whitetortoiseshellbracketright", 0x3019),
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
  @test.assert_eq(extractor.charcode_of_codepoint(0x3008), Some(1))
  @test.assert_eq(extractor.charcode_of_codepoint(0x3000), Some(19))
  @test.assert_eq(extractor.charcode_of_codepoint(0x5344), Some(33))
  @test.assert_eq(extractor.charcode_of_codepoint(0x3019), Some(41))
}

///|
test "PdfTextExtractor decodes Hiragana AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/ahiragana", 0x3042),
    ("/asmallhiragana", 0x3041),
    ("/bahiragana", 0x3070),
    ("/behiragana", 0x3079),
    ("/bihiragana", 0x3073),
    ("/bohiragana", 0x307C),
    ("/buhiragana", 0x3076),
    ("/dahiragana", 0x3060),
    ("/dehiragana", 0x3067),
    ("/dihiragana", 0x3062),
    ("/dohiragana", 0x3069),
    ("/duhiragana", 0x3065),
    ("/ehiragana", 0x3048),
    ("/esmallhiragana", 0x3047),
    ("/gahiragana", 0x304C),
    ("/gehiragana", 0x3052),
    ("/gihiragana", 0x304E),
    ("/gohiragana", 0x3054),
    ("/guhiragana", 0x3050),
    ("/hahiragana", 0x306F),
    ("/hehiragana", 0x3078),
    ("/hihiragana", 0x3072),
    ("/hohiragana", 0x307B),
    ("/huhiragana", 0x3075),
    ("/ihiragana", 0x3044),
    ("/ismallhiragana", 0x3043),
    ("/iterationhiragana", 0x309D),
    ("/kahiragana", 0x304B),
    ("/kehiragana", 0x3051),
    ("/kihiragana", 0x304D),
    ("/kohiragana", 0x3053),
    ("/kuhiragana", 0x304F),
    ("/mahiragana", 0x307E),
    ("/mehiragana", 0x3081),
    ("/mihiragana", 0x307F),
    ("/mohiragana", 0x3082),
    ("/muhiragana", 0x3080),
    ("/nahiragana", 0x306A),
    ("/nehiragana", 0x306D),
    ("/nhiragana", 0x3093),
    ("/nihiragana", 0x306B),
    ("/nohiragana", 0x306E),
    ("/nuhiragana", 0x306C),
    ("/ohiragana", 0x304A),
    ("/osmallhiragana", 0x3049),
    ("/pahiragana", 0x3071),
    ("/pehiragana", 0x307A),
    ("/pihiragana", 0x3074),
    ("/pohiragana", 0x307D),
    ("/puhiragana", 0x3077),
    ("/rahiragana", 0x3089),
    ("/rehiragana", 0x308C),
    ("/rihiragana", 0x308A),
    ("/rohiragana", 0x308D),
    ("/ruhiragana", 0x308B),
    ("/sahiragana", 0x3055),
    ("/sehiragana", 0x305B),
    ("/semivoicedmarkkana", 0x309C),
    ("/sihiragana", 0x3057),
    ("/sohiragana", 0x305D),
    ("/suhiragana", 0x3059),
    ("/tahiragana", 0x305F),
    ("/tehiragana", 0x3066),
    ("/tihiragana", 0x3061),
    ("/tohiragana", 0x3068),
    ("/tuhiragana", 0x3064),
    ("/tusmallhiragana", 0x3063),
    ("/uhiragana", 0x3046),
    ("/usmallhiragana", 0x3045),
    ("/voicediterationhiragana", 0x309E),
    ("/voicedmarkkana", 0x309B),
    ("/vuhiragana", 0x3094),
    ("/wahiragana", 0x308F),
    ("/wasmallhiragana", 0x308E),
    ("/wehiragana", 0x3091),
    ("/wihiragana", 0x3090),
    ("/wohiragana", 0x3092),
    ("/yahiragana", 0x3084),
    ("/yasmallhiragana", 0x3083),
    ("/yohiragana", 0x3088),
    ("/yosmallhiragana", 0x3087),
    ("/yuhiragana", 0x3086),
    ("/yusmallhiragana", 0x3085),
    ("/zahiragana", 0x3056),
    ("/zehiragana", 0x305C),
    ("/zihiragana", 0x3058),
    ("/zohiragana", 0x305E),
    ("/zuhiragana", 0x305A),
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
  @test.assert_eq(extractor.charcode_of_codepoint(0x3042), Some(1))
  @test.assert_eq(extractor.charcode_of_codepoint(0x309D), Some(27))
  @test.assert_eq(extractor.charcode_of_codepoint(0x309B), Some(71))
  @test.assert_eq(extractor.charcode_of_codepoint(0x305A), Some(88))
}

///|
test "PdfTextExtractor decodes Katakana AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/akatakana", 0x30A2),
    ("/asmallkatakana", 0x30A1),
    ("/bakatakana", 0x30D0),
    ("/bekatakana", 0x30D9),
    ("/bikatakana", 0x30D3),
    ("/bokatakana", 0x30DC),
    ("/bukatakana", 0x30D6),
    ("/dakatakana", 0x30C0),
    ("/dekatakana", 0x30C7),
    ("/dikatakana", 0x30C2),
    ("/dokatakana", 0x30C9),
    ("/dotkatakana", 0x30FB),
    ("/dukatakana", 0x30C5),
    ("/ekatakana", 0x30A8),
    ("/esmallkatakana", 0x30A7),
    ("/gakatakana", 0x30AC),
    ("/gekatakana", 0x30B2),
    ("/gikatakana", 0x30AE),
    ("/gokatakana", 0x30B4),
    ("/gukatakana", 0x30B0),
    ("/hakatakana", 0x30CF),
    ("/hekatakana", 0x30D8),
    ("/hikatakana", 0x30D2),
    ("/hokatakana", 0x30DB),
    ("/hukatakana", 0x30D5),
    ("/ikatakana", 0x30A4),
    ("/ismallkatakana", 0x30A3),
    ("/iterationkatakana", 0x30FD),
    ("/kakatakana", 0x30AB),
    ("/kasmallkatakana", 0x30F5),
    ("/kekatakana", 0x30B1),
    ("/kesmallkatakana", 0x30F6),
    ("/kikatakana", 0x30AD),
    ("/kokatakana", 0x30B3),
    ("/kukatakana", 0x30AF),
    ("/makatakana", 0x30DE),
    ("/mekatakana", 0x30E1),
    ("/mikatakana", 0x30DF),
    ("/mokatakana", 0x30E2),
    ("/mukatakana", 0x30E0),
    ("/nakatakana", 0x30CA),
    ("/nekatakana", 0x30CD),
    ("/nikatakana", 0x30CB),
    ("/nkatakana", 0x30F3),
    ("/nokatakana", 0x30CE),
    ("/nukatakana", 0x30CC),
    ("/okatakana", 0x30AA),
    ("/osmallkatakana", 0x30A9),
    ("/pakatakana", 0x30D1),
    ("/pekatakana", 0x30DA),
    ("/pikatakana", 0x30D4),
    ("/pokatakana", 0x30DD),
    ("/prolongedkana", 0x30FC),
    ("/pukatakana", 0x30D7),
    ("/rakatakana", 0x30E9),
    ("/rekatakana", 0x30EC),
    ("/rikatakana", 0x30EA),
    ("/rokatakana", 0x30ED),
    ("/rukatakana", 0x30EB),
    ("/sakatakana", 0x30B5),
    ("/sekatakana", 0x30BB),
    ("/sikatakana", 0x30B7),
    ("/sokatakana", 0x30BD),
    ("/sukatakana", 0x30B9),
    ("/takatakana", 0x30BF),
    ("/tekatakana", 0x30C6),
    ("/tikatakana", 0x30C1),
    ("/tokatakana", 0x30C8),
    ("/tukatakana", 0x30C4),
    ("/tusmallkatakana", 0x30C3),
    ("/ukatakana", 0x30A6),
    ("/usmallkatakana", 0x30A5),
    ("/vakatakana", 0x30F7),
    ("/vekatakana", 0x30F9),
    ("/vikatakana", 0x30F8),
    ("/voicediterationkatakana", 0x30FE),
    ("/vokatakana", 0x30FA),
    ("/vukatakana", 0x30F4),
    ("/wakatakana", 0x30EF),
    ("/wasmallkatakana", 0x30EE),
    ("/wekatakana", 0x30F1),
    ("/wikatakana", 0x30F0),
    ("/wokatakana", 0x30F2),
    ("/yakatakana", 0x30E4),
    ("/yasmallkatakana", 0x30E3),
    ("/yokatakana", 0x30E8),
    ("/yosmallkatakana", 0x30E7),
    ("/yukatakana", 0x30E6),
    ("/yusmallkatakana", 0x30E5),
    ("/zakatakana", 0x30B6),
    ("/zekatakana", 0x30BC),
    ("/zikatakana", 0x30B8),
    ("/zokatakana", 0x30BE),
    ("/zukatakana", 0x30BA),
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
  @test.assert_eq(extractor.charcode_of_codepoint(0x30A2), Some(1))
  @test.assert_eq(extractor.charcode_of_codepoint(0x30FB), Some(12))
  @test.assert_eq(extractor.charcode_of_codepoint(0x30FC), Some(53))
  @test.assert_eq(extractor.charcode_of_codepoint(0x30BA), Some(94))
}

///|
test "PdfTextExtractor decodes Bopomofo AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/abopomofo", 0x311A),
    ("/aibopomofo", 0x311E),
    ("/anbopomofo", 0x3122),
    ("/angbopomofo", 0x3124),
    ("/aubopomofo", 0x3120),
    ("/bbopomofo", 0x3105),
    ("/cbopomofo", 0x3118),
    ("/chbopomofo", 0x3114),
    ("/dbopomofo", 0x3109),
    ("/ebopomofo", 0x311C),
    ("/ehbopomofo", 0x311D),
    ("/eibopomofo", 0x311F),
    ("/enbopomofo", 0x3123),
    ("/engbopomofo", 0x3125),
    ("/erbopomofo", 0x3126),
    ("/fbopomofo", 0x3108),
    ("/gbopomofo", 0x310D),
    ("/hbopomofo", 0x310F),
    ("/ibopomofo", 0x3127),
    ("/iubopomofo", 0x3129),
    ("/jbopomofo", 0x3110),
    ("/kbopomofo", 0x310E),
    ("/lbopomofo", 0x310C),
    ("/mbopomofo", 0x3107),
    ("/nbopomofo", 0x310B),
    ("/obopomofo", 0x311B),
    ("/oubopomofo", 0x3121),
    ("/pbopomofo", 0x3106),
    ("/qbopomofo", 0x3111),
    ("/rbopomofo", 0x3116),
    ("/sbopomofo", 0x3119),
    ("/shbopomofo", 0x3115),
    ("/tbopomofo", 0x310A),
    ("/ubopomofo", 0x3128),
    ("/xbopomofo", 0x3112),
    ("/zbopomofo", 0x3117),
    ("/zhbopomofo", 0x3113),
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
  @test.assert_eq(extractor.charcode_of_codepoint(0x311A), Some(1))
  @test.assert_eq(extractor.charcode_of_codepoint(0x3105), Some(6))
  @test.assert_eq(extractor.charcode_of_codepoint(0x3129), Some(20))
  @test.assert_eq(extractor.charcode_of_codepoint(0x3113), Some(37))
}

///|
test "PdfTextExtractor decodes Hangul compatibility jamo AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/aekorean", 0x3150),
    ("/akorean", 0x314F),
    ("/araeaekorean", 0x318E),
    ("/araeakorean", 0x318D),
    ("/chieuchkorean", 0x314A),
    ("/cieuckorean", 0x3148),
    ("/ekorean", 0x3154),
    ("/eokorean", 0x3153),
    ("/eukorean", 0x3161),
    ("/hangulfiller", 0x3164),
    ("/hieuhkorean", 0x314E),
    ("/ieungkorean", 0x3147),
    ("/ikorean", 0x3163),
    ("/kapyeounmieumkorean", 0x3171),
    ("/kapyeounphieuphkorean", 0x3184),
    ("/kapyeounpieupkorean", 0x3178),
    ("/kapyeounssangpieupkorean", 0x3179),
    ("/khieukhkorean", 0x314B),
    ("/kiyeokkorean", 0x3131),
    ("/kiyeoksioskorean", 0x3133),
    ("/mieumkorean", 0x3141),
    ("/mieumpansioskorean", 0x3170),
    ("/mieumpieupkorean", 0x316E),
    ("/mieumsioskorean", 0x316F),
    ("/nieuncieuckorean", 0x3135),
    ("/nieunhieuhkorean", 0x3136),
    ("/nieunkorean", 0x3134),
    ("/nieunpansioskorean", 0x3168),
    ("/nieunsioskorean", 0x3167),
    ("/nieuntikeutkorean", 0x3166),
    ("/oekorean", 0x315A),
    ("/okorean", 0x3157),
    ("/pansioskorean", 0x317F),
    ("/phieuphkorean", 0x314D),
    ("/pieupcieuckorean", 0x3176),
    ("/pieupkiyeokkorean", 0x3172),
    ("/pieupkorean", 0x3142),
    ("/pieupsioskiyeokkorean", 0x3174),
    ("/pieupsioskorean", 0x3144),
    ("/pieupsiostikeutkorean", 0x3175),
    ("/pieupthieuthkorean", 0x3177),
    ("/pieuptikeutkorean", 0x3173),
    ("/rieulhieuhkorean", 0x3140),
    ("/rieulkiyeokkorean", 0x313A),
    ("/rieulkiyeoksioskorean", 0x3169),
    ("/rieulkorean", 0x3139),
    ("/rieulmieumkorean", 0x313B),
    ("/rieulpansioskorean", 0x316C),
    ("/rieulphieuphkorean", 0x313F),
    ("/rieulpieupkorean", 0x313C),
    ("/rieulpieupsioskorean", 0x316B),
    ("/rieulsioskorean", 0x313D),
    ("/rieulthieuthkorean", 0x313E),
    ("/rieultikeutkorean", 0x316A),
    ("/rieulyeorinhieuhkorean", 0x316D),
    ("/sioscieuckorean", 0x317E),
    ("/sioskiyeokkorean", 0x317A),
    ("/sioskorean", 0x3145),
    ("/siosnieunkorean", 0x317B),
    ("/siospieupkorean", 0x317D),
    ("/siostikeutkorean", 0x317C),
    ("/ssangcieuckorean", 0x3149),
    ("/ssanghieuhkorean", 0x3185),
    ("/ssangieungkorean", 0x3180),
    ("/ssangkiyeokkorean", 0x3132),
    ("/ssangnieunkorean", 0x3165),
    ("/ssangpieupkorean", 0x3143),
    ("/ssangsioskorean", 0x3146),
    ("/ssangtikeutkorean", 0x3138),
    ("/thieuthkorean", 0x314C),
    ("/tikeutkorean", 0x3137),
    ("/ukorean", 0x315C),
    ("/waekorean", 0x3159),
    ("/wakorean", 0x3158),
    ("/wekorean", 0x315E),
    ("/weokorean", 0x315D),
    ("/wikorean", 0x315F),
    ("/yaekorean", 0x3152),
    ("/yakorean", 0x3151),
    ("/yekorean", 0x3156),
    ("/yeokorean", 0x3155),
    ("/yeorinhieuhkorean", 0x3186),
    ("/yesieungkorean", 0x3181),
    ("/yesieungpansioskorean", 0x3183),
    ("/yesieungsioskorean", 0x3182),
    ("/yikorean", 0x3162),
    ("/yoikorean", 0x3189),
    ("/yokorean", 0x315B),
    ("/yoyaekorean", 0x3188),
    ("/yoyakorean", 0x3187),
    ("/yuikorean", 0x318C),
    ("/yukorean", 0x3160),
    ("/yuyekorean", 0x318B),
    ("/yuyeokorean", 0x318A),
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
  @test.assert_eq(extractor.charcode_of_codepoint(0x3150), Some(1))
  @test.assert_eq(extractor.charcode_of_codepoint(0x3164), Some(10))
  @test.assert_eq(extractor.charcode_of_codepoint(0x3131), Some(19))
  @test.assert_eq(extractor.charcode_of_codepoint(0x318A), Some(94))
}

///|
test "PdfTextExtractor decodes Enclosed CJK AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/chieuchacirclekorean", 0x3277),
    ("/chieuchaparenkorean", 0x3217),
    ("/chieuchcirclekorean", 0x3269),
    ("/chieuchparenkorean", 0x3209),
    ("/cieucacirclekorean", 0x3276),
    ("/cieucaparenkorean", 0x3216),
    ("/cieuccirclekorean", 0x3268),
    ("/cieucparenkorean", 0x3208),
    ("/cieucuparenkorean", 0x321C),
    ("/eightideographicparen", 0x3227),
    ("/fiveideographicparen", 0x3224),
    ("/fourideographicparen", 0x3223),
    ("/hieuhacirclekorean", 0x327B),
    ("/hieuhaparenkorean", 0x321B),
    ("/hieuhcirclekorean", 0x326D),
    ("/hieuhparenkorean", 0x320D),
    ("/ideographearthcircle", 0x328F),
    ("/ideographfirecircle", 0x328B),
    ("/ideographicallianceparen", 0x323F),
    ("/ideographiccallparen", 0x323A),
    ("/ideographiccentrecircle", 0x32A5),
    ("/ideographiccongratulationparen", 0x3237),
    ("/ideographiccorrectcircle", 0x32A3),
    ("/ideographicearthparen", 0x322F),
    ("/ideographicenterpriseparen", 0x323D),
    ("/ideographicexcellentcircle", 0x329D),
    ("/ideographicfestivalparen", 0x3240),
    ("/ideographicfinancialcircle", 0x3296),
    ("/ideographicfinancialparen", 0x3236),
    ("/ideographicfireparen", 0x322B),
    ("/ideographichaveparen", 0x3232),
    ("/ideographichighcircle", 0x32A4),
    ("/ideographiclaborcircle", 0x3298),
    ("/ideographiclaborparen", 0x3238),
    ("/ideographicleftcircle", 0x32A7),
    ("/ideographiclowcircle", 0x32A6),
    ("/ideographicmedicinecircle", 0x32A9),
    ("/ideographicmetalparen", 0x322E),
    ("/ideographicmoonparen", 0x322A),
    ("/ideographicnameparen", 0x3234),
    ("/ideographicprintcircle", 0x329E),
    ("/ideographicreachparen", 0x3243),
    ("/ideographicrepresentparen", 0x3239),
    ("/ideographicresourceparen", 0x323E),
    ("/ideographicrightcircle", 0x32A8),
    ("/ideographicsecretcircle", 0x3299),
    ("/ideographicselfparen", 0x3242),
    ("/ideographicsocietyparen", 0x3233),
    ("/ideographicspecialparen", 0x3235),
    ("/ideographicstockparen", 0x3231),
    ("/ideographicstudyparen", 0x323B),
    ("/ideographicsunparen", 0x3230),
    ("/ideographicsuperviseparen", 0x323C),
    ("/ideographicwaterparen", 0x322C),
    ("/ideographicwoodparen", 0x322D),
    ("/ideographmetalcircle", 0x328E),
    ("/ideographmooncircle", 0x328A),
    ("/ideographnamecircle", 0x3294),
    ("/ideographsuncircle", 0x3290),
    ("/ideographwatercircle", 0x328C),
    ("/ideographwoodcircle", 0x328D),
    ("/ieungacirclekorean", 0x3275),
    ("/ieungaparenkorean", 0x3215),
    ("/ieungcirclekorean", 0x3267),
    ("/ieungparenkorean", 0x3207),
    ("/khieukhacirclekorean", 0x3278),
    ("/khieukhaparenkorean", 0x3218),
    ("/khieukhcirclekorean", 0x326A),
    ("/khieukhparenkorean", 0x320A),
    ("/kiyeokacirclekorean", 0x326E),
    ("/kiyeokaparenkorean", 0x320E),
    ("/kiyeokcirclekorean", 0x3260),
    ("/kiyeokparenkorean", 0x3200),
    ("/koreanstandardsymbol", 0x327F),
    ("/mieumacirclekorean", 0x3272),
    ("/mieumaparenkorean", 0x3212),
    ("/mieumcirclekorean", 0x3264),
    ("/mieumparenkorean", 0x3204),
    ("/nieunacirclekorean", 0x326F),
    ("/nieunaparenkorean", 0x320F),
    ("/nieuncirclekorean", 0x3261),
    ("/nieunparenkorean", 0x3201),
    ("/nineideographicparen", 0x3228),
    ("/oneideographicparen", 0x3220),
    ("/phieuphacirclekorean", 0x327A),
    ("/phieuphaparenkorean", 0x321A),
    ("/phieuphcirclekorean", 0x326C),
    ("/phieuphparenkorean", 0x320C),
    ("/pieupacirclekorean", 0x3273),
    ("/pieupaparenkorean", 0x3213),
    ("/pieupcirclekorean", 0x3265),
    ("/pieupparenkorean", 0x3205),
    ("/rieulacirclekorean", 0x3271),
    ("/rieulaparenkorean", 0x3211),
    ("/rieulcirclekorean", 0x3263),
    ("/rieulparenkorean", 0x3203),
    ("/sevenideographicparen", 0x3226),
    ("/siosacirclekorean", 0x3274),
    ("/siosaparenkorean", 0x3214),
    ("/sioscirclekorean", 0x3266),
    ("/siosparenkorean", 0x3206),
    ("/sixideographicparen", 0x3225),
    ("/tenideographicparen", 0x3229),
    ("/thieuthacirclekorean", 0x3279),
    ("/thieuthaparenkorean", 0x3219),
    ("/thieuthcirclekorean", 0x326B),
    ("/thieuthparenkorean", 0x320B),
    ("/threeideographicparen", 0x3222),
    ("/tikeutacirclekorean", 0x3270),
    ("/tikeutaparenkorean", 0x3210),
    ("/tikeutcirclekorean", 0x3262),
    ("/tikeutparenkorean", 0x3202),
    ("/twoideographicparen", 0x3221),
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
  @test.assert_eq(extractor.charcode_of_codepoint(0x3277), Some(1))
  @test.assert_eq(extractor.charcode_of_codepoint(0x328F), Some(17))
  @test.assert_eq(extractor.charcode_of_codepoint(0x327F), Some(74))
  @test.assert_eq(extractor.charcode_of_codepoint(0x3221), Some(113))
}

///|
test "PdfTextExtractor decodes box drawing AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/SF010000", 0x250C),
    ("/SF020000", 0x2514),
    ("/SF030000", 0x2510),
    ("/SF040000", 0x2518),
    ("/SF050000", 0x253C),
    ("/SF060000", 0x252C),
    ("/SF070000", 0x2534),
    ("/SF080000", 0x251C),
    ("/SF090000", 0x2524),
    ("/SF100000", 0x2500),
    ("/SF110000", 0x2502),
    ("/SF190000", 0x2561),
    ("/SF200000", 0x2562),
    ("/SF210000", 0x2556),
    ("/SF220000", 0x2555),
    ("/SF230000", 0x2563),
    ("/SF240000", 0x2551),
    ("/SF250000", 0x2557),
    ("/SF260000", 0x255D),
    ("/SF270000", 0x255C),
    ("/SF280000", 0x255B),
    ("/SF360000", 0x255E),
    ("/SF370000", 0x255F),
    ("/SF380000", 0x255A),
    ("/SF390000", 0x2554),
    ("/SF400000", 0x2569),
    ("/SF410000", 0x2566),
    ("/SF420000", 0x2560),
    ("/SF430000", 0x2550),
    ("/SF440000", 0x256C),
    ("/SF450000", 0x2567),
    ("/SF460000", 0x2568),
    ("/SF470000", 0x2564),
    ("/SF480000", 0x2565),
    ("/SF490000", 0x2559),
    ("/SF500000", 0x2558),
    ("/SF510000", 0x2552),
    ("/SF520000", 0x2553),
    ("/SF530000", 0x256B),
    ("/SF540000", 0x256A),
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
  @test.assert_eq(extractor.charcode_of_codepoint(0x250C), Some(1))
  @test.assert_eq(extractor.charcode_of_codepoint(0x253C), Some(5))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2500), Some(10))
  @test.assert_eq(extractor.charcode_of_codepoint(0x256C), Some(30))
  @test.assert_eq(extractor.charcode_of_codepoint(0x256A), Some(40))
}

///|
test "PdfTextExtractor decodes block element AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/block", 0x2588),
    ("/dkshade", 0x2593),
    ("/dnblock", 0x2584),
    ("/lfblock", 0x258C),
    ("/ltshade", 0x2591),
    ("/rtblock", 0x2590),
    ("/shade", 0x2592),
    ("/shadedark", 0x2593),
    ("/shadelight", 0x2591),
    ("/shademedium", 0x2592),
    ("/upblock", 0x2580),
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
  @test.assert_eq(extractor.charcode_of_codepoint(0x2593), Some(2))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2591), Some(5))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2592), Some(7))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2580), Some(11))
}

///|
test "PdfTextExtractor decodes geometric shape AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/H18533", 0x25CF),
    ("/H18543", 0x25AA),
    ("/H18551", 0x25AB),
    ("/H22073", 0x25A1),
    ("/blackcircle", 0x25CF),
    ("/blackdiamond", 0x25C6),
    ("/blackdownpointingtriangle", 0x25BC),
    ("/blackleftpointingpointer", 0x25C4),
    ("/blackleftpointingtriangle", 0x25C0),
    ("/blacklowerlefttriangle", 0x25E3),
    ("/blacklowerrighttriangle", 0x25E2),
    ("/blackrectangle", 0x25AC),
    ("/blackrightpointingpointer", 0x25BA),
    ("/blackrightpointingtriangle", 0x25B6),
    ("/blacksmallsquare", 0x25AA),
    ("/blacksquare", 0x25A0),
    ("/blackupperlefttriangle", 0x25E4),
    ("/blackupperrighttriangle", 0x25E5),
    ("/blackuppointingsmalltriangle", 0x25B4),
    ("/blackuppointingtriangle", 0x25B2),
    ("/bulletinverse", 0x25D8),
    ("/bullseye", 0x25CE),
    ("/circle", 0x25CB),
    ("/circlewithlefthalfblack", 0x25D0),
    ("/circlewithrighthalfblack", 0x25D1),
    ("/dottedcircle", 0x25CC),
    ("/filledbox", 0x25A0),
    ("/filledrect", 0x25AC),
    ("/fisheye", 0x25C9),
    ("/invbullet", 0x25D8),
    ("/invcircle", 0x25D9),
    ("/largecircle", 0x25EF),
    ("/openbullet", 0x25E6),
    ("/squarediagonalcrosshatchfill", 0x25A9),
    ("/squarehorizontalfill", 0x25A4),
    ("/squareorthogonalcrosshatchfill", 0x25A6),
    ("/squareupperlefttolowerrightfill", 0x25A7),
    ("/squareupperrighttolowerleftfill", 0x25A8),
    ("/squareverticalfill", 0x25A5),
    ("/squarewhitewithsmallblack", 0x25A3),
    ("/triagdn", 0x25BC),
    ("/triaglf", 0x25C4),
    ("/triagrt", 0x25BA),
    ("/triagup", 0x25B2),
    ("/whitebullet", 0x25E6),
    ("/whitecircle", 0x25CB),
    ("/whitecircleinverse", 0x25D9),
    ("/whitediamond", 0x25C7),
    ("/whitediamondcontainingblacksmalldiamond", 0x25C8),
    ("/whitedownpointingsmalltriangle", 0x25BF),
    ("/whitedownpointingtriangle", 0x25BD),
    ("/whiteleftpointingsmalltriangle", 0x25C3),
    ("/whiteleftpointingtriangle", 0x25C1),
    ("/whiterightpointingsmalltriangle", 0x25B9),
    ("/whiterightpointingtriangle", 0x25B7),
    ("/whitesmallsquare", 0x25AB),
    ("/whitesquare", 0x25A1),
    ("/whiteuppointingsmalltriangle", 0x25B5),
    ("/whiteuppointingtriangle", 0x25B3),
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
  @test.assert_eq(extractor.charcode_of_codepoint(0x25CF), Some(1))
  @test.assert_eq(extractor.charcode_of_codepoint(0x25AA), Some(2))
  @test.assert_eq(extractor.charcode_of_codepoint(0x25AB), Some(3))
  @test.assert_eq(extractor.charcode_of_codepoint(0x25A1), Some(4))
  @test.assert_eq(extractor.charcode_of_codepoint(0x25BC), Some(7))
  @test.assert_eq(extractor.charcode_of_codepoint(0x25E6), Some(33))
  @test.assert_eq(extractor.charcode_of_codepoint(0x25B3), Some(59))
}

///|
test "PdfTextExtractor decodes dingbat AGL alias glyph names" {
  let entries : Array[(String, Int)] = [
    ("/arrowrightheavy", 0x279E),
    ("/checkmark", 0x2713),
    ("/onecircleinversesansserif", 0x278A),
    ("/twocircleinversesansserif", 0x278B),
    ("/threecircleinversesansserif", 0x278C),
    ("/fourcircleinversesansserif", 0x278D),
    ("/fivecircleinversesansserif", 0x278E),
    ("/sixcircleinversesansserif", 0x278F),
    ("/sevencircleinversesansserif", 0x2790),
    ("/eightcircleinversesansserif", 0x2791),
    ("/ninecircleinversesansserif", 0x2792),
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
  @test.assert_eq(extractor.charcode_of_codepoint(0x279E), Some(1))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2713), Some(2))
  @test.assert_eq(extractor.charcode_of_codepoint(0x278A), Some(3))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2792), Some(11))
}

///|
test "PdfTextExtractor decodes miscellaneous symbol AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/beamedsixteenthnotes", 0x266C),
    ("/blacksmilingface", 0x263B),
    ("/blackstar", 0x2605),
    ("/clubsuitblack", 0x2663),
    ("/clubsuitwhite", 0x2667),
    ("/compass", 0x263C),
    ("/diamondsuitwhite", 0x2662),
    ("/earth", 0x2641),
    ("/eighthnotebeamed", 0x266B),
    ("/female", 0x2640),
    ("/heartsuitblack", 0x2665),
    ("/heartsuitwhite", 0x2661),
    ("/hotsprings", 0x2668),
    ("/invsmileface", 0x263B),
    ("/male", 0x2642),
    ("/mars", 0x2642),
    ("/musicalnote", 0x266A),
    ("/musicalnotedbl", 0x266B),
    ("/musicflatsign", 0x266D),
    ("/musicsharpsign", 0x266F),
    ("/pointingindexdownwhite", 0x261F),
    ("/pointingindexleftwhite", 0x261C),
    ("/pointingindexrightwhite", 0x261E),
    ("/pointingindexupwhite", 0x261D),
    ("/quarternote", 0x2669),
    ("/smileface", 0x263A),
    ("/spadesuitblack", 0x2660),
    ("/spadesuitwhite", 0x2664),
    ("/sun", 0x263C),
    ("/telephoneblack", 0x260E),
    ("/venus", 0x2640),
    ("/whitesmilingface", 0x263A),
    ("/whitestar", 0x2606),
    ("/whitetelephone", 0x260F),
    ("/yinyang", 0x262F),
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
  @test.assert_eq(extractor.charcode_of_codepoint(0x263B), Some(2))
  @test.assert_eq(extractor.charcode_of_codepoint(0x263C), Some(6))
  @test.assert_eq(extractor.charcode_of_codepoint(0x266B), Some(9))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2640), Some(10))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2642), Some(15))
  @test.assert_eq(extractor.charcode_of_codepoint(0x262F), Some(35))
}

///|
test "PdfTextExtractor decodes Latin Extended-A AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/Abreve", 0x0102),
    ("/Amacron", 0x0100),
    ("/Aogonek", 0x0104),
    ("/Cacute", 0x0106),
    ("/Ccaron", 0x010C),
    ("/Ccircumflex", 0x0108),
    ("/Cdot", 0x010A),
    ("/Cdotaccent", 0x010A),
    ("/Dcaron", 0x010E),
    ("/Dcroat", 0x0110),
    ("/Dslash", 0x0110),
    ("/Ebreve", 0x0114),
    ("/Ecaron", 0x011A),
    ("/Edot", 0x0116),
    ("/Edotaccent", 0x0116),
    ("/Emacron", 0x0112),
    ("/Eng", 0x014A),
    ("/Eogonek", 0x0118),
    ("/Gbreve", 0x011E),
    ("/Gcedilla", 0x0122),
    ("/Gcircumflex", 0x011C),
    ("/Gcommaaccent", 0x0122),
    ("/Gdot", 0x0120),
    ("/Gdotaccent", 0x0120),
    ("/Hbar", 0x0126),
    ("/Hcircumflex", 0x0124),
    ("/IJ", 0x0132),
    ("/Ibreve", 0x012C),
    ("/Idot", 0x0130),
    ("/Idotaccent", 0x0130),
    ("/Imacron", 0x012A),
    ("/Iogonek", 0x012E),
    ("/Itilde", 0x0128),
    ("/Jcircumflex", 0x0134),
    ("/Kcedilla", 0x0136),
    ("/Kcommaaccent", 0x0136),
    ("/Lacute", 0x0139),
    ("/Lcaron", 0x013D),
    ("/Lcedilla", 0x013B),
    ("/Lcommaaccent", 0x013B),
    ("/Ldot", 0x013F),
    ("/Ldotaccent", 0x013F),
    ("/Lslash", 0x0141),
    ("/Nacute", 0x0143),
    ("/Ncaron", 0x0147),
    ("/Ncedilla", 0x0145),
    ("/Ncommaaccent", 0x0145),
    ("/OE", 0x0152),
    ("/Obreve", 0x014E),
    ("/Odblacute", 0x0150),
    ("/Ohungarumlaut", 0x0150),
    ("/Omacron", 0x014C),
    ("/Racute", 0x0154),
    ("/Rcaron", 0x0158),
    ("/Rcedilla", 0x0156),
    ("/Rcommaaccent", 0x0156),
    ("/Sacute", 0x015A),
    ("/Scaron", 0x0160),
    ("/Scedilla", 0x015E),
    ("/Scircumflex", 0x015C),
    ("/Tbar", 0x0166),
    ("/Tcaron", 0x0164),
    ("/Tcedilla", 0x0162),
    ("/Tcommaaccent", 0x0162),
    ("/Ubreve", 0x016C),
    ("/Udblacute", 0x0170),
    ("/Uhungarumlaut", 0x0170),
    ("/Umacron", 0x016A),
    ("/Uogonek", 0x0172),
    ("/Uring", 0x016E),
    ("/Utilde", 0x0168),
    ("/Wcircumflex", 0x0174),
    ("/Ycircumflex", 0x0176),
    ("/Ydieresis", 0x0178),
    ("/Zacute", 0x0179),
    ("/Zcaron", 0x017D),
    ("/Zdot", 0x017B),
    ("/Zdotaccent", 0x017B),
    ("/abreve", 0x0103),
    ("/amacron", 0x0101),
    ("/aogonek", 0x0105),
    ("/cacute", 0x0107),
    ("/ccaron", 0x010D),
    ("/ccircumflex", 0x0109),
    ("/cdot", 0x010B),
    ("/cdotaccent", 0x010B),
    ("/dcaron", 0x010F),
    ("/dcroat", 0x0111),
    ("/dmacron", 0x0111),
    ("/dotlessi", 0x0131),
    ("/ebreve", 0x0115),
    ("/ecaron", 0x011B),
    ("/edot", 0x0117),
    ("/edotaccent", 0x0117),
    ("/emacron", 0x0113),
    ("/eng", 0x014B),
    ("/eogonek", 0x0119),
    ("/gbreve", 0x011F),
    ("/gcedilla", 0x0123),
    ("/gcircumflex", 0x011D),
    ("/gcommaaccent", 0x0123),
    ("/gdot", 0x0121),
    ("/gdotaccent", 0x0121),
    ("/hbar", 0x0127),
    ("/hcircumflex", 0x0125),
    ("/ibreve", 0x012D),
    ("/ij", 0x0133),
    ("/imacron", 0x012B),
    ("/iogonek", 0x012F),
    ("/itilde", 0x0129),
    ("/jcircumflex", 0x0135),
    ("/kcedilla", 0x0137),
    ("/kcommaaccent", 0x0137),
    ("/kgreenlandic", 0x0138),
    ("/lacute", 0x013A),
    ("/lcaron", 0x013E),
    ("/lcedilla", 0x013C),
    ("/lcommaaccent", 0x013C),
    ("/ldot", 0x0140),
    ("/ldotaccent", 0x0140),
    ("/longs", 0x017F),
    ("/lslash", 0x0142),
    ("/nacute", 0x0144),
    ("/napostrophe", 0x0149),
    ("/ncaron", 0x0148),
    ("/ncedilla", 0x0146),
    ("/ncommaaccent", 0x0146),
    ("/obreve", 0x014F),
    ("/odblacute", 0x0151),
    ("/oe", 0x0153),
    ("/ohungarumlaut", 0x0151),
    ("/omacron", 0x014D),
    ("/quoterightn", 0x0149),
    ("/racute", 0x0155),
    ("/rcaron", 0x0159),
    ("/rcedilla", 0x0157),
    ("/rcommaaccent", 0x0157),
    ("/sacute", 0x015B),
    ("/scaron", 0x0161),
    ("/scedilla", 0x015F),
    ("/scircumflex", 0x015D),
    ("/slong", 0x017F),
    ("/tbar", 0x0167),
    ("/tcaron", 0x0165),
    ("/tcedilla", 0x0163),
    ("/tcommaaccent", 0x0163),
    ("/ubreve", 0x016D),
    ("/udblacute", 0x0171),
    ("/uhungarumlaut", 0x0171),
    ("/umacron", 0x016B),
    ("/uogonek", 0x0173),
    ("/uring", 0x016F),
    ("/utilde", 0x0169),
    ("/wcircumflex", 0x0175),
    ("/ycircumflex", 0x0177),
    ("/zacute", 0x017A),
    ("/zcaron", 0x017E),
    ("/zdot", 0x017C),
    ("/zdotaccent", 0x017C),
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
  @test.assert_eq(extractor.charcode_of_codepoint(0x0102), Some(1))
  @test.assert_eq(extractor.charcode_of_codepoint(0x010A), Some(7))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0122), Some(20))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0149), Some(124))
  @test.assert_eq(extractor.charcode_of_codepoint(0x017F), Some(121))
}

///|
test "PdfTextExtractor decodes Latin Extended-B AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/AEacute", 0x01FC),
    ("/AEmacron", 0x01E2),
    ("/Acaron", 0x01CD),
    ("/Adblgrave", 0x0200),
    ("/Adieresismacron", 0x01DE),
    ("/Adotmacron", 0x01E0),
    ("/Ainvertedbreve", 0x0202),
    ("/Aringacute", 0x01FA),
    ("/Bhook", 0x0181),
    ("/Btopbar", 0x0182),
    ("/Chook", 0x0187),
    ("/DZ", 0x01F1),
    ("/DZcaron", 0x01C4),
    ("/Dafrican", 0x0189),
    ("/Dhook", 0x018A),
    ("/Dtopbar", 0x018B),
    ("/Dz", 0x01F2),
    ("/Dzcaron", 0x01C5),
    ("/Edblgrave", 0x0204),
    ("/Einvertedbreve", 0x0206),
    ("/Eopen", 0x0190),
    ("/Ereversed", 0x018E),
    ("/Esh", 0x01A9),
    ("/Ezh", 0x01B7),
    ("/Ezhcaron", 0x01EE),
    ("/Ezhreversed", 0x01B8),
    ("/Fhook", 0x0191),
    ("/Gacute", 0x01F4),
    ("/Gammaafrican", 0x0194),
    ("/Gcaron", 0x01E6),
    ("/Ghook", 0x0193),
    ("/Gstroke", 0x01E4),
    ("/Icaron", 0x01CF),
    ("/Idblgrave", 0x0208),
    ("/Iinvertedbreve", 0x020A),
    ("/Iotaafrican", 0x0196),
    ("/Istroke", 0x0197),
    ("/Kcaron", 0x01E8),
    ("/Khook", 0x0198),
    ("/LJ", 0x01C7),
    ("/Lj", 0x01C8),
    ("/Mturned", 0x019C),
    ("/NJ", 0x01CA),
    ("/Nhookleft", 0x019D),
    ("/Nj", 0x01CB),
    ("/Ocaron", 0x01D1),
    ("/Ocenteredtilde", 0x019F),
    ("/Odblgrave", 0x020C),
    ("/Ohorn", 0x01A0),
    ("/Oi", 0x01A2),
    ("/Oinvertedbreve", 0x020E),
    ("/Oogonek", 0x01EA),
    ("/Oogonekmacron", 0x01EC),
    ("/Oopen", 0x0186),
    ("/Oslashacute", 0x01FE),
    ("/Ostrokeacute", 0x01FE),
    ("/Phook", 0x01A4),
    ("/Rdblgrave", 0x0210),
    ("/Rinvertedbreve", 0x0212),
    ("/Schwa", 0x018F),
    ("/Scommaaccent", 0x0218),
    ("/Thook", 0x01AC),
    ("/Tonefive", 0x01BC),
    ("/Tonesix", 0x0184),
    ("/Tonetwo", 0x01A7),
    ("/Tretroflexhook", 0x01AE),
    ("/Ucaron", 0x01D3),
    ("/Udblgrave", 0x0214),
    ("/Udieresisacute", 0x01D7),
    ("/Udieresiscaron", 0x01D9),
    ("/Udieresisgrave", 0x01DB),
    ("/Udieresismacron", 0x01D5),
    ("/Uhorn", 0x01AF),
    ("/Uinvertedbreve", 0x0216),
    ("/Upsilonafrican", 0x01B1),
    ("/Vhook", 0x01B2),
    ("/Yhook", 0x01B3),
    ("/Zstroke", 0x01B5),
    ("/acaron", 0x01CE),
    ("/adblgrave", 0x0201),
    ("/adieresismacron", 0x01DF),
    ("/adotmacron", 0x01E1),
    ("/aeacute", 0x01FD),
    ("/aemacron", 0x01E3),
    ("/ainvertedbreve", 0x0203),
    ("/aringacute", 0x01FB),
    ("/bstroke", 0x0180),
    ("/btopbar", 0x0183),
    ("/chook", 0x0188),
    ("/clickalveolar", 0x01C2),
    ("/clickdental", 0x01C0),
    ("/clicklateral", 0x01C1),
    ("/clickretroflex", 0x01C3),
    ("/deltaturned", 0x018D),
    ("/dtopbar", 0x018C),
    ("/dz", 0x01F3),
    ("/dzcaron", 0x01C6),
    ("/edblgrave", 0x0205),
    ("/einvertedbreve", 0x0207),
    ("/eshreversedloop", 0x01AA),
    ("/eturned", 0x01DD),
    ("/ezhcaron", 0x01EF),
    ("/ezhreversed", 0x01B9),
    ("/ezhtail", 0x01BA),
    ("/gacute", 0x01F5),
    ("/gcaron", 0x01E7),
    ("/glottalinvertedstroke", 0x01BE),
    ("/gstroke", 0x01E5),
    ("/hv", 0x0195),
    ("/icaron", 0x01D0),
    ("/idblgrave", 0x0209),
    ("/iinvertedbreve", 0x020B),
    ("/jcaron", 0x01F0),
    ("/kcaron", 0x01E9),
    ("/khook", 0x0199),
    ("/lambdastroke", 0x019B),
    ("/lbar", 0x019A),
    ("/lj", 0x01C9),
    ("/nj", 0x01CC),
    ("/nlegrightlong", 0x019E),
    ("/ocaron", 0x01D2),
    ("/odblgrave", 0x020D),
    ("/ohorn", 0x01A1),
    ("/oi", 0x01A3),
    ("/oinvertedbreve", 0x020F),
    ("/oogonek", 0x01EB),
    ("/oogonekmacron", 0x01ED),
    ("/oslashacute", 0x01FF),
    ("/ostrokeacute", 0x01FF),
    ("/phook", 0x01A5),
    ("/rdblgrave", 0x0211),
    ("/rinvertedbreve", 0x0213),
    ("/scommaaccent", 0x0219),
    ("/thook", 0x01AD),
    ("/tonefive", 0x01BD),
    ("/tonesix", 0x0185),
    ("/tonetwo", 0x01A8),
    ("/tpalatalhook", 0x01AB),
    ("/twostroke", 0x01BB),
    ("/ucaron", 0x01D4),
    ("/udblgrave", 0x0215),
    ("/udieresisacute", 0x01D8),
    ("/udieresiscaron", 0x01DA),
    ("/udieresisgrave", 0x01DC),
    ("/udieresismacron", 0x01D6),
    ("/uhorn", 0x01B0),
    ("/uinvertedbreve", 0x0217),
    ("/wynn", 0x01BF),
    ("/yhook", 0x01B4),
    ("/yr", 0x01A6),
    ("/zstroke", 0x01B6),
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
  @test.assert_eq(extractor.charcode_of_codepoint(0x01FC), Some(1))
  @test.assert_eq(extractor.charcode_of_codepoint(0x01FE), Some(55))
  @test.assert_eq(extractor.charcode_of_codepoint(0x01FF), Some(128))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0219), Some(133))
}

///|
test "PdfTextExtractor decodes private-use AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/Acute", 0xF6C9),
    ("/Caron", 0xF6CA),
    ("/Dieresis", 0xF6CB),
    ("/DieresisAcute", 0xF6CC),
    ("/DieresisGrave", 0xF6CD),
    ("/Grave", 0xF6CE),
    ("/Hungarumlaut", 0xF6CF),
    ("/LL", 0xF6BF),
    ("/Macron", 0xF6D0),
    ("/afii10063", 0xF6C4),
    ("/afii10064", 0xF6C5),
    ("/afii10192", 0xF6C6),
    ("/afii10831", 0xF6C7),
    ("/afii10832", 0xF6C8),
    ("/apple", 0xF8FF),
    ("/commaaccent", 0xF6C3),
    ("/cyrBreve", 0xF6D1),
    ("/cyrFlex", 0xF6D2),
    ("/cyrbreve", 0xF6D4),
    ("/cyrflex", 0xF6D5),
    ("/dblGrave", 0xF6D3),
    ("/dblgrave", 0xF6D6),
    ("/dieresisacute", 0xF6D7),
    ("/dieresisgrave", 0xF6D8),
    ("/dollarsuperior", 0xF6E4),
    ("/dotlessj", 0xF6BE),
    ("/ll", 0xF6C0),
    ("/maichattawalowleftthai", 0xF895),
    ("/maichattawalowrightthai", 0xF894),
    ("/maichattawaupperleftthai", 0xF893),
    ("/maieklowleftthai", 0xF88C),
    ("/maieklowrightthai", 0xF88B),
    ("/maiekupperleftthai", 0xF88A),
    ("/maihanakatleftthai", 0xF884),
    ("/maitaikhuleftthai", 0xF889),
    ("/maitholowleftthai", 0xF88F),
    ("/maitholowrightthai", 0xF88E),
    ("/maithoupperleftthai", 0xF88D),
    ("/maitrilowleftthai", 0xF892),
    ("/maitrilowrightthai", 0xF891),
    ("/maitriupperleftthai", 0xF890),
    ("/nikhahitleftthai", 0xF899),
    ("/saraiileftthai", 0xF886),
    ("/saraileftthai", 0xF885),
    ("/saraueeleftthai", 0xF888),
    ("/saraueleftthai", 0xF887),
    ("/thanthakhatlowleftthai", 0xF898),
    ("/thanthakhatlowrightthai", 0xF897),
    ("/thanthakhatupperleftthai", 0xF896),
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
  @test.assert_eq(extractor.charcode_of_codepoint(0xF6C9), Some(1))
  @test.assert_eq(extractor.charcode_of_codepoint(0xF8FF), Some(15))
  @test.assert_eq(extractor.charcode_of_codepoint(0xF6BE), Some(26))
  @test.assert_eq(extractor.charcode_of_codepoint(0xF896), Some(49))
}

///|
test "PdfTextExtractor decodes Halfwidth and Fullwidth AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/Amonospace", 0xFF21),
    ("/Bmonospace", 0xFF22),
    ("/Cmonospace", 0xFF23),
    ("/Dmonospace", 0xFF24),
    ("/Emonospace", 0xFF25),
    ("/Fmonospace", 0xFF26),
    ("/Gmonospace", 0xFF27),
    ("/Hmonospace", 0xFF28),
    ("/Imonospace", 0xFF29),
    ("/Jmonospace", 0xFF2A),
    ("/Kmonospace", 0xFF2B),
    ("/Lmonospace", 0xFF2C),
    ("/Mmonospace", 0xFF2D),
    ("/Nmonospace", 0xFF2E),
    ("/Omonospace", 0xFF2F),
    ("/Pmonospace", 0xFF30),
    ("/Qmonospace", 0xFF31),
    ("/Rmonospace", 0xFF32),
    ("/Smonospace", 0xFF33),
    ("/Tmonospace", 0xFF34),
    ("/Umonospace", 0xFF35),
    ("/Vmonospace", 0xFF36),
    ("/Wmonospace", 0xFF37),
    ("/Xmonospace", 0xFF38),
    ("/Ymonospace", 0xFF39),
    ("/Zmonospace", 0xFF3A),
    ("/akatakanahalfwidth", 0xFF71),
    ("/amonospace", 0xFF41),
    ("/ampersandmonospace", 0xFF06),
    ("/asciicircummonospace", 0xFF3E),
    ("/asciitildemonospace", 0xFF5E),
    ("/asmallkatakanahalfwidth", 0xFF67),
    ("/asteriskmonospace", 0xFF0A),
    ("/atmonospace", 0xFF20),
    ("/backslashmonospace", 0xFF3C),
    ("/barmonospace", 0xFF5C),
    ("/bmonospace", 0xFF42),
    ("/braceleftmonospace", 0xFF5B),
    ("/bracerightmonospace", 0xFF5D),
    ("/bracketleftmonospace", 0xFF3B),
    ("/bracketrightmonospace", 0xFF3D),
    ("/centmonospace", 0xFFE0),
    ("/cmonospace", 0xFF43),
    ("/colonmonospace", 0xFF1A),
    ("/commamonospace", 0xFF0C),
    ("/cornerbracketlefthalfwidth", 0xFF62),
    ("/cornerbracketrighthalfwidth", 0xFF63),
    ("/dmonospace", 0xFF44),
    ("/dollarmonospace", 0xFF04),
    ("/eightmonospace", 0xFF18),
    ("/ekatakanahalfwidth", 0xFF74),
    ("/emonospace", 0xFF45),
    ("/equalmonospace", 0xFF1D),
    ("/esmallkatakanahalfwidth", 0xFF6A),
    ("/exclammonospace", 0xFF01),
    ("/fivemonospace", 0xFF15),
    ("/fmonospace", 0xFF46),
    ("/fourmonospace", 0xFF14),
    ("/gmonospace", 0xFF47),
    ("/gravemonospace", 0xFF40),
    ("/greatermonospace", 0xFF1E),
    ("/hakatakanahalfwidth", 0xFF8A),
    ("/hekatakanahalfwidth", 0xFF8D),
    ("/hikatakanahalfwidth", 0xFF8B),
    ("/hmonospace", 0xFF48),
    ("/hokatakanahalfwidth", 0xFF8E),
    ("/hukatakanahalfwidth", 0xFF8C),
    ("/hyphenmonospace", 0xFF0D),
    ("/ideographiccommaleft", 0xFF64),
    ("/ikatakanahalfwidth", 0xFF72),
    ("/imonospace", 0xFF49),
    ("/ismallkatakanahalfwidth", 0xFF68),
    ("/jmonospace", 0xFF4A),
    ("/kakatakanahalfwidth", 0xFF76),
    ("/katahiraprolongmarkhalfwidth", 0xFF70),
    ("/kekatakanahalfwidth", 0xFF79),
    ("/kikatakanahalfwidth", 0xFF77),
    ("/kmonospace", 0xFF4B),
    ("/kokatakanahalfwidth", 0xFF7A),
    ("/kukatakanahalfwidth", 0xFF78),
    ("/lessmonospace", 0xFF1C),
    ("/lmonospace", 0xFF4C),
    ("/macronmonospace", 0xFFE3),
    ("/makatakanahalfwidth", 0xFF8F),
    ("/mekatakanahalfwidth", 0xFF92),
    ("/middledotkatakanahalfwidth", 0xFF65),
    ("/mikatakanahalfwidth", 0xFF90),
    ("/mmonospace", 0xFF4D),
    ("/mokatakanahalfwidth", 0xFF93),
    ("/mukatakanahalfwidth", 0xFF91),
    ("/nakatakanahalfwidth", 0xFF85),
    ("/nekatakanahalfwidth", 0xFF88),
    ("/nikatakanahalfwidth", 0xFF86),
    ("/ninemonospace", 0xFF19),
    ("/nkatakanahalfwidth", 0xFF9D),
    ("/nmonospace", 0xFF4E),
    ("/nokatakanahalfwidth", 0xFF89),
    ("/nukatakanahalfwidth", 0xFF87),
    ("/numbersignmonospace", 0xFF03),
    ("/okatakanahalfwidth", 0xFF75),
    ("/omonospace", 0xFF4F),
    ("/onemonospace", 0xFF11),
    ("/osmallkatakanahalfwidth", 0xFF6B),
    ("/parenleftmonospace", 0xFF08),
    ("/parenrightmonospace", 0xFF09),
    ("/percentmonospace", 0xFF05),
    ("/periodhalfwidth", 0xFF61),
    ("/periodmonospace", 0xFF0E),
    ("/plusmonospace", 0xFF0B),
    ("/pmonospace", 0xFF50),
    ("/qmonospace", 0xFF51),
    ("/questionmonospace", 0xFF1F),
    ("/quotedblmonospace", 0xFF02),
    ("/quotesinglemonospace", 0xFF07),
    ("/rakatakanahalfwidth", 0xFF97),
    ("/rekatakanahalfwidth", 0xFF9A),
    ("/rikatakanahalfwidth", 0xFF98),
    ("/rmonospace", 0xFF52),
    ("/rokatakanahalfwidth", 0xFF9B),
    ("/rukatakanahalfwidth", 0xFF99),
    ("/sakatakanahalfwidth", 0xFF7B),
    ("/sekatakanahalfwidth", 0xFF7E),
    ("/semicolonmonospace", 0xFF1B),
    ("/semivoicedmarkkanahalfwidth", 0xFF9F),
    ("/sevenmonospace", 0xFF17),
    ("/sikatakanahalfwidth", 0xFF7C),
    ("/sixmonospace", 0xFF16),
    ("/slashmonospace", 0xFF0F),
    ("/smonospace", 0xFF53),
    ("/sokatakanahalfwidth", 0xFF7F),
    ("/sterlingmonospace", 0xFFE1),
    ("/sukatakanahalfwidth", 0xFF7D),
    ("/takatakanahalfwidth", 0xFF80),
    ("/tekatakanahalfwidth", 0xFF83),
    ("/threemonospace", 0xFF13),
    ("/tikatakanahalfwidth", 0xFF81),
    ("/tmonospace", 0xFF54),
    ("/tokatakanahalfwidth", 0xFF84),
    ("/tukatakanahalfwidth", 0xFF82),
    ("/tusmallkatakanahalfwidth", 0xFF6F),
    ("/twomonospace", 0xFF12),
    ("/ukatakanahalfwidth", 0xFF73),
    ("/umonospace", 0xFF55),
    ("/underscoremonospace", 0xFF3F),
    ("/usmallkatakanahalfwidth", 0xFF69),
    ("/vmonospace", 0xFF56),
    ("/voicedmarkkanahalfwidth", 0xFF9E),
    ("/wakatakanahalfwidth", 0xFF9C),
    ("/wmonospace", 0xFF57),
    ("/wokatakanahalfwidth", 0xFF66),
    ("/wonmonospace", 0xFFE6),
    ("/xmonospace", 0xFF58),
    ("/yakatakanahalfwidth", 0xFF94),
    ("/yasmallkatakanahalfwidth", 0xFF6C),
    ("/yenmonospace", 0xFFE5),
    ("/ymonospace", 0xFF59),
    ("/yokatakanahalfwidth", 0xFF96),
    ("/yosmallkatakanahalfwidth", 0xFF6E),
    ("/yukatakanahalfwidth", 0xFF95),
    ("/yusmallkatakanahalfwidth", 0xFF6D),
    ("/zeromonospace", 0xFF10),
    ("/zmonospace", 0xFF5A),
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
  @test.assert_eq(extractor.charcode_of_codepoint(0xFF21), Some(1))
  @test.assert_eq(extractor.charcode_of_codepoint(0xFFE0), Some(42))
  @test.assert_eq(extractor.charcode_of_codepoint(0xFF61), Some(107))
  @test.assert_eq(extractor.charcode_of_codepoint(0xFF5A), Some(162))
}

///|
test "PdfTextExtractor decodes TrueType Gxx glyph names" {
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(
      PdfHelvetica,
      PdfCustomEncoding(PdfStandardEncoding, [
        text_difference_for_test("/G82", 1),
        text_difference_for_test("/G8a", 2),
        text_difference_for_test("/G8A", 3),
        text_difference_for_test("/G6D", 4),
        text_difference_for_test("/Gf0.alt", 5),
        text_difference_for_test("/GG2", 6),
        text_difference_for_test("/G2G", 7),
        text_difference_for_test("/G81", 8),
        text_difference_for_test("/GA6", 9),
        text_difference_for_test("/Ga6", 10),
      ]),
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(
      text_bytes_for_test([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]),
    ),
    [0x201A, 0x0160, 0x008A, 0x002D, 0x00F0, 6, 7, 8, 0x00B6, 0x00A6],
  )
  @test.assert_eq(
    try! extractor.glyphnames_of_text(
      text_bytes_for_test([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]),
    ),
    [
      text_name_for_test("/G82"),
      text_name_for_test("/G8a"),
      text_name_for_test("/G8A"),
      text_name_for_test("/G6D"),
      text_name_for_test("/Gf0.alt"),
      text_name_for_test("/GG2"),
      text_name_for_test("/G2G"),
      text_name_for_test("/G81"),
      text_name_for_test("/GA6"),
      text_name_for_test("/Ga6"),
    ],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x201A), Some(1))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0160), Some(2))
  @test.assert_eq(extractor.charcode_of_codepoint(0x008A), Some(3))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00F0), Some(5))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00B6), Some(9))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00A6), Some(10))
}

///|
test "PdfTextExtractor decodes control glyph names" {
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(
      PdfHelvetica,
      PdfCustomEncoding(PdfStandardEncoding, [
        text_difference_for_test("/controlCR", 1),
        text_difference_for_test("/controlLF", 2),
        text_difference_for_test("/controlHT", 3),
        text_difference_for_test("/controlFF", 4),
      ]),
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(text_bytes_for_test([1, 2, 3, 4])),
    [13, 10, 9, 12],
  )
  @test.assert_eq(
    try! extractor.glyphnames_of_text(text_bytes_for_test([1, 2, 3, 4])),
    [
      text_name_for_test("/controlCR"),
      text_name_for_test("/controlLF"),
      text_name_for_test("/controlHT"),
      text_name_for_test("/controlFF"),
    ],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(13), Some(1))
  @test.assert_eq(extractor.charcode_of_codepoint(10), Some(2))
  @test.assert_eq(extractor.charcode_of_codepoint(9), Some(3))
  @test.assert_eq(extractor.charcode_of_codepoint(12), Some(4))
}
