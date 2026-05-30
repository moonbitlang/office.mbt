///|
fn draft_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn draft_substitute_ops_for_test() -> Array[@pdflite.PdfContentOp] {
  [
    Op_q,
    Op_w(0.0),
    Op_G(0.0),
    Op_re(0.0, 0.0, 1.0, 1.0),
    Op_m(0.0, 0.0),
    Op_l(1.0, 1.0),
    Op_m(0.0, 1.0),
    Op_l(1.0, 0.0),
    Op_S,
    Op_Q,
  ]
}

///|
fn draft_inline_image_for_test() -> @pdflite.PdfContentOp {
  Op_InlineImage(
    PdfDictionary([
      (draft_name_for_test("/W"), PdfInteger(1)),
      (draft_name_for_test("/H"), PdfInteger(1)),
      (
        draft_name_for_test("/CS"),
        PdfNameObject(draft_name_for_test("/DeviceGray")),
      ),
      (draft_name_for_test("/BPC"), PdfInteger(1)),
    ]),
    None,
    Bytes::from_array([0]),
  )
}

///|
fn draft_image_object_for_test() -> @pdflite.PdfObject {
  @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (
        draft_name_for_test("/Subtype"),
        PdfNameObject(draft_name_for_test("/Image")),
      ),
      (draft_name_for_test("/Length"), PdfInteger(0)),
    ]),
    StreamGot([]),
  )
}

///|
fn draft_subtyped_dictionary_for_test(
  subtype : @pdflite.PdfName,
) -> @pdflite.PdfObject {
  @pdflite.pdf_dictionary([
    (draft_name_for_test("/Subtype"), PdfNameObject(subtype)),
  ])
}

///|
fn draft_resources_for_test(
  entries : ArrayView[(@pdflite.PdfName, @pdflite.PdfObject)],
) -> @pdflite.PdfObject {
  @pdflite.pdf_dictionary([
    (draft_name_for_test("/XObject"), @pdflite.pdf_dictionary(entries)),
  ])
}

///|
fn draft_form_object_for_test(
  ops : ArrayView[@pdflite.PdfContentOp],
  resources : @pdflite.PdfObject,
) -> @pdflite.PdfObject {
  let stream = try! @pdflite.pdf_content_stream_of_ops(ops)
  try! (try! stream.add_dict_entry(
    draft_name_for_test("/Subtype"),
    PdfNameObject(draft_name_for_test("/Form")),
  )).add_dict_entry(draft_name_for_test("/Resources"), resources)
}

///|
fn draft_document_for_test(
  doc : @pdflite.PdfDocument,
  pages : ArrayView[@page.PdfPage],
) -> @pdflite.PdfDocument {
  let page_root = try! doc.add_pagetree(pages)
  ignore(try! doc.add_root(page_root, []))
  doc
}

///|
fn draft_lookup_for_test(
  doc : @pdflite.PdfDocument,
  key : String,
  object : @pdflite.PdfObject,
) -> @pdflite.PdfObject raise {
  match doc.lookup_direct(draft_name_for_test(key), object) {
    Some(value) => value
    None => fail("missing " + key)
  }
}

///|
fn draft_xobject_entries_for_test(
  doc : @pdflite.PdfDocument,
  resources : @pdflite.PdfObject,
) -> Array[(@pdflite.PdfName, @pdflite.PdfObject)] raise {
  match draft_lookup_for_test(doc, "/XObject", resources) {
    PdfDictionary(entries) => entries
    _ => fail("expected XObject dictionary")
  }
}

///|
test "PdfDocument draft removes image xobjects and inline images" {
  let image_name = draft_name_for_test("/Im1")
  let form_name = draft_name_for_test("/Fm1")
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(7, draft_image_object_for_test())
  doc.add_object_given_number(
    8,
    draft_form_object_for_test([Op_q, Op_Q], PdfDictionary([])),
  )
  let page = {
    ..@page.pdf_page_blank(@pdflite.paper_a4),
    resources: draft_resources_for_test([
      (image_name, PdfIndirect(7)),
      (form_name, PdfIndirect(8)),
    ]),
    content: [
      try! @pdflite.pdf_content_stream_of_ops([
        Op_Do(image_name),
        Op_Do(form_name),
        draft_inline_image_for_test(),
      ]),
    ],
  }
  let drafted = try! draft_document_for_test(doc, [page]).draft(None, true, [1])
  let pages = try! drafted.pages_of_pagetree()
  @test.assert_eq(
    try! drafted.parse_content_ops(pages[0].content),
    [
      ..draft_substitute_ops_for_test(),
      Op_Do(form_name),
      ..draft_substitute_ops_for_test(),
    ],
  )
  let xobjects = try! draft_xobject_entries_for_test(
    drafted,
    pages[0].resources,
  )
  @test.assert_eq(xobjects.length(), 1)
  @test.assert_eq(xobjects[0].0, form_name)
  guard drafted.direct(xobjects[0].1) is PdfStreamObject(_) else {
    fail("expected retained form XObject")
  }
  @test.assert_eq(drafted.lookup_object_or_null(7), PdfNull)
  let reparsed = try! @pdflite.pdf_read_document_from_bytes(
    try! @pdflite.pdf_write_document(drafted),
  )
  let reparsed_pages = try! reparsed.pages_of_pagetree()
  @test.assert_eq(
    try! reparsed.parse_content_ops(reparsed_pages[0].content),
    [
      ..draft_substitute_ops_for_test(),
      Op_Do(form_name),
      ..draft_substitute_ops_for_test(),
    ],
  )
}

