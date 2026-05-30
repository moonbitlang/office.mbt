///|
fn codec_bytes_for_test(values : ArrayView[Int]) -> @pdflite.PdfBytes {
  try! @pdflite.pdf_bytes_of_int_array(values)
}

///|
fn codec_ascii_for_test(text : String) -> @pdflite.PdfBytes {
  @ascii.encode(text)
}

///|
fn codec_wrap_view_for_test(
  prefix : String,
  data : BytesView,
  suffix : String,
) -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  for byte in @ascii.encode(prefix)[:] {
    output.push(byte)
  }
  for byte in data {
    output.push(byte)
  }
  for byte in @ascii.encode(suffix)[:] {
    output.push(byte)
  }
  Bytes::from_array(output)
}

///|
fn codec_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(codec_ascii_for_test(text))
}

///|
fn codec_deep_flate_match_data_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  let phrase = codec_ascii_for_test(
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyz",
  )
  for byte in phrase[:] {
    output.push(byte)
  }
  for index in 0..<96 {
    output.push(65)
    output.push(66)
    output.push((33 + index % 80).to_byte())
  }
  for byte in phrase[:] {
    output.push(byte)
  }
  Bytes::from_array(output)
}

///|
#cfg(target="native")
fn codec_miniz_mixed_stored_data_for_test() -> @pdflite.PdfBytes {
  try! @pdflite.pdf_bytes_of_int_array(
    [
      for index in 0..<64 => (index * 37 + 11) % 256
    ],
  )
}

