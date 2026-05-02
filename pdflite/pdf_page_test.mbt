///|
fn page_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn page_rect_for_test(
  min_x : Double,
  min_y : Double,
  max_x : Double,
  max_y : Double,
) -> @pdflite.PdfRectangle {
  { min_x, min_y, max_x, max_y }
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
fn page_raw_stream_for_test(text : String) -> @pdflite.PdfObject {
  let data = @ascii.encode(text)
  @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (page_name_for_test("/Length"), PdfInteger(data.length())),
    ]),
    StreamGot(data),
  )
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
fn page_xobject_resources_for_test(
  entries : ArrayView[(@pdflite.PdfName, @pdflite.PdfObject)],
) -> @pdflite.PdfObject {
  @pdflite.pdf_dictionary([
    (page_name_for_test("/XObject"), @pdflite.pdf_dictionary(entries)),
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
fn page_annotation_numbers_for_test(
  page_object : @pdflite.PdfObject,
) -> Array[Int] {
  let numbers : Array[Int] = []
  match page_object.lookup_immediate(page_name_for_test("/Annots")) {
    Some(PdfArray(items)) =>
      for item in items {
        match item {
          PdfIndirect(number) => numbers.push(number)
          _ => ()
        }
      }
    _ => ()
  }
  numbers
}

///|
fn page_destination_entries_for_test(
  doc : @pdflite.PdfDocument,
) -> Array[(@pdflite.PdfBytes, @pdflite.PdfObject)] {
  match
    doc.lookup_chain(doc.lookup_object_or_null(doc.root()), [
      page_name_for_test("/Names"),
      page_name_for_test("/Dests"),
    ]) {
    Some(tree) => doc.read_name_tree(tree)
    None => []
  }
}

///|
fn page_catalog_destination_for_test(
  doc : @pdflite.PdfDocument,
  name : String,
) -> @pdflite.PdfObject? {
  match
    doc
    .lookup_object_or_null(doc.root())
    .lookup_immediate(page_name_for_test("/Dests")) {
    Some(PdfDictionary(entries)) =>
      for entry in entries {
        let (key, value) = entry
        if key == page_name_for_test(name) {
          break Some(value)
        }
      } nobreak {
        None
      }
    _ => None
  }
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
  let key_s = page_name_for_test("/S")
  let key_d = page_name_for_test("/D")
  let type_goto = page_name_for_test("/GoTo")
  let type_xyz = page_name_for_test("/XYZ")
  @test.assert_eq(try! doc.page_reference_numbers(), [3, 5])
  @test.assert_eq(try! doc.pages_of_pagetree_quick(), 2)
  @test.assert_eq(try! doc.endpage(), 2)
  @test.assert_eq(try! doc.endpage_fast(), 2)
  @test.assert_eq(try! doc.page_object_number(1), Some(3))
  @test.assert_eq(try! doc.page_object_number(2), Some(5))
  @test.assert_eq(try! doc.page_object_number(3), None)
  @test.assert_eq(
    try! doc.page_number_of_target(DestFit(TargetPageObject(5))),
    2,
  )
  @test.assert_eq(
    try! doc.page_number_of_target(
      DestAction(
        @pdflite.pdf_dictionary([
          (key_s, PdfNameObject(type_goto)),
          (
            key_d,
            PdfArray([
              PdfIndirect(3),
              PdfNameObject(type_xyz),
              PdfInteger(0),
              PdfInteger(0),
              PdfNull,
            ]),
          ),
        ]),
      ),
    ),
    1,
  )
  @test.assert_eq(try! doc.page_number_of_target(DestNull), 0)
  @test.assert_eq(
    try! doc.target_of_page_number(2),
    DestFit(TargetPageObject(5)),
  )
  @test.assert_eq(try! doc.target_of_page_number(3), DestNull)
}

///|
test "PdfDocument pages_of_pagetree_quick allows direct page dictionaries" {
  let key_type = page_name_for_test("/Type")
  let key_pages = page_name_for_test("/Pages")
  let key_kids = page_name_for_test("/Kids")
  let key_count = page_name_for_test("/Count")
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
      (
        key_kids,
        PdfArray([
          @pdflite.pdf_dictionary([
            (key_type, PdfNameObject(page_name_for_test("/Page"))),
          ]),
          @pdflite.pdf_dictionary([
            (key_type, PdfNameObject(page_name_for_test("/Pages"))),
            (
              key_kids,
              PdfArray([
                @pdflite.pdf_dictionary([
                  (key_type, PdfNameObject(page_name_for_test("/Page"))),
                ]),
              ]),
            ),
            (key_count, PdfInteger(1)),
          ]),
        ]),
      ),
      (key_count, PdfInteger(2)),
    ]),
  )
  @test.assert_eq(try! doc.pages_of_pagetree_quick(), 2)
  @test.assert_eq(try! doc.endpage(), 2)
}

///|
test "PdfDocument pages_of_pagetree_quick rejects malformed kids" {
  let key_type = page_name_for_test("/Type")
  let key_pages = page_name_for_test("/Pages")
  let key_kids = page_name_for_test("/Kids")
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
      (key_kids, PdfArray([PdfInteger(1)])),
    ]),
  )
  let result : Result[Int, Error] = try? doc.pages_of_pagetree_quick()
  guard result is Err(@pdflite.PdfError::PageTreeExpected) else {
    fail("expected PageTreeExpected")
  }
}

