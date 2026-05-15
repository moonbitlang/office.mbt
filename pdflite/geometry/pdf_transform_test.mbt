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
  actual : @geometry.Point2,
  expected : @geometry.Point2,
) -> Unit raise {
  assert_close_for_transform_test(actual.x, expected.x)
  assert_close_for_transform_test(actual.y, expected.y)
}

///|
fn assert_matrix_close_for_transform_test(
  actual : @geometry.TransformMatrix,
  expected : @geometry.TransformMatrix,
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
  actual : @geometry.TransformDecomposition,
  expected : @geometry.TransformDecomposition,
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
  let point = @geometry.point2(2.0, 3.0)
  @test.assert_eq(@geometry.transform_identity_matrix.apply(point), point)
  @test.assert_eq(
    @geometry.transform_translate(10.0, 20.0).apply(point),
    @geometry.point2(12.0, 23.0),
  )
  @test.assert_eq(
    @geometry.transform_scale(@geometry.point2(0.0, 0.0), 2.0, 3.0).apply(point),
    @geometry.point2(4.0, 9.0),
  )
}

///|
test "TransformMatrix rotates and shears points" {
  let quarter_turn = @geometry.transform_rotate(
    @geometry.point2(0.0, 0.0),
    1.5707963267948966,
  )
  assert_point_close_for_transform_test(
    quarter_turn.apply(@geometry.point2(1.0, 0.0)),
    @geometry.point2(0.0, 1.0),
  )
  @test.assert_eq(
    @geometry.transform_shear_x(@geometry.point2(0.0, 0.0), 2.0).apply(
      @geometry.point2(3.0, 4.0),
    ),
    @geometry.point2(11.0, 4.0),
  )
  @test.assert_eq(
    @geometry.transform_shear_y(@geometry.point2(0.0, 0.0), 2.0).apply(
      @geometry.point2(3.0, 4.0),
    ),
    @geometry.point2(3.0, 10.0),
  )
}

///|
test "Transform operations preserve CamlPDF list ordering" {
  let point = @geometry.point2(1.0, 1.0)
  let identity = @geometry.transform_identity()
  @test.assert_eq(identity, [])
  @test.assert_eq(@geometry.transform_apply(identity, point), point)
  let ops : FixedArray[@geometry.TransformOp] = [
    Translate(10.0, 20.0),
    Scale(@geometry.point2(0.0, 0.0), 2.0, 3.0),
  ]
  @test.assert_eq(
    @geometry.transform_apply_ops(ops, point),
    @geometry.point2(12.0, 23.0),
  )
  @test.assert_eq(
    @geometry.transform_apply(ops, point),
    @geometry.point2(12.0, 23.0),
  )
}

///|
test "Transform debug strings preserve CamlPDF transform ordering" {
  let origin = @geometry.point2(1.0, 2.0)
  let ops : Array[@geometry.TransformOp] = [
    Translate(10.0, 20.0),
    Scale(origin, 3.0, 4.0),
    Rotate(origin, 0.5),
    ShearX(origin, 0.25),
    ShearY(origin, 0.75),
  ]
  @test.assert_eq(
    @geometry.transform_string_of_ops(ops),
    "Shear in Y about (1, 2), proportionality constant 0.75\nShear in X about (1, 2), proportionality constant 0.25\nRotate by 0.5 about (1, 2)\nScale about (1, 2) by 3 in x and 4 in y\nTranslate by 10, 20\n",
  )
  @test.assert_eq(
    @geometry.transform_string_of_transform(ops),
    @geometry.transform_string_of_ops(ops),
  )
  @test.assert_eq(
    @geometry.transform_string_of_op(Translate(10.0, 20.0)),
    "Translate by 10, 20\n",
  )
}

///|
test "TransformMatrix debug string renders matrix components" {
  let matrix : @geometry.TransformMatrix = {
    a: 1.0,
    b: 2.0,
    c: 3.0,
    d: 4.0,
    e: 5.0,
    f: 6.0,
  }
  @test.assert_eq(matrix.debug_string(), "1, 2, 3, 4, 5, 6")
  @test.assert_eq(
    @geometry.transform_string_of_matrix(matrix),
    matrix.debug_string(),
  )
}

///|
test "transform_compose_op merges like operations at the head" {
  let origin = @geometry.point2(1.0, 2.0)
  @test.assert_eq(@geometry.transform_compose_op(Translate(1.0, 2.0), []), [
    Translate(1.0, 2.0),
  ])
  let tail : Array[@geometry.TransformOp] = [
    Scale(origin, 2.0, 3.0),
    Translate(4.0, 5.0),
  ]
  @test.assert_eq(
    @geometry.transform_compose_op(Scale(origin, 5.0, 7.0), tail),
    [Scale(origin, 10.0, 21.0), Translate(4.0, 5.0)],
  )
  @test.assert_eq(
    @geometry.transform_compose_op(Translate(6.0, 7.0), [
      Translate(1.0, 2.0),
      Rotate(origin, 0.5),
    ]),
    [Translate(7.0, 9.0), Rotate(origin, 0.5)],
  )
  @test.assert_eq(
    @geometry.transform_compose_op(Rotate(origin, 0.25), [Rotate(origin, 0.5)]),
    [Rotate(origin, 0.75)],
  )
  @test.assert_eq(
    @geometry.transform_compose_op(ShearX(origin, 0.25), [ShearX(origin, 0.5)]),
    [ShearX(origin, 0.75)],
  )
  @test.assert_eq(
    @geometry.transform_compose_op(ShearY(origin, 0.25), [ShearY(origin, 0.5)]),
    [ShearY(origin, 0.75)],
  )
  @test.assert_eq(
    @geometry.transform_compose_op(
      Scale(@geometry.point2(0.0, 0.0), 2.0, 2.0),
      tail,
    ),
    [
      Scale(@geometry.point2(0.0, 0.0), 2.0, 2.0),
      Scale(origin, 2.0, 3.0),
      Translate(4.0, 5.0),
    ],
  )
}

