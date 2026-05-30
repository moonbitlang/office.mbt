///|
fn content_inline_bytes_for_test(text : String) -> @pdflite.PdfBytes {
  @ascii.encode(text)
}

///|
fn content_inline_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn content_inline_concat_for_test(
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
fn content_inline_compressed_render_for_test(
  prefix : @pdflite.PdfBytes,
  data : @pdflite.PdfBytes,
) -> @pdflite.PdfBytes {
  let encoded = @flate.pdf_flate_encode(data)
  content_inline_concat_for_test([
    prefix,
    content_inline_bytes_for_test(" /F /Fl /L "),
    content_inline_bytes_for_test(encoded.length().to_string()),
    content_inline_bytes_for_test(" ID "),
    encoded,
    content_inline_bytes_for_test(" EI"),
  ])
}

///|
fn content_inline_lzw_codes_for_test(
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
fn content_inline_image_op_for_test() -> @content.PdfContentOp {
  Op_InlineImage(
    PdfDictionary([
      (content_inline_name_for_test("/W"), PdfInteger(1)),
      (content_inline_name_for_test("/H"), PdfInteger(1)),
      (
        content_inline_name_for_test("/CS"),
        PdfNameObject(content_inline_name_for_test("/RGB")),
      ),
      (content_inline_name_for_test("/BPC"), PdfInteger(8)),
    ]),
    Some(
      PdfDictionary([
        (content_inline_name_for_test("/Predictor"), PdfInteger(1)),
      ]),
    ),
    content_inline_bytes_for_test("abc"),
  )
}

///|
test "pdf_content_bytes_of_ops renders simple inline images" {
  let rendered = try! @pdflite.pdf_content_bytes_of_ops([
    content_inline_image_op_for_test(),
  ])
  let expected = content_inline_compressed_render_for_test(
    content_inline_bytes_for_test("BI /W 1 /H 1 /CS /RGB /BPC 8"),
    content_inline_bytes_for_test("abc"),
  )
  @test.assert_eq(rendered, expected)
  @test.assert_eq(try! @pdflite.pdf_parse_content_ops_from_bytes(rendered), [
    Op_InlineImage(
      PdfDictionary([
        (content_inline_name_for_test("/W"), PdfInteger(1)),
        (content_inline_name_for_test("/H"), PdfInteger(1)),
        (
          content_inline_name_for_test("/CS"),
          PdfNameObject(content_inline_name_for_test("/RGB")),
        ),
        (content_inline_name_for_test("/BPC"), PdfInteger(8)),
      ]),
      None,
      content_inline_bytes_for_test("abc"),
    ),
  ])
}

///|
test "pdf_content_bytes_of_ops preserves filtered inline image data" {
  let jpeg_data = try! @pdflite.pdf_bytes_of_int_array([0xFF, 0xD8, 0xFF, 0xD9])
  let rendered = try! @pdflite.pdf_content_bytes_of_ops([
    Op_InlineImage(
      PdfDictionary([
        (content_inline_name_for_test("/W"), PdfInteger(1)),
        (content_inline_name_for_test("/H"), PdfInteger(1)),
        (
          content_inline_name_for_test("/F"),
          PdfNameObject(content_inline_name_for_test("/DCT")),
        ),
      ]),
      Some(
        PdfDictionary([
          (content_inline_name_for_test("/Predictor"), PdfInteger(1)),
        ]),
      ),
      jpeg_data,
    ),
  ])
  @test.assert_eq(
    rendered,
    content_inline_concat_for_test([
      content_inline_bytes_for_test(
        "BI /W 1 /H 1 /F /DCT /DP << /Predictor 1 >> ID ",
      ),
      jpeg_data,
      content_inline_bytes_for_test(" EI"),
    ]),
  )
}

///|
test "pdf_parse_content_ops_from_bytes parses simple inline images" {
  let data = content_inline_bytes_for_test(
    "q BI /W 1 /H 1 /CS /RGB /BPC 8 /DP << /Predictor 1 >> ID abc\nEI Q",
  )
  @test.assert_eq(try! @pdflite.pdf_parse_content_ops_from_bytes(data), [
    Op_q,
    content_inline_image_op_for_test(),
    Op_Q,
  ])
  @test.assert_eq(
    try! @pdflite.pdf_content_bytes_of_ops(
      try! @pdflite.pdf_parse_content_ops_from_bytes(data),
    ),
    content_inline_concat_for_test([
      content_inline_bytes_for_test("q "),
      content_inline_compressed_render_for_test(
        content_inline_bytes_for_test("BI /W 1 /H 1 /CS /RGB /BPC 8"),
        content_inline_bytes_for_test("abc"),
      ),
      content_inline_bytes_for_test(" Q"),
    ]),
  )
}

///|
test "pdf_parse_content_ops_from_bytes falls back for array inline image spaces" {
  let data = content_inline_bytes_for_test(
    "BI /W 1 /H 1 /CS [/RGB] /BPC 8 ID abc EI",
  )
  @test.assert_eq(try! @pdflite.pdf_parse_content_ops_from_bytes(data), [
    Op_InlineImage(
      @syntax.pdf_dictionary([
        (content_inline_name_for_test("/W"), PdfInteger(1)),
        (content_inline_name_for_test("/H"), PdfInteger(1)),
        (
          content_inline_name_for_test("/CS"),
          PdfArray([PdfNameObject(content_inline_name_for_test("/RGB"))]),
        ),
        (content_inline_name_for_test("/BPC"), PdfInteger(8)),
      ]),
      None,
      content_inline_bytes_for_test("abc"),
    ),
  ])
  let length_data = content_inline_bytes_for_test(
    "BI /CS [/RGB] /L 6 ID A EI B\nEI Q",
  )
  @test.assert_eq(try! @pdflite.pdf_parse_content_ops_from_bytes(length_data), [
    Op_InlineImage(
      @syntax.pdf_dictionary([
        (
          content_inline_name_for_test("/CS"),
          PdfArray([PdfNameObject(content_inline_name_for_test("/RGB"))]),
        ),
        (content_inline_name_for_test("/L"), PdfInteger(6)),
      ]),
      None,
      content_inline_bytes_for_test("A EI B"),
    ),
    Op_Q,
  ])
}

///|
test "pdf_parse_content_ops_from_bytes preserves raw inline image EI bytes" {
  let data = content_inline_bytes_for_test(
    "BI /W 6 /H 1 /CS /G /BPC 8 ID A EI B\nEI Q",
  )
  @test.assert_eq(try! @pdflite.pdf_parse_content_ops_from_bytes(data), [
    Op_InlineImage(
      PdfDictionary([
        (content_inline_name_for_test("/W"), PdfInteger(6)),
        (content_inline_name_for_test("/H"), PdfInteger(1)),
        (
          content_inline_name_for_test("/CS"),
          PdfNameObject(content_inline_name_for_test("/G")),
        ),
        (content_inline_name_for_test("/BPC"), PdfInteger(8)),
      ]),
      None,
      content_inline_bytes_for_test("A EI B"),
    ),
    Op_Q,
  ])
}

///|
test "pdf_parse_content_ops_from_bytes preserves image mask EI bytes" {
  let data = content_inline_bytes_for_test("BI /W 16 /H 1 /IM true ID EI\nEI")
  @test.assert_eq(try! @pdflite.pdf_parse_content_ops_from_bytes(data), [
    Op_InlineImage(
      PdfDictionary([
        (content_inline_name_for_test("/W"), PdfInteger(16)),
        (content_inline_name_for_test("/H"), PdfInteger(1)),
        (content_inline_name_for_test("/IM"), PdfBoolean(true)),
      ]),
      None,
      content_inline_bytes_for_test("EI"),
    ),
  ])
}

///|
test "pdf_parse_content_ops_from_bytes decodes ASCIIHex inline images" {
  let data = content_inline_bytes_for_test(
    "BI /W 3 /H 1 /CS /G /BPC 8 /F /AHx /DP << /Predictor 1 >> ID 616263>\nEI",
  )
  let parsed = try! @pdflite.pdf_parse_content_ops_from_bytes(data)
  @test.assert_eq(parsed, [
    Op_InlineImage(
      PdfDictionary([
        (content_inline_name_for_test("/W"), PdfInteger(3)),
        (content_inline_name_for_test("/H"), PdfInteger(1)),
        (
          content_inline_name_for_test("/CS"),
          PdfNameObject(content_inline_name_for_test("/G")),
        ),
        (content_inline_name_for_test("/BPC"), PdfInteger(8)),
      ]),
      None,
      content_inline_bytes_for_test("abc"),
    ),
  ])
  @test.assert_eq(
    try! @pdflite.pdf_content_bytes_of_ops(parsed),
    content_inline_compressed_render_for_test(
      content_inline_bytes_for_test("BI /W 3 /H 1 /CS /G /BPC 8"),
      content_inline_bytes_for_test("abc"),
    ),
  )
}

///|
test "pdf_parse_content_ops_from_bytes decodes ASCII85 inline image arrays" {
  let encoded = @codec.pdf_ascii85_encode(content_inline_bytes_for_test("abc"))
  let data = content_inline_concat_for_test([
    content_inline_bytes_for_test(
      "BI /W 1 /H 1 /CS /RGB /BPC 8 /Filter [ /A85 ] ID ",
    ),
    encoded,
    content_inline_bytes_for_test("\nEI"),
  ])
  @test.assert_eq(try! @pdflite.pdf_parse_content_ops_from_bytes(data), [
    Op_InlineImage(
      PdfDictionary([
        (content_inline_name_for_test("/W"), PdfInteger(1)),
        (content_inline_name_for_test("/H"), PdfInteger(1)),
        (
          content_inline_name_for_test("/CS"),
          PdfNameObject(content_inline_name_for_test("/RGB")),
        ),
        (content_inline_name_for_test("/BPC"), PdfInteger(8)),
      ]),
      None,
      content_inline_bytes_for_test("abc"),
    ),
  ])
}

///|
test "pdf_parse_content_ops_from_bytes reads ASCII85 inline images through terminator" {
  let data = content_inline_concat_for_test([
    content_inline_bytes_for_test("BI /W 3 /H 1 /CS /G /BPC 8 /F /A85 ID "),
    content_inline_bytes_for_test("!%\nEI\n~>"),
    content_inline_bytes_for_test("\nEI Q"),
  ])
  @test.assert_eq(try! @pdflite.pdf_parse_content_ops_from_bytes(data), [
    Op_InlineImage(
      PdfDictionary([
        (content_inline_name_for_test("/W"), PdfInteger(3)),
        (content_inline_name_for_test("/H"), PdfInteger(1)),
        (
          content_inline_name_for_test("/CS"),
          PdfNameObject(content_inline_name_for_test("/G")),
        ),
        (content_inline_name_for_test("/BPC"), PdfInteger(8)),
      ]),
      None,
      try! @pdflite.pdf_bytes_of_int_array([0, 41, 129]),
    ),
    Op_Q,
  ])
}

///|
test "pdf_parse_content_ops_from_bytes decodes RunLength inline images" {
  let encoded = @codec.pdf_run_length_encode(
    content_inline_bytes_for_test("A EI B"),
  )
  let data = content_inline_concat_for_test([
    content_inline_bytes_for_test("BI /W 6 /H 1 /CS /G /BPC 8 /F /RL ID "),
    encoded,
    content_inline_bytes_for_test("\nEI Q"),
  ])
  @test.assert_eq(try! @pdflite.pdf_parse_content_ops_from_bytes(data), [
    Op_InlineImage(
      PdfDictionary([
        (content_inline_name_for_test("/W"), PdfInteger(6)),
        (content_inline_name_for_test("/H"), PdfInteger(1)),
        (
          content_inline_name_for_test("/CS"),
          PdfNameObject(content_inline_name_for_test("/G")),
        ),
        (content_inline_name_for_test("/BPC"), PdfInteger(8)),
      ]),
      None,
      content_inline_bytes_for_test("A EI B"),
    ),
    Op_Q,
  ])

  let array_encoded = @codec.pdf_run_length_encode(
    content_inline_bytes_for_test("ABCZZZZ"),
  )
  let array_data = content_inline_concat_for_test([
    content_inline_bytes_for_test(
      "BI /W 7 /H 1 /CS /G /BPC 8 /Filter [ /RunLengthDecode ] ID ",
    ),
    array_encoded,
    content_inline_bytes_for_test("\nEI"),
  ])
  @test.assert_eq(try! @pdflite.pdf_parse_content_ops_from_bytes(array_data), [
    Op_InlineImage(
      PdfDictionary([
        (content_inline_name_for_test("/W"), PdfInteger(7)),
        (content_inline_name_for_test("/H"), PdfInteger(1)),
        (
          content_inline_name_for_test("/CS"),
          PdfNameObject(content_inline_name_for_test("/G")),
        ),
        (content_inline_name_for_test("/BPC"), PdfInteger(8)),
      ]),
      None,
      content_inline_bytes_for_test("ABCZZZZ"),
    ),
  ])
}

///|
test "pdf_parse_content_ops_from_bytes decodes Flate inline images through zlib end" {
  let encoded = @flate.pdf_flate_encode(content_inline_bytes_for_test("A EI B"))
  let data = content_inline_concat_for_test([
    content_inline_bytes_for_test("BI /W 6 /H 1 /CS /G /BPC 8 /F /Fl ID "),
    encoded,
    content_inline_bytes_for_test("\nEI Q"),
  ])
  @test.assert_eq(try! @pdflite.pdf_parse_content_ops_from_bytes(data), [
    Op_InlineImage(
      PdfDictionary([
        (content_inline_name_for_test("/W"), PdfInteger(6)),
        (content_inline_name_for_test("/H"), PdfInteger(1)),
        (
          content_inline_name_for_test("/CS"),
          PdfNameObject(content_inline_name_for_test("/G")),
        ),
        (content_inline_name_for_test("/BPC"), PdfInteger(8)),
      ]),
      None,
      content_inline_bytes_for_test("A EI B"),
    ),
    Op_Q,
  ])

  let array_encoded = @flate.pdf_flate_encode(
    content_inline_bytes_for_test("xyz"),
  )
  let array_data = content_inline_concat_for_test([
    content_inline_bytes_for_test(
      "BI /W 3 /H 1 /CS /G /BPC 8 /Filter [ /FlateDecode ] ID ",
    ),
    array_encoded,
    content_inline_bytes_for_test("\nEI"),
  ])
  @test.assert_eq(try! @pdflite.pdf_parse_content_ops_from_bytes(array_data), [
    Op_InlineImage(
      PdfDictionary([
        (content_inline_name_for_test("/W"), PdfInteger(3)),
        (content_inline_name_for_test("/H"), PdfInteger(1)),
        (
          content_inline_name_for_test("/CS"),
          PdfNameObject(content_inline_name_for_test("/G")),
        ),
        (content_inline_name_for_test("/BPC"), PdfInteger(8)),
      ]),
      None,
      content_inline_bytes_for_test("xyz"),
    ),
  ])
}

///|
test "pdf_parse_content_ops_from_bytes decodes multi-filter inline images" {
  let ascii85_flate_encoded = @codec.pdf_ascii85_encode(
    @flate.pdf_flate_encode(content_inline_bytes_for_test("abc")),
  )
  let ascii85_flate_data = content_inline_concat_for_test([
    content_inline_bytes_for_test(
      "BI /W 3 /H 1 /CS /G /BPC 8 /Filter [ /A85 /Fl ] ID ",
    ),
    ascii85_flate_encoded,
    content_inline_bytes_for_test("\nEI"),
  ])
  @test.assert_eq(
    try! @pdflite.pdf_parse_content_ops_from_bytes(ascii85_flate_data),
    [
      Op_InlineImage(
        PdfDictionary([
          (content_inline_name_for_test("/W"), PdfInteger(3)),
          (content_inline_name_for_test("/H"), PdfInteger(1)),
          (
            content_inline_name_for_test("/CS"),
            PdfNameObject(content_inline_name_for_test("/G")),
          ),
          (content_inline_name_for_test("/BPC"), PdfInteger(8)),
        ]),
        None,
        content_inline_bytes_for_test("abc"),
      ),
    ],
  )

  let run_length_hex_encoded = @codec.pdf_run_length_encode(
    @codec.pdf_ascii_hex_encode(content_inline_bytes_for_test("xyz")),
  )
  let run_length_hex_data = content_inline_concat_for_test([
    content_inline_bytes_for_test(
      "BI /W 3 /H 1 /CS /G /BPC 8 /Filter [ /RL /AHx ] ID ",
    ),
    run_length_hex_encoded,
    content_inline_bytes_for_test("\nEI"),
  ])
  @test.assert_eq(
    try! @pdflite.pdf_parse_content_ops_from_bytes(run_length_hex_data),
    [
      Op_InlineImage(
        PdfDictionary([
          (content_inline_name_for_test("/W"), PdfInteger(3)),
          (content_inline_name_for_test("/H"), PdfInteger(1)),
          (
            content_inline_name_for_test("/CS"),
            PdfNameObject(content_inline_name_for_test("/G")),
          ),
          (content_inline_name_for_test("/BPC"), PdfInteger(8)),
        ]),
        None,
        content_inline_bytes_for_test("xyz"),
      ),
    ],
  )
}

///|
test "pdf_parse_content_ops_from_bytes decodes LZW inline images through EOD" {
  let encoded = content_inline_lzw_codes_for_test(
    [65, 32, 69, 73, 32, 66, 257],
    1,
  )
  let data = content_inline_concat_for_test([
    content_inline_bytes_for_test("BI /W 6 /H 1 /CS /G /BPC 8 /F /LZW ID "),
    encoded,
    content_inline_bytes_for_test("\nEI Q"),
  ])
  @test.assert_eq(try! @pdflite.pdf_parse_content_ops_from_bytes(data), [
    Op_InlineImage(
      PdfDictionary([
        (content_inline_name_for_test("/W"), PdfInteger(6)),
        (content_inline_name_for_test("/H"), PdfInteger(1)),
        (
          content_inline_name_for_test("/CS"),
          PdfNameObject(content_inline_name_for_test("/G")),
        ),
        (content_inline_name_for_test("/BPC"), PdfInteger(8)),
      ]),
      None,
      content_inline_bytes_for_test("A EI B"),
    ),
    Op_Q,
  ])

  let array_encoded = content_inline_lzw_codes_for_test(
    [256, 120, 121, 122, 257],
    1,
  )
  let array_data = content_inline_concat_for_test([
    content_inline_bytes_for_test(
      "BI /W 3 /H 1 /CS /G /BPC 8 /Filter [ /LZWDecode ] ID ",
    ),
    array_encoded,
    content_inline_bytes_for_test("\nEI"),
  ])
  @test.assert_eq(try! @pdflite.pdf_parse_content_ops_from_bytes(array_data), [
    Op_InlineImage(
      PdfDictionary([
        (content_inline_name_for_test("/W"), PdfInteger(3)),
        (content_inline_name_for_test("/H"), PdfInteger(1)),
        (
          content_inline_name_for_test("/CS"),
          PdfNameObject(content_inline_name_for_test("/G")),
        ),
        (content_inline_name_for_test("/BPC"), PdfInteger(8)),
      ]),
      None,
      content_inline_bytes_for_test("xyz"),
    ),
  ])
}

///|
test "pdf_parse_content_ops_from_bytes preserves unsupported inline filters" {
  let data = content_inline_bytes_for_test(
    "BI /W 1 /H 1 /CS /G /BPC 8 /F 7 ID A EI",
  )
  @test.assert_eq(try! @pdflite.pdf_parse_content_ops_from_bytes(data), [
    Op_InlineImage(
      PdfDictionary([
        (content_inline_name_for_test("/W"), PdfInteger(1)),
        (content_inline_name_for_test("/H"), PdfInteger(1)),
        (
          content_inline_name_for_test("/CS"),
          PdfNameObject(content_inline_name_for_test("/G")),
        ),
        (content_inline_name_for_test("/BPC"), PdfInteger(8)),
        (content_inline_name_for_test("/F"), PdfInteger(7)),
      ]),
      None,
      content_inline_bytes_for_test("A"),
    ),
  ])
  let length_data = content_inline_bytes_for_test(
    "BI /W 1 /H 1 /CS /G /BPC 8 /F /CCF /L 6 ID A EI B\nEI Q",
  )
  @test.assert_eq(try! @pdflite.pdf_parse_content_ops_from_bytes(length_data), [
    Op_InlineImage(
      PdfDictionary([
        (content_inline_name_for_test("/W"), PdfInteger(1)),
        (content_inline_name_for_test("/H"), PdfInteger(1)),
        (
          content_inline_name_for_test("/CS"),
          PdfNameObject(content_inline_name_for_test("/G")),
        ),
        (content_inline_name_for_test("/BPC"), PdfInteger(8)),
        (
          content_inline_name_for_test("/F"),
          PdfNameObject(content_inline_name_for_test("/CCF")),
        ),
        (content_inline_name_for_test("/L"), PdfInteger(6)),
      ]),
      None,
      content_inline_bytes_for_test("A EI B"),
    ),
    Op_Q,
  ])
  let full_length_data = content_inline_bytes_for_test(
    "BI /W 1 /H 1 /CS /G /BPC 8 /F /CCF /Length 6 ID C EI D\nEI",
  )
  @test.assert_eq(
    try! @pdflite.pdf_parse_content_ops_from_bytes(full_length_data),
    [
      Op_InlineImage(
        PdfDictionary([
          (content_inline_name_for_test("/W"), PdfInteger(1)),
          (content_inline_name_for_test("/H"), PdfInteger(1)),
          (
            content_inline_name_for_test("/CS"),
            PdfNameObject(content_inline_name_for_test("/G")),
          ),
          (content_inline_name_for_test("/BPC"), PdfInteger(8)),
          (
            content_inline_name_for_test("/F"),
            PdfNameObject(content_inline_name_for_test("/CCF")),
          ),
          (content_inline_name_for_test("/Length"), PdfInteger(6)),
        ]),
        None,
        content_inline_bytes_for_test("C EI D"),
      ),
    ],
  )
}

///|
test "pdf_parse_content_ops_from_bytes parses inline image comments" {
  let data = content_inline_bytes_for_test(
    "BI % ignored\n/W 1 /H 1 /CS /RGB /BPC 8 /DP << /Predictor 1 >> ID abc\nEI",
  )
  @test.assert_eq(try! @pdflite.pdf_parse_content_ops_from_bytes(data), [
    content_inline_image_op_for_test(),
  ])
}

///|
test "pdf_parse_content_ops_from_bytes reads DCT inline images through EOI" {
  let jpeg_data = try! @pdflite.pdf_bytes_of_int_array([
    0xFF, 0xD8, 65, 32, 69, 73, 32, 66, 0xFF, 0xD9,
  ])
  let data = content_inline_concat_for_test([
    content_inline_bytes_for_test("BI /W 1 /H 1 /F /DCT ID "),
    jpeg_data,
    content_inline_bytes_for_test("\nEI Q"),
  ])
  @test.assert_eq(try! @pdflite.pdf_parse_content_ops_from_bytes(data), [
    Op_InlineImage(
      PdfDictionary([
        (content_inline_name_for_test("/W"), PdfInteger(1)),
        (content_inline_name_for_test("/H"), PdfInteger(1)),
        (
          content_inline_name_for_test("/F"),
          PdfNameObject(content_inline_name_for_test("/DCT")),
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
  let data = content_inline_concat_for_test([
    content_inline_bytes_for_test("BI /W 1 /H 1 /Filter [ /DCTDecode ] ID "),
    jpeg_data,
    content_inline_bytes_for_test(" EI"),
  ])
  @test.assert_eq(try! @pdflite.pdf_parse_content_ops_from_bytes(data), [
    Op_InlineImage(
      PdfDictionary([
        (content_inline_name_for_test("/W"), PdfInteger(1)),
        (content_inline_name_for_test("/H"), PdfInteger(1)),
        (
          content_inline_name_for_test("/Filter"),
          PdfArray([PdfNameObject(content_inline_name_for_test("/DCTDecode"))]),
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
  let data = content_inline_concat_for_test([
    content_inline_bytes_for_test("BI /W 1 /H 1 /Filter [ /DCT ] ID "),
    jpeg_data,
    content_inline_bytes_for_test(" EI"),
  ])
  @test.assert_eq(try! @pdflite.pdf_parse_content_ops_from_bytes(data), [
    Op_InlineImage(
      PdfDictionary([
        (content_inline_name_for_test("/W"), PdfInteger(1)),
        (content_inline_name_for_test("/H"), PdfInteger(1)),
        (
          content_inline_name_for_test("/Filter"),
          PdfArray([PdfNameObject(content_inline_name_for_test("/DCT"))]),
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
  let data = content_inline_concat_for_test([
    content_inline_bytes_for_test("BI /W 1 /H 1 /Filter [ /DCT /A85 ] ID "),
    jpeg_data,
    content_inline_bytes_for_test("\nEI Q"),
  ])
  @test.assert_eq(try! @pdflite.pdf_parse_content_ops_from_bytes(data), [
    Op_InlineImage(
      PdfDictionary([
        (content_inline_name_for_test("/W"), PdfInteger(1)),
        (content_inline_name_for_test("/H"), PdfInteger(1)),
        (
          content_inline_name_for_test("/Filter"),
          PdfArray([
            PdfNameObject(content_inline_name_for_test("/DCT")),
            PdfNameObject(content_inline_name_for_test("/A85")),
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
test "pdf_parse_content_ops_from_bytes decodes leading inline filters before DCT" {
  let jpeg_data = try! @pdflite.pdf_bytes_of_int_array([
    0xFF, 0xD8, 65, 32, 69, 73, 32, 66, 0xFF, 0xD9,
  ])
  let encoded = @codec.pdf_ascii85_encode(jpeg_data)
  let data = content_inline_concat_for_test([
    content_inline_bytes_for_test("BI /W 1 /H 1 /Filter [ /A85 /DCT ] ID "),
    encoded,
    content_inline_bytes_for_test("\nEI Q"),
  ])
  @test.assert_eq(try! @pdflite.pdf_parse_content_ops_from_bytes(data), [
    Op_InlineImage(
      PdfDictionary([
        (
          content_inline_name_for_test("/Filter"),
          PdfArray([PdfNameObject(content_inline_name_for_test("/DCT"))]),
        ),
        (content_inline_name_for_test("/H"), PdfInteger(1)),
        (content_inline_name_for_test("/W"), PdfInteger(1)),
      ]),
      None,
      jpeg_data,
    ),
    Op_Q,
  ])
}

///|
test "pdf_parse_content_ops_from_bytes decodes leading inline filters before CCITT" {
  let data = content_inline_concat_for_test([
    content_inline_bytes_for_test(
      "BI /W 4 /H 1 /CS /G /BPC 1 /Filter [ /AHx /CCITTFaxDecode ] /DecodeParms [ null << /Columns 4 /Rows 1 >> ] ID ",
    ),
    content_inline_bytes_for_test("B0>"),
    content_inline_bytes_for_test("\nEI Q"),
  ])
  @test.assert_eq(try! @pdflite.pdf_parse_content_ops_from_bytes(data), [
    Op_InlineImage(
      PdfDictionary([
        (content_inline_name_for_test("/W"), PdfInteger(4)),
        (content_inline_name_for_test("/H"), PdfInteger(1)),
        (
          content_inline_name_for_test("/CS"),
          PdfNameObject(content_inline_name_for_test("/G")),
        ),
        (content_inline_name_for_test("/BPC"), PdfInteger(1)),
      ]),
      None,
      try! @pdflite.pdf_bytes_of_int_array([0xF0]),
    ),
    Op_Q,
  ])
}

///|
test "pdf_parse_content_ops_from_bytes preserves unsupported deferred inline filters after leading decode" {
  let encoded = @codec.pdf_ascii_hex_encode(
    content_inline_bytes_for_test("abc"),
  )
  let data = content_inline_concat_for_test([
    content_inline_bytes_for_test(
      "BI /W 3 /H 1 /CS /G /BPC 1 /Filter [ /AHx /NoSuchFilter ] ID ",
    ),
    encoded,
    content_inline_bytes_for_test("\nEI Q"),
  ])
  @test.assert_eq(try! @pdflite.pdf_parse_content_ops_from_bytes(data), [
    Op_InlineImage(
      PdfDictionary([
        (
          content_inline_name_for_test("/Filter"),
          PdfArray([
            PdfNameObject(content_inline_name_for_test("/NoSuchFilter")),
          ]),
        ),
        (content_inline_name_for_test("/BPC"), PdfInteger(1)),
        (
          content_inline_name_for_test("/CS"),
          PdfNameObject(content_inline_name_for_test("/G")),
        ),
        (content_inline_name_for_test("/H"), PdfInteger(1)),
        (content_inline_name_for_test("/W"), PdfInteger(3)),
      ]),
      None,
      content_inline_bytes_for_test("abc"),
    ),
    Op_Q,
  ])
}

///|
test "pdf_parse_content_ops_from_bytes recovers junk before inline image end" {
  @test.assert_eq(
    try! @pdflite.pdf_parse_content_ops_from_bytes(
      content_inline_bytes_for_test(
        "BI /W 1 /H 1 /CS /G /BPC 8 ID A junk-before-marker EI Q",
      ),
    ),
    [
      Op_InlineImage(
        PdfDictionary([
          (content_inline_name_for_test("/W"), PdfInteger(1)),
          (content_inline_name_for_test("/H"), PdfInteger(1)),
          (
            content_inline_name_for_test("/CS"),
            PdfNameObject(content_inline_name_for_test("/G")),
          ),
          (content_inline_name_for_test("/BPC"), PdfInteger(8)),
        ]),
        None,
        content_inline_bytes_for_test("A"),
      ),
      Op_Q,
    ],
  )

  let jpeg_data = try! @pdflite.pdf_bytes_of_int_array([0xFF, 0xD8, 0xFF, 0xD9])
  let dct_data = content_inline_concat_for_test([
    content_inline_bytes_for_test("BI /W 1 /H 1 /F /DCT ID "),
    jpeg_data,
    content_inline_bytes_for_test(" junk-before-marker EI Q"),
  ])
  @test.assert_eq(try! @pdflite.pdf_parse_content_ops_from_bytes(dct_data), [
    Op_InlineImage(
      PdfDictionary([
        (content_inline_name_for_test("/W"), PdfInteger(1)),
        (content_inline_name_for_test("/H"), PdfInteger(1)),
        (
          content_inline_name_for_test("/F"),
          PdfNameObject(content_inline_name_for_test("/DCT")),
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
  let result : Result[Array[@content.PdfContentOp], Error] = try? @pdflite.pdf_parse_content_ops_from_bytes(
    content_inline_bytes_for_test("BI /W 1 ID abc"),
  )
  guard result is Err(@pdflite.PdfError::ParseEndStreamExpected) else {
    fail("expected @pdflite.PdfError::ParseEndStreamExpected")
  }
  let sized_result : Result[Array[@content.PdfContentOp], Error] = try? @pdflite.pdf_parse_content_ops_from_bytes(
    content_inline_bytes_for_test("BI /W 1 /H 1 /CS /G /BPC 8 ID A"),
  )
  guard sized_result is Err(@pdflite.PdfError::ParseEndStreamExpected) else {
    fail("expected sized @pdflite.PdfError::ParseEndStreamExpected")
  }
  let run_length_data = content_inline_concat_for_test([
    content_inline_bytes_for_test("BI /W 1 /H 1 /CS /G /BPC 8 /F /RL ID "),
    try! @pdflite.pdf_bytes_of_int_array([0, 65]),
    content_inline_bytes_for_test(" EI"),
  ])
  let run_length_result : Result[Array[@content.PdfContentOp], Error] = try? @pdflite.pdf_parse_content_ops_from_bytes(
    run_length_data,
  )
  guard run_length_result is Err(@pdflite.PdfError::ParseEndStreamExpected) else {
    fail("expected RunLength @pdflite.PdfError::ParseEndStreamExpected")
  }
  let ascii85_result : Result[Array[@content.PdfContentOp], Error] = try? @pdflite.pdf_parse_content_ops_from_bytes(
    content_inline_bytes_for_test(
      "BI /W 1 /H 1 /CS /G /BPC 8 /F /A85 ID !!!! EI",
    ),
  )
  guard ascii85_result is Err(@pdflite.PdfError::ParseEndStreamExpected) else {
    fail("expected ASCII85 @pdflite.PdfError::ParseEndStreamExpected")
  }
  let ascii_hex_result : Result[Array[@content.PdfContentOp], Error] = try? @pdflite.pdf_parse_content_ops_from_bytes(
    content_inline_bytes_for_test("BI /W 1 /H 1 /CS /G /BPC 8 /F /AHx ID 41 EI"),
  )
  guard ascii_hex_result is Err(@pdflite.PdfError::ParseEndStreamExpected) else {
    fail("expected ASCIIHex @pdflite.PdfError::ParseEndStreamExpected")
  }
}
