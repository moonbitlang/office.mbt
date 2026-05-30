///|
fn codec_stream_bytes_for_test(values : ArrayView[Int]) -> @pdflite.PdfBytes {
  try! @pdflite.pdf_bytes_of_int_array(values)
}

///|
fn codec_stream_ascii_for_test(text : String) -> @pdflite.PdfBytes {
  @ascii.encode(text)
}

///|
fn codec_stream_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(codec_stream_ascii_for_test(text))
}

///|
fn codec_stream_lzw_codes_for_test(
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
fn codec_stream_bits_for_test(bits : ArrayView[Int]) -> @pdflite.PdfBytes {
  let writer = @pdflite.bit_writer_new()
  for bit in bits {
    try! writer.put_bit(bit)
  }
  writer.to_bytes()
}

///|
test "pdf_decode_stream_onestage decodes single stream filter" {
  let length = codec_stream_name_for_test("/Length")
  let filter = codec_stream_name_for_test("/Filter")
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (length, PdfInteger(5)),
      (filter, PdfNameObject(codec_stream_name_for_test("/ASCIIHexDecode"))),
    ]),
    StreamGot(codec_stream_ascii_for_test("4869>")),
  )
  let decoded = try! @pdflite.pdf_decode_stream_onestage(stream)
  guard decoded is PdfStreamObject(decoded_stream) else {
    fail("expected decoded stream")
  }
  @test.assert_eq(
    decoded_stream.data,
    StreamGot(codec_stream_ascii_for_test("Hi")),
  )
  @test.assert_eq(
    decoded_stream.dictionary.lookup_immediate(length),
    Some(PdfInteger(2)),
  )
  @test.assert_eq(decoded_stream.dictionary.lookup_immediate(filter), None)
}

///|
test "pdf_decode_stream_onestage applies first DecodeParms predictor" {
  let length = codec_stream_name_for_test("/Length")
  let filter = codec_stream_name_for_test("/Filter")
  let decodeparms = codec_stream_name_for_test("/DecodeParms")
  let predictor = codec_stream_name_for_test("/Predictor")
  let columns = codec_stream_name_for_test("/Columns")
  let encoded = @codec.pdf_ascii_hex_encode(
    codec_stream_bytes_for_test([1, 10, 10, 10]),
  )
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (length, PdfInteger(encoded.length())),
      (filter, PdfNameObject(codec_stream_name_for_test("/ASCIIHexDecode"))),
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
    StreamGot(codec_stream_bytes_for_test([10, 20, 30])),
  )
  @test.assert_eq(decoded_stream.dictionary.lookup_immediate(filter), None)
  @test.assert_eq(decoded_stream.dictionary.lookup_immediate(decodeparms), None)
}

///|
test "PdfDocument pdf_decode_stream resolves indirect filters and DecodeParms" {
  let length = codec_stream_name_for_test("/Length")
  let filter = codec_stream_name_for_test("/Filter")
  let decodeparms = codec_stream_name_for_test("/DecodeParms")
  let predictor = codec_stream_name_for_test("/Predictor")
  let columns = codec_stream_name_for_test("/Columns")
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(
    8,
    PdfNameObject(codec_stream_name_for_test("/ASCIIHexDecode")),
  )
  doc.add_object_given_number(
    9,
    @pdflite.pdf_dictionary([
      (predictor, PdfInteger(15)),
      (columns, PdfInteger(3)),
    ]),
  )
  let encoded = @codec.pdf_ascii_hex_encode(
    codec_stream_bytes_for_test([1, 10, 10, 10]),
  )
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (length, PdfInteger(encoded.length())),
      (filter, PdfIndirect(8)),
      (decodeparms, PdfIndirect(9)),
    ]),
    StreamGot(encoded),
  )
  let decoded = try! doc.pdf_decode_stream(stream)
  guard decoded is PdfStreamObject(decoded_stream) else {
    fail("expected decoded stream")
  }
  @test.assert_eq(
    decoded_stream.data,
    StreamGot(codec_stream_bytes_for_test([10, 20, 30])),
  )
  @test.assert_eq(decoded_stream.dictionary.lookup_immediate(filter), None)
  @test.assert_eq(decoded_stream.dictionary.lookup_immediate(decodeparms), None)
}

///|
test "PdfDocument pdf_decode_stream decodes array filters with indirect entries" {
  let length = codec_stream_name_for_test("/Length")
  let filter = codec_stream_name_for_test("/Filter")
  let decodeparms = codec_stream_name_for_test("/DecodeParms")
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(
    8,
    PdfNameObject(codec_stream_name_for_test("/ASCIIHexDecode")),
  )
  let ascii85 = @codec.pdf_ascii85_encode(
    codec_stream_bytes_for_test([77, 97, 110]),
  )
  let encoded = @codec.pdf_ascii_hex_encode(ascii85)
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (length, PdfInteger(encoded.length())),
      (
        filter,
        PdfArray([
          PdfIndirect(8),
          PdfNameObject(codec_stream_name_for_test("/A85")),
        ]),
      ),
    ]),
    StreamGot(encoded),
  )
  let decoded = try! doc.pdf_decode_stream(stream)
  guard decoded is PdfStreamObject(decoded_stream) else {
    fail("expected decoded stream")
  }
  @test.assert_eq(
    decoded_stream.data,
    StreamGot(codec_stream_bytes_for_test([77, 97, 110])),
  )
  @test.assert_eq(decoded_stream.dictionary.lookup_immediate(filter), None)
  @test.assert_eq(decoded_stream.dictionary.lookup_immediate(decodeparms), None)
}

