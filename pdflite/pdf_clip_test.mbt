///|
fn assert_close_for_clip_test(actual : Double, expected : Double) -> Unit raise {
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
fn assert_clip_vertex_for_test(
  actual : @pdflite.PdfClipVertex,
  x : Double,
  y : Double,
) -> Unit raise {
  assert_close_for_clip_test(actual.x, x)
  assert_close_for_clip_test(actual.y, y)
}

///|
test "cpdf clip exposes GPC operation codes" {
  @test.assert_eq(@pdflite.PdfClipDifference.gpc_code(), 0)
  @test.assert_eq(@pdflite.PdfClipIntersection.gpc_code(), 1)
  @test.assert_eq(@pdflite.PdfClipExclusiveOr.gpc_code(), 2)
  @test.assert_eq(@pdflite.PdfClipUnion.gpc_code(), 3)
}

///|
test "cpdf clip builds null and box polygons" {
  let empty = @pdflite.pdf_clip_null_polygon()
  @test.assert_eq(@pdflite.pdf_nullpoly(), empty)
  @test.assert_eq(empty.num_contours(), 0)
  @test.assert_eq(empty.contours.length(), 0)

  let polygon = @pdflite.pdf_clip_polygon_of_box(10.0, 20.0, 30.0, 40.0)
  @test.assert_eq(
    @pdflite.pdf_gpc_polygon_of_box(10.0, 20.0, 30.0, 40.0),
    polygon,
  )
  @test.assert_eq(polygon.num_contours(), 1)
  let contour = polygon.contours[0]
  @test.assert_eq(contour.hole, false)
  @test.assert_eq(contour.hole_flag(), 0)
  @test.assert_eq(contour.num_vertices(), 4)
  assert_clip_vertex_for_test(contour.vertices[0], 10.0, 30.0)
  assert_clip_vertex_for_test(contour.vertices[1], 20.0, 30.0)
  assert_clip_vertex_for_test(contour.vertices[2], 20.0, 40.0)
  assert_clip_vertex_for_test(contour.vertices[3], 10.0, 40.0)
}

///|
test "cpdf clip make polygon preserves hole flags and copies vertices" {
  let exterior = [
    @pdflite.pdf_clip_vertex(0.0, 0.0),
    @pdflite.pdf_clip_vertex(10.0, 0.0),
    @pdflite.pdf_clip_vertex(10.0, 10.0),
    @pdflite.pdf_clip_vertex(0.0, 10.0),
  ]
  let hole = [
    @pdflite.pdf_clip_vertex(3.0, 3.0),
    @pdflite.pdf_clip_vertex(7.0, 3.0),
    @pdflite.pdf_clip_vertex(7.0, 7.0),
    @pdflite.pdf_clip_vertex(3.0, 7.0),
  ]
  let polygon = @pdflite.pdf_clip_make_polygon([false, true], [exterior, hole])
  @test.assert_eq(
    try! @pdflite.pdf_make_gpcpolygon([false, true], [exterior, hole]),
    polygon,
  )
  exterior[0] = @pdflite.pdf_clip_vertex(99.0, 99.0)

  @test.assert_eq(polygon.num_contours(), 2)
  @test.assert_eq(polygon.contours[0].hole_flag(), 0)
  @test.assert_eq(polygon.contours[1].hole_flag(), 1)
  assert_clip_vertex_for_test(polygon.contours[0].vertices[0], 0.0, 0.0)
  assert_clip_vertex_for_test(polygon.contours[1].vertices[2], 7.0, 7.0)
}

///|
test "cpdf clip make polygon rejects mismatched inputs" {
  let result = try @pdflite.pdf_clip_make_polygon([true], []) catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard result is Err(BadNumberArgument(_)) else {
    fail("expected BadNumberArgument for mismatched clip polygon inputs")
  }
}

///|
test "cpdf clip polygon serializes to JSON literal shape" {
  let polygon = @pdflite.pdf_clip_make_polygon([false], [
    [@pdflite.pdf_clip_vertex(1.0, 2.0)],
  ])
  let expected : Json = {
    "contours": [{ "hole": false, "vertices": [{ "x": 1.0, "y": 2.0 }] }],
  }
  @test.assert_eq(ToJson::to_json(polygon), expected)
}

///|
test "cpdf clip source-spelled debug printer returns printed polygon text" {
  let polygon = @pdflite.pdf_gpc_polygon_of_box(1.0, 2.5, -3.0, 4.25)
  @test.assert_eq(
    @pdflite.pdf_gpcml_printpolygon(polygon),
    @ascii.encode(
      "Contours: 1\n" +
      "  Contour with 4 vertices and hole 0\n" +
      "    {x = 1.000000, y = -3.000000}\n" +
      "    {x = 2.500000, y = -3.000000}\n" +
      "    {x = 2.500000, y = 4.250000}\n" +
      "    {x = 1.000000, y = 4.250000}\n",
    ),
  )
}
