///|
test "PdfDocument test_matterhorn_json checks annotation subtype and tabs" {
  let unknown = ua_matterhorn_document_for_test(
    [],
    rest=ua_matterhorn_page_rest_with_annots_for_test(
      [ua_matterhorn_annotation_for_test("/Custom")],
      tabs=Some(PdfNameObject(ua_matterhorn_name_for_test("/S"))),
    ),
  )
  @test.assert_eq(
    try! unknown.test_matterhorn_json("28-006"),
    Json::array([ua_matterhorn_28_006_failure_for_test()]),
  )

  let link = ua_matterhorn_document_for_test(
    [],
    rest=ua_matterhorn_page_rest_with_annots_for_test(
      [ua_matterhorn_annotation_for_test("/Link")],
      tabs=Some(PdfNameObject(ua_matterhorn_name_for_test("/S"))),
    ),
  )
  @test.assert_eq(try! link.test_matterhorn_json("28-006"), Json::array([]))

  let trap_net = ua_matterhorn_document_for_test(
    [],
    rest=ua_matterhorn_page_rest_with_annots_for_test(
      [ua_matterhorn_annotation_for_test("/TrapNet")],
      tabs=Some(PdfNameObject(ua_matterhorn_name_for_test("/S"))),
    ),
  )
  @test.assert_eq(
    try! trap_net.test_matterhorn_json("28-007"),
    Json::array([ua_matterhorn_28_007_failure_for_test()]),
  )
  @test.assert_eq(try! link.test_matterhorn_json("28-007"), Json::array([]))

  let no_tabs = ua_matterhorn_document_for_test(
    [],
    rest=ua_matterhorn_page_rest_with_annots_for_test([
      ua_matterhorn_annotation_for_test("/Link"),
    ]),
  )
  @test.assert_eq(
    try! no_tabs.test_matterhorn_json("28-008"),
    Json::array([ua_matterhorn_28_008_failure_for_test()]),
  )
  @test.assert_eq(try! link.test_matterhorn_json("28-008"), Json::array([]))

  let no_annotations = ua_matterhorn_document_for_test([])
  @test.assert_eq(
    try! no_annotations.test_matterhorn_json("28-008"),
    Json::array([]),
  )

  let row_tabs = ua_matterhorn_document_for_test(
    [],
    rest=ua_matterhorn_page_rest_with_annots_for_test(
      [ua_matterhorn_annotation_for_test("/Link")],
      tabs=Some(PdfNameObject(ua_matterhorn_name_for_test("/R"))),
    ),
  )
  @test.assert_eq(
    try! row_tabs.test_matterhorn_json("28-009"),
    Json::array([ua_matterhorn_28_009_failure_for_test()]),
  )
  @test.assert_eq(try! link.test_matterhorn_json("28-009"), Json::array([]))
  @test.assert_eq(try! no_tabs.test_matterhorn_json("28-009"), Json::array([]))
}

///|
test "PdfDocument test_matterhorn_json checks annotation Annot parents" {
  let key_struct_parent = ua_matterhorn_name_for_test("/StructParent")

  let missing_struct_parent = ua_matterhorn_document_for_test([])
  missing_struct_parent.add_object_given_number(
    40,
    ua_matterhorn_annotation_for_test("/Stamp"),
  )
  @test.assert_eq(
    try! missing_struct_parent.test_matterhorn_json("28-002"),
    Json::array([ua_matterhorn_28_002_failure_for_test()]),
  )

  let wrong_type = ua_matterhorn_document_for_test(
    [],
    root_extras=ua_matterhorn_struct_parent_tree_root_for_test([
      (7, ua_matterhorn_structure_element_for_test("/Span")),
    ]),
  )
  wrong_type.add_object_given_number(
    40,
    ua_matterhorn_annotation_for_test("/Stamp", extras=[
      (key_struct_parent, PdfInteger(7)),
    ]),
  )
  @test.assert_eq(
    try! wrong_type.test_matterhorn_json("28-002"),
    Json::array([ua_matterhorn_28_002_failure_for_test()]),
  )

  let missing_parent = ua_matterhorn_document_for_test(
    [],
    root_extras=ua_matterhorn_struct_parent_tree_root_for_test([
      (7, ua_matterhorn_structure_element_for_test("/Annot")),
    ]),
  )
  missing_parent.add_object_given_number(
    40,
    ua_matterhorn_annotation_for_test("/Stamp", extras=[
      (key_struct_parent, PdfInteger(99)),
    ]),
  )
  @test.assert_eq(
    try! missing_parent.test_matterhorn_json("28-002"),
    Json::array([ua_matterhorn_28_002_failure_for_test()]),
  )

  let valid = ua_matterhorn_document_for_test(
    [],
    root_extras=ua_matterhorn_struct_parent_tree_root_for_test([
      (7, ua_matterhorn_structure_element_for_test("/Annot")),
    ]),
  )
  valid.add_object_given_number(
    40,
    ua_matterhorn_annotation_for_test("/Stamp", extras=[
      (key_struct_parent, PdfInteger(7)),
    ]),
  )
  @test.assert_eq(try! valid.test_matterhorn_json("28-002"), Json::array([]))

  let exempt = ua_matterhorn_document_for_test([])
  exempt.add_object_given_number(40, ua_matterhorn_annotation_for_test("/Link"))
  exempt.add_object_given_number(
    41,
    ua_matterhorn_annotation_for_test("/Widget"),
  )
  exempt.add_object_given_number(
    42,
    ua_matterhorn_annotation_for_test("/PrinterMark"),
  )
  @test.assert_eq(try! exempt.test_matterhorn_json("28-002"), Json::array([]))

  let source_square_typo = ua_matterhorn_document_for_test([])
  source_square_typo.add_object_given_number(
    40,
    ua_matterhorn_annotation_for_test("/Square"),
  )
  @test.assert_eq(
    try! source_square_typo.test_matterhorn_json("28-002"),
    Json::array([]),
  )
}

