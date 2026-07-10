///|
test "ByteOutput writes bytes views and ASCII without using String for payloads" {
  let output = try! @core.byte_output_new(initial_size=2)
  try! output.write_byte(65)
  try! output.write_view(Bytes::from_array([0, 0xFF]))
  try! output.write_ascii("PDF")
  @test.assert_eq(output.position(), 6)
  @test.assert_eq(output.length(), 6)
  @test.assert_eq(@core.pdf_int_array_of_bytes(output.to_bytes()), [
    65, 0, 0xFF, 80, 68, 70,
  ])
}

///|
test "ByteOutput seek overwrites bytes and frozen output stays owned" {
  let output = try! @core.byte_output_new()
  try! output.write_view(b"ABCD")
  let frozen = output.to_bytes()
  try! output.seek(1)
  try! output.write_ascii("zz")
  @test.assert_eq(@core.pdf_int_array_of_bytes(frozen), [65, 66, 67, 68])
  @test.assert_eq(@core.pdf_int_array_of_bytes(output.to_bytes()), [
    65, 122, 122, 68,
  ])
}

///|
test "ByteOutput writes bytes and views at explicit positions" {
  let output = try! @core.byte_output_new()
  try! output.write_ascii("ABCD")
  try! output.write_byte_at(1, 0x78)
  @test.assert_eq(output.position(), 2)
  try! output.write_view_at(3, b"YZ")
  @test.assert_eq(output.position(), 5)
  @test.assert_eq(@core.pdf_int_array_of_bytes(output.to_bytes()), [
    65, 0x78, 67, 89, 90,
  ])
  try! output.write_byte_at(7, 0x51)
  @test.assert_eq(@core.pdf_int_array_of_bytes(output.to_bytes()), [
    65, 0x78, 67, 89, 90, 0, 0, 0x51,
  ])
  let bad_position : Result[Unit, Error] = try
    output.write_byte_at(-1, 0)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_position is Err(@core.PdfError::InvalidCursorPosition(-1)) else {
    fail(
      "expected @core.PdfError::InvalidCursorPosition for positioned byte output",
    )
  }
  let bad_view_position : Result[Unit, Error] = try
    output.write_view_at(-1, b"x")
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_view_position is Err(@core.PdfError::InvalidCursorPosition(-1)) else {
    fail(
      "expected @core.PdfError::InvalidCursorPosition for positioned view output",
    )
  }
}

///|
test "ByteOutput writes checked byte slices" {
  let output = try! @core.byte_output_new()
  let source = b"012345"
  try! output.write_view_slice(source, 2, 3)
  @test.assert_eq(@core.pdf_int_array_of_bytes(output.to_bytes()), [50, 51, 52])
  @test.assert_eq(output.position(), 3)
  let bad_offset : Result[Unit, Error] = try
    output.write_view_slice(source, -1, 1)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_offset is Err(@core.PdfError::InvalidCursorPosition(-1)) else {
    fail("expected @core.PdfError::InvalidCursorPosition for byte output slice")
  }
  let bad_length : Result[Unit, Error] = try
    output.write_view_slice(source, 0, -1)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_length is Err(@core.PdfError::InvalidReadLength(-1)) else {
    fail("expected @core.PdfError::InvalidReadLength for byte output slice")
  }
  let too_long : Result[Unit, Error] = try
    output.write_view_slice(source, 4, 3)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard too_long is Err(@core.PdfError::EndOfInput) else {
    fail("expected @core.PdfError::EndOfInput for byte output slice")
  }
  let overflow : Result[Unit, Error] = try
    output.write_view_slice(source, 2147483647, 1)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard overflow is Err(@core.PdfError::InvalidReadLength(1)) else {
    fail(
      "expected @core.PdfError::InvalidReadLength for byte output slice overflow",
    )
  }
}

///|
test "ByteOutput sparse writes zero-fill skipped positions" {
  let output = try! @core.byte_output_new(initial_size=1)
  try! output.seek(4)
  try! output.write_byte(0x7E)
  @test.assert_eq(output.position(), 5)
  @test.assert_eq(output.length(), 5)
  @test.assert_eq(@core.pdf_int_array_of_bytes(output.to_bytes()), [
    0, 0, 0, 0, 0x7E,
  ])
}

///|
test "ByteOutput writes repeated bytes for padding and fill" {
  let output = try! @core.byte_output_new()
  try! output.write_ascii("A")
  try! output.write_repeated_byte(3, value=0x20)
  try! output.write_repeated_byte(2, value=0xFF)
  @test.assert_eq(output.position(), 6)
  @test.assert_eq(@core.pdf_int_array_of_bytes(output.to_bytes()), [
    65, 0x20, 0x20, 0x20, 0xFF, 0xFF,
  ])
  let empty = try! @core.byte_output_new()
  try! empty.write_repeated_byte(0, value=0x41)
  @test.assert_eq(empty.position(), 0)
  @test.assert_eq(empty.to_bytes(), Bytes::new(0))
  let bad_length : Result[Unit, Error] = try
    output.write_repeated_byte(-1)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_length is Err(@core.PdfError::InvalidReadLength(-1)) else {
    fail("expected @core.PdfError::InvalidReadLength for repeated byte write")
  }
  let bad_value : Result[Unit, Error] = try
    output.write_repeated_byte(1, value=256)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_value is Err(@core.PdfError::InvalidByte(256)) else {
    fail("expected @core.PdfError::InvalidByte for repeated byte write")
  }
  try! output.seek(2147483647)
  let overflow : Result[Unit, Error] = try output.write_repeated_byte(1) catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard overflow is Err(@core.PdfError::InvalidReadLength(1)) else {
    fail(
      "expected @core.PdfError::InvalidReadLength for repeated byte overflow",
    )
  }
}

///|
test "ByteOutput reports checked cursor and byte errors" {
  let negative_size : Result[@core.ByteOutput, Error] = try
    @core.byte_output_new(initial_size=-1)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard negative_size is Err(@core.PdfError::InvalidReadLength(-1)) else {
    fail(
      "expected @core.PdfError::InvalidReadLength for negative byte output size",
    )
  }
  let output = try! @core.byte_output_new()
  let bad_seek : Result[Unit, Error] = try output.seek(-1) catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_seek is Err(@core.PdfError::InvalidCursorPosition(-1)) else {
    fail(
      "expected @core.PdfError::InvalidCursorPosition for negative byte output seek",
    )
  }
  let bad_byte : Result[Unit, Error] = try output.write_byte(256) catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_byte is Err(@core.PdfError::InvalidByte(256)) else {
    fail("expected @core.PdfError::InvalidByte for byte output")
  }
  try! output.seek(2147483647)
  let overflow : Result[Unit, Error] = try output.write_view(b"x") catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard overflow is Err(@core.PdfError::InvalidReadLength(1)) else {
    fail("expected @core.PdfError::InvalidReadLength for byte output overflow")
  }
}
