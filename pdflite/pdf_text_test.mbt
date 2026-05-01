///|
fn text_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn text_bytes_for_test(values : ArrayView[Int]) -> @pdflite.PdfBytes {
  try! @pdflite.pdf_bytes_of_int_array(values)
}

///|
fn text_difference_for_test(
  name : String,
  code : Int,
) -> @pdflite.PdfEncodingDifference {
  { name: text_name_for_test(name), code }
}

///|
fn text_standard_font_data_for_test(
  font : @pdflite.PdfStandardFont,
  encoding : @pdflite.PdfEncoding,
) -> @pdflite.PdfStandardFontData {
  { font, encoding }
}

///|
fn text_font_descriptor_for_test() -> @pdflite.PdfFontDescriptor {
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
test "PdfStandardFont exposes CamlPDF standard font names" {
  let fonts : Array[(@pdflite.PdfStandardFont, String)] = [
    (PdfTimesRoman, "Times-Roman"),
    (PdfTimesBold, "Times-Bold"),
    (PdfTimesItalic, "Times-Italic"),
    (PdfTimesBoldItalic, "Times-BoldItalic"),
    (PdfHelvetica, "Helvetica"),
    (PdfHelveticaBold, "Helvetica-Bold"),
    (PdfHelveticaOblique, "Helvetica-Oblique"),
    (PdfHelveticaBoldOblique, "Helvetica-BoldOblique"),
    (PdfCourier, "Courier"),
    (PdfCourierBold, "Courier-Bold"),
    (PdfCourierOblique, "Courier-Oblique"),
    (PdfCourierBoldOblique, "Courier-BoldOblique"),
    (PdfSymbol, "Symbol"),
    (PdfZapfDingbats, "ZapfDingbats"),
  ]
  for entry in fonts {
    @test.assert_eq(entry.0.name(), entry.1)
    @test.assert_eq(entry.0.pdf_name(), text_name_for_test("/" + entry.1))
  }
}

///|
test "pdf_utf16be_of_codepoints writes PDF Unicode strings as bytes" {
  let encoded = try! @pdflite.pdf_utf16be_of_codepoints([0x41, 0x20AC, 0x1D11E])
  @test.assert_eq(
    encoded,
    text_bytes_for_test([
      0xFE, 0xFF, 0x00, 0x41, 0x20, 0xAC, 0xD8, 0x34, 0xDD, 0x1E,
    ]),
  )
  @test.assert_eq(@pdflite.pdf_is_unicode_string(encoded[:]), true)
  @test.assert_eq(try! @pdflite.pdf_codepoints_of_utf16be(encoded[2:]), [
    0x41, 0x20AC, 0x1D11E,
  ])
}

///|
test "pdf_codepoints_of_utf16be rejects malformed UTF16BE bytes" {
  let odd = try? @pdflite.pdf_codepoints_of_utf16be(
    text_bytes_for_test([0x00])[:],
  )
  guard odd is Err(InvalidUTF16BE) else {
    fail("expected InvalidUTF16BE for odd byte length")
  }
  let unpaired_high = try? @pdflite.pdf_codepoints_of_utf16be(
    text_bytes_for_test([0xD8, 0x34, 0x00, 0x41])[:],
  )
  guard unpaired_high is Err(InvalidUTF16BE) else {
    fail("expected InvalidUTF16BE for unpaired high surrogate")
  }
  let isolated_low = try? @pdflite.pdf_codepoints_of_utf16be(
    text_bytes_for_test([0xDD, 0x1E])[:],
  )
  guard isolated_low is Err(InvalidUTF16BE) else {
    fail("expected InvalidUTF16BE for isolated low surrogate")
  }
}

///|
test "pdf_utf16be_of_codepoints rejects invalid Unicode scalar values" {
  let surrogate = try? @pdflite.pdf_utf16be_of_codepoints([0xD800])
  guard surrogate is Err(InvalidUnicodeCodepoint(0xD800)) else {
    fail("expected InvalidUnicodeCodepoint for surrogate scalar")
  }
  let too_large = try? @pdflite.pdf_utf16be_of_codepoints([0x110000])
  guard too_large is Err(InvalidUnicodeCodepoint(0x110000)) else {
    fail("expected InvalidUnicodeCodepoint for out-of-range scalar")
  }
}

///|
test "pdf_utf8_of_codepoints writes UTF8 bytes and roundtrips" {
  let encoded = try! @pdflite.pdf_utf8_of_codepoints([
    0x41, 0xA2, 0x20AC, 0x1D11E,
  ])
  @test.assert_eq(
    encoded,
    text_bytes_for_test([
      0x41, 0xC2, 0xA2, 0xE2, 0x82, 0xAC, 0xF0, 0x9D, 0x84, 0x9E,
    ]),
  )
  @test.assert_eq(try! @pdflite.pdf_codepoints_of_utf8(encoded[:]), [
    0x41, 0xA2, 0x20AC, 0x1D11E,
  ])
}

///|
test "pdf_codepoints_of_utf8 rejects malformed UTF8 bytes" {
  let truncated = try? @pdflite.pdf_codepoints_of_utf8(
    text_bytes_for_test([0xE2, 0x82])[:],
  )
  guard truncated is Err(InvalidUTF8) else {
    fail("expected InvalidUTF8 for truncated sequence")
  }
  let bad_continuation = try? @pdflite.pdf_codepoints_of_utf8(
    text_bytes_for_test([0xE2, 0x28, 0xAC])[:],
  )
  guard bad_continuation is Err(InvalidUTF8) else {
    fail("expected InvalidUTF8 for bad continuation")
  }
  let overlong = try? @pdflite.pdf_codepoints_of_utf8(
    text_bytes_for_test([0xC0, 0x80])[:],
  )
  guard overlong is Err(InvalidUTF8) else {
    fail("expected InvalidUTF8 for overlong sequence")
  }
  let surrogate = try? @pdflite.pdf_codepoints_of_utf8(
    text_bytes_for_test([0xED, 0xA0, 0x80])[:],
  )
  guard surrogate is Err(InvalidUnicodeCodepoint(0xD800)) else {
    fail("expected InvalidUnicodeCodepoint for decoded surrogate")
  }
}

///|
test "PDFDocEncoding decodes CamlPDF byte mappings" {
  @test.assert_eq(
    try! @pdflite.pdf_codepoint_of_pdfdocencoding_byte(0x09),
    0x09,
  )
  @test.assert_eq(
    try! @pdflite.pdf_codepoint_of_pdfdocencoding_byte(0x18),
    0x02D8,
  )
  @test.assert_eq(
    try! @pdflite.pdf_codepoint_of_pdfdocencoding_byte(0xA0),
    0x20AC,
  )
  @test.assert_eq(
    try! @pdflite.pdf_codepoint_of_pdfdocencoding_byte(0x93),
    0xFB02,
  )
  let undefined_byte_result = try? @pdflite.pdf_codepoint_of_pdfdocencoding_byte(
    0x94,
  )
  guard undefined_byte_result is Err(InvalidPDFDocEncoding(0x94)) else {
    fail("expected InvalidPDFDocEncoding for undefined byte")
  }
  @test.assert_eq(
    try! @pdflite.pdf_codepoints_of_pdfdocencoding(
      text_bytes_for_test([0x41, 0xA0, 0x93])[:],
    ),
    [0x41, 0x20AC, 0xFB02],
  )
}

///|
test "PDFDocEncoding encodes codepoints and falls back to UTF16BE" {
  @test.assert_eq(
    @pdflite.pdf_pdfdocencoding_byte_of_codepoint(0x20AC),
    Some(0xA0),
  )
  @test.assert_eq(
    @pdflite.pdf_pdfdocencoding_byte_of_codepoint(0xFB01),
    Some(0x93),
  )
  @test.assert_eq(
    @pdflite.pdf_pdfdocencoding_of_codepoints([0x41, 0x20AC, 0xFB01]),
    Some(text_bytes_for_test([0x41, 0xA0, 0x93])),
  )
  @test.assert_eq(@pdflite.pdf_pdfdocencoding_of_codepoints([0x4E2D]), None)
  @test.assert_eq(
    try! @pdflite.pdf_pdfdocstring_of_codepoints([0x4E2D]),
    text_bytes_for_test([0xFE, 0xFF, 0x4E, 0x2D]),
  )
}

///|
test "PDF document string helpers bridge PDFDoc UTF16BE and UTF8 bytes" {
  @test.assert_eq(
    try! @pdflite.pdf_codepoints_of_pdfdocstring(
      text_bytes_for_test([0x41, 0xA0])[:],
    ),
    [0x41, 0x20AC],
  )
  @test.assert_eq(
    try! @pdflite.pdf_codepoints_of_pdfdocstring(
      text_bytes_for_test([0xFE, 0xFF, 0x00, 0x41, 0x20, 0xAC])[:],
    ),
    [0x41, 0x20AC],
  )
  @test.assert_eq(
    try! @pdflite.pdf_utf8_of_pdfdocstring(text_bytes_for_test([0x41, 0xA0])[:]),
    text_bytes_for_test([0x41, 0xE2, 0x82, 0xAC]),
  )
  @test.assert_eq(
    try! @pdflite.pdf_pdfdocstring_of_utf8(
      text_bytes_for_test([0x41, 0xE2, 0x82, 0xAC])[:],
    ),
    text_bytes_for_test([0x41, 0xA0]),
  )
  @test.assert_eq(
    try! @pdflite.pdf_simplify_utf16be(
      text_bytes_for_test([0xFE, 0xFF, 0x00, 0x41, 0x20, 0xAC])[:],
    ),
    text_bytes_for_test([0x41, 0xA0]),
  )
  @test.assert_eq(
    try! @pdflite.pdf_simplify_utf16be(text_bytes_for_test([0x41])[:]),
    text_bytes_for_test([0x41]),
  )
}

///|
test "pdf_standard_font_of_name accepts CamlPDF aliases" {
  let aliases : Array[(String, @pdflite.PdfStandardFont)] = [
    ("/Times-Roman", PdfTimesRoman),
    ("/TimesNewRoman", PdfTimesRoman),
    ("/Times-Bold", PdfTimesBold),
    ("/TimesNewRoman,Bold", PdfTimesBold),
    ("/Times-Italic", PdfTimesItalic),
    ("/TimesNewRoman,Italic", PdfTimesItalic),
    ("/Times-BoldItalic", PdfTimesBoldItalic),
    ("/TimesNewRoman,BoldItalic", PdfTimesBoldItalic),
    ("/Helvetica", PdfHelvetica),
    ("/Arial", PdfHelvetica),
    ("/Helvetica-Bold", PdfHelveticaBold),
    ("/Arial,Bold", PdfHelveticaBold),
    ("/Helvetica-Oblique", PdfHelveticaOblique),
    ("/Arial,Italic", PdfHelveticaOblique),
    ("/Helvetica-BoldOblique", PdfHelveticaBoldOblique),
    ("/Arial,BoldItalic", PdfHelveticaBoldOblique),
    ("/Courier", PdfCourier),
    ("/CourierNew", PdfCourier),
    ("/Courier-Bold", PdfCourierBold),
    ("/CourierNew,Bold", PdfCourierBold),
    ("/Courier-Oblique", PdfCourierOblique),
    ("/CourierNew,Italic", PdfCourierOblique),
    ("/Courier-BoldOblique", PdfCourierBoldOblique),
    ("/CourierNew,BoldItalic", PdfCourierBoldOblique),
    ("/Symbol", PdfSymbol),
    ("/ZapfDingbats", PdfZapfDingbats),
  ]
  for entry in aliases {
    @test.assert_eq(@pdflite.pdf_standard_font_of_name(entry.0), Some(entry.1))
    @test.assert_eq(
      @pdflite.pdf_standard_font_of_pdf_name(text_name_for_test(entry.0)),
      Some(entry.1),
    )
  }
  @test.assert_eq(@pdflite.pdf_standard_font_of_name("Times-Roman"), None)
  @test.assert_eq(
    @pdflite.pdf_standard_font_of_pdf_name(text_name_for_test("/Missing")),
    None,
  )
}

///|
test "PdfStandardFont exposes standard14 baseline stem and flags" {
  let metrics : Array[(@pdflite.PdfStandardFont, Int, Int, Int)] = [
    (PdfTimesRoman, 331, 116, 32),
    (PdfTimesBold, 338, 122, 32),
    (PdfTimesItalic, 326, 105, 32),
    (PdfTimesBoldItalic, 334, 108, 32),
    (PdfHelvetica, 359, 114, 32),
    (PdfHelveticaBold, 359, 123, 32),
    (PdfHelveticaOblique, 359, 127, 32),
    (PdfHelveticaBoldOblique, 359, 136, 32),
    (PdfCourier, 281, 88, 33),
    (PdfCourierBold, 281, 93, 33),
    (PdfCourierOblique, 281, 100, 33),
    (PdfCourierBoldOblique, 281, 104, 33),
    (PdfSymbol, 336, 0, 65541),
    (PdfZapfDingbats, 352, 125, 4),
  ]
  for entry in metrics {
    @test.assert_eq(entry.0.baseline_adjustment(), entry.1)
    @test.assert_eq(entry.0.stemv(), entry.2)
    @test.assert_eq(entry.0.flags(), entry.3)
  }
}

///|
test "PdfEncoding debug names preserve CamlPDF forms" {
  @test.assert_eq(
    @pdflite.PdfImplicitInFontFile.debug_name(),
    "ImplicitInFontFile",
  )
  @test.assert_eq(@pdflite.PdfStandardEncoding.debug_name(), "StandardEncoding")
  @test.assert_eq(@pdflite.PdfMacRomanEncoding.debug_name(), "MacRomanEncoding")
  @test.assert_eq(@pdflite.PdfWinAnsiEncoding.debug_name(), "WinAnsiEncoding")
  @test.assert_eq(
    @pdflite.PdfMacExpertEncoding.debug_name(),
    "MacExpertEncoding",
  )
  let difference : @pdflite.PdfEncodingDifference = {
    name: text_name_for_test("/A"),
    code: 65,
  }
  @test.assert_eq(
    @pdflite.PdfCustomEncoding(PdfWinAnsiEncoding, [difference]).debug_name(),
    "CustomEncoding with base WinAnsiEncoding and differences 65 -> /A, ",
  )
  @test.assert_eq(
    @pdflite.PdfFillUndefinedWithStandard(PdfMacRomanEncoding).debug_name(),
    "FillUndefinedWithStandard MacRomanEncoding",
  )
}

///|
test "PdfEncoding converts predefined encoding names" {
  let encodings : Array[(@pdflite.PdfEncoding, @pdflite.PdfName)] = [
    (PdfStandardEncoding, text_name_for_test("/StandardEncoding")),
    (PdfMacRomanEncoding, text_name_for_test("/MacRomanEncoding")),
    (PdfWinAnsiEncoding, text_name_for_test("/WinAnsiEncoding")),
    (PdfMacExpertEncoding, text_name_for_test("/MacExpertEncoding")),
  ]
  for entry in encodings {
    @test.assert_eq(entry.0.pdf_name(), Some(entry.1))
    @test.assert_eq(@pdflite.pdf_encoding_of_name(entry.1), Some(entry.0))
  }
  @test.assert_eq(@pdflite.PdfImplicitInFontFile.pdf_name(), None)
  @test.assert_eq(
    @pdflite.PdfCustomEncoding(PdfStandardEncoding, []).pdf_name(),
    None,
  )
  @test.assert_eq(
    @pdflite.pdf_encoding_of_name(text_name_for_test("/MissingEncoding")),
    None,
  )
}

///|
test "PdfDocument read_encoding reads direct and dictionary encodings" {
  let doc = @pdflite.pdf_document_empty()
  let direct_font = @pdflite.pdf_dictionary([
    (
      text_name_for_test("/Encoding"),
      PdfNameObject(text_name_for_test("/WinAnsiEncoding")),
    ),
  ])
  @test.assert_eq(try! doc.read_encoding(direct_font), PdfWinAnsiEncoding)
  let unknown_direct = @pdflite.pdf_dictionary([
    (
      text_name_for_test("/Encoding"),
      PdfNameObject(text_name_for_test("/UnknownEncoding")),
    ),
  ])
  @test.assert_eq(try! doc.read_encoding(unknown_direct), PdfImplicitInFontFile)
  let dictionary_font = @pdflite.pdf_dictionary([
    (
      text_name_for_test("/Subtype"),
      PdfNameObject(text_name_for_test("/Type1")),
    ),
    (
      text_name_for_test("/Encoding"),
      @pdflite.pdf_dictionary([
        (
          text_name_for_test("/BaseEncoding"),
          PdfNameObject(text_name_for_test("/MacRomanEncoding")),
        ),
        (
          text_name_for_test("/Differences"),
          PdfArray([
            PdfInteger(65),
            PdfNameObject(text_name_for_test("/A")),
            PdfNameObject(text_name_for_test("/B")),
            PdfInteger(70),
            PdfNameObject(text_name_for_test("/C")),
          ]),
        ),
      ]),
    ),
  ])
  @test.assert_eq(
    try! doc.read_encoding(dictionary_font),
    PdfCustomEncoding(PdfMacRomanEncoding, [
      text_difference_for_test("/A", 65),
      text_difference_for_test("/B", 66),
      text_difference_for_test("/C", 70),
    ]),
  )
}

///|
test "PdfDocument read_encoding handles default and TrueType encodings" {
  let doc = @pdflite.pdf_document_empty()
  let plain = @pdflite.pdf_dictionary([
    (
      text_name_for_test("/Subtype"),
      PdfNameObject(text_name_for_test("/Type1")),
    ),
    (text_name_for_test("/Encoding"), @pdflite.pdf_dictionary([])),
  ])
  @test.assert_eq(try! doc.read_encoding(plain), PdfStandardEncoding)
  let embedded = @pdflite.pdf_dictionary([
    (
      text_name_for_test("/Subtype"),
      PdfNameObject(text_name_for_test("/Type1")),
    ),
    (text_name_for_test("/Encoding"), @pdflite.pdf_dictionary([])),
    (
      text_name_for_test("/FontDescriptor"),
      @pdflite.pdf_dictionary([
        (text_name_for_test("/FontFile"), PdfIndirect(99)),
      ]),
    ),
  ])
  @test.assert_eq(try! doc.read_encoding(embedded), PdfImplicitInFontFile)
  let symbolic = @pdflite.pdf_dictionary([
    (
      text_name_for_test("/Subtype"),
      PdfNameObject(text_name_for_test("/Type1")),
    ),
    (text_name_for_test("/Encoding"), @pdflite.pdf_dictionary([])),
    (
      text_name_for_test("/FontDescriptor"),
      @pdflite.pdf_dictionary([(text_name_for_test("/Flags"), PdfInteger(8))]),
    ),
  ])
  @test.assert_eq(try! doc.read_encoding(symbolic), PdfImplicitInFontFile)
  let true_type = @pdflite.pdf_dictionary([
    (
      text_name_for_test("/Subtype"),
      PdfNameObject(text_name_for_test("/TrueType")),
    ),
    (
      text_name_for_test("/Encoding"),
      @pdflite.pdf_dictionary([
        (
          text_name_for_test("/BaseEncoding"),
          PdfNameObject(text_name_for_test("/WinAnsiEncoding")),
        ),
      ]),
    ),
  ])
  @test.assert_eq(
    try! doc.read_encoding(true_type),
    PdfFillUndefinedWithStandard(PdfWinAnsiEncoding),
  )
}

///|
test "PdfDocument read_encoding rejects malformed encoding dictionaries" {
  let doc = @pdflite.pdf_document_empty()
  let bad_differences = @pdflite.pdf_dictionary([
    (
      text_name_for_test("/Subtype"),
      PdfNameObject(text_name_for_test("/Type1")),
    ),
    (
      text_name_for_test("/Encoding"),
      @pdflite.pdf_dictionary([
        (
          text_name_for_test("/Differences"),
          PdfArray([PdfNameObject(text_name_for_test("/A"))]),
        ),
      ]),
    ),
  ])
  let differences_result = try? doc.read_encoding(bad_differences)
  guard differences_result is Err(EncodingDifferencesMalformed) else {
    fail("expected EncodingDifferencesMalformed")
  }
  let bad_base = @pdflite.pdf_dictionary([
    (
      text_name_for_test("/Subtype"),
      PdfNameObject(text_name_for_test("/Type1")),
    ),
    (
      text_name_for_test("/Encoding"),
      @pdflite.pdf_dictionary([
        (text_name_for_test("/BaseEncoding"), PdfInteger(1)),
      ]),
    ),
  ])
  let base_result = try? doc.read_encoding(bad_base)
  guard base_result is Err(EncodingExpected) else {
    fail("expected EncodingExpected")
  }
  let bad_subtype = @pdflite.pdf_dictionary([
    (text_name_for_test("/Encoding"), @pdflite.pdf_dictionary([])),
  ])
  let subtype_result = try? doc.read_encoding(bad_subtype)
  guard subtype_result is Err(FontSubtypeExpected) else {
    fail("expected FontSubtypeExpected")
  }
}

///|
test "PdfDocument read_font_descriptor parses metrics font files and charset" {
  let doc = @pdflite.pdf_document_empty()
  let descriptor = @pdflite.pdf_dictionary([
    (
      text_name_for_test("/FontBBox"),
      PdfArray([
        PdfInteger(500),
        PdfInteger(-200),
        PdfInteger(-10),
        PdfInteger(700),
      ]),
    ),
    (text_name_for_test("/Ascent"), PdfInteger(720)),
    (text_name_for_test("/Descent"), PdfReal(-180.5)),
    (text_name_for_test("/AvgWidth"), PdfInteger(501)),
    (text_name_for_test("/MaxWidth"), PdfInteger(1000)),
    (text_name_for_test("/Flags"), PdfInteger(4)),
    (text_name_for_test("/FontFile2"), PdfIndirect(42)),
    (
      text_name_for_test("/CharSet"),
      PdfString(
        text_bytes_for_test([47, 65, 32, 47, 66, 32, 47, 67, 32, 47, 32, 47, 68]),
      ),
    ),
  ])
  let font = @pdflite.pdf_dictionary([
    (text_name_for_test("/FontDescriptor"), descriptor),
  ])
  guard (try! doc.read_font_descriptor(font)) is Some(read_descriptor) else {
    fail("expected font descriptor")
  }
  @test.assert_eq(read_descriptor.ascent, 720.0)
  @test.assert_eq(read_descriptor.descent, -180.5)
  @test.assert_eq(read_descriptor.avgwidth, 501.0)
  @test.assert_eq(read_descriptor.maxwidth, 1000.0)
  @test.assert_eq(read_descriptor.flags, 0)
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
      text_name_for_test("/A"),
      text_name_for_test("/B"),
      text_name_for_test("/C"),
    ]),
  )
}

