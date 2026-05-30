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
fn hello_content_ops_for_test() -> Array[@content.PdfContentOp] {
  [
    Op_cm(@geometry.transform_translate(50.0, 770.0)),
    Op_BT,
    Op_Tf(content_name_for_test("/F0"), 36.0),
    Op_Tj(content_bytes_for_test("Hello, World!")),
    Op_ET,
  ]
}

///|
fn extended_content_ops_for_test() -> Array[@content.PdfContentOp] {
  [
    Op_d([3.0, 2.0], 1.0),
    Op_ri(content_name_for_test("/RelativeColorimetric")),
    Op_i(0.5),
    Op_m(1.0, 2.0),
    Op_c(1.0, 2.0, 3.0, 4.0, 5.0, 6.0),
    Op_v(7.0, 8.0, 9.0, 10.0),
    Op_y(11.0, 12.0, 13.0, 14.0),
    Op_BT,
    Op_Tc(1.5),
    Op_Tw(2.5),
    Op_Tz(90.0),
    Op_TL(14.0),
    Op_Tr(2),
    Op_Ts(3.5),
    Op_ET,
    Op_CS(content_name_for_test("/DeviceRGB")),
    Op_SC([1.0, 0.0, 0.0]),
    Op_cs(content_name_for_test("/Pattern")),
    Op_scnName(content_name_for_test("/P1"), [0.25]),
    Op_SCNName(content_name_for_test("/P2"), [0.1, 0.2]),
    Op_sh(content_name_for_test("/S1")),
  ]
}

///|
fn comprehensive_content_ops_for_test() -> Array[@content.PdfContentOp] {
  [
    Op_w(2.0),
    Op_J(1),
    Op_j(2),
    Op_M(10.0),
    Op_l(3.0, 4.0),
    Op_h,
    Op_re(0.0, 0.0, 20.0, 30.0),
    Op_S,
    Op_s,
    Op_f,
    Op_F,
    Op_fstar,
    Op_B,
    Op_Bstar,
    Op_b,
    Op_bstar,
    Op_n,
    Op_W,
    Op_Wstar,
    Op_Td(5.0, 6.0),
    Op_TD(7.0, 8.0),
    Op_Tm(@geometry.transform_translate(9.0, 10.0)),
    Op_Tstar,
    Op_G(0.5),
    Op_g(0.25),
    Op_RG(1.0, 0.5, 0.0),
    Op_rg(0.0, 0.5, 1.0),
    Op_K(0.1, 0.2, 0.3, 0.4),
    Op_k(0.5, 0.6, 0.7, 0.8),
    Op_gs(content_name_for_test("/GS1")),
    Op_sc([0.1, 0.2]),
    Op_SCN([0.3]),
    Op_scn([0.4, 0.5]),
    Op_Do(content_name_for_test("/Im1")),
    Op_Unknown(content_bytes_for_test("1 2 ZZ")),
  ]
}

///|
fn marked_text_content_ops_for_test() -> Array[@content.PdfContentOp] {
  [
    Op_quote(content_bytes_for_test("Next")),
    Op_double_quote(3.0, 4.0, content_bytes_for_test("Spacing")),
    Op_d0(500.0, 0.0),
    Op_d1(500.0, 0.0, 0.0, -10.0, 600.0, 700.0),
    Op_MP(content_name_for_test("/Span")),
    Op_DP(
      content_name_for_test("/Span"),
      PdfDictionary([(content_name_for_test("/MCID"), PdfInteger(7))]),
    ),
    Op_BMC(content_name_for_test("/Artifact")),
    Op_BDC(
      content_name_for_test("/Span"),
      PdfNameObject(content_name_for_test("/P")),
    ),
    Op_EMC,
    Op_BX,
    Op_EX,
  ]
}

