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
fn content_lzw_codes_for_test(
  codes : ArrayView[Int],
  early_change : Int,
) -> @pdflite.PdfBytes {
  let writer = @pdflite.bit_writer_new()
  let mut code_length = 9
  let mut next_code = 258
  let mut old_code = 256
  for code in codes {
    try! writer.put_value_int(code_length, code)
    match code {
      256 => {
        code_length = 9
        next_code = 258
        old_code = 256
      }
      257 => ()
      _ =>
        if old_code == 256 {
          old_code = code
        } else {
          next_code += 1
          match next_code + early_change {
            512 | 1024 | 2048 => code_length += 1
            _ => ()
          }
          old_code = code
        }
    }
  }
  writer.to_bytes()
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
fn extended_content_ops_for_test() -> Array[@pdflite.PdfContentOp] {
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
fn comprehensive_content_ops_for_test() -> Array[@pdflite.PdfContentOp] {
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
    Op_Tm(@pdflite.transform_translate(9.0, 10.0)),
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
fn marked_text_content_ops_for_test() -> Array[@pdflite.PdfContentOp] {
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
fn inline_image_content_op_for_test() -> @pdflite.PdfContentOp {
  Op_InlineImage(
    PdfDictionary([
      (content_name_for_test("/W"), PdfInteger(1)),
      (content_name_for_test("/H"), PdfInteger(1)),
      (
        content_name_for_test("/CS"),
        PdfNameObject(content_name_for_test("/RGB")),
      ),
      (content_name_for_test("/BPC"), PdfInteger(8)),
    ]),
    Some(PdfDictionary([(content_name_for_test("/Predictor"), PdfInteger(1))])),
    content_bytes_for_test("abc"),
  )
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
test "pdf_content_bytes_of_ops renders simple inline images" {
  @test.assert_eq(
    try! @pdflite.pdf_content_bytes_of_ops([inline_image_content_op_for_test()]),
    content_bytes_for_test(
      "BI /W 1 /H 1 /CS /RGB /BPC 8 /DP << /Predictor 1 >> ID abc EI",
    ),
  )
}

///|
test "pdf_parse_content_ops_from_bytes parses simple inline images" {
  let data = content_bytes_for_test(
    "q BI /W 1 /H 1 /CS /RGB /BPC 8 /DP << /Predictor 1 >> ID abc\nEI Q",
  )
  @test.assert_eq(try! @pdflite.pdf_parse_content_ops_from_bytes(data), [
    Op_q,
    inline_image_content_op_for_test(),
    Op_Q,
  ])
  @test.assert_eq(
    try! @pdflite.pdf_content_bytes_of_ops(
      try! @pdflite.pdf_parse_content_ops_from_bytes(data),
    ),
    content_bytes_for_test(
      "q BI /W 1 /H 1 /CS /RGB /BPC 8 /DP << /Predictor 1 >> ID abc EI Q",
    ),
  )
}

///|
test "pdf_parse_content_ops_from_bytes falls back for array inline image spaces" {
  let data = content_bytes_for_test("BI /W 1 /H 1 /CS [/RGB] /BPC 8 ID abc EI")
  @test.assert_eq(try! @pdflite.pdf_parse_content_ops_from_bytes(data), [
    Op_InlineImage(
      @pdflite.pdf_dictionary([
        (content_name_for_test("/W"), PdfInteger(1)),
        (content_name_for_test("/H"), PdfInteger(1)),
        (
          content_name_for_test("/CS"),
          PdfArray([PdfNameObject(content_name_for_test("/RGB"))]),
        ),
        (content_name_for_test("/BPC"), PdfInteger(8)),
      ]),
      None,
      content_bytes_for_test("abc"),
    ),
  ])
}

///|
test "pdf_parse_content_ops_from_bytes preserves raw inline image EI bytes" {
  let data = content_bytes_for_test(
    "BI /W 6 /H 1 /CS /G /BPC 8 ID A EI B\nEI Q",
  )
  @test.assert_eq(try! @pdflite.pdf_parse_content_ops_from_bytes(data), [
    Op_InlineImage(
      PdfDictionary([
        (content_name_for_test("/W"), PdfInteger(6)),
        (content_name_for_test("/H"), PdfInteger(1)),
        (
          content_name_for_test("/CS"),
          PdfNameObject(content_name_for_test("/G")),
        ),
        (content_name_for_test("/BPC"), PdfInteger(8)),
      ]),
      None,
      content_bytes_for_test("A EI B"),
    ),
    Op_Q,
  ])
}

///|
test "pdf_parse_content_ops_from_bytes preserves image mask EI bytes" {
  let data = content_bytes_for_test("BI /W 16 /H 1 /IM true ID EI\nEI")
  @test.assert_eq(try! @pdflite.pdf_parse_content_ops_from_bytes(data), [
    Op_InlineImage(
      PdfDictionary([
        (content_name_for_test("/W"), PdfInteger(16)),
        (content_name_for_test("/H"), PdfInteger(1)),
        (content_name_for_test("/IM"), PdfBoolean(true)),
      ]),
      None,
      content_bytes_for_test("EI"),
    ),
  ])
}

///|
test "pdf_parse_content_ops_from_bytes decodes ASCIIHex inline images" {
  let data = content_bytes_for_test(
    "BI /W 3 /H 1 /CS /G /BPC 8 /F /AHx /DP << /Predictor 1 >> ID 616263>\nEI",
  )
  let parsed = try! @pdflite.pdf_parse_content_ops_from_bytes(data)
  @test.assert_eq(parsed, [
    Op_InlineImage(
      PdfDictionary([
        (content_name_for_test("/W"), PdfInteger(3)),
        (content_name_for_test("/H"), PdfInteger(1)),
        (
          content_name_for_test("/CS"),
          PdfNameObject(content_name_for_test("/G")),
        ),
        (content_name_for_test("/BPC"), PdfInteger(8)),
      ]),
      None,
      content_bytes_for_test("abc"),
    ),
  ])
  @test.assert_eq(
    try! @pdflite.pdf_content_bytes_of_ops(parsed),
    content_bytes_for_test("BI /W 3 /H 1 /CS /G /BPC 8 ID abc EI"),
  )
}

///|
test "pdf_parse_content_ops_from_bytes decodes ASCII85 inline image arrays" {
  let encoded = @pdflite.pdf_ascii85_encode(content_bytes_for_test("abc"))
  let data = content_concat_for_test([
    content_bytes_for_test("BI /W 1 /H 1 /CS /RGB /BPC 8 /Filter [ /A85 ] ID "),
    encoded,
    content_bytes_for_test("\nEI"),
  ])
  @test.assert_eq(try! @pdflite.pdf_parse_content_ops_from_bytes(data), [
    Op_InlineImage(
      PdfDictionary([
        (content_name_for_test("/W"), PdfInteger(1)),
        (content_name_for_test("/H"), PdfInteger(1)),
        (
          content_name_for_test("/CS"),
          PdfNameObject(content_name_for_test("/RGB")),
        ),
        (content_name_for_test("/BPC"), PdfInteger(8)),
      ]),
      None,
      content_bytes_for_test("abc"),
    ),
  ])
}

///|
test "pdf_parse_content_ops_from_bytes reads ASCII85 inline images through terminator" {
  let data = content_concat_for_test([
    content_bytes_for_test("BI /W 3 /H 1 /CS /G /BPC 8 /F /A85 ID "),
    content_bytes_for_test("!%\nEI\n~>"),
    content_bytes_for_test("\nEI Q"),
  ])
  @test.assert_eq(try! @pdflite.pdf_parse_content_ops_from_bytes(data), [
    Op_InlineImage(
      PdfDictionary([
        (content_name_for_test("/W"), PdfInteger(3)),
        (content_name_for_test("/H"), PdfInteger(1)),
        (
          content_name_for_test("/CS"),
          PdfNameObject(content_name_for_test("/G")),
        ),
        (content_name_for_test("/BPC"), PdfInteger(8)),
      ]),
      None,
      try! @pdflite.pdf_bytes_of_int_array([0, 41, 129]),
    ),
    Op_Q,
  ])
}

///|
test "pdf_parse_content_ops_from_bytes decodes RunLength inline images" {
  let encoded = @pdflite.pdf_run_length_encode(content_bytes_for_test("A EI B"))
  let data = content_concat_for_test([
    content_bytes_for_test("BI /W 6 /H 1 /CS /G /BPC 8 /F /RL ID "),
    encoded,
    content_bytes_for_test("\nEI Q"),
  ])
  @test.assert_eq(try! @pdflite.pdf_parse_content_ops_from_bytes(data), [
    Op_InlineImage(
      PdfDictionary([
        (content_name_for_test("/W"), PdfInteger(6)),
        (content_name_for_test("/H"), PdfInteger(1)),
        (
          content_name_for_test("/CS"),
          PdfNameObject(content_name_for_test("/G")),
        ),
        (content_name_for_test("/BPC"), PdfInteger(8)),
      ]),
      None,
      content_bytes_for_test("A EI B"),
    ),
    Op_Q,
  ])

  let array_encoded = @pdflite.pdf_run_length_encode(
    content_bytes_for_test("ABCZZZZ"),
  )
  let array_data = content_concat_for_test([
    content_bytes_for_test(
      "BI /W 7 /H 1 /CS /G /BPC 8 /Filter [ /RunLengthDecode ] ID ",
    ),
    array_encoded,
    content_bytes_for_test("\nEI"),
  ])
  @test.assert_eq(try! @pdflite.pdf_parse_content_ops_from_bytes(array_data), [
    Op_InlineImage(
      PdfDictionary([
        (content_name_for_test("/W"), PdfInteger(7)),
        (content_name_for_test("/H"), PdfInteger(1)),
        (
          content_name_for_test("/CS"),
          PdfNameObject(content_name_for_test("/G")),
        ),
        (content_name_for_test("/BPC"), PdfInteger(8)),
      ]),
      None,
      content_bytes_for_test("ABCZZZZ"),
    ),
  ])
}

///|
test "pdf_parse_content_ops_from_bytes decodes Flate inline images through zlib end" {
  let encoded = @pdflite.pdf_flate_encode(content_bytes_for_test("A EI B"))
  let data = content_concat_for_test([
    content_bytes_for_test("BI /W 6 /H 1 /CS /G /BPC 8 /F /Fl ID "),
    encoded,
    content_bytes_for_test("\nEI Q"),
  ])
  @test.assert_eq(try! @pdflite.pdf_parse_content_ops_from_bytes(data), [
    Op_InlineImage(
      PdfDictionary([
        (content_name_for_test("/W"), PdfInteger(6)),
        (content_name_for_test("/H"), PdfInteger(1)),
        (
          content_name_for_test("/CS"),
          PdfNameObject(content_name_for_test("/G")),
        ),
        (content_name_for_test("/BPC"), PdfInteger(8)),
      ]),
      None,
      content_bytes_for_test("A EI B"),
    ),
    Op_Q,
  ])

  let array_encoded = @pdflite.pdf_flate_encode(content_bytes_for_test("xyz"))
  let array_data = content_concat_for_test([
    content_bytes_for_test(
      "BI /W 3 /H 1 /CS /G /BPC 8 /Filter [ /FlateDecode ] ID ",
    ),
    array_encoded,
    content_bytes_for_test("\nEI"),
  ])
  @test.assert_eq(try! @pdflite.pdf_parse_content_ops_from_bytes(array_data), [
    Op_InlineImage(
      PdfDictionary([
        (content_name_for_test("/W"), PdfInteger(3)),
        (content_name_for_test("/H"), PdfInteger(1)),
        (
          content_name_for_test("/CS"),
          PdfNameObject(content_name_for_test("/G")),
        ),
        (content_name_for_test("/BPC"), PdfInteger(8)),
      ]),
      None,
      content_bytes_for_test("xyz"),
    ),
  ])
}

///|
test "pdf_parse_content_ops_from_bytes decodes LZW inline images through EOD" {
  let encoded = content_lzw_codes_for_test([65, 32, 69, 73, 32, 66, 257], 1)
  let data = content_concat_for_test([
    content_bytes_for_test("BI /W 6 /H 1 /CS /G /BPC 8 /F /LZW ID "),
    encoded,
    content_bytes_for_test("\nEI Q"),
  ])
  @test.assert_eq(try! @pdflite.pdf_parse_content_ops_from_bytes(data), [
    Op_InlineImage(
      PdfDictionary([
        (content_name_for_test("/W"), PdfInteger(6)),
        (content_name_for_test("/H"), PdfInteger(1)),
        (
          content_name_for_test("/CS"),
          PdfNameObject(content_name_for_test("/G")),
        ),
        (content_name_for_test("/BPC"), PdfInteger(8)),
      ]),
      None,
      content_bytes_for_test("A EI B"),
    ),
    Op_Q,
  ])

  let array_encoded = content_lzw_codes_for_test([256, 120, 121, 122, 257], 1)
  let array_data = content_concat_for_test([
    content_bytes_for_test(
      "BI /W 3 /H 1 /CS /G /BPC 8 /Filter [ /LZWDecode ] ID ",
    ),
    array_encoded,
    content_bytes_for_test("\nEI"),
  ])
  @test.assert_eq(try! @pdflite.pdf_parse_content_ops_from_bytes(array_data), [
    Op_InlineImage(
      PdfDictionary([
        (content_name_for_test("/W"), PdfInteger(3)),
        (content_name_for_test("/H"), PdfInteger(1)),
        (
          content_name_for_test("/CS"),
          PdfNameObject(content_name_for_test("/G")),
        ),
        (content_name_for_test("/BPC"), PdfInteger(8)),
      ]),
      None,
      content_bytes_for_test("xyz"),
    ),
  ])
}

///|
test "pdf_parse_content_ops_from_bytes preserves unsupported inline filters" {
  let data = content_bytes_for_test("BI /W 1 /H 1 /CS /G /BPC 8 /F 7 ID A EI")
  @test.assert_eq(try! @pdflite.pdf_parse_content_ops_from_bytes(data), [
    Op_InlineImage(
      PdfDictionary([
        (content_name_for_test("/W"), PdfInteger(1)),
        (content_name_for_test("/H"), PdfInteger(1)),
        (
          content_name_for_test("/CS"),
          PdfNameObject(content_name_for_test("/G")),
        ),
        (content_name_for_test("/BPC"), PdfInteger(8)),
        (content_name_for_test("/F"), PdfInteger(7)),
      ]),
      None,
      content_bytes_for_test("A"),
    ),
  ])
}

///|
test "pdf_parse_content_ops_from_bytes parses inline image comments" {
  let data = content_bytes_for_test(
    "BI % ignored\n/W 1 /H 1 /CS /RGB /BPC 8 /DP << /Predictor 1 >> ID abc\nEI",
  )
  @test.assert_eq(try! @pdflite.pdf_parse_content_ops_from_bytes(data), [
    inline_image_content_op_for_test(),
  ])
}

///|
test "pdf_parse_content_ops_from_bytes reads DCT inline images through EOI" {
  let jpeg_data = try! @pdflite.pdf_bytes_of_int_array([
    0xFF, 0xD8, 65, 32, 69, 73, 32, 66, 0xFF, 0xD9,
  ])
  let data = content_concat_for_test([
    content_bytes_for_test("BI /W 1 /H 1 /F /DCT ID "),
    jpeg_data,
    content_bytes_for_test("\nEI Q"),
  ])
  @test.assert_eq(try! @pdflite.pdf_parse_content_ops_from_bytes(data), [
    Op_InlineImage(
      PdfDictionary([
        (content_name_for_test("/W"), PdfInteger(1)),
        (content_name_for_test("/H"), PdfInteger(1)),
        (
          content_name_for_test("/F"),
          PdfNameObject(content_name_for_test("/DCT")),
        ),
      ]),
      None,
      jpeg_data,
    ),
    Op_Q,
  ])
}

///|
test "pdf_parse_content_ops_from_bytes reads DCTDecode inline image arrays" {
  let jpeg_data = try! @pdflite.pdf_bytes_of_int_array([0xFF, 0xD8, 0xFF, 0xD9])
  let data = content_concat_for_test([
    content_bytes_for_test("BI /W 1 /H 1 /Filter [ /DCTDecode ] ID "),
    jpeg_data,
    content_bytes_for_test(" EI"),
  ])
  @test.assert_eq(try! @pdflite.pdf_parse_content_ops_from_bytes(data), [
    Op_InlineImage(
      PdfDictionary([
        (content_name_for_test("/W"), PdfInteger(1)),
        (content_name_for_test("/H"), PdfInteger(1)),
        (
          content_name_for_test("/Filter"),
          PdfArray([PdfNameObject(content_name_for_test("/DCTDecode"))]),
        ),
      ]),
      None,
      jpeg_data,
    ),
  ])
}

///|
test "pdf_parse_content_ops_from_bytes reads DCT inline image arrays" {
  let jpeg_data = try! @pdflite.pdf_bytes_of_int_array([0xFF, 0xD8, 0xFF, 0xD9])
  let data = content_concat_for_test([
    content_bytes_for_test("BI /W 1 /H 1 /Filter [ /DCT ] ID "),
    jpeg_data,
    content_bytes_for_test(" EI"),
  ])
  @test.assert_eq(try! @pdflite.pdf_parse_content_ops_from_bytes(data), [
    Op_InlineImage(
      PdfDictionary([
        (content_name_for_test("/W"), PdfInteger(1)),
        (content_name_for_test("/H"), PdfInteger(1)),
        (
          content_name_for_test("/Filter"),
          PdfArray([PdfNameObject(content_name_for_test("/DCT"))]),
        ),
      ]),
      None,
      jpeg_data,
    ),
  ])
}

///|
test "pdf_parse_content_ops_from_bytes reads DCT first inline image arrays" {
  let jpeg_data = try! @pdflite.pdf_bytes_of_int_array([
    0xFF, 0xD8, 65, 32, 69, 73, 32, 66, 0xFF, 0xD9,
  ])
  let data = content_concat_for_test([
    content_bytes_for_test("BI /W 1 /H 1 /Filter [ /DCT /A85 ] ID "),
    jpeg_data,
    content_bytes_for_test("\nEI Q"),
  ])
  @test.assert_eq(try! @pdflite.pdf_parse_content_ops_from_bytes(data), [
    Op_InlineImage(
      PdfDictionary([
        (content_name_for_test("/W"), PdfInteger(1)),
        (content_name_for_test("/H"), PdfInteger(1)),
        (
          content_name_for_test("/Filter"),
          PdfArray([
            PdfNameObject(content_name_for_test("/DCT")),
            PdfNameObject(content_name_for_test("/A85")),
          ]),
        ),
      ]),
      None,
      jpeg_data,
    ),
    Op_Q,
  ])
}

///|
test "pdf_parse_content_ops_from_bytes reports unterminated inline images" {
  let result : Result[Array[@pdflite.PdfContentOp], Error] = try? @pdflite.pdf_parse_content_ops_from_bytes(
    content_bytes_for_test("BI /W 1 ID abc"),
  )
  guard result is Err(@pdflite.PdfError::ParseEndStreamExpected) else {
    fail("expected ParseEndStreamExpected")
  }
  let run_length_data = content_concat_for_test([
    content_bytes_for_test("BI /W 1 /H 1 /CS /G /BPC 8 /F /RL ID "),
    try! @pdflite.pdf_bytes_of_int_array([0, 65]),
    content_bytes_for_test(" EI"),
  ])
  let run_length_result : Result[Array[@pdflite.PdfContentOp], Error] = try? @pdflite.pdf_parse_content_ops_from_bytes(
    run_length_data,
  )
  guard run_length_result is Err(@pdflite.PdfError::ParseEndStreamExpected) else {
    fail("expected RunLength ParseEndStreamExpected")
  }
  let ascii85_result : Result[Array[@pdflite.PdfContentOp], Error] = try? @pdflite.pdf_parse_content_ops_from_bytes(
    content_bytes_for_test("BI /W 1 /H 1 /CS /G /BPC 8 /F /A85 ID !!!! EI"),
  )
  guard ascii85_result is Err(@pdflite.PdfError::ParseEndStreamExpected) else {
    fail("expected ASCII85 ParseEndStreamExpected")
  }
  let ascii_hex_result : Result[Array[@pdflite.PdfContentOp], Error] = try? @pdflite.pdf_parse_content_ops_from_bytes(
    content_bytes_for_test("BI /W 1 /H 1 /CS /G /BPC 8 /F /AHx ID 41 EI"),
  )
  guard ascii_hex_result is Err(@pdflite.PdfError::ParseEndStreamExpected) else {
    fail("expected ASCIIHex ParseEndStreamExpected")
  }
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
    @pdflite.pdf_content_begin_artifact(),
    Op_Tj(content_bytes_for_test("artifact")),
    @pdflite.pdf_content_end_artifact(),
  ]
  let data = content_bytes_for_test("/Artifact BMC (artifact) Tj EMC")
  @test.assert_eq(try! @pdflite.pdf_content_bytes_of_ops(ops), data)
  @test.assert_eq(try! @pdflite.pdf_parse_content_ops_from_bytes(data), ops)
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
  let encoded = @pdflite.pdf_ascii_hex_encode(content_bytes_for_test("q Q"))
  doc.add_object_given_number(
    9,
    @pdflite.pdf_stream(
      @pdflite.pdf_dictionary([
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
  let resources = @pdflite.pdf_dictionary([
    (
      content_name_for_test("/ColorSpace"),
      @pdflite.pdf_dictionary([
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
        @pdflite.pdf_dictionary([
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
  let resources = @pdflite.pdf_dictionary([
    (
      content_name_for_test("/ColorSpace"),
      @pdflite.pdf_dictionary([
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
        @pdflite.pdf_dictionary([
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
    try! doc.parse_content_ops_with_resources(@pdflite.pdf_dictionary([]), [
      content_stream_for_test("BI /W 2 /H 1 /BPC 8 /CS [/RGB] ID A EI B EI Q"),
    ]),
    [
      Op_InlineImage(
        @pdflite.pdf_dictionary([
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
  let result : Result[Array[@pdflite.PdfContentOp], Error] = try? doc.parse_content_ops_with_resources(
    @pdflite.pdf_dictionary([]),
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
}

///|
test "PdfDocument parse_content_ops reports non-stream content objects" {
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(10, PdfInteger(42))
  let result : Result[Array[@pdflite.PdfContentOp], Error] = try? doc.parse_content_ops([
      PdfIndirect(10),
    ],
  )
  guard result is Err(@pdflite.PdfError::ParseStreamExpected) else {
    fail("expected ParseStreamExpected")
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
test "pdf_parse_content_ops_from_bytes parses nested text array objects" {
  let data = content_bytes_for_test("[(A) [1] << /K 2 >>] TJ")
  @test.assert_eq(try! @pdflite.pdf_parse_content_ops_from_bytes(data), [
    Op_TJ(
      PdfArray([
        PdfString(content_bytes_for_test("A")),
        PdfArray([PdfInteger(1)]),
        PdfDictionary([(content_name_for_test("/K"), PdfInteger(2))]),
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
test "pdf_parse_content_ops_from_bytes preserves invalid known-operator operands" {
  let data = content_bytes_for_test("true w /Bad J 1 ri /Bad Tj 1 Do")
  @test.assert_eq(try! @pdflite.pdf_parse_content_ops_from_bytes(data), [
    Op_Unknown(content_bytes_for_test("true w")),
    Op_Unknown(content_bytes_for_test("/Bad J")),
    Op_Unknown(content_bytes_for_test("1 ri")),
    Op_Unknown(content_bytes_for_test("/Bad Tj")),
    Op_Unknown(content_bytes_for_test("1 Do")),
  ])
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

///|
test "pdf content parser reports malformed complex and inline-image operands" {
  let malformed_array : Result[Array[@pdflite.PdfContentOp], Error] = try? @pdflite.pdf_parse_content_ops_from_bytes(
    content_bytes_for_test("[(A) 1 TJ"),
  )
  guard malformed_array is Err(@pdflite.PdfError::ParseObjectExpected) else {
    fail("expected ParseObjectExpected")
  }
  let malformed_inline_image : Result[Array[@pdflite.PdfContentOp], Error] = try? @pdflite.pdf_parse_content_ops_from_bytes(
    content_bytes_for_test("BI /W ID abc EI"),
  )
  guard malformed_inline_image is Err(@pdflite.PdfError::ContentOperandExpected) else {
    fail("expected ContentOperandExpected")
  }
  let malformed_inline_dictionary : Result[@pdflite.PdfBytes, Error] = try? @pdflite.pdf_content_bytes_of_ops([
      Op_InlineImage(PdfInteger(1), None, content_bytes_for_test("abc")),
    ],
  )
  guard malformed_inline_dictionary
    is Err(@pdflite.PdfError::DictionaryExpected) else {
    fail("expected DictionaryExpected")
  }
}
