///|
test "PdfDocument test_matterhorn_json detects Type0 CIDSystemInfo mismatches" {
  let registry_mismatch = ua_matterhorn_document_for_test([])
  registry_mismatch.add_object_given_number(
    40,
    ua_matterhorn_type0_font_for_test(PdfIndirect(42), 41),
  )
  registry_mismatch.add_object_given_number(
    41,
    ua_matterhorn_cid_font_for_test("Other", "UCS"),
  )
  registry_mismatch.add_object_given_number(
    42,
    ua_matterhorn_cmap_for_test("Adobe", "UCS"),
  )
  @test.assert_eq(
    try! registry_mismatch.test_matterhorn_json("31-001"),
    Json::array([ua_matterhorn_31_001_failure_for_test()]),
  )

  let ordering_mismatch = ua_matterhorn_document_for_test([])
  ordering_mismatch.add_object_given_number(
    40,
    ua_matterhorn_type0_font_for_test(PdfIndirect(42), 41),
  )
  ordering_mismatch.add_object_given_number(
    41,
    ua_matterhorn_cid_font_for_test("Adobe", "Japan1"),
  )
  ordering_mismatch.add_object_given_number(
    42,
    ua_matterhorn_cmap_for_test("Adobe", "UCS"),
  )
  @test.assert_eq(
    try! ordering_mismatch.test_matterhorn_json("31-002"),
    Json::array([ua_matterhorn_31_002_failure_for_test()]),
  )

  let identity_encoding = ua_matterhorn_document_for_test([])
  identity_encoding.add_object_given_number(
    40,
    ua_matterhorn_type0_font_for_test(
      PdfNameObject(ua_matterhorn_name_for_test("/Identity-H")),
      41,
    ),
  )
  identity_encoding.add_object_given_number(
    41,
    ua_matterhorn_cid_font_for_test("Other", "Japan1"),
  )
  @test.assert_eq(
    try! identity_encoding.test_matterhorn_json("31-001"),
    Json::array([]),
  )
  @test.assert_eq(
    try! identity_encoding.test_matterhorn_json("31-002"),
    Json::array([]),
  )
  @test.assert_eq(
    try! identity_encoding.test_matterhorn_json("31-003"),
    Json::array([]),
  )

  let matching = ua_matterhorn_document_for_test([])
  matching.add_object_given_number(
    40,
    ua_matterhorn_type0_font_for_test(PdfIndirect(42), 41),
  )
  matching.add_object_given_number(
    41,
    ua_matterhorn_cid_font_for_test("Adobe", "UCS"),
  )
  matching.add_object_given_number(
    42,
    ua_matterhorn_cmap_for_test("Adobe", "UCS"),
  )
  @test.assert_eq(try! matching.test_matterhorn_json("31-001"), Json::array([]))
  @test.assert_eq(try! matching.test_matterhorn_json("31-002"), Json::array([]))

  let source_supplement_comparison = ua_matterhorn_document_for_test([])
  source_supplement_comparison.add_object_given_number(
    40,
    ua_matterhorn_type0_font_for_test(PdfIndirect(42), 41),
  )
  source_supplement_comparison.add_object_given_number(
    41,
    ua_matterhorn_cid_font_for_test("Adobe", "UCS"),
  )
  source_supplement_comparison.add_object_given_number(
    42,
    ua_matterhorn_cmap_for_test("Adobe", "UCS"),
  )
  @test.assert_eq(
    try! source_supplement_comparison.test_matterhorn_json("31-003"),
    Json::array([ua_matterhorn_31_003_failure_for_test()]),
  )

  let source_supplement_match = ua_matterhorn_document_for_test([])
  source_supplement_match.add_object_given_number(
    40,
    ua_matterhorn_type0_font_for_test(PdfIndirect(42), 41),
  )
  source_supplement_match.add_object_given_number(
    41,
    ua_matterhorn_cid_font_for_test("Other", "Adobe"),
  )
  source_supplement_match.add_object_given_number(
    42,
    ua_matterhorn_cmap_for_test("Adobe", "UCS"),
  )
  @test.assert_eq(
    try! source_supplement_match.test_matterhorn_json("31-003"),
    Json::array([]),
  )
}

