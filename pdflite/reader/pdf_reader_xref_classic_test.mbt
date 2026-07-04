///|
test "read startxref finds final marker before eof" {
  @test.assert_eq(
    try! @reader.pdf_read_startxref_position(
      @ascii.encode("startxref\n7\n%%EOF\njunk startxref\n9\n%%EOF"),
    ),
    9,
  )
}

///|
test "cursor consume ascii advances only on match" {
  let cursor = @core.byte_cursor_of_bytes(@ascii.encode("xref trailer"))
  try! @reader.pdf_cursor_consume_ascii(
    cursor,
    [120, 114, 101, 102],
    XRefExpected,
  )
  @test.assert_eq(cursor.absolute_position(), 4)

  let mismatch : Result[Unit, Error] = try
    @reader.pdf_cursor_consume_ascii(cursor, [120], XRefExpected)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard mismatch is Err(@core.PdfError::XRefExpected) else {
    fail("expected XRefExpected")
  }
  @test.assert_eq(cursor.absolute_position(), 4)
}

///|
test "classic xref entries parse fixed width rows" {
  let cursor = @core.byte_cursor_of_bytes(
    @ascii.encode(
      "xref\n0 2\n0000000000 65535 f \n0000000017 00000 n \ntrailer\n",
    ),
  )
  let entries = try! @reader.pdf_cursor_read_classic_xref_entries(cursor)
  @test.assert_eq(entries.length(), 2)
  @test.assert_eq(entries[0], {
    object_number: 0,
    offset: 0,
    generation: 65535,
    in_use: false,
    object_stream: None,
  })
  @test.assert_eq(entries[1], {
    object_number: 1,
    offset: 17,
    generation: 0,
    in_use: true,
    object_stream: None,
  })
}
