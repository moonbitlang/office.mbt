///|
fn text_standard_font_name_for_test(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn text_standard_font_bytes_for_test(values : ArrayView[Int]) -> @core.PdfBytes {
  try! @core.pdf_bytes_of_int_array(values)
}

///|
fn text_standard_font_difference_for_test(
  name : String,
  code : Int,
) -> @pdflite.PdfEncodingDifference {
  { name: text_standard_font_name_for_test(name), code }
}

///|
fn text_standard_font_data_helper_for_test(
  font : @pdflite.PdfStandardFont,
  encoding : @pdflite.PdfEncoding,
) -> @pdflite.PdfStandardFontData {
  { font, encoding }
}

///|
fn text_standard_font_descriptor_for_test() -> @pdflite.PdfFontDescriptor {
  {
    ascent: 0.0,
    descent: 0.0,
    avgwidth: 0.0,
    maxwidth: 0.0,
    flags: 0,
    fontbbox: { min_x: 0.0, min_y: 0.0, max_x: 0.0, max_y: 0.0 },
    italicangle: 0.0,
    capheight: 0.0,
    xheight: 0.0,
    stemv: 0.0,
    fontfile: None,
    charset: None,
    tounicode: None,
  }
}

///|
test "PdfStandardFont exposes CamlPDF standard font names" {
  let fonts : Array[(@pdflite.PdfStandardFont, String)] = [
    (PdfTimesRoman, "Times-Roman"),
    (PdfTimesBold, "Times-Bold"),
    (PdfTimesItalic, "Times-Italic"),
    (PdfTimesBoldItalic, "Times-BoldItalic"),
    (PdfHelvetica, "Helvetica"),
    (PdfHelveticaBold, "Helvetica-Bold"),
    (PdfHelveticaOblique, "Helvetica-Oblique"),
    (PdfHelveticaBoldOblique, "Helvetica-BoldOblique"),
    (PdfCourier, "Courier"),
    (PdfCourierBold, "Courier-Bold"),
    (PdfCourierOblique, "Courier-Oblique"),
    (PdfCourierBoldOblique, "Courier-BoldOblique"),
    (PdfSymbol, "Symbol"),
    (PdfZapfDingbats, "ZapfDingbats"),
  ]
  for entry in fonts {
    @test.assert_eq(entry.0.name(), entry.1)
    @test.assert_eq(@pdflite.pdf_string_of_standard_font(entry.0), entry.1)
    @test.assert_eq(
      entry.0.pdf_name(),
      text_standard_font_name_for_test("/" + entry.1),
    )
  }
}

///|
test "pdf_standard_font_of_name accepts CamlPDF aliases" {
  let aliases : Array[(String, @pdflite.PdfStandardFont)] = [
    ("/Times-Roman", PdfTimesRoman),
    ("/TimesNewRoman", PdfTimesRoman),
    ("/Times-Bold", PdfTimesBold),
    ("/TimesNewRoman,Bold", PdfTimesBold),
    ("/Times-Italic", PdfTimesItalic),
    ("/TimesNewRoman,Italic", PdfTimesItalic),
    ("/Times-BoldItalic", PdfTimesBoldItalic),
    ("/TimesNewRoman,BoldItalic", PdfTimesBoldItalic),
    ("/Helvetica", PdfHelvetica),
    ("/Arial", PdfHelvetica),
    ("/Helvetica-Bold", PdfHelveticaBold),
    ("/Arial,Bold", PdfHelveticaBold),
    ("/Helvetica-Oblique", PdfHelveticaOblique),
    ("/Arial,Italic", PdfHelveticaOblique),
    ("/Helvetica-BoldOblique", PdfHelveticaBoldOblique),
    ("/Arial,BoldItalic", PdfHelveticaBoldOblique),
    ("/Courier", PdfCourier),
    ("/CourierNew", PdfCourier),
    ("/Courier-Bold", PdfCourierBold),
    ("/CourierNew,Bold", PdfCourierBold),
    ("/Courier-Oblique", PdfCourierOblique),
    ("/CourierNew,Italic", PdfCourierOblique),
    ("/Courier-BoldOblique", PdfCourierBoldOblique),
    ("/CourierNew,BoldItalic", PdfCourierBoldOblique),
    ("/Symbol", PdfSymbol),
    ("/ZapfDingbats", PdfZapfDingbats),
  ]
  for entry in aliases {
    @test.assert_eq(@pdflite.pdf_standard_font_of_name(entry.0), Some(entry.1))
    @test.assert_eq(
      @pdflite.pdf_standard_font_of_pdf_name(
        text_standard_font_name_for_test(entry.0),
      ),
      Some(entry.1),
    )
  }
  @test.assert_eq(@pdflite.pdf_standard_font_of_name("Times-Roman"), None)
  @test.assert_eq(
    @pdflite.pdf_standard_font_of_pdf_name(
      text_standard_font_name_for_test("/Missing"),
    ),
    None,
  )
}

///|
test "PdfStandardFont exposes standard14 baseline stem and flags" {
  let metrics : Array[(@pdflite.PdfStandardFont, Int, Int, Int)] = [
    (PdfTimesRoman, 331, 116, 32),
    (PdfTimesBold, 338, 122, 32),
    (PdfTimesItalic, 326, 105, 32),
    (PdfTimesBoldItalic, 334, 108, 32),
    (PdfHelvetica, 359, 114, 32),
    (PdfHelveticaBold, 359, 123, 32),
    (PdfHelveticaOblique, 359, 127, 32),
    (PdfHelveticaBoldOblique, 359, 136, 32),
    (PdfCourier, 281, 88, 33),
    (PdfCourierBold, 281, 93, 33),
    (PdfCourierOblique, 281, 100, 33),
    (PdfCourierBoldOblique, 281, 104, 33),
    (PdfSymbol, 336, 0, 65541),
    (PdfZapfDingbats, 352, 125, 4),
  ]
  for entry in metrics {
    @test.assert_eq(entry.0.baseline_adjustment(), entry.1)
    @test.assert_eq(
      @pdflite.pdf_standard14_baseline_adjustment(entry.0),
      entry.1,
    )
    @test.assert_eq(entry.0.stemv(), entry.2)
    @test.assert_eq(
      @pdflite.pdf_standard14_stemv_of_standard_font(entry.0),
      entry.2,
    )
    @test.assert_eq(entry.0.flags(), entry.3)
    @test.assert_eq(
      @pdflite.pdf_standard14_flags_of_standard_font(entry.0),
      entry.3,
    )
  }
}

///|
test "PdfStandardFont exposes Standard14 AFM data tables" {
  let counts : Array[(@pdflite.PdfStandardFont, Int, Int, Int, Int)] = [
    (PdfTimesRoman, 25, 149, 315, 206),
    (PdfTimesBold, 25, 149, 315, 223),
    (PdfTimesItalic, 25, 149, 315, 213),
    (PdfTimesBoldItalic, 25, 149, 315, 205),
    (PdfHelvetica, 25, 149, 315, 289),
    (PdfHelveticaBold, 25, 149, 315, 252),
    (PdfHelveticaOblique, 25, 149, 315, 289),
    (PdfHelveticaBoldOblique, 25, 149, 315, 252),
    (PdfCourier, 25, 149, 315, 0),
    (PdfCourierBold, 25, 149, 315, 0),
    (PdfCourierOblique, 25, 149, 315, 0),
    (PdfCourierBoldOblique, 25, 149, 315, 0),
    (PdfSymbol, 21, 189, 190, 0),
    (PdfZapfDingbats, 21, 202, 202, 0),
  ]
  for entry in counts {
    let data = @pdflite.pdf_standard14_afm_data(entry.0)
    @test.assert_eq(data.headers.length(), entry.1)
    @test.assert_eq(data.char_metrics.length(), entry.2)
    @test.assert_eq(data.char_name_widths.length(), entry.3)
    @test.assert_eq(data.kerns.length(), entry.4)
  }
  @test.assert_eq(
    @pdflite.PdfCourier.afm_data().headers[5],
    (@ascii.encode("FontName"), @ascii.encode("Courier")),
  )
}

///|
test "PdfStandardFont text_width mirrors CamlPDF widths and kerning" {
  let av = text_standard_font_bytes_for_test([65, 86])
  @test.assert_eq(
    @pdflite.PdfHelvetica.text_width(PdfWinAnsiEncoding, av),
    1334,
  )
  @test.assert_eq(
    @pdflite.PdfHelvetica.text_width(PdfWinAnsiEncoding, av, kern=true),
    1264,
  )
  @test.assert_eq(
    @pdflite.pdf_standard14_textwidth(
      true,
      PdfWinAnsiEncoding,
      PdfHelvetica,
      av,
    ),
    1264,
  )
  let to = text_standard_font_bytes_for_test([84, 111])
  @test.assert_eq(
    @pdflite.pdf_standard14_text_width(PdfTimesRoman, PdfWinAnsiEncoding, to),
    1111,
  )
  @test.assert_eq(
    @pdflite.pdf_standard14_textwidth(
      false,
      PdfWinAnsiEncoding,
      PdfTimesRoman,
      to,
    ),
    1111,
  )
  @test.assert_eq(
    @pdflite.pdf_standard14_text_width(
      PdfTimesRoman,
      PdfWinAnsiEncoding,
      to,
      kern=true,
    ),
    1031,
  )
  let courier = text_standard_font_bytes_for_test([65, 66, 67])
  @test.assert_eq(
    @pdflite.PdfCourier.text_width(PdfImplicitInFontFile, courier),
    1800,
  )
  @test.assert_eq(
    @pdflite.PdfCourier.text_width(PdfImplicitInFontFile, courier, kern=true),
    1800,
  )
  let missing_code = text_standard_font_bytes_for_test([1])
  @test.assert_eq(
    @pdflite.PdfCourier.text_width(PdfImplicitInFontFile, missing_code),
    0,
  )
}

///|
test "PdfStandardFont text_width uses glyph-name widths for explicit encodings" {
  let custom : @pdflite.PdfEncoding = PdfCustomEncoding(PdfWinAnsiEncoding, [
    text_standard_font_difference_for_test("/AE", 65),
  ])
  let text = text_standard_font_bytes_for_test([65, 66, 0])
  @test.assert_eq(@pdflite.PdfHelvetica.text_width(custom, text), 1945)
  let standard_font = text_standard_font_data_helper_for_test(
    PdfHelvetica,
    custom,
  )
  @test.assert_eq(standard_font.text_width(text), 1945)
  let symbol_text = text_standard_font_bytes_for_test([65])
  @test.assert_eq(
    @pdflite.PdfSymbol.text_width(PdfImplicitInFontFile, symbol_text),
    722,
  )
  let slashless : @pdflite.PdfEncoding = PdfCustomEncoding(PdfWinAnsiEncoding, [
    { name: text_standard_font_name_for_test("AE"), code: 65 },
  ])
  @test.assert_eq(
    @pdflite.PdfHelvetica.text_width(slashless, symbol_text),
    1000,
  )
  let unknown : @pdflite.PdfEncoding = PdfCustomEncoding(PdfWinAnsiEncoding, [
    text_standard_font_difference_for_test("/MissingGlyph", 65),
  ])
  @test.assert_eq(@pdflite.PdfHelvetica.text_width(unknown, symbol_text), 0)
}

///|
test "PdfTextExtractor text_width uses font metrics" {
  let av = text_standard_font_bytes_for_test([65, 86])
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_helper_for_test(PdfHelvetica, PdfWinAnsiEncoding),
  )
  @test.assert_eq(try! standard_font.text_extractor().text_width(av), 1334.0)
  let metrics : Array[Double] = [ for _ in 0..<256 => 250.0 ]
  metrics[65] = 500.0
  metrics[66] = 700.0
  let simple_font : @pdflite.PdfFont = PdfFontSimple({
    fonttype: PdfType1,
    basefont: Some(text_standard_font_name_for_test("/CustomFont")),
    firstchar: 0,
    lastchar: 255,
    widths: [],
    fontdescriptor: None,
    fontmetrics: Some(metrics),
    encoding: PdfWinAnsiEncoding,
  })
  @test.assert_eq(
    try! simple_font
    .text_extractor()
    .text_width(text_standard_font_bytes_for_test([65, 66, 67])),
    1450.0,
  )
  let composite : @pdflite.PdfCompositeCIDFont = {
    cid_system_info: {
      registry: text_standard_font_bytes_for_test([65]),
      ordering: text_standard_font_bytes_for_test([73]),
      supplement: 0,
    },
    cid_basefont: text_standard_font_name_for_test("/Descendant"),
    cid_fontdescriptor: text_standard_font_descriptor_for_test(),
    cid_widths: [(0x41, 600.0), (0x20AC, 900.0)],
    cid_widths2: [],
    cid_default_width: 1000.0,
    cid_default_width2: [880.0, -1000.0],
  }
  let cid_font : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_standard_font_name_for_test("/Top"),
    composite,
    encoding: PdfPredefinedCMap(text_standard_font_name_for_test("/Identity-H")),
  })
  @test.assert_eq(
    try! cid_font
    .text_extractor()
    .text_width(
      text_standard_font_bytes_for_test([0x00, 0x41, 0x20, 0xAC, 0x00, 0x42]),
    ),
    2500.0,
  )
}
