// Whitebox tests run within the package scope.
// Use them to validate internal helpers or invariants.
// Keep them focused; public behavior belongs in `_test.mbt`.

///|
test "private PDF number set deduplicates membership and additions" {
  let numbers = @core.pdf_number_set([1, 1])
  @test.assert_eq(numbers.contains(1), true)
  @test.assert_eq(numbers.contains(2), false)
  numbers.add(2)
  numbers.add(2)
  @test.assert_eq(numbers.contains(2), true)
  let output : Array[Int] = []
  @core.pdf_push_unique_number(output, numbers, 2)
  @core.pdf_push_unique_number(output, numbers, 3)
  @core.pdf_push_unique_number(output, numbers, 3)
  @test.assert_eq(output, [3])
}

///|
test "private destination page number lookup preserves first page reference" {
  let lookup = pdf_page_number_lookup([10, 10, 20])
  @test.assert_eq(lookup.page_number(10), 1)
  @test.assert_eq(lookup.page_number(20), 3)
  @test.assert_eq(lookup.page_number(30), 0)
  @test.assert_eq(
    pdf_destination_page_number_of_target(lookup, TargetOtherDocPageNumber(1)),
    2,
  )
  @test.assert_eq(
    pdf_destination_page_number_of_target(lookup, TargetPageObject(10)),
    1,
  )
}

///|
test "pdf duplicate stream candidates reject non-stream objects" {
  @test.assert_eq(
    pdf_duplicate_stream_candidate(1, PdfInteger(1)) is None,
    true,
  )
  let stream = @syntax.pdf_stream(
    PdfDictionary([]),
    StreamGot(@ascii.encode("a")),
  )
  guard pdf_duplicate_stream_candidate(2, stream) is Some(candidate) else {
    fail("expected stream candidate")
  }
  @test.assert_eq(candidate.number, 2)
  @test.assert_eq(candidate.equals(candidate), true)
}

///|
test "PdfDocument copy preserves parser-private object states" {
  let doc = pdf_document_empty()
  doc.objects.set_entry(
    5,
    pdf_object_entry(ObjectParsedAlreadyDecrypted(PdfInteger(50)), generation=2),
  )
  doc.objects.object_stream_ids[8] = 5
  @test.assert_eq(doc.direct(PdfIndirect(5)), PdfInteger(50))
  let copied = doc.copy()
  @test.assert_eq(copied.lookup_object_or_null(5), PdfInteger(50))
  @test.assert_eq(
    copied.objects.get_entry(5),
    Some(
      pdf_object_entry(
        ObjectParsedAlreadyDecrypted(PdfInteger(50)),
        generation=2,
      ),
    ),
  )
  @test.assert_eq(copied.objects.object_stream_ids.get(8), Some(5))
  copied.objects.set_entry(5, pdf_object_entry(ObjectParsed(PdfInteger(7))))
  copied.objects.object_stream_ids[8] = 9
  @test.assert_eq(doc.lookup_object_or_null(5), PdfInteger(50))
  @test.assert_eq(doc.objects.object_stream_ids.get(8), Some(5))
}

///|
test "PdfDocument stream decompression preserves already-decrypted state" {
  let length = @core.pdf_name_of_bytes(@ascii.encode("/Length"))
  let filter = @core.pdf_name_of_bytes(@ascii.encode("/Filter"))
  let encoded = @codec.pdf_ascii_hex_encode(@ascii.encode("Hi"))
  let stream = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (length, PdfInteger(encoded.length())),
      (filter, PdfNameObject(@core.pdf_name_of_bytes(@ascii.encode("/AHx")))),
    ]),
    StreamGot(encoded),
  )
  let doc = pdf_document_empty()
  doc.objects.set_entry(
    6,
    pdf_object_entry(ObjectParsedAlreadyDecrypted(stream), generation=3),
  )
  try! doc.pdf_decode_streams_until_unknown()
  guard doc.objects.get_entry(6)
    is Some(
      {
        data: ObjectParsedAlreadyDecrypted(PdfStreamObject(decoded)),
        generation: 3,
      }
    ) else {
    fail("expected already-decrypted stream")
  }
  @test.assert_eq(decoded.data, StreamGot(@ascii.encode("Hi")))
  @test.assert_eq(
    decoded.dictionary.lookup_immediate(length),
    Some(PdfInteger(2)),
  )
}

///|
test "PdfDocument renumbering preserves parser object-stream hints" {
  let doc = pdf_document_empty()
  doc.objects.set_entry(8, pdf_object_entry(ObjectParsed(PdfInteger(8))))
  doc.objects.set_entry(9, pdf_object_entry(ObjectParsed(PdfInteger(9))))
  doc.objects.object_stream_ids[8] = 5
  doc.objects.object_stream_ids[99] = 5
  let renumbered = try! doc.renumber_objects([(8, 2), (9, 3)])
  @test.assert_eq(renumbered.objects.object_stream_ids.get(2), Some(5))
  @test.assert_eq(renumbered.objects.object_stream_ids.get(8), None)
  @test.assert_eq(renumbered.objects.object_stream_ids.get(99), None)
}

///|
test "PdfDocument ARC4 crypt preserves parser-private object states" {
  let key = try! @core.pdf_bytes_of_int_array([1, 2, 3, 4, 5])
  let doc = pdf_document_empty()
  doc.objects.set_entry(
    1,
    pdf_object_entry(
      ObjectParsedAlreadyDecrypted(PdfString(@ascii.encode("plain"))),
    ),
  )
  doc.objects.set_entry(2, pdf_object_entry(ObjectToParse))
  doc.objects.set_entry(
    3,
    pdf_object_entry(
      ObjectToParseFromObjectStream({ object_stream_number: 7, index: 0 }),
    ),
  )
  let encrypted = try! doc.arc4_crypt_parsed_objects(key, 40, false, 0)
  @test.assert_eq(encrypted.objects.get_entry(1), doc.objects.get_entry(1))
  @test.assert_eq(encrypted.objects.get_entry(2), doc.objects.get_entry(2))
  @test.assert_eq(encrypted.objects.get_entry(3), doc.objects.get_entry(3))
}

///|
test "PdfDocument select_object_numbers ignores deferred parser states" {
  let doc = pdf_document_empty()
  doc.add_object_given_number(1, PdfNull)
  doc.objects.set_entry(2, pdf_object_entry(ObjectToParse))
  doc.objects.set_entry(
    3,
    pdf_object_entry(
      ObjectToParseFromObjectStream({ object_stream_number: 7, index: 0 }),
    ),
  )
  @test.assert_eq(doc.select_object_numbers(fn(object) { object == PdfNull }), [
    1,
  ])
}
