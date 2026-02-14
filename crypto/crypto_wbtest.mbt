///|
test "crypto internal aes cbc encrypt/decrypt roundtrip" {
  let data = b"0123456789abcdef0123456789abcdef"
  let key256 = b"0123456789abcdef0123456789abcdef"
  let iv = b"0000000000000000"
  let cbc256 = aes_cbc_encrypt(key256, iv, data)
  let cbc256_dec = aes_cbc_decrypt(key256, iv, cbc256)
  inspect(cbc256_dec, content="b\"0123456789abcdef0123456789abcdef\"")
}

///|
test "crypto internal aes cbc encrypt invalid lengths" {
  let key128 = b"0123456789abcdef"
  let data = b"0123456789abcdef0123456789abcdef"
  let bad_iv : Result[Bytes, Error] = try? aes_cbc_encrypt(key128, b"iv", data)
  inspect(bad_iv is Err(CryptoError::InvalidCrypto(_)), content="true")
  let bad_len_cbc_enc : Result[Bytes, Error] = try? aes_cbc_encrypt(
    key128, b"0000000000000000", b"123",
  )
  inspect(bad_len_cbc_enc is Err(CryptoError::InvalidCrypto(_)), content="true")
}

///|
test "crypto internal hash_bytes wrapper" {
  let data = b"abc"
  inspect(
    hash_bytes("sha256", data) == hash_concat("sha256", [data]),
    content="true",
  )
  inspect(hash_bytes("UNKNOWN_ALGO", data).length(), content="0")
}

///|
test "crypto internal big-endian helpers" {
  let bytes32 : Bytes = b"\x01\x02\x03\x04"
  inspect(u32_from_be(bytes32, 0), content="16909060")

  let bytes64 : Bytes = b"\x01\x02\x03\x04\x05\x06\x07\x08"
  inspect(u64_from_be(bytes64, 0), content="72623859790382856")

  let out : Array[Byte] = []
  push_u32_be(out, 0x01020304U)
  inspect(Bytes::from_array(out), content="b\"\\x01\\x02\\x03\\x04\"")
}
