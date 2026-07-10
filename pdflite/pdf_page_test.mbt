///|
fn page_name_for_test(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn page_rect_for_test(
  min_x : Double,
  min_y : Double,
  max_x : Double,
  max_y : Double,
) -> @geometry.PdfRectangle {
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
    @syntax.pdf_dictionary([
      (key_type, PdfNameObject(type_catalog)),
      (key_pages, PdfIndirect(2)),
    ]),
  )
  doc.add_object_given_number(
    2,
    @syntax.pdf_dictionary([
      (key_type, PdfNameObject(type_pages)),
      (key_kids, PdfArray([PdfIndirect(3), PdfIndirect(4)])),
      (key_count, PdfInteger(2)),
    ]),
  )
  doc.add_object_given_number(
    3,
    @syntax.pdf_dictionary([(key_type, PdfNameObject(type_page))]),
  )
  doc.add_object_given_number(
    4,
    @syntax.pdf_dictionary([
      (key_type, PdfNameObject(type_pages)),
      (key_kids, PdfArray([PdfIndirect(5)])),
      (key_count, PdfInteger(1)),
    ]),
  )
  doc.add_object_given_number(
    5,
    @syntax.pdf_dictionary([(key_type, PdfNameObject(type_page))]),
  )
  doc
}

///|
fn page_hello_ops_for_test() -> Array[@content.PdfContentOp] {
  [
    Op_cm(@geometry.transform_translate(50.0, 770.0)),
    Op_BT,
    Op_Tf(page_name_for_test("/F0"), 36.0),
    Op_Tj(b"Hello, World!"),
    Op_ET,
  ]
}

///|
fn page_hello_resources_for_test() -> @syntax.PdfObject {
  let key_font = page_name_for_test("/Font")
  let key_type = page_name_for_test("/Type")
  let key_subtype = page_name_for_test("/Subtype")
  let key_basefont = page_name_for_test("/BaseFont")
  let font = @syntax.pdf_dictionary([
    (key_type, PdfNameObject(page_name_for_test("/Font"))),
    (key_subtype, PdfNameObject(page_name_for_test("/Type1"))),
    (key_basefont, PdfNameObject(page_name_for_test("/Times-Italic"))),
  ])
  @syntax.pdf_dictionary([
    (key_font, @syntax.pdf_dictionary([(page_name_for_test("/F0"), font)])),
  ])
}

///|
fn page_index_mediabox_for_test(index : Int) -> @syntax.PdfObject {
  PdfArray([
    PdfInteger(index),
    PdfInteger(0),
    PdfInteger(index + 100),
    PdfInteger(200),
  ])
}

///|
fn page_indexed_blank_for_test(index : Int) -> @page.PdfPage {
  {
    ..@page.pdf_page_blank(@geometry.paper_a4),
    mediabox: page_index_mediabox_for_test(index),
  }
}

///|
fn page_prefix_resources_for_test(
  names : ArrayView[String],
) -> @syntax.PdfObject {
  let font_entries : Array[(@core.PdfName, @syntax.PdfObject)] = []
  for name in names {
    font_entries.push((page_name_for_test(name), PdfDictionary([])))
  }
  @syntax.pdf_dictionary([
    (page_name_for_test("/Font"), PdfDictionary(font_entries)),
  ])
}

///|
fn page_prefix_document_for_test(
  names : ArrayView[String],
) -> @pdflite.PdfDocument {
  let doc = @pdflite.pdf_document_empty()
  let page = {
    ..@page.pdf_page_blank(@geometry.paper_a4),
    resources: page_prefix_resources_for_test(names),
  }
  let page_root = try! doc.add_pagetree([page])
  ignore(try! doc.add_root(page_root, []))
  doc
}

///|
fn page_xobject_resources_for_test(
  entries : ArrayView[(@core.PdfName, @syntax.PdfObject)],
) -> @syntax.PdfObject {
  @syntax.pdf_dictionary([
    (page_name_for_test("/XObject"), @syntax.pdf_dictionary(entries)),
  ])
}