///|
test "PdfDocument test_matterhorn_json checks Type2 CIDToGIDMap" {
  let missing_map = ua_matterhorn_document_for_test([])
  let missing_font = ua_matterhorn_cid_font_type2_for_test(None)
  missing_map.add_object_given_number(40, missing_font)
  @test.assert_eq(
    try! missing_map.test_matterhorn_json("31-004"),
    Json::array([
      ua_matterhorn_31_004_failure_for_test(
        ua_matterhorn_serialized_object_extra_for_test(missing_font),
      ),
    ]),
  )
  @test.assert_eq(
    try! missing_map.test_matterhorn_json("31-005"),
    Json::array([ua_matterhorn_31_005_failure_for_test()]),
  )

  let invalid_map = ua_matterhorn_document_for_test([])
  let invalid_font = ua_matterhorn_cid_font_type2_for_test(Some(PdfInteger(7)))
  invalid_map.add_object_given_number(40, invalid_font)
  @test.assert_eq(
    try! invalid_map.test_matterhorn_json("31-004"),
    Json::array([
      ua_matterhorn_31_004_failure_for_test(
        ua_matterhorn_serialized_object_extra_for_test(invalid_font),
      ),
    ]),
  )
  @test.assert_eq(
    try! invalid_map.test_matterhorn_json("31-005"),
    Json::array([]),
  )

  let identity_map = ua_matterhorn_document_for_test([])
  identity_map.add_object_given_number(
    40,
    ua_matterhorn_cid_font_type2_for_test(
      Some(PdfNameObject(ua_matterhorn_name_for_test("/Identity"))),
    ),
  )
  @test.assert_eq(
    try! identity_map.test_matterhorn_json("31-004"),
    Json::array([]),
  )
  @test.assert_eq(
    try! identity_map.test_matterhorn_json("31-005"),
    Json::array([]),
  )

  let stream_map = ua_matterhorn_document_for_test([])
  stream_map.add_object_given_number(
    40,
    ua_matterhorn_cid_font_type2_for_test(
      Some(@syntax.pdf_stream(PdfDictionary([]), StreamGot(b"\x00\x01"))),
    ),
  )
  @test.assert_eq(
    try! stream_map.test_matterhorn_json("31-004"),
    Json::array([]),
  )
  @test.assert_eq(
    try! stream_map.test_matterhorn_json("31-005"),
    Json::array([]),
  )

  let non_cid_type2 = ua_matterhorn_document_for_test([])
  non_cid_type2.add_object_given_number(
    40,
    PdfDictionary([
      (
        ua_matterhorn_name_for_test("/Subtype"),
        PdfNameObject(ua_matterhorn_name_for_test("/CIDFontType0")),
      ),
    ]),
  )
  @test.assert_eq(
    try! non_cid_type2.test_matterhorn_json("31-004"),
    Json::array([]),
  )
  @test.assert_eq(
    try! non_cid_type2.test_matterhorn_json("31-005"),
    Json::array([]),
  )
}

