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
test "pdf_black_text_ops moves colour state out of text blocks" {
  let font = tweak_name_for_test("/F1")
  let shade = tweak_name_for_test("/Shade")
  @test.assert_eq(
    @pdflite.pdf_black_text_ops(PdfContentRGB(0.1, 0.2, 0.3), [
      Op_g(0.8),
      Op_BT,
      Op_rg(1.0, 0.0, 0.0),
      Op_Tf(font, 12.0),
      Op_Tj(tweak_bytes_for_test("text")),
      Op_q,
      Op_Td(1.0, 2.0),
      Op_sh(shade),
      Op_ET,
      Op_rg(0.5, 0.5, 0.5),
    ]),
    [
      Op_g(0.8),
      Op_BT,
      Op_rg(0.1, 0.2, 0.3),
      Op_Tf(font, 12.0),
      Op_Tj(tweak_bytes_for_test("text")),
      Op_q,
      Op_Td(1.0, 2.0),
      Op_ET,
      Op_rg(1.0, 0.0, 0.0),
      Op_q,
      Op_sh(shade),
      Op_rg(0.5, 0.5, 0.5),
    ],
  )
}

///|
test "pdf_black_lines_ops rewrites stroke colour operators" {
  let device_rgb = tweak_name_for_test("/DeviceRGB")
  let pattern = tweak_name_for_test("/Pattern")
  let spot = tweak_name_for_test("/Spot")
  @test.assert_eq(
    @pdflite.pdf_black_lines_ops(PdfContentCMYK(0.1, 0.2, 0.3, 0.4), [
      Op_CS(pattern),
      Op_SC([1.0]),
      Op_SCNName(spot, [0.5]),
      Op_G(0.6),
      Op_RG(1.0, 0.0, 0.0),
      Op_K(0.0, 1.0, 0.0, 0.0),
      Op_g(0.2),
      Op_cs(pattern),
    ]),
    [
      Op_CS(device_rgb),
      Op_K(0.1, 0.2, 0.3, 0.4),
      Op_K(0.1, 0.2, 0.3, 0.4),
      Op_K(0.1, 0.2, 0.3, 0.4),
      Op_K(0.1, 0.2, 0.3, 0.4),
      Op_K(0.1, 0.2, 0.3, 0.4),
      Op_g(0.2),
      Op_cs(pattern),
    ],
  )
  @test.assert_eq(
    @pdflite.pdf_black_lines_ops(PdfContentRGB(0.1, 0.2, 0.3), [Op_G(0.6)]),
    [Op_RG(0.1, 0.2, 0.3)],
  )
  @test.assert_eq(
    @pdflite.pdf_black_lines_ops(@colour.pdf_content_black, [
      Op_K(0.0, 0.0, 0.0, 1.0),
    ]),
    [Op_G(0.0)],
  )
}

///|
test "pdf_black_fills_ops rewrites fill colour operators" {
  let device_rgb = tweak_name_for_test("/DeviceRGB")
  let pattern = tweak_name_for_test("/Pattern")
  let spot = tweak_name_for_test("/Spot")
  @test.assert_eq(
    @pdflite.pdf_black_fills_ops(PdfContentCMYK(0.1, 0.2, 0.3, 0.4), [
      Op_cs(pattern),
      Op_sc([1.0]),
      Op_scnName(spot, [0.5]),
      Op_g(0.6),
      Op_rg(1.0, 0.0, 0.0),
      Op_k(0.0, 1.0, 0.0, 0.0),
      Op_G(0.2),
      Op_CS(pattern),
    ]),
    [
      Op_cs(device_rgb),
      Op_k(0.1, 0.2, 0.3, 0.4),
      Op_k(0.1, 0.2, 0.3, 0.4),
      Op_k(0.1, 0.2, 0.3, 0.4),
      Op_k(0.1, 0.2, 0.3, 0.4),
      Op_k(0.1, 0.2, 0.3, 0.4),
      Op_G(0.2),
      Op_CS(pattern),
    ],
  )
  @test.assert_eq(
    @pdflite.pdf_black_fills_ops(PdfContentRGB(0.1, 0.2, 0.3), [Op_g(0.6)]),
    [Op_rg(0.1, 0.2, 0.3)],
  )
  @test.assert_eq(
    @pdflite.pdf_black_fills_ops(@colour.pdf_content_black, [
      Op_k(0.0, 0.0, 0.0, 1.0),
    ]),
    [Op_g(0.0)],
  )
}

