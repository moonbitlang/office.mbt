///|
fn squeeze_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn squeeze_data_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  for _ in 0..<128 {
    for byte in @ascii.encode("stream data repeats well\n")[:] {
      output.push(byte)
    }
  }
  Bytes::from_array(output)
}

///|
fn squeeze_stream_for_test(
  entries : ArrayView[(@pdflite.PdfName, @pdflite.PdfObject)],
  data : @pdflite.PdfBytes,
) -> @pdflite.PdfObject {
  let length = squeeze_name_for_test("/Length")
  let dictionary_entries : Array[(@pdflite.PdfName, @pdflite.PdfObject)] = [
    (length, PdfInteger(data.length())),
  ]
  for entry in entries {
    dictionary_entries.push(entry)
  }
  @pdflite.pdf_stream(PdfDictionary(dictionary_entries), StreamGot(data))
}

///|
fn squeeze_direct_stream_for_test(
  data : @pdflite.PdfBytes,
) -> @pdflite.PdfObject {
  squeeze_stream_for_test([], data)
}

///|
fn squeeze_filter_for_test(
  document : @pdflite.PdfDocument,
  object_number : Int,
) -> @pdflite.PdfObject? {
  let filter = squeeze_name_for_test("/Filter")
  match document.lookup_object_or_null(object_number) {
    PdfStreamObject(stream) => stream.dictionary.lookup_immediate(filter)
    _ => None
  }
}

///|
fn squeeze_filter_is_flate_for_test(value : @pdflite.PdfObject?) -> Bool {
  let flate = squeeze_name_for_test("/FlateDecode")
  match value {
    Some(PdfNameObject(name)) => name == flate
    Some(PdfArray([PdfNameObject(name), ..])) => name == flate
    _ => false
  }
}

///|
fn squeeze_stream_bytes_for_test(
  document : @pdflite.PdfDocument,
  object_number : Int,
) -> @pdflite.PdfBytes? {
  match document.lookup_object_or_null(object_number) {
    PdfStreamObject(stream) =>
      Some(
        try! @pdflite.pdf_stream(stream.dictionary, stream.data).stream_bytes(),
      )
    _ => None
  }
}

///|
test "PdfDocument recompress flates uncompressed streams and skips metadata" {
  let data = squeeze_data_for_test()
  let normal = squeeze_stream_for_test([], data)
  let metadata = squeeze_stream_for_test(
    [
      (
        squeeze_name_for_test("/Type"),
        PdfNameObject(squeeze_name_for_test("/Metadata")),
      ),
    ],
    data,
  )
  let document = @pdflite.pdf_document_empty()
  document.add_object_given_number(1, normal)
  document.add_object_given_number(2, metadata)

  let recompressed = try! document.recompress()

  @test.assert_eq(document.lookup_object_or_null(1), normal)
  @test.assert_eq(
    squeeze_filter_for_test(recompressed, 1),
    Some(PdfNameObject(squeeze_name_for_test("/FlateDecode"))),
  )
  @test.assert_eq(
    squeeze_stream_bytes_for_test(try! recompressed.decompress(), 1),
    Some(data),
  )
  @test.assert_eq(recompressed.lookup_object_or_null(2), metadata)
}

///|
test "recompress_pdf transcodes older lossless filters through Flate" {
  let data = squeeze_data_for_test()
  let raw = squeeze_stream_for_test([], data)
  let ascii_hex = try! @pdflite.pdf_encode_stream_with_filter(
    squeeze_name_for_test("/ASCIIHexDecode"),
    raw,
  )
  let document = @pdflite.pdf_document_empty()
  document.add_object_given_number(7, ascii_hex)

  let recompressed = try! @pdflite.recompress_pdf(document)

  @test.assert_eq(
    squeeze_filter_for_test(recompressed, 7),
    Some(PdfNameObject(squeeze_name_for_test("/FlateDecode"))),
  )
  @test.assert_eq(
    squeeze_stream_bytes_for_test(try! recompressed.decompress(), 7),
    Some(data),
  )
}

