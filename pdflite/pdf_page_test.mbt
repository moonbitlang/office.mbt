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
fn page_index_mediabox_for_test(index : Int) -> @pdflite.PdfObject {
  PdfArray([
    PdfInteger(index),
    PdfInteger(0),
    PdfInteger(index + 100),
    PdfInteger(200),
  ])
}

///|
fn page_indexed_blank_for_test(index : Int) -> @pdflite.PdfPage {
  {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    mediabox: page_index_mediabox_for_test(index),
  }
}

///|
fn page_prefix_resources_for_test(
  names : ArrayView[String],
) -> @pdflite.PdfObject {
  let font_entries : Array[(@pdflite.PdfName, @pdflite.PdfObject)] = []
  for name in names {
    font_entries.push((page_name_for_test(name), PdfDictionary([])))
  }
  @pdflite.pdf_dictionary([
    (page_name_for_test("/Font"), PdfDictionary(font_entries)),
  ])
}

///|
fn page_prefix_document_for_test(
  names : ArrayView[String],
) -> @pdflite.PdfDocument {
  let doc = @pdflite.pdf_document_empty()
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    resources: page_prefix_resources_for_test(names),
  }
  let page_root = try! doc.add_pagetree([page])
  ignore(try! doc.add_root(page_root, []))
  doc
}

///|
fn page_prefix_resource_entry_for_test(name : String) -> @pdflite.PdfObject {
  PdfDictionary([(page_name_for_test(name), PdfDictionary([]))])
}

///|
fn page_prefix_full_resources_for_test(
  prefix? : String = "",
) -> @pdflite.PdfObject {
  @pdflite.pdf_dictionary([
    (
      page_name_for_test("/Font"),
      page_prefix_resource_entry_for_test("/" + prefix + "F0"),
    ),
    (
      page_name_for_test("/ExtGState"),
      page_prefix_resource_entry_for_test("/" + prefix + "GS1"),
    ),
    (
      page_name_for_test("/ColorSpace"),
      page_prefix_resource_entry_for_test("/" + prefix + "CS1"),
    ),
    (
      page_name_for_test("/Pattern"),
      page_prefix_resource_entry_for_test("/" + prefix + "P1"),
    ),
    (
      page_name_for_test("/Shading"),
      page_prefix_resource_entry_for_test("/" + prefix + "Sh1"),
    ),
    (
      page_name_for_test("/XObject"),
      page_prefix_resource_entry_for_test("/" + prefix + "Im1"),
    ),
    (
      page_name_for_test("/Properties"),
      page_prefix_resource_entry_for_test("/" + prefix + "Prop1"),
    ),
  ])
}

///|
fn page_prefix_content_ops_for_test(
  prefix? : String = "",
) -> Array[@pdflite.PdfContentOp] {
  [
    Op_Tf(page_name_for_test("/" + prefix + "F0"), 12.0),
    Op_gs(page_name_for_test("/" + prefix + "GS1")),
    Op_CS(page_name_for_test("/DeviceRGB")),
    Op_cs(page_name_for_test("/" + prefix + "CS1")),
    Op_SCNName(page_name_for_test("/" + prefix + "P1"), [0.2]),
    Op_scnName(page_name_for_test("/" + prefix + "P1"), [0.3]),
    Op_sh(page_name_for_test("/" + prefix + "Sh1")),
    Op_Do(page_name_for_test("/" + prefix + "Im1")),
    Op_DP(
      page_name_for_test("/Span"),
      PdfNameObject(page_name_for_test("/" + prefix + "Prop1")),
    ),
    Op_BDC(
      page_name_for_test("/Span"),
      PdfNameObject(page_name_for_test("/" + prefix + "Prop1")),
    ),
    Op_InlineImage(
      PdfDictionary([
        (
          page_name_for_test("/CS"),
          PdfNameObject(page_name_for_test("/" + prefix + "CS1")),
        ),
        (page_name_for_test("/W"), PdfInteger(1)),
      ]),
      None,
      @ascii.encode("x"),
    ),
  ]
}

