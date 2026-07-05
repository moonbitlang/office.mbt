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
    @base64.Malformed(_) => raise InvalidBase64(msg="invalid base64 data")
  }
}
