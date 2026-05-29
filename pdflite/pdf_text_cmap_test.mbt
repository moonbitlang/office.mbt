///|
fn text_cmap_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn text_cmap_bytes_for_test(values : ArrayView[Int]) -> @pdflite.PdfBytes {
  try! @pdflite.pdf_bytes_of_int_array(values)
}

///|
fn text_cmap_concat_for_test(
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
fn text_cmap_font_descriptor_for_test() -> @pdflite.PdfFontDescriptor {
  {
    ascent: 0.0,
    descent: 0.0,
    avgwidth: 0.0,
    maxwidth: 0.0,
    flags: 0,
    fontbbox: { min_x: 0.0, min_y: 0.0, max_x: 0.0, max_y: 0.0 },
    italicangle: 0.0,
    capheight: 0.0,
    xheight: 0.0,
    stemv: 0.0,
    fontfile: None,
    charset: None,
    tounicode: None,
  }
}

///|
fn text_cmap_cid_system_info_object_for_test() -> @pdflite.PdfObject {
  @pdflite.pdf_dictionary([
    (
      text_cmap_name_for_test("/Registry"),
      PdfString(text_cmap_bytes_for_test([82])),
    ),
    (
      text_cmap_name_for_test("/Ordering"),
      PdfString(text_cmap_bytes_for_test([79])),
    ),
    (text_cmap_name_for_test("/Supplement"), PdfInteger(0)),
  ])
}

///|
fn text_cmap_valid_cid_descendant_for_test(
  extra : ArrayView[(@pdflite.PdfName, @pdflite.PdfObject)],
) -> @pdflite.PdfObject {
  let entries : Array[(@pdflite.PdfName, @pdflite.PdfObject)] = [
    (
      text_cmap_name_for_test("/CIDSystemInfo"),
      text_cmap_cid_system_info_object_for_test(),
    ),
    (
      text_cmap_name_for_test("/BaseFont"),
      PdfNameObject(text_cmap_name_for_test("/Descendant")),
    ),
    (text_cmap_name_for_test("/FontDescriptor"), @pdflite.pdf_dictionary([])),
  ]
  for entry in extra {
    entries.push(entry)
  }
  @pdflite.pdf_dictionary(entries)
}

///|
test "pdf_parse_cmap_data returns ToUnicode map and WMode" {
  let parsed = @pdflite.pdf_parse_cmap_data(
    @ascii.encode(
      "/CIDInit /ProcSet findresource begin\n" +
      "/Identity-H usecmap\n" +
      "/WMode 1 def\n" +
      "2 beginbfchar\n" +
      "<21><0041>\n" +
      "<22><0042>\n" +
      "endbfchar\n",
    ),
  )
  @test.assert_eq(parsed.wmode, Some(1))
  @test.assert_eq(parsed.map, [
    (33, text_cmap_bytes_for_test([0x00, 0x41])),
    (34, text_cmap_bytes_for_test([0x00, 0x42])),
  ])
  @test.assert_eq(parsed.usecmap, Some(text_cmap_name_for_test("/Identity-H")))
  let malformed_wmode = @pdflite.pdf_parse_cmap_data(
    @ascii.encode("/WMode invalid\n"),
  )
  @test.assert_eq(malformed_wmode.wmode, None)
  @test.assert_eq(malformed_wmode.map, [])
  @test.assert_eq(
    @pdflite.pdf_parse_cmap_data(@ascii.encode("/XMode 1\n")).wmode,
    None,
  )
}

///|
test "pdf_parse_cmap_data reads WMode across PDF whitespace" {
  let parsed = @pdflite.pdf_parse_cmap_data(
    @ascii.encode(
      "/CIDInit /ProcSet findresource begin\n" +
      "/WMode\r\n1 def\n" +
      "1 beginbfchar\n" +
      "<21><0041>\n" +
      "endbfchar\n",
    ),
  )
  @test.assert_eq(parsed.wmode, Some(1))
  @test.assert_eq(parsed.map, [(33, text_cmap_bytes_for_test([0x00, 0x41]))])
  @test.assert_eq(
    @pdflite.pdf_parse_cmap_data(@ascii.encode("/WMode\nbad\n/WMode\t0 def\n")).wmode,
    Some(0),
  )
}

///|
test "pdf_parse_cmap_data reads UseCMap names across PDF whitespace" {
  let parsed = @pdflite.pdf_parse_cmap_data(
    @ascii.encode("/Identity-V\r\nusecmap\n"),
  )
  @test.assert_eq(parsed.usecmap, Some(text_cmap_name_for_test("/Identity-V")))
  @test.assert_eq(
    @pdflite.pdf_parse_cmap_data(@ascii.encode("usecmap\n")).usecmap,
    None,
  )
  @test.assert_eq(
    @pdflite.pdf_parse_cmap_data(@ascii.encode("/Bad#2dName usecmap\n")).usecmap,
    Some(text_cmap_name_for_test("/Bad-Name")),
  )
  @test.assert_eq(
    @pdflite.pdf_parse_cmap_data(@ascii.encode("/Bad#xxName usecmap\n")).usecmap,
    None,
  )
}

///|
test "pdf_parse_cmap_data reads CMap header metadata" {
  let parsed = @pdflite.pdf_parse_cmap_data(
    @ascii.encode(
      "/CIDSystemInfo <<\n" +
      "  /Registry (Adobe)\n" +
      "  /Ordering (UCS)\n" +
      "  /Supplement 0\n" +
      ">> def\n" +
      "/CMapName /Adobe-Identity-UCS def\n" +
      "/CMapType 2 def\n",
    ),
  )
  @test.assert_eq(
    parsed.cmap_name,
    Some(text_cmap_name_for_test("/Adobe-Identity-UCS")),
  )
  @test.assert_eq(parsed.cmap_type, Some(2))
  @test.assert_eq(
    parsed.cid_system_info,
    Some({
      registry: @ascii.encode("Adobe"),
      ordering: @ascii.encode("UCS"),
      supplement: 0,
    }),
  )
  let dict_style = @pdflite.pdf_parse_cmap_data(
    @ascii.encode(
      "/CIDSystemInfo 3 dict dup begin\n" +
      "/Registry (Adobe) def\n" +
      "/Ordering (Japan1) def\n" +
      "/Supplement 6 def\n" +
      "end def\n",
    ),
  )
  @test.assert_eq(
    dict_style.cid_system_info,
    Some({
      registry: @ascii.encode("Adobe"),
      ordering: @ascii.encode("Japan1"),
      supplement: 6,
    }),
  )
  let malformed = @pdflite.pdf_parse_cmap_data(
    @ascii.encode(
      "/CIDSystemInfo << /Registry /Adobe /Ordering (UCS) /Supplement bad >>\n" +
      "/CMapName Adobe-Identity-UCS def\n" +
      "/CMapType bad def\n",
    ),
  )
  @test.assert_eq(malformed.cmap_name, None)
  @test.assert_eq(malformed.cmap_type, None)
  @test.assert_eq(malformed.cid_system_info, None)
}

///|
test "pdf_parse_cmap decodes stream objects" {
  let doc = @pdflite.pdf_document_empty()
  let cmap_data = @ascii.encode(
    "/WMode 0 def\n" + "1 beginbfrange\n" + "<30><31><0061>\n" + "endbfrange\n",
  )
  let encoded_cmap = @pdflite.pdf_flate_encode(cmap_data)
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (text_cmap_name_for_test("/Length"), PdfInteger(encoded_cmap.length())),
      (
        text_cmap_name_for_test("/Filter"),
        PdfNameObject(text_cmap_name_for_test("/FlateDecode")),
      ),
      (
        text_cmap_name_for_test("/UseCMap"),
        PdfNameObject(text_cmap_name_for_test("/Identity-V")),
      ),
    ]),
    StreamGot(encoded_cmap),
  )
  doc.add_object_given_number(17, stream)
  @test.assert_eq(@pdflite.pdf_parse_cmap(doc, PdfIndirect(17)), {
    map: [
      (48, text_cmap_bytes_for_test([0x00, 0x61])),
      (49, text_cmap_bytes_for_test([0x00, 0x62])),
    ],
    cid_map: [],
    notdef_map: [],
    codespaces: [],
    usecmap: Some(text_cmap_name_for_test("/Identity-V")),
    wmode: Some(0),
    cmap_name: None,
    cmap_type: None,
    cid_system_info: None,
  })
  let non_stream : Result[@pdflite.PdfParsedCMap, Error] = try? @pdflite.pdf_parse_cmap(
    doc,
    PdfInteger(1),
  )
  guard non_stream is Err(@pdflite.PdfError::CMapEncodingExpected) else {
    fail("expected @pdflite.PdfError::CMapEncodingExpected")
  }
}

///|
test "PdfDocument parse_cmap reads stream dictionary metadata" {
  let doc = @pdflite.pdf_document_empty()
  let cmap_data = @ascii.encode(
    "1 begincidchar\n" + "<41> 100\n" + "endcidchar\n",
  )
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (text_cmap_name_for_test("/Length"), PdfInteger(cmap_data.length())),
      (text_cmap_name_for_test("/WMode"), PdfInteger(1)),
      (
        text_cmap_name_for_test("/CMapName"),
        PdfNameObject(text_cmap_name_for_test("/Dictionary-CMap")),
      ),
      (text_cmap_name_for_test("/CMapType"), PdfInteger(1)),
      (
        text_cmap_name_for_test("/CIDSystemInfo"),
        @pdflite.pdf_dictionary([
          (
            text_cmap_name_for_test("/Registry"),
            PdfString(@ascii.encode("DictRegistry")),
          ),
          (
            text_cmap_name_for_test("/Ordering"),
            PdfString(@ascii.encode("DictOrdering")),
          ),
          (text_cmap_name_for_test("/Supplement"), PdfInteger(4)),
        ]),
      ),
      (
        text_cmap_name_for_test("/UseCMap"),
        PdfNameObject(text_cmap_name_for_test("/GB-EUC-H")),
      ),
    ]),
    StreamGot(cmap_data),
  )
  doc.add_object_given_number(18, stream)
  let parsed = try! doc.parse_cmap(PdfIndirect(18))
  @test.assert_eq(parsed.cid_map, [(0x41, 100)])
  @test.assert_eq(parsed.usecmap, Some(text_cmap_name_for_test("/GB-EUC-H")))
  @test.assert_eq(parsed.wmode, Some(1))
  @test.assert_eq(
    parsed.cmap_name,
    Some(text_cmap_name_for_test("/Dictionary-CMap")),
  )
  @test.assert_eq(parsed.cmap_type, Some(1))
  @test.assert_eq(
    parsed.cid_system_info,
    Some({
      registry: @ascii.encode("DictRegistry"),
      ordering: @ascii.encode("DictOrdering"),
      supplement: 4,
    }),
  )

  let overriding_data = @ascii.encode(
    "/WMode 0 def\n" +
    "/CMapName /Program-CMap def\n" +
    "/CMapType 2 def\n" +
    "/CIDSystemInfo << /Registry (ProgRegistry) /Ordering (ProgOrdering) /Supplement 5 >> def\n",
  )
  doc.add_object_given_number(
    19,
    @pdflite.pdf_stream(
      @pdflite.pdf_dictionary([
        (
          text_cmap_name_for_test("/Length"),
          PdfInteger(overriding_data.length()),
        ),
        (text_cmap_name_for_test("/WMode"), PdfInteger(1)),
        (
          text_cmap_name_for_test("/CMapName"),
          PdfNameObject(text_cmap_name_for_test("/Dictionary-CMap")),
        ),
        (text_cmap_name_for_test("/CMapType"), PdfInteger(1)),
        (
          text_cmap_name_for_test("/CIDSystemInfo"),
          @pdflite.pdf_dictionary([
            (
              text_cmap_name_for_test("/Registry"),
              PdfString(@ascii.encode("DictRegistry")),
            ),
            (
              text_cmap_name_for_test("/Ordering"),
              PdfString(@ascii.encode("DictOrdering")),
            ),
            (text_cmap_name_for_test("/Supplement"), PdfInteger(4)),
          ]),
        ),
      ]),
      StreamGot(overriding_data),
    ),
  )
  let overridden = try! doc.parse_cmap(PdfIndirect(19))
  @test.assert_eq(overridden.wmode, Some(0))
  @test.assert_eq(
    overridden.cmap_name,
    Some(text_cmap_name_for_test("/Program-CMap")),
  )
  @test.assert_eq(overridden.cmap_type, Some(2))
  @test.assert_eq(
    overridden.cid_system_info,
    Some({
      registry: @ascii.encode("ProgRegistry"),
      ordering: @ascii.encode("ProgOrdering"),
      supplement: 5,
    }),
  )

  doc.add_object_given_number(
    20,
    @pdflite.pdf_stream(
      @pdflite.pdf_dictionary([
        (text_cmap_name_for_test("/Length"), PdfInteger(0)),
        (text_cmap_name_for_test("/CIDSystemInfo"), PdfInteger(1)),
      ]),
      StreamGot(Bytes::new(0)),
    ),
  )
  @test.assert_eq((try! doc.parse_cmap(PdfIndirect(20))).cid_system_info, None)

  doc.add_object_given_number(21, PdfInteger(1))
  doc.add_object_given_number(
    22,
    PdfNameObject(text_cmap_name_for_test("/Indirect-CMap")),
  )
  doc.add_object_given_number(23, PdfInteger(2))
  doc.add_object_given_number(
    24,
    @pdflite.pdf_dictionary([
      (
        text_cmap_name_for_test("/Registry"),
        PdfString(@ascii.encode("IndirectRegistry")),
      ),
      (
        text_cmap_name_for_test("/Ordering"),
        PdfString(@ascii.encode("IndirectOrdering")),
      ),
      (text_cmap_name_for_test("/Supplement"), PdfInteger(6)),
    ]),
  )
  doc.add_object_given_number(
    25,
    PdfNameObject(text_cmap_name_for_test("/Identity-V")),
  )
  doc.add_object_given_number(
    26,
    @pdflite.pdf_stream(
      @pdflite.pdf_dictionary([
        (text_cmap_name_for_test("/Length"), PdfInteger(0)),
        (text_cmap_name_for_test("/WMode"), PdfIndirect(21)),
        (text_cmap_name_for_test("/CMapName"), PdfIndirect(22)),
        (text_cmap_name_for_test("/CMapType"), PdfIndirect(23)),
        (text_cmap_name_for_test("/CIDSystemInfo"), PdfIndirect(24)),
        (text_cmap_name_for_test("/UseCMap"), PdfIndirect(25)),
      ]),
      StreamGot(Bytes::new(0)),
    ),
  )
  let indirect = try! doc.parse_cmap(PdfIndirect(26))
  @test.assert_eq(indirect.wmode, Some(1))
  @test.assert_eq(
    indirect.cmap_name,
    Some(text_cmap_name_for_test("/Indirect-CMap")),
  )
  @test.assert_eq(indirect.cmap_type, Some(2))
  @test.assert_eq(
    indirect.usecmap,
    Some(text_cmap_name_for_test("/Identity-V")),
  )
  @test.assert_eq(
    indirect.cid_system_info,
    Some({
      registry: @ascii.encode("IndirectRegistry"),
      ordering: @ascii.encode("IndirectOrdering"),
      supplement: 6,
    }),
  )
}

///|
test "pdf_parse_cmap_data reads external CID mappings and codespaces" {
  let parsed = @pdflite.pdf_parse_cmap_data(
    @ascii.encode(
      "2 begincodespacerange\n" +
      "<00><7F>\n" +
      "<8100><81FF>\n" +
      "endcodespacerange\n" +
      "1 begincidchar\n" +
      "<41> 100\n" +
      "endcidchar\n" +
      "1 begincidrange\n" +
      "<8140><8142> 200\n" +
      "endcidrange\n" +
      "1 beginnotdefchar\n" +
      "<20> 0\n" +
      "endnotdefchar\n" +
      "1 beginnotdefrange\n" +
      "<30><31> 5\n" +
      "endnotdefrange\n",
    ),
  )
  @test.assert_eq(parsed.codespaces, [
    { length: 1, first: 0x00, last: 0x7F },
    { length: 2, first: 0x8100, last: 0x81FF },
  ])
  @test.assert_eq(parsed.cid_map, [
    (0x41, 100),
    (0x8140, 200),
    (0x8141, 201),
    (0x8142, 202),
  ])
  @test.assert_eq(parsed.notdef_map, [(0x20, 0), (0x30, 5), (0x31, 6)])
  @test.assert_eq(parsed.map, [])
}

