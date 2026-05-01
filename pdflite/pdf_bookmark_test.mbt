///|
fn bookmark_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn bookmark_bytes_for_test(text : String) -> @pdflite.PdfBytes {
  @ascii.encode(text)
}

///|
fn bookmark_bytes_from_ints_for_test(
  values : ArrayView[Int],
) -> @pdflite.PdfBytes {
  try! @pdflite.pdf_bytes_of_int_array(values)
}

///|
fn bookmark_colour_for_test(
  red : Double,
  green : Double,
  blue : Double,
) -> @pdflite.PdfBookmarkColour {
  { red, green, blue }
}

///|
fn bookmark_document_for_test() -> @pdflite.PdfDocument {
  let key_type = bookmark_name_for_test("/Type")
  let key_outlines = bookmark_name_for_test("/Outlines")
  let key_first = bookmark_name_for_test("/First")
  let key_next = bookmark_name_for_test("/Next")
  let key_title = bookmark_name_for_test("/Title")
  let key_dest = bookmark_name_for_test("/Dest")
  let key_action = bookmark_name_for_test("/A")
  let key_s = bookmark_name_for_test("/S")
  let key_d = bookmark_name_for_test("/D")
  let key_count = bookmark_name_for_test("/Count")
  let key_colour = bookmark_name_for_test("/C")
  let key_flags = bookmark_name_for_test("/F")
  let type_catalog = bookmark_name_for_test("/Catalog")
  let doc = @pdflite.pdf_document_empty()
  doc.set_root(1)
  doc.add_object_given_number(
    1,
    PdfDictionary([
      (key_type, PdfNameObject(type_catalog)),
      (key_outlines, PdfIndirect(2)),
    ]),
  )
  doc.add_object_given_number(2, PdfDictionary([(key_first, PdfIndirect(3))]))
  doc.add_object_given_number(
    3,
    PdfDictionary([
      (key_title, PdfString(bookmark_bytes_for_test("Top"))),
      (
        key_dest,
        PdfArray([
          PdfIndirect(10),
          PdfNameObject(bookmark_name_for_test("/Fit")),
        ]),
      ),
      (key_first, PdfIndirect(4)),
      (key_count, PdfInteger(2)),
      (key_colour, PdfArray([PdfReal(0.1), PdfReal(0.2), PdfReal(0.3)])),
      (key_flags, PdfInteger(2)),
    ]),
  )
  doc.add_object_given_number(
    4,
    PdfDictionary([
      (key_title, PdfString(bookmark_bytes_for_test("Child"))),
      (
        key_action,
        PdfDictionary([
          (key_s, PdfNameObject(bookmark_name_for_test("/GoTo"))),
          (
            key_d,
            PdfArray([
              PdfIndirect(11),
              PdfNameObject(bookmark_name_for_test("/XYZ")),
              PdfInteger(1),
              PdfInteger(2),
              PdfNull,
            ]),
          ),
        ]),
      ),
      (key_next, PdfIndirect(5)),
    ]),
  )
  doc.add_object_given_number(
    5,
    PdfDictionary([
      (key_title, PdfString(bookmark_bytes_for_test("Sibling"))),
      (key_dest, PdfString(bookmark_bytes_for_test("named"))),
    ]),
  )
  doc
}

///|
fn bookmark_single_outline_doc_for_test(
  outline : @pdflite.PdfObject,
) -> @pdflite.PdfDocument {
  let key_type = bookmark_name_for_test("/Type")
  let key_outlines = bookmark_name_for_test("/Outlines")
  let key_first = bookmark_name_for_test("/First")
  let type_catalog = bookmark_name_for_test("/Catalog")
  let doc = @pdflite.pdf_document_empty()
  doc.set_root(1)
  doc.add_object_given_number(
    1,
    PdfDictionary([
      (key_type, PdfNameObject(type_catalog)),
      (key_outlines, PdfIndirect(2)),
    ]),
  )
  doc.add_object_given_number(2, PdfDictionary([(key_first, PdfIndirect(3))]))
  doc.add_object_given_number(3, outline)
  doc
}

