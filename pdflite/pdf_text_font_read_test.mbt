///|
fn text_font_read_name_for_test(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn text_font_read_bytes_for_test(values : ArrayView[Int]) -> @core.PdfBytes {
  try! @core.pdf_bytes_of_int_array(values)
}

///|
fn text_font_read_standard_font_data_for_test(
  font : @pdflite.PdfStandardFont,
  encoding : @pdflite.PdfEncoding,
) -> @pdflite.PdfStandardFontData {
  { font, encoding }
}

///|
fn text_font_read_type3_charproc_stream_for_test(
  ops : ArrayView[@content.PdfContentOp],
) -> @syntax.PdfObject raise {
  let data = @pdflite.pdf_content_bytes_of_ops(ops)
  @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (text_font_read_name_for_test("/Length"), PdfInteger(data.length())),
    ]),
    StreamGot(data),
  )
}

///|
fn text_font_read_cid_system_info_object_for_test() -> @syntax.PdfObject {
  @syntax.pdf_dictionary([
    (
      text_font_read_name_for_test("/Registry"),
      PdfString(text_font_read_bytes_for_test([82])),
    ),
    (
      text_font_read_name_for_test("/Ordering"),
      PdfString(text_font_read_bytes_for_test([79])),
    ),
    (text_font_read_name_for_test("/Supplement"), PdfInteger(0)),
  ])
}

///|
fn text_font_read_valid_cid_descendant_for_test(
  extra : ArrayView[(@core.PdfName, @syntax.PdfObject)],
) -> @syntax.PdfObject {
  let entries : Array[(@core.PdfName, @syntax.PdfObject)] = [
    (
      text_font_read_name_for_test("/CIDSystemInfo"),
      text_font_read_cid_system_info_object_for_test(),
    ),
    (
      text_font_read_name_for_test("/BaseFont"),
      PdfNameObject(text_font_read_name_for_test("/Descendant")),
    ),
    (
      text_font_read_name_for_test("/FontDescriptor"),
      @syntax.pdf_dictionary([]),
    ),
  ]
  for entry in extra {
    entries.push(entry)
  }
  @syntax.pdf_dictionary(entries)
}

///|
fn text_font_read_cid_top_font_for_test(
  descendant_number : Int,
  encoding : @syntax.PdfObject,
) -> @syntax.PdfObject {
  @syntax.pdf_dictionary([
    (
      text_font_read_name_for_test("/BaseFont"),
      PdfNameObject(text_font_read_name_for_test("/T")),
    ),
    (
      text_font_read_name_for_test("/DescendantFonts"),
      PdfArray([PdfIndirect(descendant_number)]),
    ),
    (text_font_read_name_for_test("/Encoding"), encoding),
  ])
}

///|
test "PdfDocument read_font_descriptor parses metrics font files and charset" {
  let doc = @pdflite.pdf_document_empty()
  let descriptor = @syntax.pdf_dictionary([
    (
      text_font_read_name_for_test("/FontBBox"),
      PdfArray([
        PdfInteger(500),
        PdfInteger(-200),
        PdfInteger(-10),
        PdfInteger(700),
      ]),
    ),
    (text_font_read_name_for_test("/Ascent"), PdfInteger(720)),
    (text_font_read_name_for_test("/Descent"), PdfReal(-180.5)),
    (text_font_read_name_for_test("/AvgWidth"), PdfInteger(501)),
    (text_font_read_name_for_test("/MaxWidth"), PdfInteger(1000)),
    (text_font_read_name_for_test("/Flags"), PdfInteger(4)),
    (text_font_read_name_for_test("/ItalicAngle"), PdfReal(-12.5)),
    (text_font_read_name_for_test("/CapHeight"), PdfInteger(680)),
    (text_font_read_name_for_test("/XHeight"), PdfInteger(450)),
    (text_font_read_name_for_test("/StemV"), PdfInteger(90)),
    (text_font_read_name_for_test("/FontFile2"), PdfIndirect(42)),
    (
      text_font_read_name_for_test("/CharSet"),
      PdfString(
        text_font_read_bytes_for_test([
          47, 65, 32, 47, 66, 32, 47, 67, 32, 47, 32, 47, 68,
        ]),
      ),
    ),
  ])
  let font = @syntax.pdf_dictionary([
    (text_font_read_name_for_test("/FontDescriptor"), descriptor),
  ])
  guard (try! doc.read_font_descriptor(font)) is Some(read_descriptor) else {
    fail("expected font descriptor")
  }
  @test.assert_eq(read_descriptor.ascent, 720.0)
  @test.assert_eq(read_descriptor.descent, -180.5)
  @test.assert_eq(read_descriptor.avgwidth, 501.0)
  @test.assert_eq(read_descriptor.maxwidth, 1000.0)
  @test.assert_eq(read_descriptor.flags, 4)
  @test.assert_eq(read_descriptor.italicangle, -12.5)
  @test.assert_eq(read_descriptor.capheight, 680.0)
  @test.assert_eq(read_descriptor.xheight, 450.0)
  @test.assert_eq(read_descriptor.stemv, 90.0)
  @test.assert_eq(read_descriptor.fontbbox, {
    min_x: -10.0,
    min_y: -200.0,
    max_x: 500.0,
    max_y: 700.0,
  })
  @test.assert_eq(read_descriptor.fontfile, Some(PdfFontFile2(42)))
  @test.assert_eq(
    read_descriptor.charset,
    Some([
      text_font_read_name_for_test("/A"),
      text_font_read_name_for_test("/B"),
      text_font_read_name_for_test("/C"),
    ]),
  )
}

///|
test "PdfDocument read_font_descriptor uses CamlPDF defaults and fontfile priority" {
  let doc = @pdflite.pdf_document_empty()
  @test.assert_eq(
    try! doc.read_font_descriptor(@syntax.pdf_dictionary([])),
    None,
  )
  let descriptor = @syntax.pdf_dictionary([
    (text_font_read_name_for_test("/FontFile"), PdfIndirect(10)),
    (text_font_read_name_for_test("/FontFile2"), PdfIndirect(11)),
    (text_font_read_name_for_test("/CharSet"), PdfInteger(0)),
  ])
  let font = @syntax.pdf_dictionary([
    (text_font_read_name_for_test("/FontDescriptor"), descriptor),
  ])
  guard (try! doc.read_font_descriptor(font)) is Some(read_descriptor) else {
    fail("expected font descriptor")
  }
  @test.assert_eq(read_descriptor.fontbbox, {
    min_x: 0.0,
    min_y: 0.0,
    max_x: 0.0,
    max_y: 0.0,
  })
  @test.assert_eq(read_descriptor.ascent, 0.0)
  @test.assert_eq(read_descriptor.fontfile, Some(PdfFontFile(10)))
  @test.assert_eq(read_descriptor.charset, None)
}

