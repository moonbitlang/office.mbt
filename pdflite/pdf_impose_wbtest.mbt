///|
fn impose_box_for_test(width : Double, height : Double) -> PdfObject {
  PdfArray([PdfReal(0.0), PdfReal(0.0), PdfReal(width), PdfReal(height)])
}

///|
fn impose_transforms_for_test(
  fit? : Bool = false,
  x? : Int = 2,
  y? : Int = 2,
  columns? : Bool = false,
  rtl? : Bool = false,
  btt? : Bool = false,
  center? : Bool = false,
  margin? : Double = 0.0,
  page_width? : Double = 100.0,
  page_height? : Double = 200.0,
  output_width? : Double = 200.0,
  output_height? : Double = 400.0,
  fit_extra_hspace? : Double = 0.0,
  fit_extra_vspace? : Double = 0.0,
  count? : Int = 3,
) -> Array[TransformMatrix] raise PdfError {
  pdf_document_empty().pdf_impose_transforms(
    fit,
    x,
    y,
    columns,
    rtl,
    btt,
    center,
    margin,
    impose_box_for_test(page_width, page_height),
    impose_box_for_test(output_width, output_height),
    fit_extra_hspace,
    fit_extra_vspace,
    count,
  )
}

///|
test "pdf_impose_transforms preserves row and column ordering" {
  @test.assert_eq(try! impose_transforms_for_test(columns=false, count=3), [
    transform_translate(0.0, 200.0),
    transform_translate(100.0, 200.0),
    transform_translate(0.0, 0.0),
  ])
  @test.assert_eq(try! impose_transforms_for_test(columns=true, count=3), [
    transform_translate(0.0, 200.0),
    transform_translate(0.0, 0.0),
    transform_translate(100.0, 200.0),
  ])
}

///|
test "pdf_impose_transforms centers short final rows" {
  @test.assert_eq(
    try! impose_transforms_for_test(x=3, y=1, center=true, count=2),
    [transform_translate(50.0, 0.0), transform_translate(150.0, 0.0)],
  )
}

///|
test "pdf_impose_transforms preserves right-to-left and bottom-to-top ordering" {
  @test.assert_eq(
    try! impose_transforms_for_test(rtl=true, btt=true, count=4),
    [
      transform_translate(100.0, 0.0),
      transform_translate(0.0, 0.0),
      transform_translate(100.0, 200.0),
      transform_translate(0.0, 200.0),
    ],
  )
}

///|
test "pdf_impose_transforms applies fit spacing and margin transforms" {
  @test.assert_eq(
    try! impose_transforms_for_test(
      x=2,
      y=1,
      output_width=220.0,
      output_height=120.0,
      fit_extra_hspace=5.0,
      fit_extra_vspace=7.0,
      count=2,
    ),
    [transform_translate(5.0, 7.0), transform_translate(110.0, 7.0)],
  )
  @test.assert_eq(
    try! impose_transforms_for_test(
      fit=true,
      x=1,
      y=1,
      margin=10.0,
      page_width=200.0,
      page_height=100.0,
      output_width=200.0,
      output_height=100.0,
      count=1,
    ),
    [{ a: 0.8, b: 0.0, c: 0.0, d: 0.8, e: 20.0, f: 10.0 }],
  )
}

///|
test "pdf_impose_transforms rejects invalid grids and margins" {
  let bad_grid : Result[Array[TransformMatrix], Error] = try? impose_transforms_for_test(
    x=0,
  )
  guard bad_grid
    is Err(PdfError::BadNumberArgument("impose: x and y must be positive")) else {
    fail("expected BadNumberArgument for non-positive imposition grid")
  }

  let bad_margin : Result[Array[TransformMatrix], Error] = try? impose_transforms_for_test(
    fit=true,
    x=1,
    y=1,
    margin=60.0,
    output_width=200.0,
    output_height=100.0,
    count=1,
  )
  guard bad_margin
    is Err(PdfError::BadNumberArgument("impose: margin would fill whole page")) else {
    fail("expected BadNumberArgument for over-large imposition margin")
  }
}
