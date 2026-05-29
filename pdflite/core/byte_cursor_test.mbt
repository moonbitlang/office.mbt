///|
fn pdf_bytes_for_cursor_test(values : ArrayView[Int]) -> @core.PdfBytes {
  try! @core.pdf_bytes_of_int_array(values)
}

///|
fn pdf_bytes_to_ints_for_cursor_test(bytes : @core.PdfBytes) -> Array[Int] {
  @core.pdf_bytes_to_array(bytes).map(byte => byte.to_int())
}

///|
fn bytes_view_to_ints_for_cursor_test(view : BytesView) -> Array[Int] {
  view.to_array().map(byte => byte.to_int())
}

///|
test "ByteCursor reads bytes and preserves peek position" {
  let bytes = pdf_bytes_for_cursor_test([65, 66])
  let cursor = @core.byte_cursor_of_bytes(bytes, source="fixture")
  @test.assert_eq(cursor.source(), "fixture")
  @test.assert_eq(cursor.length(), 2)
  @test.assert_eq(cursor.position(), 0)
  @test.assert_eq(cursor.input_byte(), 65)
  @test.assert_eq(cursor.position(), 1)
  @test.assert_eq(cursor.peek_byte(), 66)
  @test.assert_eq(cursor.position(), 1)
  @test.assert_eq(cursor.read_byte(), Some(66))
  @test.assert_eq(cursor.position(), 2)
  @test.assert_eq(cursor.peek_byte(), @core.pdf_no_more)
  @test.assert_eq(cursor.position(), 2)
  @test.assert_eq(cursor.read_byte(), None)
  @test.assert_eq(cursor.position(), 2)
}

///|
test "ByteCursor formats CamlPDF-style input error context" {
  let cursor = @core.byte_cursor_of_bytes(
    pdf_bytes_for_cursor_test([65, 66, 67]),
    source="sample.pdf",
  )
  cursor.nudge()
  @test.assert_eq(
    cursor.input_pdf_error("bad token"),
    "bad token whilst reading file sample.pdf at position 1",
  )
  cursor.set_offset(1)
  cursor.seek(0)
  @test.assert_eq(
    cursor.input_pdf_error("inside object"),
    "inside object whilst reading file sample.pdf at position 0",
  )
}

///|
test "ByteCursor reports remaining length and peek at boundaries" {
  let bytes = pdf_bytes_for_cursor_test([65, 66])
  let cursor = @core.byte_cursor_of_bytes(bytes)
  @test.assert_eq(cursor.remaining_length(), 2)
  @test.assert_eq(cursor.peek(), Some(65))
  @test.assert_eq(cursor.position(), 0)
  cursor.seek(2)
  @test.assert_eq(cursor.remaining_length(), 0)
  @test.assert_eq(cursor.peek(), None)
  @test.assert_eq(bytes_view_to_ints_for_cursor_test(cursor.remaining_view()), [])
  cursor.seek(5)
  @test.assert_eq(cursor.remaining_length(), 0)
  @test.assert_eq(cursor.read_byte_back(), None)
}

///|
test "ByteCursor peeks byte slices without advancing" {
  let cursor = @core.byte_cursor_of_bytes(
    pdf_bytes_for_cursor_test([65, 66, 67]),
  )
  cursor.nudge()
  @test.assert_eq(
    bytes_view_to_ints_for_cursor_test(try! cursor.peek_view(2)),
    [66, 67],
  )
  @test.assert_eq(
    pdf_bytes_to_ints_for_cursor_test(try! cursor.peek_bytes(1)),
    [66],
  )
  @test.assert_eq(cursor.position(), 1)
  let bad_length : Result[BytesView, Error] = try? cursor.peek_view(-1)
  guard bad_length is Err(@core.PdfError::InvalidReadLength(-1)) else {
    fail("expected @core.PdfError::InvalidReadLength for negative peek")
  }
  let too_long : Result[BytesView, Error] = try? cursor.peek_view(3)
  guard too_long is Err(@core.PdfError::EndOfInput) else {
    fail("expected @core.PdfError::EndOfInput for oversized peek")
  }
}

///|
test "ByteCursor supports rewind nudge and reading behind" {
  let bytes = pdf_bytes_for_cursor_test([65, 66, 67])
  let cursor = @core.byte_cursor_of_bytes(bytes)
  cursor.nudge()
  cursor.nudge()
  @test.assert_eq(cursor.position(), 2)
  cursor.rewind()
  @test.assert_eq(cursor.position(), 1)
  @test.assert_eq(cursor.read_byte_back(), Some(65))
  @test.assert_eq(cursor.position(), 0)
  @test.assert_eq(cursor.read_byte_back(), None)
}