///|
test "PdfDocument applies external CMap Identity UseCMap fallback" {
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(4, text_cmap_valid_cid_descendant_for_test([]))
  let cmap_data = @ascii.encode(
    "/Identity-H usecmap\n" +
    "1 begincidchar\n" +
    "<0041> 99\n" +
    "endcidchar\n" +
    "1 beginnotdefchar\n" +
    "<0041> 77\n" +
    "endnotdefchar\n",
  )
  let cmap = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (text_cmap_name_for_test("/Length"), PdfInteger(cmap_data.length())),
    ]),
    StreamGot(cmap_data),
  )
  doc.add_object_given_number(5, cmap)
  let font = @pdflite.pdf_dictionary([
    (
      text_cmap_name_for_test("/Subtype"),
      PdfNameObject(text_cmap_name_for_test("/Type0")),
    ),
    (
      text_cmap_name_for_test("/BaseFont"),
      PdfNameObject(text_cmap_name_for_test("/T")),
    ),
    (text_cmap_name_for_test("/DescendantFonts"), PdfArray([PdfIndirect(4)])),
    (text_cmap_name_for_test("/Encoding"), PdfIndirect(5)),
  ])
  guard (try! doc.read_cidkeyed_font(font)).encoding
    is PdfExternalCMap(5, parsed) else {
    fail("expected parsed external CMap")
  }
  @test.assert_eq(parsed.usecmap, Some(text_cmap_name_for_test("/Identity-H")))
  let extractor = try! doc.text_extractor_of_font(font)
  @test.assert_eq(
    extractor.codepoints_of_text(
      text_cmap_bytes_for_test([0x00, 0x41, 0x00, 0x42]),
    ),
    [99, 0x42],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(99), Some(0x0041))
  @test.assert_eq(extractor.charcode_of_codepoint(77), None)
  @test.assert_eq(extractor.charcode_of_codepoint(0x42), Some(0x0042))
  @test.assert_eq(extractor.charcode_of_codepoint(0x41), None)
}

///|
test "PdfDocument applies external CMap Unicode maps before inherited fallback" {
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(4, text_cmap_valid_cid_descendant_for_test([]))
  let cmap_data = @ascii.encode(
    "/Identity-H usecmap\n" +
    "4 beginbfchar\n" +
    "<0041><0061>\n" +
    "<0042><0062>\n" +
    "<0044><00610062>\n" +
    "<0047><D800>\n" +
    "endbfchar\n" +
    "1 beginbfrange\n" +
    "<0045><0046><0063>\n" +
    "endbfrange\n" +
    "1 begincidchar\n" +
    "<0042> 66\n" +
    "endcidchar\n",
  )
  let cmap = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (text_cmap_name_for_test("/Length"), PdfInteger(cmap_data.length())),
    ]),
    StreamGot(cmap_data),
  )
  doc.add_object_given_number(5, cmap)
  let font = @pdflite.pdf_dictionary([
    (
      text_cmap_name_for_test("/Subtype"),
      PdfNameObject(text_cmap_name_for_test("/Type0")),
    ),
    (
      text_cmap_name_for_test("/BaseFont"),
      PdfNameObject(text_cmap_name_for_test("/T")),
    ),
    (text_cmap_name_for_test("/DescendantFonts"), PdfArray([PdfIndirect(4)])),
    (text_cmap_name_for_test("/Encoding"), PdfIndirect(5)),
  ])
  let cid_font = doc.read_cidkeyed_font(font)
  guard cid_font.encoding is PdfExternalCMap(5, parsed) else {
    fail("expected parsed external CMap")
  }
  @test.assert_eq(parsed.map, [
    (0x0041, text_cmap_bytes_for_test([0x00, 0x61])),
    (0x0042, text_cmap_bytes_for_test([0x00, 0x62])),
    (0x0044, text_cmap_bytes_for_test([0x00, 0x61, 0x00, 0x62])),
    (0x0047, text_cmap_bytes_for_test([0xD8, 0x00])),
    (0x0045, text_cmap_bytes_for_test([0x00, 0x63])),
    (0x0046, text_cmap_bytes_for_test([0x00, 0x64])),
  ])
  let extractor = doc.text_extractor_of_font(font)
  @test.assert_eq(
    extractor.codepoints_of_text(
      text_cmap_bytes_for_test([
        0x00, 0x41, 0x00, 0x42, 0x00, 0x43, 0x00, 0x44, 0x00, 0x45, 0x00, 0x46, 0x00,
        0x47,
      ]),
    ),
    [0x61, 66, 0x43, 0x61, 0x62, 0x63, 0x64, 0x47],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x61), Some(0x0041))
  @test.assert_eq(extractor.charcode_of_codepoint(66), Some(0x0042))
  @test.assert_eq(extractor.charcode_of_codepoint(0x62), Some(0x0062))
  @test.assert_eq(extractor.charcode_of_codepoint(0x63), Some(0x0045))
  @test.assert_eq(extractor.charcode_of_codepoint(0x41), None)
  @test.assert_eq(extractor.charcode_of_codepoint(0x47), None)
}

///|
test "PdfDocument applies external CMap predefined UseCMap fallback" {
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(4, text_cmap_valid_cid_descendant_for_test([]))
  let cmap_data = @ascii.encode(
    "/GB-EUC-H usecmap\n" + "1 begincidchar\n" + "<A1A1> 99\n" + "endcidchar\n",
  )
  let cmap = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (text_cmap_name_for_test("/Length"), PdfInteger(cmap_data.length())),
    ]),
    StreamGot(cmap_data),
  )
  doc.add_object_given_number(5, cmap)
  let font = @pdflite.pdf_dictionary([
    (
      text_cmap_name_for_test("/Subtype"),
      PdfNameObject(text_cmap_name_for_test("/Type0")),
    ),
    (
      text_cmap_name_for_test("/BaseFont"),
      PdfNameObject(text_cmap_name_for_test("/T")),
    ),
    (text_cmap_name_for_test("/DescendantFonts"), PdfArray([PdfIndirect(4)])),
    (text_cmap_name_for_test("/Encoding"), PdfIndirect(5)),
  ])
  let extractor = try! doc.text_extractor_of_font(font)
  @test.assert_eq(
    extractor.codepoints_of_text(
      text_cmap_bytes_for_test([0x41, 0xA1, 0xA1, 0xC4, 0xE3]),
    ),
    [0x41, 99, 0x4F60],
  )
  @test.assert_eq(
    extractor.codepoints_of_text(text_cmap_bytes_for_test([0x81, 0x40])),
    [0x8140],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(99), Some(0xA1A1))
  @test.assert_eq(extractor.charcode_of_codepoint(0x4F60), Some(0xC4E3))
  @test.assert_eq(extractor.charcode_of_codepoint(0x3000), None)
  @test.assert_eq(extractor.charcode_of_codepoint(0x20AC), None)

  let one_byte_cmap_data = @ascii.encode("/NoSuch-H usecmap\n")
  doc.add_object_given_number(
    6,
    @pdflite.pdf_stream(
      @pdflite.pdf_dictionary([
        (
          text_cmap_name_for_test("/Length"),
          PdfInteger(one_byte_cmap_data.length()),
        ),
      ]),
      StreamGot(one_byte_cmap_data),
    ),
  )
  let one_byte_font = @pdflite.pdf_dictionary([
    (
      text_cmap_name_for_test("/Subtype"),
      PdfNameObject(text_cmap_name_for_test("/Type0")),
    ),
    (
      text_cmap_name_for_test("/BaseFont"),
      PdfNameObject(text_cmap_name_for_test("/T")),
    ),
    (text_cmap_name_for_test("/DescendantFonts"), PdfArray([PdfIndirect(4)])),
    (text_cmap_name_for_test("/Encoding"), PdfIndirect(6)),
  ])
  @test.assert_eq(
    (try! doc.text_extractor_of_font(one_byte_font)).codepoints_of_text(
      text_cmap_bytes_for_test([0x41]),
    ),
    [0x41],
  )
}

///|
test "PdfDocument composes external CMap UseCMap stream bases" {
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(4, text_cmap_valid_cid_descendant_for_test([]))
  let base_data = @ascii.encode(
    "/Identity-H usecmap\n" +
    "/CIDSystemInfo << /Registry (Adobe) /Ordering (Test) /Supplement 3 >> def\n" +
    "/CMapName /Base-CMap def\n" +
    "/CMapType 1 def\n" +
    "/WMode 0 def\n" +
    "1 begincodespacerange\n" +
    "<0000><00FF>\n" +
    "endcodespacerange\n" +
    "1 begincidrange\n" +
    "<0040><0042> 500\n" +
    "endcidrange\n" +
    "1 beginnotdefrange\n" +
    "<0050><0051> 700\n" +
    "endnotdefrange\n" +
    "2 beginbfchar\n" +
    "<0041><0042>\n" +
    "<0042><0043>\n" +
    "endbfchar\n",
  )
  doc.add_object_given_number(
    6,
    @pdflite.pdf_stream(
      @pdflite.pdf_dictionary([
        (text_cmap_name_for_test("/Length"), PdfInteger(base_data.length())),
      ]),
      StreamGot(base_data),
    ),
  )
  let derived_data = @ascii.encode(
    "/WMode 1 def\n" +
    "/CMapType 2 def\n" +
    "1 begincidchar\n" +
    "<0041> 99\n" +
    "endcidchar\n" +
    "1 beginnotdefchar\n" +
    "<0050> 77\n" +
    "endnotdefchar\n" +
    "1 beginbfchar\n" +
    "<0041><0041>\n" +
    "endbfchar\n",
  )
  let derived_cmap = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (text_cmap_name_for_test("/Length"), PdfInteger(derived_data.length())),
      (text_cmap_name_for_test("/UseCMap"), PdfIndirect(6)),
    ]),
    StreamGot(derived_data),
  )
  doc.add_object_given_number(5, derived_cmap)
  let parsed = try! doc.parse_cmap(PdfIndirect(5))
  @test.assert_eq(parsed.wmode, Some(1))
  @test.assert_eq(parsed.usecmap, Some(text_cmap_name_for_test("/Identity-H")))
  @test.assert_eq(parsed.cmap_name, Some(text_cmap_name_for_test("/Base-CMap")))
  @test.assert_eq(parsed.cmap_type, Some(2))
  @test.assert_eq(
    parsed.cid_system_info,
    Some({
      registry: @ascii.encode("Adobe"),
      ordering: @ascii.encode("Test"),
      supplement: 3,
    }),
  )
  @test.assert_eq(parsed.codespaces, [
    { length: 2, first: 0x0000, last: 0x00FF },
  ])
  @test.assert_eq(parsed.cid_map, [(0x0041, 99), (0x0040, 500), (0x0042, 502)])
  @test.assert_eq(parsed.notdef_map, [(0x0050, 77), (0x0051, 701)])
  @test.assert_eq(parsed.map, [
    (0x0041, text_cmap_bytes_for_test([0x00, 0x41])),
    (0x0042, text_cmap_bytes_for_test([0x00, 0x43])),
  ])
  let font = @pdflite.pdf_dictionary([
    (
      text_cmap_name_for_test("/Subtype"),
      PdfNameObject(text_cmap_name_for_test("/Type0")),
    ),
    (
      text_cmap_name_for_test("/BaseFont"),
      PdfNameObject(text_cmap_name_for_test("/T")),
    ),
    (text_cmap_name_for_test("/DescendantFonts"), PdfArray([PdfIndirect(4)])),
    (text_cmap_name_for_test("/Encoding"), PdfIndirect(5)),
  ])
  let extractor = try! doc.text_extractor_of_font(font)
  @test.assert_eq(
    extractor.codepoints_of_text(
      text_cmap_bytes_for_test([0x00, 0x40, 0x00, 0x41, 0x00, 0x42]),
    ),
    [500, 99, 502],
  )
  @test.assert_eq(
    extractor.codepoints_of_text(
      text_cmap_bytes_for_test([0x00, 0x50, 0x00, 0x51, 0x00, 0x52]),
    ),
    [77, 701, 0x52],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(99), Some(0x0041))
  @test.assert_eq(extractor.charcode_of_codepoint(500), Some(0x0040))
  @test.assert_eq(extractor.charcode_of_codepoint(501), Some(0x01F5))
  @test.assert_eq(extractor.charcode_of_codepoint(77), Some(0x0050))
  @test.assert_eq(extractor.charcode_of_codepoint(701), Some(0x0051))
  @test.assert_eq(extractor.charcode_of_codepoint(0x51), None)
  @test.assert_eq(extractor.charcode_of_codepoint(0x52), Some(0x0052))
}

///|
test "PdfDocument ignores cyclic external CMap UseCMap stream bases" {
  let doc = @pdflite.pdf_document_empty()
  let cmap_data = @ascii.encode(
    "1 begincidchar\n" + "<41> 7\n" + "endcidchar\n",
  )
  doc.add_object_given_number(
    9,
    @pdflite.pdf_stream(
      @pdflite.pdf_dictionary([
        (text_cmap_name_for_test("/Length"), PdfInteger(cmap_data.length())),
        (text_cmap_name_for_test("/UseCMap"), PdfIndirect(9)),
      ]),
      StreamGot(cmap_data),
    ),
  )
  @test.assert_eq((try! doc.parse_cmap(PdfIndirect(9))).cid_map, [(0x41, 7)])
}

///|
test "PdfDocument ignores malformed external CMap UseCMap values" {
  let doc = @pdflite.pdf_document_empty()
  let cmap_data = @ascii.encode(
    "1 begincidchar\n" + "<41> 7\n" + "endcidchar\n",
  )
  doc.add_object_given_number(
    10,
    @pdflite.pdf_stream(
      @pdflite.pdf_dictionary([
        (text_cmap_name_for_test("/Length"), PdfInteger(cmap_data.length())),
        (text_cmap_name_for_test("/UseCMap"), PdfInteger(1)),
      ]),
      StreamGot(cmap_data),
    ),
  )
  @test.assert_eq((try! doc.parse_cmap(PdfIndirect(10))).cid_map, [(0x41, 7)])
}

///|
test "PdfDocument applies ToUnicode UseCMap stream composition" {
  let doc = @pdflite.pdf_document_empty()
  let base_data = @ascii.encode(
    "2 beginbfchar\n" + "<21><0041>\n" + "<22><0042>\n" + "endbfchar\n",
  )
  doc.add_object_given_number(
    11,
    @pdflite.pdf_stream(
      @pdflite.pdf_dictionary([
        (text_cmap_name_for_test("/Length"), PdfInteger(base_data.length())),
      ]),
      StreamGot(base_data),
    ),
  )
  let derived_data = @ascii.encode(
    "1 beginbfchar\n" + "<22><005A>\n" + "endbfchar\n",
  )
  doc.add_object_given_number(
    12,
    @pdflite.pdf_stream(
      @pdflite.pdf_dictionary([
        (text_cmap_name_for_test("/Length"), PdfInteger(derived_data.length())),
        (text_cmap_name_for_test("/UseCMap"), PdfIndirect(11)),
      ]),
      StreamGot(derived_data),
    ),
  )
  let font = @pdflite.pdf_dictionary([
    (
      text_cmap_name_for_test("/Subtype"),
      PdfNameObject(text_cmap_name_for_test("/Type1")),
    ),
    (
      text_cmap_name_for_test("/BaseFont"),
      PdfNameObject(text_cmap_name_for_test("/Custom")),
    ),
    (text_cmap_name_for_test("/ToUnicode"), PdfIndirect(12)),
  ])
  guard (try! doc.read_font(font)) is PdfFontSimple(read) else {
    fail("expected simple font")
  }
  guard read.fontdescriptor is Some(read_descriptor) else {
    fail("expected descriptor carrying ToUnicode")
  }
  @test.assert_eq(
    read_descriptor.tounicode,
    Some([
      (0x22, text_cmap_bytes_for_test([0x00, 0x5A])),
      (0x21, text_cmap_bytes_for_test([0x00, 0x41])),
    ]),
  )
  let extractor = try! doc.text_extractor_of_font(font)
  @test.assert_eq(
    extractor.codepoints_of_text(text_cmap_bytes_for_test([0x21, 0x22, 0x23])),
    [0x41, 0x5A, 0x23],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x41), Some(0x21))
  @test.assert_eq(extractor.charcode_of_codepoint(0x5A), Some(0x22))
  @test.assert_eq(extractor.charcode_of_codepoint(0x42), None)
}

