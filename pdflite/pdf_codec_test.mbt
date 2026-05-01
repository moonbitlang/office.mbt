///|
fn codec_bytes_for_test(values : ArrayView[Int]) -> @pdflite.PdfBytes {
  try! @pdflite.pdf_bytes_of_int_array(values)
}

///|
fn codec_ascii_for_test(text : String) -> @pdflite.PdfBytes {
  @ascii.encode(text)
}

///|
fn codec_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(codec_ascii_for_test(text))
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
test "pdf_ascii_hex_encode renders uppercase hex with terminator" {
  @test.assert_eq(
    @pdflite.pdf_ascii_hex_encode(codec_bytes_for_test([0, 15, 160, 255])),
    codec_ascii_for_test("000FA0FF>"),
  )
}

///|
test "pdf_ascii_hex_decode ignores whitespace and accepts lowercase" {
  @test.assert_eq(
    try! @pdflite.pdf_ascii_hex_decode(codec_ascii_for_test("  61 62\n63>")),
    codec_ascii_for_test("abc"),
  )
  @test.assert_eq(
    try! @pdflite.pdf_ascii_hex_decode(codec_ascii_for_test("af>")),
    codec_bytes_for_test([175]),
  )
}

///|
test "pdf_ascii_hex_decode pads odd final nibble before terminator" {
  @test.assert_eq(
    try! @pdflite.pdf_ascii_hex_decode(codec_ascii_for_test("6>")),
    codec_bytes_for_test([96]),
  )
}

///|
test "pdf_ascii_hex_decode reports invalid hex data" {
  let result : Result[@pdflite.PdfBytes, Error] = try? @pdflite.pdf_ascii_hex_decode(
    codec_ascii_for_test("6Z>"),
  )
  guard result is Err(@pdflite.PdfError::InvalidHexEscape) else {
    fail("expected InvalidHexEscape")
  }
}

///|
test "pdf_ascii85_encode renders full partial and zero chunks" {
  @test.assert_eq(
    @pdflite.pdf_ascii85_encode(codec_bytes_for_test([77, 97, 110, 32])),
    codec_ascii_for_test("9jqo^~>"),
  )
  @test.assert_eq(
    @pdflite.pdf_ascii85_encode(codec_bytes_for_test([77, 97, 110])),
    codec_ascii_for_test("9jqo~>"),
  )
  @test.assert_eq(
    @pdflite.pdf_ascii85_encode(codec_bytes_for_test([0, 0, 0, 0])),
    codec_ascii_for_test("z~>"),
  )
}

///|
test "pdf_ascii85_decode expands zero and partial chunks" {
  @test.assert_eq(
    try! @pdflite.pdf_ascii85_decode(codec_ascii_for_test("9jqo^~>")),
    codec_bytes_for_test([77, 97, 110, 32]),
  )
  @test.assert_eq(
    try! @pdflite.pdf_ascii85_decode(codec_ascii_for_test("9jqo~>")),
    codec_bytes_for_test([77, 97, 110]),
  )
  @test.assert_eq(
    try! @pdflite.pdf_ascii85_decode(codec_ascii_for_test("z~>")),
    codec_bytes_for_test([0, 0, 0, 0]),
  )
}

///|
test "pdf_ascii85_decode skips whitespace" {
  @test.assert_eq(
    try! @pdflite.pdf_ascii85_decode(codec_ascii_for_test("  9j\nqo^ ~>")),
    codec_bytes_for_test([77, 97, 110, 32]),
  )
}

///|
test "pdf_ascii85_decode reports malformed data" {
  let bad_char : Result[@pdflite.PdfBytes, Error] = try? @pdflite.pdf_ascii85_decode(
    codec_ascii_for_test("9jqo{~>"),
  )
  guard bad_char is Err(@pdflite.PdfError::InvalidASCII85Data) else {
    fail("expected InvalidASCII85Data")
  }
  let bad_zero : Result[@pdflite.PdfBytes, Error] = try? @pdflite.pdf_ascii85_decode(
    codec_ascii_for_test("!z~>"),
  )
  guard bad_zero is Err(@pdflite.PdfError::InvalidASCII85Data) else {
    fail("expected InvalidASCII85Data")
  }
  let one_digit : Result[@pdflite.PdfBytes, Error] = try? @pdflite.pdf_ascii85_decode(
    codec_ascii_for_test("!~>"),
  )
  guard one_digit is Err(@pdflite.PdfError::InvalidASCII85Data) else {
    fail("expected InvalidASCII85Data")
  }
  let overflowing_group : Result[@pdflite.PdfBytes, Error] = try? @pdflite.pdf_ascii85_decode(
    codec_ascii_for_test("uuuuu~>"),
  )
  guard overflowing_group is Err(@pdflite.PdfError::InvalidASCII85Data) else {
    fail("expected InvalidASCII85Data")
  }
  let unterminated : Result[@pdflite.PdfBytes, Error] = try? @pdflite.pdf_ascii85_decode(
    codec_ascii_for_test("9jqo"),
  )
  guard unterminated is Err(@pdflite.PdfError::InvalidASCII85Data) else {
    fail("expected InvalidASCII85Data")
  }
}

