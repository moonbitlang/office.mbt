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
