///|
test "PdfDocument test_matterhorn_json checks table and list structure syntax" {
  let bad_table_row = ua_matterhorn_document_for_test(
    [],
    root_extras=ua_matterhorn_struct_tree_root_for_test([
      ua_matterhorn_structure_element_for_test("/Table", extras=[
        (
          ua_matterhorn_name_for_test("/K"),
          PdfArray([
            ua_matterhorn_structure_element_for_test("/TR", extras=[
              (
                ua_matterhorn_name_for_test("/K"),
                PdfArray([ua_matterhorn_structure_element_for_test("/P")]),
              ),
            ]),
          ]),
        ),
      ]),
    ]),
  )
  @test.assert_eq(
    try! bad_table_row.test_matterhorn_json("09-004"),
    Json::array([
      ua_matterhorn_09_004_failure_for_test(
        Json::string("Every /TR element must be a /TH or /TD"),
      ),
    ]),
  )

  let bad_table_top = ua_matterhorn_document_for_test(
    [],
    root_extras=ua_matterhorn_struct_tree_root_for_test([
      ua_matterhorn_structure_element_for_test("/Table", extras=[
        (
          ua_matterhorn_name_for_test("/K"),
          PdfArray([ua_matterhorn_structure_element_for_test("/P")]),
        ),
      ]),
    ]),
  )
  @test.assert_eq(
    try! bad_table_top.test_matterhorn_json("09-004"),
    Json::array([
      ua_matterhorn_09_004_failure_for_test(
        Json::string("Top-level /Table not of required form"),
      ),
    ]),
  )

  let valid_table = ua_matterhorn_document_for_test(
    [],
    root_extras=ua_matterhorn_struct_tree_root_for_test([
      ua_matterhorn_structure_element_for_test("/Table", extras=[
        (
          ua_matterhorn_name_for_test("/K"),
          PdfArray([
            ua_matterhorn_structure_element_for_test("/TR", extras=[
              (
                ua_matterhorn_name_for_test("/K"),
                PdfArray([
                  ua_matterhorn_structure_element_for_test("/TH"),
                  ua_matterhorn_structure_element_for_test("/TD"),
                ]),
              ),
            ]),
          ]),
        ),
      ]),
    ]),
  )
  @test.assert_eq(
    try! valid_table.test_matterhorn_json("09-004"),
    Json::array([]),
  )

  let empty_list = ua_matterhorn_document_for_test(
    [],
    root_extras=ua_matterhorn_struct_tree_root_for_test([
      ua_matterhorn_structure_element_for_test("/L"),
    ]),
  )
  @test.assert_eq(
    try! empty_list.test_matterhorn_json("09-005"),
    Json::array([
      ua_matterhorn_09_005_failure_for_test(Json::string("No /LI in /L")),
    ]),
  )

  let bad_list_item = ua_matterhorn_document_for_test(
    [],
    root_extras=ua_matterhorn_struct_tree_root_for_test([
      ua_matterhorn_structure_element_for_test("/L", extras=[
        (
          ua_matterhorn_name_for_test("/K"),
          PdfArray([
            ua_matterhorn_structure_element_for_test("/LI", extras=[
              (
                ua_matterhorn_name_for_test("/K"),
                PdfArray([ua_matterhorn_structure_element_for_test("/P")]),
              ),
            ]),
          ]),
        ),
      ]),
    ]),
  )
  @test.assert_eq(
    try! bad_list_item.test_matterhorn_json("09-005"),
    Json::array([
      ua_matterhorn_09_005_failure_for_test(
        Json::string("Child of /LI must be /Lbl or /LBody"),
      ),
    ]),
  )

  let valid_list = ua_matterhorn_document_for_test(
    [],
    root_extras=ua_matterhorn_struct_tree_root_for_test([
      ua_matterhorn_structure_element_for_test("/L", extras=[
        (
          ua_matterhorn_name_for_test("/K"),
          PdfArray([
            ua_matterhorn_structure_element_for_test("/LI", extras=[
              (
                ua_matterhorn_name_for_test("/K"),
                PdfArray([
                  ua_matterhorn_structure_element_for_test("/Lbl"),
                  ua_matterhorn_structure_element_for_test("/LBody"),
                ]),
              ),
            ]),
          ]),
        ),
      ]),
    ]),
  )
  @test.assert_eq(
    try! valid_list.test_matterhorn_json("09-005"),
    Json::array([]),
  )
}

