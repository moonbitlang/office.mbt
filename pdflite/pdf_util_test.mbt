///|
fn util_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn util_lookup_for_test(
  object : @pdflite.PdfObject,
  key : @pdflite.PdfName,
) -> @pdflite.PdfObject? {
  object.lookup_immediate(key)
}

///|
test "PdfDocument remove_dict_entry_everywhere rewrites trailer objects streams and arrays" {
  let key_remove = util_name_for_test("/Remove")
  let key_keep = util_name_for_test("/Keep")
  let doc = @pdflite.pdf_document_empty()
  doc.set_trailer_dict(
    @pdflite.pdf_dictionary([
      (key_keep, PdfInteger(1)),
      (key_remove, PdfInteger(2)),
    ]),
  )
  doc.add_object_given_number(
    1,
    @pdflite.pdf_dictionary([
      (key_remove, PdfInteger(10)),
      (key_keep, @pdflite.pdf_dictionary([(key_remove, PdfInteger(11))])),
    ]),
  )
  doc.add_object_given_number(
    2,
    @pdflite.pdf_array([
      @pdflite.pdf_dictionary([(key_remove, PdfInteger(20))]),
      PdfInteger(3),
    ]),
  )
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([(key_remove, PdfInteger(30))]),
    StreamGot(try! @pdflite.pdf_bytes_of_int_array([65, 66])),
  )
  doc.add_object_given_number(3, stream)

  doc.remove_dict_entry_everywhere(key_remove)

  @test.assert_eq(util_lookup_for_test(doc.trailer_dict(), key_remove), None)
  guard doc.lookup_object_or_null(1) is PdfDictionary(entries1) else {
    fail("expected dictionary object")
  }
  @test.assert_eq(
    util_lookup_for_test(PdfDictionary(entries1), key_remove),
    None,
  )
  guard util_lookup_for_test(PdfDictionary(entries1), key_keep)
    is Some(PdfDictionary(nested_entries)) else {
    fail("expected nested dictionary")
  }
  @test.assert_eq(
    util_lookup_for_test(PdfDictionary(nested_entries), key_remove),
    None,
  )
  guard doc.lookup_object_or_null(2)
    is PdfArray([PdfDictionary(array_entries), _]) else {
    fail("expected array dictionary")
  }
  @test.assert_eq(
    util_lookup_for_test(PdfDictionary(array_entries), key_remove),
    None,
  )
  guard doc.lookup_object_or_null(3) is PdfStreamObject(updated_stream) else {
    fail("expected stream object")
  }
  @test.assert_eq(
    util_lookup_for_test(updated_stream.dictionary, key_remove),
    None,
  )
  @test.assert_eq(
    updated_stream.data,
    StreamGot(try! @pdflite.pdf_bytes_of_int_array([65, 66])),
  )
}

///|
test "PdfDocument dictionary entry rewrite honours resolved search values" {
  let key_target = util_name_for_test("/Target")
  let key_other = util_name_for_test("/Other")
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(10, PdfInteger(99))
  doc.add_object_given_number(11, PdfInteger(42))
  doc.add_object_given_number(
    1,
    @pdflite.pdf_dictionary([
      (key_target, PdfIndirect(10)),
      (key_other, PdfInteger(1)),
    ]),
  )
  doc.add_object_given_number(
    2,
    @pdflite.pdf_dictionary([(key_target, PdfIndirect(11))]),
  )

  doc.remove_dict_entry_everywhere(key_target, search=Some(PdfInteger(99)))

  @test.assert_eq(
    util_lookup_for_test(doc.lookup_object_or_null(1), key_target),
    None,
  )
  @test.assert_eq(
    util_lookup_for_test(doc.lookup_object_or_null(2), key_target),
    Some(PdfIndirect(11)),
  )

  doc.replace_dict_entry_everywhere(
    key_target,
    PdfInteger(7),
    search=Some(PdfInteger(42)),
  )
  @test.assert_eq(
    util_lookup_for_test(doc.lookup_object_or_null(2), key_target),
    Some(PdfInteger(7)),
  )
}

///|
test "pdf_replace_dict_entry ignores missing keys and updates trailer" {
  let key_target = util_name_for_test("/Target")
  let key_keep = util_name_for_test("/Keep")
  let doc = @pdflite.pdf_document_empty()
  doc.set_trailer_dict(
    @pdflite.pdf_dictionary([
      (key_keep, PdfInteger(1)),
      (key_target, PdfInteger(2)),
    ]),
  )
  doc.add_object_given_number(
    1,
    @pdflite.pdf_dictionary([(key_keep, PdfInteger(3))]),
  )

  @pdflite.pdf_replace_dict_entry(doc, key_target, PdfInteger(9))

  @test.assert_eq(
    util_lookup_for_test(doc.trailer_dict(), key_target),
    Some(PdfInteger(9)),
  )
  @test.assert_eq(
    util_lookup_for_test(doc.lookup_object_or_null(1), key_keep),
    Some(PdfInteger(3)),
  )
}

///|
test "pdf_check_injectible reports cpdf shell metacharacters" {
  try! @pdflite.pdf_check_injectible("safe/名前.pdf")
  let ampersand : Result[Unit, Error] = try? @pdflite.pdf_check_injectible(
    "a&b.pdf",
  )
  guard ampersand is Err(@pdflite.PdfError::InsecurePathName("a&b.pdf")) else {
    fail("expected InsecurePathName for ampersand")
  }
  let newline : Result[Unit, Error] = try? @pdflite.pdf_check_injectible(
    "a\nb.pdf",
  )
  guard newline is Err(@pdflite.PdfError::InsecurePathName("a\nb.pdf")) else {
    fail("expected InsecurePathName for newline")
  }
}