///|
test "PdfDocument test_matterhorn_json checks annotation Contents or Alt" {
  let key_struct_parent = ua_matterhorn_name_for_test("/StructParent")

  let unstructured = ua_matterhorn_document_for_test([])
  unstructured.add_object_given_number(
    40,
    ua_matterhorn_annotation_for_test("/Stamp"),
  )
  @test.assert_eq(
    try! unstructured.test_matterhorn_json("28-004"),
    Json::array([]),
  )

  let missing_alt = ua_matterhorn_document_for_test(
    [],
    root_extras=ua_matterhorn_struct_parent_tree_root_for_test([
      (7, ua_matterhorn_structure_element_for_test("/Annot")),
    ]),
  )
  missing_alt.add_object_given_number(
    40,
    ua_matterhorn_annotation_for_test("/Stamp", extras=[
      (key_struct_parent, PdfInteger(7)),
    ]),
  )
  @test.assert_eq(
    try! missing_alt.test_matterhorn_json("28-004"),
    Json::array([ua_matterhorn_28_004_failure_for_test()]),
  )

  let missing_parent = ua_matterhorn_document_for_test(
    [],
    root_extras=ua_matterhorn_struct_parent_tree_root_for_test([
      (7, ua_matterhorn_structure_element_for_test("/Annot")),
    ]),
  )
  missing_parent.add_object_given_number(
    40,
    ua_matterhorn_annotation_for_test("/Stamp", extras=[
      (key_struct_parent, PdfInteger(99)),
    ]),
  )
  @test.assert_eq(
    try! missing_parent.test_matterhorn_json("28-004"),
    Json::array([ua_matterhorn_28_004_failure_for_test()]),
  )

  let with_contents = ua_matterhorn_document_for_test([])
  with_contents.add_object_given_number(
    40,
    ua_matterhorn_annotation_for_test("/Stamp", extras=[
      (ua_matterhorn_name_for_test("/Contents"), PdfString(b"Reviewed")),
    ]),
  )
  @test.assert_eq(
    try! with_contents.test_matterhorn_json("28-004"),
    Json::array([]),
  )

  let with_alt = ua_matterhorn_document_for_test(
    [],
    root_extras=ua_matterhorn_struct_parent_tree_root_for_test([
      (
        7,
        ua_matterhorn_structure_element_for_test("/Annot", extras=[
          (
            ua_matterhorn_name_for_test("/Alt"),
            PdfString(b"Reviewed annotation"),
          ),
        ]),
      ),
    ]),
  )
  with_alt.add_object_given_number(
    40,
    ua_matterhorn_annotation_for_test("/Stamp", extras=[
      (key_struct_parent, PdfInteger(7)),
    ]),
  )
  @test.assert_eq(try! with_alt.test_matterhorn_json("28-004"), Json::array([]))

  let link_missing_alt = ua_matterhorn_document_for_test(
    [],
    root_extras=ua_matterhorn_struct_parent_tree_root_for_test([
      (7, ua_matterhorn_structure_element_for_test("/Link")),
    ]),
  )
  link_missing_alt.add_object_given_number(
    40,
    ua_matterhorn_annotation_for_test("/Link", extras=[
      (key_struct_parent, PdfInteger(7)),
    ]),
  )
  @test.assert_eq(
    try! link_missing_alt.test_matterhorn_json("28-004"),
    Json::array([ua_matterhorn_28_004_failure_for_test()]),
  )

  let widget_exempt = ua_matterhorn_document_for_test(
    [],
    root_extras=ua_matterhorn_struct_parent_tree_root_for_test([
      (7, ua_matterhorn_structure_element_for_test("/Form")),
    ]),
  )
  widget_exempt.add_object_given_number(
    40,
    ua_matterhorn_annotation_for_test("/Widget", extras=[
      (key_struct_parent, PdfInteger(7)),
    ]),
  )
  @test.assert_eq(
    try! widget_exempt.test_matterhorn_json("28-004"),
    Json::array([]),
  )

  let source_square_typo = ua_matterhorn_document_for_test(
    [],
    root_extras=ua_matterhorn_struct_parent_tree_root_for_test([
      (7, ua_matterhorn_structure_element_for_test("/Annot")),
    ]),
  )
  source_square_typo.add_object_given_number(
    40,
    ua_matterhorn_annotation_for_test("/Square", extras=[
      (key_struct_parent, PdfInteger(7)),
    ]),
  )
  @test.assert_eq(
    try! source_square_typo.test_matterhorn_json("28-004"),
    Json::array([]),
  )
}

