// Port of font-types 0.11.3 `src/fixed.rs` (subset: Fixed, F26Dot6, F2Dot14).

///|
/// 32-bit signed fixed point number with 16 bits of fraction.
pub(all) struct Fixed(Int) derive(Eq, Compare, Hash, Debug)

///|
/// 32-bit signed fixed point number with 6 bits of fraction.
pub(all) struct F26Dot6(Int) derive(Eq, Compare, Hash, Debug)

///|
/// 16-bit signed fixed point number with 14 bits of fraction.
///
/// The raw value is stored sign-extended in an `Int`.
pub(all) struct F2Dot14(Int) derive(Eq, Compare, Hash, Debug)

// ---------------------------------------------------------------------------
// Fixed (16.16)

///|
pub let fixed_int_mask : Int = 0xFFFF0000

///|
pub fn Fixed::zero() -> Fixed {
  Fixed(0)
}

///|
pub fn Fixed::one() -> Fixed {
  Fixed(0x10000)
}

///|
pub fn Fixed::neg_one() -> Fixed {
  Fixed(0xFFFF0000)
}

///|
pub fn Fixed::min_value() -> Fixed {
  Fixed(-2147483648)
}

///|
pub fn Fixed::max_value() -> Fixed {
  Fixed(2147483647)
}

///|
/// Creates a new fixed point value from the underlying bit representation.
pub fn Fixed::from_bits(bits : Int) -> Fixed {
  Fixed(bits)
}

///|
/// Returns the underlying bit representation of the value.
pub fn Fixed::to_bits(self : Fixed) -> Int {
  self.0
}

///|
/// Returns the nearest integer value.
pub fn Fixed::round(self : Fixed) -> Fixed {
  Fixed((self.0 + 0x8000) & fixed_int_mask)
}

///|
/// Returns the absolute value of the number (wrapping).
pub fn Fixed::abs(self : Fixed) -> Fixed {
  Fixed(if self.0 < 0 { -self.0 } else { self.0 })
}

///|
/// Returns the largest integer less than or equal to the number.
pub fn Fixed::floor(self : Fixed) -> Fixed {
  Fixed(self.0 & fixed_int_mask)
}

///|
/// Returns the fractional part of the number.
pub fn Fixed::fract(self : Fixed) -> Fixed {
  Fixed(self.0 - self.floor().0)
}

///|
/// Wrapping addition.
pub fn Fixed::wrapping_add(self : Fixed, other : Fixed) -> Fixed {
  Fixed(self.0 + other.0)
}

///|
/// Wrapping subtraction.
pub fn Fixed::wrapping_sub(self : Fixed, other : Fixed) -> Fixed {
  Fixed(self.0 - other.0)
}

///|
/// Saturating addition.
pub fn Fixed::saturating_add(self : Fixed, other : Fixed) -> Fixed {
  Fixed(saturate_i32(self.0.to_int64() + other.0.to_int64()))
}

///|
/// Saturating subtraction.
pub fn Fixed::saturating_sub(self : Fixed, other : Fixed) -> Fixed {
  Fixed(saturate_i32(self.0.to_int64() - other.0.to_int64()))
}

///|
/// Checked addition.
pub fn Fixed::checked_add(self : Fixed, other : Fixed) -> Fixed? {
  let r = self.0.to_int64() + other.0.to_int64()
  if r > 2147483647L || r < -2147483648L {
    None
  } else {
    Some(Fixed(r.to_int()))
  }
}

///|
pub impl Add for Fixed with fn add(self, other) {
  Fixed(self.0 + other.0)
}

///|
pub impl Sub for Fixed with fn sub(self, other) {
  Fixed(self.0 - other.0)
}

///|
pub impl Mul for Fixed with fn mul(self, other) {
  Fixed(fixed_mul_bits(self.0, other.0))
}

///|
pub impl Div for Fixed with fn div(self, other) {
  Fixed(fixed_div_bits(self.0, other.0))
}

///|
pub impl Neg for Fixed with fn neg(self) {
  Fixed(-self.0)
}

///|
/// Multiplies `self` by `a` and divides the product by `b`.
pub fn Fixed::mul_div(self : Fixed, a : Fixed, b : Fixed) -> Fixed {
  Fixed(mul_div_bits(self.0, a.0, b.0))
}

