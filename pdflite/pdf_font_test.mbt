///|
fn font_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn font_descriptor_for_test() -> @pdflite.PdfObject {
  PdfDictionary([
    (font_name_for_test("/FontFile"), PdfIndirect(4)),
    (font_name_for_test("/FontFile2"), PdfIndirect(5)),
    (font_name_for_test("/FontFile3"), PdfIndirect(6)),
    (font_name_for_test("/Flags"), PdfInteger(32)),
  ])
}

///|
fn font_document_for_test() -> @pdflite.PdfDocument {
  let key_type = font_name_for_test("/Type")
  let key_font = font_name_for_test("/Font")
  let key_font_descriptor = font_name_for_test("/FontDescriptor")
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(
    2,
    PdfDictionary([
      (key_type, PdfNameObject(key_font)),
      (key_font_descriptor, PdfIndirect(3)),
    ]),
  )
  doc.add_object_given_number(3, font_descriptor_for_test())
  doc.add_object_given_number(4, PdfString(@ascii.encode("font one")))
  doc.add_object_given_number(5, PdfString(@ascii.encode("font two")))
  doc.add_object_given_number(6, PdfString(@ascii.encode("font three")))
  doc.add_object_given_number(
    7,
    PdfDictionary([(key_font_descriptor, font_descriptor_for_test())]),
  )
  doc
}

///|
fn font_json_int_for_test(value : Int) -> Json {
  Json::number(value.to_double(), repr=value.to_string())
}

///|
fn font_resource_dictionary_for_test(
  entries : ArrayView[(String, @pdflite.PdfObject)],
) -> @pdflite.PdfObject {
  PdfDictionary(
    [
      for entry in entries => (font_name_for_test(entry.0), entry.1)
    ],
  )
}

///|
fn font_required_lookup_for_test(
  document : @pdflite.PdfDocument,
  key : String,
  object : @pdflite.PdfObject,
) -> @pdflite.PdfObject raise {
  match document.lookup_direct(font_name_for_test(key), object) {
    Some(value) => value
    None => fail("missing key " + key)
  }
}

///|
fn font_font_object_for_test(
  subtype : String,
  basefont : String,
  encoding : String?,
) -> @pdflite.PdfObject {
  let entries : Array[(@pdflite.PdfName, @pdflite.PdfObject)] = [
    (font_name_for_test("/Type"), PdfNameObject(font_name_for_test("/Font"))),
    (font_name_for_test("/Subtype"), PdfNameObject(font_name_for_test(subtype))),
    (
      font_name_for_test("/BaseFont"),
      PdfNameObject(font_name_for_test(basefont)),
    ),
  ]
  match encoding {
    Some(value) =>
      entries.push(
        (
          font_name_for_test("/Encoding"),
          PdfNameObject(font_name_for_test(value)),
        ),
      )
    None => ()
  }
  PdfDictionary(entries)
}

///|
fn font_font_object_with_descriptor_for_test(
  subtype : String,
  basefont : String,
  encoding : String?,
  descriptor : @pdflite.PdfObject,
) -> @pdflite.PdfObject {
  guard font_font_object_for_test(subtype, basefont, encoding)
    is PdfDictionary(entries) else {
    return PdfDictionary([])
  }
  entries.push((font_name_for_test("/FontDescriptor"), descriptor))
  PdfDictionary(entries)
}

///|
fn font_composite_font_for_test(
  descendants : ArrayView[@pdflite.PdfObject],
) -> @pdflite.PdfObject {
  guard font_font_object_for_test("/Type0", "/CompositeFont", None)
    is PdfDictionary(entries) else {
    return PdfDictionary([])
  }
  entries.push(
    (
      font_name_for_test("/DescendantFonts"),
      PdfArray([ for descendant in descendants => descendant ]),
    ),
  )
  PdfDictionary(entries)
}

