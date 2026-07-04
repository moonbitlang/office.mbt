///|
fn coord_name_for_test(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn coord_rect_object_for_test(
  x0 : Int,
  y0 : Int,
  x1 : Int,
  y1 : Int,
) -> @syntax.PdfObject {
  PdfArray([PdfInteger(x0), PdfInteger(y0), PdfInteger(x1), PdfInteger(y1)])
}

///|
fn coord_page_for_test(
  width : Int,
  height : Int,
  cropbox? : @syntax.PdfObject? = None,
) -> @page.PdfPage {
  let page = @page.pdf_page_custom(
    coord_rect_object_for_test(0, 0, width, height),
  )
  match cropbox {
    Some(cropbox) =>
      {
        ..page,
        rest: PdfDictionary([(coord_name_for_test("/CropBox"), cropbox)]),
      }
    None => page
  }
}

///|
fn coord_page_with_boxes_for_test() -> @page.PdfPage {
  {
    ..coord_page_for_test(200, 100),
    rest: PdfDictionary([
      (coord_name_for_test("/ArtBox"), coord_rect_object_for_test(1, 2, 11, 22)),
      (
        coord_name_for_test("/TrimBox"),
        coord_rect_object_for_test(3, 4, 23, 44),
      ),
      (
        coord_name_for_test("/BleedBox"),
        coord_rect_object_for_test(5, 6, 35, 66),
      ),
    ]),
  }
}

///|
fn coord_document_for_test(
  pages : ArrayView[@page.PdfPage],
) -> @pdflite.PdfDocument raise {
  let document = @pdflite.pdf_document_empty()
  let page_root = document.add_pagetree(pages)
  ignore(document.add_root(page_root, []))
  document
}

///|
fn assert_close_for_coord_test(
  actual : Double,
  expected : Double,
) -> Unit raise {
  let difference = if actual > expected {
    actual - expected
  } else {
    expected - actual
  }
  guard difference < 0.0000001 else {
    fail(
      "expected " +
      actual.to_string() +
      " to be close to " +
      expected.to_string(),
    )
  }
}

///|
fn assert_point_for_coord_test(
  actual : @geometry.Point2,
  x : Double,
  y : Double,
) -> Unit raise {
  assert_close_for_coord_test(actual.x, x)
  assert_close_for_coord_test(actual.y, y)
}

///|
fn assert_coordinate_tuple_for_test(
  actual : (Double, Double),
  x : Double,
  y : Double,
) -> Unit raise {
  assert_close_for_coord_test(actual.0, x)
  assert_close_for_coord_test(actual.1, y)
}

///|
fn assert_coord_rectangle_for_test(
  actual : @geometry.PdfCoordRectangle,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> Unit raise {
  assert_close_for_coord_test(actual.x, x)
  assert_close_for_coord_test(actual.y, y)
  assert_close_for_coord_test(actual.width, width)
  assert_close_for_coord_test(actual.height, height)
}

///|
test "cpdf coord parses unit numbers and paper sizes" {
  let document = @pdflite.pdf_document_empty()
  assert_close_for_coord_test(try! document.parse_single_number("25.4mm"), 72.0)
  assert_close_for_coord_test(try! document.parse_single_number("2.54cm"), 72.0)
  assert_close_for_coord_test(try! document.parse_single_number("1in"), 72.0)
  assert_close_for_coord_test(try! document.parse_single_number("12pt"), 12.0)
  let values = try! document.parse_units_string(
    @page.pdf_page_blank(@geometry.paper_a4),
    "a4portrait",
  )
  @test.assert_eq(values.length(), 2)
  assert_close_for_coord_test(
    values[0],
    @geometry.unit_points(@geometry.paper_a4.width(), @geometry.paper_a4.unit()),
  )
  assert_close_for_coord_test(
    values[1],
    @geometry.unit_points(
      @geometry.paper_a4.height(),
      @geometry.paper_a4.unit(),
    ),
  )
}

///|
test "cpdf coord parses compact adjacent unit suffixes" {
  let document = @pdflite.pdf_document_empty()
  assert_point_for_coord_test(
    try! document.parse_coordinate("10mm20mm"),
    10.0 / 10.0 / 2.54 * 72.0,
    20.0 / 10.0 / 2.54 * 72.0,
  )
  assert_coord_rectangle_for_test(
    try! document.parse_coordinate_rectangle("1in2in3in4in"),
    72.0,
    144.0,
    216.0,
    288.0,
  )
}

///|
test "cpdf coord parses rectangles and absolute rectangle syntax" {
  let document = @pdflite.pdf_document_empty()
  assert_coord_rectangle_for_test(
    try! document.parse_coordinate_rectangle("10 20 30 40"),
    10.0,
    20.0,
    30.0,
    40.0,
  )
  assert_coord_rectangle_for_test(
    try! document.parse_coordinate_rectangle("?10 20 30 40"),
    10.0,
    20.0,
    20.0,
    20.0,
  )
}

///|
test "cpdf coord reads page and cropbox characteristics" {
  let document = try! coord_document_for_test([
    coord_page_for_test(
      200,
      100,
      cropbox=Some(coord_rect_object_for_test(10, 20, 110, 80)),
    ),
  ])
  let page = (try! document.pages_of_pagetree())[0]
  @test.assert_eq(
    try! document.parse_units_string(page, "PW PH CW CH CMINX CMAXY"),
    [200.0, 100.0, 100.0, 60.0, 10.0, 80.0],
  )
  @test.assert_eq(
    try! document.parse_units_string(page, "PW div 2 PH add 10"),
    [100.0, 110.0],
  )
}

///|
test "cpdf coord reads alternate page boxes and rectangle wrapper" {
  let document = try! coord_document_for_test([coord_page_with_boxes_for_test()])
  let page = (try! document.pages_of_pagetree())[0]
  @test.assert_eq(
    try! document.parse_units_string(
      page, "AW AH AMINX AMAXY TW TH TMINY TMAXX BW BH BMINX BMAXY",
    ),
    [10.0, 20.0, 1.0, 22.0, 20.0, 40.0, 4.0, 23.0, 30.0, 60.0, 5.0, 66.0],
  )
  let rectangles = try! @pdflite.pdf_parse_coordinate_rectangles(
    document, "?AMINX AMINY AMAXX AMAXY",
  )
  @test.assert_eq(rectangles.length(), 1)
  assert_coord_rectangle_for_test(rectangles[0], 1.0, 2.0, 10.0, 20.0)
  @test.assert_eq(
    try! @pdflite.pdf_parse_rectangle(document, "?10 20 30 40"),
    (10.0, 20.0, 20.0, 20.0),
  )
  @test.assert_eq(
    try! @pdflite.pdf_parse_rectangles(document, "?AMINX AMINY AMAXX AMAXY"),
    [(1.0, 2.0, 10.0, 20.0)],
  )
}

///|
test "cpdf coord parses coordinates across document pages" {
  let document = try! coord_document_for_test([
    coord_page_for_test(200, 100),
    coord_page_for_test(300, 150),
  ])
  assert_point_for_coord_test(
    try! document.parse_coordinate("10 20"),
    10.0,
    20.0,
  )
  assert_coordinate_tuple_for_test(
    try! document.parse_coordinate_tuple("10 20"),
    10.0,
    20.0,
  )
  assert_coordinate_tuple_for_test(
    try! @pdflite.pdf_parse_coordinate_tuple(document, "10 20"),
    10.0,
    20.0,
  )
  let scaled = try! document.parse_coordinates("* 10")
  @test.assert_eq(scaled.length(), 2)
  assert_point_for_coord_test(scaled[0], 20.0, 10.0)
  assert_point_for_coord_test(scaled[1], 20.0, 10.0)
  let scaled_tuples = try! document.parse_coordinates_tuple("* 10")
  @test.assert_eq(scaled_tuples.length(), 2)
  assert_coordinate_tuple_for_test(scaled_tuples[0], 20.0, 10.0)
  assert_coordinate_tuple_for_test(scaled_tuples[1], 20.0, 10.0)
  let scaled_suffix = try! document.parse_coordinates("10 *")
  assert_point_for_coord_test(scaled_suffix[0], 10.0, 5.0)
  assert_point_for_coord_test(scaled_suffix[1], 10.0, 5.0)
  let scaled_suffix_tuples = try! @pdflite.pdf_parse_coordinates_tuple(
    document, "10 *",
  )
  @test.assert_eq(scaled_suffix_tuples.length(), 2)
  assert_coordinate_tuple_for_test(scaled_suffix_tuples[0], 10.0, 5.0)
  assert_coordinate_tuple_for_test(scaled_suffix_tuples[1], 10.0, 5.0)
}

///|
test "cpdf coord reports arity errors" {
  let document = @pdflite.pdf_document_empty()
  let bad_rect : Result[@geometry.PdfCoordRectangle, Error] = try
    document.parse_coordinate_rectangle("10 20 30")
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_rect is Err(@core.PdfError::BadRectangleSpecification("10 20 30")) else {
    fail("expected BadRectangleSpecification for three rectangle numbers")
  }
  let bad_coord : Result[@geometry.Point2, Error] = try
    document.parse_coordinate("10 20 30")
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_coord is Err(@core.PdfError::BadCoordinateSpecification("10 20 30")) else {
    fail("expected BadCoordinateSpecification for three coordinate numbers")
  }
  let bad_number : Result[Double, Error] = try
    document.parse_single_number("10 20")
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_number is Err(@core.PdfError::BadNumberArgument("10 20")) else {
    fail("expected BadNumberArgument for two numbers")
  }
}
