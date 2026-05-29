///|
fn standard14_width_ascii_for_test(text : String) -> Bytes {
  @ascii.encode(text)
}

///|
test "standard14 package exposes AFM glyph widths and kerning" {
  let helvetica = @standard14.PdfHelvetica.afm_data()
  @test.assert_eq(
    @standard14.pdf_standard14_width_of_charcode(helvetica, 65),
    667,
  )
  @test.assert_eq(
    @standard14.pdf_standard14_width_of_glyphname(
      helvetica,
      standard14_width_ascii_for_test("/AE"),
    ),
    1000,
  )
  @test.assert_eq(
    @standard14.pdf_standard14_width_of_glyphname(
      helvetica,
      standard14_width_ascii_for_test("AE"),
    ),
    1000,
  )
  @test.assert_eq(
    @standard14.pdf_standard14_width_of_glyphname(
      helvetica,
      standard14_width_ascii_for_test("/MissingGlyph"),
    ),
    0,
  )
  @test.assert_eq(@standard14.pdf_standard14_kern(helvetica, 65, 86), -70)
  @test.assert_eq(
    @standard14.pdf_standard14_width_of_charcode(
      @standard14.PdfCourier.afm_data(),
      65,
    ),
    600,
  )
  @test.assert_eq(
    @standard14.pdf_standard14_width_of_charcode(
      @standard14.PdfCourier.afm_data(),
      1,
    ),
    0,
  )
}
