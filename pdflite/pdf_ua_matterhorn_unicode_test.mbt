///|
test "PdfDocument test_matterhorn_json checks character code Unicode mapping" {
  let missing_encoding_font = ua_matterhorn_font_for_test(
    "/Type1",
    "/MissingEncoding",
    None,
    None,
  )
  let missing_encoding = ua_matterhorn_font_resource_document_for_test(
    missing_encoding_font,
  )
  @test.assert_eq(
    try! missing_encoding.test_matterhorn_json("10-001"),
    Json::array([
      ua_matterhorn_10_001_failure_for_test(Json::string("Not a Type 0 font")),
    ]),
  )

  let bad_encoding_name = ua_matterhorn_font_resource_document_for_test(
    ua_matterhorn_font_for_test(
      "/Type1",
      "/BadEncoding",
      Some("/BadEncoding"),
      None,
    ),
  )
  @test.assert_eq(
    try! bad_encoding_name.test_matterhorn_json("10-001"),
    Json::array([
      ua_matterhorn_10_001_failure_for_test(Json::string("No /Differences")),
    ]),
  )

  let bad_difference = ua_matterhorn_font_resource_document_for_test(
    ua_matterhorn_font_for_test("/Type1", "/BadDifference", None, None, extras=[
      (
        ua_matterhorn_name_for_test("/Encoding"),
        PdfDictionary([
          (
            ua_matterhorn_name_for_test("/Differences"),
            PdfArray([
              PdfInteger(65),
              PdfNameObject(ua_matterhorn_name_for_test("/DefinitelyNotAGlyph")),
            ]),
          ),
        ]),
      ),
    ]),
  )
  @test.assert_eq(
    try! bad_difference.test_matterhorn_json("10-001"),
    Json::array([ua_matterhorn_10_001_failure_for_test(Json::null())]),
  )

  let winansi = ua_matterhorn_font_resource_document_for_test(
    ua_matterhorn_font_for_test(
      "/Type1",
      "/WinAnsi",
      Some("/WinAnsiEncoding"),
      None,
    ),
  )
  @test.assert_eq(try! winansi.test_matterhorn_json("10-001"), Json::array([]))

  let valid_difference = ua_matterhorn_font_resource_document_for_test(
    ua_matterhorn_font_for_test("/Type1", "/ValidDifference", None, None, extras=[
      (
        ua_matterhorn_name_for_test("/Encoding"),
        PdfDictionary([
          (
            ua_matterhorn_name_for_test("/Differences"),
            PdfArray([
              PdfInteger(65),
              PdfNameObject(ua_matterhorn_name_for_test("/A")),
            ]),
          ),
        ]),
      ),
    ]),
  )
  @test.assert_eq(
    try! valid_difference.test_matterhorn_json("10-001"),
    Json::array([]),
  )

  let with_tounicode = ua_matterhorn_font_resource_document_for_test(
    ua_matterhorn_font_for_test("/Type1", "/WithToUnicode", None, None, extras=[
      (
        ua_matterhorn_name_for_test("/ToUnicode"),
        @pdflite.pdf_stream(PdfDictionary([]), StreamGot(b"")),
      ),
    ]),
  )
  @test.assert_eq(
    try! with_tounicode.test_matterhorn_json("10-001"),
    Json::array([]),
  )

  let type0_unimplemented = ua_matterhorn_font_resource_document_for_test(
    ua_matterhorn_font_for_test("/Type0", "/Composite", None, None),
  )
  @test.assert_eq(
    try! type0_unimplemented.test_matterhorn_json("10-001"),
    Json::array([]),
  )

  let cid_font_skipped = ua_matterhorn_font_resource_document_for_test(
    ua_matterhorn_font_for_test("/CIDFontType2", "/CID", None, None),
  )
  @test.assert_eq(
    try! cid_font_skipped.test_matterhorn_json("10-001"),
    Json::array([]),
  )
}
