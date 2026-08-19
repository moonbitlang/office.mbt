///|
/// Dispatch `algorithm` onto the official `moonbitlang/x/crypto`
/// one-shot hash functions, hashing the concatenation of `parts`.
/// Returns empty bytes for unknown algorithms (matches the legacy
/// in-repo crypto package contract).
fn hash_concat(algorithm : String, parts : ArrayView[BytesView]) -> Bytes {
  let buffer = @buffer.Buffer()
  for part in parts {
    buffer.write_bytesview(part)
  }
  let data = buffer.to_bytes()
  match algorithm.to_lower() {
    "md4" => Bytes::from_array(@crypto.md4(data))
    "md5" => Bytes::from_array(@crypto.md5(data))
    "ripemd-160" | "ripemd160" => Bytes::from_array(@crypto.ripemd160(data))
    "sha1" => Bytes::from_array(@crypto.sha1(data))
    "sha256" => Bytes::from_array(@crypto.sha256(data))
    "sha384" => Bytes::from_array(@crypto.sha384(data))
    "sha512" => Bytes::from_array(@crypto.sha512(data))
    _ => Default::default()
  }
}