///|
/// Creates a 16.16 fixed point value from a 32 bit integer.
pub fn Fixed::from_i32(i : Int) -> Fixed {
  Fixed(i << 16)
}

///|
/// Converts a 16.16 fixed point value to a 32 bit integer, rounding off
/// the fractional bits.
pub fn Fixed::to_i32(self : Fixed) -> Int {
  (self.0 + 0x8000) >> 16
}

///|
/// Converts a 16.16 to 26.6 fixed point value.
pub fn Fixed::to_f26dot6(self : Fixed) -> F26Dot6 {
  F26Dot6((self.0 + 0x200) >> 10)
}

///|
/// Converts a 16.16 to 2.14 fixed point value.
pub fn Fixed::to_f2dot14(self : Fixed) -> F2Dot14 {
  F2Dot14(trunc_i16((self.0 + 2) >> 2))
}

///|
/// Converts a 16.16 fixed point value to a single precision floating
/// point value.
pub fn Fixed::to_f32(self : Fixed) -> Float {
  Float::from_int(self.0) * (1.0 : Float) / (65536.0 : Float)
}

///|
/// Creates a fixed point value from a f64 (rounded to the nearest value).
pub fn Fixed::from_f64(x : Double) -> Fixed {
  let frac = (if is_sign_positive(x) { 1.0 } else { 0.0 }) - 0.5
  Fixed((x * 65536.0 + frac).to_int())
}

///|
/// Returns the value as a f64 (lossless).
pub fn Fixed::to_f64(self : Fixed) -> Double {
  let int = ((self.0 & fixed_int_mask) >> 16).to_double()
  let fract = (self.0 & 0xFFFF).to_double() / 65536.0
  int + fract
}

// ---------------------------------------------------------------------------
// F26Dot6

///|
pub fn F26Dot6::zero() -> F26Dot6 {
  F26Dot6(0)
}

///|
pub fn F26Dot6::one() -> F26Dot6 {
  F26Dot6(64)
}

///|
pub fn F26Dot6::from_bits(bits : Int) -> F26Dot6 {
  F26Dot6(bits)
}

///|
pub fn F26Dot6::to_bits(self : F26Dot6) -> Int {
  self.0
}

///|
/// Returns the nearest integer value.
pub fn F26Dot6::round(self : F26Dot6) -> F26Dot6 {
  F26Dot6((self.0 + 32) & -64)
}

///|
pub fn F26Dot6::abs(self : F26Dot6) -> F26Dot6 {
  F26Dot6(if self.0 < 0 { -self.0 } else { self.0 })
}

///|
pub fn F26Dot6::floor(self : F26Dot6) -> F26Dot6 {
  F26Dot6(self.0 & -64)
}

///|
pub fn F26Dot6::fract(self : F26Dot6) -> F26Dot6 {
  F26Dot6(self.0 - self.floor().0)
}

///|
pub fn F26Dot6::from_i32(i : Int) -> F26Dot6 {
  F26Dot6(i << 6)
}

///|
pub fn F26Dot6::to_i32(self : F26Dot6) -> Int {
  (self.0 + 32) >> 6
}

///|
/// Converts a 26.6 fixed point value to a single precision floating point
/// value.
pub fn F26Dot6::to_f32(self : F26Dot6) -> Float {
  Float::from_int(self.0) * ((1.0 : Float) / (64.0 : Float))
}

///|
pub fn F26Dot6::from_f64(x : Double) -> F26Dot6 {
  let frac = (if is_sign_positive(x) { 1.0 } else { 0.0 }) - 0.5
  F26Dot6((x * 64.0 + frac).to_int())
}

///|
pub fn F26Dot6::to_f64(self : F26Dot6) -> Double {
  let int = ((self.0 & -64) >> 6).to_double()
  let fract = (self.0 & 63).to_double() / 64.0
  int + fract
}

///|
pub fn F26Dot6::mul_div(self : F26Dot6, a : F26Dot6, b : F26Dot6) -> F26Dot6 {
  F26Dot6(mul_div_bits(self.0, a.0, b.0))
}

///|
pub impl Add for F26Dot6 with fn add(self, other) {
  F26Dot6(self.0 + other.0)
}

///|
pub impl Sub for F26Dot6 with fn sub(self, other) {
  F26Dot6(self.0 - other.0)
}

