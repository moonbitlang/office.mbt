///|
fn reader_bytes_for_header_test(values : ArrayView[Int]) -> @core.PdfBytes {
  try! @core.pdf_bytes_of_int_array(values)
}

///|
test "pdf_read_header_from_cursor finds header and advances past it" {
  let cursor = @core.byte_cursor_of_bytes(
    reader_bytes_for_header_test([
      0, 1, 2, 37, 80, 68, 70, 45, 49, 46, 55, 10, 65,
    ]),
  )
  @test.assert_eq(try! @reader.pdf_read_header_from_cursor(cursor), {
    major: 1,
    minor: 7,
  })
  @test.assert_eq(cursor.absolute_position(), 11)
  @test.assert_eq(cursor.position(), 8)
  @test.assert_eq(cursor.peek_byte(), 10)
}

///|
test "pdf_read_header_from_bytes defaults when no header is found" {
  @test.assert_eq(
    try! @reader.pdf_read_header_from_bytes(
      reader_bytes_for_header_test([65, 66]),
    ),
    @reader.pdf_default_version,
  )
}

///|
test "pdf_read_header_from_view reads borrowed slices" {
  let bytes = reader_bytes_for_header_test([
    120, 120, 37, 80, 68, 70, 45, 49, 46, 54, 10, 122, 122,
  ])
  @test.assert_eq(
    try! @reader.pdf_read_header_from_view(bytes[2:bytes.length() - 2]),
    { major: 1, minor: 6 },
  )
}