///|
test "PdfDocument pdf_decode_stream handles short filter keys and DP arrays" {
  let length = codec_stream_name_for_test("/Length")
  let short_filter = codec_stream_name_for_test("/F")
  let short_decodeparms = codec_stream_name_for_test("/DP")
  let predictor = codec_stream_name_for_test("/Predictor")
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(
    8,
    PdfNameObject(codec_stream_name_for_test("/AHx")),
  )
  let retained_decodeparms = @pdflite.pdf_dictionary([
    (predictor, PdfInteger(1)),
  ])
  let encoded = @codec.pdf_ascii_hex_encode(codec_stream_ascii_for_test("Hi"))
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (length, PdfInteger(encoded.length())),
      (short_filter, PdfArray([PdfIndirect(8)])),
      (short_decodeparms, PdfArray([PdfNull, retained_decodeparms])),
    ]),
    StreamGot(encoded),
  )
  let decoded = try! doc.pdf_decode_stream(stream)
  guard decoded is PdfStreamObject(decoded_stream) else {
    fail("expected decoded stream")
  }
  @test.assert_eq(
    decoded_stream.data,
    StreamGot(codec_stream_ascii_for_test("Hi")),
  )
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
test "PdfDocument pdf_decode_stream accepts indirect DecodeParms arrays" {
  let length = codec_stream_name_for_test("/Length")
  let filter = codec_stream_name_for_test("/Filter")
  let decodeparms = codec_stream_name_for_test("/DecodeParms")
  let predictor = codec_stream_name_for_test("/Predictor")
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(
    9,
    @pdflite.pdf_dictionary([(predictor, PdfInteger(1))]),
  )
  let encoded = @codec.pdf_ascii_hex_encode(codec_stream_ascii_for_test("Hi"))
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (length, PdfInteger(encoded.length())),
      (filter, PdfNameObject(codec_stream_name_for_test("/ASCIIHexDecode"))),
      (decodeparms, PdfArray([PdfIndirect(9)])),
    ]),
    StreamGot(encoded),
  )
  let decoded = try! doc.pdf_decode_stream(stream)
  guard decoded is PdfStreamObject(decoded_stream) else {
    fail("expected decoded stream")
  }
  @test.assert_eq(
    decoded_stream.data,
    StreamGot(codec_stream_ascii_for_test("Hi")),
  )
  @test.assert_eq(decoded_stream.dictionary.lookup_immediate(filter), None)
  @test.assert_eq(
    decoded_stream.dictionary.lookup_immediate(decodeparms),
    Some(PdfArray([])),
  )
}

///|
test "PdfDocument pdf_decode_stream applies indirect lzw EarlyChange" {
  let length = codec_stream_name_for_test("/Length")
  let filter = codec_stream_name_for_test("/Filter")
  let decodeparms = codec_stream_name_for_test("/DecodeParms")
  let early_change = codec_stream_name_for_test("/EarlyChange")
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(
    9,
    @pdflite.pdf_dictionary([(early_change, PdfInteger(0))]),
  )
  let codes : Array[Int] = [256]
  for _ in 0..<255 {
    codes.push(65)
  }
  codes.push(257)
  let encoded = codec_stream_lzw_codes_for_test(codes, 0)
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (length, PdfInteger(encoded.length())),
      (filter, PdfNameObject(codec_stream_name_for_test("/LZWDecode"))),
      (decodeparms, PdfIndirect(9)),
    ]),
    StreamGot(encoded),
  )
  let decoded = try! doc.pdf_decode_stream(stream)
  guard decoded is PdfStreamObject(decoded_stream) else {
    fail("expected decoded stream")
  }
  @test.assert_eq(
    decoded_stream.data,
    StreamGot(codec_stream_bytes_for_test([ for _ in 0..<255 => 65 ])),
  )
}

///|
test "PdfDocument pdf_decode_stream decodes CCITT Group 3 one dimensional rows" {
  let length = codec_stream_name_for_test("/Length")
  let filter = codec_stream_name_for_test("/Filter")
  let decodeparms = codec_stream_name_for_test("/DecodeParms")
  let columns = codec_stream_name_for_test("/Columns")
  let rows = codec_stream_name_for_test("/Rows")
  let doc = @pdflite.pdf_document_empty()
  let encoded = codec_stream_bits_for_test([
    // white 4, black 4; then white 0, black 8
    1, 0, 1, 1, 0, 1, 1, 0, 0, 1, 1, 0, 1, 0, 1, 0, 0, 0, 1, 0, 1,
  ])
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (length, PdfInteger(encoded.length())),
      (filter, PdfNameObject(codec_stream_name_for_test("/CCITTFaxDecode"))),
      (
        decodeparms,
        @pdflite.pdf_dictionary([
          (columns, PdfInteger(8)),
          (rows, PdfInteger(2)),
        ]),
      ),
    ]),
    StreamGot(encoded),
  )
  let decoded = doc.pdf_decode_stream(stream)
  guard decoded is PdfStreamObject(decoded_stream) else {
    fail("expected decoded stream")
  }
  @test.assert_eq(
    decoded_stream.data,
    StreamGot(codec_stream_bytes_for_test([0xF0, 0x00])),
  )
  @test.assert_eq(decoded_stream.dictionary.lookup_immediate(filter), None)
  @test.assert_eq(decoded_stream.dictionary.lookup_immediate(decodeparms), None)
}

