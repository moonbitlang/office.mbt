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
