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
