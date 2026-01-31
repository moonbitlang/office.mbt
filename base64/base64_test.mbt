///|
test "encode/decode" {
  let input = @encoding/utf8.encode("hello")
  inspect(encode(input), content="aGVsbG8=")
  let decoded = decode("aGVsbG8=")
  inspect(@encoding/utf8.decode(decoded), content="hello")
  let result : Result[Bytes, Error] = try? decode("!!")
  inspect(result is Err(Base64Error::InvalidBase64(_)), content="true")
}

///|
test "encode padding variants" {
  inspect(encode(@encoding/utf8.encode("f")), content="Zg==")
  inspect(encode(@encoding/utf8.encode("fo")), content="Zm8=")
  inspect(encode(@encoding/utf8.encode("foo")), content="Zm9v")
}

///|
test "decode invalid length and padding" {
  let bad_len : Result[Bytes, Error] = try? decode("a")
  inspect(bad_len is Err(Base64Error::InvalidBase64(_)), content="true")
  let bad_pad : Result[Bytes, Error] = try? decode("====")
  inspect(bad_pad is Err(Base64Error::InvalidBase64(_)), content="true")
}

///|
test "decode rejects non-ascii and chars after padding" {
  let after_pad : Result[Bytes, Error] = try? decode("Zg==A")
  inspect(after_pad is Err(Base64Error::InvalidBase64(_)), content="true")
  let non_ascii : Result[Bytes, Error] = try? decode("Zg==ÿ")
  inspect(non_ascii is Err(Base64Error::InvalidBase64(_)), content="true")
}