///|
test "PdfDocument composes multi-hop ToUnicode UseCMap stream bases" {
  let doc = @pdflite.pdf_document_empty()
  let base_data = @ascii.encode(
    "1 beginbfchar\n" + "<21><0041>\n" + "endbfchar\n",
  )
  doc.add_object_given_number(
    31,
    @pdflite.pdf_stream(
      @pdflite.pdf_dictionary([
        (text_cmap_name_for_test("/Length"), PdfInteger(base_data.length())),
      ]),
      StreamGot(base_data),
    ),
  )
  let middle_data = @ascii.encode(
    "1 beginbfchar\n" + "<22><0042>\n" + "endbfchar\n",
  )
  doc.add_object_given_number(
    32,
    @pdflite.pdf_stream(
      @pdflite.pdf_dictionary([
        (text_cmap_name_for_test("/Length"), PdfInteger(middle_data.length())),
        (text_cmap_name_for_test("/UseCMap"), PdfIndirect(31)),
      ]),
      StreamGot(middle_data),
    ),
  )
  let derived_data = @ascii.encode(
    "1 beginbfchar\n" + "<23><0043>\n" + "endbfchar\n",
  )
  doc.add_object_given_number(
    33,
    @pdflite.pdf_stream(
      @pdflite.pdf_dictionary([
        (text_cmap_name_for_test("/Length"), PdfInteger(derived_data.length())),
        (text_cmap_name_for_test("/UseCMap"), PdfIndirect(32)),
      ]),
      StreamGot(derived_data),
    ),
  )
  @test.assert_eq((try! doc.parse_cmap(PdfIndirect(33))).map, [
    (0x23, text_cmap_bytes_for_test([0x00, 0x43])),
    (0x22, text_cmap_bytes_for_test([0x00, 0x42])),
    (0x21, text_cmap_bytes_for_test([0x00, 0x41])),
  ])
}

///|
test "PdfDocument reads bfchar and sequential bfrange ToUnicode CMaps" {
  let doc = @pdflite.pdf_document_empty()
  let tounicode = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([]),
    StreamGot(
      @ascii.encode(
        "1 begincodespacerange\n" +
        "<00><FF>\n" +
        "endcodespacerange\n" +
        "2 beginbfchar\n" +
        "<21><0041>\n" +
        "<25><20AC>\n" +
        "endbfchar\n" +
        "1 beginbfrange\n" +
        "<22><24><0042>\n" +
        "<26><27>[<0058><0059>]\n" +
        "endbfrange\n" +
        "2 beginbfchar <28><005A> <2B><0063> endbfchar\n" +
        "1 beginbfrange <29><2A>[<0061><0062>] endbfrange\n" +
        "2 beginbfrange <2C><2D><0064> <2E><2F><0066> endbfrange\n" +
        "1 beginbfchar <30><0068> endbfchar 1 beginbfrange <31><32><0069> endbfrange\n" +
        "1 beginbfrange\n" +
        "<51><53><00FE>\n" +
        "endbfrange\n",
      ),
    ),
  )
  doc.add_object_given_number(2, tounicode)
  let font = @pdflite.pdf_dictionary([
    (
      text_cmap_name_for_test("/Subtype"),
      PdfNameObject(text_cmap_name_for_test("/Type1")),
    ),
    (
      text_cmap_name_for_test("/BaseFont"),
      PdfNameObject(text_cmap_name_for_test("/Custom")),
    ),
    (text_cmap_name_for_test("/ToUnicode"), PdfIndirect(2)),
  ])
  guard (try! doc.read_font(font)) is PdfFontSimple(read) else {
    fail("expected simple font")
  }
  guard read.fontdescriptor is Some(read_descriptor) else {
    fail("expected descriptor carrying ToUnicode")
  }
  @test.assert_eq(
    read_descriptor.tounicode,
    Some([
      (33, text_cmap_bytes_for_test([0x00, 0x41])),
      (37, text_cmap_bytes_for_test([0x20, 0xAC])),
      (34, text_cmap_bytes_for_test([0x00, 0x42])),
      (35, text_cmap_bytes_for_test([0x00, 0x43])),
      (36, text_cmap_bytes_for_test([0x00, 0x44])),
      (38, text_cmap_bytes_for_test([0x00, 0x58])),
      (39, text_cmap_bytes_for_test([0x00, 0x59])),
      (40, text_cmap_bytes_for_test([0x00, 0x5A])),
      (43, text_cmap_bytes_for_test([0x00, 0x63])),
      (41, text_cmap_bytes_for_test([0x00, 0x61])),
      (42, text_cmap_bytes_for_test([0x00, 0x62])),
      (44, text_cmap_bytes_for_test([0x00, 0x64])),
      (45, text_cmap_bytes_for_test([0x00, 0x65])),
      (46, text_cmap_bytes_for_test([0x00, 0x66])),
      (47, text_cmap_bytes_for_test([0x00, 0x67])),
      (48, text_cmap_bytes_for_test([0x00, 0x68])),
      (49, text_cmap_bytes_for_test([0x00, 0x69])),
      (50, text_cmap_bytes_for_test([0x00, 0x6A])),
      (81, text_cmap_bytes_for_test([0x00, 0xFE])),
      (82, text_cmap_bytes_for_test([0x00, 0xFF])),
      (83, text_cmap_bytes_for_test([0x01, 0x00])),
    ]),
  )
  let extractor = try! doc.text_extractor_of_font(font)
  @test.assert_eq(
    try! extractor.codepoints_of_text(
      text_cmap_bytes_for_test([
        33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 81,
        82, 83, 51,
      ]),
    ),
    [
      0x41, 0x42, 0x43, 0x44, 0x20AC, 0x58, 0x59, 0x5A, 0x61, 0x62, 0x63, 0x64, 0x65,
      0x66, 0x67, 0x68, 0x69, 0x6A, 0xFE, 0xFF, 0x0100, 51,
    ],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x20AC), Some(37))
  @test.assert_eq(extractor.charcode_of_codepoint(0x59), Some(39))
  @test.assert_eq(extractor.charcode_of_codepoint(0x5A), Some(40))
  @test.assert_eq(extractor.charcode_of_codepoint(0x62), Some(42))
  @test.assert_eq(extractor.charcode_of_codepoint(0x63), Some(43))
  @test.assert_eq(extractor.charcode_of_codepoint(0x64), Some(44))
  @test.assert_eq(extractor.charcode_of_codepoint(0x67), Some(47))
  @test.assert_eq(extractor.charcode_of_codepoint(0x68), Some(48))
  @test.assert_eq(extractor.charcode_of_codepoint(0x69), Some(49))
  @test.assert_eq(extractor.charcode_of_codepoint(0x6A), Some(50))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0100), Some(83))
  @test.assert_eq(extractor.charcode_of_codepoint(0x45), None)
}

///|
test "PdfDocument reads split bfchar ToUnicode CMaps" {
  let doc = @pdflite.pdf_document_empty()
  let tounicode = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([]),
    StreamGot(
      @ascii.encode(
        "3 beginbfchar\n" +
        "<41>\n" +
        "<0041>\n" +
        "<42><0042><43>\n" +
        "<0043> endbfchar\n",
      ),
    ),
  )
  doc.add_object_given_number(2, tounicode)
  let font = @pdflite.pdf_dictionary([
    (
      text_cmap_name_for_test("/Subtype"),
      PdfNameObject(text_cmap_name_for_test("/Type1")),
    ),
    (
      text_cmap_name_for_test("/BaseFont"),
      PdfNameObject(text_cmap_name_for_test("/Custom")),
    ),
    (text_cmap_name_for_test("/ToUnicode"), PdfIndirect(2)),
  ])
  guard (try! doc.read_font(font)) is PdfFontSimple(read) else {
    fail("expected simple font")
  }
  guard read.fontdescriptor is Some(read_descriptor) else {
    fail("expected descriptor carrying ToUnicode")
  }
  @test.assert_eq(
    read_descriptor.tounicode,
    Some([
      (65, text_cmap_bytes_for_test([0x00, 0x41])),
      (66, text_cmap_bytes_for_test([0x00, 0x42])),
      (67, text_cmap_bytes_for_test([0x00, 0x43])),
    ]),
  )
  let extractor = try! doc.text_extractor_of_font(font)
  @test.assert_eq(
    try! extractor.codepoints_of_text(
      text_cmap_bytes_for_test([65, 66, 67, 68]),
    ),
    [0x41, 0x42, 0x43, 68],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x43), Some(67))
}

///|
test "PdfDocument reads multiline bfrange array ToUnicode CMaps" {
  let doc = @pdflite.pdf_document_empty()
  let tounicode = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([]),
    StreamGot(
      @ascii.encode(
        "3 beginbfrange\n" +
        "<30><32> [\n" +
        "<0061>\n" +
        "<0062>\n" +
        "<0063>\n" +
        "]\n" +
        "<33><35> [<0064>\n" +
        "<0065>\n" +
        "<0066>]\n" +
        "<36><38>\n" +
        "[\n" +
        "<0067><0068>\n" +
        "<0069>\n" +
        "] endbfrange 1 beginbfchar <39><006A> endbfchar\n",
      ),
    ),
  )
  doc.add_object_given_number(2, tounicode)
  let font = @pdflite.pdf_dictionary([
    (
      text_cmap_name_for_test("/Subtype"),
      PdfNameObject(text_cmap_name_for_test("/Type1")),
    ),
    (
      text_cmap_name_for_test("/BaseFont"),
      PdfNameObject(text_cmap_name_for_test("/Custom")),
    ),
    (text_cmap_name_for_test("/ToUnicode"), PdfIndirect(2)),
  ])
  guard (try! doc.read_font(font)) is PdfFontSimple(read) else {
    fail("expected simple font")
  }
  guard read.fontdescriptor is Some(read_descriptor) else {
    fail("expected descriptor carrying ToUnicode")
  }
  @test.assert_eq(
    read_descriptor.tounicode,
    Some([
      (48, text_cmap_bytes_for_test([0x00, 0x61])),
      (49, text_cmap_bytes_for_test([0x00, 0x62])),
      (50, text_cmap_bytes_for_test([0x00, 0x63])),
      (51, text_cmap_bytes_for_test([0x00, 0x64])),
      (52, text_cmap_bytes_for_test([0x00, 0x65])),
      (53, text_cmap_bytes_for_test([0x00, 0x66])),
      (54, text_cmap_bytes_for_test([0x00, 0x67])),
      (55, text_cmap_bytes_for_test([0x00, 0x68])),
      (56, text_cmap_bytes_for_test([0x00, 0x69])),
      (57, text_cmap_bytes_for_test([0x00, 0x6A])),
    ]),
  )
  let extractor = try! doc.text_extractor_of_font(font)
  @test.assert_eq(
    try! extractor.codepoints_of_text(
      text_cmap_bytes_for_test([48, 49, 50, 51, 52, 53, 54, 55, 56, 57]),
    ),
    [0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6A],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x61), Some(48))
  @test.assert_eq(extractor.charcode_of_codepoint(0x69), Some(56))
  @test.assert_eq(extractor.charcode_of_codepoint(0x6A), Some(57))
}

///|
test "pdf_parse_cmap_data keeps bfrange entries after multiline array close" {
  let parsed = @pdflite.pdf_parse_cmap_data(
    @ascii.encode(
      "4 beginbfrange\n" +
      "<30><31> [\n" +
      "<0061>\n" +
      "<0062>] <32><33><0063>\n" +
      "<34><35> [<0065><0066>] <36><37>[<0067><0068>]\n" +
      "endbfrange\n",
    ),
  )
  @test.assert_eq(parsed.map, [
    (48, text_cmap_bytes_for_test([0x00, 0x61])),
    (49, text_cmap_bytes_for_test([0x00, 0x62])),
    (50, text_cmap_bytes_for_test([0x00, 0x63])),
    (51, text_cmap_bytes_for_test([0x00, 0x64])),
    (52, text_cmap_bytes_for_test([0x00, 0x65])),
    (53, text_cmap_bytes_for_test([0x00, 0x66])),
    (54, text_cmap_bytes_for_test([0x00, 0x67])),
    (55, text_cmap_bytes_for_test([0x00, 0x68])),
  ])
}

///|
test "pdf_parse_cmap_data keeps bfrange entries before multiline array" {
  let parsed = @pdflite.pdf_parse_cmap_data(
    @ascii.encode(
      "3 beginbfrange\n" +
      "<30><31><0061> <32><33>[\n" +
      "<0063>\n" +
      "<0064>]\n" +
      "<34><35><0065>\n" +
      "endbfrange\n",
    ),
  )
  @test.assert_eq(parsed.map, [
    (48, text_cmap_bytes_for_test([0x00, 0x61])),
    (49, text_cmap_bytes_for_test([0x00, 0x62])),
    (50, text_cmap_bytes_for_test([0x00, 0x63])),
    (51, text_cmap_bytes_for_test([0x00, 0x64])),
    (52, text_cmap_bytes_for_test([0x00, 0x65])),
    (53, text_cmap_bytes_for_test([0x00, 0x66])),
  ])
}

///|
test "PdfDocument reads repeated inline bfrange arrays" {
  let doc = @pdflite.pdf_document_empty()
  let tounicode = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([]),
    StreamGot(
      @ascii.encode(
        "2 beginbfrange <40><41>[<0061><0062>] <42><43>[<0063><0064>] endbfrange\n" +
        "3 beginbfrange <44><45><0065> <46><47>[<0067><0068>] <48><49><0069> endbfrange\n",
      ),
    ),
  )
  doc.add_object_given_number(2, tounicode)
  let font = @pdflite.pdf_dictionary([
    (
      text_cmap_name_for_test("/Subtype"),
      PdfNameObject(text_cmap_name_for_test("/Type1")),
    ),
    (
      text_cmap_name_for_test("/BaseFont"),
      PdfNameObject(text_cmap_name_for_test("/Custom")),
    ),
    (text_cmap_name_for_test("/ToUnicode"), PdfIndirect(2)),
  ])
  guard (try! doc.read_font(font)) is PdfFontSimple(read) else {
    fail("expected simple font")
  }
  guard read.fontdescriptor is Some(read_descriptor) else {
    fail("expected descriptor carrying ToUnicode")
  }
  @test.assert_eq(
    read_descriptor.tounicode,
    Some([
      (64, text_cmap_bytes_for_test([0x00, 0x61])),
      (65, text_cmap_bytes_for_test([0x00, 0x62])),
      (66, text_cmap_bytes_for_test([0x00, 0x63])),
      (67, text_cmap_bytes_for_test([0x00, 0x64])),
      (68, text_cmap_bytes_for_test([0x00, 0x65])),
      (69, text_cmap_bytes_for_test([0x00, 0x66])),
      (70, text_cmap_bytes_for_test([0x00, 0x67])),
      (71, text_cmap_bytes_for_test([0x00, 0x68])),
      (72, text_cmap_bytes_for_test([0x00, 0x69])),
      (73, text_cmap_bytes_for_test([0x00, 0x6A])),
    ]),
  )
  let extractor = try! doc.text_extractor_of_font(font)
  @test.assert_eq(
    try! extractor.codepoints_of_text(
      text_cmap_bytes_for_test([64, 65, 66, 67, 68, 69, 70, 71, 72, 73]),
    ),
    [0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6A],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x61), Some(64))
  @test.assert_eq(extractor.charcode_of_codepoint(0x66), Some(69))
  @test.assert_eq(extractor.charcode_of_codepoint(0x6A), Some(73))
}

