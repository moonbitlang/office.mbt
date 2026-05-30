///|
fn javascript_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn javascript_lookup_for_test(
  object : @syntax.PdfObject,
  key : @pdflite.PdfName,
) -> @syntax.PdfObject? {
  object.lookup_immediate(key)
}

///|
fn javascript_document_with_object_for_test(
  object : @syntax.PdfObject,
) -> @pdflite.PdfDocument {
  let document = @pdflite.pdf_document_empty()
  document.add_object_given_number(1, object)
  document
}

///|
test "PdfDocument contains_javascript follows cpdf string and URI checks" {
  let key_s = javascript_name_for_test("/S")
  let key_uri = javascript_name_for_test("/URI")
  @test.assert_eq(
    javascript_document_with_object_for_test(
      PdfDictionary([(key_s, PdfString(@ascii.encode("/JavaScript")))]),
    ).contains_javascript(),
    true,
  )
  @test.assert_eq(
    javascript_document_with_object_for_test(
      PdfDictionary([
        (key_s, PdfNameObject(javascript_name_for_test("/JavaScript"))),
      ]),
    ).contains_javascript(),
    false,
  )
  @test.assert_eq(
    javascript_document_with_object_for_test(
      PdfDictionary([(key_uri, PdfString(@ascii.encode("javascript:alert(1)")))]),
    ).contains_javascript(),
    true,
  )
  @test.assert_eq(
    javascript_document_with_object_for_test(
      PdfDictionary([(key_uri, PdfString(@ascii.encode("JavaScript:alert(1)")))]),
    ).contains_javascript(),
    false,
  )
}

///|
test "PdfDocument contains_javascript scans stream dictionaries" {
  let key_s = javascript_name_for_test("/S")
  let document = javascript_document_with_object_for_test(
    PdfStreamObject({
      dictionary: PdfDictionary([
        (key_s, PdfString(@ascii.encode("/JavaScript"))),
      ]),
      data: StreamGot(@ascii.encode("payload")),
    }),
  )
  @test.assert_eq(document.contains_javascript(), true)
}

///|
test "PdfDocument contains_javascript detects root JavaScript name tree" {
  let key_root = javascript_name_for_test("/Root")
  let key_names = javascript_name_for_test("/Names")
  let key_javascript = javascript_name_for_test("/JavaScript")
  let document = @pdflite.pdf_document_empty()
  document.add_object_given_number(
    10,
    PdfDictionary([
      (key_names, PdfDictionary([(key_javascript, PdfDictionary([]))])),
    ]),
  )
  document.set_trailer_dict(PdfDictionary([(key_root, PdfIndirect(10))]))
  @test.assert_eq(document.contains_javascript(), true)
}

///|
fn javascript_removal_document_for_test() -> @pdflite.PdfDocument {
  let key_js = javascript_name_for_test("/JS")
  let key_uri = javascript_name_for_test("/URI")
  let key_root = javascript_name_for_test("/Root")
  let key_names = javascript_name_for_test("/Names")
  let key_javascript = javascript_name_for_test("/JavaScript")
  let document = @pdflite.pdf_document_empty()
  document.add_object_given_number(
    1,
    PdfDictionary([
      (key_js, PdfString(@ascii.encode("app.alert('x')"))),
      (javascript_name_for_test("/Keep"), PdfInteger(7)),
    ]),
  )
  document.add_object_given_number(
    2,
    PdfArray([
      PdfDictionary([(key_uri, PdfString(@ascii.encode("javascript:alert(1)")))]),
    ]),
  )
  document.add_object_given_number(
    3,
    PdfStreamObject({
      dictionary: PdfDictionary([
        (key_js, PdfString(@ascii.encode("stream alert"))),
      ]),
      data: StreamGot(@ascii.encode("payload")),
    }),
  )
  document.add_object_given_number(
    10,
    PdfDictionary([
      (key_names, PdfDictionary([(key_javascript, PdfDictionary([]))])),
    ]),
  )
  document.set_trailer_dict(PdfDictionary([(key_root, PdfIndirect(10))]))
  document
}

///|
test "PdfDocument remove_javascript empties JS and URI entries and removes name tree" {
  let document = javascript_removal_document_for_test()
  @test.assert_eq(document.contains_javascript(), true)
  try! document.remove_javascript()
  let key_js = javascript_name_for_test("/JS")
  let key_uri = javascript_name_for_test("/URI")
  let key_root = javascript_name_for_test("/Root")
  let key_names = javascript_name_for_test("/Names")
  let key_javascript = javascript_name_for_test("/JavaScript")
  @test.assert_eq(
    javascript_lookup_for_test(document.lookup_object_or_null(1), key_js),
    Some(PdfString(@ascii.encode(""))),
  )
  guard document.lookup_object_or_null(2) is PdfArray([PdfDictionary(entries)]) else {
    fail("expected nested URI dictionary")
  }
  let nested : @syntax.PdfObject = PdfDictionary(entries)
  @test.assert_eq(
    javascript_lookup_for_test(nested, key_uri),
    Some(PdfString(@ascii.encode(""))),
  )
  guard document.lookup_object_or_null(3) is PdfStreamObject(stream) else {
    fail("expected stream object")
  }
  @test.assert_eq(
    javascript_lookup_for_test(stream.dictionary, key_js),
    Some(PdfString(@ascii.encode(""))),
  )
  @test.assert_eq(
    document.lookup_chain(document.trailer_dict(), [
      key_root, key_names, key_javascript,
    ]),
    None,
  )
  @test.assert_eq(document.contains_javascript(), false)
}

///|
test "pdf_contains_javascript and pdf_remove_javascript wrappers" {
  let document = javascript_removal_document_for_test()
  @test.assert_eq(@pdflite.pdf_contains_javascript(document), true)
  try! @pdflite.pdf_remove_javascript(document)
  @test.assert_eq(@pdflite.pdf_contains_javascript(document), false)
}
