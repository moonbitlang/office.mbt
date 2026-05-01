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
fn page_manual_extract_document_for_test() -> @pdflite.PdfDocument {
  let key_type = page_name_for_test("/Type")
  let key_pages = page_name_for_test("/Pages")
  let key_kids = page_name_for_test("/Kids")
  let key_count = page_name_for_test("/Count")
  let key_resources = page_name_for_test("/Resources")
  let key_mediabox = page_name_for_test("/MediaBox")
  let key_rotate = page_name_for_test("/Rotate")
  let key_contents = page_name_for_test("/Contents")
  let key_annots = page_name_for_test("/Annots")
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
      (key_resources, page_hello_resources_for_test()),
      (
        key_mediabox,
        PdfArray([
          PdfInteger(0),
          PdfInteger(0),
          PdfInteger(100),
          PdfInteger(200),
        ]),
      ),
      (key_rotate, PdfInteger(90)),
    ]),
  )
  doc.add_object_given_number(
    3,
    @pdflite.pdf_dictionary([
      (key_type, PdfNameObject(type_page)),
      (key_contents, PdfIndirect(6)),
      (key_annots, PdfArray([])),
    ]),
  )
  doc.add_object_given_number(
    4,
    @pdflite.pdf_dictionary([
      (key_type, PdfNameObject(type_page)),
      (
        key_mediabox,
        PdfArray([
          PdfInteger(10),
          PdfInteger(20),
          PdfInteger(30),
          PdfInteger(40),
        ]),
      ),
      (key_rotate, PdfInteger(-90)),
      (key_contents, PdfArray([PdfIndirect(999), PdfIndirect(7)])),
    ]),
  )
  doc.add_object_given_number(
    6,
    try! @pdflite.pdf_content_stream_of_ops(page_hello_ops_for_test()),
  )
  doc.add_object_given_number(
    7,
    try! @pdflite.pdf_content_stream_of_ops([Op_BT, Op_ET]),
  )
  doc
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
  let pages = try! parsed.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  @test.assert_eq(pages[0].resources, page_hello_resources_for_test())
  @test.assert_eq(pages[0].content.length(), 1)
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
  @test.assert_eq(
    try! parsed.parse_content_ops(pages[0].content),
    page_hello_ops_for_test(),
  )
}

///|
test "pdf_minimum_valid_pdf creates a writable one-page document" {
  let doc = try! @pdflite.pdf_minimum_valid_pdf()
  @test.assert_eq(try! doc.endpage(), 1)
  let pages = try! doc.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  @test.assert_eq(pages[0], @pdflite.pdf_page_blank(@pdflite.paper_a4))
  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    try! @pdflite.pdf_write_document(doc),
  )
  @test.assert_eq(try! parsed.endpage(), 1)
  let parsed_pages = try! parsed.pages_of_pagetree()
  @test.assert_eq(parsed_pages[0].content, [])
  @test.assert_eq(parsed_pages[0].resources, PdfDictionary([]))
  @test.assert_eq(parsed_pages[0].rotate, Rotate0)
  @test.assert_eq(
    try! parsed.parse_rectangle(parsed_pages[0].mediabox),
    try! doc.parse_rectangle(pages[0].mediabox),
  )
}

///|
test "PdfDocument pages_of_pagetree extracts inherited page properties" {
  let doc = page_manual_extract_document_for_test()
  let pages = try! doc.pages_of_pagetree()
  @test.assert_eq(pages.length(), 2)
  @test.assert_eq(pages[0].resources, page_hello_resources_for_test())
  @test.assert_eq(
    pages[0].mediabox,
    PdfArray([PdfInteger(0), PdfInteger(0), PdfInteger(100), PdfInteger(200)]),
  )
  @test.assert_eq(pages[0].rotate, Rotate90)
  @test.assert_eq(pages[0].content, [PdfIndirect(6)])
  @test.assert_eq(
    pages[0].rest,
    @pdflite.pdf_dictionary([(page_name_for_test("/Annots"), PdfArray([]))]),
  )
  @test.assert_eq(pages[1].resources, page_hello_resources_for_test())
  @test.assert_eq(
    pages[1].mediabox,
    PdfArray([PdfInteger(10), PdfInteger(20), PdfInteger(30), PdfInteger(40)]),
  )
  @test.assert_eq(pages[1].rotate, Rotate270)
  @test.assert_eq(pages[1].content, [PdfIndirect(7)])
}