///|
test "PdfDocument read_font_descriptor uses CamlPDF defaults and fontfile priority" {
  let doc = @pdflite.pdf_document_empty()
  @test.assert_eq(
    try! doc.read_font_descriptor(@pdflite.pdf_dictionary([])),
    None,
  )
  let descriptor = @pdflite.pdf_dictionary([
    (text_name_for_test("/FontFile"), PdfIndirect(10)),
    (text_name_for_test("/FontFile2"), PdfIndirect(11)),
    (text_name_for_test("/CharSet"), PdfInteger(0)),
  ])
  let font = @pdflite.pdf_dictionary([
    (text_name_for_test("/FontDescriptor"), descriptor),
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
test "PdfDocument read_font_metrics builds 256-entry width table" {
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(7, PdfInteger(620))
  let descriptor = @pdflite.pdf_dictionary([
    (text_name_for_test("/MissingWidth"), PdfInteger(250)),
  ])
  let font = @pdflite.pdf_dictionary([
    (text_name_for_test("/FontDescriptor"), descriptor),
    (text_name_for_test("/FirstChar"), PdfInteger(65)),
    (text_name_for_test("/LastChar"), PdfInteger(67)),
    (
      text_name_for_test("/Widths"),
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
  @test.assert_eq(try! doc.read_font_metrics(@pdflite.pdf_dictionary([])), None)
  let type3 = @pdflite.pdf_dictionary([
    (
      text_name_for_test("/Subtype"),
      PdfNameObject(text_name_for_test("/Type3")),
    ),
    (text_name_for_test("/MissingWidth"), PdfReal(5.5)),
    (text_name_for_test("/FirstChar"), PdfInteger(0)),
    (text_name_for_test("/LastChar"), PdfInteger(0)),
    (text_name_for_test("/Widths"), PdfArray([PdfInteger(9)])),
  ])
  guard (try! doc.read_font_metrics(type3)) is Some(type3_metrics) else {
    fail("expected type3 metrics")
  }
  @test.assert_eq(type3_metrics[0], 9.0)
  @test.assert_eq(type3_metrics[1], 5.5)

  let malformed = @pdflite.pdf_dictionary([
    (text_name_for_test("/FontDescriptor"), @pdflite.pdf_dictionary([])),
    (text_name_for_test("/FirstChar"), PdfInteger(65)),
    (text_name_for_test("/LastChar"), PdfInteger(66)),
    (text_name_for_test("/Widths"), PdfArray([PdfInteger(600)])),
  ])
  let malformed_result = try? doc.read_font_metrics(malformed)
  guard malformed_result is Err(FontWidthsExpected) else {
    fail("expected FontWidthsExpected")
  }

  let bad_width = @pdflite.pdf_dictionary([
    (text_name_for_test("/FontDescriptor"), @pdflite.pdf_dictionary([])),
    (text_name_for_test("/FirstChar"), PdfInteger(65)),
    (text_name_for_test("/LastChar"), PdfInteger(65)),
    (
      text_name_for_test("/Widths"),
      PdfArray([PdfNameObject(text_name_for_test("/Bad"))]),
    ),
  ])
  let bad_width_result = try? doc.read_font_metrics(bad_width)
  guard bad_width_result is Err(FontWidthExpected) else {
    fail("expected FontWidthExpected")
  }
}

///|
test "PdfDocument read_simple_font builds Type1 font records" {
  let doc = @pdflite.pdf_document_empty()
  let descriptor = @pdflite.pdf_dictionary([
    (text_name_for_test("/Ascent"), PdfInteger(700)),
    (text_name_for_test("/FontFile2"), PdfIndirect(9)),
    (text_name_for_test("/MissingWidth"), PdfInteger(250)),
  ])
  let font = @pdflite.pdf_dictionary([
    (
      text_name_for_test("/Subtype"),
      PdfNameObject(text_name_for_test("/Type1")),
    ),
    (
      text_name_for_test("/BaseFont"),
      PdfNameObject(text_name_for_test("/CustomFont")),
    ),
    (text_name_for_test("/FontDescriptor"), descriptor),
    (text_name_for_test("/FirstChar"), PdfInteger(65)),
    (text_name_for_test("/LastChar"), PdfInteger(65)),
    (text_name_for_test("/Widths"), PdfArray([PdfInteger(500)])),
    (
      text_name_for_test("/Encoding"),
      PdfNameObject(text_name_for_test("/WinAnsiEncoding")),
    ),
  ])
  let simple = try! doc.read_simple_font(font)
  @test.assert_eq(simple.fonttype, PdfType1)
  @test.assert_eq(simple.basefont, Some(text_name_for_test("/CustomFont")))
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
  let font = @pdflite.pdf_dictionary([
    (
      text_name_for_test("/Subtype"),
      PdfNameObject(text_name_for_test("/Type3")),
    ),
    (text_name_for_test("/FontBBox"), PdfArray([PdfInteger(1)])),
    (
      text_name_for_test("/FontMatrix"),
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
      text_name_for_test("/CharProcs"),
      @pdflite.pdf_dictionary([
        (text_name_for_test("/A"), PdfInteger(1)),
        (text_name_for_test("/B"), PdfInteger(2)),
      ]),
    ),
    (text_name_for_test("/MissingWidth"), PdfReal(5.5)),
    (text_name_for_test("/FirstChar"), PdfInteger(0)),
    (text_name_for_test("/LastChar"), PdfInteger(0)),
    (text_name_for_test("/Widths"), PdfArray([PdfInteger(9)])),
    (
      text_name_for_test("/Encoding"),
      PdfNameObject(text_name_for_test("/MacRomanEncoding")),
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
    (text_name_for_test("/A"), PdfInteger(1)),
    (text_name_for_test("/B"), PdfInteger(2)),
  ])
  @test.assert_eq(type3_data.resources, @pdflite.pdf_dictionary([]))
  @test.assert_eq(simple.encoding, PdfMacRomanEncoding)
  @test.assert_eq(simple.fonttype.debug_name(), "Type 3: charprocs for/A/B")
}

///|
test "PdfDocument read_simple_font rejects malformed simple fonts" {
  let doc = @pdflite.pdf_document_empty()
  let missing_subtype = try? doc.read_simple_font(@pdflite.pdf_dictionary([]))
  guard missing_subtype is Err(FontSubtypeExpected) else {
    fail("expected FontSubtypeExpected for missing subtype")
  }
  let unknown_subtype = try? doc.read_simple_font(
    @pdflite.pdf_dictionary([
      (
        text_name_for_test("/Subtype"),
        PdfNameObject(text_name_for_test("/CIDFontType2")),
      ),
    ]),
  )
  guard unknown_subtype is Err(FontSubtypeExpected) else {
    fail("expected FontSubtypeExpected for unknown subtype")
  }
  let missing_charprocs = try? doc.read_simple_font(
    @pdflite.pdf_dictionary([
      (
        text_name_for_test("/Subtype"),
        PdfNameObject(text_name_for_test("/Type3")),
      ),
    ]),
  )
  guard missing_charprocs is Err(FontCharProcsExpected) else {
    fail("expected FontCharProcsExpected")
  }
}

///|
test "PdfDocument detects and reads standard14 fonts" {
  let doc = @pdflite.pdf_document_empty()
  let font = @pdflite.pdf_dictionary([
    (
      text_name_for_test("/Subtype"),
      PdfNameObject(text_name_for_test("/Type1")),
    ),
    (
      text_name_for_test("/BaseFont"),
      PdfNameObject(text_name_for_test("/Arial,Bold")),
    ),
    (
      text_name_for_test("/Encoding"),
      PdfNameObject(text_name_for_test("/WinAnsiEncoding")),
    ),
  ])
  @test.assert_eq(doc.is_standard14_font(font), true)
  @test.assert_eq(doc.is_simple_font(font), true)
  let standard = try! doc.read_standard14_font(font)
  @test.assert_eq(
    standard,
    text_standard_font_data_for_test(PdfHelveticaBold, PdfWinAnsiEncoding),
  )
  @test.assert_eq(standard.debug_name(), "StandardFont Helvetica-Bold")
  let overridden = @pdflite.pdf_dictionary([
    (
      text_name_for_test("/Subtype"),
      PdfNameObject(text_name_for_test("/Type1")),
    ),
    (
      text_name_for_test("/BaseFont"),
      PdfNameObject(text_name_for_test("/Helvetica")),
    ),
    (text_name_for_test("/Widths"), PdfArray([])),
  ])
  @test.assert_eq(doc.is_standard14_font(overridden), false)
  let true_type_alias = @pdflite.pdf_dictionary([
    (
      text_name_for_test("/Subtype"),
      PdfNameObject(text_name_for_test("/TrueType")),
    ),
    (
      text_name_for_test("/BaseFont"),
      PdfNameObject(text_name_for_test("/Helvetica")),
    ),
  ])
  @test.assert_eq(doc.is_standard14_font(true_type_alias), true)
  let wrong_subtype = @pdflite.pdf_dictionary([
    (
      text_name_for_test("/Subtype"),
      PdfNameObject(text_name_for_test("/CIDFontType2")),
    ),
    (
      text_name_for_test("/BaseFont"),
      PdfNameObject(text_name_for_test("/Helvetica")),
    ),
  ])
  @test.assert_eq(doc.is_standard14_font(wrong_subtype), false)
  @test.assert_eq(doc.is_simple_font(wrong_subtype), false)
}

///|
test "PdfDocument read_standard14_font rejects bad base fonts" {
  let doc = @pdflite.pdf_document_empty()
  let unknown = @pdflite.pdf_dictionary([
    (
      text_name_for_test("/BaseFont"),
      PdfNameObject(text_name_for_test("/NotStandard")),
    ),
  ])
  let unknown_result = try? doc.read_standard14_font(unknown)
  guard unknown_result is Err(StandardFontExpected) else {
    fail("expected StandardFontExpected")
  }
  let missing_result = try? doc.read_standard14_font(
    @pdflite.pdf_dictionary([]),
  )
  guard missing_result is Err(BaseFontExpected) else {
    fail("expected BaseFontExpected")
  }
}

///|
test "PdfDocument read_font dispatches standard14 and simple fonts" {
  let doc = @pdflite.pdf_document_empty()
  let standard = @pdflite.pdf_dictionary([
    (
      text_name_for_test("/Subtype"),
      PdfNameObject(text_name_for_test("/TrueType")),
    ),
    (
      text_name_for_test("/BaseFont"),
      PdfNameObject(text_name_for_test("/Helvetica")),
    ),
    (
      text_name_for_test("/Encoding"),
      PdfNameObject(text_name_for_test("/MacRomanEncoding")),
    ),
  ])
  @test.assert_eq(
    try! doc.read_font(standard),
    PdfFontStandard(
      text_standard_font_data_for_test(PdfHelvetica, PdfMacRomanEncoding),
    ),
  )
  @test.assert_eq(
    (try! doc.read_font(standard)).debug_name(),
    "StandardFont Helvetica",
  )

  let simple = @pdflite.pdf_dictionary([
    (
      text_name_for_test("/Subtype"),
      PdfNameObject(text_name_for_test("/Type1")),
    ),
    (
      text_name_for_test("/BaseFont"),
      PdfNameObject(text_name_for_test("/CustomFont")),
    ),
    (
      text_name_for_test("/Encoding"),
      PdfNameObject(text_name_for_test("/WinAnsiEncoding")),
    ),
  ])
  @test.assert_eq(
    try! doc.read_font(simple),
    PdfFontSimple({
      fonttype: PdfType1,
      basefont: Some(text_name_for_test("/CustomFont")),
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
  let unknown = @pdflite.pdf_dictionary([
    (
      text_name_for_test("/Subtype"),
      PdfNameObject(text_name_for_test("/CIDFontType2")),
    ),
  ])
  let unknown_result = try? doc.read_font(unknown)
  guard unknown_result is Err(FontTypeExpected) else {
    fail("expected FontTypeExpected")
  }
}

///|
test "PdfDocument read_font reads CID-keyed Type0 fonts" {
  let doc = @pdflite.pdf_document_empty()
  let descendant = @pdflite.pdf_dictionary([
    (
      text_name_for_test("/CIDSystemInfo"),
      @pdflite.pdf_dictionary([
        (
          text_name_for_test("/Registry"),
          PdfString(text_bytes_for_test([65, 100, 111, 98, 101])),
        ),
        (
          text_name_for_test("/Ordering"),
          PdfString(
            text_bytes_for_test([73, 100, 101, 110, 116, 105, 116, 121]),
          ),
        ),
        (text_name_for_test("/Supplement"), PdfInteger(0)),
      ]),
    ),
    (
      text_name_for_test("/BaseFont"),
      PdfNameObject(text_name_for_test("/DescendantFont")),
    ),
    (
      text_name_for_test("/FontDescriptor"),
      @pdflite.pdf_dictionary([(text_name_for_test("/Ascent"), PdfInteger(880))]),
    ),
    (
      text_name_for_test("/W"),
      PdfArray([
        PdfInteger(1),
        PdfArray([PdfInteger(500), PdfReal(501.5)]),
        PdfInteger(10),
        PdfInteger(12),
        PdfInteger(600),
      ]),
    ),
    (
      text_name_for_test("/W2"),
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
    (text_name_for_test("/DW"), PdfInteger(1001)),
    (text_name_for_test("/DW2"), PdfArray([PdfInteger(880), PdfReal(-1000.5)])),
  ])
  doc.add_object_given_number(33, descendant)
  let font = @pdflite.pdf_dictionary([
    (
      text_name_for_test("/Subtype"),
      PdfNameObject(text_name_for_test("/Type0")),
    ),
    (
      text_name_for_test("/BaseFont"),
      PdfNameObject(text_name_for_test("/TopFont")),
    ),
    (text_name_for_test("/DescendantFonts"), PdfArray([PdfIndirect(33)])),
    (
      text_name_for_test("/Encoding"),
      PdfNameObject(text_name_for_test("/Identity-H")),
    ),
  ])
  @test.assert_eq(doc.is_cidkeyed_font(font), true)
  guard (try! doc.read_font(font)) is PdfFontCIDKeyed(cid_font) else {
    fail("expected CID-keyed font")
  }
  @test.assert_eq(cid_font.debug_name(), "CIDKeyedFont /TopFont")
  @test.assert_eq(cid_font.basefont, text_name_for_test("/TopFont"))
  @test.assert_eq(
    cid_font.encoding,
    PdfPredefinedCMap(text_name_for_test("/Identity-H")),
  )
  @test.assert_eq(cid_font.encoding.is_identity_h(), true)
  @test.assert_eq(cid_font.is_identity_h(), true)
  let cid_font_value : @pdflite.PdfFont = PdfFontCIDKeyed(cid_font)
  @test.assert_eq(cid_font_value.is_identity_h(), true)
  let identity_v : @pdflite.PdfCMapEncoding = PdfPredefinedCMap(
    text_name_for_test("/Identity-V"),
  )
  @test.assert_eq(identity_v.is_identity_h(), false)
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(PdfHelvetica, PdfWinAnsiEncoding),
  )
  @test.assert_eq(standard_font.is_identity_h(), false)
  let composite = cid_font.composite
  @test.assert_eq(composite.cid_basefont, text_name_for_test("/DescendantFont"))
  @test.assert_eq(
    composite.cid_system_info.registry,
    text_bytes_for_test([65, 100, 111, 98, 101]),
  )
  @test.assert_eq(
    composite.cid_system_info.ordering,
    text_bytes_for_test([73, 100, 101, 110, 116, 105, 116, 121]),
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
  let descendant = @pdflite.pdf_dictionary([
    (
      text_name_for_test("/CIDSystemInfo"),
      @pdflite.pdf_dictionary([
        (text_name_for_test("/Registry"), PdfString(text_bytes_for_test([82]))),
        (text_name_for_test("/Ordering"), PdfString(text_bytes_for_test([79]))),
        (text_name_for_test("/Supplement"), PdfInteger(1)),
      ]),
    ),
    (
      text_name_for_test("/BaseFont"),
      PdfNameObject(text_name_for_test("/Descendant")),
    ),
    (text_name_for_test("/FontDescriptor"), @pdflite.pdf_dictionary([])),
  ])
  let cmap = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([]),
    StreamGot(text_bytes_for_test([1, 2, 3])),
  )
  doc.add_object_given_number(4, descendant)
  doc.add_object_given_number(5, cmap)
  let font = @pdflite.pdf_dictionary([
    (text_name_for_test("/BaseFont"), PdfNameObject(text_name_for_test("/Top"))),
    (text_name_for_test("/DescendantFonts"), PdfArray([PdfIndirect(4)])),
    (text_name_for_test("/Encoding"), PdfIndirect(5)),
  ])
  @test.assert_eq(try! doc.read_cidkeyed_font(font), {
    basefont: text_name_for_test("/Top"),
    composite: {
      cid_system_info: {
        registry: text_bytes_for_test([82]),
        ordering: text_bytes_for_test([79]),
        supplement: 1,
      },
      cid_basefont: text_name_for_test("/Descendant"),
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
    encoding: PdfCMap(5),
  })
}

///|
test "PdfDocument read_cidkeyed_font rejects malformed CID data" {
  let doc = @pdflite.pdf_document_empty()
  let missing_descendant = try? doc.read_cidkeyed_font(
    @pdflite.pdf_dictionary([
      (text_name_for_test("/BaseFont"), PdfNameObject(text_name_for_test("/T"))),
    ]),
  )
  guard missing_descendant is Err(DescendantFontExpected) else {
    fail("expected DescendantFontExpected")
  }

  let bad_system_info = @pdflite.pdf_dictionary([
    (
      text_name_for_test("/CIDSystemInfo"),
      @pdflite.pdf_dictionary([
        (text_name_for_test("/Ordering"), PdfString(text_bytes_for_test([79]))),
        (text_name_for_test("/Supplement"), PdfInteger(0)),
      ]),
    ),
    (
      text_name_for_test("/BaseFont"),
      PdfNameObject(text_name_for_test("/Descendant")),
    ),
    (text_name_for_test("/FontDescriptor"), @pdflite.pdf_dictionary([])),
  ])
  doc.add_object_given_number(6, bad_system_info)
  let bad_system_font = @pdflite.pdf_dictionary([
    (text_name_for_test("/BaseFont"), PdfNameObject(text_name_for_test("/T"))),
    (text_name_for_test("/DescendantFonts"), PdfArray([PdfIndirect(6)])),
    (
      text_name_for_test("/Encoding"),
      PdfNameObject(text_name_for_test("/Identity-H")),
    ),
  ])
  let system_result = try? doc.read_cidkeyed_font(bad_system_font)
  guard system_result is Err(CIDRegistryExpected) else {
    fail("expected CIDRegistryExpected")
  }

  let bad_widths = @pdflite.pdf_dictionary([
    (
      text_name_for_test("/CIDSystemInfo"),
      @pdflite.pdf_dictionary([
        (text_name_for_test("/Registry"), PdfString(text_bytes_for_test([82]))),
        (text_name_for_test("/Ordering"), PdfString(text_bytes_for_test([79]))),
        (text_name_for_test("/Supplement"), PdfInteger(0)),
      ]),
    ),
    (
      text_name_for_test("/BaseFont"),
      PdfNameObject(text_name_for_test("/Descendant")),
    ),
    (text_name_for_test("/FontDescriptor"), @pdflite.pdf_dictionary([])),
    (
      text_name_for_test("/W"),
      PdfArray([PdfInteger(5), PdfInteger(4), PdfInteger(100)]),
    ),
  ])
  doc.add_object_given_number(7, bad_widths)
  let bad_widths_font = @pdflite.pdf_dictionary([
    (text_name_for_test("/BaseFont"), PdfNameObject(text_name_for_test("/T"))),
    (text_name_for_test("/DescendantFonts"), PdfArray([PdfIndirect(7)])),
    (
      text_name_for_test("/Encoding"),
      PdfNameObject(text_name_for_test("/Identity-H")),
    ),
  ])
  let widths_result = try? doc.read_cidkeyed_font(bad_widths_font)
  guard widths_result is Err(CIDWidthsExpected) else {
    fail("expected CIDWidthsExpected")
  }

  let bad_widths2 = @pdflite.pdf_dictionary([
    (
      text_name_for_test("/CIDSystemInfo"),
      @pdflite.pdf_dictionary([
        (text_name_for_test("/Registry"), PdfString(text_bytes_for_test([82]))),
        (text_name_for_test("/Ordering"), PdfString(text_bytes_for_test([79]))),
        (text_name_for_test("/Supplement"), PdfInteger(0)),
      ]),
    ),
    (
      text_name_for_test("/BaseFont"),
      PdfNameObject(text_name_for_test("/Descendant")),
    ),
    (text_name_for_test("/FontDescriptor"), @pdflite.pdf_dictionary([])),
    (
      text_name_for_test("/W2"),
      PdfArray([PdfInteger(5), PdfArray([PdfInteger(100), PdfInteger(1)])]),
    ),
  ])
  doc.add_object_given_number(8, bad_widths2)
  let bad_widths2_font = @pdflite.pdf_dictionary([
    (text_name_for_test("/BaseFont"), PdfNameObject(text_name_for_test("/T"))),
    (text_name_for_test("/DescendantFonts"), PdfArray([PdfIndirect(8)])),
    (
      text_name_for_test("/Encoding"),
      PdfNameObject(text_name_for_test("/Identity-H")),
    ),
  ])
  let widths2_result = try? doc.read_cidkeyed_font(bad_widths2_font)
  guard widths2_result is Err(CIDWidths2Expected) else {
    fail("expected CIDWidths2Expected")
  }

  let valid_descendant = @pdflite.pdf_dictionary([
    (
      text_name_for_test("/CIDSystemInfo"),
      @pdflite.pdf_dictionary([
        (text_name_for_test("/Registry"), PdfString(text_bytes_for_test([82]))),
        (text_name_for_test("/Ordering"), PdfString(text_bytes_for_test([79]))),
        (text_name_for_test("/Supplement"), PdfInteger(0)),
      ]),
    ),
    (
      text_name_for_test("/BaseFont"),
      PdfNameObject(text_name_for_test("/Descendant")),
    ),
    (text_name_for_test("/FontDescriptor"), @pdflite.pdf_dictionary([])),
  ])
  doc.add_object_given_number(9, valid_descendant)
  let direct_cmap = @pdflite.pdf_dictionary([
    (text_name_for_test("/BaseFont"), PdfNameObject(text_name_for_test("/T"))),
    (text_name_for_test("/DescendantFonts"), PdfArray([PdfIndirect(9)])),
    (
      text_name_for_test("/Encoding"),
      @pdflite.pdf_stream(@pdflite.pdf_dictionary([]), StreamGot([])),
    ),
  ])
  let direct_cmap_result = try? doc.read_cidkeyed_font(direct_cmap)
  guard direct_cmap_result is Err(CMapEncodingExpected) else {
    fail("expected CMapEncodingExpected")
  }
}

///|
test "PdfDocument write_encoding writes custom differences" {
  let doc = @pdflite.pdf_document_empty()
  let number = try! doc.write_encoding(
    PdfCustomEncoding(PdfImplicitInFontFile, [
      text_difference_for_test("/A", 65),
      text_difference_for_test("/B", 66),
    ]),
  )
  @test.assert_eq(
    doc.lookup_object_or_null(number),
    @pdflite.pdf_dictionary([
      (
        text_name_for_test("/Type"),
        PdfNameObject(text_name_for_test("/Encoding")),
      ),
      (
        text_name_for_test("/Differences"),
        PdfArray([
          PdfInteger(65),
          PdfNameObject(text_name_for_test("/A")),
          PdfInteger(66),
          PdfNameObject(text_name_for_test("/B")),
        ]),
      ),
    ]),
  )
  let unsupported = try? doc.write_encoding(PdfWinAnsiEncoding)
  guard unsupported is Err(EncodingWriteUnsupported) else {
    fail("expected EncodingWriteUnsupported")
  }
}

///|
test "pdf_make_font builds Type1 font dictionaries" {
  @test.assert_eq(
    try! @pdflite.pdf_make_font(
      text_name_for_test("/Helvetica"),
      PdfWinAnsiEncoding,
    ),
    @pdflite.pdf_dictionary([
      (text_name_for_test("/Type"), PdfNameObject(text_name_for_test("/Font"))),
      (
        text_name_for_test("/Subtype"),
        PdfNameObject(text_name_for_test("/Type1")),
      ),
      (
        text_name_for_test("/Encoding"),
        PdfNameObject(text_name_for_test("/WinAnsiEncoding")),
      ),
      (
        text_name_for_test("/BaseFont"),
        PdfNameObject(text_name_for_test("/Helvetica")),
      ),
    ]),
  )
  let custom = try? @pdflite.pdf_make_font(
    text_name_for_test("/Custom"),
    PdfCustomEncoding(PdfImplicitInFontFile, []),
  )
  guard custom is Err(EncodingWriteUnsupported) else {
    fail("expected EncodingWriteUnsupported")
  }
}

///|
test "PdfDocument write_font writes standard14 fonts" {
  let doc = @pdflite.pdf_document_empty()
  let number = try! doc.write_font(
    PdfFontStandard(
      text_standard_font_data_for_test(PdfHelveticaBold, PdfWinAnsiEncoding),
    ),
  )
  @test.assert_eq(number, 1)
  @test.assert_eq(
    doc.lookup_object_or_null(number),
    @pdflite.pdf_dictionary([
      (text_name_for_test("/Type"), PdfNameObject(text_name_for_test("/Font"))),
      (
        text_name_for_test("/Subtype"),
        PdfNameObject(text_name_for_test("/Type1")),
      ),
      (
        text_name_for_test("/Encoding"),
        PdfNameObject(text_name_for_test("/WinAnsiEncoding")),
      ),
      (
        text_name_for_test("/BaseFont"),
        PdfNameObject(text_name_for_test("/Helvetica-Bold")),
      ),
    ]),
  )

  let fixed_number = try! doc.write_font(
    PdfFontStandard(
      text_standard_font_data_for_test(PdfTimesRoman, PdfMacRomanEncoding),
    ),
    objnum=Some(20),
  )
  @test.assert_eq(fixed_number, 20)
  @test.assert_eq(
    doc.lookup_object_or_null(20),
    @pdflite.pdf_dictionary([
      (text_name_for_test("/Type"), PdfNameObject(text_name_for_test("/Font"))),
      (
        text_name_for_test("/Subtype"),
        PdfNameObject(text_name_for_test("/Type1")),
      ),
      (
        text_name_for_test("/Encoding"),
        PdfNameObject(text_name_for_test("/MacRomanEncoding")),
      ),
      (
        text_name_for_test("/BaseFont"),
        PdfNameObject(text_name_for_test("/Times-Roman")),
      ),
    ]),
  )
}

///|
test "PdfDocument write_font writes Type3 fonts" {
  let doc = @pdflite.pdf_document_empty()
  let number = try! doc.write_font(
    PdfFontSimple({
      fonttype: PdfType3({
        fontbbox: { min_x: 1.0, min_y: 2.0, max_x: 3.0, max_y: 4.0 },
        fontmatrix: @pdflite.transform_identity_matrix,
        charprocs: [
          (text_name_for_test("/A"), PdfInteger(10)),
          (text_name_for_test("/B"), PdfInteger(11)),
        ],
        resources: @pdflite.pdf_dictionary([
          (text_name_for_test("/ProcSet"), PdfArray([])),
        ]),
      }),
      basefont: None,
      firstchar: 0,
      lastchar: 0,
      widths: [],
      fontdescriptor: Some(text_font_descriptor_for_test()),
      fontmetrics: None,
      encoding: PdfImplicitInFontFile,
    }),
  )
  @test.assert_eq(number, 1)
  @test.assert_eq(
    doc.lookup_object_or_null(number),
    @pdflite.pdf_dictionary([
      (text_name_for_test("/Type"), PdfNameObject(text_name_for_test("/Font"))),
      (
        text_name_for_test("/Subtype"),
        PdfNameObject(text_name_for_test("/Type3")),
      ),
      (
        text_name_for_test("/FontBBox"),
        PdfArray([PdfReal(0.0), PdfReal(0.0), PdfReal(0.0), PdfReal(0.0)]),
      ),
      (
        text_name_for_test("/FontMatrix"),
        PdfArray([
          PdfReal(0.0),
          PdfReal(0.0),
          PdfReal(0.0),
          PdfReal(0.0),
          PdfReal(0.0),
          PdfReal(0.0),
        ]),
      ),
      (
        text_name_for_test("/CharProcs"),
        @pdflite.pdf_dictionary([
          (text_name_for_test("/A"), PdfNull),
          (text_name_for_test("/B"), PdfNull),
        ]),
      ),
      (text_name_for_test("/FirstChar"), PdfInteger(0)),
      (text_name_for_test("/LastChar"), PdfInteger(0)),
      (text_name_for_test("/Widths"), PdfArray([PdfReal(0.0)])),
    ]),
  )
}

///|
test "PdfDocument write_font writes Type3 custom encoding object" {
  let doc = @pdflite.pdf_document_empty()
  let number = try! doc.write_font(
    PdfFontSimple({
      fonttype: PdfType3({
        fontbbox: { min_x: 0.0, min_y: 0.0, max_x: 0.0, max_y: 0.0 },
        fontmatrix: @pdflite.transform_identity_matrix,
        charprocs: [(text_name_for_test("/A"), PdfInteger(10))],
        resources: @pdflite.pdf_dictionary([]),
      }),
      basefont: None,
      firstchar: 0,
      lastchar: 0,
      widths: [],
      fontdescriptor: Some(text_font_descriptor_for_test()),
      fontmetrics: None,
      encoding: PdfCustomEncoding(PdfImplicitInFontFile, [
        text_difference_for_test("/A", 65),
      ]),
    }),
    objnum=Some(20),
  )
  @test.assert_eq(number, 20)
  @test.assert_eq(
    doc.lookup_object_or_null(1),
    @pdflite.pdf_dictionary([
      (
        text_name_for_test("/Type"),
        PdfNameObject(text_name_for_test("/Encoding")),
      ),
      (
        text_name_for_test("/Differences"),
        PdfArray([PdfInteger(65), PdfNameObject(text_name_for_test("/A"))]),
      ),
    ]),
  )
  @test.assert_eq(
    doc
    .lookup_object_or_null(20)
    .lookup_immediate(text_name_for_test("/Encoding")),
    Some(PdfIndirect(1)),
  )
}

///|
test "PdfDocument write_font writes embedded TrueType fonts" {
  let doc = @pdflite.pdf_document_empty()
  let descriptor : @pdflite.PdfFontDescriptor = {
    ..text_font_descriptor_for_test(),
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
      basefont: Some(text_name_for_test("/Subset+Custom")),
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
        text_name_for_test("/Type"),
        PdfNameObject(text_name_for_test("/FontDescriptor")),
      ),
      (
        text_name_for_test("/FontName"),
        PdfNameObject(text_name_for_test("/Subset+Custom")),
      ),
      (text_name_for_test("/Flags"), PdfInteger(32)),
      (
        text_name_for_test("/FontBBox"),
        PdfArray([
          PdfInteger(-10),
          PdfInteger(-200),
          PdfInteger(500),
          PdfInteger(700),
        ]),
      ),
      (text_name_for_test("/ItalicAngle"), PdfInteger(-12)),
      (text_name_for_test("/Ascent"), PdfInteger(720)),
      (text_name_for_test("/Descent"), PdfInteger(-180)),
      (text_name_for_test("/CapHeight"), PdfInteger(680)),
      (text_name_for_test("/StemV"), PdfInteger(90)),
      (text_name_for_test("/XHeight"), PdfInteger(450)),
      (text_name_for_test("/AvgWidth"), PdfInteger(501)),
      (text_name_for_test("/MaxWidth"), PdfInteger(1000)),
      (text_name_for_test("/FontFile2"), PdfIndirect(9)),
    ]),
  )
  @test.assert_eq(
    doc.lookup_object_or_null(number),
    @pdflite.pdf_dictionary([
      (text_name_for_test("/Type"), PdfNameObject(text_name_for_test("/Font"))),
      (
        text_name_for_test("/Subtype"),
        PdfNameObject(text_name_for_test("/TrueType")),
      ),
      (
        text_name_for_test("/BaseFont"),
        PdfNameObject(text_name_for_test("/Subset+Custom")),
      ),
      (text_name_for_test("/FontDescriptor"), PdfIndirect(1)),
      (text_name_for_test("/FirstChar"), PdfInteger(65)),
      (text_name_for_test("/LastChar"), PdfInteger(66)),
      (
        text_name_for_test("/Widths"),
        PdfArray([PdfInteger(500), PdfInteger(610)]),
      ),
      (
        text_name_for_test("/Encoding"),
        PdfNameObject(text_name_for_test("/WinAnsiEncoding")),
      ),
    ]),
  )
}

///|
test "PdfDocument write_font places embedded TrueType fonts at requested object number" {
  let doc = @pdflite.pdf_document_empty()
  let descriptor : @pdflite.PdfFontDescriptor = {
    ..text_font_descriptor_for_test(),
    fontfile: Some(PdfFontFile2(7)),
  }
  let number = try! doc.write_font(
    PdfFontSimple({
      fonttype: PdfTrueType,
      basefont: Some(text_name_for_test("/Placed")),
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
    .lookup_immediate(text_name_for_test("/FontDescriptor")),
    Some(PdfIndirect(1)),
  )
  @test.assert_eq(
    doc
    .lookup_object_or_null(20)
    .lookup_immediate(text_name_for_test("/Encoding")),
    Some(PdfNameObject(text_name_for_test("/MacRomanEncoding"))),
  )
}

///|
test "PdfDocument write_font writes TrueType ToUnicode CMaps" {
  let doc = @pdflite.pdf_document_empty()
  let descriptor : @pdflite.PdfFontDescriptor = {
    ..text_font_descriptor_for_test(),
    fontfile: Some(PdfFontFile2(7)),
    tounicode: Some([
      (9, text_bytes_for_test([0x00, 0x42])),
      (3, text_bytes_for_test([0x00, 0x41])),
    ]),
  }
  let number = try! doc.write_font(
    PdfFontSimple({
      fonttype: PdfTrueType,
      basefont: Some(text_name_for_test("/WithToUnicode")),
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
    .lookup_immediate(text_name_for_test("/ToUnicode")),
    Some(PdfIndirect(2)),
  )
  @test.assert_eq(
    doc
    .lookup_object_or_null(3)
    .lookup_immediate(text_name_for_test("/Encoding")),
    None,
  )
  guard doc.lookup_object_or_null(2) is PdfStreamObject(stream) else {
    fail("expected ToUnicode stream")
  }
  guard stream.data is StreamGot(bytes) else {
    fail("expected owned ToUnicode bytes")
  }
  @test.assert_eq(
    stream.dictionary.lookup_immediate(text_name_for_test("/Length")),
    Some(PdfInteger(bytes.length())),
  )
  @test.assert_eq(
    try! @ascii.decode(bytes[:]),
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
      (33, text_bytes_for_test([0x00, 0x41])),
      (34, text_bytes_for_test([0x00, 0x42])),
    ]),
  )
  let extractor = try! doc.text_extractor_of_font(
    doc.lookup_object_or_null(number),
  )
  @test.assert_eq(
    try! extractor.codepoints_of_text(text_bytes_for_test([33, 34, 35])[:]),
    [0x41, 0x42, 35],
  )
  @test.assert_eq(
    try! extractor.glyphnames_and_codepoints_of_text(
      text_bytes_for_test([33, 34, 35])[:],
    ),
    [
      {
        glyphname: @pdflite.pdf_name_of_bytes(
          text_bytes_for_test([47, 0x00, 0x41]),
        ),
        codepoints: [0x41],
      },
      {
        glyphname: @pdflite.pdf_name_of_bytes(
          text_bytes_for_test([47, 0x00, 0x42]),
        ),
        codepoints: [0x42],
      },
      { glyphname: text_name_for_test(".notdef"), codepoints: [35] },
    ],
  )
  @test.assert_eq(
    try! extractor.glyphnames_of_text(text_bytes_for_test([33, 35])[:]),
    [
      @pdflite.pdf_name_of_bytes(text_bytes_for_test([47, 0x00, 0x41])),
      text_name_for_test(".notdef"),
    ],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x42), Some(34))
  @test.assert_eq(extractor.charcode_of_codepoint(0x43), None)
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
        "2 beginbfrange <2C><2D><0064> <2E><2F><0066> endbfrange\n",
      ),
    ),
  )
  doc.add_object_given_number(2, tounicode)
  let font = @pdflite.pdf_dictionary([
    (
      text_name_for_test("/Subtype"),
      PdfNameObject(text_name_for_test("/Type1")),
    ),
    (
      text_name_for_test("/BaseFont"),
      PdfNameObject(text_name_for_test("/Custom")),
    ),
    (text_name_for_test("/ToUnicode"), PdfIndirect(2)),
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
      (33, text_bytes_for_test([0x00, 0x41])),
      (37, text_bytes_for_test([0x20, 0xAC])),
      (34, text_bytes_for_test([0x00, 0x42])),
      (35, text_bytes_for_test([0x00, 0x43])),
      (36, text_bytes_for_test([0x00, 0x44])),
      (38, text_bytes_for_test([0x00, 0x58])),
      (39, text_bytes_for_test([0x00, 0x59])),
      (40, text_bytes_for_test([0x00, 0x5A])),
      (43, text_bytes_for_test([0x00, 0x63])),
      (41, text_bytes_for_test([0x00, 0x61])),
      (42, text_bytes_for_test([0x00, 0x62])),
      (44, text_bytes_for_test([0x00, 0x64])),
      (45, text_bytes_for_test([0x00, 0x65])),
      (46, text_bytes_for_test([0x00, 0x66])),
      (47, text_bytes_for_test([0x00, 0x67])),
    ]),
  )
  let extractor = try! doc.text_extractor_of_font(font)
  @test.assert_eq(
    try! extractor.codepoints_of_text(
      text_bytes_for_test([
        33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48,
      ])[:],
    ),
    [
      0x41, 0x42, 0x43, 0x44, 0x20AC, 0x58, 0x59, 0x5A, 0x61, 0x62, 0x63, 0x64, 0x65,
      0x66, 0x67, 48,
    ],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x20AC), Some(37))
  @test.assert_eq(extractor.charcode_of_codepoint(0x59), Some(39))
  @test.assert_eq(extractor.charcode_of_codepoint(0x5A), Some(40))
  @test.assert_eq(extractor.charcode_of_codepoint(0x62), Some(42))
  @test.assert_eq(extractor.charcode_of_codepoint(0x63), Some(43))
  @test.assert_eq(extractor.charcode_of_codepoint(0x64), Some(44))
  @test.assert_eq(extractor.charcode_of_codepoint(0x67), Some(47))
  @test.assert_eq(extractor.charcode_of_codepoint(0x45), None)
}

///|
test "PdfDocument decodes filtered ToUnicode CMap streams" {
  let doc = @pdflite.pdf_document_empty()
  let cmap = @ascii.encode("1 beginbfchar\n<41><005A>\nendbfchar\n")
  let encoded = @pdflite.pdf_ascii_hex_encode(cmap)
  let tounicode = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (text_name_for_test("/Length"), PdfInteger(encoded.length())),
      (
        text_name_for_test("/Filter"),
        PdfNameObject(text_name_for_test("/ASCIIHexDecode")),
      ),
    ]),
    StreamGot(encoded),
  )
  doc.add_object_given_number(2, tounicode)
  let font = @pdflite.pdf_dictionary([
    (
      text_name_for_test("/Subtype"),
      PdfNameObject(text_name_for_test("/Type1")),
    ),
    (
      text_name_for_test("/BaseFont"),
      PdfNameObject(text_name_for_test("/Custom")),
    ),
    (text_name_for_test("/ToUnicode"), PdfIndirect(2)),
  ])
  let extractor = try! doc.text_extractor_of_font(font)
  @test.assert_eq(
    try! extractor.codepoints_of_text(text_bytes_for_test([65, 66])[:]),
    [0x5A, 66],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x5A), Some(65))
}