///|
fn codec_lzw_codes_for_test(
  codes : ArrayView[Int],
  early_change : Int,
) -> @pdflite.PdfBytes {
  let writer = @pdflite.bit_writer_new()
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
test "@codec.pdf_ascii_hex_encode renders uppercase hex with terminator" {
  @test.assert_eq(
    @codec.pdf_ascii_hex_encode(codec_bytes_for_test([0, 15, 160, 255])),
    codec_ascii_for_test("000FA0FF>"),
  )
  @test.assert_eq(
    @codec.pdf_ascii_hex_encode(Bytes::new(0)),
    codec_ascii_for_test(">"),
  )
}

///|
test "@codec.pdf_ascii_hex_decode ignores whitespace and accepts lowercase" {
  @test.assert_eq(
    try! @codec.pdf_ascii_hex_decode(codec_ascii_for_test("  61 62\n63>")),
    codec_ascii_for_test("abc"),
  )
  @test.assert_eq(
    try! @codec.pdf_ascii_hex_decode(codec_ascii_for_test("af>")),
    codec_bytes_for_test([175]),
  )
}

///|
test "pdf_ascii_hex view codecs read borrowed slices" {
  let plain = codec_ascii_for_test("abc")
  let wrapped_plain = codec_wrap_view_for_test("xx", plain, "yy")
  @test.assert_eq(
    @codec.pdf_ascii_hex_encode_view(
      wrapped_plain[2:wrapped_plain.length() - 2],
    ),
    codec_ascii_for_test("616263>"),
  )
  let encoded = codec_ascii_for_test("xx61 62 63>yy")
  @test.assert_eq(
    try! @codec.pdf_ascii_hex_decode_view(encoded[2:encoded.length() - 2]),
    plain,
  )
}

///|
test "@codec.pdf_ascii_hex_decode pads odd final nibble before terminator" {
  @test.assert_eq(
    try! @codec.pdf_ascii_hex_decode(codec_ascii_for_test("6>")),
    codec_bytes_for_test([96]),
  )
  @test.assert_eq(
    try! @codec.pdf_ascii_hex_decode(codec_ascii_for_test(">")),
    codec_bytes_for_test([]),
  )
}

///|
test "@codec.pdf_ascii_hex_decode reports invalid hex data" {
  let result : Result[@pdflite.PdfBytes, Error] = try? @codec.pdf_ascii_hex_decode(
    codec_ascii_for_test("6Z>"),
  )
  guard result is Err(@pdflite.PdfError::InvalidHexEscape) else {
    fail("expected @pdflite.PdfError::InvalidHexEscape")
  }
}

///|
test "@codec.pdf_ascii85_encode renders full partial and zero chunks" {
  @test.assert_eq(
    @codec.pdf_ascii85_encode(codec_bytes_for_test([77, 97, 110, 32])),
    codec_ascii_for_test("9jqo^~>"),
  )
  @test.assert_eq(
    @codec.pdf_ascii85_encode(codec_bytes_for_test([77, 97, 110])),
    codec_ascii_for_test("9jqo~>"),
  )
  @test.assert_eq(
    @codec.pdf_ascii85_encode(codec_bytes_for_test([0, 0, 0, 0])),
    codec_ascii_for_test("z~>"),
  )
  @test.assert_eq(
    @codec.pdf_ascii85_encode(Bytes::new(0)),
    codec_ascii_for_test("~>"),
  )
}

///|
test "@codec.pdf_ascii85_decode expands zero and partial chunks" {
  @test.assert_eq(
    try! @codec.pdf_ascii85_decode(codec_ascii_for_test("9jqo^~>")),
    codec_bytes_for_test([77, 97, 110, 32]),
  )
  @test.assert_eq(
    try! @codec.pdf_ascii85_decode(codec_ascii_for_test("9jqo~>")),
    codec_bytes_for_test([77, 97, 110]),
  )
  @test.assert_eq(
    try! @codec.pdf_ascii85_decode(codec_ascii_for_test("z~>")),
    codec_bytes_for_test([0, 0, 0, 0]),
  )
  @test.assert_eq(
    try! @codec.pdf_ascii85_decode(codec_ascii_for_test("~>")),
    codec_bytes_for_test([]),
  )
}

///|
test "@codec.pdf_ascii85_decode skips whitespace" {
  @test.assert_eq(
    try! @codec.pdf_ascii85_decode(codec_ascii_for_test("  9j\nqo^ ~>")),
    codec_bytes_for_test([77, 97, 110, 32]),
  )
}

///|
test "pdf_ascii85 view codecs read borrowed slices" {
  let plain = codec_bytes_for_test([77, 97, 110])
  let wrapped_plain = codec_wrap_view_for_test("xx", plain, "yy")
  @test.assert_eq(
    @codec.pdf_ascii85_encode_view(wrapped_plain[2:wrapped_plain.length() - 2]),
    codec_ascii_for_test("9jqo~>"),
  )
  let encoded = codec_ascii_for_test("xx9jqo~>yy")
  @test.assert_eq(
    try! @codec.pdf_ascii85_decode_view(encoded[2:encoded.length() - 2]),
    plain,
  )
}

///|
test "@codec.pdf_ascii85_decode reports malformed data" {
  let bad_char : Result[@pdflite.PdfBytes, Error] = try? @codec.pdf_ascii85_decode(
    codec_ascii_for_test("9jqo{~>"),
  )
  guard bad_char is Err(@pdflite.PdfError::InvalidASCII85Data) else {
    fail("expected @pdflite.PdfError::InvalidASCII85Data")
  }
  let bad_zero : Result[@pdflite.PdfBytes, Error] = try? @codec.pdf_ascii85_decode(
    codec_ascii_for_test("!z~>"),
  )
  guard bad_zero is Err(@pdflite.PdfError::InvalidASCII85Data) else {
    fail("expected @pdflite.PdfError::InvalidASCII85Data")
  }
  let one_digit : Result[@pdflite.PdfBytes, Error] = try? @codec.pdf_ascii85_decode(
    codec_ascii_for_test("!~>"),
  )
  guard one_digit is Err(@pdflite.PdfError::InvalidASCII85Data) else {
    fail("expected @pdflite.PdfError::InvalidASCII85Data")
  }
  let overflowing_group : Result[@pdflite.PdfBytes, Error] = try? @codec.pdf_ascii85_decode(
    codec_ascii_for_test("uuuuu~>"),
  )
  guard overflowing_group is Err(@pdflite.PdfError::InvalidASCII85Data) else {
    fail("expected @pdflite.PdfError::InvalidASCII85Data")
  }
  let unterminated : Result[@pdflite.PdfBytes, Error] = try? @codec.pdf_ascii85_decode(
    codec_ascii_for_test("9jqo"),
  )
  guard unterminated is Err(@pdflite.PdfError::InvalidASCII85Data) else {
    fail("expected @pdflite.PdfError::InvalidASCII85Data")
  }
}

///|
test "@codec.pdf_lzw_decode expands clear literal dictionary and eod codes" {
  @test.assert_eq(
    try! @codec.pdf_lzw_decode(codec_bytes_for_test([128, 16, 96, 32])),
    codec_ascii_for_test("A"),
  )
  @test.assert_eq(
    try! @codec.pdf_lzw_decode(codec_bytes_for_test([128, 16, 72, 80, 40, 8])),
    codec_ascii_for_test("ABAB"),
  )
}

///|
test "@codec.pdf_lzw_decode handles eof and reset boundaries" {
  @test.assert_eq(
    try! @codec.pdf_lzw_decode(codec_bytes_for_test([])),
    codec_bytes_for_test([]),
  )
  @test.assert_eq(
    try! @codec.pdf_lzw_decode(codec_lzw_codes_for_test([257], 1)),
    codec_bytes_for_test([]),
  )
  @test.assert_eq(
    try! @codec.pdf_lzw_decode(codec_lzw_codes_for_test([256], 1)),
    codec_bytes_for_test([]),
  )
  @test.assert_eq(
    try! @codec.pdf_lzw_decode(
      codec_lzw_codes_for_test([65, 66, 256, 67, 257], 1),
    ),
    codec_ascii_for_test("ABC"),
  )
  @test.assert_eq(
    try! @codec.pdf_lzw_decode(codec_lzw_codes_for_test([65], 1)),
    codec_ascii_for_test("A"),
  )
  @test.assert_eq(
    try! @codec.pdf_lzw_decode(codec_lzw_codes_for_test([65, 256], 1)),
    codec_ascii_for_test("A"),
  )
}

///|
test "@codec.pdf_lzw_decode handles the repeated previous-code case" {
  @test.assert_eq(
    try! @codec.pdf_lzw_decode(codec_bytes_for_test([128, 16, 96, 80, 16])),
    codec_ascii_for_test("AAA"),
  )
}

///|
test "@codec.pdf_lzw_decode_view reads borrowed compressed slices" {
  let encoded = codec_bytes_for_test([128, 16, 96, 32])
  let wrapped = codec_wrap_view_for_test("xx", encoded, "yy")
  @test.assert_eq(
    try! @codec.pdf_lzw_decode_view(wrapped[2:wrapped.length() - 2]),
    codec_ascii_for_test("A"),
  )
}

///|
test "@codec.pdf_lzw_decode reports malformed input codes" {
  let result : Result[@pdflite.PdfBytes, Error] = try? @codec.pdf_lzw_decode(
    codec_bytes_for_test([128, 75, 32, 32]),
  )
  guard result is Err(@pdflite.PdfError::InvalidLZWData) else {
    fail("expected @pdflite.PdfError::InvalidLZWData")
  }
  let result : Result[@pdflite.PdfBytes, Error] = try? @codec.pdf_lzw_decode(
    codec_lzw_codes_for_test([65, 300], 1),
  )
  guard result is Err(@pdflite.PdfError::InvalidLZWData) else {
    fail("expected @pdflite.PdfError::InvalidLZWData")
  }
}

///|
test "@flate.pdf_flate_decode expands zlib stored and dynamic blocks" {
  @test.assert_eq(
    try! @flate.pdf_flate_decode(
      codec_bytes_for_test([
        120, 1, 1, 11, 0, 244, 255, 104, 101, 108, 108, 111, 32, 119, 111, 114, 108,
        100, 26, 11, 4, 93,
      ]),
    ),
    codec_ascii_for_test("hello world"),
  )
  @test.assert_eq(
    try! @flate.pdf_flate_decode(
      codec_bytes_for_test([120, 1, 115, 4, 0, 0, 66, 0, 66]),
    ),
    codec_ascii_for_test("A"),
  )
  @test.assert_eq(
    try! @flate.pdf_flate_decode(
      codec_bytes_for_test([
        120, 156, 237, 196, 57, 1, 0, 0, 8, 4, 160, 172, 231, 211, 191, 130, 41,
        220, 96, 32, 213, 179, 145, 36, 73, 146, 36, 73, 146, 244, 217, 1, 198, 122,
        142, 2,
      ]),
    ),
    codec_ascii_for_test("abcde".repeat(1000)),
  )
}

///|
test "@flate.pdf_flate_encode roundtrips an empty payload" {
  let empty = codec_bytes_for_test([])
  let encoded = @flate.pdf_flate_encode(empty)
  @test.assert_eq(try! @flate.pdf_flate_decode(encoded), empty)
}

///|
test "@flate.pdf_flate_decode reports malformed zlib data" {
  @test.assert_eq(try! @flate.pdf_flate_decode(codec_bytes_for_test([])), [])
  let short_data : Result[@pdflite.PdfBytes, Error] = try? @flate.pdf_flate_decode(
    codec_bytes_for_test([120, 1, 0]),
  )
  guard short_data is Err(@pdflite.PdfError::InvalidFlateData) else {
    fail("expected @pdflite.PdfError::InvalidFlateData")
  }
  let bad_header : Result[@pdflite.PdfBytes, Error] = try? @flate.pdf_flate_decode(
    codec_bytes_for_test([120, 2, 1, 0, 0, 255, 255, 0, 0, 0, 1]),
  )
  guard bad_header is Err(@pdflite.PdfError::InvalidFlateData) else {
    fail("expected @pdflite.PdfError::InvalidFlateData")
  }
  let bad_stored_length : Result[@pdflite.PdfBytes, Error] = try? @flate.pdf_flate_decode(
    codec_bytes_for_test([120, 1, 1, 1, 0, 0, 0, 65, 0, 66, 0, 66]),
  )
  guard bad_stored_length is Err(@pdflite.PdfError::InvalidFlateData) else {
    fail("expected @pdflite.PdfError::InvalidFlateData")
  }
  let bad_block_type : Result[@pdflite.PdfBytes, Error] = try? @flate.pdf_flate_decode(
    codec_bytes_for_test([120, 1, 7, 0, 1, 0, 0]),
  )
  guard bad_block_type is Err(@pdflite.PdfError::InvalidFlateData) else {
    fail("expected @pdflite.PdfError::InvalidFlateData")
  }
  let bad_checksum : Result[@pdflite.PdfBytes, Error] = try? @flate.pdf_flate_decode(
    codec_bytes_for_test([120, 1, 1, 1, 0, 254, 255, 65, 0, 0, 0, 0]),
  )
  guard bad_checksum is Err(@pdflite.PdfError::InvalidFlateData) else {
    fail("expected @pdflite.PdfError::InvalidFlateData")
  }
}

///|
test "@flate.pdf_flate_encode chooses compact zlib blocks" {
  @test.assert_eq(
    try! @flate.pdf_flate_decode(
      @flate.pdf_flate_encode(codec_bytes_for_test([])),
    ),
    codec_bytes_for_test([]),
  )
  let encoded = @flate.pdf_flate_encode(codec_ascii_for_test("Hi"))
  @test.assert_eq(encoded[0].to_int(), 120)
  @test.assert_eq(
    try! @flate.pdf_flate_decode(encoded),
    codec_ascii_for_test("Hi"),
  )
  let high_bytes = try! @pdflite.pdf_bytes_of_int_array(
    [
      for _ in 0..<32 => 255
    ],
  )
  let repeated = @flate.pdf_flate_encode(high_bytes)
  @test.assert_eq(repeated.length() < 20, true)
  @test.assert_eq(try! @flate.pdf_flate_decode(repeated), high_bytes)
  let long_run = @ascii.encode("A".repeat(300))
  let encoded_run = @flate.pdf_flate_encode(long_run)
  @test.assert_eq(encoded_run.length() < long_run.length(), true)
  @test.assert_eq(try! @flate.pdf_flate_decode(encoded_run), long_run)
  let repeated_phrase = codec_ascii_for_test("ABCABCABCABCABCABC")
  let encoded_phrase = @flate.pdf_flate_encode(repeated_phrase)
  @test.assert_eq(encoded_phrase.length() < 20, true)
  @test.assert_eq(try! @flate.pdf_flate_decode(encoded_phrase), repeated_phrase)
  let shadowed_match = codec_ascii_for_test(
    "ABCDEFGHIJABCXABCDEFGHIJABCDEFGHIJ",
  )
  let encoded_shadowed_match = @flate.pdf_flate_encode(shadowed_match)
  @test.assert_eq(
    encoded_shadowed_match.length() < shadowed_match.length(),
    true,
  )
  @test.assert_eq(
    try! @flate.pdf_flate_decode(encoded_shadowed_match),
    shadowed_match,
  )
  let alternating_high = try! @pdflite.pdf_bytes_of_int_array(
    [
      for i in 0..<40 => if i % 2 == 0 { 255 } else { 254 }
    ],
  )
  let encoded_alternating_high = @flate.pdf_flate_encode(alternating_high)
  @test.assert_eq(encoded_alternating_high.length() < 20, true)
  @test.assert_eq(
    try! @flate.pdf_flate_decode(encoded_alternating_high),
    alternating_high,
  )
  let non_repeating_high = try! @pdflite.pdf_bytes_of_int_array(
    [
      for i in 0..<40 => 216 + i
    ],
  )
  let compact_non_repeating = @flate.pdf_flate_encode(non_repeating_high)
  @test.assert_eq(compact_non_repeating.length() <= 51, true)
  @test.assert_eq(
    try! @flate.pdf_flate_decode(compact_non_repeating),
    non_repeating_high,
  )
  let skewed_literals = try! @pdflite.pdf_bytes_of_int_array(
    [
      for i in 0..<4096 => {
        let bucket = ((i * 73 + i / 11 * 29 + i / 97) & 0x7fffffff) % 32
        if bucket < 25 {
          65
        } else if bucket < 30 {
          66
        } else {
          67
        }
      }
    ],
  )
  let dynamic = @flate.pdf_flate_encode(skewed_literals)
  @test.assert_eq(dynamic.length() < skewed_literals.length() / 3, true)
  @test.assert_eq(try! @flate.pdf_flate_decode(dynamic), skewed_literals)
}

///|
test "@flate.pdf_flate_encode_with_level exposes zlib level choices" {
  let repeated = @ascii.encode("ABC".repeat(80))
  let stored = @flate.pdf_flate_encode_with_level(repeated, 0)
  @test.assert_eq(stored[0].to_int(), 120)
  @test.assert_eq(stored[1].to_int(), 1)
  @test.assert_eq(stored[2].to_int() & 0x07, 1)
  @test.assert_eq(@flate.pdf_flate_decode(stored), repeated)

  let fast = @flate.pdf_flate_encode_with_level(repeated, 1)
  @test.assert_eq(fast[1].to_int(), 1)
  @test.assert_eq(fast.length() < stored.length(), true)
  @test.assert_eq(@flate.pdf_flate_decode(fast), repeated)

  let fast_incompressible = try! @pdflite.pdf_bytes_of_int_array(
    [
      for i in 0..<100 => 144 + i
    ],
  )
  let fast_incompressible_encoded = @flate.pdf_flate_encode_with_level(
    fast_incompressible, 1,
  )
  @test.assert_eq(fast_incompressible_encoded[2].to_int() & 0x07, 1)
  @test.assert_eq(
    @flate.pdf_flate_decode(fast_incompressible_encoded),
    fast_incompressible,
  )

  let default_level = @flate.pdf_flate_encode_with_level(repeated, 6)
  @test.assert_eq(default_level[1].to_int(), 156)
  @test.assert_eq(@flate.pdf_flate_decode(default_level), repeated)

  let balanced = @flate.pdf_flate_encode_with_level(repeated, 4)
  @test.assert_eq(balanced[1].to_int(), 94)
  @test.assert_eq(@flate.pdf_flate_decode(balanced), repeated)

  let best = @flate.pdf_flate_encode_view_with_level(repeated, 9)
  @test.assert_eq(best[1].to_int(), 218)
  @test.assert_eq(@flate.pdf_flate_decode(best), repeated)

  let invalid : Result[@pdflite.PdfBytes, Error] = try? @flate.pdf_flate_encode_with_level(
    repeated, 10,
  )
  guard invalid is Err(_) else { fail("expected invalid Flate level to raise") }
}

///|
test "@flate.pdf_flate_encode_with_level uses deeper match search at high levels" {
  let data = codec_deep_flate_match_data_for_test()
  let fast = @flate.pdf_flate_encode_with_level(data, 1)
  let default_level = @flate.pdf_flate_encode_with_level(data, 6)
  let best = @flate.pdf_flate_encode_with_level(data, 9)

  @test.assert_eq(@flate.pdf_flate_decode(fast), data)
  @test.assert_eq(@flate.pdf_flate_decode(default_level), data)
  @test.assert_eq(@flate.pdf_flate_decode(best), data)
  @test.assert_eq(best.length() <= fast.length(), true)
}

///|
#cfg(target="native")
test "@flate.pdf_flate_encode uses native miniz default level on native target" {
  let data = codec_ascii_for_test("Hi")
  let encoded = @flate.pdf_flate_encode(data)
  @test.assert_eq(encoded[0].to_int(), 120)
  @test.assert_eq(encoded[1].to_int(), 156)
  @test.assert_eq(@flate.pdf_flate_decode(encoded), data)
}

///|
#cfg(target="native")
test "@flate.pdf_flate_encode_with_level matches native miniz byte output" {
  let small = codec_ascii_for_test("Hi")
  let small_cases : Array[(Int, Array[Int])] = [
    (0, [120, 1, 1, 2, 0, 253, 255, 72, 105, 0, 251, 0, 178]),
    (4, [120, 94, 1, 2, 0, 253, 255, 72, 105, 0, 251, 0, 178]),
    (6, [120, 156, 1, 2, 0, 253, 255, 72, 105, 0, 251, 0, 178]),
    (9, [120, 218, 1, 2, 0, 253, 255, 72, 105, 0, 251, 0, 178]),
  ]
  for case in small_cases {
    let (level, expected) = case
    @test.assert_eq(
      @flate.pdf_flate_encode_with_level(small, level),
      codec_bytes_for_test(expected),
    )
  }
  let repeated = codec_ascii_for_test("ABC".repeat(80))
  let compressed_body = [
    229, 194, 1, 13, 0, 0, 0, 130, 176, 108, 104, 255, 78, 4, 97, 59, 59, 37, 2,
    33, 243, 61, 225,
  ]
  let compressed_cases : Array[(Int, Array[Int])] = [
    (1, [120, 1] + compressed_body),
    (6, [120, 156] + compressed_body),
    (9, [120, 218] + compressed_body),
  ]
  for case in compressed_cases {
    let (level, expected) = case
    @test.assert_eq(
      @flate.pdf_flate_encode_with_level(repeated, level),
      codec_bytes_for_test(expected),
    )
  }

  let mixed_stored = codec_miniz_mixed_stored_data_for_test()
  let mixed_stored_body = [
    1, 64, 0, 191, 255, 11, 48, 85, 122, 159, 196, 233, 14, 51, 88, 125, 162, 199,
    236, 17, 54, 91, 128, 165, 202, 239, 20, 57, 94, 131, 168, 205, 242, 23, 60,
    97, 134, 171, 208, 245, 26, 63, 100, 137, 174, 211, 248, 29, 66, 103, 140, 177,
    214, 251, 32, 69, 106, 143, 180, 217, 254, 35, 72, 109, 146, 183, 220, 1, 38,
    247, 237, 32, 33,
  ]
  let mixed_stored_cases : Array[(Int, Array[Int])] = [
    (1, [120, 1] + mixed_stored_body),
    (6, [120, 156] + mixed_stored_body),
    (9, [120, 218] + mixed_stored_body),
  ]
  for case in mixed_stored_cases {
    let (level, expected) = case
    let encoded = @flate.pdf_flate_encode_with_level(mixed_stored, level)
    @test.assert_eq(encoded, codec_bytes_for_test(expected))
    @test.assert_eq(@flate.pdf_flate_decode(encoded), mixed_stored)
  }
}

///|
test "pdf_flate view codecs read borrowed slices" {
  let plain = codec_ascii_for_test("Hi")
  let wrapped_plain = codec_wrap_view_for_test("xx", plain, "yy")
  let encoded = @flate.pdf_flate_encode_view(
    wrapped_plain[2:wrapped_plain.length() - 2],
  )
  @test.assert_eq(encoded[0].to_int(), 120)
  let wrapped_encoded = codec_wrap_view_for_test("xx", encoded, "yy")
  @test.assert_eq(
    try! @flate.pdf_flate_decode_view(
      wrapped_encoded[2:wrapped_encoded.length() - 2],
    ),
    plain,
  )
}

///|
test "pdf_decode_filter_bytes dispatches supported filter names" {
  @test.assert_eq(
    try! @pdflite.pdf_decode_filter_bytes(
      codec_name_for_test("/AHx"),
      codec_ascii_for_test("4869>"),
    ),
    codec_ascii_for_test("Hi"),
  )
  @test.assert_eq(
    try! @pdflite.pdf_decode_filter_bytes(
      codec_name_for_test("/A85"),
      codec_ascii_for_test("9jqo~>"),
    ),
    codec_bytes_for_test([77, 97, 110]),
  )
  @test.assert_eq(
    try! @pdflite.pdf_decode_filter_bytes(
      codec_name_for_test("/RL"),
      codec_bytes_for_test([0, 65, 128]),
    ),
    codec_ascii_for_test("A"),
  )
  @test.assert_eq(
    try! @pdflite.pdf_decode_filter_bytes(
      codec_name_for_test("/Crypt"),
      codec_ascii_for_test("raw"),
    ),
    codec_ascii_for_test("raw"),
  )
  let raw_crypt = codec_ascii_for_test("raw")
  let decoded_crypt = try! @pdflite.pdf_decode_filter_bytes(
    codec_name_for_test("/Crypt"),
    raw_crypt,
  )
  @test.assert_eq(physical_equal(raw_crypt, decoded_crypt), true)
  @test.assert_eq(
    try! @pdflite.pdf_decode_filter_bytes(
      codec_name_for_test("/LZW"),
      codec_bytes_for_test([128, 16, 96, 32]),
    ),
    codec_ascii_for_test("A"),
  )
  @test.assert_eq(
    try! @pdflite.pdf_decode_filter_bytes(
      codec_name_for_test("/Fl"),
      codec_bytes_for_test([120, 1, 1, 2, 0, 253, 255, 72, 105, 0, 251, 0, 178]),
    ),
    codec_ascii_for_test("Hi"),
  )
}

///|
test "pdf filter dispatch view APIs read borrowed slices" {
  let encoded_hex = codec_ascii_for_test("xx4869>yy")
  @test.assert_eq(
    @pdflite.pdf_decode_filter_view(
      codec_name_for_test("/AHx"),
      encoded_hex[2:encoded_hex.length() - 2],
    ),
    codec_ascii_for_test("Hi"),
  )
  let raw = codec_ascii_for_test("xxHi yy")
  @test.assert_eq(
    @pdflite.pdf_encode_filter_view(
      codec_name_for_test("/A85"),
      raw[2:raw.length() - 2],
    ),
    @codec.pdf_ascii85_encode(codec_ascii_for_test("Hi ")),
  )
  let flate = codec_name_for_test("/FlateDecode")
  let encoded_flate = @flate.pdf_flate_encode(codec_ascii_for_test("Hi"))
  let wrapped_flate = codec_wrap_view_for_test("xx", encoded_flate, "yy")
  @test.assert_eq(
    @pdflite.pdf_decode_filter_view(
      flate,
      wrapped_flate[2:wrapped_flate.length() - 2],
    ),
    codec_ascii_for_test("Hi"),
  )
  let encoded_flate_view = @pdflite.pdf_encode_filter_view(
    flate,
    raw[2:raw.length() - 2],
  )
  @test.assert_eq(
    @flate.pdf_flate_decode(encoded_flate_view),
    codec_ascii_for_test("Hi "),
  )
  let encoded_flate_best_view = @pdflite.pdf_encode_filter_view_with_flate_level(
    flate,
    raw[2:raw.length() - 2],
    9,
  )
  @test.assert_eq(encoded_flate_best_view[1].to_int(), 218)
  @test.assert_eq(
    @flate.pdf_flate_decode(encoded_flate_best_view),
    codec_ascii_for_test("Hi "),
  )
  let crypt_raw = codec_ascii_for_test("xxrawyy")
  @test.assert_eq(
    @pdflite.pdf_decode_filter_view(
      codec_name_for_test("/Crypt"),
      crypt_raw[2:crypt_raw.length() - 2],
    ),
    codec_ascii_for_test("raw"),
  )
  @test.assert_eq(
    @pdflite.pdf_encode_filter_view(
      codec_name_for_test("/Crypt"),
      crypt_raw[2:crypt_raw.length() - 2],
    ),
    codec_ascii_for_test("raw"),
  )
}

///|
test "pdf_encode_filter_bytes dispatches supported filter names" {
  let raw_crypt = codec_ascii_for_test("raw")
  let encoded_crypt = try! @pdflite.pdf_encode_filter_bytes(
    codec_name_for_test("/Crypt"),
    raw_crypt,
  )
  @test.assert_eq(encoded_crypt, codec_ascii_for_test("raw"))
  @test.assert_eq(physical_equal(raw_crypt, encoded_crypt), true)
  @test.assert_eq(
    try! @pdflite.pdf_encode_filter_bytes(
      codec_name_for_test("/ASCIIHexDecode"),
      codec_ascii_for_test("Hi"),
    ),
    codec_ascii_for_test("4869>"),
  )
  @test.assert_eq(
    try! @pdflite.pdf_encode_filter_bytes(
      codec_name_for_test("/ASCII85Decode"),
      codec_bytes_for_test([77, 97, 110]),
    ),
    codec_ascii_for_test("9jqo~>"),
  )
  @test.assert_eq(
    try! @pdflite.pdf_encode_filter_bytes(
      codec_name_for_test("/RunLengthDecode"),
      codec_ascii_for_test("A"),
    ),
    codec_bytes_for_test([0, 65, 128]),
  )
  @test.assert_eq(
    try! @pdflite.pdf_decode_filter_bytes(
      codec_name_for_test("/FlateDecode"),
      try! @pdflite.pdf_encode_filter_bytes(
        codec_name_for_test("/FlateDecode"),
        codec_ascii_for_test("Hi"),
      ),
    ),
    codec_ascii_for_test("Hi"),
  )
}

///|
test "pdf encode filter and stream APIs accept explicit Flate levels" {
  let flate = codec_name_for_test("/FlateDecode")
  let data = codec_ascii_for_test("ABCABCABCABCABCABC")
  let encoded = @pdflite.pdf_encode_filter_bytes_with_flate_level(
    flate, data, 6,
  )
  @test.assert_eq(encoded[1].to_int(), 156)
  @test.assert_eq(@pdflite.pdf_decode_filter_bytes(flate, encoded), data)

  let length = codec_name_for_test("/Length")
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([(length, PdfInteger(data.length()))]),
    StreamGot(data),
  )
  let stored = @pdflite.pdf_encode_stream_with_filter(
    flate,
    stream,
    flate_level=Some(0),
  )
  guard stored is PdfStreamObject(stored_stream) else {
    fail("expected Flate-encoded stream")
  }
  guard stored_stream.data is StreamGot(stored_data) else {
    fail("expected owned encoded stream")
  }
  @test.assert_eq(stored_data[1].to_int(), 1)
  @test.assert_eq(
    stored_stream.dictionary.lookup_immediate(length),
    Some(PdfInteger(stored_data.length())),
  )

  let tuned = @pdflite.pdf_encode_stream_with_encoding(
    PdfStreamFlate,
    stream,
    flate_level=Some(9),
  )
  guard tuned is PdfStreamObject(tuned_stream) else {
    fail("expected tuned Flate stream")
  }
  guard tuned_stream.data is StreamGot(tuned_data) else {
    fail("expected owned tuned stream")
  }
  @test.assert_eq(tuned_data[1].to_int(), 218)

  let predicted = @pdflite.pdf_encode_stream_with_filter_and_predictor(
    flate,
    10,
    1,
    8,
    data.length(),
    stream,
    flate_level=Some(4),
  )
  guard predicted is PdfStreamObject(predicted_stream) else {
    fail("expected predictor Flate stream")
  }
  guard predicted_stream.data is StreamGot(predicted_data) else {
    fail("expected owned predictor stream")
  }
  @test.assert_eq(predicted_data[1].to_int(), 94)
}

