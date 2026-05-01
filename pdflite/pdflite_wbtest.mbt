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
