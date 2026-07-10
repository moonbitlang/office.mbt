///|
test "crypto aes ecb roundtrip (128/256)" {
  let data = b"0123456789abcdef0123456789abcdef"
  let key128 = b"0123456789abcdef"
  let key256 = b"0123456789abcdef0123456789abcdef"
  let ecb128 = aes_ecb_encrypt(key128, data)
  let ecb128_dec = aes_ecb_decrypt(key128, ecb128)
  inspect(ecb128_dec, content="b\"0123456789abcdef0123456789abcdef\"")
  let ecb256 = aes_ecb_encrypt(key256, data)
  let ecb256_dec = aes_ecb_decrypt(key256, ecb256)
  inspect(ecb256_dec, content="b\"0123456789abcdef0123456789abcdef\"")
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
  try aes_ecb_encrypt(b"short", data) catch {
    e => inspect(e is InvalidCrypto(_), content="true")
  } noraise {
    _ => fail("expected aes_ecb_encrypt to raise")
  }
  try aes_ecb_encrypt(key128, b"123") catch {
    e => inspect(e is InvalidCrypto(_), content="true")
  } noraise {
    _ => fail("expected aes_ecb_encrypt to raise")
  }
  try aes_ecb_decrypt(key128, b"123") catch {
    e => inspect(e is InvalidCrypto(_), content="true")
  } noraise {
    _ => fail("expected aes_ecb_decrypt to raise")
  }
  try aes_cbc_decrypt(key128, b"iv", data) catch {
    e => inspect(e is InvalidCrypto(_), content="true")
  } noraise {
    _ => fail("expected aes_cbc_decrypt to raise")
  }
  try aes_cbc_decrypt(key128, b"0000000000000000", b"123") catch {
    e => inspect(e is InvalidCrypto(_), content="true")
  } noraise {
    _ => fail("expected aes_cbc_decrypt to raise")
  }
}

///|
test "crypto hash unknown algorithm returns empty" {
  let unknown = hash_concat("UNKNOWN_ALGO", [b"abc"])
  inspect(unknown.length(), content="0")
  let known = hash_concat("SHA256", [b"abc"])
  inspect(known.length() > 0, content="true")
}
