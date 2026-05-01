///|
fn text_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
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
    @test.assert_eq(entry.0.pdf_name(), text_name_for_test("/" + entry.1))
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
      @pdflite.pdf_standard_font_of_pdf_name(text_name_for_test(entry.0)),
      Some(entry.1),
    )
  }
  @test.assert_eq(@pdflite.pdf_standard_font_of_name("Times-Roman"), None)
  @test.assert_eq(
    @pdflite.pdf_standard_font_of_pdf_name(text_name_for_test("/Missing")),
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
    @test.assert_eq(entry.0.stemv(), entry.2)
    @test.assert_eq(entry.0.flags(), entry.3)
  }
}