///|
fn font_descriptor_without_files_for_test() -> @pdflite.PdfObject {
  PdfDictionary([(font_name_for_test("/Flags"), PdfInteger(4))])
}

///|
fn font_descriptor_with_file_for_test(
  key : String,
  number : Int,
) -> @pdflite.PdfObject {
  PdfDictionary([
    (font_name_for_test(key), PdfIndirect(number)),
    (font_name_for_test("/Flags"), PdfInteger(32)),
  ])
}

///|
fn font_file_stream_for_test(data : String) -> @pdflite.PdfObject {
  let bytes = @ascii.encode(data)
  @pdflite.pdf_stream(
    PdfDictionary([(font_name_for_test("/Length"), PdfInteger(bytes.length()))]),
    StreamGot(bytes),
  )
}

///|
fn font_minimal_font_object_for_test() -> @pdflite.PdfObject {
  PdfDictionary([
    (font_name_for_test("/Type"), PdfNameObject(font_name_for_test("/Font"))),
  ])
}

///|
fn font_form_xobject_for_test(
  resources : @pdflite.PdfObject,
) -> @pdflite.PdfObject {
  @pdflite.pdf_stream(
    PdfDictionary([
      (
        font_name_for_test("/Subtype"),
        PdfNameObject(font_name_for_test("/Form")),
      ),
      (font_name_for_test("/Resources"), resources),
      (font_name_for_test("/Length"), PdfInteger(0)),
    ]),
    StreamGot([]),
  )
}

///|
fn font_listing_document_for_test() -> @pdflite.PdfDocument {
  let key_font = font_name_for_test("/Font")
  let key_xobject = font_name_for_test("/XObject")
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(
    20,
    font_font_object_for_test("/Type1", "/Helvetica", Some("/WinAnsiEncoding")),
  )
  doc.add_object_given_number(
    21,
    font_font_object_for_test("/TrueType", "/SubsetFont", None),
  )
  doc.add_object_given_number(22, font_minimal_font_object_for_test())
  doc.add_object_given_number(
    24,
    font_form_xobject_for_test(
      PdfDictionary([
        (
          key_font,
          font_resource_dictionary_for_test([("/F3", PdfIndirect(22))]),
        ),
      ]),
    ),
  )
  doc.add_object_given_number(
    23,
    font_form_xobject_for_test(
      PdfDictionary([
        (
          key_font,
          font_resource_dictionary_for_test([("/F2", PdfIndirect(21))]),
        ),
        (
          key_xobject,
          font_resource_dictionary_for_test([("/FmNested", PdfIndirect(24))]),
        ),
      ]),
    ),
  )
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    resources: PdfDictionary([
      (key_font, font_resource_dictionary_for_test([("/F1", PdfIndirect(20))])),
      (
        key_xobject,
        font_resource_dictionary_for_test([
          ("/Fm1", PdfIndirect(23)),
          ("/FmAgain", PdfIndirect(23)),
        ]),
      ),
    ]),
  }
  let page_root = try! doc.add_pagetree([
    page,
    @pdflite.pdf_page_blank(@pdflite.paper_a4),
  ])
  ignore(try! doc.add_root(page_root, []))
  doc
}

