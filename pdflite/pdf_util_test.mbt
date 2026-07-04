///|
test "pdf progress helpers gate and record cpdf fragments" {
  @pdflite.pdf_set_progress(false)
  @pdflite.pdf_clear_progress_output()
  @pdflite.pdf_progress_line("Loading file input.pdf")
  @pdflite.pdf_progress_line_no_end("ignored")
  @pdflite.pdf_progress_page(9)
  @pdflite.pdf_progress_endpage()
  @pdflite.pdf_progress_done()
  @test.assert_eq(@pdflite.pdf_progress_output(), "")
  @test.assert_eq(@pdflite.pdf_progress(), false)

  @pdflite.pdf_set_progress(true)
  @pdflite.pdf_progress_line("Loading file input.pdf")
  @pdflite.pdf_progress_line_no_end("Page ")
  @pdflite.pdf_progress_page(9)
  @pdflite.pdf_progress_endpage()
  @pdflite.pdf_progress_done()

  @test.assert_eq(@pdflite.pdf_progress(), true)
  @test.assert_eq(
    @pdflite.pdf_progress_output(),
    "Loading file input.pdf\nPage 9.\n",
  )
  @pdflite.pdf_set_progress(false)
  @pdflite.pdf_clear_progress_output()
}

///|
fn util_name_for_test(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn util_lookup_for_test(
  object : @syntax.PdfObject,
  key : @core.PdfName,
) -> @syntax.PdfObject? {
  object.lookup_immediate(key)
}

///|
test "PdfDocument remove_dict_entry_everywhere rewrites trailer objects streams and arrays" {
  let key_remove = util_name_for_test("/Remove")
  let key_keep = util_name_for_test("/Keep")
  let doc = @pdflite.pdf_document_empty()
  doc.set_trailer_dict(
    @syntax.pdf_dictionary([
      (key_keep, PdfInteger(1)),
      (key_remove, PdfInteger(2)),
    ]),
  )
  doc.add_object_given_number(
    1,
    @syntax.pdf_dictionary([
      (key_remove, PdfInteger(10)),
      (key_keep, @syntax.pdf_dictionary([(key_remove, PdfInteger(11))])),
    ]),
  )
  doc.add_object_given_number(
    2,
    @syntax.pdf_array([
      @syntax.pdf_dictionary([(key_remove, PdfInteger(20))]),
      PdfInteger(3),
    ]),
  )
  let stream = @syntax.pdf_stream(
    @syntax.pdf_dictionary([(key_remove, PdfInteger(30))]),
    StreamGot(try! @core.pdf_bytes_of_int_array([65, 66])),
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
    StreamGot(try! @core.pdf_bytes_of_int_array([65, 66])),
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
    @syntax.pdf_dictionary([
      (key_target, PdfIndirect(10)),
      (key_other, PdfInteger(1)),
    ]),
  )
  doc.add_object_given_number(
    2,
    @syntax.pdf_dictionary([(key_target, PdfIndirect(11))]),
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
    @syntax.pdf_dictionary([
      (key_keep, PdfInteger(1)),
      (key_target, PdfInteger(2)),
    ]),
  )
  doc.add_object_given_number(
    1,
    @syntax.pdf_dictionary([(key_keep, PdfInteger(3))]),
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
test "cpdfutil string-key dictionary wrappers match source argument shape" {
  let key_target = util_name_for_test("/Target")
  let key_keep = util_name_for_test("/Keep")
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(10, PdfInteger(99))
  doc.add_object_given_number(
    1,
    @syntax.pdf_dictionary([
      (key_target, PdfIndirect(10)),
      (key_keep, PdfInteger(1)),
    ]),
  )
  doc.set_trailer_dict(@syntax.pdf_dictionary([(key_target, PdfInteger(2))]))

  @pdflite.pdf_remove_dict_entry_string(
    doc,
    "/Target",
    search=Some(PdfInteger(99)),
  )

  @test.assert_eq(
    util_lookup_for_test(doc.lookup_object_or_null(1), key_target),
    None,
  )
  @test.assert_eq(
    util_lookup_for_test(doc.trailer_dict(), key_target),
    Some(PdfInteger(2)),
  )

  doc.replace_dict_entry_string(
    "/Target",
    PdfString(@ascii.encode("updated")),
    search=Some(PdfInteger(2)),
  )

  @test.assert_eq(
    util_lookup_for_test(doc.trailer_dict(), key_target),
    Some(PdfString(@ascii.encode("updated"))),
  )
  @test.assert_eq(
    util_lookup_for_test(doc.lookup_object_or_null(1), key_keep),
    Some(PdfInteger(1)),
  )
}

///|
test "PdfDocument dict_entry_values scans dictionaries arrays streams and trailer" {
  let key_target = util_name_for_test("/Target")
  let key_nested = util_name_for_test("/Nested")
  let key_stream_value = util_name_for_test("/StreamValue")
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(9, PdfInteger(99))
  doc.add_object_given_number(
    1,
    @syntax.pdf_dictionary([
      (key_target, PdfInteger(1)),
      (
        key_nested,
        @syntax.pdf_dictionary([
          (key_target, PdfString(@ascii.encode("nested"))),
        ]),
      ),
    ]),
  )
  doc.add_object_given_number(
    2,
    @syntax.pdf_array([@syntax.pdf_dictionary([(key_target, PdfReal(2.5))])]),
  )
  doc.add_object_given_number(
    3,
    @syntax.pdf_stream(
      @syntax.pdf_dictionary([(key_target, PdfNameObject(key_stream_value))]),
      StreamGot(@ascii.encode("stream")),
    ),
  )
  doc.add_object_given_number(
    4,
    @syntax.pdf_stream(PdfInteger(0), StreamGot(@ascii.encode("bad"))),
  )
  doc.set_trailer_dict(@syntax.pdf_dictionary([(key_target, PdfIndirect(9))]))

  @test.assert_eq(@pdflite.pdf_dict_entry_values(doc, key_target), [
    PdfString(@ascii.encode("nested")),
    PdfInteger(1),
    PdfReal(2.5),
    PdfNameObject(key_stream_value),
    PdfInteger(99),
  ])
}

///|
test "pdf_print_dict_entry renders resolved values as PDF syntax" {
  let key_target = util_name_for_test("/Target")
  let key_value = util_name_for_test("/Value")
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(10, PdfNameObject(key_value))
  doc.add_object_given_number(
    1,
    @syntax.pdf_dictionary([(key_target, PdfIndirect(10))]),
  )
  doc.add_object_given_number(
    2,
    @syntax.pdf_dictionary([(key_target, PdfString(@ascii.encode("plain")))]),
  )

  @test.assert_eq(try! @pdflite.pdf_print_dict_entry(doc, key_target), [
    @ascii.encode("/Value"),
    @ascii.encode("(plain)"),
  ])
}

///|
test "cpdftweak print_dict_entry source-order wrapper accepts string keys" {
  let key_target = util_name_for_test("/Target")
  let key_value = util_name_for_test("/Value")
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(10, PdfNameObject(key_value))
  doc.add_object_given_number(
    1,
    @syntax.pdf_dictionary([(key_target, PdfIndirect(10))]),
  )
  doc.add_object_given_number(
    2,
    @syntax.pdf_dictionary([(key_target, PdfString(@ascii.encode("plain")))]),
  )

  let expected = try! @pdflite.pdf_print_dict_entry(doc, key_target)
  @test.assert_eq(
    try! doc.dict_entry_rendered_values_string("/Target"),
    expected,
  )
  @test.assert_eq(
    try! @pdflite.pdf_print_dict_entry_string(doc, "/Target"),
    expected,
  )
  @test.assert_eq(
    try! @pdflite.pdf_print_dict_entry_cpdf_order(true, doc, "/Target"),
    expected,
  )
}

///|
test "pdf_get_dict_entries renders cpdf style JSON wrappers" {
  let key_target = util_name_for_test("/Target")
  let key_other = util_name_for_test("/Other")
  let key_value = util_name_for_test("/Value")
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(
    1,
    @syntax.pdf_dictionary([(key_target, PdfInteger(7))]),
  )
  doc.add_object_given_number(
    2,
    @syntax.pdf_dictionary([(key_target, PdfNameObject(key_value))]),
  )
  doc.add_object_given_number(
    3,
    @syntax.pdf_dictionary([
      (
        key_target,
        PdfArray([PdfBoolean(true), PdfNull, PdfReal(2.5), PdfIndirect(5)]),
      ),
    ]),
  )
  doc.add_object_given_number(
    4,
    @syntax.pdf_dictionary([(key_target, PdfIndirect(5))]),
  )
  doc.add_object_given_number(
    5,
    @syntax.pdf_stream(
      @syntax.pdf_dictionary([(key_other, PdfInteger(1))]),
      StreamGot(@ascii.encode("payload")),
    ),
  )
  let expected : Json = [
    { "I": 7.0 },
    { "N": "/Value" },
    [true, null, { "F": 2.5 }, 5.0],
    { "S": [{ "/Other": { "I": 1.0 } }, "payload"] },
  ]

  @test.assert_eq(
    try! @pdflite.pdf_get_dict_entries(doc, key_target),
    @utf8.encode(expected.stringify()),
  )
}

///|
test "cpdftweak get_dict_entries source-order wrapper accepts string keys" {
  let key_target = util_name_for_test("/Target")
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(
    1,
    @syntax.pdf_dictionary([(key_target, PdfString(@ascii.encode("hello")))]),
  )

  let expected = try! @pdflite.pdf_get_dict_entries(doc, key_target, utf8=true)
  @test.assert_eq(
    try! doc.dict_entries_json_string("/Target", utf8=true),
    expected,
  )
  @test.assert_eq(
    try! @pdflite.pdf_get_dict_entries_string(doc, "/Target", utf8=true),
    expected,
  )
  @test.assert_eq(
    try! @pdflite.pdf_get_dict_entries_cpdf_order(true, doc, "/Target"),
    expected,
  )
}

///|
test "PdfDocument json_of_object exposes cpdf single-object dictionary shape" {
  let key_array = util_name_for_test("/Array")
  let key_name = util_name_for_test("/Name")
  let key_number = util_name_for_test("/Number")
  let key_value = util_name_for_test("/Value")
  let doc = @pdflite.pdf_document_empty()
  let object = @syntax.pdf_dictionary([
    (
      key_array,
      @syntax.pdf_array([
        PdfBoolean(true),
        PdfNull,
        PdfReal(1.5),
        PdfIndirect(8),
      ]),
    ),
    (key_name, PdfNameObject(key_value)),
    (key_number, PdfInteger(7)),
  ])
  let expected = Json::object(
    Map([
      (
        "/Array",
        Json::array([
          Json::boolean(true),
          Json::null(),
          Json::object(Map([("F", Json::number(1.5))])),
          Json::number(8.0, repr="8"),
        ]),
      ),
      ("/Name", Json::object(Map([("N", Json::string("/Value"))]))),
      ("/Number", Json::object(Map([("I", Json::number(7.0, repr="7"))]))),
    ]),
  )

  @test.assert_eq(try! doc.json_of_object(object), expected)
  @test.assert_eq(try! @pdflite.pdf_json_of_object(doc, object), expected)
}

///|
test "PdfDocument json_of_object emits streams and utf8 string wrappers" {
  let key_other = util_name_for_test("/Other")
  let doc = @pdflite.pdf_document_empty()
  let stream = @syntax.pdf_stream(
    @syntax.pdf_dictionary([(key_other, PdfInteger(1))]),
    StreamGot(@ascii.encode("payload")),
  )
  let stream_expected = Json::object(
    Map([
      (
        "S",
        Json::array([
          Json::object(
            Map([
              (
                "/Other",
                Json::object(Map([("I", Json::number(1.0, repr="1"))])),
              ),
            ]),
          ),
          Json::string("payload"),
        ]),
      ),
    ]),
  )
  let utf8_expected = Json::object(Map([("U", Json::string("hello"))]))

  @test.assert_eq(try! doc.json_of_object(stream), stream_expected)
  @test.assert_eq(
    try! doc.json_of_object(PdfString(@ascii.encode("hello")), utf8=true),
    utf8_expected,
  )
}

///|
test "PdfDocument CPDFJSON output honors clean_strings option" {
  let unicode_ascii = try! @pdflite.pdf_utf16be_of_codepoints([0x41, 0x42])
  let raw_json = Json::string("<feff00410042>")
  let clean_json = Json::string("AB")
  let doc = @pdflite.pdf_document_empty()

  @test.assert_eq(try! doc.json_of_object(PdfString(unicode_ascii)), raw_json)
  @test.assert_eq(
    try! doc.json_of_object(PdfString(unicode_ascii), clean_strings=true),
    clean_json,
  )
  @test.assert_eq(
    try! @pdflite.pdf_json_of_object(
      doc,
      PdfString(unicode_ascii),
      clean_strings=true,
    ),
    clean_json,
  )
  @test.assert_eq(
    try! doc.json_of_object(
      PdfString(unicode_ascii),
      utf8=true,
      clean_strings=true,
    ),
    Json::object(Map([("U", Json::string("AB"))])),
  )

  let key_root = util_name_for_test("/Root")
  let key_title = util_name_for_test("/Title")
  doc.set_trailer_dict(
    PdfDictionary([
      (key_root, PdfIndirect(1)),
      (key_title, PdfString(unicode_ascii)),
    ]),
  )
  doc.add_object_given_number(
    1,
    @syntax.pdf_dictionary([(key_title, PdfString(unicode_ascii))]),
  )
  let exported = try! doc.json_of_document(clean_strings=true)
  @test.assert_eq(
    try! @pdflite.pdf_json_of_document(doc, clean_strings=true),
    exported,
  )

  guard util_cpdfjson_entry_for_test(exported, 1) is Some(Object(object_json)) else {
    fail("expected document object entry")
  }
  @test.assert_eq(object_json.get("/Title"), Some(clean_json))

  guard util_cpdfjson_entry_for_test(exported, 0) is Some(Object(trailer_json)) else {
    fail("expected trailer entry")
  }
  @test.assert_eq(trailer_json.get("/Title"), Some(raw_json))
}

///|
test "PdfDocument CPDFJSON output honors no_stream_data option" {
  let key_other = util_name_for_test("/Other")
  let doc = @pdflite.pdf_document_empty()
  let stream = @syntax.pdf_stream(
    @syntax.pdf_dictionary([(key_other, PdfInteger(1))]),
    StreamGot(@ascii.encode("payload")),
  )
  let stream_json = try! doc.json_of_object(stream, no_stream_data=true)
  @test.assert_eq(
    try! @pdflite.pdf_json_of_object(doc, stream, no_stream_data=true),
    stream_json,
  )
  guard stream_json is Object(stream_wrapper) else {
    fail("expected elided stream wrapper")
  }
  guard stream_wrapper.get("S")
    is Some(Array([dict_json, String("<<stream data elided>>")])) else {
    fail("expected elided stream data")
  }
  guard dict_json is Object(dict_entries) else {
    fail("expected stream dictionary")
  }
  @test.assert_eq(
    dict_entries.get("/Other"),
    Some(Json::object(Map([("I", Json::number(1.0, repr="1"))]))),
  )

  let document = try! @pdflite.pdf_document_of_json(
    util_cpdfjson_document_for_test(),
  )
  let exported = try! document.json_of_document(no_stream_data=true)
  @test.assert_eq(
    try! @pdflite.pdf_json_of_document(document, no_stream_data=true),
    exported,
  )
  guard util_cpdfjson_entry_for_test(exported, -1) is Some(params_json) else {
    fail("expected CPDFJSON params entry")
  }
  let params = try! @pdflite.pdf_object_of_json(params_json)
  @test.assert_eq(
    util_lookup_for_test(
      params,
      util_name_for_test("/CPDFJSONstreamdataincluded"),
    ),
    Some(PdfBoolean(false)),
  )
  guard util_cpdfjson_entry_for_test(exported, 2)
    is Some(Object(object2_wrapper)) else {
    fail("expected object 2 stream wrapper")
  }
  guard object2_wrapper.get("S")
    is Some(Array([_, String("<<stream data elided>>")])) else {
    fail("expected elided document stream data")
  }

  let parsed = try! document.json_of_document(
    parse_content=true,
    no_stream_data=true,
  )
  guard util_cpdfjson_entry_for_test(parsed, -1) is Some(parsed_params_json) else {
    fail("expected parsed CPDFJSON params entry")
  }
  let parsed_params = try! @pdflite.pdf_object_of_json(parsed_params_json)
  @test.assert_eq(
    util_lookup_for_test(
      parsed_params,
      util_name_for_test("/CPDFJSONcontentparsed"),
    ),
    Some(PdfBoolean(true)),
  )
  @test.assert_eq(
    util_lookup_for_test(
      parsed_params,
      util_name_for_test("/CPDFJSONstreamdataincluded"),
    ),
    Some(PdfBoolean(false)),
  )
  guard util_cpdfjson_entry_for_test(parsed, 2)
    is Some(Object(parsed_stream_wrapper)) else {
    fail("expected parsed stream wrapper")
  }
  guard parsed_stream_wrapper.get("S") is Some(Array([_, Array(parsed_ops)])) else {
    fail("expected parsed operation arrays despite no_stream_data")
  }
  @test.assert_eq(parsed_ops.length(), 5)
}

///|
fn util_cpdfjson_encoded_function_stream_for_test(
  data : String,
) -> @syntax.PdfObject {
  let bytes = @ascii.encode(data)
  let raw_stream = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (util_name_for_test("/FunctionType"), PdfInteger(4)),
      (util_name_for_test("/Length"), PdfInteger(bytes.length())),
    ]),
    StreamGot(bytes),
  )
  try! @pdflite.pdf_encode_stream_with_filter(
    util_name_for_test("/FlateDecode"),
    raw_stream,
  )
}