///|
test "PdfDocument test_matterhorn_json checks CMap names" {
  let unlisted_encoding = ua_matterhorn_document_for_test([])
  unlisted_encoding.add_object_given_number(
    40,
    ua_matterhorn_type0_font_for_test(
      PdfNameObject(ua_matterhorn_name_for_test("/Private-H")),
      41,
    ),
  )
  @test.assert_eq(
    try! unlisted_encoding.test_matterhorn_json("31-006"),
    Json::array([ua_matterhorn_31_006_failure_for_test("/Private-H")]),
  )

  let listed_encoding = ua_matterhorn_document_for_test([])
  listed_encoding.add_object_given_number(
    40,
    ua_matterhorn_type0_font_for_test(
      PdfNameObject(ua_matterhorn_name_for_test("/GB-EUC-H")),
      41,
    ),
  )
  @test.assert_eq(
    try! listed_encoding.test_matterhorn_json("31-006"),
    Json::array([]),
  )

  let source_typo_encoding = ua_matterhorn_document_for_test([])
  source_typo_encoding.add_object_given_number(
    40,
    ua_matterhorn_type0_font_for_test(
      PdfNameObject(ua_matterhorn_name_for_test("/KSCms-UHS-HW-V")),
      41,
    ),
  )
  @test.assert_eq(
    try! source_typo_encoding.test_matterhorn_json("31-006"),
    Json::array([]),
  )

  let corrected_encoding = ua_matterhorn_document_for_test([])
  corrected_encoding.add_object_given_number(
    40,
    ua_matterhorn_type0_font_for_test(
      PdfNameObject(ua_matterhorn_name_for_test("/KSCms-UHC-HW-V")),
      41,
    ),
  )
  @test.assert_eq(
    try! corrected_encoding.test_matterhorn_json("31-006"),
    Json::array([ua_matterhorn_31_006_failure_for_test("/KSCms-UHC-HW-V")]),
  )

  let embedded_encoding = ua_matterhorn_document_for_test([])
  embedded_encoding.add_object_given_number(
    40,
    ua_matterhorn_type0_font_for_test(PdfIndirect(42), 41),
  )
  @test.assert_eq(
    try! embedded_encoding.test_matterhorn_json("31-006"),
    Json::array([]),
  )

  let non_type0 = ua_matterhorn_document_for_test([])
  non_type0.add_object_given_number(
    40,
    PdfDictionary([
      (
        ua_matterhorn_name_for_test("/Subtype"),
        PdfNameObject(ua_matterhorn_name_for_test("/Type1")),
      ),
      (
        ua_matterhorn_name_for_test("/Encoding"),
        PdfNameObject(ua_matterhorn_name_for_test("/Private-H")),
      ),
    ]),
  )
  @test.assert_eq(
    try! non_type0.test_matterhorn_json("31-006"),
    Json::array([]),
  )

  let unlisted_base = ua_matterhorn_document_for_test([])
  unlisted_base.add_object_given_number(
    42,
    PdfDictionary([
      (
        ua_matterhorn_name_for_test("/UseCMap"),
        PdfNameObject(ua_matterhorn_name_for_test("/PrivateBase-H")),
      ),
    ]),
  )
  @test.assert_eq(
    try! unlisted_base.test_matterhorn_json("31-008"),
    Json::array([ua_matterhorn_31_008_failure_for_test("/PrivateBase-H")]),
  )

  let listed_base = ua_matterhorn_document_for_test([])
  listed_base.add_object_given_number(
    42,
    PdfDictionary([
      (
        ua_matterhorn_name_for_test("/UseCMap"),
        PdfNameObject(ua_matterhorn_name_for_test("/Identity-H")),
      ),
    ]),
  )
  @test.assert_eq(
    try! listed_base.test_matterhorn_json("31-008"),
    Json::array([]),
  )

  let source_typo_base = ua_matterhorn_document_for_test([])
  source_typo_base.add_object_given_number(
    42,
    PdfDictionary([
      (
        ua_matterhorn_name_for_test("/UseCMap"),
        PdfNameObject(ua_matterhorn_name_for_test("/KSCms-UHS-HW-V")),
      ),
    ]),
  )
  @test.assert_eq(
    try! source_typo_base.test_matterhorn_json("31-008"),
    Json::array([]),
  )

  let corrected_base = ua_matterhorn_document_for_test([])
  corrected_base.add_object_given_number(
    42,
    PdfDictionary([
      (
        ua_matterhorn_name_for_test("/UseCMap"),
        PdfNameObject(ua_matterhorn_name_for_test("/KSCms-UHC-HW-V")),
      ),
    ]),
  )
  @test.assert_eq(
    try! corrected_base.test_matterhorn_json("31-008"),
    Json::array([ua_matterhorn_31_008_failure_for_test("/KSCms-UHC-HW-V")]),
  )

  let embedded_base = ua_matterhorn_document_for_test([])
  embedded_base.add_object_given_number(
    42,
    PdfDictionary([
      (
        ua_matterhorn_name_for_test("/UseCMap"),
        @syntax.pdf_stream(PdfDictionary([]), StreamGot(b"")),
      ),
    ]),
  )
  @test.assert_eq(
    try! embedded_base.test_matterhorn_json("31-008"),
    Json::array([]),
  )
}