///|
test "PdfDocument recompress handles short filters and filter arrays" {
  let data = squeeze_data_for_test()
  let encoded = @pdflite.pdf_encode_filter_bytes(
    squeeze_name_for_test("/ASCIIHexDecode"),
    data,
  )
  let short_filter = squeeze_stream_for_test(
    [
      (
        squeeze_name_for_test("/F"),
        PdfNameObject(squeeze_name_for_test("/ASCIIHexDecode")),
      ),
    ],
    encoded,
  )
  let filter_array = squeeze_stream_for_test(
    [
      (
        squeeze_name_for_test("/Filter"),
        PdfArray([PdfNameObject(squeeze_name_for_test("/ASCIIHexDecode"))]),
      ),
    ],
    encoded,
  )
  let empty_filter_array = squeeze_stream_for_test(
    [(squeeze_name_for_test("/Filter"), PdfArray([]))],
    data,
  )
  let short_alias_filter = squeeze_stream_for_test(
    [
      (
        squeeze_name_for_test("/Filter"),
        PdfNameObject(squeeze_name_for_test("/AHx")),
      ),
    ],
    encoded,
  )
  let document = @pdflite.pdf_document_empty()
  document.add_object_given_number(10, short_filter)
  document.add_object_given_number(11, filter_array)
  document.add_object_given_number(12, empty_filter_array)
  document.add_object_given_number(17, short_alias_filter)

  let recompressed = try! document.recompress()
  let decompressed = try! recompressed.decompress()

  for number in [10, 11, 12, 17] {
    @test.assert_eq(
      squeeze_filter_is_flate_for_test(
        squeeze_filter_for_test(recompressed, number),
      ),
      true,
    )
    @test.assert_eq(
      squeeze_stream_bytes_for_test(decompressed, number),
      Some(data),
    )
  }
}

///|
test "PdfDocument recompress covers short filter arrays and malformed filters" {
  let data = squeeze_data_for_test()
  let encoded = @pdflite.pdf_encode_filter_bytes(
    squeeze_name_for_test("/ASCIIHexDecode"),
    data,
  )
  let short_empty_filter = squeeze_stream_for_test(
    [(squeeze_name_for_test("/F"), PdfArray([]))],
    data,
  )
  let short_filter_array = squeeze_stream_for_test(
    [
      (
        squeeze_name_for_test("/F"),
        PdfArray([PdfNameObject(squeeze_name_for_test("/ASCIIHexDecode"))]),
      ),
    ],
    encoded,
  )
  let malformed_filter = squeeze_stream_for_test(
    [(squeeze_name_for_test("/Filter"), PdfInteger(42))],
    data,
  )
  let malformed_short_filter = squeeze_stream_for_test(
    [(squeeze_name_for_test("/F"), PdfInteger(42))],
    data,
  )
  let document = @pdflite.pdf_document_empty()
  document.add_object_given_number(13, short_empty_filter)
  document.add_object_given_number(14, short_filter_array)

  let recompressed = try! document.recompress()
  let decompressed = try! recompressed.decompress()

  for number in [13, 14] {
    @test.assert_eq(
      squeeze_filter_is_flate_for_test(
        squeeze_filter_for_test(recompressed, number),
      ),
      true,
    )
    @test.assert_eq(
      squeeze_stream_bytes_for_test(decompressed, number),
      Some(data),
    )
  }

  let malformed_document = @pdflite.pdf_document_empty()
  malformed_document.add_object_given_number(15, malformed_filter)
  malformed_document.add_object_given_number(16, malformed_short_filter)
  let malformed_recompressed = try! malformed_document.recompress()
  @test.assert_eq(
    malformed_recompressed.lookup_object_or_null(15),
    malformed_filter,
  )
  @test.assert_eq(
    malformed_recompressed.lookup_object_or_null(16),
    malformed_short_filter,
  )
}

///|
test "PdfDocument decompress removes supported stream filters" {
  let data = squeeze_data_for_test()
  let raw = squeeze_stream_for_test([], data)
  let flate = try! @pdflite.pdf_encode_stream_with_filter(
    squeeze_name_for_test("/FlateDecode"),
    raw,
  )
  let document = @pdflite.pdf_document_empty()
  document.add_object_given_number(3, flate)

  let decompressed = try! @pdflite.decompress_pdf(document)

  @test.assert_eq(squeeze_filter_for_test(decompressed, 3), None)
  @test.assert_eq(squeeze_stream_bytes_for_test(decompressed, 3), Some(data))
  @test.assert_eq(document.lookup_object_or_null(3), flate)
}

///|
test "squeeze stream helpers leave encrypted documents unchanged" {
  let data = squeeze_data_for_test()
  let raw = squeeze_stream_for_test([], data)
  let flate = try! @pdflite.pdf_encode_stream_with_filter(
    squeeze_name_for_test("/FlateDecode"),
    raw,
  )
  let document = @pdflite.pdf_document_empty()
  document.add_object_given_number(4, raw)
  document.add_object_given_number(5, flate)
  document.set_trailer_dict(
    PdfDictionary([(squeeze_name_for_test("/Encrypt"), PdfDictionary([]))]),
  )

  let recompressed = try! document.recompress()
  let decompressed = try! document.decompress()

  @test.assert_eq(recompressed.lookup_object_or_null(4), raw)
  @test.assert_eq(decompressed.lookup_object_or_null(5), flate)
}

