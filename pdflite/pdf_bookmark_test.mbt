///|
fn bookmark_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn bookmark_bytes_for_test(text : String) -> @pdflite.PdfBytes {
  @ascii.encode(text)
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