///|
test "PdfDocument read_font_descriptor accepts FontFile3 and stops malformed charset" {
  let doc = @pdflite.pdf_document_empty()
  let descriptor = @syntax.pdf_dictionary([
    (text_font_read_name_for_test("/FontFile3"), PdfIndirect(12)),
    (text_font_read_name_for_test("/CharSet"), PdfString(b"/A 7 /B")),
  ])
  let font = @syntax.pdf_dictionary([
    (text_font_read_name_for_test("/FontDescriptor"), descriptor),
  ])
  guard (try! doc.read_font_descriptor(font)) is Some(read_descriptor) else {
    fail("expected font descriptor")
  }
  @test.assert_eq(read_descriptor.fontfile, Some(PdfFontFile3(12)))
  @test.assert_eq(
    read_descriptor.charset,
    Some([text_font_read_name_for_test("/A")]),
  )
}

///|
test "PdfDocument read_font_metrics builds 256-entry width table" {
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(7, PdfInteger(620))
  let descriptor = @syntax.pdf_dictionary([
    (text_font_read_name_for_test("/MissingWidth"), PdfInteger(250)),
  ])
  let font = @syntax.pdf_dictionary([
    (text_font_read_name_for_test("/FontDescriptor"), descriptor),
    (text_font_read_name_for_test("/FirstChar"), PdfInteger(65)),
    (text_font_read_name_for_test("/LastChar"), PdfInteger(67)),
    (
      text_font_read_name_for_test("/Widths"),
      PdfArray([PdfInteger(600), PdfReal(610.5), PdfIndirect(7)]),
    ),
  ])
  guard (try! doc.read_font_metrics(font)) is Some(metrics) else {
    fail("expected font metrics")
  }
  @test.assert_eq(metrics.length(), 256)
  @test.assert_eq(metrics[0], 250.0)
  @test.assert_eq(metrics[64], 250.0)
  @test.assert_eq(metrics[65], 600.0)
  @test.assert_eq(metrics[66], 610.5)
  @test.assert_eq(metrics[67], 620.0)
  @test.assert_eq(metrics[68], 250.0)
  @test.assert_eq(metrics[255], 250.0)
}

///|
test "PdfDocument read_font_metrics handles Type3 fonts and malformed widths" {
  let doc = @pdflite.pdf_document_empty()
  @test.assert_eq(try! doc.read_font_metrics(@syntax.pdf_dictionary([])), None)
  let type3 = @syntax.pdf_dictionary([
    (
      text_font_read_name_for_test("/Subtype"),
      PdfNameObject(text_font_read_name_for_test("/Type3")),
    ),
    (text_font_read_name_for_test("/MissingWidth"), PdfReal(5.5)),
    (text_font_read_name_for_test("/FirstChar"), PdfInteger(0)),
    (text_font_read_name_for_test("/LastChar"), PdfInteger(0)),
    (text_font_read_name_for_test("/Widths"), PdfArray([PdfInteger(9)])),
  ])
  guard (try! doc.read_font_metrics(type3)) is Some(type3_metrics) else {
    fail("expected type3 metrics")
  }
  @test.assert_eq(type3_metrics[0], 9.0)
  @test.assert_eq(type3_metrics[1], 5.5)

  let malformed = @syntax.pdf_dictionary([
    (
      text_font_read_name_for_test("/FontDescriptor"),
      @syntax.pdf_dictionary([]),
    ),
    (text_font_read_name_for_test("/FirstChar"), PdfInteger(65)),
    (text_font_read_name_for_test("/LastChar"), PdfInteger(66)),
    (text_font_read_name_for_test("/Widths"), PdfArray([PdfInteger(600)])),
  ])
  let malformed_result = try doc.read_font_metrics(malformed) catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard malformed_result is Err(FontWidthsExpected) else {
    fail("expected @core.PdfError::FontWidthsExpected")
  }

  let bad_width = @syntax.pdf_dictionary([
    (
      text_font_read_name_for_test("/FontDescriptor"),
      @syntax.pdf_dictionary([]),
    ),
    (text_font_read_name_for_test("/FirstChar"), PdfInteger(65)),
    (text_font_read_name_for_test("/LastChar"), PdfInteger(65)),
    (
      text_font_read_name_for_test("/Widths"),
      PdfArray([PdfNameObject(text_font_read_name_for_test("/Bad"))]),
    ),
  ])
  let bad_width_result = try doc.read_font_metrics(bad_width) catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_width_result is Err(FontWidthExpected) else {
    fail("expected @core.PdfError::FontWidthExpected")
  }

  let bad_firstchar = @syntax.pdf_dictionary([
    (
      text_font_read_name_for_test("/FontDescriptor"),
      @syntax.pdf_dictionary([]),
    ),
    (text_font_read_name_for_test("/FirstChar"), PdfInteger(-1)),
    (text_font_read_name_for_test("/LastChar"), PdfInteger(65)),
    (text_font_read_name_for_test("/Widths"), PdfArray([PdfInteger(600)])),
  ])
  let bad_firstchar_result = try doc.read_font_metrics(bad_firstchar) catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_firstchar_result is Err(FontFirstCharExpected) else {
    fail("expected @core.PdfError::FontFirstCharExpected")
  }

  let missing_widths = @syntax.pdf_dictionary([
    (
      text_font_read_name_for_test("/FontDescriptor"),
      @syntax.pdf_dictionary([]),
    ),
    (text_font_read_name_for_test("/FirstChar"), PdfInteger(65)),
    (text_font_read_name_for_test("/LastChar"), PdfInteger(65)),
  ])
  let missing_widths_result = try doc.read_font_metrics(missing_widths) catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard missing_widths_result is Err(FontWidthsExpected) else {
    fail("expected @core.PdfError::FontWidthsExpected for missing widths")
  }

  let inverted_bounds = @syntax.pdf_dictionary([
    (
      text_font_read_name_for_test("/FontDescriptor"),
      @syntax.pdf_dictionary([]),
    ),
    (text_font_read_name_for_test("/FirstChar"), PdfInteger(66)),
    (text_font_read_name_for_test("/LastChar"), PdfInteger(65)),
    (text_font_read_name_for_test("/Widths"), PdfArray([])),
  ])
  let inverted_bounds_result = try
    doc.read_font_metrics(inverted_bounds)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard inverted_bounds_result is Err(FontWidthsExpected) else {
    fail("expected @core.PdfError::FontWidthsExpected for inverted bounds")
  }
}