///|
test "PdfDocument page_number_of_target resolves named destinations" {
  let key_dests = page_name_for_test("/Dests")
  let key_names = page_name_for_test("/Names")
  let type_fit = page_name_for_test("/Fit")
  let named_destination = page_name_for_test("/Chapter")
  let string_destination = @ascii.encode("chapter")
  let doc = try! @pdflite.pdf_minimum_valid_pdf()
  let page_refs = try! doc.page_reference_numbers()
  let dest : @pdflite.PdfObject = PdfArray([
    PdfIndirect(page_refs[0]),
    PdfNameObject(type_fit),
  ])
  let tree = doc.build_name_tree([(string_destination, dest)])
  doc.add_object_given_number(
    doc.root(),
    try! doc
    .lookup_object_or_null(doc.root())
    .add_dict_entry(key_names, PdfDictionary([(key_dests, tree)])),
  )
  doc.add_object_given_number(
    doc.root(),
    try! doc
    .lookup_object_or_null(doc.root())
    .add_dict_entry(key_dests, PdfDictionary([(named_destination, dest)])),
  )
  @test.assert_eq(
    try! doc.page_number_of_target(DestString(string_destination)),
    1,
  )
  @test.assert_eq(
    try! doc.page_number_of_target(DestNamed(named_destination)),
    1,
  )
  @test.assert_eq(
    try! doc.page_number_of_target(DestString(@ascii.encode("missing"))),
    0,
  )
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
    page_rect_for_test(0.0, 0.0, 595.2765, 841.89105),
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
test "PdfDocument combine_pdf_resources unions known and unknown resource keys" {
  let doc = @pdflite.pdf_document_empty()
  let first = @pdflite.pdf_dictionary([
    (
      page_name_for_test("/ProcSet"),
      PdfArray([PdfNameObject(page_name_for_test("/PDF"))]),
    ),
    (
      page_name_for_test("/Font"),
      @pdflite.pdf_dictionary([(page_name_for_test("/F0"), PdfInteger(1))]),
    ),
    (
      page_name_for_test("/ColorSpace"),
      @pdflite.pdf_dictionary([
        (page_name_for_test("/CSA"), PdfNameObject(page_name_for_test("/RGB"))),
      ]),
    ),
  ])
  let second = @pdflite.pdf_dictionary([
    (page_name_for_test("/Custom"), PdfBoolean(true)),
    (
      page_name_for_test("/Font"),
      @pdflite.pdf_dictionary([(page_name_for_test("/F1"), PdfInteger(2))]),
    ),
    (
      page_name_for_test("/ColorSpace"),
      @pdflite.pdf_dictionary([
        (page_name_for_test("/CSB"), PdfNameObject(page_name_for_test("/CMYK"))),
      ]),
    ),
    (
      page_name_for_test("/Pattern"),
      @pdflite.pdf_dictionary([(page_name_for_test("/P1"), PdfNull)]),
    ),
  ])
  @test.assert_eq(
    doc.combine_pdf_resources(first, second),
    @pdflite.pdf_dictionary([
      (
        page_name_for_test("/ProcSet"),
        PdfArray([PdfNameObject(page_name_for_test("/PDF"))]),
      ),
      (page_name_for_test("/Custom"), PdfBoolean(true)),
      (
        page_name_for_test("/Font"),
        @pdflite.pdf_dictionary([
          (page_name_for_test("/F0"), PdfInteger(1)),
          (page_name_for_test("/F1"), PdfInteger(2)),
        ]),
      ),
      (
        page_name_for_test("/ColorSpace"),
        @pdflite.pdf_dictionary([
          (
            page_name_for_test("/CSA"),
            PdfNameObject(page_name_for_test("/RGB")),
          ),
          (
            page_name_for_test("/CSB"),
            PdfNameObject(page_name_for_test("/CMYK")),
          ),
        ]),
      ),
      (
        page_name_for_test("/Pattern"),
        @pdflite.pdf_dictionary([(page_name_for_test("/P1"), PdfNull)]),
      ),
    ]),
  )
}

///|
test "PdfDocument combine_pdf_resources resolves indirect subdictionaries" {
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(
    12,
    @pdflite.pdf_dictionary([(page_name_for_test("/F0"), PdfInteger(1))]),
  )
  @test.assert_eq(
    doc.combine_pdf_resources(
      @pdflite.pdf_dictionary([(page_name_for_test("/Font"), PdfIndirect(12))]),
      PdfInteger(0),
    ),
    @pdflite.pdf_dictionary([
      (
        page_name_for_test("/Font"),
        @pdflite.pdf_dictionary([(page_name_for_test("/F0"), PdfInteger(1))]),
      ),
    ]),
  )
}

///|
test "pdf_page_process_stub returns identity page matrix" {
  let (value, number, matrix) = try! @pdflite.pdf_page_process_stub(
    fn(n, p) { n + p },
    2,
    5,
  )
  @test.assert_eq(value, 7)
  @test.assert_eq(number, 2)
  @test.assert_eq(matrix, @pdflite.transform_identity_matrix)
}

///|
test "pdf_page_process_stub propagates callback errors" {
  let result : Result[(Int, Int, @pdflite.TransformMatrix), Error] = try? @pdflite.pdf_page_process_stub(
    fn(n, p) raise {
      if p == 0 {
        fail("bad page")
      }
      n / p
    },
    6,
    0,
  )
  guard result is Err(_) else { fail("expected callback failure") }
}

///|
test "PdfDocument process_xobjects rewrites form xobject streams" {
  let key_subtype = page_name_for_test("/Subtype")
  let key_filter = page_name_for_test("/Filter")
  let key_length = page_name_for_test("/Length")
  let key_keep = page_name_for_test("/Keep")
  let key_extra = page_name_for_test("/Extra")
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(
    20,
    @pdflite.pdf_stream(
      @pdflite.pdf_dictionary([
        (key_subtype, PdfNameObject(page_name_for_test("/Form"))),
        (key_filter, PdfNameObject(page_name_for_test("/FlateDecode"))),
        (key_length, PdfInteger(3)),
        (key_keep, PdfInteger(1)),
      ]),
      StreamGot(@ascii.encode("old")),
    ),
  )
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    resources: page_xobject_resources_for_test([
      (page_name_for_test("/Fm1"), PdfIndirect(20)),
    ]),
  }
  try! doc.process_xobjects(page, fn(_, _, streams) raise @pdflite.PdfError {
    if streams.length() < 0 {
      raise ParseStreamExpected
    }
    [
      @pdflite.pdf_stream(
        @pdflite.pdf_dictionary([
          (key_filter, PdfNameObject(page_name_for_test("/ASCIIHexDecode"))),
          (key_length, PdfInteger(2)),
          (key_extra, PdfInteger(7)),
        ]),
        StreamGot(@ascii.encode("BT")),
      ),
    ]
  })
  guard doc.lookup_object_or_null(20) is PdfStreamObject(stream) else {
    fail("expected form xobject stream")
  }
  @test.assert_eq(stream.data, StreamGot(@ascii.encode("BT")))
  @test.assert_eq(
    stream.dictionary.lookup_immediate(key_subtype),
    Some(PdfNameObject(page_name_for_test("/Form"))),
  )
  @test.assert_eq(stream.dictionary.lookup_immediate(key_filter), None)
  @test.assert_eq(
    stream.dictionary.lookup_immediate(key_length),
    Some(PdfInteger(2)),
  )
  @test.assert_eq(
    stream.dictionary.lookup_immediate(key_keep),
    Some(PdfInteger(1)),
  )
  @test.assert_eq(
    stream.dictionary.lookup_immediate(key_extra),
    Some(PdfInteger(7)),
  )
}

///|
test "PdfDocument process_xobjects skips non-form xobjects" {
  let key_subtype = page_name_for_test("/Subtype")
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(
    21,
    @pdflite.pdf_stream(
      @pdflite.pdf_dictionary([
        (key_subtype, PdfNameObject(page_name_for_test("/Image"))),
      ]),
      StreamGot(@ascii.encode("image")),
    ),
  )
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    resources: page_xobject_resources_for_test([
      (page_name_for_test("/Im1"), PdfIndirect(21)),
    ]),
  }
  let calls : Ref[Int] = { val: 0 }
  try! doc.process_xobjects(page, fn(_, _, streams) raise @pdflite.PdfError {
    if streams.length() < 0 {
      raise ParseStreamExpected
    }
    calls.val += 1
    []
  })
  @test.assert_eq(calls.val, 0)
  @test.assert_eq(
    doc.lookup_object_or_null(21),
    @pdflite.pdf_stream(
      @pdflite.pdf_dictionary([
        (key_subtype, PdfNameObject(page_name_for_test("/Image"))),
      ]),
      StreamGot(@ascii.encode("image")),
    ),
  )
}