///|
test "PdfDocument test_matterhorn_json compares CMap WMode values" {
  let mismatch = ua_matterhorn_document_for_test([])
  mismatch.add_object_given_number(
    42,
    ua_matterhorn_cmap_stream_for_test(Some(0), Some(1)),
  )
  @test.assert_eq(
    try! mismatch.test_matterhorn_json("31-007"),
    Json::array([ua_matterhorn_31_007_failure_for_test()]),
  )

  let matching = ua_matterhorn_document_for_test([])
  matching.add_object_given_number(
    42,
    ua_matterhorn_cmap_stream_for_test(Some(1), Some(1)),
  )
  @test.assert_eq(try! matching.test_matterhorn_json("31-007"), Json::array([]))

  let default_stream_wmode = ua_matterhorn_document_for_test([])
  default_stream_wmode.add_object_given_number(
    42,
    ua_matterhorn_cmap_stream_for_test(Some(0), None),
  )
  @test.assert_eq(
    try! default_stream_wmode.test_matterhorn_json("31-007"),
    Json::array([]),
  )

  let no_dictionary_wmode = ua_matterhorn_document_for_test([])
  no_dictionary_wmode.add_object_given_number(
    42,
    ua_matterhorn_cmap_stream_for_test(None, Some(1)),
  )
  @test.assert_eq(
    try! no_dictionary_wmode.test_matterhorn_json("31-007"),
    Json::array([]),
  )
}

///|
test "PdfDocument test_matterhorn_json checks missing fonts" {
  let document = ua_matterhorn_document_for_test(
    [],
    resources=ua_matterhorn_font_resources_for_test([
      ("/F1", PdfIndirect(40)),
      ("/F2", PdfIndirect(41)),
      ("/F3", PdfIndirect(42)),
      ("/F4", PdfIndirect(43)),
    ]),
  )
  document.add_object_given_number(
    40,
    ua_matterhorn_font_for_test("/Type1", "/MissingOne", None, None),
  )
  document.add_object_given_number(
    41,
    ua_matterhorn_font_for_test("/Type3", "/InlineType3", None, None),
  )
  document.add_object_given_number(
    42,
    ua_matterhorn_font_for_test(
      "/Type1",
      "/EmbeddedOne",
      None,
      Some(ua_matterhorn_font_descriptor_with_file_for_test(None, b"font")),
    ),
  )
  document.add_object_given_number(
    43,
    ua_matterhorn_font_for_test(
      "/Type1",
      "/DescriptorMissing",
      Some("/MacRomanEncoding"),
      Some(ua_matterhorn_font_descriptor_for_test(Some(32))),
    ),
  )
  @test.assert_eq(
    try! document.test_matterhorn_json("31-009"),
    Json::array([
      ua_matterhorn_31_009_failure_for_test(
        Json::array([
          Json::string("1 /F1 /Type1 /MissingOne Built-in"),
          Json::string("1 /F4 /Type1 /DescriptorMissing /MacRomanEncoding"),
        ]),
      ),
    ]),
  )
}

///|
test "PdfDocument test_matterhorn_json preserves source no-op font-file checks" {
  let document = ua_matterhorn_document_for_test([])
  for
    name in [
      "31-011", "31-012", "31-013", "31-014", "31-015", "31-016", "31-018", "31-030",
    ] {
    @test.assert_eq(try! document.test_matterhorn_json(name), Json::array([]))
  }
}

