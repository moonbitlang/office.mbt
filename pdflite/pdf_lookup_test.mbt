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
  let dict = @syntax.pdf_dictionary([(key_type, PdfIndirect(2))])
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
test "PdfDocument lookup_required mirrors CamlPDF lookup_exception" {
  let doc = @pdflite.pdf_document_empty()
  let key_type = lookup_name_for_test([47, 84, 121, 112, 101])
  let key_null = lookup_name_for_test([47, 78, 117, 108, 108])
  let key_missing = lookup_name_for_test([47, 77, 105, 115, 115, 105, 110, 103])
  doc.add_object_given_number(2, PdfInteger(42))
  let dict = @syntax.pdf_dictionary([
    (key_type, PdfIndirect(2)),
    (key_null, PdfNull),
  ])
  @test.assert_eq(
    try! doc.lookup_required(key_type, dict, RootExpected),
    PdfInteger(42),
  )
  let stream = @syntax.pdf_stream(
    @syntax.pdf_dictionary([(key_type, PdfInteger(7))]),
    StreamGot(try! @pdflite.pdf_bytes_of_int_array([65])),
  )
  @test.assert_eq(
    try! doc.lookup_required(key_type, stream, RootExpected),
    PdfInteger(7),
  )
  let missing : Result[@syntax.PdfObject, Error] = try? doc.lookup_required(
    key_missing,
    dict,
    RootExpected,
  )
  guard missing is Err(@pdflite.PdfError::RootExpected) else {
    fail("expected @pdflite.PdfError::RootExpected for missing key")
  }
  let null_value : Result[@syntax.PdfObject, Error] = try? doc.lookup_required(
    key_null,
    dict,
    RootExpected,
  )
  guard null_value is Err(@pdflite.PdfError::RootExpected) else {
    fail("expected @pdflite.PdfError::RootExpected for null value")
  }
  let not_dictionary : Result[@syntax.PdfObject, Error] = try? doc.lookup_required(
    key_type,
    PdfInteger(1),
    DictionaryExpected,
  )
  guard not_dictionary is Err(@pdflite.PdfError::DictionaryExpected) else {
    fail("expected caller-provided error for non-dictionary")
  }
}

