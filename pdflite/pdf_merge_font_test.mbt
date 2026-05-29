///|
fn merge_font_one_page_doc_for_test(
  major : Int,
  minor : Int,
) -> @pdflite.PdfDocument {
  let doc = try! @pdflite.pdf_minimum_valid_pdf()
  doc.set_version(major, minor)
  doc
}

///|
fn merge_font_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn merge_font_add_catalog_entry_for_test(
  doc : @pdflite.PdfDocument,
  key : @pdflite.PdfName,
  value : @pdflite.PdfObject,
) -> @pdflite.PdfDocument {
  let root = doc.lookup_object_or_null(doc.root())
  let new_root = doc.add_object(try! root.add_dict_entry(key, value))
  doc.set_root(new_root)
  doc.set_trailer_dict(
    try! doc
    .trailer_dict()
    .add_dict_entry(merge_font_name_for_test("/Root"), PdfIndirect(new_root)),
  )
  doc
}

///|
fn merge_font_duplicate_stream_for_test() -> @pdflite.PdfObject {
  @pdflite.pdf_stream(
    PdfDictionary([(merge_font_name_for_test("/Length"), PdfInteger(2))]),
    StreamGot(@ascii.encode("Hi")),
  )
}

///|
fn merge_font_catalog_stream_doc_for_test(
  key : @pdflite.PdfName,
  stream_number : Int,
) -> @pdflite.PdfDocument {
  let doc = merge_font_one_page_doc_for_test(1, 4)
  doc.add_object_given_number(
    stream_number,
    merge_font_duplicate_stream_for_test(),
  )
  merge_font_add_catalog_entry_for_test(doc, key, PdfIndirect(stream_number))
}

///|
test "PdfDocument remove_duplicate_fonts coalesces identical streams" {
  let key_info = merge_font_name_for_test("/Info")
  let doc = @pdflite.pdf_document_empty()
  let stream = merge_font_duplicate_stream_for_test()
  doc.add_object_given_number(1, stream)
  doc.add_object_given_number(2, stream)
  doc.add_object_given_number(3, PdfArray([PdfIndirect(1), PdfIndirect(2)]))
  doc.set_trailer_dict(PdfDictionary([(key_info, PdfIndirect(2))]))
  @pdflite.pdf_remove_duplicate_fonts(doc)
  @test.assert_eq(doc.lookup_object_or_null(1), stream)
  @test.assert_eq(doc.lookup_object_or_null(2), PdfNull)
  @test.assert_eq(
    doc.lookup_object_or_null(3),
    PdfArray([PdfIndirect(1), PdfIndirect(1)]),
  )
  @test.assert_eq(
    doc.trailer_dict().lookup_immediate(key_info),
    Some(PdfIndirect(1)),
  )
}

///|
test "PdfDocument remove_duplicate_fonts coalesces deferred stream data" {
  let doc = @pdflite.pdf_document_empty()
  let input = @pdflite.byte_cursor_of_bytes(@ascii.encode("xxHiyyHi"))
  let dictionary : @pdflite.PdfObject = PdfDictionary([
    (merge_font_name_for_test("/Length"), PdfInteger(2)),
  ])
  doc.add_object_given_number(
    1,
    @pdflite.pdf_stream(
      dictionary,
      StreamToGet(@pdflite.stream_to_get(input, 2, 2)),
    ),
  )
  doc.add_object_given_number(
    2,
    @pdflite.pdf_stream(
      dictionary,
      StreamToGet(@pdflite.stream_to_get(input, 6, 2)),
    ),
  )
  doc.add_object_given_number(3, PdfArray([PdfIndirect(1), PdfIndirect(2)]))
  doc.remove_duplicate_fonts()
  @test.assert_eq(
    try! doc.lookup_object_or_null(1).stream_bytes(),
    @ascii.encode("Hi"),
  )
  @test.assert_eq(doc.lookup_object_or_null(2), PdfNull)
  @test.assert_eq(
    doc.lookup_object_or_null(3),
    PdfArray([PdfIndirect(1), PdfIndirect(1)]),
  )
}

///|
test "pdf_merge_documents can remove duplicate font streams" {
  let key_first_stream = merge_font_name_for_test("/PieceInfo")
  let key_second_stream = merge_font_name_for_test("/Metadata")
  let first = merge_font_catalog_stream_doc_for_test(key_first_stream, 30)
  let second = merge_font_catalog_stream_doc_for_test(key_second_stream, 30)
  let without_dedupe = try! @pdflite.pdf_merge_documents([first, second], [
    [1],
    [1],
  ])
  let root = without_dedupe.lookup_object_or_null(without_dedupe.root())
  guard root.lookup_immediate(key_first_stream)
    is Some(PdfIndirect(first_stream)) else {
    fail("expected first stream")
  }
  guard root.lookup_immediate(key_second_stream)
    is Some(PdfIndirect(second_stream)) else {
    fail("expected second stream")
  }
  @test.assert_eq(first_stream == second_stream, false)
  let deduped = try! @pdflite.pdf_merge_documents(
    [first, second],
    [[1], [1]],
    remove_duplicate_fonts=true,
  )
  let root = deduped.lookup_object_or_null(deduped.root())
  guard root.lookup_immediate(key_first_stream)
    is Some(PdfIndirect(first_stream)) else {
    fail("expected deduped first stream")
  }
  guard root.lookup_immediate(key_second_stream)
    is Some(PdfIndirect(second_stream)) else {
    fail("expected deduped second stream")
  }
  @test.assert_eq(first_stream, second_stream)
  @test.assert_eq(
    deduped.lookup_object_or_null(first_stream),
    merge_font_duplicate_stream_for_test(),
  )
}