///|
test "PdfDocument black_text rewrites selected pages and form xobjects" {
  let key_xobject = tweak_name_for_test("/XObject")
  let key_subtype = tweak_name_for_test("/Subtype")
  let key_form = tweak_name_for_test("/Form")
  let form_name = tweak_name_for_test("/BlackTextForm")
  let base = try! @pdflite.pdf_blank_document(200.0, 100.0, 2)
  let form = try! tweak_stream_for_test([
    Op_BT,
    Op_rg(1.0, 0.0, 0.0),
    Op_Tj(tweak_bytes_for_test("form")),
    Op_ET,
  ]).add_dict_entry(key_subtype, PdfNameObject(key_form))
  let form_number = base.add_object(form)
  let pages = try! base.pages_of_pagetree()
  let first = {
    ..pages[0],
    resources: PdfDictionary([
      (key_xobject, PdfDictionary([(form_name, PdfIndirect(form_number))])),
    ]),
    content: [
      tweak_stream_for_test([
        Op_Do(form_name),
        Op_BT,
        Op_g(0.5),
        Op_Tj(tweak_bytes_for_test("page")),
        Op_ET,
      ]),
    ],
  }
  let second = {
    ..pages[1],
    content: [
      tweak_stream_for_test([
        Op_BT,
        Op_g(0.5),
        Op_Tj(tweak_bytes_for_test("skip")),
        Op_ET,
      ]),
    ],
  }
  let document = try! base.change_pages([first, second])

  let rewritten = try! @pdflite.pdf_black_text(
    document,
    [1],
    @colour.pdf_content_black,
  )
  let source_order = try! @pdflite.pdf_blacktext(
    @colour.pdf_content_black,
    [1],
    document,
  )
  let rewritten_pages = try! rewritten.pages_of_pagetree()
  let source_order_pages = try! source_order.pages_of_pagetree()

  @test.assert_eq(tweak_content_ops_for_test(rewritten, rewritten_pages[0]), [
    Op_Do(form_name),
    Op_BT,
    Op_g(0.0),
    Op_Tj(tweak_bytes_for_test("page")),
    Op_ET,
    Op_g(0.5),
  ])
  @test.assert_eq(tweak_content_ops_for_test(rewritten, rewritten_pages[1]), [
    Op_BT,
    Op_g(0.5),
    Op_Tj(tweak_bytes_for_test("skip")),
    Op_ET,
  ])
  guard rewritten.lookup_object_or_null(form_number)
    is PdfStreamObject(form_stream) else {
    fail("expected retained form xobject stream")
  }
  @test.assert_eq(
    try! rewritten.parse_content_ops([PdfStreamObject(form_stream)]),
    [
      Op_BT,
      Op_g(0.0),
      Op_Tj(tweak_bytes_for_test("form")),
      Op_ET,
      Op_rg(1.0, 0.0, 0.0),
    ],
  )
  @test.assert_eq(
    tweak_content_ops_for_test(source_order, source_order_pages[0]),
    tweak_content_ops_for_test(rewritten, rewritten_pages[0]),
  )
}