///|
test "PdfDocument lookup_direct_or_array follows CamlPDF array names" {
  let doc = @pdflite.pdf_document_empty()
  let index_1 = lookup_name_for_test([47, 91, 49])
  let index_1_with_tail = lookup_name_for_test([47, 91, 49, 116, 97, 105, 108])
  let index_2 = lookup_name_for_test([47, 91, 50])
  let malformed_index = lookup_name_for_test([47, 91, 120])
  doc.add_object_given_number(8, PdfInteger(88))
  let array : @syntax.PdfObject = PdfArray([PdfInteger(7), PdfIndirect(8)])
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
  let dict = @syntax.pdf_dictionary([(malformed_index, PdfInteger(5))])
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
  let dict = @syntax.pdf_dictionary([
    (key_target, PdfIndirect(5)),
    (key_other, PdfInteger(2)),
  ])
  doc.add_object_given_number(2, dict)
  doc.add_object_given_number(5, PdfIndirect(9))
  @test.assert_eq(doc.indirect_number(key_target, PdfIndirect(2)), Some(5))
  @test.assert_eq(doc.indirect_number(key_other, PdfIndirect(2)), None)
  @test.assert_eq(doc.indirect_number(key_missing, PdfIndirect(2)), None)
  @test.assert_eq(doc.indirect_number(key_target, PdfInteger(1)), None)
  let stream = @syntax.pdf_stream(
    @syntax.pdf_dictionary([(key_target, PdfIndirect(7))]),
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
  let nested = @syntax.pdf_dictionary([
    (
      key_root,
      @syntax.pdf_dictionary([
        (key_child, @syntax.pdf_dictionary([(key_value, PdfInteger(7))])),
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
  let nested = @syntax.pdf_dictionary([
    (
      key_items,
      PdfArray([
        PdfInteger(0),
        @syntax.pdf_dictionary([(key_value, PdfInteger(9))]),
      ]),
    ),
  ])
  @test.assert_eq(
    doc.lookup_chain(nested, [key_items, index_1, key_value]),
    Some(PdfInteger(9)),
  )
}

///|
test "PdfDocument replace_chain creates missing direct dictionaries" {
  let doc = @pdflite.pdf_document_empty()
  let key_root = lookup_name_for_test([47, 82, 111, 111, 116])
  let key_names = lookup_name_for_test([47, 78, 97, 109, 101, 115])
  let key_javascript = lookup_name_for_test([
    47, 74, 97, 118, 97, 83, 99, 114, 105, 112, 116,
  ])
  try! doc.replace_chain([key_root, key_names, key_javascript], PdfInteger(42))
  @test.assert_eq(
    doc.lookup_chain(doc.trailer_dict(), [key_root, key_names, key_javascript]),
    Some(PdfInteger(42)),
  )
}

///|
test "PdfDocument replace_chain preserves indirect dictionary structure" {
  let doc = @pdflite.pdf_document_empty()
  let key_root = lookup_name_for_test([47, 82, 111, 111, 116])
  let key_names = lookup_name_for_test([47, 78, 97, 109, 101, 115])
  let key_javascript = lookup_name_for_test([
    47, 74, 97, 118, 97, 83, 99, 114, 105, 112, 116,
  ])
  doc.set_trailer_dict(@syntax.pdf_dictionary([(key_root, PdfIndirect(1))]))
  doc.add_object_given_number(
    1,
    @syntax.pdf_dictionary([(key_names, @syntax.pdf_dictionary([]))]),
  )
  try! doc.replace_chain(
    [key_root, key_names, key_javascript],
    PdfString(try! @pdflite.pdf_bytes_of_int_array([65])),
  )
  @test.assert_eq(
    doc.trailer_dict().lookup_immediate(key_root),
    Some(PdfIndirect(1)),
  )
  @test.assert_eq(
    doc.lookup_chain(doc.lookup_object_or_null(1), [key_names, key_javascript]),
    Some(PdfString(try! @pdflite.pdf_bytes_of_int_array([65]))),
  )
}

///|
test "PdfDocument replace_chain updates array chain entries" {
  let doc = @pdflite.pdf_document_empty()
  let key_items = lookup_name_for_test([47, 73, 116, 101, 109, 115])
  let key_value = lookup_name_for_test([47, 86, 97, 108, 117, 101])
  let index_0 = lookup_name_for_test([47, 91, 48])
  let index_1 = lookup_name_for_test([47, 91, 49])
  let index_2 = lookup_name_for_test([47, 91, 50])
  let bad_index = lookup_name_for_test([47, 91, 120])
  doc.add_object_given_number(
    7,
    @syntax.pdf_dictionary([(key_value, PdfInteger(1))]),
  )
  doc.set_trailer_dict(
    @syntax.pdf_dictionary([
      (
        key_items,
        PdfArray([
          PdfIndirect(7),
          @syntax.pdf_dictionary([(key_value, PdfInteger(2))]),
        ]),
      ),
    ]),
  )
  try! doc.replace_chain([key_items, index_0, key_value], PdfInteger(10))
  try! doc.replace_chain([key_items, index_1, key_value], PdfInteger(11))
  @test.assert_eq(
    doc.lookup_chain(doc.trailer_dict(), [key_items, index_0, key_value]),
    Some(PdfInteger(10)),
  )
  @test.assert_eq(
    doc.lookup_chain(doc.trailer_dict(), [key_items, index_1, key_value]),
    Some(PdfInteger(11)),
  )
  try! doc.replace_chain([key_items, index_1], PdfInteger(99))
  @test.assert_eq(
    doc.lookup_chain(doc.trailer_dict(), [key_items, index_1]),
    Some(PdfInteger(99)),
  )
  let final_out_of_range : Result[Unit, Error] = try? doc.replace_chain(
    [key_items, index_2],
    PdfInteger(0),
  )
  guard final_out_of_range
    is Err(@pdflite.PdfError::DictionaryKeyNotFound(missing)) &&
    missing == index_2 else {
    fail(
      "expected @pdflite.PdfError::DictionaryKeyNotFound for final out-of-range array chain",
    )
  }
  let out_of_range : Result[Unit, Error] = try? doc.replace_chain(
    [key_items, index_2, key_value],
    PdfInteger(0),
  )
  guard out_of_range is Err(@pdflite.PdfError::DictionaryKeyNotFound(missing)) &&
    missing == index_2 else {
    fail(
      "expected @pdflite.PdfError::DictionaryKeyNotFound for out-of-range array chain",
    )
  }
  let malformed : Result[Unit, Error] = try? doc.replace_chain(
    [key_items, bad_index],
    PdfInteger(0),
  )
  guard malformed is Err(@pdflite.PdfError::DictionaryKeyNotFound(missing)) &&
    missing == bad_index else {
    fail(
      "expected @pdflite.PdfError::DictionaryKeyNotFound for malformed array chain",
    )
  }
}

///|
test "PdfDocument replace_chain reports malformed chains" {
  let doc = @pdflite.pdf_document_empty()
  let key_root = lookup_name_for_test([47, 82, 111, 111, 116])
  let empty : Result[Unit, Error] = try? doc.replace_chain([], PdfInteger(1))
  guard empty is Err(@pdflite.PdfError::DictionaryExpected) else {
    fail("expected @pdflite.PdfError::DictionaryExpected for empty chain")
  }
  doc.set_trailer_dict(PdfInteger(1))
  let not_dictionary : Result[Unit, Error] = try? doc.replace_chain(
    [key_root],
    PdfInteger(2),
  )
  guard not_dictionary is Err(@pdflite.PdfError::DictionaryExpected) else {
    fail(
      "expected @pdflite.PdfError::DictionaryExpected for non-dictionary trailer",
    )
  }
}

///|
test "PdfDocument remove_chain removes direct dictionary entries" {
  let doc = @pdflite.pdf_document_empty()
  let key_root = lookup_name_for_test([47, 82, 111, 111, 116])
  let key_names = lookup_name_for_test([47, 78, 97, 109, 101, 115])
  let key_javascript = lookup_name_for_test([
    47, 74, 97, 118, 97, 83, 99, 114, 105, 112, 116,
  ])
  let key_dests = lookup_name_for_test([47, 68, 101, 115, 116, 115])
  doc.set_trailer_dict(
    @syntax.pdf_dictionary([
      (
        key_root,
        @syntax.pdf_dictionary([
          (
            key_names,
            @syntax.pdf_dictionary([
              (key_javascript, PdfInteger(1)),
              (key_dests, PdfInteger(2)),
            ]),
          ),
        ]),
      ),
    ]),
  )
  @test.assert_eq(
    try! doc.remove_chain([key_root, key_names, key_javascript]),
    true,
  )
  @test.assert_eq(
    doc.lookup_chain(doc.trailer_dict(), [key_root, key_names, key_javascript]),
    None,
  )
  @test.assert_eq(
    doc.lookup_chain(doc.trailer_dict(), [key_root, key_names, key_dests]),
    Some(PdfInteger(2)),
  )
  @test.assert_eq(
    try! doc.remove_chain([key_root, key_names, key_javascript]),
    false,
  )
  @test.assert_eq(
    try! doc.remove_chain([key_root, key_javascript, key_dests]),
    false,
  )
}

///|
test "PdfDocument remove_chain preserves indirect dictionary structure" {
  let doc = @pdflite.pdf_document_empty()
  let key_root = lookup_name_for_test([47, 82, 111, 111, 116])
  let key_names = lookup_name_for_test([47, 78, 97, 109, 101, 115])
  let key_javascript = lookup_name_for_test([
    47, 74, 97, 118, 97, 83, 99, 114, 105, 112, 116,
  ])
  doc.set_trailer_dict(@syntax.pdf_dictionary([(key_root, PdfIndirect(1))]))
  doc.add_object_given_number(
    1,
    @syntax.pdf_dictionary([
      (key_names, @syntax.pdf_dictionary([(key_javascript, PdfInteger(1))])),
    ]),
  )
  @test.assert_eq(
    try! doc.remove_chain([key_root, key_names, key_javascript]),
    true,
  )
  @test.assert_eq(
    doc.trailer_dict().lookup_immediate(key_root),
    Some(PdfIndirect(1)),
  )
  @test.assert_eq(
    doc.lookup_chain(doc.lookup_object_or_null(1), [key_names, key_javascript]),
    None,
  )
}

///|
test "PdfDocument remove_chain updates array chain entries" {
  let doc = @pdflite.pdf_document_empty()
  let key_items = lookup_name_for_test([47, 73, 116, 101, 109, 115])
  let key_value = lookup_name_for_test([47, 86, 97, 108, 117, 101])
  let index_0 = lookup_name_for_test([47, 91, 48])
  let index_1 = lookup_name_for_test([47, 91, 49])
  let index_2 = lookup_name_for_test([47, 91, 50])
  let bad_index = lookup_name_for_test([47, 91, 120])
  doc.add_object_given_number(
    7,
    @syntax.pdf_dictionary([(key_value, PdfInteger(1))]),
  )
  doc.set_trailer_dict(
    @syntax.pdf_dictionary([
      (
        key_items,
        PdfArray([
          PdfIndirect(7),
          @syntax.pdf_dictionary([(key_value, PdfInteger(2))]),
        ]),
      ),
    ]),
  )
  @test.assert_eq(try! doc.remove_chain([key_items, index_0, key_value]), true)
  @test.assert_eq(try! doc.remove_chain([key_items, index_1, key_value]), true)
  @test.assert_eq(
    doc.lookup_chain(doc.trailer_dict(), [key_items, index_0, key_value]),
    None,
  )
  @test.assert_eq(
    doc.lookup_chain(doc.trailer_dict(), [key_items, index_1, key_value]),
    None,
  )
  @test.assert_eq(try! doc.remove_chain([key_items, index_1, key_value]), false)
  @test.assert_eq(try! doc.remove_chain([key_items, index_2, key_value]), false)
  let remove_array_slot : Result[Bool, Error] = try? doc.remove_chain([
    key_items, index_1,
  ])
  guard remove_array_slot is Err(@pdflite.PdfError::DictionaryExpected) else {
    fail(
      "expected @pdflite.PdfError::DictionaryExpected for array slot removal",
    )
  }
  let malformed : Result[Bool, Error] = try? doc.remove_chain([
    key_items, bad_index, key_value,
  ])
  guard malformed is Err(@pdflite.PdfError::DictionaryKeyNotFound(missing)) &&
    missing == bad_index else {
    fail(
      "expected @pdflite.PdfError::DictionaryKeyNotFound for malformed array chain",
    )
  }
}

///|
test "PdfDocument remove_chain reports malformed short chains" {
  let doc = @pdflite.pdf_document_empty()
  let key_root = lookup_name_for_test([47, 82, 111, 111, 116])
  let key_child = lookup_name_for_test([47, 67, 104, 105, 108, 100])
  let empty : Result[Bool, Error] = try? doc.remove_chain([])
  guard empty is Err(@pdflite.PdfError::DictionaryExpected) else {
    fail("expected @pdflite.PdfError::DictionaryExpected for empty chain")
  }
  @test.assert_eq(try! doc.remove_chain([key_root]), false)
  doc.set_trailer_dict(@syntax.pdf_dictionary([(key_root, PdfInteger(1))]))
  let existing_single : Result[Bool, Error] = try? doc.remove_chain([key_root])
  guard existing_single is Err(@pdflite.PdfError::DictionaryExpected) else {
    fail(
      "expected @pdflite.PdfError::DictionaryExpected for existing single-entry chain",
    )
  }
  let non_dictionary : Result[Bool, Error] = try? doc.remove_chain([
    key_root, key_child,
  ])
  guard non_dictionary is Err(@pdflite.PdfError::DictionaryExpected) else {
    fail(
      "expected @pdflite.PdfError::DictionaryExpected for non-dictionary chain parent",
    )
  }
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
    fail("expected @pdflite.PdfError::NumberExpected")
  }
  let bad_rect : Result[@geometry.PdfRectangle, Error] = try? doc.parse_rectangle(
    PdfArray([PdfInteger(1)]),
  )
  guard bad_rect is Err(@pdflite.PdfError::RectangleExpected) else {
    fail("expected @pdflite.PdfError::RectangleExpected")
  }
  let bad_number_rect : Result[@geometry.PdfRectangle, Error] = try? doc.parse_rectangle(
    PdfArray([PdfInteger(1), PdfNull, PdfInteger(3), PdfInteger(4)]),
  )
  guard bad_number_rect is Err(@pdflite.PdfError::BadRectangle) else {
    fail("expected @pdflite.PdfError::BadRectangle")
  }
}

///|
test "PdfDocument transform_rect and transform_quadpoints update geometry" {
  let doc = @pdflite.pdf_document_empty()
  let matrix = @geometry.transform_translate(1.0, 2.0)
  @test.assert_eq(
    try! doc.transform_rect(
      matrix,
      PdfArray([PdfInteger(0), PdfInteger(0), PdfInteger(10), PdfInteger(20)]),
    ),
    PdfArray([PdfReal(1.0), PdfReal(2.0), PdfReal(11.0), PdfReal(22.0)]),
  )
  @test.assert_eq(
    doc.transform_quadpoints(
      matrix,
      PdfArray([
        PdfInteger(0),
        PdfInteger(0),
        PdfInteger(10),
        PdfInteger(0),
        PdfInteger(10),
        PdfInteger(10),
        PdfInteger(0),
        PdfInteger(10),
        PdfInteger(99),
      ]),
    ),
    PdfArray([
      PdfReal(1.0),
      PdfReal(2.0),
      PdfReal(11.0),
      PdfReal(2.0),
      PdfReal(11.0),
      PdfReal(12.0),
      PdfReal(1.0),
      PdfReal(12.0),
      PdfInteger(99),
    ]),
  )
  let malformed : @syntax.PdfObject = PdfArray([
    PdfInteger(0),
    PdfNameObject(lookup_name_for_test([47, 66, 97, 100])),
    PdfInteger(10),
    PdfInteger(0),
    PdfInteger(10),
    PdfInteger(10),
    PdfInteger(0),
    PdfInteger(10),
  ])
  @test.assert_eq(doc.transform_quadpoints(matrix, malformed), malformed)
  @test.assert_eq(
    doc.transform_quadpoints(matrix, PdfInteger(1)),
    PdfInteger(1),
  )
  let bad_rect : Result[@syntax.PdfObject, Error] = try? doc.transform_rect(
    matrix,
    PdfInteger(1),
  )
  guard bad_rect is Err(@pdflite.PdfError::RectangleExpected) else {
    fail("expected @pdflite.PdfError::RectangleExpected")
  }
}

///|
test "PdfDocument parse_matrix and pdf_object_of_matrix round trip matrices" {
  let doc = @pdflite.pdf_document_empty()
  let key_matrix = lookup_name_for_test([47, 77, 97, 116, 114, 105, 120])
  let matrix = @geometry.transform_translate(10.0, 20.0)
  let dict = @syntax.pdf_dictionary([
    (key_matrix, @pdflite.pdf_object_of_matrix(matrix)),
  ])
  @test.assert_eq(try! doc.parse_matrix(key_matrix, dict), matrix)
  @test.assert_eq(
    try! doc.parse_matrix(lookup_name_for_test([47, 77, 105, 115, 115]), dict),
    @geometry.transform_identity_matrix,
  )
  let bad = @syntax.pdf_dictionary([(key_matrix, PdfArray([PdfInteger(1)]))])
  let bad_matrix : Result[@geometry.TransformMatrix, Error] = try? doc.parse_matrix(
    key_matrix, bad,
  )
  guard bad_matrix is Err(@pdflite.PdfError::MatrixMalformed) else {
    fail("expected @pdflite.PdfError::MatrixMalformed")
  }
}