///|
test "PdfDocument reads ToUnicode hex strings with whitespace and odd nibbles" {
  let doc = @pdflite.pdf_document_empty()
  let tounicode = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([]),
    StreamGot(
      @ascii.encode(
        "3 beginbfchar\n" +
        "<41><00 5A>\n" +
        "<4><006>\n" +
        "<43><D834 DD1E>\n" +
        "endbfchar\n",
      ),
    ),
  )
  doc.add_object_given_number(2, tounicode)
  let font = @pdflite.pdf_dictionary([
    (
      text_cmap_name_for_test("/Subtype"),
      PdfNameObject(text_cmap_name_for_test("/Type1")),
    ),
    (
      text_cmap_name_for_test("/BaseFont"),
      PdfNameObject(text_cmap_name_for_test("/Custom")),
    ),
    (text_cmap_name_for_test("/ToUnicode"), PdfIndirect(2)),
  ])
  guard (try! doc.read_font(font)) is PdfFontSimple(read) else {
    fail("expected simple font")
  }
  guard read.fontdescriptor is Some(read_descriptor) else {
    fail("expected descriptor carrying ToUnicode")
  }
  @test.assert_eq(
    read_descriptor.tounicode,
    Some([
      (65, text_cmap_bytes_for_test([0x00, 0x5A])),
      (0x40, text_cmap_bytes_for_test([0x00, 0x60])),
      (67, text_cmap_bytes_for_test([0xD8, 0x34, 0xDD, 0x1E])),
    ]),
  )
  let extractor = try! doc.text_extractor_of_font(font)
  @test.assert_eq(
    try! extractor.codepoints_of_text(
      text_cmap_bytes_for_test([65, 0x40, 67, 68]),
    ),
    [0x5A, 0x60, 0x1D11E, 68],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x1D11E), Some(67))
}

///|
test "PdfDocument reads ToUnicode CMaps with PDF whitespace separators" {
  let doc = @pdflite.pdf_document_empty()
  let cmap = text_cmap_concat_for_test([
    @ascii.encode("2 beginbfchar"),
    text_cmap_bytes_for_test([12]),
    @ascii.encode("<41>"),
    text_cmap_bytes_for_test([0]),
    @ascii.encode("<0041>"),
    text_cmap_bytes_for_test([12]),
    @ascii.encode("<42>"),
    text_cmap_bytes_for_test([0]),
    @ascii.encode("<0042> endbfchar\n1 beginbfrange"),
    text_cmap_bytes_for_test([12]),
    @ascii.encode("<43>"),
    text_cmap_bytes_for_test([0]),
    @ascii.encode("<44>"),
    text_cmap_bytes_for_test([12]),
    @ascii.encode("<0043> endbfrange\n"),
  ])
  let tounicode = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([]),
    StreamGot(cmap),
  )
  doc.add_object_given_number(2, tounicode)
  let font = @pdflite.pdf_dictionary([
    (
      text_cmap_name_for_test("/Subtype"),
      PdfNameObject(text_cmap_name_for_test("/Type1")),
    ),
    (
      text_cmap_name_for_test("/BaseFont"),
      PdfNameObject(text_cmap_name_for_test("/Custom")),
    ),
    (text_cmap_name_for_test("/ToUnicode"), PdfIndirect(2)),
  ])
  guard (try! doc.read_font(font)) is PdfFontSimple(read) else {
    fail("expected simple font")
  }
  guard read.fontdescriptor is Some(read_descriptor) else {
    fail("expected descriptor carrying ToUnicode")
  }
  @test.assert_eq(
    read_descriptor.tounicode,
    Some([
      (65, text_cmap_bytes_for_test([0x00, 0x41])),
      (66, text_cmap_bytes_for_test([0x00, 0x42])),
      (67, text_cmap_bytes_for_test([0x00, 0x43])),
      (68, text_cmap_bytes_for_test([0x00, 0x44])),
    ]),
  )
  let extractor = try! doc.text_extractor_of_font(font)
  @test.assert_eq(
    try! extractor.codepoints_of_text(
      text_cmap_bytes_for_test([65, 66, 67, 68, 69]),
    ),
    [0x41, 0x42, 0x43, 0x44, 69],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x44), Some(68))
}

///|
test "pdf_parse_cmap_data reads whitespace-split CMap markers" {
  let cmap = text_cmap_concat_for_test([
    @ascii.encode("/WMode 1 def\n1 begin"),
    text_cmap_bytes_for_test([9, 10]),
    @ascii.encode("bfchar<41><0041>end"),
    text_cmap_bytes_for_test([12]),
    @ascii.encode("bfchar\n1 begin"),
    text_cmap_bytes_for_test([0, 13, 10]),
    @ascii.encode("bfrange<42><43><0042>end"),
    text_cmap_bytes_for_test([32]),
    @ascii.encode("bfrange\n"),
  ])
  let parsed = @pdflite.pdf_parse_cmap_data(cmap)
  @test.assert_eq(parsed.wmode, Some(1))
  @test.assert_eq(parsed.map, [
    (65, text_cmap_bytes_for_test([0x00, 0x41])),
    (66, text_cmap_bytes_for_test([0x00, 0x42])),
    (67, text_cmap_bytes_for_test([0x00, 0x43])),
  ])
}

///|
test "pdf_parse_cmap_data augments partial CMap marker parsing" {
  let cmap = text_cmap_concat_for_test([
    @ascii.encode("1 beginbfchar\n<40><0040>\nendbfchar\n1 begin"),
    text_cmap_bytes_for_test([10]),
    @ascii.encode("bfchar<41><0041>end"),
    text_cmap_bytes_for_test([10]),
    @ascii.encode("bfchar\n"),
  ])
  @test.assert_eq(@pdflite.pdf_parse_cmap_data(cmap).map, [
    (64, text_cmap_bytes_for_test([0x00, 0x40])),
    (65, text_cmap_bytes_for_test([0x00, 0x41])),
  ])
}

///|
test "pdf_parse_cmap_data ignores PDF comments in CMap programs" {
  let parsed = @pdflite.pdf_parse_cmap_data(
    @ascii.encode(
      "% /Identity-H usecmap\n" +
      "/Identity-V usecmap % /Identity-H usecmap\n" +
      "/WMode 1 def % /WMode 0 def\n" +
      "/CMapName /Real-CMap def % /CMapName /Fake-CMap def\n" +
      "/CMapType 2 def % /CMapType 1 def\n" +
      "/CIDSystemInfo << /Registry (Ad%obe) /Ordering (UCS) /Supplement 0 >> def % /Ordering (Fake)\n" +
      "1 begincodespacerange\n" +
      "<00><7F> % <8100><81FF>\n" +
      "endcodespacerange\n" +
      "1 beginbfchar\n" +
      "<41><0041> % <42><0042> endbfchar\n" +
      "<42><0042>\n" +
      "endbfchar\n" +
      "1 beginbfrange\n" +
      "<43><44>[<0043> % <9999> ] endbfrange\n" +
      "<0044>] % endbfrange\n" +
      "endbfrange\n" +
      "1 begincidchar\n" +
      "<45> 100 % <46> 900 endcidchar\n" +
      "<46> 101\n" +
      "endcidchar\n" +
      "1 beginnotdefrange\n" +
      "<47><48> 200 % <49><4A> 300\n" +
      "endnotdefrange\n",
    ),
  )
  @test.assert_eq(parsed.usecmap, Some(text_cmap_name_for_test("/Identity-V")))
  @test.assert_eq(parsed.wmode, Some(1))
  @test.assert_eq(parsed.cmap_name, Some(text_cmap_name_for_test("/Real-CMap")))
  @test.assert_eq(parsed.cmap_type, Some(2))
  @test.assert_eq(
    parsed.cid_system_info,
    Some({
      registry: @ascii.encode("Ad%obe"),
      ordering: @ascii.encode("UCS"),
      supplement: 0,
    }),
  )
  @test.assert_eq(parsed.codespaces, [{ length: 1, first: 0x00, last: 0x7F }])
  @test.assert_eq(parsed.map, [
    (0x41, text_cmap_bytes_for_test([0x00, 0x41])),
    (0x42, text_cmap_bytes_for_test([0x00, 0x42])),
    (0x43, text_cmap_bytes_for_test([0x00, 0x43])),
    (0x44, text_cmap_bytes_for_test([0x00, 0x44])),
  ])
  @test.assert_eq(parsed.cid_map, [(0x45, 100), (0x46, 101)])
  @test.assert_eq(parsed.notdef_map, [(0x47, 200), (0x48, 201)])
  let escaped_literal = @pdflite.pdf_parse_cmap_data(
    @ascii.encode(
      "/CIDSystemInfo << /Registry (Ad\\%o(be)) /Ordering (UCS) /Supplement 1 >> def % /Supplement 9\n",
    ),
  )
  @test.assert_eq(
    escaped_literal.cid_system_info,
    Some({
      registry: @ascii.encode("Ad%o(be)"),
      ordering: @ascii.encode("UCS"),
      supplement: 1,
    }),
  )
}

///|
test "PdfDocument decodes filtered ToUnicode CMap streams" {
  let doc = @pdflite.pdf_document_empty()
  let cmap = @ascii.encode("1 beginbfchar\n<41><005A>\nendbfchar\n")
  let encoded = @pdflite.pdf_ascii_hex_encode(cmap)
  let tounicode = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (text_cmap_name_for_test("/Length"), PdfInteger(encoded.length())),
      (
        text_cmap_name_for_test("/Filter"),
        PdfNameObject(text_cmap_name_for_test("/ASCIIHexDecode")),
      ),
    ]),
    StreamGot(encoded),
  )
  doc.add_object_given_number(2, tounicode)
  let font = @pdflite.pdf_dictionary([
    (
      text_cmap_name_for_test("/Subtype"),
      PdfNameObject(text_cmap_name_for_test("/Type1")),
    ),
    (
      text_cmap_name_for_test("/BaseFont"),
      PdfNameObject(text_cmap_name_for_test("/Custom")),
    ),
    (text_cmap_name_for_test("/ToUnicode"), PdfIndirect(2)),
  ])
  let extractor = try! doc.text_extractor_of_font(font)
  @test.assert_eq(
    try! extractor.codepoints_of_text(text_cmap_bytes_for_test([65, 66])),
    [0x5A, 66],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x5A), Some(65))
  doc.add_object_given_number(
    8,
    PdfNameObject(text_cmap_name_for_test("/ASCIIHexDecode")),
  )
  let tounicode = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (text_cmap_name_for_test("/Length"), PdfInteger(encoded.length())),
      (text_cmap_name_for_test("/Filter"), PdfIndirect(8)),
    ]),
    StreamGot(encoded),
  )
  doc.add_object_given_number(9, tounicode)
  let font = @pdflite.pdf_dictionary([
    (
      text_cmap_name_for_test("/Subtype"),
      PdfNameObject(text_cmap_name_for_test("/Type1")),
    ),
    (
      text_cmap_name_for_test("/BaseFont"),
      PdfNameObject(text_cmap_name_for_test("/Custom")),
    ),
    (text_cmap_name_for_test("/ToUnicode"), PdfIndirect(9)),
  ])
  let extractor = try! doc.text_extractor_of_font(font)
  @test.assert_eq(
    try! extractor.codepoints_of_text(text_cmap_bytes_for_test([65, 66])),
    [0x5A, 66],
  )
}