///|
test "PdfDocument CPDFJSON parse_content decodes function streams" {
  let doc = @pdflite.pdf_document_empty()
  let encoded = util_cpdfjson_encoded_function_stream_for_test("{ 1 }")
  let elided = try! doc.json_of_object(encoded, no_stream_data=true)
  guard elided is Object(elided_wrapper) else {
    fail("expected elided function stream wrapper")
  }
  guard elided_wrapper.get("S")
    is Some(Array([_, String("<<stream data elided>>")])) else {
    fail("expected ordinary no_stream_data elision")
  }

  let decoded = try! doc.json_of_object(
    encoded,
    parse_content=true,
    no_stream_data=true,
  )
  @test.assert_eq(
    try! @pdflite.pdf_json_of_object(
      doc,
      encoded,
      parse_content=true,
      no_stream_data=true,
    ),
    decoded,
  )
  guard decoded is Object(decoded_wrapper) else {
    fail("expected decoded function stream wrapper")
  }
  guard decoded_wrapper.get("S")
    is Some(Array([Object(decoded_dict), String(decoded_data)])) else {
    fail("expected decoded function stream data")
  }
  @test.assert_eq(decoded_data, "{ 1 }")
  @test.assert_eq(decoded_dict.get("/Filter"), None)
  @test.assert_eq(
    decoded_dict.get("/FunctionType"),
    Some(Json::object(Map([("I", Json::number(4.0, repr="4"))]))),
  )
  @test.assert_eq(
    decoded_dict.get("/Length"),
    Some(Json::object(Map([("I", Json::number(5.0, repr="5"))]))),
  )

  let key_function = util_name_for_test("/Function")
  let document = try! @pdflite.pdf_document_of_json(
    util_cpdfjson_document_for_test(),
  )
  document.add_object_given_number(
    4,
    @syntax.pdf_dictionary([
      (
        util_name_for_test("/Type"),
        PdfNameObject(util_name_for_test("/Catalog")),
      ),
      (util_name_for_test("/Pages"), PdfIndirect(1)),
      (key_function, PdfIndirect(5)),
    ]),
  )
  document.add_object_given_number(5, encoded)
  let exported = try! document.json_of_document(
    parse_content=true,
    no_stream_data=true,
  )
  @test.assert_eq(
    try! @pdflite.pdf_json_of_document(
      document,
      parse_content=true,
      no_stream_data=true,
    ),
    exported,
  )
  guard util_cpdfjson_entry_for_test(exported, 5)
    is Some(Object(document_wrapper)) else {
    fail("expected document function stream wrapper")
  }
  guard document_wrapper.get("S")
    is Some(Array([Object(document_dict), String(document_data)])) else {
    fail("expected decoded document function stream data")
  }
  @test.assert_eq(document_data, "{ 1 }")
  @test.assert_eq(document_dict.get("/Filter"), None)
}

