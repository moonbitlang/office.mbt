///|
fn lookup_name_for_test(values : ArrayView[Int]) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(try! @pdflite.pdf_bytes_of_int_array(values))
}

///|
test "PdfDocument direct resolves parsed indirect objects" {
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(5, PdfIndirect(6))
  doc.add_object_given_number(6, PdfInteger(42))
  @test.assert_eq(doc.direct(PdfIndirect(5)), PdfInteger(42))
  @test.assert_eq(doc.direct(PdfIndirect(9)), PdfNull)
  let cyclic = @pdflite.pdf_document_empty()
  cyclic.add_object_given_number(1, PdfIndirect(1))
  @test.assert_eq(cyclic.direct(PdfIndirect(1)), PdfNull)
  let objects = @pdflite.pdf_objects_empty()
  objects.set_entry(9, @pdflite.pdf_object_entry(ObjectToParse))
  @test.assert_eq(objects.lookup_object_or_null(9), PdfNull)
}

///|
test "PdfDocument lookup_direct follows dictionary indirections" {
  let doc = @pdflite.pdf_document_empty()
  let key_type = lookup_name_for_test([47, 84, 121, 112, 101])
  let key_alt = lookup_name_for_test([47, 65, 108, 116])
  doc.add_object_given_number(2, PdfNameObject(key_type))
  let dict = @pdflite.pdf_dictionary([(key_type, PdfIndirect(2))])
  @test.assert_eq(
    doc.lookup_direct(key_type, dict),
    Some(PdfNameObject(key_type)),
  )
  @test.assert_eq(doc.lookup_direct(key_alt, dict), None)
  @test.assert_eq(
    doc.lookup_direct_or_else(key_alt, key_type, dict),
    Some(PdfNameObject(key_type)),
  )
  @test.assert_eq(doc.lookup_direct(key_type, PdfInteger(2)), None)
}

///|
test "PdfDocument lookup_direct_or_array follows CamlPDF array names" {
  let doc = @pdflite.pdf_document_empty()
  let index_1 = lookup_name_for_test([47, 91, 49])
  let index_1_with_tail = lookup_name_for_test([47, 91, 49, 116, 97, 105, 108])
  let index_2 = lookup_name_for_test([47, 91, 50])
  let malformed_index = lookup_name_for_test([47, 91, 120])
  doc.add_object_given_number(8, PdfInteger(88))
  let array : @pdflite.PdfObject = PdfArray([PdfInteger(7), PdfIndirect(8)])
  @test.assert_eq(
    doc.lookup_direct_or_array(index_1, array),
    Some(PdfInteger(88)),
  )
  @test.assert_eq(
    doc.lookup_direct_or_array(index_1_with_tail, array),
    Some(PdfInteger(88)),
  )
  @test.assert_eq(doc.lookup_direct_or_array(index_2, array), None)
  @test.assert_eq(doc.lookup_direct_or_array(index_1, PdfInteger(1)), None)
  let dict = @pdflite.pdf_dictionary([(malformed_index, PdfInteger(5))])
  @test.assert_eq(
    doc.lookup_direct_or_array(malformed_index, dict),
    Some(PdfInteger(5)),
  )
}

///|
test "PdfDocument indirect_number returns the stored indirect reference" {
  let doc = @pdflite.pdf_document_empty()
  let key_target = lookup_name_for_test([47, 84, 97, 114, 103, 101, 116])
  let key_other = lookup_name_for_test([47, 79, 116, 104, 101, 114])
  let key_missing = lookup_name_for_test([47, 77, 105, 115, 115, 105, 110, 103])
  let dict = @pdflite.pdf_dictionary([
    (key_target, PdfIndirect(5)),
    (key_other, PdfInteger(2)),
  ])
  doc.add_object_given_number(2, dict)
  doc.add_object_given_number(5, PdfIndirect(9))
  @test.assert_eq(doc.indirect_number(key_target, PdfIndirect(2)), Some(5))
  @test.assert_eq(doc.indirect_number(key_other, PdfIndirect(2)), None)
  @test.assert_eq(doc.indirect_number(key_missing, PdfIndirect(2)), None)
  @test.assert_eq(doc.indirect_number(key_target, PdfInteger(1)), None)
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([(key_target, PdfIndirect(7))]),
    StreamGot(try! @pdflite.pdf_bytes_of_int_array([65])),
  )
  @test.assert_eq(doc.indirect_number(key_target, stream), Some(7))
}