///|
test "PdfDocument test_matterhorn_json checks TrueType encoding Matterhorn checks" {
  let missing_encoding = ua_matterhorn_document_for_test([])
  missing_encoding.add_object_given_number(
    40,
    ua_matterhorn_truetype_font_for_test(Some(32), None),
  )
  @test.assert_eq(
    try! missing_encoding.test_matterhorn_json("31-019"),
    Json::array([ua_matterhorn_31_019_failure_for_test()]),
  )

  let symbolic_missing_encoding = ua_matterhorn_document_for_test([])
  symbolic_missing_encoding.add_object_given_number(
    40,
    ua_matterhorn_truetype_font_for_test(Some(4), None),
  )
  @test.assert_eq(
    try! symbolic_missing_encoding.test_matterhorn_json("31-019"),
    Json::array([]),
  )

  let missing_base = ua_matterhorn_document_for_test([])
  missing_base.add_object_given_number(
    40,
    ua_matterhorn_truetype_font_for_test(
      Some(32),
      Some(ua_matterhorn_encoding_dictionary_for_test([])),
    ),
  )
  @test.assert_eq(
    try! missing_base.test_matterhorn_json("31-020"),
    Json::array([ua_matterhorn_31_020_failure_for_test()]),
  )

  let valid_base = ua_matterhorn_document_for_test([])
  valid_base.add_object_given_number(
    40,
    ua_matterhorn_truetype_font_for_test(
      Some(32),
      Some(
        ua_matterhorn_encoding_dictionary_for_test([
          (
            ua_matterhorn_name_for_test("/BaseEncoding"),
            PdfNameObject(ua_matterhorn_name_for_test("/WinAnsiEncoding")),
          ),
        ]),
      ),
    ),
  )
  @test.assert_eq(
    try! valid_base.test_matterhorn_json("31-020"),
    Json::array([]),
  )
  @test.assert_eq(
    try! valid_base.test_matterhorn_json("31-021"),
    Json::array([]),
  )

  let invalid_encoding_name = ua_matterhorn_document_for_test([])
  invalid_encoding_name.add_object_given_number(
    40,
    ua_matterhorn_truetype_font_for_test(
      Some(32),
      Some(PdfNameObject(ua_matterhorn_name_for_test("/MacExpertEncoding"))),
    ),
  )
  @test.assert_eq(
    try! invalid_encoding_name.test_matterhorn_json("31-021"),
    Json::array([ua_matterhorn_31_021_failure_for_test(Json::null())]),
  )

  let invalid_base = ua_matterhorn_document_for_test([])
  invalid_base.add_object_given_number(
    40,
    ua_matterhorn_truetype_font_for_test(
      Some(32),
      Some(
        ua_matterhorn_encoding_dictionary_for_test([
          (ua_matterhorn_name_for_test("/BaseEncoding"), PdfInteger(7)),
        ]),
      ),
    ),
  )
  @test.assert_eq(
    try! invalid_base.test_matterhorn_json("31-021"),
    Json::array([ua_matterhorn_31_021_failure_for_test(Json::string("7"))]),
  )

  let invalid_difference = ua_matterhorn_document_for_test([])
  invalid_difference.add_object_given_number(
    40,
    ua_matterhorn_truetype_font_for_test(
      Some(32),
      Some(
        ua_matterhorn_encoding_dictionary_for_test([
          (
            ua_matterhorn_name_for_test("/BaseEncoding"),
            PdfNameObject(ua_matterhorn_name_for_test("/WinAnsiEncoding")),
          ),
          (
            ua_matterhorn_name_for_test("/Differences"),
            PdfArray([
              PdfInteger(65),
              PdfNameObject(ua_matterhorn_name_for_test("/A")),
              PdfNameObject(ua_matterhorn_name_for_test("/DefinitelyNotAGlyph")),
            ]),
          ),
        ]),
      ),
    ),
  )
  @test.assert_eq(
    try! invalid_difference.test_matterhorn_json("31-022"),
    Json::array([ua_matterhorn_31_022_failure_for_test("/DefinitelyNotAGlyph")]),
  )

  let generated_difference_name = ua_matterhorn_document_for_test([])
  generated_difference_name.add_object_given_number(
    40,
    ua_matterhorn_truetype_font_for_test(
      Some(32),
      Some(
        ua_matterhorn_encoding_dictionary_for_test([
          (
            ua_matterhorn_name_for_test("/Differences"),
            PdfArray([
              PdfInteger(65),
              PdfNameObject(ua_matterhorn_name_for_test("/uni0041")),
            ]),
          ),
        ]),
      ),
    ),
  )
  @test.assert_eq(
    try! generated_difference_name.test_matterhorn_json("31-022"),
    Json::array([ua_matterhorn_31_022_failure_for_test("/uni0041")]),
  )

  let valid_difference = ua_matterhorn_document_for_test([])
  valid_difference.add_object_given_number(
    40,
    ua_matterhorn_truetype_font_for_test(
      Some(32),
      Some(
        ua_matterhorn_encoding_dictionary_for_test([
          (
            ua_matterhorn_name_for_test("/Differences"),
            PdfArray([
              PdfInteger(65),
              PdfNameObject(ua_matterhorn_name_for_test("/A")),
            ]),
          ),
        ]),
      ),
    ),
  )
  @test.assert_eq(
    try! valid_difference.test_matterhorn_json("31-022"),
    Json::array([]),
  )
}