///|
test "PdfDocument read_simple_font builds Type1 font records" {
  let doc = @pdflite.pdf_document_empty()
  let descriptor = @syntax.pdf_dictionary([
    (text_font_read_name_for_test("/Ascent"), PdfInteger(700)),
    (text_font_read_name_for_test("/FontFile2"), PdfIndirect(9)),
    (text_font_read_name_for_test("/MissingWidth"), PdfInteger(250)),
  ])
  let font = @syntax.pdf_dictionary([
    (
      text_font_read_name_for_test("/Subtype"),
      PdfNameObject(text_font_read_name_for_test("/Type1")),
    ),
    (
      text_font_read_name_for_test("/BaseFont"),
      PdfNameObject(text_font_read_name_for_test("/CustomFont")),
    ),
    (text_font_read_name_for_test("/FontDescriptor"), descriptor),
    (text_font_read_name_for_test("/FirstChar"), PdfInteger(65)),
    (text_font_read_name_for_test("/LastChar"), PdfInteger(65)),
    (text_font_read_name_for_test("/Widths"), PdfArray([PdfInteger(500)])),
    (
      text_font_read_name_for_test("/Encoding"),
      PdfNameObject(text_font_read_name_for_test("/WinAnsiEncoding")),
    ),
  ])
  let simple = try! doc.read_simple_font(font)
  @test.assert_eq(simple.fonttype, PdfType1)
  @test.assert_eq(
    simple.basefont,
    Some(text_font_read_name_for_test("/CustomFont")),
  )
  @test.assert_eq(simple.firstchar, 0)
  @test.assert_eq(simple.lastchar, 0)
  @test.assert_eq(simple.widths, [])
  @test.assert_eq(simple.encoding, PdfWinAnsiEncoding)
  @test.assert_eq(
    simple.debug_name(),
    "fonttype = Type 1\nbasefont /CustomFont\nencoding is WinAnsiEncoding\n",
  )
  guard simple.fontdescriptor is Some(fontdescriptor) else {
    fail("expected font descriptor")
  }
  @test.assert_eq(fontdescriptor.ascent, 700.0)
  @test.assert_eq(fontdescriptor.fontfile, Some(PdfFontFile2(9)))
  guard simple.fontmetrics is Some(metrics) else {
    fail("expected font metrics")
  }
  @test.assert_eq(metrics.length(), 256)
  @test.assert_eq(metrics[65], 500.0)
  @test.assert_eq(metrics[64], 250.0)
}

///|
test "PdfDocument read_simple_font reads Type3 glyph data" {
  let doc = @pdflite.pdf_document_empty()
  let font = @syntax.pdf_dictionary([
    (
      text_font_read_name_for_test("/Subtype"),
      PdfNameObject(text_font_read_name_for_test("/Type3")),
    ),
    (text_font_read_name_for_test("/FontBBox"), PdfArray([PdfInteger(1)])),
    (
      text_font_read_name_for_test("/FontMatrix"),
      PdfArray([
        PdfInteger(1),
        PdfInteger(0),
        PdfInteger(0),
        PdfInteger(1),
        PdfInteger(2),
        PdfInteger(3),
      ]),
    ),
    (
      text_font_read_name_for_test("/CharProcs"),
      @syntax.pdf_dictionary([
        (text_font_read_name_for_test("/A"), PdfInteger(1)),
        (text_font_read_name_for_test("/B"), PdfInteger(2)),
      ]),
    ),
    (text_font_read_name_for_test("/MissingWidth"), PdfReal(5.5)),
    (text_font_read_name_for_test("/FirstChar"), PdfInteger(0)),
    (text_font_read_name_for_test("/LastChar"), PdfInteger(0)),
    (text_font_read_name_for_test("/Widths"), PdfArray([PdfInteger(9)])),
    (
      text_font_read_name_for_test("/Encoding"),
      PdfNameObject(text_font_read_name_for_test("/MacRomanEncoding")),
    ),
  ])
  let simple = try! doc.read_simple_font(font)
  guard simple.fonttype is PdfType3(type3_data) else {
    fail("expected Type3 font")
  }
  @test.assert_eq(type3_data.fontbbox, {
    min_x: 0.0,
    min_y: 0.0,
    max_x: 0.0,
    max_y: 0.0,
  })
  @test.assert_eq(type3_data.fontmatrix, {
    a: 1.0,
    b: 0.0,
    c: 0.0,
    d: 1.0,
    e: 2.0,
    f: 3.0,
  })
  @test.assert_eq(type3_data.charprocs, [
    (text_font_read_name_for_test("/A"), PdfInteger(1)),
    (text_font_read_name_for_test("/B"), PdfInteger(2)),
  ])
  @test.assert_eq(type3_data.resources, @syntax.pdf_dictionary([]))
  @test.assert_eq(simple.encoding, PdfMacRomanEncoding)
  @test.assert_eq(simple.fonttype.debug_name(), "Type 3: charprocs for/A/B")
}

///|
test "PdfDocument read_simple_font preserves direct Type3 CharProc streams" {
  let doc = @pdflite.pdf_document_empty()
  let d0_stream = text_font_read_type3_charproc_stream_for_test([
    Op_d0(500.0, 0.0),
  ])
  let d1_stream = text_font_read_type3_charproc_stream_for_test([
    Op_d1(600.0, 0.0, 0.0, -20.0, 600.0, 700.0),
  ])
  let font = @syntax.pdf_dictionary([
    (
      text_font_read_name_for_test("/Subtype"),
      PdfNameObject(text_font_read_name_for_test("/Type3")),
    ),
    (
      text_font_read_name_for_test("/CharProcs"),
      @syntax.pdf_dictionary([
        (text_font_read_name_for_test("/A"), d0_stream),
        (text_font_read_name_for_test("/B"), d1_stream),
      ]),
    ),
    (text_font_read_name_for_test("/FirstChar"), PdfInteger(65)),
    (text_font_read_name_for_test("/LastChar"), PdfInteger(66)),
    (
      text_font_read_name_for_test("/Widths"),
      PdfArray([PdfInteger(500), PdfInteger(600)]),
    ),
  ])
  let simple = doc.read_simple_font(font)
  guard simple.fonttype is PdfType3(type3_data) else {
    fail("expected Type3 font")
  }
  @test.assert_eq(type3_data.charprocs, [
    (text_font_read_name_for_test("/A"), d0_stream),
    (text_font_read_name_for_test("/B"), d1_stream),
  ])
  @test.assert_eq(
    @pdflite.pdf_parse_content_ops_from_bytes(
      type3_data.charprocs[0].1.stream_bytes(),
    ),
    [Op_d0(500.0, 0.0)],
  )
  @test.assert_eq(
    @pdflite.pdf_parse_content_ops_from_bytes(
      type3_data.charprocs[1].1.stream_bytes(),
    ),
    [Op_d1(600.0, 0.0, 0.0, -20.0, 600.0, 700.0)],
  )
  guard simple.fontmetrics is Some(metrics) else {
    fail("expected Type3 metrics")
  }
  @test.assert_eq(metrics[65], 500.0)
  @test.assert_eq(metrics[66], 600.0)
}

