///|
fn artifact_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn artifact_stream_for_test(
  ops : ArrayView[@pdflite.PdfContentOp],
) -> @pdflite.PdfObject raise @pdflite.PdfError {
  @pdflite.pdf_content_stream_of_ops(ops)
}

///|
fn artifact_resources_for_test(
  xobjects : ArrayView[(@pdflite.PdfName, @pdflite.PdfObject)],
) -> @pdflite.PdfObject {
  if xobjects.length() == 0 {
    @pdflite.pdf_dictionary([])
  } else {
    @pdflite.pdf_dictionary([
      (artifact_name_for_test("/XObject"), @pdflite.pdf_dictionary(xobjects)),
    ])
  }
}

///|
fn artifact_page_for_test(
  ops : ArrayView[@pdflite.PdfContentOp],
  resources? : @pdflite.PdfObject = @pdflite.pdf_dictionary([]),
  rest? : @pdflite.PdfObject = @pdflite.pdf_dictionary([]),
) -> @pdflite.PdfPage raise @pdflite.PdfError {
  {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    content: [artifact_stream_for_test(ops)],
    resources,
    rest,
  }
}

///|
fn artifact_document_for_test(
  pages : ArrayView[@pdflite.PdfPage],
) -> @pdflite.PdfDocument raise @pdflite.PdfError {
  @pdflite.pdf_blank_document(100.0, 100.0, pages.length()).change_pages(pages)
}

///|
fn artifact_page_ops_for_test(
  document : @pdflite.PdfDocument,
  page : @pdflite.PdfPage,
) -> Array[@pdflite.PdfContentOp] raise @pdflite.PdfError {
  document.parse_content_ops_with_resources(page.resources, page.content)
}

///|
test "PdfDocument remove_struct_tree strips structure entries and marked content" {
  let key_keep = artifact_name_for_test("/Keep")
  let key_mcid = artifact_name_for_test("/MCID")
  let key_struct_parent = artifact_name_for_test("/StructParent")
  let key_struct_parents = artifact_name_for_test("/StructParents")
  let key_struct_tree_root = artifact_name_for_test("/StructTreeRoot")
  let span = artifact_name_for_test("/Span")
  let document = try! artifact_document_for_test([
    try! artifact_page_for_test(
      [
        Op_MP(span),
        Op_DP(span, PdfDictionary([(key_mcid, PdfInteger(7))])),
        Op_BMC(span),
        Op_BT,
        Op_EMC,
        Op_BDC(span, PdfDictionary([])),
        Op_ET,
        Op_EMC,
      ],
      rest=@pdflite.pdf_dictionary([
        (key_struct_parents, PdfInteger(0)),
        (key_keep, PdfInteger(9)),
      ]),
    ),
  ])
  document.add_object_given_number(
    document.root(),
    try! document
    .lookup_object_or_null(document.root())
    .add_dict_entry(key_struct_tree_root, PdfIndirect(30)),
  )
  document.add_object_given_number(
    30,
    @pdflite.pdf_dictionary([(key_keep, PdfInteger(30))]),
  )
  document.add_object_given_number(
    40,
    @pdflite.pdf_dictionary([
      (key_struct_parent, PdfInteger(1)),
      (key_keep, PdfInteger(40)),
    ]),
  )
  let removed = try! document.remove_struct_tree()
  let wrapped = try! @pdflite.pdf_remove_struct_tree(document)
  let pages = try! removed.pages_of_pagetree()
  let wrapped_pages = try! wrapped.pages_of_pagetree()
  @test.assert_eq(try! artifact_page_ops_for_test(removed, pages[0]), [
    Op_BT,
    Op_ET,
  ])
  @test.assert_eq(try! artifact_page_ops_for_test(wrapped, wrapped_pages[0]), [
    Op_BT,
    Op_ET,
  ])
  @test.assert_eq(
    removed
    .lookup_object_or_null(removed.root())
    .lookup_immediate(key_struct_tree_root),
    None,
  )
  @test.assert_eq(pages[0].rest.lookup_immediate(key_struct_parents), None)
  @test.assert_eq(pages[0].rest.lookup_immediate(key_keep), Some(PdfInteger(9)))
  @test.assert_eq(
    removed.lookup_object_or_null(40).lookup_immediate(key_struct_parent),
    None,
  )
  @test.assert_eq(
    removed.lookup_object_or_null(40).lookup_immediate(key_keep),
    Some(PdfInteger(40)),
  )
}

