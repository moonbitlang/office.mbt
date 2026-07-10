///|
fn text_wbtest_name(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn text_wbtest_descriptor(
  tounicode : Array[(Int, @core.PdfBytes)]?,
) -> PdfFontDescriptor {
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
    tounicode,
  }
}

///|
fn text_wbtest_simple_font(
  basefont : @core.PdfName?,
  fontmetrics : Array[Double]?,
  descriptor : PdfFontDescriptor?,
) -> PdfSimpleFont {
  {
    fonttype: PdfType1,
    basefont,
    firstchar: 0,
    lastchar: 0,
    widths: [],
    fontdescriptor: descriptor,
    fontmetrics,
    encoding: PdfWinAnsiEncoding,
  }
}

///|
test "private simple-font charcode width covers metric and standard fallbacks" {
  let metrics_font = text_wbtest_simple_font(None, Some([250.0]), None)
  @test.assert_eq(pdf_text_simple_font_charcode_width(metrics_font, 0), 250.0)
  @test.assert_eq(pdf_text_simple_font_charcode_width(metrics_font, 2), 0.0)

  let standard_font = text_wbtest_simple_font(
    Some(text_wbtest_name("/Helvetica")),
    None,
    None,
  )
  @test.assert_eq(pdf_text_simple_font_charcode_width(standard_font, 65), 667.0)
  @test.assert_eq(pdf_text_simple_font_charcode_width(standard_font, 300), 0.0)

  let unknown_font = text_wbtest_simple_font(
    Some(text_wbtest_name("/UnknownFont")),
    None,
    None,
  )
  @test.assert_eq(pdf_text_simple_font_charcode_width(unknown_font, 65), 0.0)
  @test.assert_eq(
    pdf_text_simple_font_charcode_width(
      text_wbtest_simple_font(None, None, None),
      65,
    ),
    0.0,
  )
}

///|
test "private text glyph extraction falls back for malformed ToUnicode bytes" {
  let font : PdfFont = PdfFontSimple(
    text_wbtest_simple_font(
      Some(text_wbtest_name("/Helvetica")),
      None,
      Some(text_wbtest_descriptor(Some([(65, b"x")]))),
    ),
  )
  let extractor = font.text_extractor()
  @test.assert_eq(extractor.pdf_text_glyph_of_charcode(65), {
    glyphname: pdf_text_notdef_name(),
    codepoints: [65],
  })
}
