///|
fn addtext_resource_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn addtext_resource_font_descriptor_for_test(
  capheight : Double,
) -> @pdflite.PdfFontDescriptor {
  {
    ascent: 0.0,
    descent: 0.0,
    avgwidth: 0.0,
    maxwidth: 0.0,
    flags: 0,
    fontbbox: { min_x: 0.0, min_y: 0.0, max_x: 0.0, max_y: 0.0 },
    italicangle: 0.0,
    capheight,
    xheight: 0.0,
    stemv: 0.0,
    fontfile: None,
    charset: None,
    tounicode: None,
  }
}

///|
fn addtext_resource_simple_font_for_test(
  capheight : Double,
) -> @pdflite.PdfFont {
  PdfFontSimple({
    fonttype: PdfType1,
    basefont: None,
    firstchar: 0,
    lastchar: -1,
    widths: [],
    fontdescriptor: Some(addtext_resource_font_descriptor_for_test(capheight)),
    fontmetrics: None,
    encoding: PdfWinAnsiEncoding,
  })
}

///|
fn addtext_resource_simple_font_with_encoding_for_test(
  encoding : @pdflite.PdfEncoding,
) -> @pdflite.PdfFont {
  PdfFontSimple({
    fonttype: PdfType1,
    basefont: None,
    firstchar: 0,
    lastchar: -1,
    widths: [],
    fontdescriptor: Some(addtext_resource_font_descriptor_for_test(700.0)),
    fontmetrics: None,
    encoding,
  })
}

///|
fn addtext_resource_standard_font_for_test() -> @pdflite.PdfFont {
  PdfFontStandard({ font: PdfHelvetica, encoding: PdfWinAnsiEncoding })
}

///|
test "pdf_addtext_effective_encoding follows selected add-text font" {
  @test.assert_eq(
    @pdflite.pdf_addtext_effective_encoding(
      Some(
        PdfFontStandard({ font: PdfTimesRoman, encoding: PdfMacRomanEncoding }),
      ),
    ),
    PdfMacRomanEncoding,
  )
  @test.assert_eq(
    @pdflite.pdf_addtext_effective_encoding(
      Some(
        addtext_resource_simple_font_with_encoding_for_test(
          PdfMacExpertEncoding,
        ),
      ),
    ),
    PdfMacExpertEncoding,
  )
  @test.assert_eq(
    @pdflite.pdf_addtext_effective_encoding(None),
    PdfWinAnsiEncoding,
  )
}

///|
test "PdfDocument addtext_page_font_dictionary uses empty fallback" {
  let document = @pdflite.pdf_document_empty()
  let page = @page.pdf_page_blank(@geometry.paper_a4)
  @test.assert_eq(
    document.addtext_page_font_dictionary(page),
    PdfDictionary([]),
  )
}

///|
test "PdfDocument addtext_page_font_dictionary resolves indirect fonts" {
  let document = @pdflite.pdf_document_empty()
  let fonts : @syntax.PdfObject = PdfDictionary([
    (addtext_resource_name_for_test("/F0"), PdfInteger(1)),
  ])
  let number = document.add_object(fonts)
  let page = {
    ..@page.pdf_page_blank(@geometry.paper_a4),
    resources: PdfDictionary([
      (addtext_resource_name_for_test("/Font"), PdfIndirect(number)),
    ]),
  }
  @test.assert_eq(
    @pdflite.pdf_addtext_page_font_dictionary(document, page),
    fonts,
  )
}

///|
test "PdfDocument addtext_page_font_dictionary preserves malformed values" {
  let document = @pdflite.pdf_document_empty()
  let page = {
    ..@page.pdf_page_blank(@geometry.paper_a4),
    resources: PdfDictionary([
      (addtext_resource_name_for_test("/Font"), PdfInteger(7)),
    ]),
  }
  @test.assert_eq(document.addtext_page_font_dictionary(page), PdfInteger(7))
}

///|
test "pdf_addtext_allocate_font_names handles non-fontpack resources" {
  let f0 = addtext_resource_name_for_test("/F0")
  let f1 = addtext_resource_name_for_test("/F1")
  let f2 = addtext_resource_name_for_test("/F2")
  let fontdict : @syntax.PdfObject = PdfDictionary([
    (f0, PdfInteger(1)),
    (f1, PdfInteger(2)),
  ])
  let allocated = try! @pdflite.pdf_addtext_allocate_font_names(fontdict, None)
  @test.assert_eq(allocated.0, f2)
  @test.assert_eq(allocated.1, fontdict)
  @test.assert_eq(allocated.2, [])
}

