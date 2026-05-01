///|
fn object_name_for_test(values : ArrayView[Int]) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(try! @pdflite.pdf_bytes_of_int_array(values))
}

///|
fn object_dictionary_keys_for_test(
  object : @pdflite.PdfObject,
) -> Array[@pdflite.PdfName] {
  match object.dictionary_view() {
    Some(entries) => [ for entry in entries => entry.0 ]
    None => []
  }
}

///|
test "PdfObject stores byte strings names arrays and dictionaries" {
  let name_type = object_name_for_test([47, 84, 121, 112, 101])
  let string_bytes = try! @pdflite.pdf_bytes_of_int_array([0, 255])
  let object = @pdflite.pdf_dictionary([
    (name_type, PdfNameObject(name_type)),
    (object_name_for_test([47, 83]), PdfString(string_bytes)),
    (
      object_name_for_test([47, 65]),
      @pdflite.pdf_array([PdfInteger(1), PdfBoolean(true)]),
    ),
  ])
  @test.assert_eq(
    object.lookup_immediate(name_type),
    Some(PdfNameObject(name_type)),
  )
  let cursor = @pdflite.byte_cursor_of_bytes(
    try! @pdflite.pdf_bytes_of_int_array([65, 66, 67]),
    source="object stream",
  )
  let deferred = @pdflite.stream_to_get(cursor, 1, 2)
  @test.assert_eq(deferred.input().source(), "object stream")
  @test.assert_eq(deferred.input().length(), 3)
  @test.assert_eq(deferred.position(), 1)
  @test.assert_eq(deferred.length(), 2)
  let non_dict_stream = @pdflite.pdf_stream(
    PdfInteger(1),
    StreamToGet(deferred),
  )
  @test.assert_eq(non_dict_stream.dictionary_view(), None)
}

///|
test "PdfObject dictionary add follows CamlPDF replacement order" {
  let name_a = object_name_for_test([47, 65])
  let name_b = object_name_for_test([47, 66])
  let name_c = object_name_for_test([47, 67])
  let dict = @pdflite.pdf_dictionary([
    (name_a, PdfInteger(1)),
    (name_b, PdfInteger(2)),
  ])
  let replaced = try! dict.add_dict_entry(name_b, PdfInteger(20))
  @test.assert_eq(replaced.lookup_immediate(name_b), Some(PdfInteger(20)))
  @test.assert_eq(object_dictionary_keys_for_test(replaced), [name_a, name_b])
  let added = try! dict.add_dict_entry(name_c, PdfInteger(3))
  @test.assert_eq(object_dictionary_keys_for_test(added), [
    name_c, name_b, name_a,
  ])
}

///|
test "PdfObject dictionary replace and remove report checked errors" {
  let name_a = object_name_for_test([47, 65])
  let name_b = object_name_for_test([47, 66])
  let dict = @pdflite.pdf_dictionary([(name_a, PdfInteger(1))])
  let replaced = try! dict.replace_dict_entry(name_a, PdfInteger(10))
  @test.assert_eq(replaced.lookup_immediate(name_a), Some(PdfInteger(10)))
  let missing : Result[@pdflite.PdfObject, Error] = try? dict.replace_dict_entry(
    name_b,
    PdfInteger(2),
  )
  guard missing is Err(@pdflite.PdfError::DictionaryKeyNotFound(missing_key)) &&
    missing_key == name_b else {
    fail("expected DictionaryKeyNotFound")
  }
  let not_dict_replace : Result[@pdflite.PdfObject, Error] = try? @pdflite.PdfInteger(
    1,
  ).replace_dict_entry(name_a, PdfInteger(2))
  guard not_dict_replace
    is Err(@pdflite.PdfError::DictionaryKeyNotFound(missing_key)) &&
    missing_key == name_a else {
    fail("expected DictionaryKeyNotFound")
  }
  let removed = try! dict.remove_dict_entry(name_a)
  @test.assert_eq(removed.lookup_immediate(name_a), None)
  let not_dict_add : Result[@pdflite.PdfObject, Error] = try? @pdflite.PdfInteger(
    1,
  ).add_dict_entry(name_a, PdfInteger(2))
  guard not_dict_add is Err(@pdflite.PdfError::DictionaryExpected) else {
    fail("expected DictionaryExpected")
  }
  let not_dict : Result[@pdflite.PdfObject, Error] = try? @pdflite.PdfInteger(1).remove_dict_entry(
    name_a,
  )
  guard not_dict is Err(@pdflite.PdfError::DictionaryExpected) else {
    fail("expected DictionaryExpected")
  }
}

///|
test "PdfObject stream dictionary helpers mutate stream dictionaries" {
  let name_length = object_name_for_test([47, 76, 101, 110, 103, 116, 104])
  let stream_data = @pdflite.StreamGot(
    try! @pdflite.pdf_bytes_of_int_array([65, 66]),
  )
  let stream = @pdflite.pdf_stream(PdfNull, stream_data)
  let updated = try! stream.add_dict_entry(name_length, PdfInteger(2))
  @test.assert_eq(updated.lookup_immediate(name_length), Some(PdfInteger(2)))
  let replaced = try! updated.replace_dict_entry(name_length, PdfInteger(4))
  @test.assert_eq(replaced.lookup_immediate(name_length), Some(PdfInteger(4)))
  let removed = try! replaced.remove_dict_entry(name_length)
  @test.assert_eq(removed.lookup_immediate(name_length), None)
}
