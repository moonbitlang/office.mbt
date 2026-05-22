///|
fn remove_text_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn remove_text_bytes_for_test(text : String) -> Bytes {
  @ascii.encode(text)
}

///|
fn remove_text_stream_for_test(
  ops : ArrayView[@pdflite.PdfContentOp],
) -> @pdflite.PdfObject {
  try! @pdflite.pdf_content_stream_of_ops(ops)
}

///|
fn remove_text_content_ops_for_test(
  document : @pdflite.PdfDocument,
  page : @pdflite.PdfPage,
) -> Array[@pdflite.PdfContentOp] {
  try! document.parse_content_ops_with_resources(page.resources, page.content)
}

///|
test "pdf_remove_added_text_ops skips nested CPDFSTAMP blocks" {
  let stamp = remove_text_name_for_test("/CPDFSTAMP")
  let ops : Array[@pdflite.PdfContentOp] = [
    Op_q,
    Op_BMC(stamp),
    Op_Tj(remove_text_bytes_for_test("drop outer")),
    Op_BMC(stamp),
    Op_Tj(remove_text_bytes_for_test("drop inner")),
    Op_EMC,
    Op_Tj(remove_text_bytes_for_test("still drop")),
    Op_EMC,
    Op_Tj(remove_text_bytes_for_test("keep")),
  ]
  @test.assert_eq(@pdflite.pdf_remove_added_text_ops(ops), [
    Op_q,
    Op_Tj(remove_text_bytes_for_test("keep")),
  ])
}

///|
test "pdf_remove_added_text_ops drops unterminated stamp tail" {
  let stamp = remove_text_name_for_test("/CPDFSTAMP")
  @test.assert_eq(
    @pdflite.pdf_remove_added_text_ops([
      Op_Tj(remove_text_bytes_for_test("keep")),
      Op_BMC(stamp),
      Op_Tj(remove_text_bytes_for_test("drop")),
    ]),
    [Op_Tj(remove_text_bytes_for_test("keep"))],
  )
}

///|
test "pdf_remove_all_text_ops removes only text showing operators" {
  let text = remove_text_bytes_for_test("text")
  let ops : Array[@pdflite.PdfContentOp] = [
    Op_BT,
    Op_Tf(remove_text_name_for_test("/F1"), 12.0),
    Op_Tj(text),
    Op_TJ(PdfArray([PdfString(text), PdfInteger(20)])),
    Op_quote(text),
    Op_double_quote(1.0, 2.0, text),
    Op_Tstar,
    Op_ET,
  ]
  @test.assert_eq(@pdflite.pdf_remove_all_text_ops(ops), [
    Op_BT,
    Op_Tf(remove_text_name_for_test("/F1"), 12.0),
    Op_Tstar,
    Op_ET,
  ])
}

///|
test "PdfDocument remove_added_text rewrites only selected pages" {
  let stamp = remove_text_name_for_test("/CPDFSTAMP")
  let base = try! @pdflite.pdf_blank_document(200.0, 100.0, 2)
  let pages = try! base.pages_of_pagetree()
  let first = {
    ..pages[0],
    content: [
      remove_text_stream_for_test([
        Op_BMC(stamp),
        Op_Tj(remove_text_bytes_for_test("drop first")),
        Op_EMC,
        Op_Tj(remove_text_bytes_for_test("keep first")),
      ]),
    ],
  }
  let second = {
    ..pages[1],
    content: [
      remove_text_stream_for_test([
        Op_BMC(stamp),
        Op_Tj(remove_text_bytes_for_test("keep second stamp")),
        Op_EMC,
        Op_Tj(remove_text_bytes_for_test("keep second")),
      ]),
    ],
  }
  let document = try! base.change_pages([first, second])
  let stripped = try! document.remove_added_text([1])
  let stripped_pages = try! stripped.pages_of_pagetree()
  @test.assert_eq(
    remove_text_content_ops_for_test(stripped, stripped_pages[0]),
    [Op_Tj(remove_text_bytes_for_test("keep first"))],
  )
  @test.assert_eq(
    remove_text_content_ops_for_test(stripped, stripped_pages[1]),
    [
      Op_BMC(stamp),
      Op_Tj(remove_text_bytes_for_test("keep second stamp")),
      Op_EMC,
      Op_Tj(remove_text_bytes_for_test("keep second")),
    ],
  )
}