///|
test "transform_append preserves CamlPDF transform-list order" {
  let after : Array[@geometry.TransformOp] = [Translate(10.0, 20.0)]
  let before : Array[@geometry.TransformOp] = [
    Scale(@geometry.point2(0.0, 0.0), 2.0, 3.0),
  ]
  let appended = @geometry.transform_append(after, before)
  @test.assert_eq(appended, [
    Translate(10.0, 20.0),
    Scale(@geometry.point2(0.0, 0.0), 2.0, 3.0),
  ])
  @test.assert_eq(
    @geometry.transform_apply_ops(appended, @geometry.point2(1.0, 1.0)),
    @geometry.point2(12.0, 23.0),
  )
}

///|
test "transform_matrix_of_op covers direct operation variants" {
  let ops : FixedArray[@geometry.TransformOp] = [
    Translate(10.0, 20.0),
    Scale(@geometry.point2(0.0, 0.0), 2.0, 3.0),
  ]
  assert_matrix_close_for_transform_test(
    @geometry.transform_matrix_of_transform(ops),
    @geometry.transform_matrix_of_ops(ops),
  )
  let quarter_turn = @geometry.transform_matrix_of_op(
    Rotate(@geometry.point2(0.0, 0.0), 1.5707963267948966),
  )
  assert_point_close_for_transform_test(
    quarter_turn.apply(@geometry.point2(1.0, 0.0)),
    @geometry.point2(0.0, 1.0),
  )
  @test.assert_eq(
    @geometry.transform_matrix_of_op(ShearX(@geometry.point2(0.0, 0.0), 2.0)).apply(
      @geometry.point2(3.0, 4.0),
    ),
    @geometry.point2(11.0, 4.0),
  )
  @test.assert_eq(
    @geometry.transform_matrix_of_op(ShearY(@geometry.point2(0.0, 0.0), 2.0)).apply(
      @geometry.point2(3.0, 4.0),
    ),
    @geometry.point2(3.0, 10.0),
  )
}

///|
test "TransformMatrix inversion reverses a transform" {
  let matrix = @geometry.transform_matrix_compose(
    @geometry.transform_translate(10.0, 20.0),
    @geometry.transform_scale(@geometry.point2(0.0, 0.0), 2.0, 4.0),
  )
  let inverse = try! matrix.invert()
  let inverse_from_function = try! @geometry.transform_matrix_invert(matrix)
  let point = @geometry.point2(3.0, 5.0)
  assert_point_close_for_transform_test(
    inverse.apply(matrix.apply(point)),
    point,
  )
  assert_matrix_close_for_transform_test(inverse_from_function, inverse)
  assert_point_close_for_transform_test(
    @geometry.transform_apply_matrix(matrix, point),
    matrix.apply(point),
  )
}

///|
test "TransformMatrix inversion reports non-invertable matrices" {
  let matrix : @geometry.TransformMatrix = {
    a: 0.0,
    b: 0.0,
    c: 0.0,
    d: 0.0,
    e: 0.0,
    f: 0.0,
  }
  let result : Result[@geometry.TransformMatrix, Error] = try? matrix.invert()
  guard result is Err(@geometry.PdfError::MatrixNotInvertable) else {
    fail("expected PdfError::MatrixNotInvertable")
  }
}

///|
test "TransformMatrix inversion rejects overflow-scaled matrices" {
  let matrix : @geometry.TransformMatrix = {
    a: 1.0e308,
    b: 0.0,
    c: 0.0,
    d: 1.0e308,
    e: 0.0,
    f: 0.0,
  }
  let result : Result[@geometry.TransformMatrix, Error] = try? matrix.invert()
  guard result is Err(@geometry.PdfError::MatrixNotInvertable) else {
    fail("expected PdfError::MatrixNotInvertable")
  }
}

///|
test "TransformMatrix decompose mirrors CamlPDF scalar components" {
  assert_decomposition_close_for_transform_test(
    @geometry.transform_identity_matrix.decompose(),
    {
      scale: 1.0,
      aspect: 1.0,
      rotation: 0.0,
      shear: 0.0,
      translate_x: 0.0,
      translate_y: 0.0,
    },
  )
  assert_decomposition_close_for_transform_test(
    @geometry.transform_decompose(@geometry.transform_identity_matrix),
    @geometry.transform_identity_matrix.decompose(),
  )
  let degenerate : @geometry.TransformMatrix = {
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
  let parts : @geometry.TransformDecomposition = {
    scale: 2.0,
    aspect: 3.0,
    rotation: 0.25,
    shear: 0.1,
    translate_x: 10.0,
    translate_y: -4.0,
  }
  let matrix = @geometry.transform_recompose(parts)
  let matrix_from_components = @geometry.transform_recompose_components(
    2.0, 3.0, 0.25, 0.1, 10.0, -4.0,
  )
  assert_matrix_close_for_transform_test(matrix_from_components, matrix)
  assert_decomposition_close_for_transform_test(matrix.decompose(), parts)
  assert_matrix_close_for_transform_test(
    @geometry.transform_recompose(matrix.decompose()),
    matrix,
  )
}