///|
test "PdfTextExtractor reads identity CMap text as two-byte character codes" {
  let composite : @pdflite.PdfCompositeCIDFont = {
    cid_system_info: {
      registry: text_cmap_bytes_for_test([65]),
      ordering: text_cmap_bytes_for_test([73]),
      supplement: 0,
    },
    cid_basefont: text_cmap_name_for_test("/Descendant"),
    cid_fontdescriptor: text_cmap_font_descriptor_for_test(),
    cid_widths: [],
    cid_widths2: [],
    cid_default_width: 1000.0,
    cid_default_width2: [880.0, -1000.0],
  }
  let cid_font_h : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_name_for_test("/Top"),
    composite,
    encoding: PdfPredefinedCMap(text_cmap_name_for_test("/Identity-H")),
  })
  let extractor = cid_font_h.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(
      text_cmap_bytes_for_test([0x00, 0x41, 0x20, 0xAC]),
    ),
    [0x41, 0x20AC],
  )
  @test.assert_eq(
    try! extractor.glyphnames_of_text(text_cmap_bytes_for_test([0x00, 0x41])),
    [text_cmap_name_for_test(".notdef")],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x41), None)
  @test.assert_eq(extractor.charcode_of_codepoint(0xF6E6), None)
  let odd = try? extractor.codepoints_of_text(text_cmap_bytes_for_test([0x00]))
  guard odd is Err(BadText) else { fail("expected @pdflite.PdfError::BadText") }
  let cid_font_v_data : @pdflite.PdfCIDKeyedFont = {
    basefont: text_cmap_name_for_test("/TopVertical"),
    composite,
    encoding: PdfPredefinedCMap(text_cmap_name_for_test("/Identity-V")),
  }
  @test.assert_eq(cid_font_v_data.is_identity_v(), true)
  @test.assert_eq(cid_font_v_data.uses_two_byte_codes(), true)
  let cid_font_v : @pdflite.PdfFont = PdfFontCIDKeyed(cid_font_v_data)
  @test.assert_eq(cid_font_v.is_identity_h(), false)
  @test.assert_eq(cid_font_v.is_identity_v(), true)
  @test.assert_eq(cid_font_v.uses_two_byte_codes(), true)
  let vertical_extractor = cid_font_v.text_extractor()
  @test.assert_eq(
    try! vertical_extractor.codepoints_of_text(
      text_cmap_bytes_for_test([0x00, 0x42, 0x4E, 0x00]),
    ),
    [0x42, 0x4E00],
  )
  @test.assert_eq(
    try! vertical_extractor.glyphnames_of_text(
      text_cmap_bytes_for_test([0x4E, 0x00]),
    ),
    [text_cmap_name_for_test(".notdef")],
  )
  let vertical_odd = try? vertical_extractor.codepoints_of_text(
    text_cmap_bytes_for_test([0x4E]),
  )
  guard vertical_odd is Err(BadText) else {
    fail("expected @pdflite.PdfError::BadText")
  }
  let ucs2_cmap_font_h : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_name_for_test("/TopUCS2"),
    composite,
    encoding: PdfPredefinedCMap(text_cmap_name_for_test("/UniJIS-UCS2-H")),
  })
  @test.assert_eq(ucs2_cmap_font_h.is_identity_h(), false)
  @test.assert_eq(ucs2_cmap_font_h.is_identity_v(), false)
  @test.assert_eq(ucs2_cmap_font_h.uses_two_byte_codes(), true)
  let ucs2_h_extractor = ucs2_cmap_font_h.text_extractor()
  @test.assert_eq(
    try! ucs2_h_extractor.codepoints_of_text(
      text_cmap_bytes_for_test([0x00, 0x41, 0x4E, 0x00]),
    ),
    [0x41, 0x4E00],
  )
  @test.assert_eq(ucs2_h_extractor.charcode_of_codepoint(0x4E00), Some(0x4E00))
  let ucs2_odd = try? ucs2_h_extractor.codepoints_of_text(
    text_cmap_bytes_for_test([0x00, 0x41, 0x4E]),
  )
  guard ucs2_odd is Err(_) else { fail("expected malformed UCS2 text error") }
  let ucs2_cmap_font_v : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_name_for_test("/TopUCS2Vertical"),
    composite,
    encoding: PdfPredefinedCMap(text_cmap_name_for_test("/UniCNS-UCS2-V")),
  })
  @test.assert_eq(ucs2_cmap_font_v.uses_two_byte_codes(), true)
  @test.assert_eq(
    try! ucs2_cmap_font_v
    .text_extractor()
    .codepoints_of_text(text_cmap_bytes_for_test([0x00, 0x42, 0x4E, 0x8C])),
    [0x42, 0x4E8C],
  )
  let utf16_cmap_font_h : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_name_for_test("/TopUTF16"),
    composite,
    encoding: PdfPredefinedCMap(text_cmap_name_for_test("/UniJIS-UTF16-H")),
  })
  @test.assert_eq(utf16_cmap_font_h.uses_two_byte_codes(), true)
  @test.assert_eq(
    utf16_cmap_font_h
    .text_extractor()
    .codepoints_of_text(text_cmap_bytes_for_test([0x30, 0x42, 0x30, 0xA2])),
    [0x3042, 0x30A2],
  )
  @test.assert_eq(
    utf16_cmap_font_h
    .text_extractor()
    .codepoints_of_text(text_cmap_bytes_for_test([0xD8, 0x34, 0xDD, 0x1E])),
    [0x1D11E],
  )
  @test.assert_eq(
    utf16_cmap_font_h.text_extractor().charcode_of_codepoint(0x3042),
    Some(0x3042),
  )
  @test.assert_eq(
    utf16_cmap_font_h.text_extractor().charcode_of_codepoint(0x1D11E),
    Some(0xD834DD1E),
  )
  let utf16_unpaired = try? utf16_cmap_font_h
    .text_extractor()
    .codepoints_of_text(text_cmap_bytes_for_test([0xD8, 0x34, 0x30, 0x42]))
  guard utf16_unpaired is Err(_) else {
    fail("expected malformed UTF16 predefined CMap text error")
  }
  let utf16_cmap_font_v : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_name_for_test("/TopUTF16Vertical"),
    composite,
    encoding: PdfPredefinedCMap(text_cmap_name_for_test("/UniCNS-UTF16-V")),
  })
  @test.assert_eq(utf16_cmap_font_v.uses_two_byte_codes(), true)
  @test.assert_eq(
    utf16_cmap_font_v
    .text_extractor()
    .codepoints_of_text(text_cmap_bytes_for_test([0x4E, 0x00, 0x4E, 0x8C])),
    [0x4E00, 0x4E8C],
  )
  let utf8_cmap_font_h : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_name_for_test("/TopUTF8"),
    composite,
    encoding: PdfPredefinedCMap(text_cmap_name_for_test("/UniJIS-UTF8-H")),
  })
  @test.assert_eq(utf8_cmap_font_h.uses_two_byte_codes(), false)
  @test.assert_eq(
    utf8_cmap_font_h
    .text_extractor()
    .codepoints_of_text(
      text_cmap_bytes_for_test([0x41, 0xE3, 0x81, 0x82, 0xF0, 0x9D, 0x84, 0x9E]),
    ),
    [0x41, 0x3042, 0x1D11E],
  )
  @test.assert_eq(
    utf8_cmap_font_h.text_extractor().charcode_of_codepoint(0x3042),
    Some(0xE38182),
  )
  @test.assert_eq(
    utf8_cmap_font_h.text_extractor().charcode_of_codepoint(0x1D11E),
    Some(0xF09D849E),
  )
  let utf8_bad = try? utf8_cmap_font_h
    .text_extractor()
    .codepoints_of_text(text_cmap_bytes_for_test([0xE3, 0x81]))
  guard utf8_bad is Err(_) else {
    fail("expected malformed UTF8 predefined CMap text error")
  }
  let utf8_tounicode_descriptor : @pdflite.PdfFontDescriptor = {
    ..text_cmap_font_descriptor_for_test(),
    tounicode: Some([
      (0xE38182, text_cmap_bytes_for_test([0x26, 0x03])),
      (0xF09D849E, text_cmap_bytes_for_test([0x03, 0xA9])),
    ]),
  }
  let utf8_tounicode_font : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_name_for_test("/TopUTF8ToUnicode"),
    composite: { ..composite, cid_fontdescriptor: utf8_tounicode_descriptor },
    encoding: PdfPredefinedCMap(text_cmap_name_for_test("/UniJIS-UTF8-H")),
  })
  let utf8_tounicode_extractor = utf8_tounicode_font.text_extractor()
  @test.assert_eq(
    utf8_tounicode_extractor.codepoints_of_text(
      text_cmap_bytes_for_test([0xE3, 0x81, 0x82, 0xF0, 0x9D, 0x84, 0x9E]),
    ),
    [0x2603, 0x03A9],
  )
  @test.assert_eq(
    utf8_tounicode_extractor.charcode_of_codepoint(0x2603),
    Some(0xE38182),
  )
  @test.assert_eq(
    utf8_tounicode_extractor.charcode_of_codepoint(0x03A9),
    Some(0xF09D849E),
  )
  let utf32_cmap_font_v : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_name_for_test("/TopUTF32Vertical"),
    composite,
    encoding: PdfPredefinedCMap(text_cmap_name_for_test("/UniCNS-UTF32-V")),
  })
  @test.assert_eq(utf32_cmap_font_v.uses_two_byte_codes(), false)
  @test.assert_eq(
    utf32_cmap_font_v
    .text_extractor()
    .codepoints_of_text(
      text_cmap_bytes_for_test([0x00, 0x00, 0x00, 0x41, 0x00, 0x01, 0xD1, 0x1E]),
    ),
    [0x41, 0x1D11E],
  )
  @test.assert_eq(
    utf32_cmap_font_v.text_extractor().charcode_of_codepoint(0x1D11E),
    Some(0x1D11E),
  )
  let utf32_bad = try? utf32_cmap_font_v
    .text_extractor()
    .codepoints_of_text(text_cmap_bytes_for_test([0x00, 0x00, 0xD8, 0x00]))
  guard utf32_bad is Err(_) else {
    fail("expected malformed UTF32 predefined CMap text error")
  }
  let direct_unicode_predefined_cases : Array[
    (String, Array[Int], Array[Int], Int, Int),
  ] = [
    (
      "/UniAKR-UTF8-H",
      [0x41, 0xEA, 0xB0, 0x80],
      [0x41, 0xAC00],
      0xAC00,
      0xEAB080,
    ),
    ("/UniAKR-UTF16-H", [0xAC, 0x00], [0xAC00], 0xAC00, 0xAC00),
    ("/UniAKR-UTF32-H", [0x00, 0x00, 0xAC, 0x00], [0xAC00], 0xAC00, 0xAC00),
    ("/UniGB-UTF16-H", [0x4E, 0x00], [0x4E00], 0x4E00, 0x4E00),
    ("/UniGB-UTF16-V", [0x56, 0xFD], [0x56FD], 0x56FD, 0x56FD),
    ("/UniGB-UCS32-H", [0x00, 0x00, 0x4E, 0x00], [0x4E00], 0x4E00, 0x4E00),
    ("/UniGB-UCS32-V", [0x00, 0x00, 0x56, 0xFD], [0x56FD], 0x56FD, 0x56FD),
    ("/UniKS-UCS2-H", [0xAC, 0x00], [0xAC00], 0xAC00, 0xAC00),
    ("/UniKS-UCS2-V", [0xB0, 0x98], [0xB098], 0xB098, 0xB098),
    ("/UniJIS-UCS2-HW-H", [0x00, 0x41], [0x41], 0x41, 0x41),
    ("/UniJIS-UCS2-HW-V", [0xFF, 0x76], [0xFF76], 0xFF76, 0xFF76),
  ]
  for case in direct_unicode_predefined_cases {
    let direct_unicode_font : @pdflite.PdfFont = PdfFontCIDKeyed({
      basefont: text_cmap_name_for_test("/TopDirectUnicode"),
      composite,
      encoding: PdfPredefinedCMap(text_cmap_name_for_test(case.0)),
    })
    let direct_unicode_extractor = direct_unicode_font.text_extractor()
    @test.assert_eq(
      direct_unicode_extractor.codepoints_of_text(
        text_cmap_bytes_for_test(case.1),
      ),
      case.2,
    )
    @test.assert_eq(
      direct_unicode_extractor.charcode_of_codepoint(case.3),
      Some(case.4),
    )
  }
  let non_ucs2_predefined_font : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_name_for_test("/TopGBEUC"),
    composite,
    encoding: PdfPredefinedCMap(text_cmap_name_for_test("/GB-EUC-H")),
  })
  @test.assert_eq(non_ucs2_predefined_font.uses_two_byte_codes(), false)
  @test.assert_eq(
    try! non_ucs2_predefined_font
    .text_extractor()
    .codepoints_of_text(text_cmap_bytes_for_test([0x41, 0x81, 0x40])),
    [0x41, 0x8140],
  )
  let gb_euc_tounicode_descriptor : @pdflite.PdfFontDescriptor = {
    ..text_cmap_font_descriptor_for_test(),
    tounicode: Some([
      (0x41, text_cmap_bytes_for_test([0x00, 0x41])),
      (0x8140, text_cmap_bytes_for_test([0x4E, 0x00])),
    ]),
  }
  let gb_euc_tounicode_font : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_name_for_test("/TopGBEUCToUnicode"),
    composite: { ..composite, cid_fontdescriptor: gb_euc_tounicode_descriptor },
    encoding: PdfPredefinedCMap(text_cmap_name_for_test("/GB-EUC-H")),
  })
  @test.assert_eq(
    try! gb_euc_tounicode_font
    .text_extractor()
    .codepoints_of_text(text_cmap_bytes_for_test([0x41, 0x81, 0x40])),
    [0x41, 0x4E00],
  )
  let gb_euc_truncated = try? gb_euc_tounicode_font
    .text_extractor()
    .codepoints_of_text(text_cmap_bytes_for_test([0x81]))
  guard gb_euc_truncated is Err(BadText) else {
    fail("expected @pdflite.PdfError::BadText for truncated GB-EUC charcode")
  }
  let gb_euc_builtin_font : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_name_for_test("/TopGBEUCBuiltin"),
    composite,
    encoding: PdfPredefinedCMap(text_cmap_name_for_test("/GB-EUC-H")),
  })
  let gb_euc_builtin_extractor = gb_euc_builtin_font.text_extractor()
  @test.assert_eq(
    gb_euc_builtin_extractor.codepoints_of_text(
      text_cmap_bytes_for_test([
        0x41, 0xC4, 0xE3, 0xBA, 0xC3, 0xA1, 0xA1, 0xA3, 0xC1,
      ]),
    ),
    [0x41, 0x4F60, 0x597D, 0x3000, 0xFF21],
  )
  @test.assert_eq(
    gb_euc_builtin_extractor.charcode_of_codepoint(0x41),
    Some(0x41),
  )
  @test.assert_eq(
    gb_euc_builtin_extractor.charcode_of_codepoint(0x4F60),
    Some(0xC4E3),
  )
  @test.assert_eq(
    gb_euc_builtin_extractor.charcode_of_codepoint(0x597D),
    Some(0xBAC3),
  )
  @test.assert_eq(
    gb_euc_builtin_extractor.charcode_of_codepoint(0x3000),
    Some(0xA1A1),
  )
  @test.assert_eq(
    gb_euc_builtin_extractor.charcode_of_codepoint(0xFF21),
    Some(0xA3C1),
  )
  @test.assert_eq(gb_euc_builtin_extractor.charcode_of_codepoint(0x20AC), None)
  let gbpc_euc_builtin_font : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_name_for_test("/TopGBpcEUCBuiltin"),
    composite,
    encoding: PdfPredefinedCMap(text_cmap_name_for_test("/GBpc-EUC-H")),
  })
  let gbpc_euc_builtin_extractor = gbpc_euc_builtin_font.text_extractor()
  @test.assert_eq(
    gbpc_euc_builtin_extractor.codepoints_of_text(
      text_cmap_bytes_for_test([
        0x41, 0x80, 0x83, 0xA0, 0xFD, 0xFE, 0xFF, 0xA1, 0xA1, 0xA1, 0xAB, 0xA8, 0xBF,
        0xC4, 0xE3, 0xBA, 0xC3,
      ]),
    ),
    [
      0x41, 0x00FC, 0x83, 0x00A0, 0x00A9, 0x2122, 0x2026, 0x3000, 0x301C, 0x006E,
      0x0300, 0x4F60, 0x597D,
    ],
  )
  @test.assert_eq(
    gbpc_euc_builtin_extractor.codepoints_of_text(
      text_cmap_bytes_for_test([0x81, 0x40]),
    ),
    [0x8140],
  )
  @test.assert_eq(
    gbpc_euc_builtin_extractor.charcode_of_codepoint(0x41),
    Some(0x41),
  )
  @test.assert_eq(
    gbpc_euc_builtin_extractor.charcode_of_codepoint(0x00FC),
    Some(0x80),
  )
  @test.assert_eq(
    gbpc_euc_builtin_extractor.charcode_of_codepoint(0x00A9),
    Some(0xFD),
  )
  @test.assert_eq(
    gbpc_euc_builtin_extractor.charcode_of_codepoint(0x2122),
    Some(0xFE),
  )
  @test.assert_eq(
    gbpc_euc_builtin_extractor.charcode_of_codepoint(0x2026),
    Some(0xFF),
  )
  @test.assert_eq(
    gbpc_euc_builtin_extractor.charcode_of_codepoint(0x301C),
    Some(0xA1AB),
  )
  @test.assert_eq(
    gbpc_euc_builtin_extractor.charcode_of_codepoint(0x4F60),
    Some(0xC4E3),
  )
  @test.assert_eq(
    gbpc_euc_builtin_extractor.charcode_of_codepoint(0x597D),
    Some(0xBAC3),
  )
  @test.assert_eq(
    gbpc_euc_builtin_extractor.charcode_of_codepoint(0x0300),
    None,
  )
  let gbpc_euc_truncated = try? gbpc_euc_builtin_extractor.codepoints_of_text(
    text_cmap_bytes_for_test([0xA1]),
  )
  guard gbpc_euc_truncated is Err(BadText) else {
    fail("expected @pdflite.PdfError::BadText for truncated GBpc-EUC charcode")
  }
  let big5_builtin_font : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_name_for_test("/TopBig5Builtin"),
    composite,
    encoding: PdfPredefinedCMap(text_cmap_name_for_test("/ETen-B5-H")),
  })
  let big5_builtin_extractor = big5_builtin_font.text_extractor()
  @test.assert_eq(
    big5_builtin_extractor.codepoints_of_text(
      text_cmap_bytes_for_test([
        0x41, 0xA7, 0x41, 0xA6, 0x6E, 0xA4, 0x40, 0xA4, 0xA4, 0xA1, 0x40,
      ]),
    ),
    [0x41, 0x4F60, 0x597D, 0x4E00, 0x4E2D, 0x3000],
  )
  @test.assert_eq(
    big5_builtin_extractor.codepoints_of_text(
      text_cmap_bytes_for_test([0x81, 0x40]),
    ),
    [0x8140],
  )
  @test.assert_eq(
    big5_builtin_extractor.charcode_of_codepoint(0x41),
    Some(0x41),
  )
  @test.assert_eq(
    big5_builtin_extractor.charcode_of_codepoint(0x4F60),
    Some(0xA741),
  )
  @test.assert_eq(
    big5_builtin_extractor.charcode_of_codepoint(0x597D),
    Some(0xA66E),
  )
  @test.assert_eq(
    big5_builtin_extractor.charcode_of_codepoint(0x3000),
    Some(0xA140),
  )
  @test.assert_eq(big5_builtin_extractor.charcode_of_codepoint(0x20AC), None)
  let big5_truncated = try? big5_builtin_extractor.codepoints_of_text(
    text_cmap_bytes_for_test([0xA7]),
  )
  guard big5_truncated is Err(BadText) else {
    fail("expected @pdflite.PdfError::BadText for truncated Big5 charcode")
  }
  let b5pc_builtin_font : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_name_for_test("/TopB5pcBuiltin"),
    composite,
    encoding: PdfPredefinedCMap(text_cmap_name_for_test("/B5pc-H")),
  })
  let b5pc_builtin_extractor = b5pc_builtin_font.text_extractor()
  @test.assert_eq(
    b5pc_builtin_extractor.codepoints_of_text(
      text_cmap_bytes_for_test([
        0x41, 0x80, 0x83, 0xA0, 0xFD, 0xFE, 0xFF, 0xA1, 0x40, 0xA7, 0x41, 0xA6, 0x6E,
        0xA1, 0x4B, 0xA1, 0x51,
      ]),
    ),
    [
      0x41, 0x005C, 0x83, 0x00A0, 0x00A9, 0x2122, 0x2026, 0x3000, 0x4F60, 0x597D,
      0x22EF, 0xFE54,
    ],
  )
  @test.assert_eq(
    b5pc_builtin_extractor.codepoints_of_text(
      text_cmap_bytes_for_test([0x81, 0x40]),
    ),
    [0x8140],
  )
  @test.assert_eq(
    b5pc_builtin_extractor.charcode_of_codepoint(0x005C),
    Some(0x5C),
  )
  @test.assert_eq(
    b5pc_builtin_extractor.charcode_of_codepoint(0x00A9),
    Some(0xFD),
  )
  @test.assert_eq(
    b5pc_builtin_extractor.charcode_of_codepoint(0x2122),
    Some(0xFE),
  )
  @test.assert_eq(
    b5pc_builtin_extractor.charcode_of_codepoint(0x2026),
    Some(0xFF),
  )
  @test.assert_eq(
    b5pc_builtin_extractor.charcode_of_codepoint(0x22EF),
    Some(0xA14B),
  )
  @test.assert_eq(
    b5pc_builtin_extractor.charcode_of_codepoint(0xFE54),
    Some(0xA151),
  )
  @test.assert_eq(
    b5pc_builtin_extractor.charcode_of_codepoint(0x4F60),
    Some(0xA741),
  )
  @test.assert_eq(
    b5pc_builtin_extractor.charcode_of_codepoint(0x597D),
    Some(0xA66E),
  )
  @test.assert_eq(b5pc_builtin_extractor.charcode_of_codepoint(0x20AC), None)
  let b5pc_truncated = try? b5pc_builtin_extractor.codepoints_of_text(
    text_cmap_bytes_for_test([0xA1]),
  )
  guard b5pc_truncated is Err(BadText) else {
    fail("expected @pdflite.PdfError::BadText for truncated B5pc charcode")
  }
  let hkscs_builtin_font : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_name_for_test("/TopHKscsBuiltin"),
    composite,
    encoding: PdfPredefinedCMap(text_cmap_name_for_test("/HKscs-B5-H")),
  })
  let hkscs_builtin_extractor = hkscs_builtin_font.text_extractor()
  @test.assert_eq(
    hkscs_builtin_extractor.codepoints_of_text(
      text_cmap_bytes_for_test([
        0x41, 0x87, 0x40, 0x87, 0x45, 0x89, 0x43, 0xA1, 0x40, 0xA7, 0x41, 0xA6, 0x6E,
        0xC6, 0xE4, 0xFE, 0xFE, 0x80,
      ]),
    ),
    [
      0x41, 0x43F0, 0x27267, 0x650A, 0x3000, 0x4F60, 0x597D, 0xFF3B, 0x79D4, 0x80,
    ],
  )
  @test.assert_eq(
    hkscs_builtin_extractor.codepoints_of_text(
      text_cmap_bytes_for_test([0x81, 0x40]),
    ),
    [0x8140],
  )
  @test.assert_eq(
    hkscs_builtin_extractor.charcode_of_codepoint(0x41),
    Some(0x41),
  )
  @test.assert_eq(
    hkscs_builtin_extractor.charcode_of_codepoint(0x43F0),
    Some(0x8740),
  )
  @test.assert_eq(
    hkscs_builtin_extractor.charcode_of_codepoint(0x27267),
    Some(0x8745),
  )
  @test.assert_eq(
    hkscs_builtin_extractor.charcode_of_codepoint(0x650A),
    Some(0x8943),
  )
  @test.assert_eq(
    hkscs_builtin_extractor.charcode_of_codepoint(0x3000),
    Some(0xA140),
  )
  @test.assert_eq(
    hkscs_builtin_extractor.charcode_of_codepoint(0x4F60),
    Some(0xA741),
  )
  @test.assert_eq(
    hkscs_builtin_extractor.charcode_of_codepoint(0x597D),
    Some(0xA66E),
  )
  @test.assert_eq(
    hkscs_builtin_extractor.charcode_of_codepoint(0xFF3B),
    Some(0xC6E4),
  )
  @test.assert_eq(
    hkscs_builtin_extractor.charcode_of_codepoint(0x79D4),
    Some(0xFEFE),
  )
  @test.assert_eq(hkscs_builtin_extractor.charcode_of_codepoint(0x1F600), None)
  let hkscs_truncated = try? hkscs_builtin_extractor.codepoints_of_text(
    text_cmap_bytes_for_test([0x87]),
  )
  guard hkscs_truncated is Err(BadText) else {
    fail("expected @pdflite.PdfError::BadText for truncated HKSCS charcode")
  }
  let etenms_b5_builtin_font : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_name_for_test("/TopETenmsBuiltin"),
    composite,
    encoding: PdfPredefinedCMap(text_cmap_name_for_test("/ETenms-B5-H")),
  })
  let etenms_b5_builtin_extractor = etenms_b5_builtin_font.text_extractor()
  @test.assert_eq(
    etenms_b5_builtin_extractor.codepoints_of_text(
      text_cmap_bytes_for_test([0x41, 0xA1, 0xC2, 0xA2, 0x41, 0xC7, 0xFD, 0x80]),
    ),
    [0x41, 0x00AF, 0x2215, 0x0419, 0x80],
  )
  @test.assert_eq(
    etenms_b5_builtin_extractor.codepoints_of_text(
      text_cmap_bytes_for_test([0x81, 0x40]),
    ),
    [0x8140],
  )
  @test.assert_eq(
    etenms_b5_builtin_extractor.charcode_of_codepoint(0x00AF),
    Some(0xA1C2),
  )
  @test.assert_eq(
    etenms_b5_builtin_extractor.charcode_of_codepoint(0x2215),
    Some(0xA241),
  )
  @test.assert_eq(
    etenms_b5_builtin_extractor.charcode_of_codepoint(0x0419),
    Some(0xC7FD),
  )
  @test.assert_eq(
    etenms_b5_builtin_extractor.charcode_of_codepoint(0x1F600),
    None,
  )
  let etenms_b5_truncated = try? etenms_b5_builtin_extractor.codepoints_of_text(
    text_cmap_bytes_for_test([0xA1]),
  )
  guard etenms_b5_truncated is Err(BadText) else {
    fail("expected @pdflite.PdfError::BadText for truncated ETenms-B5 charcode")
  }
  let hk_b5_cases : Array[(String, Array[Int], Array[Int], Int, Int)] = [
    (
      "/HKdla-B5-H",
      [0x41, 0xFA, 0x41, 0x80],
      [0x41, 0x5F0D, 0x80],
      0x5F0D,
      0xFA41,
    ),
    (
      "/HKdlb-B5-H",
      [0x41, 0x8E, 0x40, 0x80],
      [0x41, 0x99C4, 0x80],
      0x99C4,
      0x8E40,
    ),
    (
      "/HKgccs-B5-H",
      [0x41, 0x8A, 0x43, 0x80],
      [0x41, 0x20C42, 0x80],
      0x20C42,
      0x8A43,
    ),
    (
      "/HKm314-B5-H",
      [0x41, 0xC7, 0x40, 0x80],
      [0x41, 0x4E21, 0x80],
      0x4E21,
      0xC740,
    ),
    (
      "/HKm471-B5-H",
      [0x41, 0xFA, 0x40, 0x80],
      [0x41, 0x4E21, 0x80],
      0x4E21,
      0xFA40,
    ),
  ]
  for case in hk_b5_cases {
    let hk_b5_font : @pdflite.PdfFont = PdfFontCIDKeyed({
      basefont: text_cmap_name_for_test("/TopHKB5Builtin"),
      composite,
      encoding: PdfPredefinedCMap(text_cmap_name_for_test(case.0)),
    })
    let hk_b5_extractor = hk_b5_font.text_extractor()
    @test.assert_eq(
      hk_b5_extractor.codepoints_of_text(text_cmap_bytes_for_test(case.1)),
      case.2,
    )
    @test.assert_eq(hk_b5_extractor.charcode_of_codepoint(case.3), Some(case.4))
  }
  let hkgccs_b5_builtin_font : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_name_for_test("/TopHKgccsBuiltin"),
    composite,
    encoding: PdfPredefinedCMap(text_cmap_name_for_test("/HKgccs-B5-H")),
  })
  let hkgccs_b5_builtin_extractor = hkgccs_b5_builtin_font.text_extractor()
  @test.assert_eq(
    hkgccs_b5_builtin_extractor.codepoints_of_text(
      text_cmap_bytes_for_test([0x81, 0x40]),
    ),
    [0x8140],
  )
  @test.assert_eq(
    hkgccs_b5_builtin_extractor.charcode_of_codepoint(0x1F600),
    None,
  )
  let hkgccs_b5_truncated = try? hkgccs_b5_builtin_extractor.codepoints_of_text(
    text_cmap_bytes_for_test([0x8A]),
  )
  guard hkgccs_b5_truncated is Err(BadText) else {
    fail("expected @pdflite.PdfError::BadText for truncated HKgccs-B5 charcode")
  }
  let cns_euc_builtin_font : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_name_for_test("/TopCNSEUCBuiltin"),
    composite,
    encoding: PdfPredefinedCMap(text_cmap_name_for_test("/CNS-EUC-H")),
  })
  let cns_euc_builtin_extractor = cns_euc_builtin_font.text_extractor()
  @test.assert_eq(
    cns_euc_builtin_extractor.codepoints_of_text(
      text_cmap_bytes_for_test([
        0x20, 0x80, 0xA1, 0xA1, 0xA1, 0xAC, 0x8E, 0xA2, 0xA1, 0xA1,
      ]),
    ),
    [0x20, 0x80, 0x3000, 0x2026, 0x4E42],
  )
  @test.assert_eq(
    cns_euc_builtin_extractor.charcode_of_codepoint(0x20),
    Some(0x20),
  )
  @test.assert_eq(
    cns_euc_builtin_extractor.charcode_of_codepoint(0x3000),
    Some(0xA1A1),
  )
  @test.assert_eq(
    cns_euc_builtin_extractor.charcode_of_codepoint(0x2026),
    Some(0xA1AC),
  )
  @test.assert_eq(
    cns_euc_builtin_extractor.charcode_of_codepoint(0x4E42),
    Some(0x8EA2A1A1),
  )
  @test.assert_eq(
    cns_euc_builtin_extractor.charcode_of_codepoint(0x1F600),
    None,
  )
  let cns_euc_vertical_font : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_name_for_test("/TopCNSEUCVerticalBuiltin"),
    composite,
    encoding: PdfPredefinedCMap(text_cmap_name_for_test("/CNS-EUC-V")),
  })
  let cns_euc_vertical_extractor = cns_euc_vertical_font.text_extractor()
  @test.assert_eq(
    cns_euc_vertical_extractor.codepoints_of_text(
      text_cmap_bytes_for_test([0xA1, 0xAC, 0x8E, 0xA1, 0xA1, 0xAC]),
    ),
    [0xFE19, 0xFE19],
  )
  @test.assert_eq(
    cns_euc_vertical_extractor.charcode_of_codepoint(0xFE19),
    Some(0xA1AC),
  )
  let cns_euc_truncated = try? cns_euc_builtin_extractor.codepoints_of_text(
    text_cmap_bytes_for_test([0x8E, 0xA1, 0xA1]),
  )
  guard cns_euc_truncated is Err(BadText) else {
    fail("expected @pdflite.PdfError::BadText for truncated CNS-EUC charcode")
  }
  let uhc_builtin_font : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_name_for_test("/TopUHCBuiltin"),
    composite,
    encoding: PdfPredefinedCMap(text_cmap_name_for_test("/KSCms-UHC-H")),
  })
  let uhc_builtin_extractor = uhc_builtin_font.text_extractor()
  @test.assert_eq(
    uhc_builtin_extractor.codepoints_of_text(
      text_cmap_bytes_for_test([
        0x41, 0xB0, 0xA1, 0xC7, 0xD1, 0xB1, 0xDB, 0x81, 0x41, 0xA4, 0xD4,
      ]),
    ),
    [0x41, 0xAC00, 0xD55C, 0xAE00, 0xAC02, 0x3164],
  )
  @test.assert_eq(
    uhc_builtin_extractor.codepoints_of_text(
      text_cmap_bytes_for_test([0x81, 0x40]),
    ),
    [0x8140],
  )
  @test.assert_eq(uhc_builtin_extractor.charcode_of_codepoint(0x41), Some(0x41))
  @test.assert_eq(
    uhc_builtin_extractor.charcode_of_codepoint(0xAC00),
    Some(0xB0A1),
  )
  @test.assert_eq(
    uhc_builtin_extractor.charcode_of_codepoint(0xD55C),
    Some(0xC7D1),
  )
  @test.assert_eq(
    uhc_builtin_extractor.charcode_of_codepoint(0xAC02),
    Some(0x8141),
  )
  @test.assert_eq(
    uhc_builtin_extractor.charcode_of_codepoint(0x3164),
    Some(0xA4D4),
  )
  @test.assert_eq(uhc_builtin_extractor.charcode_of_codepoint(0x1F600), None)
  let uhc_truncated = try? uhc_builtin_extractor.codepoints_of_text(
    text_cmap_bytes_for_test([0x81]),
  )
  guard uhc_truncated is Err(BadText) else {
    fail("expected @pdflite.PdfError::BadText for truncated UHC charcode")
  }
  let uhc_hw_builtin_font : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_name_for_test("/TopUHCHWBuiltin"),
    composite,
    encoding: PdfPredefinedCMap(text_cmap_name_for_test("/KSCms-UHC-HW-H")),
  })
  let uhc_hw_builtin_extractor = uhc_hw_builtin_font.text_extractor()
  @test.assert_eq(
    uhc_hw_builtin_extractor.codepoints_of_text(
      text_cmap_bytes_for_test([0xB0, 0xA1, 0xA4, 0xD4]),
    ),
    [0xAC00, 0x3164],
  )
  @test.assert_eq(
    uhc_hw_builtin_extractor.charcode_of_codepoint(0xAC00),
    Some(0xB0A1),
  )
  @test.assert_eq(
    uhc_hw_builtin_extractor.charcode_of_codepoint(0x3164),
    Some(0xA4D4),
  )
  let gbk_builtin_font : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_name_for_test("/TopGBKBuiltin"),
    composite,
    encoding: PdfPredefinedCMap(text_cmap_name_for_test("/GBK-EUC-H")),
  })
  let gbk_builtin_extractor = gbk_builtin_font.text_extractor()
  @test.assert_eq(
    gbk_builtin_extractor.codepoints_of_text(
      text_cmap_bytes_for_test([
        0x41, 0x80, 0x81, 0x40, 0xC4, 0xE3, 0xBA, 0xC3, 0xA1, 0xA1, 0xA3, 0xC1, 0xA1,
        0x40, 0xA8, 0xBC, 0xFE, 0xFE, 0xFF,
      ]),
    ),
    [
      0x41, 0x80, 0x4E02, 0x4F60, 0x597D, 0x3000, 0xFF21, 0xE4C6, 0x1E3F, 0xE4C5,
      0xF8F5,
    ],
  )
  @test.assert_eq(
    gbk_builtin_extractor.codepoints_of_text(
      text_cmap_bytes_for_test([0x81, 0x39]),
    ),
    [0x8139],
  )
  @test.assert_eq(gbk_builtin_extractor.charcode_of_codepoint(0x41), Some(0x41))
  @test.assert_eq(gbk_builtin_extractor.charcode_of_codepoint(0x80), Some(0x80))
  @test.assert_eq(
    gbk_builtin_extractor.charcode_of_codepoint(0x4E02),
    Some(0x8140),
  )
  @test.assert_eq(
    gbk_builtin_extractor.charcode_of_codepoint(0x4F60),
    Some(0xC4E3),
  )
  @test.assert_eq(
    gbk_builtin_extractor.charcode_of_codepoint(0x597D),
    Some(0xBAC3),
  )
  @test.assert_eq(
    gbk_builtin_extractor.charcode_of_codepoint(0xE4C6),
    Some(0xA140),
  )
  @test.assert_eq(
    gbk_builtin_extractor.charcode_of_codepoint(0x1E3F),
    Some(0xA8BC),
  )
  @test.assert_eq(
    gbk_builtin_extractor.charcode_of_codepoint(0xE4C5),
    Some(0xFEFE),
  )
  @test.assert_eq(
    gbk_builtin_extractor.charcode_of_codepoint(0xF8F5),
    Some(0xFF),
  )
  @test.assert_eq(gbk_builtin_extractor.charcode_of_codepoint(0x1F600), None)
  let gbk_truncated = try? gbk_builtin_extractor.codepoints_of_text(
    text_cmap_bytes_for_test([0x81]),
  )
  guard gbk_truncated is Err(BadText) else {
    fail("expected @pdflite.PdfError::BadText for truncated GBK charcode")
  }
  let gbkp_builtin_font : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_name_for_test("/TopGBKpBuiltin"),
    composite,
    encoding: PdfPredefinedCMap(text_cmap_name_for_test("/GBKp-EUC-H")),
  })
  let gbkp_builtin_extractor = gbkp_builtin_font.text_extractor()
  @test.assert_eq(
    gbkp_builtin_extractor.codepoints_of_text(
      text_cmap_bytes_for_test([
        0x41, 0x80, 0x81, 0x40, 0xC4, 0xE3, 0xFF, 0x81, 0x39,
      ]),
    ),
    [0x41, 0x80, 0x4E02, 0x4F60, 0xF8F5, 0x8139],
  )
  @test.assert_eq(
    gbkp_builtin_extractor.charcode_of_codepoint(0x4E02),
    Some(0x8140),
  )
  @test.assert_eq(
    gbkp_builtin_extractor.charcode_of_codepoint(0x4F60),
    Some(0xC4E3),
  )
  @test.assert_eq(
    gbkp_builtin_extractor.charcode_of_codepoint(0xF8F5),
    Some(0xFF),
  )
  @test.assert_eq(gbkp_builtin_extractor.charcode_of_codepoint(0x1F600), None)
  let gbkp_truncated = try? gbkp_builtin_extractor.codepoints_of_text(
    text_cmap_bytes_for_test([0x81]),
  )
  guard gbkp_truncated is Err(BadText) else {
    fail("expected @pdflite.PdfError::BadText for truncated GBKp charcode")
  }
  let gbk2k_builtin_font : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_name_for_test("/TopGBK2KBuiltin"),
    composite,
    encoding: PdfPredefinedCMap(text_cmap_name_for_test("/GBK2K-H")),
  })
  let gbk2k_builtin_extractor = gbk2k_builtin_font.text_extractor()
  @test.assert_eq(
    gbk2k_builtin_extractor.codepoints_of_text(
      text_cmap_bytes_for_test([
        0x41, 0x81, 0x40, 0xC4, 0xE3, 0xBA, 0xC3, 0xFE, 0x51, 0x81, 0x30, 0x84, 0x36,
        0x82, 0x36, 0x94, 0x35,
      ]),
    ),
    [0x41, 0x4E02, 0x4F60, 0x597D, 0x20087, 0x00A5, 0xA4C6],
  )
  @test.assert_eq(
    gbk2k_builtin_extractor.codepoints_of_text(
      text_cmap_bytes_for_test([0x81, 0x30, 0x81, 0x30]),
    ),
    [0x81308130],
  )
  @test.assert_eq(
    gbk2k_builtin_extractor.codepoints_of_text(
      text_cmap_bytes_for_test([0x80, 0x40]),
    ),
    [0x8040],
  )
  @test.assert_eq(
    gbk2k_builtin_extractor.charcode_of_codepoint(0x41),
    Some(0x41),
  )
  @test.assert_eq(
    gbk2k_builtin_extractor.charcode_of_codepoint(0x4E02),
    Some(0x8140),
  )
  @test.assert_eq(
    gbk2k_builtin_extractor.charcode_of_codepoint(0x4F60),
    Some(0xC4E3),
  )
  @test.assert_eq(
    gbk2k_builtin_extractor.charcode_of_codepoint(0x597D),
    Some(0xBAC3),
  )
  @test.assert_eq(
    gbk2k_builtin_extractor.charcode_of_codepoint(0x20087),
    Some(0xFE51),
  )
  @test.assert_eq(
    gbk2k_builtin_extractor.charcode_of_codepoint(0x00A5),
    Some(0x81308436),
  )
  @test.assert_eq(
    gbk2k_builtin_extractor.charcode_of_codepoint(0xA4C6),
    Some(0x82369435),
  )
  @test.assert_eq(gbk2k_builtin_extractor.charcode_of_codepoint(0x1F600), None)
  let gbk2k_truncated = try? gbk2k_builtin_extractor.codepoints_of_text(
    text_cmap_bytes_for_test([0x81, 0x30, 0x81]),
  )
  guard gbk2k_truncated is Err(BadText) else {
    fail("expected @pdflite.PdfError::BadText for truncated GBK2K charcode")
  }
  let ksc_euc_builtin_font : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_name_for_test("/TopKSCEUCBuiltin"),
    composite,
    encoding: PdfPredefinedCMap(text_cmap_name_for_test("/KSC-EUC-H")),
  })
  let ksc_euc_builtin_extractor = ksc_euc_builtin_font.text_extractor()
  @test.assert_eq(
    ksc_euc_builtin_extractor.codepoints_of_text(
      text_cmap_bytes_for_test([
        0x41, 0x7E, 0xA1, 0xA1, 0xB0, 0xA1, 0xC7, 0xD1, 0x80,
      ]),
    ),
    [0x41, 0x203E, 0x3000, 0xAC00, 0xD55C, 0x80],
  )
  @test.assert_eq(
    ksc_euc_builtin_extractor.codepoints_of_text(
      text_cmap_bytes_for_test([0xA4, 0xD4]),
    ),
    [0xA4D4],
  )
  @test.assert_eq(
    ksc_euc_builtin_extractor.charcode_of_codepoint(0x41),
    Some(0x41),
  )
  @test.assert_eq(
    ksc_euc_builtin_extractor.charcode_of_codepoint(0x203E),
    Some(0x7E),
  )
  @test.assert_eq(
    ksc_euc_builtin_extractor.charcode_of_codepoint(0x3000),
    Some(0xA1A1),
  )
  @test.assert_eq(
    ksc_euc_builtin_extractor.charcode_of_codepoint(0xAC00),
    Some(0xB0A1),
  )
  @test.assert_eq(
    ksc_euc_builtin_extractor.charcode_of_codepoint(0xD55C),
    Some(0xC7D1),
  )
  @test.assert_eq(
    ksc_euc_builtin_extractor.charcode_of_codepoint(0x4E0D),
    Some(0xDCF4),
  )
  @test.assert_eq(ksc_euc_builtin_extractor.charcode_of_codepoint(0x3164), None)
  let ksc_euc_truncated = try? ksc_euc_builtin_extractor.codepoints_of_text(
    text_cmap_bytes_for_test([0xA1]),
  )
  guard ksc_euc_truncated is Err(BadText) else {
    fail("expected @pdflite.PdfError::BadText for truncated KSC-EUC charcode")
  }
  let kscpc_euc_builtin_font : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_name_for_test("/TopKSCpcEUCBuiltin"),
    composite,
    encoding: PdfPredefinedCMap(text_cmap_name_for_test("/KSCpc-EUC-H")),
  })
  let kscpc_euc_builtin_extractor = kscpc_euc_builtin_font.text_extractor()
  @test.assert_eq(
    kscpc_euc_builtin_extractor.codepoints_of_text(
      text_cmap_bytes_for_test([
        0x41, 0x80, 0x81, 0x84, 0x9F, 0xFE, 0xFF, 0xA1, 0x41, 0xA1, 0x51, 0xA2, 0xE6,
        0xA2, 0xEF, 0xB0, 0xA1, 0xC7, 0xD1,
      ]),
    ),
    [
      0x41, 0x00A0, 0x20A9, 0xFF3F, 0x9F, 0x2122, 0x22EF, 0x300C, 0x28, 0x28, 0x31,
      0x20DE, 0x5B, 0x31, 0x30, 0x5D, 0xAC00, 0xD55C,
    ],
  )
  @test.assert_eq(
    kscpc_euc_builtin_extractor.codepoints_of_text(
      text_cmap_bytes_for_test([0xA1, 0x40]),
    ),
    [0xA140],
  )
  @test.assert_eq(
    kscpc_euc_builtin_extractor.charcode_of_codepoint(0x28),
    Some(0x28),
  )
  @test.assert_eq(
    kscpc_euc_builtin_extractor.charcode_of_codepoint(0x20A9),
    Some(0x81),
  )
  @test.assert_eq(
    kscpc_euc_builtin_extractor.charcode_of_codepoint(0xFF3F),
    Some(0x84),
  )
  @test.assert_eq(
    kscpc_euc_builtin_extractor.charcode_of_codepoint(0x2122),
    Some(0xFE),
  )
  @test.assert_eq(
    kscpc_euc_builtin_extractor.charcode_of_codepoint(0x22EF),
    Some(0xFF),
  )
  @test.assert_eq(
    kscpc_euc_builtin_extractor.charcode_of_codepoint(0x300C),
    Some(0xA141),
  )
  @test.assert_eq(
    kscpc_euc_builtin_extractor.charcode_of_codepoint(0xAC00),
    Some(0xB0A1),
  )
  @test.assert_eq(
    kscpc_euc_builtin_extractor.charcode_of_codepoint(0x20DE),
    None,
  )
  let kscpc_euc_truncated = try? kscpc_euc_builtin_extractor.codepoints_of_text(
    text_cmap_bytes_for_test([0xA1]),
  )
  guard kscpc_euc_truncated is Err(BadText) else {
    fail("expected @pdflite.PdfError::BadText for truncated KSCpc-EUC charcode")
  }
  let vertical_builtin_cases : Array[(String, Array[Int], Array[Int], Int, Int)] = [
    ("/GB-EUC-V", [0xA1, 0xA2], [0x3001], 0x3001, 0xA1A2),
    ("/GBpc-EUC-V", [0xA1, 0xA2], [0x3001], 0x3001, 0xA1A2),
    ("/GBK-EUC-V", [0xA1, 0xA2], [0x3001], 0x3001, 0xA1A2),
    ("/GBKp-EUC-V", [0xA1, 0xA2], [0x3001], 0x3001, 0xA1A2),
    ("/GBK2K-V", [0xA4, 0xC3], [0x3064], 0x3064, 0xA4C3),
    ("/B5-V", [0xA1, 0x4B], [0xFE19], 0xFE19, 0xA14B),
    ("/B5pc-V", [0xA1, 0x4B], [0xFE19], 0xFE19, 0xA14B),
    ("/ETen-B5-V", [0xA1, 0x4B], [0xFE19], 0xFE19, 0xA14B),
    ("/ETenms-B5-V", [0xA1, 0x4C], [0xFE30], 0xFE30, 0xA14C),
    ("/HKdla-B5-V", [0xA1, 0x4B], [0xFE19], 0xFE19, 0xA14B),
    ("/HKdlb-B5-V", [0xA1, 0x4B], [0xFE19], 0xFE19, 0xA14B),
    ("/HKgccs-B5-V", [0xA1, 0x4B], [0xFE19], 0xFE19, 0xA14B),
    ("/HKm314-B5-V", [0xA1, 0x4B], [0xFE19], 0xFE19, 0xA14B),
    ("/HKm471-B5-V", [0xA1, 0x4B], [0xFE19], 0xFE19, 0xA14B),
    ("/HKscs-B5-V", [0xA1, 0x4B], [0xFE19], 0xFE19, 0xA14B),
    ("/KSC-EUC-V", [0xA1, 0xA6], [0x22EF], 0x22EF, 0xA1A6),
    ("/KSCpc-EUC-V", [0xA1, 0xA6], [0x22EF], 0x22EF, 0xA1A6),
    ("/KSCms-UHC-V", [0xA1, 0xA6], [0x22EF], 0x22EF, 0xA1A6),
    ("/KSCms-UHC-HW-V", [0xA1, 0xA6], [0x22EF], 0x22EF, 0xA1A6),
  ]
  for case in vertical_builtin_cases {
    let vertical_builtin_font : @pdflite.PdfFont = PdfFontCIDKeyed({
      basefont: text_cmap_name_for_test("/TopVerticalBuiltin"),
      composite,
      encoding: PdfPredefinedCMap(text_cmap_name_for_test(case.0)),
    })
    let vertical_builtin_extractor = vertical_builtin_font.text_extractor()
    @test.assert_eq(
      vertical_builtin_extractor.codepoints_of_text(
        text_cmap_bytes_for_test(case.1),
      ),
      case.2,
    )
    @test.assert_eq(
      vertical_builtin_extractor.charcode_of_codepoint(case.3),
      Some(case.4),
    )
  }
  let rksj_tounicode_descriptor : @pdflite.PdfFontDescriptor = {
    ..text_cmap_font_descriptor_for_test(),
    tounicode: Some([
      (0x8140, text_cmap_bytes_for_test([0x4E, 0x8C])),
      (0xA6, text_cmap_bytes_for_test([0xFF, 0x66])),
    ]),
  }
  let rksj_tounicode_font : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_name_for_test("/TopRKSJToUnicode"),
    composite: { ..composite, cid_fontdescriptor: rksj_tounicode_descriptor },
    encoding: PdfPredefinedCMap(text_cmap_name_for_test("/90ms-RKSJ-H")),
  })
  @test.assert_eq(
    try! rksj_tounicode_font
    .text_extractor()
    .codepoints_of_text(text_cmap_bytes_for_test([0x81, 0x40, 0xA6])),
    [0x4E8C, 0xFF66],
  )
  let rksj_builtin_font : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_name_for_test("/TopRKSJBuiltin"),
    composite,
    encoding: PdfPredefinedCMap(text_cmap_name_for_test("/90ms-RKSJ-H")),
  })
  let rksj_builtin_extractor = rksj_builtin_font.text_extractor()
  @test.assert_eq(
    rksj_builtin_extractor.codepoints_of_text(
      text_cmap_bytes_for_test([0x41, 0xA6, 0x81, 0x40]),
    ),
    [0x41, 0xFF66, 0x3000],
  )
  @test.assert_eq(
    rksj_builtin_extractor.charcode_of_codepoint(0x41),
    Some(0x41),
  )
  @test.assert_eq(
    rksj_builtin_extractor.charcode_of_codepoint(0xFF66),
    Some(0xA6),
  )
  @test.assert_eq(
    rksj_builtin_extractor.charcode_of_codepoint(0x20AC),
    Some(0x80),
  )
  @test.assert_eq(
    rksj_builtin_extractor.charcode_of_codepoint(0x3000),
    Some(0x8140),
  )
  @test.assert_eq(
    rksj_builtin_extractor.charcode_of_codepoint(0x4E8C),
    Some(0x93F1),
  )
  let rksj_truncated = try? rksj_builtin_extractor.codepoints_of_text(
    text_cmap_bytes_for_test([0x81]),
  )
  guard rksj_truncated is Err(_) else {
    fail("expected malformed RKSJ charcode")
  }
  let pv_rksj_builtin_font : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_name_for_test("/Top90pvRKSJBuiltin"),
    composite,
    encoding: PdfPredefinedCMap(text_cmap_name_for_test("/90pv-RKSJ-H")),
  })
  let pv_rksj_builtin_extractor = pv_rksj_builtin_font.text_extractor()
  @test.assert_eq(
    pv_rksj_builtin_extractor.codepoints_of_text(
      text_cmap_bytes_for_test([0x5C, 0x80, 0xA0, 0x81, 0x7C, 0x85, 0x91]),
    ),
    [0x00A5, 0x005C, 0x00A0, 0x2212, 0xF860, 0x0030, 0x002E],
  )
  @test.assert_eq(
    pv_rksj_builtin_extractor.charcode_of_codepoint(0x00A5),
    Some(0x5C),
  )
  @test.assert_eq(
    pv_rksj_builtin_extractor.charcode_of_codepoint(0x005C),
    Some(0x80),
  )
  @test.assert_eq(
    pv_rksj_builtin_extractor.charcode_of_codepoint(0x2212),
    Some(0x817C),
  )
  @test.assert_eq(pv_rksj_builtin_extractor.charcode_of_codepoint(0xF860), None)
  let jis_builtin_font : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_name_for_test("/TopJISBuiltin"),
    composite,
    encoding: PdfPredefinedCMap(text_cmap_name_for_test("/H")),
  })
  @test.assert_eq(jis_builtin_font.uses_two_byte_codes(), true)
  let jis_builtin_extractor = jis_builtin_font.text_extractor()
  @test.assert_eq(
    jis_builtin_extractor.codepoints_of_text(
      text_cmap_bytes_for_test([0x21, 0x21, 0x24, 0x22]),
    ),
    [0x3000, 0x3042],
  )
  @test.assert_eq(
    jis_builtin_extractor.charcode_of_codepoint(0x3042),
    Some(0x2422),
  )
  let jis_truncated = try? jis_builtin_extractor.codepoints_of_text(
    text_cmap_bytes_for_test([0x21]),
  )
  guard jis_truncated is Err(BadText) else {
    fail("expected @pdflite.PdfError::BadText for truncated JIS charcode")
  }
  let japan_euc_builtin_font : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_name_for_test("/TopJapanEUCBuiltin"),
    composite,
    encoding: PdfPredefinedCMap(text_cmap_name_for_test("/EUC-H")),
  })
  let japan_euc_builtin_extractor = japan_euc_builtin_font.text_extractor()
  @test.assert_eq(
    japan_euc_builtin_extractor.codepoints_of_text(
      text_cmap_bytes_for_test([0xA1, 0xA1, 0xA4, 0xA2]),
    ),
    [0x3000, 0x3042],
  )
  @test.assert_eq(
    japan_euc_builtin_extractor.charcode_of_codepoint(0x3042),
    Some(0xA4A2),
  )
  let hojo_euc_builtin_font : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_name_for_test("/TopHojoEUCBuiltin"),
    composite,
    encoding: PdfPredefinedCMap(text_cmap_name_for_test("/Hojo-EUC-H")),
  })
  let hojo_euc_builtin_extractor = hojo_euc_builtin_font.text_extractor()
  @test.assert_eq(
    hojo_euc_builtin_extractor.codepoints_of_text(
      text_cmap_bytes_for_test([0x8F, 0xB4, 0xAE]),
    ),
    [0x4EDD],
  )
  @test.assert_eq(
    hojo_euc_builtin_extractor.charcode_of_codepoint(0x4EDD),
    Some(0x8FB4AE),
  )
  let hojo_euc_truncated = try? hojo_euc_builtin_extractor.codepoints_of_text(
    text_cmap_bytes_for_test([0x8F, 0xB4]),
  )
  guard hojo_euc_truncated is Err(BadText) else {
    fail("expected @pdflite.PdfError::BadText for truncated Hojo-EUC charcode")
  }
  let rare_japan1_predefined_cases = [
    ("/78-H", [0x21, 0x21, 0x24, 0x22], [0x3000, 0x3042], 0x3042, 0x2422, true),
    ("/78-V", [0x21, 0x21, 0x24, 0x21], [0x3000, 0x3041], 0x3041, 0x2421, true),
    (
      "/78-RKSJ-H",
      [0x81, 0x40, 0x82, 0xA0],
      [0x3000, 0x3042],
      0x3042,
      0x82A0,
      false,
    ),
    (
      "/78-RKSJ-V",
      [0x81, 0x40, 0x82, 0x9F],
      [0x3000, 0x3041],
      0x3041,
      0x829F,
      false,
    ),
    (
      "/78ms-RKSJ-H",
      [0x81, 0x40, 0x82, 0xA0],
      [0x3000, 0x3042],
      0x3042,
      0x82A0,
      false,
    ),
    (
      "/78ms-RKSJ-V",
      [0x81, 0x40, 0x82, 0x9F],
      [0x3000, 0x3041],
      0x3041,
      0x829F,
      false,
    ),
    (
      "/83pv-RKSJ-H",
      [0x80, 0x81, 0x40, 0x82, 0xA0],
      [0x005C, 0x3000, 0x3042],
      0x005C,
      0x80,
      false,
    ),
    (
      "/90ms-RKSJ-V",
      [0x81, 0x40, 0x82, 0x9F],
      [0x3000, 0x3041],
      0x3041,
      0x829F,
      false,
    ),
    (
      "/90msp-RKSJ-H",
      [0x41, 0x5C, 0xA6, 0x81, 0x40, 0x93, 0xF1],
      [0x41, 0x00A5, 0xFF66, 0x3000, 0x4E8C],
      0x00A5,
      0x5C,
      false,
    ),
    (
      "/90msp-RKSJ-V",
      [0x41, 0x5C, 0xA6, 0x81, 0x40, 0x82, 0x9F, 0x93, 0xF1],
      [0x41, 0x00A5, 0xFF66, 0x3000, 0x3041, 0x4E8C],
      0x3041,
      0x829F,
      false,
    ),
    (
      "/90pv-RKSJ-V",
      [0x80, 0x81, 0x40, 0x82, 0x9F],
      [0x005C, 0x3000, 0x3041],
      0x005C,
      0x80,
      false,
    ),
    (
      "/RKSJ-H",
      [0x81, 0x40, 0x82, 0xA0],
      [0x3000, 0x3042],
      0x3042,
      0x82A0,
      false,
    ),
    (
      "/RKSJ-V",
      [0x81, 0x40, 0x82, 0x9F],
      [0x3000, 0x3041],
      0x3041,
      0x829F,
      false,
    ),
    (
      "/78-EUC-H",
      [0xA1, 0xA1, 0xA4, 0xA2],
      [0x3000, 0x3042],
      0x3042,
      0xA4A2,
      false,
    ),
    (
      "/78-EUC-V",
      [0xA1, 0xA1, 0xA4, 0xA1],
      [0x3000, 0x3041],
      0x3041,
      0xA4A1,
      false,
    ),
    (
      "/EUC-V",
      [0xA1, 0xA1, 0xA4, 0xA1],
      [0x3000, 0x3041],
      0x3041,
      0xA4A1,
      false,
    ),
    ("/Add-H", [0x28, 0x21, 0x24, 0x22], [0x2500, 0x3042], 0x2500, 0x2821, true),
    ("/Add-V", [0x28, 0x21, 0x24, 0x21], [0x2500, 0x3041], 0x3041, 0x2421, true),
    (
      "/Add-RKSJ-H",
      [0x84, 0x9F, 0x82, 0xA0],
      [0x2500, 0x3042],
      0x2500,
      0x849F,
      false,
    ),
    (
      "/Add-RKSJ-V",
      [0x84, 0x9F, 0x82, 0x9F],
      [0x2500, 0x3041],
      0x3041,
      0x829F,
      false,
    ),
    ("/Ext-H", [0x2C, 0x24, 0x24, 0x22], [0x2500, 0x3042], 0x3042, 0x2422, true),
    ("/Ext-V", [0x2C, 0x24, 0x24, 0x21], [0x2500, 0x3041], 0x3041, 0x2421, true),
    (
      "/Ext-RKSJ-H",
      [0x86, 0xA2, 0x82, 0xA0],
      [0x2500, 0x3042],
      0x3042,
      0x82A0,
      false,
    ),
    (
      "/Ext-RKSJ-V",
      [0x86, 0xA2, 0x82, 0x9F],
      [0x2500, 0x3041],
      0x3041,
      0x829F,
      false,
    ),
    ("/Hojo-H", [0x34, 0x2E], [0x4EDD], 0x4EDD, 0x342E, true),
    ("/Hojo-V", [0x34, 0x2E], [0x4EDD], 0x4EDD, 0x342E, true),
    ("/Hojo-EUC-V", [0x8F, 0xB4, 0xAE], [0x4EDD], 0x4EDD, 0x8FB4AE, false),
    (
      "/NWP-H",
      [0x2E, 0x21, 0x2C, 0x24, 0x24, 0x22],
      [0xFF01, 0x2500, 0x3042],
      0x3042,
      0x2422,
      true,
    ),
    ("/NWP-V", [0x2E, 0x21, 0x24, 0x21], [0xFF01, 0x3041], 0x3041, 0x2421, true),
  ]
  for case in rare_japan1_predefined_cases {
    let rare_japan1_font : @pdflite.PdfFont = PdfFontCIDKeyed({
      basefont: text_cmap_name_for_test("/TopRareJapan1Builtin"),
      composite,
      encoding: PdfPredefinedCMap(text_cmap_name_for_test(case.0)),
    })
    @test.assert_eq(rare_japan1_font.uses_two_byte_codes(), case.5)
    let rare_japan1_extractor = rare_japan1_font.text_extractor()
    @test.assert_eq(
      rare_japan1_extractor.codepoints_of_text(text_cmap_bytes_for_test(case.1)),
      case.2,
    )
    @test.assert_eq(
      rare_japan1_extractor.charcode_of_codepoint(case.3),
      Some(case.4),
    )
    @test.assert_eq(rare_japan1_extractor.charcode_of_codepoint(0x1F600), None)
  }
  let external_cmap_font : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_name_for_test("/ExternalCMap"),
    composite,
    encoding: PdfCMap(7),
  })
  let external_extractor = external_cmap_font.text_extractor()
  @test.assert_eq(
    try! external_extractor.codepoints_of_text(
      text_cmap_bytes_for_test([0x00, 0x42]),
    ),
    [0x00, 0x42],
  )
  @test.assert_eq(external_extractor.charcode_of_codepoint(0x42), None)
}

