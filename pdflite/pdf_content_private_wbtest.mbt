// Whitebox tests run within the package scope.
// Use them to validate internal helpers or invariants.
// Keep them focused; public behavior belongs in `_test.mbt`.

///|
fn wbtest_content_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn content_wbtest_lzw_codes(
  codes : ArrayView[Int],
  early_change : Int,
) -> PdfBytes {
  let writer = bit_writer_new()
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
test "private content helpers cover malformed operand fallbacks" {
  @test.assert_eq(
    pdf_content_op_section(Op_InlineImage(PdfNull, None, [])),
    ([], Bytes::new(0)),
  )
  @test.assert_eq(
    pdf_content_op_section(Op_Unknown(@ascii.encode("ZZ"))),
    ([], @ascii.encode("ZZ")),
  )
  @test.assert_eq(
    pdf_content_read_complex_object(
      byte_cursor_of_bytes(Bytes::new(0)),
      LexInt(7),
    ),
    PdfInteger(7),
  )
  let empty_object : Result[@syntax.PdfObject, Error] = try? pdf_content_read_object(
    byte_cursor_of_bytes(Bytes::new(0)),
  )
  guard empty_object is Err(PdfError::ParseObjectExpected) else {
    fail("expected PdfError::ParseObjectExpected")
  }
  @test.assert_eq(
    try! pdf_content_read_inline_image_data(
      byte_cursor_of_bytes(@ascii.encode("EI ")),
    ),
    Bytes::new(0),
  )
  @test.assert_eq(
    pdf_content_inline_image_data_length(
      None,
      PdfDictionary([
        (wbtest_content_name("/W"), PdfInteger(1)),
        (wbtest_content_name("/H"), PdfInteger(1)),
        (
          wbtest_content_name("/CS"),
          PdfNameObject(wbtest_content_name("/CMYK")),
        ),
        (wbtest_content_name("/BPC"), PdfInteger(8)),
      ]),
    ),
    Some(4),
  )
  @test.assert_eq(
    pdf_content_inline_image_data_length(
      None,
      PdfDictionary([
        (wbtest_content_name("/W"), PdfInteger(1)),
        (wbtest_content_name("/H"), PdfInteger(1)),
        (wbtest_content_name("/CS"), PdfNameObject(wbtest_content_name("/G"))),
        (wbtest_content_name("/BPC"), PdfInteger(1)),
      ]),
    ),
    Some(1),
  )
  @test.assert_eq(
    pdf_content_inline_image_data_length(
      None,
      PdfDictionary([
        (wbtest_content_name("/W"), PdfInteger(1)),
        (wbtest_content_name("/H"), PdfInteger(1)),
        (wbtest_content_name("/CS"), PdfNameObject(wbtest_content_name("/G"))),
        (wbtest_content_name("/BPC"), PdfInteger(8)),
        (
          wbtest_content_name("/Filter"),
          PdfNameObject(wbtest_content_name("/ASCIIHexDecode")),
        ),
      ]),
    ),
    None,
  )
  @test.assert_eq(
    try! pdf_content_read_sized_inline_image_data(
      byte_cursor_of_bytes(@ascii.encode("AB EI")),
      2,
    ),
    @ascii.encode("AB"),
  )
  let short_sized_inline : Result[PdfBytes, Error] = try? pdf_content_read_sized_inline_image_data(
    byte_cursor_of_bytes(@ascii.encode("A")),
    2,
  )
  guard short_sized_inline is Err(PdfError::ParseEndStreamExpected) else {
    fail("expected PdfError::ParseEndStreamExpected")
  }
  let bad_sized_length : Result[PdfBytes, Error] = try? pdf_content_read_sized_inline_image_data(
    byte_cursor_of_bytes(@ascii.encode(" EI")),
    -1,
  )
  guard bad_sized_length is Err(PdfError::InvalidReadLength(-1)) else {
    fail("expected PdfError::InvalidReadLength")
  }
  let jpeg_data = try! pdf_bytes_of_int_array([0xFF, 0xD8, 0xFF, 0xD9])
  @test.assert_eq(
    try! pdf_content_read_dct_inline_image_data(
      byte_cursor_of_bytes(
        try! pdf_bytes_of_int_array([0xFF, 0xD8, 0xFF, 0xD9, 32, 69, 73]),
      ),
    ),
    jpeg_data,
  )
  @test.assert_eq(pdf_content_filter_is_inline_dct(PdfInteger(1)), false)
  @test.assert_eq(
    pdf_content_filter_is_inline_dct(
      PdfArray([
        PdfNameObject(wbtest_content_name("/DCTDecode")),
        PdfNameObject(wbtest_content_name("/ASCII85Decode")),
      ]),
    ),
    true,
  )
  guard pdf_content_filter_inline_text_filter(PdfInteger(1)) is None else {
    fail("expected no text filter for non-name")
  }
  guard pdf_content_filter_inline_text_filter(
      PdfNameObject(wbtest_content_name("/Unsupported")),
    )
    is None else {
    fail("expected no text filter for unsupported name")
  }
  guard pdf_content_filter_inline_text_filter(
      PdfArray([
        PdfNameObject(wbtest_content_name("/ASCII85Decode")),
        PdfNameObject(wbtest_content_name("/FlateDecode")),
      ]),
    )
    is Some(PdfContentInlineAscii85) else {
    fail("expected ASCII85 text filter")
  }
  guard pdf_content_inline_image_text_filter(PdfDictionary([])) is None else {
    fail("expected no inline image text filter")
  }
  guard pdf_content_inline_image_single_text_filter(PdfDictionary([])) is None else {
    fail("expected no single inline image text filter")
  }
  guard pdf_content_filter_single_inline_text_filter(
      PdfNameObject(wbtest_content_name("/AHx")),
    )
    is Some(PdfContentInlineAsciiHex) else {
    fail("expected single ASCIIHex text filter")
  }
  guard pdf_content_filter_single_inline_text_filter(
      PdfArray([PdfNameObject(wbtest_content_name("/ASCII85Decode"))]),
    )
    is Some(PdfContentInlineAscii85) else {
    fail("expected single ASCII85 text filter")
  }
  guard pdf_content_filter_single_inline_text_filter(
      PdfArray([
        PdfNameObject(wbtest_content_name("/ASCII85Decode")),
        PdfNameObject(wbtest_content_name("/FlateDecode")),
      ]),
    )
    is None else {
    fail("expected no single text filter for multi-stage array")
  }
  @test.assert_eq(
    try! pdf_content_read_text_encoded_inline_image_data(
      byte_cursor_of_bytes(@ascii.encode("616263> EI")),
      PdfContentInlineAsciiHex,
    ),
    @ascii.encode("616263>"),
  )
  let missing_text_encoded_end : Result[PdfBytes, Error] = try? pdf_content_read_text_encoded_inline_image_data(
    byte_cursor_of_bytes(@ascii.encode("616263 EI")),
    PdfContentInlineAsciiHex,
  )
  guard missing_text_encoded_end is Err(_) else {
    fail("expected missing text inline image end to raise")
  }
  let decoded_hex_cursor = byte_cursor_of_bytes(
    @ascii.encode("616263> EI next"),
  )
  @test.assert_eq(
    try! pdf_content_read_text_encoded_inline_image_decoded(
      decoded_hex_cursor,
      PdfContentInlineAsciiHex,
    ),
    @ascii.encode("abc"),
  )
  @test.assert_eq(decoded_hex_cursor.remaining_view(), @ascii.encode(" next"))
  let ascii85_inline = @codec.pdf_ascii85_encode(@ascii.encode("abc"))
  let decoded_ascii85_cursor = byte_cursor_of_bytes(
    pdf_bytes_concat_views([ascii85_inline, @ascii.encode(" EI next")]),
  )
  @test.assert_eq(
    try! pdf_content_read_text_encoded_inline_image_decoded(
      decoded_ascii85_cursor,
      PdfContentInlineAscii85,
    ),
    @ascii.encode("abc"),
  )
  @test.assert_eq(
    decoded_ascii85_cursor.remaining_view(),
    @ascii.encode(" next"),
  )
  @test.assert_eq(pdf_content_filter_is_inline_run_length(PdfInteger(1)), false)
  @test.assert_eq(
    pdf_content_inline_image_uses_single_run_length(PdfDictionary([])),
    false,
  )
  @test.assert_eq(
    pdf_content_filter_is_single_inline_run_length(
      PdfNameObject(wbtest_content_name("/RL")),
    ),
    true,
  )
  @test.assert_eq(
    pdf_content_filter_is_single_inline_run_length(
      PdfArray([PdfNameObject(wbtest_content_name("/RunLengthDecode"))]),
    ),
    true,
  )
  @test.assert_eq(
    pdf_content_filter_is_single_inline_run_length(
      PdfArray([
        PdfNameObject(wbtest_content_name("/RunLengthDecode")),
        PdfNameObject(wbtest_content_name("/ASCII85Decode")),
      ]),
    ),
    false,
  )
  @test.assert_eq(pdf_content_filter_is_inline_flate(PdfInteger(1)), false)
  @test.assert_eq(
    pdf_content_inline_image_uses_single_flate(PdfDictionary([])),
    false,
  )
  @test.assert_eq(
    pdf_content_filter_is_inline_flate(
      PdfArray([PdfNameObject(wbtest_content_name("/FlateDecode"))]),
    ),
    true,
  )
  @test.assert_eq(
    pdf_content_filter_is_single_inline_flate(
      PdfNameObject(wbtest_content_name("/Fl")),
    ),
    true,
  )
  @test.assert_eq(
    pdf_content_filter_is_single_inline_flate(
      PdfArray([PdfNameObject(wbtest_content_name("/FlateDecode"))]),
    ),
    true,
  )
  @test.assert_eq(
    pdf_content_filter_is_single_inline_flate(
      PdfArray([
        PdfNameObject(wbtest_content_name("/FlateDecode")),
        PdfNameObject(wbtest_content_name("/ASCII85Decode")),
      ]),
    ),
    false,
  )
  @test.assert_eq(pdf_content_filter_is_inline_lzw(PdfInteger(1)), false)
  @test.assert_eq(
    pdf_content_inline_image_uses_single_lzw(PdfDictionary([])),
    false,
  )
  @test.assert_eq(
    pdf_content_filter_is_inline_lzw(
      PdfArray([PdfNameObject(wbtest_content_name("/LZWDecode"))]),
    ),
    true,
  )
  @test.assert_eq(
    pdf_content_filter_is_single_inline_lzw(
      PdfNameObject(wbtest_content_name("/LZW")),
    ),
    true,
  )
  @test.assert_eq(
    pdf_content_filter_is_single_inline_lzw(
      PdfArray([PdfNameObject(wbtest_content_name("/LZWDecode"))]),
    ),
    true,
  )
  @test.assert_eq(
    pdf_content_filter_is_single_inline_lzw(
      PdfArray([
        PdfNameObject(wbtest_content_name("/LZWDecode")),
        PdfNameObject(wbtest_content_name("/ASCII85Decode")),
      ]),
    ),
    false,
  )
  let flate_inline = @flate.pdf_flate_encode(@ascii.encode("AB"))
  @test.assert_eq(
    try! pdf_content_read_flate_inline_image_data(
      byte_cursor_of_bytes(
        pdf_bytes_concat_views([flate_inline, @ascii.encode(" EI")]),
      ),
    ),
    flate_inline,
  )
  @test.assert_eq(
    pdf_content_read_flate_inline_image_data(
      byte_cursor_of_bytes(
        pdf_bytes_concat_views([
          @ascii.encode(" "),
          flate_inline,
          @ascii.encode(" EI"),
        ]),
      ),
    ),
    flate_inline,
  )
  let decoded_flate_cursor = byte_cursor_of_bytes(
    pdf_bytes_concat_views([flate_inline, @ascii.encode(" EI next")]),
  )
  @test.assert_eq(
    try! pdf_content_read_flate_inline_image_decoded(decoded_flate_cursor),
    @ascii.encode("AB"),
  )
  @test.assert_eq(decoded_flate_cursor.remaining_view(), @ascii.encode(" next"))
  let lzw_inline = content_wbtest_lzw_codes([256, 65, 257], 1)
  @test.assert_eq(
    try! pdf_content_read_lzw_inline_image_data(
      byte_cursor_of_bytes(
        pdf_bytes_concat_views([lzw_inline, @ascii.encode(" EI")]),
      ),
      PdfDictionary([]),
      None,
    ),
    lzw_inline,
  )
  @test.assert_eq(
    pdf_content_read_lzw_inline_image_data(
      byte_cursor_of_bytes(
        pdf_bytes_concat_views([
          @ascii.encode(" "),
          lzw_inline,
          @ascii.encode(" EI"),
        ]),
      ),
      PdfDictionary([]),
      None,
    ),
    lzw_inline,
  )
  let decoded_lzw_cursor = byte_cursor_of_bytes(
    pdf_bytes_concat_views([lzw_inline, @ascii.encode(" EI next")]),
  )
  @test.assert_eq(
    try! pdf_content_read_lzw_inline_image_decoded(decoded_lzw_cursor),
    @ascii.encode("A"),
  )
  @test.assert_eq(decoded_lzw_cursor.remaining_view(), @ascii.encode(" next"))
  @test.assert_eq(
    try! pdf_content_read_lzw_inline_image_data(
      byte_cursor_of_bytes(
        pdf_bytes_concat_views([lzw_inline, @ascii.encode(" EI")]),
      ),
      PdfDictionary([]),
      Some(
        PdfDictionary([(wbtest_content_name("/EarlyChange"), PdfInteger(1))]),
      ),
    ),
    lzw_inline,
  )
  @test.assert_eq(
    try! pdf_content_read_run_length_inline_image_data(
      byte_cursor_of_bytes(
        try! pdf_bytes_of_int_array([253, 90, 128, 32, 69, 73]),
      ),
    ),
    try! pdf_bytes_of_int_array([253, 90, 128]),
  )
  let run_length_encoded = try! pdf_bytes_of_int_array([253, 90, 128])
  let decoded_run_length_cursor = byte_cursor_of_bytes(
    pdf_bytes_concat_views([run_length_encoded, @ascii.encode(" EI next")]),
  )
  @test.assert_eq(
    try! pdf_content_read_run_length_inline_image_decoded(
      decoded_run_length_cursor,
    ),
    @ascii.encode("ZZZZ"),
  )
  @test.assert_eq(
    decoded_run_length_cursor.remaining_view(),
    @ascii.encode(" next"),
  )
  let missing_run_length_eod : Result[PdfBytes, Error] = try? pdf_content_read_run_length_inline_image_decoded(
    byte_cursor_of_bytes(try! pdf_bytes_of_int_array([253, 90])),
  )
  guard missing_run_length_eod is Err(PdfError::ParseEndStreamExpected) else {
    fail("expected PdfError::ParseEndStreamExpected")
  }
  let missing_encoded_run_length_eod : Result[PdfBytes, Error] = try? pdf_content_read_run_length_inline_image_data(
    byte_cursor_of_bytes(try! pdf_bytes_of_int_array([253, 90])),
  )
  guard missing_encoded_run_length_eod is Err(_) else {
    fail("expected missing encoded run length EOD to raise")
  }
  let short_run_length_prefix : Result[(PdfBytes, Int), Error] = try? pdf_content_run_length_decode_view_prefix(
    try! pdf_bytes_of_int_array([253]),
  )
  guard short_run_length_prefix is Err(_) else {
    fail("expected short run length prefix to raise")
  }
  let flate_with_decode_parms = byte_cursor_of_bytes(
    pdf_bytes_concat_views([
      @ascii.encode("/W 1 /H 2 /CS /G /BPC 8 /F /Fl /DP << /Predictor 1 >> ID "),
      flate_inline,
      @ascii.encode(" EI"),
    ]),
  )
  @test.assert_eq(
    pdf_content_read_inline_image(
      flate_with_decode_parms,
      pdf_content_parse_context(None),
    ),
    Op_InlineImage(
      PdfDictionary([
        (wbtest_content_name("/W"), PdfInteger(1)),
        (wbtest_content_name("/H"), PdfInteger(2)),
        (wbtest_content_name("/CS"), PdfNameObject(wbtest_content_name("/G"))),
        (wbtest_content_name("/BPC"), PdfInteger(8)),
      ]),
      None,
      @ascii.encode("AB"),
    ),
  )
  let lzw_with_decode_parms = byte_cursor_of_bytes(
    pdf_bytes_concat_views([
      @ascii.encode(
        "/W 1 /H 1 /CS /G /BPC 8 /F /LZW /DP << /EarlyChange 1 >> ID ",
      ),
      lzw_inline,
      @ascii.encode(" EI"),
    ]),
  )
  @test.assert_eq(
    pdf_content_read_inline_image(
      lzw_with_decode_parms,
      pdf_content_parse_context(None),
    ),
    Op_InlineImage(
      PdfDictionary([
        (wbtest_content_name("/W"), PdfInteger(1)),
        (wbtest_content_name("/H"), PdfInteger(1)),
        (wbtest_content_name("/CS"), PdfNameObject(wbtest_content_name("/G"))),
        (wbtest_content_name("/BPC"), PdfInteger(8)),
      ]),
      None,
      @ascii.encode("A"),
    ),
  )
  let bad_dct_end : Result[PdfBytes, Error] = try? pdf_content_read_dct_inline_image_data(
    byte_cursor_of_bytes(
      try! pdf_bytes_of_int_array([0xFF, 0xD8, 0xFF, 0xD9, 32, 88, 88]),
    ),
  )
  guard bad_dct_end is Err(PdfError::ParseEndStreamExpected) else {
    fail("expected PdfError::ParseEndStreamExpected")
  }
  let bad_inline : Result[@content.PdfContentOp, Error] = try? pdf_content_read_inline_image(
    byte_cursor_of_bytes(@ascii.encode("1 ID data EI")),
    pdf_content_parse_context(None),
  )
  guard bad_inline is Err(PdfError::ContentOperandExpected) else {
    fail("expected PdfError::ContentOperandExpected")
  }
}
