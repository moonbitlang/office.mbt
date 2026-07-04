///|
fn page_redact_name_for_test(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn page_redact_stream_for_test(
  ops : ArrayView[@content.PdfContentOp],
) -> @syntax.PdfObject {
  try! @pdflite.pdf_content_stream_of_ops(ops)
}

///|
fn page_redact_page_for_test(
  ops : ArrayView[@content.PdfContentOp],
  rest? : @syntax.PdfObject = PdfDictionary([]),
  resources? : @syntax.PdfObject = PdfDictionary([]),
  rotate? : @page.PdfPageRotation = Rotate0,
) -> @page.PdfPage {
  {
    content: [page_redact_stream_for_test(ops)],
    mediabox: PdfArray([
      PdfReal(0.0),
      PdfReal(0.0),
      PdfReal(100.0),
      PdfReal(100.0),
    ]),
    resources,
    rotate,
    rest,
  }
}

///|
fn page_redact_document_for_test(
  pages : ArrayView[@page.PdfPage],
) -> @pdflite.PdfDocument {
  try! (try! @pdflite.pdf_blank_document(100.0, 100.0, pages.length())).change_pages(
    pages,
  )
}

///|
fn page_redact_ops_for_test(
  document : @pdflite.PdfDocument,
  page : @page.PdfPage,
) -> Array[@content.PdfContentOp] {
  try! document.parse_content_ops_with_resources(page.resources, page.content)
}

///|
fn page_redact_structure_doc_for_test() -> @pdflite.PdfDocument raise {
  let key_k = page_redact_name_for_test("/K")
  let key_obj = page_redact_name_for_test("/Obj")
  let doc = @pdflite.pdf_document_empty()
  let page_root = doc.add_pagetree([
    page_redact_page_for_test([Op_S]),
    page_redact_page_for_test([Op_BT]),
  ])
  ignore(doc.add_root(page_root, []))
  let page_numbers = doc.page_reference_numbers()
  doc.add_object_given_number(
    30,
    @syntax.pdf_dictionary([(key_k, PdfArray([PdfIndirect(31)]))]),
  )
  doc.add_object_given_number(
    31,
    @syntax.pdf_dictionary([
      (key_obj, PdfIndirect(page_numbers[0])),
      (key_k, PdfInteger(0)),
    ]),
  )
  doc
}

///|
test "PdfDocument redact_pages empties selected pages and preserves geometry" {
  let key_annots = page_redact_name_for_test("/Annots")
  let key_custom = page_redact_name_for_test("/Custom")
  let key_font = page_redact_name_for_test("/Font")
  let page1 = page_redact_page_for_test(
    [Op_S],
    rest=PdfDictionary([
      (key_annots, PdfArray([PdfInteger(1)])),
      (key_custom, PdfInteger(9)),
    ]),
    resources=PdfDictionary([(key_font, PdfDictionary([]))]),
    rotate=Rotate90,
  )
  let page2 = page_redact_page_for_test(
    [Op_BT],
    rest=PdfDictionary([(key_annots, PdfArray([PdfInteger(2)]))]),
    resources=PdfDictionary([(key_font, PdfInteger(2))]),
  )
  let document = page_redact_document_for_test([page1, page2])
  let redacted = try! document.redact_pages([1])
  let pages = try! redacted.pages_of_pagetree()
  @test.assert_eq(pages[0].content, [])
  @test.assert_eq(pages[0].resources, PdfDictionary([]))
  @test.assert_eq(pages[0].rotate, Rotate90)
  @test.assert_eq(pages[0].mediabox, page1.mediabox)
  @test.assert_eq(pages[0].rest.lookup_immediate(key_annots), None)
  @test.assert_eq(
    pages[0].rest.lookup_immediate(key_custom),
    Some(PdfInteger(9)),
  )
  @test.assert_eq(page_redact_ops_for_test(redacted, pages[1]), [Op_BT])
  @test.assert_eq(
    pages[1].rest.lookup_immediate(key_annots),
    Some(PdfArray([PdfInteger(2)])),
  )

  let wrapped = try! @pdflite.pdf_redact_pages(document, [2])
  let wrapped_pages = try! wrapped.pages_of_pagetree()
  @test.assert_eq(page_redact_ops_for_test(wrapped, wrapped_pages[0]), [Op_S])
  @test.assert_eq(wrapped_pages[1].content, [])
  let source_order = try! @pdflite.pdf_redact_pages_cpdf_order(
    false,
    document,
    [1],
  )
  let source_order_pages = try! source_order.pages_of_pagetree()
  @test.assert_eq(source_order_pages[0].content, [])
  @test.assert_eq(
    page_redact_ops_for_test(source_order, source_order_pages[1]),
    [Op_BT],
  )
}

///|
test "PdfDocument redact_pages optionally trims redacted page structure" {
  let key_k = page_redact_name_for_test("/K")
  let untrimmed = try! page_redact_structure_doc_for_test().redact_pages([1])
  guard untrimmed.lookup_object_or_null(30) != PdfNull else {
    fail("expected unprocessed redaction to leave structure objects")
  }
  @test.assert_eq(
    untrimmed.lookup_object_or_null(30).lookup_immediate(key_k),
    Some(PdfArray([PdfIndirect(31)])),
  )

  let trimmed = try! page_redact_structure_doc_for_test().redact_pages(
    [1],
    process_struct_tree=true,
  )
  @test.assert_eq(trimmed.lookup_object_or_null(30), PdfNull)
  let pages = try! trimmed.pages_of_pagetree()
  @test.assert_eq(pages[0].content, [])
  @test.assert_eq(page_redact_ops_for_test(trimmed, pages[1]), [Op_BT])
  let wrapped = try! @pdflite.pdf_redact_pages_cpdf_order(
    true,
    page_redact_structure_doc_for_test(),
    [1],
  )
  @test.assert_eq(wrapped.lookup_object_or_null(30), PdfNull)
}

///|
test "PdfDocument redact_pages validates selected pages" {
  let document = page_redact_document_for_test([
    page_redact_page_for_test([Op_S]),
  ])
  let bad : Result[@pdflite.PdfDocument, Error] = try
    document.redact_pages([2])
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad
    is Err(
      @core.PdfError::BadPageSpecification(
        "redact_pages: range contains pages not present in pdf"
      )
    ) else {
    fail("expected redact_pages to reject an out-of-range page")
  }
}