///|
test "pdf_string_of_bookmark renders CamlPDF debug line as bytes" {
  let bookmark : @pdflite.PdfBookmark = {
    level: 1,
    text: bookmark_bytes_from_ints_for_test([65, 0xFF]),
    target: DestFit(TargetPageObject(7)),
    is_open: true,
    colour: @pdflite.pdf_bookmark_black,
    flags: 0,
  }
  @test.assert_eq(
    try! @pdflite.pdf_string_of_bookmark(bookmark),
    bookmark_bytes_from_ints_for_test([
      49, 32, 65, 255, 32, 91, 55, 32, 48, 32, 82, 32, 47, 70, 105, 116, 93, 32,
      116, 114, 117, 101, 10,
    ]),
  )
}

///|
test "PdfDocument read_bookmarks traverses outline trees" {
  let doc = bookmark_document_for_test()
  @test.assert_eq(try! doc.read_bookmarks(), [
    {
      level: 0,
      text: bookmark_bytes_for_test("Top"),
      target: DestFit(TargetPageObject(10)),
      is_open: true,
      colour: bookmark_colour_for_test(0.1, 0.2, 0.3),
      flags: 2,
    },
    {
      level: 1,
      text: bookmark_bytes_for_test("Child"),
      target: DestXYZ(TargetPageObject(11), Some(1.0), Some(2.0), None),
      is_open: false,
      colour: @pdflite.pdf_bookmark_black,
      flags: 0,
    },
    {
      level: 1,
      text: bookmark_bytes_for_test("Sibling"),
      target: DestString(bookmark_bytes_for_test("named")),
      is_open: false,
      colour: @pdflite.pdf_bookmark_black,
      flags: 0,
    },
  ])
}

///|
test "PdfDocument read_bookmarks handles preserved destinations and fallback fields" {
  let key_title = bookmark_name_for_test("/Title")
  let key_dest = bookmark_name_for_test("/Dest")
  let key_action = bookmark_name_for_test("/A")
  let key_s = bookmark_name_for_test("/S")
  let key_d = bookmark_name_for_test("/D")
  let key_colour = bookmark_name_for_test("/C")
  let doc = bookmark_single_outline_doc_for_test(
    PdfDictionary([
      (key_dest, PdfString(bookmark_bytes_for_test("named"))),
      (
        key_colour,
        PdfArray([
          PdfNameObject(bookmark_name_for_test("/Bad")),
          PdfReal(0.2),
          PdfReal(0.3),
        ]),
      ),
    ]),
  )
  let bookmark = (try! doc.read_bookmarks(preserve_actions=true))[0]
  @test.assert_eq(bookmark.text, bookmark_bytes_for_test(""))
  @test.assert_eq(bookmark.target, DestString(bookmark_bytes_for_test("named")))
  @test.assert_eq(bookmark.colour, @pdflite.pdf_bookmark_black)
  let action_with_dest : @pdflite.PdfObject = PdfDictionary([
    (
      key_d,
      PdfArray([PdfIndirect(7), PdfNameObject(bookmark_name_for_test("/Fit"))]),
    ),
  ])
  let doc = bookmark_single_outline_doc_for_test(
    PdfDictionary([
      (key_title, PdfString(bookmark_bytes_for_test("ActionDest"))),
      (key_action, action_with_dest),
    ]),
  )
  @test.assert_eq(
    (try! doc.read_bookmarks(preserve_actions=true))[0].target,
    DestFit(TargetPageObject(7)),
  )
  let action_without_dest : @pdflite.PdfObject = PdfDictionary([
    (key_s, PdfNameObject(bookmark_name_for_test("/URI"))),
  ])
  let doc = bookmark_single_outline_doc_for_test(
    PdfDictionary([
      (key_title, PdfString(bookmark_bytes_for_test("Action"))),
      (key_action, action_without_dest),
    ]),
  )
  @test.assert_eq(
    (try! doc.read_bookmarks())[0].target,
    DestAction(action_without_dest),
  )
}

