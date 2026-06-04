// Whitebox tests for text CMap, ToUnicode, and stream internals.
// Public text behavior belongs in `_test.mbt` files.

///|
fn cmap_wbtest_text_bytes(values : ArrayView[Int]) -> @core.PdfBytes {
  try! @core.pdf_bytes_of_int_array(values)
}

///|
fn cmap_wbtest_text_name(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
test "private text ToUnicode CMap helpers reject malformed ranges" {
  @test.assert_eq(pdf_text_parse_hex_bytes(@ascii.encode("0g"), 0, 2), None)
  @test.assert_eq(pdf_text_after_ascii(@ascii.encode("abc"), "missing"), None)
  @test.assert_eq(pdf_text_parse_cmap_hex_groups(@ascii.encode("<0g>")), None)
  @test.assert_eq(
    pdf_text_parse_cmap_hex_group_at(@ascii.encode("<0g>"), 0),
    None,
  )
  @test.assert_eq(
    pdf_text_tounicode_bfrange_inline_entries(@ascii.encode("<01><02>[<0041>]")),
    None,
  )
  @test.assert_eq(
    pdf_text_tounicode_bfrange_inline_entries(@ascii.encode("<01><01>[<0g>]")),
    None,
  )
  @test.assert_eq(
    pdf_text_tounicode_bfrange_inline_entries(@ascii.encode("<00><01><ff>")),
    None,
  )
  @test.assert_eq(
    pdf_text_tounicode_bfrange_inline_entries(@ascii.encode("<02><01><0041>")),
    None,
  )
  @test.assert_eq(
    pdf_text_tounicode_bfrange_inline_entries(@ascii.encode("<01>")),
    None,
  )
  @test.assert_eq(
    pdf_text_add_to_big_endian_bytes(cmap_wbtest_text_bytes([0xff]), 1),
    None,
  )
  @test.assert_eq(
    pdf_text_tounicode_bfrange_array_entries(1, 2, [cmap_wbtest_text_bytes([0])]),
    None,
  )
  let bfchar_entries : Array[(Int, @core.PdfBytes)] = []
  pdf_text_push_tounicode_bfchar_entry(
    bfchar_entries,
    Bytes::new(0),
    cmap_wbtest_text_bytes([0x00, 0x41]),
  )
  @test.assert_eq(bfchar_entries, [])

  let invalid_bfrange_entries : Array[(Int, @core.PdfBytes)] = []
  guard pdf_text_append_tounicode_bfrange_line(
      invalid_bfrange_entries,
      @ascii.encode("<02><01>["),
    )
    is None else {
    fail("expected invalid bfrange line")
  }
  guard pdf_text_append_tounicode_bfrange_line(
      invalid_bfrange_entries,
      @ascii.encode("<01>["),
    )
    is None else {
    fail("expected incomplete bfrange line")
  }
  guard pdf_text_append_tounicode_bfrange_line(
      invalid_bfrange_entries,
      @ascii.encode("<01><02><FF>"),
    )
    is None else {
    fail("expected overflow bfrange line")
  }
  guard pdf_text_append_tounicode_bfrange_line(
      invalid_bfrange_entries,
      @ascii.encode("<01><02>plain"),
    )
    is None else {
    fail("expected missing unicode bfrange line")
  }
  @test.assert_eq(invalid_bfrange_entries, [])
  let pending : PdfTextCMapBFRangeArray = { first: 1, last: 2, unicodes: [] }
  let pending_entries : Array[(Int, @core.PdfBytes)] = []
  let append_result = pdf_text_append_pending_bfrange_array(
    pending_entries,
    pending,
    @ascii.encode("<0041>]"),
  )
  guard append_result is PdfTextCMapBFRangeArrayClosed(rest) else {
    fail("expected closed bfrange array")
  }
  @test.assert_eq(rest.length(), 0)
  @test.assert_eq(pending_entries, [])
  @test.assert_eq(pdf_text_parse_tounicode(@ascii.encode("plain")), None)
  @test.assert_eq(
    pdf_text_parse_tounicode(
      @ascii.encode("1 beginbfrange <01><02>[<0041>] endbfrange\n"),
    ),
    None,
  )
}

///|
test "private external CMap helpers cover malformed and compact sections" {
  let empty_parsed : PdfParsedCMap = {
    map: [],
    cid_map: [],
    notdef_map: [],
    codespaces: [],
    usecmap: None,
    wmode: None,
    cmap_name: None,
    cmap_type: None,
    cid_system_info: None,
  }
  @test.assert_eq(PdfExternalCMap(1, empty_parsed).uses_two_byte_codes(), false)
  @test.assert_eq(
    pdf_text_parsed_cmap_charcodes_of_text(
      empty_parsed,
      cmap_wbtest_text_bytes([1, 2]),
    ),
    [1, 2],
  )
  let identity_base_parsed : PdfParsedCMap = {
    map: [],
    cid_map: [],
    notdef_map: [],
    codespaces: [],
    usecmap: Some(cmap_wbtest_text_name("/Identity-H")),
    wmode: None,
    cmap_name: None,
    cmap_type: None,
    cid_system_info: None,
  }
  @test.assert_eq(
    PdfExternalCMap(4, identity_base_parsed).uses_two_byte_codes(),
    true,
  )
  @test.assert_eq(
    PdfExternalCMap(4, {
      ..identity_base_parsed,
      usecmap: Some(cmap_wbtest_text_name("/Identity-V")),
    }).uses_two_byte_codes(),
    true,
  )
  let ucs2_base_parsed : PdfParsedCMap = {
    ..identity_base_parsed,
    usecmap: Some(cmap_wbtest_text_name("/Adobe-Japan1-UCS2-H")),
  }
  @test.assert_eq(
    PdfExternalCMap(4, ucs2_base_parsed).uses_two_byte_codes(),
    true,
  )
  @test.assert_eq(
    pdf_text_parsed_cmap_charcodes_of_text(
      ucs2_base_parsed,
      cmap_wbtest_text_bytes([0x12, 0x34]),
    ),
    [0x1234],
  )
  let truncated_ucs2 : Result[Array[Int], Error] = try
    pdf_text_parsed_cmap_charcodes_of_text(
      ucs2_base_parsed,
      cmap_wbtest_text_bytes([0x12]),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard truncated_ucs2 is Err(_) else {
    fail("expected truncated external UCS2 UseCMap text to raise")
  }
  @test.assert_eq(
    pdf_text_parsed_cmap_charcodes_of_text(
      identity_base_parsed,
      cmap_wbtest_text_bytes([1, 2]),
    ),
    [0x0102],
  )
  let odd_identity : Result[Array[Int], Error] = try
    pdf_text_parsed_cmap_charcodes_of_text(
      identity_base_parsed,
      cmap_wbtest_text_bytes([1]),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard odd_identity is Err(_) else {
    fail("expected odd identity CMap text to raise")
  }
  let mixed_identity_base_parsed : PdfParsedCMap = {
    map: [],
    cid_map: [],
    notdef_map: [],
    codespaces: [{ length: 1, first: 0x00, last: 0x7F }],
    usecmap: Some(cmap_wbtest_text_name("/Identity-H")),
    wmode: None,
    cmap_name: None,
    cmap_type: None,
    cid_system_info: None,
  }
  @test.assert_eq(
    pdf_text_parsed_cmap_charcodes_of_text(
      mixed_identity_base_parsed,
      cmap_wbtest_text_bytes([0x00, 0x41]),
    ),
    [0x0041],
  )
  let two_byte_parsed : PdfParsedCMap = {
    map: [],
    cid_map: [],
    notdef_map: [],
    codespaces: [{ length: 2, first: 0x0000, last: 0xFFFF }],
    usecmap: None,
    wmode: None,
    cmap_name: None,
    cmap_type: None,
    cid_system_info: None,
  }
  @test.assert_eq(
    PdfExternalCMap(2, two_byte_parsed).uses_two_byte_codes(),
    true,
  )
  let mixed_parsed : PdfParsedCMap = {
    map: [],
    cid_map: [],
    notdef_map: [],
    codespaces: [
      { length: 2, first: 0x4100, last: 0x41FF },
      { length: 1, first: 0x00, last: 0x7F },
    ],
    usecmap: None,
    wmode: None,
    cmap_name: None,
    cmap_type: None,
    cid_system_info: None,
  }
  @test.assert_eq(PdfExternalCMap(3, mixed_parsed).uses_two_byte_codes(), false)
  @test.assert_eq(
    pdf_text_parsed_cmap_charcodes_of_text(
      mixed_parsed,
      cmap_wbtest_text_bytes([0x41, 0x00]),
    ),
    [0x4100],
  )
  let composed = pdf_text_compose_parsed_cmap(
    {
      map: [(1, cmap_wbtest_text_bytes([0x00, 0x41]))],
      cid_map: [(1, 10)],
      notdef_map: [(1, 20)],
      codespaces: [{ length: 1, first: 1, last: 1 }],
      usecmap: Some(cmap_wbtest_text_name("/Identity-V")),
      wmode: Some(1),
      cmap_name: Some(cmap_wbtest_text_name("/Derived")),
      cmap_type: Some(2),
      cid_system_info: Some({
        registry: cmap_wbtest_text_bytes([69]),
        ordering: cmap_wbtest_text_bytes([70]),
        supplement: 5,
      }),
    },
    {
      map: [
        (1, cmap_wbtest_text_bytes([0x00, 0x42])),
        (2, cmap_wbtest_text_bytes([0x00, 0x43])),
        (2, cmap_wbtest_text_bytes([0x00, 0x44])),
      ],
      cid_map: [(1, 11), (2, 12), (2, 13)],
      notdef_map: [(1, 21), (2, 22), (2, 23)],
      codespaces: [{ length: 2, first: 0, last: 0xFFFF }],
      usecmap: Some(cmap_wbtest_text_name("/Identity-H")),
      wmode: Some(0),
      cmap_name: Some(cmap_wbtest_text_name("/Base")),
      cmap_type: Some(1),
      cid_system_info: Some({
        registry: cmap_wbtest_text_bytes([65]),
        ordering: cmap_wbtest_text_bytes([66]),
        supplement: 3,
      }),
    },
  )
  @test.assert_eq(composed.map, [
    (1, cmap_wbtest_text_bytes([0x00, 0x41])),
    (2, cmap_wbtest_text_bytes([0x00, 0x43])),
  ])
  @test.assert_eq(composed.cid_map, [(1, 10), (2, 12)])
  @test.assert_eq(composed.notdef_map, [(1, 20), (2, 22)])
  @test.assert_eq(composed.codespaces, [
    { length: 1, first: 1, last: 1 },
    { length: 2, first: 0, last: 0xFFFF },
  ])
  @test.assert_eq(composed.usecmap, Some(cmap_wbtest_text_name("/Identity-V")))
  @test.assert_eq(composed.wmode, Some(1))
  @test.assert_eq(composed.cmap_name, Some(cmap_wbtest_text_name("/Derived")))
  @test.assert_eq(composed.cmap_type, Some(2))
  @test.assert_eq(
    composed.cid_system_info,
    Some({
      registry: cmap_wbtest_text_bytes([69]),
      ordering: cmap_wbtest_text_bytes([70]),
      supplement: 5,
    }),
  )
  let inherited_metadata = pdf_text_compose_parsed_cmap(empty_parsed, {
    map: [],
    cid_map: [],
    notdef_map: [],
    codespaces: [],
    usecmap: Some(cmap_wbtest_text_name("/Identity-H")),
    wmode: Some(0),
    cmap_name: Some(cmap_wbtest_text_name("/Inherited")),
    cmap_type: Some(1),
    cid_system_info: Some({
      registry: cmap_wbtest_text_bytes([67]),
      ordering: cmap_wbtest_text_bytes([68]),
      supplement: 4,
    }),
  })
  @test.assert_eq(
    inherited_metadata.usecmap,
    Some(cmap_wbtest_text_name("/Identity-H")),
  )
  @test.assert_eq(inherited_metadata.wmode, Some(0))
  @test.assert_eq(
    inherited_metadata.cmap_name,
    Some(cmap_wbtest_text_name("/Inherited")),
  )
  @test.assert_eq(inherited_metadata.cmap_type, Some(1))
  @test.assert_eq(
    inherited_metadata.cid_system_info,
    Some({
      registry: cmap_wbtest_text_bytes([67]),
      ordering: cmap_wbtest_text_bytes([68]),
      supplement: 4,
    }),
  )
  @test.assert_eq(
    pdf_text_parse_cmap_ascii_int_at(@ascii.encode(" 7x"), 0),
    Some((7, 2)),
  )
  @test.assert_eq(
    pdf_text_parse_cmap_ascii_int_at(@ascii.encode(" +7x"), 0),
    None,
  )
  @test.assert_eq(
    pdf_text_parse_cmap_ascii_int_at(@ascii.encode(" +x"), 0),
    None,
  )
  let cidchar_entries : Array[(Int, Int)] = []
  pdf_text_push_cmap_cidchar_entries(
    cidchar_entries,
    @ascii.encode("<> 1 <41> 7 <42> +"),
  )
  @test.assert_eq(cidchar_entries, [(0x41, 7)])
  pdf_text_push_cmap_cidchar_entries(cidchar_entries, @ascii.encode("<43> +7"))
  @test.assert_eq(cidchar_entries, [(0x41, 7)])

  let cidrange_entries : Array[(Int, Int)] = []
  pdf_text_push_cmap_cidrange_entries(
    cidrange_entries,
    @ascii.encode("<02><01> 5"),
  )
  @test.assert_eq(cidrange_entries, [])
  pdf_text_push_cmap_cidrange_entries(
    cidrange_entries,
    @ascii.encode("<10><11>"),
  )
  @test.assert_eq(cidrange_entries, [])
  pdf_text_push_cmap_cidrange_entries(cidrange_entries, @ascii.encode("<12> 8"))
  @test.assert_eq(cidrange_entries, [])

  let codespaces : Array[PdfCMapCodeSpace] = []
  pdf_text_push_cmap_codespace_entries(codespaces, @ascii.encode("<00><FFFF>"))
  @test.assert_eq(codespaces, [])
  pdf_text_push_cmap_codespace_entries(codespaces, @ascii.encode("<00>"))
  @test.assert_eq(codespaces, [])

  @test.assert_eq(
    pdf_text_parse_cmap_cids(
      @ascii.encode("1 begin\n" + "cidchar\n" + "<41> 7\n" + "endcidchar\n"),
    ),
    Some([(0x41, 7)]),
  )
  @test.assert_eq(
    pdf_text_parse_cmap_cids(
      @ascii.encode(
        "1 begincidchar <41> 7 endcidchar\n" +
        "1 begin\n" +
        "cidchar\n" +
        "<42> 8\n" +
        "endcidchar\n",
      ),
    ),
    Some([(0x41, 7), (0x42, 8)]),
  )
  @test.assert_eq(
    pdf_text_parse_cmap_notdefs(
      @ascii.encode(
        "1 beginnotdefchar <20> 0 endnotdefchar\n" +
        "1 begin\n" +
        "notdefrange\n" +
        "<30><31> 5\n" +
        "endnotdefrange\n",
      ),
    ),
    Some([(0x20, 0), (0x30, 5), (0x31, 6)]),
  )
  @test.assert_eq(
    pdf_text_parse_cmap_notdefs(
      @ascii.encode(
        "1 begin\n" + "notdefchar\n" + "<20> 0\n" + "endnotdefchar\n",
      ),
    ),
    Some([(0x20, 0)]),
  )
  @test.assert_eq(
    pdf_text_parse_cmap_codespaces(
      @ascii.encode(
        "1 begin\n" + "codespacerange\n" + "<00><7F>\n" + "endcodespacerange\n",
      ),
    ),
    Some([{ length: 1, first: 0x00, last: 0x7F }]),
  )
  @test.assert_eq(
    pdf_text_parse_cmap_codespaces(
      @ascii.encode(
        "1 begincodespacerange <00><7F> endcodespacerange\n" +
        "1 begin\n" +
        "codespacerange\n" +
        "<8100><81FF>\n" +
        "endcodespacerange\n",
      ),
    ),
    Some([
      { length: 1, first: 0x00, last: 0x7F },
      { length: 2, first: 0x8100, last: 0x81FF },
    ]),
  )

  let fallback_doc = pdf_document_empty()
  let descendant = @syntax.pdf_dictionary([
    (
      cmap_wbtest_text_name("/CIDSystemInfo"),
      @syntax.pdf_dictionary([
        (
          cmap_wbtest_text_name("/Registry"),
          PdfString(cmap_wbtest_text_bytes([82])),
        ),
        (
          cmap_wbtest_text_name("/Ordering"),
          PdfString(cmap_wbtest_text_bytes([79])),
        ),
        (cmap_wbtest_text_name("/Supplement"), PdfInteger(0)),
      ]),
    ),
    (
      cmap_wbtest_text_name("/BaseFont"),
      PdfNameObject(cmap_wbtest_text_name("/Descendant")),
    ),
    (cmap_wbtest_text_name("/FontDescriptor"), @syntax.pdf_dictionary([])),
  ])
  fallback_doc.add_object_given_number(4, descendant)
  let bad_cmap = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (
        cmap_wbtest_text_name("/Filter"),
        PdfNameObject(cmap_wbtest_text_name("/NoSuchFilter")),
      ),
    ]),
    StreamGot(cmap_wbtest_text_bytes([1])),
  )
  fallback_doc.add_object_given_number(5, bad_cmap)
  let font = @syntax.pdf_dictionary([
    (
      cmap_wbtest_text_name("/BaseFont"),
      PdfNameObject(cmap_wbtest_text_name("/Top")),
    ),
    (cmap_wbtest_text_name("/DescendantFonts"), PdfArray([PdfIndirect(4)])),
    (cmap_wbtest_text_name("/Encoding"), PdfIndirect(5)),
  ])
  guard (try! fallback_doc.read_cidkeyed_font(font)).encoding is PdfCMap(5) else {
    fail("expected unparsed fallback CMap")
  }
}

