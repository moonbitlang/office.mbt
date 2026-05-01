///|
fn pdf_bytes_for_cursor_test(values : ArrayView[Int]) -> @pdflite.PdfBytes {
  try! @pdflite.pdf_bytes_of_int_array(values)
}

///|
fn pdf_bytes_to_ints_for_cursor_test(bytes : @pdflite.PdfBytes) -> Array[Int] {
  @pdflite.pdf_bytes_to_array(bytes).map(byte => byte.to_int())
}

///|
fn bytes_view_to_ints_for_cursor_test(view : BytesView) -> Array[Int] {
  view.to_array().map(byte => byte.to_int())
}

///|
test "ByteCursor reads bytes and preserves peek position" {
  let bytes = pdf_bytes_for_cursor_test([65, 66])
  let cursor = @pdflite.byte_cursor_of_bytes(bytes, source="fixture")
  @test.assert_eq(cursor.source(), "fixture")
  @test.assert_eq(cursor.length(), 2)
  @test.assert_eq(cursor.position(), 0)
  @test.assert_eq(cursor.input_byte(), 65)
  @test.assert_eq(cursor.position(), 1)
  @test.assert_eq(cursor.peek_byte(), 66)
  @test.assert_eq(cursor.position(), 1)
  @test.assert_eq(cursor.read_byte(), Some(66))
  @test.assert_eq(cursor.position(), 2)
  @test.assert_eq(cursor.peek_byte(), @pdflite.pdf_no_more)
  @test.assert_eq(cursor.position(), 2)
  @test.assert_eq(cursor.read_byte(), None)
  @test.assert_eq(cursor.position(), 2)
}

///|
test "ByteCursor reports remaining length and peek at boundaries" {
  let bytes = pdf_bytes_for_cursor_test([65, 66])
  let cursor = @pdflite.byte_cursor_of_bytes(bytes)
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
test "ByteCursor supports rewind nudge and reading behind" {
  let bytes = pdf_bytes_for_cursor_test([65, 66, 67])
  let cursor = @pdflite.byte_cursor_of_bytes(bytes)
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
  let cursor = @pdflite.byte_cursor_of_bytes(bytes)
  let bad_offset : Result[Unit, Error] = try? cursor.set_offset(-1)
  guard bad_offset is Err(@pdflite.PdfError::InvalidCursorPosition(-1)) else {
    fail("expected InvalidCursorPosition for negative offset")
  }
  let bad_rewind : Result[Unit, Error] = try? cursor.rewind()
  guard bad_rewind is Err(@pdflite.PdfError::InvalidCursorPosition(-1)) else {
    fail("expected InvalidCursorPosition for rewind before start")
  }
}

///|
test "ByteCursor offset mirrors shifted input positions" {
  let bytes = pdf_bytes_for_cursor_test([65, 66, 67])
  let cursor = @pdflite.byte_cursor_of_bytes(bytes)
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
  let cursor = @pdflite.byte_cursor_of_bytes(bytes)
  let view = try! cursor.read_view(2)
  @test.assert_eq(bytes_view_to_ints_for_cursor_test(view), [65, 66])
  @test.assert_eq(cursor.position(), 2)
  @test.assert_eq(bytes_view_to_ints_for_cursor_test(cursor.remaining_view()), [
    67,
  ])
  let owned = @pdflite.pdf_bytes_of_view(view)
  @test.assert_eq(pdf_bytes_to_ints_for_cursor_test(owned), [65, 66])
}

///|
test "ByteCursor reads lines as byte data" {
  let bytes = pdf_bytes_for_cursor_test([65, 10, 66])
  let cursor = @pdflite.byte_cursor_of_bytes(bytes)
  @test.assert_eq(
    bytes_view_to_ints_for_cursor_test(try! cursor.read_line_view()),
    [65, 10],
  )
  @test.assert_eq(
    bytes_view_to_ints_for_cursor_test(try! cursor.read_line_view()),
    [66],
  )
  let result : Result[BytesView, Error] = try? cursor.read_line_view()
  guard result is Err(@pdflite.PdfError::EndOfInput) else {
    fail("expected EndOfInput after all lines are consumed")
  }
}

///|
test "ByteCursor read_line_views consumes remaining line data without ownership" {
  let bytes = pdf_bytes_for_cursor_test([65, 10, 66, 10, 67])
  let cursor = @pdflite.byte_cursor_of_bytes(bytes)
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
  let cursor = @pdflite.byte_cursor_of_bytes(bytes)
  @test.assert_eq(pdf_bytes_to_ints_for_cursor_test(try! cursor.read_line()), [
    65, 10,
  ])
}

///|
test "ByteCursor read_lines allocates owned lines" {
  let bytes = pdf_bytes_for_cursor_test([65, 10, 66])
  let cursor = @pdflite.byte_cursor_of_bytes(bytes)
  let lines = cursor.read_lines()
  @test.assert_eq(lines.length(), 2)
  @test.assert_eq(pdf_bytes_to_ints_for_cursor_test(lines[0]), [65, 10])
  @test.assert_eq(pdf_bytes_to_ints_for_cursor_test(lines[1]), [66])
  @test.assert_eq(cursor.position(), cursor.length())
}

///|
test "ByteCursor reports checked cursor errors" {
  let bytes = pdf_bytes_for_cursor_test([65, 66])
  let cursor = @pdflite.byte_cursor_of_bytes(bytes)
  let bad_seek : Result[Unit, Error] = try? cursor.seek(-1)
  guard bad_seek is Err(@pdflite.PdfError::InvalidCursorPosition(-1)) else {
    fail("expected InvalidCursorPosition for negative seek")
  }
  let bad_length : Result[BytesView, Error] = try? cursor.read_view(-1)
  guard bad_length is Err(@pdflite.PdfError::InvalidReadLength(-1)) else {
    fail("expected InvalidReadLength for negative read")
  }
  let too_long : Result[BytesView, Error] = try? cursor.read_view(3)
  guard too_long is Err(@pdflite.PdfError::EndOfInput) else {
    fail("expected EndOfInput for oversized read")
  }
}
