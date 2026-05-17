///|
fn tweak_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn tweak_bytes_for_test(text : String) -> Bytes {
  @ascii.encode(text)
}

///|
fn tweak_stream_for_test(
  ops : ArrayView[@pdflite.PdfContentOp],
) -> @pdflite.PdfObject {
  try! @pdflite.pdf_content_stream_of_ops(ops)
}

///|
fn tweak_content_ops_for_test(
  document : @pdflite.PdfDocument,
  page : @pdflite.PdfPage,
) -> Array[@pdflite.PdfContentOp] {
  try! document.parse_content_ops_with_resources(page.resources, page.content)
}

///|
test "pdf_reveal_hidden_text_ops removes rendering mode operators" {
  let ops : Array[@pdflite.PdfContentOp] = [
    Op_BT,
    Op_Tr(3),
    Op_Tj(tweak_bytes_for_test("hidden")),
    Op_Tr(0),
    Op_ET,
  ]
  @test.assert_eq(@pdflite.pdf_reveal_hidden_text_ops(ops), [
    Op_BT,
    Op_Tj(tweak_bytes_for_test("hidden")),
    Op_ET,
  ])
}

///|
test "PdfDocument reveal_hidden_text rewrites only selected pages" {
  let base = try! @pdflite.pdf_blank_document(200.0, 100.0, 2)
  let pages = try! base.pages_of_pagetree()
  let first = {
    ..pages[0],
    content: [
      tweak_stream_for_test([
        Op_BT,
        Op_Tr(3),
        Op_Tj(tweak_bytes_for_test("first")),
        Op_ET,
      ]),
    ],
  }
  let second = {
    ..pages[1],
    content: [
      tweak_stream_for_test([
        Op_BT,
        Op_Tr(7),
        Op_Tj(tweak_bytes_for_test("second")),
        Op_ET,
      ]),
    ],
  }
  let document = try! base.change_pages([first, second])
  let original_pages = try! document.pages_of_pagetree()

  let revealed = try! document.reveal_hidden_text([1])
  let revealed_pages = try! revealed.pages_of_pagetree()

  @test.assert_eq(tweak_content_ops_for_test(revealed, revealed_pages[0]), [
    Op_BT,
    Op_Tj(tweak_bytes_for_test("first")),
    Op_ET,
  ])
  @test.assert_eq(tweak_content_ops_for_test(revealed, revealed_pages[1]), [
    Op_BT,
    Op_Tr(7),
    Op_Tj(tweak_bytes_for_test("second")),
    Op_ET,
  ])
  @test.assert_eq(tweak_content_ops_for_test(document, original_pages[0]), [
    Op_BT,
    Op_Tr(3),
    Op_Tj(tweak_bytes_for_test("first")),
    Op_ET,
  ])
}

///|
test "PdfDocument reveal_hidden_text rewrites selected page form xobjects" {
  let key_xobject = tweak_name_for_test("/XObject")
  let key_subtype = tweak_name_for_test("/Subtype")
  let key_form = tweak_name_for_test("/Form")
  let form_name = tweak_name_for_test("/Fm1")
  let base = try! @pdflite.pdf_blank_document(200.0, 100.0, 1)
  let form = try! tweak_stream_for_test([
    Op_q,
    Op_BT,
    Op_Tr(3),
    Op_Tj(tweak_bytes_for_test("form")),
    Op_ET,
    Op_Q,
  ]).add_dict_entry(key_subtype, PdfNameObject(key_form))
  let form_number = base.add_object(form)
  let pages = try! base.pages_of_pagetree()
  let page = {
    ..pages[0],
    resources: PdfDictionary([
      (key_xobject, PdfDictionary([(form_name, PdfIndirect(form_number))])),
    ]),
    content: [
      tweak_stream_for_test([
        Op_Do(form_name),
        Op_BT,
        Op_Tr(7),
        Op_Tj(tweak_bytes_for_test("page")),
        Op_ET,
      ]),
    ],
  }
  let document = try! base.change_pages([page])

  let revealed = try! @pdflite.pdf_reveal_hidden_text(document, [1])
  let revealed_pages = try! revealed.pages_of_pagetree()

  @test.assert_eq(tweak_content_ops_for_test(revealed, revealed_pages[0]), [
    Op_Do(form_name),
    Op_BT,
    Op_Tj(tweak_bytes_for_test("page")),
    Op_ET,
  ])
  guard revealed.lookup_object_or_null(form_number)
    is PdfStreamObject(form_stream) else {
    fail("expected retained form xobject stream")
  }
  @test.assert_eq(
    try! revealed.parse_content_ops([PdfStreamObject(form_stream)]),
    [Op_q, Op_BT, Op_Tj(tweak_bytes_for_test("form")), Op_ET, Op_Q],
  )
}

