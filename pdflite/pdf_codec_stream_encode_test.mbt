///|
fn codec_stream_encode_bytes_for_test(
  values : ArrayView[Int],
) -> @core.PdfBytes {
  try! @core.pdf_bytes_of_int_array(values)
}

///|
fn codec_stream_encode_ascii_for_test(text : String) -> @core.PdfBytes {
  @ascii.encode(text)
}

///|
fn codec_stream_encode_name_for_test(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
test "pdf_encode_stream_with_filter adds filter and updates length" {
  let length = codec_stream_encode_name_for_test("/Length")
  let filter = codec_stream_encode_name_for_test("/Filter")
  let stream = @syntax.pdf_stream(
    @syntax.pdf_dictionary([(length, PdfInteger(2))]),
    StreamGot(codec_stream_encode_ascii_for_test("Hi")),
  )
  let encoded = try! @pdflite.pdf_encode_stream_with_filter(
    codec_stream_encode_name_for_test("/ASCIIHexDecode"),
    stream,
  )
  guard encoded is PdfStreamObject(encoded_stream) else {
    fail("expected encoded stream")
  }
  @test.assert_eq(
    encoded_stream.data,
    StreamGot(codec_stream_encode_ascii_for_test("4869>")),
  )
  @test.assert_eq(
    encoded_stream.dictionary.lookup_immediate(length),
    Some(PdfInteger(5)),
  )
  @test.assert_eq(
    encoded_stream.dictionary.lookup_immediate(filter),
    Some(PdfNameObject(codec_stream_encode_name_for_test("/ASCIIHexDecode"))),
  )
}

///|
test "PdfStreamEncoding maps CamlPDF encoding and predictor choices" {
  @test.assert_eq(
    @pdflite.PdfStreamASCIIHex.filter_name(),
    codec_stream_encode_name_for_test("/ASCIIHexDecode"),
  )
  @test.assert_eq(
    @pdflite.PdfStreamASCII85.filter_name(),
    codec_stream_encode_name_for_test("/ASCII85Decode"),
  )
  @test.assert_eq(
    @pdflite.PdfStreamRunLength.filter_name(),
    codec_stream_encode_name_for_test("/RunLengthDecode"),
  )
  @test.assert_eq(
    @pdflite.PdfStreamFlate.filter_name(),
    codec_stream_encode_name_for_test("/FlateDecode"),
  )
  @test.assert_eq(@pdflite.PdfStreamPredictorTIFF2.number(), 2)
  @test.assert_eq(@pdflite.PdfStreamPredictorPNGNone.number(), 10)
  @test.assert_eq(@pdflite.PdfStreamPredictorPNGSub.number(), 11)
  @test.assert_eq(@pdflite.PdfStreamPredictorPNGUp.number(), 12)
  @test.assert_eq(@pdflite.PdfStreamPredictorPNGAverage.number(), 13)
  @test.assert_eq(@pdflite.PdfStreamPredictorPNGPaeth.number(), 14)
  @test.assert_eq(@pdflite.PdfStreamPredictorPNGOptimum.number(), 15)
  @test.assert_eq(
    @pdflite.PdfStreamCCITT(8, 9).filter_name(),
    codec_stream_encode_name_for_test("/CCITTFaxDecode"),
  )
  @test.assert_eq(
    @pdflite.PdfStreamCCITTG4(8, 9).filter_name(),
    codec_stream_encode_name_for_test("/CCITTFaxDecode"),
  )
}

///|
test "pdf_encode_stream_with_encoding wraps filter and predictor APIs" {
  let length = codec_stream_encode_name_for_test("/Length")
  let filter = codec_stream_encode_name_for_test("/Filter")
  let decodeparms = codec_stream_encode_name_for_test("/DecodeParms")
  let stream = @syntax.pdf_stream(
    @syntax.pdf_dictionary([(length, PdfInteger(2))]),
    StreamGot(codec_stream_encode_ascii_for_test("Hi")),
  )
  let encoded = try! @pdflite.pdf_encode_stream_with_encoding(
    PdfStreamASCIIHex,
    stream,
  )
  guard encoded is PdfStreamObject(encoded_stream) else {
    fail("expected encoded stream")
  }
  @test.assert_eq(
    encoded_stream.data,
    StreamGot(codec_stream_encode_ascii_for_test("4869>")),
  )
  @test.assert_eq(
    encoded_stream.dictionary.lookup_immediate(filter),
    Some(PdfNameObject(codec_stream_encode_name_for_test("/ASCIIHexDecode"))),
  )

  let predictor_stream = @syntax.pdf_stream(
    @syntax.pdf_dictionary([(length, PdfInteger(6))]),
    StreamGot(codec_stream_encode_bytes_for_test([10, 20, 30, 11, 25, 35])),
  )
  let predicted = try! @pdflite.pdf_encode_stream_with_encoding(
    PdfStreamASCIIHex,
    predictor_stream,
    predictor=Some(PdfStreamPredictorPNGUp),
    predictor_columns=3,
  )
  guard predicted is PdfStreamObject(predicted_stream) else {
    fail("expected predicted stream")
  }
  @test.assert_eq(
    predicted_stream.data,
    StreamGot(codec_stream_encode_ascii_for_test("020A141E02010505>")),
  )
  guard predicted_stream.dictionary.lookup_immediate(decodeparms)
    is Some(PdfDictionary(_)) else {
    fail("expected typed DecodeParms dictionary")
  }
  let decoded = try! @pdflite.pdf_decode_stream(predicted)
  guard decoded is PdfStreamObject(decoded_stream) else {
    fail("expected decoded stream")
  }
  @test.assert_eq(
    decoded_stream.data,
    StreamGot(codec_stream_encode_bytes_for_test([10, 20, 30, 11, 25, 35])),
  )
  @test.assert_eq(decoded_stream.dictionary.lookup_immediate(filter), None)
  @test.assert_eq(decoded_stream.dictionary.lookup_immediate(decodeparms), None)

  let skipped = try! @pdflite.pdf_encode_stream_with_encoding(
    PdfStreamASCIIHex,
    stream,
    only_if_smaller=true,
  )
  guard skipped is PdfStreamObject(skipped_stream) else {
    fail("expected skipped stream")
  }
  @test.assert_eq(
    skipped_stream.data,
    StreamGot(codec_stream_encode_ascii_for_test("Hi")),
  )
  @test.assert_eq(skipped_stream.dictionary.lookup_immediate(filter), None)

  let ccitt_stream = @syntax.pdf_stream(
    @syntax.pdf_dictionary([(length, PdfInteger(2))]),
    StreamGot(codec_stream_encode_bytes_for_test([0xF0, 0x00])),
  )
  let ccitt = try! @pdflite.pdf_encode_stream_with_encoding(
    PdfStreamCCITT(8, 2),
    ccitt_stream,
  )
  guard ccitt is PdfStreamObject(ccitt_encoded) else {
    fail("expected CCITT encoded stream")
  }
  @test.assert_eq(
    ccitt_encoded.data,
    StreamGot(
      codec_stream_encode_bytes_for_test([0xB6, 0x6A, 0x28, 0x00, 0x80, 0x08]),
    ),
  )
  @test.assert_eq(
    ccitt_encoded.dictionary.lookup_immediate(filter),
    Some(PdfNameObject(codec_stream_encode_name_for_test("/CCITTFaxDecode"))),
  )
  guard ccitt_encoded.dictionary.lookup_immediate(decodeparms)
    is Some(PdfDictionary(_)) else {
    fail("expected CCITT DecodeParms dictionary")
  }
  let ccitt_decoded = try! @pdflite.pdf_decode_stream(ccitt)
  guard ccitt_decoded is PdfStreamObject(ccitt_decoded_stream) else {
    fail("expected CCITT decoded stream")
  }
  @test.assert_eq(
    ccitt_decoded_stream.data,
    StreamGot(codec_stream_encode_bytes_for_test([0xF0, 0x00])),
  )

  let skipped_ccitt = try! @pdflite.pdf_encode_stream_with_encoding(
    PdfStreamCCITT(8, 2),
    ccitt_stream,
    only_if_smaller=true,
  )
  guard skipped_ccitt is PdfStreamObject(skipped_ccitt_stream) else {
    fail("expected skipped CCITT stream")
  }
  @test.assert_eq(
    skipped_ccitt_stream.data,
    StreamGot(codec_stream_encode_bytes_for_test([0xF0, 0x00])),
  )
  @test.assert_eq(
    skipped_ccitt_stream.dictionary.lookup_immediate(filter),
    None,
  )

  let ccitt_bad_predictor : Result[@syntax.PdfObject, Error] = try
    @pdflite.pdf_encode_stream_with_encoding(
      PdfStreamCCITT(8, 2),
      ccitt_stream,
      predictor=Some(PdfStreamPredictorPNGUp),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard ccitt_bad_predictor is Err(_) else {
    fail("expected CCITT predictor encoding to raise")
  }

  let ccitt_bad_object : Result[@syntax.PdfObject, Error] = try
    @pdflite.pdf_encode_stream_with_encoding(
      PdfStreamCCITT(8, 2),
      PdfInteger(0),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard ccitt_bad_object is Err(_) else {
    fail("expected CCITT encoding of a non-stream to raise")
  }

  let ccitt_g4_stream = @syntax.pdf_stream(
    @syntax.pdf_dictionary([(length, PdfInteger(3))]),
    StreamGot(codec_stream_encode_bytes_for_test([0xC0, 0xB0, 0x80])),
  )
  let ccitt_g4 = try! @pdflite.pdf_encode_stream_with_encoding(
    PdfStreamCCITTG4(4, 3),
    ccitt_g4_stream,
  )
  guard ccitt_g4 is PdfStreamObject(ccitt_g4_encoded) else {
    fail("expected CCITT G4 encoded stream")
  }
  @test.assert_eq(
    ccitt_g4_encoded.dictionary.lookup_immediate(filter),
    Some(PdfNameObject(codec_stream_encode_name_for_test("/CCITTFaxDecode"))),
  )
  guard ccitt_g4_encoded.dictionary.lookup_immediate(decodeparms)
    is Some(PdfDictionary(g4_decodeparms)) else {
    fail("expected CCITT G4 DecodeParms dictionary")
  }
  @test.assert_eq(g4_decodeparms, [
    (codec_stream_encode_name_for_test("/K"), PdfInteger(-1)),
    (codec_stream_encode_name_for_test("/Columns"), PdfInteger(4)),
    (codec_stream_encode_name_for_test("/Rows"), PdfInteger(3)),
  ])
  let ccitt_g4_decoded = try! @pdflite.pdf_decode_stream(ccitt_g4)
  guard ccitt_g4_decoded is PdfStreamObject(ccitt_g4_decoded_stream) else {
    fail("expected CCITT G4 decoded stream")
  }
  @test.assert_eq(
    ccitt_g4_decoded_stream.data,
    StreamGot(codec_stream_encode_bytes_for_test([0xC0, 0xB0, 0x80])),
  )

  let skipped_g4 = try! @pdflite.pdf_encode_stream_with_encoding(
    PdfStreamCCITTG4(4, 3),
    ccitt_g4_stream,
    only_if_smaller=true,
  )
  guard skipped_g4 is PdfStreamObject(skipped_g4_stream) else {
    fail("expected skipped CCITT G4 stream")
  }
  @test.assert_eq(
    skipped_g4_stream.data,
    StreamGot(codec_stream_encode_bytes_for_test([0xC0, 0xB0, 0x80])),
  )
  @test.assert_eq(skipped_g4_stream.dictionary.lookup_immediate(filter), None)

  let ccitt_g4_bad_predictor : Result[@syntax.PdfObject, Error] = try
    @pdflite.pdf_encode_stream_with_encoding(
      PdfStreamCCITTG4(4, 3),
      ccitt_g4_stream,
      predictor=Some(PdfStreamPredictorPNGUp),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard ccitt_g4_bad_predictor is Err(_) else {
    fail("expected CCITT G4 predictor encoding to raise")
  }
}

///|
test "pdf_encode_stream_with_filter prepends existing filters" {
  let length = codec_stream_encode_name_for_test("/Length")
  let filter = codec_stream_encode_name_for_test("/Filter")
  let ascii_hex = codec_stream_encode_name_for_test("/ASCIIHexDecode")
  let run_length = codec_stream_encode_name_for_test("/RunLengthDecode")
  let ascii85 = codec_stream_encode_name_for_test("/ASCII85Decode")
  let stream = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (length, PdfInteger(2)),
      (filter, PdfNameObject(run_length)),
    ]),
    StreamGot(codec_stream_encode_ascii_for_test("Hi")),
  )
  let encoded = try! @pdflite.pdf_encode_stream_with_filter(ascii_hex, stream)
  guard encoded is PdfStreamObject(encoded_stream) else {
    fail("expected encoded stream")
  }
  @test.assert_eq(
    encoded_stream.dictionary.lookup_immediate(filter),
    Some(PdfArray([PdfNameObject(ascii_hex), PdfNameObject(run_length)])),
  )
  let stream = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (length, PdfInteger(2)),
      (filter, PdfArray([PdfNameObject(ascii85)])),
    ]),
    StreamGot(codec_stream_encode_ascii_for_test("Hi")),
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
test "pdf_encode_stream_with_filter can skip non-smaller encodings" {
  let length = codec_stream_encode_name_for_test("/Length")
  let filter = codec_stream_encode_name_for_test("/Filter")
  let stream = @syntax.pdf_stream(
    @syntax.pdf_dictionary([(length, PdfInteger(2))]),
    StreamGot(codec_stream_encode_ascii_for_test("Hi")),
  )
  let skipped = try! @pdflite.pdf_encode_stream_with_filter(
    codec_stream_encode_name_for_test("/ASCIIHexDecode"),
    stream,
    only_if_smaller=true,
  )
  guard skipped is PdfStreamObject(skipped_stream) else {
    fail("expected skipped stream")
  }
  @test.assert_eq(
    skipped_stream.data,
    StreamGot(codec_stream_encode_ascii_for_test("Hi")),
  )
  @test.assert_eq(skipped_stream.dictionary.lookup_immediate(filter), None)
  @test.assert_eq(
    skipped_stream.dictionary.lookup_immediate(length),
    Some(PdfInteger(2)),
  )
  let repeated = codec_stream_encode_bytes_for_test([ for _ in 0..<30 => 65 ])
  let stream = @syntax.pdf_stream(
    @syntax.pdf_dictionary([(length, PdfInteger(repeated.length()))]),
    StreamGot(repeated),
  )
  let encoded = try! @pdflite.pdf_encode_stream_with_filter(
    codec_stream_encode_name_for_test("/RunLengthDecode"),
    stream,
    only_if_smaller=true,
  )
  guard encoded is PdfStreamObject(encoded_stream) else {
    fail("expected encoded stream")
  }
  @test.assert_eq(
    encoded_stream.data,
    StreamGot(@codec.pdf_run_length_encode(repeated)),
  )
  @test.assert_eq(
    encoded_stream.dictionary.lookup_immediate(filter),
    Some(PdfNameObject(codec_stream_encode_name_for_test("/RunLengthDecode"))),
  )
}

