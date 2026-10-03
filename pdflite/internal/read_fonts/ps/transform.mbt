// Port of read-fonts 0.39.2 `src/ps/transform.rs`.

///|
/// Simple fixed point matrix multiplication with a scaling factor.
///
/// Note: this transforms the translation component of `b` by the upper 2x2 of
/// `a`. This matches the offset transform FreeType uses when concatenating
/// the matrices from the top and font dicts.
pub fn combine_scaled(
  a : FontMatrix,
  b : FontMatrix,
  scale : Int,
) -> FontMatrix {
  let a = a.elements()
  let b = b.elements()
  let val = Fixed::from_i32(scale)
  let xx = a[0].mul_div(b[0], val) + a[2].mul_div(b[1], val)
  let yx = a[1].mul_div(b[0], val) + a[3].mul_div(b[1], val)
  let xy = a[0].mul_div(b[2], val) + a[2].mul_div(b[3], val)
  let yy = a[1].mul_div(b[2], val) + a[3].mul_div(b[3], val)
  let x = b[4]
  let y = b[5]
  let dx = x.mul_div(a[0], val) + y.mul_div(a[2], val)
  let dy = x.mul_div(a[1], val) + y.mul_div(a[3], val)
  FontMatrix::from_elements([xx, yx, xy, yy, dx, dy])
}

///|
fn abs64(x : Int64) -> Int64 {
  if x < 0L {
    -x
  } else {
    x
  }
}

///|
/// Check for a degenerate matrix.
fn is_degenerate(matrix : FontMatrix) -> Bool {
  let mut xx = matrix.xx.to_bits().to_int64()
  let mut yx = matrix.yx.to_bits().to_int64()
  let mut xy = matrix.xy.to_bits().to_int64()
  let mut yy = matrix.yy.to_bits().to_int64()
  let val = abs64(xx) | abs64(yx) | abs64(xy) | abs64(yy)
  if val == 0L || val > 0x7FFFFFFFL {
    return true
  }
  // Scale the matrix to avoid temp1 overflow
  let msb = 32 - val.to_int().clz() - 1
  let shift = msb - 12
  if shift > 0 {
    xx = xx >> shift
    xy = xy >> shift
    yx = yx >> shift
    yy = yy >> shift
  }
  let temp1 = 32L * abs64(xx * yy - xy * yx)
  let temp2 = xx * xx + xy * xy + yx * yx + yy * yy
  if temp1 <= temp2 {
    return true
  }
  false
}

///|
/// Combination of a matrix and optional scale.
pub(all) struct Transform {
  /// Affine font matrix.
  matrix : FontMatrix
  /// Fixed point scale factor.
  ///
  /// This is assumed to convert from font units to 26.6 values.
  scale : Fixed?
} derive(Eq, Debug)

///|
/// The transform that doesn't modify coordinates or metrics.
pub fn Transform::identity() -> Transform {
  { matrix: FontMatrix::identity(), scale: None, }
}

///|
/// Computes a scale factor for the given ppem and upem values.
pub fn Transform::compute_scale(ppem : Float, upem : Int) -> Fixed {
  Fixed::from_bits((ppem * 64.0).to_int()) /
  Fixed::from_bits(if upem > 1 { upem } else { 1 })
}

///|
/// Applies the transform to a horizontal metric such as an advance width.
pub fn Transform::transform_h_metric(self : Transform, metric : Fixed) -> Fixed {
  let mut metric = Fixed::from_bits(metric.to_i32())
  if self.matrix.xx != Fixed::one() {
    // x scale
    metric = metric * self.matrix.xx
  }
  // x translation
  metric = metric + self.matrix.dx
  if self.scale is Some(scale) {
    // Multiplying by scale converts to 26.6 but we want to keep the
    // result in 16.16
    Fixed::from_bits((metric * scale).to_bits() << 10)
  } else {
    // Metric is currently in font units. Convert back to 16.16
    Fixed::from_bits(metric.to_bits() << 16)
  }
}

///|
/// An affine matrix with a scaling factor.
pub(all) struct ScaledFontMatrix {
  /// The matrix.
  matrix : FontMatrix
  /// The dynamic scale factor used when parsing this matrix.
  scale : Int
} derive(Eq, Debug)

///|
/// Parses a font matrix using dynamic scaling factors.
///
/// Returns the matrix and an adjusted upem factor.
fn ScaledFontMatrix::parse(cursor : Cursor) -> ScaledFontMatrix? {
  let values = FixedArray::make(6, Fixed::zero())
  let scalings = FixedArray::make(6, 0)
  let mut max_scaling = -2147483648
  let mut min_scaling = 2147483647
  for i in 0..<6 {
    let (v, s) = parse_fixed_dynamic(cursor) catch { _ => return None }
    if v != Fixed::zero() {
      max_scaling = if s > max_scaling { s } else { max_scaling }
      min_scaling = if s < min_scaling { s } else { min_scaling }
    }
    values[i] = v
    scalings[i] = s
  }
  if !(max_scaling >= -9 && max_scaling <= 0) ||
    max_scaling - min_scaling < 0 ||
    max_scaling - min_scaling > 9 {
    return None
  }
  for i in 0..<6 {
    let value = values[i]
    let scaling = scalings[i]
    if value == Fixed::zero() {
      continue
    }
    let divisor = bcd_power_tens[max_scaling - scaling]
    let half_divisor = divisor >> 1
    let bits = value.to_bits()
    values[i] = if value < Fixed::zero() {
      if -2147483648 + half_divisor < bits {
        Fixed::from_bits((bits - half_divisor) / divisor)
      } else {
        Fixed::from_bits(-2147483648 / divisor)
      }
    } else if 2147483647 - half_divisor > bits {
      Fixed::from_bits((bits + half_divisor) / divisor)
    } else {
      Fixed::from_bits(2147483647 / divisor)
    }
  }
  let matrix = FontMatrix::from_elements(values)
  // Check for a degenerate matrix
  if is_degenerate(matrix) {
    return None
  }
  let scale = bcd_power_tens[-max_scaling]
  Some({ matrix, scale, })
}

///|
/// Compute a new font matrix and UPEM scale factor where the Y scale of
/// the matrix is 1.0.
pub fn ScaledFontMatrix::normalize(self : ScaledFontMatrix) -> ScaledFontMatrix {
  let matrix = self.matrix.elements()
  let mut scaled_upem = self.scale
  let factor = if matrix[3] != Fixed::zero() {
    matrix[3].abs()
  } else {
    // Use yx if yy is zero
    matrix[1].abs()
  }
  if factor != Fixed::one() {
    scaled_upem = (Fixed::from_bits(scaled_upem) / factor).to_bits()
    for i in 0..<6 {
      matrix[i] = matrix[i] / factor
    }
  }
  // FT shifts off the fractional parts of the translation?
  for i in 4..<6 {
    matrix[i] = Fixed::from_bits(matrix[i].to_bits() >> 16)
  }
  { matrix: FontMatrix::from_elements(matrix), scale: scaled_upem, }
}