///|
test "pdf_remove_clipping_ops removes exact W n pairs" {
  @test.assert_eq(
    @pdflite.pdf_remove_clipping_ops([Op_W, Op_n, Op_m(1.0, 2.0), Op_W]),
    [Op_n, Op_m(1.0, 2.0), Op_W],
  )
  @test.assert_eq(@pdflite.pdf_remove_clipping_ops([Op_Wstar, Op_n]), [
    Op_Wstar,
    Op_n,
  ])
}

///|
test "PdfDocument remove_clipping rewrites only selected pages" {
  let base = try! @pdflite.pdf_blank_document(200.0, 100.0, 2)
  let pages = try! base.pages_of_pagetree()
  let first = {
    ..pages[0],
    content: [tweak_stream_for_test([Op_W, Op_n, Op_S])],
  }
  let second = {
    ..pages[1],
    content: [tweak_stream_for_test([Op_W, Op_n, Op_S])],
  }
  let document = try! base.change_pages([first, second])
  let original_pages = try! document.pages_of_pagetree()

  let unclipped = try! document.remove_clipping([1])
  let unclipped_pages = try! unclipped.pages_of_pagetree()

  @test.assert_eq(tweak_content_ops_for_test(unclipped, unclipped_pages[0]), [
    Op_n,
    Op_S,
  ])
  @test.assert_eq(tweak_content_ops_for_test(unclipped, unclipped_pages[1]), [
    Op_W,
    Op_n,
    Op_S,
  ])
  @test.assert_eq(tweak_content_ops_for_test(document, original_pages[0]), [
    Op_W,
    Op_n,
    Op_S,
  ])
}

///|
test "PdfDocument remove_clipping rewrites selected page form xobjects" {
  let key_xobject = tweak_name_for_test("/XObject")
  let key_subtype = tweak_name_for_test("/Subtype")
  let key_form = tweak_name_for_test("/Form")
  let form_name = tweak_name_for_test("/ClipForm")
  let base = try! @pdflite.pdf_blank_document(200.0, 100.0, 1)
  let form = try! tweak_stream_for_test([Op_q, Op_W, Op_n, Op_S, Op_Q]).add_dict_entry(
    key_subtype,
    PdfNameObject(key_form),
  )
  let form_number = base.add_object(form)
  let pages = try! base.pages_of_pagetree()
  let page = {
    ..pages[0],
    resources: PdfDictionary([
      (key_xobject, PdfDictionary([(form_name, PdfIndirect(form_number))])),
    ]),
    content: [tweak_stream_for_test([Op_Do(form_name), Op_W, Op_n, Op_S])],
  }
  let document = try! base.change_pages([page])

  let unclipped = try! @pdflite.pdf_remove_clipping(document, [1])
  let unclipped_pages = try! unclipped.pages_of_pagetree()

  @test.assert_eq(tweak_content_ops_for_test(unclipped, unclipped_pages[0]), [
    Op_Do(form_name),
    Op_n,
    Op_S,
  ])
  guard unclipped.lookup_object_or_null(form_number)
    is PdfStreamObject(form_stream) else {
    fail("expected retained form xobject stream")
  }
  @test.assert_eq(
    try! unclipped.parse_content_ops([PdfStreamObject(form_stream)]),
    [Op_q, Op_n, Op_S, Op_Q],
  )
}