///|
test "pdf filter dispatch reports unsupported filters" {
  let flate = codec_name_for_test("/DCTDecode")
  let result : Result[@pdflite.PdfBytes, Error] = try? @pdflite.pdf_decode_filter_bytes(
    flate,
    codec_ascii_for_test("data"),
  )
  guard result is Err(@pdflite.PdfError::FilterNotSupported(filter)) &&
    filter == flate else {
    fail("expected @pdflite.PdfError::FilterNotSupported")
  }
  let result : Result[@pdflite.PdfBytes, Error] = try? @pdflite.pdf_encode_filter_bytes(
    flate,
    codec_ascii_for_test("data"),
  )
  guard result is Err(@pdflite.PdfError::FilterNotSupported(filter)) &&
    filter == flate else {
    fail("expected @pdflite.PdfError::FilterNotSupported")
  }
}

///|
test "pdf_decode_predictor decodes tiff predictor 2" {
  @test.assert_eq(
    try! @pdflite.pdf_decode_predictor(
      2,
      1,
      8,
      3,
      codec_bytes_for_test([10, 5, 5, 1, 1, 1]),
    ),
    codec_bytes_for_test([10, 15, 20, 1, 2, 3]),
  )
}

///|
test "pdf_encode_predictor emits tiff predictor 2 rows" {
  let plain = codec_bytes_for_test([10, 15, 20, 1, 2, 3])
  let encoded = try! @pdflite.pdf_encode_predictor(2, 1, 8, 3, plain)
  @test.assert_eq(encoded, codec_bytes_for_test([10, 5, 5, 1, 1, 1]))
  @test.assert_eq(
    try! @pdflite.pdf_decode_predictor(2, 1, 8, 3, encoded),
    plain,
  )
  let rgb_plain = codec_bytes_for_test([10, 20, 30, 13, 25, 35])
  let rgb_encoded = try! @pdflite.pdf_encode_predictor(2, 3, 8, 2, rgb_plain)
  @test.assert_eq(rgb_encoded, codec_bytes_for_test([10, 20, 30, 3, 5, 5]))
  @test.assert_eq(
    try! @pdflite.pdf_decode_predictor(2, 3, 8, 2, rgb_encoded),
    rgb_plain,
  )
  let partial = codec_bytes_for_test([10, 20, 30, 40])
  @test.assert_eq(
    try! @pdflite.pdf_encode_predictor(2, 1, 8, 3, partial),
    codec_bytes_for_test([10, 10, 10, 40]),
  )
}

