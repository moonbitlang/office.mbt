///|
fn jpeg_bytes_for_test(values : ArrayView[Int]) -> @pdflite.PdfBytes {
  try! @pdflite.pdf_bytes_of_int_array(values)
}

///|
fn jpeg_bytes_to_ints_for_test(bytes : @pdflite.PdfBytes) -> Array[Int] {
  @pdflite.pdf_bytes_to_array(bytes).map(byte => byte.to_int())
}

///|
test "ByteCursor read_jpeg_data consumes through JPEG EOI marker" {
  let cursor = @pdflite.byte_cursor_of_bytes(
    jpeg_bytes_for_test([0xFF, 0xD8, 1, 2, 0xFF, 0xD9, 65, 66]),
  )
  @test.assert_eq(jpeg_bytes_to_ints_for_test(try! cursor.read_jpeg_data()), [
    0xFF, 0xD8, 1, 2, 0xFF, 0xD9,
  ])
  @test.assert_eq(cursor.position(), 6)
  @test.assert_eq(cursor.read_byte(), Some(65))
  let function_cursor = @pdflite.byte_cursor_of_bytes(
    jpeg_bytes_for_test([0xFF, 0xD8, 0xFF, 0xD9, 0]),
  )
  @test.assert_eq(
    jpeg_bytes_to_ints_for_test(
      try! @pdflite.pdf_get_jpeg_data(function_cursor),
    ),
    [0xFF, 0xD8, 0xFF, 0xD9],
  )
  @test.assert_eq(function_cursor.read_byte(), Some(0))
}

///|
test "ByteCursor read_jpeg_data ignores stuffed and bare D9 bytes" {
  let cursor = @pdflite.byte_cursor_of_bytes(
    jpeg_bytes_for_test([0xFF, 0xD8, 0xFF, 0x00, 0xD9, 0xFF, 0xD9, 7]),
  )
  @test.assert_eq(jpeg_bytes_to_ints_for_test(try! cursor.read_jpeg_data()), [
    0xFF, 0xD8, 0xFF, 0x00, 0xD9, 0xFF, 0xD9,
  ])
  @test.assert_eq(cursor.read_byte(), Some(7))
}

///|
test "ByteCursor read_jpeg_data reports missing JPEG EOI marker" {
  let cursor = @pdflite.byte_cursor_of_bytes(
    jpeg_bytes_for_test([0xFF, 0xD8, 1, 2, 0xFF]),
  )
  let result : Result[@pdflite.PdfBytes, Error] = try? cursor.read_jpeg_data()
  guard result is Err(@pdflite.PdfError::EndOfInput) else {
    fail("expected @pdflite.PdfError::EndOfInput for missing JPEG EOI marker")
  }
  @test.assert_eq(cursor.position(), cursor.length())
}
