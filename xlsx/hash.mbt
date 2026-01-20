///|
fn hash_concat(algorithm : String, parts : ArrayView[BytesView]) -> Bytes {
  let buffer = @buffer.new()
  for part in parts {
    buffer.write_bytesview(part)
  }
  let data = buffer.to_bytes()
  match algorithm.to_lower() {
    "md4" => md4_hash(data)
    "md5" => md5_hash(data)
    "ripemd-160" => ripemd160_hash(data)
    "sha1" => sha1_hash(data)
    "sha256" => sha256_hash(data)
    "sha384" => sha384_hash(data)
    "sha512" => sha512_hash(data)
    _ => Bytes::default()
  }
}

///|
fn hash_bytes(algorithm : String, input : BytesView) -> Bytes {
  hash_concat(algorithm, [input])
}