///|
fn font_missing_document_for_test() -> @pdflite.PdfDocument {
  let key_font = font_name_for_test("/Font")
  let key_xobject = font_name_for_test("/XObject")
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(4, PdfString(@ascii.encode("font one")))
  doc.add_object_given_number(5, PdfString(@ascii.encode("font two")))
  doc.add_object_given_number(6, PdfString(@ascii.encode("font three")))
  doc.add_object_given_number(
    40,
    font_font_object_for_test("/Type1", "/MissingOne", None),
  )
  doc.add_object_given_number(
    41,
    font_font_object_for_test("/Type3", "/InlineType3", None),
  )
  doc.add_object_given_number(
    42,
    font_font_object_with_descriptor_for_test(
      "/Type1",
      "/EmbeddedOne",
      None,
      PdfIndirect(48),
    ),
  )
  doc.add_object_given_number(
    43,
    font_composite_font_for_test([PdfIndirect(45), PdfIndirect(46)]),
  )
  doc.add_object_given_number(
    44,
    font_font_object_with_descriptor_for_test(
      "/Type1",
      "/DescriptorMissing",
      Some("/MacRomanEncoding"),
      PdfIndirect(49),
    ),
  )
  doc.add_object_given_number(
    45,
    font_font_object_for_test("/CIDFontType2", "/CIDMissing", None),
  )
  doc.add_object_given_number(
    46,
    font_font_object_with_descriptor_for_test(
      "/CIDFontType2",
      "/CIDEmbedded",
      None,
      PdfIndirect(48),
    ),
  )
  doc.add_object_given_number(
    47,
    font_font_object_for_test("/Type1", "/SecondPageMissing", None),
  )
  doc.add_object_given_number(48, font_descriptor_for_test())
  doc.add_object_given_number(49, font_descriptor_without_files_for_test())
  doc.add_object_given_number(
    50,
    font_form_xobject_for_test(
      PdfDictionary([
        (
          key_font,
          font_resource_dictionary_for_test([("/XF", PdfIndirect(51))]),
        ),
      ]),
    ),
  )
  doc.add_object_given_number(
    51,
    font_font_object_for_test("/Type1", "/XObjectMissing", None),
  )
  let first_page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    resources: PdfDictionary([
      (
        key_font,
        font_resource_dictionary_for_test([
          ("/F1", PdfIndirect(40)),
          ("/F2", PdfIndirect(41)),
          ("/F3", PdfIndirect(42)),
          ("/F4", PdfIndirect(43)),
          ("/F5", PdfIndirect(44)),
        ]),
      ),
      (
        key_xobject,
        font_resource_dictionary_for_test([("/Fm", PdfIndirect(50))]),
      ),
    ]),
  }
  let second_page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    resources: PdfDictionary([
      (key_font, font_resource_dictionary_for_test([("/F6", PdfIndirect(47))])),
    ]),
  }
  let page_root = try! doc.add_pagetree([first_page, second_page])
  ignore(try! doc.add_root(page_root, []))
  doc
}

///|
fn font_extraction_document_for_test() -> @pdflite.PdfDocument {
  let key_font = font_name_for_test("/Font")
  let key_xobject = font_name_for_test("/XObject")
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(80, font_file_stream_for_test("outer-font"))
  doc.add_object_given_number(
    81,
    font_descriptor_with_file_for_test("/FontFile2", 80),
  )
  doc.add_object_given_number(
    82,
    font_font_object_with_descriptor_for_test(
      "/TrueType",
      "/CustomEmbedded",
      Some("/WinAnsiEncoding"),
      PdfIndirect(81),
    ),
  )
  doc.add_object_given_number(90, font_file_stream_for_test("nested-font"))
  doc.add_object_given_number(
    91,
    font_descriptor_with_file_for_test("/FontFile", 90),
  )
  doc.add_object_given_number(
    92,
    font_font_object_with_descriptor_for_test(
      "/Type1",
      "/NestedEmbedded",
      Some("/MacRomanEncoding"),
      PdfIndirect(91),
    ),
  )
  doc.add_object_given_number(
    93,
    font_form_xobject_for_test(
      PdfDictionary([
        (
          key_font,
          font_resource_dictionary_for_test([("/FX", PdfIndirect(92))]),
        ),
      ]),
    ),
  )
  doc.add_object_given_number(
    94,
    font_font_object_for_test(
      "/Type1",
      "/NoEmbeddedFile",
      Some("/StandardEncoding"),
    ),
  )
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    resources: PdfDictionary([
      (
        key_font,
        font_resource_dictionary_for_test([
          ("/F1", PdfIndirect(82)),
          ("/FNo", PdfIndirect(94)),
        ]),
      ),
      (
        key_xobject,
        font_resource_dictionary_for_test([("/Fm", PdfIndirect(93))]),
      ),
    ]),
  }
  let page_root = try! doc.add_pagetree([page])
  ignore(try! doc.add_root(page_root, []))
  doc
}