///|
test "PdfDocument test_matterhorn_json checks TOC Ruby and Warichu structure syntax" {
  let loose_toci = ua_matterhorn_document_for_test(
    [],
    root_extras=ua_matterhorn_struct_tree_root_for_test([
      ua_matterhorn_structure_element_for_test("/TOCI"),
    ]),
  )
  @test.assert_eq(
    try! loose_toci.test_matterhorn_json("09-006"),
    Json::array([
      ua_matterhorn_09_006_failure_for_test(
        Json::string("TOCI without TOC above"),
      ),
    ]),
  )

  let bad_toc_child = ua_matterhorn_document_for_test(
    [],
    root_extras=ua_matterhorn_struct_tree_root_for_test([
      ua_matterhorn_structure_element_for_test("/TOC", extras=[
        (
          ua_matterhorn_name_for_test("/K"),
          PdfArray([ua_matterhorn_structure_element_for_test("/P")]),
        ),
      ]),
    ]),
  )
  @test.assert_eq(
    try! bad_toc_child.test_matterhorn_json("09-006"),
    Json::array([
      ua_matterhorn_09_006_failure_for_test(
        Json::string("/TOC children must be /TOC or /TOCI"),
      ),
    ]),
  )

  let valid_toc = ua_matterhorn_document_for_test(
    [],
    root_extras=ua_matterhorn_struct_tree_root_for_test([
      ua_matterhorn_structure_element_for_test("/TOC", extras=[
        (
          ua_matterhorn_name_for_test("/K"),
          PdfArray([
            ua_matterhorn_structure_element_for_test("/TOCI", extras=[
              (
                ua_matterhorn_name_for_test("/K"),
                PdfArray([
                  ua_matterhorn_structure_element_for_test("/Lbl"),
                  ua_matterhorn_structure_element_for_test("/P"),
                ]),
              ),
            ]),
          ]),
        ),
      ]),
    ]),
  )
  @test.assert_eq(
    try! valid_toc.test_matterhorn_json("09-006"),
    Json::array([]),
  )

  let bad_ruby = ua_matterhorn_document_for_test(
    [],
    root_extras=ua_matterhorn_struct_tree_root_for_test([
      ua_matterhorn_structure_element_for_test("/Ruby", extras=[
        (
          ua_matterhorn_name_for_test("/K"),
          PdfArray([ua_matterhorn_structure_element_for_test("/P")]),
        ),
      ]),
    ]),
  )
  @test.assert_eq(
    try! bad_ruby.test_matterhorn_json("09-007"),
    Json::array([ua_matterhorn_09_007_failure_for_test()]),
  )

  let source_rp_typo = ua_matterhorn_document_for_test(
    [],
    root_extras=ua_matterhorn_struct_tree_root_for_test([
      ua_matterhorn_structure_element_for_test("/Ruby", extras=[
        (
          ua_matterhorn_name_for_test("/K"),
          PdfArray([ua_matterhorn_structure_element_for_test("/RP")]),
        ),
      ]),
    ]),
  )
  @test.assert_eq(
    try! source_rp_typo.test_matterhorn_json("09-007"),
    Json::array([ua_matterhorn_09_007_failure_for_test()]),
  )

  let source_warichu_target = ua_matterhorn_document_for_test(
    [],
    root_extras=ua_matterhorn_struct_tree_root_for_test([
      ua_matterhorn_structure_element_for_test("/Ruby", extras=[
        (
          ua_matterhorn_name_for_test("/K"),
          PdfArray([ua_matterhorn_structure_element_for_test("/RB")]),
        ),
      ]),
    ]),
  )
  @test.assert_eq(
    try! source_warichu_target.test_matterhorn_json("09-008"),
    Json::array([ua_matterhorn_09_008_failure_for_test()]),
  )

  let ignored_warichu = ua_matterhorn_document_for_test(
    [],
    root_extras=ua_matterhorn_struct_tree_root_for_test([
      ua_matterhorn_structure_element_for_test("/Warichu", extras=[
        (
          ua_matterhorn_name_for_test("/K"),
          PdfArray([ua_matterhorn_structure_element_for_test("/P")]),
        ),
      ]),
    ]),
  )
  @test.assert_eq(
    try! ignored_warichu.test_matterhorn_json("09-008"),
    Json::array([]),
  )

  let source_valid_warichu = ua_matterhorn_document_for_test(
    [],
    root_extras=ua_matterhorn_struct_tree_root_for_test([
      ua_matterhorn_structure_element_for_test("/Ruby", extras=[
        (
          ua_matterhorn_name_for_test("/K"),
          PdfArray([
            ua_matterhorn_structure_element_for_test("/WT"),
            ua_matterhorn_structure_element_for_test("/WP"),
          ]),
        ),
      ]),
    ]),
  )
  @test.assert_eq(
    try! source_valid_warichu.test_matterhorn_json("09-008"),
    Json::array([]),
  )
}

