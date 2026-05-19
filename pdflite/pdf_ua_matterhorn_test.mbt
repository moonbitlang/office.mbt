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
fn ua_matterhorn_02_001_failure_for_test(extra : Json) -> Json {
  ua_matterhorn_failure_for_test(
    "02-001", "UA1:7.1-3", "One or more non-standard tag’s mapping does not terminate with a standard type.",
    extra,
  )
}

///|
fn ua_matterhorn_02_003_failure_for_test() -> Json {
  ua_matterhorn_failure_for_test(
    "02-003",
    "UA1:7.1-3",
    "A circular mapping exists.",
    Json::string("STOP. If rolemap circular, cannot proceed with other checks."),
  )
}

///|
fn ua_matterhorn_02_004_failure_for_test(extra : Json) -> Json {
  ua_matterhorn_failure_for_test(
    "02-004", "UA1:7.1-4", "One or more standard types are remapped.", extra,
  )
}

///|
fn ua_matterhorn_06_001_failure_for_test() -> Json {
  ua_matterhorn_failure_for_test(
    "06-001",
    "UA1:7.1-8",
    "Document does not contain an XMP metadata stream",
    Json::null(),
  )
}

///|
fn ua_matterhorn_06_002_failure_for_test() -> Json {
  ua_matterhorn_failure_for_test(
    "06-002",
    "UA1:5",
    "The XMP metadata stream in the Catalog dictionary does not include the PDF/UA identifier.",
    Json::null(),
  )
}

///|
fn ua_matterhorn_06_003_failure_for_test() -> Json {
  ua_matterhorn_failure_for_test(
    "06-003",
    "UA1:7.1-8",
    "XMP metadata stream does not contain dc:title",
    Json::null(),
  )
}

///|
fn ua_matterhorn_07_001_failure_for_test() -> Json {
  ua_matterhorn_failure_for_test(
    "07-001",
    "UA1:7.1-9",
    "ViewerPreferences dictionary of the Catalog dictionary does not contain a DisplayDocTitle entry",
    Json::null(),
  )
}

///|
fn ua_matterhorn_07_002_failure_for_test() -> Json {
  ua_matterhorn_failure_for_test(
    "07-002",
    "UA1:7.1-9",
    "ViewerPreferences dictionary of the Catalog dictionary contains a DisplayDocTitle entry with a value of false",
    Json::null(),
  )
}

///|
fn ua_matterhorn_20_001_failure_for_test() -> Json {
  ua_matterhorn_failure_for_test(
    "20-001",
    "UA1:7.10-1",
    "Name entry is missing or has an empty string as its value in an Optional Content Configuration Dictionary in the Configs entry in the OCProperties entry in the Catalog dictionary.",
    Json::null(),
  )
}

///|
fn ua_matterhorn_20_002_failure_for_test(extra : Json) -> Json {
  ua_matterhorn_failure_for_test(
    "20-002", "UA1:7.10-1", "Name entry is missing or has an empty string as its value in an Optional Content Configuration Dictionary that is the value of the D entry in the OCProperties entry in the Catalog dictionary.",
    extra,
  )
}

///|
fn ua_matterhorn_20_003_failure_for_test() -> Json {
  ua_matterhorn_failure_for_test(
    "20-003",
    "UA1:7.10-2",
    "An AS entry appears in an Optional Content Configuration Dictionary.",
    Json::null(),
  )
}

