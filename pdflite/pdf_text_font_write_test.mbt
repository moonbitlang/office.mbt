///|
fn text_font_write_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn text_font_write_bytes_for_test(values : ArrayView[Int]) -> @pdflite.PdfBytes {
  try! @pdflite.pdf_bytes_of_int_array(values)
}

///|
fn text_font_write_difference_for_test(
  name : String,
  code : Int,
) -> @pdflite.PdfEncodingDifference {
  { name: text_font_write_name_for_test(name), code }
}

///|
fn text_font_write_standard_font_data_for_test(
  font : @pdflite.PdfStandardFont,
  encoding : @pdflite.PdfEncoding,
) -> @pdflite.PdfStandardFontData {
  { font, encoding }
}

///|
fn text_font_write_descriptor_for_test() -> @pdflite.PdfFontDescriptor {
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
fn text_font_write_type3_charproc_stream_for_test(
  ops : ArrayView[@content.PdfContentOp],
) -> @pdflite.PdfObject raise {
  let data = @pdflite.pdf_content_bytes_of_ops(ops)
  @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (text_font_write_name_for_test("/Length"), PdfInteger(data.length())),
    ]),
    StreamGot(data),
  )
}

///|
test "PdfDocument write_encoding writes custom differences" {
  let doc = @pdflite.pdf_document_empty()
  let number = try! doc.write_encoding(
    PdfCustomEncoding(PdfImplicitInFontFile, [
      text_font_write_difference_for_test("/A", 65),
      text_font_write_difference_for_test("/B", 66),
    ]),
  )
  @test.assert_eq(
    doc.lookup_object_or_null(number),
    @pdflite.pdf_dictionary([
      (
        text_font_write_name_for_test("/Type"),
        PdfNameObject(text_font_write_name_for_test("/Encoding")),
      ),
      (
        text_font_write_name_for_test("/Differences"),
        PdfArray([
          PdfInteger(65),
          PdfNameObject(text_font_write_name_for_test("/A")),
          PdfInteger(66),
          PdfNameObject(text_font_write_name_for_test("/B")),
        ]),
      ),
    ]),
  )
  let unsupported = try? doc.write_encoding(PdfWinAnsiEncoding)
  guard unsupported is Err(EncodingWriteUnsupported) else {
    fail("expected @pdflite.PdfError::EncodingWriteUnsupported")
  }
}

///|
test "pdf_make_font builds Type1 font dictionaries" {
  @test.assert_eq(
    try! @pdflite.pdf_make_font(
      text_font_write_name_for_test("/Helvetica"),
      PdfWinAnsiEncoding,
    ),
    @pdflite.pdf_dictionary([
      (
        text_font_write_name_for_test("/Type"),
        PdfNameObject(text_font_write_name_for_test("/Font")),
      ),
      (
        text_font_write_name_for_test("/Subtype"),
        PdfNameObject(text_font_write_name_for_test("/Type1")),
      ),
      (
        text_font_write_name_for_test("/Encoding"),
        PdfNameObject(text_font_write_name_for_test("/WinAnsiEncoding")),
      ),
      (
        text_font_write_name_for_test("/BaseFont"),
        PdfNameObject(text_font_write_name_for_test("/Helvetica")),
      ),
    ]),
  )
  let custom = try? @pdflite.pdf_make_font(
    text_font_write_name_for_test("/Custom"),
    PdfCustomEncoding(PdfImplicitInFontFile, []),
  )
  guard custom is Err(EncodingWriteUnsupported) else {
    fail("expected @pdflite.PdfError::EncodingWriteUnsupported")
  }
}