///|
test "PdfDocument pages_of_pagetree falls back to last seen mediabox" {
  let key_type = page_name_for_test("/Type")
  let key_pages = page_name_for_test("/Pages")
  let key_kids = page_name_for_test("/Kids")
  let key_count = page_name_for_test("/Count")
  let key_mediabox = page_name_for_test("/MediaBox")
  let doc = @pdflite.pdf_document_empty()
  doc.set_root(1)
  doc.add_object_given_number(
    1,
    @pdflite.pdf_dictionary([
      (key_type, PdfNameObject(page_name_for_test("/Catalog"))),
      (key_pages, PdfIndirect(2)),
    ]),
  )
  doc.add_object_given_number(
    2,
    @pdflite.pdf_dictionary([
      (key_type, PdfNameObject(page_name_for_test("/Pages"))),
      (key_kids, PdfArray([PdfIndirect(3), PdfIndirect(4)])),
      (key_count, PdfInteger(2)),
    ]),
  )
  let first_box : @pdflite.PdfObject = PdfArray([
    PdfInteger(1),
    PdfInteger(2),
    PdfInteger(300),
    PdfInteger(400),
  ])
  doc.add_object_given_number(
    3,
    @pdflite.pdf_dictionary([
      (key_type, PdfNameObject(page_name_for_test("/Page"))),
      (key_mediabox, first_box),
    ]),
  )
  doc.add_object_given_number(
    4,
    @pdflite.pdf_dictionary([
      (key_type, PdfNameObject(page_name_for_test("/Page"))),
    ]),
  )
  let pages = try! doc.pages_of_pagetree()
  @test.assert_eq(pages[0].mediabox, first_box)
  @test.assert_eq(pages[1].mediabox, first_box)
}

///|
test "pdf_page_protect balances unmatched graphics saves" {
  @test.assert_eq(@pdflite.pdf_page_protect([Op_q, Op_q, Op_Q]), [Op_Q])
  @test.assert_eq(@pdflite.pdf_page_protect([Op_q, Op_Q, Op_Q]), [])
}

///|
test "PdfDocument prepend_operators merges content in non-fast mode" {
  let doc = @pdflite.pdf_document_empty()
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    content: [try! @pdflite.pdf_content_stream_of_ops([Op_BT, Op_ET])],
  }
  let updated = try! doc.prepend_operators(page, [Op_q, Op_Q])
  @test.assert_eq(updated.content.length(), 1)
  @test.assert_eq(try! doc.parse_content_ops(updated.content), [
    Op_q,
    Op_Q,
    Op_BT,
    Op_ET,
  ])
}

///|
test "PdfDocument prepend_operators preserves split streams in fast mode" {
  let doc = @pdflite.pdf_document_empty()
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    content: [try! @pdflite.pdf_content_stream_of_ops([Op_BT, Op_ET])],
  }
  let updated = try! doc.prepend_operators(page, [Op_q, Op_Q], fast=true)
  @test.assert_eq(updated.content.length(), 2)
  @test.assert_eq(try! doc.parse_content_ops(updated.content), [
    Op_q,
    Op_Q,
    Op_BT,
    Op_ET,
  ])
}

///|
test "PdfDocument postpend_operators protects existing content in non-fast mode" {
  let doc = @pdflite.pdf_document_empty()
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    content: [try! @pdflite.pdf_content_stream_of_ops([Op_q, Op_BT, Op_ET])],
  }
  let updated = try! doc.postpend_operators(page, [Op_g(0.5)])
  @test.assert_eq(updated.content.length(), 1)
  @test.assert_eq(try! doc.parse_content_ops(updated.content), [
    Op_q,
    Op_q,
    Op_BT,
    Op_ET,
    Op_Q,
    Op_Q,
    Op_g(0.5),
  ])
}

