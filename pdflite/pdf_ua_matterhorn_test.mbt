///|
fn ua_matterhorn_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn ua_matterhorn_failure_for_test(
  name : String,
  section : String,
  error : String,
  extra : Json,
) -> Json {
  Json::object(
    Map::of([
      ("name", Json::string(name)),
      ("section", Json::string(section)),
      ("error", Json::string(error)),
      ("extra", extra),
    ]),
  )
}

///|
fn ua_matterhorn_01_003_failure_for_test() -> Json {
  ua_matterhorn_failure_for_test(
    "01-003",
    "UA1:7.1-1",
    "Content marked as Artifact is present inside tagged content.",
    Json::null(),
  )
}

///|
fn ua_matterhorn_01_004_failure_for_test() -> Json {
  ua_matterhorn_failure_for_test(
    "01-004",
    "UA1:7.1-1",
    "Tagged content is present inside content marked as Artifact.",
    Json::null(),
  )
}

///|
fn ua_matterhorn_01_005_failure_for_test(extra : Json) -> Json {
  ua_matterhorn_failure_for_test(
    "01-005", "UA1:7-1-2", "Content is neither marked as Artifact nor tagged as real content.",
    extra,
  )
}

///|
fn ua_matterhorn_01_007_failure_for_test() -> Json {
  ua_matterhorn_failure_for_test(
    "01-007",
    "UA1:7-1-11",
    "Suspects entry has a value of true.",
    Json::null(),
  )
}

///|
fn ua_matterhorn_document_for_test(
  ops : ArrayView[@pdflite.PdfContentOp],
  root_extras? : ArrayView[(@pdflite.PdfName, @pdflite.PdfObject)] = [],
) -> @pdflite.PdfDocument {
  let doc = @pdflite.pdf_document_empty()
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    content: [try! @pdflite.pdf_content_stream_of_ops(ops)],
  }
  let page_root = try! doc.add_pagetree([page])
  ignore(try! doc.add_root(page_root, root_extras))
  doc
}

///|
fn ua_matterhorn_form_stream_for_test(
  ops : ArrayView[@pdflite.PdfContentOp],
) -> @pdflite.PdfObject {
  let stream = try! @pdflite.pdf_content_stream_of_ops(ops)
  try! (try! stream.add_dict_entry(
    ua_matterhorn_name_for_test("/Subtype"),
    PdfNameObject(ua_matterhorn_name_for_test("/Form")),
  )).add_dict_entry(
    ua_matterhorn_name_for_test("/Resources"),
    PdfDictionary([]),
  )
}

///|
test "PdfDocument test_matterhorn_json detects content artifact nesting" {
  let span = ua_matterhorn_name_for_test("/Span")
  let artifact = ua_matterhorn_name_for_test("/Artifact")
  let document = ua_matterhorn_document_for_test([
    Op_BDC(span, PdfDictionary([])),
    Op_BMC(artifact),
    Op_EMC,
    Op_EMC,
  ])
  @test.assert_eq(
    try! document.test_matterhorn_json("01-003"),
    Json::array([ua_matterhorn_01_003_failure_for_test()]),
  )
  @test.assert_eq(
    try! @pdflite.pdf_ua_test_matterhorn_json(document, "01-004"),
    Json::array([ua_matterhorn_01_004_failure_for_test()]),
  )
  @test.assert_eq(
    try! document.test_matterhorn_json(""),
    Json::array([
      ua_matterhorn_01_003_failure_for_test(),
      ua_matterhorn_01_004_failure_for_test(),
    ]),
  )
}

///|
test "PdfDocument test_matterhorn_json scans Form XObject content markers" {
  let span = ua_matterhorn_name_for_test("/Span")
  let artifact = ua_matterhorn_name_for_test("/Artifact")
  let document = ua_matterhorn_document_for_test([])
  document.add_object_given_number(
    20,
    ua_matterhorn_form_stream_for_test([
      Op_BDC(span, PdfDictionary([])),
      Op_BMC(artifact),
      Op_EMC,
      Op_EMC,
    ]),
  )
  @test.assert_eq(
    try! document.test_matterhorn_json("01-003"),
    Json::array([ua_matterhorn_01_003_failure_for_test()]),
  )
  @test.assert_eq(try! document.test_matterhorn_json("01-005"), Json::array([]))
}

///|
test "PdfDocument test_matterhorn_json detects unmarked real content" {
  let span = ua_matterhorn_name_for_test("/Span")
  let mcid = ua_matterhorn_name_for_test("/MCID")
  let unmarked = ua_matterhorn_document_for_test([Op_Tj(b"A")])
  @test.assert_eq(
    try! unmarked.test_matterhorn_json("01-005"),
    Json::array([ua_matterhorn_01_005_failure_for_test(Json::null())]),
  )

  let tagged = ua_matterhorn_document_for_test([
    Op_BDC(span, PdfDictionary([(mcid, PdfInteger(0))])),
    Op_Tj(b"A"),
    Op_EMC,
  ])
  @test.assert_eq(try! tagged.test_matterhorn_json("01-005"), Json::array([]))

  let clipping_only = ua_matterhorn_document_for_test([
    Op_m(0.0, 0.0),
    Op_l(1.0, 1.0),
    Op_W,
  ])
  @test.assert_eq(
    try! clipping_only.test_matterhorn_json("01-005"),
    Json::array([]),
  )

  let malformed = ua_matterhorn_document_for_test([Op_EMC])
  @test.assert_eq(
    try! malformed.test_matterhorn_json("01-005"),
    Json::array([
      ua_matterhorn_01_005_failure_for_test(Json::string("empty stack")),
    ]),
  )
}

///|
test "PdfDocument test_matterhorn_json detects MarkInfo suspects" {
  let document = ua_matterhorn_document_for_test([], root_extras=[
    (
      ua_matterhorn_name_for_test("/MarkInfo"),
      PdfDictionary([
        (ua_matterhorn_name_for_test("/Suspects"), PdfBoolean(true)),
      ]),
    ),
  ])
  @test.assert_eq(
    try! document.test_matterhorn_json("01-007"),
    Json::array([ua_matterhorn_01_007_failure_for_test()]),
  )
  @test.assert_eq(
    try! @pdflite.pdf_ua_test_matterhorn_print(document, "01-007"),
    @utf8.encode("01-007 UA1:7-1-11 Suspects entry has a value of true. \n"),
  )
}

///|
test "PdfDocument test_matterhorn_json rejects unsupported individual checks" {
  let document = ua_matterhorn_document_for_test([])
  let result : Result[Json, Error] = try? document.test_matterhorn_json(
    "02-001",
  )
  guard result is Err(@pdflite.PdfError::SoftError(_)) else {
    fail("expected unsupported Matterhorn test to raise SoftError")
  }
}