///|
test "PdfDocument write_font writes standard14 fonts" {
  let doc = @pdflite.pdf_document_empty()
  let number = doc.write_font(
    PdfFontStandard(
      text_font_write_standard_font_data_for_test(
        PdfHelveticaBold,
        PdfWinAnsiEncoding,
      ),
    ),
  )
  @test.assert_eq(number, 1)
  @test.assert_eq(
    doc.lookup_object_or_null(number),
    @pdflite.pdf_dictionary([
      (
        text_font_write_name_for_test("/Type"),
        PdfNameObject(text_font_write_name_for_test("/Font")),
      ),
      (
        text_font_write_name_for_test("/Subtype"),
        PdfNameObject(text_font_write_name_for_test("/Type1")),
      ),
      (
        text_font_write_name_for_test("/Encoding"),
        PdfNameObject(text_font_write_name_for_test("/WinAnsiEncoding")),
      ),
      (
        text_font_write_name_for_test("/BaseFont"),
        PdfNameObject(text_font_write_name_for_test("/Helvetica-Bold")),
      ),
    ]),
  )

  let fixed_number = try! doc.write_font(
    PdfFontStandard(
      text_font_write_standard_font_data_for_test(
        PdfTimesRoman,
        PdfMacRomanEncoding,
      ),
    ),
    objnum=Some(20),
  )
  @test.assert_eq(fixed_number, 20)
  @test.assert_eq(
    doc.lookup_object_or_null(20),
    @pdflite.pdf_dictionary([
      (
        text_font_write_name_for_test("/Type"),
        PdfNameObject(text_font_write_name_for_test("/Font")),
      ),
      (
        text_font_write_name_for_test("/Subtype"),
        PdfNameObject(text_font_write_name_for_test("/Type1")),
      ),
      (
        text_font_write_name_for_test("/Encoding"),
        PdfNameObject(text_font_write_name_for_test("/MacRomanEncoding")),
      ),
      (
        text_font_write_name_for_test("/BaseFont"),
        PdfNameObject(text_font_write_name_for_test("/Times-Roman")),
      ),
    ]),
  )
}

///|
test "PdfDocument write_font writes Type3 fonts" {
  let doc = @pdflite.pdf_document_empty()
  let d0_stream = text_font_write_type3_charproc_stream_for_test([
    Op_d0(500.0, 0.0),
  ])
  let d1_stream = text_font_write_type3_charproc_stream_for_test([
    Op_d1(600.0, 0.0, 0.0, -20.0, 600.0, 700.0),
  ])
  let fontmatrix : @geometry.TransformMatrix = {
    a: 0.001,
    b: 0.0,
    c: 0.0,
    d: 0.001,
    e: 2.0,
    f: 3.0,
  }
  let number = try! doc.write_font(
    PdfFontSimple({
      fonttype: PdfType3({
        fontbbox: { min_x: 1.0, min_y: 2.0, max_x: 3.0, max_y: 4.0 },
        fontmatrix,
        charprocs: [
          (text_font_write_name_for_test("/A"), d0_stream),
          (text_font_write_name_for_test("/B"), d1_stream),
        ],
        resources: @pdflite.pdf_dictionary([
          (text_font_write_name_for_test("/ProcSet"), PdfArray([])),
        ]),
      }),
      basefont: None,
      firstchar: 65,
      lastchar: 66,
      widths: [500, 600],
      fontdescriptor: Some(text_font_write_descriptor_for_test()),
      fontmetrics: None,
      encoding: PdfImplicitInFontFile,
    }),
  )
  @test.assert_eq(number, 1)
  @test.assert_eq(
    doc.lookup_object_or_null(number),
    @pdflite.pdf_dictionary([
      (
        text_font_write_name_for_test("/Type"),
        PdfNameObject(text_font_write_name_for_test("/Font")),
      ),
      (
        text_font_write_name_for_test("/Subtype"),
        PdfNameObject(text_font_write_name_for_test("/Type3")),
      ),
      (
        text_font_write_name_for_test("/FontBBox"),
        PdfArray([PdfReal(1.0), PdfReal(2.0), PdfReal(3.0), PdfReal(4.0)]),
      ),
      (
        text_font_write_name_for_test("/FontMatrix"),
        PdfArray([
          PdfReal(0.001),
          PdfReal(0.0),
          PdfReal(0.0),
          PdfReal(0.001),
          PdfReal(2.0),
          PdfReal(3.0),
        ]),
      ),
      (
        text_font_write_name_for_test("/CharProcs"),
        @pdflite.pdf_dictionary([
          (text_font_write_name_for_test("/A"), d0_stream),
          (text_font_write_name_for_test("/B"), d1_stream),
        ]),
      ),
      (
        text_font_write_name_for_test("/Resources"),
        @pdflite.pdf_dictionary([
          (text_font_write_name_for_test("/ProcSet"), PdfArray([])),
        ]),
      ),
      (text_font_write_name_for_test("/FirstChar"), PdfInteger(65)),
      (text_font_write_name_for_test("/LastChar"), PdfInteger(66)),
      (
        text_font_write_name_for_test("/Widths"),
        PdfArray([PdfInteger(500), PdfInteger(600)]),
      ),
    ]),
  )
  let simple = doc.read_simple_font(doc.lookup_object_or_null(number))
  guard simple.fonttype is PdfType3(type3_data) else {
    fail("expected Type3 font")
  }
  @test.assert_eq(type3_data.fontbbox, {
    min_x: 1.0,
    min_y: 2.0,
    max_x: 3.0,
    max_y: 4.0,
  })
  @test.assert_eq(type3_data.fontmatrix, fontmatrix)
  @test.assert_eq(type3_data.charprocs, [
    (text_font_write_name_for_test("/A"), d0_stream),
    (text_font_write_name_for_test("/B"), d1_stream),
  ])
  @test.assert_eq(
    type3_data.resources,
    @pdflite.pdf_dictionary([
      (text_font_write_name_for_test("/ProcSet"), PdfArray([])),
    ]),
  )
  guard simple.fontmetrics is Some(metrics) else {
    fail("expected Type3 metrics")
  }
  @test.assert_eq(metrics[65], 500.0)
  @test.assert_eq(metrics[66], 600.0)
}