///|
test "PdfDocument draft only_remove keeps other images and inline images" {
  let first_name = draft_name_for_test("/Im1")
  let second_name = draft_name_for_test("/Im2")
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(7, draft_image_object_for_test())
  doc.add_object_given_number(8, draft_image_object_for_test())
  let inline = draft_inline_image_for_test()
  let page = {
    ..@page.pdf_page_blank(@pdflite.paper_a4),
    resources: draft_resources_for_test([
      (first_name, PdfIndirect(7)),
      (second_name, PdfIndirect(8)),
    ]),
    content: [
      try! @pdflite.pdf_content_stream_of_ops([
        Op_Do(first_name),
        Op_Do(second_name),
        inline,
      ]),
    ],
  }
  let drafted = try! draft_document_for_test(doc, [page]).draft(
    Some(first_name),
    true,
    [1],
  )
  let pages = try! drafted.pages_of_pagetree()
  @test.assert_eq(
    try! drafted.parse_content_ops(pages[0].content),
    [..draft_substitute_ops_for_test(), Op_Do(second_name), inline],
  )
  @test.assert_eq(
    try! draft_xobject_entries_for_test(drafted, pages[0].resources),
    [(second_name, PdfIndirect(8))],
  )
  @test.assert_eq(drafted.lookup_object_or_null(7), PdfNull)
  guard drafted.lookup_object_or_null(8) is PdfStreamObject(_) else {
    fail("expected non-target image to remain")
  }
}

///|
test "PdfDocument draft recurses into form xobjects" {
  let form_name = draft_name_for_test("/Fm1")
  let inner_name = draft_name_for_test("/Inner")
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(9, draft_image_object_for_test())
  doc.add_object_given_number(
    8,
    draft_form_object_for_test(
      [Op_Do(inner_name), draft_inline_image_for_test()],
      draft_resources_for_test([(inner_name, PdfIndirect(9))]),
    ),
  )
  let page = {
    ..@page.pdf_page_blank(@pdflite.paper_a4),
    resources: draft_resources_for_test([(form_name, PdfIndirect(8))]),
    content: [try! @pdflite.pdf_content_stream_of_ops([Op_Do(form_name)])],
  }
  let drafted = try! draft_document_for_test(doc, [page]).draft(None, true, [1])
  let pages = try! drafted.pages_of_pagetree()
  @test.assert_eq(try! drafted.parse_content_ops(pages[0].content), [
    Op_Do(form_name),
  ])
  let xobjects = try! draft_xobject_entries_for_test(
    drafted,
    pages[0].resources,
  )
  @test.assert_eq(xobjects.length(), 1)
  let form = drafted.direct(xobjects[0].1)
  let form_resources = try! draft_lookup_for_test(drafted, "/Resources", form)
  @test.assert_eq(
    try! draft_xobject_entries_for_test(drafted, form_resources),
    [],
  )
  @test.assert_eq(
    try! drafted.parse_content_ops_with_resources(form_resources, [form]),
    [..draft_substitute_ops_for_test(), ..draft_substitute_ops_for_test()],
  )
  @test.assert_eq(drafted.lookup_object_or_null(9), PdfNull)
}

///|
test "PdfDocument draft can remove without replacement boxes" {
  let image_name = draft_name_for_test("/Im1")
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(7, draft_image_object_for_test())
  let page = {
    ..@page.pdf_page_blank(@pdflite.paper_a4),
    resources: draft_resources_for_test([(image_name, PdfIndirect(7))]),
    content: [
      try! @pdflite.pdf_content_stream_of_ops([
        Op_Do(image_name),
        draft_inline_image_for_test(),
      ]),
    ],
  }
  let drafted = try! draft_document_for_test(doc, [page]).draft(None, false, [1])
  let pages = try! drafted.pages_of_pagetree()
  @test.assert_eq(try! drafted.parse_content_ops(pages[0].content), [])
  @test.assert_eq(
    try! draft_xobject_entries_for_test(drafted, pages[0].resources),
    [],
  )
}

