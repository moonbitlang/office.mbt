///|
fn content_bytes_for_test(text : String) -> @pdflite.PdfBytes {
  @ascii.encode(text)
}

///|
fn content_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn content_concat_for_test(
  parts : ArrayView[@pdflite.PdfBytes],
) -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  for part in parts {
    for byte in part {
      output.push(byte)
    }
  }
  Bytes::from_array(output)
}

///|
fn hello_content_ops_for_test() -> Array[@pdflite.PdfContentOp] {
  [
    Op_cm(@pdflite.transform_translate(50.0, 770.0)),
    Op_BT,
    Op_Tf(content_name_for_test("/F0"), 36.0),
    Op_Tj(content_bytes_for_test("Hello, World!")),
    Op_ET,
  ]
}

///|
fn content_stream_for_test(text : String) -> @pdflite.PdfObject {
  let data = content_bytes_for_test(text)
  @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (content_name_for_test("/Length"), PdfInteger(data.length())),
    ]),
    StreamGot(data),
  )
}

///|
fn hello_document_for_content_test() -> @pdflite.PdfDocument {
  let key_type = content_name_for_test("/Type")
  let key_pages = content_name_for_test("/Pages")
  let key_kids = content_name_for_test("/Kids")
  let key_count = content_name_for_test("/Count")
  let key_parent = content_name_for_test("/Parent")
  let key_mediabox = content_name_for_test("/MediaBox")
  let key_resources = content_name_for_test("/Resources")
  let key_font = content_name_for_test("/Font")
  let key_contents = content_name_for_test("/Contents")
  let key_subtype = content_name_for_test("/Subtype")
  let key_basefont = content_name_for_test("/BaseFont")
  let doc = @pdflite.pdf_document_empty()
  doc.set_root(1)
  doc.add_object_given_number(
    1,
    @pdflite.pdf_dictionary([
      (key_type, PdfNameObject(content_name_for_test("/Catalog"))),
      (key_pages, PdfIndirect(2)),
    ]),
  )
  doc.add_object_given_number(
    2,
    @pdflite.pdf_dictionary([
      (key_type, PdfNameObject(content_name_for_test("/Pages"))),
      (key_kids, PdfArray([PdfIndirect(3)])),
      (key_count, PdfInteger(1)),
    ]),
  )
  let font = @pdflite.pdf_dictionary([
    (key_type, PdfNameObject(content_name_for_test("/Font"))),
    (key_subtype, PdfNameObject(content_name_for_test("/Type1"))),
    (key_basefont, PdfNameObject(content_name_for_test("/Times-Italic"))),
  ])
  doc.add_object_given_number(
    3,
    @pdflite.pdf_dictionary([
      (key_type, PdfNameObject(content_name_for_test("/Page"))),
      (key_parent, PdfIndirect(2)),
      (
        key_mediabox,
        PdfArray([
          PdfInteger(0),
          PdfInteger(0),
          PdfInteger(612),
          PdfInteger(792),
        ]),
      ),
      (
        key_resources,
        @pdflite.pdf_dictionary([
          (
            key_font,
            @pdflite.pdf_dictionary([(content_name_for_test("/F0"), font)]),
          ),
        ]),
      ),
      (key_contents, PdfIndirect(4)),
    ]),
  )
  doc.add_object_given_number(
    4,
    try! @pdflite.pdf_content_stream_of_ops(hello_content_ops_for_test()),
  )
  doc
}

///|
test "pdf_content_bytes_of_ops renders hello-style content bytes" {
  @test.assert_eq(
    try! @pdflite.pdf_content_bytes_of_ops(hello_content_ops_for_test()),
    content_bytes_for_test(
      "1 0 0 1 50 770 cm BT /F0 36 Tf (Hello, World!) Tj ET",
    ),
  )
}

///|
test "pdf_parse_content_ops_from_bytes parses hello-style content bytes" {
  @test.assert_eq(
    try! @pdflite.pdf_parse_content_ops_from_bytes(
      content_bytes_for_test(
        "1 0 0 1 50 770 cm BT /F0 36 Tf (Hello, World!) Tj ET",
      ),
    ),
    hello_content_ops_for_test(),
  )
}

