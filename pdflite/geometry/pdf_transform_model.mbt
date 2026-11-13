///|
/// A two-dimensional point in PDF user-space coordinates.
#derive(Debug, Eq, ToJson)
pub(all) struct Point2 {
  x : Double
  y : Double
}

///|
/// A high-level affine transform operation.
///
/// Operation lists preserve CamlPDF's transform model; they can be rendered for
/// diagnostics or lowered to `TransformMatrix` for application to points.
#derive(Debug, Eq, ToJson)
pub(all) enum TransformOp {
  Scale(Point2, Double, Double)
  Rotate(Point2, Double)
  Translate(Double, Double)
  ShearX(Point2, Double)
  ShearY(Point2, Double)
}

///|
/// A PDF affine transform matrix.
///
/// The fields correspond to PDF's six-operand matrix `[a b c d e f]`, where a
/// point is transformed as `x' = a*x + c*y + e` and
/// `y' = b*x + d*y + f`.
#derive(Debug, Eq, ToJson)
pub(all) struct TransformMatrix {
  a : Double
  b : Double
  c : Double
  d : Double
  e : Double
  f : Double
}

///|
/// The decomposed components of an affine transform matrix.
///
/// Values are expressed as scale, aspect ratio, rotation, shear, and
/// translation components suitable for recomposition.
#derive(Debug, Eq, ToJson)
pub(all) struct TransformDecomposition {
  scale : Double
  aspect : Double
  rotation : Double
  shear : Double
  translate_x : Double
  translate_y : Double
}
