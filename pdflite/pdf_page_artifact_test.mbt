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
  xobjects? : ArrayView[(@pdflite.PdfName, @pdflite.PdfObject)] = [],
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
) -> @pdflite.PdfPage raise @pdflite.PdfError {
  {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    content: [artifact_stream_for_test(ops)],
    resources,
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
      resources=artifact_resources_for_test(xobjects=[
        (xobject_name, PdfIndirect(20)),
      ]),
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
