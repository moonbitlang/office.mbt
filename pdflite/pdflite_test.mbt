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
test "PdfBytes concatenate read-only byte views at ownership boundary" {
  let first = try! @pdflite.pdf_bytes_of_int_array([0x25, 0x50])
  let second = try! @pdflite.pdf_bytes_of_int_array([0x44, 0x46, 0xFF])
  let parts : Array[BytesView] = [first[:], second[1:]]
  let combined = @pdflite.pdf_bytes_concat_views(parts)
  @test.assert_eq(
    @pdflite.pdf_bytes_to_array(combined).map(byte => byte.to_int()),
    [0x25, 0x50, 0x46, 0xFF],
  )
  @test.assert_eq(@pdflite.pdf_bytes_concat_views([]), Bytes::new(0))
}

///|
test "PdfBytes expose CamlPDF int-array compatibility conversions" {
  let first : FixedArray[Int] = [65, 0xFF]
  let second : Array[Int] = [0, 66]
  let combined = try! @pdflite.pdf_bytes_of_int_arrays([first, second])
  @test.assert_eq(@pdflite.pdf_int_array_of_bytes(combined[:]), [
    65, 0xFF, 0, 66,
  ])
  @test.assert_eq(@pdflite.pdf_int_array_of_bytes(combined[1:3]), [0xFF, 0])
  @test.assert_eq(
    try! @pdflite.pdf_string_of_int_array(first),
    try! @pdflite.pdf_bytes_of_int_array([65, 0xFF]),
  )
  @test.assert_eq(
    try! @pdflite.pdf_string_of_int_arrays([first, second]),
    combined,
  )
  let invalid : Result[@pdflite.PdfBytes, Error] = try? @pdflite.pdf_bytes_of_int_arrays([
      [256],
    ],
  )
  guard invalid is Err(@pdflite.PdfError::InvalidByte(256)) else {
    fail("expected InvalidByte for nested int arrays")
  }
}

///|
test "PdfBytes map byte values without mutating the source" {
  let source = try! @pdflite.pdf_bytes_of_int_array([0, 1, 255, 7])
  let mapped = try! @pdflite.pdf_bytes_map_int(source[1:3], value => 255 - value)
  @test.assert_eq(@pdflite.pdf_int_array_of_bytes(mapped[:]), [254, 0])
  @test.assert_eq(@pdflite.pdf_int_array_of_bytes(source[:]), [0, 1, 255, 7])
  let invalid : Result[@pdflite.PdfBytes, Error] = try? @pdflite.pdf_bytes_map_int(
    source[2:3],
    value => value + 1,
  )
  guard invalid is Err(@pdflite.PdfError::InvalidByte(256)) else {
    fail("expected InvalidByte for mapped byte")
  }
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

///|
test "PdfName can be built from and inspected as borrowed byte views" {
  let wrapped = @ascii.encode("xx/Typeyy")
  let name = @pdflite.pdf_name_of_view(wrapped[2:wrapped.length() - 2])
  @test.assert_eq(name.byte_length(), 5)
  @test.assert_eq([ for byte in name.view() => byte.to_int() ], [
    0x2F, 0x54, 0x79, 0x70, 0x65,
  ])
}
