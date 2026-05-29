// Whitebox tests for text glyph extraction internals.
// Public text behavior belongs in `_test.mbt` files.

///|
fn wbtest_text_bytes(values : ArrayView[Int]) -> PdfBytes {
  try! pdf_bytes_of_int_array(values)
}

///|
fn wbtest_text_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn wbtest_text_simple_font(
  encoding : PdfEncoding,
  descriptor : PdfFontDescriptor?,
) -> PdfFont {
  PdfFontSimple({
    fonttype: PdfType1,
    basefont: None,
    firstchar: 0,
    lastchar: 0,
    widths: [],
    fontdescriptor: descriptor,
    fontmetrics: None,
    encoding,
  })
}

///|
test "private text glyph helpers cover fallback and CID ToUnicode branches" {
  let implicit : PdfEncoding = PdfImplicitInFontFile
  @test.assert_eq(implicit.pdf_text_glyphname_of_charcode(65), None)
  let filled : PdfEncoding = PdfFillUndefinedWithStandard(PdfImplicitInFontFile)
  @test.assert_eq(
    filled.pdf_text_glyphname_of_charcode(65),
    Some(wbtest_text_name("/A")),
  )
  let filled_existing : PdfEncoding = PdfFillUndefinedWithStandard(
    PdfWinAnsiEncoding,
  )
  @test.assert_eq(
    filled_existing.pdf_text_glyphname_of_charcode(65),
    Some(wbtest_text_name("/A")),
  )
  let simple = wbtest_text_simple_font(PdfWinAnsiEncoding, None)
  @test.assert_eq(
    simple.pdf_text_glyphname_of_charcode(65),
    Some(wbtest_text_name("/A")),
  )
  @test.assert_eq(simple.pdf_text_uses_symbol_codepoints(), false)

  let basic_latin_entries : Array[(String, Int)] = [
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
  for entry in basic_latin_entries {
    @test.assert_eq(
      pdf_text_codepoint_of_basic_latin_glyphname(wbtest_text_name(entry.0)),
      Some(entry.1),
    )
  }
  @test.assert_eq(
    pdf_text_codepoint_of_basic_latin_glyphname(wbtest_text_name("/not-basic")),
    None,
  )
  let cjk_symbol_entries : Array[(String, Int)] = [
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
  for entry in cjk_symbol_entries {
    @test.assert_eq(
      pdf_text_codepoint_of_cjk_symbol_glyphname(wbtest_text_name(entry.0)),
      Some(entry.1),
    )
  }
  @test.assert_eq(
    pdf_text_codepoint_of_cjk_symbol_glyphname(
      wbtest_text_name("/not-cjk-symbol"),
    ),
    None,
  )
  let hiragana_entries : Array[(String, Int)] = [
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
  for entry in hiragana_entries {
    @test.assert_eq(
      pdf_text_codepoint_of_hiragana_glyphname(wbtest_text_name(entry.0)),
      Some(entry.1),
    )
  }
  @test.assert_eq(
    pdf_text_codepoint_of_hiragana_glyphname(wbtest_text_name("/not-hiragana")),
    None,
  )
  let katakana_entries : Array[(String, Int)] = [
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
  for entry in katakana_entries {
    @test.assert_eq(
      pdf_text_codepoint_of_katakana_glyphname(wbtest_text_name(entry.0)),
      Some(entry.1),
    )
  }
  @test.assert_eq(
    pdf_text_codepoint_of_katakana_glyphname(wbtest_text_name("/not-katakana")),
    None,
  )
  let bopomofo_entries : Array[(String, Int)] = [
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
  for entry in bopomofo_entries {
    @test.assert_eq(
      pdf_text_codepoint_of_bopomofo_glyphname(wbtest_text_name(entry.0)),
      Some(entry.1),
    )
  }
  @test.assert_eq(
    pdf_text_codepoint_of_bopomofo_glyphname(wbtest_text_name("/not-bopomofo")),
    None,
  )
  let hangul_compat_jamo_entries : Array[(String, Int)] = [
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
  for entry in hangul_compat_jamo_entries {
    @test.assert_eq(
      pdf_text_codepoint_of_hangul_compat_jamo_glyphname(
        wbtest_text_name(entry.0),
      ),
      Some(entry.1),
    )
  }
  @test.assert_eq(
    pdf_text_codepoint_of_hangul_compat_jamo_glyphname(
      wbtest_text_name("/not-hangul-compat-jamo"),
    ),
    None,
  )
  let enclosed_cjk_entries : Array[(String, Int)] = [
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
  for entry in enclosed_cjk_entries {
    @test.assert_eq(
      pdf_text_codepoint_of_enclosed_cjk_glyphname(wbtest_text_name(entry.0)),
      Some(entry.1),
    )
  }
  @test.assert_eq(
    pdf_text_codepoint_of_enclosed_cjk_glyphname(
      wbtest_text_name("/not-enclosed-cjk"),
    ),
    None,
  )
  let armenian_entries : Array[(String, Int)] = [
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
  for entry in armenian_entries {
    @test.assert_eq(
      pdf_text_codepoint_of_armenian_glyphname(wbtest_text_name(entry.0)),
      Some(entry.1),
    )
  }
  @test.assert_eq(
    pdf_text_codepoint_of_armenian_glyphname(wbtest_text_name("/not-armenian")),
    None,
  )
  let devanagari_entries : Array[(String, Int)] = [
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
  for entry in devanagari_entries {
    @test.assert_eq(
      pdf_text_codepoint_of_devanagari_glyphname(wbtest_text_name(entry.0)),
      Some(entry.1),
    )
  }
  @test.assert_eq(
    pdf_text_codepoint_of_devanagari_glyphname(wbtest_text_name("/not-deva")),
    None,
  )
  let thai_entries : Array[(String, Int)] = [
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
  for entry in thai_entries {
    @test.assert_eq(
      pdf_text_codepoint_of_thai_glyphname(wbtest_text_name(entry.0)),
      Some(entry.1),
    )
  }
  @test.assert_eq(
    pdf_text_codepoint_of_thai_glyphname(wbtest_text_name("/not-thai")),
    None,
  )
  let private_use_entries : Array[(String, Int)] = [
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
  for entry in private_use_entries {
    @test.assert_eq(
      pdf_text_codepoint_of_private_use_glyphname(wbtest_text_name(entry.0)),
      Some(entry.1),
    )
  }
  @test.assert_eq(
    pdf_text_codepoint_of_private_use_glyphname(
      wbtest_text_name("/not-private-use"),
    ),
    None,
  )
  let half_fullwidth_entries : Array[(String, Int)] = [
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
  for entry in half_fullwidth_entries {
    @test.assert_eq(
      pdf_text_codepoint_of_half_fullwidth_glyphname(wbtest_text_name(entry.0)),
      Some(entry.1),
    )
  }
  @test.assert_eq(
    pdf_text_codepoint_of_half_fullwidth_glyphname(
      wbtest_text_name("/not-half-fullwidth"),
    ),
    None,
  )
  @test.assert_eq(
    pdf_text_codepoint_of_punctuation_glyphname(
      wbtest_text_name("/twosuperior"),
    ),
    Some(0x00B2),
  )
  @test.assert_eq(
    pdf_text_codepoint_of_punctuation_glyphname(
      wbtest_text_name("/threesuperior"),
    ),
    Some(0x00B3),
  )
  @test.assert_eq(
    pdf_text_codepoint_of_punctuation_glyphname(
      wbtest_text_name("/onesuperior"),
    ),
    Some(0x00B9),
  )
  @test.assert_eq(
    pdf_text_codepoint_of_symbol_glyphname(wbtest_text_name("/logicalnot")),
    Some(0x00AC),
  )
  @test.assert_eq(
    pdf_text_codepoint_of_symbol_glyphname(wbtest_text_name("/degree")),
    Some(0x00B0),
  )
  @test.assert_eq(
    pdf_text_codepoint_of_symbol_glyphname(wbtest_text_name("/florin")),
    Some(0x0192),
  )
  @test.assert_eq(
    pdf_text_parse_hex_codepoint(@ascii.encode("D800"), 0, 4),
    None,
  )
  @test.assert_eq(
    pdf_text_uni_glyphname_codepoints(@ascii.encode("/uniD800")),
    None,
  )
  @test.assert_eq(
    pdf_text_codepoints_of_glyphname(wbtest_text_name("/twosuperior.alt")),
    Some([0x00B2]),
  )
  @test.assert_eq(
    pdf_text_codepoints_of_glyphname(wbtest_text_name("/!")),
    None,
  )

  let fallback_font = wbtest_text_simple_font(
    PdfCustomEncoding(PdfImplicitInFontFile, [
      { name: wbtest_text_name("/unknown"), code: 65 },
    ]),
    None,
  )
  let fallback_extractor = fallback_font.text_extractor()
  @test.assert_eq(fallback_extractor.pdf_text_encoded_glyph_of_charcode(65), {
    glyphname: wbtest_text_name("/unknown"),
    codepoints: [65],
  })

  let invalid_tounicode = [(65, wbtest_text_bytes([0]))]
  let invalid_font = wbtest_text_simple_font(
    PdfWinAnsiEncoding,
    Some({
      ..pdf_text_empty_font_descriptor(),
      tounicode: Some(invalid_tounicode),
    }),
  )
  let invalid_extractor = invalid_font.text_extractor()
  @test.assert_eq(
    try! invalid_extractor.codepoints_of_text(wbtest_text_bytes([65])),
    [65],
  )
  @test.assert_eq(invalid_extractor.charcode_of_codepoint(65), None)

  let tounicode = [(65, wbtest_text_bytes([0x00, 0x41]))]
  let cid_font : PdfFont = PdfFontCIDKeyed({
    basefont: wbtest_text_name("/Top"),
    composite: {
      cid_system_info: {
        registry: wbtest_text_bytes([82]),
        ordering: wbtest_text_bytes([79]),
        supplement: 0,
      },
      cid_basefont: wbtest_text_name("/Descendant"),
      cid_fontdescriptor: pdf_text_empty_font_descriptor(),
      cid_widths: [],
      cid_widths2: [],
      cid_default_width: 1000.0,
      cid_default_width2: [880.0, -1000.0],
    },
    encoding: PdfPredefinedCMap(wbtest_text_name("/Identity-H")),
  })
  let cid_with_tounicode = cid_font.pdf_text_with_tounicode(Some(tounicode))
  @test.assert_eq(cid_with_tounicode.pdf_text_tounicode(), Some(tounicode))
  let standard_font : PdfFont = PdfFontStandard({
    font: PdfHelvetica,
    encoding: PdfWinAnsiEncoding,
  })
  @test.assert_eq(
    standard_font.pdf_text_with_tounicode(Some(tounicode)),
    standard_font,
  )
  @test.assert_eq(pdf_text_cns1_codepoint_of_cid(-1), None)
  @test.assert_eq(pdf_text_cns1_codepoint_of_cid(0), None)
  @test.assert_eq(
    pdf_text_cns1_codepoint_of_cid(pdf_text_cns1_unicode_table.length()),
    None,
  )
  @test.assert_eq(pdf_text_gb1_codepoint_of_cid(-1), None)
  @test.assert_eq(pdf_text_gb1_codepoint_of_cid(0), None)
  @test.assert_eq(
    pdf_text_gb1_codepoint_of_cid(pdf_text_gb1_unicode_table.length()),
    None,
  )
  @test.assert_eq(
    pdf_text_predefined_cid_range_charcode_of_cid(
      [(0x81308436, 0x81308436, 1), (0x0000FE51, 0x0000FE51, 1)],
      1,
    ),
    Some(0x0000FE51),
  )
  @test.assert_eq(
    pdf_text_predefined_cid_range_lookup_unsigned(
      [(0x20, 0x7E, 10), (0x8EA2EDA1, 0x8EA2EDA2, 20)],
      0x8EA2EDA2,
    ),
    Some(21),
  )
  @test.assert_eq(
    pdf_text_predefined_cid_range_lookup_unsigned(
      [(0x20, 0x7E, 10), (0x8EA2EDA1, 0x8EA2EDA2, 20)],
      0x80,
    ),
    None,
  )
  @test.assert_eq(
    pdf_text_lower_optional_packed_charcode(Some(0x0000FE51), Some(0x81308436)),
    Some(0x0000FE51),
  )
  @test.assert_eq(
    pdf_text_lower_optional_packed_charcode(Some(0x0000FE51), None),
    Some(0x0000FE51),
  )
  @test.assert_eq(
    pdf_text_predefined_sequence_table_charcode(
      [(3, [0x21]), (1, [0x20]), (2, [0x20, 0xFE00])],
      [(0x81308436, 0x81308436, 1), (0x0000FE51, 0x0000FE51, 1)],
      0x20,
    ),
    Some(0x0000FE51),
  )
  @test.assert_eq(
    pdf_text_predefined_sequence_table_charcode(
      [(3, [0x21])],
      [(0x0000FE51, 0x0000FE51, 1)],
      0x21,
    ),
    None,
  )
  @test.assert_eq(
    pdf_text_predefined_cid_range_charcode_of_cid(
      [(0x81308436, 0x81308436, 1)],
      2,
    ),
    None,
  )
  @test.assert_eq(
    pdf_text_predefined_unicode_table_charcode(
      [0, 0x20, 0x20],
      [(0x81308436, 0x81308436, 1), (0x0000FE51, 0x0000FE51, 2)],
      0x20,
    ),
    Some(0x0000FE51),
  )
  @test.assert_eq(
    pdf_text_predefined_unicode_table_charcode(
      [0, 0x20],
      [(0x0000FE51, 0x0000FE51, 1)],
      0,
    ),
    None,
  )
  @test.assert_eq(
    pdf_text_predefined_codepoint_range_charcode(
      [(1, 1, 0x20)],
      [(0x81308436, 0x81308436, 1), (0x0000FE51, 0x0000FE51, 1)],
      0x20,
    ),
    Some(0x0000FE51),
  )
  @test.assert_eq(
    pdf_text_predefined_codepoint_range_charcode(
      [(1, 1, 0x20)],
      [(0x0000FE51, 0x0000FE51, 1)],
      0x21,
    ),
    None,
  )
  @test.assert_eq(
    pdf_text_predefined_gb1_charcode(
      [(0x81308436, 0x81308436, 1), (0x0000FE51, 0x0000FE51, 1)],
      0x20,
    ),
    Some(0x0000FE51),
  )
  let unknown_vertical_cmap = wbtest_text_name("/Unknown-V")
  guard pdf_text_predefined_gb1_vertical_codepoint_table(unknown_vertical_cmap)
    is None else {
    fail("expected no GB1 vertical table")
  }
  guard pdf_text_predefined_gb1_vertical_charcode_table(unknown_vertical_cmap)
    is None else {
    fail("expected no GB1 vertical reverse table")
  }
  guard pdf_text_predefined_korea1_vertical_codepoint_table(
      unknown_vertical_cmap,
    )
    is None else {
    fail("expected no Korea1 vertical table")
  }
  guard pdf_text_predefined_korea1_vertical_charcode_table(
      unknown_vertical_cmap,
    )
    is None else {
    fail("expected no Korea1 vertical reverse table")
  }
  let japan1_cid_cmaps = [
    "/H", "/V", "/78-H", "/78-V", "/78-EUC-H", "/78-EUC-V", "/78-RKSJ-H", "/78-RKSJ-V",
    "/78ms-RKSJ-H", "/78ms-RKSJ-V", "/83pv-RKSJ-H", "/90ms-RKSJ-H", "/90ms-RKSJ-V",
    "/90msp-RKSJ-H", "/90msp-RKSJ-V", "/90pv-RKSJ-H", "/90pv-RKSJ-V", "/Add-H", "/Add-V",
    "/Add-RKSJ-H", "/Add-RKSJ-V", "/EUC-H", "/EUC-V", "/Ext-H", "/Ext-V", "/Ext-RKSJ-H",
    "/Ext-RKSJ-V", "/Hojo-H", "/Hojo-V", "/Hojo-EUC-H", "/Hojo-EUC-V", "/NWP-H",
    "/NWP-V", "/RKSJ-H", "/RKSJ-V",
  ]
  for cmap in japan1_cid_cmaps {
    guard pdf_text_predefined_japan1_cid_ranges(wbtest_text_name(cmap))
      is Some(_) else {
      fail("expected Japan1 CID ranges for " + cmap)
    }
  }
  guard pdf_text_predefined_japan1_cid_ranges(wbtest_text_name("/Unknown"))
    is None else {
    fail("expected no Japan1 CID ranges for non-oriented CMap")
  }
  guard pdf_text_predefined_japan1_cid_ranges(wbtest_text_name("/Unknown-V"))
    is None else {
    fail("expected no Japan1 CID ranges for unknown vertical CMap")
  }
  guard pdf_text_predefined_japan1_direct_codepoint_ranges(
      wbtest_text_name("/90ms-RKSJ-H"),
    )
    is Some(_) else {
    fail("expected 90ms-RKSJ direct table")
  }
  guard pdf_text_predefined_japan1_direct_codepoint_ranges(
      wbtest_text_name("/90pv-RKSJ-H"),
    )
    is Some(_) else {
    fail("expected 90pv-RKSJ direct table")
  }
  guard pdf_text_predefined_japan1_direct_codepoint_ranges(
      wbtest_text_name("/90ms-RKSJ-V"),
    )
    is None else {
    fail("expected no direct table for vertical RKSJ")
  }
  @test.assert_eq(
    pdf_text_predefined_japan1_direct_codepoint_sequence_table(
      wbtest_text_name("/90ms-RKSJ-H"),
    ).length(),
    0,
  )
  @test.assert_eq(
    pdf_text_predefined_japan1_direct_codepoint_sequence_table(
      wbtest_text_name("/90pv-RKSJ-H"),
    ).length() >
    0,
    true,
  )
  guard pdf_text_predefined_japan1_direct_charcode_ranges(
      wbtest_text_name("/90ms-RKSJ-H"),
    )
    is Some(_) else {
    fail("expected 90ms-RKSJ direct reverse table")
  }
  guard pdf_text_predefined_japan1_direct_charcode_ranges(
      wbtest_text_name("/90pv-RKSJ-H"),
    )
    is Some(_) else {
    fail("expected 90pv-RKSJ direct reverse table")
  }
  guard pdf_text_predefined_japan1_direct_charcode_ranges(
      wbtest_text_name("/90ms-RKSJ-V"),
    )
    is None else {
    fail("expected no direct reverse table for vertical RKSJ")
  }
  @test.assert_eq(
    pdf_text_predefined_cmap_uses_japan1_two_byte_charcodes(
      wbtest_text_name("/H"),
    ),
    true,
  )
  @test.assert_eq(
    pdf_text_predefined_cmap_uses_japan1_two_byte_charcodes(
      wbtest_text_name("/90ms-RKSJ-H"),
    ),
    false,
  )
  @test.assert_eq(
    pdf_text_predefined_cmap_uses_japan1_two_byte_charcodes(
      wbtest_text_name("/EUC-H"),
    ),
    false,
  )
  @test.assert_eq(
    pdf_text_predefined_cmap_uses_hojo_euc_charcodes(
      wbtest_text_name("/Hojo-EUC-H"),
    ),
    true,
  )
  @test.assert_eq(
    pdf_text_predefined_rksj_single_byte_codepoint(0x41),
    Some(0x41),
  )
  @test.assert_eq(
    pdf_text_predefined_rksj_single_byte_codepoint(0xA6),
    Some(0xFF66),
  )
  @test.assert_eq(pdf_text_predefined_rksj_single_byte_codepoint(0x8140), None)
  @test.assert_eq(
    pdf_text_predefined_rksj_single_byte_charcode(0x41),
    Some(0x41),
  )
  @test.assert_eq(
    pdf_text_predefined_rksj_single_byte_charcode(0xFF66),
    Some(0xA6),
  )
  @test.assert_eq(pdf_text_predefined_rksj_single_byte_charcode(0x3000), None)
  @test.assert_eq(pdf_text_japan1_codepoints_of_cid(843), Some([0x3042]))
  @test.assert_eq(pdf_text_japan1_codepoints_of_cid(-1), None)
  guard pdf_text_predefined_japan1_cid_ranges(wbtest_text_name("/H"))
    is Some(jis_ranges) else {
    fail("expected JIS ranges")
  }
  @test.assert_eq(
    pdf_text_predefined_japan1_codepoints(jis_ranges, 0x2422),
    Some([0x3042]),
  )
  @test.assert_eq(pdf_text_predefined_japan1_codepoints(jis_ranges, 0), None)
  @test.assert_eq(
    pdf_text_predefined_japan1_charcode(jis_ranges, 0x3042),
    Some(0x2422),
  )
  @test.assert_eq(
    pdf_text_predefined_japan1_charcode(jis_ranges, 0x1F600),
    None,
  )
  let unknown_rksj_font : PdfFont = PdfFontCIDKeyed({
    basefont: wbtest_text_name("/UnknownRKSJ"),
    composite: {
      cid_system_info: {
        registry: wbtest_text_bytes([82]),
        ordering: wbtest_text_bytes([79]),
        supplement: 0,
      },
      cid_basefont: wbtest_text_name("/Descendant"),
      cid_fontdescriptor: pdf_text_empty_font_descriptor(),
      cid_widths: [],
      cid_widths2: [],
      cid_default_width: 1000.0,
      cid_default_width2: [880.0, -1000.0],
    },
    encoding: PdfPredefinedCMap(wbtest_text_name("/Unknown-RKSJ-H")),
  })
  let unknown_rksj_extractor = unknown_rksj_font.text_extractor()
  @test.assert_eq(
    unknown_rksj_extractor.codepoints_of_text(
      wbtest_text_bytes([0x41, 0xA6, 0x81, 0x40]),
    ),
    [0x41, 0xFF66, 0x8140],
  )
  @test.assert_eq(
    unknown_rksj_extractor.charcode_of_codepoint(0x41),
    Some(0x41),
  )
  @test.assert_eq(
    unknown_rksj_extractor.charcode_of_codepoint(0xFF66),
    Some(0xA6),
  )
  @test.assert_eq(unknown_rksj_extractor.charcode_of_codepoint(0x3000), None)
  @test.assert_eq(pdf_text_hex_int_min2(7), "07")
}
