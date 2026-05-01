///|
test "PdfUnit conversions preserve CamlPDF constants" {
  @test.assert_eq(@pdflite.unit_points(1.0, PdfPoint), 1.0)
  @test.assert_eq(@pdflite.unit_points(1.0, Inch), 72.0)
  @test.assert_eq(@pdflite.unit_points(1.0, Centimetre), 28.3465)
  @test.assert_eq(@pdflite.unit_points(1.0, Millimetre), 2.83465)
  @test.assert_eq(@pdflite.unit_inches(72.0, PdfPoint), 1.0)
  @test.assert_eq(@pdflite.unit_inches(2.54, Centimetre), 1.0)
  @test.assert_eq(@pdflite.unit_centimetres(28.3456, PdfPoint), 1.0)
  @test.assert_eq(@pdflite.unit_millimetres(1.0, Centimetre), 10.0)
}

///|
test "PaperSize exposes ISO and US paper dimensions" {
  @test.assert_eq(@pdflite.paper_a4.unit(), Millimetre)
  @test.assert_eq(@pdflite.paper_a4.width(), 210.0)
  @test.assert_eq(@pdflite.paper_a4.height(), 297.0)
  let a4_landscape = @pdflite.paper_a4.landscape()
  @test.assert_eq(a4_landscape.width(), 297.0)
  @test.assert_eq(a4_landscape.height(), 210.0)
  @test.assert_eq(@pdflite.paper_usletter.unit(), Inch)
  @test.assert_eq(@pdflite.paper_usletter.width(), 8.5)
  @test.assert_eq(@pdflite.paper_usletter.height(), 11.0)
}