///|
test "PdfDocument black_lines rewrites selected pages and form xobjects" {
  let key_xobject = tweak_name_for_test("/XObject")
  let key_subtype = tweak_name_for_test("/Subtype")
  let key_form = tweak_name_for_test("/Form")
  let form_name = tweak_name_for_test("/BlackLinesForm")
  let base = try! @pdflite.pdf_blank_document(200.0, 100.0, 2)
  let form = try! tweak_stream_for_test([Op_RG(1.0, 0.0, 0.0), Op_S]).add_dict_entry(
    key_subtype,
    PdfNameObject(key_form),
  )
  let form_number = base.add_object(form)
  let pages = try! base.pages_of_pagetree()
  let first = {
    ..pages[0],
    resources: PdfDictionary([
      (key_xobject, PdfDictionary([(form_name, PdfIndirect(form_number))])),
    ]),
    content: [tweak_stream_for_test([Op_Do(form_name), Op_G(0.8), Op_S])],
  }
  let second = {
    ..pages[1],
    content: [tweak_stream_for_test([Op_G(0.8), Op_S])],
  }
  let document = try! base.change_pages([first, second])

  let rewritten = try! @pdflite.pdf_black_lines(
    document,
    [1],
    PdfContentRGB(0.1, 0.2, 0.3),
  )
  let source_order = try! @pdflite.pdf_blacklines(
    PdfContentRGB(0.1, 0.2, 0.3),
    [1],
    document,
  )
  let rewritten_pages = try! rewritten.pages_of_pagetree()
  let source_order_pages = try! source_order.pages_of_pagetree()

  @test.assert_eq(tweak_content_ops_for_test(rewritten, rewritten_pages[0]), [
    Op_Do(form_name),
    Op_RG(0.1, 0.2, 0.3),
    Op_S,
  ])
  @test.assert_eq(tweak_content_ops_for_test(rewritten, rewritten_pages[1]), [
    Op_G(0.8),
    Op_S,
  ])
  guard rewritten.lookup_object_or_null(form_number)
    is PdfStreamObject(form_stream) else {
    fail("expected retained form xobject stream")
  }
  @test.assert_eq(
    try! rewritten.parse_content_ops([PdfStreamObject(form_stream)]),
    [Op_RG(0.1, 0.2, 0.3), Op_S],
  )
  @test.assert_eq(
    tweak_content_ops_for_test(source_order, source_order_pages[0]),
    tweak_content_ops_for_test(rewritten, rewritten_pages[0]),
  )
}