///|
fn content_stream_for_test(text : String) -> @syntax.PdfObject {
  let data = content_bytes_for_test(text)
  @syntax.pdf_stream(
    @syntax.pdf_dictionary([
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
    @syntax.pdf_dictionary([
      (key_type, PdfNameObject(content_name_for_test("/Catalog"))),
      (key_pages, PdfIndirect(2)),
    ]),
  )
  doc.add_object_given_number(
    2,
    @syntax.pdf_dictionary([
      (key_type, PdfNameObject(content_name_for_test("/Pages"))),
      (key_kids, PdfArray([PdfIndirect(3)])),
      (key_count, PdfInteger(1)),
    ]),
  )
  let font = @syntax.pdf_dictionary([
    (key_type, PdfNameObject(content_name_for_test("/Font"))),
    (key_subtype, PdfNameObject(content_name_for_test("/Type1"))),
    (key_basefont, PdfNameObject(content_name_for_test("/Times-Italic"))),
  ])
  doc.add_object_given_number(
    3,
    @syntax.pdf_dictionary([
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
        @syntax.pdf_dictionary([
          (
            key_font,
            @syntax.pdf_dictionary([(content_name_for_test("/F0"), font)]),
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
test "pdf_content_bytes_of_op renders one content operator" {
  @test.assert_eq(
    try! @pdflite.pdf_content_bytes_of_op(Op_Tj(content_bytes_for_test("One"))),
    content_bytes_for_test("(One) Tj"),
  )
  @test.assert_eq(
    try! @pdflite.pdf_content_bytes_of_op(
      Op_Unknown(content_bytes_for_test("1 2 ZZ")),
    ),
    content_bytes_for_test("1 2 ZZ"),
  )
}

///|
test "pdf_content_bytes_of_ops preserves empty unknown spacing" {
  @test.assert_eq(try! @pdflite.pdf_content_bytes_of_ops([]), Bytes::new(0))
  @test.assert_eq(
    try! @pdflite.pdf_content_bytes_of_ops([Op_Unknown(Bytes::new(0)), Op_Q]),
    content_bytes_for_test("Q"),
  )
  @test.assert_eq(
    try! @pdflite.pdf_content_bytes_of_ops([
      Op_q,
      Op_Unknown(Bytes::new(0)),
      Op_Q,
    ]),
    content_bytes_for_test("q  Q"),
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
test "pdf_parse_content_ops_from_view parses borrowed content slices" {
  let wrapped = content_bytes_for_test("xxBT /F0 12 Tf ETyy")
  @test.assert_eq(
    try! @pdflite.pdf_parse_content_ops_from_view(
      wrapped[2:wrapped.length() - 2],
    ),
    [Op_BT, Op_Tf(content_name_for_test("/F0"), 12.0), Op_ET],
  )
}

///|
test "pdf_content_bytes_of_ops renders marked content and text quote operators" {
  @test.assert_eq(
    try! @pdflite.pdf_content_bytes_of_ops(marked_text_content_ops_for_test()),
    content_bytes_for_test(
      "(Next) ' 3 4 (Spacing) \" 500 0 d0 500 0 0 -10 600 700 d1 /Span MP /Span << /MCID 7 >> DP /Artifact BMC /Span /P BDC EMC BX EX",
    ),
  )
}

///|
test "pdf_parse_content_ops_from_bytes parses marked content and text quote operators" {
  let data = content_bytes_for_test(
    "(Next) ' 3 4 (Spacing) \" 500 0 d0 500 0 0 -10 600 700 d1 /Span MP /Span << /MCID 7 >> DP /Artifact BMC /Span /P BDC EMC BX EX",
  )
  @test.assert_eq(
    try! @pdflite.pdf_parse_content_ops_from_bytes(data),
    marked_text_content_ops_for_test(),
  )
  @test.assert_eq(
    try! @pdflite.pdf_content_bytes_of_ops(
      try! @pdflite.pdf_parse_content_ops_from_bytes(data),
    ),
    data,
  )
}

///|
test "pdf_content artifact helpers mirror CamlPDF artifact markers" {
  let ops = [
    @content.pdf_content_begin_artifact(),
    Op_Tj(content_bytes_for_test("artifact")),
    @content.pdf_content_end_artifact(),
  ]
  let data = content_bytes_for_test("/Artifact BMC (artifact) Tj EMC")
  @test.assert_eq(try! @pdflite.pdf_content_bytes_of_ops(ops), data)
  @test.assert_eq(try! @pdflite.pdf_parse_content_ops_from_bytes(data), ops)
}

///|
test "@content.pdf_content_add_artifacts wraps unmarked operator runs" {
  @test.assert_eq(
    @content.pdf_content_add_artifacts([
      Op_q,
      Op_Tj(content_bytes_for_test("artifact")),
      Op_Q,
    ]),
    [
      @content.pdf_content_begin_artifact(),
      Op_q,
      Op_Tj(content_bytes_for_test("artifact")),
      Op_Q,
      @content.pdf_content_end_artifact(),
    ],
  )
  @test.assert_eq(@content.pdf_content_add_artifacts([]), [])
}

///|
test "@content.pdf_content_add_artifacts preserves real marked content" {
  let span = content_name_for_test("/Span")
  let properties = @syntax.pdf_dictionary([
    (content_name_for_test("/MCID"), PdfInteger(7)),
  ])
  @test.assert_eq(
    @content.pdf_content_add_artifacts([
      Op_Tj(content_bytes_for_test("artifact")),
      Op_BDC(span, properties),
      Op_Tj(content_bytes_for_test("content")),
      Op_EMC,
      Op_Tj(content_bytes_for_test("tail")),
    ]),
    [
      @content.pdf_content_begin_artifact(),
      Op_Tj(content_bytes_for_test("artifact")),
      @content.pdf_content_end_artifact(),
      Op_BDC(span, properties),
      Op_Tj(content_bytes_for_test("content")),
      Op_EMC,
      @content.pdf_content_begin_artifact(),
      Op_Tj(content_bytes_for_test("tail")),
      @content.pdf_content_end_artifact(),
    ],
  )
}

///|
test "@content.pdf_content_add_artifacts converts cpdftype back-channel artifact markers" {
  @test.assert_eq(
    @content.pdf_content_add_artifacts([
      Op_BMC(content_name_for_test("/BeginArtifact")),
      Op_Tj(content_bytes_for_test("backchannel")),
      Op_BMC(content_name_for_test("/EndArtifact")),
    ]),
    [
      @content.pdf_content_begin_artifact(),
      Op_Tj(content_bytes_for_test("backchannel")),
      @content.pdf_content_end_artifact(),
    ],
  )
}

///|
test "pdf_content_bytes_of_ops renders extended graphics and text operators" {
  @test.assert_eq(
    try! @pdflite.pdf_content_bytes_of_ops(extended_content_ops_for_test()),
    content_bytes_for_test(
      "[3 2] 1 d /RelativeColorimetric ri 0.5 i 1 2 m 1 2 3 4 5 6 c 7 8 9 10 v 11 12 13 14 y BT 1.5 Tc 2.5 Tw 90 Tz 14 TL 2 Tr 3.5 Ts ET /DeviceRGB CS 1 0 0 SC /Pattern cs 0.25 /P1 scn 0.1 0.2 /P2 SCN /S1 sh",
    ),
  )
}

///|
test "pdf_parse_content_ops_from_bytes parses extended graphics and text operators" {
  let data = content_bytes_for_test(
    "[3 2] 1 d /RelativeColorimetric ri 0.5 i 1 2 m 1 2 3 4 5 6 c 7 8 9 10 v 11 12 13 14 y BT 1.5 Tc 2.5 Tw 90 Tz 14 TL 2 Tr 3.5 Ts ET /DeviceRGB CS 1 0 0 SC /Pattern cs 0.25 /P1 scn 0.1 0.2 /P2 SCN /S1 sh",
  )
  @test.assert_eq(
    try! @pdflite.pdf_parse_content_ops_from_bytes(data),
    extended_content_ops_for_test(),
  )
  @test.assert_eq(
    try! @pdflite.pdf_content_bytes_of_ops(
      try! @pdflite.pdf_parse_content_ops_from_bytes(data),
    ),
    data,
  )
}

///|
test "pdf_content_bytes_of_ops renders comprehensive operator coverage" {
  let data = content_bytes_for_test(
    "2 w 1 J 2 j 10 M 3 4 l h 0 0 20 30 re S s f F f* B B* b b* n W W* 5 6 Td 7 8 TD 1 0 0 1 9 10 Tm T* 0.5 G 0.25 g 1 0.5 0 RG 0 0.5 1 rg 0.1 0.2 0.3 0.4 K 0.5 0.6 0.7 0.8 k /GS1 gs 0.1 0.2 sc 0.3 SCN 0.4 0.5 scn /Im1 Do 1 2 ZZ",
  )
  @test.assert_eq(
    try! @pdflite.pdf_content_bytes_of_ops(comprehensive_content_ops_for_test()),
    data,
  )
}

///|
test "pdf_parse_content_ops_from_bytes parses comprehensive operator coverage" {
  let data = content_bytes_for_test(
    "2 w 1 J 2 j 10 M 3 4 l h 0 0 20 30 re S s f F f* B B* b b* n W W* 5 6 Td 7 8 TD 1 0 0 1 9 10 Tm T* 0.5 G 0.25 g 1 0.5 0 RG 0 0.5 1 rg 0.1 0.2 0.3 0.4 K 0.5 0.6 0.7 0.8 k /GS1 gs 0.1 0.2 sc 0.3 SCN 0.4 0.5 scn /Im1 Do 1 2 ZZ",
  )
  @test.assert_eq(
    try! @pdflite.pdf_parse_content_ops_from_bytes(data),
    comprehensive_content_ops_for_test(),
  )
  @test.assert_eq(
    try! @pdflite.pdf_content_bytes_of_ops(
      try! @pdflite.pdf_parse_content_ops_from_bytes(data),
    ),
    data,
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
  doc.add_object_given_number(
    8,
    PdfNameObject(content_name_for_test("/ASCIIHexDecode")),
  )
  let encoded = @codec.pdf_ascii_hex_encode(content_bytes_for_test("q Q"))
  doc.add_object_given_number(
    9,
    @syntax.pdf_stream(
      @syntax.pdf_dictionary([
        (content_name_for_test("/Length"), PdfInteger(encoded.length())),
        (content_name_for_test("/Filter"), PdfIndirect(8)),
      ]),
      StreamGot(encoded),
    ),
  )
  @test.assert_eq(try! doc.parse_content_ops([PdfIndirect(9)]), [Op_q, Op_Q])
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
test "PdfDocument parse_content_ops_with_resources sizes named inline image spaces" {
  let doc = @pdflite.pdf_document_empty()
  let resources = @syntax.pdf_dictionary([
    (
      content_name_for_test("/ColorSpace"),
      @syntax.pdf_dictionary([
        (
          content_name_for_test("/CS1"),
          PdfNameObject(content_name_for_test("/RGB")),
        ),
      ]),
    ),
  ])
  @test.assert_eq(
    try! doc.parse_content_ops_with_resources(resources, [
      content_stream_for_test("BI /W 2 /H 1 /BPC 8 /CS /CS1 ID A EI B EI Q"),
    ]),
    [
      Op_InlineImage(
        @syntax.pdf_dictionary([
          (content_name_for_test("/W"), PdfInteger(2)),
          (content_name_for_test("/H"), PdfInteger(1)),
          (content_name_for_test("/BPC"), PdfInteger(8)),
          (
            content_name_for_test("/CS"),
            PdfNameObject(content_name_for_test("/CS1")),
          ),
        ]),
        None,
        content_bytes_for_test("A EI B"),
      ),
      Op_Q,
    ],
  )
}

///|
test "PdfDocument parse_content_bytes_with_resources parses one resource-aware stream" {
  let doc = @pdflite.pdf_document_empty()
  let resources = @syntax.pdf_dictionary([
    (
      content_name_for_test("/ColorSpace"),
      @syntax.pdf_dictionary([
        (
          content_name_for_test("/CS1"),
          PdfNameObject(content_name_for_test("/RGB")),
        ),
      ]),
    ),
  ])
  @test.assert_eq(
    try! doc.parse_content_bytes_with_resources(
      resources,
      content_bytes_for_test("BI /W 2 /H 1 /BPC 8 /CS /CS1 ID A EI B EI"),
    ),
    [
      Op_InlineImage(
        @syntax.pdf_dictionary([
          (content_name_for_test("/W"), PdfInteger(2)),
          (content_name_for_test("/H"), PdfInteger(1)),
          (content_name_for_test("/BPC"), PdfInteger(8)),
          (
            content_name_for_test("/CS"),
            PdfNameObject(content_name_for_test("/CS1")),
          ),
        ]),
        None,
        content_bytes_for_test("A EI B"),
      ),
    ],
  )
}

///|
test "PdfDocument parse_content_ops_with_resources sizes array inline image spaces" {
  let doc = @pdflite.pdf_document_empty()
  @test.assert_eq(
    try! doc.parse_content_ops_with_resources(@syntax.pdf_dictionary([]), [
      content_stream_for_test("BI /W 2 /H 1 /BPC 8 /CS [/RGB] ID A EI B EI Q"),
    ]),
    [
      Op_InlineImage(
        @syntax.pdf_dictionary([
          (content_name_for_test("/W"), PdfInteger(2)),
          (content_name_for_test("/H"), PdfInteger(1)),
          (content_name_for_test("/BPC"), PdfInteger(8)),
          (
            content_name_for_test("/CS"),
            PdfArray([PdfNameObject(content_name_for_test("/RGB"))]),
          ),
        ]),
        None,
        content_bytes_for_test("A EI B"),
      ),
      Op_Q,
    ],
  )
}

///|
test "PdfDocument parse_content_ops_with_resources reports missing inline image resources" {
  let doc = @pdflite.pdf_document_empty()
  @test.assert_eq(
    try! doc.parse_content_ops_with_resources(@syntax.pdf_dictionary([]), [
      content_stream_for_test(
        "BI /W 1 /H 1 /BPC 8 /CS /Missing /L 6 ID A EI B\nEI Q",
      ),
    ]),
    [
      Op_InlineImage(
        @syntax.pdf_dictionary([
          (content_name_for_test("/W"), PdfInteger(1)),
          (content_name_for_test("/H"), PdfInteger(1)),
          (content_name_for_test("/BPC"), PdfInteger(8)),
          (
            content_name_for_test("/CS"),
            PdfNameObject(content_name_for_test("/Missing")),
          ),
          (content_name_for_test("/L"), PdfInteger(6)),
        ]),
        None,
        content_bytes_for_test("A EI B"),
      ),
      Op_Q,
    ],
  )
  let result : Result[Array[@content.PdfContentOp], Error] = try? doc.parse_content_ops_with_resources(
    @syntax.pdf_dictionary([]),
    [content_stream_for_test("BI /W 1 /H 1 /BPC 8 /CS /Missing ID abc EI")],
  )
  guard result is Err(@pdflite.PdfError::DictionaryKeyNotFound(name)) &&
    name == content_name_for_test("/ColorSpace") else {
    fail("expected missing ColorSpace resource dictionary")
  }
}

///|
test "pdf_content_concat_streams inserts whitespace between split bytes" {
  @test.assert_eq(
    @pdflite.pdf_content_concat_streams([
      content_bytes_for_test("q"),
      content_bytes_for_test("Q"),
      content_bytes_for_test("BT"),
    ]),
    content_bytes_for_test("q Q BT"),
  )
  @test.assert_eq(@pdflite.pdf_content_concat_streams([]), Bytes::new(0))
  @test.assert_eq(
    @pdflite.pdf_content_concat_streams([
      Bytes::new(0),
      content_bytes_for_test("q"),
    ]),
    content_bytes_for_test("q"),
  )
  @test.assert_eq(
    @pdflite.pdf_content_concat_streams([
      content_bytes_for_test("q"),
      Bytes::new(0),
      content_bytes_for_test("Q"),
    ]),
    content_bytes_for_test("q  Q"),
  )
}

///|
test "pdf_content_concat_stream_views inserts whitespace between borrowed slices" {
  let first = content_bytes_for_test("xxq")
  let second = content_bytes_for_test("Qyy")
  let third = content_bytes_for_test("zzBTww")
  @test.assert_eq(
    @pdflite.pdf_content_concat_stream_views([
      first[2:],
      second[:second.length() - 2],
      third[2:third.length() - 2],
    ]),
    content_bytes_for_test("q Q BT"),
  )
  @test.assert_eq(
    @pdflite.pdf_content_concat_stream_views([first[:0], first[2:]]),
    content_bytes_for_test("q"),
  )
  @test.assert_eq(
    @pdflite.pdf_content_concat_stream_views([
      first[2:],
      second[:0],
      second[:second.length() - 2],
    ]),
    content_bytes_for_test("q  Q"),
  )
}

///|
test "pdf_string_of_content_op exposes CamlPDF byte-oriented debug strings" {
  @test.assert_eq(
    try! @pdflite.pdf_string_of_content_op(Op_q),
    content_bytes_for_test("q"),
  )
  @test.assert_eq(
    try! @pdflite.pdf_string_of_content_ops([
      Op_q,
      Op_Tf(content_name_for_test("/F1"), 12.0),
      Op_Tj(try! @pdflite.pdf_bytes_of_int_array([65, 0xFF])),
      Op_Q,
    ]),
    content_bytes_for_test("q /F1 12 Tf (A\\377) Tj Q"),
  )
}

///|
test "PdfDocument parse_content_ops reports non-stream content objects" {
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(10, PdfInteger(42))
  let result : Result[Array[@content.PdfContentOp], Error] = try? doc.parse_content_ops([
      PdfIndirect(10),
    ],
  )
  guard result is Err(@pdflite.PdfError::ParseStreamExpected) else {
    fail("expected @pdflite.PdfError::ParseStreamExpected")
  }
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
test "pdf_parse_content_ops_from_bytes handles literal operands before unknown operators" {
  @test.assert_eq(
    try! @pdflite.pdf_parse_content_ops_from_bytes(
      content_bytes_for_test("true false null XX"),
    ),
    [Op_Unknown(content_bytes_for_test("true false null XX"))],
  )
}

///|
test "pdf_parse_content_ops_from_bytes parses text array operators" {
  let data = content_bytes_for_test("[(A) -20 (B)] TJ")
  @test.assert_eq(try! @pdflite.pdf_parse_content_ops_from_bytes(data), [
    Op_TJ(
      PdfArray([
        PdfString(content_bytes_for_test("A")),
        PdfReal(-20.0),
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
test "pdf_parse_content_ops_from_bytes skips malformed text array members" {
  let data = content_bytes_for_test("[(A) [1] << /K 2 >> -2 (B)] TJ")
  @test.assert_eq(try! @pdflite.pdf_parse_content_ops_from_bytes(data), [
    Op_TJ(
      PdfArray([
        PdfString(content_bytes_for_test("A")),
        PdfReal(-2.0),
        PdfString(content_bytes_for_test("B")),
      ]),
    ),
  ])
  @test.assert_eq(
    try! @pdflite.pdf_content_bytes_of_ops(
      try! @pdflite.pdf_parse_content_ops_from_bytes(data),
    ),
    content_bytes_for_test("[(A) -2 (B)] TJ"),
  )
}

///|
test "pdf_parse_content_ops_from_bytes preserves invalid known-operator operands" {
  let data = content_bytes_for_test("true w /Bad J 1 ri /Bad Tj 1 TJ 1 Do")
  @test.assert_eq(try! @pdflite.pdf_parse_content_ops_from_bytes(data), [
    Op_Unknown(content_bytes_for_test("true w")),
    Op_Unknown(content_bytes_for_test("/Bad J")),
    Op_Unknown(content_bytes_for_test("1 ri")),
    Op_Unknown(content_bytes_for_test("/Bad Tj")),
    Op_Unknown(content_bytes_for_test("1 TJ")),
    Op_Unknown(content_bytes_for_test("1 Do")),
  ])
}

///|
test "pdf_parse_content_ops_from_bytes uses CamlPDF malformed color fallback" {
  let data = content_bytes_for_test(
    "SCN scn true SC /Bad sc null SCN true /Spot scn /TintOnly scn",
  )
  @test.assert_eq(try! @pdflite.pdf_parse_content_ops_from_bytes(data), [
    Op_SCN([]),
    Op_scn([]),
    Op_SC([0.0, 0.0, 0.0]),
    Op_sc([0.0, 0.0, 0.0]),
    Op_SCN([0.0, 0.0, 0.0]),
    Op_scnName(content_name_for_test("/Spot"), [0.0, 0.0, 0.0]),
    Op_scnName(content_name_for_test("/TintOnly"), []),
  ])
}

///|
test "pdf_parse_content_ops_from_bytes reports trailing operands" {
  let result : Result[Array[@content.PdfContentOp], Error] = try? @pdflite.pdf_parse_content_ops_from_bytes(
    content_bytes_for_test("1 2"),
  )
  guard result is Err(@pdflite.PdfError::ContentOperatorExpected) else {
    fail("expected @pdflite.PdfError::ContentOperatorExpected")
  }
}

///|
test "pdf content parser reports malformed complex and inline-image operands" {
  let malformed_dash : Result[Array[@content.PdfContentOp], Error] = try? @pdflite.pdf_parse_content_ops_from_bytes(
    content_bytes_for_test("[/Bad] 0 d"),
  )
  guard malformed_dash is Err(@pdflite.PdfError::NumberExpected) else {
    fail("expected @pdflite.PdfError::NumberExpected")
  }
  let malformed_array : Result[Array[@content.PdfContentOp], Error] = try? @pdflite.pdf_parse_content_ops_from_bytes(
    content_bytes_for_test("[(A) 1 TJ"),
  )
  guard malformed_array is Err(@pdflite.PdfError::ParseObjectExpected) else {
    fail("expected @pdflite.PdfError::ParseObjectExpected")
  }
  let malformed_inline_image : Result[Array[@content.PdfContentOp], Error] = try? @pdflite.pdf_parse_content_ops_from_bytes(
    content_bytes_for_test("BI /W ID abc EI"),
  )
  guard malformed_inline_image is Err(@pdflite.PdfError::ContentOperandExpected) else {
    fail("expected @pdflite.PdfError::ContentOperandExpected")
  }
  let malformed_inline_dictionary : Result[@pdflite.PdfBytes, Error] = try? @pdflite.pdf_content_bytes_of_ops([
      Op_InlineImage(PdfInteger(1), None, content_bytes_for_test("abc")),
    ],
  )
  guard malformed_inline_dictionary
    is Err(@pdflite.PdfError::DictionaryExpected) else {
    fail("expected @pdflite.PdfError::DictionaryExpected")
  }
}
