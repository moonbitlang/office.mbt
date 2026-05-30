///|
fn page_content_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn page_content_raw_stream_for_test(text : String) -> @pdflite.PdfObject {
  let data = @ascii.encode(text)
  @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (page_content_name_for_test("/Length"), PdfInteger(data.length())),
    ]),
    StreamGot(data),
  )
}

///|
fn page_content_prefix_resources_for_test(
  names : ArrayView[String],
) -> @pdflite.PdfObject {
  let font_entries : Array[(@pdflite.PdfName, @pdflite.PdfObject)] = []
  for name in names {
    font_entries.push((page_content_name_for_test(name), PdfDictionary([])))
  }
  @pdflite.pdf_dictionary([
    (page_content_name_for_test("/Font"), PdfDictionary(font_entries)),
  ])
}

///|
fn page_content_prefix_resource_entry_for_test(
  name : String,
) -> @pdflite.PdfObject {
  PdfDictionary([(page_content_name_for_test(name), PdfDictionary([]))])
}

///|
fn page_content_prefix_full_resources_for_test(
  prefix? : String = "",
) -> @pdflite.PdfObject {
  @pdflite.pdf_dictionary([
    (
      page_content_name_for_test("/Font"),
      page_content_prefix_resource_entry_for_test("/" + prefix + "F0"),
    ),
    (
      page_content_name_for_test("/ExtGState"),
      page_content_prefix_resource_entry_for_test("/" + prefix + "GS1"),
    ),
    (
      page_content_name_for_test("/ColorSpace"),
      page_content_prefix_resource_entry_for_test("/" + prefix + "CS1"),
    ),
    (
      page_content_name_for_test("/Pattern"),
      page_content_prefix_resource_entry_for_test("/" + prefix + "P1"),
    ),
    (
      page_content_name_for_test("/Shading"),
      page_content_prefix_resource_entry_for_test("/" + prefix + "Sh1"),
    ),
    (
      page_content_name_for_test("/XObject"),
      page_content_prefix_resource_entry_for_test("/" + prefix + "Im1"),
    ),
    (
      page_content_name_for_test("/Properties"),
      page_content_prefix_resource_entry_for_test("/" + prefix + "Prop1"),
    ),
  ])
}

///|
fn page_content_prefix_content_ops_for_test(
  prefix? : String = "",
) -> Array[@content.PdfContentOp] {
  [
    Op_Tf(page_content_name_for_test("/" + prefix + "F0"), 12.0),
    Op_gs(page_content_name_for_test("/" + prefix + "GS1")),
    Op_CS(page_content_name_for_test("/DeviceRGB")),
    Op_cs(page_content_name_for_test("/" + prefix + "CS1")),
    Op_SCNName(page_content_name_for_test("/" + prefix + "P1"), [0.2]),
    Op_scnName(page_content_name_for_test("/" + prefix + "P1"), [0.3]),
    Op_sh(page_content_name_for_test("/" + prefix + "Sh1")),
    Op_Do(page_content_name_for_test("/" + prefix + "Im1")),
    Op_DP(
      page_content_name_for_test("/Span"),
      PdfNameObject(page_content_name_for_test("/" + prefix + "Prop1")),
    ),
    Op_BDC(
      page_content_name_for_test("/Span"),
      PdfNameObject(page_content_name_for_test("/" + prefix + "Prop1")),
    ),
    Op_InlineImage(
      PdfDictionary([
        (
          page_content_name_for_test("/CS"),
          PdfNameObject(page_content_name_for_test("/" + prefix + "CS1")),
        ),
        (page_content_name_for_test("/W"), PdfInteger(1)),
      ]),
      None,
      @ascii.encode("x"),
    ),
  ]
}

///|
fn page_content_renumber_content_ops_for_test() -> Array[@content.PdfContentOp] {
  [
    Op_Tf(page_content_name_for_test("/r1"), 12.0),
    Op_gs(page_content_name_for_test("/r2")),
    Op_CS(page_content_name_for_test("/DeviceRGB")),
    Op_cs(page_content_name_for_test("/r3")),
    Op_SCNName(page_content_name_for_test("/r4"), [0.2]),
    Op_scnName(page_content_name_for_test("/r4"), [0.3]),
    Op_sh(page_content_name_for_test("/r5")),
    Op_Do(page_content_name_for_test("/r6")),
    Op_DP(
      page_content_name_for_test("/Span"),
      PdfNameObject(page_content_name_for_test("/r7")),
    ),
    Op_BDC(
      page_content_name_for_test("/Span"),
      PdfNameObject(page_content_name_for_test("/r7")),
    ),
    Op_InlineImage(
      PdfDictionary([
        (
          page_content_name_for_test("/CS"),
          PdfNameObject(page_content_name_for_test("/r3")),
        ),
        (page_content_name_for_test("/W"), PdfInteger(1)),
      ]),
      None,
      @ascii.encode("x"),
    ),
  ]
}

///|
fn page_content_resource_value_for_test(
  resources : @pdflite.PdfObject,
  key : String,
) -> @pdflite.PdfObject? {
  resources.lookup_immediate(page_content_name_for_test(key))
}

