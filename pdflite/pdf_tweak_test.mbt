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