///|
test "PdfDocument test_matterhorn_json checks structure attribute requirements" {
  let bad = ua_matterhorn_document_for_test(
    [],
    root_extras=ua_matterhorn_struct_tree_root_for_test([
      ua_matterhorn_structure_element_for_test("/Figure"),
      ua_matterhorn_structure_element_for_test("/TH"),
      ua_matterhorn_structure_element_for_test("/Formula"),
      ua_matterhorn_structure_element_for_test("/Note"),
    ]),
  )
  @test.assert_eq(
    try! bad.test_matterhorn_json("13-004"),
    Json::array([ua_matterhorn_13_004_failure_for_test()]),
  )
  @test.assert_eq(
    try! bad.test_matterhorn_json("15-003"),
    Json::array([ua_matterhorn_15_003_failure_for_test()]),
  )
  @test.assert_eq(
    try! bad.test_matterhorn_json("17-002"),
    Json::array([ua_matterhorn_17_002_failure_for_test()]),
  )
  @test.assert_eq(try! bad.test_matterhorn_json("17-003"), Json::array([]))
  @test.assert_eq(
    try! bad.test_matterhorn_json("19-003"),
    Json::array([ua_matterhorn_19_003_failure_for_test()]),
  )

  let good = ua_matterhorn_document_for_test(
    [],
    root_extras=ua_matterhorn_struct_tree_root_for_test([
      ua_matterhorn_structure_element_for_test("/Figure", extras=[
        (
          ua_matterhorn_name_for_test("/ActualText"),
          PdfString(@ascii.encode("figure")),
        ),
      ]),
      ua_matterhorn_structure_element_for_test("/TH", extras=[
        (
          ua_matterhorn_name_for_test("/A"),
          PdfDictionary([
            (
              ua_matterhorn_name_for_test("/Scope"),
              PdfNameObject(ua_matterhorn_name_for_test("/Column")),
            ),
          ]),
        ),
      ]),
      ua_matterhorn_structure_element_for_test("/Formula", extras=[
        (ua_matterhorn_name_for_test("/Alt"), PdfString(@ascii.encode("x"))),
      ]),
      ua_matterhorn_structure_element_for_test("/Note", extras=[
        (ua_matterhorn_name_for_test("/ID"), PdfString(@ascii.encode("n1"))),
      ]),
    ]),
  )
  for name in ["13-004", "15-003", "17-002", "19-003"] {
    @test.assert_eq(try! good.test_matterhorn_json(name), Json::array([]))
  }

  let mapped = ua_matterhorn_document_for_test(
    [],
    root_extras=ua_matterhorn_struct_tree_root_for_test(
      [ua_matterhorn_structure_element_for_test("/Figgy")],
      extras=[
        (
          ua_matterhorn_name_for_test("/RoleMap"),
          PdfDictionary([
            (
              ua_matterhorn_name_for_test("/Figgy"),
              PdfNameObject(ua_matterhorn_name_for_test("/Figure")),
            ),
          ]),
        ),
      ],
    ),
  )
  @test.assert_eq(
    try! mapped.test_matterhorn_json("13-004"),
    Json::array([ua_matterhorn_13_004_failure_for_test()]),
  )
}