///|
test "PdfDocument add_prefix renames resources and content references" {
  let doc = @pdflite.pdf_document_empty()
  let page = {
    ..@page.pdf_page_blank(@geometry.paper_a4),
    resources: page_content_prefix_full_resources_for_test(),
    content: [
      try! @pdflite.pdf_content_stream_of_ops(
        page_content_prefix_content_ops_for_test(),
      ),
    ],
  }
  let page_root = try! doc.add_pagetree([page])
  ignore(try! doc.add_root(page_root, []))
  try! doc.add_prefix("p")
  let pages = try! doc.pages_of_pagetree()
  @test.assert_eq(
    pages[0].resources,
    page_content_prefix_full_resources_for_test(prefix="p"),
  )
  @test.assert_eq(
    try! doc.parse_content_ops(pages[0].content),
    page_content_prefix_content_ops_for_test(prefix="p"),
  )
}

///|
test "PdfDocument add_prefix rewrites shared content streams once" {
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(
    9,
    try! @pdflite.pdf_content_stream_of_ops([
      Op_Tf(page_content_name_for_test("/F0"), 12.0),
    ]),
  )
  let page = {
    ..@page.pdf_page_blank(@geometry.paper_a4),
    resources: page_content_prefix_resources_for_test(["/F0"]),
    content: [PdfIndirect(9)],
  }
  let page_root = try! doc.add_pagetree([page, page])
  ignore(try! doc.add_root(page_root, []))
  try! doc.add_prefix("p")
  @test.assert_eq(try! doc.parse_content_ops([PdfIndirect(9)]), [
    Op_Tf(page_content_name_for_test("/pF0"), 12.0),
  ])
}

///|
test "PdfDocument merge_content_streams combines page content arrays" {
  let key_type = page_content_name_for_test("/Type")
  let key_contents = page_content_name_for_test("/Contents")
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(
    1,
    @pdflite.pdf_dictionary([
      (key_type, PdfNameObject(page_content_name_for_test("/Page"))),
      (key_contents, PdfArray([PdfIndirect(2), PdfIndirect(3)])),
    ]),
  )
  doc.add_object_given_number(2, page_content_raw_stream_for_test("BT"))
  doc.add_object_given_number(3, page_content_raw_stream_for_test("ET"))
  try! doc.merge_content_streams()
  guard doc.lookup_object_or_null(1).lookup_immediate(key_contents)
    is Some(PdfIndirect(merged)) else {
    fail("expected merged content stream")
  }
  @test.assert_eq(merged == 2 || merged == 3, false)
  @test.assert_eq(try! doc.parse_content_ops([PdfIndirect(merged)]), [
    Op_BT,
    Op_ET,
  ])
}

///|
test "PdfDocument merge_content_streams leaves single content arrays unchanged" {
  let key_type = page_content_name_for_test("/Type")
  let key_contents = page_content_name_for_test("/Contents")
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(
    1,
    @pdflite.pdf_dictionary([
      (key_type, PdfNameObject(page_content_name_for_test("/Page"))),
      (key_contents, PdfArray([PdfIndirect(2)])),
    ]),
  )
  doc.add_object_given_number(2, page_content_raw_stream_for_test("BT ET"))
  try! doc.merge_content_streams()
  @test.assert_eq(
    doc.lookup_object_or_null(1).lookup_immediate(key_contents),
    Some(PdfArray([PdfIndirect(2)])),
  )
}

///|
test "PdfDocument merge_content_streams rejects non-stream content arrays" {
  let key_type = page_content_name_for_test("/Type")
  let key_contents = page_content_name_for_test("/Contents")
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(
    1,
    @pdflite.pdf_dictionary([
      (key_type, PdfNameObject(page_content_name_for_test("/Page"))),
      (key_contents, PdfArray([PdfInteger(1), PdfIndirect(2)])),
    ]),
  )
  doc.add_object_given_number(2, page_content_raw_stream_for_test("BT ET"))
  let result : Result[Unit, Error] = try? doc.merge_content_streams()
  guard result is Err(@pdflite.PdfError::ParseStreamExpected) else {
    fail("expected @pdflite.PdfError::ParseStreamExpected")
  }
}

///|
test "PdfDocument add_prefix keeps parseable content arrays split" {
  let key_type = page_content_name_for_test("/Type")
  let key_resources = page_content_name_for_test("/Resources")
  let key_contents = page_content_name_for_test("/Contents")
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(
    1,
    @pdflite.pdf_dictionary([
      (key_type, PdfNameObject(page_content_name_for_test("/Page"))),
      (key_resources, page_content_prefix_resources_for_test(["/F0"])),
      (key_contents, PdfArray([PdfIndirect(2), PdfIndirect(3)])),
    ]),
  )
  doc.add_object_given_number(2, page_content_raw_stream_for_test("BT"))
  doc.add_object_given_number(3, page_content_raw_stream_for_test("ET"))
  try! doc.add_prefix("p")
  let page = doc.lookup_object_or_null(1)
  @test.assert_eq(
    page.lookup_immediate(key_contents),
    Some(PdfArray([PdfIndirect(2), PdfIndirect(3)])),
  )
  guard page.lookup_immediate(key_resources) is Some(resources) else {
    fail("expected prefixed resources")
  }
  @test.assert_eq(
    page_content_resource_value_for_test(resources, "/Font"),
    Some(page_content_prefix_resource_entry_for_test("/pF0")),
  )
}