///|
test "PdfDocument write_font writes Type3 custom encoding object" {
  let doc = @pdflite.pdf_document_empty()
  let number = try! doc.write_font(
    PdfFontSimple({
      fonttype: PdfType3({
        fontbbox: { min_x: 0.0, min_y: 0.0, max_x: 0.0, max_y: 0.0 },
        fontmatrix: @geometry.transform_identity_matrix,
        charprocs: [(text_font_write_name_for_test("/A"), PdfInteger(10))],
        resources: @pdflite.pdf_dictionary([]),
      }),
      basefont: None,
      firstchar: 0,
      lastchar: 0,
      widths: [],
      fontdescriptor: Some(text_font_write_descriptor_for_test()),
      fontmetrics: None,
      encoding: PdfCustomEncoding(PdfImplicitInFontFile, [
        text_font_write_difference_for_test("/A", 65),
      ]),
    }),
    objnum=Some(20),
  )
  @test.assert_eq(number, 20)
  @test.assert_eq(
    doc.lookup_object_or_null(1),
    @pdflite.pdf_dictionary([
      (
        text_font_write_name_for_test("/Type"),
        PdfNameObject(text_font_write_name_for_test("/Encoding")),
      ),
      (
        text_font_write_name_for_test("/Differences"),
        PdfArray([
          PdfInteger(65),
          PdfNameObject(text_font_write_name_for_test("/A")),
        ]),
      ),
    ]),
  )
  @test.assert_eq(
    doc
    .lookup_object_or_null(20)
    .lookup_immediate(text_font_write_name_for_test("/Encoding")),
    Some(PdfIndirect(1)),
  )
}

