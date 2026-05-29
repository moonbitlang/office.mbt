///|
fn text_extractor_agl_extra_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn text_extractor_agl_extra_bytes_for_test(
  values : ArrayView[Int],
) -> @pdflite.PdfBytes {
  try! @pdflite.pdf_bytes_of_int_array(values)
}

///|
fn text_extractor_agl_extra_difference_for_test(
  name : String,
  code : Int,
) -> @pdflite.PdfEncodingDifference {
  { name: text_extractor_agl_extra_name_for_test(name), code }
}

///|
fn text_extractor_agl_extra_standard_font_data_for_test(
  font : @pdflite.PdfStandardFont,
  encoding : @pdflite.PdfEncoding,
) -> @pdflite.PdfStandardFontData {
  { font, encoding }
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
    differences.push(
      text_extractor_agl_extra_difference_for_test(entry.0, code),
    )
    text_codes.push(code)
    expected_codepoints.push(entry.1)
  }
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_extractor_agl_extra_standard_font_data_for_test(
      PdfHelvetica,
      PdfCustomEncoding(PdfStandardEncoding, differences),
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(
      text_extractor_agl_extra_bytes_for_test(text_codes),
    ),
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
    differences.push(
      text_extractor_agl_extra_difference_for_test(entry.0, code),
    )
    text_codes.push(code)
    expected_codepoints.push(entry.1)
  }
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_extractor_agl_extra_standard_font_data_for_test(
      PdfHelvetica,
      PdfCustomEncoding(PdfStandardEncoding, differences),
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(
      text_extractor_agl_extra_bytes_for_test(text_codes),
    ),
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
    differences.push(
      text_extractor_agl_extra_difference_for_test(entry.0, code),
    )
    text_codes.push(code)
    expected_codepoints.push(entry.1)
  }
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_extractor_agl_extra_standard_font_data_for_test(
      PdfHelvetica,
      PdfCustomEncoding(PdfStandardEncoding, differences),
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(
      text_extractor_agl_extra_bytes_for_test(text_codes),
    ),
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
    differences.push(
      text_extractor_agl_extra_difference_for_test(entry.0, code),
    )
    text_codes.push(code)
    expected_codepoints.push(entry.1)
  }
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_extractor_agl_extra_standard_font_data_for_test(
      PdfHelvetica,
      PdfCustomEncoding(PdfStandardEncoding, differences),
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(
      text_extractor_agl_extra_bytes_for_test(text_codes),
    ),
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
    differences.push(
      text_extractor_agl_extra_difference_for_test(entry.0, code),
    )
    text_codes.push(code)
    expected_codepoints.push(entry.1)
  }
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_extractor_agl_extra_standard_font_data_for_test(
      PdfHelvetica,
      PdfCustomEncoding(PdfStandardEncoding, differences),
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(
      text_extractor_agl_extra_bytes_for_test(text_codes),
    ),
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
    differences.push(
      text_extractor_agl_extra_difference_for_test(entry.0, code),
    )
    text_codes.push(code)
    expected_codepoints.push(entry.1)
  }
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_extractor_agl_extra_standard_font_data_for_test(
      PdfHelvetica,
      PdfCustomEncoding(PdfStandardEncoding, differences),
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(
      text_extractor_agl_extra_bytes_for_test(text_codes),
    ),
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
    differences.push(
      text_extractor_agl_extra_difference_for_test(entry.0, code),
    )
    text_codes.push(code)
    expected_codepoints.push(entry.1)
  }
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_extractor_agl_extra_standard_font_data_for_test(
      PdfHelvetica,
      PdfCustomEncoding(PdfStandardEncoding, differences),
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(
      text_extractor_agl_extra_bytes_for_test(text_codes),
    ),
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
    differences.push(
      text_extractor_agl_extra_difference_for_test(entry.0, code),
    )
    text_codes.push(code)
    expected_codepoints.push(entry.1)
  }
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_extractor_agl_extra_standard_font_data_for_test(
      PdfHelvetica,
      PdfCustomEncoding(PdfStandardEncoding, differences),
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(
      text_extractor_agl_extra_bytes_for_test(text_codes),
    ),
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
    differences.push(
      text_extractor_agl_extra_difference_for_test(entry.0, code),
    )
    text_codes.push(code)
    expected_codepoints.push(entry.1)
  }
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_extractor_agl_extra_standard_font_data_for_test(
      PdfHelvetica,
      PdfCustomEncoding(PdfStandardEncoding, differences),
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(
      text_extractor_agl_extra_bytes_for_test(text_codes),
    ),
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
    differences.push(
      text_extractor_agl_extra_difference_for_test(entry.0, code),
    )
    text_codes.push(code)
    expected_codepoints.push(entry.1)
  }
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_extractor_agl_extra_standard_font_data_for_test(
      PdfHelvetica,
      PdfCustomEncoding(PdfStandardEncoding, differences),
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(
      text_extractor_agl_extra_bytes_for_test(text_codes),
    ),
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
    differences.push(
      text_extractor_agl_extra_difference_for_test(entry.0, code),
    )
    text_codes.push(code)
    expected_codepoints.push(entry.1)
  }
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_extractor_agl_extra_standard_font_data_for_test(
      PdfHelvetica,
      PdfCustomEncoding(PdfStandardEncoding, differences),
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(
      text_extractor_agl_extra_bytes_for_test(text_codes),
    ),
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
    differences.push(
      text_extractor_agl_extra_difference_for_test(entry.0, code),
    )
    text_codes.push(code)
    expected_codepoints.push(entry.1)
  }
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_extractor_agl_extra_standard_font_data_for_test(
      PdfHelvetica,
      PdfCustomEncoding(PdfStandardEncoding, differences),
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(
      text_extractor_agl_extra_bytes_for_test(text_codes),
    ),
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
    differences.push(
      text_extractor_agl_extra_difference_for_test(entry.0, code),
    )
    text_codes.push(code)
    expected_codepoints.push(entry.1)
  }
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_extractor_agl_extra_standard_font_data_for_test(
      PdfHelvetica,
      PdfCustomEncoding(PdfStandardEncoding, differences),
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(
      text_extractor_agl_extra_bytes_for_test(text_codes),
    ),
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
    differences.push(
      text_extractor_agl_extra_difference_for_test(entry.0, code),
    )
    text_codes.push(code)
    expected_codepoints.push(entry.1)
  }
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_extractor_agl_extra_standard_font_data_for_test(
      PdfHelvetica,
      PdfCustomEncoding(PdfStandardEncoding, differences),
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(
      text_extractor_agl_extra_bytes_for_test(text_codes),
    ),
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
    differences.push(
      text_extractor_agl_extra_difference_for_test(entry.0, code),
    )
    text_codes.push(code)
    expected_codepoints.push(entry.1)
  }
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_extractor_agl_extra_standard_font_data_for_test(
      PdfHelvetica,
      PdfCustomEncoding(PdfStandardEncoding, differences),
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(
      text_extractor_agl_extra_bytes_for_test(text_codes),
    ),
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
    text_extractor_agl_extra_standard_font_data_for_test(
      PdfHelvetica,
      PdfCustomEncoding(PdfStandardEncoding, [
        text_extractor_agl_extra_difference_for_test("/G82", 1),
        text_extractor_agl_extra_difference_for_test("/G8a", 2),
        text_extractor_agl_extra_difference_for_test("/G8A", 3),
        text_extractor_agl_extra_difference_for_test("/G6D", 4),
        text_extractor_agl_extra_difference_for_test("/Gf0.alt", 5),
        text_extractor_agl_extra_difference_for_test("/GG2", 6),
        text_extractor_agl_extra_difference_for_test("/G2G", 7),
        text_extractor_agl_extra_difference_for_test("/G81", 8),
        text_extractor_agl_extra_difference_for_test("/GA6", 9),
        text_extractor_agl_extra_difference_for_test("/Ga6", 10),
      ]),
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(
      text_extractor_agl_extra_bytes_for_test([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]),
    ),
    [0x201A, 0x0160, 0x008A, 0x002D, 0x00F0, 6, 7, 8, 0x00B6, 0x00A6],
  )
  @test.assert_eq(
    try! extractor.glyphnames_of_text(
      text_extractor_agl_extra_bytes_for_test([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]),
    ),
    [
      text_extractor_agl_extra_name_for_test("/G82"),
      text_extractor_agl_extra_name_for_test("/G8a"),
      text_extractor_agl_extra_name_for_test("/G8A"),
      text_extractor_agl_extra_name_for_test("/G6D"),
      text_extractor_agl_extra_name_for_test("/Gf0.alt"),
      text_extractor_agl_extra_name_for_test("/GG2"),
      text_extractor_agl_extra_name_for_test("/G2G"),
      text_extractor_agl_extra_name_for_test("/G81"),
      text_extractor_agl_extra_name_for_test("/GA6"),
      text_extractor_agl_extra_name_for_test("/Ga6"),
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
    text_extractor_agl_extra_standard_font_data_for_test(
      PdfHelvetica,
      PdfCustomEncoding(PdfStandardEncoding, [
        text_extractor_agl_extra_difference_for_test("/controlCR", 1),
        text_extractor_agl_extra_difference_for_test("/controlLF", 2),
        text_extractor_agl_extra_difference_for_test("/controlHT", 3),
        text_extractor_agl_extra_difference_for_test("/controlFF", 4),
      ]),
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(
      text_extractor_agl_extra_bytes_for_test([1, 2, 3, 4]),
    ),
    [13, 10, 9, 12],
  )
  @test.assert_eq(
    try! extractor.glyphnames_of_text(
      text_extractor_agl_extra_bytes_for_test([1, 2, 3, 4]),
    ),
    [
      text_extractor_agl_extra_name_for_test("/controlCR"),
      text_extractor_agl_extra_name_for_test("/controlLF"),
      text_extractor_agl_extra_name_for_test("/controlHT"),
      text_extractor_agl_extra_name_for_test("/controlFF"),
    ],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(13), Some(1))
  @test.assert_eq(extractor.charcode_of_codepoint(10), Some(2))
  @test.assert_eq(extractor.charcode_of_codepoint(9), Some(3))
  @test.assert_eq(extractor.charcode_of_codepoint(12), Some(4))
}
