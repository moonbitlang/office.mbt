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
fn assert_rectangle_for_shape_test(
  actual : @pdflite.PdfRectangle,
  min_x : Double,
  min_y : Double,
  max_x : Double,
  max_y : Double,
) -> Unit raise {
  assert_close_for_shape_test(actual.min_x, min_x)
  assert_close_for_shape_test(actual.min_y, min_y)
  assert_close_for_shape_test(actual.max_x, max_x)
  assert_close_for_shape_test(actual.max_y, max_y)
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
test "cpdf shape restrict angle preserves source edge semantics" {
  assert_close_for_shape_test(@pdflite.pdf_restrict_angle(1.0, 0.5), 1.0)
  assert_close_for_shape_test(
    @pdflite.pdf_restrict_angle(@math.PI / 2.0, 2.0 * @math.PI - 0.1),
    3.0 * @math.PI / 2.0,
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

///|
test "cpdfcontent path geometry computes segment and path bounds" {
  let straight = @pdflite.PdfPathStraight(
    @pdflite.point2(3.0, 4.0),
    @pdflite.point2(-1.0, 8.0),
  )
  assert_rectangle_for_shape_test(straight.bounds(), -1.0, 4.0, 3.0, 8.0)
  let bezier = @pdflite.PdfPathBezier(
    @pdflite.point2(10.0, 0.0),
    @pdflite.point2(-5.0, 20.0),
    @pdflite.point2(2.0, -3.0),
    @pdflite.point2(7.0, 8.0),
  )
  assert_rectangle_for_shape_test(
    @pdflite.pdf_path_segment_bounds(bezier),
    -5.0,
    -3.0,
    10.0,
    20.0,
  )
  let path : @pdflite.PdfPath = {
    winding_rule: PdfPathNonZero,
    subpaths: [
      {
        hole: PdfPathNotHole,
        closure: PdfPathOpen,
        segments: [straight, bezier],
      },
    ],
  }
  assert_rectangle_for_shape_test(path.bounds(), -5.0, -3.0, 10.0, 20.0)
  @test.assert_eq(@pdflite.pdf_path_bounds(path), path.bounds())
  let empty : @pdflite.PdfPath = { winding_rule: PdfPathEvenOdd, subpaths: [] }
  assert_rectangle_for_shape_test(empty.bounds(), 0.0, 0.0, 0.0, 0.0)
}

///|
test "cpdfcontent path geometry transforms segments and paths" {
  let matrix = @pdflite.transform_translate(10.0, -2.0)
  let segment = @pdflite.PdfPathBezier(
    @pdflite.point2(1.0, 2.0),
    @pdflite.point2(3.0, 4.0),
    @pdflite.point2(5.0, 6.0),
    @pdflite.point2(7.0, 8.0),
  )
  match segment.transform(matrix) {
    PdfPathBezier(start, control1, control2, finish) => {
      assert_point_for_shape_test(start, 11.0, 0.0)
      assert_point_for_shape_test(control1, 13.0, 2.0)
      assert_point_for_shape_test(control2, 15.0, 4.0)
      assert_point_for_shape_test(finish, 17.0, 6.0)
    }
    _ => fail("expected transformed bezier")
  }
  let path : @pdflite.PdfPath = {
    winding_rule: PdfPathEvenOdd,
    subpaths: [
      {
        hole: PdfPathHole,
        closure: PdfPathClosed,
        segments: [
          PdfPathStraight(@pdflite.point2(0.0, 0.0), @pdflite.point2(2.0, 3.0)),
        ],
      },
    ],
  }
  let transformed = @pdflite.pdf_path_transform(path, matrix)
  @test.assert_eq(transformed.winding_rule, PdfPathEvenOdd)
  @test.assert_eq(transformed.subpaths[0].hole, PdfPathHole)
  @test.assert_eq(transformed.subpaths[0].closure, PdfPathClosed)
  match transformed.subpaths[0].segments[0] {
    PdfPathStraight(start, finish) => {
      assert_point_for_shape_test(start, 10.0, -2.0)
      assert_point_for_shape_test(finish, 12.0, 1.0)
    }
    _ => fail("expected transformed straight segment")
  }
}