///|
test "PdfDocument read_simple_font covers MMType1 TrueType and Type3 resources" {
  let doc = @pdflite.pdf_document_empty()
  let mm_type1 = try! doc.read_simple_font(
    @syntax.pdf_dictionary([
      (
        text_font_read_name_for_test("/Subtype"),
        PdfNameObject(text_font_read_name_for_test("/MMType1")),
      ),
    ]),
  )
  @test.assert_eq(mm_type1.fonttype, PdfMMType1)
  @test.assert_eq(
    mm_type1.debug_name(),
    "fonttype = MM Type 1\nbasefont \nencoding is ImplicitInFontFile\n",
  )

  let true_type = try! doc.read_simple_font(
    @syntax.pdf_dictionary([
      (
        text_font_read_name_for_test("/Subtype"),
        PdfNameObject(text_font_read_name_for_test("/TrueType")),
      ),
    ]),
  )
  @test.assert_eq(true_type.fonttype, PdfTrueType)
  @test.assert_eq(true_type.fonttype.debug_name(), "Truetype")

  let resources = @syntax.pdf_dictionary([
    (text_font_read_name_for_test("/ProcSet"), PdfArray([])),
  ])
  let type3 = try! doc.read_simple_font(
    @syntax.pdf_dictionary([
      (
        text_font_read_name_for_test("/Subtype"),
        PdfNameObject(text_font_read_name_for_test("/Type3")),
      ),
      (
        text_font_read_name_for_test("/CharProcs"),
        @syntax.pdf_dictionary([
          (text_font_read_name_for_test("/A"), PdfInteger(1)),
        ]),
      ),
      (text_font_read_name_for_test("/Resources"), resources),
      (text_font_read_name_for_test("/FirstChar"), PdfInteger(0)),
      (text_font_read_name_for_test("/LastChar"), PdfInteger(0)),
      (text_font_read_name_for_test("/Widths"), PdfArray([PdfInteger(9)])),
    ]),
  )
  guard type3.fonttype is PdfType3(type3_data) else {
    fail("expected Type3 font")
  }
  @test.assert_eq(type3_data.resources, resources)
}