///|
test "PdfDocument read_bookmarks can preserve non-array actions" {
  let key_type = bookmark_name_for_test("/Type")
  let key_outlines = bookmark_name_for_test("/Outlines")
  let key_first = bookmark_name_for_test("/First")
  let key_title = bookmark_name_for_test("/Title")
  let key_action = bookmark_name_for_test("/A")
  let key_s = bookmark_name_for_test("/S")
  let key_d = bookmark_name_for_test("/D")
  let type_catalog = bookmark_name_for_test("/Catalog")
  let doc = @pdflite.pdf_document_empty()
  let action : @pdflite.PdfObject = PdfDictionary([
    (key_s, PdfNameObject(bookmark_name_for_test("/GoTo"))),
    (key_d, PdfString(bookmark_bytes_for_test("named"))),
  ])
  doc.set_root(1)
  doc.add_object_given_number(
    1,
    PdfDictionary([
      (key_type, PdfNameObject(type_catalog)),
      (key_outlines, PdfIndirect(2)),
    ]),
  )
  doc.add_object_given_number(2, PdfDictionary([(key_first, PdfIndirect(3))]))
  doc.add_object_given_number(
    3,
    PdfDictionary([
      (key_title, PdfString(bookmark_bytes_for_test("Action"))),
      (key_action, action),
    ]),
  )
  @test.assert_eq(
    (try! doc.read_bookmarks())[0].target,
    DestString(bookmark_bytes_for_test("named")),
  )
  @test.assert_eq(
    (try! doc.read_bookmarks(preserve_actions=true))[0].target,
    DestAction(action),
  )
}

///|
test "PdfDocument read_bookmarks requires a root catalog" {
  let doc = @pdflite.pdf_document_empty()
  let result : Result[Array[@pdflite.PdfBookmark], Error] = try? doc.read_bookmarks()
  guard result is Err(@pdflite.PdfError::RootExpected) else {
    fail("expected RootExpected")
  }
}

///|
test "PdfDocument read_bookmarks returns empty without outlines" {
  let key_type = bookmark_name_for_test("/Type")
  let type_catalog = bookmark_name_for_test("/Catalog")
  let doc = @pdflite.pdf_document_empty()
  doc.set_root(1)
  doc.add_object_given_number(
    1,
    PdfDictionary([(key_type, PdfNameObject(type_catalog))]),
  )
  @test.assert_eq(try! doc.read_bookmarks(), [])
}

///|
test "PdfDocument remove_bookmarks installs a catalog without outlines" {
  let key_root = bookmark_name_for_test("/Root")
  let doc = bookmark_document_for_test()
  doc.set_trailer_dict(PdfDictionary([(key_root, PdfIndirect(doc.root()))]))
  let stripped = try! doc.remove_bookmarks()
  @test.assert_eq((try! doc.read_bookmarks()).length(), 3)
  @test.assert_eq(try! stripped.read_bookmarks(), [])
  @test.assert_eq(stripped.root(), 6)
  @test.assert_eq(
    stripped.trailer_dict().lookup_immediate(key_root),
    Some(PdfIndirect(6)),
  )
}

///|
test "PdfDocument remove_bookmarks requires a root catalog" {
  let doc = @pdflite.pdf_document_empty()
  let result : Result[@pdflite.PdfDocument, Error] = try? doc.remove_bookmarks()
  guard result is Err(@pdflite.PdfError::RootExpected) else {
    fail("expected RootExpected")
  }
}