///|
fn page_resource_value_for_test(
  resources : @syntax.PdfObject,
  key : String,
) -> @syntax.PdfObject? {
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
    @syntax.pdf_dictionary([
      (key_type, PdfNameObject(type_catalog)),
      (key_pages, PdfIndirect(2)),
    ]),
  )
  doc.add_object_given_number(
    2,
    @syntax.pdf_dictionary([
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
    @syntax.pdf_dictionary([
      (key_type, PdfNameObject(type_page)),
      (key_contents, PdfIndirect(6)),
      (key_annots, PdfArray([])),
    ]),
  )
  doc.add_object_given_number(
    4,
    @syntax.pdf_dictionary([
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
        @syntax.pdf_dictionary([
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
test "standalone page lifecycle helpers delegate to document methods" {
  let doc = page_tree_document_for_test()
  @test.assert_eq(
    try! @pdflite.pdf_page_reference_numbers(doc),
    try! doc.page_reference_numbers(),
  )
  @test.assert_eq(
    try! @pdflite.pdf_pages_of_pagetree(doc),
    try! doc.pages_of_pagetree(),
  )
  @test.assert_eq(try! @pdflite.pdf_endpage(doc), try! doc.endpage())
  @test.assert_eq(try! @pdflite.pdf_endpage_fast(doc), try! doc.endpage_fast())
  @test.assert_eq(
    try! @pdflite.pdf_page_object_number(doc, 2),
    try! doc.page_object_number(2),
  )
  let destination : @destination.PdfDestination = DestFit(TargetPageObject(5))
  @test.assert_eq(
    try! @pdflite.pdf_pagenumber_of_target(doc, destination),
    try! doc.page_number_of_target(destination),
  )
  @test.assert_eq(
    try! @pdflite.pdf_target_of_pagenumber(doc, 2),
    try! doc.target_of_page_number(2),
  )
  let blank = @page.pdf_page_blank(@geometry.paper_a4)
  let built = try! @pdflite.pdf_add_pagetree(
    [blank],
    @pdflite.pdf_document_empty(),
  )
  let rooted = try! @pdflite.pdf_add_root(built.1, [], built.0)
  @test.assert_eq(try! @pdflite.pdf_endpage(rooted), 1)
  @test.assert_eq((try! @pdflite.pdf_renumber_pages(doc, [blank])).length(), 1)
  let changed = try! @pdflite.pdf_change_pages(false, doc, [blank])
  @test.assert_eq(try! changed.endpage(), 1)
  let extracted = try! @pdflite.pdf_of_pages(doc, [1])
  @test.assert_eq(try! extracted.endpage(), 1)
  let prefixed = try! @pdflite.pdf_minimum_valid_pdf()
  @test.assert_eq(
    @pdflite.pdf_shortest_unused_prefix(prefixed),
    prefixed.shortest_unused_prefix(),
  )
  try! @pdflite.pdf_add_prefix(prefixed, "zz")
  @test.assert_eq(
    (try! @pdflite.pdf_prepend_operators(doc, [Op_q], blank, fast=true)).content.length(),
    blank.content.length() + 1,
  )
  @test.assert_eq(
    (try! @pdflite.pdf_postpend_operators(doc, [Op_q], blank, fast=true)).content.length(),
    blank.content.length() + 1,
  )
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
    @syntax.pdf_dictionary([
      (key_type, PdfNameObject(page_name_for_test("/Catalog"))),
      (key_pages, PdfIndirect(2)),
    ]),
  )
  doc.add_object_given_number(
    2,
    @syntax.pdf_dictionary([
      (key_type, PdfNameObject(page_name_for_test("/Pages"))),
      (
        key_kids,
        PdfArray([
          @syntax.pdf_dictionary([
            (key_type, PdfNameObject(page_name_for_test("/Page"))),
          ]),
          @syntax.pdf_dictionary([
            (key_type, PdfNameObject(page_name_for_test("/Pages"))),
            (
              key_kids,
              PdfArray([
                @syntax.pdf_dictionary([
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
    @syntax.pdf_dictionary([
      (key_type, PdfNameObject(page_name_for_test("/Catalog"))),
      (key_pages, PdfIndirect(2)),
    ]),
  )
  doc.add_object_given_number(
    2,
    @syntax.pdf_dictionary([
      (key_type, PdfNameObject(page_name_for_test("/Pages"))),
      (key_kids, PdfArray([PdfInteger(1)])),
    ]),
  )
  let result : Result[Int, Error] = try doc.pages_of_pagetree_quick() catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard result is Err(@core.PdfError::PageTreeExpected) else {
    fail("expected @core.PdfError::PageTreeExpected")
  }
}

///|
test "PdfDocument page_number_of_target resolves named destinations" {
  let key_dests = page_name_for_test("/Dests")
  let key_names = page_name_for_test("/Names")
  let type_fit = page_name_for_test("/Fit")
  let named_destination = page_name_for_test("/Chapter")
  let string_destination = b"chapter"
  let doc = try! @pdflite.pdf_minimum_valid_pdf()
  let page_refs = try! doc.page_reference_numbers()
  let dest : @syntax.PdfObject = PdfArray([
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
  @test.assert_eq(try! doc.page_number_of_target(DestString(b"missing")), 0)
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
  doc.add_object_given_number(1, @syntax.pdf_dictionary([]))
  let result : Result[Array[Int], Error] = try
    doc.page_reference_numbers()
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard result is Err(@core.PdfError::PageTreeExpected) else {
    fail("expected @core.PdfError::PageTreeExpected")
  }
}

///|
test "@page.pdf_page_blank creates an A4 page rectangle in PDF points" {
  let page = @page.pdf_page_blank(@geometry.paper_a4)
  @test.assert_eq(page.content, [])
  @test.assert_eq(page.resources, PdfDictionary([]))
  @test.assert_eq(page.rotate, Rotate0)
  @test.assert_eq(
    page.mediabox,
    PdfArray([
      PdfReal(0.0),
      PdfReal(0.0),
      PdfReal(@geometry.unit_points(210.0, Millimetre)),
      PdfReal(@geometry.unit_points(297.0, Millimetre)),
    ]),
  )
}

///|
test "@page.pdf_page_rotation_of_int preserves CamlPDF rotation cases" {
  @test.assert_eq(try! @page.pdf_page_rotation_of_int(0), Rotate0)
  @test.assert_eq(try! @page.pdf_page_rotation_of_int(90), Rotate90)
  @test.assert_eq(try! @page.pdf_page_rotation_of_int(-180), Rotate180)
  @test.assert_eq(try! @page.pdf_page_rotation_of_int(-90), Rotate270)
  let result : Result[@page.PdfPageRotation, Error] = try
    @page.pdf_page_rotation_of_int(45)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard result is Err(@core.PdfError::PageRotationExpected(45)) else {
    fail("expected @core.PdfError::PageRotationExpected")
  }
}

///|
test "PdfDocument add_pagetree and add_root build a writable page document" {
  let doc = @pdflite.pdf_document_empty()
  let page = {
    ..@page.pdf_page_blank(@geometry.paper_a4),
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
test "pdfhello-style standard font document roundtrips" {
  let doc = @pdflite.pdf_document_empty()
  let page = {
    ..@page.pdf_page_blank(@geometry.paper_a4),
    content: [
      try! @pdflite.pdf_content_stream_of_ops(page_hello_ops_for_test()),
    ],
    resources: page_hello_resources_for_test(),
  }
  let page_root = try! doc.add_pagetree([page])
  ignore(try! doc.add_root(page_root, []))
  let rendered = try! @pdflite.pdf_write_document(doc)
  let parsed = try! @pdflite.pdf_read_document_from_bytes(rendered)
  @test.assert_eq(try! parsed.endpage(), 1)

  let pages = try! parsed.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  @test.assert_eq(
    try! parsed.parse_rectangle(pages[0].mediabox),
    page_rect_for_test(0.0, 0.0, 595.2765, 841.89105),
  )
  @test.assert_eq(pages[0].resources, page_hello_resources_for_test())
  @test.assert_eq(
    try! parsed.parse_content_ops(pages[0].content),
    page_hello_ops_for_test(),
  )

  let font_resources = match
    page_resource_value_for_test(pages[0].resources, "/Font") {
    Some(font_resources) => font_resources
    None => fail("expected font resources")
  }
  let font_object = match
    font_resources.lookup_immediate(page_name_for_test("/F0")) {
    Some(font_object) => font_object
    None => fail("expected F0 font")
  }
  @test.assert_eq(
    try! parsed.read_font(font_object),
    PdfFontStandard({ font: PdfTimesItalic, encoding: PdfImplicitInFontFile }),
  )

  let hello = b"Hello, World!"
  let extractor = try! parsed.text_extractor_of_font(font_object)
  @test.assert_eq(try! extractor.codepoints_of_text(hello), [
    72, 101, 108, 108, 111, 44, 32, 87, 111, 114, 108, 100, 33,
  ])
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
  @test.assert_eq(pages[0], @page.pdf_page_blank(@geometry.paper_a4))
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
  let names : ReadOnlyArray[String] = [
    "/a", "/b", "/c", "/d", "/e", "/f", "/g", "/h", "/i", "/j", "/k", "/l", "/m",
    "/n", "/o", "/p", "/q", "/r", "/s", "/t", "/u", "/v", "/w", "/x", "/y", "/z",
  ]
  @test.assert_eq(
    page_prefix_document_for_test(names).shortest_unused_prefix(),
    "az",
  )
}

///|
test "PdfDocument combine_pdf_rests preserves unknown entries and appends annotations" {
  let doc = @pdflite.pdf_document_empty()
  let first = @syntax.pdf_dictionary([
    (page_name_for_test("/Rotate"), PdfInteger(90)),
    (page_name_for_test("/Annots"), PdfArray([PdfIndirect(1), PdfInteger(2)])),
  ])
  let second = @syntax.pdf_dictionary([
    (page_name_for_test("/Custom"), PdfBoolean(true)),
    (page_name_for_test("/Annots"), PdfArray([PdfIndirect(3)])),
  ])
  @test.assert_eq(
    doc.combine_pdf_rests(first, second),
    @syntax.pdf_dictionary([
      (page_name_for_test("/Rotate"), PdfInteger(90)),
      (page_name_for_test("/Custom"), PdfBoolean(true)),
      (
        page_name_for_test("/Annots"),
        PdfArray([PdfIndirect(1), PdfInteger(2), PdfIndirect(3)]),
      ),
    ]),
  )
}

///|
test "PdfDocument combine_pdf_rests resolves indirect annotation arrays" {
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(20, PdfArray([PdfInteger(20), PdfIndirect(21)]))
  let first = @syntax.pdf_dictionary([
    (page_name_for_test("/Annots"), PdfIndirect(20)),
  ])
  let second = @syntax.pdf_dictionary([
    (page_name_for_test("/Custom"), PdfNull),
    (page_name_for_test("/Annots"), PdfInteger(1)),
  ])
  @test.assert_eq(
    doc.combine_pdf_rests(first, second),
    @syntax.pdf_dictionary([
      (page_name_for_test("/Custom"), PdfNull),
      (
        page_name_for_test("/Annots"),
        PdfArray([PdfInteger(20), PdfIndirect(21)]),
      ),
    ]),
  )
}

///|
test "PdfDocument combine_pdf_rests ignores non-dictionary rest inputs" {
  let doc = @pdflite.pdf_document_empty()
  @test.assert_eq(
    doc.combine_pdf_rests(
      PdfInteger(1),
      @syntax.pdf_dictionary([
        (page_name_for_test("/Annots"), PdfArray([PdfInteger(7)])),
      ]),
    ),
    @syntax.pdf_dictionary([
      (page_name_for_test("/Annots"), PdfArray([PdfInteger(7)])),
    ]),
  )
  @test.assert_eq(
    doc.combine_pdf_rests(PdfInteger(1), PdfBoolean(false)),
    @syntax.pdf_dictionary([]),
  )
}

///|
test "PdfDocument combine_pdf_resources unions known and unknown resource keys" {
  let doc = @pdflite.pdf_document_empty()
  let first = @syntax.pdf_dictionary([
    (
      page_name_for_test("/ProcSet"),
      PdfArray([PdfNameObject(page_name_for_test("/PDF"))]),
    ),
    (
      page_name_for_test("/Font"),
      @syntax.pdf_dictionary([(page_name_for_test("/F0"), PdfInteger(1))]),
    ),
    (
      page_name_for_test("/ColorSpace"),
      @syntax.pdf_dictionary([
        (page_name_for_test("/CSA"), PdfNameObject(page_name_for_test("/RGB"))),
      ]),
    ),
  ])
  let second = @syntax.pdf_dictionary([
    (page_name_for_test("/Custom"), PdfBoolean(true)),
    (
      page_name_for_test("/Font"),
      @syntax.pdf_dictionary([(page_name_for_test("/F1"), PdfInteger(2))]),
    ),
    (
      page_name_for_test("/ColorSpace"),
      @syntax.pdf_dictionary([
        (page_name_for_test("/CSB"), PdfNameObject(page_name_for_test("/CMYK"))),
      ]),
    ),
    (
      page_name_for_test("/Pattern"),
      @syntax.pdf_dictionary([(page_name_for_test("/P1"), PdfNull)]),
    ),
  ])
  @test.assert_eq(
    doc.combine_pdf_resources(first, second),
    @syntax.pdf_dictionary([
      (
        page_name_for_test("/ProcSet"),
        PdfArray([PdfNameObject(page_name_for_test("/PDF"))]),
      ),
      (page_name_for_test("/Custom"), PdfBoolean(true)),
      (
        page_name_for_test("/Font"),
        @syntax.pdf_dictionary([
          (page_name_for_test("/F0"), PdfInteger(1)),
          (page_name_for_test("/F1"), PdfInteger(2)),
        ]),
      ),
      (
        page_name_for_test("/ColorSpace"),
        @syntax.pdf_dictionary([
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
        @syntax.pdf_dictionary([(page_name_for_test("/P1"), PdfNull)]),
      ),
    ]),
  )
}

///|
test "PdfDocument combine_pdf_resources resolves indirect subdictionaries" {
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(
    12,
    @syntax.pdf_dictionary([(page_name_for_test("/F0"), PdfInteger(1))]),
  )
  @test.assert_eq(
    doc.combine_pdf_resources(
      @syntax.pdf_dictionary([(page_name_for_test("/Font"), PdfIndirect(12))]),
      PdfInteger(0),
    ),
    @syntax.pdf_dictionary([
      (
        page_name_for_test("/Font"),
        @syntax.pdf_dictionary([(page_name_for_test("/F0"), PdfInteger(1))]),
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
  @test.assert_eq(matrix, @geometry.transform_identity_matrix)
}

///|
test "pdf_page_process_stub propagates callback errors" {
  let result : Result[(Int, Int, @geometry.TransformMatrix), Error] = try
    @pdflite.pdf_page_process_stub(
      fn(n, p) raise {
        if p == 0 {
          fail("bad page")
        }
        n / p
      },
      6,
      0,
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard result is Err(_) else { fail("expected callback failure") }
}

///|
test "PdfDocument process_pages rewrites selected pages and carries matrices" {
  let key_open_action = page_name_for_test("/OpenAction")
  let type_xyz = page_name_for_test("/XYZ")
  let document = @pdflite.pdf_document_empty()
  let page_root = try! document.add_pagetree([
    @page.pdf_page_blank(@geometry.paper_a4),
    @page.pdf_page_blank(@geometry.paper_a4),
  ])
  ignore(try! document.add_root(page_root, []))
  let old_numbers = try! document.page_reference_numbers()
  document.add_object_given_number(
    document.root(),
    try! document
    .lookup_object_or_null(document.root())
    .add_dict_entry(
      key_open_action,
      PdfArray([
        PdfIndirect(old_numbers[0]),
        PdfNameObject(type_xyz),
        PdfReal(1.0),
        PdfReal(2.0),
        PdfNull,
      ]),
    ),
  )
  @pdflite.pdf_clear_progress_output()
  @pdflite.pdf_set_progress(true)
  let seen : Array[Int] = []
  let processed = try! document.process_pages([1, 99], (page_number, page) => {
    seen.push(page_number)
    (
      { ..page, rotate: Rotate90 },
      page_number,
      @geometry.transform_translate(10.0, 20.0),
    )
  })
  @pdflite.pdf_set_progress(false)

  @test.assert_eq(seen, [1])
  @test.assert_eq(@pdflite.pdf_progress_output(), "1.\n")
  let pages = try! processed.pages_of_pagetree()
  @test.assert_eq(pages[0].rotate, Rotate90)
  @test.assert_eq(pages[1].rotate, Rotate0)
  let new_numbers = try! processed.page_reference_numbers()
  guard processed
    .lookup_object_or_null(processed.root())
    .lookup_immediate(key_open_action)
    is Some(open_action) else {
    fail("expected transformed open action")
  }
  @test.assert_eq(
    processed.direct(open_action),
    PdfArray([
      PdfIndirect(new_numbers[0]),
      PdfNameObject(type_xyz),
      PdfReal(11.0),
      PdfReal(22.0),
      PdfNull,
    ]),
  )

  let wrapped = try! @pdflite.pdf_process_pages(document, [2], (_, page) => {
    (page, 2, @geometry.transform_identity_matrix)
  })
  @test.assert_eq((try! wrapped.pages_of_pagetree()).length(), 2)
  let source_order_seen : Array[Int] = []
  let source_order = try! @pdflite.pdf_process_pages_cpdf_order(
    (page_number, page) => {
      source_order_seen.push(page_number)
      (
        { ..page, rotate: Rotate180 },
        page_number,
        @geometry.transform_identity_matrix,
      )
    },
    document,
    [1],
  )
  @test.assert_eq(source_order_seen, [1])
  let source_order_pages = try! source_order.pages_of_pagetree()
  @test.assert_eq(source_order_pages[0].rotate, Rotate180)
  @test.assert_eq(source_order_pages[1].rotate, Rotate0)
}

///|
test "PdfDocument iter_pages and map_pages follow document order" {
  let document = try! @pdflite.pdf_blank_document(10.0, 10.0, 3)
  let iterated : Array[Int] = []
  try! document.iter_pages([3, 1, 9], (page_number, page) => {
    ignore(page)
    iterated.push(page_number)
  })
  @test.assert_eq(iterated, [1, 3])

  let wrapped_iterated : Array[Int] = []
  try! @pdflite.pdf_iter_pages(document, [2], (page_number, page) => {
    ignore(page)
    wrapped_iterated.push(page_number)
  })
  @test.assert_eq(wrapped_iterated, [2])
  let source_order_iterated : Array[Int] = []
  try! @pdflite.pdf_iter_pages_cpdf_order(
    (page_number, page) => {
      ignore(page)
      source_order_iterated.push(page_number)
    },
    document,
    [3, 2],
  )
  @test.assert_eq(source_order_iterated, [2, 3])

  let mapped = try! document.map_pages([3, 1, 9], (page_number, page) => {
    page_number * 100 + @page.pdf_page_int_of_rotation(page.rotate)
  })
  @test.assert_eq(mapped, [100, 300])
  @test.assert_eq(
    try! @pdflite.pdf_map_pages(document, [2], (page_number, page) => {
      page_number + @page.pdf_page_int_of_rotation(page.rotate)
    }),
    [2],
  )
  @test.assert_eq(
    try! @pdflite.pdf_map_pages_cpdf_order(
      (page_number, page) => {
        page_number * 10 + @page.pdf_page_int_of_rotation(page.rotate)
      },
      document,
      [2, 1],
    ),
    [10, 20],
  )
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
    @syntax.pdf_stream(
      @syntax.pdf_dictionary([
        (key_subtype, PdfNameObject(page_name_for_test("/Form"))),
        (key_filter, PdfNameObject(page_name_for_test("/FlateDecode"))),
        (key_length, PdfInteger(3)),
        (key_keep, PdfInteger(1)),
      ]),
      StreamGot(b"old"),
    ),
  )
  let page = {
    ..@page.pdf_page_blank(@geometry.paper_a4),
    resources: page_xobject_resources_for_test([
      (page_name_for_test("/Fm1"), PdfIndirect(20)),
    ]),
  }
  try! doc.process_xobjects(page, fn(_, _, streams) raise @core.PdfError {
    if streams.length() < 0 {
      raise ParseStreamExpected
    }
    [
      @syntax.pdf_stream(
        @syntax.pdf_dictionary([
          (key_filter, PdfNameObject(page_name_for_test("/ASCIIHexDecode"))),
          (key_length, PdfInteger(2)),
          (key_extra, PdfInteger(7)),
        ]),
        StreamGot(b"BT"),
      ),
    ]
  })
  guard doc.lookup_object_or_null(20) is PdfStreamObject(stream) else {
    fail("expected form xobject stream")
  }
  @test.assert_eq(stream.data, StreamGot(b"BT"))
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
test "PdfDocument process_xobjects materializes deferred form streams" {
  let key_subtype = page_name_for_test("/Subtype")
  let key_length = page_name_for_test("/Length")
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(
    20,
    @syntax.pdf_stream(
      @syntax.pdf_dictionary([
        (key_subtype, PdfNameObject(page_name_for_test("/Form"))),
        (key_length, PdfInteger(99)),
      ]),
      StreamToGet(
        @syntax.stream_to_get(@core.byte_cursor_of_bytes(b"xxBTyy"), 2, 2),
      ),
    ),
  )
  let page = {
    ..@page.pdf_page_blank(@geometry.paper_a4),
    resources: page_xobject_resources_for_test([
      (page_name_for_test("/Fm1"), PdfIndirect(20)),
    ]),
  }
  let seen_data : Ref[@syntax.PdfStreamData?] = { val: None }
  let seen_length : Ref[@syntax.PdfObject?] = { val: None }
  try! doc.process_xobjects(page, fn(_, _, streams) raise @core.PdfError {
    if streams.length() < 0 {
      raise ParseStreamExpected
    }
    match streams[0] {
      PdfStreamObject(stream) => {
        seen_data.val = Some(stream.data)
        seen_length.val = stream.dictionary.lookup_immediate(key_length)
        [PdfStreamObject(stream)]
      }
      other => [other]
    }
  })
  @test.assert_eq(seen_data.val, Some(StreamGot(b"BT")))
  @test.assert_eq(seen_length.val, Some(PdfInteger(2)))
  guard doc.lookup_object_or_null(20) is PdfStreamObject(stream) else {
    fail("expected form xobject stream")
  }
  @test.assert_eq(stream.data, StreamGot(b"BT"))
  @test.assert_eq(
    stream.dictionary.lookup_immediate(key_length),
    Some(PdfInteger(2)),
  )
}

///|
test "PdfDocument process_xobjects skips non-form xobjects" {
  let key_subtype = page_name_for_test("/Subtype")
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(
    21,
    @syntax.pdf_stream(
      @syntax.pdf_dictionary([
        (key_subtype, PdfNameObject(page_name_for_test("/Image"))),
      ]),
      StreamGot(b"image"),
    ),
  )
  let page = {
    ..@page.pdf_page_blank(@geometry.paper_a4),
    resources: page_xobject_resources_for_test([
      (page_name_for_test("/Im1"), PdfIndirect(21)),
    ]),
  }
  let calls : Ref[Int] = { val: 0 }
  try! doc.process_xobjects(page, fn(_, _, streams) raise @core.PdfError {
    if streams.length() < 0 {
      raise ParseStreamExpected
    }
    calls.val += 1
    []
  })
  @test.assert_eq(calls.val, 0)
  @test.assert_eq(
    doc.lookup_object_or_null(21),
    @syntax.pdf_stream(
      @syntax.pdf_dictionary([
        (key_subtype, PdfNameObject(page_name_for_test("/Image"))),
      ]),
      StreamGot(b"image"),
    ),
  )
}

///|
test "PdfDocument process_xobjects validates xobject resources" {
  let key_subtype = page_name_for_test("/Subtype")
  let doc = @pdflite.pdf_document_empty()
  let non_indirect_page = {
    ..@page.pdf_page_blank(@geometry.paper_a4),
    resources: page_xobject_resources_for_test([
      (page_name_for_test("/Inline"), PdfDictionary([])),
    ]),
  }
  let non_indirect : Result[Unit, Error] = try
    doc.process_xobjects(non_indirect_page, fn(
      _,
      _,
      streams,
    ) raise @core.PdfError {
      if streams.length() < 0 {
        raise ParseStreamExpected
      }
      []
    })
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard non_indirect is Err(@core.PdfError::DictionaryExpected) else {
    fail("expected @core.PdfError::DictionaryExpected")
  }
  doc.add_object_given_number(22, @syntax.pdf_dictionary([]))
  let missing_subtype_page = {
    ..@page.pdf_page_blank(@geometry.paper_a4),
    resources: page_xobject_resources_for_test([
      (page_name_for_test("/MissingSubtype"), PdfIndirect(22)),
    ]),
  }
  let missing_subtype : Result[Unit, Error] = try
    doc.process_xobjects(missing_subtype_page, fn(
      _,
      _,
      streams,
    ) raise @core.PdfError {
      if streams.length() < 0 {
        raise ParseStreamExpected
      }
      []
    })
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard missing_subtype is Err(@core.PdfError::DictionaryKeyNotFound(_)) else {
    fail("expected @core.PdfError::DictionaryKeyNotFound")
  }
  doc.add_object_given_number(
    23,
    @syntax.pdf_stream(
      @syntax.pdf_dictionary([
        (key_subtype, PdfNameObject(page_name_for_test("/Form"))),
      ]),
      StreamGot(b"form"),
    ),
  )
  let bad_result_page = {
    ..@page.pdf_page_blank(@geometry.paper_a4),
    resources: page_xobject_resources_for_test([
      (page_name_for_test("/Bad"), PdfIndirect(23)),
    ]),
  }
  let bad_result : Result[Unit, Error] = try
    doc.process_xobjects(bad_result_page, fn(
      _,
      _,
      streams,
    ) raise @core.PdfError {
      if streams.length() < 0 {
        raise ParseStreamExpected
      }
      [PdfDictionary([])]
    })
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_result is Err(@core.PdfError::ParseStreamExpected) else {
    fail("expected @core.PdfError::ParseStreamExpected")
  }
  let bad_length : Result[Unit, Error] = try
    doc.process_xobjects(bad_result_page, fn(
      _,
      _,
      streams,
    ) raise @core.PdfError {
      if streams.length() < 0 {
        raise ParseStreamExpected
      }
      []
    })
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_length is Err(@core.PdfError::ParseStreamExpected) else {
    fail("expected @core.PdfError::ParseStreamExpected for bad callback length")
  }
  let bad_dictionary : Result[Unit, Error] = try
    doc.process_xobjects(bad_result_page, fn(
      _,
      _,
      streams,
    ) raise @core.PdfError {
      if streams.length() < 0 {
        raise ParseStreamExpected
      }
      [@syntax.pdf_stream(PdfInteger(1), StreamGot(b"bad"))]
    })
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_dictionary is Err(@core.PdfError::DictionaryExpected) else {
    fail(
      "expected @core.PdfError::DictionaryExpected for bad stream dictionary",
    )
  }
  doc.add_object_given_number(
    24,
    @syntax.pdf_dictionary([
      (key_subtype, PdfNameObject(page_name_for_test("/Form"))),
    ]),
  )
  let non_stream_page = {
    ..@page.pdf_page_blank(@geometry.paper_a4),
    resources: page_xobject_resources_for_test([
      (page_name_for_test("/NonStream"), PdfIndirect(24)),
    ]),
  }
  let non_stream : Result[Unit, Error] = try
    doc.process_xobjects(non_stream_page, fn(
      _,
      _,
      streams,
    ) raise @core.PdfError {
      if streams.length() < 0 {
        raise ParseStreamExpected
      }
      []
    })
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard non_stream is Err(@core.PdfError::ParseStreamExpected) else {
    fail("expected @core.PdfError::ParseStreamExpected for non-stream form")
  }
  let calls : Ref[Int] = { val: 0 }
  try! doc.process_xobjects(@page.pdf_page_blank(@geometry.paper_a4), fn(
    _,
    _,
    streams,
  ) raise @core.PdfError {
    if streams.length() < 0 {
      raise ParseStreamExpected
    }
    calls.val += 1
    []
  })
  @test.assert_eq(calls.val, 0)
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
    @syntax.pdf_dictionary([(page_name_for_test("/Annots"), PdfArray([]))]),
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
    @syntax.pdf_dictionary([
      (key_type, PdfNameObject(page_name_for_test("/Catalog"))),
      (key_pages, PdfIndirect(2)),
    ]),
  )
  doc.add_object_given_number(
    2,
    @syntax.pdf_dictionary([
      (key_type, PdfNameObject(page_name_for_test("/Pages"))),
      (key_kids, PdfArray([PdfIndirect(3), PdfIndirect(4)])),
      (key_count, PdfInteger(2)),
    ]),
  )
  let first_box : @syntax.PdfObject = PdfArray([
    PdfInteger(1),
    PdfInteger(2),
    PdfInteger(300),
    PdfInteger(400),
  ])
  doc.add_object_given_number(
    3,
    @syntax.pdf_dictionary([
      (key_type, PdfNameObject(page_name_for_test("/Page"))),
      (key_mediabox, first_box),
    ]),
  )
  doc.add_object_given_number(
    4,
    @syntax.pdf_dictionary([
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
  let parent_mediabox : @syntax.PdfObject = PdfArray([
    PdfInteger(0),
    PdfInteger(0),
    PdfInteger(300),
    PdfInteger(400),
  ])
  let parent_cropbox : @syntax.PdfObject = PdfArray([
    PdfInteger(10),
    PdfInteger(20),
    PdfInteger(290),
    PdfInteger(380),
  ])
  let resource_object = @syntax.pdf_dictionary([
    (page_name_for_test("/Font"), PdfDictionary([])),
  ])
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(8, resource_object)
  doc.add_object_given_number(
    2,
    @syntax.pdf_dictionary([
      (key_type, PdfNameObject(page_name_for_test("/Pages"))),
      (key_mediabox, parent_mediabox),
      (key_cropbox, parent_cropbox),
      (key_rotate, PdfInteger(90)),
      (key_resources, PdfIndirect(8)),
    ]),
  )
  doc.add_object_given_number(
    3,
    @syntax.pdf_dictionary([
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
  let inherited_mediabox : @syntax.PdfObject = PdfArray([
    PdfInteger(1),
    PdfInteger(2),
    PdfInteger(500),
    PdfInteger(600),
  ])
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(
    2,
    @syntax.pdf_dictionary([
      (key_type, PdfNameObject(page_name_for_test("/Pages"))),
      (key_mediabox, inherited_mediabox),
    ]),
  )
  doc.add_object_given_number(
    4,
    @syntax.pdf_dictionary([
      (key_type, PdfNameObject(page_name_for_test("/Pages"))),
      (key_parent, PdfIndirect(2)),
    ]),
  )
  doc.add_object_given_number(
    5,
    @syntax.pdf_dictionary([
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
    ..@page.pdf_page_blank(@geometry.paper_a4),
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
  let resources = @syntax.pdf_dictionary([
    (
      page_name_for_test("/ColorSpace"),
      @syntax.pdf_dictionary([
        (page_name_for_test("/CS1"), PdfNameObject(page_name_for_test("/RGB"))),
      ]),
    ),
  ])
  let data = b"BI /W 2 /H 1 /BPC 8 /CS /CS1 ID A EI B EI Q"
  let page = {
    ..@page.pdf_page_blank(@geometry.paper_a4),
    resources,
    content: [
      @syntax.pdf_stream(
        @syntax.pdf_dictionary([
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
        @syntax.pdf_dictionary([
          (page_name_for_test("/W"), PdfInteger(2)),
          (page_name_for_test("/H"), PdfInteger(1)),
          (page_name_for_test("/BPC"), PdfInteger(8)),
          (page_name_for_test("/CS"), PdfNameObject(page_name_for_test("/CS1"))),
        ]),
        None,
        b"A EI B",
      ),
      Op_Q,
    ],
  )
}

///|
test "PdfDocument prepend_operators falls back for missing inline image resources" {
  let doc = @pdflite.pdf_document_empty()
  let data = b"BI /W 1 /H 1 /BPC 8 /CS /Missing ID abc EI"
  let page = {
    ..@page.pdf_page_blank(@geometry.paper_a4),
    content: [
      @syntax.pdf_stream(
        @syntax.pdf_dictionary([
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
      @syntax.pdf_dictionary([
        (page_name_for_test("/W"), PdfInteger(1)),
        (page_name_for_test("/H"), PdfInteger(1)),
        (page_name_for_test("/BPC"), PdfInteger(8)),
        (
          page_name_for_test("/CS"),
          PdfNameObject(page_name_for_test("/Missing")),
        ),
      ]),
      None,
      b"abc",
    ),
  ])
}

///|
test "PdfDocument prepend_operators propagates non-colour parse errors" {
  let doc = @pdflite.pdf_document_empty()
  let data = b"1 2"
  let page = {
    ..@page.pdf_page_blank(@geometry.paper_a4),
    content: [
      @syntax.pdf_stream(
        @syntax.pdf_dictionary([
          (page_name_for_test("/Length"), PdfInteger(data.length())),
        ]),
        StreamGot(data),
      ),
    ],
  }
  let result : Result[@page.PdfPage, Error] = try
    doc.prepend_operators(page, [Op_q])
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard result is Err(@core.PdfError::ContentOperatorExpected) else {
    fail("expected @core.PdfError::ContentOperatorExpected")
  }
}

///|
test "PdfDocument prepend_operators preserves split streams in fast mode" {
  let doc = @pdflite.pdf_document_empty()
  let page = {
    ..@page.pdf_page_blank(@geometry.paper_a4),
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
    ..@page.pdf_page_blank(@geometry.paper_a4),
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
  let page = @page.pdf_page_blank(@geometry.paper_a4)
  let updated = try! doc.postpend_operators(page, [Op_BT, Op_ET])
  @test.assert_eq(updated.content.length(), 1)
  @test.assert_eq(try! doc.parse_content_ops(updated.content), [Op_BT, Op_ET])
}
