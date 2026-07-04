///|
fn bookmark_name_for_test(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn bookmark_bytes_for_test(text : String) -> @core.PdfBytes {
  @ascii.encode(text)
}

///|
fn bookmark_bytes_from_ints_for_test(values : ArrayView[Int]) -> @core.PdfBytes {
  try! @core.pdf_bytes_of_int_array(values)
}

///|
fn bookmark_join_bytes_for_test(
  parts : ArrayView[@core.PdfBytes],
) -> @core.PdfBytes {
  let output : Array[Byte] = []
  for part in parts {
    for byte in part {
      output.push(byte)
    }
  }
  Bytes::from_array(output)
}

///|
fn bookmark_json_int_for_test(value : Int) -> Json {
  Json::number(value.to_double(), repr=value.to_string())
}

///|
fn bookmark_json_pdf_int_for_test(value : Int) -> Json {
  Json::object(Map([("I", bookmark_json_int_for_test(value))]))
}

///|
fn bookmark_json_name_for_test(name : String) -> Json {
  Json::object(Map([("N", Json::string(name))]))
}

///|
fn bookmark_colour_for_test(
  red : Double,
  green : Double,
  blue : Double,
) -> @bookmark.PdfBookmarkColour {
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
  let key_root = bookmark_name_for_test("/Root")
  let type_catalog = bookmark_name_for_test("/Catalog")
  let doc = @pdflite.pdf_document_empty()
  doc.set_root(1)
  doc.set_trailer_dict(PdfDictionary([(key_root, PdfIndirect(1))]))
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
fn bookmark_listing_document_for_test() -> @pdflite.PdfDocument raise {
  let document = try! @pdflite.pdf_blank_document(100.0, 100.0, 2)
  let page_refs = try! document.page_reference_numbers()
  let bookmarks : Array[@bookmark.PdfBookmark] = [
    {
      level: 0,
      text: bookmark_bytes_for_test("Top\nQuote\""),
      target: DestFit(TargetPageObject(page_refs[0])),
      is_open: true,
      colour: bookmark_colour_for_test(0.1, 0.2, 0.3),
      flags: 2,
    },
    {
      level: 1,
      text: bookmark_bytes_for_test("Child"),
      target: DestXYZ(
        TargetPageObject(page_refs[1]),
        Some(1.0),
        Some(2.0),
        None,
      ),
      is_open: false,
      colour: @bookmark.pdf_bookmark_black,
      flags: 1,
    },
    {
      level: 0,
      text: bookmark_bytes_for_test("Named"),
      target: DestString(bookmark_bytes_for_test("named")),
      is_open: false,
      colour: @bookmark.pdf_bookmark_black,
      flags: 0,
    },
  ]
  document.add_bookmarks(bookmarks)
}

///|
fn bookmark_single_outline_doc_for_test(
  outline : @syntax.PdfObject,
) -> @pdflite.PdfDocument {
  let key_type = bookmark_name_for_test("/Type")
  let key_outlines = bookmark_name_for_test("/Outlines")
  let key_first = bookmark_name_for_test("/First")
  let key_root = bookmark_name_for_test("/Root")
  let type_catalog = bookmark_name_for_test("/Catalog")
  let doc = @pdflite.pdf_document_empty()
  doc.set_root(1)
  doc.set_trailer_dict(PdfDictionary([(key_root, PdfIndirect(1))]))
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
  let bookmark : @bookmark.PdfBookmark = {
    level: 1,
    text: bookmark_bytes_from_ints_for_test([65, 0xFF]),
    target: DestFit(TargetPageObject(7)),
    is_open: true,
    colour: @bookmark.pdf_bookmark_black,
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
test "PdfDocument list_bookmarks renders selected cpdf bookmark lines" {
  let document = try! bookmark_listing_document_for_test()
  let expected = bookmark_join_bytes_for_test([
    @ascii.encode("0 \"Top\\nQuote\\\"\" 1 open \""),
    try! @pdflite.pdf_write_object(
      PdfArray([PdfInteger(1), PdfNameObject(bookmark_name_for_test("/Fit"))]),
    ),
    @ascii.encode("\"\n0 \"Named\" 0 \""),
    try! @pdflite.pdf_write_object(PdfString(bookmark_bytes_for_test("named"))),
    @ascii.encode("\"\n"),
  ])
  @test.assert_eq(
    try! document.list_bookmarks([1], encoding=PdfMetadataUTF8),
    expected,
  )
  @test.assert_eq(
    try! @pdflite.pdf_list_bookmarks(
      false,
      false,
      PdfMetadataUTF8,
      [1],
      document,
    ),
    expected,
  )
  let bad_page : Result[@core.PdfBytes, Error] = try
    document.list_bookmarks([3], encoding=PdfMetadataUTF8)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_page is Err(@core.PdfError::BadPageSpecification(_)) else {
    fail("expected @core.PdfError::BadPageSpecification")
  }
}

///|
test "PdfDocument list_bookmarks escapes cpdf backslash titles" {
  let document = try! @pdflite.pdf_blank_document(100.0, 100.0, 1)
  let page_refs = try! document.page_reference_numbers()
  let bookmarked = try! document.add_bookmarks([
    {
      level: 0,
      text: bookmark_bytes_for_test("Slash\\Marker"),
      target: DestFit(TargetPageObject(page_refs[0])),
      is_open: false,
      colour: @bookmark.pdf_bookmark_black,
      flags: 0,
    },
  ])
  let expected = bookmark_join_bytes_for_test([
    @ascii.encode("0 \"Slash\\\\Marker\" 1 \""),
    try! @pdflite.pdf_write_object(
      PdfArray([PdfInteger(1), PdfNameObject(bookmark_name_for_test("/Fit"))]),
    ),
    @ascii.encode("\"\n"),
  ])
  @test.assert_eq(
    try! bookmarked.list_bookmarks([1], encoding=PdfMetadataUTF8),
    expected,
  )
  @test.assert_eq(
    try! @pdflite.pdf_list_bookmarks(
      false,
      false,
      PdfMetadataUTF8,
      [1],
      bookmarked,
    ),
    expected,
  )
}

///|
test "PdfDocument list_bookmarks strips non-ASCII bookmark title bytes" {
  let document = try! @pdflite.pdf_blank_document(100.0, 100.0, 1)
  let page_refs = try! document.page_reference_numbers()
  let text = try! @pdflite.pdf_pdfdocstring_of_utf8(
    @utf8.encode("Résumé\nQuote\""),
  )
  let bookmarked = try! document.add_bookmarks([
    {
      level: 0,
      text,
      target: DestFit(TargetPageObject(page_refs[0])),
      is_open: false,
      colour: @bookmark.pdf_bookmark_black,
      flags: 0,
    },
  ])
  let expected = bookmark_join_bytes_for_test([
    @ascii.encode("0 \"Rsum\\nQuote\\\"\" 1 \""),
    try! @pdflite.pdf_write_object(
      PdfArray([PdfInteger(1), PdfNameObject(bookmark_name_for_test("/Fit"))]),
    ),
    @ascii.encode("\"\n"),
  ])
  @test.assert_eq(
    try! bookmarked.list_bookmarks([1], encoding=PdfMetadataStripped),
    expected,
  )
}

///|
test "PdfDocument bookmarks_json exports cpdf bookmark rows" {
  let document = try! bookmark_listing_document_for_test()
  let top_row = Json::object(
    Map([
      ("level", bookmark_json_int_for_test(0)),
      ("text", Json::string("Top\nQuote\"")),
      ("page", bookmark_json_int_for_test(1)),
      ("open", Json::boolean(true)),
      (
        "target",
        Json::array([
          bookmark_json_pdf_int_for_test(1),
          bookmark_json_name_for_test("/Fit"),
        ]),
      ),
      (
        "colour",
        Json::array([Json::number(0.1), Json::number(0.2), Json::number(0.3)]),
      ),
      ("italic", Json::boolean(false)),
      ("bold", Json::boolean(true)),
    ]),
  )
  let child_row = Json::object(
    Map([
      ("level", bookmark_json_int_for_test(1)),
      ("text", Json::string("Child")),
      ("page", bookmark_json_int_for_test(2)),
      ("open", Json::boolean(false)),
      (
        "target",
        Json::array([
          bookmark_json_pdf_int_for_test(2),
          bookmark_json_name_for_test("/XYZ"),
          Json::object(Map([("F", Json::number(1.0))])),
          Json::object(Map([("F", Json::number(2.0))])),
          Json::null(),
        ]),
      ),
      (
        "colour",
        Json::array([Json::number(0.0), Json::number(0.0), Json::number(0.0)]),
      ),
      ("italic", Json::boolean(true)),
      ("bold", Json::boolean(false)),
    ]),
  )
  let named_row = Json::object(
    Map([
      ("level", bookmark_json_int_for_test(0)),
      ("text", Json::string("Named")),
      ("page", bookmark_json_int_for_test(0)),
      ("open", Json::boolean(false)),
      ("target", Json::string("named")),
      (
        "colour",
        Json::array([Json::number(0.0), Json::number(0.0), Json::number(0.0)]),
      ),
      ("italic", Json::boolean(false)),
      ("bold", Json::boolean(false)),
    ]),
  )
  let expected = Json::array([top_row, child_row, named_row])
  let expected_filtered = Json::array([top_row, named_row])
  @test.assert_eq(try! document.bookmarks_json(), expected)
  @test.assert_eq(
    try! @pdflite.pdf_get_bookmarks_json(false, document),
    @utf8.encode(expected.stringify()),
  )
  @test.assert_eq(
    try! document.list_bookmarks([1], json=true),
    @utf8.encode(expected_filtered.stringify()),
  )
}

///|
test "PdfDocument bookmark_name_of_spec expands cpdf filename fields" {
  let document = try! bookmark_listing_document_for_test()
  let bookmarks = try! document.read_bookmarks(preserve_actions=true)
  let spec = "sec-%%-@F-@N@-@Sxx@-@Exxx@-@B-@b4@"
  @test.assert_eq(
    try! document.bookmark_name_of_spec(
      PdfMetadataUTF8,
      bookmarks,
      0,
      spec,
      7,
      "base",
      1,
      2,
    ),
    "sec-07-base-7-01-002-TopQuote-TopQ",
  )
  @test.assert_eq(
    try! @pdflite.pdf_bookmark_name_of_spec(
      PdfMetadataUTF8,
      bookmarks,
      document,
      0,
      spec,
      7,
      "base",
      1,
      2,
    ),
    "sec-07-base-7-01-002-TopQuote-TopQ",
  )
  @test.assert_eq(
    try! @pdflite.pdf_name_of_spec(
      PdfMetadataUTF8,
      bookmarks,
      document,
      0,
      spec,
      7,
      "base",
      1,
      2,
    ),
    "sec-07-base-7-01-002-TopQuote-TopQ",
  )
  @test.assert_eq(
    try! document.bookmark_name_of_spec(
      PdfMetadataUTF8,
      bookmarks,
      0,
      "plain-%",
      123,
      "base",
      1,
      2,
    ),
    "plain-3",
  )
  let broad : Result[String, Error] = try
    document.bookmark_name_of_spec(
      PdfMetadataUTF8,
      bookmarks,
      0,
      "@Nxxxxxxxxx@",
      7,
      "base",
      1,
      2,
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard broad is Err(@core.PdfError::SoftError(_)) else {
    fail("expected @core.PdfError::SoftError")
  }
  let bad_prefix : Result[String, Error] = try
    document.bookmark_name_of_spec(
      PdfMetadataUTF8,
      bookmarks,
      0,
      "@b@",
      7,
      "base",
      1,
      2,
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_prefix is Err(@core.PdfError::SoftError(_)) else {
    fail("expected @core.PdfError::SoftError")
  }
}

///|
test "PdfDocument parse_bookmark_text reads cpdf plain text bookmarks" {
  let document = try! @pdflite.pdf_blank_document(100.0, 100.0, 2)
  let page_refs = try! document.page_reference_numbers()
  let source = @ascii.encode(
    "0 \"Top\\nQuote\\\"Slash\\\\\" 1 open \"[1 /Fit]\"\n" +
    "1 \"Child\\q\" 2 \"[1 /XYZ 10 null 2]\"\n" +
    "0 \"Named\" 0 \"(chapter)\"\n\n",
  )
  let expected : Array[@bookmark.PdfBookmark] = [
    {
      level: 0,
      text: bookmark_bytes_for_test("Top\nQuote\"Slash\\"),
      target: DestFit(TargetPageObject(page_refs[0])),
      is_open: true,
      colour: @bookmark.pdf_bookmark_black,
      flags: 0,
    },
    {
      level: 1,
      text: bookmark_bytes_for_test("Child\\q"),
      target: DestXYZ(
        TargetPageObject(page_refs[1]),
        Some(10.0),
        None,
        Some(2.0),
      ),
      is_open: false,
      colour: @bookmark.pdf_bookmark_black,
      flags: 0,
    },
    {
      level: 0,
      text: bookmark_bytes_for_test("Named"),
      target: DestString(bookmark_bytes_for_test("chapter")),
      is_open: false,
      colour: @bookmark.pdf_bookmark_black,
      flags: 0,
    },
  ]
  @test.assert_eq(try! document.parse_bookmark_text(source), expected)
  @test.assert_eq(
    try! @pdflite.pdf_parse_bookmark_text(true, source, document),
    expected,
  )
  @test.assert_eq(
    try! @pdflite.pdf_parse_bookmark_file(true, document, source),
    expected,
  )
  let updated = try! @pdflite.pdf_add_bookmarks_from_text(
    true, source, document,
  )
  @test.assert_eq(try! updated.read_bookmarks(preserve_actions=true), expected)
}

///|
test "PdfDocument parse_bookmark_text validates plain text structure" {
  let document = try! @pdflite.pdf_blank_document(100.0, 100.0, 2)
  let bad_first_level : Result[Array[@bookmark.PdfBookmark], Error] = try
    document.parse_bookmark_text(@ascii.encode("1 \"Bad\" 1\n"))
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_first_level is Err(@core.PdfError::SoftError(_)) else {
    fail("expected @core.PdfError::SoftError for first level")
  }
  let bad_jump : Result[Array[@bookmark.PdfBookmark], Error] = try
    document.parse_bookmark_text(@ascii.encode("0 \"Top\" 1\n2 \"Bad\" 1\n"))
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_jump is Err(@core.PdfError::SoftError(_)) else {
    fail("expected @core.PdfError::SoftError for level jump")
  }
  let malformed : Result[Array[@bookmark.PdfBookmark], Error] = try
    document.parse_bookmark_text(@ascii.encode("0 not-a-string 1\n"))
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard malformed is Err(@core.PdfError::SoftError(_)) else {
    fail("expected @core.PdfError::SoftError for malformed line")
  }
  let unterminated : Result[Array[@bookmark.PdfBookmark], Error] = try
    document.parse_bookmark_text(@ascii.encode("0 \"Missing end 1\n"))
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard unterminated is Err(@core.PdfError::SoftError(_)) else {
    fail("expected @core.PdfError::SoftError for unterminated string")
  }
  @test.assert_eq(
    (try! document.parse_bookmark_text(
      @ascii.encode("0 \"Top\" 1\n2 \"Allowed\" 1\n"),
      verify=false,
    )).length(),
    2,
  )
}

///|
test "PdfDocument parse_bookmark_json reads cpdf bookmark rows" {
  let document = try! @pdflite.pdf_blank_document(100.0, 100.0, 2)
  let page_refs = try! document.page_reference_numbers()
  let json = Json::array([
    Json::object(
      Map([
        ("level", bookmark_json_int_for_test(0)),
        ("text", Json::string("Top")),
        ("page", bookmark_json_int_for_test(1)),
        ("open", Json::boolean(true)),
        (
          "target",
          Json::array([
            bookmark_json_pdf_int_for_test(1),
            bookmark_json_name_for_test("/Fit"),
          ]),
        ),
        (
          "colour",
          Json::array([Json::number(0.1), Json::number(0.2), Json::number(0.3)]),
        ),
        ("italic", Json::boolean(true)),
        ("bold", Json::boolean(false)),
      ]),
    ),
    Json::object(
      Map([
        ("level", bookmark_json_int_for_test(1)),
        ("text", Json::string("Child")),
        ("page", bookmark_json_int_for_test(2)),
        ("open", Json::boolean(false)),
        (
          "target",
          Json::array([
            bookmark_json_pdf_int_for_test(2),
            bookmark_json_name_for_test("/XYZ"),
            Json::object(Map([("F", Json::number(10.0))])),
            Json::null(),
            Json::object(Map([("F", Json::number(2.0))])),
          ]),
        ),
        (
          "colour",
          Json::array([Json::number(0.0), Json::number(0.0), Json::number(0.0)]),
        ),
        ("italic", Json::boolean(false)),
        ("bold", Json::boolean(true)),
      ]),
    ),
    Json::object(
      Map([
        ("level", bookmark_json_int_for_test(0)),
        ("text", Json::string("Named")),
        ("page", bookmark_json_int_for_test(0)),
        ("open", Json::boolean(false)),
        ("target", Json::string("chapter")),
        (
          "colour",
          Json::array([Json::number(0.0), Json::number(0.0), Json::number(0.0)]),
        ),
        ("italic", Json::boolean(false)),
        ("bold", Json::boolean(false)),
      ]),
    ),
  ])
  let expected : Array[@bookmark.PdfBookmark] = [
    {
      level: 0,
      text: bookmark_bytes_for_test("Top"),
      target: DestFit(TargetPageObject(page_refs[0])),
      is_open: true,
      colour: bookmark_colour_for_test(0.1, 0.2, 0.3),
      flags: 1,
    },
    {
      level: 1,
      text: bookmark_bytes_for_test("Child"),
      target: DestXYZ(
        TargetPageObject(page_refs[1]),
        Some(10.0),
        None,
        Some(2.0),
      ),
      is_open: false,
      colour: @bookmark.pdf_bookmark_black,
      flags: 2,
    },
    {
      level: 0,
      text: bookmark_bytes_for_test("Named"),
      target: DestString(bookmark_bytes_for_test("chapter")),
      is_open: false,
      colour: @bookmark.pdf_bookmark_black,
      flags: 0,
    },
  ]
  @test.assert_eq(try! document.parse_bookmark_json(json), expected)
  @test.assert_eq(
    try! @pdflite.pdf_parse_bookmark_json(true, json, document),
    expected,
  )
  let updated = try! @pdflite.pdf_add_bookmarks_from_json(true, json, document)
  @test.assert_eq(try! updated.read_bookmarks(preserve_actions=true), expected)
}

///|
test "PdfDocument parse_bookmark_json rejects malformed rows" {
  let document = try! @pdflite.pdf_blank_document(100.0, 100.0, 2)
  let top_level : Result[Array[@bookmark.PdfBookmark], Error] = try
    document.parse_bookmark_json(Json::object(Map([])))
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard top_level is Err(@core.PdfError::SoftError(_)) else {
    fail("expected @core.PdfError::SoftError for top-level object")
  }
  let malformed_row : Result[Array[@bookmark.PdfBookmark], Error] = try
    document.parse_bookmark_json(
      Json::array([
        Json::object(Map([("level", bookmark_json_int_for_test(0))])),
      ]),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard malformed_row is Err(@core.PdfError::SoftError(_)) else {
    fail("expected @core.PdfError::SoftError for malformed row")
  }
}

///|
test "PdfDocument read_bookmarks traverses outline trees" {
  let doc = bookmark_document_for_test()
  let expected : Array[@bookmark.PdfBookmark] = [
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
      colour: @bookmark.pdf_bookmark_black,
      flags: 0,
    },
    {
      level: 1,
      text: bookmark_bytes_for_test("Sibling"),
      target: DestString(bookmark_bytes_for_test("named")),
      is_open: false,
      colour: @bookmark.pdf_bookmark_black,
      flags: 0,
    },
  ]
  @test.assert_eq(try! doc.read_bookmarks(), expected)
  @test.assert_eq(try! @pdflite.pdf_read_bookmarks(doc), expected)
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
  @test.assert_eq(bookmark.colour, @bookmark.pdf_bookmark_black)
  let action_with_dest : @syntax.PdfObject = PdfDictionary([
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
  let action_without_dest : @syntax.PdfObject = PdfDictionary([
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
  let key_root = bookmark_name_for_test("/Root")
  let type_catalog = bookmark_name_for_test("/Catalog")
  let doc = @pdflite.pdf_document_empty()
  let action : @syntax.PdfObject = PdfDictionary([
    (key_s, PdfNameObject(bookmark_name_for_test("/GoTo"))),
    (key_d, PdfString(bookmark_bytes_for_test("named"))),
  ])
  doc.set_root(1)
  doc.set_trailer_dict(PdfDictionary([(key_root, PdfIndirect(1))]))
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
test "PdfDocument read_bookmarks prefers trailer root over document root" {
  let key_type = bookmark_name_for_test("/Type")
  let key_outlines = bookmark_name_for_test("/Outlines")
  let key_first = bookmark_name_for_test("/First")
  let key_title = bookmark_name_for_test("/Title")
  let key_root = bookmark_name_for_test("/Root")
  let type_catalog = bookmark_name_for_test("/Catalog")
  let doc = @pdflite.pdf_document_empty()
  doc.set_root(1)
  doc.set_trailer_dict(PdfDictionary([(key_root, PdfIndirect(10))]))
  doc.add_object_given_number(
    1,
    PdfDictionary([(key_type, PdfNameObject(type_catalog))]),
  )
  doc.add_object_given_number(
    10,
    PdfDictionary([
      (key_type, PdfNameObject(type_catalog)),
      (key_outlines, PdfIndirect(11)),
    ]),
  )
  doc.add_object_given_number(11, PdfDictionary([(key_first, PdfIndirect(12))]))
  doc.add_object_given_number(
    12,
    PdfDictionary([(key_title, PdfString(bookmark_bytes_for_test("Trailer")))]),
  )
  @test.assert_eq(
    (try! doc.read_bookmarks())[0].text,
    bookmark_bytes_for_test("Trailer"),
  )
}

///|
test "PdfDocument read_bookmarks requires a root catalog" {
  let doc = @pdflite.pdf_document_empty()
  let result : Result[Array[@bookmark.PdfBookmark], Error] = try
    doc.read_bookmarks()
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard result is Err(@core.PdfError::RootExpected) else {
    fail("expected @core.PdfError::RootExpected")
  }
}

///|
test "PdfDocument read_bookmarks rejects unresolved trailer root" {
  let key_root = bookmark_name_for_test("/Root")
  let key_type = bookmark_name_for_test("/Type")
  let type_catalog = bookmark_name_for_test("/Catalog")
  let doc = @pdflite.pdf_document_empty()
  doc.set_root(1)
  doc.set_trailer_dict(PdfDictionary([(key_root, PdfIndirect(99))]))
  doc.add_object_given_number(
    1,
    PdfDictionary([(key_type, PdfNameObject(type_catalog))]),
  )
  let result : Result[Array[@bookmark.PdfBookmark], Error] = try
    doc.read_bookmarks()
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard result is Err(@core.PdfError::RootExpected) else {
    fail("expected @core.PdfError::RootExpected")
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
  let stripped = try! doc.remove_bookmarks()
  let stripped_from_function = try! @pdflite.pdf_remove_bookmarks(doc)
  @test.assert_eq((try! doc.read_bookmarks()).length(), 3)
  @test.assert_eq(try! stripped.read_bookmarks(), [])
  @test.assert_eq(try! stripped_from_function.read_bookmarks(), [])
  @test.assert_eq(stripped.root(), 6)
  @test.assert_eq(
    stripped.trailer_dict().lookup_immediate(key_root),
    Some(PdfIndirect(6)),
  )
}

///|
test "PdfDocument remove_bookmarks preserves trailer-root catalog entries" {
  let key_type = bookmark_name_for_test("/Type")
  let key_outlines = bookmark_name_for_test("/Outlines")
  let key_first = bookmark_name_for_test("/First")
  let key_title = bookmark_name_for_test("/Title")
  let key_root = bookmark_name_for_test("/Root")
  let key_lang = bookmark_name_for_test("/Lang")
  let key_page_mode = bookmark_name_for_test("/PageMode")
  let type_catalog = bookmark_name_for_test("/Catalog")
  let page_mode_use_outlines = bookmark_name_for_test("/UseOutlines")
  let doc = @pdflite.pdf_document_empty()
  doc.set_root(1)
  doc.set_trailer_dict(PdfDictionary([(key_root, PdfIndirect(10))]))
  doc.add_object_given_number(
    1,
    PdfDictionary([
      (key_type, PdfNameObject(type_catalog)),
      (key_lang, PdfString(bookmark_bytes_for_test("stale"))),
    ]),
  )
  doc.add_object_given_number(
    10,
    PdfDictionary([
      (key_type, PdfNameObject(type_catalog)),
      (key_page_mode, PdfNameObject(page_mode_use_outlines)),
      (key_outlines, PdfIndirect(11)),
    ]),
  )
  doc.add_object_given_number(11, PdfDictionary([(key_first, PdfIndirect(12))]))
  doc.add_object_given_number(
    12,
    PdfDictionary([(key_title, PdfString(bookmark_bytes_for_test("Trailer")))]),
  )
  let stripped = try! doc.remove_bookmarks()
  let catalog = stripped.lookup_object_or_null(stripped.root())
  @test.assert_eq(catalog.lookup_immediate(key_outlines), None)
  @test.assert_eq(catalog.lookup_immediate(key_lang), None)
  @test.assert_eq(
    catalog.lookup_immediate(key_page_mode),
    Some(PdfNameObject(page_mode_use_outlines)),
  )
}

///|
test "PdfDocument remove_bookmarks requires a root catalog" {
  let doc = @pdflite.pdf_document_empty()
  let result : Result[@pdflite.PdfDocument, Error] = try
    doc.remove_bookmarks()
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard result is Err(@core.PdfError::RootExpected) else {
    fail("expected @core.PdfError::RootExpected")
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
  let action : @syntax.PdfObject = PdfDictionary([
    (key_s, PdfNameObject(bookmark_name_for_test("/URI"))),
  ])
  let bookmarks : Array[@bookmark.PdfBookmark] = [
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
      colour: @bookmark.pdf_bookmark_black,
      flags: 0,
    },
    {
      level: 0,
      text: bookmark_bytes_for_test("Closed"),
      target: DestNull,
      is_open: false,
      colour: @bookmark.pdf_bookmark_black,
      flags: 0,
    },
    {
      level: 1,
      text: bookmark_bytes_for_test("Hidden"),
      target: DestAction(action),
      is_open: false,
      colour: @bookmark.pdf_bookmark_black,
      flags: 0,
    },
  ]
  let updated = try! doc.add_bookmarks(bookmarks)
  let updated_from_function = try! @pdflite.pdf_add_bookmarks(bookmarks, doc)
  @test.assert_eq(try! doc.read_bookmarks(), [])
  @test.assert_eq(try! updated.read_bookmarks(preserve_actions=true), bookmarks)
  @test.assert_eq(
    try! @pdflite.pdf_read_bookmarks(
      updated_from_function,
      preserve_actions=true,
    ),
    bookmarks,
  )
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
test "PdfDocument add_bookmarks preserves trailer-root catalog entries" {
  let key_type = bookmark_name_for_test("/Type")
  let key_outlines = bookmark_name_for_test("/Outlines")
  let key_root = bookmark_name_for_test("/Root")
  let key_lang = bookmark_name_for_test("/Lang")
  let key_page_mode = bookmark_name_for_test("/PageMode")
  let type_catalog = bookmark_name_for_test("/Catalog")
  let page_mode_use_none = bookmark_name_for_test("/UseNone")
  let doc = @pdflite.pdf_document_empty()
  doc.set_root(1)
  doc.set_trailer_dict(PdfDictionary([(key_root, PdfIndirect(10))]))
  doc.add_object_given_number(
    1,
    PdfDictionary([
      (key_type, PdfNameObject(type_catalog)),
      (key_lang, PdfString(bookmark_bytes_for_test("stale"))),
    ]),
  )
  doc.add_object_given_number(
    10,
    PdfDictionary([
      (key_type, PdfNameObject(type_catalog)),
      (key_page_mode, PdfNameObject(page_mode_use_none)),
    ]),
  )
  let bookmarks : Array[@bookmark.PdfBookmark] = [
    {
      level: 0,
      text: bookmark_bytes_for_test("Top"),
      target: DestNull,
      is_open: false,
      colour: @bookmark.pdf_bookmark_black,
      flags: 0,
    },
  ]
  let updated = try! doc.add_bookmarks(bookmarks)
  @test.assert_eq(try! updated.read_bookmarks(), bookmarks)
  @test.assert_eq(updated.root(), 13)
  let catalog = updated.lookup_object_or_null(updated.root())
  @test.assert_eq(catalog.lookup_immediate(key_lang), None)
  @test.assert_eq(catalog.lookup_immediate(key_outlines), Some(PdfIndirect(12)))
  @test.assert_eq(
    catalog.lookup_immediate(key_page_mode),
    Some(PdfNameObject(page_mode_use_none)),
  )
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
  let bookmarks : Array[@bookmark.PdfBookmark] = [
    {
      level: 0,
      text: bookmark_bytes_for_test("Top"),
      target: DestNull,
      is_open: false,
      colour: @bookmark.pdf_bookmark_black,
      flags: 0,
    },
  ]
  let result : Result[@pdflite.PdfDocument, Error] = try
    doc.add_bookmarks(bookmarks)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard result is Err(@core.PdfError::RootExpected) else {
    fail("expected @core.PdfError::RootExpected")
  }
}

///|
test "PdfDocument add_bookmark_title indents existing bookmarks" {
  let doc = try! @pdflite.pdf_minimum_valid_pdf()
  let page_refs = try! doc.page_reference_numbers()
  let bookmarked = try! doc.add_bookmarks([
    {
      level: 0,
      text: bookmark_bytes_for_test("Top"),
      target: DestFit(TargetPageObject(page_refs[0])),
      is_open: true,
      colour: @bookmark.pdf_bookmark_black,
      flags: 0,
    },
  ])

  let titled = try! @pdflite.pdf_add_bookmark_title(
    "/tmp/report.pdf", false, bookmarked,
  )
  @test.assert_eq(try! titled.read_bookmarks(preserve_actions=true), [
    {
      level: 0,
      text: bookmark_bytes_for_test("report.pdf"),
      target: DestXYZ(TargetPageObject(page_refs[0]), None, None, None),
      is_open: false,
      colour: @bookmark.pdf_bookmark_black,
      flags: 0,
    },
    {
      level: 1,
      text: bookmark_bytes_for_test("Top"),
      target: DestFit(TargetPageObject(page_refs[0])),
      is_open: false,
      colour: @bookmark.pdf_bookmark_black,
      flags: 0,
    },
  ])
}

///|
test "PdfDocument bookmarks_open_to_level rewrites open state" {
  let doc = try! @pdflite.pdf_minimum_valid_pdf()
  let page_refs = try! doc.page_reference_numbers()
  let bookmarked = try! doc.add_bookmarks([
    {
      level: 0,
      text: bookmark_bytes_for_test("Top"),
      target: DestFit(TargetPageObject(page_refs[0])),
      is_open: false,
      colour: @bookmark.pdf_bookmark_black,
      flags: 0,
    },
    {
      level: 1,
      text: bookmark_bytes_for_test("Child"),
      target: DestFit(TargetPageObject(page_refs[0])),
      is_open: true,
      colour: @bookmark.pdf_bookmark_black,
      flags: 0,
    },
  ])

  let opened = try! bookmarked.bookmarks_open_to_level(1)
  let wrapper = try! @pdflite.pdf_bookmarks_open_to_level(1, bookmarked)
  let expected : Array[@bookmark.PdfBookmark] = [
    {
      level: 0,
      text: bookmark_bytes_for_test("Top"),
      target: DestFit(TargetPageObject(page_refs[0])),
      is_open: true,
      colour: @bookmark.pdf_bookmark_black,
      flags: 0,
    },
    {
      level: 1,
      text: bookmark_bytes_for_test("Child"),
      target: DestFit(TargetPageObject(page_refs[0])),
      is_open: false,
      colour: @bookmark.pdf_bookmark_black,
      flags: 0,
    },
  ]
  @test.assert_eq(try! opened.read_bookmarks(preserve_actions=true), expected)
  @test.assert_eq(try! wrapper.read_bookmarks(preserve_actions=true), expected)
}

///|
test "pdf_change_bookmark rewrites page-object destinations" {
  let bookmark : @bookmark.PdfBookmark = {
    level: 0,
    text: bookmark_bytes_for_test("Top"),
    target: DestFitR(TargetPageObject(10), 1.0, 2.0, 3.0, 4.0),
    is_open: false,
    colour: @bookmark.pdf_bookmark_black,
    flags: 0,
  }
  @test.assert_eq(
    @pdflite.pdf_change_bookmark([(10, 42)], bookmark).target,
    DestFitR(TargetPageObject(42), 1.0, 2.0, 3.0, 4.0),
  )
  @test.assert_eq(@pdflite.pdf_change_bookmark([(11, 42)], bookmark), bookmark)
  @test.assert_eq(
    @pdflite.pdf_change_bookmark([(10, 42)], {
      ..bookmark,
      target: DestFitB(TargetPageObject(10)),
    }).target,
    DestFit(TargetPageObject(42)),
  )
  @test.assert_eq(
    @pdflite.pdf_change_bookmark([(10, 42)], {
      ..bookmark,
      target: DestFit(TargetOtherDocPageNumber(10)),
    }).target,
    DestFit(TargetOtherDocPageNumber(10)),
  )
}

///|
test "PdfDocument transform_bookmark transforms bookmark target" {
  let doc = @pdflite.pdf_document_empty()
  let bookmark : @bookmark.PdfBookmark = {
    level: 0,
    text: bookmark_bytes_for_test("Top"),
    target: DestFitH(TargetPageObject(7), Some(5.0)),
    is_open: false,
    colour: @bookmark.pdf_bookmark_black,
    flags: 0,
  }
  @test.assert_eq(
    try! doc.transform_bookmark(
      @geometry.transform_translate(10.0, 20.0),
      bookmark,
    ),
    { ..bookmark, target: DestFitH(TargetPageObject(7), Some(25.0)) },
  )
  @test.assert_eq(
    try! @pdflite.pdf_transform_bookmark(
      doc,
      @geometry.transform_translate(10.0, 20.0),
      bookmark,
    ),
    { ..bookmark, target: DestFitH(TargetPageObject(7), Some(25.0)) },
  )
}