///|
fn font_copy_source_document_for_test() -> @pdflite.PdfDocument {
  let key_font = font_name_for_test("/Font")
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(80, font_file_stream_for_test("copy-font"))
  doc.add_object_given_number(
    81,
    font_descriptor_with_file_for_test("/FontFile2", 80),
  )
  doc.add_object_given_number(
    82,
    font_font_object_with_descriptor_for_test(
      "/TrueType",
      "/CopiedFont",
      Some("/WinAnsiEncoding"),
      PdfIndirect(81),
    ),
  )
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    resources: PdfDictionary([
      (
        key_font,
        font_resource_dictionary_for_test([("/FSrc", PdfIndirect(82))]),
      ),
    ]),
  }
  let page_root = try! doc.add_pagetree([page])
  ignore(try! doc.add_root(page_root, []))
  doc
}

///|
fn font_copy_target_document_for_test() -> @pdflite.PdfDocument {
  let key_font = font_name_for_test("/Font")
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(
    30,
    font_font_object_for_test("/Type1", "/ExistingFont", None),
  )
  let first_page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    resources: PdfDictionary([
      (
        key_font,
        font_resource_dictionary_for_test([("/Existing", PdfIndirect(30))]),
      ),
    ]),
  }
  let page_root = try! doc.add_pagetree([
    first_page,
    @pdflite.pdf_page_blank(@pdflite.paper_a4),
  ])
  ignore(try! doc.add_root(page_root, []))
  doc
}

///|
test "PdfDocument remove_embedded_fonts strips font files from descriptors" {
  let key_font_descriptor = font_name_for_test("/FontDescriptor")
  let key_font_file = font_name_for_test("/FontFile")
  let key_font_file2 = font_name_for_test("/FontFile2")
  let key_font_file3 = font_name_for_test("/FontFile3")
  let key_flags = font_name_for_test("/Flags")
  let doc = font_document_for_test()
  let updated = try! doc.remove_embedded_fonts()
  let updated_from_function = try! @pdflite.pdf_remove_fonts(doc)
  guard updated.lookup_object_or_null(2).lookup_immediate(key_font_descriptor)
    is Some(PdfIndirect(descriptor_number)) else {
    fail("expected rewritten indirect font descriptor")
  }
  @test.assert_eq(descriptor_number != 3, true)
  let descriptor = updated.lookup_object_or_null(descriptor_number)
  @test.assert_eq(descriptor.lookup_immediate(key_font_file), None)
  @test.assert_eq(descriptor.lookup_immediate(key_font_file2), None)
  @test.assert_eq(descriptor.lookup_immediate(key_font_file3), None)
  @test.assert_eq(descriptor.lookup_immediate(key_flags), Some(PdfInteger(32)))
  @test.assert_eq(
    doc.lookup_object_or_null(2).lookup_immediate(key_font_descriptor),
    Some(PdfIndirect(3)),
  )
  @test.assert_eq(
    updated.lookup_object_or_null(3).lookup_immediate(key_font_file2),
    Some(PdfIndirect(5)),
  )
  guard updated_from_function
    .lookup_object_or_null(2)
    .lookup_immediate(key_font_descriptor)
    is Some(PdfIndirect(wrapper_descriptor_number)) else {
    fail("expected wrapper to rewrite font descriptor")
  }
  let wrapper_descriptor = updated_from_function.lookup_object_or_null(
    wrapper_descriptor_number,
  )
  @test.assert_eq(wrapper_descriptor.lookup_immediate(key_font_file), None)
  @test.assert_eq(
    updated.lookup_object_or_null(7).lookup_immediate(key_font_descriptor),
    Some(font_descriptor_for_test()),
  )
}