///|
test "pdf_decode_predictor decodes png row filters" {
  @test.assert_eq(
    try! @pdflite.pdf_decode_predictor(10, 1, 8, 3, codec_bytes_for_test([])),
    codec_bytes_for_test([]),
  )
  @test.assert_eq(
    try! @pdflite.pdf_decode_predictor(
      15,
      1,
      8,
      3,
      codec_bytes_for_test([
        0, 10, 20, 30, 1, 1, 2, 3, 2, 1, 1, 1, 3, 2, 4, 6, 4, 1, 1, 1,
      ]),
    ),
    codec_bytes_for_test([10, 20, 30, 1, 3, 6, 2, 4, 7, 3, 7, 13, 4, 8, 14]),
  )
}

///|
test "pdf_decode_predictor covers png paeth and short rows" {
  @test.assert_eq(
    try! @pdflite.pdf_decode_predictor(
      15,
      1,
      8,
      2,
      codec_bytes_for_test([4, 7, 8]),
    ),
    codec_bytes_for_test([7, 15]),
  )
  @test.assert_eq(
    try! @pdflite.pdf_decode_predictor(
      15,
      1,
      8,
      2,
      codec_bytes_for_test([0, 5, 10, 4, 251, 1]),
    ),
    codec_bytes_for_test([5, 10, 0, 6]),
  )
  @test.assert_eq(
    try! @pdflite.pdf_decode_predictor(
      10,
      1,
      8,
      3,
      codec_bytes_for_test([0, 65]),
    ),
    codec_bytes_for_test([65, 0, 0]),
  )
  for row in [(1, [5, 5, 5]), (2, [5, 0, 0]), (3, [5, 2, 1]), (4, [5, 5, 5])] {
    let (filter, expected) = row
    @test.assert_eq(
      try! @pdflite.pdf_decode_predictor(
        15,
        1,
        8,
        3,
        codec_bytes_for_test([filter, 5]),
      ),
      codec_bytes_for_test(expected),
    )
  }
}