///|
test "pdf_lzw_decode expands clear literal dictionary and eod codes" {
  @test.assert_eq(
    try! @pdflite.pdf_lzw_decode(codec_bytes_for_test([128, 16, 96, 32])),
    codec_ascii_for_test("A"),
  )
  @test.assert_eq(
    try! @pdflite.pdf_lzw_decode(codec_bytes_for_test([128, 16, 72, 80, 40, 8])),
    codec_ascii_for_test("ABAB"),
  )
}

///|
test "pdf_lzw_decode handles eof and reset boundaries" {
  @test.assert_eq(
    try! @pdflite.pdf_lzw_decode(codec_bytes_for_test([])),
    codec_bytes_for_test([]),
  )
  @test.assert_eq(
    try! @pdflite.pdf_lzw_decode(codec_lzw_codes_for_test([257], 1)),
    codec_bytes_for_test([]),
  )
  @test.assert_eq(
    try! @pdflite.pdf_lzw_decode(codec_lzw_codes_for_test([256], 1)),
    codec_bytes_for_test([]),
  )
  @test.assert_eq(
    try! @pdflite.pdf_lzw_decode(
      codec_lzw_codes_for_test([65, 66, 256, 67, 257], 1),
    ),
    codec_ascii_for_test("ABC"),
  )
  @test.assert_eq(
    try! @pdflite.pdf_lzw_decode(codec_lzw_codes_for_test([65], 1)),
    codec_ascii_for_test("A"),
  )
  @test.assert_eq(
    try! @pdflite.pdf_lzw_decode(codec_lzw_codes_for_test([65, 256], 1)),
    codec_ascii_for_test("A"),
  )
}

///|
test "pdf_lzw_decode handles the repeated previous-code case" {
  @test.assert_eq(
    try! @pdflite.pdf_lzw_decode(codec_bytes_for_test([128, 16, 96, 80, 16])),
    codec_ascii_for_test("AAA"),
  )
}

///|
test "pdf_lzw_decode reports malformed input codes" {
  let result : Result[@pdflite.PdfBytes, Error] = try? @pdflite.pdf_lzw_decode(
    codec_bytes_for_test([128, 75, 32, 32]),
  )
  guard result is Err(@pdflite.PdfError::InvalidLZWData) else {
    fail("expected InvalidLZWData")
  }
  let result : Result[@pdflite.PdfBytes, Error] = try? @pdflite.pdf_lzw_decode(
    codec_lzw_codes_for_test([65, 300], 1),
  )
  guard result is Err(@pdflite.PdfError::InvalidLZWData) else {
    fail("expected InvalidLZWData")
  }
}

