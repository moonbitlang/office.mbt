///|
fn texttopdf_standard_font_for_test() -> @pdflite.PdfFont {
  PdfFontStandard({ font: PdfHelvetica, encoding: PdfWinAnsiEncoding })
}

///|
fn texttopdf_bold_font_for_test() -> @pdflite.PdfFont {
  PdfFontStandard({ font: PdfHelveticaBold, encoding: PdfWinAnsiEncoding })
}

///|
fn texttopdf_standard_pack_for_test() -> @pdflite.PdfFontPack {
  try! @pdflite.pdf_fontpack_of_standard_font(
    texttopdf_standard_font_for_test(),
  )
}

///|
fn texttopdf_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn texttopdf_lookup_for_test(
  object : @pdflite.PdfObject,
  key : String,
) -> @pdflite.PdfObject raise {
  match object.lookup_immediate(texttopdf_name_for_test(key)) {
    Some(value) => value
    None => {
      fail("missing dictionary key " + key)
      PdfNull
    }
  }
}

///|
fn texttopdf_lookup_indirect_object_for_test(
  document : @pdflite.PdfDocument,
  object : @pdflite.PdfObject,
  key : String,
) -> (Int, @pdflite.PdfObject) raise {
  let reference = try! texttopdf_lookup_for_test(object, key)
  guard reference is PdfIndirect(number) else {
    fail("expected dictionary key " + key + " to be indirect")
    (0, PdfNull)
  }
  (number, document.lookup_object_or_null(number))
}

///|
fn texttopdf_page_ops_for_test(
  document : @pdflite.PdfDocument,
  page : @pdflite.PdfPage,
) -> Array[@pdflite.PdfContentOp] raise {
  document.parse_content_ops(page.content)
}

///|
test "pdf_texttopdf_of_utf8_with_newlines maps UTF8 to cpdftype text" {
  let font = texttopdf_standard_font_for_test()
  @test.assert_eq(
    try! @pdflite.pdf_texttopdf_of_utf8_with_newlines(
      texttopdf_standard_pack_for_test(),
      12.0,
      @ascii.encode("A\nB\rC"),
    ),
    [
      PdfTypeFont("0", font, 12.0),
      PdfTypeText(@ascii.encode("A")),
      PdfTypeNewLine,
      PdfTypeText(@ascii.encode("BC")),
    ],
  )
}

///|
test "pdf_texttopdf_of_utf8_with_newlines skips unmapped glyphs" {
  let font = texttopdf_standard_font_for_test()
  @test.assert_eq(
    try! @pdflite.pdf_texttopdf_of_utf8_with_newlines(
      texttopdf_standard_pack_for_test(),
      9.0,
      @utf8.encode("A☃B"),
    ),
    [PdfTypeFont("0", font, 9.0), PdfTypeText(@ascii.encode("AB"))],
  )
}

///|
test "pdf_texttopdf_of_utf8_with_newlines switches font runs" {
  let regular = texttopdf_standard_font_for_test()
  let bold = texttopdf_bold_font_for_test()
  let pack : @pdflite.PdfFontPack = {
    fonts: [regular, bold],
    entries: [
      { codepoint: 65, font_index: 0, charcode: 65 },
      { codepoint: 66, font_index: 1, charcode: 66 },
      { codepoint: 67, font_index: 1, charcode: 67 },
      { codepoint: 68, font_index: 0, charcode: 68 },
    ],
  }
  @test.assert_eq(
    try! @pdflite.pdf_texttopdf_of_utf8_with_newlines(
      pack,
      10.0,
      @ascii.encode("ABCD"),
    ),
    [
      PdfTypeFont("0", regular, 10.0),
      PdfTypeText(@ascii.encode("A")),
      PdfTypeFont("1", bold, 10.0),
      PdfTypeText(@ascii.encode("BC")),
      PdfTypeFont("0", regular, 10.0),
      PdfTypeText(@ascii.encode("D")),
    ],
  )
}

///|
test "pdf_texttopdf_of_utf8_with_newlines rejects invalid charcodes" {
  let font = texttopdf_standard_font_for_test()
  let pack : @pdflite.PdfFontPack = {
    fonts: [font],
    entries: [{ codepoint: 65, font_index: 0, charcode: 300 }],
  }
  let result : Result[Array[@pdflite.PdfTypeElement], Error] = try? @pdflite.pdf_texttopdf_of_utf8_with_newlines(
    pack,
    10.0,
    @ascii.encode("A"),
  )
  guard result is Err(@pdflite.PdfError::BadText) else {
    fail("expected invalid charcode to raise BadText")
  }
}

