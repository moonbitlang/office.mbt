///|
fn page_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn page_tree_document_for_test() -> @pdflite.PdfDocument {
  let key_type = page_name_for_test("/Type")
  let key_pages = page_name_for_test("/Pages")
  let key_kids = page_name_for_test("/Kids")
  let key_count = page_name_for_test("/Count")
  let type_catalog = page_name_for_test("/Catalog")
  let type_pages = page_name_for_test("/Pages")
  let type_page = page_name_for_test("/Page")
  let doc = @pdflite.pdf_document_empty()
  doc.set_root(1)
  doc.add_object_given_number(
    1,
    @pdflite.pdf_dictionary([
      (key_type, PdfNameObject(type_catalog)),
      (key_pages, PdfIndirect(2)),
    ]),
  )
  doc.add_object_given_number(
    2,
    @pdflite.pdf_dictionary([
      (key_type, PdfNameObject(type_pages)),
      (key_kids, PdfArray([PdfIndirect(3), PdfIndirect(4)])),
      (key_count, PdfInteger(2)),
    ]),
  )
  doc.add_object_given_number(
    3,
    @pdflite.pdf_dictionary([(key_type, PdfNameObject(type_page))]),
  )
  doc.add_object_given_number(
    4,
    @pdflite.pdf_dictionary([
      (key_type, PdfNameObject(type_pages)),
      (key_kids, PdfArray([PdfIndirect(5)])),
      (key_count, PdfInteger(1)),
    ]),
  )
  doc.add_object_given_number(
    5,
    @pdflite.pdf_dictionary([(key_type, PdfNameObject(type_page))]),
  )
  doc
}

///|
test "PdfDocument page_reference_numbers traverses page tree in order" {
  let doc = page_tree_document_for_test()
  @test.assert_eq(try! doc.page_reference_numbers(), [3, 5])
  @test.assert_eq(try! doc.endpage(), 2)
  @test.assert_eq(try! doc.endpage_fast(), 2)
}

///|
test "PdfDocument page helpers survive writer and reader round trip" {
  let rendered = try! @pdflite.pdf_write_document(page_tree_document_for_test())
  let parsed = try! @pdflite.pdf_read_document_from_bytes(rendered)
  @test.assert_eq(parsed.object_numbers(), [1, 2, 3, 4, 5])
  @test.assert_eq(try! parsed.page_reference_numbers(), [3, 5])
  @test.assert_eq(try! parsed.endpage(), 2)
  @test.assert_eq(try! parsed.endpage_fast(), 2)
}

///|
test "PdfDocument page_reference_numbers reports missing page root" {
  let doc = @pdflite.pdf_document_empty()
  doc.set_root(1)
  doc.add_object_given_number(1, @pdflite.pdf_dictionary([]))
  let result : Result[Array[Int], Error] = try? doc.page_reference_numbers()
  guard result is Err(@pdflite.PdfError::PageTreeExpected) else {
    fail("expected PageTreeExpected")
  }
}

///|
test "PdfDocument page_reference_numbers reports missing catalog object" {
  let doc = @pdflite.pdf_document_empty()
  doc.set_root(99)
  let result : Result[Array[Int], Error] = try? doc.page_reference_numbers()
  guard result is Err(@pdflite.PdfError::RootExpected) else {
    fail("expected RootExpected")
  }
}
