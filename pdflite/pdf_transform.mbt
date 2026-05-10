///|
/// A two-dimensional point in PDF user-space coordinates.
pub(all) struct Point2 {
  x : Double
  y : Double
} derive(Debug, Eq, ToJson)

///|
/// A high-level affine transform operation.
///
/// Operation lists preserve CamlPDF's transform model; they can be rendered for
/// diagnostics or lowered to `TransformMatrix` for application to points.
pub(all) enum TransformOp {
  Scale(Point2, Double, Double)
  Rotate(Point2, Double)
  Translate(Double, Double)
  ShearX(Point2, Double)
  ShearY(Point2, Double)
} derive(Debug, Eq, ToJson)

///|
/// A PDF affine transform matrix.
///
/// The fields correspond to PDF's six-operand matrix `[a b c d e f]`, where a
/// point is transformed as `x' = a*x + c*y + e` and
/// `y' = b*x + d*y + f`.
pub(all) struct TransformMatrix {
  a : Double
  b : Double
  c : Double
  d : Double
  e : Double
  f : Double
} derive(Debug, Eq, ToJson)

///|
/// The decomposed components of an affine transform matrix.
///
/// Values are expressed as scale, aspect ratio, rotation, shear, and
/// translation components suitable for recomposition.
pub(all) struct TransformDecomposition {
  scale : Double
  aspect : Double
  rotation : Double
  shear : Double
  translate_x : Double
  translate_y : Double
} derive(Debug, Eq, ToJson)

///|
fn transform_point_debug_string(point : Point2) -> String {
  "(" + point.x.to_string() + ", " + point.y.to_string() + ")"
}

///|
/// Formats one transform operation in CamlPDF-compatible debug text.
pub fn TransformOp::debug_string(self : TransformOp) -> String {
  match self {
    Scale(origin, sx, sy) =>
      "Scale about " +
      transform_point_debug_string(origin) +
      " by " +
      sx.to_string() +
      " in x and " +
      sy.to_string() +
      " in y\n"
    Rotate(origin, angle) =>
      "Rotate by " +
      angle.to_string() +
      " about " +
      transform_point_debug_string(origin) +
      "\n"
    Translate(dx, dy) =>
      "Translate by " + dx.to_string() + ", " + dy.to_string() + "\n"
    ShearX(origin, factor) =>
      "Shear in X about " +
      transform_point_debug_string(origin) +
      ", proportionality constant " +
      factor.to_string() +
      "\n"
    ShearY(origin, factor) =>
      "Shear in Y about " +
      transform_point_debug_string(origin) +
      ", proportionality constant " +
      factor.to_string() +
      "\n"
  }
}

///|
/// Formats one transform operation in CamlPDF-compatible debug text.
pub fn transform_string_of_op(op : TransformOp) -> String {
  op.debug_string()
}

///|
/// Formats a transform operation list in display order.
///
/// CamlPDF prints the most recently composed operation first, so this walks the
/// input list in reverse.
pub fn transform_string_of_ops(ops : ArrayView[TransformOp]) -> String {
  let mut text = ""
  for index in 0..<ops.length() {
    text = text + ops[ops.length() - index - 1].debug_string()
  }
  text
}

///|
/// Compatibility alias for formatting a transform operation list.
pub fn transform_string_of_transform(ops : ArrayView[TransformOp]) -> String {
  transform_string_of_ops(ops)
}

///|
/// Formats a matrix as its six comma-separated operands.
pub fn TransformMatrix::debug_string(self : TransformMatrix) -> String {
  self.a.to_string() +
  ", " +
  self.b.to_string() +
  ", " +
  self.c.to_string() +
  ", " +
  self.d.to_string() +
  ", " +
  self.e.to_string() +
  ", " +
  self.f.to_string()
}

///|
/// Formats a matrix as its six comma-separated operands.
pub fn transform_string_of_matrix(matrix : TransformMatrix) -> String {
  matrix.debug_string()
}

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

///|
fn transform_ops_with_head(
  head : TransformOp,
  tail : ArrayView[TransformOp],
) -> Array[TransformOp] {
  let output = [head]
  for item in tail {
    output.push(item)
  }
  output
}

