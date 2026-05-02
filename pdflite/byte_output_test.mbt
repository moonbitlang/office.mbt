///|
test "ByteOutput writes bytes views and ASCII without using String for payloads" {
  let output = try! @pdflite.byte_output_new(initial_size=2)
  try! output.write_byte(65)
  try! output.write_view(Bytes::from_array([0, 0xFF])[:])
  try! output.write_ascii("PDF")
  @test.assert_eq(output.position(), 6)
  @test.assert_eq(output.length(), 6)
  @test.assert_eq(@pdflite.pdf_int_array_of_bytes(output.to_bytes()[:]), [
    65, 0, 0xFF, 80, 68, 70,
  ])
}

///|
test "ByteOutput seek overwrites bytes and frozen output stays owned" {
  let output = try! @pdflite.byte_output_new()
  try! output.write_view(@ascii.encode("ABCD")[:])
  let frozen = output.to_bytes()
  try! output.seek(1)
  try! output.write_ascii("zz")
  @test.assert_eq(@pdflite.pdf_int_array_of_bytes(frozen[:]), [65, 66, 67, 68])
  @test.assert_eq(@pdflite.pdf_int_array_of_bytes(output.to_bytes()[:]), [
    65, 122, 122, 68,
  ])
}

///|
test "ByteOutput writes checked byte slices" {
  let output = try! @pdflite.byte_output_new()
  let source = @ascii.encode("012345")
  try! output.write_view_slice(source[:], 2, 3)
  @test.assert_eq(@pdflite.pdf_int_array_of_bytes(output.to_bytes()[:]), [
    50, 51, 52,
  ])
  @test.assert_eq(output.position(), 3)
  let bad_offset : Result[Unit, Error] = try? output.write_view_slice(
    source[:],
    -1,
    1,
  )
  guard bad_offset is Err(@pdflite.PdfError::InvalidCursorPosition(-1)) else {
    fail("expected InvalidCursorPosition for byte output slice")
  }
  let bad_length : Result[Unit, Error] = try? output.write_view_slice(
    source[:],
    0,
    -1,
  )
  guard bad_length is Err(@pdflite.PdfError::InvalidReadLength(-1)) else {
    fail("expected InvalidReadLength for byte output slice")
  }
  let too_long : Result[Unit, Error] = try? output.write_view_slice(
    source[:],
    4,
    3,
  )
  guard too_long is Err(@pdflite.PdfError::EndOfInput) else {
    fail("expected EndOfInput for byte output slice")
  }
  let overflow : Result[Unit, Error] = try? output.write_view_slice(
    source[:],
    2147483647,
    1,
  )
  guard overflow is Err(@pdflite.PdfError::InvalidReadLength(1)) else {
    fail("expected InvalidReadLength for byte output slice overflow")
  }
}

///|
test "ByteOutput sparse writes zero-fill skipped positions" {
  let output = try! @pdflite.byte_output_new(initial_size=1)
  try! output.seek(4)
  try! output.write_byte(0x7E)
  @test.assert_eq(output.position(), 5)
  @test.assert_eq(output.length(), 5)
  @test.assert_eq(@pdflite.pdf_int_array_of_bytes(output.to_bytes()[:]), [
    0, 0, 0, 0, 0x7E,
  ])
}

///|
test "ByteOutput reports checked cursor and byte errors" {
  let negative_size : Result[@pdflite.ByteOutput, Error] = try? @pdflite.byte_output_new(
    initial_size=-1,
  )
  guard negative_size is Err(@pdflite.PdfError::InvalidReadLength(-1)) else {
    fail("expected InvalidReadLength for negative byte output size")
  }
  let output = try! @pdflite.byte_output_new()
  let bad_seek : Result[Unit, Error] = try? output.seek(-1)
  guard bad_seek is Err(@pdflite.PdfError::InvalidCursorPosition(-1)) else {
    fail("expected InvalidCursorPosition for negative byte output seek")
  }
  let bad_byte : Result[Unit, Error] = try? output.write_byte(256)
  guard bad_byte is Err(@pdflite.PdfError::InvalidByte(256)) else {
    fail("expected InvalidByte for byte output")
  }
  try! output.seek(2147483647)
  let overflow : Result[Unit, Error] = try? output.write_view(
    @ascii.encode("x")[:],
  )
  guard overflow is Err(@pdflite.PdfError::InvalidReadLength(1)) else {
    fail("expected InvalidReadLength for byte output overflow")
  }
}