///|
test "pdf_remove_added_text wrapper preserves source document" {
  let stamp = remove_text_name_for_test("/CPDFSTAMP")
  let base = try! @pdflite.pdf_blank_document(200.0, 100.0, 1)
  let pages = try! base.pages_of_pagetree()
  let page = {
    ..pages[0],
    content: [
      remove_text_stream_for_test([
        Op_BMC(stamp),
        Op_Tj(remove_text_bytes_for_test("drop")),
        Op_EMC,
        Op_Tj(remove_text_bytes_for_test("keep")),
      ]),
    ],
  }
  let document = try! base.change_pages([page])
  let stripped = try! @pdflite.pdf_remove_added_text(document, [1])
  let source_order = try! @pdflite.pdf_removetext([1], document)
  let stripped_pages = try! stripped.pages_of_pagetree()
  @test.assert_eq(
    remove_text_content_ops_for_test(stripped, stripped_pages[0]),
    [Op_Tj(remove_text_bytes_for_test("keep"))],
  )
  let source_order_pages = try! source_order.pages_of_pagetree()
  @test.assert_eq(
    remove_text_content_ops_for_test(source_order, source_order_pages[0]),
    [Op_Tj(remove_text_bytes_for_test("keep"))],
  )
  let original_pages = try! document.pages_of_pagetree()
  @test.assert_eq(
    remove_text_content_ops_for_test(document, original_pages[0]),
    [
      Op_BMC(stamp),
      Op_Tj(remove_text_bytes_for_test("drop")),
      Op_EMC,
      Op_Tj(remove_text_bytes_for_test("keep")),
    ],
  )
}

///|
test "PdfDocument remove_all_text rewrites selected page and form xobjects" {
  let key_type = remove_text_name_for_test("/Type")
  let key_xobject = remove_text_name_for_test("/XObject")
  let key_subtype = remove_text_name_for_test("/Subtype")
  let key_form = remove_text_name_for_test("/Form")
  let form_name = remove_text_name_for_test("/Fm1")
  let base = try! @pdflite.pdf_blank_document(200.0, 100.0, 1)
  let form_with_type = try! remove_text_stream_for_test([
    Op_q,
    Op_Tj(remove_text_bytes_for_test("form text")),
    Op_Q,
  ]).add_dict_entry(key_type, PdfNameObject(key_xobject))
  let form = try! form_with_type.add_dict_entry(
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
    content: [
      remove_text_stream_for_test([
        Op_Do(form_name),
        Op_Tj(remove_text_bytes_for_test("page text")),
      ]),
    ],
  }
  let document = try! base.change_pages([page])
  let stripped = try! document.remove_all_text([1])
  let stripped_pages = try! stripped.pages_of_pagetree()
  @test.assert_eq(
    remove_text_content_ops_for_test(stripped, stripped_pages[0]),
    [Op_Do(form_name)],
  )
  guard stripped.lookup_object_or_null(form_number)
    is PdfStreamObject(form_stream) else {
    fail("expected retained form xobject stream")
  }
  @test.assert_eq(
    try! stripped.parse_content_ops([PdfStreamObject(form_stream)]),
    [Op_q, Op_Q],
  )
}

///|
test "pdf_remove_all_text wrapper preserves source document" {
  let base = try! @pdflite.pdf_blank_document(200.0, 100.0, 1)
  let pages = try! base.pages_of_pagetree()
  let page = {
    ..pages[0],
    content: [
      remove_text_stream_for_test([
        Op_Tj(remove_text_bytes_for_test("drop")),
        Op_Tstar,
      ]),
    ],
  }
  let document = try! base.change_pages([page])
  let stripped = try! @pdflite.pdf_remove_all_text(document, [1])
  let source_order = try! @pdflite.pdf_remove_all_text_cpdf_order([1], document)
  let stripped_pages = try! stripped.pages_of_pagetree()
  @test.assert_eq(
    remove_text_content_ops_for_test(stripped, stripped_pages[0]),
    [Op_Tstar],
  )
  let source_order_pages = try! source_order.pages_of_pagetree()
  @test.assert_eq(
    remove_text_content_ops_for_test(source_order, source_order_pages[0]),
    [Op_Tstar],
  )
  let original_pages = try! document.pages_of_pagetree()
  @test.assert_eq(
    remove_text_content_ops_for_test(document, original_pages[0]),
    [Op_Tj(remove_text_bytes_for_test("drop")), Op_Tstar],
  )
}
