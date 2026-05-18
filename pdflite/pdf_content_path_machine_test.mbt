///|
fn content_path_apply_for_test(
  ops : ArrayView[@pdflite.PdfContentOp],
) -> @pdflite.PdfContentPathOpResult {
  let mut result : @pdflite.PdfContentPathOpResult = {
    partial_path: PdfContentNoPartialPath,
    drawn_path: None,
  }
  for op in ops {
    result = result.partial_path.content_apply_path_op(op)
  }
  result
}

///|
fn content_path_assert_point_for_test(
  point : @pdflite.Point2,
  x : Double,
  y : Double,
) -> Unit raise {
  @test.assert_eq(point, @pdflite.point2(x, y))
}

///|
test "cpdfcontent path machine splits move-to subpaths before stroke" {
  let result = content_path_apply_for_test([
    Op_m(0.0, 0.0),
    Op_l(1.0, 0.0),
    Op_m(2.0, 2.0),
    Op_l(3.0, 2.0),
    Op_S,
  ])
  guard result.drawn_path is Some(drawn) else { fail("expected stroked path") }
  @test.assert_eq(drawn.stroked, true)
  @test.assert_eq(drawn.filled, false)
  @test.assert_eq(drawn.path.winding_rule, PdfPathEvenOdd)
  @test.assert_eq(drawn.path.subpaths.length(), 2)
  @test.assert_eq(drawn.path.subpaths[0].closure, PdfPathOpen)
  @test.assert_eq(drawn.path.subpaths[1].closure, PdfPathOpen)
  match drawn.path.subpaths[0].segments[0] {
    PdfPathStraight(start, finish) => {
      content_path_assert_point_for_test(start, 0.0, 0.0)
      content_path_assert_point_for_test(finish, 1.0, 0.0)
    }
    _ => fail("expected first subpath straight segment")
  }
  match drawn.path.subpaths[1].segments[0] {
    PdfPathStraight(start, finish) => {
      content_path_assert_point_for_test(start, 2.0, 2.0)
      content_path_assert_point_for_test(finish, 3.0, 2.0)
    }
    _ => fail("expected second subpath straight segment")
  }
  guard result.partial_path is PdfContentPartialPath(state) else {
    fail("expected cleared partial path")
  }
  @test.assert_eq(state.segments.length(), 0)
  @test.assert_eq(state.subpaths.length(), 0)
}

///|
test "cpdfcontent path machine closes fill paths and wrapper matches method" {
  let partial = @pdflite.pdf_content_no_partial_path().content_apply_path_op(
      Op_m(0.0, 0.0),
    ).partial_path.content_apply_path_op(Op_l(1.0, 0.0)).partial_path
  let result = @pdflite.pdf_content_apply_path_op(partial, Op_f)
  guard result.drawn_path is Some(drawn) else { fail("expected filled path") }
  @test.assert_eq(drawn.stroked, false)
  @test.assert_eq(drawn.filled, true)
  @test.assert_eq(drawn.path.winding_rule, PdfPathNonZero)
  @test.assert_eq(drawn.path.subpaths.length(), 1)
  @test.assert_eq(drawn.path.subpaths[0].closure, PdfPathClosed)
}

///|
test "cpdfcontent path machine handles curve shorthands and even-odd fill" {
  let result = content_path_apply_for_test([
    Op_m(0.0, 0.0),
    Op_v(1.0, 0.0, 1.0, 1.0),
    Op_y(2.0, 1.0, 2.0, 2.0),
    Op_fstar,
  ])
  guard result.drawn_path is Some(drawn) else {
    fail("expected even-odd filled path")
  }
  @test.assert_eq(drawn.filled, true)
  @test.assert_eq(drawn.stroked, false)
  @test.assert_eq(drawn.path.winding_rule, PdfPathEvenOdd)
  let segments = drawn.path.subpaths[0].segments
  @test.assert_eq(drawn.path.subpaths[0].closure, PdfPathOpen)
  match segments[0] {
    PdfPathBezier(start, control1, control2, finish) => {
      content_path_assert_point_for_test(start, 0.0, 0.0)
      content_path_assert_point_for_test(control1, 0.0, 0.0)
      content_path_assert_point_for_test(control2, 1.0, 0.0)
      content_path_assert_point_for_test(finish, 1.0, 1.0)
    }
    _ => fail("expected v shorthand bezier")
  }
  match segments[1] {
    PdfPathBezier(start, control1, control2, finish) => {
      content_path_assert_point_for_test(start, 1.0, 1.0)
      content_path_assert_point_for_test(control1, 2.0, 1.0)
      content_path_assert_point_for_test(control2, 2.0, 2.0)
      content_path_assert_point_for_test(finish, 2.0, 2.0)
    }
    _ => fail("expected y shorthand bezier")
  }
}

///|
test "cpdfcontent path machine matches cpdf Bstar close behavior" {
  let direct = content_path_apply_for_test([
    Op_m(0.0, 0.0),
    Op_l(1.0, 0.0),
    Op_Bstar,
  ])
  guard direct.drawn_path is Some(direct_drawn) else {
    fail("expected direct Bstar path")
  }
  @test.assert_eq(direct_drawn.filled, true)
  @test.assert_eq(direct_drawn.stroked, true)
  @test.assert_eq(direct_drawn.path.winding_rule, PdfPathEvenOdd)
  @test.assert_eq(direct_drawn.path.subpaths.length(), 1)
  @test.assert_eq(direct_drawn.path.subpaths[0].closure, PdfPathClosed)
  let lower = content_path_apply_for_test([
    Op_m(0.0, 0.0),
    Op_l(1.0, 0.0),
    Op_bstar,
  ])
  guard lower.drawn_path is Some(lower_drawn) else {
    fail("expected lowercase bstar path")
  }
  @test.assert_eq(lower_drawn.path.subpaths.length(), 2)
  @test.assert_eq(lower_drawn.path.subpaths[0].closure, PdfPathClosed)
  @test.assert_eq(lower_drawn.path.subpaths[0].segments.length(), 1)
  @test.assert_eq(lower_drawn.path.subpaths[1].closure, PdfPathClosed)
  @test.assert_eq(lower_drawn.path.subpaths[1].segments.length(), 0)
}

///|
test "cpdfcontent path machine expands rectangle operator before painting" {
  let result = content_path_apply_for_test([
    Op_re(10.0, 20.0, 30.0, 40.0),
    Op_Bstar,
  ])
  guard result.drawn_path is Some(drawn) else {
    fail("expected painted rectangle")
  }
  @test.assert_eq(drawn.filled, true)
  @test.assert_eq(drawn.stroked, true)
  @test.assert_eq(drawn.path.winding_rule, PdfPathEvenOdd)
  @test.assert_eq(drawn.path.subpaths.length(), 2)
  let subpath = drawn.path.subpaths[0]
  @test.assert_eq(subpath.closure, PdfPathClosed)
  @test.assert_eq(subpath.segments.length(), 3)
  match subpath.segments[2] {
    PdfPathStraight(start, finish) => {
      content_path_assert_point_for_test(start, 40.0, 60.0)
      content_path_assert_point_for_test(finish, 10.0, 60.0)
    }
    _ => fail("expected rectangle straight segment")
  }
  @test.assert_eq(drawn.path.subpaths[1].closure, PdfPathClosed)
  @test.assert_eq(drawn.path.subpaths[1].segments.length(), 0)
  let cleared = result.partial_path.content_apply_path_op(Op_n)
  @test.assert_eq(cleared.partial_path, PdfContentNoPartialPath)
  @test.assert_eq(cleared.drawn_path, None)
}