///|
test "PdfDocument list_fonts walks page and XObject resources" {
  let doc = font_listing_document_for_test()
  let fonts = try! doc.list_fonts([1])
  let wrapped = try! @pdflite.pdf_list_fonts(doc, [1])
  @test.assert_eq(fonts.length(), 3)
  @test.assert_eq(wrapped, fonts)
  @test.assert_eq(fonts[0].page, 1)
  @test.assert_eq(fonts[0].name, "/F1")
  @test.assert_eq(fonts[0].subtype, "/Type1")
  @test.assert_eq(fonts[0].basefont, "/Helvetica")
  @test.assert_eq(fonts[0].encoding, "/WinAnsiEncoding")
  @test.assert_eq(fonts[0].font, doc.lookup_object_or_null(20))
  @test.assert_eq(fonts[1].name, "/Fm1/F2")
  @test.assert_eq(fonts[1].subtype, "/TrueType")
  @test.assert_eq(fonts[1].basefont, "/SubsetFont")
  @test.assert_eq(fonts[1].encoding, "")
  @test.assert_eq(fonts[1].font, doc.lookup_object_or_null(21))
  @test.assert_eq(fonts[2].name, "/Fm1/FmNested/F3")
  @test.assert_eq(fonts[2].subtype, "")
  @test.assert_eq(fonts[2].basefont, "")
  @test.assert_eq(fonts[2].encoding, "")
  @test.assert_eq(fonts[2].font, doc.lookup_object_or_null(22))
  @test.assert_eq(try! doc.list_fonts([2]), [])
  let bad_page : Result[Array[@pdflite.PdfFontListEntry], Error] = try? doc.list_fonts([
      3,
    ],
  )
  guard bad_page is Err(@pdflite.PdfError::BadPageSpecification(_)) else {
    fail("expected BadPageSpecification")
  }
}

///|
test "PdfDocument font listing renders text and JSON" {
  let doc = font_listing_document_for_test()
  let text = try! doc.list_fonts_text([1])
  let wrapped_text = try! @pdflite.pdf_list_fonts_text(doc, [1])
  @test.assert_eq(
    text,
    @ascii.encode(
      "1 /F1 /Type1 /Helvetica /WinAnsiEncoding\n" +
      "1 /Fm1/F2 /TrueType /SubsetFont \n" +
      "1 /Fm1/FmNested/F3   \n",
    ),
  )
  @test.assert_eq(wrapped_text, text)
  let expected = Json::array([
    Json::object(
      Map::of([
        ("page", font_json_int_for_test(1)),
        ("name", Json::string("/F1")),
        ("subtype", Json::string("/Type1")),
        ("basefont", Json::string("/Helvetica")),
        ("encoding", Json::string("/WinAnsiEncoding")),
      ]),
    ),
    Json::object(
      Map::of([
        ("page", font_json_int_for_test(1)),
        ("name", Json::string("/Fm1/F2")),
        ("subtype", Json::string("/TrueType")),
        ("basefont", Json::string("/SubsetFont")),
        ("encoding", Json::null()),
      ]),
    ),
    Json::object(
      Map::of([
        ("page", font_json_int_for_test(1)),
        ("name", Json::string("/Fm1/FmNested/F3")),
        ("subtype", Json::null()),
        ("basefont", Json::null()),
        ("encoding", Json::null()),
      ]),
    ),
  ])
  let json = try! doc.fonts_json([1])
  @test.assert_eq(json, expected)
  @test.assert_eq(try! @pdflite.pdf_fonts_json(doc, [1]), expected)
  @test.assert_eq(
    try! doc.fonts_json_blob([1]),
    @utf8.encode(expected.stringify()),
  )
  @test.assert_eq(
    try! @pdflite.pdf_fonts_json_blob(doc, [1]),
    @utf8.encode(expected.stringify()),
  )
}