///|
test "PdfDocument CPDFJSON document output honors decompress_streams option" {
  let key_root = util_name_for_test("/Root")
  let key_payload = util_name_for_test("/Payload")
  let key_length = util_name_for_test("/Length")
  let key_filter = util_name_for_test("/Filter")
  let doc = @pdflite.pdf_document_empty()
  doc.set_trailer_dict(PdfDictionary([(key_root, PdfIndirect(1))]))
  doc.add_object_given_number(
    1,
    @syntax.pdf_dictionary([(key_payload, PdfIndirect(5))]),
  )
  doc.add_object_given_number(
    5,
    @syntax.pdf_stream(
      @syntax.pdf_dictionary([
        (key_length, PdfInteger(5)),
        (key_filter, PdfNameObject(util_name_for_test("/ASCIIHexDecode"))),
      ]),
      StreamGot(@ascii.encode("4869>")),
    ),
  )

  let raw = try! doc.json_of_document()
  guard util_cpdfjson_entry_for_test(raw, 5) is Some(Object(raw_wrapper)) else {
    fail("expected raw stream wrapper")
  }
  guard raw_wrapper.get("S") is Some(Array([Object(raw_dict), String("4869>")])) else {
    fail("expected encoded stream data before decompression")
  }
  @test.assert_eq(
    raw_dict.get("/Filter"),
    Some(Json::object(Map([("N", Json::string("/ASCIIHexDecode"))]))),
  )

  let decompressed = try! doc.json_of_document(decompress_streams=true)
  @test.assert_eq(
    try! @pdflite.pdf_json_of_document(doc, decompress_streams=true),
    decompressed,
  )
  guard util_cpdfjson_entry_for_test(decompressed, 5)
    is Some(Object(decoded_wrapper)) else {
    fail("expected decoded stream wrapper")
  }
  guard decoded_wrapper.get("S")
    is Some(Array([Object(decoded_dict), String("Hi")])) else {
    fail("expected decoded stream data")
  }
  @test.assert_eq(decoded_dict.get("/Filter"), None)
  @test.assert_eq(
    decoded_dict.get("/Length"),
    Some(Json::object(Map([("I", Json::number(2.0, repr="2"))]))),
  )

  let elided = try! doc.json_of_document(
    decompress_streams=true,
    no_stream_data=true,
  )
  guard util_cpdfjson_entry_for_test(elided, 5) is Some(Object(elided_wrapper)) else {
    fail("expected elided decoded stream wrapper")
  }
  guard elided_wrapper.get("S")
    is Some(Array([Object(elided_dict), String("<<stream data elided>>")])) else {
    fail("expected elided decoded stream data")
  }
  @test.assert_eq(elided_dict.get("/Filter"), None)
  @test.assert_eq(
    elided_dict.get("/Length"),
    Some(Json::object(Map([("I", Json::number(2.0, repr="2"))]))),
  )
}