///|
test "PdfDocument add_bookmarks builds linked outline objects" {
  let key_root = bookmark_name_for_test("/Root")
  let key_type = bookmark_name_for_test("/Type")
  let key_outlines = bookmark_name_for_test("/Outlines")
  let key_first = bookmark_name_for_test("/First")
  let key_last = bookmark_name_for_test("/Last")
  let key_next = bookmark_name_for_test("/Next")
  let key_prev = bookmark_name_for_test("/Prev")
  let key_parent = bookmark_name_for_test("/Parent")
  let key_count = bookmark_name_for_test("/Count")
  let key_action = bookmark_name_for_test("/A")
  let key_s = bookmark_name_for_test("/S")
  let type_catalog = bookmark_name_for_test("/Catalog")
  let doc = @pdflite.pdf_document_empty()
  doc.set_root(1)
  doc.set_trailer_dict(PdfDictionary([(key_root, PdfIndirect(1))]))
  doc.add_object_given_number(
    1,
    PdfDictionary([(key_type, PdfNameObject(type_catalog))]),
  )
  let action : @pdflite.PdfObject = PdfDictionary([
    (key_s, PdfNameObject(bookmark_name_for_test("/URI"))),
  ])
  let bookmarks : Array[@pdflite.PdfBookmark] = [
    {
      level: 0,
      text: bookmark_bytes_for_test("Top"),
      target: DestFit(TargetPageObject(10)),
      is_open: true,
      colour: bookmark_colour_for_test(0.4, 0.5, 0.6),
      flags: 2,
    },
    {
      level: 1,
      text: bookmark_bytes_for_test("Child"),
      target: DestXYZ(TargetPageObject(11), Some(1.0), Some(2.0), None),
      is_open: false,
      colour: @pdflite.pdf_bookmark_black,
      flags: 0,
    },
    {
      level: 0,
      text: bookmark_bytes_for_test("Closed"),
      target: DestNull,
      is_open: false,
      colour: @pdflite.pdf_bookmark_black,
      flags: 0,
    },
    {
      level: 1,
      text: bookmark_bytes_for_test("Hidden"),
      target: DestAction(action),
      is_open: false,
      colour: @pdflite.pdf_bookmark_black,
      flags: 0,
    },
  ]
  let updated = try! doc.add_bookmarks(bookmarks)
  @test.assert_eq(try! doc.read_bookmarks(), [])
  @test.assert_eq(try! updated.read_bookmarks(preserve_actions=true), bookmarks)
  @test.assert_eq(updated.root(), 7)
  let catalog = updated.lookup_object_or_null(updated.root())
  @test.assert_eq(catalog.lookup_immediate(key_outlines), Some(PdfIndirect(6)))
  let outline_root = updated.lookup_object_or_null(6)
  @test.assert_eq(
    outline_root.lookup_immediate(key_first),
    Some(PdfIndirect(2)),
  )
  @test.assert_eq(outline_root.lookup_immediate(key_last), Some(PdfIndirect(4)))
  @test.assert_eq(outline_root.lookup_immediate(key_count), Some(PdfInteger(3)))
  let top = updated.lookup_object_or_null(2)
  @test.assert_eq(top.lookup_immediate(key_parent), Some(PdfIndirect(6)))
  @test.assert_eq(top.lookup_immediate(key_first), Some(PdfIndirect(3)))
  @test.assert_eq(top.lookup_immediate(key_last), Some(PdfIndirect(3)))
  @test.assert_eq(top.lookup_immediate(key_next), Some(PdfIndirect(4)))
  @test.assert_eq(top.lookup_immediate(key_count), Some(PdfInteger(1)))
  let closed = updated.lookup_object_or_null(4)
  @test.assert_eq(closed.lookup_immediate(key_parent), Some(PdfIndirect(6)))
  @test.assert_eq(closed.lookup_immediate(key_prev), Some(PdfIndirect(2)))
  @test.assert_eq(closed.lookup_immediate(key_first), Some(PdfIndirect(5)))
  @test.assert_eq(closed.lookup_immediate(key_last), Some(PdfIndirect(5)))
  @test.assert_eq(closed.lookup_immediate(key_count), Some(PdfInteger(-1)))
  let hidden = updated.lookup_object_or_null(5)
  @test.assert_eq(hidden.lookup_immediate(key_parent), Some(PdfIndirect(4)))
  @test.assert_eq(hidden.lookup_immediate(key_action), Some(action))
}

///|
test "PdfDocument add_bookmarks with an empty list removes outlines" {
  let doc = bookmark_document_for_test()
  let updated = try! doc.add_bookmarks([])
  @test.assert_eq(try! updated.read_bookmarks(), [])
  @test.assert_eq((try! doc.read_bookmarks()).length(), 3)
}

///|
test "PdfDocument add_bookmarks requires a root catalog" {
  let doc = @pdflite.pdf_document_empty()
  let bookmarks : Array[@pdflite.PdfBookmark] = [
    {
      level: 0,
      text: bookmark_bytes_for_test("Top"),
      target: DestNull,
      is_open: false,
      colour: @pdflite.pdf_bookmark_black,
      flags: 0,
    },
  ]
  let result : Result[@pdflite.PdfDocument, Error] = try? doc.add_bookmarks(
    bookmarks,
  )
  guard result is Err(@pdflite.PdfError::RootExpected) else {
    fail("expected RootExpected")
  }
}

///|
test "PdfDocument transform_bookmark transforms bookmark target" {
  let doc = @pdflite.pdf_document_empty()
  let bookmark : @pdflite.PdfBookmark = {
    level: 0,
    text: bookmark_bytes_for_test("Top"),
    target: DestFitH(TargetPageObject(7), Some(5.0)),
    is_open: false,
    colour: @pdflite.pdf_bookmark_black,
    flags: 0,
  }
  @test.assert_eq(
    try! doc.transform_bookmark(
      @pdflite.transform_translate(10.0, 20.0),
      bookmark,
    ),
    { ..bookmark, target: DestFitH(TargetPageObject(7), Some(25.0)) },
  )
}
