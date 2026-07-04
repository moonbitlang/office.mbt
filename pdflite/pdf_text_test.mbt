///|
fn text_core_name_for_test(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn text_core_bytes_for_test(values : ArrayView[Int]) -> @core.PdfBytes {
  try! @core.pdf_bytes_of_int_array(values)
}

///|
fn text_core_font_descriptor_for_test() -> @pdflite.PdfFontDescriptor {
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
test "pdftext top-level font and extractor wrappers match methods" {
  let doc = @pdflite.pdf_document_empty()
  let font_object = @syntax.pdf_dictionary([
    (
      text_core_name_for_test("/Subtype"),
      PdfNameObject(text_core_name_for_test("/Type1")),
    ),
    (
      text_core_name_for_test("/BaseFont"),
      PdfNameObject(text_core_name_for_test("/Helvetica")),
    ),
    (
      text_core_name_for_test("/Encoding"),
      PdfNameObject(text_core_name_for_test("/WinAnsiEncoding")),
    ),
  ])
  let font = try! @pdflite.pdf_read_font(doc, font_object)
  @test.assert_eq(@pdflite.pdf_string_of_font(font), font.debug_name())
  @test.assert_eq(@pdflite.pdf_string_of_font(font), "StandardFont Helvetica")
  @test.assert_eq(@pdflite.pdf_is_identity_h(font), false)

  let text = text_core_bytes_for_test([65, 66])
  let extractor = try! @pdflite.pdf_text_extractor_of_font(doc, font_object)
  let real_extractor = @pdflite.pdf_text_extractor_of_font_real(font)
  @test.assert_eq(try! @pdflite.pdf_codepoints_of_text(extractor, text), [
    65, 66,
  ])
  @test.assert_eq(try! @pdflite.pdf_codepoints_of_text(real_extractor, text), [
    65, 66,
  ])
  @test.assert_eq(
    try! @pdflite.pdf_glyphnames_of_text(
      extractor,
      text_core_bytes_for_test([65]),
    ),
    [text_core_name_for_test("/A")],
  )
  let charcode = try! @pdflite.pdf_charcode_extractor_of_font(doc, font_object)
  let real_charcode = @pdflite.pdf_charcode_extractor_of_font_real(
    font,
    debug=true,
  )
  @test.assert_eq(charcode(0x41), Some(65))
  @test.assert_eq(real_charcode(0x42), Some(66))
  @test.assert_eq(real_charcode(0x2603), None)

  let output = @pdflite.pdf_document_empty()
  let written = try! @pdflite.pdf_write_font(output, font, objnum=Some(7))
  @test.assert_eq(written, 7)
  @test.assert_eq(
    output.lookup_object_or_null(7),
    @syntax.pdf_dictionary([
      (
        text_core_name_for_test("/Type"),
        PdfNameObject(text_core_name_for_test("/Font")),
      ),
      (
        text_core_name_for_test("/Subtype"),
        PdfNameObject(text_core_name_for_test("/Type1")),
      ),
      (
        text_core_name_for_test("/Encoding"),
        PdfNameObject(text_core_name_for_test("/WinAnsiEncoding")),
      ),
      (
        text_core_name_for_test("/BaseFont"),
        PdfNameObject(text_core_name_for_test("/Helvetica")),
      ),
    ]),
  )
}

///|
test "PdfTextExtractor codepoints_of_text keeps ToUnicode first match and fallbacks" {
  let extractor = @pdflite.pdf_text_extractor_of_font_real(
    PdfFontSimple({
      fonttype: PdfType1,
      basefont: Some(text_core_name_for_test("/Helvetica")),
      firstchar: 0,
      lastchar: 0,
      widths: [],
      fontdescriptor: Some({
        ..text_core_font_descriptor_for_test(),
        tounicode: Some([
          (65, text_core_bytes_for_test([0x00, 0x41])),
          (65, text_core_bytes_for_test([0x00, 0x42])),
          (66, text_core_bytes_for_test([0xD8, 0x00])),
        ]),
      }),
      fontmetrics: None,
      encoding: PdfWinAnsiEncoding,
    }),
  )
  @test.assert_eq(
    try! extractor.codepoints_of_text(text_core_bytes_for_test([65, 66, 67])),
    [0x41, 66, 67],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x41), Some(65))
  @test.assert_eq(extractor.charcode_of_codepoint(0x42), Some(65))
}

///|
test "PdfDocument write_font rejects unsupported font variants" {
  let doc = @pdflite.pdf_document_empty()
  let unsupported = try
    doc.write_font(
      PdfFontSimple({
        fonttype: PdfType1,
        basefont: Some(text_core_name_for_test("/CustomFont")),
        firstchar: 0,
        lastchar: 0,
        widths: [],
        fontdescriptor: None,
        fontmetrics: None,
        encoding: PdfWinAnsiEncoding,
      }),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard unsupported is Err(FontWriteUnsupported) else {
    fail("expected @core.PdfError::FontWriteUnsupported")
  }
  let unsupported_type3 = try
    doc.write_font(
      PdfFontSimple({
        fonttype: PdfType3({
          fontbbox: { min_x: 0.0, min_y: 0.0, max_x: 0.0, max_y: 0.0 },
          fontmatrix: @geometry.transform_identity_matrix,
          charprocs: [],
          resources: @syntax.pdf_dictionary([]),
        }),
        basefont: None,
        firstchar: 0,
        lastchar: 0,
        widths: [],
        fontdescriptor: None,
        fontmetrics: None,
        encoding: PdfImplicitInFontFile,
      }),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard unsupported_type3 is Err(FontWriteUnsupported) else {
    fail("expected @core.PdfError::FontWriteUnsupported")
  }
  let unsupported_encoding = try
    doc.write_font(
      PdfFontSimple({
        fonttype: PdfType3({
          fontbbox: { min_x: 0.0, min_y: 0.0, max_x: 0.0, max_y: 0.0 },
          fontmatrix: @geometry.transform_identity_matrix,
          charprocs: [],
          resources: @syntax.pdf_dictionary([]),
        }),
        basefont: None,
        firstchar: 0,
        lastchar: 0,
        widths: [],
        fontdescriptor: Some(text_core_font_descriptor_for_test()),
        fontmetrics: None,
        encoding: PdfWinAnsiEncoding,
      }),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard unsupported_encoding is Err(EncodingWriteUnsupported) else {
    fail("expected @core.PdfError::EncodingWriteUnsupported")
  }
  let unsupported_truetype = try
    doc.write_font(
      PdfFontSimple({
        fonttype: PdfTrueType,
        basefont: Some(text_core_name_for_test("/MissingFontFile2")),
        firstchar: 0,
        lastchar: 0,
        widths: [],
        fontdescriptor: Some(text_core_font_descriptor_for_test()),
        fontmetrics: None,
        encoding: PdfWinAnsiEncoding,
      }),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard unsupported_truetype is Err(FontWriteUnsupported) else {
    fail("expected @core.PdfError::FontWriteUnsupported")
  }
  let unsupported_truetype_encoding = try
    doc.write_font(
      PdfFontSimple({
        fonttype: PdfTrueType,
        basefont: Some(text_core_name_for_test("/CustomEncoding")),
        firstchar: 0,
        lastchar: 0,
        widths: [],
        fontdescriptor: Some({
          ..text_core_font_descriptor_for_test(),
          fontfile: Some(PdfFontFile2(7)),
        }),
        fontmetrics: None,
        encoding: PdfCustomEncoding(PdfImplicitInFontFile, []),
      }),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard unsupported_truetype_encoding is Err(EncodingWriteUnsupported) else {
    fail("expected @core.PdfError::EncodingWriteUnsupported")
  }
}
