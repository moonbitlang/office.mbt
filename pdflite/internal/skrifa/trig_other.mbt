// Fallbacks for `trig_native.mbt` on non-native targets: the `f64`
// functions rounded to `f32`, which matches the (correctly rounded in
// practice) platform `sinf`/`cosf`/`tanf` but is not guaranteed to.

///|
fn sin_cos_f32(x : Float) -> (Float, Float) {
  let x = x.to_double()
  (Float::from_double(@math.sin(x)), Float::from_double(@math.cos(x)))
}

///|
fn tan_f32(x : Float) -> Float {
  Float::from_double(@math.tan(x.to_double()))
}