///|
test "PdfDocument test_matterhorn_json preserves source no-op form field TU check" {
  let key_struct_parent = ua_matterhorn_name_for_test("/StructParent")
  let field_number = 40
  let parent_tree = @pdflite.pdf_document_empty().build_number_tree([
    (7, ua_matterhorn_structure_element_for_test("/Form")),
  ])
  let document = ua_matterhorn_document_for_test([], root_extras=[
    (
      ua_matterhorn_name_for_test("/AcroForm"),
      PdfDictionary([
        (
          ua_matterhorn_name_for_test("/Fields"),
          PdfArray([PdfIndirect(field_number)]),
        ),
      ]),
    ),
    (
      ua_matterhorn_name_for_test("/StructTreeRoot"),
      PdfDictionary([(ua_matterhorn_name_for_test("/ParentTree"), parent_tree)]),
    ),
  ])
  document.add_object_given_number(
    field_number,
    PdfDictionary([
      (ua_matterhorn_name_for_test("/T"), PdfString(b"field name")),
      (key_struct_parent, PdfInteger(7)),
    ]),
  )
  @test.assert_eq(try! document.test_matterhorn_json("28-005"), Json::array([]))
}

///|
test "PdfDocument test_matterhorn_json checks annotation structure parents" {
  let key_struct_parent = ua_matterhorn_name_for_test("/StructParent")

  let widget_unstructured = ua_matterhorn_document_for_test([])
  widget_unstructured.add_object_given_number(
    40,
    ua_matterhorn_annotation_for_test("/Widget"),
  )
  @test.assert_eq(
    try! widget_unstructured.test_matterhorn_json("28-010"),
    Json::array([
      ua_matterhorn_28_010_failure_for_test(
        Json::string("not in structure tree"),
      ),
    ]),
  )

  let widget_wrong_type = ua_matterhorn_document_for_test(
    [],
    root_extras=ua_matterhorn_struct_parent_tree_root_for_test([
      (7, ua_matterhorn_structure_element_for_test("/Link")),
    ]),
  )
  widget_wrong_type.add_object_given_number(
    40,
    ua_matterhorn_annotation_for_test("/Widget", extras=[
      (key_struct_parent, PdfInteger(7)),
    ]),
  )
  @test.assert_eq(
    try! widget_wrong_type.test_matterhorn_json("28-010"),
    Json::array([
      ua_matterhorn_28_010_failure_for_test(Json::string("type is not form")),
    ]),
  )

  let widget_valid = ua_matterhorn_document_for_test(
    [],
    root_extras=ua_matterhorn_struct_parent_tree_root_for_test([
      (7, ua_matterhorn_structure_element_for_test("/Form")),
    ]),
  )
  widget_valid.add_object_given_number(
    40,
    ua_matterhorn_annotation_for_test("/Widget", extras=[
      (key_struct_parent, PdfInteger(7)),
    ]),
  )
  @test.assert_eq(
    try! widget_valid.test_matterhorn_json("28-010"),
    Json::array([]),
  )

  let widget_missing_parent = ua_matterhorn_document_for_test(
    [],
    root_extras=ua_matterhorn_struct_parent_tree_root_for_test([
      (7, ua_matterhorn_structure_element_for_test("/Form")),
    ]),
  )
  widget_missing_parent.add_object_given_number(
    40,
    ua_matterhorn_annotation_for_test("/Widget", extras=[
      (key_struct_parent, PdfInteger(99)),
    ]),
  )
  @test.assert_eq(
    try! widget_missing_parent.test_matterhorn_json("28-010"),
    Json::array([
      ua_matterhorn_28_010_failure_for_test(
        Json::string("not found in parent tree"),
      ),
    ]),
  )

  let link_unstructured = ua_matterhorn_document_for_test([])
  link_unstructured.add_object_given_number(
    40,
    ua_matterhorn_annotation_for_test("/Link"),
  )
  @test.assert_eq(
    try! link_unstructured.test_matterhorn_json("28-011"),
    Json::array([]),
  )

  let link_wrong_type = ua_matterhorn_document_for_test(
    [],
    root_extras=ua_matterhorn_struct_parent_tree_root_for_test([
      (8, ua_matterhorn_structure_element_for_test("/Form")),
    ]),
  )
  link_wrong_type.add_object_given_number(
    40,
    ua_matterhorn_annotation_for_test("/Link", extras=[
      (key_struct_parent, PdfInteger(8)),
    ]),
  )
  @test.assert_eq(
    try! link_wrong_type.test_matterhorn_json("28-011"),
    Json::array([
      ua_matterhorn_28_011_failure_for_test(Json::string("type is not link")),
    ]),
  )

  let link_valid = ua_matterhorn_document_for_test(
    [],
    root_extras=ua_matterhorn_struct_parent_tree_root_for_test([
      (8, ua_matterhorn_structure_element_for_test("/Link")),
    ]),
  )
  link_valid.add_object_given_number(
    40,
    ua_matterhorn_annotation_for_test("/Link", extras=[
      (key_struct_parent, PdfInteger(8)),
    ]),
  )
  @test.assert_eq(
    try! link_valid.test_matterhorn_json("28-011"),
    Json::array([]),
  )

  let link_missing_parent = ua_matterhorn_document_for_test(
    [],
    root_extras=ua_matterhorn_struct_parent_tree_root_for_test([
      (8, ua_matterhorn_structure_element_for_test("/Link")),
    ]),
  )
  link_missing_parent.add_object_given_number(
    40,
    ua_matterhorn_annotation_for_test("/Link", extras=[
      (key_struct_parent, PdfInteger(99)),
    ]),
  )
  @test.assert_eq(
    try! link_missing_parent.test_matterhorn_json("28-011"),
    Json::array([
      ua_matterhorn_28_011_failure_for_test(
        Json::string("not found in parent tree"),
      ),
    ]),
  )
}

