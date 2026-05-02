///|
test "PdfObjectMap stores parsed and deferred object states" {
  let map = @pdflite.pdf_object_map_empty()
  map.set_entry(3, @pdflite.pdf_object_entry(ObjectParsed(PdfInteger(30))))
  map.set_entry(
    4,
    @pdflite.pdf_object_entry(ObjectParsedAlreadyDecrypted(PdfInteger(40))),
  )
  map.set_entry(
    9,
    @pdflite.pdf_object_entry(
      ObjectToParseFromObjectStream({ object_stream_number: 5, index: 1 }),
    ),
  )
  @test.assert_eq(map.length(), 3)
  @test.assert_eq(map.contains(3), true)
  @test.assert_eq(map.object_numbers(), [3, 4, 9])
  @test.assert_eq(map.lookup_parsed_or_null(3), PdfInteger(30))
  @test.assert_eq(map.lookup_parsed_or_null(4), PdfInteger(40))
  @test.assert_eq(map.lookup_parsed_or_null(9), PdfNull)
  @test.assert_eq(map.lookup_parsed_or_null(12), PdfNull)
}

///|
test "PdfObjects add and remove objects with CamlPDF-style event log" {
  let objects = @pdflite.pdf_objects_empty()
  let first = objects.add_object(PdfInteger(10))
  @test.assert_eq(first, 1)
  objects.add_object_given_number(7, PdfBoolean(true))
  @test.assert_eq(objects.max_object_number(), 7)
  @test.assert_eq(objects.object_numbers(), [1, 7])
  @test.assert_eq(objects.lookup_object_or_null(1), PdfInteger(10))
  @test.assert_eq(objects.lookup_object_or_null(7), PdfBoolean(true))
  objects.remove_object(1)
  @test.assert_eq(objects.object_numbers(), [7])
  @test.assert_eq(objects.lookup_object_or_null(1), PdfNull)
  @test.assert_eq(objects.log(), [
    (1, ObjectAltered),
    (7, ObjectAltered),
    (1, ObjectDeleted),
  ])
}

///|
test "PdfObjects map_objects_in_place preserves parsed state tags" {
  let objects = @pdflite.pdf_objects_empty()
  objects.set_entry(
    1,
    @pdflite.pdf_object_entry(ObjectParsed(PdfInteger(10)), generation=2),
  )
  objects.set_entry(
    2,
    @pdflite.pdf_object_entry(
      ObjectParsedAlreadyDecrypted(PdfInteger(20)),
      generation=3,
    ),
  )
  objects.set_entry(3, @pdflite.pdf_object_entry(ObjectToParse, generation=4))
  objects.map_objects_in_place(fn(object) {
    match object {
      PdfInteger(value) => PdfInteger(value + 1)
      _ => object
    }
  })
  guard objects.get_entry(1)
    is Some({ data: ObjectParsed(PdfInteger(11)), generation: 2 }) else {
    fail("expected mapped parsed object")
  }
  guard objects.get_entry(2)
    is Some(
      { data: ObjectParsedAlreadyDecrypted(PdfInteger(21)), generation: 3 }
    ) else {
    fail("expected mapped already-decrypted object")
  }
  guard objects.get_entry(3) is Some({ data: ObjectToParse, generation: 4 }) else {
    fail("expected deferred object to remain deferred")
  }
}

///|
test "PdfObjects parsed_entries returns sorted parsed objects with generations" {
  let objects = @pdflite.pdf_objects_empty()
  objects.set_entry(
    3,
    @pdflite.pdf_object_entry(ObjectParsed(PdfInteger(30)), generation=2),
  )
  objects.set_entry(1, @pdflite.pdf_object_entry(ObjectToParse, generation=8))
  objects.set_entry(
    2,
    @pdflite.pdf_object_entry(
      ObjectParsedAlreadyDecrypted(PdfInteger(20)),
      generation=4,
    ),
  )
  @test.assert_eq(objects.parsed_entries(), [
    (2, 4, PdfInteger(20)),
    (3, 2, PdfInteger(30)),
  ])
}

