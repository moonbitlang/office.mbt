// Rust's `f32::sin_cos` is merged by LLVM into a single `sincosf` call; on
// Apple platforms that is `__sincosf_stret`, which can differ from
// `sinf`/`cosf` in the last place. These stubs reproduce that for
// bit-identical results.

#include <math.h>
#include <moonbit.h>

MOONBIT_FFI_EXPORT
float skrifa_sincosf_sin(float x) {
#if defined(__APPLE__)
  return __sincosf_stret(x).__sinval;
#else
  return sinf(x);
#endif
}

MOONBIT_FFI_EXPORT
float skrifa_sincosf_cos(float x) {
#if defined(__APPLE__)
  return __sincosf_stret(x).__cosval;
#else
  return cosf(x);
#endif
}