///|
test "PdfDocument process_xobjects validates xobject resources" {
  let key_subtype = page_name_for_test("/Subtype")
  let doc = @pdflite.pdf_document_empty()
  let non_indirect_page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    resources: page_xobject_resources_for_test([
      (page_name_for_test("/Inline"), PdfDictionary([])),
    ]),
  }
  let non_indirect : Result[Unit, Error] = try? doc.process_xobjects(
    non_indirect_page,
    fn(_, _, streams) raise @pdflite.PdfError {
      if streams.length() < 0 {
        raise ParseStreamExpected
      }
      []
    },
  )
  guard non_indirect is Err(@pdflite.PdfError::DictionaryExpected) else {
    fail("expected DictionaryExpected")
  }
  doc.add_object_given_number(22, @pdflite.pdf_dictionary([]))
  let missing_subtype_page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    resources: page_xobject_resources_for_test([
      (page_name_for_test("/MissingSubtype"), PdfIndirect(22)),
    ]),
  }
  let missing_subtype : Result[Unit, Error] = try? doc.process_xobjects(
    missing_subtype_page,
    fn(_, _, streams) raise @pdflite.PdfError {
      if streams.length() < 0 {
        raise ParseStreamExpected
      }
      []
    },
  )
  guard missing_subtype is Err(@pdflite.PdfError::DictionaryKeyNotFound(_)) else {
    fail("expected DictionaryKeyNotFound")
  }
  doc.add_object_given_number(
    23,
    @pdflite.pdf_stream(
      @pdflite.pdf_dictionary([
        (key_subtype, PdfNameObject(page_name_for_test("/Form"))),
      ]),
      StreamGot(@ascii.encode("form")),
    ),
  )
  let bad_result_page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    resources: page_xobject_resources_for_test([
      (page_name_for_test("/Bad"), PdfIndirect(23)),
    ]),
  }
  let bad_result : Result[Unit, Error] = try? doc.process_xobjects(
    bad_result_page,
    fn(_, _, streams) raise @pdflite.PdfError {
      if streams.length() < 0 {
        raise ParseStreamExpected
      }
      [PdfDictionary([])]
    },
  )
  guard bad_result is Err(@pdflite.PdfError::ParseStreamExpected) else {
    fail("expected ParseStreamExpected")
  }
  let bad_length : Result[Unit, Error] = try? doc.process_xobjects(
    bad_result_page,
    fn(_, _, streams) raise @pdflite.PdfError {
      if streams.length() < 0 {
        raise ParseStreamExpected
      }
      []
    },
  )
  guard bad_length is Err(@pdflite.PdfError::ParseStreamExpected) else {
    fail("expected ParseStreamExpected for bad callback length")
  }
  let bad_dictionary : Result[Unit, Error] = try? doc.process_xobjects(
    bad_result_page,
    fn(_, _, streams) raise @pdflite.PdfError {
      if streams.length() < 0 {
        raise ParseStreamExpected
      }
      [@pdflite.pdf_stream(PdfInteger(1), StreamGot(@ascii.encode("bad")))]
    },
  )
  guard bad_dictionary is Err(@pdflite.PdfError::DictionaryExpected) else {
    fail("expected DictionaryExpected for bad stream dictionary")
  }
  doc.add_object_given_number(
    24,
    @pdflite.pdf_dictionary([
      (key_subtype, PdfNameObject(page_name_for_test("/Form"))),
    ]),
  )
  let non_stream_page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    resources: page_xobject_resources_for_test([
      (page_name_for_test("/NonStream"), PdfIndirect(24)),
    ]),
  }
  let non_stream : Result[Unit, Error] = try? doc.process_xobjects(
    non_stream_page,
    fn(_, _, streams) raise @pdflite.PdfError {
      if streams.length() < 0 {
        raise ParseStreamExpected
      }
      []
    },
  )
  guard non_stream is Err(@pdflite.PdfError::ParseStreamExpected) else {
    fail("expected ParseStreamExpected for non-stream form")
  }
  let calls : Ref[Int] = { val: 0 }
  try! doc.process_xobjects(@pdflite.pdf_page_blank(@pdflite.paper_a4), fn(
    _,
    _,
    streams,
  ) raise @pdflite.PdfError {
    if streams.length() < 0 {
      raise ParseStreamExpected
    }
    calls.val += 1
    []
  })
  @test.assert_eq(calls.val, 0)
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
test "PdfDocument merge_content_streams combines page content arrays" {
  let key_type = page_name_for_test("/Type")
  let key_contents = page_name_for_test("/Contents")
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(
    1,
    @pdflite.pdf_dictionary([
      (key_type, PdfNameObject(page_name_for_test("/Page"))),
      (key_contents, PdfArray([PdfIndirect(2), PdfIndirect(3)])),
    ]),
  )
  doc.add_object_given_number(2, page_raw_stream_for_test("BT"))
  doc.add_object_given_number(3, page_raw_stream_for_test("ET"))
  try! doc.merge_content_streams()
  guard doc.lookup_object_or_null(1).lookup_immediate(key_contents)
    is Some(PdfIndirect(merged)) else {
    fail("expected merged content stream")
  }
  @test.assert_eq(merged == 2 || merged == 3, false)
  @test.assert_eq(try! doc.parse_content_ops([PdfIndirect(merged)]), [
    Op_BT,
    Op_ET,
  ])
}

///|
test "PdfDocument merge_content_streams leaves single content arrays unchanged" {
  let key_type = page_name_for_test("/Type")
  let key_contents = page_name_for_test("/Contents")
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(
    1,
    @pdflite.pdf_dictionary([
      (key_type, PdfNameObject(page_name_for_test("/Page"))),
      (key_contents, PdfArray([PdfIndirect(2)])),
    ]),
  )
  doc.add_object_given_number(2, page_raw_stream_for_test("BT ET"))
  try! doc.merge_content_streams()
  @test.assert_eq(
    doc.lookup_object_or_null(1).lookup_immediate(key_contents),
    Some(PdfArray([PdfIndirect(2)])),
  )
}

///|
test "PdfDocument merge_content_streams rejects non-stream content arrays" {
  let key_type = page_name_for_test("/Type")
  let key_contents = page_name_for_test("/Contents")
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(
    1,
    @pdflite.pdf_dictionary([
      (key_type, PdfNameObject(page_name_for_test("/Page"))),
      (key_contents, PdfArray([PdfInteger(1), PdfIndirect(2)])),
    ]),
  )
  doc.add_object_given_number(2, page_raw_stream_for_test("BT ET"))
  let result : Result[Unit, Error] = try? doc.merge_content_streams()
  guard result is Err(@pdflite.PdfError::ParseStreamExpected) else {
    fail("expected ParseStreamExpected")
  }
}

///|
test "PdfDocument add_prefix keeps parseable content arrays split" {
  let key_type = page_name_for_test("/Type")
  let key_resources = page_name_for_test("/Resources")
  let key_contents = page_name_for_test("/Contents")
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(
    1,
    @pdflite.pdf_dictionary([
      (key_type, PdfNameObject(page_name_for_test("/Page"))),
      (key_resources, page_prefix_resources_for_test(["/F0"])),
      (key_contents, PdfArray([PdfIndirect(2), PdfIndirect(3)])),
    ]),
  )
  doc.add_object_given_number(2, page_raw_stream_for_test("BT"))
  doc.add_object_given_number(3, page_raw_stream_for_test("ET"))
  try! doc.add_prefix("p")
  let page = doc.lookup_object_or_null(1)
  @test.assert_eq(
    page.lookup_immediate(key_contents),
    Some(PdfArray([PdfIndirect(2), PdfIndirect(3)])),
  )
  guard page.lookup_immediate(key_resources) is Some(resources) else {
    fail("expected prefixed resources")
  }
  @test.assert_eq(
    page_resource_value_for_test(resources, "/Font"),
    Some(page_prefix_resource_entry_for_test("/pF0")),
  )
}