///|
fn page_renumber_content_ops_for_test() -> Array[@pdflite.PdfContentOp] {
  [
    Op_Tf(page_name_for_test("/r1"), 12.0),
    Op_gs(page_name_for_test("/r2")),
    Op_CS(page_name_for_test("/DeviceRGB")),
    Op_cs(page_name_for_test("/r3")),
    Op_SCNName(page_name_for_test("/r4"), [0.2]),
    Op_scnName(page_name_for_test("/r4"), [0.3]),
    Op_sh(page_name_for_test("/r5")),
    Op_Do(page_name_for_test("/r6")),
    Op_DP(page_name_for_test("/Span"), PdfNameObject(page_name_for_test("/r7"))),
    Op_BDC(
      page_name_for_test("/Span"),
      PdfNameObject(page_name_for_test("/r7")),
    ),
    Op_InlineImage(
      PdfDictionary([
        (page_name_for_test("/CS"), PdfNameObject(page_name_for_test("/r3"))),
        (page_name_for_test("/W"), PdfInteger(1)),
      ]),
      None,
      @ascii.encode("x"),
    ),
  ]
}

///|
fn page_resource_value_for_test(
  resources : @pdflite.PdfObject,
  key : String,
) -> @pdflite.PdfObject? {
  resources.lookup_immediate(page_name_for_test(key))
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
test "PdfDocument add_pagetree balances larger page arrays" {
  let key_kids = page_name_for_test("/Kids")
  let key_count = page_name_for_test("/Count")
  let doc = @pdflite.pdf_document_empty()
  let source_pages = [ for i in 0..<12 => page_indexed_blank_for_test(i) ]
  let page_root = try! doc.add_pagetree(source_pages)
  ignore(try! doc.add_root(page_root, []))
  let root_node = doc.lookup_object_or_null(page_root)
  let root_kids = match root_node.lookup_immediate(key_kids) {
    Some(PdfArray(kids)) => kids
    _ => fail("expected root kids")
  }
  @test.assert_eq(root_node.lookup_immediate(key_count), Some(PdfInteger(12)))
  @test.assert_eq(root_kids.length(), 7)
  guard root_kids[0] is PdfIndirect(left_number) else {
    fail("expected left branch")
  }
  guard root_kids[6] is PdfIndirect(right_number) else {
    fail("expected right branch")
  }
  @test.assert_eq(
    doc.lookup_object_or_null(left_number).lookup_immediate(key_count),
    Some(PdfInteger(3)),
  )
  @test.assert_eq(
    doc.lookup_object_or_null(right_number).lookup_immediate(key_count),
    Some(PdfInteger(4)),
  )
  @test.assert_eq(try! doc.endpage_fast(), 12)
  let extracted = try! doc.pages_of_pagetree()
  @test.assert_eq(extracted.length(), 12)
  for i in 0..<12 {
    @test.assert_eq(extracted[i].mediabox, page_index_mediabox_for_test(i))
  }
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
test "PdfDocument shortest_unused_prefix scans page resource names" {
  @test.assert_eq(
    (try! @pdflite.pdf_minimum_valid_pdf()).shortest_unused_prefix(),
    "a",
  )
  @test.assert_eq(
    page_prefix_document_for_test(["/aFont", "/bState"]).shortest_unused_prefix(),
    "c",
  )
}

///|
test "PdfDocument shortest_unused_prefix preserves CamlPDF prefix sequence" {
  let names = [
    "/a", "/b", "/c", "/d", "/e", "/f", "/g", "/h", "/i", "/j", "/k", "/l", "/m",
    "/n", "/o", "/p", "/q", "/r", "/s", "/t", "/u", "/v", "/w", "/x", "/y", "/z",
  ]
  @test.assert_eq(
    page_prefix_document_for_test(names).shortest_unused_prefix(),
    "az",
  )
}

///|
test "PdfDocument add_prefix renames resources and content references" {
  let doc = @pdflite.pdf_document_empty()
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    resources: page_prefix_full_resources_for_test(),
    content: [
      try! @pdflite.pdf_content_stream_of_ops(
        page_prefix_content_ops_for_test(),
      ),
    ],
  }
  let page_root = try! doc.add_pagetree([page])
  ignore(try! doc.add_root(page_root, []))
  try! doc.add_prefix("p")
  let pages = try! doc.pages_of_pagetree()
  @test.assert_eq(
    pages[0].resources,
    page_prefix_full_resources_for_test(prefix="p"),
  )
  @test.assert_eq(
    try! doc.parse_content_ops(pages[0].content),
    page_prefix_content_ops_for_test(prefix="p"),
  )
}

///|
test "PdfDocument add_prefix rewrites shared content streams once" {
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(
    9,
    try! @pdflite.pdf_content_stream_of_ops([
      Op_Tf(page_name_for_test("/F0"), 12.0),
    ]),
  )
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    resources: page_prefix_resources_for_test(["/F0"]),
    content: [PdfIndirect(9)],
  }
  let page_root = try! doc.add_pagetree([page, page])
  ignore(try! doc.add_root(page_root, []))
  try! doc.add_prefix("p")
  @test.assert_eq(try! doc.parse_content_ops([PdfIndirect(9)]), [
    Op_Tf(page_name_for_test("/pF0"), 12.0),
  ])
}

