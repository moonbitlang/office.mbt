///|
test "PdfBytes preserve byte-oriented PDF data" {
  let header : FixedArray[Int] = [0x25, 0x50, 0x44, 0x46, 0xFF]
  let bytes = try! @pdflite.pdf_bytes_of_int_array(header)
  @test.assert_eq(@pdflite.pdf_bytes_length(bytes), 5)
  @test.assert_eq(@pdflite.pdf_bytes_get(bytes, 0), Some(0x25))
  @test.assert_eq(@pdflite.pdf_bytes_get(bytes, 4), Some(0xFF))
  @test.assert_eq(@pdflite.pdf_bytes_get(bytes, 5), None)
  @test.assert_eq(
    @pdflite.pdf_bytes_to_array(bytes).map(byte => byte.to_int()),
    [0x25, 0x50, 0x44, 0x46, 0xFF],
  )
  @test.assert_eq(@pdflite.pdf_bytes_to_fixed_array(bytes)[4].to_int(), 0xFF)
  let raw : FixedArray[Byte] = [0x00, 0xFF]
  let from_fixed = @pdflite.pdf_bytes_of_array_view(raw)
  @test.assert_eq(@pdflite.pdf_bytes_get(from_fixed, 1), Some(0xFF))
  let growable : Array[Byte] = [0x7F, 0x80]
  let from_growable = @pdflite.pdf_bytes_of_array_view(growable)
  @test.assert_eq(@pdflite.pdf_bytes_get(from_growable, 1), Some(0x80))
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
  let raw_name : FixedArray[Int] = [0x2F, 0x54, 0x79, 0x70, 0x65]
  let name_bytes = try! @pdflite.pdf_bytes_of_int_array(raw_name)
  let name = @pdflite.pdf_name_of_bytes(name_bytes)
  @test.assert_eq(name.byte_length(), 5)
  @test.assert_eq(@pdflite.pdf_bytes_get(name.bytes(), 0), Some(0x2F))
}