///|
test "PdfDocument test_matterhorn_json checks TrueType cmap Matterhorn checks" {
  let encoding_with_differences = ua_matterhorn_encoding_dictionary_for_test([
    (
      ua_matterhorn_name_for_test("/Differences"),
      PdfArray([
        PdfInteger(65),
        PdfNameObject(ua_matterhorn_name_for_test("/A")),
      ]),
    ),
  ])

  let missing_unicode_cmap = ua_matterhorn_document_for_test([])
  missing_unicode_cmap.add_object_given_number(
    40,
    ua_matterhorn_truetype_font_with_file_for_test(
      Some(32),
      Some(encoding_with_differences),
      ua_matterhorn_truetype_cmap_font_for_test([(1, 0)]),
    ),
  )
  @test.assert_eq(
    try! missing_unicode_cmap.test_matterhorn_json("31-023"),
    Json::array([ua_matterhorn_31_023_failure_for_test()]),
  )

  let unicode_cmap = ua_matterhorn_document_for_test([])
  unicode_cmap.add_object_given_number(
    40,
    ua_matterhorn_truetype_font_with_file_for_test(
      Some(32),
      Some(encoding_with_differences),
      ua_matterhorn_truetype_cmap_font_for_test([(3, 1)]),
    ),
  )
  @test.assert_eq(
    try! unicode_cmap.test_matterhorn_json("31-023"),
    Json::array([]),
  )

  let no_fontfile = ua_matterhorn_document_for_test([])
  no_fontfile.add_object_given_number(
    40,
    ua_matterhorn_truetype_font_for_test(
      Some(32),
      Some(encoding_with_differences),
    ),
  )
  @test.assert_eq(
    try! no_fontfile.test_matterhorn_json("31-023"),
    Json::array([]),
  )

  let symbolic_encoding = ua_matterhorn_document_for_test([])
  symbolic_encoding.add_object_given_number(
    40,
    ua_matterhorn_truetype_font_for_test(
      Some(4),
      Some(PdfNameObject(ua_matterhorn_name_for_test("/WinAnsiEncoding"))),
    ),
  )
  @test.assert_eq(
    try! symbolic_encoding.test_matterhorn_json("31-024"),
    Json::array([ua_matterhorn_31_024_failure_for_test()]),
  )

  let non_symbolic_encoding = ua_matterhorn_document_for_test([])
  non_symbolic_encoding.add_object_given_number(
    40,
    ua_matterhorn_truetype_font_for_test(
      Some(32),
      Some(PdfNameObject(ua_matterhorn_name_for_test("/WinAnsiEncoding"))),
    ),
  )
  @test.assert_eq(
    try! non_symbolic_encoding.test_matterhorn_json("31-024"),
    Json::array([]),
  )

  let symbolic_non_symbolic_cmap = ua_matterhorn_document_for_test([])
  symbolic_non_symbolic_cmap.add_object_given_number(
    40,
    ua_matterhorn_truetype_font_with_file_for_test(
      Some(4),
      None,
      ua_matterhorn_truetype_cmap_font_for_test([(3, 1)]),
    ),
  )
  @test.assert_eq(
    try! symbolic_non_symbolic_cmap.test_matterhorn_json("31-017"),
    Json::array([
      ua_matterhorn_31_017_failure_for_test(Json::string("(3, 1) cmap")),
    ]),
  )
  @test.assert_eq(
    try! symbolic_non_symbolic_cmap.test_matterhorn_json("31-026"),
    Json::array([]),
  )

  let symbolic_cmaps = ua_matterhorn_document_for_test([])
  symbolic_cmaps.add_object_given_number(
    40,
    ua_matterhorn_truetype_font_with_file_for_test(
      Some(4),
      None,
      ua_matterhorn_truetype_cmap_font_for_test([(1, 8), (3, 0)]),
    ),
  )
  @test.assert_eq(
    try! symbolic_cmaps.test_matterhorn_json("31-017"),
    Json::array([]),
  )
  @test.assert_eq(
    try! symbolic_cmaps.test_matterhorn_json("31-026"),
    Json::array([]),
  )

  let symbolic_no_cmap = ua_matterhorn_document_for_test([])
  symbolic_no_cmap.add_object_given_number(
    40,
    ua_matterhorn_truetype_font_with_file_for_test(Some(4), None, b"\x00"),
  )
  @test.assert_eq(
    try! symbolic_no_cmap.test_matterhorn_json("31-025"),
    Json::array([ua_matterhorn_31_025_failure_for_test()]),
  )

  let symbolic_missing_fontfile = ua_matterhorn_document_for_test([])
  symbolic_missing_fontfile.add_object_given_number(
    40,
    ua_matterhorn_truetype_font_for_test(Some(4), None),
  )
  @test.assert_eq(
    try! symbolic_missing_fontfile.test_matterhorn_json("31-025"),
    Json::array([]),
  )

  let multiple_without_symbol_cmap = ua_matterhorn_document_for_test([])
  multiple_without_symbol_cmap.add_object_given_number(
    40,
    ua_matterhorn_truetype_font_with_file_for_test(
      Some(4),
      None,
      ua_matterhorn_truetype_cmap_font_for_test([(1, 0), (3, 1)]),
    ),
  )
  @test.assert_eq(
    try! multiple_without_symbol_cmap.test_matterhorn_json("31-026"),
    Json::array([ua_matterhorn_31_026_failure_for_test()]),
  )
}

