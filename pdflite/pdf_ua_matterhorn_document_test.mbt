///|
test "PdfDocument test_matterhorn_json detects missing metadata and viewer preferences" {
  let document = ua_matterhorn_document_for_test([])
  @test.assert_eq(
    try! document.test_matterhorn_json("06-001"),
    Json::array([ua_matterhorn_06_001_failure_for_test()]),
  )
  @test.assert_eq(try! document.test_matterhorn_json("06-002"), Json::array([]))
  @test.assert_eq(try! document.test_matterhorn_json("06-003"), Json::array([]))
  @test.assert_eq(
    try! document.test_matterhorn_json("07-001"),
    Json::array([ua_matterhorn_07_001_failure_for_test()]),
  )
}

///|
test "PdfDocument test_matterhorn_json detects missing XMP fields" {
  let metadata =
    #|<x:xmpmeta xmlns:x="adobe:ns:meta/"
    #| xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
    #| <rdf:RDF><rdf:Description/></rdf:RDF>
    #|</x:xmpmeta>
  let document = ua_matterhorn_document_with_metadata_for_test(
    @ascii.encode(metadata),
    [ua_matterhorn_display_doc_title_for_test(true)],
  )
  @test.assert_eq(try! document.test_matterhorn_json("06-001"), Json::array([]))
  @test.assert_eq(
    try! document.test_matterhorn_json("06-002"),
    Json::array([ua_matterhorn_06_002_failure_for_test()]),
  )
  @test.assert_eq(
    try! document.test_matterhorn_json("06-003"),
    Json::array([ua_matterhorn_06_003_failure_for_test()]),
  )
  @test.assert_eq(
    try! document.test_matterhorn_json(""),
    Json::array([
      ua_matterhorn_06_002_failure_for_test(),
      ua_matterhorn_06_003_failure_for_test(),
      ua_matterhorn_11_001_failure_for_test(Json::string("No top-level /Lang")),
    ]),
  )
}

///|
test "PdfDocument test_matterhorn_json accepts PDF/UA metadata" {
  let document = try! @pdflite.pdf_ua_create_pdfua1(
    "Accessible Title", @geometry.paper_a4, 1,
  )
  @test.assert_eq(try! document.test_matterhorn_json("06-001"), Json::array([]))
  @test.assert_eq(try! document.test_matterhorn_json("06-002"), Json::array([]))
  @test.assert_eq(try! document.test_matterhorn_json("06-003"), Json::array([]))
  @test.assert_eq(try! document.test_matterhorn_json("07-001"), Json::array([]))
  @test.assert_eq(try! document.test_matterhorn_json("07-002"), Json::array([]))
}

///|
test "PdfDocument test_matterhorn_json detects false DisplayDocTitle" {
  let document = ua_matterhorn_document_for_test([], root_extras=[
    ua_matterhorn_display_doc_title_for_test(false),
  ])
  @test.assert_eq(try! document.test_matterhorn_json("07-001"), Json::array([]))
  @test.assert_eq(
    try! document.test_matterhorn_json("07-002"),
    Json::array([ua_matterhorn_07_002_failure_for_test()]),
  )
}

///|
test "PdfDocument test_matterhorn_json checks top-level language" {
  let missing = ua_matterhorn_document_for_test([])
  @test.assert_eq(
    try! missing.test_matterhorn_json("11-001"),
    Json::array([
      ua_matterhorn_11_001_failure_for_test(Json::string("No top-level /Lang")),
    ]),
  )

  let empty = ua_matterhorn_document_for_test([], root_extras=[
    (ua_matterhorn_name_for_test("/Lang"), PdfString(@ascii.encode(""))),
  ])
  @test.assert_eq(
    try! empty.test_matterhorn_json("11-001"),
    Json::array([
      ua_matterhorn_11_001_failure_for_test(
        Json::string("Top-level /Lang is empty"),
      ),
    ]),
  )

  let present = ua_matterhorn_document_for_test([], root_extras=[
    (ua_matterhorn_name_for_test("/Lang"), PdfString(@ascii.encode("en-US"))),
  ])
  @test.assert_eq(try! present.test_matterhorn_json("11-001"), Json::array([]))
}

///|
test "PdfDocument test_matterhorn_json preserves source no-op language checks" {
  let document = ua_matterhorn_document_for_test([])
  for name in ["11-002", "11-003", "11-004", "11-005", "11-006"] {
    @test.assert_eq(try! document.test_matterhorn_json(name), Json::array([]))
  }
}