///|
/// Adds one operation to the front of an operation list, merging with the first
/// operation when the two adjacent operations are compatible.
///
/// Compatible adjacent translations, scales about the same origin, rotations
/// about the same origin, and shears about the same origin are combined to keep
/// operation lists compact.
pub fn transform_compose_op(
  op : TransformOp,
  ops : ArrayView[TransformOp],
) -> Array[TransformOp] {
  if ops.length() == 0 {
    [op]
  } else {
    let head = ops[0]
    let rest = ops[1:]
    match (head, op) {
      (Translate(dx, dy), Translate(dx2, dy2)) =>
        transform_ops_with_head(Translate(dx + dx2, dy + dy2), rest)
      (Scale(origin, sx, sy), Scale(origin2, sx2, sy2)) if origin == origin2 =>
        transform_ops_with_head(Scale(origin, sx * sx2, sy * sy2), rest)
      (Rotate(origin, angle), Rotate(origin2, angle2)) if origin == origin2 =>
        transform_ops_with_head(Rotate(origin, angle + angle2), rest)
      (ShearX(origin, factor), ShearX(origin2, factor2)) if origin == origin2 =>
        transform_ops_with_head(ShearX(origin, factor + factor2), rest)
      (ShearY(origin, factor), ShearY(origin2, factor2)) if origin == origin2 =>
        transform_ops_with_head(ShearY(origin, factor + factor2), rest)
      _ => transform_ops_with_head(op, ops)
    }
  }
}

///|
/// Concatenates two transform operation lists.
///
/// The `after` operations are placed before the `before` operations to preserve
/// the same ordering used by CamlPDF transform lists.
pub fn transform_append(
  after : ArrayView[TransformOp],
  before : ArrayView[TransformOp],
) -> Array[TransformOp] {
  let output : Array[TransformOp] = []
  for item in after {
    output.push(item)
  }
  for item in before {
    output.push(item)
  }
  output
}

///|
/// Applies this matrix to a point.
pub fn TransformMatrix::apply(self : TransformMatrix, point : Point2) -> Point2 {
  {
    x: point.x * self.a + point.y * self.c + self.e,
    y: point.x * self.b + point.y * self.d + self.f,
  }
}

///|
/// Applies a matrix to a point.
pub fn transform_apply_matrix(
  matrix : TransformMatrix,
  point : Point2,
) -> Point2 {
  matrix.apply(point)
}

///|
/// Lowers one high-level transform operation to a matrix.
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
/// Lowers an operation list to one composed matrix.
pub fn transform_matrix_of_ops(ops : ArrayView[TransformOp]) -> TransformMatrix {
  let mut matrix = transform_identity_matrix
  for op in ops {
    matrix = transform_matrix_compose(matrix, transform_matrix_of_op(op))
  }
  matrix
}

///|
/// Compatibility alias for lowering a transform operation list to a matrix.
pub fn transform_matrix_of_transform(
  ops : ArrayView[TransformOp],
) -> TransformMatrix {
  transform_matrix_of_ops(ops)
}

///|
/// Applies a transform operation list to a point.
pub fn transform_apply_ops(
  ops : ArrayView[TransformOp],
  point : Point2,
) -> Point2 {
  transform_matrix_of_ops(ops).apply(point)
}

///|
/// Compatibility alias for applying a transform operation list to a point.
pub fn transform_apply(ops : ArrayView[TransformOp], point : Point2) -> Point2 {
  transform_apply_ops(ops, point)
}

///|
/// Returns the inverse of this matrix.
///
/// Raises `PdfError::MatrixNotInvertable` when the matrix determinant is zero
/// or too small to produce a finite inverse.
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
/// Returns the inverse of a matrix.
///
/// Raises `PdfError::MatrixNotInvertable` when the matrix cannot be inverted.
pub fn transform_matrix_invert(
  matrix : TransformMatrix,
) -> TransformMatrix raise PdfError {
  matrix.invert()
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
/// Decomposes this matrix into scale, aspect, rotation, shear, and translation
/// components.
///
/// Non-finite and underflowed intermediate values are normalized to zero so the
/// result is stable for malformed or degenerate matrices.
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
/// Decomposes a matrix into scale, aspect, rotation, shear, and translation.
pub fn transform_decompose(matrix : TransformMatrix) -> TransformDecomposition {
  matrix.decompose()
}

///|
/// Recomposes a matrix from decomposed transform components.
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

///|
/// Recomposes a matrix from individual decomposition fields.
pub fn transform_recompose_components(
  scale : Double,
  aspect : Double,
  rotation : Double,
  shear : Double,
  translate_x : Double,
  translate_y : Double,
) -> TransformMatrix {
  transform_recompose({
    scale,
    aspect,
    rotation,
    shear,
    translate_x,
    translate_y,
  })
}
