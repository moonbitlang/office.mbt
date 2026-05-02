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
test "pdf_objects_of_entries derives max object number without event log" {
  let objects = @pdflite.pdf_objects_of_entries([
    (5, @pdflite.pdf_object_entry(ObjectParsed(PdfInteger(50)), generation=2)),
    (
      1,
      @pdflite.pdf_object_entry(
        ObjectParsedAlreadyDecrypted(PdfInteger(10)),
        generation=3,
      ),
    ),
  ])
  @test.assert_eq(objects.max_object_number(), 5)
  @test.assert_eq(objects.object_numbers(), [1, 5])
  @test.assert_eq(objects.lookup_object_or_null(5), PdfInteger(50))
  @test.assert_eq(objects.log(), [])
  guard objects.get_entry(1)
    is Some(
      { data: ObjectParsedAlreadyDecrypted(PdfInteger(10)), generation: 3 }
    ) else {
    fail("expected parsed state and generation to be preserved")
  }
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
test "PdfObjects stream_entries returns sorted parsed stream objects" {
  let objects = @pdflite.pdf_objects_empty()
  let first_stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([]),
    StreamGot(try! @pdflite.pdf_bytes_of_int_array([65])),
  )
  let second_stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([]),
    StreamGot(try! @pdflite.pdf_bytes_of_int_array([66])),
  )
  objects.set_entry(
    3,
    @pdflite.pdf_object_entry(ObjectParsed(first_stream), generation=2),
  )
  objects.set_entry(
    1,
    @pdflite.pdf_object_entry(ObjectParsed(PdfInteger(10)), generation=9),
  )
  objects.set_entry(
    2,
    @pdflite.pdf_object_entry(
      ObjectParsedAlreadyDecrypted(second_stream),
      generation=4,
    ),
  )
  guard first_stream is PdfStreamObject(first) else {
    fail("expected stream object")
  }
  guard second_stream is PdfStreamObject(second) else {
    fail("expected stream object")
  }
  @test.assert_eq(objects.stream_entries(), [(2, 4, second), (3, 2, first)])
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
test "PdfDocument stream_object_entries delegates stream entries" {
  let doc = @pdflite.pdf_document_empty()
  let stream_object = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([]),
    StreamGot(try! @pdflite.pdf_bytes_of_int_array([65])),
  )
  doc.add_object_given_number(7, stream_object, generation=2)
  doc.add_object_given_number(1, PdfInteger(10))
  guard stream_object is PdfStreamObject(stream) else {
    fail("expected stream object")
  }
  @test.assert_eq(doc.stream_object_entries(), [(7, 2, stream)])
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
test "PdfDocument copy deep-copies mutable object containers and streams" {
  let key_root = @pdflite.pdf_name_of_bytes(@ascii.encode("/Root"))
  let key_length = @pdflite.pdf_name_of_bytes(@ascii.encode("/Length"))
  let key_initial = @pdflite.pdf_name_of_bytes(@ascii.encode("/Initial"))
  let key_added = @pdflite.pdf_name_of_bytes(@ascii.encode("/Added"))
  let doc = @pdflite.pdf_document_empty()
  let stream_object : @pdflite.PdfObject = @pdflite.pdf_stream(
    PdfDictionary([(key_length, PdfInteger(1))]),
    StreamGot(try! @pdflite.pdf_bytes_of_int_array([65])),
  )
  doc.add_object_given_number(
    1,
    PdfArray([PdfDictionary([(key_initial, PdfInteger(1))]), stream_object]),
  )
  doc.add_object_given_number(
    2,
    @pdflite.pdf_stream(
      PdfDictionary([]),
      StreamToGet(
        @pdflite.stream_to_get(
          @pdflite.byte_cursor_of_bytes(
            try! @pdflite.pdf_bytes_of_int_array([65, 66, 67]),
          ),
          1,
          2,
        ),
      ),
    ),
  )
  doc.set_trailer_dict(PdfDictionary([(key_root, PdfArray([PdfIndirect(1)]))]))
  let copied = doc.copy()
  guard copied.lookup_object_or_null(1) is PdfArray(copied_values) else {
    fail("expected copied array")
  }
  guard doc.lookup_object_or_null(1) is PdfArray(original_values) else {
    fail("expected original array")
  }
  copied_values.push(PdfInteger(99))
  @test.assert_eq(original_values.length(), 2)
  guard copied_values[0] is PdfDictionary(copied_nested_entries) else {
    fail("expected copied nested dictionary")
  }
  copied_nested_entries.push((key_added, PdfInteger(2)))
  @test.assert_eq(original_values[0].lookup_immediate(key_added), None)
  ignore(try! copied_values[1].add_dict_entry(key_added, PdfInteger(3)))
  @test.assert_eq(original_values[1].lookup_immediate(key_added), None)
  guard copied.trailer_dict() is PdfDictionary(copied_trailer_entries) else {
    fail("expected copied trailer dictionary")
  }
  copied_trailer_entries.push((key_added, PdfInteger(4)))
  @test.assert_eq(doc.trailer_dict().lookup_immediate(key_added), None)
  @test.assert_eq(
    try! copied.lookup_object_or_null(2).stream_bytes(),
    try! @pdflite.pdf_bytes_of_int_array([66, 67]),
  )
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
test "PdfDocument renumber_objects_compact packs sparse object numbers" {
  let key_root = @pdflite.pdf_name_of_bytes(@ascii.encode("/Root"))
  let key_pages = @pdflite.pdf_name_of_bytes(@ascii.encode("/Pages"))
  let key_parent = @pdflite.pdf_name_of_bytes(@ascii.encode("/Parent"))
  let doc = @pdflite.pdf_document_empty()
  doc.set_root(10)
  doc.set_trailer_dict(PdfDictionary([(key_root, PdfIndirect(10))]))
  doc.add_object_given_number(10, PdfDictionary([(key_pages, PdfIndirect(20))]))
  doc.add_object_given_number(
    20,
    PdfDictionary([(key_parent, PdfIndirect(10))]),
  )
  doc.add_object_given_number(40, PdfString(@ascii.encode("detached")))
  let renumbered = try! doc.renumber_objects_compact()
  @test.assert_eq(doc.object_numbers(), [10, 20, 40])
  @test.assert_eq(renumbered.object_numbers(), [1, 2, 3])
  @test.assert_eq(renumbered.root(), 1)
  @test.assert_eq(renumbered.event_log(), [])
  @test.assert_eq(
    renumbered.trailer_dict().lookup_immediate(key_root),
    Some(PdfIndirect(1)),
  )
  @test.assert_eq(
    renumbered.lookup_object_or_null(1).lookup_immediate(key_pages),
    Some(PdfIndirect(2)),
  )
  @test.assert_eq(
    renumbered.lookup_object_or_null(2).lookup_immediate(key_parent),
    Some(PdfIndirect(1)),
  )
}

///|
test "PdfDocument renumber_objects applies explicit change table" {
  let key_root = @pdflite.pdf_name_of_bytes(@ascii.encode("/Root"))
  let key_next = @pdflite.pdf_name_of_bytes(@ascii.encode("/Next"))
  let doc = @pdflite.pdf_document_empty()
  doc.set_root(10)
  doc.set_trailer_dict(PdfDictionary([(key_root, PdfIndirect(10))]))
  doc.add_object_given_number(10, PdfDictionary([(key_next, PdfIndirect(20))]))
  doc.add_object_given_number(20, PdfArray([PdfIndirect(10), PdfIndirect(99)]))
  let renumbered = try! doc.renumber_objects([(10, 5), (20, 6)])
  @test.assert_eq(renumbered.object_numbers(), [5, 6])
  @test.assert_eq(renumbered.root(), 5)
  @test.assert_eq(
    renumbered.lookup_object_or_null(5).lookup_immediate(key_next),
    Some(PdfIndirect(6)),
  )
  @test.assert_eq(
    renumbered.lookup_object_or_null(6),
    PdfArray([PdfIndirect(5), PdfIndirect(99)]),
  )
  let duplicate : Result[@pdflite.PdfDocument, Error] = try? doc.renumber_objects([
      (10, 5),
      (20, 5),
    ],
  )
  guard duplicate is Err(@pdflite.PdfError::InvalidObjectNumber(5)) else {
    fail("expected duplicate target to be rejected")
  }
}

///|
test "pdf_renumber_documents gives documents disjoint compact ranges" {
  let key_root = @pdflite.pdf_name_of_bytes(@ascii.encode("/Root"))
  let key_peer = @pdflite.pdf_name_of_bytes(@ascii.encode("/Peer"))
  let first = @pdflite.pdf_document_empty()
  first.set_root(10)
  first.set_trailer_dict(PdfDictionary([(key_root, PdfIndirect(10))]))
  first.add_object_given_number(
    10,
    PdfDictionary([(key_peer, PdfIndirect(20))]),
  )
  first.add_object_given_number(20, PdfInteger(20))
  let second = @pdflite.pdf_document_empty()
  second.set_root(7)
  second.set_trailer_dict(PdfDictionary([(key_root, PdfIndirect(7))]))
  second.add_object_given_number(
    7,
    PdfDictionary([(key_peer, PdfIndirect(30))]),
  )
  second.add_object_given_number(30, PdfInteger(30))
  let renumbered = try! @pdflite.pdf_renumber_documents([first, second])
  @test.assert_eq(renumbered.length(), 2)
  @test.assert_eq(renumbered[0].object_numbers(), [1, 2])
  @test.assert_eq(renumbered[0].root(), 1)
  @test.assert_eq(
    renumbered[0].lookup_object_or_null(1).lookup_immediate(key_peer),
    Some(PdfIndirect(2)),
  )
  @test.assert_eq(renumbered[1].object_numbers(), [3, 4])
  @test.assert_eq(renumbered[1].root(), 3)
  @test.assert_eq(
    renumbered[1].lookup_object_or_null(3).lookup_immediate(key_peer),
    Some(PdfIndirect(4)),
  )
  @test.assert_eq(first.object_numbers(), [10, 20])
  @test.assert_eq(second.object_numbers(), [7, 30])
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