///|
test "PdfDocument missing_fonts reports page and descendant fonts" {
  let doc = font_missing_document_for_test()
  let missing = try! doc.missing_fonts([1])
  let wrapped = try! @pdflite.pdf_missing_fonts(doc, [1])
  @test.assert_eq(wrapped, missing)
  @test.assert_eq(missing.length(), 3)
  @test.assert_eq(missing[0].page, 1)
  @test.assert_eq(missing[0].name, "/F1")
  @test.assert_eq(missing[0].subtype, "/Type1")
  @test.assert_eq(missing[0].basefont, "/MissingOne")
  @test.assert_eq(missing[0].encoding, "Built-in")
  @test.assert_eq(missing[1].name, "/F4")
  @test.assert_eq(missing[1].subtype, "/CIDFontType2")
  @test.assert_eq(missing[1].basefont, "/CIDMissing")
  @test.assert_eq(missing[1].encoding, "Built-in")
  @test.assert_eq(missing[2].name, "/F5")
  @test.assert_eq(missing[2].subtype, "/Type1")
  @test.assert_eq(missing[2].basefont, "/DescriptorMissing")
  @test.assert_eq(missing[2].encoding, "/MacRomanEncoding")
  let second_page = try! doc.missing_fonts([2])
  @test.assert_eq(second_page.length(), 1)
  @test.assert_eq(second_page[0].name, "/F6")
  @test.assert_eq(second_page[0].basefont, "/SecondPageMissing")
  @test.assert_eq(doc.is_missing_font(doc.lookup_object_or_null(40)), true)
  @test.assert_eq(doc.is_missing_font(doc.lookup_object_or_null(41)), false)
  @test.assert_eq(doc.is_missing_font(doc.lookup_object_or_null(42)), false)
  @test.assert_eq(doc.is_missing_font(doc.lookup_object_or_null(44)), true)
  let bad_page : Result[Array[@pdflite.PdfMissingFontEntry], Error] = try? doc.missing_fonts([
      3,
    ],
  )
  guard bad_page is Err(@pdflite.PdfError::BadPageSpecification(_)) else {
    fail("expected BadPageSpecification")
  }
}

///|
test "PdfDocument missing_fonts_text matches cpdf rows" {
  let doc = font_missing_document_for_test()
  let text = try! doc.missing_fonts_text([1])
  @test.assert_eq(
    text,
    @ascii.encode(
      "1, /F1, /Type1, /MissingOne, Built-in\n" +
      "1, /F4, /CIDFontType2, /CIDMissing, Built-in\n" +
      "1, /F5, /Type1, /DescriptorMissing, /MacRomanEncoding\n",
    ),
  )
  @test.assert_eq(try! @pdflite.pdf_missing_fonts_text(doc, [1]), text)
}

///|
test "PdfDocument font_from_name resolves page and XObject paths" {
  let doc = font_extraction_document_for_test()
  @test.assert_eq(
    try! doc.font_from_name("/F1", 1),
    doc.lookup_object_or_null(82),
  )
  @test.assert_eq(
    try! @pdflite.pdf_font_from_name(doc, "/Fm/FX", 1),
    doc.lookup_object_or_null(92),
  )
  @test.assert_eq(try! doc.font_from_name("/Missing", 1), PdfNull)
  @test.assert_eq(try! doc.font_from_name("/Fm/Missing", 1), PdfNull)
  let bad_page : Result[@pdflite.PdfObject, Error] = try? doc.font_from_name(
    "/F1", 2,
  )
  guard bad_page is Err(@pdflite.PdfError::BadPageSpecification(_)) else {
    fail("expected BadPageSpecification")
  }
}

