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
fn page_hello_ops_for_test() -> Array[@pdflite.PdfContentOp] {
  [
    Op_cm(@pdflite.transform_translate(50.0, 770.0)),
    Op_BT,
    Op_Tf(page_name_for_test("/F0"), 36.0),
    Op_Tj(@ascii.encode("Hello, World!")),
    Op_ET,
  ]
}

///|
fn page_hello_resources_for_test() -> @pdflite.PdfObject {
  let key_font = page_name_for_test("/Font")
  let key_type = page_name_for_test("/Type")
  let key_subtype = page_name_for_test("/Subtype")
  let key_basefont = page_name_for_test("/BaseFont")
  let font = @pdflite.pdf_dictionary([
    (key_type, PdfNameObject(page_name_for_test("/Font"))),
    (key_subtype, PdfNameObject(page_name_for_test("/Type1"))),
    (key_basefont, PdfNameObject(page_name_for_test("/Times-Italic"))),
  ])
  @pdflite.pdf_dictionary([
    (key_font, @pdflite.pdf_dictionary([(page_name_for_test("/F0"), font)])),
  ])
}

///|
test "PdfDocument page_reference_numbers traverses page tree in order" {
  let doc = page_tree_document_for_test()
  @test.assert_eq(try! doc.page_reference_numbers(), [3, 5])
  @test.assert_eq(try! doc.endpage(), 2)
  @test.assert_eq(try! doc.endpage_fast(), 2)
  @test.assert_eq(try! doc.page_object_number(1), Some(3))
  @test.assert_eq(try! doc.page_object_number(2), Some(5))
  @test.assert_eq(try! doc.page_object_number(3), None)
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
test "pdf_page_blank creates an A4 page rectangle in PDF points" {
  let page = @pdflite.pdf_page_blank(@pdflite.paper_a4)
  @test.assert_eq(page.content, [])
  @test.assert_eq(page.resources, PdfDictionary([]))
  @test.assert_eq(page.rotate, Rotate0)
  @test.assert_eq(
    page.mediabox,
    PdfArray([
      PdfReal(0.0),
      PdfReal(0.0),
      PdfReal(@pdflite.unit_points(210.0, Millimetre)),
      PdfReal(@pdflite.unit_points(297.0, Millimetre)),
    ]),
  )
}

///|
test "pdf_page_rotation_of_int preserves CamlPDF rotation cases" {
  @test.assert_eq(try! @pdflite.pdf_page_rotation_of_int(0), Rotate0)
  @test.assert_eq(try! @pdflite.pdf_page_rotation_of_int(90), Rotate90)
  @test.assert_eq(try! @pdflite.pdf_page_rotation_of_int(-180), Rotate180)
  @test.assert_eq(try! @pdflite.pdf_page_rotation_of_int(-90), Rotate270)
  let result : Result[@pdflite.PdfPageRotation, Error] = try? @pdflite.pdf_page_rotation_of_int(
    45,
  )
  guard result is Err(@pdflite.PdfError::PageRotationExpected(45)) else {
    fail("expected PageRotationExpected")
  }
}

///|
test "PdfDocument add_pagetree and add_root build a writable page document" {
  let doc = @pdflite.pdf_document_empty()
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    content: [
      try! @pdflite.pdf_content_stream_of_ops(page_hello_ops_for_test()),
    ],
    resources: page_hello_resources_for_test(),
  }
  let page_root = try! doc.add_pagetree([page])
  ignore(try! doc.add_root(page_root, []))
  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    try! @pdflite.pdf_write_document(doc),
  )
  @test.assert_eq(try! parsed.endpage(), 1)
  let page_numbers = try! parsed.page_reference_numbers()
  @test.assert_eq(page_numbers.length(), 1)
  let page_object = parsed.lookup_object_or_null(page_numbers[0])
  let contents = match
    page_object.lookup_immediate(page_name_for_test("/Contents")) {
    Some(PdfArray(items)) => items
    _ => fail("expected page contents")
  }
  @test.assert_eq(
    try! parsed.parse_content_ops(contents),
    page_hello_ops_for_test(),
  )
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