///|
test "PdfDocument renumber_pages gives duplicate page resources distinct names" {
  let doc = @pdflite.pdf_document_empty()
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    resources: page_prefix_resources_for_test(["/F0"]),
    content: [
      try! @pdflite.pdf_content_stream_of_ops([
        Op_Tf(page_name_for_test("/F0"), 12.0),
      ]),
    ],
  }
  let pages = try! doc.renumber_pages([page, page])
  @test.assert_eq(pages.length(), 2)
  @test.assert_eq(
    page_resource_value_for_test(pages[0].resources, "/Font"),
    Some(page_prefix_resource_entry_for_test("/r1")),
  )
  @test.assert_eq(
    page_resource_value_for_test(pages[1].resources, "/Font"),
    Some(page_prefix_resource_entry_for_test("/r2")),
  )
  @test.assert_eq(
    page_resource_value_for_test(pages[0].resources, "/ColorSpace"),
    Some(PdfDictionary([])),
  )
  @test.assert_eq(try! doc.parse_content_ops(pages[0].content), [
    Op_Tf(page_name_for_test("/r1"), 12.0),
  ])
  @test.assert_eq(try! doc.parse_content_ops(pages[1].content), [
    Op_Tf(page_name_for_test("/r2"), 12.0),
  ])
}

