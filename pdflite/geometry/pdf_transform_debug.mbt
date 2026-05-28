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
