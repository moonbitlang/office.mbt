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
    XlsxError::InvalidBase64(_) => ()
    _ => fail("expected InvalidBase64 for \{text}")
  } noraise {
    _ => fail("expected base64_decode to raise for \{text}")
  }
}