///|
test "pdf_texttopdf_tag_paragraphs wraps blank-line paragraphs" {
  @test.assert_eq(@pdflite.pdf_texttopdf_tag_paragraphs([]), [
    PdfTypeTag("P", 0),
    PdfTypeEndTag,
  ])
  @test.assert_eq(
    @pdflite.pdf_texttopdf_tag_paragraphs([
      PdfTypeText(@ascii.encode("A")),
      PdfTypeNewLine,
      PdfTypeNewLine,
      PdfTypeText(@ascii.encode("B")),
    ]),
    [
      PdfTypeTag("P", 0),
      PdfTypeText(@ascii.encode("A")),
      PdfTypeEndTag,
      PdfTypeNewLine,
      PdfTypeNewLine,
      PdfTypeTag("P", 0),
      PdfTypeText(@ascii.encode("B")),
      PdfTypeEndTag,
    ],
  )
}

///|
test "pdf_texttopdf_typeset creates a standalone text document" {
  let paper = @pdflite.paper_size_make(PdfPoint, 100.0, 100.0)
  let fontpack = texttopdf_standard_pack_for_test()
  let text = @ascii.encode("Hi")
  let document = try! @pdflite.pdf_texttopdf_typeset(
    fontpack, 10.0, paper, text,
  )
  let source_order = try! @pdflite.pdf_texttopdf_typeset_cpdf_order(
    false, paper, fontpack, 10.0, text,
  )
  @test.assert_eq(document.root() > 0, true)
  let catalog = try! document.catalog()
  @test.assert_eq(
    try! texttopdf_lookup_for_test(catalog, "/Type"),
    PdfNameObject(texttopdf_name_for_test("/Catalog")),
  )
  let pages_ref = try! texttopdf_lookup_for_test(catalog, "/Pages")
  guard pages_ref is PdfIndirect(_) else {
    fail("expected catalog /Pages reference")
  }
  let pages = try! document.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  let ops = try! texttopdf_page_ops_for_test(document, pages[0])
  let mut found_text = false
  let mut font_ops = 0
  for op in ops {
    match op {
      Op_Tf(_, 10.0) => font_ops += 1
      Op_Tj(bytes) if bytes == @ascii.encode("Hi") => found_text = true
      _ => ()
    }
  }
  @test.assert_eq(font_ops >= 1, true)
  @test.assert_eq(found_text, true)
  let source_pages = try! source_order.pages_of_pagetree()
  @test.assert_eq(source_pages.length(), pages.length())
  @test.assert_eq(
    try! texttopdf_page_ops_for_test(source_order, source_pages[0]),
    ops,
  )
}

///|
test "pdf_texttopdf_typeset creates a blank document for empty text" {
  let paper = @pdflite.paper_size_make(PdfPoint, 100.0, 100.0)
  let document = try! @pdflite.pdf_texttopdf_typeset(
    texttopdf_standard_pack_for_test(),
    10.0,
    paper,
    @ascii.encode(""),
  )
  let pages = try! document.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  @test.assert_eq(pages[0].content, [])
  @test.assert_eq(
    pages[0].resources,
    PdfDictionary([(texttopdf_name_for_test("/Font"), PdfDictionary([]))]),
  )
}