///|
test "pdf_encode_stream_with_filter_and_predictor round trips through decode stream" {
  let length = codec_stream_encode_name_for_test("/Length")
  let filter = codec_stream_encode_name_for_test("/Filter")
  let decodeparms = codec_stream_encode_name_for_test("/DecodeParms")
  let stream = @syntax.pdf_stream(
    @syntax.pdf_dictionary([(length, PdfInteger(6))]),
    StreamGot(codec_stream_encode_bytes_for_test([10, 20, 30, 11, 25, 35])),
  )
  let encoded = try! @pdflite.pdf_encode_stream_with_filter_and_predictor(
    codec_stream_encode_name_for_test("/ASCIIHexDecode"),
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
    StreamGot(codec_stream_encode_ascii_for_test("020A141E02010505>")),
  )
  @test.assert_eq(
    encoded_stream.dictionary.lookup_immediate(filter),
    Some(PdfNameObject(codec_stream_encode_name_for_test("/ASCIIHexDecode"))),
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
    StreamGot(codec_stream_encode_bytes_for_test([10, 20, 30, 11, 25, 35])),
  )
  @test.assert_eq(decoded_stream.dictionary.lookup_immediate(filter), None)
  @test.assert_eq(decoded_stream.dictionary.lookup_immediate(decodeparms), None)
}