///|
test "pdf_flate_decode expands zlib stored and dynamic blocks" {
  @test.assert_eq(
    try! @pdflite.pdf_flate_decode(
      codec_bytes_for_test([
        120, 1, 1, 11, 0, 244, 255, 104, 101, 108, 108, 111, 32, 119, 111, 114, 108,
        100, 26, 11, 4, 93,
      ]),
    ),
    codec_ascii_for_test("hello world"),
  )
  @test.assert_eq(
    try! @pdflite.pdf_flate_decode(
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
test "pdf_flate_decode reports malformed zlib data" {
  let bad_header : Result[@pdflite.PdfBytes, Error] = try? @pdflite.pdf_flate_decode(
    codec_bytes_for_test([120, 2, 1, 0, 0, 255, 255, 0, 0, 0, 1]),
  )
  guard bad_header is Err(@pdflite.PdfError::InvalidFlateData) else {
    fail("expected InvalidFlateData")
  }
  let bad_checksum : Result[@pdflite.PdfBytes, Error] = try? @pdflite.pdf_flate_decode(
    codec_bytes_for_test([120, 1, 1, 1, 0, 254, 255, 65, 0, 0, 0, 0]),
  )
  guard bad_checksum is Err(@pdflite.PdfError::InvalidFlateData) else {
    fail("expected InvalidFlateData")
  }
}

///|
test "pdf_flate_encode emits zlib stored blocks" {
  let encoded = @pdflite.pdf_flate_encode(codec_ascii_for_test("Hi"))
  @test.assert_eq(
    encoded,
    codec_bytes_for_test([120, 1, 1, 2, 0, 253, 255, 72, 105, 0, 251, 0, 178]),
  )
  @test.assert_eq(
    try! @pdflite.pdf_flate_decode(encoded),
    codec_ascii_for_test("Hi"),
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
test "pdf_encode_filter_bytes dispatches supported filter names" {
  @test.assert_eq(
    try! @pdflite.pdf_encode_filter_bytes(
      codec_name_for_test("/Crypt"),
      codec_ascii_for_test("raw"),
    ),
    codec_ascii_for_test("raw"),
  )
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
    try! @pdflite.pdf_encode_filter_bytes(
      codec_name_for_test("/FlateDecode"),
      codec_ascii_for_test("Hi"),
    ),
    codec_bytes_for_test([120, 1, 1, 2, 0, 253, 255, 72, 105, 0, 251, 0, 178]),
  )
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
    fail("expected FilterNotSupported")
  }
  let result : Result[@pdflite.PdfBytes, Error] = try? @pdflite.pdf_encode_filter_bytes(
    flate,
    codec_ascii_for_test("data"),
  )
  guard result is Err(@pdflite.PdfError::FilterNotSupported(filter)) &&
    filter == flate else {
    fail("expected FilterNotSupported")
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
test "pdf_decode_predictor decodes png row filters" {
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
    fail("expected PredictorNotSupported")
  }
  let result : Result[@pdflite.PdfBytes, Error] = try? @pdflite.pdf_decode_predictor(
    15,
    1,
    8,
    1,
    codec_bytes_for_test([9, 0]),
  )
  guard result is Err(@pdflite.PdfError::PredictorNotSupported(9)) else {
    fail("expected PredictorNotSupported")
  }
  let result : Result[@pdflite.PdfBytes, Error] = try? @pdflite.pdf_decode_predictor(
    2,
    1,
    1,
    1,
    codec_bytes_for_test([0]),
  )
  guard result is Err(@pdflite.PdfError::PredictorNotSupported(2)) else {
    fail("expected PredictorNotSupported")
  }
  let result : Result[@pdflite.PdfBytes, Error] = try? @pdflite.pdf_decode_predictor(
    2,
    0,
    8,
    1,
    codec_bytes_for_test([0]),
  )
  guard result is Err(@pdflite.PdfError::PredictorExpected) else {
    fail("expected PredictorExpected")
  }
}

///|
test "pdf predictors keep identity data and reject bad encode parameters" {
  @test.assert_eq(
    try! @pdflite.pdf_decode_predictor(1, 1, 8, 1, codec_ascii_for_test("raw")),
    codec_ascii_for_test("raw"),
  )
  @test.assert_eq(
    try! @pdflite.pdf_encode_predictor(1, 1, 8, 1, codec_ascii_for_test("raw")),
    codec_ascii_for_test("raw"),
  )
  let unsupported : Result[@pdflite.PdfBytes, Error] = try? @pdflite.pdf_encode_predictor(
    13,
    1,
    8,
    1,
    codec_ascii_for_test("raw"),
  )
  guard unsupported is Err(@pdflite.PdfError::PredictorNotSupported(13)) else {
    fail("expected PredictorNotSupported")
  }
  let bad_dimensions : Result[@pdflite.PdfBytes, Error] = try? @pdflite.pdf_encode_predictor(
    11,
    1,
    0,
    1,
    codec_ascii_for_test("raw"),
  )
  guard bad_dimensions is Err(@pdflite.PdfError::PredictorExpected) else {
    fail("expected PredictorExpected")
  }
}

///|
test "pdf_encode_predictor emits png sub and up rows" {
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
test "pdf_decode_stream_onestage decodes single stream filter" {
  let length = codec_name_for_test("/Length")
  let filter = codec_name_for_test("/Filter")
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (length, PdfInteger(5)),
      (filter, PdfNameObject(codec_name_for_test("/ASCIIHexDecode"))),
    ]),
    StreamGot(codec_ascii_for_test("4869>")),
  )
  let decoded = try! @pdflite.pdf_decode_stream_onestage(stream)
  guard decoded is PdfStreamObject(decoded_stream) else {
    fail("expected decoded stream")
  }
  @test.assert_eq(decoded_stream.data, StreamGot(codec_ascii_for_test("Hi")))
  @test.assert_eq(
    decoded_stream.dictionary.lookup_immediate(length),
    Some(PdfInteger(2)),
  )
  @test.assert_eq(decoded_stream.dictionary.lookup_immediate(filter), None)
}

///|
test "pdf_decode_stream_onestage applies first DecodeParms predictor" {
  let length = codec_name_for_test("/Length")
  let filter = codec_name_for_test("/Filter")
  let decodeparms = codec_name_for_test("/DecodeParms")
  let predictor = codec_name_for_test("/Predictor")
  let columns = codec_name_for_test("/Columns")
  let encoded = @pdflite.pdf_ascii_hex_encode(
    codec_bytes_for_test([1, 10, 10, 10]),
  )
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (length, PdfInteger(encoded.length())),
      (filter, PdfNameObject(codec_name_for_test("/ASCIIHexDecode"))),
      (
        decodeparms,
        @pdflite.pdf_dictionary([
          (predictor, PdfInteger(15)),
          (columns, PdfInteger(3)),
        ]),
      ),
    ]),
    StreamGot(encoded),
  )
  let decoded = try! @pdflite.pdf_decode_stream_onestage(stream)
  guard decoded is PdfStreamObject(decoded_stream) else {
    fail("expected decoded stream")
  }
  @test.assert_eq(
    decoded_stream.data,
    StreamGot(codec_bytes_for_test([10, 20, 30])),
  )
  @test.assert_eq(decoded_stream.dictionary.lookup_immediate(filter), None)
  @test.assert_eq(decoded_stream.dictionary.lookup_immediate(decodeparms), None)
}

