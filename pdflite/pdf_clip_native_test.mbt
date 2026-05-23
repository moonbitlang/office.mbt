///|
fn clip_native_assert_close_for_test(
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
fn clip_native_bounds_for_test(
  contour : @pdflite.PdfClipContour,
) -> (Double, Double, Double, Double) raise {
  guard contour.vertices.length() > 0 else {
    fail("expected non-empty contour")
  }
  let first = contour.vertices[0]
  let mut xmin = first.x
  let mut xmax = first.x
  let mut ymin = first.y
  let mut ymax = first.y
  for vertex in contour.vertices {
    if vertex.x < xmin {
      xmin = vertex.x
    }
    if vertex.x > xmax {
      xmax = vertex.x
    }
    if vertex.y < ymin {
      ymin = vertex.y
    }
    if vertex.y > ymax {
      ymax = vertex.y
    }
  }
  (xmin, xmax, ymin, ymax)
}

///|
fn clip_native_assert_bounds_for_test(
  contour : @pdflite.PdfClipContour,
  xmin : Double,
  xmax : Double,
  ymin : Double,
  ymax : Double,
) -> Unit raise {
  let (actual_xmin, actual_xmax, actual_ymin, actual_ymax) = clip_native_bounds_for_test(
    contour,
  )
  clip_native_assert_close_for_test(actual_xmin, xmin)
  clip_native_assert_close_for_test(actual_xmax, xmax)
  clip_native_assert_close_for_test(actual_ymin, ymin)
  clip_native_assert_close_for_test(actual_ymax, ymax)
}

///|
fn clip_native_contour_area_for_test(
  contour : @pdflite.PdfClipContour,
) -> Double {
  let mut area = 0.0
  let vertices = contour.vertices
  if vertices.length() >= 3 {
    for index in 0..<vertices.length() {
      let current = vertices[index]
      let next = vertices[(index + 1) % vertices.length()]
      area = area + current.x * next.y - next.x * current.y
    }
  }
  let absolute = if area < 0.0 { -area } else { area }
  absolute / 2.0
}

///|
fn clip_native_polygon_area_for_test(
  polygon : @pdflite.PdfClipPolygon,
) -> Double {
  let mut area = 0.0
  for contour in polygon.contours {
    area = area + clip_native_contour_area_for_test(contour)
  }
  area
}

///|
fn clip_native_assert_polygon_area_for_test(
  polygon : @pdflite.PdfClipPolygon,
  expected : Double,
) -> Unit raise {
  clip_native_assert_close_for_test(
    clip_native_polygon_area_for_test(polygon),
    expected,
  )
}

///|
test "native cpdf clip intersects overlapping boxes" {
  let left = @pdflite.pdf_clip_polygon_of_box(0.0, 10.0, 0.0, 10.0)
  let right = @pdflite.pdf_clip_polygon_of_box(5.0, 15.0, 5.0, 15.0)
  let result = @pdflite.pdf_clip_polygon_clip(PdfClipIntersection, left, right)
  @test.assert_eq(
    try! @pdflite.pdf_gpcml_clippolygon(PdfClipIntersection, left, right),
    result,
  )

  @test.assert_eq(result.num_contours(), 1)
  let contour = result.contours[0]
  @test.assert_eq(contour.hole, false)
  @test.assert_eq(contour.num_vertices(), 4)
  clip_native_assert_bounds_for_test(contour, 5.0, 10.0, 5.0, 10.0)
  clip_native_assert_polygon_area_for_test(result, 25.0)
}

///|
test "native cpdf clip differences overlapping boxes" {
  let left = @pdflite.pdf_clip_polygon_of_box(0.0, 10.0, 0.0, 10.0)
  let right = @pdflite.pdf_clip_polygon_of_box(5.0, 15.0, 5.0, 15.0)
  let result = @pdflite.pdf_clip_polygon_clip(PdfClipDifference, left, right)

  @test.assert_eq(result.num_contours(), 1)
  let contour = result.contours[0]
  @test.assert_eq(contour.hole, false)
  clip_native_assert_bounds_for_test(contour, 0.0, 10.0, 0.0, 10.0)
  clip_native_assert_polygon_area_for_test(result, 75.0)
}

///|
test "native cpdf clip exclusive-or removes overlap from boxes" {
  let left = @pdflite.pdf_clip_polygon_of_box(0.0, 10.0, 0.0, 10.0)
  let right = @pdflite.pdf_clip_polygon_of_box(5.0, 15.0, 5.0, 15.0)
  let result = @pdflite.pdf_clip_polygon_clip(PdfClipExclusiveOr, left, right)

  guard result.num_contours() > 0 else { fail("expected non-empty xor result") }
  for contour in result.contours {
    @test.assert_eq(contour.hole, false)
  }
  clip_native_assert_polygon_area_for_test(result, 150.0)
}

///|
test "native cpdf clip returns null polygon for disjoint intersection" {
  let left = @pdflite.pdf_clip_polygon_of_box(0.0, 1.0, 0.0, 1.0)
  let right = @pdflite.pdf_clip_polygon_of_box(2.0, 3.0, 2.0, 3.0)
  let result = @pdflite.PdfClipIntersection.clip_polygons(left, right)

  @test.assert_eq(result.num_contours(), 0)
}

///|
test "native cpdf clip unions disjoint boxes as two contours" {
  let left = @pdflite.pdf_clip_polygon_of_box(0.0, 1.0, 0.0, 1.0)
  let right = @pdflite.pdf_clip_polygon_of_box(2.0, 3.0, 2.0, 3.0)
  let result = @pdflite.pdf_clip_polygon_clip(PdfClipUnion, left, right)

  @test.assert_eq(result.num_contours(), 2)
  for contour in result.contours {
    @test.assert_eq(contour.hole, false)
    @test.assert_eq(contour.num_vertices(), 4)
  }
}