///|
test "PdfDocument append_page_content prepends parsed bytes to selected pages" {
  let base = try! @pdflite.pdf_blank_document(200.0, 100.0, 2)
  let pages = try! base.pages_of_pagetree()
  let first = { ..pages[0], content: [tweak_stream_for_test([Op_S])] }
  let second = { ..pages[1], content: [tweak_stream_for_test([Op_S])] }
  let document = try! base.change_pages([first, second])
  let original_pages = try! document.pages_of_pagetree()

  let appended = try! document.append_page_content(
    [1],
    tweak_bytes_for_test("BT ET"),
    before=true,
  )
  let appended_pages = try! appended.pages_of_pagetree()

  @test.assert_eq(tweak_content_ops_for_test(appended, appended_pages[0]), [
    Op_BT,
    Op_ET,
    Op_S,
  ])
  @test.assert_eq(tweak_content_ops_for_test(appended, appended_pages[1]), [
    Op_S,
  ])
  @test.assert_eq(tweak_content_ops_for_test(document, original_pages[0]), [
    Op_S,
  ])
}

///|
test "PdfDocument append_page_content_ops appends selected pages in fast mode" {
  let base = try! @pdflite.pdf_blank_document(200.0, 100.0, 2)
  let pages = try! base.pages_of_pagetree()
  let first = { ..pages[0], content: [tweak_stream_for_test([Op_BT, Op_ET])] }
  let second = { ..pages[1], content: [tweak_stream_for_test([Op_BT, Op_ET])] }
  let document = try! base.change_pages([first, second])

  let appended = try! @pdflite.pdf_append_page_content_ops(
    document,
    [2],
    [Op_g(0.5)],
    fast=true,
  )
  let appended_pages = try! appended.pages_of_pagetree()

  @test.assert_eq(tweak_content_ops_for_test(appended, appended_pages[0]), [
    Op_BT,
    Op_ET,
  ])
  @test.assert_eq(tweak_content_ops_for_test(appended, appended_pages[1]), [
    Op_BT,
    Op_ET,
    Op_q,
    Op_g(0.5),
    Op_Q,
  ])
}

///|
test "PdfDocument append_page_content no-ops for empty content and ops" {
  let base = try! @pdflite.pdf_blank_document(200.0, 100.0, 1)
  let pages = try! base.pages_of_pagetree()
  let page = { ..pages[0], content: [tweak_stream_for_test([Op_S])] }
  let document = try! base.change_pages([page])
  let unchanged_bytes = try! @pdflite.pdf_append_page_content(
    document,
    [1],
    Bytes::new(0),
  )
  let unchanged_ops = try! document.append_page_content_ops([1], [])
  @test.assert_eq(
    tweak_content_ops_for_test(
      unchanged_bytes,
      (try! unchanged_bytes.pages_of_pagetree())[0],
    ),
    [Op_S],
  )
  @test.assert_eq(
    tweak_content_ops_for_test(
      unchanged_ops,
      (try! unchanged_ops.pages_of_pagetree())[0],
    ),
    [Op_S],
  )
}

///|
test "PdfDocument append_page_content_multiple applies one payload per page" {
  let base = try! @pdflite.pdf_blank_document(200.0, 100.0, 2)
  let appended = try! @pdflite.pdf_append_page_content_multiple(base, [
    tweak_bytes_for_test("BT ET"),
    tweak_bytes_for_test("q Q"),
  ])
  let appended_pages = try! appended.pages_of_pagetree()
  @test.assert_eq(tweak_content_ops_for_test(appended, appended_pages[0]), [
    Op_BT,
    Op_ET,
  ])
  @test.assert_eq(tweak_content_ops_for_test(appended, appended_pages[1]), [
    Op_q,
    Op_Q,
  ])

  let mismatch : Result[@pdflite.PdfDocument, Error] = try? base.append_page_content_multiple([
      tweak_bytes_for_test("BT ET"),
    ],
  )
  guard mismatch is Err(@pdflite.PdfError::BadPageSpecification(_)) else {
    fail(
      "expected BadPageSpecification for append_page_content_multiple mismatch",
    )
  }
}

