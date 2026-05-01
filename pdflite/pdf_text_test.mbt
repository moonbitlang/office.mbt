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
        "endbfrange\n",
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
    ]),
  )
  let extractor = try! doc.text_extractor_of_font(font)
  @test.assert_eq(
    try! extractor.codepoints_of_text(
      text_bytes_for_test([33, 34, 35, 36, 37, 38])[:],
    ),
    [0x41, 0x42, 0x43, 0x44, 0x20AC, 38],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x20AC), Some(37))
  @test.assert_eq(extractor.charcode_of_codepoint(0x45), None)
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
  @test.assert_eq(extractor.charcode_of_codepoint(39), None)
}

///|
test "PdfTextExtractor extracts WinAnsi Basic Latin quote glyphs" {
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(PdfHelvetica, PdfWinAnsiEncoding),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(text_bytes_for_test([39, 96])[:]),
    [39, 96],
  )
  @test.assert_eq(
    try! extractor.glyphnames_of_text(text_bytes_for_test([39, 96])[:]),
    [text_name_for_test("/quotesingle"), text_name_for_test("/grave")],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(39), Some(39))
  @test.assert_eq(extractor.charcode_of_codepoint(96), Some(96))
}

///|
test "PdfTextExtractor uses custom encoding differences before base encoding" {
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(
      PdfHelvetica,
      PdfCustomEncoding(PdfStandardEncoding, [
        text_difference_for_test("/Euro", 65),
      ]),
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(text_bytes_for_test([65, 66])[:]),
    [0x20AC, 66],
  )
  @test.assert_eq(
    try! extractor.glyphnames_of_text(text_bytes_for_test([65, 66])[:]),
    [text_name_for_test("/Euro"), text_name_for_test("/B")],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x20AC), Some(65))
  @test.assert_eq(extractor.charcode_of_codepoint(66), Some(66))
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