///|
test "PdfDocument applies indirect external CMap text segmentation and CID mapping" {
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(4, text_cmap_valid_cid_descendant_for_test([]))
  let cmap_data = @ascii.encode(
    "2 begincodespacerange\n" +
    "<00><7F>\n" +
    "<8100><81FF>\n" +
    "endcodespacerange\n" +
    "1 begincidchar\n" +
    "<41> 100\n" +
    "endcidchar\n" +
    "1 begincidrange\n" +
    "<8140><8142> 200\n" +
    "endcidrange\n",
  )
  let cmap = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (text_cmap_name_for_test("/Length"), PdfInteger(cmap_data.length())),
    ]),
    StreamGot(cmap_data),
  )
  doc.add_object_given_number(5, cmap)
  let font = @pdflite.pdf_dictionary([
    (
      text_cmap_name_for_test("/Subtype"),
      PdfNameObject(text_cmap_name_for_test("/Type0")),
    ),
    (
      text_cmap_name_for_test("/BaseFont"),
      PdfNameObject(text_cmap_name_for_test("/T")),
    ),
    (text_cmap_name_for_test("/DescendantFonts"), PdfArray([PdfIndirect(4)])),
    (text_cmap_name_for_test("/Encoding"), PdfIndirect(5)),
  ])
  guard (try! doc.read_cidkeyed_font(font)).encoding
    is PdfExternalCMap(5, parsed) else {
    fail("expected parsed external CMap")
  }
  @test.assert_eq(parsed.codespaces, [
    { length: 1, first: 0x00, last: 0x7F },
    { length: 2, first: 0x8100, last: 0x81FF },
  ])
  let extractor = try! doc.text_extractor_of_font(font)
  @test.assert_eq(
    extractor.codepoints_of_text(
      text_cmap_bytes_for_test([0x41, 0x81, 0x40, 0x81, 0x42, 0x30]),
    ),
    [100, 200, 202, 0x30],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(202), Some(0x8142))
  @test.assert_eq(extractor.charcode_of_codepoint(0x30), None)
  let truncated : Result[Array[Int], Error] = try? extractor.codepoints_of_text(
    text_cmap_bytes_for_test([0x81]),
  )
  guard truncated is Err(_) else {
    fail("expected malformed external CMap code")
  }
}

