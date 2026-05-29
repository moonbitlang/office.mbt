// Whitebox tests for LZW codec internals.

///|
fn wbtest_lzw_codes(
  codes : ArrayView[Int],
  early_change : Int,
) -> @core.PdfBytes {
  let writer = @core.bit_writer_new()
  let mut code_length = 9
  let mut next_code = 258
  let mut old_code = 256
  for code in codes {
    try! writer.put_value_int(code_length, code)
    match code {
      256 => {
        code_length = 9
        next_code = 258
        old_code = 256
      }
      257 => ()
      _ =>
        if old_code == 256 {
          old_code = code
        } else {
          next_code += 1
          match next_code + early_change {
            512 | 1024 | 2048 => code_length += 1
            _ => ()
          }
          old_code = code
        }
    }
  }
  writer.to_bytes()
}

///|
test "private LZW code expansion rejects malformed tables" {
  let bad_next_code : Result[Int?, Error] = try? pdf_lzw_next_code(
    @core.bitstream_of_bytes(Bytes::new(0)),
    32,
  )
  guard bad_next_code is Err(@core.PdfError::InvalidLZWData) else {
    fail("expected @core.PdfError::InvalidLZWData")
  }

  let short_prefix = Array::make(4, 0)
  let short_append = Array::make(4, 0)
  let out_of_range : Result[Array[Int], Error] = try? pdf_lzw_decode_code(
    4, short_prefix, short_append, 4,
  )
  guard out_of_range is Err(@core.PdfError::InvalidLZWData) else {
    fail("expected @core.PdfError::InvalidLZWData")
  }

  let looping_prefix = Array::make(300, 0)
  let looping_append = Array::make(300, 0)
  looping_prefix[256] = 300
  let bad_chain : Result[Array[Int], Error] = try? pdf_lzw_decode_code(
    256, looping_prefix, looping_append, 300,
  )
  guard bad_chain is Err(@core.PdfError::InvalidLZWData) else {
    fail("expected @core.PdfError::InvalidLZWData")
  }

  let negative_prefix = Array::make(300, 0)
  let negative_append = Array::make(300, 0)
  negative_prefix[256] = -1
  let bad_terminal : Result[Array[Int], Error] = try? pdf_lzw_decode_code(
    256, negative_prefix, negative_append, 300,
  )
  guard bad_terminal is Err(@core.PdfError::InvalidLZWData) else {
    fail("expected @core.PdfError::InvalidLZWData")
  }

  let prefix_encoded = wbtest_lzw_codes([65, 257], 1)
  @test.assert_eq(
    try! pdf_lzw_decode_view_prefix(prefix_encoded),
    (@ascii.encode("A"), prefix_encoded.length()),
  )
  let eod_encoded = wbtest_lzw_codes([257], 1)
  @test.assert_eq(
    try! pdf_lzw_decode_view_prefix(eod_encoded),
    (Bytes::new(0), eod_encoded.length()),
  )
  let clear_eod_encoded = wbtest_lzw_codes([256, 257], 1)
  @test.assert_eq(
    try! pdf_lzw_decode_view_prefix(clear_eod_encoded),
    (Bytes::new(0), clear_eod_encoded.length()),
  )
  let exact_byte_encoded = wbtest_lzw_codes(
    [65, 66, 67, 68, 69, 70, 71, 257],
    1,
  )
  @test.assert_eq(
    try! pdf_lzw_decode_view_prefix(exact_byte_encoded),
    (@ascii.encode("ABCDEFG"), exact_byte_encoded.length()),
  )
  let clear_restart_encoded = wbtest_lzw_codes([65, 256, 66, 257], 1)
  @test.assert_eq(
    try! pdf_lzw_decode_view_prefix(clear_restart_encoded),
    (@ascii.encode("AB"), clear_restart_encoded.length()),
  )
  let clear_then_eod_encoded = wbtest_lzw_codes([65, 256, 257], 1)
  @test.assert_eq(
    try! pdf_lzw_decode_view_prefix(clear_then_eod_encoded),
    (@ascii.encode("A"), clear_then_eod_encoded.length()),
  )
  let clear_then_eof : Result[(@core.PdfBytes, Int), Error] = try? pdf_lzw_decode_view_prefix(
    wbtest_lzw_codes([65, 256], 1),
  )
  guard clear_then_eof is Err(@core.PdfError::InvalidLZWData) else {
    fail("expected @core.PdfError::InvalidLZWData")
  }
  let repeated_previous_encoded = wbtest_lzw_codes([65, 258, 257], 1)
  @test.assert_eq(
    try! pdf_lzw_decode_view_prefix(repeated_previous_encoded),
    (@ascii.encode("AAA"), repeated_previous_encoded.length()),
  )
  let bump_codes : Array[Int] = [256]
  for _ in 0..<255 {
    bump_codes.push(65)
  }
  bump_codes.push(257)
  let bump_encoded = wbtest_lzw_codes(bump_codes, 0)
  let bump_result : Result[(@core.PdfBytes, Int), Error] = try? pdf_lzw_decode_view_prefix(
    bump_encoded,
  )
  guard bump_result is Err(@core.PdfError::InvalidLZWData) else {
    fail("expected @core.PdfError::InvalidLZWData")
  }
  let bad_forward_code : Result[(@core.PdfBytes, Int), Error] = try? pdf_lzw_decode_view_prefix(
    wbtest_lzw_codes([65, 300], 1),
  )
  guard bad_forward_code is Err(@core.PdfError::InvalidLZWData) else {
    fail("expected @core.PdfError::InvalidLZWData")
  }
  let missing_eod : Result[(@core.PdfBytes, Int), Error] = try? pdf_lzw_decode_view_prefix(
    wbtest_lzw_codes([65], 1),
  )
  guard missing_eod is Err(@core.PdfError::InvalidLZWData) else {
    fail("expected @core.PdfError::InvalidLZWData")
  }
  let empty_prefix : Result[(@core.PdfBytes, Int), Error] = try? pdf_lzw_decode_view_prefix(
    Bytes::new(0),
  )
  guard empty_prefix is Err(@core.PdfError::InvalidLZWData) else {
    fail("expected @core.PdfError::InvalidLZWData")
  }
}
