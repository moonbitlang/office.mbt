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
}

///|
test "pdf_encode_filter_bytes dispatches supported filter names" {
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
}

///|
test "pdf filter dispatch reports unsupported filters" {
  let flate = codec_name_for_test("/FlateDecode")
  let result : Result[@pdflite.PdfBytes, Error] = try? @pdflite.pdf_decode_filter_bytes(
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
}