///|
fn ua_matterhorn_30_001_failure_for_test() -> Json {
  ua_matterhorn_failure_for_test(
    "30-001",
    "UA1:7.2",
    "A reference XObject is present.",
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
fn ua_matterhorn_document_with_metadata_for_test(
  metadata : BytesView,
  root_extras? : ArrayView[(@pdflite.PdfName, @pdflite.PdfObject)] = [],
) -> @pdflite.PdfDocument {
  let document = ua_matterhorn_document_for_test([], root_extras~)
  try! document.set_metadata_from_bytes(metadata)
}

///|
fn ua_matterhorn_rolemap_for_test(
  entries : ArrayView[(String, String)],
) -> (@pdflite.PdfName, @pdflite.PdfObject) {
  (
    ua_matterhorn_name_for_test("/StructTreeRoot"),
    PdfDictionary([
      (
        ua_matterhorn_name_for_test("/RoleMap"),
        PdfDictionary(
          [
            for entry in entries => {
              (
                ua_matterhorn_name_for_test(entry.0),
                PdfNameObject(ua_matterhorn_name_for_test(entry.1)),
              )
            }
          ],
        ),
      ),
    ]),
  )
}

///|
fn ua_matterhorn_ocproperties_for_test(
  entries : ArrayView[(@pdflite.PdfName, @pdflite.PdfObject)],
) -> (@pdflite.PdfName, @pdflite.PdfObject) {
  (
    ua_matterhorn_name_for_test("/OCProperties"),
    PdfDictionary([ for entry in entries => entry ]),
  )
}

///|
fn ua_matterhorn_display_doc_title_for_test(
  value : Bool,
) -> (@pdflite.PdfName, @pdflite.PdfObject) {
  (
    ua_matterhorn_name_for_test("/ViewerPreferences"),
    PdfDictionary([
      (ua_matterhorn_name_for_test("/DisplayDocTitle"), PdfBoolean(value)),
    ]),
  )
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
      ua_matterhorn_06_001_failure_for_test(),
      ua_matterhorn_07_001_failure_for_test(),
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
    "09-004",
  )
  guard result is Err(@pdflite.PdfError::SoftError(_)) else {
    fail("expected unsupported Matterhorn test to raise SoftError")
  }
}

///|
test "PdfDocument test_matterhorn_json detects role map target chains" {
  let bad = ua_matterhorn_document_for_test([], root_extras=[
    ua_matterhorn_rolemap_for_test([("/Custom", "/StillCustom")]),
  ])
  @test.assert_eq(
    try! bad.test_matterhorn_json("02-001"),
    Json::array([ua_matterhorn_02_001_failure_for_test(Json::string("/Custom"))]),
  )
  @test.assert_eq(
    try! bad.test_matterhorn_text("02-001"),
    @utf8.encode(
      "02-001 UA1:7.1-3 One or more non-standard tag’s mapping does not terminate with a standard type. (\"/Custom\")\n",
    ),
  )
  @test.assert_eq(try! bad.test_matterhorn_json("02-003"), Json::array([]))
  @test.assert_eq(try! bad.test_matterhorn_json("02-004"), Json::array([]))

  let good = ua_matterhorn_document_for_test([], root_extras=[
    ua_matterhorn_rolemap_for_test([
      ("/Custom", "/Intermediate"),
      ("/Intermediate", "/P"),
    ]),
  ])
  @test.assert_eq(try! good.test_matterhorn_json("02-001"), Json::array([]))
}

///|
test "PdfDocument test_matterhorn_json prechecks circular role maps" {
  let document = ua_matterhorn_document_for_test([], root_extras=[
    ua_matterhorn_rolemap_for_test([
      ("/Custom", "/Other"),
      ("/Other", "/Custom"),
    ]),
  ])
  @test.assert_eq(
    try! document.test_matterhorn_json("02-003"),
    Json::array([ua_matterhorn_02_003_failure_for_test()]),
  )
  @test.assert_eq(
    try! document.test_matterhorn_json("02-001"),
    Json::array([ua_matterhorn_02_003_failure_for_test()]),
  )
  @test.assert_eq(
    try! document.test_matterhorn_json("06-001"),
    Json::array([ua_matterhorn_02_003_failure_for_test()]),
  )
}

///|
test "PdfDocument test_matterhorn_json detects standard type remapping" {
  let document = ua_matterhorn_document_for_test([], root_extras=[
    ua_matterhorn_rolemap_for_test([("/P", "/Span")]),
  ])
  @test.assert_eq(try! document.test_matterhorn_json("02-001"), Json::array([]))
  @test.assert_eq(
    try! document.test_matterhorn_json("02-004"),
    Json::array([ua_matterhorn_02_004_failure_for_test(Json::string("/P"))]),
  )
}

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
    root_extras=[ua_matterhorn_display_doc_title_for_test(true)],
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
    ]),
  )
}

