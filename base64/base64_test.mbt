///|
test "encode/decode" {
  let input = @encoding/utf8.encode("hello")
  inspect(encode(input), content="aGVsbG8=")
  let decoded = decode("aGVsbG8=")
  inspect(@encoding/utf8.decode(decoded), content="hello")
  let result : Result[Bytes, Error] = try? decode("!!")
  inspect(result is Err(Base64Error::InvalidBase64(_)), content="true")
}