///|
test "PdfTextExtractor reads Identity-H text as two-byte character codes" {
  let cid_font : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_name_for_test("/Top"),
    composite: {
      cid_system_info: {
        registry: text_bytes_for_test([65]),
        ordering: text_bytes_for_test([73]),
        supplement: 0,
      },
      cid_basefont: text_name_for_test("/Descendant"),
      cid_fontdescriptor: text_font_descriptor_for_test(),
      cid_widths: [],
      cid_widths2: [],
      cid_default_width: 1000.0,
      cid_default_width2: [880.0, -1000.0],
    },
    encoding: PdfPredefinedCMap(text_name_for_test("/Identity-H")),
  })
  let extractor = cid_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(
      text_bytes_for_test([0x00, 0x41, 0x20, 0xAC])[:],
    ),
    [0x41, 0x20AC],
  )
  @test.assert_eq(
    try! extractor.glyphnames_of_text(text_bytes_for_test([0x00, 0x41])[:]),
    [text_name_for_test(".notdef")],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x41), None)
  let odd = try? extractor.codepoints_of_text(text_bytes_for_test([0x00])[:])
  guard odd is Err(BadText) else { fail("expected BadText") }
}

///|
test "PdfTextExtractor extracts StandardEncoding Basic Latin glyphs" {
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(PdfHelvetica, PdfStandardEncoding),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(text_bytes_for_test([65, 39, 96])[:]),
    [65, 0x2019, 0x2018],
  )
  @test.assert_eq(
    try! extractor.glyphnames_of_text(text_bytes_for_test([65, 39, 96])[:]),
    [
      text_name_for_test("/A"),
      text_name_for_test("/quoteright"),
      text_name_for_test("/quoteleft"),
    ],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(65), Some(65))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2019), Some(39))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2018), Some(96))
  @test.assert_eq(extractor.charcode_of_codepoint(39), Some(0xA9))
  @test.assert_eq(
    try! extractor.codepoints_of_text(
      text_bytes_for_test([0xA9, 0xAE, 0xAF, 0xB1, 0xB7, 0xBC])[:],
    ),
    [39, 0xFB01, 0xFB02, 0x2013, 0x2022, 0x2026],
  )
  @test.assert_eq(
    try! extractor.glyphnames_of_text(
      text_bytes_for_test([0xA9, 0xAE, 0xAF, 0xB1, 0xB7, 0xBC])[:],
    ),
    [
      text_name_for_test("/quotesingle"),
      text_name_for_test("/fi"),
      text_name_for_test("/fl"),
      text_name_for_test("/endash"),
      text_name_for_test("/bullet"),
      text_name_for_test("/ellipsis"),
    ],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0xFB01), Some(0xAE))
  @test.assert_eq(extractor.charcode_of_codepoint(0xFB02), Some(0xAF))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2022), Some(0xB7))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2026), Some(0xBC))
  @test.assert_eq(
    try! extractor.codepoints_of_text(
      text_bytes_for_test([
        0xC1, 0xC2, 0xC6, 0xC7, 0xCA, 0xCD, 0xCF, 0xD0, 0xE1, 0xE8, 0xEA, 0xF1, 0xF5,
        0xF8, 0xFA, 0xFB,
      ])[:],
    ),
    [
      96, 0x00B4, 0x02D8, 0x02D9, 0x02DA, 0x02DD, 0x02C7, 0x2014, 0x00C6, 0x0141,
      0x0152, 0x00E6, 0x0131, 0x0142, 0x0153, 0x00DF,
    ],
  )
  @test.assert_eq(
    try! extractor.glyphnames_of_text(
      text_bytes_for_test([
        0xC1, 0xC2, 0xC6, 0xC7, 0xCA, 0xCD, 0xCF, 0xD0, 0xE1, 0xE8, 0xEA, 0xF1, 0xF5,
        0xF8, 0xFA, 0xFB,
      ])[:],
    ),
    [
      text_name_for_test("/grave"),
      text_name_for_test("/acute"),
      text_name_for_test("/breve"),
      text_name_for_test("/dotaccent"),
      text_name_for_test("/ring"),
      text_name_for_test("/hungarumlaut"),
      text_name_for_test("/caron"),
      text_name_for_test("/emdash"),
      text_name_for_test("/AE"),
      text_name_for_test("/Lslash"),
      text_name_for_test("/OE"),
      text_name_for_test("/ae"),
      text_name_for_test("/dotlessi"),
      text_name_for_test("/lslash"),
      text_name_for_test("/oe"),
      text_name_for_test("/germandbls"),
    ],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x02D8), Some(0xC6))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2014), Some(0xD0))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00C6), Some(0xE1))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0141), Some(0xE8))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0131), Some(0xF5))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00DF), Some(0xFB))
}