///|
test "PdfDocument write_font writes embedded TrueType fonts" {
  let doc = @pdflite.pdf_document_empty()
  let descriptor : @pdflite.PdfFontDescriptor = {
    ..text_font_write_descriptor_for_test(),
    ascent: 720.0,
    descent: -180.0,
    avgwidth: 501.0,
    maxwidth: 1000.0,
    flags: 32,
    fontbbox: { min_x: -10.0, min_y: -200.0, max_x: 500.0, max_y: 700.0 },
    italicangle: -12.0,
    capheight: 680.0,
    xheight: 450.0,
    stemv: 90.0,
    fontfile: Some(PdfFontFile2(9)),
  }
  let number = try! doc.write_font(
    PdfFontSimple({
      fonttype: PdfTrueType,
      basefont: Some(text_font_write_name_for_test("/Subset+Custom")),
      firstchar: 65,
      lastchar: 66,
      widths: [500, 610],
      fontdescriptor: Some(descriptor),
      fontmetrics: None,
      encoding: PdfFillUndefinedWithStandard(PdfWinAnsiEncoding),
    }),
  )
  @test.assert_eq(number, 2)
  @test.assert_eq(
    doc.lookup_object_or_null(1),
    @pdflite.pdf_dictionary([
      (
        text_font_write_name_for_test("/Type"),
        PdfNameObject(text_font_write_name_for_test("/FontDescriptor")),
      ),
      (
        text_font_write_name_for_test("/FontName"),
        PdfNameObject(text_font_write_name_for_test("/Subset+Custom")),
      ),
      (text_font_write_name_for_test("/Flags"), PdfInteger(32)),
      (
        text_font_write_name_for_test("/FontBBox"),
        PdfArray([
          PdfInteger(-10),
          PdfInteger(-200),
          PdfInteger(500),
          PdfInteger(700),
        ]),
      ),
      (text_font_write_name_for_test("/ItalicAngle"), PdfInteger(-12)),
      (text_font_write_name_for_test("/Ascent"), PdfInteger(720)),
      (text_font_write_name_for_test("/Descent"), PdfInteger(-180)),
      (text_font_write_name_for_test("/CapHeight"), PdfInteger(680)),
      (text_font_write_name_for_test("/StemV"), PdfInteger(90)),
      (text_font_write_name_for_test("/XHeight"), PdfInteger(450)),
      (text_font_write_name_for_test("/AvgWidth"), PdfInteger(501)),
      (text_font_write_name_for_test("/MaxWidth"), PdfInteger(1000)),
      (text_font_write_name_for_test("/FontFile2"), PdfIndirect(9)),
    ]),
  )
  @test.assert_eq(
    doc.lookup_object_or_null(number),
    @pdflite.pdf_dictionary([
      (
        text_font_write_name_for_test("/Type"),
        PdfNameObject(text_font_write_name_for_test("/Font")),
      ),
      (
        text_font_write_name_for_test("/Subtype"),
        PdfNameObject(text_font_write_name_for_test("/TrueType")),
      ),
      (
        text_font_write_name_for_test("/BaseFont"),
        PdfNameObject(text_font_write_name_for_test("/Subset+Custom")),
      ),
      (text_font_write_name_for_test("/FontDescriptor"), PdfIndirect(1)),
      (text_font_write_name_for_test("/FirstChar"), PdfInteger(65)),
      (text_font_write_name_for_test("/LastChar"), PdfInteger(66)),
      (
        text_font_write_name_for_test("/Widths"),
        PdfArray([PdfInteger(500), PdfInteger(610)]),
      ),
      (
        text_font_write_name_for_test("/Encoding"),
        PdfNameObject(text_font_write_name_for_test("/WinAnsiEncoding")),
      ),
    ]),
  )
}

///|
test "PdfDocument write_font places embedded TrueType fonts at requested object number" {
  let doc = @pdflite.pdf_document_empty()
  let descriptor : @pdflite.PdfFontDescriptor = {
    ..text_font_write_descriptor_for_test(),
    fontfile: Some(PdfFontFile2(7)),
  }
  let number = try! doc.write_font(
    PdfFontSimple({
      fonttype: PdfTrueType,
      basefont: Some(text_font_write_name_for_test("/Placed")),
      firstchar: 0,
      lastchar: 0,
      widths: [300],
      fontdescriptor: Some(descriptor),
      fontmetrics: None,
      encoding: PdfMacRomanEncoding,
    }),
    objnum=Some(20),
  )
  @test.assert_eq(number, 20)
  @test.assert_eq(
    doc
    .lookup_object_or_null(20)
    .lookup_immediate(text_font_write_name_for_test("/FontDescriptor")),
    Some(PdfIndirect(1)),
  )
  @test.assert_eq(
    doc
    .lookup_object_or_null(20)
    .lookup_immediate(text_font_write_name_for_test("/Encoding")),
    Some(PdfNameObject(text_font_write_name_for_test("/MacRomanEncoding"))),
  )
}