///|
test "pdf_decode_stream_onestage accepts DecodeParms arrays" {
  let length = codec_name_for_test("/Length")
  let filter = codec_name_for_test("/Filter")
  let decodeparms = codec_name_for_test("/DecodeParms")
  let predictor = codec_name_for_test("/Predictor")
  let encoded = @pdflite.pdf_ascii_hex_encode(codec_ascii_for_test("Hi"))
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (length, PdfInteger(encoded.length())),
      (filter, PdfNameObject(codec_name_for_test("/ASCIIHexDecode"))),
      (
        decodeparms,
        PdfArray([@pdflite.pdf_dictionary([(predictor, PdfInteger(1))])]),
      ),
    ]),
    StreamGot(encoded),
  )
  let decoded = try! @pdflite.pdf_decode_stream_onestage(stream)
  guard decoded is PdfStreamObject(decoded_stream) else {
    fail("expected decoded stream")
  }
  @test.assert_eq(decoded_stream.data, StreamGot(codec_ascii_for_test("Hi")))
  @test.assert_eq(
    decoded_stream.dictionary.lookup_immediate(decodeparms),
    Some(PdfArray([])),
  )
}

///|
test "pdf_decode_stream_onestage applies lzw EarlyChange DecodeParms" {
  let length = codec_name_for_test("/Length")
  let filter = codec_name_for_test("/Filter")
  let decodeparms = codec_name_for_test("/DecodeParms")
  let early_change = codec_name_for_test("/EarlyChange")
  let codes : Array[Int] = [256]
  for _ in 0..<255 {
    codes.push(65)
  }
  codes.push(257)
  let encoded = codec_lzw_codes_for_test(codes[:], 0)
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (length, PdfInteger(encoded.length())),
      (filter, PdfNameObject(codec_name_for_test("/LZWDecode"))),
      (decodeparms, @pdflite.pdf_dictionary([(early_change, PdfInteger(0))])),
    ]),
    StreamGot(encoded),
  )
  let decoded = try! @pdflite.pdf_decode_stream_onestage(stream)
  guard decoded is PdfStreamObject(decoded_stream) else {
    fail("expected decoded stream")
  }
  @test.assert_eq(
    decoded_stream.data,
    StreamGot(codec_bytes_for_test([ for _ in 0..<255 => 65 ])),
  )
  @test.assert_eq(decoded_stream.dictionary.lookup_immediate(filter), None)
  @test.assert_eq(decoded_stream.dictionary.lookup_immediate(decodeparms), None)
}

///|
test "pdf_decode_stream_onestage handles short filters and null decodeparms" {
  let length = codec_name_for_test("/Length")
  let short_filter = codec_name_for_test("/F")
  let short_decodeparms = codec_name_for_test("/DP")
  let predictor = codec_name_for_test("/Predictor")
  let encoded = @pdflite.pdf_ascii_hex_encode(codec_ascii_for_test("Hi"))
  let retained_decodeparms = @pdflite.pdf_dictionary([
    (predictor, PdfInteger(1)),
  ])
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (length, PdfInteger(encoded.length())),
      (short_filter, PdfNameObject(codec_name_for_test("/AHx"))),
      (short_decodeparms, PdfArray([PdfNull, retained_decodeparms])),
    ]),
    StreamGot(encoded),
  )
  let decoded = try! @pdflite.pdf_decode_stream_onestage(stream)
  guard decoded is PdfStreamObject(decoded_stream) else {
    fail("expected decoded stream")
  }
  @test.assert_eq(decoded_stream.data, StreamGot(codec_ascii_for_test("Hi")))
  @test.assert_eq(
    decoded_stream.dictionary.lookup_immediate(short_filter),
    None,
  )
  @test.assert_eq(
    decoded_stream.dictionary.lookup_immediate(short_decodeparms),
    Some(PdfArray([retained_decodeparms])),
  )
}