///|
test "PdfDocument pdf_decode_stream decodes CCITT Group 4 rows" {
  let length = codec_stream_name_for_test("/Length")
  let filter = codec_stream_name_for_test("/Filter")
  let decodeparms = codec_stream_name_for_test("/DecodeParms")
  let encoded = codec_stream_bits_for_test([
    // horizontal mode, white 4, black 4 against the initial all-white reference.
    0, 0, 1, 1, 0, 1, 1, 0, 1, 1,
  ])
  let decoded = @pdflite.pdf_document_empty().pdf_decode_stream(
    @pdflite.pdf_stream(
      @pdflite.pdf_dictionary([
        (length, PdfInteger(encoded.length())),
        (filter, PdfNameObject(codec_stream_name_for_test("/CCITTFaxDecode"))),
        (
          decodeparms,
          @pdflite.pdf_dictionary([
            (codec_stream_name_for_test("/K"), PdfInteger(-1)),
            (codec_stream_name_for_test("/Columns"), PdfInteger(8)),
            (codec_stream_name_for_test("/Rows"), PdfInteger(1)),
          ]),
        ),
      ]),
      StreamGot(encoded),
    ),
  )
  guard decoded is PdfStreamObject(decoded_stream) else {
    fail("expected decoded stream")
  }
  @test.assert_eq(
    decoded_stream.data,
    StreamGot(codec_stream_bytes_for_test([0xF0])),
  )
  @test.assert_eq(decoded_stream.dictionary.lookup_immediate(filter), None)
  @test.assert_eq(decoded_stream.dictionary.lookup_immediate(decodeparms), None)
}

///|
test "PdfDocument pdf_decode_stream decodes CCITT short filter and direct DecodeParms" {
  let length = codec_stream_name_for_test("/Length")
  let filter = codec_stream_name_for_test("/Filter")
  let decodeparms = codec_stream_name_for_test("/DecodeParms")
  let columns = codec_stream_name_for_test("/Columns")
  let rows = codec_stream_name_for_test("/Rows")
  let black_is_1 = codec_stream_name_for_test("/BlackIs1")
  let encoded = codec_stream_bits_for_test([
    // white 0, black 4, white 4 with /BlackIs1 true.
    0, 0, 1, 1, 0, 1, 0, 1, 0, 1, 1, 1, 0, 1, 1,
  ])
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(
    20,
    @pdflite.pdf_dictionary([
      (columns, PdfInteger(8)),
      (rows, PdfInteger(1)),
      (black_is_1, PdfBoolean(true)),
    ]),
  )
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (length, PdfInteger(encoded.length())),
      (filter, PdfNameObject(codec_stream_name_for_test("/CCF"))),
      (decodeparms, PdfIndirect(20)),
    ]),
    StreamGot(encoded),
  )
  let decoded = doc.pdf_decode_stream(stream)
  guard decoded is PdfStreamObject(decoded_stream) else {
    fail("expected decoded stream")
  }
  @test.assert_eq(
    decoded_stream.data,
    StreamGot(codec_stream_bytes_for_test([0xF0])),
  )
  @test.assert_eq(decoded_stream.dictionary.lookup_immediate(filter), None)
  @test.assert_eq(decoded_stream.dictionary.lookup_immediate(decodeparms), None)
}

///|
test "PdfDocument pdf_decode_stream reports unsupported CCITT two dimensional K" {
  let length = codec_stream_name_for_test("/Length")
  let filter = codec_stream_name_for_test("/Filter")
  let decodeparms = codec_stream_name_for_test("/DecodeParms")
  let result : Result[@pdflite.PdfObject, Error] = try? @pdflite.pdf_decode_stream(
    @pdflite.pdf_stream(
      @pdflite.pdf_dictionary([
        (length, PdfInteger(1)),
        (filter, PdfNameObject(codec_stream_name_for_test("/CCITTFaxDecode"))),
        (
          decodeparms,
          @pdflite.pdf_dictionary([
            (codec_stream_name_for_test("/K"), PdfInteger(1)),
          ]),
        ),
      ]),
      StreamGot(codec_stream_bytes_for_test([0])),
    ),
  )
  guard result is Err(@pdflite.PdfError::CCITTNotSupported(_)) else {
    fail("expected unsupported CCITT K")
  }
}

///|
test "PdfDocument pdf_decode_stream_until_unknown no longer stops at CCITT" {
  let length = codec_stream_name_for_test("/Length")
  let filter = codec_stream_name_for_test("/Filter")
  let decodeparms = codec_stream_name_for_test("/DecodeParms")
  let encoded = codec_stream_bits_for_test([1, 0, 1, 1])
  let doc = @pdflite.pdf_document_empty()
  let decoded = doc.pdf_decode_stream_until_unknown(
    @pdflite.pdf_stream(
      @pdflite.pdf_dictionary([
        (length, PdfInteger(encoded.length())),
        (filter, PdfNameObject(codec_stream_name_for_test("/CCITTFaxDecode"))),
        (
          decodeparms,
          @pdflite.pdf_dictionary([
            (codec_stream_name_for_test("/Columns"), PdfInteger(4)),
            (codec_stream_name_for_test("/Rows"), PdfInteger(1)),
          ]),
        ),
      ]),
      StreamGot(encoded),
    ),
  )
  guard decoded is PdfStreamObject(decoded_stream) else {
    fail("expected decoded stream")
  }
  @test.assert_eq(
    decoded_stream.data,
    StreamGot(codec_stream_bytes_for_test([0xF0])),
  )
  @test.assert_eq(decoded_stream.dictionary.lookup_immediate(filter), None)
}

