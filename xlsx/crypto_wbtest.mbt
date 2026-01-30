///|
fn bytes_to_hex(bytes : BytesView) -> String {
  let digits = "0123456789abcdef"
  let sb = StringBuilder::new()
  for b in bytes {
    let v = b.to_int()
    let hi = (v >> 4) & 0xf
    let lo = v & 0xf
    sb.write_char(digits.get_char(hi).unwrap_or('?'))
    sb.write_char(digits.get_char(lo).unwrap_or('?'))
  }
  sb.to_string()
}

///|
fn hex_value(ch : Char) -> Int raise XlsxError {
  if ch >= '0' && ch <= '9' {
    ch.to_int() - '0'.to_int()
  } else if ch >= 'a' && ch <= 'f' {
    ch.to_int() - 'a'.to_int() + 10
  } else if ch >= 'A' && ch <= 'F' {
    ch.to_int() - 'A'.to_int() + 10
  } else {
    raise XlsxError::InvalidBase64(msg="invalid hex")
  }
}

///|
fn hex_to_bytes(text : StringView) -> Bytes raise XlsxError {
  let out : Array[Byte] = Array::new(capacity=text.length() / 2)
  let mut pending_hi : Int? = None
  for ch in text {
    let v = hex_value(ch)
    match pending_hi {
      None => pending_hi = Some(v)
      Some(hi) => {
        out.push(((hi << 4) | v).to_byte())
        pending_hi = None
      }
    }
  }
  if pending_hi is Some(_) {
    raise XlsxError::InvalidBase64(msg="invalid hex length")
  }
  Bytes::from_array(out)
}

///|
test "base64 encode/decode" {
  let input = @encoding/utf8.encode("hello")
  inspect(base64_encode(input), content="aGVsbG8=")
  let decoded = base64_decode("aGVsbG8=")
  inspect(@encoding/utf8.decode(decoded), content="hello")
  let result : Result[Bytes, Error] = try? base64_decode("!!")
  inspect(result is Err(XlsxError::InvalidBase64(_)), content="true")
}

///|
test "hash vectors" {
  let data = @encoding/utf8.encode("abc")
  inspect(
    bytes_to_hex(@crypto.hash_bytes("md4", data)),
    content="a448017aaf21d8525fc10ae87aa6729d",
  )
  inspect(
    bytes_to_hex(@crypto.hash_bytes("md5", data)),
    content="900150983cd24fb0d6963f7d28e17f72",
  )
  inspect(
    bytes_to_hex(@crypto.hash_bytes("sha1", data)),
    content="a9993e364706816aba3e25717850c26c9cd0d89d",
  )
  inspect(
    bytes_to_hex(@crypto.hash_bytes("sha1", Bytes::default())),
    content="da39a3ee5e6b4b0d3255bfef95601890afd80709",
  )
  inspect(
    bytes_to_hex(
      @crypto.hash_bytes(
        "sha1",
        @encoding/utf8.encode(
          "abcdbcdecdefdefgefghfghighijhijkijkljklmnlmnomnopnopq",
        ),
      ),
    ),
    content="967b4ca81ed24d3fad00dcd88994c4e380d1090a",
  )
  inspect(
    bytes_to_hex(
      @crypto.hash_bytes("sha1", @encoding/utf8.encode(String::repeat("a", 56))),
    ),
    content="c2db330f6083854c99d4b5bfb6e8f29f201be699",
  )
  inspect(
    bytes_to_hex(@crypto.hash_bytes("sha256", data)),
    content="ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  )
  let sha384_expected = String::add(
    "cb00753f45a35e8bb5a03d699ac65007272c32ab0eded1631a8b605a43ff5bed", "8086072ba1e7cc2358baeca134c825a7",
  )
  inspect(
    bytes_to_hex(@crypto.hash_bytes("sha384", data)),
    content=sha384_expected,
  )
  let sha512_expected = String::add(
    "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a", "2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f",
  )
  inspect(
    bytes_to_hex(@crypto.hash_bytes("sha512", data)),
    content=sha512_expected,
  )
  inspect(
    bytes_to_hex(@crypto.hash_bytes("ripemd-160", data)),
    content="8eb208f7e05d987a9b044a8e98c6b087f15a0bfc",
  )
}

///|
test "aes block vectors" {
  let key = hex_to_bytes("000102030405060708090a0b0c0d0e0f")
  let plain = hex_to_bytes("00112233445566778899aabbccddeeff")
  let expected = "69c4e0d86a7b0430d8cdb78070b4c55a"
  let enc = aes_ecb_encrypt(key, plain)
  inspect(bytes_to_hex(enc), content=expected)
  let dec = aes_ecb_decrypt(key, enc)
  inspect(bytes_to_hex(dec), content="00112233445566778899aabbccddeeff")
}

///|
test "aes cbc roundtrip" {
  let key = hex_to_bytes("2b7e151628aed2a6abf7158809cf4f3c")
  let iv = hex_to_bytes("000102030405060708090a0b0c0d0e0f")
  let data = hex_to_bytes(
    String::add(
      "6bc1bee22e409f96e93d7e117393172a", "ae2d8a571e03ac9c9eb76fac45af8e51",
    ),
  )
  let enc = @crypto.aes_cbc_encrypt(key, iv, data) catch {
    _ => fail("aes_cbc_encrypt failed")
  }
  let dec = aes_cbc_decrypt(key, iv, enc)
  let expected = String::add(
    "6bc1bee22e409f96e93d7e117393172a", "ae2d8a571e03ac9c9eb76fac45af8e51",
  )
  inspect(bytes_to_hex(dec), content=expected)
}

///|
test "cfb roundtrip" {
  let builder = cfb_builder_new()
  builder.put("EncryptionInfo", @encoding/utf8.encode("info"))
  builder.put("EncryptedPackage", @encoding/utf8.encode("package"))
  let bytes = builder.write()
  let reader = cfb_read(bytes)
  let info = reader.read_stream("EncryptionInfo")
  let encrypted = reader.read_stream("EncryptedPackage")
  inspect(@encoding/utf8.decode(info), content="info")
  inspect(@encoding/utf8.decode(encrypted), content="package")
}