///|
test "ByteCursor reports checked offset and rewind errors" {
  let bytes = pdf_bytes_for_cursor_test([65, 66])
  let cursor = @core.byte_cursor_of_bytes(bytes)
  let bad_offset : Result[Unit, Error] = try? cursor.set_offset(-1)
  guard bad_offset is Err(@core.PdfError::InvalidCursorPosition(-1)) else {
    fail("expected @core.PdfError::InvalidCursorPosition for negative offset")
  }
  let bad_rewind : Result[Unit, Error] = try? cursor.rewind()
  guard bad_rewind is Err(@core.PdfError::InvalidCursorPosition(-1)) else {
    fail(
      "expected @core.PdfError::InvalidCursorPosition for rewind before start",
    )
  }
}

///|
test "ByteCursor offset mirrors shifted input positions" {
  let bytes = pdf_bytes_for_cursor_test([65, 66, 67])
  let cursor = @core.byte_cursor_of_bytes(bytes)
  cursor.seek(2)
  cursor.set_offset(1)
  @test.assert_eq(cursor.position(), 1)
  @test.assert_eq(cursor.absolute_position(), 2)
  cursor.seek(0)
  @test.assert_eq(cursor.absolute_position(), 1)
  @test.assert_eq(cursor.input_byte(), 66)
}

///|
test "ByteCursor exposes read-only views without copying" {
  let bytes = pdf_bytes_for_cursor_test([65, 66, 67])
  let cursor = @core.byte_cursor_of_bytes(bytes)
  @test.assert_eq(bytes_view_to_ints_for_cursor_test(cursor.view()), [
    65, 66, 67,
  ])
  @test.assert_eq(pdf_bytes_to_ints_for_cursor_test(cursor.to_bytes()), [
    65, 66, 67,
  ])
  @test.assert_eq(cursor.position(), 0)
  let view = try! cursor.read_view(2)
  @test.assert_eq(bytes_view_to_ints_for_cursor_test(view), [65, 66])
  @test.assert_eq(cursor.position(), 2)
  @test.assert_eq(bytes_view_to_ints_for_cursor_test(cursor.remaining_view()), [
    67,
  ])
  let owned = @core.pdf_bytes_of_view(view)
  @test.assert_eq(pdf_bytes_to_ints_for_cursor_test(owned), [65, 66])
}

///|
test "ByteCursor read_remaining_bytes consumes only unread bytes" {
  let cursor = @core.byte_cursor_of_bytes(
    pdf_bytes_for_cursor_test([65, 66, 67]),
  )
  cursor.nudge()
  @test.assert_eq(
    pdf_bytes_to_ints_for_cursor_test(cursor.read_remaining_bytes()),
    [66, 67],
  )
  @test.assert_eq(cursor.position(), cursor.length())
  @test.assert_eq(
    pdf_bytes_to_ints_for_cursor_test(cursor.read_remaining_bytes()),
    [],
  )
}

///|
test "ByteCursor reads borrowed and owned slices at shifted positions" {
  let bytes = pdf_bytes_for_cursor_test([65, 66, 67, 68])
  let cursor = @core.byte_cursor_of_bytes(bytes)
  cursor.seek(2)
  cursor.set_offset(1)
  let view = try! cursor.read_view_at(1, 2)
  @test.assert_eq(bytes_view_to_ints_for_cursor_test(view), [67, 68])
  @test.assert_eq(cursor.position(), 3)
  let owned = try! cursor.read_bytes_at(0, 2)
  @test.assert_eq(pdf_bytes_to_ints_for_cursor_test(owned), [66, 67])
  @test.assert_eq(cursor.position(), 2)
}

///|
test "ByteCursor read_until_view stops before matching byte" {
  let bytes = pdf_bytes_for_cursor_test([65, 66, 44, 67])
  let cursor = @core.byte_cursor_of_bytes(bytes)
  let token = try! cursor.read_until_view(byte => byte == 44)
  @test.assert_eq(bytes_view_to_ints_for_cursor_test(token), [65, 66])
  @test.assert_eq(cursor.position(), 2)
  @test.assert_eq(cursor.peek_byte(), 44)
  let empty = try! cursor.read_until_view(byte => byte == 44)
  @test.assert_eq(bytes_view_to_ints_for_cursor_test(empty), [])
  @test.assert_eq(cursor.position(), 2)
}

///|
test "ByteCursor read_until_view handles EOF policy" {
  let bytes = pdf_bytes_for_cursor_test([65, 66])
  let cursor = @core.byte_cursor_of_bytes(bytes)
  let all = try! cursor.read_until_view(byte => byte == 44)
  @test.assert_eq(bytes_view_to_ints_for_cursor_test(all), [65, 66])
  @test.assert_eq(cursor.position(), 2)

  let strict = @core.byte_cursor_of_bytes(bytes)
  let missing : Result[BytesView, Error] = try? strict.read_until_view(
    byte => byte == 44,
    eof_is_delimiter=false,
  )
  guard missing is Err(@core.PdfError::EndOfInput) else {
    fail("expected @core.PdfError::EndOfInput when EOF is not a delimiter")
  }
  @test.assert_eq(strict.position(), 2)
}