///|
test "PdfDocument pdf_decode_stream uses default lzw EarlyChange" {
  let length = codec_stream_name_for_test("/Length")
  let filter = codec_stream_name_for_test("/Filter")
  let doc = @pdflite.pdf_document_empty()
  let encoded = codec_stream_lzw_codes_for_test([256, 65, 257], 1)
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (length, PdfInteger(encoded.length())),
      (filter, PdfNameObject(codec_stream_name_for_test("/LZWDecode"))),
    ]),
    StreamGot(encoded),
  )
  let decoded = try! doc.pdf_decode_stream(stream)
  guard decoded is PdfStreamObject(decoded_stream) else {
    fail("expected decoded stream")
  }
  @test.assert_eq(
    decoded_stream.data,
    StreamGot(codec_stream_ascii_for_test("A")),
  )
}

///|
test "PdfDocument pdf_decode_stream handles empty filter arrays as raw" {
  let length = codec_stream_name_for_test("/Length")
  let filter = codec_stream_name_for_test("/Filter")
  let doc = @pdflite.pdf_document_empty()
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([(length, PdfInteger(2)), (filter, PdfArray([]))]),
    StreamGot(codec_stream_ascii_for_test("Hi")),
  )
  let decoded = try! doc.pdf_decode_stream(stream)
  guard decoded is PdfStreamObject(decoded_stream) else {
    fail("expected decoded stream")
  }
  @test.assert_eq(
    decoded_stream.data,
    StreamGot(codec_stream_ascii_for_test("Hi")),
  )
  @test.assert_eq(
    decoded_stream.dictionary.lookup_immediate(filter),
    Some(PdfArray([])),
  )
}

///|
test "PdfDocument pdf_decode_stream reports malformed document-aware metadata" {
  let length = codec_stream_name_for_test("/Length")
  let filter = codec_stream_name_for_test("/Filter")
  let decodeparms = codec_stream_name_for_test("/DecodeParms")
  let predictor = codec_stream_name_for_test("/Predictor")
  let doc = @pdflite.pdf_document_empty()
  let result : Result[@pdflite.PdfObject, Error] = try? doc.pdf_decode_stream(
    PdfNull,
  )
  guard result is Err(@pdflite.PdfError::ParseStreamExpected) else {
    fail("expected @pdflite.PdfError::ParseStreamExpected")
  }
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (filter, PdfNameObject(codec_stream_name_for_test("/AHx"))),
    ]),
    StreamGot(codec_stream_ascii_for_test("4869>")),
  )
  let result : Result[@pdflite.PdfObject, Error] = try? doc.pdf_decode_stream(
    stream,
  )
  guard result is Err(@pdflite.PdfError::StreamLengthExpected) else {
    fail("expected @pdflite.PdfError::StreamLengthExpected")
  }
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([(length, PdfInteger(2)), (filter, PdfInteger(1))]),
    StreamGot(codec_stream_ascii_for_test("Hi")),
  )
  let result : Result[@pdflite.PdfObject, Error] = try? doc.pdf_decode_stream(
    stream,
  )
  guard result is Err(@pdflite.PdfError::FilterExpected) else {
    fail("expected @pdflite.PdfError::FilterExpected")
  }
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (length, PdfInteger(2)),
      (filter, PdfArray([PdfInteger(1)])),
    ]),
    StreamGot(codec_stream_ascii_for_test("Hi")),
  )
  let result : Result[@pdflite.PdfObject, Error] = try? doc.pdf_decode_stream(
    stream,
  )
  guard result is Err(@pdflite.PdfError::FilterExpected) else {
    fail("expected @pdflite.PdfError::FilterExpected")
  }
  doc.add_object_given_number(
    9,
    @pdflite.pdf_dictionary([
      (predictor, PdfNameObject(codec_stream_name_for_test("/Bad"))),
    ]),
  )
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (length, PdfInteger(5)),
      (filter, PdfNameObject(codec_stream_name_for_test("/ASCIIHexDecode"))),
      (decodeparms, PdfIndirect(9)),
    ]),
    StreamGot(codec_stream_ascii_for_test("4869>")),
  )
  let result : Result[@pdflite.PdfObject, Error] = try? doc.pdf_decode_stream(
    stream,
  )
  guard result is Err(@pdflite.PdfError::PredictorExpected) else {
    fail("expected @pdflite.PdfError::PredictorExpected")
  }
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (length, PdfInteger(5)),
      (filter, PdfNameObject(codec_stream_name_for_test("/ASCIIHexDecode"))),
      (decodeparms, PdfArray([PdfInteger(1)])),
    ]),
    StreamGot(codec_stream_ascii_for_test("4869>")),
  )
  let result : Result[@pdflite.PdfObject, Error] = try? doc.pdf_decode_stream(
    stream,
  )
  guard result is Err(@pdflite.PdfError::PredictorExpected) else {
    fail("expected @pdflite.PdfError::PredictorExpected")
  }
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (length, PdfInteger(5)),
      (filter, PdfNameObject(codec_stream_name_for_test("/ASCIIHexDecode"))),
      (decodeparms, PdfInteger(1)),
    ]),
    StreamGot(codec_stream_ascii_for_test("4869>")),
  )
  let result : Result[@pdflite.PdfObject, Error] = try? doc.pdf_decode_stream(
    stream,
  )
  guard result is Err(@pdflite.PdfError::PredictorExpected) else {
    fail("expected @pdflite.PdfError::PredictorExpected")
  }
}

