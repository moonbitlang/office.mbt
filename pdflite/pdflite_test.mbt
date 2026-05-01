///|
test "PdfBytes preserve byte-oriented PDF data" {
  let bytes = try! @pdflite.pdf_bytes_of_int_array([
    0x25, 0x50, 0x44, 0x46, 0xFF,
  ])
  @test.assert_eq(@pdflite.pdf_bytes_length(bytes), 5)
  @test.assert_eq(@pdflite.pdf_bytes_get(bytes, 0), Some(0x25))
  @test.assert_eq(@pdflite.pdf_bytes_get(bytes, 4), Some(0xFF))
  @test.assert_eq(@pdflite.pdf_bytes_get(bytes, 5), None)
  @test.assert_eq(
    @pdflite.pdf_bytes_to_array(bytes).map(byte => byte.to_int()),
    [0x25, 0x50, 0x44, 0x46, 0xFF],
  )
}

///|
test "PdfBytes reject out-of-range integers" {
  let too_large : Result[Byte, Error] = try? @pdflite.pdf_byte_of_int(256)
  guard too_large is Err(@pdflite.PdfError::InvalidByte(256)) else {
    fail("expected InvalidByte for 256")
  }
  let negative : Result[Byte, Error] = try? @pdflite.pdf_byte_of_int(-1)
  guard negative is Err(@pdflite.PdfError::InvalidByte(-1)) else {
    fail("expected InvalidByte for -1")
  }
}

///|
test "PdfName stores names as bytes" {
  let name_bytes = try! @pdflite.pdf_bytes_of_int_array([
    0x2F, 0x54, 0x79, 0x70, 0x65,
  ])
  let name = @pdflite.pdf_name_of_bytes(name_bytes)
  @test.assert_eq(name.byte_length(), 5)
  @test.assert_eq(@pdflite.pdf_bytes_get(name.bytes(), 0), Some(0x2F))
}
