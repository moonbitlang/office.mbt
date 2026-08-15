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
/// Hand one stream to miniz and require it to accept and reproduce `input`.
fn miniz_accepts(encoded : Bytes, input : Bytes, what : String) -> Unit raise {
  let status = Ref::{ val: 0 }
  let decoded = pdf_flate_zlib_decode_ffi(encoded, status)
  // status is the FFI's own verdict; the fallback in pdf_flate.mbt would have
  // hidden a refusal behind a successful pure decode
  assert_eq(status.val, 1, msg="miniz rejected \{what}")
  assert_eq(decoded, input, msg="miniz decoded \{what} wrong")
}

///|
test "miniz accepts and decodes what the pure encoder produces" {
  for entry in determinism_corpus() {
    let (name, input) = entry
    for level in determinism_levels() {
      miniz_accepts(
        pdf_flate_encode_view_with_level_pure(input, level),
        input,
        "\{name} at level \{level}",
      )
    }
  }
}

///|
/// The same oracle over the two match encoders called directly.
///
/// Without this the two layers never meet on the inputs that matter most.
/// `pdf_flate_encode_view_with_level_pure` selects a stored block for every
/// window-boundary case -- that is exactly why the boundary vectors call the
/// match encoders directly -- so the streams that actually carry, or
/// deliberately reject, a match at distance 32768 were the one part of the
/// corpus reaching no independent decoder at all. They were snapshotted for
/// agreement across backends and never once checked for validity.
///
/// A match encoder is entitled to refuse an input; the selector catches that
/// and falls back. A refusal is therefore not a failure here, but anything it
/// does emit has to be a stream miniz can read.
/// The `try` covers only the encode. Wrapping the oracle too would catch the
/// assertion failures it raises, so a miniz refusal would be indistinguishable
/// from an encoder refusal and the test could not fail.
test "miniz accepts what the match encoders produce directly" {
  let mut checked = 0
  for entry in determinism_corpus() {
    let (name, input) = entry
    let header = pdf_flate_default_header()
    let fixed = Some(
      pdf_flate_encode_fixed_match_view_with_header(input, header, 64),
    ) catch {
      _ => None
    }
    if fixed is Some(encoded) {
      miniz_accepts(encoded, input, "\{name} through the fixed match encoder")
      checked = checked + 1
    }
    let dynamic = Some(
      pdf_flate_encode_dynamic_match_view_with_header(input, header, 64),
    ) catch {
      _ => None
    }
    if dynamic is Some(encoded) {
      miniz_accepts(encoded, input, "\{name} through the dynamic match encoder")
      checked = checked + 1
    }
  }
  // encoders that refused everything would otherwise pass this vacuously
  assert_true(checked >= 24)
}
