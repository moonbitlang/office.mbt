///|
test "crypto aes ecb/cbc roundtrip (128/256)" {
  let data = b"0123456789abcdef0123456789abcdef"
  let key128 = b"0123456789abcdef"
  let key256 = b"0123456789abcdef0123456789abcdef"
  let iv = b"0000000000000000"
  let ecb128 = aes_ecb_encrypt(key128, data)
  let ecb128_dec = aes_ecb_decrypt(key128, ecb128)
  inspect(ecb128_dec, content="b\"0123456789abcdef0123456789abcdef\"")
  let ecb256 = aes_ecb_encrypt(key256, data)
  let ecb256_dec = aes_ecb_decrypt(key256, ecb256)
  inspect(ecb256_dec, content="b\"0123456789abcdef0123456789abcdef\"")
  let cbc256 = aes_cbc_encrypt(key256, iv, data)
  let cbc256_dec = aes_cbc_decrypt(key256, iv, cbc256)
  inspect(cbc256_dec, content="b\"0123456789abcdef0123456789abcdef\"")
}

///|
test "crypto aes ecb roundtrip (192)" {
  let data = b"0123456789abcdef0123456789abcdef"
  let key192 = b"0123456789abcdef01234567"
  let enc = aes_ecb_encrypt(key192, data)
  let dec = aes_ecb_decrypt(key192, enc)
  inspect(dec, content="b\"0123456789abcdef0123456789abcdef\"")
}

///|
test "crypto aes invalid key/iv/data lengths" {
  let key128 = b"0123456789abcdef"
  let data = b"0123456789abcdef0123456789abcdef"
  let bad_key : Result[Bytes, Error] = try? aes_ecb_encrypt(b"short", data)
  inspect(bad_key is Err(CryptoError::InvalidCrypto(_)), content="true")
  let bad_len : Result[Bytes, Error] = try? aes_ecb_encrypt(key128, b"123")
  inspect(bad_len is Err(CryptoError::InvalidCrypto(_)), content="true")
  let bad_iv : Result[Bytes, Error] = try? aes_cbc_encrypt(key128, b"iv", data)
  inspect(bad_iv is Err(CryptoError::InvalidCrypto(_)), content="true")
  let bad_len_dec : Result[Bytes, Error] = try? aes_ecb_decrypt(key128, b"123")
  inspect(bad_len_dec is Err(CryptoError::InvalidCrypto(_)), content="true")
  let bad_iv_dec : Result[Bytes, Error] = try? aes_cbc_decrypt(
    key128, b"iv", data,
  )
  inspect(bad_iv_dec is Err(CryptoError::InvalidCrypto(_)), content="true")
  let bad_len_cbc_enc : Result[Bytes, Error] = try? aes_cbc_encrypt(
    key128, b"0000000000000000", b"123",
  )
  inspect(bad_len_cbc_enc is Err(CryptoError::InvalidCrypto(_)), content="true")
  let bad_len_cbc_dec : Result[Bytes, Error] = try? aes_cbc_decrypt(
    key128, b"0000000000000000", b"123",
  )
  inspect(bad_len_cbc_dec is Err(CryptoError::InvalidCrypto(_)), content="true")
}

///|
test "crypto hash unknown algorithm returns empty" {
  let unknown = hash_bytes("UNKNOWN_ALGO", b"abc")
  inspect(unknown.length(), content="0")
  let known = hash_bytes("SHA256", b"abc")
  inspect(known.length() > 0, content="true")
}