///|
test "PdfDocument test_matterhorn_json checks link annotation contents" {
  let missing_contents = ua_matterhorn_document_for_test(
    [],
    rest=ua_matterhorn_page_rest_with_annots_for_test(
      [ua_matterhorn_annotation_for_test("/Link")],
      tabs=Some(PdfNameObject(ua_matterhorn_name_for_test("/S"))),
    ),
  )
  @test.assert_eq(
    try! missing_contents.test_matterhorn_json("28-012"),
    Json::array([ua_matterhorn_28_012_failure_for_test()]),
  )

  let with_contents = ua_matterhorn_document_for_test(
    [],
    rest=ua_matterhorn_page_rest_with_annots_for_test(
      [
        ua_matterhorn_annotation_for_test("/Link", extras=[
          (
            ua_matterhorn_name_for_test("/Contents"),
            PdfString(b"Open related section"),
          ),
        ]),
      ],
      tabs=Some(PdfNameObject(ua_matterhorn_name_for_test("/S"))),
    ),
  )
  @test.assert_eq(
    try! with_contents.test_matterhorn_json("28-012"),
    Json::array([]),
  )

  let non_link = ua_matterhorn_document_for_test(
    [],
    rest=ua_matterhorn_page_rest_with_annots_for_test(
      [ua_matterhorn_annotation_for_test("/Text")],
      tabs=Some(PdfNameObject(ua_matterhorn_name_for_test("/S"))),
    ),
  )
  @test.assert_eq(try! non_link.test_matterhorn_json("28-012"), Json::array([]))
}

