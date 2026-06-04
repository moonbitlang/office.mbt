///|
fn jpeg_bytes_for_test(values : ArrayView[Int]) -> @core.PdfBytes {
  try! @core.pdf_bytes_of_int_array(values)
}

///|
fn jpeg_bytes_to_ints_for_test(bytes : @core.PdfBytes) -> Array[Int] {
  @core.pdf_bytes_to_array(bytes).map(byte => byte.to_int())
}

///|
test "@codec.pdf_cursor_read_jpeg_data consumes through JPEG EOI marker" {
  let cursor = @core.byte_cursor_of_bytes(
    jpeg_bytes_for_test([0xFF, 0xD8, 1, 2, 0xFF, 0xD9, 65, 66]),
  )
  @test.assert_eq(
    jpeg_bytes_to_ints_for_test(try! @codec.pdf_cursor_read_jpeg_data(cursor)),
    [0xFF, 0xD8, 1, 2, 0xFF, 0xD9],
  )
  @test.assert_eq(cursor.position(), 6)
  @test.assert_eq(cursor.read_byte(), Some(65))
  let function_cursor = @core.byte_cursor_of_bytes(
    jpeg_bytes_for_test([0xFF, 0xD8, 0xFF, 0xD9, 0]),
  )
  @test.assert_eq(
    jpeg_bytes_to_ints_for_test(try! @codec.pdf_get_jpeg_data(function_cursor)),
    [0xFF, 0xD8, 0xFF, 0xD9],
  )
  @test.assert_eq(function_cursor.read_byte(), Some(0))
}

///|
test "@codec.pdf_cursor_read_jpeg_data ignores stuffed and bare D9 bytes" {
  let cursor = @core.byte_cursor_of_bytes(
    jpeg_bytes_for_test([0xFF, 0xD8, 0xFF, 0x00, 0xD9, 0xFF, 0xD9, 7]),
  )
  @test.assert_eq(
    jpeg_bytes_to_ints_for_test(try! @codec.pdf_cursor_read_jpeg_data(cursor)),
    [0xFF, 0xD8, 0xFF, 0x00, 0xD9, 0xFF, 0xD9],
  )
  @test.assert_eq(cursor.read_byte(), Some(7))
}

///|
test "@codec.pdf_cursor_read_jpeg_data reports missing JPEG EOI marker" {
  let cursor = @core.byte_cursor_of_bytes(
    jpeg_bytes_for_test([0xFF, 0xD8, 1, 2, 0xFF]),
  )
  let result : Result[@core.PdfBytes, Error] = try
    @codec.pdf_cursor_read_jpeg_data(cursor)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard result is Err(@core.PdfError::EndOfInput) else {
    fail("expected @core.PdfError::EndOfInput for missing JPEG EOI marker")
  }
  @test.assert_eq(cursor.position(), cursor.length())
}

///|
fn jpeg_jfif_for_test(marker : Int) -> @core.PdfBytes {
  jpeg_bytes_for_test([
    0xFF, 0xD8, 0xFF, 0xE0,
    // APP0 length = 9, followed by "JFIF\0" and two padding bytes.
     0x00, 0x09, 0x4A, 0x46, 0x49, 0x46, 0x00, 0xAA, 0xBB,
    // SOF marker, length, precision, height 300, width 400.
     0xFF, marker, 0x00, 0x09, 0x08, 0x01, 0x2C, 0x01, 0x90, 0x03, 0x01,
  ])
}

///|
fn jpeg_exif_for_test() -> @core.PdfBytes {
  jpeg_bytes_for_test([
    0xFF, 0xD8, 0xFF, 0xE1,
    // APP1 length = 10, followed by "Exif\0" and three padding bytes.
     0x00, 0x0A, 0x45, 0x78, 0x69, 0x66, 0x00, 0xAA, 0xBB, 0xCC,
    // SOF0 marker, length, precision, height 256, width 512.
     0xFF, 0xC0, 0x00, 0x09, 0x08, 0x01, 0x00, 0x02, 0x00, 0x03, 0x01,
  ])
}

///|
fn jpeg_jfif_with_intermediate_block_for_test() -> @core.PdfBytes {
  jpeg_bytes_for_test([
    0xFF, 0xD8, 0xFF, 0xE0,
    // APP0 length = 9, followed by "JFIF\0" and two padding bytes.
     0x00, 0x09, 0x4A, 0x46, 0x49, 0x46, 0x00, 0xAA, 0xBB,
    // DQT-like non-SOF segment with length 4 and two payload bytes.
     0xFF, 0xDB, 0x00, 0x04, 0x11, 0x22,
    // SOF0 marker, length, precision, height 33, width 66.
     0xFF, 0xC0, 0x00, 0x09, 0x08, 0x00, 0x21, 0x00, 0x42, 0x03, 0x01,
  ])
}