///|
test "pdf_encode_stream_with_filter_and_predictor round trips tiff predictor" {
  let length = codec_stream_encode_name_for_test("/Length")
  let filter = codec_stream_encode_name_for_test("/Filter")
  let predictor = codec_stream_encode_name_for_test("/Predictor")
  let stream = @syntax.pdf_stream(
    @syntax.pdf_dictionary([(length, PdfInteger(6))]),
    StreamGot(codec_stream_encode_bytes_for_test([10, 20, 30, 13, 25, 35])),
  )
  let encoded = try! @pdflite.pdf_encode_stream_with_filter_and_predictor(
    codec_stream_encode_name_for_test("/ASCIIHexDecode"),
    2,
    3,
    8,
    2,
    stream,
  )
  guard encoded is PdfStreamObject(encoded_stream) else {
    fail("expected encoded stream")
  }
  @test.assert_eq(
    encoded_stream.data,
    StreamGot(codec_stream_encode_ascii_for_test("0A141E030505>")),
  )
  guard encoded_stream.dictionary.lookup_immediate(
      codec_stream_encode_name_for_test("/DecodeParms"),
    )
    is Some(PdfDictionary(_) as decodeparms_object) else {
    fail("expected DecodeParms dictionary")
  }
  @test.assert_eq(
    decodeparms_object.lookup_immediate(predictor),
    Some(PdfInteger(2)),
  )
  let decoded = try! @pdflite.pdf_decode_stream(encoded)
  guard decoded is PdfStreamObject(decoded_stream) else {
    fail("expected decoded stream")
  }
  @test.assert_eq(
    decoded_stream.data,
    StreamGot(codec_stream_encode_bytes_for_test([10, 20, 30, 13, 25, 35])),
  )
  @test.assert_eq(decoded_stream.dictionary.lookup_immediate(filter), None)
}