///|
test "PdfDocument test_matterhorn_json checks numbered heading structure" {
  let first_h2 = ua_matterhorn_document_for_test(
    [],
    root_extras=ua_matterhorn_struct_tree_root_for_test([
      ua_matterhorn_structure_element_for_test("/H2"),
    ]),
  )
  @test.assert_eq(
    try! first_h2.test_matterhorn_json("14-002"),
    Json::array([ua_matterhorn_14_002_failure_for_test(Json::string("/H2"))]),
  )

  let skipped = ua_matterhorn_document_for_test(
    [],
    root_extras=ua_matterhorn_struct_tree_root_for_test([
      ua_matterhorn_structure_element_for_test("/H1"),
      ua_matterhorn_structure_element_for_test("/H3"),
    ]),
  )
  @test.assert_eq(
    try! skipped.test_matterhorn_json("14-003"),
    Json::array([ua_matterhorn_14_003_failure_for_test(Json::string("1 -> 3"))]),
  )

  let repeated_h = ua_matterhorn_document_for_test(
    [],
    root_extras=ua_matterhorn_struct_tree_root_for_test([
      ua_matterhorn_structure_element_for_test("/H"),
      ua_matterhorn_structure_element_for_test("/H"),
    ]),
  )
  @test.assert_eq(
    try! repeated_h.test_matterhorn_json("14-006"),
    Json::array([ua_matterhorn_14_006_failure_for_test()]),
  )

  let mixed = ua_matterhorn_document_for_test(
    [],
    root_extras=ua_matterhorn_struct_tree_root_for_test([
      ua_matterhorn_structure_element_for_test("/H"),
      ua_matterhorn_structure_element_for_test("/H1"),
    ]),
  )
  @test.assert_eq(
    try! mixed.test_matterhorn_json("14-007"),
    Json::array([ua_matterhorn_14_007_failure_for_test()]),
  )

  let valid = ua_matterhorn_document_for_test(
    [],
    root_extras=ua_matterhorn_struct_tree_root_for_test([
      ua_matterhorn_structure_element_for_test("/H1"),
      ua_matterhorn_structure_element_for_test("/H2"),
    ]),
  )
  for name in ["14-002", "14-003", "14-006", "14-007"] {
    @test.assert_eq(try! valid.test_matterhorn_json(name), Json::array([]))
  }
}

///|
test "PdfDocument test_matterhorn_json detects duplicate note IDs" {
  let duplicate = ua_matterhorn_document_for_test([])
  duplicate.add_object_given_number(
    40,
    ua_matterhorn_structure_element_for_test("/Note", extras=[
      (ua_matterhorn_name_for_test("/ID"), PdfString(@ascii.encode("same"))),
    ]),
  )
  duplicate.add_object_given_number(
    41,
    ua_matterhorn_structure_element_for_test("/Note", extras=[
      (ua_matterhorn_name_for_test("/ID"), PdfString(@ascii.encode("same"))),
    ]),
  )
  @test.assert_eq(
    try! duplicate.test_matterhorn_json("19-004"),
    Json::array([ua_matterhorn_19_004_failure_for_test()]),
  )

  let unique = ua_matterhorn_document_for_test([])
  unique.add_object_given_number(
    40,
    ua_matterhorn_structure_element_for_test("/Note", extras=[
      (ua_matterhorn_name_for_test("/ID"), PdfString(@ascii.encode("a"))),
    ]),
  )
  unique.add_object_given_number(
    41,
    ua_matterhorn_structure_element_for_test("/Note", extras=[
      (ua_matterhorn_name_for_test("/ID"), PdfString(@ascii.encode("b"))),
    ]),
  )
  @test.assert_eq(try! unique.test_matterhorn_json("19-004"), Json::array([]))
}