///|
test "PdfDocument write_font writes TrueType ToUnicode CMaps" {
  let doc = @pdflite.pdf_document_empty()
  let descriptor : @pdflite.PdfFontDescriptor = {
    ..text_font_write_descriptor_for_test(),
    fontfile: Some(PdfFontFile2(7)),
    tounicode: Some([
      (9, text_font_write_bytes_for_test([0x00, 0x42])),
      (3, text_font_write_bytes_for_test([0x00, 0x41])),
    ]),
  }
  let number = try! doc.write_font(
    PdfFontSimple({
      fonttype: PdfTrueType,
      basefont: Some(text_font_write_name_for_test("/WithToUnicode")),
      firstchar: 65,
      lastchar: 66,
      widths: [500, 610],
      fontdescriptor: Some(descriptor),
      fontmetrics: None,
      encoding: PdfWinAnsiEncoding,
    }),
  )
  @test.assert_eq(number, 3)
  @test.assert_eq(
    doc
    .lookup_object_or_null(3)
    .lookup_immediate(text_font_write_name_for_test("/ToUnicode")),
    Some(PdfIndirect(2)),
  )
  @test.assert_eq(
    doc
    .lookup_object_or_null(3)
    .lookup_immediate(text_font_write_name_for_test("/Encoding")),
    None,
  )
  guard doc.lookup_object_or_null(2) is PdfStreamObject(stream) else {
    fail("expected ToUnicode stream")
  }
  guard stream.data is StreamGot(bytes) else {
    fail("expected owned ToUnicode bytes")
  }
  @test.assert_eq(
    stream.dictionary.lookup_immediate(text_font_write_name_for_test("/Length")),
    Some(PdfInteger(bytes.length())),
  )
  @test.assert_eq(
    try! @ascii.decode(bytes),
    "/CIDInit /ProcSet findresource begin\n" +
    "12 dict begin\n" +
    "begincmap\n" +
    "/CIDSystemInfo <<\n" +
    "  /Registry (Adobe)\n" +
    "  /Ordering (UCS)\n" +
    "  /Supplement 0\n" +
    ">> def\n" +
    "/CMapName /Adobe-Identity-UCS def\n" +
    "/CMapType 2 def\n" +
    "1 begincodespacerange\n" +
    "<00><FF>\n" +
    "endcodespacerange\n" +
    "2 beginbfrange\n" +
    "<21><21><0041>\n" +
    "<22><22><0042>\n" +
    "endbfrange\n" +
    "endcmap\n" +
    "CMapName currentdict /CMap defineresource pop\n" +
    "end\n" +
    "end\n",
  )
  guard (try! doc.read_font(doc.lookup_object_or_null(number)))
    is PdfFontSimple(read) else {
    fail("expected simple TrueType font")
  }
  guard read.fontdescriptor is Some(read_descriptor) else {
    fail("expected read descriptor")
  }
  @test.assert_eq(
    read_descriptor.tounicode,
    Some([
      (33, text_font_write_bytes_for_test([0x00, 0x41])),
      (34, text_font_write_bytes_for_test([0x00, 0x42])),
    ]),
  )
  let extractor = try! doc.text_extractor_of_font(
    doc.lookup_object_or_null(number),
  )
  @test.assert_eq(
    try! extractor.codepoints_of_text(
      text_font_write_bytes_for_test([33, 34, 35]),
    ),
    [0x41, 0x42, 35],
  )
  @test.assert_eq(
    try! extractor.glyphnames_and_codepoints_of_text(
      text_font_write_bytes_for_test([33, 34, 35]),
    ),
    [
      {
        glyphname: @pdflite.pdf_name_of_bytes(
          text_font_write_bytes_for_test([47, 0x00, 0x41]),
        ),
        codepoints: [0x41],
      },
      {
        glyphname: @pdflite.pdf_name_of_bytes(
          text_font_write_bytes_for_test([47, 0x00, 0x42]),
        ),
        codepoints: [0x42],
      },
      { glyphname: text_font_write_name_for_test(".notdef"), codepoints: [35] },
    ],
  )
  @test.assert_eq(
    try! extractor.glyphnames_of_text(text_font_write_bytes_for_test([33, 35])),
    [
      @pdflite.pdf_name_of_bytes(
        text_font_write_bytes_for_test([47, 0x00, 0x41]),
      ),
      text_font_write_name_for_test(".notdef"),
    ],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x42), Some(34))
  @test.assert_eq(extractor.charcode_of_codepoint(0x43), None)
}
