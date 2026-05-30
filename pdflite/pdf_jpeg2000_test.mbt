///|
fn jpeg2000_bytes_for_test(values : ArrayView[Int]) -> @core.PdfBytes {
  try! @core.pdf_bytes_of_int_array(values)
}

///|
fn jpeg2000_jp2_for_test(prefix : ArrayView[Int]) -> @core.PdfBytes {
  let values : Array[Int] = [
    0x00, 0x00, 0x00, 0x0C, 0x6A, 0x50, 0x20, 0x20, 0x0D, 0x0A, 0x87, 0x0A,
  ]
  for byte in prefix {
    values.push(byte)
  }
  // ihdr, height 300, width 400
  for
    byte in [
      0x69, 0x68, 0x64, 0x72, 0x00, 0x00, 0x01, 0x2C, 0x00, 0x00, 0x01, 0x90,
    ] {
    values.push(byte)
  }
  jpeg2000_bytes_for_test(values)
}

///|
test "pdf_jpeg2000_dimensions reads immediate image header box" {
  @test.assert_eq(
    try! @pdflite.pdf_jpeg2000_dimensions(jpeg2000_jp2_for_test([])),
    (400, 300),
  )
}

///|
test "pdf_jpeg2000_dimensions scans for unaligned image header box" {
  @test.assert_eq(
    try! @pdflite.pdf_jpeg2000_dimensions_view(
      jpeg2000_jp2_for_test([0xAA, 0xBB, 0xCC]),
    ),
    (400, 300),
  )
}

///|
test "pdf_jpeg2000_dimensions reports malformed JPEG2000 inputs" {
  let bad_header : Result[(Int, Int), Error] = try? @pdflite.pdf_jpeg2000_dimensions(
    jpeg2000_bytes_for_test([
      0x00, 0x00, 0x00, 0x0C, 0x6A, 0x50, 0x20, 0x21, 0x0D, 0x0A, 0x87, 0x0A,
    ]),
  )
  guard bad_header is Err(@core.PdfError::BadJPEG2000Header) else {
    fail("expected BadJPEG2000Header")
  }
  let missing_header : Result[(Int, Int), Error] = try? @pdflite.pdf_jpeg2000_dimensions(
    jpeg2000_bytes_for_test([
      0x00, 0x00, 0x00, 0x0C, 0x6A, 0x50, 0x20, 0x20, 0x0D, 0x0A, 0x87, 0x0A, 0x66,
      0x72, 0x65, 0x65,
    ]),
  )
  guard missing_header is Err(@core.PdfError::JPEG2000DimensionsExpected) else {
    fail("expected JPEG2000DimensionsExpected")
  }
  let truncated : Result[(Int, Int), Error] = try? @pdflite.pdf_jpeg2000_dimensions(
    jpeg2000_bytes_for_test([0x00, 0x00, 0x00, 0x0C, 0x6A, 0x50]),
  )
  guard truncated is Err(@core.PdfError::BadJPEG2000Header) else {
    fail("expected BadJPEG2000Header for truncated signature")
  }
}