///|
test "PdfDocument read_simple_font rejects malformed simple fonts" {
  let doc = @pdflite.pdf_document_empty()
  let missing_subtype = try
    doc.read_simple_font(@syntax.pdf_dictionary([]))
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard missing_subtype is Err(FontSubtypeExpected) else {
    fail("expected @core.PdfError::FontSubtypeExpected for missing subtype")
  }
  let unknown_subtype = try
    doc.read_simple_font(
      @syntax.pdf_dictionary([
        (
          text_font_read_name_for_test("/Subtype"),
          PdfNameObject(text_font_read_name_for_test("/CIDFontType2")),
        ),
      ]),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard unknown_subtype is Err(FontSubtypeExpected) else {
    fail("expected @core.PdfError::FontSubtypeExpected for unknown subtype")
  }
  let missing_charprocs = try
    doc.read_simple_font(
      @syntax.pdf_dictionary([
        (
          text_font_read_name_for_test("/Subtype"),
          PdfNameObject(text_font_read_name_for_test("/Type3")),
        ),
      ]),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard missing_charprocs is Err(FontCharProcsExpected) else {
    fail("expected @core.PdfError::FontCharProcsExpected")
  }
}

///|
test "PdfDocument detects and reads standard14 fonts" {
  let doc = @pdflite.pdf_document_empty()
  let font = @syntax.pdf_dictionary([
    (
      text_font_read_name_for_test("/Subtype"),
      PdfNameObject(text_font_read_name_for_test("/Type1")),
    ),
    (
      text_font_read_name_for_test("/BaseFont"),
      PdfNameObject(text_font_read_name_for_test("/Arial,Bold")),
    ),
    (
      text_font_read_name_for_test("/Encoding"),
      PdfNameObject(text_font_read_name_for_test("/WinAnsiEncoding")),
    ),
  ])
  @test.assert_eq(doc.is_standard14_font(font), true)
  @test.assert_eq(doc.is_simple_font(font), true)
  let standard = try! doc.read_standard14_font(font)
  @test.assert_eq(
    standard,
    text_font_read_standard_font_data_for_test(
      PdfHelveticaBold,
      PdfWinAnsiEncoding,
    ),
  )
  @test.assert_eq(standard.debug_name(), "StandardFont Helvetica-Bold")
  let overridden = @syntax.pdf_dictionary([
    (
      text_font_read_name_for_test("/Subtype"),
      PdfNameObject(text_font_read_name_for_test("/Type1")),
    ),
    (
      text_font_read_name_for_test("/BaseFont"),
      PdfNameObject(text_font_read_name_for_test("/Helvetica")),
    ),
    (text_font_read_name_for_test("/Widths"), PdfArray([])),
  ])
  @test.assert_eq(doc.is_standard14_font(overridden), false)
  let true_type_alias = @syntax.pdf_dictionary([
    (
      text_font_read_name_for_test("/Subtype"),
      PdfNameObject(text_font_read_name_for_test("/TrueType")),
    ),
    (
      text_font_read_name_for_test("/BaseFont"),
      PdfNameObject(text_font_read_name_for_test("/Helvetica")),
    ),
  ])
  @test.assert_eq(doc.is_standard14_font(true_type_alias), true)
  let wrong_subtype = @syntax.pdf_dictionary([
    (
      text_font_read_name_for_test("/Subtype"),
      PdfNameObject(text_font_read_name_for_test("/CIDFontType2")),
    ),
    (
      text_font_read_name_for_test("/BaseFont"),
      PdfNameObject(text_font_read_name_for_test("/Helvetica")),
    ),
  ])
  @test.assert_eq(doc.is_standard14_font(wrong_subtype), false)
  @test.assert_eq(doc.is_simple_font(wrong_subtype), false)
  let missing_base = @syntax.pdf_dictionary([
    (
      text_font_read_name_for_test("/Subtype"),
      PdfNameObject(text_font_read_name_for_test("/Type1")),
    ),
  ])
  @test.assert_eq(doc.is_standard14_font(missing_base), false)
  @test.assert_eq(doc.is_simple_font(@syntax.pdf_dictionary([])), false)
  @test.assert_eq(doc.is_cidkeyed_font(@syntax.pdf_dictionary([])), false)
}

///|
test "PdfDocument read_standard14_font rejects bad base fonts" {
  let doc = @pdflite.pdf_document_empty()
  let unknown = @syntax.pdf_dictionary([
    (
      text_font_read_name_for_test("/BaseFont"),
      PdfNameObject(text_font_read_name_for_test("/NotStandard")),
    ),
  ])
  let unknown_result = try doc.read_standard14_font(unknown) catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard unknown_result is Err(StandardFontExpected) else {
    fail("expected @core.PdfError::StandardFontExpected")
  }
  let missing_result = try
    doc.read_standard14_font(@syntax.pdf_dictionary([]))
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard missing_result is Err(BaseFontExpected) else {
    fail("expected @core.PdfError::BaseFontExpected")
  }
}

///|
test "PdfDocument read_font dispatches standard14 and simple fonts" {
  let doc = @pdflite.pdf_document_empty()
  let standard = @syntax.pdf_dictionary([
    (
      text_font_read_name_for_test("/Subtype"),
      PdfNameObject(text_font_read_name_for_test("/TrueType")),
    ),
    (
      text_font_read_name_for_test("/BaseFont"),
      PdfNameObject(text_font_read_name_for_test("/Helvetica")),
    ),
    (
      text_font_read_name_for_test("/Encoding"),
      PdfNameObject(text_font_read_name_for_test("/MacRomanEncoding")),
    ),
  ])
  @test.assert_eq(
    try! doc.read_font(standard),
    PdfFontStandard(
      text_font_read_standard_font_data_for_test(
        PdfHelvetica,
        PdfMacRomanEncoding,
      ),
    ),
  )
  @test.assert_eq(
    (try! doc.read_font(standard)).debug_name(),
    "StandardFont Helvetica",
  )

  let simple = @syntax.pdf_dictionary([
    (
      text_font_read_name_for_test("/Subtype"),
      PdfNameObject(text_font_read_name_for_test("/Type1")),
    ),
    (
      text_font_read_name_for_test("/BaseFont"),
      PdfNameObject(text_font_read_name_for_test("/CustomFont")),
    ),
    (
      text_font_read_name_for_test("/Encoding"),
      PdfNameObject(text_font_read_name_for_test("/WinAnsiEncoding")),
    ),
  ])
  @test.assert_eq(
    try! doc.read_font(simple),
    PdfFontSimple({
      fonttype: PdfType1,
      basefont: Some(text_font_read_name_for_test("/CustomFont")),
      firstchar: 0,
      lastchar: 0,
      widths: [],
      fontdescriptor: None,
      fontmetrics: None,
      encoding: PdfWinAnsiEncoding,
    }),
  )
  @test.assert_eq(
    (try! doc.read_font(simple)).debug_name(),
    "SimpleFont fonttype = Type 1\nbasefont /CustomFont\nencoding is WinAnsiEncoding\n",
  )
}

///|
test "PdfDocument read_font rejects unknown fonts" {
  let doc = @pdflite.pdf_document_empty()
  let unknown = @syntax.pdf_dictionary([
    (
      text_font_read_name_for_test("/Subtype"),
      PdfNameObject(text_font_read_name_for_test("/CIDFontType2")),
    ),
  ])
  let unknown_result = try doc.read_font(unknown) catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard unknown_result is Err(FontTypeExpected) else {
    fail("expected @core.PdfError::FontTypeExpected")
  }
}

///|
test "PdfDocument read_font reads CID-keyed Type0 fonts" {
  let doc = @pdflite.pdf_document_empty()
  let descendant = @syntax.pdf_dictionary([
    (
      text_font_read_name_for_test("/CIDSystemInfo"),
      @syntax.pdf_dictionary([
        (
          text_font_read_name_for_test("/Registry"),
          PdfString(text_font_read_bytes_for_test([65, 100, 111, 98, 101])),
        ),
        (
          text_font_read_name_for_test("/Ordering"),
          PdfString(
            text_font_read_bytes_for_test([
              73, 100, 101, 110, 116, 105, 116, 121,
            ]),
          ),
        ),
        (text_font_read_name_for_test("/Supplement"), PdfInteger(0)),
      ]),
    ),
    (
      text_font_read_name_for_test("/BaseFont"),
      PdfNameObject(text_font_read_name_for_test("/DescendantFont")),
    ),
    (
      text_font_read_name_for_test("/FontDescriptor"),
      @syntax.pdf_dictionary([
        (text_font_read_name_for_test("/Ascent"), PdfInteger(880)),
      ]),
    ),
    (
      text_font_read_name_for_test("/W"),
      PdfArray([
        PdfInteger(1),
        PdfArray([PdfInteger(500), PdfReal(501.5)]),
        PdfInteger(10),
        PdfInteger(12),
        PdfInteger(600),
      ]),
    ),
    (
      text_font_read_name_for_test("/W2"),
      PdfArray([
        PdfInteger(20),
        PdfArray([
          PdfInteger(100),
          PdfInteger(1),
          PdfInteger(2),
          PdfInteger(200),
          PdfInteger(3),
          PdfInteger(4),
        ]),
        PdfInteger(30),
        PdfInteger(31),
        PdfInteger(900),
        PdfInteger(5),
        PdfInteger(6),
      ]),
    ),
    (text_font_read_name_for_test("/DW"), PdfInteger(1001)),
    (
      text_font_read_name_for_test("/DW2"),
      PdfArray([PdfInteger(880), PdfReal(-1000.5)]),
    ),
  ])
  doc.add_object_given_number(33, descendant)
  let font = @syntax.pdf_dictionary([
    (
      text_font_read_name_for_test("/Subtype"),
      PdfNameObject(text_font_read_name_for_test("/Type0")),
    ),
    (
      text_font_read_name_for_test("/BaseFont"),
      PdfNameObject(text_font_read_name_for_test("/TopFont")),
    ),
    (
      text_font_read_name_for_test("/DescendantFonts"),
      PdfArray([PdfIndirect(33)]),
    ),
    (
      text_font_read_name_for_test("/Encoding"),
      PdfNameObject(text_font_read_name_for_test("/Identity-H")),
    ),
  ])
  @test.assert_eq(doc.is_cidkeyed_font(font), true)
  guard (try! doc.read_font(font)) is PdfFontCIDKeyed(cid_font) else {
    fail("expected CID-keyed font")
  }
  @test.assert_eq(cid_font.debug_name(), "CIDKeyedFont /TopFont")
  @test.assert_eq(cid_font.basefont, text_font_read_name_for_test("/TopFont"))
  @test.assert_eq(
    cid_font.encoding,
    PdfPredefinedCMap(text_font_read_name_for_test("/Identity-H")),
  )
  @test.assert_eq(cid_font.encoding.is_identity_h(), true)
  @test.assert_eq(cid_font.encoding.is_identity_v(), false)
  @test.assert_eq(cid_font.encoding.uses_two_byte_codes(), true)
  @test.assert_eq(cid_font.is_identity_h(), true)
  @test.assert_eq(cid_font.is_identity_v(), false)
  @test.assert_eq(cid_font.uses_two_byte_codes(), true)
  let cid_font_value : @pdflite.PdfFont = PdfFontCIDKeyed(cid_font)
  @test.assert_eq(cid_font_value.is_identity_h(), true)
  @test.assert_eq(cid_font_value.is_identity_v(), false)
  @test.assert_eq(cid_font_value.uses_two_byte_codes(), true)
  let identity_v : @pdflite.PdfCMapEncoding = PdfPredefinedCMap(
    text_font_read_name_for_test("/Identity-V"),
  )
  @test.assert_eq(identity_v.is_identity_h(), false)
  @test.assert_eq(identity_v.is_identity_v(), true)
  @test.assert_eq(identity_v.uses_two_byte_codes(), true)
  let ucs2_font = @syntax.pdf_dictionary([
    (
      text_font_read_name_for_test("/Subtype"),
      PdfNameObject(text_font_read_name_for_test("/Type0")),
    ),
    (
      text_font_read_name_for_test("/BaseFont"),
      PdfNameObject(text_font_read_name_for_test("/TopFontUCS2")),
    ),
    (
      text_font_read_name_for_test("/DescendantFonts"),
      PdfArray([PdfIndirect(33)]),
    ),
    (
      text_font_read_name_for_test("/Encoding"),
      PdfNameObject(text_font_read_name_for_test("/UniJIS-UCS2-H")),
    ),
  ])
  guard (try! doc.read_font(ucs2_font)) is PdfFontCIDKeyed(ucs2_cid_font) else {
    fail("expected UCS2 CID-keyed font")
  }
  @test.assert_eq(ucs2_cid_font.encoding.is_identity_h(), false)
  @test.assert_eq(ucs2_cid_font.encoding.is_identity_v(), false)
  @test.assert_eq(ucs2_cid_font.encoding.uses_two_byte_codes(), true)
  let utf16_font = @syntax.pdf_dictionary([
    (
      text_font_read_name_for_test("/Subtype"),
      PdfNameObject(text_font_read_name_for_test("/Type0")),
    ),
    (
      text_font_read_name_for_test("/BaseFont"),
      PdfNameObject(text_font_read_name_for_test("/TopFontUTF16")),
    ),
    (
      text_font_read_name_for_test("/DescendantFonts"),
      PdfArray([PdfIndirect(33)]),
    ),
    (
      text_font_read_name_for_test("/Encoding"),
      PdfNameObject(text_font_read_name_for_test("/UniJIS-UTF16-V")),
    ),
  ])
  guard (try! doc.read_font(utf16_font)) is PdfFontCIDKeyed(utf16_cid_font) else {
    fail("expected UTF16 CID-keyed font")
  }
  @test.assert_eq(utf16_cid_font.encoding.is_identity_h(), false)
  @test.assert_eq(utf16_cid_font.encoding.is_identity_v(), false)
  @test.assert_eq(utf16_cid_font.encoding.uses_two_byte_codes(), true)
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_font_read_standard_font_data_for_test(PdfHelvetica, PdfWinAnsiEncoding),
  )
  @test.assert_eq(standard_font.is_identity_h(), false)
  @test.assert_eq(standard_font.is_identity_v(), false)
  @test.assert_eq(standard_font.uses_two_byte_codes(), false)
  let composite = cid_font.composite
  @test.assert_eq(
    composite.cid_basefont,
    text_font_read_name_for_test("/DescendantFont"),
  )
  @test.assert_eq(
    composite.cid_system_info.registry,
    text_font_read_bytes_for_test([65, 100, 111, 98, 101]),
  )
  @test.assert_eq(
    composite.cid_system_info.ordering,
    text_font_read_bytes_for_test([73, 100, 101, 110, 116, 105, 116, 121]),
  )
  @test.assert_eq(composite.cid_system_info.supplement, 0)
  @test.assert_eq(composite.cid_fontdescriptor.ascent, 880.0)
  @test.assert_eq(composite.cid_widths, [
    (1, 500.0),
    (2, 501.5),
    (10, 600.0),
    (11, 600.0),
    (12, 600.0),
  ])
  @test.assert_eq(composite.cid_widths2, [
    (20, { width: 100.0, vx: 1.0, vy: 2.0 }),
    (21, { width: 200.0, vx: 3.0, vy: 4.0 }),
    (30, { width: 900.0, vx: 5.0, vy: 6.0 }),
    (31, { width: 900.0, vx: 5.0, vy: 6.0 }),
  ])
  @test.assert_eq(composite.cid_default_width, 1001.0)
  @test.assert_eq(composite.cid_default_width2, [880.0, -1000.5])
}

///|
test "PdfDocument read_cidkeyed_font supports indirect CMap streams" {
  let doc = @pdflite.pdf_document_empty()
  let descendant = @syntax.pdf_dictionary([
    (
      text_font_read_name_for_test("/CIDSystemInfo"),
      @syntax.pdf_dictionary([
        (
          text_font_read_name_for_test("/Registry"),
          PdfString(text_font_read_bytes_for_test([82])),
        ),
        (
          text_font_read_name_for_test("/Ordering"),
          PdfString(text_font_read_bytes_for_test([79])),
        ),
        (text_font_read_name_for_test("/Supplement"), PdfInteger(1)),
      ]),
    ),
    (
      text_font_read_name_for_test("/BaseFont"),
      PdfNameObject(text_font_read_name_for_test("/Descendant")),
    ),
    (
      text_font_read_name_for_test("/FontDescriptor"),
      @syntax.pdf_dictionary([]),
    ),
  ])
  let cmap = @syntax.pdf_stream(
    @syntax.pdf_dictionary([]),
    StreamGot(text_font_read_bytes_for_test([1, 2, 3])),
  )
  doc.add_object_given_number(4, descendant)
  doc.add_object_given_number(5, cmap)
  let font = @syntax.pdf_dictionary([
    (
      text_font_read_name_for_test("/BaseFont"),
      PdfNameObject(text_font_read_name_for_test("/Top")),
    ),
    (
      text_font_read_name_for_test("/DescendantFonts"),
      PdfArray([PdfIndirect(4)]),
    ),
    (text_font_read_name_for_test("/Encoding"), PdfIndirect(5)),
  ])
  @test.assert_eq(try! doc.read_cidkeyed_font(font), {
    basefont: text_font_read_name_for_test("/Top"),
    composite: {
      cid_system_info: {
        registry: text_font_read_bytes_for_test([82]),
        ordering: text_font_read_bytes_for_test([79]),
        supplement: 1,
      },
      cid_basefont: text_font_read_name_for_test("/Descendant"),
      cid_fontdescriptor: {
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
      },
      cid_widths: [],
      cid_widths2: [],
      cid_default_width: 1000.0,
      cid_default_width2: [880.0, -1000.0],
    },
    encoding: PdfExternalCMap(5, {
      map: [],
      cid_map: [],
      notdef_map: [],
      codespaces: [],
      usecmap: None,
      wmode: None,
      cmap_name: None,
      cmap_type: None,
      cid_system_info: None,
    }),
  })
}

///|
test "PdfDocument read_cidkeyed_font rejects malformed CID data" {
  let doc = @pdflite.pdf_document_empty()
  let missing_basefont = try
    doc.read_cidkeyed_font(@syntax.pdf_dictionary([]))
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard missing_basefont is Err(BaseFontExpected) else {
    fail("expected @core.PdfError::BaseFontExpected")
  }
  let missing_descendant = try
    doc.read_cidkeyed_font(
      @syntax.pdf_dictionary([
        (
          text_font_read_name_for_test("/BaseFont"),
          PdfNameObject(text_font_read_name_for_test("/T")),
        ),
      ]),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard missing_descendant is Err(DescendantFontExpected) else {
    fail("expected @core.PdfError::DescendantFontExpected")
  }

  let bad_supplement = try
    doc.read_cid_system_info(
      @syntax.pdf_dictionary([
        (
          text_font_read_name_for_test("/Registry"),
          PdfString(text_font_read_bytes_for_test([82])),
        ),
        (
          text_font_read_name_for_test("/Ordering"),
          PdfString(text_font_read_bytes_for_test([79])),
        ),
      ]),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_supplement is Err(CIDSupplementExpected) else {
    fail("expected @core.PdfError::CIDSupplementExpected")
  }

  let bad_system_info = @syntax.pdf_dictionary([
    (
      text_font_read_name_for_test("/CIDSystemInfo"),
      @syntax.pdf_dictionary([
        (
          text_font_read_name_for_test("/Ordering"),
          PdfString(text_font_read_bytes_for_test([79])),
        ),
        (text_font_read_name_for_test("/Supplement"), PdfInteger(0)),
      ]),
    ),
    (
      text_font_read_name_for_test("/BaseFont"),
      PdfNameObject(text_font_read_name_for_test("/Descendant")),
    ),
    (
      text_font_read_name_for_test("/FontDescriptor"),
      @syntax.pdf_dictionary([]),
    ),
  ])
  doc.add_object_given_number(6, bad_system_info)
  let bad_system_font = @syntax.pdf_dictionary([
    (
      text_font_read_name_for_test("/BaseFont"),
      PdfNameObject(text_font_read_name_for_test("/T")),
    ),
    (
      text_font_read_name_for_test("/DescendantFonts"),
      PdfArray([PdfIndirect(6)]),
    ),
    (
      text_font_read_name_for_test("/Encoding"),
      PdfNameObject(text_font_read_name_for_test("/Identity-H")),
    ),
  ])
  let system_result = try doc.read_cidkeyed_font(bad_system_font) catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard system_result is Err(CIDRegistryExpected) else {
    fail("expected @core.PdfError::CIDRegistryExpected")
  }

  doc.add_object_given_number(
    10,
    @syntax.pdf_dictionary([
      (
        text_font_read_name_for_test("/BaseFont"),
        PdfNameObject(text_font_read_name_for_test("/Descendant")),
      ),
      (
        text_font_read_name_for_test("/FontDescriptor"),
        @syntax.pdf_dictionary([]),
      ),
    ]),
  )
  let missing_system_result = try
    doc.read_cidkeyed_font(
      text_font_read_cid_top_font_for_test(
        10,
        PdfNameObject(text_font_read_name_for_test("/Identity-H")),
      ),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard missing_system_result is Err(CIDSystemInfoExpected) else {
    fail("expected @core.PdfError::CIDSystemInfoExpected")
  }

  doc.add_object_given_number(
    11,
    @syntax.pdf_dictionary([
      (
        text_font_read_name_for_test("/CIDSystemInfo"),
        text_font_read_cid_system_info_object_for_test(),
      ),
      (
        text_font_read_name_for_test("/FontDescriptor"),
        @syntax.pdf_dictionary([]),
      ),
    ]),
  )
  let missing_cid_basefont_result = try
    doc.read_cidkeyed_font(
      text_font_read_cid_top_font_for_test(
        11,
        PdfNameObject(text_font_read_name_for_test("/Identity-H")),
      ),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard missing_cid_basefont_result is Err(CIDBaseFontExpected) else {
    fail("expected @core.PdfError::CIDBaseFontExpected")
  }

  doc.add_object_given_number(
    12,
    @syntax.pdf_dictionary([
      (
        text_font_read_name_for_test("/CIDSystemInfo"),
        text_font_read_cid_system_info_object_for_test(),
      ),
      (
        text_font_read_name_for_test("/BaseFont"),
        PdfNameObject(text_font_read_name_for_test("/Descendant")),
      ),
    ]),
  )
  let missing_descriptor_result = try
    doc.read_cidkeyed_font(
      text_font_read_cid_top_font_for_test(
        12,
        PdfNameObject(text_font_read_name_for_test("/Identity-H")),
      ),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard missing_descriptor_result is Err(CIDFontDescriptorExpected) else {
    fail("expected @core.PdfError::CIDFontDescriptorExpected")
  }

  let bad_widths = @syntax.pdf_dictionary([
    (
      text_font_read_name_for_test("/CIDSystemInfo"),
      @syntax.pdf_dictionary([
        (
          text_font_read_name_for_test("/Registry"),
          PdfString(text_font_read_bytes_for_test([82])),
        ),
        (
          text_font_read_name_for_test("/Ordering"),
          PdfString(text_font_read_bytes_for_test([79])),
        ),
        (text_font_read_name_for_test("/Supplement"), PdfInteger(0)),
      ]),
    ),
    (
      text_font_read_name_for_test("/BaseFont"),
      PdfNameObject(text_font_read_name_for_test("/Descendant")),
    ),
    (
      text_font_read_name_for_test("/FontDescriptor"),
      @syntax.pdf_dictionary([]),
    ),
    (
      text_font_read_name_for_test("/W"),
      PdfArray([PdfInteger(5), PdfInteger(4), PdfInteger(100)]),
    ),
  ])
  doc.add_object_given_number(7, bad_widths)
  let bad_widths_font = @syntax.pdf_dictionary([
    (
      text_font_read_name_for_test("/BaseFont"),
      PdfNameObject(text_font_read_name_for_test("/T")),
    ),
    (
      text_font_read_name_for_test("/DescendantFonts"),
      PdfArray([PdfIndirect(7)]),
    ),
    (
      text_font_read_name_for_test("/Encoding"),
      PdfNameObject(text_font_read_name_for_test("/Identity-H")),
    ),
  ])
  let widths_result = try doc.read_cidkeyed_font(bad_widths_font) catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard widths_result is Err(CIDWidthsExpected) else {
    fail("expected @core.PdfError::CIDWidthsExpected")
  }

  let malformed_widths : Array[@syntax.PdfObject] = [
    text_font_read_valid_cid_descendant_for_test([
      (
        text_font_read_name_for_test("/W"),
        PdfArray([
          PdfInteger(1),
          PdfArray([PdfNameObject(text_font_read_name_for_test("/Bad"))]),
        ]),
      ),
    ]),
    text_font_read_valid_cid_descendant_for_test([
      (
        text_font_read_name_for_test("/W"),
        PdfArray([
          PdfInteger(1),
          PdfNameObject(text_font_read_name_for_test("/Bad")),
        ]),
      ),
    ]),
    text_font_read_valid_cid_descendant_for_test([
      (
        text_font_read_name_for_test("/W"),
        PdfArray([PdfNameObject(text_font_read_name_for_test("/Bad"))]),
      ),
    ]),
  ]
  for index in 0..<malformed_widths.length() {
    doc.add_object_given_number(13 + index, malformed_widths[index])
    let result = try
      doc.read_cidkeyed_font(
        text_font_read_cid_top_font_for_test(
          13 + index,
          PdfNameObject(text_font_read_name_for_test("/Identity-H")),
        ),
      )
    catch {
      err => Err(err)
    } noraise {
      value => Ok(value)
    }
    guard result is Err(CIDWidthsExpected) else {
      fail("expected @core.PdfError::CIDWidthsExpected for malformed widths")
    }
  }

  let bad_widths2 = @syntax.pdf_dictionary([
    (
      text_font_read_name_for_test("/CIDSystemInfo"),
      @syntax.pdf_dictionary([
        (
          text_font_read_name_for_test("/Registry"),
          PdfString(text_font_read_bytes_for_test([82])),
        ),
        (
          text_font_read_name_for_test("/Ordering"),
          PdfString(text_font_read_bytes_for_test([79])),
        ),
        (text_font_read_name_for_test("/Supplement"), PdfInteger(0)),
      ]),
    ),
    (
      text_font_read_name_for_test("/BaseFont"),
      PdfNameObject(text_font_read_name_for_test("/Descendant")),
    ),
    (
      text_font_read_name_for_test("/FontDescriptor"),
      @syntax.pdf_dictionary([]),
    ),
    (
      text_font_read_name_for_test("/W2"),
      PdfArray([PdfInteger(5), PdfArray([PdfInteger(100), PdfInteger(1)])]),
    ),
  ])
  doc.add_object_given_number(8, bad_widths2)
  let bad_widths2_font = @syntax.pdf_dictionary([
    (
      text_font_read_name_for_test("/BaseFont"),
      PdfNameObject(text_font_read_name_for_test("/T")),
    ),
    (
      text_font_read_name_for_test("/DescendantFonts"),
      PdfArray([PdfIndirect(8)]),
    ),
    (
      text_font_read_name_for_test("/Encoding"),
      PdfNameObject(text_font_read_name_for_test("/Identity-H")),
    ),
  ])
  let widths2_result = try doc.read_cidkeyed_font(bad_widths2_font) catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard widths2_result is Err(CIDWidths2Expected) else {
    fail("expected @core.PdfError::CIDWidths2Expected")
  }

  let malformed_widths2 : Array[@syntax.PdfObject] = [
    text_font_read_valid_cid_descendant_for_test([
      (
        text_font_read_name_for_test("/W2"),
        PdfArray([
          PdfInteger(5),
          PdfInteger(4),
          PdfInteger(100),
          PdfInteger(1),
          PdfInteger(2),
        ]),
      ),
    ]),
    text_font_read_valid_cid_descendant_for_test([
      (
        text_font_read_name_for_test("/W2"),
        PdfArray([
          PdfInteger(1),
          PdfNameObject(text_font_read_name_for_test("/Bad")),
        ]),
      ),
    ]),
    text_font_read_valid_cid_descendant_for_test([
      (
        text_font_read_name_for_test("/W2"),
        PdfArray([PdfNameObject(text_font_read_name_for_test("/Bad"))]),
      ),
    ]),
  ]
  for index in 0..<malformed_widths2.length() {
    doc.add_object_given_number(16 + index, malformed_widths2[index])
    let result = try
      doc.read_cidkeyed_font(
        text_font_read_cid_top_font_for_test(
          16 + index,
          PdfNameObject(text_font_read_name_for_test("/Identity-H")),
        ),
      )
    catch {
      err => Err(err)
    } noraise {
      value => Ok(value)
    }
    guard result is Err(CIDWidths2Expected) else {
      fail(
        "expected @core.PdfError::CIDWidths2Expected for malformed vertical widths",
      )
    }
  }

  let valid_descendant = @syntax.pdf_dictionary([
    (
      text_font_read_name_for_test("/CIDSystemInfo"),
      @syntax.pdf_dictionary([
        (
          text_font_read_name_for_test("/Registry"),
          PdfString(text_font_read_bytes_for_test([82])),
        ),
        (
          text_font_read_name_for_test("/Ordering"),
          PdfString(text_font_read_bytes_for_test([79])),
        ),
        (text_font_read_name_for_test("/Supplement"), PdfInteger(0)),
      ]),
    ),
    (
      text_font_read_name_for_test("/BaseFont"),
      PdfNameObject(text_font_read_name_for_test("/Descendant")),
    ),
    (
      text_font_read_name_for_test("/FontDescriptor"),
      @syntax.pdf_dictionary([]),
    ),
  ])
  doc.add_object_given_number(9, valid_descendant)
  let direct_cmap = @syntax.pdf_dictionary([
    (
      text_font_read_name_for_test("/BaseFont"),
      PdfNameObject(text_font_read_name_for_test("/T")),
    ),
    (
      text_font_read_name_for_test("/DescendantFonts"),
      PdfArray([PdfIndirect(9)]),
    ),
    (
      text_font_read_name_for_test("/Encoding"),
      @syntax.pdf_stream(@syntax.pdf_dictionary([]), StreamGot([])),
    ),
  ])
  let direct_cmap_result = try doc.read_cidkeyed_font(direct_cmap) catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard direct_cmap_result is Err(CMapEncodingExpected) else {
    fail("expected @core.PdfError::CMapEncodingExpected")
  }
  let bad_cmap = try
    doc.read_cidkeyed_font(
      text_font_read_cid_top_font_for_test(9, PdfInteger(1)),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_cmap is Err(CMapEncodingExpected) else {
    fail("expected @core.PdfError::CMapEncodingExpected for non-name encoding")
  }
}
