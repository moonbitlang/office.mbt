// Whitebox tests run within the package scope.
// Use them to validate internal helpers or invariants.
// Keep them focused; public behavior belongs in `_test.mbt`.

///|
test "pdf_duplicate_stream_equal rejects non-stream objects" {
  @test.assert_eq(
    pdf_duplicate_stream_equal(PdfInteger(1), PdfInteger(1)),
    false,
  )
  @test.assert_eq(
    pdf_duplicate_stream_equal(
      pdf_stream(PdfDictionary([]), StreamGot(@ascii.encode("a"))),
      PdfInteger(1),
    ),
    false,
  )
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
test "writer parses signed integer fragments for scientific reals" {
  @test.assert_eq(
    try! pdf_writer_parse_signed_int(@ascii.encode("+12")[:], 0),
    12,
  )
  @test.assert_eq(
    try! pdf_writer_parse_signed_int(@ascii.encode("12")[:], 0),
    12,
  )
  let missing : Result[Int, Error] = try? pdf_writer_parse_signed_int(
    @ascii.encode("+")[:],
    0,
  )
  guard missing is Err(PdfError::NumberExpected) else {
    fail("expected NumberExpected")
  }
  let malformed : Result[Int, Error] = try? pdf_writer_parse_signed_int(
    @ascii.encode("12a")[:],
    0,
  )
  guard malformed is Err(PdfError::NumberExpected) else {
    fail("expected NumberExpected")
  }
}

///|
test "writer expands scientific real edge forms" {
  let plus_output : Array[Byte] = []
  try! pdf_writer_push_scientific_real(
    plus_output,
    @ascii.encode("+1.25e2")[:],
    5,
  )
  @test.assert_eq(Bytes::from_array(plus_output), @ascii.encode("125"))

  let negative_output : Array[Byte] = []
  try! pdf_writer_push_scientific_real(
    negative_output,
    @ascii.encode("-1.25e2")[:],
    5,
  )
  @test.assert_eq(Bytes::from_array(negative_output), @ascii.encode("-125"))

  let padded_output : Array[Byte] = []
  try! pdf_writer_push_scientific_real(
    padded_output,
    @ascii.encode("1.2e3")[:],
    3,
  )
  @test.assert_eq(Bytes::from_array(padded_output), @ascii.encode("1200"))

  let middle_output : Array[Byte] = []
  try! pdf_writer_push_scientific_real(
    middle_output,
    @ascii.encode("1.25e1")[:],
    4,
  )
  @test.assert_eq(Bytes::from_array(middle_output), @ascii.encode("12.5"))

  let zero_output : Array[Byte] = []
  try! pdf_writer_push_scientific_real(zero_output, @ascii.encode(".e1")[:], 1)
  @test.assert_eq(Bytes::from_array(zero_output), @ascii.encode("0"))

  let malformed_output : Array[Byte] = []
  let malformed : Result[Unit, Error] = try? pdf_writer_push_scientific_real(
    malformed_output,
    @ascii.encode("1Ae1")[:],
    2,
  )
  guard malformed is Err(PdfError::NumberExpected) else {
    fail("expected NumberExpected")
  }
}

///|
test "pdf_write_document rejects deferred object states" {
  let doc = pdf_document_empty()
  doc.objects.set_entry(1, pdf_object_entry(ObjectToParse))
  let result : Result[PdfBytes, Error] = try? pdf_write_document(doc)
  guard result is Err(PdfError::ParsedObjectExpected) else {
    fail("expected ParsedObjectExpected")
  }
}

///|
test "parser prefix helper reports malformed indirect prefixes" {
  let too_short : Result[PdfParsedIndirectObject, Error] = try? pdf_parse_indirect_object_prefix_lexemes([
      LexInt(1),
      LexInt(0),
    ],
  )
  guard too_short is Err(PdfError::ParseIndirectObjectExpected) else {
    fail("expected ParseIndirectObjectExpected")
  }
  let bad_header : Result[PdfParsedIndirectObject, Error] = try? pdf_parse_indirect_object_prefix_lexemes([
      LexInt(1),
      LexInt(0),
      LexNull,
    ],
  )
  guard bad_header is Err(PdfError::ParseIndirectObjectExpected) else {
    fail("expected ParseIndirectObjectExpected")
  }
}

///|
test "page-label private helpers preserve non-uppercase bytes and root guards" {
  @test.assert_eq(
    pdf_page_label_lowercase(@ascii.encode("A1Z!")),
    @ascii.encode("a1z!"),
  )
  let doc = pdf_document_empty()
  let result : Result[Bool, Error] = try? doc.pdf_page_label_has_labels()
  guard result is Err(PdfError::RootExpected) else {
    fail("expected RootExpected")
  }
}

///|
test "private annotation and bookmark guards report malformed roots" {
  let annotation_rest : Result[PdfObject, Error] = try? pdf_annotation_rest(
    PdfInteger(1),
  )
  guard annotation_rest is Err(PdfError::DictionaryExpected) else {
    fail("expected DictionaryExpected")
  }
  let doc = pdf_document_empty()
  let outlines : Result[Bool, Error] = try? doc.pdf_bookmark_has_outlines()
  guard outlines is Err(PdfError::RootExpected) else {
    fail("expected RootExpected")
  }
}

///|
test "private structure survival helpers cover direct cases" {
  let key_pg = pdf_structure_pg_key()
  let doc = pdf_document_empty()
  doc.add_object_given_number(
    50,
    PdfDictionary([
      (key_pg, PdfIndirect(2)),
      (pdf_structure_k_key(), PdfInteger(0)),
    ]),
  )
  @test.assert_eq(doc.pdf_structure_indirect_survives(50, [2]), false)
  @test.assert_eq(doc.pdf_structure_k_item_survives(PdfInteger(1), [2]), true)
  @test.assert_eq(doc.pdf_structure_filtered_k_value(PdfInteger(1), [2]), None)
}