///|
test "pdf_decode_predictor reports unsupported predictor" {
  let result : Result[@pdflite.PdfBytes, Error] = try? @pdflite.pdf_decode_predictor(
    9,
    1,
    8,
    1,
    codec_bytes_for_test([0]),
  )
  guard result is Err(@pdflite.PdfError::PredictorNotSupported(9)) else {
    fail("expected @pdflite.PdfError::PredictorNotSupported")
  }
  let result : Result[@pdflite.PdfBytes, Error] = try? @pdflite.pdf_decode_predictor(
    15,
    1,
    8,
    1,
    codec_bytes_for_test([9, 0]),
  )
  guard result is Err(@pdflite.PdfError::PredictorNotSupported(9)) else {
    fail("expected @pdflite.PdfError::PredictorNotSupported")
  }
  let result : Result[@pdflite.PdfBytes, Error] = try? @pdflite.pdf_decode_predictor(
    2,
    1,
    1,
    1,
    codec_bytes_for_test([0]),
  )
  guard result is Err(@pdflite.PdfError::PredictorNotSupported(2)) else {
    fail("expected @pdflite.PdfError::PredictorNotSupported")
  }
  let result : Result[@pdflite.PdfBytes, Error] = try? @pdflite.pdf_decode_predictor(
    2,
    0,
    8,
    1,
    codec_bytes_for_test([0]),
  )
  guard result is Err(@pdflite.PdfError::PredictorExpected) else {
    fail("expected @pdflite.PdfError::PredictorExpected")
  }
}