///|
test "PdfDocument test_matterhorn_json checks missing ToUnicode exemptions" {
  let symbolic_descriptor = ua_matterhorn_font_descriptor_for_test(Some(4))
  let symbolic_truetype = ua_matterhorn_font_for_test(
    "/TrueType",
    "/SymbolicTrueType",
    None,
    Some(symbolic_descriptor),
  )
  let missing_tounicode = ua_matterhorn_document_for_test([])
  missing_tounicode.add_object_given_number(40, symbolic_truetype)
  @test.assert_eq(
    try! missing_tounicode.test_matterhorn_json("31-027"),
    Json::array([
      ua_matterhorn_31_027_failure_for_test(
        ua_matterhorn_serialized_object_extra_for_test(symbolic_truetype),
      ),
    ]),
  )

  let with_tounicode = ua_matterhorn_document_for_test([])
  with_tounicode.add_object_given_number(
    40,
    ua_matterhorn_font_for_test(
      "/TrueType",
      "/SymbolicTrueType",
      None,
      Some(symbolic_descriptor),
      extras=[
        (
          ua_matterhorn_name_for_test("/ToUnicode"),
          @syntax.pdf_stream(PdfDictionary([]), StreamGot(b"")),
        ),
      ],
    ),
  )
  @test.assert_eq(
    try! with_tounicode.test_matterhorn_json("31-027"),
    Json::array([]),
  )

  let winansi = ua_matterhorn_document_for_test([])
  winansi.add_object_given_number(
    40,
    ua_matterhorn_font_for_test(
      "/TrueType",
      "/SymbolicTrueType",
      Some("/WinAnsiEncoding"),
      Some(symbolic_descriptor),
    ),
  )
  @test.assert_eq(try! winansi.test_matterhorn_json("31-027"), Json::array([]))

  let type0_collection = ua_matterhorn_document_for_test([])
  type0_collection.add_object_given_number(
    41,
    PdfDictionary([
      (
        ua_matterhorn_name_for_test("/CIDSystemInfo"),
        PdfDictionary([
          (
            ua_matterhorn_name_for_test("/Registry"),
            PdfNameObject(ua_matterhorn_name_for_test("/Adobe")),
          ),
          (
            ua_matterhorn_name_for_test("/Ordering"),
            PdfNameObject(ua_matterhorn_name_for_test("/GB1")),
          ),
        ]),
      ),
    ]),
  )
  type0_collection.add_object_given_number(
    40,
    ua_matterhorn_font_for_test(
      "/Type0",
      "/Composite",
      None,
      Some(symbolic_descriptor),
      extras=[
        (
          ua_matterhorn_name_for_test("/DescendantFonts"),
          PdfArray([PdfIndirect(41)]),
        ),
      ],
    ),
  )
  @test.assert_eq(
    try! type0_collection.test_matterhorn_json("31-027"),
    Json::array([]),
  )

  let cid_font_silent = ua_matterhorn_document_for_test([])
  cid_font_silent.add_object_given_number(
    40,
    ua_matterhorn_font_for_test(
      "/CIDFontType2",
      "/CID",
      None,
      Some(symbolic_descriptor),
    ),
  )
  @test.assert_eq(
    try! cid_font_silent.test_matterhorn_json("31-027"),
    Json::array([]),
  )

  let type1_unimplemented = ua_matterhorn_document_for_test([])
  type1_unimplemented.add_object_given_number(
    40,
    ua_matterhorn_font_for_test(
      "/Type1",
      "/SymbolicType1",
      None,
      Some(symbolic_descriptor),
    ),
  )
  @test.assert_eq(
    try! type1_unimplemented.test_matterhorn_json("31-027"),
    Json::array([]),
  )
}

