///|
fn position_bounds_for_test() -> @pdflite.PdfRectangle {
  { min_x: 0.0, min_y: 0.0, max_x: 100.0, max_y: 50.0 }
}

///|
fn position_square_bounds_for_test() -> @pdflite.PdfRectangle {
  { min_x: 0.0, min_y: 0.0, max_x: 100.0, max_y: 100.0 }
}

///|
fn assert_close_for_position_test(
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
fn assert_position_for_test(
  actual : @pdflite.PdfCalculatedPosition,
  x : Double,
  y : Double,
  rotation : Double,
) -> Unit raise {
  assert_close_for_position_test(actual.x, x)
  assert_close_for_position_test(actual.y, y)
  assert_close_for_position_test(actual.rotation, rotation)
}

///|
test "cpdf position debug strings use OCaml fixed precision spellings" {
  @test.assert_eq(
    @pdflite.pdf_string_of_position(PdfPositionPosCentre(1.5, -2.25)),
    "PosCentre 1.500000 -2.250000",
  )
  @test.assert_eq(
    @pdflite.pdf_string_of_position(PdfPositionPosLeft(1.0, 2.0)),
    "PosLeft 1.000000 2.000000",
  )
  @test.assert_eq(
    @pdflite.pdf_string_of_position(PdfPositionPosRight(3.0, 4.0)),
    "PosRight 3.000000 4.000000",
  )
  @test.assert_eq(
    @pdflite.pdf_string_of_position(PdfPositionTop(7.0)),
    "Top 7.000000",
  )
  @test.assert_eq(
    @pdflite.pdf_string_of_position(PdfPositionTopLeft(1.0, 2.0)),
    "TopLeft 1.000000 2.000000",
  )
  @test.assert_eq(
    @pdflite.pdf_string_of_position(PdfPositionTopRight(3.0, 4.0)),
    "TopRight 3.000000 4.000000",
  )
  @test.assert_eq(
    @pdflite.pdf_string_of_position(PdfPositionLeft(8.0)),
    "Left 8.000000",
  )
  @test.assert_eq(
    @pdflite.pdf_string_of_position(PdfPositionBottomLeft(1.0, 2.0)),
    "BottomLeft 1.000000 2.000000",
  )
  @test.assert_eq(
    @pdflite.pdf_string_of_position(PdfPositionBottom(9.0)),
    "Bottom 9.000000",
  )
  @test.assert_eq(
    @pdflite.pdf_string_of_position(PdfPositionBottomRight(3.0, 4.0)),
    "BottomRight 3.000000 4.000000",
  )
  @test.assert_eq(
    @pdflite.pdf_string_of_position(PdfPositionRight(10.0)),
    "Right 10.000000",
  )
  @test.assert_eq(
    @pdflite.pdf_string_of_position(PdfPositionDiagonal),
    "Diagonal",
  )
  @test.assert_eq(
    @pdflite.pdf_string_of_position(PdfPositionReverseDiagonal),
    "Reverse Diagonal",
  )
  @test.assert_eq(@pdflite.pdf_string_of_position(PdfPositionCentre), "Centre")
}

///|
test "cpdf position calculates centered and absolute placements" {
  let bounds = position_bounds_for_test()
  assert_position_for_test(
    @pdflite.pdf_calculate_position(false, 20.0, bounds, PdfPositionCentre),
    40.0,
    25.0,
    0.0,
  )
  assert_position_for_test(
    @pdflite.pdf_calculate_position(
      false,
      20.0,
      bounds,
      PdfPositionPosLeft(10.0, 4.0),
    ),
    10.0,
    4.0,
    0.0,
  )
  assert_position_for_test(
    @pdflite.pdf_calculate_position(
      false,
      20.0,
      bounds,
      PdfPositionPosCentre(50.0, 4.0),
    ),
    40.0,
    4.0,
    0.0,
  )
  assert_position_for_test(
    @pdflite.pdf_calculate_position(
      false,
      20.0,
      bounds,
      PdfPositionPosRight(50.0, 4.0),
    ),
    30.0,
    4.0,
    0.0,
  )
}

///|
test "cpdf position calculates edge placements and ignore distance" {
  let bounds = position_bounds_for_test()
  assert_position_for_test(
    @pdflite.pdf_calculate_position(false, 20.0, bounds, PdfPositionTop(5.0)),
    40.0,
    45.0,
    0.0,
  )
  assert_position_for_test(
    @pdflite.pdf_calculate_position(true, 20.0, bounds, PdfPositionTop(5.0)),
    40.0,
    50.0,
    0.0,
  )
  assert_position_for_test(
    @pdflite.pdf_calculate_position(
      false,
      20.0,
      bounds,
      PdfPositionTopLeft(3.0, 4.0),
    ),
    3.0,
    46.0,
    0.0,
  )
  assert_position_for_test(
    @pdflite.pdf_calculate_position(
      false,
      20.0,
      bounds,
      PdfPositionTopRight(3.0, 4.0),
    ),
    77.0,
    46.0,
    0.0,
  )
  assert_position_for_test(
    @pdflite.pdf_calculate_position(false, 20.0, bounds, PdfPositionLeft(5.0)),
    5.0,
    25.0,
    0.0,
  )
  assert_position_for_test(
    @pdflite.pdf_calculate_position(
      false,
      20.0,
      bounds,
      PdfPositionBottomLeft(3.0, 4.0),
    ),
    3.0,
    4.0,
    0.0,
  )
  assert_position_for_test(
    @pdflite.pdf_calculate_position(false, 20.0, bounds, PdfPositionBottom(5.0)),
    40.0,
    5.0,
    0.0,
  )
  assert_position_for_test(
    @pdflite.pdf_calculate_position(
      false,
      20.0,
      bounds,
      PdfPositionBottomRight(3.0, 4.0),
    ),
    77.0,
    4.0,
    0.0,
  )
  assert_position_for_test(
    @pdflite.pdf_calculate_position(false, 20.0, bounds, PdfPositionRight(5.0)),
    75.0,
    25.0,
    0.0,
  )
}

///|
test "cpdf position ignore distance zeros all edge offsets" {
  let bounds = position_bounds_for_test()
  assert_position_for_test(
    @pdflite.pdf_calculate_position(
      true,
      20.0,
      bounds,
      PdfPositionTopLeft(3.0, 4.0),
    ),
    0.0,
    50.0,
    0.0,
  )
  assert_position_for_test(
    @pdflite.pdf_calculate_position(
      true,
      20.0,
      bounds,
      PdfPositionTopRight(3.0, 4.0),
    ),
    80.0,
    50.0,
    0.0,
  )
  assert_position_for_test(
    @pdflite.pdf_calculate_position(true, 20.0, bounds, PdfPositionLeft(5.0)),
    0.0,
    25.0,
    0.0,
  )
  assert_position_for_test(
    @pdflite.pdf_calculate_position(
      true,
      20.0,
      bounds,
      PdfPositionBottomLeft(3.0, 4.0),
    ),
    0.0,
    0.0,
    0.0,
  )
  assert_position_for_test(
    @pdflite.pdf_calculate_position(true, 20.0, bounds, PdfPositionBottom(5.0)),
    40.0,
    0.0,
    0.0,
  )
  assert_position_for_test(
    @pdflite.pdf_calculate_position(
      true,
      20.0,
      bounds,
      PdfPositionBottomRight(3.0, 4.0),
    ),
    80.0,
    0.0,
    0.0,
  )
  assert_position_for_test(
    @pdflite.pdf_calculate_position(true, 20.0, bounds, PdfPositionRight(5.0)),
    80.0,
    25.0,
    0.0,
  )
}

///|
test "cpdf position calculates diagonal placements" {
  let bounds = position_square_bounds_for_test()
  let diagonal = @pdflite.pdf_calculate_position(
    false,
    20.0,
    bounds,
    PdfPositionDiagonal,
  )
  assert_position_for_test(
    diagonal,
    42.928932188134524,
    42.928932188134524,
    @math.PI / 4.0,
  )
  let reverse = @pdflite.pdf_calculate_position(
    false,
    20.0,
    bounds,
    PdfPositionReverseDiagonal,
  )
  assert_position_for_test(
    reverse,
    42.928932188134524,
    57.071067811865476,
    -@math.PI / 4.0,
  )
}