///|
test "PdfDocument black_fills rewrites selected pages and form xobjects" {
  let key_xobject = tweak_name_for_test("/XObject")
  let key_subtype = tweak_name_for_test("/Subtype")
  let key_form = tweak_name_for_test("/Form")
  let form_name = tweak_name_for_test("/BlackFillsForm")
  let base = try! @pdflite.pdf_blank_document(200.0, 100.0, 2)
  let form = try! tweak_stream_for_test([Op_rg(1.0, 0.0, 0.0), Op_f]).add_dict_entry(
    key_subtype,
    PdfNameObject(key_form),
  )
  let form_number = base.add_object(form)
  let pages = try! base.pages_of_pagetree()
  let first = {
    ..pages[0],
    resources: PdfDictionary([
      (key_xobject, PdfDictionary([(form_name, PdfIndirect(form_number))])),
    ]),
    content: [tweak_stream_for_test([Op_Do(form_name), Op_g(0.8), Op_f])],
  }
  let second = {
    ..pages[1],
    content: [tweak_stream_for_test([Op_g(0.8), Op_f])],
  }
  let document = try! base.change_pages([first, second])

  let rewritten = try! @pdflite.pdf_black_fills(
    document,
    [1],
    PdfContentGrey(0.25),
  )
  let source_order = try! @pdflite.pdf_blackfills(
    PdfContentGrey(0.25),
    [1],
    document,
  )
  let rewritten_pages = try! rewritten.pages_of_pagetree()
  let source_order_pages = try! source_order.pages_of_pagetree()

  @test.assert_eq(tweak_content_ops_for_test(rewritten, rewritten_pages[0]), [
    Op_Do(form_name),
    Op_g(0.25),
    Op_f,
  ])
  @test.assert_eq(tweak_content_ops_for_test(rewritten, rewritten_pages[1]), [
    Op_g(0.8),
    Op_f,
  ])
  guard rewritten.lookup_object_or_null(form_number)
    is PdfStreamObject(form_stream) else {
    fail("expected retained form xobject stream")
  }
  @test.assert_eq(
    try! rewritten.parse_content_ops([PdfStreamObject(form_stream)]),
    [Op_g(0.25), Op_f],
  )
  @test.assert_eq(
    tweak_content_ops_for_test(source_order, source_order_pages[0]),
    tweak_content_ops_for_test(rewritten, rewritten_pages[0]),
  )
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
  let source_order = try! @pdflite.pdf_reveal_hidden_text_cpdf_order(
    [1],
    document,
  )
  let revealed_pages = try! revealed.pages_of_pagetree()
  let source_order_pages = try! source_order.pages_of_pagetree()

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
  @test.assert_eq(
    tweak_content_ops_for_test(source_order, source_order_pages[0]),
    tweak_content_ops_for_test(revealed, revealed_pages[0]),
  )
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
  let source_order = try! @pdflite.pdf_append_page_content_cpdf_order(
    tweak_bytes_for_test("BT ET"),
    true,
    false,
    [1],
    document,
  )
  let appended_pages = try! appended.pages_of_pagetree()
  let source_order_pages = try! source_order.pages_of_pagetree()

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
  @test.assert_eq(
    tweak_content_ops_for_test(source_order, source_order_pages[0]),
    tweak_content_ops_for_test(appended, appended_pages[0]),
  )
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
  let source_order = try! @pdflite.pdf_append_page_content_multiple_cpdf_order(
    [tweak_bytes_for_test("BT ET"), tweak_bytes_for_test("q Q")],
    false,
    false,
    base,
  )
  let appended_pages = try! appended.pages_of_pagetree()
  let source_order_pages = try! source_order.pages_of_pagetree()
  @test.assert_eq(tweak_content_ops_for_test(appended, appended_pages[0]), [
    Op_BT,
    Op_ET,
  ])
  @test.assert_eq(tweak_content_ops_for_test(appended, appended_pages[1]), [
    Op_q,
    Op_Q,
  ])
  @test.assert_eq(
    tweak_content_ops_for_test(source_order, source_order_pages[1]),
    tweak_content_ops_for_test(appended, appended_pages[1]),
  )

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
  let source_order = try! @pdflite.pdf_append_page_content_multiple_ops_cpdf_order(
    [[Op_BT, Op_ET], [Op_q, Op_Q]],
    true,
    false,
    base,
  )
  let appended_pages = try! appended.pages_of_pagetree()
  let source_order_pages = try! source_order.pages_of_pagetree()
  @test.assert_eq(tweak_content_ops_for_test(appended, appended_pages[0]), [
    Op_BT,
    Op_ET,
  ])
  @test.assert_eq(tweak_content_ops_for_test(appended, appended_pages[1]), [
    Op_q,
    Op_Q,
  ])
  @test.assert_eq(
    tweak_content_ops_for_test(source_order, source_order_pages[0]),
    tweak_content_ops_for_test(appended, appended_pages[0]),
  )

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
test "PdfDocument find_object_by_spec resolves trailer and object chains" {
  let key_root = tweak_name_for_test("/Root")
  let key_value = tweak_name_for_test("/Value")
  let key_items = tweak_name_for_test("/Items")
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(
    2,
    PdfDictionary([
      (key_value, PdfInteger(42)),
      (
        key_items,
        PdfArray([PdfInteger(7), PdfDictionary([(key_value, PdfInteger(9))])]),
      ),
    ]),
  )
  doc.set_trailer_dict(PdfDictionary([(key_root, PdfIndirect(2))]))

  @test.assert_eq(try! doc.find_object_by_spec(""), doc.trailer_dict())
  @test.assert_eq(
    try! @pdflite.pdf_find_object(doc, "/Root/Value"),
    PdfInteger(42),
  )
  @test.assert_eq(
    try! @pdflite.pdf_find_obj(doc, "/Root/Value"),
    PdfInteger(42),
  )
  @test.assert_eq(
    try! doc.find_object_by_spec("2/Items/[1/Value"),
    PdfInteger(9),
  )
  @test.assert_eq(
    try! doc.find_object_by_spec("2Value"),
    doc.lookup_object_or_null(2),
  )
  @test.assert_eq(
    try! doc.find_object_by_spec("0/Root"),
    doc.lookup_object_or_null(2),
  )
}

///|
test "PdfDocument find_object_by_spec resolves page object specs" {
  let key_page = tweak_name_for_test("/Page")
  let doc = try! @pdflite.pdf_blank_document(200.0, 100.0, 1)
  let page_refs = try! doc.page_reference_numbers()

  @test.assert_eq(
    try! doc.find_object_by_spec("P1"),
    doc.lookup_object_or_null(page_refs[0]),
  )
  @test.assert_eq(
    try! doc.find_object_by_spec("P1/Type"),
    PdfNameObject(key_page),
  )
}

///|
test "PdfDocument find_object_by_spec reports malformed specs and missing chains" {
  let doc = @pdflite.pdf_document_empty()
  let page_doc = try! @pdflite.pdf_blank_document(200.0, 100.0, 1)
  let bad_object : Result[@pdflite.PdfObject, Error] = try? doc.find_object_by_spec(
    "abc",
  )
  guard bad_object is Err(@pdflite.PdfError::BadPageSpecification(_)) else {
    fail("expected BadPageSpecification for malformed object spec")
  }
  let missing_chain : Result[@pdflite.PdfObject, Error] = try? doc.find_object_by_spec(
    "/Missing",
  )
  guard missing_chain is Err(@pdflite.PdfError::BadPageSpecification(_)) else {
    fail("expected BadPageSpecification for missing object chain")
  }
  let missing_page : Result[@pdflite.PdfObject, Error] = try? doc.find_object_by_spec(
    "P1",
  )
  guard missing_page is Err(@pdflite.PdfError::RootExpected) else {
    fail("expected RootExpected while resolving page object refs")
  }
  let out_of_range_page : Result[@pdflite.PdfObject, Error] = try? page_doc.find_object_by_spec(
    "P2",
  )
  guard out_of_range_page is Err(@pdflite.PdfError::BadPageSpecification(_)) else {
    fail("expected BadPageSpecification for out-of-range page object spec")
  }
}

///|
test "PdfDocument replace_object_by_spec updates chains objects and page specs" {
  let key_root = tweak_name_for_test("/Root")
  let key_value = tweak_name_for_test("/Value")
  let key_child = tweak_name_for_test("/Child")
  let key_items = tweak_name_for_test("/Items")
  let key_custom = tweak_name_for_test("/CustomPage")
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(5, PdfDictionary([(key_value, PdfInteger(5))]))
  doc.add_object_given_number(
    2,
    PdfDictionary([
      (key_value, PdfInteger(1)),
      (key_child, PdfDictionary([(key_value, PdfInteger(2))])),
      (
        key_items,
        PdfArray([
          PdfIndirect(5),
          PdfDictionary([(key_value, PdfInteger(9))]),
          PdfInteger(0),
        ]),
      ),
    ]),
  )
  doc.set_trailer_dict(PdfDictionary([(key_root, PdfIndirect(2))]))

  try! @pdflite.pdf_replace_object_by_spec(doc, "/Root/Value", PdfInteger(99))
  @test.assert_eq(try! doc.find_object_by_spec("/Root/Value"), PdfInteger(99))
  try! @pdflite.pdf_replace_obj(doc, "/Root/Value", PdfInteger(98))
  @test.assert_eq(try! doc.find_object_by_spec("/Root/Value"), PdfInteger(98))
  try! doc.replace_object_by_spec("/Root/Child/Value", PdfInteger(10))
  @test.assert_eq(
    try! doc.find_object_by_spec("/Root/Child/Value"),
    PdfInteger(10),
  )
  try! doc.replace_object_by_spec("2/Items/[1/Value", PdfInteger(11))
  @test.assert_eq(
    try! doc.find_object_by_spec("2/Items/[1/Value"),
    PdfInteger(11),
  )
  try! doc.replace_object_by_spec("2/Items/[0/Value", PdfInteger(12))
  @test.assert_eq(
    try! doc.find_object_by_spec("2/Items/[0/Value"),
    PdfInteger(12),
  )
  try! doc.replace_object_by_spec("2/Items/[1", PdfInteger(13))
  @test.assert_eq(try! doc.find_object_by_spec("2/Items/[1"), PdfInteger(13))

  try! doc.replace_object_by_spec("3", PdfInteger(3))
  @test.assert_eq(doc.lookup_object_or_null(3), PdfInteger(3))

  let trailer_doc = @pdflite.pdf_document_empty()
  try! trailer_doc.replace_object_by_spec(
    "",
    PdfDictionary([(key_value, PdfInteger(1))]),
  )
  @test.assert_eq(
    trailer_doc.trailer_dict(),
    PdfDictionary([(key_value, PdfInteger(1))]),
  )
  try! trailer_doc.replace_object_by_spec(
    "0",
    PdfDictionary([(key_value, PdfInteger(2))]),
  )
  @test.assert_eq(
    trailer_doc.trailer_dict(),
    PdfDictionary([(key_value, PdfInteger(2))]),
  )

  let page_doc = try! @pdflite.pdf_blank_document(200.0, 100.0, 1)
  try! page_doc.replace_object_by_spec("P1/Type", PdfNameObject(key_custom))
  @test.assert_eq(
    try! page_doc.find_object_by_spec("P1/Type"),
    PdfNameObject(key_custom),
  )

  let missing : Result[Unit, Error] = try? doc.replace_object_by_spec(
    "/Root/Missing",
    PdfInteger(0),
  )
  guard missing is Err(@pdflite.PdfError::BadPageSpecification(_)) else {
    fail("expected BadPageSpecification for missing replace chain")
  }
  let missing_intermediate : Result[Unit, Error] = try? doc.replace_object_by_spec(
    "2/Missing/Value",
    PdfInteger(0),
  )
  guard missing_intermediate is Err(@pdflite.PdfError::BadPageSpecification(_)) else {
    fail("expected BadPageSpecification for missing intermediate replace chain")
  }
  let missing_array_index : Result[Unit, Error] = try? doc.replace_object_by_spec(
    "2/Items/[9/Value",
    PdfInteger(0),
  )
  guard missing_array_index is Err(@pdflite.PdfError::BadPageSpecification(_)) else {
    fail("expected BadPageSpecification for missing array index")
  }
  let missing_direct_array_index : Result[Unit, Error] = try? doc.replace_object_by_spec(
    "2/Items/[9",
    PdfInteger(0),
  )
  guard missing_direct_array_index
    is Err(@pdflite.PdfError::BadPageSpecification(_)) else {
    fail("expected BadPageSpecification for direct missing array index")
  }
  let non_array_key : Result[Unit, Error] = try? doc.replace_object_by_spec(
    "2/Items/Value",
    PdfInteger(0),
  )
  guard non_array_key is Err(@pdflite.PdfError::BadPageSpecification(_)) else {
    fail("expected BadPageSpecification for non-array key inside array")
  }
  let bad_array_key : Result[Unit, Error] = try? doc.replace_object_by_spec(
    "2/Items/[x/Value",
    PdfInteger(0),
  )
  guard bad_array_key is Err(@pdflite.PdfError::BadPageSpecification(_)) else {
    fail("expected BadPageSpecification for malformed array pseudo-key")
  }
  let non_container : Result[Unit, Error] = try? doc.replace_object_by_spec(
    "2/Items/[2/Value",
    PdfInteger(0),
  )
  guard non_container is Err(@pdflite.PdfError::BadPageSpecification(_)) else {
    fail("expected BadPageSpecification for non-container replace chain")
  }
  let out_of_range_page : Result[Unit, Error] = try? page_doc.replace_object_by_spec(
    "P2/Type",
    PdfInteger(0),
  )
  guard out_of_range_page is Err(@pdflite.PdfError::BadPageSpecification(_)) else {
    fail("expected BadPageSpecification for out-of-range page replace spec")
  }
}

///|
test "PdfDocument remove_object_by_spec removes decimal object numbers" {
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(9, PdfInteger(9))

  try! @pdflite.pdf_remove_object_by_spec(doc, "9")
  @test.assert_eq(doc.lookup_object_or_null(9), PdfNull)
  doc.add_object_given_number(10, PdfInteger(10))
  try! @pdflite.pdf_remove_obj(doc, "10")
  @test.assert_eq(doc.lookup_object_or_null(10), PdfNull)

  let bad_spec : Result[Unit, Error] = try? doc.remove_object_by_spec("9/A")
  guard bad_spec is Err(@pdflite.PdfError::BadPageSpecification(_)) else {
    fail("expected BadPageSpecification for non-decimal remove object spec")
  }
  let empty_spec : Result[Unit, Error] = try? doc.remove_object_by_spec("")
  guard empty_spec is Err(@pdflite.PdfError::BadPageSpecification(_)) else {
    fail("expected BadPageSpecification for empty remove object spec")
  }
}

///|
test "PdfDocument replace_stream_by_spec updates bytes and Length" {
  let key_length = tweak_name_for_test("/Length")
  let key_filter = tweak_name_for_test("/Filter")
  let key_dummy = tweak_name_for_test("/Dummy")
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(
    4,
    @pdflite.pdf_stream(
      PdfDictionary([
        (key_length, PdfInteger(3)),
        (key_filter, PdfNameObject(key_dummy)),
      ]),
      StreamGot(tweak_bytes_for_test("old")),
    ),
  )

  try! @pdflite.pdf_replace_stream_by_spec(
    doc,
    "4",
    tweak_bytes_for_test("new data"),
  )
  guard doc.lookup_object_or_null(4) is PdfStreamObject(stream) else {
    fail("expected stream object after replace_stream_by_spec")
  }
  @test.assert_eq(
    try! @pdflite.pdf_stream(stream.dictionary, stream.data).stream_bytes(),
    tweak_bytes_for_test("new data"),
  )
  @test.assert_eq(
    doc.lookup_direct(key_length, PdfStreamObject(stream)),
    Some(PdfInteger(tweak_bytes_for_test("new data").length())),
  )
  @test.assert_eq(
    doc.lookup_direct(key_filter, PdfStreamObject(stream)),
    Some(PdfNameObject(key_dummy)),
  )

  let non_stream : Result[Unit, Error] = try? doc.replace_stream_by_spec(
    "3",
    tweak_bytes_for_test("x"),
  )
  guard non_stream is Err(@pdflite.PdfError::ParseStreamExpected) else {
    fail("expected ParseStreamExpected for non-stream replacement target")
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
  let source_order = try! @pdflite.pdf_thinlines([2], 2.0, document)
  let thinned_pages = try! thinned.pages_of_pagetree()
  let source_order_pages = try! source_order.pages_of_pagetree()

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
  @test.assert_eq(
    tweak_content_ops_for_test(source_order, source_order_pages[1]),
    tweak_content_ops_for_test(thinned, thinned_pages[1]),
  )
}
