///|
fn ccitt_wb_bytes(values : ArrayView[Int]) -> PdfBytes {
  try! pdf_bytes_of_int_array(values)
}

///|
fn ccitt_wb_bits(bits : ArrayView[Int]) -> PdfBytes {
  let writer = bit_writer_new()
  for bit in bits {
    try! writer.put_bit(bit)
  }
  writer.to_bytes()
}

///|
fn ccitt_wb_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn assert_ccitt_decodeparms_expected(
  result : Result[PdfCCITTParams, Error],
) -> Unit raise {
  guard result is Err(PdfError::CCITTDecodeParmsExpected) else {
    fail("expected PdfError::CCITTDecodeParmsExpected")
  }
}

///|
test "CCITT private helpers handle EOL spans and reference lookups" {
  let eol = bitstream_of_bytes(ccitt_wb_bytes([0x00, 0x10]))
  @test.assert_eq(pdf_ccitt_read_run(eol, true), -1)

  let bad_span : Result[Int, Error] = try? pdf_ccitt_output_span(
    [1, 1],
    1,
    2,
    0,
  )
  guard bad_span is Err(PdfError::InvalidCCITTData) else {
    fail("expected invalid CCITT span")
  }

  @test.assert_eq(pdf_ccitt_find_value([1, 1], 3, 0), 2)
  @test.assert_eq(pdf_ccitt_find_b1([1, 1, 0, 0], 1, false, 1, 0), 4)
  @test.assert_eq(pdf_ccitt_find_b2([1, 1, 0, 0], 1, false, 1, 0), 4)
}

///|
test "CCITT Group 3 covers alignment EOL padding EOF and invalid params" {
  let aligned = pdf_ccitt_decode_view(ccitt_wb_bytes([0xB0, 0xB0]), {
    ..pdf_ccitt_default_params(),
    columns: 4,
    rows: 2,
    encoded_byte_align: true,
  })
  @test.assert_eq(aligned, ccitt_wb_bytes([0xF0, 0xF0]))

  let padded = pdf_ccitt_decode_view(ccitt_wb_bytes([0x70, 0x01]), {
    ..pdf_ccitt_default_params(),
    columns: 4,
    rows: 1,
  })
  @test.assert_eq(padded, ccitt_wb_bytes([0xF0]))

  let eof = pdf_ccitt_decode_view(ccitt_wb_bytes([]), {
    ..pdf_ccitt_default_params(),
    columns: 4,
  })
  @test.assert_eq(eof, ccitt_wb_bytes([]))

  let invalid : Result[PdfBytes, Error] = try? pdf_ccitt_decode_view(
    ccitt_wb_bytes([]),
    { ..pdf_ccitt_default_params(), columns: 0 },
  )
  guard invalid is Err(PdfError::InvalidCCITTData) else {
    fail("expected invalid CCITT params")
  }

  let bad_run : Result[PdfBytes, Error] = try? pdf_ccitt_decode_view(
    ccitt_wb_bits([1, 1, 0, 0]),
    { ..pdf_ccitt_default_params(), columns: 4, rows: 1 },
  )
  guard bad_run is Err(PdfError::InvalidCCITTData) else {
    fail("expected invalid CCITT run")
  }

  let bad_output = try? pdf_ccitt_decode_g3_1d(
    bitstream_of_bytes(ccitt_wb_bits([1, 0, 1, 1])),
    bit_writer_new(),
    { ..pdf_ccitt_default_params(), columns: 4, rows: 1 },
    2,
    0,
  )
  guard bad_output is Err(InvalidCCITTData) else {
    fail("expected normalized invalid CCITT output")
  }
}

