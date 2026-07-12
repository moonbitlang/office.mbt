///|
/// Standard, padded base64 via the core encoding library (shared with
/// docx2html and pdflite). Used for embedded image data in a few OOXML parts.
fn base64_encode(bytes : BytesView) -> String {
  @base64.encode(bytes)
}

///|
fn base64_decode(text : StringView) -> Bytes raise XlsxError {
  // Core enforces RFC 4648 canonical decoding, which differs from the removed
  // in-repo decoder on non-standard input only: it accepts unpadded groups
  // (e.g. "Zg" -> "f") and rejects non-canonical padding (e.g. "Zh==").
  // Valid OOXML embeds standard padded base64, so real workbooks are
  // unaffected; the edge cases are pinned in base64_wbtest.mbt. The input is
  // not echoed into the error (it can be large or binary).
  @base64.decode(text) catch {
    Malformed(_) => raise InvalidBase64(msg="invalid base64 data")
  }
}

// Contract tests for the xlsx base64 wrappers (now backed by core's
// encoding/base64). Preserves the vectors from the removed in-repo base64
// package and pins the XlsxError mapping on malformed input.

///|
test "base64_encode round-trips and matches known vectors" {
  inspect(base64_encode(@encoding/utf8.encode("hello")), content="aGVsbG8=")
  let decoded = base64_decode("aGVsbG8=")
  inspect(@encoding/utf8.decode(decoded), content="hello")
}

///|
test "base64_encode padding variants" {
  inspect(base64_encode(@encoding/utf8.encode("f")), content="Zg==")
  inspect(base64_encode(@encoding/utf8.encode("fo")), content="Zm8=")
  inspect(base64_encode(@encoding/utf8.encode("foo")), content="Zm9v")
  inspect(base64_encode(@encoding/utf8.encode("")), content="")
}

///|
test "base64_decode raises XlsxError::InvalidBase64 on malformed input" {
  // Invalid length ("a" is a lone sextet).
  assert_base64_rejects("a")
  // Data after padding.
  assert_base64_rejects("Zg==A")
  // A stray non-alphabet character.
  assert_base64_rejects("Zg=@")
}

///|
/// Documents the RFC-4648-canonical decode semantics inherited from core,
/// which differ from the removed in-repo decoder ONLY on non-standard input
/// (valid OOXML always uses standard padded base64, so real workbooks are
/// unaffected). Pinned here so the behavior change is explicit.
test "base64_decode canonical-form semantics (differs from old on edge input)" {
  // Unpadded groups are ACCEPTED (the old decoder rejected these as invalid
  // length).
  inspect(@encoding/utf8.decode(base64_decode("Zg")), content="f")
  inspect(@encoding/utf8.decode(base64_decode("Zm8")), content="fo")
  // Non-canonical padding (non-zero bits before '=') is REJECTED (the old
  // decoder silently accepted these, ignoring the trailing bits).
  assert_base64_rejects("Zh==")
  assert_base64_rejects("Zm9=")
}

///|
fn assert_base64_rejects(text : String) -> Unit raise {
  try base64_decode(text) |> ignore catch {
    InvalidBase64(_) => ()
    _ => fail("expected InvalidBase64 for \{text}")
  } noraise {
    _ => fail("expected base64_decode to raise for \{text}")
  }
}
