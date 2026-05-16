///|
fn assert_close_for_shape_test(
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
fn assert_point_for_shape_test(
  actual : @pdflite.Point2,
  x : Double,
  y : Double,
) -> Unit raise {
  assert_close_for_shape_test(actual.x, x)
  assert_close_for_shape_test(actual.y, y)
}

///|
test "cpdf shape exposes kappa and restricts angles" {
  assert_close_for_shape_test(@pdflite.pdf_shape_kappa, 0.5522847498307936)
  assert_close_for_shape_test(
    @pdflite.pdf_restrict_angle(@math.PI / 2.0, 0.2),
    0.0,
  )
  assert_close_for_shape_test(
    @pdflite.pdf_restrict_angle(@math.PI / 2.0, 1.0),
    @math.PI / 2.0,
  )
}

///|
test "cpdf shape builds rectangle paths" {
  let path = @pdflite.pdf_shape_rectangle(10.0, 20.0, 30.0, 40.0)
  @test.assert_eq(path.winding_rule, PdfPathEvenOdd)
  @test.assert_eq(path.subpaths.length(), 1)
  let subpath = path.subpaths[0]
  @test.assert_eq(subpath.hole, PdfPathNotHole)
  @test.assert_eq(subpath.closure, PdfPathClosed)
  @test.assert_eq(subpath.segments.length(), 4)
  match subpath.segments[0] {
    PdfPathStraight(start, finish) => {
      assert_point_for_shape_test(start, 10.0, 20.0)
      assert_point_for_shape_test(finish, 40.0, 20.0)
    }
    _ => fail("expected rectangle segment to be straight")
  }
  match subpath.segments[3] {
    PdfPathStraight(start, finish) => {
      assert_point_for_shape_test(start, 10.0, 60.0)
      assert_point_for_shape_test(finish, 10.0, 20.0)
    }
    _ => fail("expected rectangle segment to be straight")
  }
}

///|
test "cpdf shape builds connected circle paths" {
  let path = @pdflite.pdf_shape_circle(10.0, 20.0, 5.0)
  @test.assert_eq(path.winding_rule, PdfPathNonZero)
  @test.assert_eq(path.subpaths.length(), 1)
  let subpath = path.subpaths[0]
  @test.assert_eq(subpath.hole, PdfPathNotHole)
  @test.assert_eq(subpath.closure, PdfPathClosed)
  @test.assert_eq(subpath.segments.length(), 4)
  match subpath.segments[0] {
    PdfPathBezier(start, control1, control2, finish) => {
      assert_point_for_shape_test(start, 15.0, 20.0)
      assert_point_for_shape_test(control1, 15.0, 22.761423749153966)
      assert_point_for_shape_test(control2, 12.761423749153966, 25.0)
      assert_point_for_shape_test(finish, 10.0, 25.0)
    }
    _ => fail("expected circle segment to be bezier")
  }
  match (subpath.segments[0], subpath.segments[1]) {
    (PdfPathBezier(_, _, _, first_end), PdfPathBezier(second_start, _, _, _)) =>
      assert_point_for_shape_test(second_start, first_end.x, first_end.y)
    _ => fail("expected connected bezier circle segments")
  }
}