///|
test "CCITT Group 3 encoder covers white black long runs and malformed input" {
  let encoded = pdf_ccitt_encode_g3_1d_view(ccitt_wb_bytes([0xF0, 0x00]), 8, 2)
  @test.assert_eq(encoded, ccitt_wb_bytes([0xB6, 0x6A, 0x28, 0x00, 0x80, 0x08]))
  @test.assert_eq(
    pdf_ccitt_decode_view(encoded, {
      ..pdf_ccitt_default_params(),
      columns: 8,
      rows: 2,
    }),
    ccitt_wb_bytes([0xF0, 0x00]),
  )

  let long = pdf_ccitt_encode_g3_1d_view(
    ccitt_wb_bytes([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]),
    80,
    1,
  )
  @test.assert_eq(
    pdf_ccitt_decode_view(long, {
      ..pdf_ccitt_default_params(),
      columns: 80,
      rows: 1,
    }),
    ccitt_wb_bytes([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]),
  )

  let empty = pdf_ccitt_encode_g3_1d_view(ccitt_wb_bytes([]), 8, 0)
  @test.assert_eq(empty, ccitt_wb_bytes([0x00, 0x10, 0x01]))

  let short : Result[PdfBytes, Error] = try? pdf_ccitt_encode_g3_1d_view(
    ccitt_wb_bytes([]),
    8,
    1,
  )
  guard short is Err(_) else { fail("expected not enough CCITT source data") }

  let invalid : Result[PdfBytes, Error] = try? pdf_ccitt_encode_g3_1d_view(
    ccitt_wb_bytes([]),
    0,
    1,
  )
  guard invalid is Err(_) else { fail("expected invalid CCITT encode params") }

  let bad_write : Result[Unit, Error] = try? pdf_ccitt_write_run(
    bit_writer_new(),
    true,
    -1,
  )
  guard bad_write is Err(_) else {
    fail("expected invalid private CCITT run length")
  }

  let bad_read : Result[(Bool, Int), Error] = try? pdf_ccitt_encode_read_run(
    bitstream_of_bytes(ccitt_wb_bytes([0xFF])),
    0,
  )
  guard bad_read is Err(_) else {
    fail("expected invalid private CCITT read columns")
  }
}

///|
test "CCITT Group 4 covers pass vertical horizontal black EOFB and unsupported modes" {
  let pass = pdf_ccitt_decode_view(ccitt_wb_bits([0, 0, 0, 1]), {
    ..pdf_ccitt_default_params(),
    k: -1,
    columns: 4,
    rows: 1,
  })
  @test.assert_eq(pass, ccitt_wb_bytes([0xF0]))

  let vertical = pdf_ccitt_decode_view(ccitt_wb_bits([1]), {
    ..pdf_ccitt_default_params(),
    k: -1,
    columns: 4,
    rows: 1,
  })
  @test.assert_eq(vertical, ccitt_wb_bytes([0xF0]))

  let aligned = pdf_ccitt_decode_view(ccitt_wb_bytes([0x10, 0x10]), {
    ..pdf_ccitt_default_params(),
    k: -1,
    columns: 4,
    rows: 2,
    encoded_byte_align: true,
  })
  @test.assert_eq(aligned, ccitt_wb_bytes([0xF0, 0xF0]))

  let mixed = pdf_ccitt_decode_view(
    ccitt_wb_bits([
      // row 1: horizontal, white 2, black 2
      0, 0, 1, 0, 1, 1, 1, 1, 1,
      // row 2: vertical left one, then horizontal while current color is black
       0, 1, 0, 0, 0, 1, 0, 1, 0, 0, 1, 1, 1,
    ]),
    { ..pdf_ccitt_default_params(), k: -1, columns: 4, rows: 2 },
  )
  @test.assert_eq(mixed, ccitt_wb_bytes([0xC0, 0xB0]))

  let pass_black = pdf_ccitt_decode_view(
    ccitt_wb_bits([
      // row 1: horizontal, white 2, black 2
      0, 0, 1, 0, 1, 1, 1, 1, 1,
      // row 2: vertical left one, then pass while current color is black
       0, 1, 0, 0, 0, 0, 1,
    ]),
    { ..pdf_ccitt_default_params(), k: -1, columns: 4, rows: 2 },
  )
  @test.assert_eq(pass_black, ccitt_wb_bytes([0xC0, 0x80]))

  let vertical_black = pdf_ccitt_decode_view(
    ccitt_wb_bits([
      // row 1: horizontal, white 2, black 2
      0, 0, 1, 0, 1, 1, 1, 1, 1,
      // row 2: vertical left one, vertical left one while black, vertical zero
       0, 1, 0, 0, 1, 0, 1,
    ]),
    { ..pdf_ccitt_default_params(), k: -1, columns: 4, rows: 2 },
  )
  @test.assert_eq(vertical_black, ccitt_wb_bytes([0xC0, 0x90]))

  let eofb = pdf_ccitt_decode_view(ccitt_wb_bytes([0x00, 0x10, 0x01]), {
    ..pdf_ccitt_default_params(),
    k: -1,
    columns: 4,
  })
  @test.assert_eq(eofb, ccitt_wb_bytes([]))

  let eof = pdf_ccitt_decode_view(ccitt_wb_bytes([]), {
    ..pdf_ccitt_default_params(),
    k: -1,
    columns: 4,
  })
  @test.assert_eq(eof, ccitt_wb_bytes([]))

  let unsupported : Result[PdfBytes, Error] = try? pdf_ccitt_decode_view(
    ccitt_wb_bytes([0x00, 0xF0]),
    { ..pdf_ccitt_default_params(), k: -1, columns: 4 },
  )
  guard unsupported is Err(PdfError::CCITTNotSupported(_)) else {
    fail("expected unsupported CCITT uncompressed mode")
  }

  let invalid : Result[PdfBytes, Error] = try? pdf_ccitt_decode_view(
    ccitt_wb_bits([0, 1, 1]),
    { ..pdf_ccitt_default_params(), k: -1, columns: 4, rows: 1 },
  )
  guard invalid is Err(PdfError::InvalidCCITTData) else {
    fail("expected invalid CCITT Group 4 span")
  }

  let bad_output = try? pdf_ccitt_decode_g4(
    bitstream_of_bytes(ccitt_wb_bits([1])),
    bit_writer_new(),
    { ..pdf_ccitt_default_params(), k: -1, columns: 4, rows: 1 },
    2,
    0,
  )
  guard bad_output is Err(InvalidCCITTData) else {
    fail("expected normalized invalid CCITT Group 4 output")
  }
}