///|
test "pdf_decode_stream_onestage removes only first array filter" {
  let length = codec_name_for_test("/Length")
  let filter = codec_name_for_test("/Filter")
  let encoded_once = @pdflite.pdf_ascii_hex_encode(
    codec_ascii_for_test("9jqo~>"),
  )
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (length, PdfInteger(encoded_once.length())),
      (
        filter,
        PdfArray([
          PdfNameObject(codec_name_for_test("/AHx")),
          PdfNameObject(codec_name_for_test("/A85")),
        ]),
      ),
    ]),
    StreamGot(encoded_once),
  )
  let decoded = try! @pdflite.pdf_decode_stream_onestage(stream)
  guard decoded is PdfStreamObject(decoded_stream) else {
    fail("expected decoded stream")
  }
  @test.assert_eq(
    decoded_stream.data,
    StreamGot(codec_ascii_for_test("9jqo~>")),
  )
  @test.assert_eq(
    decoded_stream.dictionary.lookup_immediate(filter),
    Some(PdfArray([PdfNameObject(codec_name_for_test("/A85"))])),
  )
}

///|
test "pdf_decode_stream_onestage treats empty filter arrays as raw" {
  let length = codec_name_for_test("/Length")
  let filter = codec_name_for_test("/Filter")
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([(length, PdfInteger(2)), (filter, PdfArray([]))]),
    StreamGot(codec_ascii_for_test("Hi")),
  )
  let decoded = try! @pdflite.pdf_decode_stream_onestage(stream)
  guard decoded is PdfStreamObject(decoded_stream) else {
    fail("expected decoded stream")
  }
  @test.assert_eq(decoded_stream.data, StreamGot(codec_ascii_for_test("Hi")))
  @test.assert_eq(
    decoded_stream.dictionary.lookup_immediate(filter),
    Some(PdfArray([])),
  )
}

///|
test "pdf_decode_stream_onestage uses default lzw EarlyChange" {
  let length = codec_name_for_test("/Length")
  let filter = codec_name_for_test("/Filter")
  let encoded = codec_lzw_codes_for_test([256, 65, 257], 1)
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (length, PdfInteger(encoded.length())),
      (filter, PdfNameObject(codec_name_for_test("/LZWDecode"))),
    ]),
    StreamGot(encoded),
  )
  let decoded = try! @pdflite.pdf_decode_stream_onestage(stream)
  guard decoded is PdfStreamObject(decoded_stream) else {
    fail("expected decoded stream")
  }
  @test.assert_eq(decoded_stream.data, StreamGot(codec_ascii_for_test("A")))
}

///|
test "pdf_decode_stream decodes all supported filter stages" {
  let length = codec_name_for_test("/Length")
  let filter = codec_name_for_test("/Filter")
  let ascii85 = @pdflite.pdf_ascii85_encode(codec_bytes_for_test([77, 97, 110]))
  let encoded = @pdflite.pdf_ascii_hex_encode(ascii85)
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (length, PdfInteger(encoded.length())),
      (
        filter,
        PdfArray([
          PdfNameObject(codec_name_for_test("/AHx")),
          PdfNameObject(codec_name_for_test("/A85")),
        ]),
      ),
    ]),
    StreamGot(encoded),
  )
  let decoded = try! @pdflite.pdf_decode_stream(stream)
  guard decoded is PdfStreamObject(decoded_stream) else {
    fail("expected decoded stream")
  }
  @test.assert_eq(
    decoded_stream.data,
    StreamGot(codec_bytes_for_test([77, 97, 110])),
  )
  @test.assert_eq(
    decoded_stream.dictionary.lookup_immediate(length),
    Some(PdfInteger(3)),
  )
  @test.assert_eq(decoded_stream.dictionary.lookup_immediate(filter), None)
}

