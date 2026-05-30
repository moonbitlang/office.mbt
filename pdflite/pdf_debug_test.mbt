///|
fn debug_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn debug_dictionary_for_test(
  entries : ArrayView[(@pdflite.PdfName, @syntax.PdfObject)],
) -> @syntax.PdfObject {
  @syntax.pdf_dictionary(entries)
}

///|
test "PdfDocument debug_objects renders trailer catalog pages and objects" {
  let key_root = debug_name_for_test("/Root")
  let key_type = debug_name_for_test("/Type")
  let key_catalog = debug_name_for_test("/Catalog")
  let key_pages = debug_name_for_test("/Pages")
  let key_count = debug_name_for_test("/Count")
  let key_kids = debug_name_for_test("/Kids")
  let pages = debug_dictionary_for_test([
    (key_type, PdfNameObject(key_pages)),
    (key_count, PdfInteger(0)),
    (key_kids, PdfArray([])),
  ])
  let catalog = debug_dictionary_for_test([
    (key_type, PdfNameObject(key_catalog)),
    (key_pages, PdfIndirect(2)),
  ])
  let document = @pdflite.pdf_document_empty()
  document.set_root(1)
  document.set_trailer_dict(
    debug_dictionary_for_test([(key_root, PdfIndirect(1))]),
  )
  document.add_object_given_number(2, pages)
  document.add_object_given_number(1, catalog)
  @test.assert_eq(
    try! document.debug_objects(),
    @ascii.encode(
      "Trailerdict: << /Root 1 0 R >>\n" +
      "Root: 1\n" +
      "Catalog: << /Type /Catalog /Pages 2 0 R >>\n" +
      "Pages: << /Type /Pages /Count 0 /Kids [] >>\n" +
      "1 0 obj:\n\n" +
      "<< /Type /Catalog /Pages 2 0 R >>\n" +
      "2 0 obj:\n\n" +
      "<< /Type /Pages /Count 0 /Kids [] >>\n",
    ),
  )
}

///|
test "pdf_debug_objects reports missing trailer root and keeps object dump" {
  let document = @pdflite.pdf_document_empty()
  document.add_object_given_number(3, PdfString(@ascii.encode("hi")))
  @test.assert_eq(
    try! @pdflite.pdf_debug_objects(document),
    @ascii.encode(
      "Trailerdict: << >>\n" +
      "Root: 0\n" +
      "No catalog!\n" +
      "3 0 obj:\n\n" +
      "(hi)\n",
    ),
  )
  @test.assert_eq(
    try! @pdflite.pdf_print_pdf_objs(document),
    try! @pdflite.pdf_debug_objects(document),
  )
}

///|
test "PdfDocument debug_objects preserves cpdf no-pages message" {
  let key_root = debug_name_for_test("/Root")
  let key_type = debug_name_for_test("/Type")
  let key_catalog = debug_name_for_test("/Catalog")
  let catalog = debug_dictionary_for_test([
    (key_type, PdfNameObject(key_catalog)),
  ])
  let document = @pdflite.pdf_document_empty()
  document.set_root(1)
  document.set_trailer_dict(
    debug_dictionary_for_test([(key_root, PdfIndirect(1))]),
  )
  document.add_object_given_number(1, catalog)
  @test.assert_eq(
    try! document.debug_objects(),
    @ascii.encode(
      "Trailerdict: << /Root 1 0 R >>\n" +
      "Root: 1\n" +
      "Catalog: << /Type /Catalog >>\n" +
      "no catalog\n" +
      "1 0 obj:\n\n" +
      "<< /Type /Catalog >>\n",
    ),
  )
}