///|
test "CCITT Group 4 encoder roundtrips mixed rows and malformed input" {
  let raw = ccitt_wb_bytes([0xC0, 0xB0, 0x80])
  let encoded = pdf_ccitt_encode_g4_view(raw, 4, 3)
  @test.assert_eq(
    pdf_ccitt_decode_view(encoded, {
      ..pdf_ccitt_default_params(),
      k: -1,
      columns: 4,
      rows: 3,
    }),
    raw,
  )

  let horizontal = ccitt_wb_bytes([0x00])
  @test.assert_eq(
    pdf_ccitt_decode_view(pdf_ccitt_encode_g4_view(horizontal, 4, 1), {
      ..pdf_ccitt_default_params(),
      k: -1,
      columns: 4,
      rows: 1,
    }),
    horizontal,
  )

  let pass = ccitt_wb_bytes([0x9F, 0xF0])
  @test.assert_eq(
    pdf_ccitt_decode_view(pdf_ccitt_encode_g4_view(pass, 8, 2), {
      ..pdf_ccitt_default_params(),
      k: -1,
      columns: 8,
      rows: 2,
    }),
    pass,
  )

  let empty = pdf_ccitt_encode_g4_view(ccitt_wb_bytes([]), 4, 0)
  @test.assert_eq(
    pdf_ccitt_decode_view(empty, {
      ..pdf_ccitt_default_params(),
      k: -1,
      columns: 4,
      rows: 0,
    }),
    ccitt_wb_bytes([]),
  )

  let short : Result[PdfBytes, Error] = try? pdf_ccitt_encode_g4_view(
    ccitt_wb_bytes([]),
    4,
    1,
  )
  guard short is Err(_) else {
    fail("expected not enough CCITT Group 4 source data")
  }

  let invalid : Result[PdfBytes, Error] = try? pdf_ccitt_encode_g4_view(
    ccitt_wb_bytes([]),
    0,
    1,
  )
  guard invalid is Err(_) else {
    fail("expected invalid CCITT Group 4 encode params")
  }

  let modes = bit_writer_new()
  pdf_ccitt_write_mode(modes, CCITTPass)
  pdf_ccitt_write_mode(modes, CCITTVertical(-1))
  pdf_ccitt_write_mode(modes, CCITTVertical(-3))
  @test.assert_eq(modes.to_bytes(), ccitt_wb_bytes([0x16, 0x0C]))

  let right_three = bit_writer_new()
  pdf_ccitt_write_mode(right_three, CCITTVertical(3))
  @test.assert_eq(right_three.to_bytes(), ccitt_wb_bytes([0x04]))

  let unsupported_mode : Result[Unit, Error] = try? pdf_ccitt_write_mode(
    bit_writer_new(),
    CCITTUncompressed,
  )
  guard unsupported_mode is Err(_) else {
    fail("expected unsupported Group 4 uncompressed write mode")
  }

  let invalid_mode : Result[Unit, Error] = try? pdf_ccitt_write_mode(
    bit_writer_new(),
    CCITTVertical(4),
  )
  guard invalid_mode is Err(_) else {
    fail("expected invalid Group 4 vertical write mode")
  }

  let missing_row : Result[Array[Int], Error] = try? pdf_ccitt_line_from_data(
    ccitt_wb_bytes([]),
    4,
    0,
  )
  guard missing_row is Err(_) else {
    fail("expected missing CCITT Group 4 source row")
  }
}