///|
test "pdf_decode_stream bounds excessive filter stages" {
  let length = codec_name_for_test("/Length")
  let filter = codec_name_for_test("/Filter")
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (length, PdfInteger(1)),
      (
        filter,
        PdfArray(
          [
            for _ in 0..<1025 => PdfNameObject(codec_name_for_test("/Crypt"))
          ],
        ),
      ),
    ]),
    StreamGot(codec_ascii_for_test("x")),
  )
  let result : Result[@pdflite.PdfObject, Error] = try? @pdflite.pdf_decode_stream(
    stream,
  )
  guard result is Err(@pdflite.PdfError::FilterExpected) else {
    fail("expected FilterExpected")
  }
}

///|
test "pdf_encode_stream_with_filter adds filter and updates length" {
  let length = codec_name_for_test("/Length")
  let filter = codec_name_for_test("/Filter")
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([(length, PdfInteger(2))]),
    StreamGot(codec_ascii_for_test("Hi")),
  )
  let encoded = try! @pdflite.pdf_encode_stream_with_filter(
    codec_name_for_test("/ASCIIHexDecode"),
    stream,
  )
  guard encoded is PdfStreamObject(encoded_stream) else {
    fail("expected encoded stream")
  }
  @test.assert_eq(encoded_stream.data, StreamGot(codec_ascii_for_test("4869>")))
  @test.assert_eq(
    encoded_stream.dictionary.lookup_immediate(length),
    Some(PdfInteger(5)),
  )
  @test.assert_eq(
    encoded_stream.dictionary.lookup_immediate(filter),
    Some(PdfNameObject(codec_name_for_test("/ASCIIHexDecode"))),
  )
}

///|
test "pdf_encode_stream_with_filter prepends existing filters" {
  let length = codec_name_for_test("/Length")
  let filter = codec_name_for_test("/Filter")
  let ascii_hex = codec_name_for_test("/ASCIIHexDecode")
  let run_length = codec_name_for_test("/RunLengthDecode")
  let ascii85 = codec_name_for_test("/ASCII85Decode")
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (length, PdfInteger(2)),
      (filter, PdfNameObject(run_length)),
    ]),
    StreamGot(codec_ascii_for_test("Hi")),
  )
  let encoded = try! @pdflite.pdf_encode_stream_with_filter(ascii_hex, stream)
  guard encoded is PdfStreamObject(encoded_stream) else {
    fail("expected encoded stream")
  }
  @test.assert_eq(
    encoded_stream.dictionary.lookup_immediate(filter),
    Some(PdfArray([PdfNameObject(ascii_hex), PdfNameObject(run_length)])),
  )
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (length, PdfInteger(2)),
      (filter, PdfArray([PdfNameObject(ascii85)])),
    ]),
    StreamGot(codec_ascii_for_test("Hi")),
  )
  let encoded = try! @pdflite.pdf_encode_stream_with_filter(run_length, stream)
  guard encoded is PdfStreamObject(encoded_stream) else {
    fail("expected encoded stream")
  }
  @test.assert_eq(
    encoded_stream.dictionary.lookup_immediate(filter),
    Some(PdfArray([PdfNameObject(run_length), PdfNameObject(ascii85)])),
  )
}

///|
test "pdf_encode_stream_with_filter_and_predictor round trips through decode stream" {
  let length = codec_name_for_test("/Length")
  let filter = codec_name_for_test("/Filter")
  let decodeparms = codec_name_for_test("/DecodeParms")
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([(length, PdfInteger(6))]),
    StreamGot(codec_bytes_for_test([10, 20, 30, 11, 25, 35])),
  )
  let encoded = try! @pdflite.pdf_encode_stream_with_filter_and_predictor(
    codec_name_for_test("/ASCIIHexDecode"),
    12,
    1,
    8,
    3,
    stream,
  )
  guard encoded is PdfStreamObject(encoded_stream) else {
    fail("expected encoded stream")
  }
  @test.assert_eq(
    encoded_stream.data,
    StreamGot(codec_ascii_for_test("020A141E02010505>")),
  )
  @test.assert_eq(
    encoded_stream.dictionary.lookup_immediate(filter),
    Some(PdfNameObject(codec_name_for_test("/ASCIIHexDecode"))),
  )
  guard encoded_stream.dictionary.lookup_immediate(decodeparms)
    is Some(PdfDictionary(_)) else {
    fail("expected DecodeParms dictionary")
  }
  let decoded = try! @pdflite.pdf_decode_stream(encoded)
  guard decoded is PdfStreamObject(decoded_stream) else {
    fail("expected decoded stream")
  }
  @test.assert_eq(
    decoded_stream.data,
    StreamGot(codec_bytes_for_test([10, 20, 30, 11, 25, 35])),
  )
  @test.assert_eq(decoded_stream.dictionary.lookup_immediate(filter), None)
  @test.assert_eq(decoded_stream.dictionary.lookup_immediate(decodeparms), None)
}

