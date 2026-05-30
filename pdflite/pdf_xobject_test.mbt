///|
fn xobject_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn xobject_lookup_for_test(
  doc : @pdflite.PdfDocument,
  object : @pdflite.PdfObject,
  key : String,
) -> @pdflite.PdfObject? {
  doc.lookup_direct(xobject_name_for_test(key), object)
}

///|
fn xobject_page_doc_for_test(
  pages : ArrayView[@page.PdfPage],
) -> @pdflite.PdfDocument {
  let doc = @pdflite.pdf_document_empty()
  let root = try! doc.add_pagetree(pages)
  ignore(try! doc.add_root(root, []))
  doc
}

///|
fn xobject_stream_for_test(
  ops : ArrayView[@pdflite.PdfContentOp],
) -> @pdflite.PdfObject {
  try! @pdflite.pdf_content_stream_of_ops(ops)
}

///|
fn xobject_base_document_for_test() -> @pdflite.PdfDocument {
  let key_font = xobject_name_for_test("/Font")
  let first = {
    ..@page.pdf_page_blank(@pdflite.paper_a4),
    resources: PdfDictionary([
      (
        key_font,
        PdfDictionary([(xobject_name_for_test("/F0"), PdfDictionary([]))]),
      ),
    ]),
    content: [xobject_stream_for_test([Op_q, Op_Q])],
  }
  let second = {
    ..@page.pdf_page_blank(@pdflite.paper_a4),
    content: [xobject_stream_for_test([Op_BT, Op_ET])],
  }
  xobject_page_doc_for_test([first, second])
}

///|
fn xobject_overlay_document_for_test() -> @pdflite.PdfDocument {
  let key_xobject = xobject_name_for_test("/XObject")
  let first = {
    ..@page.pdf_page_blank(@pdflite.paper_a4),
    resources: PdfDictionary([
      (
        key_xobject,
        PdfDictionary([(xobject_name_for_test("/Logo"), PdfDictionary([]))]),
      ),
    ]),
    content: [
      xobject_stream_for_test([
        Op_q,
        Op_Do(xobject_name_for_test("/Logo")),
        Op_Q,
      ]),
    ],
  }
  let second = {
    ..@page.pdf_page_blank(@pdflite.paper_a4),
    content: [xobject_stream_for_test([Op_BT, Op_ET])],
  }
  xobject_page_doc_for_test([first, second])
}

///|
test "PdfDocument stamp_as_xobject embeds first overlay page as form resource" {
  let base = xobject_base_document_for_test()
  let overlay = xobject_overlay_document_for_test()
  let (stamped, name) = try! base.stamp_as_xobject([1], overlay)

  @test.assert_eq(try! stamped.pages_of_pagetree().length(), 2)
  @test.assert_eq(@ascii.decode(name.bytes()) catch { _ => "" }, "/bCPDFXObj")
  let pages = try! stamped.pages_of_pagetree()
  guard xobject_lookup_for_test(stamped, pages[0].resources, "/XObject")
    is Some(xobjects) else {
    fail("expected XObject resource dictionary")
  }
  guard xobjects.lookup_immediate(name) is Some(PdfIndirect(number)) else {
    fail("expected named Form XObject reference")
  }
  guard stamped.lookup_object_or_null(number) is PdfStreamObject(stream) else {
    fail("expected Form XObject stream")
  }
  @test.assert_eq(
    xobject_lookup_for_test(stamped, stream.dictionary, "/Subtype"),
    Some(PdfNameObject(xobject_name_for_test("/Form"))),
  )
  @test.assert_eq(
    xobject_lookup_for_test(stamped, stream.dictionary, "/BBox"),
    Some(@page.pdf_page_rectangle_of_paper(@pdflite.paper_a4)),
  )
  guard xobject_lookup_for_test(stamped, stream.dictionary, "/Resources")
    is Some(form_resources) else {
    fail("expected Form XObject resources")
  }
  guard xobject_lookup_for_test(stamped, form_resources, "/XObject")
    is Some(PdfDictionary(resource_entries)) else {
    fail("expected prefixed overlay resources")
  }
  @test.assert_eq(resource_entries[0].0, xobject_name_for_test("/aLogo"))
  guard stream.data is StreamGot(data) else {
    fail("expected materialized Form XObject stream data")
  }
  @test.assert_eq(
    data,
    try! @pdflite.pdf_content_bytes_of_ops([
      Op_q,
      Op_Do(xobject_name_for_test("/aLogo")),
      Op_Q,
    ]),
  )
  @test.assert_eq(
    xobject_lookup_for_test(stamped, pages[1].resources, "/XObject"),
    None,
  )
}

