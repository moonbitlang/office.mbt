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
      (key_d, PdfDictionary([(key_name, PdfString(b""))])),
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
      (key_d, PdfDictionary([(key_name, PdfString(b"Default"))])),
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
test "PdfDocument test_matterhorn_json checks embedded file specs" {
  let missing_uf = ua_matterhorn_document_for_test(
    [],
    root_extras=ua_matterhorn_embedded_files_root_for_test(
      ua_matterhorn_file_spec_for_test(Some("attachment.bin"), None),
    ),
  )
  @test.assert_eq(
    try! missing_uf.test_matterhorn_json("21-001"),
    Json::array([ua_matterhorn_21_001_failure_for_test()]),
  )

  let valid_named = ua_matterhorn_document_for_test(
    [],
    root_extras=ua_matterhorn_embedded_files_root_for_test(
      ua_matterhorn_file_spec_for_test(
        Some("attachment.bin"),
        Some("attachment.bin"),
      ),
    ),
  )
  @test.assert_eq(
    try! valid_named.test_matterhorn_json("21-001"),
    Json::array([]),
  )

  let missing_annotation_uf = ua_matterhorn_document_for_test(
    [],
    rest=PdfDictionary([
      (
        ua_matterhorn_name_for_test("/Annots"),
        PdfArray([
          ua_matterhorn_file_attachment_annotation_for_test(
            Some(ua_matterhorn_file_spec_for_test(Some("page.bin"), None)),
          ),
        ]),
      ),
    ]),
  )
  @test.assert_eq(
    try! missing_annotation_uf.test_matterhorn_json("21-001"),
    Json::array([ua_matterhorn_21_001_failure_for_test()]),
  )

  let no_fs_annotation = ua_matterhorn_document_for_test(
    [],
    rest=PdfDictionary([
      (
        ua_matterhorn_name_for_test("/Annots"),
        PdfArray([ua_matterhorn_file_attachment_annotation_for_test(None)]),
      ),
    ]),
  )
  @test.assert_eq(
    try! no_fs_annotation.test_matterhorn_json("21-001"),
    Json::array([]),
  )
}

///|
test "PdfDocument test_matterhorn_json detects required XFA dynamicRender" {
  let required = ua_matterhorn_document_for_test(
    [],
    root_extras=ua_matterhorn_xfa_config_root_for_test(
      ua_matterhorn_xfa_config_stream_for_test(
        b"<template><dynamicRender>required</dynamicRender></template>",
      ),
    ),
  )
  @test.assert_eq(
    try! required.test_matterhorn_json("25-001"),
    Json::array([ua_matterhorn_25_001_failure_for_test()]),
  )

  let prefixed = ua_matterhorn_document_for_test(
    [],
    root_extras=ua_matterhorn_xfa_config_root_for_test(
      ua_matterhorn_xfa_config_stream_for_test(
        b"<template><xfa:dynamicRender>required</xfa:dynamicRender></template>",
      ),
    ),
  )
  @test.assert_eq(
    try! prefixed.test_matterhorn_json("25-001"),
    Json::array([ua_matterhorn_25_001_failure_for_test()]),
  )

  let optional = ua_matterhorn_document_for_test(
    [],
    root_extras=ua_matterhorn_xfa_config_root_for_test(
      ua_matterhorn_xfa_config_stream_for_test(
        b"<template><dynamicRender>optional</dynamicRender></template>",
      ),
    ),
  )
  @test.assert_eq(try! optional.test_matterhorn_json("25-001"), Json::array([]))

  let spaced = ua_matterhorn_document_for_test(
    [],
    root_extras=ua_matterhorn_xfa_config_root_for_test(
      ua_matterhorn_xfa_config_stream_for_test(
        b"<template><dynamicRender> required </dynamicRender></template>",
      ),
    ),
  )
  @test.assert_eq(try! spaced.test_matterhorn_json("25-001"), Json::array([]))

  let duplicate_config = ua_matterhorn_document_for_test(
    [],
    root_extras=ua_matterhorn_xfa_root_for_test(
      PdfArray([
        PdfString(b"config"),
        ua_matterhorn_xfa_config_stream_for_test(
          b"<dynamicRender>required</dynamicRender>",
        ),
        PdfString(b"config"),
        ua_matterhorn_xfa_config_stream_for_test(
          b"<dynamicRender>required</dynamicRender>",
        ),
      ]),
    ),
  )
  @test.assert_eq(
    try! duplicate_config.test_matterhorn_json("25-001"),
    Json::array([]),
  )

  let non_array_xfa = ua_matterhorn_document_for_test(
    [],
    root_extras=ua_matterhorn_xfa_root_for_test(
      ua_matterhorn_xfa_config_stream_for_test(
        b"<dynamicRender>required</dynamicRender>",
      ),
    ),
  )
  @test.assert_eq(
    try! non_array_xfa.test_matterhorn_json("25-001"),
    Json::array([]),
  )

  let non_stream_config = ua_matterhorn_document_for_test(
    [],
    root_extras=ua_matterhorn_xfa_config_root_for_test(PdfString(b"required")),
  )
  @test.assert_eq(
    try! non_stream_config.test_matterhorn_json("25-001"),
    Json::array([]),
  )
}

///|
test "PdfDocument test_matterhorn_json checks encryption permissions" {
  let plain = ua_matterhorn_document_for_test([])
  @test.assert_eq(try! plain.test_matterhorn_json("26-001"), Json::array([]))
  @test.assert_eq(try! plain.test_matterhorn_json("26-002"), Json::array([]))

  let no_extract_encrypted = try! ua_matterhorn_document_for_test([]).encrypt_40bit(
    b"user",
    b"owner",
    [PdfNoExtract],
    file_id=b"ua-no-extract",
  )
  let no_extract = ua_matterhorn_decryption_result_for_test(
      try! no_extract_encrypted.decrypt_with_user_password(b"user"),
    ).document
  @test.assert_eq(
    try! no_extract.test_matterhorn_json("26-001"),
    Json::array([]),
  )
  @test.assert_eq(
    try! no_extract.test_matterhorn_json("26-002"),
    Json::array([ua_matterhorn_26_002_failure_for_test()]),
  )

  let print_denied_encrypted = try! ua_matterhorn_document_for_test([]).encrypt_40bit(
    b"user",
    b"owner",
    [PdfNoPrint],
    file_id=b"ua-print-denied",
  )
  let print_denied = ua_matterhorn_decryption_result_for_test(
      try! print_denied_encrypted.decrypt_with_user_password(b"user"),
    ).document
  @test.assert_eq(
    try! print_denied.test_matterhorn_json("26-002"),
    Json::array([]),
  )
}
