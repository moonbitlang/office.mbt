///|
/// Creates a two-dimensional point.
pub fn point2(x : Double, y : Double) -> Point2 {
  { x, y }
}

///|
/// The identity affine transform matrix.
pub let transform_identity_matrix : TransformMatrix = {
  a: 1.0,
  b: 0.0,
  c: 0.0,
  d: 1.0,
  e: 0.0,
  f: 0.0,
}

///|
/// Returns an empty transform operation list, representing identity.
pub fn transform_identity() -> Array[TransformOp] {
  []
}

///|
/// Creates a translation matrix.
pub fn transform_translate(tx : Double, ty : Double) -> TransformMatrix {
  { ..transform_identity_matrix, e: tx, f: ty }
}

///|
/// Composes two matrices so `before` is applied first and `after` second.
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
/// Creates a scale matrix around `origin`.
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
/// Creates a rotation matrix around `origin`.
///
/// `angle` is measured in radians.
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
/// Creates an X-shear matrix around `origin`.
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
/// Creates a Y-shear matrix around `origin`.
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