///|
test "pdf_texttopdf_typeset can build paragraph structure tree" {
  let paper = @pdflite.paper_size_make(PdfPoint, 120.0, 120.0)
  let document = try! @pdflite.pdf_texttopdf_typeset(
    texttopdf_standard_pack_for_test(),
    10.0,
    paper,
    @ascii.encode("A\n\nB"),
    process_struct_tree=true,
  )
  let pages = try! document.pages_of_pagetree()
  let page_refs = try! document.page_reference_numbers()
  @test.assert_eq(pages.length(), 1)
  @test.assert_eq(page_refs.length(), 1)
  @test.assert_eq(
    try! texttopdf_lookup_for_test(pages[0].rest, "/StructParents"),
    PdfInteger(0),
  )
  let catalog = try! document.catalog()
  let struct_root_ref = try! texttopdf_lookup_for_test(
    catalog, "/StructTreeRoot",
  )
  guard struct_root_ref is PdfIndirect(struct_root_number) else {
    fail("expected StructTreeRoot reference")
  }
  let struct_root = document.lookup_object_or_null(struct_root_number)
  let root_k = try! texttopdf_lookup_for_test(struct_root, "/K")
  guard root_k is PdfArray([PdfIndirect(first_para), PdfIndirect(second_para)]) else {
    fail("expected two paragraph structure elements")
  }
  let parent_tree_ref = try! texttopdf_lookup_for_test(
    struct_root, "/ParentTree",
  )
  guard parent_tree_ref is PdfIndirect(parent_tree_number) else {
    fail("expected ParentTree reference")
  }
  let parent_entries = document.read_number_tree(
    PdfIndirect(parent_tree_number),
  )
  @test.assert_eq(parent_entries.length(), 1)
  @test.assert_eq(parent_entries[0].0, 0)
  @test.assert_eq(
    parent_entries[0].1,
    PdfArray([PdfIndirect(first_para), PdfIndirect(second_para)]),
  )
  let first = document.lookup_object_or_null(first_para)
  @test.assert_eq(
    try! texttopdf_lookup_for_test(first, "/S"),
    PdfNameObject(texttopdf_name_for_test("/P")),
  )
  @test.assert_eq(
    try! texttopdf_lookup_for_test(first, "/P"),
    PdfIndirect(struct_root_number),
  )
  let first_k = try! texttopdf_lookup_for_test(first, "/K")
  guard first_k is PdfArray([first_mcr]) else {
    fail("expected first paragraph MCR")
  }
  @test.assert_eq(
    try! texttopdf_lookup_for_test(first_mcr, "/Type"),
    PdfNameObject(texttopdf_name_for_test("/MCR")),
  )
  @test.assert_eq(
    try! texttopdf_lookup_for_test(first_mcr, "/Pg"),
    PdfIndirect(page_refs[0]),
  )
  @test.assert_eq(
    try! texttopdf_lookup_for_test(first_mcr, "/MCID"),
    PdfInteger(0),
  )
  let ops = try! texttopdf_page_ops_for_test(document, pages[0])
  let mut marked_paragraphs = 0
  for op in ops {
    match op {
      Op_BDC(tag, _) if tag == texttopdf_name_for_test("/P") =>
        marked_paragraphs += 1
      _ => ()
    }
  }
  @test.assert_eq(marked_paragraphs, 2)
}

///|
test "pdf_ua_subformat_of_string parses CamlPDF PDF/UA names" {
  @test.assert_eq(try! @pdflite.pdf_ua_subformat_of_string("PDF/UA-1"), PdfUA1)
  @test.assert_eq(try! @pdflite.pdf_ua_subformat_of_string("PDF/UA-2"), PdfUA2)
  @test.assert_eq(try! @pdflite.pdf_subformat_of_string("PDF/UA-1"), PdfUA1)
  @test.assert_eq(try! @pdflite.pdf_subformat_of_string("PDF/UA-2"), PdfUA2)
  let unknown : Result[@pdflite.PdfUASubformat, Error] = try? @pdflite.pdf_ua_subformat_of_string(
    "PDF/A-1",
  )
  guard unknown is Err(@pdflite.PdfError::BadText) else {
    fail("expected unknown PDF/UA subformat to raise BadText")
  }
}

///|
test "pdf_texttopdf_typeset requires title when subformat is requested" {
  let paper = @pdflite.paper_size_make(PdfPoint, 100.0, 100.0)
  let result : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_texttopdf_typeset(
    texttopdf_standard_pack_for_test(),
    10.0,
    paper,
    @ascii.encode("Hi"),
    subformat=Some(PdfUA1),
  )
  guard result is Err(@pdflite.PdfError::TitleExpected) else {
    fail("expected PDF/UA text-to-PDF without title to raise TitleExpected")
  }
}