///|
test "pdf_encode_stream_with_filter_and_predictor prepends decodeparms" {
  let length = codec_name_for_test("/Length")
  let decodeparms = codec_name_for_test("/DecodeParms")
  let predictor = codec_name_for_test("/Predictor")
  let existing = @pdflite.pdf_dictionary([(predictor, PdfInteger(1))])
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([(length, PdfInteger(3)), (decodeparms, existing)]),
    StreamGot(codec_ascii_for_test("abc")),
  )
  let encoded = try! @pdflite.pdf_encode_stream_with_filter_and_predictor(
    codec_name_for_test("/ASCIIHexDecode"),
    11,
    1,
    8,
    3,
    stream,
  )
  guard encoded is PdfStreamObject(encoded_stream) else {
    fail("expected encoded stream")
  }
  guard encoded_stream.dictionary.lookup_immediate(decodeparms)
    is Some(PdfArray([PdfDictionary(_), existing_decodeparms])) else {
    fail("expected DecodeParms array")
  }
  @test.assert_eq(existing_decodeparms, existing)
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (length, PdfInteger(3)),
      (decodeparms, PdfArray([existing])),
    ]),
    StreamGot(codec_ascii_for_test("abc")),
  )
  let encoded = try! @pdflite.pdf_encode_stream_with_filter_and_predictor(
    codec_name_for_test("/ASCIIHexDecode"),
    11,
    1,
    8,
    3,
    stream,
  )
  guard encoded is PdfStreamObject(encoded_stream) else {
    fail("expected encoded stream")
  }
  guard encoded_stream.dictionary.lookup_immediate(decodeparms)
    is Some(PdfArray([PdfDictionary(_), existing_decodeparms])) else {
    fail("expected DecodeParms array")
  }
  @test.assert_eq(existing_decodeparms, existing)
}

///|
test "pdf_decode_stream_onestage reports malformed stream filters" {
  let length = codec_name_for_test("/Length")
  let filter = codec_name_for_test("/Filter")
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([(length, PdfInteger(2)), (filter, PdfInteger(1))]),
    StreamGot(codec_ascii_for_test("Hi")),
  )
  let result : Result[@pdflite.PdfObject, Error] = try? @pdflite.pdf_decode_stream_onestage(
    stream,
  )
  guard result is Err(@pdflite.PdfError::FilterExpected) else {
    fail("expected FilterExpected")
  }
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([]),
    StreamGot(codec_ascii_for_test("Hi")),
  )
  let result : Result[@pdflite.PdfObject, Error] = try? @pdflite.pdf_decode_stream_onestage(
    stream,
  )
  guard result is Err(@pdflite.PdfError::StreamLengthExpected) else {
    fail("expected StreamLengthExpected")
  }
  let result : Result[@pdflite.PdfObject, Error] = try? @pdflite.pdf_decode_stream_onestage(
    PdfNull,
  )
  guard result is Err(@pdflite.PdfError::ParseStreamExpected) else {
    fail("expected ParseStreamExpected")
  }
  let result : Result[@pdflite.PdfObject, Error] = try? @pdflite.pdf_decode_stream(
    PdfNull,
  )
  guard result is Err(@pdflite.PdfError::ParseStreamExpected) else {
    fail("expected ParseStreamExpected")
  }
  let deferred = @pdflite.stream_to_get(
    @pdflite.byte_cursor_of_bytes(codec_ascii_for_test("Hi")),
    0,
    2,
  )
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([(length, PdfInteger(2))]),
    StreamToGet(deferred),
  )
  let result : Result[@pdflite.PdfObject, Error] = try? @pdflite.pdf_decode_stream_onestage(
    stream,
  )
  guard result is Err(@pdflite.PdfError::StreamDataExpected) else {
    fail("expected StreamDataExpected")
  }
  let decodeparms = codec_name_for_test("/DecodeParms")
  let predictor = codec_name_for_test("/Predictor")
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (length, PdfInteger(5)),
      (filter, PdfNameObject(codec_name_for_test("/ASCIIHexDecode"))),
      (
        decodeparms,
        @pdflite.pdf_dictionary([
          (predictor, PdfNameObject(codec_name_for_test("/Bad"))),
        ]),
      ),
    ]),
    StreamGot(codec_ascii_for_test("4869>")),
  )
  let result : Result[@pdflite.PdfObject, Error] = try? @pdflite.pdf_decode_stream_onestage(
    stream,
  )
  guard result is Err(@pdflite.PdfError::PredictorExpected) else {
    fail("expected PredictorExpected")
  }
}

