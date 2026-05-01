///|
fn crypt_bytes_for_test(values : ArrayView[Int]) -> @pdflite.PdfBytes {
  try! @pdflite.pdf_bytes_of_int_array(values)
}

///|
test "pdf_arc4_crypt matches standard ARC4 vectors" {
  @test.assert_eq(
    try! @pdflite.pdf_arc4_crypt(
      @ascii.encode("Key")[:],
      @ascii.encode("Plaintext")[:],
    ),
    crypt_bytes_for_test([0xBB, 0xF3, 0x16, 0xE8, 0xD9, 0x40, 0xAF, 0x0A, 0xD3]),
  )
  @test.assert_eq(
    try! @pdflite.pdf_arc4_crypt(
      @ascii.encode("Wiki")[:],
      @ascii.encode("pedia")[:],
    ),
    crypt_bytes_for_test([0x10, 0x21, 0xBF, 0x04, 0x20]),
  )
}

///|
test "pdf_arc4_crypt decrypts by applying the same stream" {
  let key = crypt_bytes_for_test([1, 2, 3, 4, 5])
  let plaintext = @ascii.encode("legacy PDF payload")
  let encrypted = try! @pdflite.pdf_arc4_crypt(key[:], plaintext[:])
  @test.assert_eq(try! @pdflite.pdf_arc4_crypt(key[:], encrypted[:]), plaintext)
  @test.assert_eq(
    try! @pdflite.pdf_arc4_crypt(key[:], Bytes::new(0)[:]),
    Bytes::new(0),
  )
}

///|
test "pdf_arc4_crypt rejects empty keys" {
  let result : Result[@pdflite.PdfBytes, Error] = try? @pdflite.pdf_arc4_crypt(
    Bytes::new(0)[:],
    @ascii.encode("data")[:],
  )
  guard result is Err(@pdflite.PdfError::CryptoKeyExpected) else {
    fail("expected CryptoKeyExpected")
  }
}

///|
test "pdf_md5_digest matches RFC 1321 vectors" {
  @test.assert_eq(
    @pdflite.pdf_md5_digest(Bytes::new(0)[:]),
    crypt_bytes_for_test([
      0xd4, 0x1d, 0x8c, 0xd9, 0x8f, 0x00, 0xb2, 0x04, 0xe9, 0x80, 0x09, 0x98, 0xec,
      0xf8, 0x42, 0x7e,
    ]),
  )
  @test.assert_eq(
    @pdflite.pdf_md5_digest(@ascii.encode("abc")[:]),
    crypt_bytes_for_test([
      0x90, 0x01, 0x50, 0x98, 0x3c, 0xd2, 0x4f, 0xb0, 0xd6, 0x96, 0x3f, 0x7d, 0x28,
      0xe1, 0x7f, 0x72,
    ]),
  )
  @test.assert_eq(
    @pdflite.pdf_md5_digest(@ascii.encode("message digest")[:]),
    crypt_bytes_for_test([
      0xf9, 0x6b, 0x69, 0x7d, 0x7c, 0xb7, 0x93, 0x8d, 0x52, 0x5a, 0x2f, 0x31, 0xaa,
      0xf1, 0x61, 0xd0,
    ]),
  )
}