///|
test "PdfDocument test_matterhorn_json checks ToUnicode value Matterhorn checks" {
  let zero_value = ua_matterhorn_document_for_test([])
  zero_value.add_object_given_number(
    40,
    ua_matterhorn_font_with_tounicode_for_test(PdfIndirect(41)),
  )
  zero_value.add_object_given_number(
    41,
    ua_matterhorn_tounicode_stream_for_test("0000"),
  )
  @test.assert_eq(
    try! zero_value.test_matterhorn_json("31-028"),
    Json::array([ua_matterhorn_31_028_failure_for_test()]),
  )
  @test.assert_eq(
    try! zero_value.test_matterhorn_json("31-029"),
    Json::array([]),
  )

  let byte_order_mark = ua_matterhorn_document_for_test([])
  byte_order_mark.add_object_given_number(
    40,
    ua_matterhorn_font_with_tounicode_for_test(PdfIndirect(41)),
  )
  byte_order_mark.add_object_given_number(
    41,
    ua_matterhorn_tounicode_stream_for_test("FEFF"),
  )
  @test.assert_eq(
    try! byte_order_mark.test_matterhorn_json("31-028"),
    Json::array([]),
  )
  @test.assert_eq(
    try! byte_order_mark.test_matterhorn_json("31-029"),
    Json::array([ua_matterhorn_31_029_failure_for_test()]),
  )

  let reverse_bom = ua_matterhorn_document_for_test([])
  reverse_bom.add_object_given_number(
    40,
    ua_matterhorn_font_with_tounicode_for_test(PdfIndirect(41)),
  )
  reverse_bom.add_object_given_number(
    41,
    ua_matterhorn_tounicode_stream_for_test("FFFE"),
  )
  @test.assert_eq(
    try! reverse_bom.test_matterhorn_json("31-029"),
    Json::array([ua_matterhorn_31_029_failure_for_test()]),
  )

  let normal_value = ua_matterhorn_document_for_test([])
  normal_value.add_object_given_number(
    40,
    ua_matterhorn_font_with_tounicode_for_test(PdfIndirect(41)),
  )
  normal_value.add_object_given_number(
    41,
    ua_matterhorn_tounicode_stream_for_test("0041"),
  )
  @test.assert_eq(
    try! normal_value.test_matterhorn_json("31-028"),
    Json::array([]),
  )
  @test.assert_eq(
    try! normal_value.test_matterhorn_json("31-029"),
    Json::array([]),
  )

  let direct_tounicode = ua_matterhorn_document_for_test([])
  direct_tounicode.add_object_given_number(
    40,
    ua_matterhorn_font_with_tounicode_for_test(
      ua_matterhorn_tounicode_stream_for_test("0000"),
    ),
  )
  @test.assert_eq(
    try! direct_tounicode.test_matterhorn_json("31-028"),
    Json::array([]),
  )
}