///|
test "PdfDocument empty document mirrors CamlPDF defaults" {
  let doc = @pdflite.pdf_document_empty()
  @test.assert_eq(doc.version(), (1, 0))
  @test.assert_eq(doc.root(), 0)
  @test.assert_eq(doc.object_count(), 0)
  @test.assert_eq(doc.trailer_dict(), PdfDictionary([]))
  @test.assert_eq(doc.was_linearized(), false)
  @test.assert_eq(doc.saved_encryption(), None)
  @test.assert_eq(doc.first_xref(), 0)
  @test.assert_eq(doc.revision_read(), 1)
  doc.set_version(1, 7)
  doc.set_root(4)
  doc.set_was_linearized(true)
  doc.set_first_xref(128)
  doc.set_revision_read(2)
  doc.set_trailer_dict(
    @pdflite.pdf_dictionary([
      (
        @pdflite.pdf_name_of_bytes(
          try! @pdflite.pdf_bytes_of_int_array([47, 82, 111, 111, 116]),
        ),
        PdfIndirect(4),
      ),
    ]),
  )
  @test.assert_eq(doc.version(), (1, 7))
  @test.assert_eq(doc.root(), 4)
  @test.assert_eq(doc.was_linearized(), true)
  @test.assert_eq(doc.first_xref(), 128)
  @test.assert_eq(doc.revision_read(), 2)
  @test.assert_eq(doc.add_object_given_number(4, PdfDictionary([])), ())
  @test.assert_eq(doc.lookup_object_or_null(4), PdfDictionary([]))
}

///|
test "PdfDocument catalog reads the root object or reports RootExpected" {
  let doc = @pdflite.pdf_document_empty()
  let missing : Result[@pdflite.PdfObject, Error] = try? doc.catalog()
  guard missing is Err(@pdflite.PdfError::RootExpected) else {
    fail("expected RootExpected for missing catalog")
  }
  doc.set_root(4)
  doc.add_object_given_number(4, @pdflite.pdf_dictionary([]))
  @test.assert_eq(try! doc.catalog(), @pdflite.pdf_dictionary([]))
  doc.add_object_given_number(4, PdfNull)
  let null_root : Result[@pdflite.PdfObject, Error] = try? doc.catalog()
  guard null_root is Err(@pdflite.PdfError::RootExpected) else {
    fail("expected RootExpected for null catalog")
  }
}

///|
test "PdfDocument object helpers delegate to document object state" {
  let doc = @pdflite.pdf_document_empty()
  let first = doc.add_object(PdfInteger(1))
  let second = doc.add_object(PdfInteger(2), generation=3)
  @test.assert_eq((first, second), (1, 2))
  @test.assert_eq(doc.object_numbers(), [1, 2])
  @test.assert_eq(doc.lookup_object_or_null(2), PdfInteger(2))
  doc.remove_object(first)
  @test.assert_eq(doc.object_numbers(), [2])
  @test.assert_eq(doc.event_log(), [
    (1, ObjectAltered),
    (2, ObjectAltered),
    (1, ObjectDeleted),
  ])
}

///|
test "PdfDocument select_object_numbers filters sorted parsed objects" {
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(
    3,
    PdfString(try! @pdflite.pdf_bytes_of_int_array([65])),
  )
  doc.add_object_given_number(1, PdfInteger(10))
  doc.add_object_given_number(2, PdfNull)
  @test.assert_eq(
    doc.select_object_numbers(fn(object) { object is PdfInteger(_) }),
    [1],
  )
  @test.assert_eq(doc.select_object_numbers(fn(object) { object == PdfNull }), [
    2,
  ])
}