///|
test "PdfDocument append_page_content_multiple_ops applies one op list per page" {
  let base = try! @pdflite.pdf_blank_document(200.0, 100.0, 2)
  let appended = try! @pdflite.pdf_append_page_content_multiple_ops(
    base,
    [[Op_BT, Op_ET], [Op_q, Op_Q]],
    before=true,
  )
  let appended_pages = try! appended.pages_of_pagetree()
  @test.assert_eq(tweak_content_ops_for_test(appended, appended_pages[0]), [
    Op_BT,
    Op_ET,
  ])
  @test.assert_eq(tweak_content_ops_for_test(appended, appended_pages[1]), [
    Op_q,
    Op_Q,
  ])

  let mismatch : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_append_page_content_multiple_ops(
    base,
    [[Op_BT, Op_ET]],
  )
  guard mismatch is Err(@pdflite.PdfError::BadPageSpecification(_)) else {
    fail(
      "expected BadPageSpecification for append_page_content_multiple_ops mismatch",
    )
  }
}

///|
test "pdf_thin_lines_ops honors thresholds and CTM scale" {
  let document = @pdflite.pdf_document_empty()
  let scale_two : @pdflite.TransformMatrix = {
    a: 2.0,
    b: 0.0,
    c: 0.0,
    d: 2.0,
    e: 0.0,
    f: 0.0,
  }

  @test.assert_eq(
    try! @pdflite.pdf_thin_lines_ops(
      document,
      PdfDictionary([]),
      [Op_w(0.5), Op_cm(scale_two), Op_w(0.25), Op_w(2.0)],
      2.0,
    ),
    [Op_w(2.0), Op_w(2.0), Op_cm(scale_two), Op_w(1.0), Op_w(2.0)],
  )
  @test.assert_eq(
    try! @pdflite.pdf_thin_lines_ops(
      document,
      PdfDictionary([]),
      [Op_w(3.0), Op_w(1.0)],
      -2.0,
    ),
    [Op_w(2.0), Op_w(2.0), Op_w(1.0)],
  )
  @test.assert_eq(
    try! @pdflite.pdf_thin_lines_ops(
      document,
      PdfDictionary([]),
      [Op_Q, Op_w(0.5)],
      2.0,
    ),
    [Op_w(2.0), Op_Q, Op_w(2.0)],
  )
  @test.assert_eq(
    try! @pdflite.pdf_thin_lines_ops(
      document,
      PdfDictionary([]),
      [Op_q, Op_cm(scale_two), Op_w(0.25), Op_Q, Op_w(0.25)],
      2.0,
    ),
    [Op_w(2.0), Op_q, Op_cm(scale_two), Op_w(1.0), Op_Q, Op_w(2.0)],
  )
}

///|
test "pdf_thin_lines_ops inserts ExtGState line width" {
  let document = @pdflite.pdf_document_empty()
  let key_extgstate = tweak_name_for_test("/ExtGState")
  let key_lw = tweak_name_for_test("/LW")
  let name_gs = tweak_name_for_test("/GS1")
  let resources : @pdflite.PdfObject = PdfDictionary([
    (
      key_extgstate,
      PdfDictionary([(name_gs, PdfDictionary([(key_lw, PdfReal(0.75))]))]),
    ),
  ])
  @test.assert_eq(
    try! @pdflite.pdf_thin_lines_ops(
      document,
      resources,
      [Op_gs(name_gs), Op_S],
      1.0,
    ),
    [Op_gs(name_gs), Op_w(0.75), Op_S],
  )

  let integer_resources : @pdflite.PdfObject = PdfDictionary([
    (
      key_extgstate,
      PdfDictionary([(name_gs, PdfDictionary([(key_lw, PdfInteger(2))]))]),
    ),
  ])
  @test.assert_eq(
    try! @pdflite.pdf_thin_lines_ops(
      document,
      integer_resources,
      [Op_gs(name_gs), Op_S],
      1.0,
    ),
    [Op_gs(name_gs), Op_w(2.0), Op_S],
  )

  let malformed_resources : @pdflite.PdfObject = PdfDictionary([
    (
      key_extgstate,
      PdfDictionary([
        (
          name_gs,
          PdfDictionary([(key_lw, PdfString(tweak_bytes_for_test("x")))]),
        ),
      ]),
    ),
  ])
  @test.assert_eq(
    try! @pdflite.pdf_thin_lines_ops(
      document,
      malformed_resources,
      [Op_gs(name_gs), Op_S],
      1.0,
    ),
    [Op_gs(name_gs), Op_S],
  )
  let missing_lw_resources : @pdflite.PdfObject = PdfDictionary([
    (key_extgstate, PdfDictionary([(name_gs, PdfDictionary([]))])),
  ])
  @test.assert_eq(
    try! @pdflite.pdf_thin_lines_ops(
      document,
      missing_lw_resources,
      [Op_gs(name_gs), Op_S],
      1.0,
    ),
    [Op_gs(name_gs), Op_S],
  )
  let missing_name_resources : @pdflite.PdfObject = PdfDictionary([
    (key_extgstate, PdfDictionary([])),
  ])
  @test.assert_eq(
    try! @pdflite.pdf_thin_lines_ops(
      document,
      missing_name_resources,
      [Op_gs(name_gs), Op_S],
      1.0,
    ),
    [Op_gs(name_gs), Op_S],
  )
  @test.assert_eq(
    try! @pdflite.pdf_thin_lines_ops(
      document,
      PdfDictionary([]),
      [Op_gs(name_gs), Op_S],
      1.0,
    ),
    [Op_gs(name_gs), Op_S],
  )
}