///|
pub impl Mul for F26Dot6 with fn mul(self, other) {
  F26Dot6(fixed_mul_bits(self.0, other.0))
}

///|
pub impl Div for F26Dot6 with fn div(self, other) {
  F26Dot6(fixed_div_bits(self.0, other.0))
}

///|
pub impl Neg for F26Dot6 with fn neg(self) {
  F26Dot6(-self.0)
}

// ---------------------------------------------------------------------------
// F2Dot14

///|
pub fn F2Dot14::zero() -> F2Dot14 {
  F2Dot14(0)
}

///|
pub fn F2Dot14::one() -> F2Dot14 {
  F2Dot14(0x4000)
}

///|
/// Creates a value from the raw (sign-extended 16-bit) representation.
pub fn F2Dot14::from_bits(bits : Int) -> F2Dot14 {
  F2Dot14(trunc_i16(bits))
}

///|
pub fn F2Dot14::to_bits(self : F2Dot14) -> Int {
  self.0
}

///|
/// Converts a 2.14 to 16.16 fixed point value.
pub fn F2Dot14::to_fixed(self : F2Dot14) -> Fixed {
  Fixed(self.0 * 4)
}

///|
pub fn F2Dot14::to_f32(self : F2Dot14) -> Float {
  let int = Float::from_int((self.0 & -16384) >> 14)
  let fract = Float::from_int(self.0 & 0x3FFF) / (16384.0 : Float)
  int + fract
}

///|
pub fn F2Dot14::from_f32(x : Float) -> F2Dot14 {
  let frac : Float = (if is_sign_positive_f32(x) { 1.0 } else { 0.0 }) - 0.5
  F2Dot14(trunc_i16(saturate_i16((x * (16384.0 : Float) + frac).to_int())))
}

// ---------------------------------------------------------------------------
// Shared helpers

///|
fn fixed_mul_bits(a : Int, b : Int) -> Int {
  let ab = a.to_int64() * b.to_int64()
  ((ab + 0x8000L - (if ab < 0L { 1L } else { 0L })) >> 16).to_int()
}

///|
fn fixed_div_bits(a : Int, b : Int) -> Int {
  let sign = (a < 0) != (b < 0)
  let au = unsigned_abs64(a)
  let bu = unsigned_abs64(b)
  let q : UInt = if bu == 0UL {
    0x7FFFFFFFU
  } else {
    (((au << 16) + (bu >> 1)) / bu).to_uint()
  }
  let q = q.reinterpret_as_int()
  if sign {
    -q
  } else {
    q
  }
}

///|
fn mul_div_bits(s : Int, a : Int, b : Int) -> Int {
  let mut sign = 1
  let mut su = s.to_uint64()
  let mut au = a.to_uint64()
  let mut bu = b.to_uint64()
  if s < 0 {
    su = 0UL - su
    sign = -1
  }
  if a < 0 {
    au = 0UL - au
    sign = -sign
  }
  if b < 0 {
    bu = 0UL - bu
    sign = -sign
  }
  let result = if bu > 0UL { (su * au + (bu >> 1)) / bu } else { 0x7FFFFFFFUL }
  let r = result.to_uint().reinterpret_as_int()
  if sign < 0 {
    -r
  } else {
    r
  }
}

///|
fn unsigned_abs64(x : Int) -> UInt64 {
  if x < 0 {
    (-x.to_int64()).reinterpret_as_uint64()
  } else {
    x.to_uint64()
  }
}

///|
/// Saturates an `Int64` to the `i32` range.
pub fn saturate_i32(x : Int64) -> Int {
  if x > 2147483647L {
    2147483647
  } else if x < -2147483648L {
    -2147483648
  } else {
    x.to_int()
  }
}

///|
fn saturate_i16(x : Int) -> Int {
  if x > 32767 {
    32767
  } else if x < -32768 {
    -32768
  } else {
    x
  }
}

///|
/// Truncates to 16 bits and sign-extends (Rust `as i16`).
pub fn trunc_i16(x : Int) -> Int {
  x << 16 >> 16
}

///|
fn is_sign_positive(x : Double) -> Bool {
  x.reinterpret_as_int64() >= 0L
}

///|
fn is_sign_positive_f32(x : Float) -> Bool {
  x.reinterpret_as_int() >= 0
}