///|
test "PdfTextExtractor extracts MacRoman accented glyphs" {
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(PdfHelvetica, PdfMacRomanEncoding),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(
      text_bytes_for_test([0x80, 0x81, 0x82, 0x83, 0x87, 0x8E])[:],
    ),
    [0x00C4, 0x00C5, 0x00C7, 0x00C9, 0x00E1, 0x00E9],
  )
  @test.assert_eq(
    try! extractor.glyphnames_of_text(
      text_bytes_for_test([0x80, 0x81, 0x82, 0x83, 0x87, 0x8E])[:],
    ),
    [
      text_name_for_test("/Adieresis"),
      text_name_for_test("/Aring"),
      text_name_for_test("/Ccedilla"),
      text_name_for_test("/Eacute"),
      text_name_for_test("/aacute"),
      text_name_for_test("/eacute"),
    ],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x00C4), Some(0x80))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00C9), Some(0x83))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00E1), Some(0x87))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00E9), Some(0x8E))
  @test.assert_eq(
    try! extractor.codepoints_of_text(
      text_bytes_for_test([
        0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9A, 0x9B, 0x9C, 0x9D, 0x9E,
        0x9F,
      ])[:],
    ),
    [
      0x00ED, 0x00EC, 0x00EE, 0x00EF, 0x00F1, 0x00F3, 0x00F2, 0x00F4, 0x00F6, 0x00F5,
      0x00FA, 0x00F9, 0x00FB, 0x00FC,
    ],
  )
  @test.assert_eq(
    try! extractor.glyphnames_of_text(
      text_bytes_for_test([
        0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9A, 0x9B, 0x9C, 0x9D, 0x9E,
        0x9F,
      ])[:],
    ),
    [
      text_name_for_test("/iacute"),
      text_name_for_test("/igrave"),
      text_name_for_test("/icircumflex"),
      text_name_for_test("/idieresis"),
      text_name_for_test("/ntilde"),
      text_name_for_test("/oacute"),
      text_name_for_test("/ograve"),
      text_name_for_test("/ocircumflex"),
      text_name_for_test("/odieresis"),
      text_name_for_test("/otilde"),
      text_name_for_test("/uacute"),
      text_name_for_test("/ugrave"),
      text_name_for_test("/ucircumflex"),
      text_name_for_test("/udieresis"),
    ],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x00ED), Some(0x92))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00F1), Some(0x96))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00F3), Some(0x97))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00FA), Some(0x9C))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00FC), Some(0x9F))
}