///|
test "PdfDocument pdf_decode_stream bounds excessive filter stages" {
  let length = codec_stream_name_for_test("/Length")
  let filter = codec_stream_name_for_test("/Filter")
  let doc = @pdflite.pdf_document_empty()
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (length, PdfInteger(1)),
      (
        filter,
        PdfArray(
          [
            for _ in 0..<1025 => {
              PdfNameObject(codec_stream_name_for_test("/Crypt"))
            }
          ],
        ),
      ),
    ]),
    StreamGot(codec_stream_ascii_for_test("x")),
  )
  let result : Result[@pdflite.PdfObject, Error] = try? doc.pdf_decode_stream(
    stream,
  )
  guard result is Err(@pdflite.PdfError::FilterExpected) else {
    fail("expected @pdflite.PdfError::FilterExpected")
  }
}

///|
test "PdfDocument pdf_decode_stream_until_unknown stops at unsupported filters" {
  let length = codec_stream_name_for_test("/Length")
  let filter = codec_stream_name_for_test("/Filter")
  let decodeparms = codec_stream_name_for_test("/DecodeParms")
  let predictor = codec_stream_name_for_test("/Predictor")
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(
    8,
    PdfNameObject(codec_stream_name_for_test("/AHx")),
  )
  doc.add_object_given_number(
    9,
    @pdflite.pdf_dictionary([(predictor, PdfInteger(1))]),
  )
  let encoded = @codec.pdf_ascii_hex_encode(codec_stream_ascii_for_test("Hi"))
  let unsupported : @pdflite.PdfObject = PdfNameObject(
    codec_stream_name_for_test("/NoSuchFilter"),
  )
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (length, PdfInteger(encoded.length())),
      (filter, PdfArray([PdfIndirect(8), unsupported])),
      (decodeparms, PdfArray([PdfIndirect(9), PdfNull])),
    ]),
    StreamGot(encoded),
  )
  let decoded = try! doc.pdf_decode_stream_until_unknown(stream)
  guard decoded is PdfStreamObject(decoded_stream) else {
    fail("expected decoded stream")
  }
  @test.assert_eq(
    decoded_stream.data,
    StreamGot(codec_stream_ascii_for_test("Hi")),
  )
  @test.assert_eq(
    decoded_stream.dictionary.lookup_immediate(length),
    Some(PdfInteger(2)),
  )
  @test.assert_eq(
    decoded_stream.dictionary.lookup_immediate(filter),
    Some(PdfArray([unsupported])),
  )
  @test.assert_eq(
    decoded_stream.dictionary.lookup_immediate(decodeparms),
    Some(PdfArray([PdfNull])),
  )
}

///|
test "PdfDocument pdf_decode_streams_until_unknown mutates document streams" {
  let length = codec_stream_name_for_test("/Length")
  let filter = codec_stream_name_for_test("/Filter")
  let decodeparms = codec_stream_name_for_test("/DecodeParms")
  let predictor = codec_stream_name_for_test("/Predictor")
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(
    8,
    PdfNameObject(codec_stream_name_for_test("/AHx")),
  )
  doc.add_object_given_number(
    9,
    @pdflite.pdf_dictionary([(predictor, PdfInteger(1))]),
  )
  let encoded = @codec.pdf_ascii_hex_encode(codec_stream_ascii_for_test("Hi"))
  let unsupported : @pdflite.PdfObject = PdfNameObject(
    codec_stream_name_for_test("/NoSuchFilter"),
  )
  let filtered = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (length, PdfInteger(encoded.length())),
      (filter, PdfArray([PdfIndirect(8), unsupported])),
      (decodeparms, PdfArray([PdfIndirect(9), PdfNull])),
    ]),
    StreamGot(encoded),
  )
  let raw = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([(length, PdfInteger(99))]),
    StreamGot(codec_stream_ascii_for_test("raw")),
  )
  doc.add_object_given_number(3, filtered, generation=2)
  doc.add_object_given_number(4, raw, generation=5)
  doc.add_object_given_number(5, PdfInteger(5))
  try! doc.pdf_decode_streams_until_unknown()
  guard doc.lookup_object_or_null(3) is PdfStreamObject(filtered_decoded) else {
    fail("expected filtered stream")
  }
  @test.assert_eq(
    filtered_decoded.data,
    StreamGot(codec_stream_ascii_for_test("Hi")),
  )
  @test.assert_eq(
    filtered_decoded.dictionary.lookup_immediate(length),
    Some(PdfInteger(2)),
  )
  @test.assert_eq(
    filtered_decoded.dictionary.lookup_immediate(filter),
    Some(PdfArray([unsupported])),
  )
  @test.assert_eq(
    filtered_decoded.dictionary.lookup_immediate(decodeparms),
    Some(PdfArray([PdfNull])),
  )
  guard doc.lookup_object_or_null(4) is PdfStreamObject(raw_decoded) else {
    fail("expected raw stream")
  }
  @test.assert_eq(
    raw_decoded.data,
    StreamGot(codec_stream_ascii_for_test("raw")),
  )
  @test.assert_eq(
    raw_decoded.dictionary.lookup_immediate(length),
    Some(PdfInteger(3)),
  )
  @test.assert_eq(doc.lookup_object_or_null(5), PdfInteger(5))
  @test.assert_eq(doc.stream_object_entries(), [
    (3, 2, filtered_decoded),
    (4, 5, raw_decoded),
  ])
}