///|
test "PdfDocument font_table renders Helvetica encoding rows" {
  let doc = font_listing_document_for_test()
  let table = try! doc.font_table("/F1", 1)
  let wrapped = try! @pdflite.pdf_font_table(doc, "/F1", 1)
  @test.assert_eq(wrapped, table)
  let row = for entry in table {
    if entry.code == 65 {
      break Some(entry)
    }
  } nobreak {
    None
  }
  guard row is Some(row) else { fail("expected code 65 row") }
  @test.assert_eq(row.unicode, "0041")
  @test.assert_eq(row.utf8, "A")
  @test.assert_eq(row.unicode_name, "")
  @test.assert_eq(row.glyphnames, "A")
  let text = try! doc.font_table_text("/F1", 1)
  @test.assert_eq(try! @pdflite.pdf_font_table_text(doc, "/F1", 1), text)
  let rendered = @utf8.decode(text) catch { _ => fail("expected UTF-8 text") }
  @test.assert_eq(rendered.contains("65 = U+0041 (A - ) = A\n"), true)
  @test.assert_eq(rendered.contains(".notdef"), false)
  let bad_page : Result[Array[@pdflite.PdfFontTableEntry], Error] = try? doc.font_table(
    "/F1", 3,
  )
  guard bad_page is Err(@pdflite.PdfError::BadPageSpecification(_)) else {
    fail("expected BadPageSpecification")
  }
}

///|
test "PdfDocument extract_fontfile_bytes returns decoded embedded bytes" {
  let doc = font_extraction_document_for_test()
  @test.assert_eq(
    try! doc.extract_fontfile_bytes(1, "/F1"),
    Some(@ascii.encode("outer-font")),
  )
  @test.assert_eq(
    try! @pdflite.pdf_extract_fontfile_bytes(doc, 1, "/Fm/FX"),
    Some(@ascii.encode("nested-font")),
  )
  @test.assert_eq(try! doc.extract_fontfile_bytes(1, "/FNo"), None)
  @test.assert_eq(try! doc.extract_fontfile_bytes(1, "/Missing"), None)
}

///|
test "PdfDocument copy_font_from adds source font to selected target pages" {
  let source = font_copy_source_document_for_test()
  let target = font_copy_target_document_for_test()
  let copied = try! target.copy_font_from(source, "/FSrc", 1, [2])
  let pages = try! copied.pages_of_pagetree()
  let first_fonts = try! font_required_lookup_for_test(
    copied,
    "/Font",
    pages[0].resources,
  )
  @test.assert_eq(
    copied.lookup_direct(font_name_for_test("/Existing"), first_fonts) != None,
    true,
  )
  @test.assert_eq(
    copied.lookup_direct(font_name_for_test("/CopiedFont"), first_fonts),
    None,
  )
  let second_fonts = try! font_required_lookup_for_test(
    copied,
    "/Font",
    pages[1].resources,
  )
  let copied_font = try! font_required_lookup_for_test(
    copied, "/CopiedFont", second_fonts,
  )
  @test.assert_eq(
    copied.lookup_direct(font_name_for_test("/BaseFont"), copied_font),
    Some(PdfNameObject(font_name_for_test("/CopiedFont"))),
  )
  let descriptor = try! font_required_lookup_for_test(
    copied, "/FontDescriptor", copied_font,
  )
  let font_file = try! font_required_lookup_for_test(
    copied, "/FontFile2", descriptor,
  )
  @test.assert_eq(try! font_file.stream_bytes(), @ascii.encode("copy-font"))
  let wrapped = try! @pdflite.pdf_copy_font(source, "/FSrc", 1, [2], target)
  let wrapped_pages = try! wrapped.pages_of_pagetree()
  let wrapped_fonts = try! font_required_lookup_for_test(
    wrapped,
    "/Font",
    wrapped_pages[1].resources,
  )
  @test.assert_eq(
    wrapped.lookup_direct(font_name_for_test("/CopiedFont"), wrapped_fonts) !=
    None,
    true,
  )
  let bad_page : Result[@pdflite.PdfDocument, Error] = try? target.copy_font_from(
    source,
    "/FSrc",
    1,
    [3],
  )
  guard bad_page is Err(@pdflite.PdfError::BadPageSpecification(_)) else {
    fail("expected BadPageSpecification")
  }
}