///|
test "PdfTextExtractor extracts WinAnsi glyphs" {
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(PdfHelvetica, PdfWinAnsiEncoding),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(
      text_bytes_for_test([39, 96, 0x80, 0x91, 0x92, 0x96, 0x97, 0xA9, 0xE9])[:],
    ),
    [39, 96, 0x20AC, 0x2018, 0x2019, 0x2013, 0x2014, 0x00A9, 0x00E9],
  )
  @test.assert_eq(
    try! extractor.glyphnames_of_text(
      text_bytes_for_test([39, 96, 0x80, 0x91, 0x92, 0x96, 0x97, 0xA9, 0xE9])[:],
    ),
    [
      text_name_for_test("/quotesingle"),
      text_name_for_test("/grave"),
      text_name_for_test("/Euro"),
      text_name_for_test("/quoteleft"),
      text_name_for_test("/quoteright"),
      text_name_for_test("/endash"),
      text_name_for_test("/emdash"),
      text_name_for_test("/copyright"),
      text_name_for_test("/eacute"),
    ],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(39), Some(39))
  @test.assert_eq(extractor.charcode_of_codepoint(96), Some(96))
  @test.assert_eq(extractor.charcode_of_codepoint(0x20AC), Some(0x80))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2018), Some(0x91))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2019), Some(0x92))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2013), Some(0x96))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2014), Some(0x97))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00A9), Some(0xA9))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00E9), Some(0xE9))
  @test.assert_eq(
    try! extractor.codepoints_of_text(
      text_bytes_for_test([
        0xA1, 0xA6, 0xAE, 0xB0, 0xB1, 0xBC, 0xC0, 0xC6, 0xD0, 0xD8, 0xDE, 0xE6, 0xF0,
        0xF8, 0xFE, 0xFF,
      ])[:],
    ),
    [
      0x00A1, 0x00A6, 0x00AE, 0x00B0, 0x00B1, 0x00BC, 0x00C0, 0x00C6, 0x00D0, 0x00D8,
      0x00DE, 0x00E6, 0x00F0, 0x00F8, 0x00FE, 0x00FF,
    ],
  )
  @test.assert_eq(
    try! extractor.glyphnames_of_text(
      text_bytes_for_test([
        0xA1, 0xA6, 0xAE, 0xB0, 0xB1, 0xBC, 0xC0, 0xC6, 0xD0, 0xD8, 0xDE, 0xE6, 0xF0,
        0xF8, 0xFE, 0xFF,
      ])[:],
    ),
    [
      text_name_for_test("/exclamdown"),
      text_name_for_test("/brokenbar"),
      text_name_for_test("/registered"),
      text_name_for_test("/degree"),
      text_name_for_test("/plusminus"),
      text_name_for_test("/onequarter"),
      text_name_for_test("/Agrave"),
      text_name_for_test("/AE"),
      text_name_for_test("/Eth"),
      text_name_for_test("/Oslash"),
      text_name_for_test("/Thorn"),
      text_name_for_test("/ae"),
      text_name_for_test("/eth"),
      text_name_for_test("/oslash"),
      text_name_for_test("/thorn"),
      text_name_for_test("/ydieresis"),
    ],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x00A6), Some(0xA6))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00B1), Some(0xB1))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00C0), Some(0xC0))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00C6), Some(0xC6))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00F0), Some(0xF0))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00FF), Some(0xFF))
}