///|
test "ByteCursor ignore_until stops before matching byte" {
  let bytes = pdf_bytes_for_cursor_test([65, 66, 44, 67])
  let cursor = @core.byte_cursor_of_bytes(bytes)
  cursor.ignore_until(byte => byte == 44)
  @test.assert_eq(cursor.position(), 2)
  @test.assert_eq(cursor.peek_byte(), 44)
  cursor.nudge()
  let missing : Result[Unit, Error] = try? cursor.ignore_until(
    byte => byte == 90,
    eof_is_delimiter=false,
  )
  guard missing is Err(@core.PdfError::EndOfInput) else {
    fail("expected @core.PdfError::EndOfInput for strict ignore_until")
  }
  @test.assert_eq(cursor.position(), 4)

  let eof_delimiter = @core.byte_cursor_of_bytes(bytes)
  eof_delimiter.ignore_until(byte => byte == 90)
  @test.assert_eq(eof_delimiter.position(), 4)
}

///|
test "ByteCursor reads lines as byte data" {
  let bytes = pdf_bytes_for_cursor_test([65, 10, 66])
  let cursor = @core.byte_cursor_of_bytes(bytes)
  @test.assert_eq(
    bytes_view_to_ints_for_cursor_test(try! cursor.read_line_view()),
    [65, 10],
  )
  @test.assert_eq(
    bytes_view_to_ints_for_cursor_test(try! cursor.read_line_view()),
    [66],
  )
  let result : Result[BytesView, Error] = try? cursor.read_line_view()
  guard result is Err(@core.PdfError::EndOfInput) else {
    fail("expected @core.PdfError::EndOfInput after all lines are consumed")
  }
}

///|
test "ByteCursor reads CR and CRLF terminated lines" {
  let bytes = pdf_bytes_for_cursor_test([65, 13, 66, 13, 10, 67])
  let cursor = @core.byte_cursor_of_bytes(bytes)
  @test.assert_eq(
    bytes_view_to_ints_for_cursor_test(try! cursor.read_line_view()),
    [65, 13],
  )
  @test.assert_eq(
    bytes_view_to_ints_for_cursor_test(try! cursor.read_line_view()),
    [66, 13, 10],
  )
  @test.assert_eq(
    bytes_view_to_ints_for_cursor_test(try! cursor.read_line_view()),
    [67],
  )
}

///|
test "ByteCursor read_line_views consumes remaining line data without ownership" {
  let bytes = pdf_bytes_for_cursor_test([65, 10, 66, 10, 67])
  let cursor = @core.byte_cursor_of_bytes(bytes)
  let lines = cursor.read_line_views()
  @test.assert_eq(lines.length(), 3)
  @test.assert_eq(bytes_view_to_ints_for_cursor_test(lines[0]), [65, 10])
  @test.assert_eq(bytes_view_to_ints_for_cursor_test(lines[1]), [66, 10])
  @test.assert_eq(bytes_view_to_ints_for_cursor_test(lines[2]), [67])
  @test.assert_eq(cursor.position(), cursor.length())
}

///|
test "ByteCursor read_line allocates owned bytes only when requested" {
  let bytes = pdf_bytes_for_cursor_test([65, 10])
  let cursor = @core.byte_cursor_of_bytes(bytes)
  @test.assert_eq(pdf_bytes_to_ints_for_cursor_test(try! cursor.read_line()), [
    65, 10,
  ])
}

///|
test "ByteCursor read_lines allocates owned lines" {
  let bytes = pdf_bytes_for_cursor_test([65, 10, 66])
  let cursor = @core.byte_cursor_of_bytes(bytes)
  let lines = cursor.read_lines()
  @test.assert_eq(lines.length(), 2)
  @test.assert_eq(pdf_bytes_to_ints_for_cursor_test(lines[0]), [65, 10])
  @test.assert_eq(pdf_bytes_to_ints_for_cursor_test(lines[1]), [66])
  @test.assert_eq(cursor.position(), cursor.length())
}

///|
test "ByteCursor reports checked cursor errors" {
  let bytes = pdf_bytes_for_cursor_test([65, 66])
  let cursor = @core.byte_cursor_of_bytes(bytes)
  let bad_seek : Result[Unit, Error] = try? cursor.seek(-1)
  guard bad_seek is Err(@core.PdfError::InvalidCursorPosition(-1)) else {
    fail("expected @core.PdfError::InvalidCursorPosition for negative seek")
  }
  let bad_read_position : Result[BytesView, Error] = try? cursor.read_view_at(
    -1, 1,
  )
  guard bad_read_position is Err(@core.PdfError::InvalidCursorPosition(-1)) else {
    fail(
      "expected @core.PdfError::InvalidCursorPosition for negative read position",
    )
  }
  let bad_length : Result[BytesView, Error] = try? cursor.read_view(-1)
  guard bad_length is Err(@core.PdfError::InvalidReadLength(-1)) else {
    fail("expected @core.PdfError::InvalidReadLength for negative read")
  }
  let too_long : Result[BytesView, Error] = try? cursor.read_view(3)
  guard too_long is Err(@core.PdfError::EndOfInput) else {
    fail("expected @core.PdfError::EndOfInput for oversized read")
  }
}