///|
test "PdfDocument add_prefix merges split content arrays before rewriting" {
  let key_type = page_name_for_test("/Type")
  let key_resources = page_name_for_test("/Resources")
  let key_contents = page_name_for_test("/Contents")
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(
    1,
    @pdflite.pdf_dictionary([
      (key_type, PdfNameObject(page_name_for_test("/Page"))),
      (key_resources, page_prefix_resources_for_test(["/F0"])),
      (key_contents, PdfArray([PdfIndirect(2), PdfIndirect(3)])),
    ]),
  )
  doc.add_object_given_number(2, page_raw_stream_for_test("BT /F0"))
  doc.add_object_given_number(3, page_raw_stream_for_test("12 Tf ET"))
  try! doc.add_prefix("p")
  let page = doc.lookup_object_or_null(1)
  guard page.lookup_immediate(key_contents) is Some(PdfIndirect(merged)) else {
    fail("expected merged content stream")
  }
  guard page.lookup_immediate(key_resources) is Some(resources) else {
    fail("expected prefixed resources")
  }
  @test.assert_eq(
    page_resource_value_for_test(resources, "/Font"),
    Some(page_prefix_resource_entry_for_test("/pF0")),
  )
  @test.assert_eq(try! doc.parse_content_ops([PdfIndirect(merged)]), [
    Op_BT,
    Op_Tf(page_name_for_test("/pF0"), 12.0),
    Op_ET,
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
test "PdfDocument replace_inherit materializes parent page attributes" {
  let key_type = page_name_for_test("/Type")
  let key_parent = page_name_for_test("/Parent")
  let key_resources = page_name_for_test("/Resources")
  let key_mediabox = page_name_for_test("/MediaBox")
  let key_cropbox = page_name_for_test("/CropBox")
  let key_rotate = page_name_for_test("/Rotate")
  let parent_mediabox : @pdflite.PdfObject = PdfArray([
    PdfInteger(0),
    PdfInteger(0),
    PdfInteger(300),
    PdfInteger(400),
  ])
  let parent_cropbox : @pdflite.PdfObject = PdfArray([
    PdfInteger(10),
    PdfInteger(20),
    PdfInteger(290),
    PdfInteger(380),
  ])
  let resource_object = @pdflite.pdf_dictionary([
    (page_name_for_test("/Font"), PdfDictionary([])),
  ])
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(8, resource_object)
  doc.add_object_given_number(
    2,
    @pdflite.pdf_dictionary([
      (key_type, PdfNameObject(page_name_for_test("/Pages"))),
      (key_mediabox, parent_mediabox),
      (key_cropbox, parent_cropbox),
      (key_rotate, PdfInteger(90)),
      (key_resources, PdfIndirect(8)),
    ]),
  )
  doc.add_object_given_number(
    3,
    @pdflite.pdf_dictionary([
      (key_type, PdfNameObject(page_name_for_test("/Page"))),
      (key_parent, PdfIndirect(2)),
      (key_rotate, PdfInteger(270)),
    ]),
  )
  try! doc.replace_inherit([3])
  let page = doc.lookup_object_or_null(3)
  @test.assert_eq(page.lookup_immediate(key_mediabox), Some(parent_mediabox))
  @test.assert_eq(page.lookup_immediate(key_cropbox), Some(parent_cropbox))
  @test.assert_eq(page.lookup_immediate(key_rotate), Some(PdfInteger(270)))
  @test.assert_eq(page.lookup_immediate(key_resources), Some(PdfIndirect(8)))
  @test.assert_eq(doc.lookup_object_or_null(8), resource_object)
}

///|
test "PdfDocument replace_inherit walks parent chain" {
  let key_type = page_name_for_test("/Type")
  let key_parent = page_name_for_test("/Parent")
  let key_mediabox = page_name_for_test("/MediaBox")
  let inherited_mediabox : @pdflite.PdfObject = PdfArray([
    PdfInteger(1),
    PdfInteger(2),
    PdfInteger(500),
    PdfInteger(600),
  ])
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(
    2,
    @pdflite.pdf_dictionary([
      (key_type, PdfNameObject(page_name_for_test("/Pages"))),
      (key_mediabox, inherited_mediabox),
    ]),
  )
  doc.add_object_given_number(
    4,
    @pdflite.pdf_dictionary([
      (key_type, PdfNameObject(page_name_for_test("/Pages"))),
      (key_parent, PdfIndirect(2)),
    ]),
  )
  doc.add_object_given_number(
    5,
    @pdflite.pdf_dictionary([
      (key_type, PdfNameObject(page_name_for_test("/Page"))),
      (key_parent, PdfIndirect(4)),
    ]),
  )
  try! doc.replace_inherit([5, 999])
  @test.assert_eq(
    doc.lookup_object_or_null(5).lookup_immediate(key_mediabox),
    Some(inherited_mediabox),
  )
  @test.assert_eq(doc.lookup_object_or_null(999), PdfNull)
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
test "PdfDocument prepend_operators parses inline image resource color spaces" {
  let doc = @pdflite.pdf_document_empty()
  let resources = @pdflite.pdf_dictionary([
    (
      page_name_for_test("/ColorSpace"),
      @pdflite.pdf_dictionary([
        (page_name_for_test("/CS1"), PdfNameObject(page_name_for_test("/RGB"))),
      ]),
    ),
  ])
  let data = @ascii.encode("BI /W 2 /H 1 /BPC 8 /CS /CS1 ID A EI B EI Q")
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    resources,
    content: [
      @pdflite.pdf_stream(
        @pdflite.pdf_dictionary([
          (page_name_for_test("/Length"), PdfInteger(data.length())),
        ]),
        StreamGot(data),
      ),
    ],
  }
  let updated = try! doc.prepend_operators(page, [Op_q])
  @test.assert_eq(
    try! doc.parse_content_ops_with_resources(resources, updated.content),
    [
      Op_q,
      Op_InlineImage(
        @pdflite.pdf_dictionary([
          (page_name_for_test("/W"), PdfInteger(2)),
          (page_name_for_test("/H"), PdfInteger(1)),
          (page_name_for_test("/BPC"), PdfInteger(8)),
          (page_name_for_test("/CS"), PdfNameObject(page_name_for_test("/CS1"))),
        ]),
        None,
        @ascii.encode("A EI B"),
      ),
      Op_Q,
    ],
  )
}

///|
test "PdfDocument prepend_operators falls back for missing inline image resources" {
  let doc = @pdflite.pdf_document_empty()
  let data = @ascii.encode("BI /W 1 /H 1 /BPC 8 /CS /Missing ID abc EI")
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    content: [
      @pdflite.pdf_stream(
        @pdflite.pdf_dictionary([
          (page_name_for_test("/Length"), PdfInteger(data.length())),
        ]),
        StreamGot(data),
      ),
    ],
  }
  let updated = try! doc.prepend_operators(page, [Op_q])
  @test.assert_eq(try! doc.parse_content_ops(updated.content), [
    Op_q,
    Op_InlineImage(
      @pdflite.pdf_dictionary([
        (page_name_for_test("/W"), PdfInteger(1)),
        (page_name_for_test("/H"), PdfInteger(1)),
        (page_name_for_test("/BPC"), PdfInteger(8)),
        (
          page_name_for_test("/CS"),
          PdfNameObject(page_name_for_test("/Missing")),
        ),
      ]),
      None,
      @ascii.encode("abc"),
    ),
  ])
}

///|
test "PdfDocument prepend_operators propagates non-colour parse errors" {
  let doc = @pdflite.pdf_document_empty()
  let data = @ascii.encode("1 2")
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    content: [
      @pdflite.pdf_stream(
        @pdflite.pdf_dictionary([
          (page_name_for_test("/Length"), PdfInteger(data.length())),
        ]),
        StreamGot(data),
      ),
    ],
  }
  let result : Result[@pdflite.PdfPage, Error] = try? doc.prepend_operators(
    page,
    [Op_q],
  )
  guard result is Err(@pdflite.PdfError::ContentOperatorExpected) else {
    fail("expected ContentOperatorExpected")
  }
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
test "pdftest-style content parse rewrite change_pages round trip" {
  let doc = @pdflite.pdf_document_empty()
  let ops = page_hello_ops_for_test()
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    content: [
      try! @pdflite.pdf_content_stream_of_ops(ops[0:3]),
      try! @pdflite.pdf_content_stream_of_ops(ops[3:ops.length()]),
    ],
    resources: page_hello_resources_for_test(),
  }
  let page_root = try! doc.add_pagetree([page])
  ignore(try! doc.add_root(page_root, []))
  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    try! @pdflite.pdf_write_document(doc),
  )
  let parsed_pages = try! parsed.pages_of_pagetree()
  let rewritten_pages : Array[@pdflite.PdfPage] = []
  for parsed_page in parsed_pages {
    let parsed_ops = try! parsed.parse_content_ops(parsed_page.content)
    rewritten_pages.push({
      ..parsed_page,
      content: [try! @pdflite.pdf_content_stream_of_ops(parsed_ops)],
    })
  }
  let changed = try! parsed.change_pages(rewritten_pages)
  try! changed.remove_unreferenced()
  let reparsed = try! @pdflite.pdf_read_document_from_bytes(
    try! @pdflite.pdf_write_document(changed),
  )
  let output_pages = try! reparsed.pages_of_pagetree()
  @test.assert_eq(output_pages.length(), 1)
  @test.assert_eq(output_pages[0].content.length(), 1)
  @test.assert_eq(
    try! reparsed.parse_content_ops(output_pages[0].content),
    page_hello_ops_for_test(),
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
test "PdfDocument change_pages transforms bookmark destinations with matrices" {
  let doc = @pdflite.pdf_document_empty()
  let page_root = try! doc.add_pagetree([
    @pdflite.pdf_page_blank(@pdflite.paper_a4),
  ])
  ignore(try! doc.add_root(page_root, []))
  let old_numbers = try! doc.page_reference_numbers()
  let bookmarked = try! doc.add_bookmarks([
    {
      level: 0,
      text: @ascii.encode("Top"),
      target: DestXYZ(
        TargetPageObject(old_numbers[0]),
        Some(1.0),
        Some(2.0),
        None,
      ),
      is_open: false,
      colour: @pdflite.pdf_bookmark_black,
      flags: 0,
    },
  ])
  let changed = try! bookmarked.change_pages(
    try! bookmarked.pages_of_pagetree(),
    change_references=true,
    matrices=[(1, @pdflite.transform_translate(10.0, 20.0))],
  )
  let new_numbers = try! changed.page_reference_numbers()
  @test.assert_eq(try! changed.read_bookmarks(preserve_actions=true), [
    {
      level: 0,
      text: @ascii.encode("Top"),
      target: DestXYZ(
        TargetPageObject(new_numbers[0]),
        Some(11.0),
        Some(22.0),
        None,
      ),
      is_open: false,
      colour: @pdflite.pdf_bookmark_black,
      flags: 0,
    },
  ])
}

///|
test "PdfDocument change_pages transforms link annotations and open action" {
  let key_annots = page_name_for_test("/Annots")
  let key_subtype = page_name_for_test("/Subtype")
  let key_dest = page_name_for_test("/Dest")
  let key_action = page_name_for_test("/A")
  let key_open_action = page_name_for_test("/OpenAction")
  let key_s = page_name_for_test("/S")
  let key_d = page_name_for_test("/D")
  let type_link = page_name_for_test("/Link")
  let type_goto = page_name_for_test("/GoTo")
  let type_xyz = page_name_for_test("/XYZ")
  let direct_annotation_number = 20
  let action_annotation_number = 21
  let annotation_array_number = 22
  let doc = @pdflite.pdf_document_empty()
  let page_root = try! doc.add_pagetree([
    @pdflite.pdf_page_blank(@pdflite.paper_a4),
  ])
  ignore(try! doc.add_root(page_root, []))
  let old_numbers = try! doc.page_reference_numbers()
  doc.add_object_given_number(
    old_numbers[0],
    try! doc
    .lookup_object_or_null(old_numbers[0])
    .add_dict_entry(key_annots, PdfIndirect(annotation_array_number)),
  )
  doc.add_object_given_number(
    annotation_array_number,
    PdfArray([
      PdfIndirect(direct_annotation_number),
      PdfIndirect(action_annotation_number),
      @pdflite.pdf_dictionary([
        (key_subtype, PdfNameObject(type_link)),
        (
          key_dest,
          PdfArray([
            PdfIndirect(old_numbers[0]),
            PdfNameObject(type_xyz),
            PdfInteger(7),
            PdfInteger(8),
            PdfNull,
          ]),
        ),
      ]),
      @pdflite.pdf_dictionary([
        (key_subtype, PdfNameObject(type_link)),
        (
          key_action,
          @pdflite.pdf_dictionary([
            (key_s, PdfNameObject(type_goto)),
            (
              key_d,
              PdfArray([
                PdfIndirect(old_numbers[0]),
                PdfNameObject(type_xyz),
                PdfInteger(9),
                PdfInteger(10),
                PdfNull,
              ]),
            ),
          ]),
        ),
      ]),
    ]),
  )
  doc.add_object_given_number(
    direct_annotation_number,
    @pdflite.pdf_dictionary([
      (key_subtype, PdfNameObject(type_link)),
      (
        key_dest,
        PdfArray([
          PdfIndirect(old_numbers[0]),
          PdfNameObject(type_xyz),
          PdfInteger(3),
          PdfInteger(4),
          PdfNull,
        ]),
      ),
    ]),
  )
  doc.add_object_given_number(
    action_annotation_number,
    @pdflite.pdf_dictionary([
      (key_subtype, PdfNameObject(type_link)),
      (
        key_action,
        @pdflite.pdf_dictionary([
          (key_s, PdfNameObject(type_goto)),
          (
            key_d,
            PdfArray([
              PdfIndirect(old_numbers[0]),
              PdfNameObject(type_xyz),
              PdfInteger(5),
              PdfInteger(6),
              PdfNull,
            ]),
          ),
        ]),
      ),
    ]),
  )
  doc.add_object_given_number(
    doc.root(),
    try! doc
    .lookup_object_or_null(doc.root())
    .add_dict_entry(
      key_open_action,
      PdfArray([
        PdfIndirect(old_numbers[0]),
        PdfNameObject(type_xyz),
        PdfInteger(1),
        PdfInteger(2),
        PdfNull,
      ]),
    ),
  )
  let changed = try! doc.change_pages(
    try! doc.pages_of_pagetree(),
    change_references=true,
    matrices=[(1, @pdflite.transform_translate(10.0, 20.0))],
  )
  let new_numbers = try! changed.page_reference_numbers()
  @test.assert_eq(
    changed
    .lookup_object_or_null(direct_annotation_number)
    .lookup_immediate(key_dest),
    Some(
      PdfArray([
        PdfIndirect(new_numbers[0]),
        PdfNameObject(type_xyz),
        PdfReal(13.0),
        PdfReal(24.0),
        PdfNull,
      ]),
    ),
  )
  match
    changed
    .lookup_object_or_null(action_annotation_number)
    .lookup_immediate(key_action) {
    Some(PdfDictionary(_) as action) =>
      @test.assert_eq(
        action.lookup_immediate(key_d),
        Some(
          PdfArray([
            PdfIndirect(new_numbers[0]),
            PdfNameObject(type_xyz),
            PdfReal(15.0),
            PdfReal(26.0),
            PdfNull,
          ]),
        ),
      )
    _ => fail("expected transformed link action")
  }
  @test.assert_eq(
    changed.lookup_object_or_null(new_numbers[0]).lookup_immediate(key_annots),
    Some(PdfIndirect(annotation_array_number)),
  )
  match changed.lookup_object_or_null(annotation_array_number) {
    PdfArray(
      [
        PdfIndirect(_),
        PdfIndirect(_),
        PdfDictionary(_) as direct_dest_annotation,
        PdfDictionary(_) as direct_action_annotation,
      ]
    ) => {
      @test.assert_eq(
        direct_dest_annotation.lookup_immediate(key_dest),
        Some(
          PdfArray([
            PdfIndirect(new_numbers[0]),
            PdfNameObject(type_xyz),
            PdfReal(17.0),
            PdfReal(28.0),
            PdfNull,
          ]),
        ),
      )
      match direct_action_annotation.lookup_immediate(key_action) {
        Some(PdfDictionary(_) as action) =>
          @test.assert_eq(
            action.lookup_immediate(key_d),
            Some(
              PdfArray([
                PdfIndirect(new_numbers[0]),
                PdfNameObject(type_xyz),
                PdfReal(19.0),
                PdfReal(30.0),
                PdfNull,
              ]),
            ),
          )
        _ => fail("expected transformed direct link action")
      }
    }
    _ => fail("expected direct link annotations in indirect annotation array")
  }
  @test.assert_eq(
    changed
    .lookup_object_or_null(changed.root())
    .lookup_immediate(key_open_action),
    Some(
      PdfArray([
        PdfIndirect(new_numbers[0]),
        PdfNameObject(type_xyz),
        PdfReal(11.0),
        PdfReal(22.0),
        PdfNull,
      ]),
    ),
  )
}

///|
test "PdfDocument change_pages transforms named destination definitions" {
  let key_names = page_name_for_test("/Names")
  let key_dests = page_name_for_test("/Dests")
  let type_xyz = page_name_for_test("/XYZ")
  let type_fith = page_name_for_test("/FitH")
  let named_destination = page_name_for_test("/Chapter")
  let string_destination = @ascii.encode("chapter")
  let doc = @pdflite.pdf_document_empty()
  let page_root = try! doc.add_pagetree([
    @pdflite.pdf_page_blank(@pdflite.paper_a4),
  ])
  ignore(try! doc.add_root(page_root, []))
  let old_numbers = try! doc.page_reference_numbers()
  let dest_tree = doc.build_name_tree([
    (
      string_destination,
      PdfArray([
        PdfIndirect(old_numbers[0]),
        PdfNameObject(type_xyz),
        PdfInteger(1),
        PdfInteger(2),
        PdfNull,
      ]),
    ),
  ])
  doc.add_object_given_number(
    doc.root(),
    try! doc
    .lookup_object_or_null(doc.root())
    .add_dict_entry(key_names, PdfDictionary([(key_dests, dest_tree)])),
  )
  doc.add_object_given_number(
    doc.root(),
    try! doc
    .lookup_object_or_null(doc.root())
    .add_dict_entry(
      key_dests,
      PdfDictionary([
        (
          named_destination,
          PdfArray([
            PdfIndirect(old_numbers[0]),
            PdfNameObject(type_fith),
            PdfInteger(5),
          ]),
        ),
      ]),
    ),
  )
  let bookmarked = try! doc.add_bookmarks([
    {
      level: 0,
      text: @ascii.encode("Named"),
      target: DestNamed(named_destination),
      is_open: false,
      colour: @pdflite.pdf_bookmark_black,
      flags: 0,
    },
    {
      level: 0,
      text: @ascii.encode("String"),
      target: DestString(string_destination),
      is_open: false,
      colour: @pdflite.pdf_bookmark_black,
      flags: 0,
    },
  ])
  let changed = try! bookmarked.change_pages(
    try! bookmarked.pages_of_pagetree(),
    change_references=true,
    matrices=[(1, @pdflite.transform_translate(10.0, 20.0))],
  )
  let new_numbers = try! changed.page_reference_numbers()
  @test.assert_eq(page_destination_entries_for_test(changed), [
    (
      string_destination,
      PdfArray([
        PdfIndirect(new_numbers[0]),
        PdfNameObject(type_xyz),
        PdfReal(11.0),
        PdfReal(22.0),
        PdfNull,
      ]),
    ),
  ])
  @test.assert_eq(
    page_catalog_destination_for_test(changed, "/Chapter"),
    Some(
      PdfArray([
        PdfIndirect(new_numbers[0]),
        PdfNameObject(type_fith),
        PdfReal(25.0),
      ]),
    ),
  )
  @test.assert_eq(try! changed.read_bookmarks(), [
    {
      level: 0,
      text: @ascii.encode("Named"),
      target: DestFitH(TargetPageObject(new_numbers[0]), Some(25.0)),
      is_open: false,
      colour: @pdflite.pdf_bookmark_black,
      flags: 0,
    },
    {
      level: 0,
      text: @ascii.encode("String"),
      target: DestXYZ(
        TargetPageObject(new_numbers[0]),
        Some(11.0),
        Some(22.0),
        None,
      ),
      is_open: false,
      colour: @pdflite.pdf_bookmark_black,
      flags: 0,
    },
  ])
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
test "PdfDocument change_pages accepts explicit serial reference changes" {
  let key_open_action = page_name_for_test("/OpenAction")
  let type_fit = page_name_for_test("/Fit")
  let doc = @pdflite.pdf_document_empty()
  let page_root = try! doc.add_pagetree([
    page_indexed_blank_for_test(0),
    page_indexed_blank_for_test(1),
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
  let changed = try! doc.change_pages(
    [page_indexed_blank_for_test(9)],
    change_references=true,
    changes=[(2, 1)],
  )
  let new_numbers = try! changed.page_reference_numbers()
  @test.assert_eq(new_numbers.length(), 1)
  @test.assert_eq(
    changed
    .lookup_object_or_null(changed.root())
    .lookup_immediate(key_open_action),
    Some(PdfArray([PdfIndirect(new_numbers[0]), PdfNameObject(type_fit)])),
  )

  let bad_old : Result[@pdflite.PdfDocument, Error] = try? doc.change_pages(
    [page_indexed_blank_for_test(9)],
    change_references=true,
    changes=[(3, 1)],
  )
  guard bad_old is Err(@pdflite.PdfError::PageTreeExpected) else {
    fail("expected PageTreeExpected for bad old serial")
  }
  let bad_new : Result[@pdflite.PdfDocument, Error] = try? doc.change_pages(
    [page_indexed_blank_for_test(9)],
    change_references=true,
    changes=[(1, 2)],
  )
  guard bad_new is Err(@pdflite.PdfError::PageTreeExpected) else {
    fail("expected PageTreeExpected for bad new serial")
  }
}

///|
test "PdfDocument change_pages skips bookmark matrices when page count changes" {
  let key_open_action = page_name_for_test("/OpenAction")
  let type_xyz = page_name_for_test("/XYZ")
  let doc = @pdflite.pdf_document_empty()
  let page_root = try! doc.add_pagetree([
    page_indexed_blank_for_test(0),
    page_indexed_blank_for_test(1),
  ])
  ignore(try! doc.add_root(page_root, []))
  let old_numbers = try! doc.page_reference_numbers()
  doc.add_object_given_number(
    doc.root(),
    try! doc
    .lookup_object_or_null(doc.root())
    .add_dict_entry(
      key_open_action,
      PdfArray([
        PdfIndirect(old_numbers[1]),
        PdfNameObject(type_xyz),
        PdfInteger(1),
        PdfInteger(2),
        PdfNull,
      ]),
    ),
  )
  let bookmarked = try! doc.add_bookmarks([
    {
      level: 0,
      text: @ascii.encode("Second"),
      target: DestXYZ(
        TargetPageObject(old_numbers[1]),
        Some(5.0),
        Some(6.0),
        None,
      ),
      is_open: false,
      colour: @pdflite.pdf_bookmark_black,
      flags: 0,
    },
  ])
  let changed = try! bookmarked.change_pages(
    [page_indexed_blank_for_test(9)],
    change_references=true,
    changes=[(2, 1)],
    matrices=[(1, @pdflite.transform_translate(10.0, 20.0))],
  )
  let new_numbers = try! changed.page_reference_numbers()
  @test.assert_eq(new_numbers.length(), 1)
  @test.assert_eq(try! changed.read_bookmarks(preserve_actions=true), [
    {
      level: 0,
      text: @ascii.encode("Second"),
      target: DestXYZ(
        TargetPageObject(new_numbers[0]),
        Some(5.0),
        Some(6.0),
        None,
      ),
      is_open: false,
      colour: @pdflite.pdf_bookmark_black,
      flags: 0,
    },
  ])
  @test.assert_eq(
    changed
    .lookup_object_or_null(changed.root())
    .lookup_immediate(key_open_action),
    Some(
      PdfArray([
        PdfIndirect(new_numbers[0]),
        PdfNameObject(type_xyz),
        PdfReal(11.0),
        PdfReal(22.0),
        PdfNull,
      ]),
    ),
  )
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
test "PdfDocument pdf_of_pages repeats selected pages with distinct objects" {
  let key_parent = page_name_for_test("/Parent")
  let key_kids = page_name_for_test("/Kids")
  let doc = @pdflite.pdf_document_empty()
  let page_root = try! doc.add_pagetree([
    page_indexed_blank_for_test(0),
    page_indexed_blank_for_test(1),
  ])
  ignore(try! doc.add_root(page_root, []))
  let extracted = try! doc.pdf_of_pages([1, 1])
  let page_refs = try! extracted.page_reference_numbers()
  @test.assert_eq(page_refs.length(), 2)
  @test.assert_eq(page_refs[0] == page_refs[1], false)
  let pages = try! extracted.pages_of_pagetree()
  @test.assert_eq(pages[0].mediabox, page_index_mediabox_for_test(0))
  @test.assert_eq(pages[1].mediabox, page_index_mediabox_for_test(0))
  guard extracted
    .lookup_object_or_null(page_refs[0])
    .lookup_immediate(key_parent)
    is Some(PdfIndirect(parent_number)) else {
    fail("expected first page parent")
  }
  @test.assert_eq(
    extracted.lookup_object_or_null(page_refs[1]).lookup_immediate(key_parent),
    Some(PdfIndirect(parent_number)),
  )
  @test.assert_eq(
    extracted.lookup_object_or_null(parent_number).lookup_immediate(key_kids),
    Some(PdfArray([PdfIndirect(page_refs[0]), PdfIndirect(page_refs[1])])),
  )
}

///|
test "PdfDocument pdf_of_pages handles page labels" {
  let doc = @pdflite.pdf_document_empty()
  let page_root = try! doc.add_pagetree([
    page_indexed_blank_for_test(0),
    page_indexed_blank_for_test(1),
    page_indexed_blank_for_test(2),
  ])
  ignore(try! doc.add_root(page_root, []))
  let labelled = try! doc.write_page_labels([
    {
      label_style: PageLabelLowercaseRoman,
      label_prefix: Some(@ascii.encode("intro-")),
      start_page: 1,
      start_value: 1,
    },
    {
      label_style: PageLabelDecimalArabic,
      label_prefix: None,
      start_page: 3,
      start_value: 1,
    },
  ])
  let extracted = try! labelled.pdf_of_pages([3, 1])
  @test.assert_eq(try! extracted.read_page_labels(), [])
  let retained = try! labelled.pdf_of_pages([3, 1], retain_numbering=true)
  @test.assert_eq(try! retained.read_page_labels(), [
    {
      label_style: PageLabelDecimalArabic,
      label_prefix: None,
      start_page: 1,
      start_value: 1,
    },
    {
      label_style: PageLabelLowercaseRoman,
      label_prefix: Some(@ascii.encode("intro-")),
      start_page: 2,
      start_value: 1,
    },
  ])
  @test.assert_eq(
    @pdflite.pdf_page_label_text_of_page_number(
      2,
      try! retained.read_page_labels(),
    ),
    Some(@ascii.encode("intro-i")),
  )
}

///|
test "PdfDocument pdf_of_pages filters bookmarks with ancestor context" {
  let doc = @pdflite.pdf_document_empty()
  let page_root = try! doc.add_pagetree([
    page_indexed_blank_for_test(0),
    page_indexed_blank_for_test(1),
    page_indexed_blank_for_test(2),
  ])
  ignore(try! doc.add_root(page_root, []))
  let page_refs = try! doc.page_reference_numbers()
  let bookmarked = try! doc.add_bookmarks([
    {
      level: 0,
      text: @ascii.encode("Parent"),
      target: DestFit(TargetPageObject(page_refs[0])),
      is_open: true,
      colour: @pdflite.pdf_bookmark_black,
      flags: 0,
    },
    {
      level: 1,
      text: @ascii.encode("Dropped"),
      target: DestFit(TargetPageObject(page_refs[1])),
      is_open: false,
      colour: @pdflite.pdf_bookmark_black,
      flags: 0,
    },
    {
      level: 1,
      text: @ascii.encode("Kept"),
      target: DestFit(TargetPageObject(page_refs[2])),
      is_open: false,
      colour: @pdflite.pdf_bookmark_black,
      flags: 0,
    },
  ])
  let extracted = try! bookmarked.pdf_of_pages([3])
  let extracted_page_refs = try! extracted.page_reference_numbers()
  @test.assert_eq(try! extracted.read_bookmarks(preserve_actions=true), [
    {
      level: 0,
      text: @ascii.encode("Parent"),
      target: DestNull,
      is_open: true,
      colour: @pdflite.pdf_bookmark_black,
      flags: 0,
    },
    {
      level: 1,
      text: @ascii.encode("Kept"),
      target: DestFit(TargetPageObject(extracted_page_refs[0])),
      is_open: false,
      colour: @pdflite.pdf_bookmark_black,
      flags: 0,
    },
  ])
}

///|
test "PdfDocument pdf_of_pages retains bookmarks with named destinations" {
  let key_dests = page_name_for_test("/Dests")
  let key_names = page_name_for_test("/Names")
  let type_fit = page_name_for_test("/Fit")
  let catalog_name = page_name_for_test("/CatalogKeep")
  let string_name = @ascii.encode("string-keep")
  let doc = @pdflite.pdf_document_empty()
  let page_root = try! doc.add_pagetree([
    page_indexed_blank_for_test(0),
    page_indexed_blank_for_test(1),
  ])
  ignore(try! doc.add_root(page_root, []))
  let page_refs = try! doc.page_reference_numbers()
  let kept_dest : @pdflite.PdfObject = PdfArray([
    PdfIndirect(page_refs[1]),
    PdfNameObject(type_fit),
  ])
  doc.add_object_given_number(
    doc.root(),
    try! doc
    .lookup_object_or_null(doc.root())
    .add_dict_entry(
      key_names,
      PdfDictionary([
        (key_dests, doc.build_name_tree([(string_name, kept_dest)])),
      ]),
    ),
  )
  doc.add_object_given_number(
    doc.root(),
    try! doc
    .lookup_object_or_null(doc.root())
    .add_dict_entry(key_dests, PdfDictionary([(catalog_name, kept_dest)])),
  )
  let bookmarked = try! doc.add_bookmarks([
    {
      level: 0,
      text: @ascii.encode("String"),
      target: DestString(string_name),
      is_open: false,
      colour: @pdflite.pdf_bookmark_black,
      flags: 0,
    },
    {
      level: 0,
      text: @ascii.encode("Named"),
      target: DestNamed(catalog_name),
      is_open: false,
      colour: @pdflite.pdf_bookmark_black,
      flags: 0,
    },
  ])
  let extracted = try! bookmarked.pdf_of_pages([2])
  let extracted_page_refs = try! extracted.page_reference_numbers()
  @test.assert_eq(try! extracted.read_bookmarks(preserve_actions=true), [
    {
      level: 0,
      text: @ascii.encode("String"),
      target: DestString(string_name),
      is_open: false,
      colour: @pdflite.pdf_bookmark_black,
      flags: 0,
    },
    {
      level: 0,
      text: @ascii.encode("Named"),
      target: DestNamed(catalog_name),
      is_open: false,
      colour: @pdflite.pdf_bookmark_black,
      flags: 0,
    },
  ])
  @test.assert_eq(try! extracted.read_bookmarks(), [
    {
      level: 0,
      text: @ascii.encode("String"),
      target: DestFit(TargetPageObject(extracted_page_refs[0])),
      is_open: false,
      colour: @pdflite.pdf_bookmark_black,
      flags: 0,
    },
    {
      level: 0,
      text: @ascii.encode("Named"),
      target: DestFit(TargetPageObject(extracted_page_refs[0])),
      is_open: false,
      colour: @pdflite.pdf_bookmark_black,
      flags: 0,
    },
  ])
}

///|
test "PdfDocument pdf_of_pages can trim structure tree" {
  let key_struct_tree_root = page_name_for_test("/StructTreeRoot")
  let key_k = page_name_for_test("/K")
  let key_pg = page_name_for_test("/Pg")
  let doc = @pdflite.pdf_document_empty()
  let page_root = try! doc.add_pagetree([
    page_indexed_blank_for_test(0),
    page_indexed_blank_for_test(1),
  ])
  ignore(try! doc.add_root(page_root, []))
  let old_page_numbers = try! doc.page_reference_numbers()
  doc.add_object_given_number(
    30,
    @pdflite.pdf_dictionary([
      (key_k, PdfArray([PdfIndirect(31), PdfIndirect(32)])),
    ]),
  )
  doc.add_object_given_number(
    31,
    @pdflite.pdf_dictionary([
      (key_pg, PdfIndirect(old_page_numbers[0])),
      (key_k, PdfInteger(0)),
    ]),
  )
  doc.add_object_given_number(
    32,
    @pdflite.pdf_dictionary([
      (key_pg, PdfIndirect(old_page_numbers[1])),
      (key_k, PdfInteger(0)),
    ]),
  )
  doc.add_object_given_number(
    doc.root(),
    try! doc
    .lookup_object_or_null(doc.root())
    .add_dict_entry(key_struct_tree_root, PdfIndirect(30)),
  )
  let extracted = try! doc.pdf_of_pages([1], process_struct_tree=true)
  let new_page_numbers = try! extracted.page_reference_numbers()
  @test.assert_eq(
    extracted
    .lookup_object_or_null(extracted.root())
    .lookup_immediate(key_struct_tree_root),
    Some(PdfIndirect(30)),
  )
  @test.assert_eq(
    extracted.lookup_object_or_null(30).lookup_immediate(key_k),
    Some(PdfIndirect(31)),
  )
  @test.assert_eq(
    extracted.lookup_object_or_null(31).lookup_immediate(key_pg),
    Some(PdfIndirect(new_page_numbers[0])),
  )
  @test.assert_eq(extracted.lookup_object_or_null(32), PdfNull)
}

///|
test "PdfDocument trim_structure_tree prunes deleted page kids" {
  let key_k = page_name_for_test("/K")
  let key_pg = page_name_for_test("/Pg")
  let doc = @pdflite.pdf_document_empty()
  let page_root = try! doc.add_pagetree([
    page_indexed_blank_for_test(0),
    page_indexed_blank_for_test(1),
  ])
  ignore(try! doc.add_root(page_root, []))
  let page_numbers = try! doc.page_reference_numbers()
  doc.add_object_given_number(
    30,
    @pdflite.pdf_dictionary([
      (key_k, PdfArray([PdfIndirect(31), PdfIndirect(32)])),
    ]),
  )
  doc.add_object_given_number(
    31,
    @pdflite.pdf_dictionary([
      (key_pg, PdfIndirect(page_numbers[0])),
      (key_k, PdfInteger(0)),
    ]),
  )
  doc.add_object_given_number(
    32,
    @pdflite.pdf_dictionary([
      (key_pg, PdfIndirect(page_numbers[1])),
      (key_k, PdfInteger(0)),
    ]),
  )
  try! doc.trim_structure_tree([1])
  @test.assert_eq(
    doc.lookup_object_or_null(30).lookup_immediate(key_k),
    Some(PdfIndirect(31)),
  )
  @test.assert_eq(doc.lookup_object_or_null(32), PdfNull)
}

///|
test "PdfDocument pdf_of_pages duplicates reused annotations" {
  let key_annots = page_name_for_test("/Annots")
  let key_subtype = page_name_for_test("/Subtype")
  let key_popup = page_name_for_test("/Popup")
  let key_parent = page_name_for_test("/Parent")
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(
    10,
    @pdflite.pdf_dictionary([
      (key_subtype, PdfNameObject(page_name_for_test("/Text"))),
      (key_popup, PdfIndirect(11)),
    ]),
  )
  doc.add_object_given_number(
    11,
    @pdflite.pdf_dictionary([
      (key_subtype, PdfNameObject(page_name_for_test("/Popup"))),
      (key_parent, PdfIndirect(10)),
    ]),
  )
  let page = {
    ..page_indexed_blank_for_test(0),
    rest: @pdflite.pdf_dictionary([
      (key_annots, PdfArray([PdfIndirect(10), PdfIndirect(11)])),
    ]),
  }
  let page_root = try! doc.add_pagetree([page, page])
  ignore(try! doc.add_root(page_root, []))
  let extracted = try! doc.pdf_of_pages([1, 2])
  let page_numbers = try! extracted.page_reference_numbers()
  let first_annots = page_annotation_numbers_for_test(
    extracted.lookup_object_or_null(page_numbers[0]),
  )
  let second_annots = page_annotation_numbers_for_test(
    extracted.lookup_object_or_null(page_numbers[1]),
  )
  @test.assert_eq(first_annots.length(), 2)
  @test.assert_eq(second_annots.length(), 2)
  @test.assert_eq(first_annots, [10, 11])
  @test.assert_eq(first_annots[0] == second_annots[0], false)
  @test.assert_eq(first_annots[1] == second_annots[1], false)
  @test.assert_eq(
    extracted
    .lookup_object_or_null(second_annots[0])
    .lookup_immediate(key_popup),
    Some(PdfIndirect(second_annots[1])),
  )
  @test.assert_eq(
    extracted
    .lookup_object_or_null(second_annots[1])
    .lookup_immediate(key_parent),
    Some(PdfIndirect(second_annots[0])),
  )
}

///|
test "PdfDocument pdf_of_pages rewrites and prunes named destinations" {
  let key_names = page_name_for_test("/Names")
  let key_dests = page_name_for_test("/Dests")
  let type_fit = page_name_for_test("/Fit")
  let doc = @pdflite.pdf_document_empty()
  let page_root = try! doc.add_pagetree([
    page_indexed_blank_for_test(0),
    page_indexed_blank_for_test(1),
  ])
  ignore(try! doc.add_root(page_root, []))
  let old_page_numbers = try! doc.page_reference_numbers()
  let dest_tree = doc.build_name_tree([
    (
      @ascii.encode("drop"),
      PdfArray([PdfIndirect(old_page_numbers[1]), PdfNameObject(type_fit)]),
    ),
    (
      @ascii.encode("keep"),
      PdfArray([PdfIndirect(old_page_numbers[0]), PdfNameObject(type_fit)]),
    ),
  ])
  doc.add_object_given_number(
    doc.root(),
    try! doc
    .lookup_object_or_null(doc.root())
    .add_dict_entry(key_names, PdfDictionary([(key_dests, dest_tree)])),
  )
  let extracted = try! doc.pdf_of_pages([1])
  let new_page_numbers = try! extracted.page_reference_numbers()
  @test.assert_eq(page_destination_entries_for_test(extracted), [
    (
      @ascii.encode("keep"),
      PdfArray([PdfIndirect(new_page_numbers[0]), PdfNameObject(type_fit)]),
    ),
  ])
}

///|
test "PdfDocument pdf_of_pages rewrites and prunes catalog destinations" {
  let key_dests = page_name_for_test("/Dests")
  let type_fit = page_name_for_test("/Fit")
  let doc = @pdflite.pdf_document_empty()
  let page_root = try! doc.add_pagetree([
    page_indexed_blank_for_test(0),
    page_indexed_blank_for_test(1),
  ])
  ignore(try! doc.add_root(page_root, []))
  let old_page_numbers = try! doc.page_reference_numbers()
  doc.add_object_given_number(
    doc.root(),
    try! doc
    .lookup_object_or_null(doc.root())
    .add_dict_entry(
      key_dests,
      PdfDictionary([
        (
          page_name_for_test("/Drop"),
          PdfArray([PdfIndirect(old_page_numbers[1]), PdfNameObject(type_fit)]),
        ),
        (
          page_name_for_test("/Keep"),
          PdfArray([PdfIndirect(old_page_numbers[0]), PdfNameObject(type_fit)]),
        ),
      ]),
    ),
  )
  let extracted = try! doc.pdf_of_pages([1])
  let new_page_numbers = try! extracted.page_reference_numbers()
  @test.assert_eq(
    page_catalog_destination_for_test(extracted, "/Keep"),
    Some(PdfArray([PdfIndirect(new_page_numbers[0]), PdfNameObject(type_fit)])),
  )
  @test.assert_eq(page_catalog_destination_for_test(extracted, "/Drop"), None)
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

  let fallback = @pdflite.pdf_document_empty()
  fallback.set_root(1)
  fallback.add_object_given_number(
    1,
    PdfDictionary([
      (
        page_name_for_test("/Type"),
        PdfNameObject(page_name_for_test("/Catalog")),
      ),
      (page_name_for_test("/Pages"), PdfIndirect(2)),
      (key_metadata, PdfIndirect(4)),
    ]),
  )
  fallback.add_object_given_number(
    2,
    PdfDictionary([
      (page_name_for_test("/Type"), PdfNameObject(page_name_for_test("/Pages"))),
      (page_name_for_test("/Kids"), PdfArray([])),
      (page_name_for_test("/Count"), PdfInteger(0)),
    ]),
  )
  fallback.add_object_given_number(4, PdfString(@ascii.encode("fallback-kept")))
  fallback.add_object_given_number(
    5,
    PdfString(@ascii.encode("fallback-removed")),
  )
  try! fallback.remove_unreferenced()
  @test.assert_eq(
    fallback.lookup_object_or_null(4),
    PdfString(@ascii.encode("fallback-kept")),
  )
  @test.assert_eq(fallback.lookup_object_or_null(5), PdfNull)
}

///|
test "PdfDocument remove_unreferenced uses trailer root as reachability root" {
  let key_root = page_name_for_test("/Root")
  let key_type = page_name_for_test("/Type")
  let key_pages = page_name_for_test("/Pages")
  let key_kids = page_name_for_test("/Kids")
  let key_count = page_name_for_test("/Count")
  let key_parent = page_name_for_test("/Parent")
  let doc = @pdflite.pdf_document_empty()
  doc.set_root(1)
  doc.add_object_given_number(
    1,
    PdfDictionary([
      (key_type, PdfNameObject(page_name_for_test("/Catalog"))),
      (key_pages, PdfIndirect(2)),
    ]),
  )
  doc.add_object_given_number(
    2,
    PdfDictionary([
      (key_type, PdfNameObject(page_name_for_test("/Pages"))),
      (key_kids, PdfArray([PdfIndirect(3)])),
      (key_count, PdfInteger(1)),
    ]),
  )
  doc.add_object_given_number(
    3,
    PdfDictionary([
      (key_type, PdfNameObject(page_name_for_test("/Page"))),
      (key_parent, PdfIndirect(2)),
    ]),
  )
  doc.add_object_given_number(
    10,
    PdfDictionary([
      (key_type, PdfNameObject(page_name_for_test("/Catalog"))),
      (key_pages, PdfIndirect(20)),
    ]),
  )
  doc.add_object_given_number(
    20,
    PdfDictionary([
      (key_type, PdfNameObject(page_name_for_test("/Pages"))),
      (key_kids, PdfArray([PdfIndirect(21)])),
      (key_count, PdfInteger(1)),
    ]),
  )
  doc.add_object_given_number(
    21,
    PdfDictionary([
      (key_type, PdfNameObject(page_name_for_test("/Page"))),
      (key_parent, PdfIndirect(20)),
    ]),
  )
  doc.set_trailer_dict(PdfDictionary([(key_root, PdfIndirect(10))]))

  try! doc.remove_unreferenced()

  @test.assert_eq(doc.lookup_object_or_null(1), PdfNull)
  @test.assert_eq(doc.lookup_object_or_null(2), PdfNull)
  @test.assert_eq(doc.lookup_object_or_null(3), PdfNull)
  @test.assert_eq(try! doc.page_reference_numbers(), [21])
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