///|
test "PdfTextExtractor extracts MacExpert ligatures" {
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(PdfHelvetica, PdfMacExpertEncoding),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(
      text_bytes_for_test([0x56, 0x57, 0x58, 0x59, 0x5A])[:],
    ),
    [0xFB00, 0xFB01, 0xFB02, 0xFB03, 0xFB04],
  )
  @test.assert_eq(
    try! extractor.glyphnames_of_text(
      text_bytes_for_test([0x56, 0x57, 0x58, 0x59, 0x5A])[:],
    ),
    [
      text_name_for_test("/ff"),
      text_name_for_test("/fi"),
      text_name_for_test("/fl"),
      text_name_for_test("/ffi"),
      text_name_for_test("/ffl"),
    ],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0xFB00), Some(0x56))
  @test.assert_eq(extractor.charcode_of_codepoint(0xFB01), Some(0x57))
  @test.assert_eq(extractor.charcode_of_codepoint(0xFB02), Some(0x58))
  @test.assert_eq(extractor.charcode_of_codepoint(0xFB03), Some(0x59))
  @test.assert_eq(extractor.charcode_of_codepoint(0xFB04), Some(0x5A))
}

///|
test "PdfTextExtractor uses built-in Standard14 encodings when implicit" {
  let helvetica : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(PdfHelvetica, PdfImplicitInFontFile),
  )
  let helvetica_extractor = helvetica.text_extractor()
  @test.assert_eq(
    try! helvetica_extractor.codepoints_of_text(
      text_bytes_for_test([65, 39, 96, 0xAE])[:],
    ),
    [65, 0x2019, 0x2018, 0xFB01],
  )
  @test.assert_eq(
    try! helvetica_extractor.glyphnames_of_text(
      text_bytes_for_test([65, 39, 96, 0xAE])[:],
    ),
    [
      text_name_for_test("/A"),
      text_name_for_test("/quoteright"),
      text_name_for_test("/quoteleft"),
      text_name_for_test("/fi"),
    ],
  )
  @test.assert_eq(helvetica_extractor.charcode_of_codepoint(65), Some(65))
  @test.assert_eq(helvetica_extractor.charcode_of_codepoint(0xFB01), Some(0xAE))
}