///|
test "pdf_addtext_allocate_font_names reserves fontpack placeholders" {
  let f0 = addtext_resource_name_for_test("/F0")
  let f1 = addtext_resource_name_for_test("/F1")
  let f2 = addtext_resource_name_for_test("/F2")
  let fontdict : @syntax.PdfObject = PdfDictionary([(f0, PdfInteger(1))])
  let pack : @pdflite.PdfFontPack = {
    fonts: [
      addtext_resource_standard_font_for_test(),
      addtext_resource_simple_font_for_test(700.0),
    ],
    entries: [],
  }
  let allocated = try! @pdflite.pdf_addtext_allocate_font_names(
    fontdict,
    Some(pack),
  )
  @test.assert_eq(allocated.0, f1)
  @test.assert_eq(allocated.2, [f1, f2])
  @test.assert_eq(allocated.1.lookup_immediate(f0), Some(PdfInteger(1)))
  @test.assert_eq(allocated.1.lookup_immediate(f1), Some(PdfNull))
  @test.assert_eq(allocated.1.lookup_immediate(f2), Some(PdfNull))
}

///|
test "pdf_addtext_fontpack_resource_dictionary installs embedded font references" {
  let f0 = addtext_resource_name_for_test("/F0")
  let f1 = addtext_resource_name_for_test("/F1")
  let f2 = addtext_resource_name_for_test("/F2")
  let fontdict : @syntax.PdfObject = PdfDictionary([(f0, PdfInteger(1))])
  let updated = try! @pdflite.pdf_addtext_fontpack_resource_dictionary(
    fontdict,
    [f1, f2],
    [10, 11],
  )
  @test.assert_eq(updated.lookup_immediate(f0), Some(PdfInteger(1)))
  @test.assert_eq(updated.lookup_immediate(f1), Some(PdfIndirect(10)))
  @test.assert_eq(updated.lookup_immediate(f2), Some(PdfIndirect(11)))
  let result : Result[@syntax.PdfObject, Error] = try? @pdflite.pdf_addtext_fontpack_resource_dictionary(
    fontdict,
    [f1],
    [10, 11],
  )
  guard result
    is Err(@pdflite.PdfError::SoftError("bad add-text fontpack resource list")) else {
    fail("expected SoftError for mismatched fontpack resource lists")
  }
}

///|
test "pdf_addtext_install_font_resource adds selected font dictionary" {
  let font_key = addtext_resource_name_for_test("/Font")
  let procset = addtext_resource_name_for_test("/ProcSet")
  let f0 = addtext_resource_name_for_test("/F0")
  let f1 = addtext_resource_name_for_test("/F1")
  let resources : @syntax.PdfObject = PdfDictionary([(procset, PdfArray([]))])
  let fontdict : @syntax.PdfObject = PdfDictionary([(f0, PdfInteger(1))])
  let updated = try! @pdflite.pdf_addtext_install_font_resource(
    resources,
    fontdict,
    f1,
    Some(PdfIndirect(10)),
  )
  @test.assert_eq(updated.lookup_immediate(procset), Some(PdfArray([])))
  guard updated.lookup_immediate(font_key) is Some(fonts) else {
    fail("expected updated font resource dictionary")
  }
  @test.assert_eq(fonts.lookup_immediate(f0), Some(PdfInteger(1)))
  @test.assert_eq(fonts.lookup_immediate(f1), Some(PdfIndirect(10)))
  @test.assert_eq(
    try! @pdflite.pdf_addtext_install_font_resource(
      resources,
      fontdict,
      f1,
      None,
    ),
    resources,
  )
}

///|
test "pdf_addtext_install_fontpack_resources adds embedded font dictionary" {
  let font_key = addtext_resource_name_for_test("/Font")
  let f0 = addtext_resource_name_for_test("/F0")
  let f1 = addtext_resource_name_for_test("/F1")
  let f2 = addtext_resource_name_for_test("/F2")
  let resources : @syntax.PdfObject = PdfDictionary([])
  let fontdict : @syntax.PdfObject = PdfDictionary([(f0, PdfInteger(1))])
  let updated = try! @pdflite.pdf_addtext_install_fontpack_resources(
    resources,
    fontdict,
    [f1, f2],
    [10, 11],
  )
  guard updated.lookup_immediate(font_key) is Some(fonts) else {
    fail("expected updated fontpack resource dictionary")
  }
  @test.assert_eq(fonts.lookup_immediate(f0), Some(PdfInteger(1)))
  @test.assert_eq(fonts.lookup_immediate(f1), Some(PdfIndirect(10)))
  @test.assert_eq(fonts.lookup_immediate(f2), Some(PdfIndirect(11)))
}

///|
test "PdfDocument addtext_selected_font_object writes standard fonts" {
  let document = @pdflite.pdf_document_empty()
  let reference = try! document.addtext_selected_font_object(
    Some(addtext_resource_standard_font_for_test()),
  )
  @test.assert_eq(reference, Some(PdfIndirect(1)))
  let font_object = document.lookup_object_or_null(1)
  @test.assert_eq(
    font_object.lookup_immediate(addtext_resource_name_for_test("/BaseFont")),
    Some(PdfNameObject(addtext_resource_name_for_test("/Helvetica"))),
  )
}

///|
test "pdf_addtext_selected_font_object preserves existing-font mode" {
  let document = @pdflite.pdf_document_empty()
  @test.assert_eq(
    try! @pdflite.pdf_addtext_selected_font_object(document, None),
    None,
  )
}