///|
test "pdfdecomp-style stream decompression survives writer reader round trip" {
  let length = codec_stream_name_for_test("/Length")
  let filter = codec_stream_name_for_test("/Filter")
  let decodeparms = codec_stream_name_for_test("/DecodeParms")
  let type_name = codec_stream_name_for_test("/Type")
  let document = @pdflite.pdf_document_empty()
  document.set_version(1, 4)
  document.set_root(1)
  document.add_object_given_number(
    1,
    @pdflite.pdf_dictionary([
      (type_name, PdfNameObject(codec_stream_name_for_test("/Catalog"))),
    ]),
  )
  let encoded = @codec.pdf_ascii_hex_encode(codec_stream_ascii_for_test("Hi"))
  let unsupported : @pdflite.PdfObject = PdfNameObject(
    codec_stream_name_for_test("/NoSuchFilter"),
  )
  document.add_object_given_number(
    2,
    @pdflite.pdf_stream(
      @pdflite.pdf_dictionary([
        (length, PdfInteger(encoded.length())),
        (
          filter,
          PdfArray([
            PdfNameObject(codec_stream_name_for_test("/ASCIIHexDecode")),
            unsupported,
          ]),
        ),
        (decodeparms, PdfArray([PdfNull, PdfNull])),
      ]),
      StreamGot(encoded),
    ),
  )
  try! document.pdf_decode_streams_until_unknown()
  let written = try! @pdflite.pdf_write_document(document)
  let parsed = try! @pdflite.pdf_read_document_from_bytes(written)
  guard parsed.lookup_object_or_null(2) is PdfStreamObject(stream) else {
    fail("expected decompressed stream")
  }
  guard stream.data is StreamToGet(_) else {
    fail("expected deferred decompressed stream")
  }
  @test.assert_eq(
    try! @pdflite.pdf_stream(stream.dictionary, stream.data).stream_bytes(),
    codec_stream_ascii_for_test("Hi"),
  )
  @test.assert_eq(
    stream.dictionary.lookup_immediate(length),
    Some(PdfInteger(2)),
  )
  @test.assert_eq(
    stream.dictionary.lookup_immediate(filter),
    Some(PdfArray([unsupported])),
  )
  @test.assert_eq(
    stream.dictionary.lookup_immediate(decodeparms),
    Some(PdfArray([PdfNull])),
  )
}

///|
test "PdfDocument pdf_decode_stream_until_unknown handles raw and malformed inputs" {
  let length = codec_stream_name_for_test("/Length")
  let filter = codec_stream_name_for_test("/Filter")
  let doc = @pdflite.pdf_document_empty()
  let raw = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([(length, PdfInteger(2))]),
    StreamGot(codec_stream_ascii_for_test("Hi")),
  )
  let decoded = try! doc.pdf_decode_stream_until_unknown(raw)
  guard decoded is PdfStreamObject(decoded_stream) else {
    fail("expected decoded stream")
  }
  @test.assert_eq(
    decoded_stream.data,
    StreamGot(codec_stream_ascii_for_test("Hi")),
  )
  let unsupported : @pdflite.PdfObject = PdfNameObject(
    codec_stream_name_for_test("/NoSuchFilter"),
  )
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([(length, PdfInteger(2)), (filter, unsupported)]),
    StreamGot(codec_stream_ascii_for_test("Hi")),
  )
  let decoded = try! doc.pdf_decode_stream_until_unknown(stream)
  guard decoded is PdfStreamObject(decoded_stream) else {
    fail("expected decoded stream")
  }
  @test.assert_eq(
    decoded_stream.data,
    StreamGot(codec_stream_ascii_for_test("Hi")),
  )
  @test.assert_eq(
    decoded_stream.dictionary.lookup_immediate(filter),
    Some(unsupported),
  )
  let result : Result[@pdflite.PdfObject, Error] = try? doc.pdf_decode_stream_until_unknown(
    PdfNull,
  )
  guard result is Err(@pdflite.PdfError::ParseStreamExpected) else {
    fail("expected @pdflite.PdfError::ParseStreamExpected")
  }
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (length, PdfInteger(3)),
      (filter, PdfNameObject(codec_stream_name_for_test("/AHx"))),
    ]),
    StreamGot(codec_stream_ascii_for_test("6Z>")),
  )
  let result : Result[@pdflite.PdfObject, Error] = try? doc.pdf_decode_stream_until_unknown(
    stream,
  )
  guard result is Err(@pdflite.PdfError::InvalidHexEscape) else {
    fail("expected @pdflite.PdfError::InvalidHexEscape")
  }
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (length, PdfInteger(1)),
      (
        filter,
        PdfArray(
          [
            for _ in 0..<1025 => {
              PdfNameObject(codec_stream_name_for_test("/Crypt"))
            }
          ],
        ),
      ),
    ]),
    StreamGot(codec_stream_ascii_for_test("x")),
  )
  let result : Result[@pdflite.PdfObject, Error] = try? doc.pdf_decode_stream_until_unknown(
    stream,
  )
  guard result is Err(@pdflite.PdfError::FilterExpected) else {
    fail("expected @pdflite.PdfError::FilterExpected")
  }
}

