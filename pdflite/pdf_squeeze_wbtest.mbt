///|
fn squeeze_wbtest_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn squeeze_wbtest_data() -> PdfBytes {
  let output : Array[Byte] = []
  for _ in 0..<96 {
    for byte in @ascii.encode("already decrypted squeeze data\n")[:] {
      output.push(byte)
    }
  }
  Bytes::from_array(output)
}

///|
fn squeeze_wbtest_stream(
  entries : ArrayView[(PdfName, PdfObject)],
  data : PdfBytes,
) -> PdfObject {
  let dictionary_entries : Array[(PdfName, PdfObject)] = [
    (squeeze_wbtest_name("/Length"), PdfInteger(data.length())),
  ]
  for entry in entries {
    dictionary_entries.push(entry)
  }
  pdf_stream(PdfDictionary(dictionary_entries), StreamGot(data))
}

///|
test "PdfDocument recompress preserves already-decrypted object-table state" {
  let data = squeeze_wbtest_data()
  let normal = squeeze_wbtest_stream([], data)
  let metadata = squeeze_wbtest_stream(
    [
      (
        squeeze_wbtest_name("/Type"),
        PdfNameObject(squeeze_wbtest_name("/Metadata")),
      ),
    ],
    data,
  )
  let doc = pdf_document_empty()
  doc.objects.set_entry(
    1,
    pdf_object_entry(ObjectParsedAlreadyDecrypted(normal)),
  )
  doc.objects.set_entry(
    2,
    pdf_object_entry(ObjectParsedAlreadyDecrypted(metadata)),
  )
  doc.add_object_given_number(3, PdfInteger(42))

  let recompressed = try! doc.recompress()

  match recompressed.objects.get_entry(1) {
    Some({ data: ObjectParsedAlreadyDecrypted(PdfStreamObject(stream)), .. }) =>
      @test.assert_eq(
        stream.dictionary.lookup_immediate(squeeze_wbtest_name("/Filter")),
        Some(PdfNameObject(squeeze_wbtest_name("/FlateDecode"))),
      )
    _ => fail("expected already-decrypted recompressed stream")
  }
  @test.assert_eq(
    recompressed.objects.get_entry(2),
    Some(pdf_object_entry(ObjectParsedAlreadyDecrypted(metadata))),
  )
  @test.assert_eq(recompressed.lookup_object_or_null(3), PdfInteger(42))
}