///|
test "PdfDocument stamp_as_xobject preserves bookmarks and trailer ID" {
  let key_id = xobject_name_for_test("/ID")
  let id = @ascii.encode("stable-file-id")
  let doc = xobject_base_document_for_test()
  doc.set_trailer_dict(
    doc
    .trailer_dict()
    .add_dict_entry(key_id, PdfArray([PdfString(id), PdfString(id)])),
  )
  let page_numbers = try! doc.page_reference_numbers()
  let bookmarked = try! doc.add_bookmarks([
    {
      level: 0,
      text: @ascii.encode("Second"),
      target: DestFit(TargetPageObject(page_numbers[1])),
      is_open: false,
      colour: @bookmark.pdf_bookmark_black,
      flags: 0,
    },
  ])
  let (stamped, _) = try! @pdflite.pdf_stamp_as_xobject(
    bookmarked,
    [1, 2],
    xobject_overlay_document_for_test(),
  )
  let new_page_numbers = try! stamped.page_reference_numbers()

  @test.assert_eq(
    stamped.trailer_dict().lookup_immediate(key_id),
    Some(PdfArray([PdfString(id), PdfString(id)])),
  )
  @test.assert_eq(try! stamped.read_bookmarks(preserve_actions=true), [
    {
      level: 0,
      text: @ascii.encode("Second"),
      target: DestFit(TargetPageObject(new_page_numbers[1])),
      is_open: false,
      colour: @bookmark.pdf_bookmark_black,
      flags: 0,
    },
  ])
  let pages = try! stamped.pages_of_pagetree()
  for page in pages {
    guard xobject_lookup_for_test(stamped, page.resources, "/XObject")
      is Some(xobjects) else {
      fail("expected XObject resource on selected page")
    }
    guard xobjects.lookup_immediate(xobject_name_for_test("/bCPDFXObj"))
      is Some(PdfIndirect(_)) else {
      fail("expected stamped resource name")
    }
  }
}

///|
test "pdf_stamp_as_xobject_string returns source string resource name" {
  let (stamped, name) = try! @pdflite.pdf_stamp_as_xobject_string(
    xobject_base_document_for_test(),
    [1],
    xobject_overlay_document_for_test(),
  )
  @test.assert_eq(name, "/bCPDFXObj")
  let pages = try! stamped.pages_of_pagetree()
  guard xobject_lookup_for_test(stamped, pages[0].resources, "/XObject")
    is Some(xobjects) else {
    fail("expected XObject resource dictionary")
  }
  guard xobjects.lookup_immediate(xobject_name_for_test(name))
    is Some(PdfIndirect(_)) else {
    fail("expected named Form XObject reference")
  }
  @test.assert_eq(
    xobject_lookup_for_test(stamped, pages[1].resources, "/XObject"),
    None,
  )
}

///|
test "PdfDocument stamp_as_xobject rejects empty overlay documents" {
  let result : Result[(@pdflite.PdfDocument, @pdflite.PdfName), Error] = try? xobject_base_document_for_test().stamp_as_xobject(
    [1],
    @pdflite.pdf_document_empty(),
  )

  guard result is Err(_) else { fail("expected empty overlay failure") }
}