///|
test "PdfDocument test_matterhorn_json accepts PDF/UA metadata" {
  let document = try! @pdflite.pdf_ua_create_pdfua1(
    "Accessible Title", @pdflite.paper_a4, 1,
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
test "PdfDocument test_matterhorn_json detects optional content config names" {
  let key_configs = ua_matterhorn_name_for_test("/Configs")
  let key_name = ua_matterhorn_name_for_test("/Name")
  let missing_name = ua_matterhorn_document_for_test([], root_extras=[
    ua_matterhorn_ocproperties_for_test([
      (key_configs, PdfArray([PdfDictionary([])])),
    ]),
  ])
  @test.assert_eq(
    try! missing_name.test_matterhorn_json("20-001"),
    Json::array([ua_matterhorn_20_001_failure_for_test()]),
  )

  let empty_name = ua_matterhorn_document_for_test([], root_extras=[
    ua_matterhorn_ocproperties_for_test([
      (
        key_configs,
        PdfArray([
          PdfDictionary([
            (key_name, PdfNameObject(ua_matterhorn_name_for_test(""))),
          ]),
        ]),
      ),
    ]),
  ])
  @test.assert_eq(
    try! empty_name.test_matterhorn_json("20-001"),
    Json::array([ua_matterhorn_20_001_failure_for_test()]),
  )

  let valid = ua_matterhorn_document_for_test([], root_extras=[
    ua_matterhorn_ocproperties_for_test([
      (
        key_configs,
        PdfArray([
          PdfDictionary([
            (key_name, PdfNameObject(ua_matterhorn_name_for_test("/Layer"))),
          ]),
        ]),
      ),
    ]),
  ])
  @test.assert_eq(try! valid.test_matterhorn_json("20-001"), Json::array([]))
}

///|
test "PdfDocument test_matterhorn_json detects default optional content names" {
  let key_d = ua_matterhorn_name_for_test("/D")
  let key_name = ua_matterhorn_name_for_test("/Name")
  let missing_name = ua_matterhorn_document_for_test([], root_extras=[
    ua_matterhorn_ocproperties_for_test([(key_d, PdfDictionary([]))]),
  ])
  @test.assert_eq(
    try! missing_name.test_matterhorn_json("20-002"),
    Json::array([
      ua_matterhorn_20_002_failure_for_test(Json::string("not present")),
    ]),
  )

  let empty_name = ua_matterhorn_document_for_test([], root_extras=[
    ua_matterhorn_ocproperties_for_test([
      (key_d, PdfDictionary([(key_name, PdfString(@ascii.encode("")))])),
    ]),
  ])
  @test.assert_eq(
    try! empty_name.test_matterhorn_json("20-002"),
    Json::array([
      ua_matterhorn_20_002_failure_for_test(Json::string("empty string")),
    ]),
  )

  let valid = ua_matterhorn_document_for_test([], root_extras=[
    ua_matterhorn_ocproperties_for_test([
      (key_d, PdfDictionary([(key_name, PdfString(@ascii.encode("Default")))])),
    ]),
  ])
  @test.assert_eq(try! valid.test_matterhorn_json("20-002"), Json::array([]))
}

///|
test "PdfDocument test_matterhorn_json detects optional content AS entries" {
  let key_as = ua_matterhorn_name_for_test("/AS")
  let key_configs = ua_matterhorn_name_for_test("/Configs")
  let key_d = ua_matterhorn_name_for_test("/D")
  let default_as = ua_matterhorn_document_for_test([], root_extras=[
    ua_matterhorn_ocproperties_for_test([
      (key_d, PdfDictionary([(key_as, PdfArray([]))])),
    ]),
  ])
  @test.assert_eq(
    try! default_as.test_matterhorn_json("20-003"),
    Json::array([ua_matterhorn_20_003_failure_for_test()]),
  )

  let config_as = ua_matterhorn_document_for_test([], root_extras=[
    ua_matterhorn_ocproperties_for_test([
      (key_configs, PdfArray([PdfDictionary([(key_as, PdfArray([]))])])),
    ]),
  ])
  @test.assert_eq(
    try! config_as.test_matterhorn_json("20-003"),
    Json::array([ua_matterhorn_20_003_failure_for_test()]),
  )

  let valid = ua_matterhorn_document_for_test([], root_extras=[
    ua_matterhorn_ocproperties_for_test([
      (key_d, PdfDictionary([])),
      (key_configs, PdfArray([PdfDictionary([])])),
    ]),
  ])
  @test.assert_eq(try! valid.test_matterhorn_json("20-003"), Json::array([]))
}

///|
test "PdfDocument test_matterhorn_json detects reference XObjects" {
  let key_ref = ua_matterhorn_name_for_test("/Ref")
  let document = ua_matterhorn_document_for_test([])
  document.add_object_given_number(
    40,
    try! ua_matterhorn_form_stream_for_test([]).add_dict_entry(
      key_ref,
      PdfDictionary([]),
    ),
  )
  @test.assert_eq(
    try! document.test_matterhorn_json("30-001"),
    Json::array([ua_matterhorn_30_001_failure_for_test()]),
  )

  let no_ref = ua_matterhorn_document_for_test([])
  no_ref.add_object_given_number(40, ua_matterhorn_form_stream_for_test([]))
  @test.assert_eq(try! no_ref.test_matterhorn_json("30-001"), Json::array([]))

  let non_form = ua_matterhorn_document_for_test([])
  non_form.add_object_given_number(
    40,
    PdfDictionary([(key_ref, PdfDictionary([]))]),
  )
  @test.assert_eq(try! non_form.test_matterhorn_json("30-001"), Json::array([]))
}