///|
test "PdfDocument lookup_chain follows nested dictionaries" {
  let doc = @pdflite.pdf_document_empty()
  let key_root = lookup_name_for_test([47, 82, 111, 111, 116])
  let key_child = lookup_name_for_test([47, 67, 104, 105, 108, 100])
  let key_value = lookup_name_for_test([47, 86, 97, 108, 117, 101])
  let nested = @pdflite.pdf_dictionary([
    (
      key_root,
      @pdflite.pdf_dictionary([
        (key_child, @pdflite.pdf_dictionary([(key_value, PdfInteger(7))])),
      ]),
    ),
  ])
  @test.assert_eq(
    doc.lookup_chain(nested, [key_root, key_child, key_value]),
    Some(PdfInteger(7)),
  )
  @test.assert_eq(doc.lookup_chain(nested, [key_child]), None)
}

///|
test "PdfDocument lookup_chain can traverse arrays by index names" {
  let doc = @pdflite.pdf_document_empty()
  let key_items = lookup_name_for_test([47, 73, 116, 101, 109, 115])
  let key_value = lookup_name_for_test([47, 86, 97, 108, 117, 101])
  let index_1 = lookup_name_for_test([47, 91, 49])
  let nested = @pdflite.pdf_dictionary([
    (
      key_items,
      PdfArray([
        PdfInteger(0),
        @pdflite.pdf_dictionary([(key_value, PdfInteger(9))]),
      ]),
    ),
  ])
  @test.assert_eq(
    doc.lookup_chain(nested, [key_items, index_1, key_value]),
    Some(PdfInteger(9)),
  )
}

///|
test "PdfDocument get_number and parse_rectangle mirror Pdf helpers" {
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(3, PdfReal(2.5))
  @test.assert_eq(try! doc.get_number(PdfInteger(2)), 2.0)
  @test.assert_eq(try! doc.get_number(PdfIndirect(3)), 2.5)
  let rect = try! doc.parse_rectangle(
    PdfArray([PdfInteger(10), PdfInteger(20), PdfInteger(0), PdfInteger(5)]),
  )
  @test.assert_eq(rect.min_x, 0.0)
  @test.assert_eq(rect.min_y, 5.0)
  @test.assert_eq(rect.max_x, 10.0)
  @test.assert_eq(rect.max_y, 20.0)
  let bad_number : Result[Double, Error] = try? doc.get_number(PdfNull)
  guard bad_number is Err(@pdflite.PdfError::NumberExpected) else {
    fail("expected NumberExpected")
  }
  let bad_rect : Result[@pdflite.PdfRectangle, Error] = try? doc.parse_rectangle(
    PdfArray([PdfInteger(1)]),
  )
  guard bad_rect is Err(@pdflite.PdfError::RectangleExpected) else {
    fail("expected RectangleExpected")
  }
  let bad_number_rect : Result[@pdflite.PdfRectangle, Error] = try? doc.parse_rectangle(
    PdfArray([PdfInteger(1), PdfNull, PdfInteger(3), PdfInteger(4)]),
  )
  guard bad_number_rect is Err(@pdflite.PdfError::BadRectangle) else {
    fail("expected BadRectangle")
  }
}

///|
test "PdfDocument parse_matrix and pdf_object_of_matrix round trip matrices" {
  let doc = @pdflite.pdf_document_empty()
  let key_matrix = lookup_name_for_test([47, 77, 97, 116, 114, 105, 120])
  let matrix = @pdflite.transform_translate(10.0, 20.0)
  let dict = @pdflite.pdf_dictionary([
    (key_matrix, @pdflite.pdf_object_of_matrix(matrix)),
  ])
  @test.assert_eq(try! doc.parse_matrix(key_matrix, dict), matrix)
  @test.assert_eq(
    try! doc.parse_matrix(lookup_name_for_test([47, 77, 105, 115, 115]), dict),
    @pdflite.transform_identity_matrix,
  )
  let bad = @pdflite.pdf_dictionary([(key_matrix, PdfArray([PdfInteger(1)]))])
  let bad_matrix : Result[@pdflite.TransformMatrix, Error] = try? doc.parse_matrix(
    key_matrix, bad,
  )
  guard bad_matrix is Err(@pdflite.PdfError::MatrixMalformed) else {
    fail("expected MatrixMalformed")
  }
}