///|
test "PdfDocument CPDFJSON document output omits unreachable objects" {
  let document = try! @pdflite.pdf_document_of_json(
    util_cpdfjson_document_for_test(),
  )
  document.add_object_given_number(99, PdfString(@ascii.encode("detached")))
  @test.assert_eq(document.object_numbers(), [1, 2, 3, 4, 99])

  let exported = try! document.json_of_document()
  @test.assert_eq(try! @pdflite.pdf_json_of_document(document), exported)
  @test.assert_eq(util_cpdfjson_entry_for_test(exported, 99), None)
  @test.assert_eq(document.object_numbers(), [1, 2, 3, 4, 99])
  @test.assert_eq(
    document.lookup_object_or_null(99),
    PdfString(@ascii.encode("detached")),
  )

  let roundtripped = try! @pdflite.pdf_document_of_json(exported)
  @test.assert_eq(roundtripped.object_numbers(), [1, 2, 3, 4])
}

///|
test "pdf_object_of_json decodes cpdf single-object wrappers" {
  let key_array = util_name_for_test("/Array")
  let key_name = util_name_for_test("/Name")
  let key_number = util_name_for_test("/Number")
  let key_string = util_name_for_test("/String")
  let key_value = util_name_for_test("/Value")
  let json : Json = {
    "/Array": [true, null, { "F": 1.5 }, 8.0],
    "/Name": { "N": "/Value" },
    "/Number": { "I": 7.0 },
    "/String": "plain",
  }

  let object = try! @pdflite.pdf_object_of_json(json)

  @test.assert_eq(util_lookup_for_test(object, key_number), Some(PdfInteger(7)))
  @test.assert_eq(
    util_lookup_for_test(object, key_name),
    Some(PdfNameObject(key_value)),
  )
  @test.assert_eq(
    util_lookup_for_test(object, key_string),
    Some(PdfString(@ascii.encode("plain"))),
  )
  guard util_lookup_for_test(object, key_array)
    is Some(PdfArray([PdfBoolean(true), PdfNull, PdfReal(1.5), PdfIndirect(8)])) else {
    fail("expected decoded CPDFJSON array")
  }
}