///|
test "PdfDocument test_matterhorn_json detects media clip dictionaries" {
  let key_type = ua_matterhorn_name_for_test("/Type")
  let key_s = ua_matterhorn_name_for_test("/S")
  let key_ct = ua_matterhorn_name_for_test("/CT")
  let media_clip : @syntax.PdfObject = PdfDictionary([
    (key_type, PdfNameObject(ua_matterhorn_name_for_test("/MediaClip"))),
    (key_s, PdfNameObject(ua_matterhorn_name_for_test("/MCD"))),
  ])
  let document = ua_matterhorn_document_for_test([])
  document.add_object_given_number(40, media_clip)
  @test.assert_eq(
    try! document.test_matterhorn_json("28-014"),
    Json::array([ua_matterhorn_28_014_failure_for_test()]),
  )
  @test.assert_eq(
    try! document.test_matterhorn_json("28-015"),
    Json::array([ua_matterhorn_28_015_failure_for_test()]),
  )

  let with_ct = ua_matterhorn_document_for_test([])
  with_ct.add_object_given_number(
    40,
    try! media_clip.add_dict_entry(key_ct, PdfString(b"video/mp4")),
  )
  @test.assert_eq(try! with_ct.test_matterhorn_json("28-014"), Json::array([]))
  @test.assert_eq(try! with_ct.test_matterhorn_json("28-015"), Json::array([]))
}

///|
test "PdfDocument test_matterhorn_json handles file attachment conformance no-op" {
  let document = ua_matterhorn_document_for_test([])
  @test.assert_eq(try! document.test_matterhorn_json("28-016"), Json::array([]))
}

///|
test "PdfDocument test_matterhorn_json detects PrinterMark structure entries" {
  let key_subtype = ua_matterhorn_name_for_test("/Subtype")
  let key_struct_parent = ua_matterhorn_name_for_test("/StructParent")
  let document = ua_matterhorn_document_for_test([])
  document.add_object_given_number(
    40,
    PdfDictionary([
      (key_subtype, PdfNameObject(ua_matterhorn_name_for_test("/PrinterMark"))),
      (key_struct_parent, PdfInteger(0)),
    ]),
  )
  @test.assert_eq(
    try! document.test_matterhorn_json("28-017"),
    Json::array([ua_matterhorn_28_017_failure_for_test()]),
  )

  let unstructured = ua_matterhorn_document_for_test([])
  unstructured.add_object_given_number(
    40,
    PdfDictionary([
      (key_subtype, PdfNameObject(ua_matterhorn_name_for_test("/PrinterMark"))),
    ]),
  )
  @test.assert_eq(
    try! unstructured.test_matterhorn_json("28-017"),
    Json::array([]),
  )

  let other_subtype = ua_matterhorn_document_for_test([])
  other_subtype.add_object_given_number(
    40,
    PdfDictionary([
      (key_subtype, PdfNameObject(ua_matterhorn_name_for_test("/Text"))),
      (key_struct_parent, PdfInteger(0)),
    ]),
  )
  @test.assert_eq(
    try! other_subtype.test_matterhorn_json("28-017"),
    Json::array([]),
  )
}

///|
test "PdfDocument test_matterhorn_json checks PrinterMark appearance marking" {
  let span = ua_matterhorn_name_for_test("/Span")
  let document = ua_matterhorn_document_for_test([])
  document.add_object_given_number(
    40,
    ua_matterhorn_printer_mark_for_test(PdfIndirect(41)),
  )
  document.add_object_given_number(
    41,
    ua_matterhorn_form_stream_for_test([Op_Tj(b"mark")]),
  )
  @test.assert_eq(
    try! document.test_matterhorn_json("28-018"),
    Json::array([ua_matterhorn_28_018_failure_for_test()]),
  )

  let dictionary_appearance = ua_matterhorn_document_for_test([])
  dictionary_appearance.add_object_given_number(
    40,
    ua_matterhorn_printer_mark_for_test(
      PdfDictionary([(ua_matterhorn_name_for_test("/On"), PdfIndirect(41))]),
    ),
  )
  dictionary_appearance.add_object_given_number(
    41,
    ua_matterhorn_form_stream_for_test([Op_Tj(b"mark")]),
  )
  @test.assert_eq(
    try! dictionary_appearance.test_matterhorn_json("28-018"),
    Json::array([ua_matterhorn_28_018_failure_for_test()]),
  )

  let marked = ua_matterhorn_document_for_test([])
  marked.add_object_given_number(
    40,
    ua_matterhorn_printer_mark_for_test(PdfIndirect(41)),
  )
  marked.add_object_given_number(
    41,
    ua_matterhorn_form_stream_for_test([
      Op_BDC(span, PdfDictionary([])),
      Op_Tj(b"mark"),
      Op_EMC,
    ]),
  )
  @test.assert_eq(try! marked.test_matterhorn_json("28-018"), Json::array([]))
}