///|
test "pdf predictors keep identity data and reject bad encode parameters" {
  let raw_decode = codec_ascii_for_test("raw")
  let decoded_identity = try! @pdflite.pdf_decode_predictor(
    1, 1, 8, 1, raw_decode,
  )
  @test.assert_eq(decoded_identity, raw_decode)
  @test.assert_eq(physical_equal(raw_decode, decoded_identity), true)
  let raw_encode = codec_ascii_for_test("raw")
  let encoded_identity = try! @pdflite.pdf_encode_predictor(
    1, 1, 8, 1, raw_encode,
  )
  @test.assert_eq(encoded_identity, raw_encode)
  @test.assert_eq(physical_equal(raw_encode, encoded_identity), true)
  let unsupported_tiff : Result[@pdflite.PdfBytes, Error] = try? @pdflite.pdf_encode_predictor(
    2,
    1,
    1,
    1,
    codec_bytes_for_test([0]),
  )
  guard unsupported_tiff is Err(@pdflite.PdfError::PredictorNotSupported(2)) else {
    fail("expected @pdflite.PdfError::PredictorNotSupported")
  }
  let unsupported : Result[@pdflite.PdfBytes, Error] = try? @pdflite.pdf_encode_predictor(
    9,
    1,
    8,
    1,
    codec_ascii_for_test("raw"),
  )
  guard unsupported is Err(@pdflite.PdfError::PredictorNotSupported(9)) else {
    fail("expected @pdflite.PdfError::PredictorNotSupported")
  }
  let bad_dimensions : Result[@pdflite.PdfBytes, Error] = try? @pdflite.pdf_encode_predictor(
    11,
    1,
    0,
    1,
    codec_ascii_for_test("raw"),
  )
  guard bad_dimensions is Err(@pdflite.PdfError::PredictorExpected) else {
    fail("expected @pdflite.PdfError::PredictorExpected")
  }
}