///|
test "pdf_content_stream_of_ops creates an owned stream that round trips" {
  let stream = try! @pdflite.pdf_content_stream_of_ops(
    hello_content_ops_for_test(),
  )
  guard stream is PdfStreamObject({ dictionary, data: StreamGot(data) }) else {
    fail("expected owned content stream")
  }
  @test.assert_eq(
    dictionary.lookup_immediate(content_name_for_test("/Length")),
    Some(PdfInteger(data.length())),
  )
  @test.assert_eq(
    try! @pdflite.pdf_parse_content_ops_from_bytes(data),
    hello_content_ops_for_test(),
  )
  let parsed = try! @pdflite.pdf_parse_stream_object_from_bytes(
    content_concat_for_test([
      content_bytes_for_test("1 0 obj\n"),
      try! @pdflite.pdf_write_object(stream),
      content_bytes_for_test("\nendobj"),
    ]),
  )
  guard parsed.object is PdfStreamObject(parsed_stream) else {
    fail("expected parsed stream object")
  }
  guard parsed_stream.data is StreamGot(parsed_data) else {
    fail("expected parsed stream object")
  }
  @test.assert_eq(parsed_data, data)
}

///|
test "content operators survive minimal page document writer and reader round trip" {
  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    try! @pdflite.pdf_write_document(hello_document_for_content_test()),
  )
  @test.assert_eq(try! parsed.page_reference_numbers(), [3])
  @test.assert_eq(
    try! parsed.parse_content_ops([PdfIndirect(4)]),
    hello_content_ops_for_test(),
  )
}

///|
test "PdfDocument parse_content_ops reads indirect owned content streams" {
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(
    7,
    try! @pdflite.pdf_content_stream_of_ops(hello_content_ops_for_test()),
  )
  @test.assert_eq(
    try! doc.parse_content_ops([PdfIndirect(7)]),
    hello_content_ops_for_test(),
  )
}

///|
test "PdfDocument parse_content_ops inserts whitespace between split streams" {
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(8, content_stream_for_test("BT /F0 36 Tf"))
  doc.add_object_given_number(9, content_stream_for_test("(Hello) Tj ET"))
  @test.assert_eq(
    try! doc.parse_content_ops([PdfIndirect(8), PdfIndirect(9)]),
    [
      Op_BT,
      Op_Tf(content_name_for_test("/F0"), 36.0),
      Op_Tj(content_bytes_for_test("Hello")),
      Op_ET,
    ],
  )
}

///|
test "pdf_parse_content_ops_from_bytes ignores comments and preserves unknown operators" {
  @test.assert_eq(
    try! @pdflite.pdf_parse_content_ops_from_bytes(
      content_bytes_for_test("q % ignored\n1 2 ZZ Q"),
    ),
    [Op_q, Op_Unknown(content_bytes_for_test("1 2 ZZ")), Op_Q],
  )
}

///|
test "pdf_parse_content_ops_from_bytes parses text array operators" {
  let data = content_bytes_for_test("[(A) -20 (B)] TJ")
  @test.assert_eq(try! @pdflite.pdf_parse_content_ops_from_bytes(data), [
    Op_TJ(
      PdfArray([
        PdfString(content_bytes_for_test("A")),
        PdfInteger(-20),
        PdfString(content_bytes_for_test("B")),
      ]),
    ),
  ])
  @test.assert_eq(
    try! @pdflite.pdf_content_bytes_of_ops(
      try! @pdflite.pdf_parse_content_ops_from_bytes(data),
    ),
    data,
  )
}

///|
test "pdf_parse_content_ops_from_bytes reports trailing operands" {
  let result : Result[Array[@pdflite.PdfContentOp], Error] = try? @pdflite.pdf_parse_content_ops_from_bytes(
    content_bytes_for_test("1 2"),
  )
  guard result is Err(@pdflite.PdfError::ContentOperatorExpected) else {
    fail("expected ContentOperatorExpected")
  }
}
