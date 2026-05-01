///|
fn reader_bytes_for_test(values : ArrayView[Int]) -> @pdflite.PdfBytes {
  try! @pdflite.pdf_bytes_of_int_array(values)
}

///|
test "ByteCursor read_pdf_header finds header and sets input offset" {
  let cursor = @pdflite.byte_cursor_of_bytes(
    reader_bytes_for_test([0, 1, 2, 37, 80, 68, 70, 45, 49, 46, 55, 10, 65]),
  )
  @test.assert_eq(try! cursor.read_pdf_header(), { major: 1, minor: 7 })
  @test.assert_eq(cursor.absolute_position(), 11)
  @test.assert_eq(cursor.position(), 8)
  @test.assert_eq(cursor.peek_byte(), 10)
}

///|
test "pdf_read_header_from_bytes defaults to PDF 2.0 when no header is found" {
  @test.assert_eq(
    try! @pdflite.pdf_read_header_from_bytes(reader_bytes_for_test([65, 66])),
    @pdflite.pdf_default_version,
  )
}