///|
test "pdf_object_of_json decodes streams and utf8 string wrappers" {
  let key_length = util_name_for_test("/Length")
  let key_other = util_name_for_test("/Other")
  let stream_json : Json = {
    "S": [{ "/Length": { "I": 99.0 }, "/Other": { "I": 1.0 } }, "payload"],
  }

  guard (try! @pdflite.pdf_object_of_json(stream_json))
    is PdfStreamObject(stream) else {
    fail("expected decoded stream object")
  }
  @test.assert_eq(stream.data, StreamGot(@ascii.encode("payload")))
  @test.assert_eq(
    util_lookup_for_test(stream.dictionary, key_length),
    Some(PdfInteger(7)),
  )
  @test.assert_eq(
    util_lookup_for_test(stream.dictionary, key_other),
    Some(PdfInteger(1)),
  )

  @test.assert_eq(
    try! @pdflite.pdf_object_of_json({ "U": "hello" }),
    PdfString(@ascii.encode("hello")),
  )
  @test.assert_eq(
    try! @pdflite.pdf_object_of_json({ "U": "Résumé" }),
    PdfString(try! @pdflite.pdf_pdfdocstring_of_utf8(@utf8.encode("Résumé"))),
  )
}

///|
test "pdf_object_of_json decodes parsed content-stream operation arrays" {
  let key_length = util_name_for_test("/Length")
  let key_other = util_name_for_test("/Other")
  let parsed_stream_json : Json = {
    "S": [
      { "/Length": { "I": 999.0 }, "/Other": { "I": 1.0 } },
      [
        [
          { "F": 1.0 },
          { "F": 0.0 },
          { "F": 0.0 },
          { "F": 1.0 },
          { "F": 50.0 },
          { "F": 770.0 },
          "cm",
        ],
        ["BT"],
        ["/F0", { "F": 36.0 }, "Tf"],
        ["Hello", "Tj"],
        ["ET"],
        [{ "F": 0.1 }, { "F": 0.2 }, { "F": 0.3 }, "RG"],
        [[{ "F": 3.0 }, { "F": 1.0 }], { "F": 0.0 }, "d"],
        ["/Span", { "N": "/Artifact" }, "BDC"],
        ["EMC"],
        [{ "F": 0.5 }, "/Spot", "SCNName"],
        [{ "F": 0.25 }, "SC"],
      ],
    ],
  }
  let expected_ops : Array[@content.PdfContentOp] = [
    Op_cm({ a: 1.0, b: 0.0, c: 0.0, d: 1.0, e: 50.0, f: 770.0 }),
    Op_BT,
    Op_Tf(util_name_for_test("/F0"), 36.0),
    Op_Tj(@ascii.encode("Hello")),
    Op_ET,
    Op_RG(0.1, 0.2, 0.3),
    Op_d([3.0, 1.0], 0.0),
    Op_BDC(
      util_name_for_test("/Span"),
      PdfNameObject(util_name_for_test("/Artifact")),
    ),
    Op_EMC,
    Op_SCNName(util_name_for_test("/Spot"), [0.5]),
    Op_SC([0.25]),
  ]
  let expected_data = try! @pdflite.pdf_content_bytes_of_ops(expected_ops)

  guard (try! @pdflite.pdf_object_of_json(parsed_stream_json))
    is PdfStreamObject(stream) else {
    fail("expected decoded parsed content stream")
  }
  @test.assert_eq(stream.data, StreamGot(expected_data))
  @test.assert_eq(
    util_lookup_for_test(stream.dictionary, key_length),
    Some(PdfInteger(expected_data.length())),
  )
  @test.assert_eq(
    util_lookup_for_test(stream.dictionary, key_other),
    Some(PdfInteger(1)),
  )
  @test.assert_eq(
    try! @pdflite.pdf_parse_content_ops_from_bytes(expected_data),
    expected_ops,
  )
}

///|
test "pdf_object_of_json rejects malformed parsed content operations" {
  let bad_number : Result[@syntax.PdfObject, Error] = try
    @pdflite.pdf_object_of_json({ "S": [{}, [[{ "I": 2.0 }, "w"]]] })
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_number is Err(@core.PdfError::NumberExpected) else {
    fail("expected NumberExpected for malformed parsed content number")
  }

  let bad_shape : Result[@syntax.PdfObject, Error] = try
    @pdflite.pdf_object_of_json({ "S": [{}, [["q", "bad"]]] })
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_shape is Err(@core.PdfError::BadText) else {
    fail("expected BadText for malformed parsed content operator")
  }
}

///|
fn util_cpdfjson_document_for_test() -> Json {
  [
    [
      -1.0,
      {
        "/CPDFJSONformatversion": { "I": 3.0 },
        "/CPDFJSONcontentparsed": true,
        "/CPDFJSONstreamdataincluded": true,
        "/CPDFJSONmajorpdfversion": { "I": 1.0 },
        "/CPDFJSONminorpdfversion": { "I": 7.0 },
      },
    ],
    [0.0, { "/Size": { "I": 5.0 }, "/Root": 4.0 }],
    [-2.0, { "I": 99.0 }],
    [
      1.0,
      { "/Type": { "N": "/Pages" }, "/Kids": [3.0], "/Count": { "I": 1.0 } },
    ],
    [
      2.0,
      {
        "S": [
          { "/Length": { "I": 999.0 } },
          [
            [
              { "F": 1.0 },
              { "F": 0.0 },
              { "F": 0.0 },
              { "F": 1.0 },
              { "F": 50.0 },
              { "F": 770.0 },
              "cm",
            ],
            ["BT"],
            ["/F0", { "F": 36.0 }, "Tf"],
            ["Hello", "Tj"],
            ["ET"],
          ],
        ],
      },
    ],
    [3.0, { "/Type": { "N": "/Page" }, "/Parent": 1.0, "/Contents": 2.0 }],
    [4.0, { "/Type": { "N": "/Catalog" }, "/Pages": 1.0 }],
  ]
}

