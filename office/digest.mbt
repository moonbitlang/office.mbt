///|
/// Returns the SHA-256 digest of `data` as a 64-character lowercase hex
/// string.
///
/// This is the content digest for `office.dump/1` provenance records
/// (`source.sha256`) and content-addressed asset ids (`sha256-<hex>`).
/// Deterministic and pure MoonBit on every backend (delegates to
/// `moonbitlang/x/crypto`), verified against the FIPS 180-2 test vectors in
/// `digest_test.mbt`.
///
/// # Example
/// ```mbt check
/// test {
///   inspect(
///     @office.sha256_hex(b"abc"),
///     content="ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
///   )
/// }
/// ```
pub fn sha256_hex(data : BytesView) -> String {
  @crypto.bytes_to_hex_string(@crypto.sha256(data))
}