///|
test "pdf_decode_stream_onestage accepts DecodeParms arrays" {
  let length = codec_stream_name_for_test("/Length")
  let filter = codec_stream_name_for_test("/Filter")
  let decodeparms = codec_stream_name_for_test("/DecodeParms")
  let predictor = codec_stream_name_for_test("/Predictor")
  let encoded = @codec.pdf_ascii_hex_encode(codec_stream_ascii_for_test("Hi"))
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (length, PdfInteger(encoded.length())),
      (filter, PdfNameObject(codec_stream_name_for_test("/ASCIIHexDecode"))),
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
  @test.assert_eq(
    decoded_stream.data,
    StreamGot(codec_stream_ascii_for_test("Hi")),
  )
  @test.assert_eq(
    decoded_stream.dictionary.lookup_immediate(decodeparms),
    Some(PdfArray([])),
  )
}

///|
test "pdf_decode_stream_onestage applies lzw EarlyChange DecodeParms" {
  let length = codec_stream_name_for_test("/Length")
  let filter = codec_stream_name_for_test("/Filter")
  let decodeparms = codec_stream_name_for_test("/DecodeParms")
  let early_change = codec_stream_name_for_test("/EarlyChange")
  let codes : Array[Int] = [256]
  for _ in 0..<255 {
    codes.push(65)
  }
  codes.push(257)
  let encoded = codec_stream_lzw_codes_for_test(codes, 0)
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (length, PdfInteger(encoded.length())),
      (filter, PdfNameObject(codec_stream_name_for_test("/LZWDecode"))),
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
    StreamGot(codec_stream_bytes_for_test([ for _ in 0..<255 => 65 ])),
  )
  @test.assert_eq(decoded_stream.dictionary.lookup_immediate(filter), None)
  @test.assert_eq(decoded_stream.dictionary.lookup_immediate(decodeparms), None)
}

///|
test "pdf_decode_stream_onestage handles short filters and null decodeparms" {
  let length = codec_stream_name_for_test("/Length")
  let short_filter = codec_stream_name_for_test("/F")
  let short_decodeparms = codec_stream_name_for_test("/DP")
  let predictor = codec_stream_name_for_test("/Predictor")
  let encoded = @codec.pdf_ascii_hex_encode(codec_stream_ascii_for_test("Hi"))
  let retained_decodeparms = @pdflite.pdf_dictionary([
    (predictor, PdfInteger(1)),
  ])
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (length, PdfInteger(encoded.length())),
      (short_filter, PdfNameObject(codec_stream_name_for_test("/AHx"))),
      (short_decodeparms, PdfArray([PdfNull, retained_decodeparms])),
    ]),
    StreamGot(encoded),
  )
  let decoded = try! @pdflite.pdf_decode_stream_onestage(stream)
  guard decoded is PdfStreamObject(decoded_stream) else {
    fail("expected decoded stream")
  }
  @test.assert_eq(
    decoded_stream.data,
    StreamGot(codec_stream_ascii_for_test("Hi")),
  )
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
  let length = codec_stream_name_for_test("/Length")
  let filter = codec_stream_name_for_test("/Filter")
  let encoded_once = @codec.pdf_ascii_hex_encode(
    codec_stream_ascii_for_test("9jqo~>"),
  )
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (length, PdfInteger(encoded_once.length())),
      (
        filter,
        PdfArray([
          PdfNameObject(codec_stream_name_for_test("/AHx")),
          PdfNameObject(codec_stream_name_for_test("/A85")),
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
    StreamGot(codec_stream_ascii_for_test("9jqo~>")),
  )
  @test.assert_eq(
    decoded_stream.dictionary.lookup_immediate(filter),
    Some(PdfArray([PdfNameObject(codec_stream_name_for_test("/A85"))])),
  )
}

///|
test "pdf_decode_stream_onestage treats empty filter arrays as raw" {
  let length = codec_stream_name_for_test("/Length")
  let filter = codec_stream_name_for_test("/Filter")
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([(length, PdfInteger(2)), (filter, PdfArray([]))]),
    StreamGot(codec_stream_ascii_for_test("Hi")),
  )
  let decoded = try! @pdflite.pdf_decode_stream_onestage(stream)
  guard decoded is PdfStreamObject(decoded_stream) else {
    fail("expected decoded stream")
  }
  @test.assert_eq(
    decoded_stream.data,
    StreamGot(codec_stream_ascii_for_test("Hi")),
  )
  @test.assert_eq(
    decoded_stream.dictionary.lookup_immediate(filter),
    Some(PdfArray([])),
  )
}

///|
test "pdf_decode_stream_onestage uses default lzw EarlyChange" {
  let length = codec_stream_name_for_test("/Length")
  let filter = codec_stream_name_for_test("/Filter")
  let encoded = codec_stream_lzw_codes_for_test([256, 65, 257], 1)
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (length, PdfInteger(encoded.length())),
      (filter, PdfNameObject(codec_stream_name_for_test("/LZWDecode"))),
    ]),
    StreamGot(encoded),
  )
  let decoded = try! @pdflite.pdf_decode_stream_onestage(stream)
  guard decoded is PdfStreamObject(decoded_stream) else {
    fail("expected decoded stream")
  }
  @test.assert_eq(
    decoded_stream.data,
    StreamGot(codec_stream_ascii_for_test("A")),
  )
}