///|
test "pdf predictor view APIs read borrowed slices" {
  let identity_input = codec_ascii_for_test("xxrawyy")
  @test.assert_eq(
    @pdflite.pdf_decode_predictor_view(
      1,
      1,
      8,
      3,
      identity_input[2:identity_input.length() - 2],
    ),
    codec_ascii_for_test("raw"),
  )
  @test.assert_eq(
    @pdflite.pdf_encode_predictor_view(
      1,
      1,
      8,
      3,
      identity_input[2:identity_input.length() - 2],
    ),
    codec_ascii_for_test("raw"),
  )
  let decoded_input = codec_bytes_for_test([1, 10, 10, 10])
  let wrapped_decoded_input = codec_wrap_view_for_test(
    "xx", decoded_input, "yy",
  )
  @test.assert_eq(
    try! @pdflite.pdf_decode_predictor_view(
      11,
      1,
      8,
      3,
      wrapped_decoded_input[2:wrapped_decoded_input.length() - 2],
    ),
    codec_bytes_for_test([10, 20, 30]),
  )
  let plain = codec_bytes_for_test([10, 20, 30])
  let wrapped_plain = codec_wrap_view_for_test("xx", plain, "yy")
  @test.assert_eq(
    try! @pdflite.pdf_encode_predictor_view(
      11,
      1,
      8,
      3,
      wrapped_plain[2:wrapped_plain.length() - 2],
    ),
    decoded_input,
  )
}