///|
test "PdfDocument map_objects_in_place updates document objects" {
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(1, PdfInteger(10))
  doc.add_object_given_number(2, PdfBoolean(true))
  doc.map_objects_in_place(fn(object) {
    match object {
      PdfInteger(value) => PdfInteger(value * 2)
      _ => object
    }
  })
  @test.assert_eq(doc.lookup_object_or_null(1), PdfInteger(20))
  @test.assert_eq(doc.lookup_object_or_null(2), PdfBoolean(true))
}

///|
test "PdfDocument parsed_object_entries delegates sorted parsed entries" {
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(4, PdfInteger(40), generation=2)
  doc.add_object_given_number(1, PdfInteger(10), generation=3)
  @test.assert_eq(doc.parsed_object_entries(), [
    (1, 3, PdfInteger(10)),
    (4, 2, PdfInteger(40)),
  ])
}

///|
test "PdfDocument copy preserves metadata and separates object map state" {
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 6)
  doc.set_root(4)
  doc.set_was_linearized(true)
  doc.set_first_xref(256)
  doc.set_revision_read(3)
  doc.add_object_given_number(4, PdfDictionary([]), generation=2)
  doc.set_trailer_dict(
    PdfDictionary([
      (@pdflite.pdf_name_of_bytes(@ascii.encode("/Root")), PdfIndirect(4)),
    ]),
  )
  let copied = doc.copy()
  @test.assert_eq(copied.version(), (1, 6))
  @test.assert_eq(copied.root(), 4)
  @test.assert_eq(copied.was_linearized(), true)
  @test.assert_eq(copied.first_xref(), 256)
  @test.assert_eq(copied.revision_read(), 3)
  @test.assert_eq(copied.trailer_dict(), doc.trailer_dict())
  @test.assert_eq(copied.lookup_object_or_null(4), PdfDictionary([]))
  copied.add_object_given_number(9, PdfInteger(9))
  copied.remove_object(4)
  @test.assert_eq(doc.object_numbers(), [4])
  @test.assert_eq(copied.object_numbers(), [9])
}

///|
test "PdfDocument renumber_objects_by_offset moves objects and rewrites references" {
  let key_root = @pdflite.pdf_name_of_bytes(@ascii.encode("/Root"))
  let key_pages = @pdflite.pdf_name_of_bytes(@ascii.encode("/Pages"))
  let key_parent = @pdflite.pdf_name_of_bytes(@ascii.encode("/Parent"))
  let doc = @pdflite.pdf_document_empty()
  doc.set_root(1)
  doc.set_trailer_dict(PdfDictionary([(key_root, PdfIndirect(1))]))
  doc.add_object_given_number(1, PdfDictionary([(key_pages, PdfIndirect(2))]))
  doc.add_object_given_number(2, PdfDictionary([(key_parent, PdfIndirect(1))]))
  let renumbered = try! doc.renumber_objects_by_offset(10)
  @test.assert_eq(doc.object_numbers(), [1, 2])
  @test.assert_eq(renumbered.object_numbers(), [11, 12])
  @test.assert_eq(renumbered.root(), 11)
  @test.assert_eq(
    renumbered.trailer_dict().lookup_immediate(key_root),
    Some(PdfIndirect(11)),
  )
  @test.assert_eq(
    renumbered.lookup_object_or_null(11).lookup_immediate(key_pages),
    Some(PdfIndirect(12)),
  )
  @test.assert_eq(
    renumbered.lookup_object_or_null(12).lookup_immediate(key_parent),
    Some(PdfIndirect(11)),
  )
  @test.assert_eq(renumbered.lookup_object_or_null(1), PdfNull)
}

///|
test "PdfDocument renumber_objects_by_offset rejects negative offsets" {
  let doc = @pdflite.pdf_document_empty()
  let result : Result[@pdflite.PdfDocument, Error] = try? doc.renumber_objects_by_offset(
    -1,
  )
  guard result is Err(@pdflite.PdfError::InvalidObjectNumber(-1)) else {
    fail("expected InvalidObjectNumber")
  }
}