///|
test "PdfDocument renumber_pages rewrites resource-backed content operators" {
  let doc = @pdflite.pdf_document_empty()
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    resources: page_prefix_full_resources_for_test(),
    content: [
      try! @pdflite.pdf_content_stream_of_ops(
        page_prefix_content_ops_for_test(),
      ),
    ],
  }
  let pages = try! doc.renumber_pages([page])
  @test.assert_eq(pages.length(), 1)
  @test.assert_eq(
    page_resource_value_for_test(pages[0].resources, "/Font"),
    Some(page_prefix_resource_entry_for_test("/r1")),
  )
  @test.assert_eq(
    page_resource_value_for_test(pages[0].resources, "/ExtGState"),
    Some(page_prefix_resource_entry_for_test("/r2")),
  )
  @test.assert_eq(
    page_resource_value_for_test(pages[0].resources, "/ColorSpace"),
    Some(page_prefix_resource_entry_for_test("/r3")),
  )
  @test.assert_eq(
    page_resource_value_for_test(pages[0].resources, "/Pattern"),
    Some(page_prefix_resource_entry_for_test("/r4")),
  )
  @test.assert_eq(
    page_resource_value_for_test(pages[0].resources, "/Shading"),
    Some(page_prefix_resource_entry_for_test("/r5")),
  )
  @test.assert_eq(
    page_resource_value_for_test(pages[0].resources, "/XObject"),
    Some(page_prefix_resource_entry_for_test("/r6")),
  )
  @test.assert_eq(
    page_resource_value_for_test(pages[0].resources, "/Properties"),
    Some(page_prefix_resource_entry_for_test("/r7")),
  )
  @test.assert_eq(
    try! doc.parse_content_ops(pages[0].content),
    page_renumber_content_ops_for_test(),
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
test "PdfDocument pdf_of_pages extracts pages in requested order" {
  let doc = @pdflite.pdf_document_empty()
  let page_root = try! doc.add_pagetree([
    page_indexed_blank_for_test(0),
    page_indexed_blank_for_test(1),
    page_indexed_blank_for_test(2),
  ])
  ignore(try! doc.add_root(page_root, []))
  let extracted = try! doc.pdf_of_pages([3, 1])
  @test.assert_eq(try! extracted.endpage(), 2)
  let pages = try! extracted.pages_of_pagetree()
  @test.assert_eq(pages.length(), 2)
  @test.assert_eq(pages[0].mediabox, page_index_mediabox_for_test(2))
  @test.assert_eq(pages[1].mediabox, page_index_mediabox_for_test(0))
  let reparsed = try! @pdflite.pdf_read_document_from_bytes(
    try! @pdflite.pdf_write_document(extracted),
  )
  let reparsed_pages = try! reparsed.pages_of_pagetree()
  @test.assert_eq(reparsed_pages.length(), 2)
  @test.assert_eq(reparsed_pages[0].mediabox, page_index_mediabox_for_test(2))
  @test.assert_eq(reparsed_pages[1].mediabox, page_index_mediabox_for_test(0))
}

///|
test "PdfDocument pdf_of_pages rejects empty and invalid ranges" {
  let doc = @pdflite.pdf_document_empty()
  let page_root = try! doc.add_pagetree([page_indexed_blank_for_test(0)])
  ignore(try! doc.add_root(page_root, []))
  let empty_page_numbers : Array[Int] = []
  let empty_result : Result[@pdflite.PdfDocument, Error] = try? doc.pdf_of_pages(
    empty_page_numbers,
  )
  guard empty_result is Err(@pdflite.PdfError::PageTreeExpected) else {
    fail("expected PageTreeExpected for empty range")
  }
  let invalid_result : Result[@pdflite.PdfDocument, Error] = try? doc.pdf_of_pages([
      2,
    ],
  )
  guard invalid_result is Err(@pdflite.PdfError::PageTreeExpected) else {
    fail("expected PageTreeExpected for invalid range")
  }
}

///|
test "PdfDocument remove_unreferenced drops detached objects" {
  let key_metadata = page_name_for_test("/Metadata")
  let doc = try! @pdflite.pdf_minimum_valid_pdf()
  let kept = doc.add_object(PdfString(@ascii.encode("kept")))
  let removed = doc.add_object(PdfString(@ascii.encode("removed")))
  doc.add_object_given_number(
    doc.root(),
    try! doc
    .lookup_object_or_null(doc.root())
    .add_dict_entry(key_metadata, PdfIndirect(kept)),
  )
  try! doc.remove_unreferenced()
  @test.assert_eq(
    doc.lookup_object_or_null(kept),
    PdfString(@ascii.encode("kept")),
  )
  @test.assert_eq(doc.lookup_object_or_null(removed), PdfNull)
  @test.assert_eq(try! doc.endpage(), 1)
}

///|
test "PdfDocument remove_unreferenced nullifies deleted page references" {
  let key_open_action = page_name_for_test("/OpenAction")
  let type_fit = page_name_for_test("/Fit")
  let doc = @pdflite.pdf_document_empty()
  let page_root = try! doc.add_pagetree([
    @pdflite.pdf_page_blank(@pdflite.paper_a4),
    { ..@pdflite.pdf_page_blank(@pdflite.paper_a4), rotate: Rotate90 },
  ])
  ignore(try! doc.add_root(page_root, []))
  let old_numbers = try! doc.page_reference_numbers()
  doc.add_object_given_number(
    doc.root(),
    try! doc
    .lookup_object_or_null(doc.root())
    .add_dict_entry(
      key_open_action,
      PdfArray([PdfIndirect(old_numbers[1]), PdfNameObject(type_fit)]),
    ),
  )
  let pages = try! doc.pages_of_pagetree()
  let changed = try! doc.change_pages([pages[0]])
  try! changed.remove_unreferenced()
  @test.assert_eq(try! changed.endpage(), 1)
  @test.assert_eq(changed.lookup_object_or_null(old_numbers[1]), PdfNull)
  @test.assert_eq(
    changed
    .lookup_object_or_null(changed.root())
    .lookup_immediate(key_open_action),
    Some(PdfArray([PdfNull, PdfNameObject(type_fit)])),
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