///|
test "pdf_encode_predictor emits png sub and up rows" {
  @test.assert_eq(
    try! @pdflite.pdf_encode_predictor(15, 1, 8, 3, codec_bytes_for_test([])),
    codec_bytes_for_test([]),
  )
  let none = try! @pdflite.pdf_encode_predictor(
    10,
    1,
    8,
    3,
    codec_bytes_for_test([10, 20, 30, 13, 25, 35]),
  )
  @test.assert_eq(none, codec_bytes_for_test([0, 10, 20, 30, 0, 13, 25, 35]))
  @test.assert_eq(
    try! @pdflite.pdf_decode_predictor(10, 1, 8, 3, none),
    codec_bytes_for_test([10, 20, 30, 13, 25, 35]),
  )
  let sub = try! @pdflite.pdf_encode_predictor(
    11,
    1,
    8,
    3,
    codec_bytes_for_test([10, 20, 30]),
  )
  @test.assert_eq(sub, codec_bytes_for_test([1, 10, 10, 10]))
  @test.assert_eq(
    try! @pdflite.pdf_decode_predictor(11, 1, 8, 3, sub),
    codec_bytes_for_test([10, 20, 30]),
  )
  let up = try! @pdflite.pdf_encode_predictor(
    12,
    1,
    8,
    3,
    codec_bytes_for_test([10, 20, 30, 11, 25, 35]),
  )
  @test.assert_eq(up, codec_bytes_for_test([2, 10, 20, 30, 2, 1, 5, 5]))
  @test.assert_eq(
    try! @pdflite.pdf_decode_predictor(12, 1, 8, 3, up),
    codec_bytes_for_test([10, 20, 30, 11, 25, 35]),
  )
  let average = try! @pdflite.pdf_encode_predictor(
    13,
    1,
    8,
    3,
    codec_bytes_for_test([10, 20, 30, 13, 25, 35]),
  )
  @test.assert_eq(average, codec_bytes_for_test([3, 10, 15, 20, 3, 8, 9, 8]))
  @test.assert_eq(
    try! @pdflite.pdf_decode_predictor(13, 1, 8, 3, average),
    codec_bytes_for_test([10, 20, 30, 13, 25, 35]),
  )
  let paeth = try! @pdflite.pdf_encode_predictor(
    14,
    1,
    8,
    3,
    codec_bytes_for_test([10, 20, 30, 13, 25, 35]),
  )
  @test.assert_eq(paeth, codec_bytes_for_test([4, 10, 10, 10, 4, 3, 5, 5]))
  @test.assert_eq(
    try! @pdflite.pdf_decode_predictor(14, 1, 8, 3, paeth),
    codec_bytes_for_test([10, 20, 30, 13, 25, 35]),
  )
  let optimum = try! @pdflite.pdf_encode_predictor(
    15,
    1,
    8,
    3,
    codec_bytes_for_test([10, 20, 30]),
  )
  @test.assert_eq(optimum, codec_bytes_for_test([1, 10, 10, 10]))
  @test.assert_eq(
    try! @pdflite.pdf_decode_predictor(15, 1, 8, 3, optimum),
    codec_bytes_for_test([10, 20, 30]),
  )
}

///|
test "pdf_encode_predictor normalizes negative byte deltas" {
  @test.assert_eq(
    try! @pdflite.pdf_encode_predictor(
      12,
      1,
      8,
      1,
      codec_bytes_for_test([200, 10]),
    ),
    codec_bytes_for_test([2, 200, 2, 66]),
  )
}

///|
test "@codec.pdf_run_length_decode expands literal and repeat chunks" {
  @test.assert_eq(
    @codec.pdf_run_length_decode(
      codec_bytes_for_test([2, 65, 66, 67, 253, 90, 128]),
    ),
    codec_ascii_for_test("ABCZZZZ"),
  )
  @test.assert_eq(
    @codec.pdf_run_length_decode(codec_bytes_for_test([128])),
    codec_bytes_for_test([]),
  )
}

///|
test "@codec.pdf_run_length_encode emits literal repeat and eod chunks" {
  @test.assert_eq(
    @codec.pdf_run_length_encode(codec_ascii_for_test("ABCZZZZ")),
    codec_bytes_for_test([2, 65, 66, 67, 253, 90, 128]),
  )
  @test.assert_eq(
    @codec.pdf_run_length_encode(codec_bytes_for_test([])),
    codec_bytes_for_test([128]),
  )
}

///|
test "pdf_run_length view codecs read borrowed slices" {
  let plain = codec_ascii_for_test("ABCZZZZ")
  let wrapped_plain = codec_wrap_view_for_test("xx", plain, "yy")
  @test.assert_eq(
    @codec.pdf_run_length_encode_view(
      wrapped_plain[2:wrapped_plain.length() - 2],
    ),
    codec_bytes_for_test([2, 65, 66, 67, 253, 90, 128]),
  )
  let encoded = codec_bytes_for_test([2, 65, 66, 67, 253, 90, 128])
  let wrapped_encoded = codec_wrap_view_for_test("xx", encoded, "yy")
  @test.assert_eq(
    @codec.pdf_run_length_decode_view(
      wrapped_encoded[2:wrapped_encoded.length() - 2],
    ),
    plain,
  )
}

///|
test "@codec.pdf_run_length_decode tolerates missing eod marker" {
  @test.assert_eq(
    @codec.pdf_run_length_decode(codec_bytes_for_test([0, 65])),
    codec_ascii_for_test("A"),
  )
  @test.assert_eq(
    @codec.pdf_run_length_decode(codec_bytes_for_test([2, 65])),
    codec_ascii_for_test("A"),
  )
  @test.assert_eq(
    @codec.pdf_run_length_decode(codec_bytes_for_test([253])),
    codec_bytes_for_test([]),
  )
}

///|
test "@codec.pdf_run_length_encode flushes long literal chunks" {
  let input = codec_bytes_for_test(
    [
      for i in 0..<129 => if i % 2 == 0 { 65 } else { 66 }
    ],
  )
  let encoded = @codec.pdf_run_length_encode(input)
  @test.assert_eq(encoded.length(), 132)
  @test.assert_eq(encoded[0].to_int(), 127)
  @test.assert_eq(encoded[129].to_int(), 0)
  @test.assert_eq(encoded[131].to_int(), 128)
  @test.assert_eq(@codec.pdf_run_length_decode(encoded), input)
}