///|
test "PdfTextExtractor extracts implicit Symbol glyphs" {
  let symbol_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(PdfSymbol, PdfImplicitInFontFile),
  )
  let extractor = symbol_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(
      text_bytes_for_test([0x41, 0x61, 0xA5, 0xAE, 0xB3, 0xD6])[:],
    ),
    [0x0391, 0x03B1, 0x221E, 0x2192, 0x2265, 0x221A],
  )
  @test.assert_eq(
    try! extractor.glyphnames_of_text(
      text_bytes_for_test([0x41, 0x61, 0xA5, 0xAE, 0xB3, 0xD6])[:],
    ),
    [
      text_name_for_test("/Alpha"),
      text_name_for_test("/alpha"),
      text_name_for_test("/infinity"),
      text_name_for_test("/arrowright"),
      text_name_for_test("/greaterequal"),
      text_name_for_test("/radical"),
    ],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x0391), Some(0x41))
  @test.assert_eq(extractor.charcode_of_codepoint(0x03B1), Some(0x61))
  @test.assert_eq(extractor.charcode_of_codepoint(0x221E), Some(0xA5))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2192), Some(0xAE))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2265), Some(0xB3))
  @test.assert_eq(extractor.charcode_of_codepoint(0x221A), Some(0xD6))
}

///|
test "PdfTextExtractor extracts implicit Symbol set and logic glyphs" {
  let symbol_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(PdfSymbol, PdfImplicitInFontFile),
  )
  let extractor = symbol_font.text_extractor()
  let text = text_bytes_for_test([
    0x40, 0x5C, 0x5E, 0x7E, 0xC0, 0xC4, 0xC5, 0xC6, 0xC7, 0xC8, 0xCE, 0xCF, 0xD0,
    0xD1, 0xD5, 0xD8, 0xD9, 0xDA, 0xDB, 0xDC, 0xDE, 0xDF, 0xE5,
  ])
  @test.assert_eq(try! extractor.codepoints_of_text(text[:]), [
    0x2245, 0x2234, 0x22A5, 0x223C, 0x2135, 0x2297, 0x2295, 0x2205, 0x2229, 0x222A,
    0x2208, 0x2209, 0x2220, 0x2207, 0x220F, 0x00AC, 0x2227, 0x2228, 0x21D4, 0x21D0,
    0x21D2, 0x21D3, 0x2211,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(text[:]), [
    text_name_for_test("/congruent"),
    text_name_for_test("/therefore"),
    text_name_for_test("/perpendicular"),
    text_name_for_test("/similar"),
    text_name_for_test("/aleph"),
    text_name_for_test("/circlemultiply"),
    text_name_for_test("/circleplus"),
    text_name_for_test("/emptyset"),
    text_name_for_test("/intersection"),
    text_name_for_test("/union"),
    text_name_for_test("/element"),
    text_name_for_test("/notelement"),
    text_name_for_test("/angle"),
    text_name_for_test("/gradient"),
    text_name_for_test("/product"),
    text_name_for_test("/logicalnot"),
    text_name_for_test("/logicaland"),
    text_name_for_test("/logicalor"),
    text_name_for_test("/arrowdblboth"),
    text_name_for_test("/arrowdblleft"),
    text_name_for_test("/arrowdblright"),
    text_name_for_test("/arrowdbldown"),
    text_name_for_test("/summation"),
  ])
  @test.assert_eq(extractor.charcode_of_codepoint(0x2245), Some(0x40))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2205), Some(0xC6))
  @test.assert_eq(extractor.charcode_of_codepoint(0x222A), Some(0xC8))
  @test.assert_eq(extractor.charcode_of_codepoint(0x21D4), Some(0xDB))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2211), Some(0xE5))
}

///|
test "PdfTextExtractor extracts implicit ZapfDingbats glyphs" {
  let dingbat_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(PdfZapfDingbats, PdfImplicitInFontFile),
  )
  let extractor = dingbat_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(
      text_bytes_for_test([0x21, 0x22, 0x23, 0x48, 0xA1])[:],
    ),
    [0x2701, 0x2702, 0x2703, 0x2605, 0x2761],
  )
  @test.assert_eq(
    try! extractor.glyphnames_of_text(
      text_bytes_for_test([0x21, 0x22, 0x23, 0x48, 0xA1])[:],
    ),
    [
      text_name_for_test("/a1"),
      text_name_for_test("/a2"),
      text_name_for_test("/a202"),
      text_name_for_test("/a35"),
      text_name_for_test("/a101"),
    ],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x2701), Some(0x21))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2702), Some(0x22))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2703), Some(0x23))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2605), Some(0x48))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2761), Some(0xA1))
}

///|
test "PdfTextExtractor extracts implicit ZapfDingbats cross and star glyphs" {
  let dingbat_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(PdfZapfDingbats, PdfImplicitInFontFile),
  )
  let extractor = dingbat_font.text_extractor()
  let text = text_bytes_for_test([
    0x3A, 0x3B, 0x3C, 0x3D, 0x3E, 0x3F, 0x40, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46,
    0x47,
  ])
  @test.assert_eq(try! extractor.codepoints_of_text(text[:]), [
    0x271A, 0x271B, 0x271C, 0x271D, 0x271E, 0x271F, 0x2720, 0x2721, 0x2722, 0x2723,
    0x2724, 0x2725, 0x2726, 0x2727,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(text[:]), [
    text_name_for_test("/a26"),
    text_name_for_test("/a27"),
    text_name_for_test("/a28"),
    text_name_for_test("/a6"),
    text_name_for_test("/a7"),
    text_name_for_test("/a8"),
    text_name_for_test("/a9"),
    text_name_for_test("/a10"),
    text_name_for_test("/a29"),
    text_name_for_test("/a30"),
    text_name_for_test("/a31"),
    text_name_for_test("/a32"),
    text_name_for_test("/a33"),
    text_name_for_test("/a34"),
  ])
  @test.assert_eq(extractor.charcode_of_codepoint(0x271A), Some(0x3A))
  @test.assert_eq(extractor.charcode_of_codepoint(0x271D), Some(0x3D))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2721), Some(0x41))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2727), Some(0x47))
}

///|
test "PdfTextExtractor extracts implicit ZapfDingbats starburst glyphs" {
  let dingbat_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(PdfZapfDingbats, PdfImplicitInFontFile),
  )
  let extractor = dingbat_font.text_extractor()
  let text = text_bytes_for_test([
    0x4D, 0x4E, 0x4F, 0x50, 0x51, 0x52, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59,
    0x5A,
  ])
  @test.assert_eq(try! extractor.codepoints_of_text(text[:]), [
    0x272D, 0x272E, 0x272F, 0x2730, 0x2731, 0x2732, 0x2733, 0x2734, 0x2735, 0x2736,
    0x2737, 0x2738, 0x2739, 0x273A,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(text[:]), [
    text_name_for_test("/a40"),
    text_name_for_test("/a41"),
    text_name_for_test("/a42"),
    text_name_for_test("/a43"),
    text_name_for_test("/a44"),
    text_name_for_test("/a45"),
    text_name_for_test("/a46"),
    text_name_for_test("/a47"),
    text_name_for_test("/a48"),
    text_name_for_test("/a49"),
    text_name_for_test("/a50"),
    text_name_for_test("/a51"),
    text_name_for_test("/a52"),
    text_name_for_test("/a53"),
  ])
  @test.assert_eq(extractor.charcode_of_codepoint(0x272D), Some(0x4D))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2730), Some(0x50))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2737), Some(0x57))
  @test.assert_eq(extractor.charcode_of_codepoint(0x273A), Some(0x5A))
}

///|
test "PdfTextExtractor extracts implicit ZapfDingbats sparkle glyphs" {
  let dingbat_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(PdfZapfDingbats, PdfImplicitInFontFile),
  )
  let extractor = dingbat_font.text_extractor()
  let text = text_bytes_for_test([
    0x5B, 0x5C, 0x5D, 0x5E, 0x5F, 0x60, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67,
    0x68, 0x69, 0x6A, 0x6B,
  ])
  @test.assert_eq(try! extractor.codepoints_of_text(text[:]), [
    0x273B, 0x273C, 0x273D, 0x273E, 0x273F, 0x2740, 0x2741, 0x2742, 0x2743, 0x2744,
    0x2745, 0x2746, 0x2747, 0x2748, 0x2749, 0x274A, 0x274B,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(text[:]), [
    text_name_for_test("/a54"),
    text_name_for_test("/a55"),
    text_name_for_test("/a56"),
    text_name_for_test("/a57"),
    text_name_for_test("/a58"),
    text_name_for_test("/a59"),
    text_name_for_test("/a60"),
    text_name_for_test("/a61"),
    text_name_for_test("/a62"),
    text_name_for_test("/a63"),
    text_name_for_test("/a64"),
    text_name_for_test("/a65"),
    text_name_for_test("/a66"),
    text_name_for_test("/a67"),
    text_name_for_test("/a68"),
    text_name_for_test("/a69"),
    text_name_for_test("/a70"),
  ])
  @test.assert_eq(extractor.charcode_of_codepoint(0x273B), Some(0x5B))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2744), Some(0x64))
  @test.assert_eq(extractor.charcode_of_codepoint(0x274B), Some(0x6B))
}

///|
test "PdfTextExtractor extracts implicit ZapfDingbats geometric glyphs" {
  let dingbat_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(PdfZapfDingbats, PdfImplicitInFontFile),
  )
  let extractor = dingbat_font.text_extractor()
  let text = text_bytes_for_test([
    0x6C, 0x6D, 0x6E, 0x6F, 0x70, 0x71, 0x72, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78,
    0x79, 0x7A, 0x7B, 0x7C, 0x7D, 0x7E,
  ])
  @test.assert_eq(try! extractor.codepoints_of_text(text[:]), [
    0x25CF, 0x274D, 0x25A0, 0x274F, 0x2750, 0x2751, 0x2752, 0x25B2, 0x25BC, 0x25C6,
    0x2756, 0x25D7, 0x2758, 0x2759, 0x275A, 0x275B, 0x275C, 0x275D, 0x275E,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(text[:]), [
    text_name_for_test("/a71"),
    text_name_for_test("/a72"),
    text_name_for_test("/a73"),
    text_name_for_test("/a74"),
    text_name_for_test("/a203"),
    text_name_for_test("/a75"),
    text_name_for_test("/a204"),
    text_name_for_test("/a76"),
    text_name_for_test("/a77"),
    text_name_for_test("/a78"),
    text_name_for_test("/a79"),
    text_name_for_test("/a81"),
    text_name_for_test("/a82"),
    text_name_for_test("/a83"),
    text_name_for_test("/a84"),
    text_name_for_test("/a97"),
    text_name_for_test("/a98"),
    text_name_for_test("/a99"),
    text_name_for_test("/a100"),
  ])
  @test.assert_eq(extractor.charcode_of_codepoint(0x25CF), Some(0x6C))
  @test.assert_eq(extractor.charcode_of_codepoint(0x25B2), Some(0x73))
  @test.assert_eq(extractor.charcode_of_codepoint(0x275E), Some(0x7E))
}

///|
test "PdfTextExtractor extracts implicit ZapfDingbats card suit glyphs" {
  let dingbat_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(PdfZapfDingbats, PdfImplicitInFontFile),
  )
  let extractor = dingbat_font.text_extractor()
  let text = text_bytes_for_test([0xA6, 0xA7, 0xA8, 0xA9, 0xAA, 0xAB])
  @test.assert_eq(try! extractor.codepoints_of_text(text[:]), [
    0x2766, 0x2767, 0x2663, 0x2666, 0x2665, 0x2660,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(text[:]), [
    text_name_for_test("/a107"),
    text_name_for_test("/a108"),
    text_name_for_test("/a112"),
    text_name_for_test("/a111"),
    text_name_for_test("/a110"),
    text_name_for_test("/a109"),
  ])
  @test.assert_eq(extractor.charcode_of_codepoint(0x2766), Some(0xA6))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2663), Some(0xA8))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2660), Some(0xAB))
}