///|
test "CCITT decode parameter parsing covers defaults arrays direct entries and malformed values" {
  @test.assert_eq(
    pdf_decode_filter_bytes(
      ccitt_wb_name("/CCITTFaxDecode"),
      ccitt_wb_bits([1, 0, 1, 1]),
    ),
    ccitt_wb_bytes([]),
  )

  let defaults = pdf_ccitt_params(@syntax.pdf_dictionary([]))
  @test.assert_eq(defaults.columns, 1728)
  @test.assert_eq(defaults.rows, 0)

  let array_params = pdf_ccitt_params(
    @syntax.pdf_dictionary([
      (
        ccitt_wb_name("/DecodeParms"),
        PdfArray([
          @syntax.pdf_dictionary([
            (ccitt_wb_name("/Columns"), PdfInteger(4)),
            (ccitt_wb_name("/Rows"), PdfInteger(1)),
            (ccitt_wb_name("/EndOfLine"), PdfBoolean(true)),
          ]),
        ]),
      ),
    ]),
  )
  @test.assert_eq(array_params.columns, 4)
  @test.assert_eq(array_params.rows, 1)
  @test.assert_eq(array_params.end_of_line, true)

  assert_ccitt_decodeparms_expected(
    try? pdf_ccitt_params(
      @syntax.pdf_dictionary([(ccitt_wb_name("/DecodeParms"), PdfInteger(1))]),
    ),
  )
  assert_ccitt_decodeparms_expected(
    try? pdf_ccitt_params(
      @syntax.pdf_dictionary([
        (
          ccitt_wb_name("/DecodeParms"),
          @syntax.pdf_dictionary([(ccitt_wb_name("/K"), PdfBoolean(true))]),
        ),
      ]),
    ),
  )
  assert_ccitt_decodeparms_expected(
    try? pdf_ccitt_params(
      @syntax.pdf_dictionary([
        (
          ccitt_wb_name("/DecodeParms"),
          @syntax.pdf_dictionary([(ccitt_wb_name("/EndOfLine"), PdfInteger(1))]),
        ),
      ]),
    ),
  )

  let doc = pdf_document_empty()
  doc.add_object_given_number(1, PdfNull)
  doc.add_object_given_number(2, PdfInteger(1))
  doc.add_object_given_number(
    3,
    @syntax.pdf_dictionary([
      (ccitt_wb_name("/Columns"), PdfInteger(5)),
      (ccitt_wb_name("/BlackIs1"), PdfBoolean(true)),
    ]),
  )
  let no_direct = doc.pdf_ccitt_params_direct(@syntax.pdf_dictionary([]))
  @test.assert_eq(no_direct.columns, 1728)
  let null_direct = doc.pdf_ccitt_params_direct(
    @syntax.pdf_dictionary([
      (ccitt_wb_name("/DecodeParms"), PdfArray([PdfIndirect(1)])),
    ]),
  )
  @test.assert_eq(null_direct.rows, 0)
  let indirect_direct = doc.pdf_ccitt_params_direct(
    @syntax.pdf_dictionary([(ccitt_wb_name("/DecodeParms"), PdfIndirect(3))]),
  )
  @test.assert_eq(indirect_direct.columns, 5)
  @test.assert_eq(indirect_direct.black_is_1, true)
  assert_ccitt_decodeparms_expected(
    try? doc.pdf_ccitt_params_direct(
      @syntax.pdf_dictionary([(ccitt_wb_name("/DecodeParms"), PdfInteger(1))]),
    ),
  )
  assert_ccitt_decodeparms_expected(
    try? doc.pdf_ccitt_params_direct(
      @syntax.pdf_dictionary([
        (ccitt_wb_name("/DecodeParms"), PdfArray([PdfIndirect(2)])),
      ]),
    ),
  )
  assert_ccitt_decodeparms_expected(
    try? doc.pdf_ccitt_params_direct(
      @syntax.pdf_dictionary([
        (
          ccitt_wb_name("/DecodeParms"),
          @syntax.pdf_dictionary([(ccitt_wb_name("/Columns"), PdfBoolean(true))]),
        ),
      ]),
    ),
  )
  assert_ccitt_decodeparms_expected(
    try? doc.pdf_ccitt_params_direct(
      @syntax.pdf_dictionary([
        (
          ccitt_wb_name("/DecodeParms"),
          @syntax.pdf_dictionary([(ccitt_wb_name("/BlackIs1"), PdfInteger(1))]),
        ),
      ]),
    ),
  )
}
