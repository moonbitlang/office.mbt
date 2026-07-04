///|
test "pdf_page_rotation_of_int normalizes PDF rotate values" {
  @test.assert_eq(try! @page.pdf_page_rotation_of_int(0), Rotate0)
  @test.assert_eq(try! @page.pdf_page_rotation_of_int(90), Rotate90)
  @test.assert_eq(try! @page.pdf_page_rotation_of_int(-180), Rotate180)
  @test.assert_eq(try! @page.pdf_page_rotation_of_int(-90), Rotate270)
}

///|
test "pdf_page_blank builds an empty page from paper size" {
  let page = @page.pdf_page_blank(@geometry.paper_a4)
  @test.assert_eq(page.content.length(), 0)
  @test.assert_eq(page.rotate, Rotate0)
  @test.assert_eq(
    page.mediabox,
    PdfArray([
      PdfReal(0.0),
      PdfReal(0.0),
      PdfReal(
        @geometry.unit_points(
          @geometry.paper_a4.width(),
          @geometry.paper_a4.unit(),
        ),
      ),
      PdfReal(
        @geometry.unit_points(
          @geometry.paper_a4.height(),
          @geometry.paper_a4.unit(),
        ),
      ),
    ]),
  )
}