///|
test "pdf_draft wrapper leaves unselected pages unchanged" {
  let image_name = draft_name_for_test("/Im1")
  let missing_name = draft_name_for_test("/Missing")
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(7, draft_image_object_for_test())
  let selected = {
    ..@page.pdf_page_blank(@pdflite.paper_a4),
    resources: draft_resources_for_test([(image_name, PdfIndirect(7))]),
    content: [
      try! @pdflite.pdf_content_stream_of_ops([
        Op_Do(image_name),
        draft_inline_image_for_test(),
      ]),
    ],
  }
  let unselected = {
    ..@page.pdf_page_blank(@pdflite.paper_a4),
    resources: @pdflite.pdf_dictionary([
      (draft_name_for_test("/ProcSet"), PdfArray([])),
    ]),
    content: [try! @pdflite.pdf_content_stream_of_ops([Op_Do(missing_name)])],
  }
  let drafted = try! @pdflite.pdf_draft(
    None,
    true,
    [1],
    draft_document_for_test(doc, [selected, unselected]),
  )
  let pages = try! drafted.pages_of_pagetree()
  @test.assert_eq(
    try! drafted.parse_content_ops(pages[0].content),
    [..draft_substitute_ops_for_test(), ..draft_substitute_ops_for_test()],
  )
  @test.assert_eq(try! drafted.parse_content_ops(pages[1].content), [
    Op_Do(missing_name),
  ])
  @test.assert_eq(
    pages[1].resources,
    @pdflite.pdf_dictionary([(draft_name_for_test("/ProcSet"), PdfArray([]))]),
  )
}

///|
test "pdf_draft_string accepts source string image names" {
  let first_name = draft_name_for_test("/Im1")
  let second_name = draft_name_for_test("/Im2")
  let inline = draft_inline_image_for_test()
  let page = {
    ..@page.pdf_page_blank(@pdflite.paper_a4),
    resources: draft_resources_for_test([
      (first_name, PdfIndirect(7)),
      (second_name, PdfIndirect(8)),
    ]),
    content: [
      try! @pdflite.pdf_content_stream_of_ops([
        Op_Do(first_name),
        Op_Do(second_name),
        inline,
      ]),
    ],
  }
  let named_doc = @pdflite.pdf_document_empty()
  named_doc.add_object_given_number(7, draft_image_object_for_test())
  named_doc.add_object_given_number(8, draft_image_object_for_test())
  let named = try! @pdflite.pdf_draft(
    Some(first_name),
    true,
    [1],
    draft_document_for_test(named_doc, [page]),
  )
  let string_doc = @pdflite.pdf_document_empty()
  string_doc.add_object_given_number(7, draft_image_object_for_test())
  string_doc.add_object_given_number(8, draft_image_object_for_test())
  let string_named = try! @pdflite.pdf_draft_string(
    Some("/Im1"),
    true,
    [1],
    draft_document_for_test(string_doc, [page]),
  )
  let named_pages = try! named.pages_of_pagetree()
  let string_pages = try! string_named.pages_of_pagetree()
  @test.assert_eq(
    try! string_named.parse_content_ops(string_pages[0].content),
    try! named.parse_content_ops(named_pages[0].content),
  )
  @test.assert_eq(
    try! draft_xobject_entries_for_test(string_named, string_pages[0].resources),
    try! draft_xobject_entries_for_test(named, named_pages[0].resources),
  )
  @test.assert_eq(string_named.lookup_object_or_null(7), PdfNull)
  guard string_named.lookup_object_or_null(8) is PdfStreamObject(_) else {
    fail("expected non-target image to remain")
  }
}

///|
test "PdfDocument draft keeps missing and non-image xobject draws" {
  let plain_name = draft_name_for_test("/Plain")
  let missing_name = draft_name_for_test("/Missing")
  let doc = @pdflite.pdf_document_empty()
  let page = {
    ..@page.pdf_page_blank(@pdflite.paper_a4),
    resources: draft_resources_for_test([
      (plain_name, @pdflite.pdf_dictionary([])),
    ]),
    content: [
      try! @pdflite.pdf_content_stream_of_ops([
        Op_Do(plain_name),
        Op_Do(missing_name),
      ]),
    ],
  }
  let drafted = try! draft_document_for_test(doc, [page]).draft(None, true, [1])
  let pages = try! drafted.pages_of_pagetree()
  @test.assert_eq(try! drafted.parse_content_ops(pages[0].content), [
    Op_Do(plain_name),
    Op_Do(missing_name),
  ])
  @test.assert_eq(
    try! draft_xobject_entries_for_test(drafted, pages[0].resources),
    [(plain_name, @pdflite.pdf_dictionary([]))],
  )
}

