///|
fn assert_close_for_transform_test(
  actual : Double,
  expected : Double,
) -> Unit raise {
  if (actual - expected).abs() > 0.000000001 {
    fail("double values were not close enough")
  }
}

///|
fn assert_point_close_for_transform_test(
  actual : @pdflite.Point2,
  expected : @pdflite.Point2,
) -> Unit raise {
  assert_close_for_transform_test(actual.x, expected.x)
  assert_close_for_transform_test(actual.y, expected.y)
}

///|
fn assert_matrix_close_for_transform_test(
  actual : @pdflite.TransformMatrix,
  expected : @pdflite.TransformMatrix,
) -> Unit raise {
  assert_close_for_transform_test(actual.a, expected.a)
  assert_close_for_transform_test(actual.b, expected.b)
  assert_close_for_transform_test(actual.c, expected.c)
  assert_close_for_transform_test(actual.d, expected.d)
  assert_close_for_transform_test(actual.e, expected.e)
  assert_close_for_transform_test(actual.f, expected.f)
}

///|
fn assert_decomposition_close_for_transform_test(
  actual : @pdflite.TransformDecomposition,
  expected : @pdflite.TransformDecomposition,
) -> Unit raise {
  assert_close_for_transform_test(actual.scale, expected.scale)
  assert_close_for_transform_test(actual.aspect, expected.aspect)
  assert_close_for_transform_test(actual.rotation, expected.rotation)
  assert_close_for_transform_test(actual.shear, expected.shear)
  assert_close_for_transform_test(actual.translate_x, expected.translate_x)
  assert_close_for_transform_test(actual.translate_y, expected.translate_y)
}

///|
test "TransformMatrix identity translate and scale points" {
  let point = @pdflite.point2(2.0, 3.0)
  @test.assert_eq(@pdflite.transform_identity_matrix.apply(point), point)
  @test.assert_eq(
    @pdflite.transform_translate(10.0, 20.0).apply(point),
    @pdflite.point2(12.0, 23.0),
  )
  @test.assert_eq(
    @pdflite.transform_scale(@pdflite.point2(0.0, 0.0), 2.0, 3.0).apply(point),
    @pdflite.point2(4.0, 9.0),
  )
}

///|
test "TransformMatrix rotates and shears points" {
  let quarter_turn = @pdflite.transform_rotate(
    @pdflite.point2(0.0, 0.0),
    1.5707963267948966,
  )
  assert_point_close_for_transform_test(
    quarter_turn.apply(@pdflite.point2(1.0, 0.0)),
    @pdflite.point2(0.0, 1.0),
  )
  @test.assert_eq(
    @pdflite.transform_shear_x(@pdflite.point2(0.0, 0.0), 2.0).apply(
      @pdflite.point2(3.0, 4.0),
    ),
    @pdflite.point2(11.0, 4.0),
  )
  @test.assert_eq(
    @pdflite.transform_shear_y(@pdflite.point2(0.0, 0.0), 2.0).apply(
      @pdflite.point2(3.0, 4.0),
    ),
    @pdflite.point2(3.0, 10.0),
  )
}

///|
test "Transform operations preserve CamlPDF list ordering" {
  let ops : FixedArray[@pdflite.TransformOp] = [
    Translate(10.0, 20.0),
    Scale(@pdflite.point2(0.0, 0.0), 2.0, 3.0),
  ]
  @test.assert_eq(
    @pdflite.transform_apply_ops(ops, @pdflite.point2(1.0, 1.0)),
    @pdflite.point2(12.0, 23.0),
  )
}

///|
test "transform_matrix_of_op covers direct operation variants" {
  let quarter_turn = @pdflite.transform_matrix_of_op(
    Rotate(@pdflite.point2(0.0, 0.0), 1.5707963267948966),
  )
  assert_point_close_for_transform_test(
    quarter_turn.apply(@pdflite.point2(1.0, 0.0)),
    @pdflite.point2(0.0, 1.0),
  )
  @test.assert_eq(
    @pdflite.transform_matrix_of_op(ShearX(@pdflite.point2(0.0, 0.0), 2.0)).apply(
      @pdflite.point2(3.0, 4.0),
    ),
    @pdflite.point2(11.0, 4.0),
  )
  @test.assert_eq(
    @pdflite.transform_matrix_of_op(ShearY(@pdflite.point2(0.0, 0.0), 2.0)).apply(
      @pdflite.point2(3.0, 4.0),
    ),
    @pdflite.point2(3.0, 10.0),
  )
}

///|
test "TransformMatrix inversion reverses a transform" {
  let matrix = @pdflite.transform_matrix_compose(
    @pdflite.transform_translate(10.0, 20.0),
    @pdflite.transform_scale(@pdflite.point2(0.0, 0.0), 2.0, 4.0),
  )
  let inverse = try! matrix.invert()
  let point = @pdflite.point2(3.0, 5.0)
  assert_point_close_for_transform_test(
    inverse.apply(matrix.apply(point)),
    point,
  )
}

///|
test "TransformMatrix inversion reports non-invertable matrices" {
  let matrix : @pdflite.TransformMatrix = {
    a: 0.0,
    b: 0.0,
    c: 0.0,
    d: 0.0,
    e: 0.0,
    f: 0.0,
  }
  let result : Result[@pdflite.TransformMatrix, Error] = try? matrix.invert()
  guard result is Err(@pdflite.PdfError::MatrixNotInvertable) else {
    fail("expected MatrixNotInvertable")
  }
}

///|
test "TransformMatrix inversion rejects overflow-scaled matrices" {
  let matrix : @pdflite.TransformMatrix = {
    a: 1.0e308,
    b: 0.0,
    c: 0.0,
    d: 1.0e308,
    e: 0.0,
    f: 0.0,
  }
  let result : Result[@pdflite.TransformMatrix, Error] = try? matrix.invert()
  guard result is Err(@pdflite.PdfError::MatrixNotInvertable) else {
    fail("expected MatrixNotInvertable")
  }
}

///|
test "TransformMatrix decompose mirrors CamlPDF scalar components" {
  assert_decomposition_close_for_transform_test(
    @pdflite.transform_identity_matrix.decompose(),
    {
      scale: 1.0,
      aspect: 1.0,
      rotation: 0.0,
      shear: 0.0,
      translate_x: 0.0,
      translate_y: 0.0,
    },
  )
  let degenerate : @pdflite.TransformMatrix = {
    a: 0.0,
    b: 0.0,
    c: 0.0,
    d: 0.0,
    e: 0.0,
    f: 0.0,
  }
  assert_decomposition_close_for_transform_test(degenerate.decompose(), {
    scale: 0.0,
    aspect: 0.0,
    rotation: 0.0,
    shear: 0.0,
    translate_x: 0.0,
    translate_y: 0.0,
  })
}

///|
test "transform_recompose rebuilds decomposed matrix components" {
  let parts : @pdflite.TransformDecomposition = {
    scale: 2.0,
    aspect: 3.0,
    rotation: 0.25,
    shear: 0.1,
    translate_x: 10.0,
    translate_y: -4.0,
  }
  let matrix = @pdflite.transform_recompose(parts)
  assert_decomposition_close_for_transform_test(matrix.decompose(), parts)
  assert_matrix_close_for_transform_test(
    @pdflite.transform_recompose(matrix.decompose()),
    matrix,
  )
}