///|
fn jpeg_progressive_without_app_header_for_test() -> @core.PdfBytes {
  jpeg_bytes_for_test([
    0xFF, 0xD8,
    // DQT-like non-SOF segment with length 4 and two payload bytes.
     0xFF, 0xDB, 0x00, 0x04, 0x11, 0x22,
    // SOF2 marker, length, precision, height 123, width 456.
     0xFF, 0xC2, 0x00, 0x09, 0x08, 0x00, 0x7B, 0x01, 0xC8, 0x03, 0x01,
  ])
}

///|
test "@codec.pdf_jpeg_dimensions reads JFIF and Exif baseline JPEG dimensions" {
  @test.assert_eq(
    try! @codec.pdf_jpeg_dimensions(jpeg_jfif_for_test(0xC0)),
    (400, 300),
  )
  @test.assert_eq(
    try! @codec.pdf_jpeg_dimensions_view(jpeg_exif_for_test()),
    (512, 256),
  )
}

///|
test "@codec.pdf_jpeg_dimensions scans over non-SOF JPEG segments" {
  @test.assert_eq(
    try! @codec.pdf_jpeg_dimensions(
      jpeg_jfif_with_intermediate_block_for_test(),
    ),
    (66, 33),
  )
}

///|
test "@codec.pdf_jpeg_dimensions rejects progressive or missing SOF0 dimensions" {
  let progressive : Result[(Int, Int), Error] = try
    @codec.pdf_jpeg_dimensions(jpeg_jfif_for_test(0xC2))
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard progressive is Err(@core.PdfError::JPEGDimensionsExpected) else {
    fail("expected JPEGDimensionsExpected for progressive JPEG")
  }
}

///|
test "@codec.pdf_jpeg_backup_dimensions reads progressive and generic SOF markers" {
  @test.assert_eq(
    try! @codec.pdf_jpeg_backup_dimensions(jpeg_jfif_for_test(0xC2)),
    (400, 300),
  )
  @test.assert_eq(
    try! @codec.pdf_jpeg_backup_dimensions_view(
      jpeg_progressive_without_app_header_for_test(),
    ),
    (456, 123),
  )
}

///|
test "@codec.pdf_jpeg_dimensions reports malformed JPEG inputs" {
  let bad_header : Result[(Int, Int), Error] = try
    @codec.pdf_jpeg_dimensions(jpeg_bytes_for_test([0xFF, 0xD8, 0xFF, 0xDB]))
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_header is Err(@core.PdfError::BadJPEGHeader) else {
    fail("expected BadJPEGHeader")
  }
  let bad_string : Result[(Int, Int), Error] = try
    @codec.pdf_jpeg_dimensions(
      jpeg_bytes_for_test([
        0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x09, 0x4E, 0x4F, 0x50, 0x45, 0x00,
      ]),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_string is Err(@core.PdfError::BadJPEGString) else {
    fail("expected BadJPEGString")
  }
  let bad_block : Result[(Int, Int), Error] = try
    @codec.pdf_jpeg_dimensions(
      jpeg_bytes_for_test([
        0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x09, 0x4A, 0x46, 0x49, 0x46, 0x00, 0xAA, 0xBB,
        0x00, 0xC0,
      ]),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_block is Err(@core.PdfError::InvalidJPEGBlock) else {
    fail("expected InvalidJPEGBlock")
  }
  let truncated : Result[(Int, Int), Error] = try
    @codec.pdf_jpeg_dimensions(
      jpeg_bytes_for_test([
        0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x09, 0x4A, 0x46, 0x49, 0x46, 0x00, 0xAA,
      ]),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard truncated is Err(@core.PdfError::JPEGDimensionsExpected) else {
    fail("expected JPEGDimensionsExpected for truncated JPEG")
  }
}

///|
test "@codec.pdf_jpeg_backup_dimensions reports malformed SOF scanning inputs" {
  let bad_header : Result[(Int, Int), Error] = try
    @codec.pdf_jpeg_backup_dimensions(jpeg_bytes_for_test([0x00, 0xD8]))
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_header is Err(@core.PdfError::BadJPEGHeader) else {
    fail("expected BadJPEGHeader")
  }
  let bad_block : Result[(Int, Int), Error] = try
    @codec.pdf_jpeg_backup_dimensions(
      jpeg_bytes_for_test([0xFF, 0xD8, 0xFF, 0xDB, 0x00, 0x01]),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_block is Err(@core.PdfError::InvalidJPEGBlock) else {
    fail("expected InvalidJPEGBlock")
  }
  let no_dimensions : Result[(Int, Int), Error] = try
    @codec.pdf_jpeg_backup_dimensions(
      jpeg_bytes_for_test([0xFF, 0xD8, 0xFF, 0xD9]),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard no_dimensions is Err(@core.PdfError::JPEGDimensionsExpected) else {
    fail("expected JPEGDimensionsExpected")
  }
}
