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
