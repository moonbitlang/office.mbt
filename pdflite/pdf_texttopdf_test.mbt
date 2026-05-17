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
  let document = try! @pdflite.pdf_texttopdf_typeset(
    texttopdf_standard_pack_for_test(),
    10.0,
    paper,
    @ascii.encode("Hi"),
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
