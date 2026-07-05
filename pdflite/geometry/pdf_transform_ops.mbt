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
  [..after, ..before]
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
