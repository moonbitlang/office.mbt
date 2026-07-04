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

///|
test "PdfDocument test_matterhorn_json detects multiply referenced MCID Form XObjects" {
  let span = ua_matterhorn_name_for_test("/Span")
  let mcid = ua_matterhorn_name_for_test("/MCID")
  let form_name = ua_matterhorn_name_for_test("/Fm1")
  let wrapper_name = ua_matterhorn_name_for_test("/Fm2")
  let target = ua_matterhorn_form_stream_for_test([
    Op_BDC(span, PdfDictionary([(mcid, PdfInteger(0))])),
    Op_Tj(b"content"),
    Op_EMC,
  ])
  let document = ua_matterhorn_document_for_test(
    [],
    resources=ua_matterhorn_xobject_resources_for_test([
      (form_name, PdfIndirect(40)),
    ]),
  )
  document.add_object_given_number(40, target)
  document.add_object_given_number(
    41,
    ua_matterhorn_form_stream_for_test(
      [],
      resources=ua_matterhorn_xobject_resources_for_test([
        (wrapper_name, PdfIndirect(40)),
      ]),
    ),
  )
  @test.assert_eq(
    try! document.test_matterhorn_json("30-002"),
    Json::array([ua_matterhorn_30_002_failure_for_test()]),
  )

  let single = ua_matterhorn_document_for_test(
    [],
    resources=ua_matterhorn_xobject_resources_for_test([
      (form_name, PdfIndirect(40)),
    ]),
  )
  single.add_object_given_number(40, target)
  @test.assert_eq(try! single.test_matterhorn_json("30-002"), Json::array([]))

  let no_mcid = ua_matterhorn_document_for_test(
    [],
    resources=ua_matterhorn_xobject_resources_for_test([
      (form_name, PdfIndirect(40)),
    ]),
  )
  no_mcid.add_object_given_number(
    40,
    ua_matterhorn_form_stream_for_test([Op_Tj(b"content")]),
  )
  no_mcid.add_object_given_number(
    41,
    ua_matterhorn_form_stream_for_test(
      [],
      resources=ua_matterhorn_xobject_resources_for_test([
        (wrapper_name, PdfIndirect(40)),
      ]),
    ),
  )
  @test.assert_eq(try! no_mcid.test_matterhorn_json("30-002"), Json::array([]))
}