///|
test "PdfDocument addtext_selected_font_object propagates writer errors" {
  let document = @pdflite.pdf_document_empty()
  let result : Result[@syntax.PdfObject?, Error] = try? document.addtext_selected_font_object(
    Some(addtext_resource_simple_font_for_test(700.0)),
  )
  guard result is Err(@pdflite.PdfError::FontWriteUnsupported) else {
    fail("expected unsupported selected font error")
  }
}

///|
test "PdfDocument addtext_resource_setup installs selected font and opacity" {
  let document = @pdflite.pdf_document_empty()
  let font_key = addtext_resource_name_for_test("/Font")
  let extgstate = addtext_resource_name_for_test("/ExtGState")
  let gs0 = addtext_resource_name_for_test("/gs0")
  let f0 = addtext_resource_name_for_test("/F0")
  let f1 = addtext_resource_name_for_test("/F1")
  let ca = addtext_resource_name_for_test("/ca")
  let ca_stroke = addtext_resource_name_for_test("/CA")
  let page = {
    ..@page.pdf_page_blank(@geometry.paper_a4),
    resources: PdfDictionary([(font_key, PdfDictionary([(f0, PdfInteger(1))]))]),
  }
  let setup = try! document.addtext_resource_setup(
    page,
    Some(addtext_resource_standard_font_for_test()),
    None,
    addtext_resource_name_for_test("/Helvetica"),
    Some(PdfIndirect(10)),
    [],
    0.5,
  )
  @test.assert_eq(setup.unique_fontname, f1)
  @test.assert_eq(setup.unique_fontnames, [])
  @test.assert_eq(setup.extgstate_name, Some(gs0))
  guard setup.resources.lookup_immediate(font_key) is Some(fonts) else {
    fail("expected prepared font dictionary")
  }
  @test.assert_eq(fonts.lookup_immediate(f0), Some(PdfInteger(1)))
  @test.assert_eq(fonts.lookup_immediate(f1), Some(PdfIndirect(10)))
  guard setup.resources.lookup_immediate(extgstate) is Some(states) else {
    fail("expected prepared ExtGState dictionary")
  }
  guard states.lookup_immediate(gs0) is Some(opacity) else {
    fail("expected opacity resource")
  }
  @test.assert_eq(opacity.lookup_immediate(ca), Some(PdfReal(0.5)))
  @test.assert_eq(opacity.lookup_immediate(ca_stroke), Some(PdfReal(0.5)))
}

///|
test "pdf_addtext_resource_setup installs fontpack resources" {
  let document = @pdflite.pdf_document_empty()
  let font_key = addtext_resource_name_for_test("/Font")
  let f0 = addtext_resource_name_for_test("/F0")
  let f1 = addtext_resource_name_for_test("/F1")
  let f2 = addtext_resource_name_for_test("/F2")
  let page = {
    ..@page.pdf_page_blank(@geometry.paper_a4),
    resources: PdfDictionary([(font_key, PdfDictionary([(f0, PdfInteger(1))]))]),
  }
  let pack : @pdflite.PdfFontPack = {
    fonts: [
      addtext_resource_standard_font_for_test(),
      addtext_resource_simple_font_for_test(700.0),
    ],
    entries: [],
  }
  let setup = try! @pdflite.pdf_addtext_resource_setup(
    document,
    page,
    None,
    Some(pack),
    addtext_resource_name_for_test("/Fallback"),
    None,
    [20, 21],
    1.0,
  )
  @test.assert_eq(setup.unique_fontname, f1)
  @test.assert_eq(setup.unique_fontnames, [f1, f2])
  @test.assert_eq(setup.extgstate_name, None)
  @test.assert_eq(setup.font_dictionary.lookup_immediate(f1), Some(PdfNull))
  guard setup.resources.lookup_immediate(font_key) is Some(fonts) else {
    fail("expected prepared fontpack dictionary")
  }
  @test.assert_eq(fonts.lookup_immediate(f0), Some(PdfInteger(1)))
  @test.assert_eq(fonts.lookup_immediate(f1), Some(PdfIndirect(20)))
  @test.assert_eq(fonts.lookup_immediate(f2), Some(PdfIndirect(21)))
}

///|
test "PdfDocument addtext_resource_setup preserves existing-font resources" {
  let document = @pdflite.pdf_document_empty()
  let font_key = addtext_resource_name_for_test("/Font")
  let resource_name = addtext_resource_name_for_test("/Fx")
  let fontdict : @syntax.PdfObject = PdfDictionary([
    (resource_name, PdfIndirect(10)),
  ])
  let page = {
    ..@page.pdf_page_blank(@geometry.paper_a4),
    resources: PdfDictionary([(font_key, fontdict)]),
  }
  let setup = try! document.addtext_resource_setup(
    page,
    None,
    None,
    resource_name,
    Some(PdfIndirect(99)),
    [],
    0.25,
  )
  @test.assert_eq(setup.resources, page.resources)
  @test.assert_eq(setup.font_dictionary, fontdict)
  @test.assert_eq(setup.unique_fontname, resource_name)
  @test.assert_eq(setup.unique_fontnames, [])
  @test.assert_eq(setup.extgstate_name, None)
}