///|
test "pdf stream encoding reports malformed objects" {
  let length = codec_name_for_test("/Length")
  let filter = codec_name_for_test("/Filter")
  let result : Result[@pdflite.PdfObject, Error] = try? @pdflite.pdf_encode_stream_with_filter(
    codec_name_for_test("/ASCIIHexDecode"),
    PdfNull,
  )
  guard result is Err(@pdflite.PdfError::ParseStreamExpected) else {
    fail("expected ParseStreamExpected")
  }
  let deferred = @pdflite.stream_to_get(
    @pdflite.byte_cursor_of_bytes(codec_ascii_for_test("Hi")),
    0,
    2,
  )
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([(length, PdfInteger(2))]),
    StreamToGet(deferred),
  )
  let result : Result[@pdflite.PdfObject, Error] = try? @pdflite.pdf_encode_stream_with_filter(
    codec_name_for_test("/ASCIIHexDecode"),
    stream,
  )
  guard result is Err(@pdflite.PdfError::StreamDataExpected) else {
    fail("expected StreamDataExpected")
  }
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([(length, PdfInteger(2)), (filter, PdfInteger(1))]),
    StreamGot(codec_ascii_for_test("Hi")),
  )
  let result : Result[@pdflite.PdfObject, Error] = try? @pdflite.pdf_encode_stream_with_filter(
    codec_name_for_test("/ASCIIHexDecode"),
    stream,
  )
  guard result is Err(@pdflite.PdfError::FilterExpected) else {
    fail("expected FilterExpected")
  }
  let decodeparms = codec_name_for_test("/DecodeParms")
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (length, PdfInteger(2)),
      (decodeparms, PdfInteger(1)),
    ]),
    StreamGot(codec_ascii_for_test("Hi")),
  )
  let result : Result[@pdflite.PdfObject, Error] = try? @pdflite.pdf_encode_stream_with_filter_and_predictor(
    codec_name_for_test("/ASCIIHexDecode"),
    11,
    1,
    8,
    2,
    stream,
  )
  guard result is Err(@pdflite.PdfError::PredictorExpected) else {
    fail("expected PredictorExpected")
  }
  let result : Result[@pdflite.PdfObject, Error] = try? @pdflite.pdf_encode_stream_with_filter_and_predictor(
    codec_name_for_test("/ASCIIHexDecode"),
    11,
    1,
    8,
    2,
    PdfNull,
  )
  guard result is Err(@pdflite.PdfError::ParseStreamExpected) else {
    fail("expected ParseStreamExpected")
  }
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([(length, PdfInteger(2))]),
    StreamToGet(deferred),
  )
  let result : Result[@pdflite.PdfObject, Error] = try? @pdflite.pdf_encode_stream_with_filter_and_predictor(
    codec_name_for_test("/ASCIIHexDecode"),
    11,
    1,
    8,
    2,
    stream,
  )
  guard result is Err(@pdflite.PdfError::StreamDataExpected) else {
    fail("expected StreamDataExpected")
  }
}

///|
test "pdf_run_length_decode expands literal and repeat chunks" {
  @test.assert_eq(
    @pdflite.pdf_run_length_decode(
      codec_bytes_for_test([2, 65, 66, 67, 253, 90, 128]),
    ),
    codec_ascii_for_test("ABCZZZZ"),
  )
}

///|
test "pdf_run_length_encode emits literal repeat and eod chunks" {
  @test.assert_eq(
    @pdflite.pdf_run_length_encode(codec_ascii_for_test("ABCZZZZ")),
    codec_bytes_for_test([2, 65, 66, 67, 253, 90, 128]),
  )
}

///|
test "pdf_run_length_decode tolerates missing eod marker" {
  @test.assert_eq(
    @pdflite.pdf_run_length_decode(codec_bytes_for_test([0, 65])),
    codec_ascii_for_test("A"),
  )
  @test.assert_eq(
    @pdflite.pdf_run_length_decode(codec_bytes_for_test([2, 65])),
    codec_ascii_for_test("A"),
  )
  @test.assert_eq(
    @pdflite.pdf_run_length_decode(codec_bytes_for_test([253])),
    codec_bytes_for_test([]),
  )
}

///|
test "pdf_run_length_encode flushes long literal chunks" {
  let input = codec_bytes_for_test(
    [
      for i in 0..<129 => if i % 2 == 0 { 65 } else { 66 }
    ],
  )
  let encoded = @pdflite.pdf_run_length_encode(input)
  @test.assert_eq(encoded.length(), 132)
  @test.assert_eq(encoded[0].to_int(), 127)
  @test.assert_eq(encoded[129].to_int(), 0)
  @test.assert_eq(encoded[131].to_int(), 128)
  @test.assert_eq(@pdflite.pdf_run_length_decode(encoded), input)
}
