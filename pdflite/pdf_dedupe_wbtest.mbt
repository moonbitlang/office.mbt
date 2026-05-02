///|
fn dedupe_name_for_test(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn dedupe_stream_for_test() -> PdfObject {
  pdf_stream(
    PdfDictionary([(dedupe_name_for_test("/Length"), PdfInteger(2))]),
    StreamGot(@ascii.encode("Hi")),
  )
}

///|
test "remove_duplicate_fonts rewrites already-decrypted stream entries" {
  let doc = pdf_document_empty()
  let stream = dedupe_stream_for_test()
  doc.objects.set_entry(1, pdf_object_entry(ObjectParsed(stream)))
  doc.objects.set_entry(
    2,
    pdf_object_entry(ObjectParsedAlreadyDecrypted(stream)),
  )
  doc.add_object_given_number(3, PdfArray([PdfIndirect(1), PdfIndirect(2)]))

  doc.remove_duplicate_fonts()

  @test.assert_eq(doc.lookup_object_or_null(1), stream)
  @test.assert_eq(doc.lookup_object_or_null(2), PdfNull)
  @test.assert_eq(
    doc.lookup_object_or_null(3),
    PdfArray([PdfIndirect(1), PdfIndirect(1)]),
  )
}