///|
test "PdfDocument remove_struct_tree rewrites referenced form xobjects" {
  let subtype_key = artifact_name_for_test("/Subtype")
  let form_name = artifact_name_for_test("/Form")
  let xobject_name = artifact_name_for_test("/Fm1")
  let span = artifact_name_for_test("/Span")
  let form = try! (try! artifact_stream_for_test([Op_BMC(span), Op_BT, Op_EMC])).add_dict_entry(
    subtype_key,
    PdfNameObject(form_name),
  )
  let source = try! artifact_document_for_test([
    try! artifact_page_for_test(
      [Op_Do(xobject_name)],
      resources=artifact_resources_for_test([(xobject_name, PdfIndirect(20))]),
    ),
  ])
  source.add_object_given_number(20, form)
  let removed = try! source.remove_struct_tree()
  let pages = try! removed.pages_of_pagetree()
  @test.assert_eq(try! artifact_page_ops_for_test(removed, pages[0]), [
    Op_Do(xobject_name),
  ])
  guard removed.lookup_object_or_null(20) is PdfStreamObject(stream) else {
    fail("expected rewritten form stream")
  }
  @test.assert_eq(try! removed.parse_content_ops([PdfStreamObject(stream)]), [
    Op_BT,
  ])
}

///|
test "PdfDocument mark_all_as_artifact wraps page content" {
  let document = try! artifact_document_for_test([
    try! artifact_page_for_test([Op_BT, Op_ET]),
  ])
  let marked = try! document.mark_all_as_artifact()
  let wrapped = try! @pdflite.pdf_mark_all_as_artifact(document)
  let pages = try! marked.pages_of_pagetree()
  let wrapped_pages = try! wrapped.pages_of_pagetree()
  let expected : Array[@pdflite.PdfContentOp] = [
    @pdflite.pdf_content_begin_artifact(),
    Op_BT,
    Op_ET,
    @pdflite.pdf_content_end_artifact(),
  ]
  @test.assert_eq(try! artifact_page_ops_for_test(marked, pages[0]), expected)
  @test.assert_eq(
    try! artifact_page_ops_for_test(wrapped, wrapped_pages[0]),
    expected,
  )
}

///|
test "PdfDocument mark_all_as_artifact rewrites referenced form xobjects" {
  let subtype_key = artifact_name_for_test("/Subtype")
  let form_name = artifact_name_for_test("/Form")
  let xobject_name = artifact_name_for_test("/Fm1")
  let form = try! (try! artifact_stream_for_test([Op_BT, Op_ET])).add_dict_entry(
    subtype_key,
    PdfNameObject(form_name),
  )
  let source = try! artifact_document_for_test([
    try! artifact_page_for_test(
      [Op_Do(xobject_name)],
      resources=artifact_resources_for_test([(xobject_name, PdfIndirect(20))]),
    ),
  ])
  source.add_object_given_number(20, form)
  let marked = try! source.mark_all_as_artifact()
  let pages = try! marked.pages_of_pagetree()
  @test.assert_eq(try! artifact_page_ops_for_test(marked, pages[0]), [
    @pdflite.pdf_content_begin_artifact(),
    Op_Do(xobject_name),
    @pdflite.pdf_content_end_artifact(),
  ])
  guard marked.lookup_object_or_null(20) is PdfStreamObject(stream) else {
    fail("expected marked form stream")
  }
  @test.assert_eq(try! marked.parse_content_ops([PdfStreamObject(stream)]), [
    @pdflite.pdf_content_begin_artifact(),
    Op_BT,
    Op_ET,
    @pdflite.pdf_content_end_artifact(),
  ])
}