///|
fn util_cpdfjson_entry_for_test(json : Json, number : Int) -> Json? {
  match json {
    Array(items) =>
      for item in items {
        match item {
          Array([Number(value, repr=_), object]) =>
            if value.to_int() == number && value == number.to_double() {
              break Some(object)
            }
          _ => ()
        }
      } nobreak {
        None
      }
    _ => None
  }
}

///|
test "pdf_document_of_json imports cpdf top-level document arrays" {
  let document = try! @pdflite.pdf_document_of_json(
    util_cpdfjson_document_for_test(),
  )
  @test.assert_eq(document.version(), (1, 7))
  @test.assert_eq(document.root(), 4)
  @test.assert_eq(document.object_numbers(), [1, 2, 3, 4])
  @test.assert_eq(document.event_log(), [])
  @test.assert_eq(
    document.trailer_dict().lookup_immediate(util_name_for_test("/Root")),
    Some(PdfIndirect(4)),
  )
  guard document.catalog() is PdfDictionary(catalog_entries) else {
    fail("expected imported catalog")
  }
  let catalog_object : @syntax.PdfObject = PdfDictionary(catalog_entries)
  @test.assert_eq(
    catalog_object.lookup_immediate(util_name_for_test("/Pages")),
    Some(PdfIndirect(1)),
  )
  guard document.lookup_object_or_null(2) is PdfStreamObject(stream) else {
    fail("expected imported content stream")
  }
  guard stream.data is StreamGot(data) else {
    fail("expected imported stream data")
  }
  @test.assert_eq(try! @pdflite.pdf_parse_content_ops_from_bytes(data), [
    Op_cm({ a: 1.0, b: 0.0, c: 0.0, d: 1.0, e: 50.0, f: 770.0 }),
    Op_BT,
    Op_Tf(util_name_for_test("/F0"), 36.0),
    Op_Tj(@ascii.encode("Hello")),
    Op_ET,
  ])
}

///|
test "PdfDocument json_of_document emits cpdf top-level arrays and round trips" {
  let document = try! @pdflite.pdf_document_of_json(
    util_cpdfjson_document_for_test(),
  )
  let exported = try! document.json_of_document()
  @test.assert_eq(try! @pdflite.pdf_json_of_document(document), exported)

  guard util_cpdfjson_entry_for_test(exported, -1) is Some(params_json) else {
    fail("expected CPDFJSON params entry")
  }
  let params = try! @pdflite.pdf_object_of_json(params_json)
  @test.assert_eq(
    util_lookup_for_test(params, util_name_for_test("/CPDFJSONformatversion")),
    Some(PdfInteger(3)),
  )
  @test.assert_eq(
    util_lookup_for_test(params, util_name_for_test("/CPDFJSONcontentparsed")),
    Some(PdfBoolean(false)),
  )
  @test.assert_eq(
    util_lookup_for_test(
      params,
      util_name_for_test("/CPDFJSONstreamdataincluded"),
    ),
    Some(PdfBoolean(true)),
  )
  @test.assert_eq(
    util_lookup_for_test(params, util_name_for_test("/CPDFJSONmajorpdfversion")),
    Some(PdfInteger(1)),
  )
  @test.assert_eq(
    util_lookup_for_test(params, util_name_for_test("/CPDFJSONminorpdfversion")),
    Some(PdfInteger(7)),
  )

  guard util_cpdfjson_entry_for_test(exported, 0) is Some(trailer_json) else {
    fail("expected CPDFJSON trailer entry")
  }
  @test.assert_eq(
    util_lookup_for_test(
      try! @pdflite.pdf_object_of_json(trailer_json),
      util_name_for_test("/Root"),
    ),
    Some(PdfIndirect(4)),
  )

  let roundtripped = try! @pdflite.pdf_document_of_json(exported)
  @test.assert_eq(roundtripped.version(), (1, 7))
  @test.assert_eq(roundtripped.root(), 4)
  @test.assert_eq(roundtripped.object_numbers(), [1, 2, 3, 4])
  guard roundtripped.lookup_object_or_null(2) is PdfStreamObject(stream) else {
    fail("expected round-tripped content stream")
  }
  guard stream.data is StreamGot(data) else {
    fail("expected round-tripped stream data")
  }
  @test.assert_eq(try! @pdflite.pdf_parse_content_ops_from_bytes(data), [
    Op_cm({ a: 1.0, b: 0.0, c: 0.0, d: 1.0, e: 50.0, f: 770.0 }),
    Op_BT,
    Op_Tf(util_name_for_test("/F0"), 36.0),
    Op_Tj(@ascii.encode("Hello")),
    Op_ET,
  ])
}

///|
test "PdfDocument json_of_document_blob emits UTF-8 CPDFJSON bytes" {
  let document = try! @pdflite.pdf_document_of_json(
    util_cpdfjson_document_for_test(),
  )
  let exported = try! document.json_of_document(parse_content=true)
  let expected = @utf8.encode(exported.stringify())
  @test.assert_eq(
    try! document.json_of_document_blob(parse_content=true),
    expected,
  )
  @test.assert_eq(try! document.json_to_output(parse_content=true), expected)
  @test.assert_eq(
    try! @pdflite.pdf_json_of_document_blob(document, parse_content=true),
    expected,
  )
  @test.assert_eq(
    try! @pdflite.pdf_json_to_output(document, parse_content=true),
    expected,
  )
}

