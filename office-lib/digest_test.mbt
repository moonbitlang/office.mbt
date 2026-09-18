// FIPS 180-2 SHA-256 test vectors (appendix B plus the empty message),
// pinning the digest helper the dump/replay machinery builds on.

///|
test "sha256_hex empty message vector" {
  inspect(
    @office.sha256_hex(b""),
    content="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  )
}

///|
test "sha256_hex one-block message vector (\"abc\")" {
  inspect(
    @office.sha256_hex(b"abc"),
    content="ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  )
}

///|
test "sha256_hex two-block 448-bit message vector" {
  inspect(
    @office.sha256_hex(
      b"abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq",
    ),
    content="248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1",
  )
}

///|
#cfg(target="native")
test "sha256_hex million-'a' message vector" {
  inspect(
    @office.sha256_hex(Bytes::make(1_000_000, b'a')),
    content="cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0",
  )
}
