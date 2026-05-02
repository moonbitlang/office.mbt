///|
pub(all) struct Point2 {
  x : Double
  y : Double
} derive(Debug, Eq, ToJson)

///|
pub(all) enum TransformOp {
  Scale(Point2, Double, Double)
  Rotate(Point2, Double)
  Translate(Double, Double)
  ShearX(Point2, Double)
  ShearY(Point2, Double)
} derive(Debug, Eq, ToJson)

///|
pub(all) struct TransformMatrix {
  a : Double
  b : Double
  c : Double
  d : Double
  e : Double
  f : Double
} derive(Debug, Eq, ToJson)

///|
pub(all) struct TransformDecomposition {
  scale : Double
  aspect : Double
  rotation : Double
  shear : Double
  translate_x : Double
  translate_y : Double
} derive(Debug, Eq, ToJson)

///|
pub fn point2(x : Double, y : Double) -> Point2 {
  { x, y }
}

///|
pub let transform_identity_matrix : TransformMatrix = {
  a: 1.0,
  b: 0.0,
  c: 0.0,
  d: 1.0,
  e: 0.0,
  f: 0.0,
}

///|
pub fn transform_translate(tx : Double, ty : Double) -> TransformMatrix {
  { ..transform_identity_matrix, e: tx, f: ty }
}

///|
pub fn transform_matrix_compose(
  after : TransformMatrix,
  before : TransformMatrix,
) -> TransformMatrix {
  {
    a: after.a * before.a + after.c * before.b,
    c: after.a * before.c + after.c * before.d,
    e: after.a * before.e + after.c * before.f + after.e,
    b: after.b * before.a + after.d * before.b,
    d: after.b * before.c + after.d * before.d,
    f: after.b * before.e + after.d * before.f + after.f,
  }
}

///|
pub fn transform_scale(
  origin : Point2,
  sx : Double,
  sy : Double,
) -> TransformMatrix {
  let translate = transform_translate(-origin.x, -origin.y)
  let translate_back = transform_translate(origin.x, origin.y)
  transform_matrix_compose(
    translate_back,
    transform_matrix_compose(
      { ..transform_identity_matrix, a: sx, d: sy },
      translate,
    ),
  )
}

///|
pub fn transform_rotate(origin : Point2, angle : Double) -> TransformMatrix {
  let translate = transform_translate(-origin.x, -origin.y)
  let translate_back = transform_translate(origin.x, origin.y)
  transform_matrix_compose(
    translate_back,
    transform_matrix_compose(
      {
        ..transform_identity_matrix,
        a: @math.cos(angle),
        c: -@math.sin(angle),
        b: @math.sin(angle),
        d: @math.cos(angle),
      },
      translate,
    ),
  )
}

///|
pub fn transform_shear_x(origin : Point2, factor : Double) -> TransformMatrix {
  let translate = transform_translate(-origin.x, -origin.y)
  let translate_back = transform_translate(origin.x, origin.y)
  transform_matrix_compose(
    translate_back,
    transform_matrix_compose(
      { ..transform_identity_matrix, c: factor },
      translate,
    ),
  )
}

///|
pub fn transform_shear_y(origin : Point2, factor : Double) -> TransformMatrix {
  let translate = transform_translate(-origin.x, -origin.y)
  let translate_back = transform_translate(origin.x, origin.y)
  transform_matrix_compose(
    translate_back,
    transform_matrix_compose(
      { ..transform_identity_matrix, b: factor },
      translate,
    ),
  )
}

///|
pub fn TransformMatrix::apply(self : TransformMatrix, point : Point2) -> Point2 {
  {
    x: point.x * self.a + point.y * self.c + self.e,
    y: point.x * self.b + point.y * self.d + self.f,
  }
}

///|
pub fn transform_matrix_of_op(op : TransformOp) -> TransformMatrix {
  match op {
    Scale(origin, sx, sy) => transform_scale(origin, sx, sy)
    Rotate(origin, angle) => transform_rotate(origin, angle)
    Translate(dx, dy) => transform_translate(dx, dy)
    ShearX(origin, factor) => transform_shear_x(origin, factor)
    ShearY(origin, factor) => transform_shear_y(origin, factor)
  }
}

///|
pub fn transform_matrix_of_ops(ops : ArrayView[TransformOp]) -> TransformMatrix {
  let mut matrix = transform_identity_matrix
  for op in ops {
    matrix = transform_matrix_compose(matrix, transform_matrix_of_op(op))
  }
  matrix
}

///|
pub fn transform_apply_ops(
  ops : ArrayView[TransformOp],
  point : Point2,
) -> Point2 {
  transform_matrix_of_ops(ops).apply(point)
}

///|
pub fn TransformMatrix::invert(
  self : TransformMatrix,
) -> TransformMatrix raise PdfError {
  let divisor = self.a * self.d - self.b * self.c
  if divisor == 0.0 {
    raise MatrixNotInvertable
  }
  let scale = 1.0 / divisor
  if scale == 0.0 {
    raise MatrixNotInvertable
  }
  {
    a: scale * self.d,
    b: scale * -self.b,
    c: scale * -self.c,
    d: scale * self.a,
    e: scale * (self.c * self.f - self.d * self.e),
    f: scale * (self.b * self.e - self.a * self.f),
  }
}

///|
fn transform_safe_float(value : Double) -> Double {
  if value.is_nan() ||
    value.is_inf() ||
    value == 0.0 ||
    value.abs() < 2.2250738585072014e-308 {
    0.0
  } else {
    value
  }
}

///|
pub fn TransformMatrix::decompose(
  self : TransformMatrix,
) -> TransformDecomposition {
  let determinant = self.a * self.d - self.c * self.b
  let moda = (self.a * self.a + self.b * self.b).sqrt()
  let modb = (self.c * self.c + self.d * self.d).sqrt()
  let dot = self.a * self.c + self.b * self.d
  let scale = determinant / moda
  let aspect = if scale.abs() == 0.0 { 1.0 } else { moda / scale.abs() }
  let rotation = @math.atan2(self.b, self.a)
  let shear = if moda * modb == 0.0 {
    0.0
  } else {
    @math.PI / 2.0 - @math.acos(dot / (moda * modb))
  }
  {
    scale: transform_safe_float(scale),
    aspect: transform_safe_float(aspect),
    rotation: transform_safe_float(rotation),
    shear: transform_safe_float(shear),
    translate_x: transform_safe_float(self.e),
    translate_y: transform_safe_float(self.f),
  }
}

///|
pub fn transform_recompose(parts : TransformDecomposition) -> TransformMatrix {
  let scale_aspect_shear = {
    ..transform_identity_matrix,
    a: parts.scale.abs() * parts.aspect,
    c: parts.scale * @math.tan(parts.shear),
    d: parts.scale,
  }
  transform_matrix_compose(
    transform_translate(parts.translate_x, parts.translate_y),
    transform_matrix_compose(
      transform_rotate(point2(0.0, 0.0), parts.rotation),
      scale_aspect_shear,
    ),
  )
}