///|
test "PdfDocument postpend_operators avoids protection for empty content" {
  let doc = @pdflite.pdf_document_empty()
  let page = @pdflite.pdf_page_blank(@pdflite.paper_a4)
  let updated = try! doc.postpend_operators(page, [Op_BT, Op_ET])
  @test.assert_eq(updated.content.length(), 1)
  @test.assert_eq(try! doc.parse_content_ops(updated.content), [Op_BT, Op_ET])
}

///|
test "PdfDocument change_pages writes modified content into a replacement page tree" {
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
  let original_pages = try! doc.pages_of_pagetree()
  let changed_page = try! doc.postpend_operators(original_pages[0], [Op_g(0.25)])
  let changed = try! doc.change_pages([changed_page])
  @test.assert_eq(
    try! doc.parse_content_ops(original_pages[0].content),
    page_hello_ops_for_test(),
  )
  let changed_pages = try! changed.pages_of_pagetree()
  let expected_ops : Array[@pdflite.PdfContentOp] = [
    Op_q,
    ..page_hello_ops_for_test(),
    Op_Q,
    Op_g(0.25),
  ]
  @test.assert_eq(
    try! changed.parse_content_ops(changed_pages[0].content),
    expected_ops,
  )
  let reparsed = try! @pdflite.pdf_read_document_from_bytes(
    try! @pdflite.pdf_write_document(changed),
  )
  @test.assert_eq(
    try! reparsed.parse_content_ops(
      (try! reparsed.pages_of_pagetree())[0].content,
    ),
    expected_ops,
  )
}

///|
test "PdfDocument change_pages renumbers same-count page references" {
  let key_open_action = page_name_for_test("/OpenAction")
  let type_fit = page_name_for_test("/Fit")
  let doc = @pdflite.pdf_document_empty()
  let first = @pdflite.pdf_page_blank(@pdflite.paper_a4)
  let second = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    rotate: Rotate90,
  }
  let page_root = try! doc.add_pagetree([first, second])
  ignore(try! doc.add_root(page_root, []))
  let old_numbers = try! doc.page_reference_numbers()
  doc.add_object_given_number(
    doc.root(),
    try! doc
    .lookup_object_or_null(doc.root())
    .add_dict_entry(
      key_open_action,
      PdfArray([PdfIndirect(old_numbers[0]), PdfNameObject(type_fit)]),
    ),
  )
  let changed = try! doc.change_pages(
    try! doc.pages_of_pagetree(),
    change_references=true,
  )
  let new_numbers = try! changed.page_reference_numbers()
  @test.assert_eq(old_numbers.length(), 2)
  @test.assert_eq(new_numbers.length(), 2)
  @test.assert_eq(
    changed
    .lookup_object_or_null(changed.root())
    .lookup_immediate(key_open_action),
    Some(PdfArray([PdfIndirect(new_numbers[0]), PdfNameObject(type_fit)])),
  )
  @test.assert_eq(
    doc.lookup_object_or_null(doc.root()).lookup_immediate(key_open_action),
    Some(PdfArray([PdfIndirect(old_numbers[0]), PdfNameObject(type_fit)])),
  )
}

///|
test "PdfDocument change_pages rejects reference renumbering when counts differ" {
  let doc = @pdflite.pdf_document_empty()
  let page_root = try! doc.add_pagetree([
    @pdflite.pdf_page_blank(@pdflite.paper_a4),
    @pdflite.pdf_page_blank(@pdflite.paper_a4),
  ])
  ignore(try! doc.add_root(page_root, []))
  let result : Result[@pdflite.PdfDocument, Error] = try? doc.change_pages(
    [@pdflite.pdf_page_blank(@pdflite.paper_a4)],
    change_references=true,
  )
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
