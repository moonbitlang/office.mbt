///|
test "encode/decode" {
  let input = @encoding/utf8.encode("hello")
  inspect(encode(input), content="aGVsbG8=")
  let decoded = decode("aGVsbG8=")
  inspect(@encoding/utf8.decode(decoded), content="hello")
  try decode("!!") catch {
    e => inspect(e is Base64Error::InvalidBase64(_), content="true")
  } noraise {
    _ => fail("expected decode to raise")
  }
}

///|
test "encode padding variants" {
  inspect(encode(@encoding/utf8.encode("f")), content="Zg==")
  inspect(encode(@encoding/utf8.encode("fo")), content="Zm8=")
  inspect(encode(@encoding/utf8.encode("foo")), content="Zm9v")
}

///|
test "decode invalid length and padding" {
  try decode("a") catch {
    e => inspect(e is Base64Error::InvalidBase64(_), content="true")
  } noraise {
    _ => fail("expected decode to raise")
  }
  try decode("====") catch {
    e => inspect(e is Base64Error::InvalidBase64(_), content="true")
  } noraise {
    _ => fail("expected decode to raise")
  }
}

///|
test "decode rejects non-ascii and chars after padding" {
  try decode("Zg==A") catch {
    e => inspect(e is Base64Error::InvalidBase64(_), content="true")
  } noraise {
    _ => fail("expected decode to raise")
  }
  try decode("Zg==ÿ") catch {
    e => inspect(e is Base64Error::InvalidBase64(_), content="true")
  } noraise {
    _ => fail("expected decode to raise")
  }
}