///|
test "PdfTextExtractor keeps external CMap text lookup precedence" {
  let composite : @pdflite.PdfCompositeCIDFont = {
    cid_system_info: {
      registry: text_cmap_bytes_for_test([65]),
      ordering: text_cmap_bytes_for_test([73]),
      supplement: 0,
    },
    cid_basefont: text_cmap_name_for_test("/Descendant"),
    cid_fontdescriptor: text_cmap_font_descriptor_for_test(),
    cid_widths: [],
    cid_widths2: [],
    cid_default_width: 1000.0,
    cid_default_width2: [880.0, -1000.0],
  }
  let font : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_name_for_test("/ExternalCMap"),
    composite,
    encoding: PdfExternalCMap(7, {
      map: [
        (0x41, text_cmap_bytes_for_test([0x00, 0x61])),
        (0x42, text_cmap_bytes_for_test([0x00, 0x62])),
        (0x43, text_cmap_bytes_for_test([0x00, 0x63])),
        (0x43, text_cmap_bytes_for_test([0x00, 0x64])),
        (0x45, text_cmap_bytes_for_test([0xD8, 0x00])),
      ],
      cid_map: [(0x41, 99), (0x41, 100)],
      notdef_map: [(0x42, 77), (0x42, 78)],
      codespaces: [{ length: 1, first: 0x00, last: 0xFF }],
      usecmap: None,
      wmode: None,
      cmap_name: None,
      cmap_type: None,
      cid_system_info: None,
    }),
  })
  let extractor = font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(
      text_cmap_bytes_for_test([0x41, 0x42, 0x43, 0x44, 0x45]),
    ),
    [99, 77, 0x63, 0x44, 0x45],
  )
  let notdef = text_cmap_name_for_test(".notdef")
  @test.assert_eq(
    try! extractor.glyphnames_and_codepoints_of_text(
      text_cmap_bytes_for_test([0x41, 0x42, 0x43, 0x44]),
    ),
    [
      { glyphname: notdef, codepoints: [99] },
      { glyphname: notdef, codepoints: [77] },
      { glyphname: notdef, codepoints: [0x63] },
      { glyphname: notdef, codepoints: [0x44] },
    ],
  )
  let identity_font : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_name_for_test("/ExternalIdentityCMap"),
    composite,
    encoding: PdfExternalCMap(8, {
      map: [],
      cid_map: [],
      notdef_map: [],
      codespaces: [],
      usecmap: Some(text_cmap_name_for_test("/Identity-H")),
      wmode: None,
      cmap_name: None,
      cmap_type: None,
      cid_system_info: None,
    }),
  })
  @test.assert_eq(
    try! identity_font
    .text_extractor()
    .glyphnames_and_codepoints_of_text(text_cmap_bytes_for_test([0x00, 0x42])),
    [{ glyphname: notdef, codepoints: [0x42] }],
  )
  let predefined_font : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_cmap_name_for_test("/ExternalGBEUCCMap"),
    composite,
    encoding: PdfExternalCMap(9, {
      map: [],
      cid_map: [],
      notdef_map: [],
      codespaces: [],
      usecmap: Some(text_cmap_name_for_test("/GB-EUC-H")),
      wmode: None,
      cmap_name: None,
      cmap_type: None,
      cid_system_info: None,
    }),
  })
  @test.assert_eq(
    try! predefined_font
    .text_extractor()
    .glyphnames_and_codepoints_of_text(
      text_cmap_bytes_for_test([0xC4, 0xE3, 0x81, 0x40]),
    ),
    [
      { glyphname: notdef, codepoints: [0x4F60] },
      { glyphname: notdef, codepoints: [0x8140] },
    ],
  )
}