///|
test "private direct Unicode predefined CMap helpers cover malformed scalars" {
  let utf8_name = cmap_wbtest_text_name("/UniJIS-UTF8-H")
  @test.assert_eq(
    pdf_text_predefined_cmap_charcodes_of_text(
      utf8_name,
      cmap_wbtest_text_bytes([0xC2, 0xA2]),
    ),
    [0xC2A2],
  )
  @test.assert_eq(pdf_text_predefined_utf8_charcode(0x41), Some(0x41))
  @test.assert_eq(pdf_text_predefined_utf8_charcode(0xA2), Some(0xC2A2))
  @test.assert_eq(pdf_text_predefined_utf8_charcode(0xD800), None)
  let truncated_utf8 : Result[Array[Int], Error] = try
    pdf_text_predefined_cmap_charcodes_of_text(
      utf8_name,
      cmap_wbtest_text_bytes([0xC2]),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard truncated_utf8 is Err(_) else {
    fail("expected truncated UTF8 predefined CMap text to raise")
  }
  let invalid_lead_utf8 : Result[Array[Int], Error] = try
    pdf_text_predefined_cmap_charcodes_of_text(
      utf8_name,
      cmap_wbtest_text_bytes([0xFF]),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard invalid_lead_utf8 is Err(_) else {
    fail("expected invalid leading UTF8 predefined CMap text to raise")
  }
  let invalid_continuation_utf8 : Result[Array[Int], Error] = try
    pdf_text_predefined_cmap_charcodes_of_text(
      utf8_name,
      cmap_wbtest_text_bytes([0xC2, 0x41]),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard invalid_continuation_utf8 is Err(_) else {
    fail("expected invalid UTF8 predefined CMap text to raise")
  }

  @test.assert_eq(pdf_text_predefined_utf16_codepoints(0xD800), None)
  @test.assert_eq(
    pdf_text_predefined_utf16_codepoints(
      pdf_text_pack_four_bytes(0xD8, 0x00, 0x00, 0x41),
    ),
    None,
  )
  @test.assert_eq(pdf_text_predefined_utf16_codepoints(0x123456), None)
  let low_surrogate_utf16 : Result[Array[Int], Error] = try
    pdf_text_predefined_cmap_charcodes_of_text(
      cmap_wbtest_text_name("/UniJIS-UTF16-H"),
      cmap_wbtest_text_bytes([0xDC, 0x00]),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard low_surrogate_utf16 is Err(_) else {
    fail("expected low-surrogate UTF16 predefined CMap text to raise")
  }

  @test.assert_eq(pdf_text_predefined_utf32_codepoints(0xD800), None)
  @test.assert_eq(pdf_text_predefined_utf32_charcode(0x110000), None)
  @test.assert_eq(
    pdf_text_predefined_direct_unicode_charcode(
      cmap_wbtest_text_name("/UniJIS-UCS2-H"),
      0x1D11E,
    ),
    None,
  )

  let composite : PdfCompositeCIDFont = {
    cid_system_info: {
      registry: cmap_wbtest_text_bytes([82]),
      ordering: cmap_wbtest_text_bytes([79]),
      supplement: 0,
    },
    cid_basefont: cmap_wbtest_text_name("/Descendant"),
    cid_fontdescriptor: pdf_text_empty_font_descriptor(),
    cid_widths: [],
    cid_widths2: [],
    cid_default_width: 1000.0,
    cid_default_width2: [880.0, -1000.0],
  }
  let two_byte_font : PdfFont = PdfFontCIDKeyed({
    basefont: cmap_wbtest_text_name("/Top"),
    composite,
    encoding: PdfPredefinedCMap(cmap_wbtest_text_name("/Identity-H")),
  })
  @test.assert_eq(
    two_byte_font.pdf_text_fixed_or_single_byte_charcodes_of_text(
      cmap_wbtest_text_bytes([0x00, 0x41]),
    ),
    [0x41],
  )
  let odd_fixed : Result[Array[Int], Error] = try
    two_byte_font.pdf_text_fixed_or_single_byte_charcodes_of_text(
      cmap_wbtest_text_bytes([0]),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard odd_fixed is Err(_) else {
    fail("expected odd fixed-width CID text to raise")
  }
}

///|
test "private text stream helpers treat malformed ToUnicode streams as absent" {
  let key = cmap_wbtest_text_name("/Missing")
  @test.assert_eq(pdf_text_dictionary_has_key(PdfInteger(1), key), false)
  @test.assert_eq(pdf_text_find_immediate_indirect(PdfInteger(1), key), None)
  let helper_doc = pdf_document_empty()

  let bad_deferred = @syntax.pdf_stream(
    PdfDictionary([]),
    StreamToGet(
      @syntax.stream_to_get(
        @core.byte_cursor_of_bytes(@ascii.encode("abc")),
        -1,
        1,
      ),
    ),
  )
  let bad_deferred_result : Result[PdfParsedCMap, Error] = try
    helper_doc.parse_cmap(bad_deferred)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_deferred_result is Err(_) else {
    fail("expected malformed deferred stream CMap to raise")
  }
  let bad_filter = @syntax.pdf_stream(
    PdfDictionary([(cmap_wbtest_text_name("/Filter"), PdfInteger(1))]),
    StreamGot(@ascii.encode("x")),
  )
  let bad_filter_result : Result[PdfParsedCMap, Error] = try
    helper_doc.parse_cmap(bad_filter)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_filter_result is Err(_) else {
    fail("expected malformed filter CMap to raise")
  }
  let unsupported_filter = @syntax.pdf_stream(
    PdfDictionary([
      (cmap_wbtest_text_name("/Length"), PdfInteger(1)),
      (
        cmap_wbtest_text_name("/Filter"),
        PdfNameObject(cmap_wbtest_text_name("/NoSuchFilter")),
      ),
    ]),
    StreamGot(@ascii.encode("x")),
  )
  let unsupported_filter_result : Result[PdfParsedCMap, Error] = try
    helper_doc.parse_cmap(unsupported_filter)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard unsupported_filter_result is Err(_) else {
    fail("expected unsupported filter CMap to raise")
  }
  let non_stream_result : Result[PdfParsedCMap, Error] = try
    helper_doc.parse_cmap(PdfInteger(1))
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard non_stream_result is Err(_) else {
    fail("expected non-stream CMap to raise")
  }

  let doc = pdf_document_empty()
  let font = @syntax.PdfDictionary([
    (cmap_wbtest_text_name("/ToUnicode"), unsupported_filter),
  ])
  @test.assert_eq(doc.pdf_text_tounicode_of_font(font), None)
}