///|
test "pdf_document_of_json_blob imports UTF-8 CPDFJSON bytes" {
  let document = try! @pdflite.pdf_document_of_json(
    util_cpdfjson_document_for_test(),
  )
  let blob = try! document.json_of_document_blob(parse_content=true)
  let imported = try! @pdflite.pdf_document_of_json_blob(blob)
  @test.assert_eq(imported.version(), (1, 7))
  @test.assert_eq(imported.root(), 4)
  @test.assert_eq(imported.object_numbers(), [1, 2, 3, 4])

  guard imported.lookup_object_or_null(2) is PdfStreamObject(stream) else {
    fail("expected imported content stream")
  }
  guard stream.data is StreamGot(data) else {
    fail("expected imported stream data")
  }
  @test.assert_eq(try! @pdflite.pdf_parse_content_ops_from_bytes(data), [
    Op_cm({ a: 1.0, b: 0.0, c: 0.0, d: 1.0, e: 50.0, f: 770.0 }),
    Op_BT,
    Op_Tf(util_name_for_test("/F0"), 36.0),
    Op_Tj(@ascii.encode("Hello")),
    Op_ET,
  ])

  let invalid_utf8 : Result[@pdflite.PdfDocument, Error] = try
    @pdflite.pdf_document_of_json_blob(
      try! @core.pdf_bytes_of_int_array([0xFF]),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard invalid_utf8 is Err(@core.PdfError::BadText) else {
    fail("expected BadText for non-UTF8 CPDFJSON bytes")
  }

  let malformed_json : Result[@pdflite.PdfDocument, Error] = try
    @pdflite.pdf_document_of_json_blob(@utf8.encode("["))
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard malformed_json is Err(@core.PdfError::BadText) else {
    fail("expected BadText for malformed CPDFJSON bytes")
  }
}

///|
test "PdfDocument json_of_document parses content streams into operation arrays" {
  let document = try! @pdflite.pdf_document_of_json(
    util_cpdfjson_document_for_test(),
  )
  let exported = try! document.json_of_document(parse_content=true)
  @test.assert_eq(
    try! @pdflite.pdf_json_of_document(document, parse_content=true),
    exported,
  )

  guard util_cpdfjson_entry_for_test(exported, -1) is Some(params_json) else {
    fail("expected CPDFJSON params entry")
  }
  let params = try! @pdflite.pdf_object_of_json(params_json)
  @test.assert_eq(
    util_lookup_for_test(params, util_name_for_test("/CPDFJSONcontentparsed")),
    Some(PdfBoolean(true)),
  )

  guard util_cpdfjson_entry_for_test(exported, 2)
    is Some(Object(stream_wrapper)) else {
    fail("expected exported stream wrapper")
  }
  guard stream_wrapper.get("S") is Some(Array([dict_json, Array(op_jsons)])) else {
    fail("expected parsed stream JSON")
  }
  guard dict_json is Object(dict_entries) else {
    fail("expected parsed stream dictionary")
  }
  @test.assert_eq(dict_entries.get("/Length"), None)
  @test.assert_eq(op_jsons.length(), 5)
  guard op_jsons.get(0) is Some(Array([_, _, _, _, _, _, String("cm")])) else {
    fail("expected cm operator JSON")
  }
  guard op_jsons.get(1) is Some(Array([String("BT")])) else {
    fail("expected BT operator JSON")
  }
  guard op_jsons.get(2) is Some(Array([String("/F0"), _, String("Tf")])) else {
    fail("expected Tf operator JSON")
  }
  guard op_jsons.get(3) is Some(Array([String("Hello"), String("Tj")])) else {
    fail("expected Tj operator JSON")
  }
  guard op_jsons.get(4) is Some(Array([String("ET")])) else {
    fail("expected ET operator JSON")
  }

  let expected_ops : Array[@content.PdfContentOp] = [
    Op_cm({ a: 1.0, b: 0.0, c: 0.0, d: 1.0, e: 50.0, f: 770.0 }),
    Op_BT,
    Op_Tf(util_name_for_test("/F0"), 36.0),
    Op_Tj(@ascii.encode("Hello")),
    Op_ET,
  ]
  guard (try! @pdflite.pdf_object_of_json(Json::object(stream_wrapper)))
    is PdfStreamObject(parsed_stream) else {
    fail("expected parsed stream object")
  }
  guard parsed_stream.data is StreamGot(parsed_data) else {
    fail("expected parsed stream data")
  }
  @test.assert_eq(
    try! @pdflite.pdf_parse_content_ops_from_bytes(parsed_data),
    expected_ops,
  )

  let roundtripped = try! @pdflite.pdf_document_of_json(exported)
  guard roundtripped.lookup_object_or_null(2) is PdfStreamObject(stream) else {
    fail("expected round-tripped content stream")
  }
  guard stream.data is StreamGot(data) else {
    fail("expected round-tripped stream data")
  }
  @test.assert_eq(
    try! @pdflite.pdf_parse_content_ops_from_bytes(data),
    expected_ops,
  )
}

///|
test "PdfDocument json_of_document precombines split content before parsing" {
  let key_length = util_name_for_test("/Length")
  let document = @pdflite.pdf_document_empty()
  document.add_object_given_number(
    2,
    @syntax.pdf_stream(
      PdfDictionary([(key_length, PdfInteger(6))]),
      StreamGot(@ascii.encode("BT /F0")),
    ),
  )
  document.add_object_given_number(
    3,
    @syntax.pdf_stream(
      PdfDictionary([(key_length, PdfInteger(8))]),
      StreamGot(@ascii.encode("36 Tf ET")),
    ),
  )
  let page = {
    ..@page.pdf_page_blank(@geometry.paper_a4),
    content: [PdfIndirect(2), PdfIndirect(3)],
  }
  let page_root = try! document.add_pagetree([page])
  ignore(try! document.add_root(page_root, []))

  let exported = try! document.json_of_document(parse_content=true)
  @test.assert_eq(
    try! @pdflite.pdf_json_of_document(document, parse_content=true),
    exported,
  )
  @test.assert_eq(util_cpdfjson_entry_for_test(exported, 2), None)
  @test.assert_eq(util_cpdfjson_entry_for_test(exported, 3), None)
  @test.assert_eq(document.lookup_object_or_null(2) is PdfStreamObject(_), true)
  @test.assert_eq(document.lookup_object_or_null(3) is PdfStreamObject(_), true)

  let parsed_streams : Array[(Int, Array[Json])] = []
  match exported {
    Array(items) =>
      for item in items {
        match item {
          Array([Number(value, repr=_), Object(wrapper)]) if value > 0.0 =>
            match wrapper.get("S") {
              Some(Array([_, Array(op_jsons)])) =>
                parsed_streams.push((value.to_int(), op_jsons))
              _ => ()
            }
          _ => ()
        }
      }
    _ => fail("expected CPDFJSON document array")
  }
  guard parsed_streams.get(0) is Some(stream_entry) else {
    fail("expected one parsed stream entry")
  }
  @test.assert_eq(parsed_streams.length(), 1)
  @test.assert_eq(stream_entry.0 == 2 || stream_entry.0 == 3, false)
  let op_jsons = stream_entry.1
  @test.assert_eq(op_jsons.length(), 3)
  guard op_jsons.get(0) is Some(Array([String("BT")])) else {
    fail("expected BT operator JSON")
  }
  guard op_jsons.get(1) is Some(Array([String("/F0"), _, String("Tf")])) else {
    fail("expected precombined Tf operator JSON")
  }
  guard op_jsons.get(2) is Some(Array([String("ET")])) else {
    fail("expected ET operator JSON")
  }

  let roundtripped = try! @pdflite.pdf_document_of_json(exported)
  let pages = try! roundtripped.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  @test.assert_eq(try! roundtripped.parse_content_ops(pages[0].content), [
    Op_BT,
    Op_Tf(util_name_for_test("/F0"), 36.0),
    Op_ET,
  ])
}

///|
test "pdf_document_of_json rejects malformed cpdf document arrays" {
  let no_stream_data : Result[@pdflite.PdfDocument, Error] = try
    @pdflite.pdf_document_of_json([
      [
        -1.0,
        {
          "/CPDFJSONstreamdataincluded": false,
          "/CPDFJSONmajorpdfversion": { "I": 1.0 },
          "/CPDFJSONminorpdfversion": { "I": 7.0 },
        },
      ],
      [0.0, { "/Root": 1.0 }],
    ])
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard no_stream_data is Err(@core.PdfError::BadText) else {
    fail("expected BadText when CPDFJSON stream data is omitted")
  }

  let missing_root : Result[@pdflite.PdfDocument, Error] = try
    @pdflite.pdf_document_of_json([
      [
        -1.0,
        {
          "/CPDFJSONmajorpdfversion": { "I": 1.0 },
          "/CPDFJSONminorpdfversion": { "I": 7.0 },
        },
      ],
      [0.0, {}],
    ])
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard missing_root is Err(@core.PdfError::RootExpected) else {
    fail("expected RootExpected when CPDFJSON trailer omits /Root")
  }

  let bad_top : Result[@pdflite.PdfDocument, Error] = try
    @pdflite.pdf_document_of_json({})
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_top is Err(@core.PdfError::BadText) else {
    fail("expected BadText for non-array CPDFJSON top level")
  }
}

///|
test "pdf_get_dict_entries emits utf8 string wrappers when requested" {
  let key_target = util_name_for_test("/Target")
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(
    1,
    @syntax.pdf_dictionary([(key_target, PdfString(@ascii.encode("hello")))]),
  )
  let expected : Json = [{ "U": "hello" }]

  @test.assert_eq(
    try! @pdflite.pdf_get_dict_entries(doc, key_target, utf8=true),
    @utf8.encode(expected.stringify()),
  )
}

///|
test "pdf_get_dict_entries escapes malformed string and name bytes" {
  let key_target = util_name_for_test("/Target")
  let doc = @pdflite.pdf_document_empty()
  let malformed_string = try! @core.pdf_bytes_of_int_array([0xFE, 0xFF, 0x00])
  let malformed_name = @core.pdf_name_of_bytes(
    try! @core.pdf_bytes_of_int_array([47, 255]),
  )
  doc.add_object_given_number(
    1,
    @syntax.pdf_dictionary([(key_target, PdfString(malformed_string))]),
  )
  doc.add_object_given_number(
    2,
    @syntax.pdf_dictionary([(key_target, PdfNameObject(malformed_name))]),
  )
  let string_json = Json::string(
    try! @ascii.decode(@pdflite.pdf_write_hex_string(malformed_string)),
  )
  let name_json = Json::object(
    Map([
      (
        "N",
        Json::string(
          try! @ascii.decode(
            try! @pdflite.pdf_write_object(PdfNameObject(malformed_name)),
          ),
        ),
      ),
    ]),
  )
  let expected = @utf8.encode(Json::array([string_json, name_json]).stringify())

  @test.assert_eq(try! @pdflite.pdf_get_dict_entries(doc, key_target), expected)
  @test.assert_eq(
    try! @pdflite.pdf_get_dict_entries(doc, key_target, utf8=true),
    expected,
  )
}

///|
test "pdf_remove_dict_entry skips malformed stream dictionaries" {
  let key_remove = util_name_for_test("/Remove")
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(
    1,
    @syntax.pdf_stream(PdfInteger(1), StreamGot(@ascii.encode("x"))),
  )
  doc.add_object_given_number(
    2,
    @syntax.pdf_dictionary([(key_remove, PdfInteger(2))]),
  )

  @pdflite.pdf_remove_dict_entry(doc, key_remove)

  guard doc.lookup_object_or_null(1) is PdfStreamObject(stream) else {
    fail("expected malformed stream object")
  }
  @test.assert_eq(stream.dictionary, PdfInteger(1))
  @test.assert_eq(stream.data, StreamGot(@ascii.encode("x")))
  @test.assert_eq(
    util_lookup_for_test(doc.lookup_object_or_null(2), key_remove),
    None,
  )
}

///|
test "pdf_check_injectible reports cpdf shell metacharacters" {
  try! @pdflite.pdf_check_injectible("safe/名前.pdf")
  let ampersand : Result[Unit, Error] = try
    @pdflite.pdf_check_injectible("a&b.pdf")
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard ampersand is Err(@core.PdfError::InsecurePathName("a&b.pdf")) else {
    fail("expected InsecurePathName for ampersand")
  }
  let newline : Result[Unit, Error] = try
    @pdflite.pdf_check_injectible("a\nb.pdf")
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard newline is Err(@core.PdfError::InsecurePathName("a\nb.pdf")) else {
    fail("expected InsecurePathName for newline")
  }
}
