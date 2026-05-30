///|
fn dedupe_name_for_test(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn dedupe_stream_for_test() -> @syntax.PdfObject {
  @syntax.pdf_stream(
    PdfDictionary([(dedupe_name_for_test("/Length"), PdfInteger(2))]),
    StreamGot(@ascii.encode("Hi")),
  )
}

///|
test "private duplicate stream changes group by length and keep canonical order" {
  let length = dedupe_name_for_test("/Length")
  let doc = pdf_document_empty()
  let two_byte = dedupe_stream_for_test()
  let one_byte = @syntax.pdf_stream(
    PdfDictionary([(length, PdfInteger(1))]),
    StreamGot(@ascii.encode("H")),
  )
  let different_dictionary = @syntax.pdf_stream(
    PdfDictionary([
      (length, PdfInteger(2)),
      (
        dedupe_name_for_test("/Subtype"),
        PdfNameObject(dedupe_name_for_test("/Font")),
      ),
    ]),
    StreamGot(@ascii.encode("Hi")),
  )
  doc.add_object_given_number(1, two_byte)
  doc.add_object_given_number(2, one_byte)
  doc.add_object_given_number(3, two_byte)
  doc.add_object_given_number(4, different_dictionary)
  doc.add_object_given_number(5, one_byte)

  @test.assert_eq(doc.pdf_duplicate_stream_changes(), [(3, 1), (5, 2)])
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
