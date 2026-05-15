///|
test "PdfUnit conversions preserve CamlPDF constants" {
  @test.assert_eq(@geometry.unit_points(1.0, PdfPoint), 1.0)
  @test.assert_eq(@geometry.unit_points(1.0, Inch), 72.0)
  @test.assert_eq(@geometry.unit_points(1.0, Centimetre), 28.3465)
  @test.assert_eq(@geometry.unit_points(1.0, Millimetre), 2.83465)
  @test.assert_eq(@geometry.unit_inches(1.0, Inch), 1.0)
  @test.assert_eq(@geometry.unit_inches(72.0, PdfPoint), 1.0)
  @test.assert_eq(@geometry.unit_inches(2.54, Centimetre), 1.0)
  @test.assert_eq(@geometry.unit_inches(25.4, Millimetre), 1.0)
  @test.assert_eq(@geometry.unit_centimetres(1.0, Inch), 2.54)
  @test.assert_eq(@geometry.unit_centimetres(10.0, Millimetre), 1.0)
  @test.assert_eq(@geometry.unit_centimetres(28.3456, PdfPoint), 1.0)
  @test.assert_eq(@geometry.unit_millimetres(1.0, Centimetre), 10.0)
}

///|
test "PaperSize exposes ISO and US paper dimensions" {
  @test.assert_eq(
    @geometry.paper_a0,
    @geometry.paper_size_make(Millimetre, 841.0, 1189.0),
  )
  @test.assert_eq(
    @geometry.paper_a1,
    @geometry.paper_size_make(Millimetre, 594.0, 841.0),
  )
  @test.assert_eq(
    @geometry.paper_a2,
    @geometry.paper_size_make(Millimetre, 420.0, 594.0),
  )
  @test.assert_eq(
    @geometry.paper_a3,
    @geometry.paper_size_make(Millimetre, 297.0, 420.0),
  )
  @test.assert_eq(@geometry.paper_a4.unit(), Millimetre)
  @test.assert_eq(@geometry.paper_a4.width(), 210.0)
  @test.assert_eq(@geometry.paper_a4.height(), 297.0)
  @test.assert_eq(
    @geometry.paper_a5,
    @geometry.paper_size_make(Millimetre, 148.0, 210.0),
  )
  @test.assert_eq(
    @geometry.paper_a6,
    @geometry.paper_size_make(Millimetre, 105.0, 148.0),
  )
  @test.assert_eq(
    @geometry.paper_a7,
    @geometry.paper_size_make(Millimetre, 74.0, 105.0),
  )
  @test.assert_eq(
    @geometry.paper_a8,
    @geometry.paper_size_make(Millimetre, 52.0, 74.0),
  )
  @test.assert_eq(
    @geometry.paper_a9,
    @geometry.paper_size_make(Millimetre, 37.0, 52.0),
  )
  @test.assert_eq(
    @geometry.paper_a10,
    @geometry.paper_size_make(Millimetre, 26.0, 37.0),
  )
  let a4_landscape = @geometry.paper_a4.landscape()
  @test.assert_eq(a4_landscape.width(), 297.0)
  @test.assert_eq(a4_landscape.height(), 210.0)
  @test.assert_eq(@geometry.paper_usletter.unit(), Inch)
  @test.assert_eq(@geometry.paper_usletter.width(), 8.5)
  @test.assert_eq(@geometry.paper_usletter.height(), 11.0)
  @test.assert_eq(
    @geometry.paper_uslegal,
    @geometry.paper_size_make(Inch, 8.5, 14.0),
  )
}