///|
test "PdfDocument draft keeps selected pages without xobject resources" {
  let missing_name = draft_name_for_test("/Missing")
  let doc = @pdflite.pdf_document_empty()
  let page = {
    ..@page.pdf_page_blank(@pdflite.paper_a4),
    resources: @pdflite.pdf_dictionary([
      (draft_name_for_test("/ProcSet"), PdfArray([])),
    ]),
    content: [try! @pdflite.pdf_content_stream_of_ops([Op_Do(missing_name)])],
  }
  let drafted = try! draft_document_for_test(doc, [page]).draft(None, true, [1])
  let pages = try! drafted.pages_of_pagetree()
  @test.assert_eq(try! drafted.parse_content_ops(pages[0].content), [
    Op_Do(missing_name),
  ])
  @test.assert_eq(
    pages[0].resources,
    @pdflite.pdf_dictionary([(draft_name_for_test("/ProcSet"), PdfArray([]))]),
  )
}

///|
test "PdfDocument draft handles null resources on empty selected pages" {
  let doc = @pdflite.pdf_document_empty()
  let page = { ..@page.pdf_page_blank(@pdflite.paper_a4), resources: PdfNull }
  let drafted = try! draft_document_for_test(doc, [page]).draft(None, true, [1])
  let pages = try! drafted.pages_of_pagetree()
  @test.assert_eq(try! drafted.parse_content_ops(pages[0].content), [])
  @test.assert_eq(pages[0].resources, PdfDictionary([]))
}

///|
test "PdfDocument draft rewrites forms without resources" {
  let form_name = draft_name_for_test("/Fm1")
  let doc = @pdflite.pdf_document_empty()
  let form = try! (try! @pdflite.pdf_content_stream_of_ops([
    draft_inline_image_for_test(),
  ])).add_dict_entry(
    draft_name_for_test("/Subtype"),
    PdfNameObject(draft_name_for_test("/Form")),
  )
  doc.add_object_given_number(8, form)
  let page = {
    ..@page.pdf_page_blank(@pdflite.paper_a4),
    resources: draft_resources_for_test([(form_name, PdfIndirect(8))]),
    content: [try! @pdflite.pdf_content_stream_of_ops([Op_Do(form_name)])],
  }
  let drafted = try! draft_document_for_test(doc, [page]).draft(None, false, [1])
  let pages = try! drafted.pages_of_pagetree()
  @test.assert_eq(try! drafted.parse_content_ops(pages[0].content), [
    Op_Do(form_name),
  ])
  let xobjects = try! draft_xobject_entries_for_test(
    drafted,
    pages[0].resources,
  )
  let rewritten_form = drafted.direct(xobjects[0].1)
  let form_resources = try! draft_lookup_for_test(
    drafted, "/Resources", rewritten_form,
  )
  @test.assert_eq(form_resources, PdfDictionary([]))
  @test.assert_eq(
    try! drafted.parse_content_ops_with_resources(form_resources, [
      rewritten_form,
    ]),
    [],
  )
}

///|
test "PdfDocument draft rejects malformed xobject resources" {
  let image_name = draft_name_for_test("/Im1")
  let doc = @pdflite.pdf_document_empty()
  let page = {
    ..@page.pdf_page_blank(@pdflite.paper_a4),
    resources: @pdflite.pdf_dictionary([
      (draft_name_for_test("/XObject"), PdfInteger(1)),
    ]),
    content: [try! @pdflite.pdf_content_stream_of_ops([Op_Do(image_name)])],
  }
  let result : Result[@pdflite.PdfDocument, Error] = try? draft_document_for_test(
    doc,
    [page],
  ).draft(None, true, [1])
  guard result is Err(@pdflite.PdfError::DictionaryExpected) else {
    fail("expected DictionaryExpected")
  }
}

///|
test "PdfDocument draft rejects non-stream form xobjects" {
  let form_name = draft_name_for_test("/Fm1")
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(
    8,
    draft_subtyped_dictionary_for_test(draft_name_for_test("/Form")),
  )
  let page = {
    ..@page.pdf_page_blank(@pdflite.paper_a4),
    resources: draft_resources_for_test([(form_name, PdfIndirect(8))]),
    content: [try! @pdflite.pdf_content_stream_of_ops([Op_Do(form_name)])],
  }
  let result : Result[@pdflite.PdfDocument, Error] = try? draft_document_for_test(
    doc,
    [page],
  ).draft(None, true, [1])
  guard result is Err(@pdflite.PdfError::ParseStreamExpected) else {
    fail("expected ParseStreamExpected")
  }
}

///|
test "PdfDocument draft rejects page ranges outside the document" {
  let result : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_minimum_valid_pdf().draft(
    None,
    false,
    [2],
  )
  guard result
    is Err(
      @pdflite.PdfError::BadPageSpecification(
        "draft: range contains pages not present in pdf"
      )
    ) else {
    fail("expected draft page range validation")
  }
}