///|
test "PdfTextExtractor extracts implicit ZapfDingbats circled digits" {
  let dingbat_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(PdfZapfDingbats, PdfImplicitInFontFile),
  )
  let extractor = dingbat_font.text_extractor()
  let text = text_bytes_for_test([
    0xAC, 0xAD, 0xAE, 0xAF, 0xB0, 0xB1, 0xB2, 0xB3, 0xB4, 0xB5,
  ])
  @test.assert_eq(try! extractor.codepoints_of_text(text[:]), [
    0x2460, 0x2461, 0x2462, 0x2463, 0x2464, 0x2465, 0x2466, 0x2467, 0x2468, 0x2469,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(text[:]), [
    text_name_for_test("/a120"),
    text_name_for_test("/a121"),
    text_name_for_test("/a122"),
    text_name_for_test("/a123"),
    text_name_for_test("/a124"),
    text_name_for_test("/a125"),
    text_name_for_test("/a126"),
    text_name_for_test("/a127"),
    text_name_for_test("/a128"),
    text_name_for_test("/a129"),
  ])
  @test.assert_eq(extractor.charcode_of_codepoint(0x2460), Some(0xAC))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2465), Some(0xB1))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2469), Some(0xB5))
}

///|
test "PdfTextExtractor extracts implicit ZapfDingbats filled circled digits" {
  let dingbat_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(PdfZapfDingbats, PdfImplicitInFontFile),
  )
  let extractor = dingbat_font.text_extractor()
  let text = text_bytes_for_test([
    0xB6, 0xB7, 0xB8, 0xB9, 0xBA, 0xBB, 0xBC, 0xBD, 0xBE, 0xBF,
  ])
  @test.assert_eq(try! extractor.codepoints_of_text(text[:]), [
    0x2776, 0x2777, 0x2778, 0x2779, 0x277A, 0x277B, 0x277C, 0x277D, 0x277E, 0x277F,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(text[:]), [
    text_name_for_test("/a130"),
    text_name_for_test("/a131"),
    text_name_for_test("/a132"),
    text_name_for_test("/a133"),
    text_name_for_test("/a134"),
    text_name_for_test("/a135"),
    text_name_for_test("/a136"),
    text_name_for_test("/a137"),
    text_name_for_test("/a138"),
    text_name_for_test("/a139"),
  ])
  @test.assert_eq(extractor.charcode_of_codepoint(0x2776), Some(0xB6))
  @test.assert_eq(extractor.charcode_of_codepoint(0x277B), Some(0xBB))
  @test.assert_eq(extractor.charcode_of_codepoint(0x277F), Some(0xBF))
}

///|
test "PdfTextExtractor extracts implicit ZapfDingbats circled sans-serif digits" {
  let dingbat_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(PdfZapfDingbats, PdfImplicitInFontFile),
  )
  let extractor = dingbat_font.text_extractor()
  let text = text_bytes_for_test([
    0xC0, 0xC1, 0xC2, 0xC3, 0xC4, 0xC5, 0xC6, 0xC7, 0xC8, 0xC9,
  ])
  @test.assert_eq(try! extractor.codepoints_of_text(text[:]), [
    0x2780, 0x2781, 0x2782, 0x2783, 0x2784, 0x2785, 0x2786, 0x2787, 0x2788, 0x2789,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(text[:]), [
    text_name_for_test("/a140"),
    text_name_for_test("/a141"),
    text_name_for_test("/a142"),
    text_name_for_test("/a143"),
    text_name_for_test("/a144"),
    text_name_for_test("/a145"),
    text_name_for_test("/a146"),
    text_name_for_test("/a147"),
    text_name_for_test("/a148"),
    text_name_for_test("/a149"),
  ])
  @test.assert_eq(extractor.charcode_of_codepoint(0x2780), Some(0xC0))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2785), Some(0xC5))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2789), Some(0xC9))
}

///|
test "PdfTextExtractor extracts implicit ZapfDingbats negative circled sans-serif digits" {
  let dingbat_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(PdfZapfDingbats, PdfImplicitInFontFile),
  )
  let extractor = dingbat_font.text_extractor()
  let text = text_bytes_for_test([
    0xCA, 0xCB, 0xCC, 0xCD, 0xCE, 0xCF, 0xD0, 0xD1, 0xD2, 0xD3,
  ])
  @test.assert_eq(try! extractor.codepoints_of_text(text[:]), [
    0x278A, 0x278B, 0x278C, 0x278D, 0x278E, 0x278F, 0x2790, 0x2791, 0x2792, 0x2793,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(text[:]), [
    text_name_for_test("/a150"),
    text_name_for_test("/a151"),
    text_name_for_test("/a152"),
    text_name_for_test("/a153"),
    text_name_for_test("/a154"),
    text_name_for_test("/a155"),
    text_name_for_test("/a156"),
    text_name_for_test("/a157"),
    text_name_for_test("/a158"),
    text_name_for_test("/a159"),
  ])
  @test.assert_eq(extractor.charcode_of_codepoint(0x278A), Some(0xCA))
  @test.assert_eq(extractor.charcode_of_codepoint(0x278F), Some(0xCF))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2793), Some(0xD3))
}

///|
test "PdfTextExtractor extracts implicit ZapfDingbats high-byte arrow glyphs" {
  let dingbat_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(PdfZapfDingbats, PdfImplicitInFontFile),
  )
  let extractor = dingbat_font.text_extractor()
  let text = text_bytes_for_test([
    0xD4, 0xD5, 0xD6, 0xD7, 0xD8, 0xD9, 0xDA, 0xDB, 0xDC, 0xDD, 0xDE, 0xDF,
  ])
  @test.assert_eq(try! extractor.codepoints_of_text(text[:]), [
    0x2794, 0x2192, 0x2194, 0x2195, 0x2798, 0x2799, 0x279A, 0x279B, 0x279C, 0x279D,
    0x279E, 0x279F,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(text[:]), [
    text_name_for_test("/a160"),
    text_name_for_test("/a161"),
    text_name_for_test("/a163"),
    text_name_for_test("/a164"),
    text_name_for_test("/a196"),
    text_name_for_test("/a165"),
    text_name_for_test("/a192"),
    text_name_for_test("/a166"),
    text_name_for_test("/a167"),
    text_name_for_test("/a168"),
    text_name_for_test("/a169"),
    text_name_for_test("/a170"),
  ])
  @test.assert_eq(extractor.charcode_of_codepoint(0x2794), Some(0xD4))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2195), Some(0xD7))
  @test.assert_eq(extractor.charcode_of_codepoint(0x279F), Some(0xDF))
}

///|
test "PdfTextExtractor extracts implicit ZapfDingbats extended arrow glyphs" {
  let dingbat_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(PdfZapfDingbats, PdfImplicitInFontFile),
  )
  let extractor = dingbat_font.text_extractor()
  let text = text_bytes_for_test([
    0xE0, 0xE1, 0xE2, 0xE3, 0xE4, 0xE5, 0xE6, 0xE7, 0xE8, 0xE9, 0xEA, 0xEB, 0xEC,
    0xED, 0xEE, 0xEF,
  ])
  @test.assert_eq(try! extractor.codepoints_of_text(text[:]), [
    0x27A0, 0x27A1, 0x27A2, 0x27A3, 0x27A4, 0x27A5, 0x27A6, 0x27A7, 0x27A8, 0x27A9,
    0x27AA, 0x27AB, 0x27AC, 0x27AD, 0x27AE, 0x27AF,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(text[:]), [
    text_name_for_test("/a171"),
    text_name_for_test("/a172"),
    text_name_for_test("/a173"),
    text_name_for_test("/a162"),
    text_name_for_test("/a174"),
    text_name_for_test("/a175"),
    text_name_for_test("/a176"),
    text_name_for_test("/a177"),
    text_name_for_test("/a178"),
    text_name_for_test("/a179"),
    text_name_for_test("/a193"),
    text_name_for_test("/a180"),
    text_name_for_test("/a199"),
    text_name_for_test("/a181"),
    text_name_for_test("/a200"),
    text_name_for_test("/a182"),
  ])
  @test.assert_eq(extractor.charcode_of_codepoint(0x27A0), Some(0xE0))
  @test.assert_eq(extractor.charcode_of_codepoint(0x27A8), Some(0xE8))
  @test.assert_eq(extractor.charcode_of_codepoint(0x27AF), Some(0xEF))
}

///|
test "PdfTextExtractor uses custom encoding differences before base encoding" {
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(
      PdfHelvetica,
      PdfCustomEncoding(PdfStandardEncoding, [
        text_difference_for_test("/Euro", 65),
        text_difference_for_test("/A.alt", 66),
        text_difference_for_test("/uni20AC", 67),
        text_difference_for_test("/u00A9", 68),
        text_difference_for_test("/uni00410042", 69),
      ]),
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(
      text_bytes_for_test([65, 66, 67, 68, 69, 70])[:],
    ),
    [0x20AC, 65, 0x20AC, 0x00A9, 65, 66, 70],
  )
  @test.assert_eq(
    try! extractor.glyphnames_of_text(
      text_bytes_for_test([65, 66, 67, 68, 69, 70])[:],
    ),
    [
      text_name_for_test("/Euro"),
      text_name_for_test("/A.alt"),
      text_name_for_test("/uni20AC"),
      text_name_for_test("/u00A9"),
      text_name_for_test("/uni00410042"),
      text_name_for_test("/F"),
    ],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x20AC), Some(65))
  @test.assert_eq(extractor.charcode_of_codepoint(65), Some(66))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00A9), Some(68))
  @test.assert_eq(extractor.charcode_of_codepoint(66), None)
  @test.assert_eq(extractor.charcode_of_codepoint(70), Some(70))
}

///|
test "PdfDocument write_font rejects unsupported font variants" {
  let doc = @pdflite.pdf_document_empty()
  let unsupported = try? doc.write_font(
    PdfFontSimple({
      fonttype: PdfType1,
      basefont: Some(text_name_for_test("/CustomFont")),
      firstchar: 0,
      lastchar: 0,
      widths: [],
      fontdescriptor: None,
      fontmetrics: None,
      encoding: PdfWinAnsiEncoding,
    }),
  )
  guard unsupported is Err(FontWriteUnsupported) else {
    fail("expected FontWriteUnsupported")
  }
  let unsupported_type3 = try? doc.write_font(
    PdfFontSimple({
      fonttype: PdfType3({
        fontbbox: { min_x: 0.0, min_y: 0.0, max_x: 0.0, max_y: 0.0 },
        fontmatrix: @pdflite.transform_identity_matrix,
        charprocs: [],
        resources: @pdflite.pdf_dictionary([]),
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
  guard unsupported_type3 is Err(FontWriteUnsupported) else {
    fail("expected FontWriteUnsupported")
  }
  let unsupported_encoding = try? doc.write_font(
    PdfFontSimple({
      fonttype: PdfType3({
        fontbbox: { min_x: 0.0, min_y: 0.0, max_x: 0.0, max_y: 0.0 },
        fontmatrix: @pdflite.transform_identity_matrix,
        charprocs: [],
        resources: @pdflite.pdf_dictionary([]),
      }),
      basefont: None,
      firstchar: 0,
      lastchar: 0,
      widths: [],
      fontdescriptor: Some(text_font_descriptor_for_test()),
      fontmetrics: None,
      encoding: PdfWinAnsiEncoding,
    }),
  )
  guard unsupported_encoding is Err(EncodingWriteUnsupported) else {
    fail("expected EncodingWriteUnsupported")
  }
  let unsupported_truetype = try? doc.write_font(
    PdfFontSimple({
      fonttype: PdfTrueType,
      basefont: Some(text_name_for_test("/MissingFontFile2")),
      firstchar: 0,
      lastchar: 0,
      widths: [],
      fontdescriptor: Some(text_font_descriptor_for_test()),
      fontmetrics: None,
      encoding: PdfWinAnsiEncoding,
    }),
  )
  guard unsupported_truetype is Err(FontWriteUnsupported) else {
    fail("expected FontWriteUnsupported")
  }
  let unsupported_truetype_encoding = try? doc.write_font(
    PdfFontSimple({
      fonttype: PdfTrueType,
      basefont: Some(text_name_for_test("/CustomEncoding")),
      firstchar: 0,
      lastchar: 0,
      widths: [],
      fontdescriptor: Some({
        ..text_font_descriptor_for_test(),
        fontfile: Some(PdfFontFile2(7)),
      }),
      fontmetrics: None,
      encoding: PdfCustomEncoding(PdfImplicitInFontFile, []),
    }),
  )
  guard unsupported_truetype_encoding is Err(EncodingWriteUnsupported) else {
    fail("expected EncodingWriteUnsupported")
  }
}
