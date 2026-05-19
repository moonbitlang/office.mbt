///|
fn content_page_json_number_for_test(value : Int) -> Json {
  Json::number(value.to_double(), repr=value.to_string())
}

///|
fn content_page_json_document_for_test() -> @pdflite.PdfDocument raise @pdflite.PdfError {
  let base = try! @pdflite.pdf_blank_document(100.0, 100.0, 2)
  let pages = try! base.pages_of_pagetree()
  let first_stream = try! @pdflite.pdf_content_stream_of_ops([
    Op_m(10.0, 20.0),
    Op_l(30.0, 20.0),
    Op_S,
  ])
  let second_stream = try! @pdflite.pdf_content_stream_of_ops([
    Op_m(1.0, 2.0),
    Op_l(3.0, 4.0),
    Op_S,
  ])
  base.change_pages([
    { ..pages[0], content: [first_stream] },
    { ..pages[1], content: [second_stream] },
  ])
}

///|
test "cpdfcontent page JSON serializes selected page contents" {
  let document = try! content_page_json_document_for_test()
  let pages = try! document.pages_of_pagetree()
  let first_entries = try! document.content_entries_of_page(pages[0])
  @test.assert_eq(first_entries.length(), 1)
  guard first_entries[0].object is PdfContentPathObject(path) else {
    fail("expected path content entry")
  }
  @test.assert_eq(path.stroked, true)
  @test.assert_eq(path.filled, false)
  @test.assert_eq(
    try! @pdflite.pdf_content_entries_of_page(document, pages[0]),
    first_entries,
  )
  let first_json = try! document.content_json_of_page(pages[0])
  @test.assert_eq(
    first_json,
    @pdflite.pdf_content_json_entries_content_json(first_entries),
  )
  @test.assert_eq(
    try! @pdflite.pdf_content_json_of_page(document, pages[0]),
    first_json,
  )
  let mediabox = try! document.parse_rectangle(pages[0].mediabox)
  let ops = try! document.parse_content_ops_with_resources(
    pages[0].resources,
    pages[0].content,
  )
  @test.assert_eq(
    try! document.content_json_of_ops(mediabox, pages[0].resources, ops),
    first_json,
  )
  @test.assert_eq(
    try! @pdflite.pdf_content_json_of_ops(
      document,
      mediabox,
      pages[0].resources,
      ops,
    ),
    first_json,
  )
  let seen : Array[@pdflite.PdfContentObject] = []
  @test.assert_eq(
    try! document.content_filter(mediabox, pages[0].resources, ops, entry => {
      seen.push(entry.object)
      false
    }),
    ops,
  )
  @test.assert_eq(seen.length(), 1)
  guard seen[0] is PdfContentPathObject(_) else {
    fail("expected filter callback to see path entry")
  }
  let wrapper_seen : Array[@pdflite.PdfContentObject] = []
  @test.assert_eq(
    try! @pdflite.pdf_content_filter(
      document,
      entry => {
        wrapper_seen.push(entry.object)
        true
      },
      mediabox,
      pages[0].resources,
      ops,
    ),
    ops,
  )
  @test.assert_eq(wrapper_seen.length(), 1)
  let selected = try! document.page_content_json([1])
  let expected = Json::array([
    Json::object(
      Map::of([
        ("page", content_page_json_number_for_test(1)),
        ("contents", first_json),
      ]),
    ),
  ])
  @test.assert_eq(selected, expected)
  @test.assert_eq(try! @pdflite.pdf_page_content_json(document, [1]), expected)
  let second_json = try! document.content_json_of_page(pages[1])
  @test.assert_eq(
    try! document.page_content_json([2, 1]),
    Json::array([
      Json::object(
        Map::of([
          ("page", content_page_json_number_for_test(1)),
          ("contents", first_json),
        ]),
      ),
      Json::object(
        Map::of([
          ("page", content_page_json_number_for_test(2)),
          ("contents", second_json),
        ]),
      ),
    ]),
  )
  @test.assert_eq(try! document.page_content_json([]), Json::array([]))
  let bad_page : Result[Json, Error] = try? document.page_content_json([3])
  guard bad_page is Err(@pdflite.PdfError::BadPageSpecification(_)) else {
    fail("expected @pdflite.PdfError::BadPageSpecification")
  }
}
