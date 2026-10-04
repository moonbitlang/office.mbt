// The C math library functions that Rust's `f32` methods call on native
// targets, for bit-identical VARC transforms.

///|
/// `f32::sin_cos` (merged by LLVM into one `sincosf` call; on Apple
/// platforms `__sincosf_stret`).
fn sin_cos_f32(x : Float) -> (Float, Float) {
  (skrifa_sincosf_sin(x), skrifa_sincosf_cos(x))
}

///|
/// `f32::tan`.
fn tan_f32(x : Float) -> Float {
  libm_tanf(x)
}

///|
extern "C" fn libm_tanf(x : Float) -> Float = "tanf"

///|
extern "C" fn skrifa_sincosf_sin(x : Float) -> Float = "skrifa_sincosf_sin"

///|
extern "C" fn skrifa_sincosf_cos(x : Float) -> Float = "skrifa_sincosf_cos"
