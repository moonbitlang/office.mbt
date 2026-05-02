///|
fn pdf_bytes_for_bitstream_test(values : ArrayView[Int]) -> @pdflite.PdfBytes {
  try! @pdflite.pdf_bytes_of_int_array(values)
}

///|
fn pdf_bytes_to_ints_for_bitstream_test(
  bytes : @pdflite.PdfBytes,
) -> Array[Int] {
  @pdflite.pdf_bytes_to_array(bytes).map(byte => byte.to_int())
}

///|
test "BitStream reads bits most significant bit first" {
  let bytes = pdf_bytes_for_bitstream_test([0b1010_0001, 0b0110_0000])
  let stream = @pdflite.bitstream_of_bytes(bytes)
  @test.assert_eq(try! stream.get_bit_int(), 1)
  @test.assert_eq(try! stream.get_bit_int(), 0)
  @test.assert_eq(try! stream.get_bit_int(), 1)
  @test.assert_eq(try! stream.get_bit_int(), 0)
  @test.assert_eq(try! stream.get_value_int(4), 0b0001)
  @test.assert_eq(try! stream.get_value_int(3), 0b011)
  @test.assert_eq(stream.bits_read(), 11)
}

///|
test "BitStream can align to the next byte boundary" {
  let bytes = pdf_bytes_for_bitstream_test([0b1010_0001, 0b0110_0000])
  let stream = @pdflite.bitstream_of_bytes(bytes)
  @test.assert_eq(try! stream.get_value_int(3), 0b101)
  stream.align()
  @test.assert_eq(stream.bits_read(), 8)
  @test.assert_eq(try! stream.get_value_int(4), 0b0110)
}

///|
test "BitStream positions can be saved and restored" {
  let bytes = pdf_bytes_for_bitstream_test([0b1010_0001])
  let stream = @pdflite.bitstream_of_bytes(bytes)
  @test.assert_eq(try! stream.get_value_int(3), 0b101)
  let mark = stream.position()
  @test.assert_eq(try! stream.get_value_int(3), 0b000)
  stream.seek(mark)
  @test.assert_eq(try! stream.get_value_int(3), 0b000)
}

///|
test "BitStream reports checked read errors" {
  let bytes = pdf_bytes_for_bitstream_test([0b0000_0000])
  let stream = @pdflite.bitstream_of_bytes(bytes)
  @test.assert_eq(try! stream.get_value_int(8), 0)
  let eof : Result[Bool, Error] = try? stream.get_bit()
  guard eof is Err(@pdflite.PdfError::EndOfInput) else {
    fail("expected EndOfInput after all bits are consumed")
  }
  let bad_count : Result[Int, Error] = try? stream.get_value_int(32)
  guard bad_count is Err(@pdflite.PdfError::InvalidBitCount(32)) else {
    fail("expected InvalidBitCount for oversized read width")
  }
}

///|
test "BitWriter writes bits most significant bit first" {
  let writer = @pdflite.bit_writer_new()
  writer.put_bit(1)
  writer.put_bit(0)
  writer.put_bit(1)
  writer.put_bit(0)
  @test.assert_eq(writer.bit_length(), 4)
  @test.assert_eq(pdf_bytes_to_ints_for_bitstream_test(writer.to_bytes()), [
    0b1010_0000,
  ])
}

///|
test "BitWriter writes multi-bit values across byte boundaries" {
  let writer = @pdflite.bit_writer_new()
  writer.put_value_int(4, 0b1010)
  writer.put_value_int(4, 0b0001)
  writer.put_value_int(3, 0b011)
  @test.assert_eq(writer.bit_length(), 11)
  @test.assert_eq(pdf_bytes_to_ints_for_bitstream_test(writer.to_bytes()), [
    0b1010_0001, 0b0110_0000,
  ])
}

///|
test "BitWriter append_aligned pads first stream and preserves inputs" {
  let first = @pdflite.bit_writer_new()
  first.put_value_int(3, 0b101)
  let second = @pdflite.bit_writer_new()
  second.put_value_int(2, 0b11)
  let appended = first.append_aligned(second)
  @test.assert_eq(first.bit_length(), 3)
  @test.assert_eq(second.bit_length(), 2)
  @test.assert_eq(appended.bit_length(), 10)
  @test.assert_eq(pdf_bytes_to_ints_for_bitstream_test(appended.to_bytes()), [
    0b1010_0000, 0b1100_0000,
  ])
}

///|
test "BitWriter append_aligned avoids extra padding for byte-aligned input" {
  let first = @pdflite.bit_writer_new()
  first.put_value_int(8, 0xAB)
  let second = @pdflite.bit_writer_new()
  second.put_value_int(4, 0xC)
  let appended = first.append_aligned(second)
  @test.assert_eq(appended.bit_length(), 12)
  @test.assert_eq(pdf_bytes_to_ints_for_bitstream_test(appended.to_bytes()), [
    0xAB, 0xC0,
  ])
}

///|
test "BitWriter append_aligned copies complete bytes from second stream" {
  let first = @pdflite.bit_writer_new()
  first.put_value_int(4, 0xA)
  let second = @pdflite.bit_writer_new()
  second.put_value_int(8, 0xBC)
  second.put_value_int(4, 0xD)
  let appended = first.append_aligned(second)
  @test.assert_eq(appended.bit_length(), 20)
  @test.assert_eq(pdf_bytes_to_ints_for_bitstream_test(appended.to_bytes()), [
    0xA0, 0xBC, 0xD0,
  ])
}

///|
test "BitWriter reports checked write errors" {
  let writer = @pdflite.bit_writer_new()
  let bad_bit : Result[Unit, Error] = try? writer.put_bit(2)
  guard bad_bit is Err(@pdflite.PdfError::InvalidBit(2)) else {
    fail("expected InvalidBit for values outside 0 or 1")
  }
  let bad_count : Result[Unit, Error] = try? writer.put_value_int(32, 0)
  guard bad_count is Err(@pdflite.PdfError::InvalidBitCount(32)) else {
    fail("expected InvalidBitCount for oversized write width")
  }
}
