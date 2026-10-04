// Fallbacks for `trig_native.mbt` on non-native targets: the `f64`
// functions rounded to `f32`. Rust's `f32` trigonometry comes from the
// platform's C library (Apple's `__sincosf_stret` is not correctly
// rounded), so upstream's VARC outlines with rotations or skews depend on
// the platform; on these targets they can differ in the last bit.

///|
fn sin_cos_f32(x : Float) -> (Float, Float) {
  let x = x.to_double()
  (Float::from_double(@math.sin(x)), Float::from_double(@math.cos(x)))
}

///|
fn tan_f32(x : Float) -> Float {
  Float::from_double(@math.tan(x.to_double()))
}