///|
test "pdf_texttopdf_typeset PDF/UA-1 writes accessibility catalog metadata" {
  let paper = @pdflite.paper_size_make(PdfPoint, 120.0, 120.0)
  let document = try! @pdflite.pdf_texttopdf_typeset(
    texttopdf_standard_pack_for_test(),
    10.0,
    paper,
    @ascii.encode("Hi"),
    subformat=Some(PdfUA1),
    title=Some("Sample title"),
  )
  @test.assert_eq(document.version(), (1, 7))
  let pages = try! document.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  @test.assert_eq(
    try! texttopdf_lookup_for_test(pages[0].rest, "/StructParents"),
    PdfInteger(0),
  )
  let (_, info) = try! texttopdf_lookup_indirect_object_for_test(
    document,
    document.trailer_dict(),
    "/Info",
  )
  @test.assert_eq(
    try! texttopdf_lookup_for_test(info, "/Title"),
    PdfString(@utf8.encode("Sample title")),
  )
  let catalog = try! document.catalog()
  let mark_info = try! texttopdf_lookup_for_test(catalog, "/MarkInfo")
  @test.assert_eq(
    try! texttopdf_lookup_for_test(mark_info, "/Marked"),
    PdfBoolean(true),
  )
  @test.assert_eq(
    try! texttopdf_lookup_for_test(catalog, "/Lang"),
    PdfString(@ascii.encode("en-US")),
  )
  let viewer_preferences = try! texttopdf_lookup_for_test(
    catalog, "/ViewerPreferences",
  )
  @test.assert_eq(
    try! texttopdf_lookup_for_test(viewer_preferences, "/DisplayDocTitle"),
    PdfBoolean(true),
  )
  let (_, struct_root) = try! texttopdf_lookup_indirect_object_for_test(
    document, catalog, "/StructTreeRoot",
  )
  @test.assert_eq(
    try! texttopdf_lookup_for_test(struct_root, "/Type"),
    PdfNameObject(texttopdf_name_for_test("/StructTreeRoot")),
  )
  guard (try! texttopdf_lookup_for_test(struct_root, "/K"))
    is PdfArray([PdfIndirect(_)]) else {
    fail("expected PDF/UA-1 root /K to contain paragraph nodes directly")
  }
}

///|
test "pdf_texttopdf_typeset PDF/UA-2 wraps paragraphs under document namespace" {
  let paper = @pdflite.paper_size_make(PdfPoint, 120.0, 120.0)
  let document = try! @pdflite.pdf_texttopdf_typeset(
    texttopdf_standard_pack_for_test(),
    10.0,
    paper,
    @ascii.encode("A\n\nB"),
    subformat=Some(PdfUA2),
    title=Some("UA2 title"),
  )
  @test.assert_eq(document.version(), (2, 0))
  let catalog = try! document.catalog()
  let (struct_root_number, struct_root) = try! texttopdf_lookup_indirect_object_for_test(
    document, catalog, "/StructTreeRoot",
  )
  let namespace_objects = try! texttopdf_lookup_for_test(
    struct_root, "/Namespaces",
  )
  guard namespace_objects is PdfArray([PdfIndirect(namespace_number)]) else {
    fail("expected PDF/UA-2 namespace array")
  }
  let namespace_object = document.lookup_object_or_null(namespace_number)
  @test.assert_eq(
    try! texttopdf_lookup_for_test(namespace_object, "/NS"),
    PdfString(@ascii.encode("http://iso.org/pdf2/ssn")),
  )
  let root_k = try! texttopdf_lookup_for_test(struct_root, "/K")
  guard root_k is PdfIndirect(document_number) else {
    fail("expected PDF/UA-2 root /K to reference document element")
  }
  let document_node = document.lookup_object_or_null(document_number)
  @test.assert_eq(
    try! texttopdf_lookup_for_test(document_node, "/S"),
    PdfNameObject(texttopdf_name_for_test("/Document")),
  )
  @test.assert_eq(
    try! texttopdf_lookup_for_test(document_node, "/P"),
    PdfIndirect(struct_root_number),
  )
  @test.assert_eq(
    try! texttopdf_lookup_for_test(document_node, "/NS"),
    PdfIndirect(namespace_number),
  )
  guard (try! texttopdf_lookup_for_test(document_node, "/K"))
    is PdfArray([PdfIndirect(first_para), PdfIndirect(second_para)]) else {
    fail("expected PDF/UA-2 document element to contain two paragraphs")
  }
  for paragraph_number in [first_para, second_para] {
    let paragraph = document.lookup_object_or_null(paragraph_number)
    @test.assert_eq(
      try! texttopdf_lookup_for_test(paragraph, "/P"),
      PdfIndirect(document_number),
    )
  }
}