///|
test "PdfDocument recompress skips malformed old-filter streams" {
  let invalid = @ascii.encode("not valid hex data")
  let malformed = squeeze_stream_for_test(
    [
      (
        squeeze_name_for_test("/Filter"),
        PdfNameObject(squeeze_name_for_test("/ASCIIHexDecode")),
      ),
    ],
    invalid,
  )
  let document = @pdflite.pdf_document_empty()
  document.add_object_given_number(9, malformed)

  let recompressed = try! document.recompress()

  @test.assert_eq(recompressed.lookup_object_or_null(9), malformed)
}

///|
test "PdfDocument squeeze removes duplicate objects and rewrites references" {
  let key_info = squeeze_name_for_test("/Info")
  let first : @pdflite.PdfObject = PdfDictionary([
    (squeeze_name_for_test("/Name"), PdfString(@ascii.encode("same"))),
  ])
  let second = first
  let holder : @pdflite.PdfObject = PdfArray([PdfIndirect(2), PdfIndirect(1)])
  let document = @pdflite.pdf_document_empty()
  document.add_object_given_number(1, first)
  document.add_object_given_number(2, second)
  document.add_object_given_number(3, holder)
  document.set_trailer_dict(PdfDictionary([(key_info, PdfIndirect(2))]))

  let squeezed = try! document.squeeze()

  @test.assert_eq(squeezed.lookup_object_or_null(1), first)
  @test.assert_eq(squeezed.lookup_object_or_null(2), PdfNull)
  @test.assert_eq(
    squeezed.lookup_object_or_null(3),
    PdfArray([PdfIndirect(1), PdfIndirect(1)]),
  )
  @test.assert_eq(
    squeezed.trailer_dict().lookup_immediate(key_info),
    Some(PdfIndirect(1)),
  )
  @test.assert_eq(document.lookup_object_or_null(2), second)
}

///|
test "squeeze reaches duplicate-object fixed point" {
  let same : @pdflite.PdfObject = PdfString(@ascii.encode("fixed point"))
  let document = @pdflite.pdf_document_empty()
  document.add_object_given_number(1, PdfArray([PdfIndirect(4)]))
  document.add_object_given_number(2, PdfArray([PdfIndirect(5)]))
  document.add_object_given_number(4, same)
  document.add_object_given_number(5, same)
  document.add_object_given_number(6, PdfArray([PdfIndirect(2)]))

  let squeezed = try! @pdflite.squeeze(document)

  @test.assert_eq(squeezed.lookup_object_or_null(5), PdfNull)
  @test.assert_eq(squeezed.lookup_object_or_null(2), PdfNull)
  @test.assert_eq(squeezed.lookup_object_or_null(6), PdfArray([PdfIndirect(1)]))
}

///|
test "squeeze preserves duplicate page and annotation objects" {
  let page : @pdflite.PdfObject = PdfDictionary([
    (
      squeeze_name_for_test("/Type"),
      PdfNameObject(squeeze_name_for_test("/Page")),
    ),
  ])
  let annotation : @pdflite.PdfObject = PdfDictionary([
    (
      squeeze_name_for_test("/Subtype"),
      PdfNameObject(squeeze_name_for_test("/RichMedia")),
    ),
  ])
  let document = @pdflite.pdf_document_empty()
  document.add_object_given_number(20, page)
  document.add_object_given_number(21, page)
  document.add_object_given_number(22, annotation)
  document.add_object_given_number(23, annotation)

  let squeezed = try! document.squeeze()

  @test.assert_eq(squeezed.lookup_object_or_null(20), page)
  @test.assert_eq(squeezed.lookup_object_or_null(21), page)
  @test.assert_eq(squeezed.lookup_object_or_null(22), annotation)
  @test.assert_eq(squeezed.lookup_object_or_null(23), annotation)
}

///|
test "squeeze deduplicates equal streams before recompressing" {
  let data = squeeze_data_for_test()
  let stream = squeeze_direct_stream_for_test(data)
  let document = @pdflite.pdf_document_empty()
  document.add_object_given_number(30, stream)
  document.add_object_given_number(31, stream)
  document.add_object_given_number(32, PdfArray([PdfIndirect(31)]))

  let squeezed = try! document.squeeze()
  let decompressed = try! squeezed.decompress()

  @test.assert_eq(squeezed.lookup_object_or_null(31), PdfNull)
  @test.assert_eq(
    squeezed.lookup_object_or_null(32),
    PdfArray([PdfIndirect(30)]),
  )
  @test.assert_eq(squeeze_stream_bytes_for_test(decompressed, 30), Some(data))
}
