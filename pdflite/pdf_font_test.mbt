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
