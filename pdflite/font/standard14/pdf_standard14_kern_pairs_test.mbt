///|
test "kern_pairs_by_name has every AFM pair, unencoded glyphs too" {
  let helvetica = @standard14.PdfHelvetica.kern_pairs_by_name()
  @test.assert_eq(helvetica.length(), 2705)
  // a pair of accented letters, which the code-keyed table cannot hold
  @test.assert_eq(
    helvetica.iter().any(p => p.0 == "V" && p.1 == "eacute" && p.2 == -80),
    true,
  )
  @test.assert_eq(
    @standard14.PdfHelveticaBold.kern_pairs_by_name().length(),
    2481,
  )
  @test.assert_eq(@standard14.PdfTimesRoman.kern_pairs_by_name().length(), 2073)
  @test.assert_eq(@standard14.PdfTimesBold.kern_pairs_by_name().length(), 2242)
  @test.assert_eq(
    @standard14.PdfTimesItalic.kern_pairs_by_name().length(),
    2321,
  )
  @test.assert_eq(
    @standard14.PdfTimesBoldItalic.kern_pairs_by_name().length(),
    2038,
  )
  @test.assert_eq(@standard14.PdfCourier.kern_pairs_by_name().length(), 0)
  // the oblique faces kern as the upright ones
  @test.assert_eq(
    @standard14.PdfHelveticaOblique.kern_pairs_by_name(),
    helvetica,
  )
}