///|
test "pdf_encode_stream_with_filter_and_predictor can skip non-smaller encodings" {
  let length = codec_stream_encode_name_for_test("/Length")
  let filter = codec_stream_encode_name_for_test("/Filter")
  let decodeparms = codec_stream_encode_name_for_test("/DecodeParms")
  let stream = @syntax.pdf_stream(
    @syntax.pdf_dictionary([(length, PdfInteger(3))]),
    StreamGot(codec_stream_encode_ascii_for_test("abc")),
  )
  let skipped = try! @pdflite.pdf_encode_stream_with_filter_and_predictor(
    codec_stream_encode_name_for_test("/ASCIIHexDecode"),
    11,
    1,
    8,
    3,
    stream,
    only_if_smaller=true,
  )
  guard skipped is PdfStreamObject(skipped_stream) else {
    fail("expected skipped stream")
  }
  @test.assert_eq(
    skipped_stream.data,
    StreamGot(codec_stream_encode_ascii_for_test("abc")),
  )
  @test.assert_eq(skipped_stream.dictionary.lookup_immediate(filter), None)
  @test.assert_eq(skipped_stream.dictionary.lookup_immediate(decodeparms), None)
}

///|
test "pdf_encode_stream_with_filter_and_predictor prepends decodeparms" {
  let length = codec_stream_encode_name_for_test("/Length")
  let decodeparms = codec_stream_encode_name_for_test("/DecodeParms")
  let predictor = codec_stream_encode_name_for_test("/Predictor")
  let existing = @syntax.pdf_dictionary([(predictor, PdfInteger(1))])
  let stream = @syntax.pdf_stream(
    @syntax.pdf_dictionary([(length, PdfInteger(3)), (decodeparms, existing)]),
    StreamGot(codec_stream_encode_ascii_for_test("abc")),
  )
  let encoded = try! @pdflite.pdf_encode_stream_with_filter_and_predictor(
    codec_stream_encode_name_for_test("/ASCIIHexDecode"),
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
  let stream = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (length, PdfInteger(3)),
      (decodeparms, PdfArray([existing])),
    ]),
    StreamGot(codec_stream_encode_ascii_for_test("abc")),
  )
  let encoded = try! @pdflite.pdf_encode_stream_with_filter_and_predictor(
    codec_stream_encode_name_for_test("/ASCIIHexDecode"),
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
test "pdf stream encoding reports malformed objects and materializes deferred data" {
  let length = codec_stream_encode_name_for_test("/Length")
  let filter = codec_stream_encode_name_for_test("/Filter")
  let result : Result[@syntax.PdfObject, Error] = try
    @pdflite.pdf_encode_stream_with_filter(
      codec_stream_encode_name_for_test("/ASCIIHexDecode"),
      PdfNull,
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard result is Err(@core.PdfError::ParseStreamExpected) else {
    fail("expected @core.PdfError::ParseStreamExpected")
  }
  let deferred = @syntax.stream_to_get(
    @core.byte_cursor_of_bytes(codec_stream_encode_ascii_for_test("Hi")),
    0,
    2,
  )
  let stream = @syntax.pdf_stream(
    @syntax.pdf_dictionary([(length, PdfInteger(2))]),
    StreamToGet(deferred),
  )
  let encoded_deferred = try! @pdflite.pdf_encode_stream_with_filter(
    codec_stream_encode_name_for_test("/ASCIIHexDecode"),
    stream,
  )
  let decoded_deferred = try! @pdflite.pdf_decode_stream(encoded_deferred)
  guard decoded_deferred is PdfStreamObject(decoded_stream) else {
    fail("expected PdfStreamObject")
  }
  @test.assert_eq(
    decoded_stream.data,
    StreamGot(codec_stream_encode_ascii_for_test("Hi")),
  )
  let stream = @syntax.pdf_stream(
    @syntax.pdf_dictionary([(length, PdfInteger(2)), (filter, PdfInteger(1))]),
    StreamGot(codec_stream_encode_ascii_for_test("Hi")),
  )
  let result : Result[@syntax.PdfObject, Error] = try
    @pdflite.pdf_encode_stream_with_filter(
      codec_stream_encode_name_for_test("/ASCIIHexDecode"),
      stream,
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard result is Err(@core.PdfError::FilterExpected) else {
    fail("expected @core.PdfError::FilterExpected")
  }
  let decodeparms = codec_stream_encode_name_for_test("/DecodeParms")
  let stream = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (length, PdfInteger(2)),
      (decodeparms, PdfInteger(1)),
    ]),
    StreamGot(codec_stream_encode_ascii_for_test("Hi")),
  )
  let result : Result[@syntax.PdfObject, Error] = try
    @pdflite.pdf_encode_stream_with_filter_and_predictor(
      codec_stream_encode_name_for_test("/ASCIIHexDecode"),
      11,
      1,
      8,
      2,
      stream,
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard result is Err(@core.PdfError::PredictorExpected) else {
    fail("expected @core.PdfError::PredictorExpected")
  }
  let result : Result[@syntax.PdfObject, Error] = try
    @pdflite.pdf_encode_stream_with_filter_and_predictor(
      codec_stream_encode_name_for_test("/ASCIIHexDecode"),
      11,
      1,
      8,
      2,
      PdfNull,
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard result is Err(@core.PdfError::ParseStreamExpected) else {
    fail("expected @core.PdfError::ParseStreamExpected")
  }
  let stream = @syntax.pdf_stream(
    @syntax.pdf_dictionary([(length, PdfInteger(2))]),
    StreamToGet(deferred),
  )
  let encoded_deferred = try! @pdflite.pdf_encode_stream_with_filter_and_predictor(
    codec_stream_encode_name_for_test("/ASCIIHexDecode"),
    11,
    1,
    8,
    2,
    stream,
  )
  let decoded_deferred = try! @pdflite.pdf_decode_stream(encoded_deferred)
  guard decoded_deferred is PdfStreamObject(decoded_stream) else {
    fail("expected PdfStreamObject")
  }
  @test.assert_eq(
    decoded_stream.data,
    StreamGot(codec_stream_encode_ascii_for_test("Hi")),
  )
}
