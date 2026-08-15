///|
// An independent oracle for the pure encoder, native only.
//
// `pdf_flate_determinism_wbtest.mbt` round-trips the pure encoder through
// `pdf_flate_decode_view` and, on the strength of that, freezes its output.
// The round trip is weaker evidence than it looks. On wasm and js it runs the
// project's own pure decoder; on native it tries the FFI decoder and then
// *falls back* to that same pure decoder whenever the FFI rejects the stream
// (`pdf_flate.mbt:134`). Encoder and decoder also share the length and
// distance tables. So a stream that only this project accepts round-trips
// everywhere, and nothing notices.
//
// This closes that hole where it can be closed. It calls the vendored miniz
// through the FFI with no fallback and requires it to both accept the stream
// and return the original bytes. miniz is a separate implementation that has
// never seen our tables, so agreement here is real interoperability evidence
// rather than the encoder agreeing with itself.
//
// Native only, because that is the only backend where miniz exists. That is a
// genuine limit: it establishes that the *algorithm* emits standard deflate,
// and says nothing about a backend-specific lowering bug on wasm or js. The
// frozen fingerprints are what cover that, and the two are complementary --
// this one is an oracle without cross-backend reach, those have cross-backend
// reach without an oracle.

///|
test "miniz accepts and decodes what the pure encoder produces" {
  for entry in determinism_corpus() {
    let (name, input) = entry
    for level in determinism_levels() {
      let encoded = pdf_flate_encode_view_with_level_pure(input, level)
      let status = Ref::{ val: 0 }
      let decoded = pdf_flate_zlib_decode_ffi(encoded, status)
      // status is the FFI's own verdict; a fallback would have hidden it
      assert_eq(status.val, 1, msg="miniz rejected \{name} at level \{level}")
      assert_eq(
        decoded,
        input,
        msg="miniz decoded \{name} at level \{level} wrong",
      )
    }
  }
}