///|
test "PdfDocument add_prefix merges split content arrays before rewriting" {
  let key_type = page_content_name_for_test("/Type")
  let key_resources = page_content_name_for_test("/Resources")
  let key_contents = page_content_name_for_test("/Contents")
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(
    1,
    @pdflite.pdf_dictionary([
      (key_type, PdfNameObject(page_content_name_for_test("/Page"))),
      (key_resources, page_content_prefix_resources_for_test(["/F0"])),
      (key_contents, PdfArray([PdfIndirect(2), PdfIndirect(3)])),
    ]),
  )
  doc.add_object_given_number(2, page_content_raw_stream_for_test("BT /F0"))
  doc.add_object_given_number(3, page_content_raw_stream_for_test("12 Tf ET"))
  try! doc.add_prefix("p")
  let page = doc.lookup_object_or_null(1)
  guard page.lookup_immediate(key_contents) is Some(PdfIndirect(merged)) else {
    fail("expected merged content stream")
  }
  guard page.lookup_immediate(key_resources) is Some(resources) else {
    fail("expected prefixed resources")
  }
  @test.assert_eq(
    page_content_resource_value_for_test(resources, "/Font"),
    Some(page_content_prefix_resource_entry_for_test("/pF0")),
  )
  @test.assert_eq(try! doc.parse_content_ops([PdfIndirect(merged)]), [
    Op_BT,
    Op_Tf(page_content_name_for_test("/pF0"), 12.0),
    Op_ET,
  ])
}

///|
test "PdfDocument renumber_pages gives duplicate page resources distinct names" {
  let doc = @pdflite.pdf_document_empty()
  let page = {
    ..@page.pdf_page_blank(@geometry.paper_a4),
    resources: page_content_prefix_resources_for_test(["/F0"]),
    content: [
      try! @pdflite.pdf_content_stream_of_ops([
        Op_Tf(page_content_name_for_test("/F0"), 12.0),
      ]),
    ],
  }
  let pages = try! doc.renumber_pages([page, page])
  @test.assert_eq(pages.length(), 2)
  @test.assert_eq(
    page_content_resource_value_for_test(pages[0].resources, "/Font"),
    Some(page_content_prefix_resource_entry_for_test("/r1")),
  )
  @test.assert_eq(
    page_content_resource_value_for_test(pages[1].resources, "/Font"),
    Some(page_content_prefix_resource_entry_for_test("/r2")),
  )
  @test.assert_eq(
    page_content_resource_value_for_test(pages[0].resources, "/ColorSpace"),
    Some(PdfDictionary([])),
  )
  @test.assert_eq(try! doc.parse_content_ops(pages[0].content), [
    Op_Tf(page_content_name_for_test("/r1"), 12.0),
  ])
  @test.assert_eq(try! doc.parse_content_ops(pages[1].content), [
    Op_Tf(page_content_name_for_test("/r2"), 12.0),
  ])
}

///|
test "PdfDocument renumber_pages rewrites resource-backed content operators" {
  let doc = @pdflite.pdf_document_empty()
  let page = {
    ..@page.pdf_page_blank(@geometry.paper_a4),
    resources: page_content_prefix_full_resources_for_test(),
    content: [
      try! @pdflite.pdf_content_stream_of_ops(
        page_content_prefix_content_ops_for_test(),
      ),
    ],
  }
  let pages = try! doc.renumber_pages([page])
  @test.assert_eq(pages.length(), 1)
  @test.assert_eq(
    page_content_resource_value_for_test(pages[0].resources, "/Font"),
    Some(page_content_prefix_resource_entry_for_test("/r1")),
  )
  @test.assert_eq(
    page_content_resource_value_for_test(pages[0].resources, "/ExtGState"),
    Some(page_content_prefix_resource_entry_for_test("/r2")),
  )
  @test.assert_eq(
    page_content_resource_value_for_test(pages[0].resources, "/ColorSpace"),
    Some(page_content_prefix_resource_entry_for_test("/r3")),
  )
  @test.assert_eq(
    page_content_resource_value_for_test(pages[0].resources, "/Pattern"),
    Some(page_content_prefix_resource_entry_for_test("/r4")),
  )
  @test.assert_eq(
    page_content_resource_value_for_test(pages[0].resources, "/Shading"),
    Some(page_content_prefix_resource_entry_for_test("/r5")),
  )
  @test.assert_eq(
    page_content_resource_value_for_test(pages[0].resources, "/XObject"),
    Some(page_content_prefix_resource_entry_for_test("/r6")),
  )
  @test.assert_eq(
    page_content_resource_value_for_test(pages[0].resources, "/Properties"),
    Some(page_content_prefix_resource_entry_for_test("/r7")),
  )
  @test.assert_eq(
    try! doc.parse_content_ops(pages[0].content),
    page_content_renumber_content_ops_for_test(),
  )
}