///|
test "pdf_decode_stream decodes all supported filter stages" {
  let length = codec_stream_name_for_test("/Length")
  let filter = codec_stream_name_for_test("/Filter")
  let ascii85 = @codec.pdf_ascii85_encode(
    codec_stream_bytes_for_test([77, 97, 110]),
  )
  let encoded = @codec.pdf_ascii_hex_encode(ascii85)
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (length, PdfInteger(encoded.length())),
      (
        filter,
        PdfArray([
          PdfNameObject(codec_stream_name_for_test("/AHx")),
          PdfNameObject(codec_stream_name_for_test("/A85")),
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
    StreamGot(codec_stream_bytes_for_test([77, 97, 110])),
  )
  @test.assert_eq(
    decoded_stream.dictionary.lookup_immediate(length),
    Some(PdfInteger(3)),
  )
  @test.assert_eq(decoded_stream.dictionary.lookup_immediate(filter), None)
}

///|
test "pdf_decode_stream bounds excessive filter stages" {
  let length = codec_stream_name_for_test("/Length")
  let filter = codec_stream_name_for_test("/Filter")
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (length, PdfInteger(1)),
      (
        filter,
        PdfArray(
          [
            for _ in 0..<1025 => {
              PdfNameObject(codec_stream_name_for_test("/Crypt"))
            }
          ],
        ),
      ),
    ]),
    StreamGot(codec_stream_ascii_for_test("x")),
  )
  let result : Result[@pdflite.PdfObject, Error] = try? @pdflite.pdf_decode_stream(
    stream,
  )
  guard result is Err(@pdflite.PdfError::FilterExpected) else {
    fail("expected @pdflite.PdfError::FilterExpected")
  }
}

///|
test "pdf_decode_stream_onestage reports malformed stream filters and materializes deferred data" {
  let length = codec_stream_name_for_test("/Length")
  let filter = codec_stream_name_for_test("/Filter")
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([(length, PdfInteger(2)), (filter, PdfInteger(1))]),
    StreamGot(codec_stream_ascii_for_test("Hi")),
  )
  let result : Result[@pdflite.PdfObject, Error] = try? @pdflite.pdf_decode_stream_onestage(
    stream,
  )
  guard result is Err(@pdflite.PdfError::FilterExpected) else {
    fail("expected @pdflite.PdfError::FilterExpected")
  }
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([]),
    StreamGot(codec_stream_ascii_for_test("Hi")),
  )
  let result : Result[@pdflite.PdfObject, Error] = try? @pdflite.pdf_decode_stream_onestage(
    stream,
  )
  guard result is Err(@pdflite.PdfError::StreamLengthExpected) else {
    fail("expected @pdflite.PdfError::StreamLengthExpected")
  }
  let result : Result[@pdflite.PdfObject, Error] = try? @pdflite.pdf_decode_stream_onestage(
    PdfNull,
  )
  guard result is Err(@pdflite.PdfError::ParseStreamExpected) else {
    fail("expected @pdflite.PdfError::ParseStreamExpected")
  }
  let result : Result[@pdflite.PdfObject, Error] = try? @pdflite.pdf_decode_stream(
    PdfNull,
  )
  guard result is Err(@pdflite.PdfError::ParseStreamExpected) else {
    fail("expected @pdflite.PdfError::ParseStreamExpected")
  }
  let deferred = @pdflite.stream_to_get(
    @pdflite.byte_cursor_of_bytes(codec_stream_ascii_for_test("Hi")),
    0,
    2,
  )
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([(length, PdfInteger(2))]),
    StreamToGet(deferred),
  )
  let decoded_deferred = try! @pdflite.pdf_decode_stream_onestage(stream)
  guard decoded_deferred is PdfStreamObject(decoded_stream) else {
    fail("expected PdfStreamObject")
  }
  @test.assert_eq(
    decoded_stream.data,
    StreamGot(codec_stream_ascii_for_test("Hi")),
  )
  @test.assert_eq(
    decoded_stream.dictionary.lookup_immediate(length),
    Some(PdfInteger(2)),
  )
  let decodeparms = codec_stream_name_for_test("/DecodeParms")
  let predictor = codec_stream_name_for_test("/Predictor")
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (length, PdfInteger(5)),
      (filter, PdfNameObject(codec_stream_name_for_test("/ASCIIHexDecode"))),
      (
        decodeparms,
        @pdflite.pdf_dictionary([
          (predictor, PdfNameObject(codec_stream_name_for_test("/Bad"))),
        ]),
      ),
    ]),
    StreamGot(codec_stream_ascii_for_test("4869>")),
  )
  let result : Result[@pdflite.PdfObject, Error] = try? @pdflite.pdf_decode_stream_onestage(
    stream,
  )
  guard result is Err(@pdflite.PdfError::PredictorExpected) else {
    fail("expected @pdflite.PdfError::PredictorExpected")
  }
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (length, PdfInteger(5)),
      (filter, PdfNameObject(codec_stream_name_for_test("/ASCIIHexDecode"))),
      (decodeparms, PdfInteger(1)),
    ]),
    StreamGot(codec_stream_ascii_for_test("4869>")),
  )
  let result : Result[@pdflite.PdfObject, Error] = try? @pdflite.pdf_decode_stream_onestage(
    stream,
  )
  guard result is Err(@pdflite.PdfError::PredictorExpected) else {
    fail("expected @pdflite.PdfError::PredictorExpected")
  }
}