///|
test "pdf_thin_lines_ops rejects CTM operations after unbalanced restore" {
  let document = @pdflite.pdf_document_empty()
  let scale_two : @pdflite.TransformMatrix = {
    a: 2.0,
    b: 0.0,
    c: 0.0,
    d: 2.0,
    e: 0.0,
    f: 0.0,
  }
  let result : Result[Array[@pdflite.PdfContentOp], Error] = try? @pdflite.pdf_thin_lines_ops(
    document,
    PdfDictionary([]),
    [Op_Q, Op_cm(scale_two)],
    2.0,
  )
  guard result is Err(@pdflite.PdfError::MatrixMalformed) else {
    fail("expected MatrixMalformed for CTM update after unbalanced Q")
  }
  let double_restore : Result[Array[@pdflite.PdfContentOp], Error] = try? @pdflite.pdf_thin_lines_ops(
    document,
    PdfDictionary([]),
    [Op_Q, Op_Q],
    2.0,
  )
  guard double_restore is Err(@pdflite.PdfError::MatrixMalformed) else {
    fail("expected MatrixMalformed for double unbalanced Q")
  }
  let restore_then_save : Result[Array[@pdflite.PdfContentOp], Error] = try? @pdflite.pdf_thin_lines_ops(
    document,
    PdfDictionary([]),
    [Op_Q, Op_q],
    2.0,
  )
  guard restore_then_save is Err(@pdflite.PdfError::MatrixMalformed) else {
    fail("expected MatrixMalformed for q after unbalanced Q")
  }
}

///|
test "PdfDocument thin_lines rewrites only selected pages" {
  let base = try! @pdflite.pdf_blank_document(200.0, 100.0, 2)
  let pages = try! base.pages_of_pagetree()
  let first = {
    ..pages[0],
    content: [tweak_stream_for_test([Op_w(0.25), Op_S])],
  }
  let second = {
    ..pages[1],
    content: [tweak_stream_for_test([Op_w(0.25), Op_S])],
  }
  let document = try! base.change_pages([first, second])
  let original_pages = try! document.pages_of_pagetree()

  let thinned = try! @pdflite.pdf_thin_lines(document, [2], 2.0)
  let thinned_pages = try! thinned.pages_of_pagetree()

  @test.assert_eq(tweak_content_ops_for_test(thinned, thinned_pages[0]), [
    Op_w(0.25),
    Op_S,
  ])
  @test.assert_eq(tweak_content_ops_for_test(thinned, thinned_pages[1]), [
    Op_w(2.0),
    Op_w(2.0),
    Op_S,
  ])
  @test.assert_eq(tweak_content_ops_for_test(document, original_pages[1]), [
    Op_w(0.25),
    Op_S,
  ])
}
