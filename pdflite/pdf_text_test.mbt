///|
fn text_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn text_bytes_for_test(values : ArrayView[Int]) -> @pdflite.PdfBytes {
  try! @pdflite.pdf_bytes_of_int_array(values)
}

///|
fn text_concat_for_test(
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
fn text_difference_for_test(
  name : String,
  code : Int,
) -> @pdflite.PdfEncodingDifference {
  { name: text_name_for_test(name), code }
}

///|
fn text_encoding_table_lookup_for_test(
  table : ArrayView[(Int, @pdflite.PdfName)],
  code : Int,
) -> @pdflite.PdfName? {
  for entry in table {
    if entry.0 == code {
      break Some(entry.1)
    }
  } nobreak {
    None
  }
}

///|
fn text_reverse_encoding_table_lookup_for_test(
  table : ArrayView[(@pdflite.PdfName, Int)],
  name : @pdflite.PdfName,
) -> Int? {
  for entry in table {
    if entry.0 == name {
      break Some(entry.1)
    }
  } nobreak {
    None
  }
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
fn text_cid_system_info_object_for_test() -> @pdflite.PdfObject {
  @pdflite.pdf_dictionary([
    (text_name_for_test("/Registry"), PdfString(text_bytes_for_test([82]))),
    (text_name_for_test("/Ordering"), PdfString(text_bytes_for_test([79]))),
    (text_name_for_test("/Supplement"), PdfInteger(0)),
  ])
}

///|
fn text_valid_cid_descendant_for_test(
  extra : ArrayView[(@pdflite.PdfName, @pdflite.PdfObject)],
) -> @pdflite.PdfObject {
  let entries : Array[(@pdflite.PdfName, @pdflite.PdfObject)] = [
    (
      text_name_for_test("/CIDSystemInfo"),
      text_cid_system_info_object_for_test(),
    ),
    (
      text_name_for_test("/BaseFont"),
      PdfNameObject(text_name_for_test("/Descendant")),
    ),
    (text_name_for_test("/FontDescriptor"), @pdflite.pdf_dictionary([])),
  ]
  for entry in extra {
    entries.push(entry)
  }
  @pdflite.pdf_dictionary(entries)
}

///|
fn text_cid_top_font_for_test(
  descendant_number : Int,
  encoding : @pdflite.PdfObject,
) -> @pdflite.PdfObject {
  @pdflite.pdf_dictionary([
    (text_name_for_test("/BaseFont"), PdfNameObject(text_name_for_test("/T"))),
    (
      text_name_for_test("/DescendantFonts"),
      PdfArray([PdfIndirect(descendant_number)]),
    ),
    (text_name_for_test("/Encoding"), encoding),
  ])
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
  let bad_four_byte_continuation = try? @pdflite.pdf_codepoints_of_utf8(
    text_bytes_for_test([0xF0, 0x9D, 0x28, 0x9E])[:],
  )
  guard bad_four_byte_continuation is Err(InvalidUTF8) else {
    fail("expected InvalidUTF8 for bad four-byte continuation")
  }
  let invalid_leading_byte = try? @pdflite.pdf_codepoints_of_utf8(
    text_bytes_for_test([0xFF])[:],
  )
  guard invalid_leading_byte is Err(InvalidUTF8) else {
    fail("expected InvalidUTF8 for invalid leading byte")
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
test "PdfStandardFont exposes Standard14 AFM data tables" {
  let counts : Array[(@pdflite.PdfStandardFont, Int, Int, Int, Int)] = [
    (PdfTimesRoman, 25, 149, 315, 206),
    (PdfTimesBold, 25, 149, 315, 223),
    (PdfTimesItalic, 25, 149, 315, 213),
    (PdfTimesBoldItalic, 25, 149, 315, 205),
    (PdfHelvetica, 25, 149, 315, 289),
    (PdfHelveticaBold, 25, 149, 315, 252),
    (PdfHelveticaOblique, 25, 149, 315, 289),
    (PdfHelveticaBoldOblique, 25, 149, 315, 252),
    (PdfCourier, 25, 149, 315, 0),
    (PdfCourierBold, 25, 149, 315, 0),
    (PdfCourierOblique, 25, 149, 315, 0),
    (PdfCourierBoldOblique, 25, 149, 315, 0),
    (PdfSymbol, 21, 189, 190, 0),
    (PdfZapfDingbats, 21, 202, 202, 0),
  ]
  for entry in counts {
    let data = @pdflite.pdf_standard14_afm_data(entry.0)
    @test.assert_eq(data.headers.length(), entry.1)
    @test.assert_eq(data.char_metrics.length(), entry.2)
    @test.assert_eq(data.char_name_widths.length(), entry.3)
    @test.assert_eq(data.kerns.length(), entry.4)
  }
  @test.assert_eq(
    @pdflite.PdfCourier.afm_data().headers[5],
    (@ascii.encode("FontName"), @ascii.encode("Courier")),
  )
}

///|
test "PdfStandardFont text_width mirrors CamlPDF widths and kerning" {
  let av = text_bytes_for_test([65, 86])
  @test.assert_eq(
    @pdflite.PdfHelvetica.text_width(PdfWinAnsiEncoding, av[:]),
    1334,
  )
  @test.assert_eq(
    @pdflite.PdfHelvetica.text_width(PdfWinAnsiEncoding, av[:], kern=true),
    1264,
  )
  let to = text_bytes_for_test([84, 111])
  @test.assert_eq(
    @pdflite.pdf_standard14_text_width(PdfTimesRoman, PdfWinAnsiEncoding, to[:]),
    1111,
  )
  @test.assert_eq(
    @pdflite.pdf_standard14_text_width(
      PdfTimesRoman,
      PdfWinAnsiEncoding,
      to[:],
      kern=true,
    ),
    1031,
  )
  let courier = text_bytes_for_test([65, 66, 67])
  @test.assert_eq(
    @pdflite.PdfCourier.text_width(PdfImplicitInFontFile, courier[:]),
    1800,
  )
  @test.assert_eq(
    @pdflite.PdfCourier.text_width(PdfImplicitInFontFile, courier[:], kern=true),
    1800,
  )
  let missing_code = text_bytes_for_test([1])
  @test.assert_eq(
    @pdflite.PdfCourier.text_width(PdfImplicitInFontFile, missing_code[:]),
    0,
  )
}

///|
test "PdfStandardFont text_width uses glyph-name widths for explicit encodings" {
  let custom : @pdflite.PdfEncoding = PdfCustomEncoding(PdfWinAnsiEncoding, [
    text_difference_for_test("/AE", 65),
  ])
  let text = text_bytes_for_test([65, 66, 0])
  @test.assert_eq(@pdflite.PdfHelvetica.text_width(custom, text[:]), 1945)
  let standard_font = text_standard_font_data_for_test(PdfHelvetica, custom)
  @test.assert_eq(standard_font.text_width(text[:]), 1945)
  let symbol_text = text_bytes_for_test([65])
  @test.assert_eq(
    @pdflite.PdfSymbol.text_width(PdfImplicitInFontFile, symbol_text[:]),
    722,
  )
  let slashless : @pdflite.PdfEncoding = PdfCustomEncoding(PdfWinAnsiEncoding, [
    { name: text_name_for_test("AE"), code: 65 },
  ])
  @test.assert_eq(
    @pdflite.PdfHelvetica.text_width(slashless, symbol_text[:]),
    1000,
  )
  let unknown : @pdflite.PdfEncoding = PdfCustomEncoding(PdfWinAnsiEncoding, [
    text_difference_for_test("/MissingGlyph", 65),
  ])
  @test.assert_eq(@pdflite.PdfHelvetica.text_width(unknown, symbol_text[:]), 0)
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
test "PdfEncoding exposes effective encoding tables" {
  let standard_table = @pdflite.PdfStandardEncoding.table()
  @test.assert_eq(
    text_encoding_table_lookup_for_test(standard_table, 65),
    Some(text_name_for_test("/A")),
  )
  @test.assert_eq(text_encoding_table_lookup_for_test(standard_table, 0), None)
  let custom : @pdflite.PdfEncoding = PdfCustomEncoding(PdfStandardEncoding, [
    text_difference_for_test("/Alpha", 65),
  ])
  let custom_table = @pdflite.pdf_table_of_encoding(custom)
  @test.assert_eq(
    text_encoding_table_lookup_for_test(custom_table, 65),
    Some(text_name_for_test("/Alpha")),
  )
  @test.assert_eq(
    text_encoding_table_lookup_for_test(custom_table, 66),
    Some(text_name_for_test("/B")),
  )
  let reverse = @pdflite.pdf_reverse_table_of_encoding(custom)
  @test.assert_eq(
    text_reverse_encoding_table_lookup_for_test(
      reverse,
      text_name_for_test("/Alpha"),
    ),
    Some(65),
  )
  @test.assert_eq(
    text_reverse_encoding_table_lookup_for_test(
      reverse,
      text_name_for_test("/B"),
    ),
    Some(66),
  )
  let filled : @pdflite.PdfEncoding = PdfFillUndefinedWithStandard(
    PdfImplicitInFontFile,
  )
  @test.assert_eq(
    text_encoding_table_lookup_for_test(filled.table(), 65),
    Some(text_name_for_test("/A")),
  )
  @test.assert_eq(@pdflite.PdfImplicitInFontFile.reverse_table(), [])
}

///|
test "Pdf font debug names cover non-Type1 variants" {
  let external_cmap : @pdflite.PdfCMapEncoding = PdfCMap(7)
  @test.assert_eq(external_cmap.is_identity_h(), false)
  let mm_type1_type : @pdflite.PdfSimpleFontType = PdfMMType1
  let true_type_type : @pdflite.PdfSimpleFontType = PdfTrueType
  @test.assert_eq(mm_type1_type.debug_name(), "MM Type 1")
  @test.assert_eq(true_type_type.debug_name(), "Truetype")
  let simple_font : @pdflite.PdfFont = PdfFontSimple({
    fonttype: PdfMMType1,
    basefont: None,
    firstchar: 0,
    lastchar: 0,
    widths: [],
    fontdescriptor: None,
    fontmetrics: None,
    encoding: PdfImplicitInFontFile,
  })
  @test.assert_eq(
    simple_font.debug_name(),
    "SimpleFont fonttype = MM Type 1\nbasefont \nencoding is ImplicitInFontFile\n",
  )
  let cid_font : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_name_for_test("/Top"),
    composite: {
      cid_system_info: {
        registry: text_bytes_for_test([82]),
        ordering: text_bytes_for_test([79]),
        supplement: 0,
      },
      cid_basefont: text_name_for_test("/Descendant"),
      cid_fontdescriptor: text_font_descriptor_for_test(),
      cid_widths: [],
      cid_widths2: [],
      cid_default_width: 1000.0,
      cid_default_width2: [880.0, -1000.0],
    },
    encoding: PdfCMap(7),
  })
  @test.assert_eq(cid_font.debug_name(), "CIDKeyedFont /Top")
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
  let non_dictionary_encoding = @pdflite.pdf_dictionary([
    (text_name_for_test("/Encoding"), PdfInteger(1)),
  ])
  @test.assert_eq(
    try! doc.read_encoding(non_dictionary_encoding),
    PdfImplicitInFontFile,
  )
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
  let unknown_base = @pdflite.pdf_dictionary([
    (
      text_name_for_test("/Subtype"),
      PdfNameObject(text_name_for_test("/Type1")),
    ),
    (
      text_name_for_test("/Encoding"),
      @pdflite.pdf_dictionary([
        (
          text_name_for_test("/BaseEncoding"),
          PdfNameObject(text_name_for_test("/UnknownEncoding")),
        ),
      ]),
    ),
  ])
  let unknown_base_result = try? doc.read_encoding(unknown_base)
  guard unknown_base_result is Err(EncodingExpected) else {
    fail("expected EncodingExpected for unknown base")
  }
  let bad_difference_object = @pdflite.pdf_dictionary([
    (
      text_name_for_test("/Subtype"),
      PdfNameObject(text_name_for_test("/Type1")),
    ),
    (
      text_name_for_test("/Encoding"),
      @pdflite.pdf_dictionary([
        (
          text_name_for_test("/Differences"),
          PdfArray([PdfInteger(65), PdfNull]),
        ),
      ]),
    ),
  ])
  let bad_difference_object_result = try? doc.read_encoding(
    bad_difference_object,
  )
  guard bad_difference_object_result is Err(EncodingDifferencesMalformed) else {
    fail("expected EncodingDifferencesMalformed for bad difference object")
  }
  let non_array_differences = @pdflite.pdf_dictionary([
    (
      text_name_for_test("/Subtype"),
      PdfNameObject(text_name_for_test("/Type1")),
    ),
    (
      text_name_for_test("/Encoding"),
      @pdflite.pdf_dictionary([
        (text_name_for_test("/Differences"), PdfInteger(65)),
      ]),
    ),
  ])
  let non_array_result = try? doc.read_encoding(non_array_differences)
  guard non_array_result is Err(EncodingDifferencesMalformed) else {
    fail("expected EncodingDifferencesMalformed for non-array differences")
  }
  let missing_flags = @pdflite.pdf_dictionary([
    (
      text_name_for_test("/Subtype"),
      PdfNameObject(text_name_for_test("/Type1")),
    ),
    (text_name_for_test("/Encoding"), @pdflite.pdf_dictionary([])),
    (text_name_for_test("/FontDescriptor"), @pdflite.pdf_dictionary([])),
  ])
  let missing_flags_result = try? doc.read_encoding(missing_flags)
  guard missing_flags_result is Err(FontFlagsExpected) else {
    fail("expected FontFlagsExpected")
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
test "PdfDocument read_font_descriptor accepts FontFile3 and stops malformed charset" {
  let doc = @pdflite.pdf_document_empty()
  let descriptor = @pdflite.pdf_dictionary([
    (text_name_for_test("/FontFile3"), PdfIndirect(12)),
    (text_name_for_test("/CharSet"), PdfString(@ascii.encode("/A 7 /B"))),
  ])
  let font = @pdflite.pdf_dictionary([
    (text_name_for_test("/FontDescriptor"), descriptor),
  ])
  guard (try! doc.read_font_descriptor(font)) is Some(read_descriptor) else {
    fail("expected font descriptor")
  }
  @test.assert_eq(read_descriptor.fontfile, Some(PdfFontFile3(12)))
  @test.assert_eq(read_descriptor.charset, Some([text_name_for_test("/A")]))
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

  let bad_firstchar = @pdflite.pdf_dictionary([
    (text_name_for_test("/FontDescriptor"), @pdflite.pdf_dictionary([])),
    (text_name_for_test("/FirstChar"), PdfInteger(-1)),
    (text_name_for_test("/LastChar"), PdfInteger(65)),
    (text_name_for_test("/Widths"), PdfArray([PdfInteger(600)])),
  ])
  let bad_firstchar_result = try? doc.read_font_metrics(bad_firstchar)
  guard bad_firstchar_result is Err(FontFirstCharExpected) else {
    fail("expected FontFirstCharExpected")
  }

  let missing_widths = @pdflite.pdf_dictionary([
    (text_name_for_test("/FontDescriptor"), @pdflite.pdf_dictionary([])),
    (text_name_for_test("/FirstChar"), PdfInteger(65)),
    (text_name_for_test("/LastChar"), PdfInteger(65)),
  ])
  let missing_widths_result = try? doc.read_font_metrics(missing_widths)
  guard missing_widths_result is Err(FontWidthsExpected) else {
    fail("expected FontWidthsExpected for missing widths")
  }

  let inverted_bounds = @pdflite.pdf_dictionary([
    (text_name_for_test("/FontDescriptor"), @pdflite.pdf_dictionary([])),
    (text_name_for_test("/FirstChar"), PdfInteger(66)),
    (text_name_for_test("/LastChar"), PdfInteger(65)),
    (text_name_for_test("/Widths"), PdfArray([])),
  ])
  let inverted_bounds_result = try? doc.read_font_metrics(inverted_bounds)
  guard inverted_bounds_result is Err(FontWidthsExpected) else {
    fail("expected FontWidthsExpected for inverted bounds")
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
test "PdfDocument read_simple_font covers MMType1 TrueType and Type3 resources" {
  let doc = @pdflite.pdf_document_empty()
  let mm_type1 = try! doc.read_simple_font(
    @pdflite.pdf_dictionary([
      (
        text_name_for_test("/Subtype"),
        PdfNameObject(text_name_for_test("/MMType1")),
      ),
    ]),
  )
  @test.assert_eq(mm_type1.fonttype, PdfMMType1)
  @test.assert_eq(
    mm_type1.debug_name(),
    "fonttype = MM Type 1\nbasefont \nencoding is ImplicitInFontFile\n",
  )

  let true_type = try! doc.read_simple_font(
    @pdflite.pdf_dictionary([
      (
        text_name_for_test("/Subtype"),
        PdfNameObject(text_name_for_test("/TrueType")),
      ),
    ]),
  )
  @test.assert_eq(true_type.fonttype, PdfTrueType)
  @test.assert_eq(true_type.fonttype.debug_name(), "Truetype")

  let resources = @pdflite.pdf_dictionary([
    (text_name_for_test("/ProcSet"), PdfArray([])),
  ])
  let type3 = try! doc.read_simple_font(
    @pdflite.pdf_dictionary([
      (
        text_name_for_test("/Subtype"),
        PdfNameObject(text_name_for_test("/Type3")),
      ),
      (
        text_name_for_test("/CharProcs"),
        @pdflite.pdf_dictionary([(text_name_for_test("/A"), PdfInteger(1))]),
      ),
      (text_name_for_test("/Resources"), resources),
      (text_name_for_test("/FirstChar"), PdfInteger(0)),
      (text_name_for_test("/LastChar"), PdfInteger(0)),
      (text_name_for_test("/Widths"), PdfArray([PdfInteger(9)])),
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
  let missing_base = @pdflite.pdf_dictionary([
    (
      text_name_for_test("/Subtype"),
      PdfNameObject(text_name_for_test("/Type1")),
    ),
  ])
  @test.assert_eq(doc.is_standard14_font(missing_base), false)
  @test.assert_eq(doc.is_simple_font(@pdflite.pdf_dictionary([])), false)
  @test.assert_eq(doc.is_cidkeyed_font(@pdflite.pdf_dictionary([])), false)
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
  let missing_basefont = try? doc.read_cidkeyed_font(
    @pdflite.pdf_dictionary([]),
  )
  guard missing_basefont is Err(BaseFontExpected) else {
    fail("expected BaseFontExpected")
  }
  let missing_descendant = try? doc.read_cidkeyed_font(
    @pdflite.pdf_dictionary([
      (text_name_for_test("/BaseFont"), PdfNameObject(text_name_for_test("/T"))),
    ]),
  )
  guard missing_descendant is Err(DescendantFontExpected) else {
    fail("expected DescendantFontExpected")
  }

  let bad_supplement = try? doc.read_cid_system_info(
    @pdflite.pdf_dictionary([
      (text_name_for_test("/Registry"), PdfString(text_bytes_for_test([82]))),
      (text_name_for_test("/Ordering"), PdfString(text_bytes_for_test([79]))),
    ]),
  )
  guard bad_supplement is Err(CIDSupplementExpected) else {
    fail("expected CIDSupplementExpected")
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

  doc.add_object_given_number(
    10,
    @pdflite.pdf_dictionary([
      (
        text_name_for_test("/BaseFont"),
        PdfNameObject(text_name_for_test("/Descendant")),
      ),
      (text_name_for_test("/FontDescriptor"), @pdflite.pdf_dictionary([])),
    ]),
  )
  let missing_system_result = try? doc.read_cidkeyed_font(
    text_cid_top_font_for_test(
      10,
      PdfNameObject(text_name_for_test("/Identity-H")),
    ),
  )
  guard missing_system_result is Err(CIDSystemInfoExpected) else {
    fail("expected CIDSystemInfoExpected")
  }

  doc.add_object_given_number(
    11,
    @pdflite.pdf_dictionary([
      (
        text_name_for_test("/CIDSystemInfo"),
        text_cid_system_info_object_for_test(),
      ),
      (text_name_for_test("/FontDescriptor"), @pdflite.pdf_dictionary([])),
    ]),
  )
  let missing_cid_basefont_result = try? doc.read_cidkeyed_font(
    text_cid_top_font_for_test(
      11,
      PdfNameObject(text_name_for_test("/Identity-H")),
    ),
  )
  guard missing_cid_basefont_result is Err(CIDBaseFontExpected) else {
    fail("expected CIDBaseFontExpected")
  }

  doc.add_object_given_number(
    12,
    @pdflite.pdf_dictionary([
      (
        text_name_for_test("/CIDSystemInfo"),
        text_cid_system_info_object_for_test(),
      ),
      (
        text_name_for_test("/BaseFont"),
        PdfNameObject(text_name_for_test("/Descendant")),
      ),
    ]),
  )
  let missing_descriptor_result = try? doc.read_cidkeyed_font(
    text_cid_top_font_for_test(
      12,
      PdfNameObject(text_name_for_test("/Identity-H")),
    ),
  )
  guard missing_descriptor_result is Err(CIDFontDescriptorExpected) else {
    fail("expected CIDFontDescriptorExpected")
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

  let malformed_widths : Array[@pdflite.PdfObject] = [
    text_valid_cid_descendant_for_test([
      (
        text_name_for_test("/W"),
        PdfArray([
          PdfInteger(1),
          PdfArray([PdfNameObject(text_name_for_test("/Bad"))]),
        ]),
      ),
    ]),
    text_valid_cid_descendant_for_test([
      (
        text_name_for_test("/W"),
        PdfArray([PdfInteger(1), PdfNameObject(text_name_for_test("/Bad"))]),
      ),
    ]),
    text_valid_cid_descendant_for_test([
      (
        text_name_for_test("/W"),
        PdfArray([PdfNameObject(text_name_for_test("/Bad"))]),
      ),
    ]),
  ]
  for index in 0..<malformed_widths.length() {
    doc.add_object_given_number(13 + index, malformed_widths[index])
    let result = try? doc.read_cidkeyed_font(
      text_cid_top_font_for_test(
        13 + index,
        PdfNameObject(text_name_for_test("/Identity-H")),
      ),
    )
    guard result is Err(CIDWidthsExpected) else {
      fail("expected CIDWidthsExpected for malformed widths")
    }
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

  let malformed_widths2 : Array[@pdflite.PdfObject] = [
    text_valid_cid_descendant_for_test([
      (
        text_name_for_test("/W2"),
        PdfArray([
          PdfInteger(5),
          PdfInteger(4),
          PdfInteger(100),
          PdfInteger(1),
          PdfInteger(2),
        ]),
      ),
    ]),
    text_valid_cid_descendant_for_test([
      (
        text_name_for_test("/W2"),
        PdfArray([PdfInteger(1), PdfNameObject(text_name_for_test("/Bad"))]),
      ),
    ]),
    text_valid_cid_descendant_for_test([
      (
        text_name_for_test("/W2"),
        PdfArray([PdfNameObject(text_name_for_test("/Bad"))]),
      ),
    ]),
  ]
  for index in 0..<malformed_widths2.length() {
    doc.add_object_given_number(16 + index, malformed_widths2[index])
    let result = try? doc.read_cidkeyed_font(
      text_cid_top_font_for_test(
        16 + index,
        PdfNameObject(text_name_for_test("/Identity-H")),
      ),
    )
    guard result is Err(CIDWidths2Expected) else {
      fail("expected CIDWidths2Expected for malformed vertical widths")
    }
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
  let bad_cmap = try? doc.read_cidkeyed_font(
    text_cid_top_font_for_test(9, PdfInteger(1)),
  )
  guard bad_cmap is Err(CMapEncodingExpected) else {
    fail("expected CMapEncodingExpected for non-name encoding")
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
test "pdf_parse_cmap_data returns ToUnicode map and WMode" {
  let parsed = @pdflite.pdf_parse_cmap_data(
    @ascii.encode(
      "/CIDInit /ProcSet findresource begin\n" +
      "/WMode 1 def\n" +
      "2 beginbfchar\n" +
      "<21><0041>\n" +
      "<22><0042>\n" +
      "endbfchar\n",
    )[:],
  )
  @test.assert_eq(parsed.wmode, Some(1))
  @test.assert_eq(parsed.map, [
    (33, text_bytes_for_test([0x00, 0x41])),
    (34, text_bytes_for_test([0x00, 0x42])),
  ])
  let malformed_wmode = @pdflite.pdf_parse_cmap_data(
    @ascii.encode("/WMode invalid\n")[:],
  )
  @test.assert_eq(malformed_wmode.wmode, None)
  @test.assert_eq(malformed_wmode.map, [])
  @test.assert_eq(
    @pdflite.pdf_parse_cmap_data(@ascii.encode("/XMode 1\n")[:]).wmode,
    None,
  )
}

///|
test "PdfDocument parse_cmap decodes stream objects" {
  let doc = @pdflite.pdf_document_empty()
  let cmap_data = @ascii.encode(
    "/WMode 0 def\n" + "1 beginbfrange\n" + "<30><31><0061>\n" + "endbfrange\n",
  )
  let encoded_cmap = @pdflite.pdf_flate_encode(cmap_data)
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (text_name_for_test("/Length"), PdfInteger(encoded_cmap.length())),
      (
        text_name_for_test("/Filter"),
        PdfNameObject(text_name_for_test("/FlateDecode")),
      ),
    ]),
    StreamGot(encoded_cmap),
  )
  doc.add_object_given_number(17, stream)
  @test.assert_eq(try! doc.parse_cmap(PdfIndirect(17)), {
    map: [
      (48, text_bytes_for_test([0x00, 0x61])),
      (49, text_bytes_for_test([0x00, 0x62])),
    ],
    wmode: Some(0),
  })
  let non_stream : Result[@pdflite.PdfParsedCMap, Error] = try? doc.parse_cmap(
    PdfInteger(1),
  )
  guard non_stream is Err(@pdflite.PdfError::CMapEncodingExpected) else {
    fail("expected CMapEncodingExpected")
  }
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
        "1 beginbfchar <30><0068> endbfchar 1 beginbfrange <31><32><0069> endbfrange\n",
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
      (48, text_bytes_for_test([0x00, 0x68])),
      (49, text_bytes_for_test([0x00, 0x69])),
      (50, text_bytes_for_test([0x00, 0x6A])),
    ]),
  )
  let extractor = try! doc.text_extractor_of_font(font)
  @test.assert_eq(
    try! extractor.codepoints_of_text(
      text_bytes_for_test([
        33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51,
      ])[:],
    ),
    [
      0x41, 0x42, 0x43, 0x44, 0x20AC, 0x58, 0x59, 0x5A, 0x61, 0x62, 0x63, 0x64, 0x65,
      0x66, 0x67, 0x68, 0x69, 0x6A, 51,
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
      (65, text_bytes_for_test([0x00, 0x41])),
      (66, text_bytes_for_test([0x00, 0x42])),
      (67, text_bytes_for_test([0x00, 0x43])),
    ]),
  )
  let extractor = try! doc.text_extractor_of_font(font)
  @test.assert_eq(
    try! extractor.codepoints_of_text(text_bytes_for_test([65, 66, 67, 68])[:]),
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
      (48, text_bytes_for_test([0x00, 0x61])),
      (49, text_bytes_for_test([0x00, 0x62])),
      (50, text_bytes_for_test([0x00, 0x63])),
      (51, text_bytes_for_test([0x00, 0x64])),
      (52, text_bytes_for_test([0x00, 0x65])),
      (53, text_bytes_for_test([0x00, 0x66])),
      (54, text_bytes_for_test([0x00, 0x67])),
      (55, text_bytes_for_test([0x00, 0x68])),
      (56, text_bytes_for_test([0x00, 0x69])),
      (57, text_bytes_for_test([0x00, 0x6A])),
    ]),
  )
  let extractor = try! doc.text_extractor_of_font(font)
  @test.assert_eq(
    try! extractor.codepoints_of_text(
      text_bytes_for_test([48, 49, 50, 51, 52, 53, 54, 55, 56, 57])[:],
    ),
    [0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6A],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x61), Some(48))
  @test.assert_eq(extractor.charcode_of_codepoint(0x69), Some(56))
  @test.assert_eq(extractor.charcode_of_codepoint(0x6A), Some(57))
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
      (64, text_bytes_for_test([0x00, 0x61])),
      (65, text_bytes_for_test([0x00, 0x62])),
      (66, text_bytes_for_test([0x00, 0x63])),
      (67, text_bytes_for_test([0x00, 0x64])),
      (68, text_bytes_for_test([0x00, 0x65])),
      (69, text_bytes_for_test([0x00, 0x66])),
      (70, text_bytes_for_test([0x00, 0x67])),
      (71, text_bytes_for_test([0x00, 0x68])),
      (72, text_bytes_for_test([0x00, 0x69])),
      (73, text_bytes_for_test([0x00, 0x6A])),
    ]),
  )
  let extractor = try! doc.text_extractor_of_font(font)
  @test.assert_eq(
    try! extractor.codepoints_of_text(
      text_bytes_for_test([64, 65, 66, 67, 68, 69, 70, 71, 72, 73])[:],
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
      (65, text_bytes_for_test([0x00, 0x5A])),
      (0x40, text_bytes_for_test([0x00, 0x60])),
      (67, text_bytes_for_test([0xD8, 0x34, 0xDD, 0x1E])),
    ]),
  )
  let extractor = try! doc.text_extractor_of_font(font)
  @test.assert_eq(
    try! extractor.codepoints_of_text(
      text_bytes_for_test([65, 0x40, 67, 68])[:],
    ),
    [0x5A, 0x60, 0x1D11E, 68],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x1D11E), Some(67))
}

///|
test "PdfDocument reads ToUnicode CMaps with PDF whitespace separators" {
  let doc = @pdflite.pdf_document_empty()
  let cmap = text_concat_for_test([
    @ascii.encode("2 beginbfchar"),
    text_bytes_for_test([12]),
    @ascii.encode("<41>"),
    text_bytes_for_test([0]),
    @ascii.encode("<0041>"),
    text_bytes_for_test([12]),
    @ascii.encode("<42>"),
    text_bytes_for_test([0]),
    @ascii.encode("<0042> endbfchar\n1 beginbfrange"),
    text_bytes_for_test([12]),
    @ascii.encode("<43>"),
    text_bytes_for_test([0]),
    @ascii.encode("<44>"),
    text_bytes_for_test([12]),
    @ascii.encode("<0043> endbfrange\n"),
  ])
  let tounicode = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([]),
    StreamGot(cmap),
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
      (65, text_bytes_for_test([0x00, 0x41])),
      (66, text_bytes_for_test([0x00, 0x42])),
      (67, text_bytes_for_test([0x00, 0x43])),
      (68, text_bytes_for_test([0x00, 0x44])),
    ]),
  )
  let extractor = try! doc.text_extractor_of_font(font)
  @test.assert_eq(
    try! extractor.codepoints_of_text(
      text_bytes_for_test([65, 66, 67, 68, 69])[:],
    ),
    [0x41, 0x42, 0x43, 0x44, 69],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x44), Some(68))
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
  doc.add_object_given_number(
    8,
    PdfNameObject(text_name_for_test("/ASCIIHexDecode")),
  )
  let tounicode = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (text_name_for_test("/Length"), PdfInteger(encoded.length())),
      (text_name_for_test("/Filter"), PdfIndirect(8)),
    ]),
    StreamGot(encoded),
  )
  doc.add_object_given_number(9, tounicode)
  let font = @pdflite.pdf_dictionary([
    (
      text_name_for_test("/Subtype"),
      PdfNameObject(text_name_for_test("/Type1")),
    ),
    (
      text_name_for_test("/BaseFont"),
      PdfNameObject(text_name_for_test("/Custom")),
    ),
    (text_name_for_test("/ToUnicode"), PdfIndirect(9)),
  ])
  let extractor = try! doc.text_extractor_of_font(font)
  @test.assert_eq(
    try! extractor.codepoints_of_text(text_bytes_for_test([65, 66])[:]),
    [0x5A, 66],
  )
}

///|
test "PdfTextExtractor reads identity CMap text as two-byte character codes" {
  let composite : @pdflite.PdfCompositeCIDFont = {
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
  }
  let cid_font_h : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_name_for_test("/Top"),
    composite,
    encoding: PdfPredefinedCMap(text_name_for_test("/Identity-H")),
  })
  let extractor = cid_font_h.text_extractor()
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
  @test.assert_eq(extractor.charcode_of_codepoint(0xF6E6), None)
  let odd = try? extractor.codepoints_of_text(text_bytes_for_test([0x00])[:])
  guard odd is Err(BadText) else { fail("expected BadText") }
  let cid_font_v : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_name_for_test("/TopVertical"),
    composite,
    encoding: PdfPredefinedCMap(text_name_for_test("/Identity-V")),
  })
  @test.assert_eq(cid_font_v.is_identity_h(), false)
  let vertical_extractor = cid_font_v.text_extractor()
  @test.assert_eq(
    try! vertical_extractor.codepoints_of_text(
      text_bytes_for_test([0x00, 0x42, 0x4E, 0x00])[:],
    ),
    [0x42, 0x4E00],
  )
  @test.assert_eq(
    try! vertical_extractor.glyphnames_of_text(
      text_bytes_for_test([0x4E, 0x00])[:],
    ),
    [text_name_for_test(".notdef")],
  )
  let vertical_odd = try? vertical_extractor.codepoints_of_text(
    text_bytes_for_test([0x4E])[:],
  )
  guard vertical_odd is Err(BadText) else { fail("expected BadText") }
  let external_cmap_font : @pdflite.PdfFont = PdfFontCIDKeyed({
    basefont: text_name_for_test("/ExternalCMap"),
    composite,
    encoding: PdfCMap(7),
  })
  let external_extractor = external_cmap_font.text_extractor()
  @test.assert_eq(
    try! external_extractor.codepoints_of_text(
      text_bytes_for_test([0x00, 0x42])[:],
    ),
    [0x00, 0x42],
  )
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
  @test.assert_eq(
    try! extractor.codepoints_of_text(text_bytes_for_test([9, 10, 12, 13])[:]),
    [9, 10, 12, 13],
  )
  @test.assert_eq(
    try! extractor.glyphnames_of_text(text_bytes_for_test([9, 10, 12, 13])[:]),
    [
      text_name_for_test("/controlHT"),
      text_name_for_test("/controlLF"),
      text_name_for_test("/controlFF"),
      text_name_for_test("/controlCR"),
    ],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(65), Some(65))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2019), Some(39))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2018), Some(96))
  @test.assert_eq(extractor.charcode_of_codepoint(9), Some(9))
  @test.assert_eq(extractor.charcode_of_codepoint(10), Some(10))
  @test.assert_eq(extractor.charcode_of_codepoint(12), Some(12))
  @test.assert_eq(extractor.charcode_of_codepoint(13), Some(13))
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
test "PdfTextExtractor extracts MacRoman punctuation symbols" {
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(PdfHelvetica, PdfMacRomanEncoding),
  )
  let extractor = standard_font.text_extractor()
  let text = text_bytes_for_test([
    0xA0, 0xA1, 0xA2, 0xA3, 0xA4, 0xA5, 0xA6, 0xA7, 0xA8, 0xA9, 0xAA, 0xAB, 0xAC,
    0xAE, 0xAF,
  ])
  @test.assert_eq(try! extractor.codepoints_of_text(text[:]), [
    0x2020, 0x00B0, 0x00A2, 0x00A3, 0x00A7, 0x2022, 0x00B6, 0x00DF, 0x00AE, 0x00A9,
    0x2122, 0x00B4, 0x00A8, 0x00C6, 0x00D8,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(text[:]), [
    text_name_for_test("/dagger"),
    text_name_for_test("/degree"),
    text_name_for_test("/cent"),
    text_name_for_test("/sterling"),
    text_name_for_test("/section"),
    text_name_for_test("/bullet"),
    text_name_for_test("/paragraph"),
    text_name_for_test("/germandbls"),
    text_name_for_test("/registered"),
    text_name_for_test("/copyright"),
    text_name_for_test("/trademark"),
    text_name_for_test("/acute"),
    text_name_for_test("/dieresis"),
    text_name_for_test("/AE"),
    text_name_for_test("/Oslash"),
  ])
  @test.assert_eq(extractor.charcode_of_codepoint(0x2020), Some(0xA0))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2022), Some(0xA5))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2122), Some(0xAA))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00C6), Some(0xAE))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00D8), Some(0xAF))
}

///|
test "PdfTextExtractor extracts MacRoman sparse B-range glyphs" {
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(PdfHelvetica, PdfMacRomanEncoding),
  )
  let extractor = standard_font.text_extractor()
  let text = text_bytes_for_test([0xB1, 0xB4, 0xB5, 0xBB, 0xBC, 0xBE, 0xBF])
  @test.assert_eq(try! extractor.codepoints_of_text(text[:]), [
    0x00B1, 0x00A5, 0x00B5, 0x00AA, 0x00BA, 0x00E6, 0x00F8,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(text[:]), [
    text_name_for_test("/plusminus"),
    text_name_for_test("/yen"),
    text_name_for_test("/mu"),
    text_name_for_test("/ordfeminine"),
    text_name_for_test("/ordmasculine"),
    text_name_for_test("/ae"),
    text_name_for_test("/oslash"),
  ])
  @test.assert_eq(extractor.charcode_of_codepoint(0x00B1), Some(0xB1))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00A5), Some(0xB4))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00B5), Some(0xB5))
  @test.assert_eq(extractor.charcode_of_codepoint(0x03BC), None)
  @test.assert_eq(extractor.charcode_of_codepoint(0x00AA), Some(0xBB))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00F8), Some(0xBF))
}

///|
test "PdfTextExtractor extracts MacRoman C-range glyphs" {
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(PdfHelvetica, PdfMacRomanEncoding),
  )
  let extractor = standard_font.text_extractor()
  let text = text_bytes_for_test([
    0xC0, 0xC1, 0xC2, 0xC4, 0xC7, 0xC8, 0xC9, 0xCA, 0xCB, 0xCC, 0xCD, 0xCE, 0xCF,
  ])
  @test.assert_eq(try! extractor.codepoints_of_text(text[:]), [
    0x00BF, 0x00A1, 0x00AC, 0x0192, 0x00AB, 0x00BB, 0x2026, 0x20, 0x00C0, 0x00C3,
    0x00D5, 0x0152, 0x0153,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(text[:]), [
    text_name_for_test("/questiondown"),
    text_name_for_test("/exclamdown"),
    text_name_for_test("/logicalnot"),
    text_name_for_test("/florin"),
    text_name_for_test("/guillemotleft"),
    text_name_for_test("/guillemotright"),
    text_name_for_test("/ellipsis"),
    text_name_for_test("/space"),
    text_name_for_test("/Agrave"),
    text_name_for_test("/Atilde"),
    text_name_for_test("/Otilde"),
    text_name_for_test("/OE"),
    text_name_for_test("/oe"),
  ])
  @test.assert_eq(extractor.charcode_of_codepoint(0x00BF), Some(0xC0))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0192), Some(0xC4))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2026), Some(0xC9))
  @test.assert_eq(extractor.charcode_of_codepoint(0x20), Some(0x20))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0153), Some(0xCF))
}

///|
test "PdfTextExtractor extracts MacRoman D-range glyphs" {
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(PdfHelvetica, PdfMacRomanEncoding),
  )
  let extractor = standard_font.text_extractor()
  let text = text_bytes_for_test([
    0xD0, 0xD1, 0xD2, 0xD3, 0xD4, 0xD5, 0xD6, 0xD8, 0xD9, 0xDA, 0xDB, 0xDC, 0xDD,
    0xDE, 0xDF,
  ])
  @test.assert_eq(try! extractor.codepoints_of_text(text[:]), [
    0x2013, 0x2014, 0x201C, 0x201D, 0x2018, 0x2019, 0x00F7, 0x00FF, 0x0178, 0x2044,
    0x00A4, 0x2039, 0x203A, 0xFB01, 0xFB02,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(text[:]), [
    text_name_for_test("/endash"),
    text_name_for_test("/emdash"),
    text_name_for_test("/quotedblleft"),
    text_name_for_test("/quotedblright"),
    text_name_for_test("/quoteleft"),
    text_name_for_test("/quoteright"),
    text_name_for_test("/divide"),
    text_name_for_test("/ydieresis"),
    text_name_for_test("/Ydieresis"),
    text_name_for_test("/fraction"),
    text_name_for_test("/currency"),
    text_name_for_test("/guilsinglleft"),
    text_name_for_test("/guilsinglright"),
    text_name_for_test("/fi"),
    text_name_for_test("/fl"),
  ])
  @test.assert_eq(extractor.charcode_of_codepoint(0x2013), Some(0xD0))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00F7), Some(0xD6))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0178), Some(0xD9))
  @test.assert_eq(extractor.charcode_of_codepoint(0xFB01), Some(0xDE))
  @test.assert_eq(extractor.charcode_of_codepoint(0xFB02), Some(0xDF))
}

///|
test "PdfTextExtractor extracts MacRoman EF-range glyphs" {
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(PdfHelvetica, PdfMacRomanEncoding),
  )
  let extractor = standard_font.text_extractor()
  let text = text_bytes_for_test([
    0xE0, 0xE1, 0xE2, 0xE3, 0xE4, 0xE5, 0xE6, 0xE7, 0xE8, 0xE9, 0xEA, 0xEB, 0xEC,
    0xED, 0xEE, 0xEF, 0xF1, 0xF2, 0xF3, 0xF4, 0xF5, 0xF6, 0xF7, 0xF8, 0xF9, 0xFA,
    0xFB, 0xFC, 0xFD, 0xFE, 0xFF,
  ])
  @test.assert_eq(try! extractor.codepoints_of_text(text[:]), [
    0x2021, 0x00B7, 0x201A, 0x201E, 0x2030, 0x00C2, 0x00CA, 0x00C1, 0x00CB, 0x00C8,
    0x00CD, 0x00CE, 0x00CF, 0x00CC, 0x00D3, 0x00D4, 0x00D2, 0x00DA, 0x00DB, 0x00D9,
    0x0131, 0x02C6, 0x02DC, 0x00AF, 0x02D8, 0x02D9, 0x02DA, 0x00B8, 0x02DD, 0x02DB,
    0x02C7,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(text[:]), [
    text_name_for_test("/daggerdbl"),
    text_name_for_test("/periodcentered"),
    text_name_for_test("/quotesinglbase"),
    text_name_for_test("/quotedblbase"),
    text_name_for_test("/perthousand"),
    text_name_for_test("/Acircumflex"),
    text_name_for_test("/Ecircumflex"),
    text_name_for_test("/Aacute"),
    text_name_for_test("/Edieresis"),
    text_name_for_test("/Egrave"),
    text_name_for_test("/Iacute"),
    text_name_for_test("/Icircumflex"),
    text_name_for_test("/Idieresis"),
    text_name_for_test("/Igrave"),
    text_name_for_test("/Oacute"),
    text_name_for_test("/Ocircumflex"),
    text_name_for_test("/Ograve"),
    text_name_for_test("/Uacute"),
    text_name_for_test("/Ucircumflex"),
    text_name_for_test("/Ugrave"),
    text_name_for_test("/dotlessi"),
    text_name_for_test("/circumflex"),
    text_name_for_test("/tilde"),
    text_name_for_test("/macron"),
    text_name_for_test("/breve"),
    text_name_for_test("/dotaccent"),
    text_name_for_test("/ring"),
    text_name_for_test("/cedilla"),
    text_name_for_test("/hungarumlaut"),
    text_name_for_test("/ogonek"),
    text_name_for_test("/caron"),
  ])
  @test.assert_eq(extractor.charcode_of_codepoint(0x2021), Some(0xE0))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2030), Some(0xE4))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00C2), Some(0xE5))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0131), Some(0xF5))
  @test.assert_eq(extractor.charcode_of_codepoint(0x02DD), Some(0xFD))
  @test.assert_eq(extractor.charcode_of_codepoint(0x02C7), Some(0xFF))
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
        0xA0, 0xA1, 0xA6, 0xAC, 0xAD, 0xAE, 0xB0, 0xB1, 0xB5, 0xBC, 0xC0, 0xC6, 0xD0,
        0xD8, 0xDE, 0xE6, 0xF0, 0xF8, 0xFE, 0xFF,
      ])[:],
    ),
    [
      0x20, 0x00A1, 0x00A6, 0x00AC, 0x2D, 0x00AE, 0x00B0, 0x00B1, 0x00B5, 0x00BC,
      0x00C0, 0x00C6, 0x00D0, 0x00D8, 0x00DE, 0x00E6, 0x00F0, 0x00F8, 0x00FE, 0x00FF,
    ],
  )
  @test.assert_eq(
    try! extractor.glyphnames_of_text(
      text_bytes_for_test([
        0xA0, 0xA1, 0xA6, 0xAC, 0xAD, 0xAE, 0xB0, 0xB1, 0xB5, 0xBC, 0xC0, 0xC6, 0xD0,
        0xD8, 0xDE, 0xE6, 0xF0, 0xF8, 0xFE, 0xFF,
      ])[:],
    ),
    [
      text_name_for_test("/space"),
      text_name_for_test("/exclamdown"),
      text_name_for_test("/brokenbar"),
      text_name_for_test("/logicalnot"),
      text_name_for_test("/hyphen"),
      text_name_for_test("/registered"),
      text_name_for_test("/degree"),
      text_name_for_test("/plusminus"),
      text_name_for_test("/mu"),
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
  @test.assert_eq(extractor.charcode_of_codepoint(0x20), Some(0x20))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2D), Some(0x2D))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00A6), Some(0xA6))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00AC), Some(0xAC))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00B1), Some(0xB1))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00B5), Some(0xB5))
  @test.assert_eq(extractor.charcode_of_codepoint(0x03BC), None)
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
test "PdfTextExtractor extracts MacExpert oldstyle digits" {
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(PdfHelvetica, PdfMacExpertEncoding),
  )
  let extractor = standard_font.text_extractor()
  let text = text_bytes_for_test([
    0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39,
  ])
  @test.assert_eq(try! extractor.codepoints_of_text(text[:]), [
    0xF730, 0xF731, 0xF732, 0xF733, 0xF734, 0xF735, 0xF736, 0xF737, 0xF738, 0xF739,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(text[:]), [
    text_name_for_test("/zerooldstyle"),
    text_name_for_test("/oneoldstyle"),
    text_name_for_test("/twooldstyle"),
    text_name_for_test("/threeoldstyle"),
    text_name_for_test("/fouroldstyle"),
    text_name_for_test("/fiveoldstyle"),
    text_name_for_test("/sixoldstyle"),
    text_name_for_test("/sevenoldstyle"),
    text_name_for_test("/eightoldstyle"),
    text_name_for_test("/nineoldstyle"),
  ])
  @test.assert_eq(extractor.charcode_of_codepoint(0xF730), Some(0x30))
  @test.assert_eq(extractor.charcode_of_codepoint(0xF735), Some(0x35))
  @test.assert_eq(extractor.charcode_of_codepoint(0xF739), Some(0x39))
}

///|
test "PdfTextExtractor extracts MacExpert superior and inferior digits" {
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(PdfHelvetica, PdfMacExpertEncoding),
  )
  let extractor = standard_font.text_extractor()
  let inferior = text_bytes_for_test([
    0xBC, 0xC1, 0xAA, 0xA3, 0xA2, 0xB0, 0xA4, 0xA6, 0xA5, 0xBB,
  ])
  @test.assert_eq(try! extractor.codepoints_of_text(inferior[:]), [
    0x2080, 0x2081, 0x2082, 0x2083, 0x2084, 0x2085, 0x2086, 0x2087, 0x2088, 0x2089,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(inferior[:]), [
    text_name_for_test("/zeroinferior"),
    text_name_for_test("/oneinferior"),
    text_name_for_test("/twoinferior"),
    text_name_for_test("/threeinferior"),
    text_name_for_test("/fourinferior"),
    text_name_for_test("/fiveinferior"),
    text_name_for_test("/sixinferior"),
    text_name_for_test("/seveninferior"),
    text_name_for_test("/eightinferior"),
    text_name_for_test("/nineinferior"),
  ])
  let superior = text_bytes_for_test([
    0xE2, 0xDA, 0xDB, 0xDC, 0xDD, 0xDE, 0xDF, 0xE0, 0xA1, 0xE1,
  ])
  @test.assert_eq(try! extractor.codepoints_of_text(superior[:]), [
    0x2070, 0x00B9, 0x00B2, 0x00B3, 0x2074, 0x2075, 0x2076, 0x2077, 0x2078, 0x2079,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(superior[:]), [
    text_name_for_test("/zerosuperior"),
    text_name_for_test("/onesuperior"),
    text_name_for_test("/twosuperior"),
    text_name_for_test("/threesuperior"),
    text_name_for_test("/foursuperior"),
    text_name_for_test("/fivesuperior"),
    text_name_for_test("/sixsuperior"),
    text_name_for_test("/sevensuperior"),
    text_name_for_test("/eightsuperior"),
    text_name_for_test("/ninesuperior"),
  ])
  @test.assert_eq(extractor.charcode_of_codepoint(0x2080), Some(0xBC))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2085), Some(0xB0))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2089), Some(0xBB))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2070), Some(0xE2))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2075), Some(0xDE))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2079), Some(0xE1))
}

///|
test "PdfTextExtractor extracts MacExpert fractions" {
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(PdfHelvetica, PdfMacExpertEncoding),
  )
  let extractor = standard_font.text_extractor()
  let text = text_bytes_for_test([
    0x2F, 0x47, 0x48, 0x49, 0x4A, 0x4B, 0x4C, 0x4D, 0x4E, 0x4F, 0x3D,
  ])
  @test.assert_eq(try! extractor.codepoints_of_text(text[:]), [
    0x2044, 0x00BC, 0x00BD, 0x00BE, 0x215B, 0x215C, 0x215D, 0x215E, 0x2153, 0x2154,
    0xF6DE,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(text[:]), [
    text_name_for_test("/fraction"),
    text_name_for_test("/onequarter"),
    text_name_for_test("/onehalf"),
    text_name_for_test("/threequarters"),
    text_name_for_test("/oneeighth"),
    text_name_for_test("/threeeighths"),
    text_name_for_test("/fiveeighths"),
    text_name_for_test("/seveneighths"),
    text_name_for_test("/onethird"),
    text_name_for_test("/twothirds"),
    text_name_for_test("/threequartersemdash"),
  ])
  @test.assert_eq(extractor.charcode_of_codepoint(0x2044), Some(0x2F))
  @test.assert_eq(extractor.charcode_of_codepoint(0x215D), Some(0x4C))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2154), Some(0x4F))
  @test.assert_eq(extractor.charcode_of_codepoint(0xF6DE), Some(0x3D))
}

///|
test "PdfTextExtractor extracts MacExpert small capitals" {
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(PdfHelvetica, PdfMacExpertEncoding),
  )
  let extractor = standard_font.text_extractor()
  let text = text_bytes_for_test([
    0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6A, 0x6B, 0x6C, 0x6D,
    0x6E, 0x6F, 0x70, 0x71, 0x72, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7A,
  ])
  @test.assert_eq(try! extractor.codepoints_of_text(text[:]), [
    0xF761, 0xF762, 0xF763, 0xF764, 0xF765, 0xF766, 0xF767, 0xF768, 0xF769, 0xF76A,
    0xF76B, 0xF76C, 0xF76D, 0xF76E, 0xF76F, 0xF770, 0xF771, 0xF772, 0xF773, 0xF774,
    0xF775, 0xF776, 0xF777, 0xF778, 0xF779, 0xF77A,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(text[:]), [
    text_name_for_test("/Asmall"),
    text_name_for_test("/Bsmall"),
    text_name_for_test("/Csmall"),
    text_name_for_test("/Dsmall"),
    text_name_for_test("/Esmall"),
    text_name_for_test("/Fsmall"),
    text_name_for_test("/Gsmall"),
    text_name_for_test("/Hsmall"),
    text_name_for_test("/Ismall"),
    text_name_for_test("/Jsmall"),
    text_name_for_test("/Ksmall"),
    text_name_for_test("/Lsmall"),
    text_name_for_test("/Msmall"),
    text_name_for_test("/Nsmall"),
    text_name_for_test("/Osmall"),
    text_name_for_test("/Psmall"),
    text_name_for_test("/Qsmall"),
    text_name_for_test("/Rsmall"),
    text_name_for_test("/Ssmall"),
    text_name_for_test("/Tsmall"),
    text_name_for_test("/Usmall"),
    text_name_for_test("/Vsmall"),
    text_name_for_test("/Wsmall"),
    text_name_for_test("/Xsmall"),
    text_name_for_test("/Ysmall"),
    text_name_for_test("/Zsmall"),
  ])
  @test.assert_eq(extractor.charcode_of_codepoint(0xF761), Some(0x61))
  @test.assert_eq(extractor.charcode_of_codepoint(0xF76D), Some(0x6D))
  @test.assert_eq(extractor.charcode_of_codepoint(0xF77A), Some(0x7A))
}

///|
test "PdfTextExtractor extracts MacExpert accented small capitals" {
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(PdfHelvetica, PdfMacExpertEncoding),
  )
  let extractor = standard_font.text_extractor()
  let text = text_bytes_for_test([
    0xBE, 0x87, 0x89, 0x8A, 0x88, 0x8C, 0x8B, 0x8D, 0x8E, 0x90, 0x91, 0x8F, 0x44,
    0x92, 0x94, 0x95, 0x93, 0xC2, 0x96, 0xCF, 0x97, 0x99, 0x9A, 0x98, 0xBF, 0x9B,
    0xA7, 0xB9, 0x9C, 0x9E, 0x9F, 0x9D, 0xB4, 0xD8, 0xBD,
  ])
  @test.assert_eq(try! extractor.codepoints_of_text(text[:]), [
    0xF7E6, 0xF7E1, 0xF7E2, 0xF7E4, 0xF7E0, 0xF7E5, 0xF7E3, 0xF7E7, 0xF7E9, 0xF7EA,
    0xF7EB, 0xF7E8, 0xF7F0, 0xF7ED, 0xF7EE, 0xF7EF, 0xF7EC, 0xF6F9, 0xF7F1, 0xF6FA,
    0xF7F3, 0xF7F4, 0xF7F6, 0xF7F2, 0xF7F8, 0xF7F5, 0xF6FD, 0xF7FE, 0xF7FA, 0xF7FB,
    0xF7FC, 0xF7F9, 0xF7FD, 0xF7FF, 0xF6FF,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(text[:]), [
    text_name_for_test("/AEsmall"),
    text_name_for_test("/Aacutesmall"),
    text_name_for_test("/Acircumflexsmall"),
    text_name_for_test("/Adieresissmall"),
    text_name_for_test("/Agravesmall"),
    text_name_for_test("/Aringsmall"),
    text_name_for_test("/Atildesmall"),
    text_name_for_test("/Ccedillasmall"),
    text_name_for_test("/Eacutesmall"),
    text_name_for_test("/Ecircumflexsmall"),
    text_name_for_test("/Edieresissmall"),
    text_name_for_test("/Egravesmall"),
    text_name_for_test("/Ethsmall"),
    text_name_for_test("/Iacutesmall"),
    text_name_for_test("/Icircumflexsmall"),
    text_name_for_test("/Idieresissmall"),
    text_name_for_test("/Igravesmall"),
    text_name_for_test("/Lslashsmall"),
    text_name_for_test("/Ntildesmall"),
    text_name_for_test("/OEsmall"),
    text_name_for_test("/Oacutesmall"),
    text_name_for_test("/Ocircumflexsmall"),
    text_name_for_test("/Odieresissmall"),
    text_name_for_test("/Ogravesmall"),
    text_name_for_test("/Oslashsmall"),
    text_name_for_test("/Otildesmall"),
    text_name_for_test("/Scaronsmall"),
    text_name_for_test("/Thornsmall"),
    text_name_for_test("/Uacutesmall"),
    text_name_for_test("/Ucircumflexsmall"),
    text_name_for_test("/Udieresissmall"),
    text_name_for_test("/Ugravesmall"),
    text_name_for_test("/Yacutesmall"),
    text_name_for_test("/Ydieresissmall"),
    text_name_for_test("/Zcaronsmall"),
  ])
  @test.assert_eq(extractor.charcode_of_codepoint(0xF7E6), Some(0xBE))
  @test.assert_eq(extractor.charcode_of_codepoint(0xF7F0), Some(0x44))
  @test.assert_eq(extractor.charcode_of_codepoint(0xF6FF), Some(0xBD))
}

///|
test "PdfTextExtractor extracts MacExpert small accent marks" {
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(PdfHelvetica, PdfMacExpertEncoding),
  )
  let extractor = standard_font.text_extractor()
  let text = text_bytes_for_test([
    0x27, 0xF3, 0xAE, 0xC9, 0x5E, 0xAC, 0xFA, 0x60, 0x22, 0xF4, 0xF2, 0xFB, 0x7E,
  ])
  @test.assert_eq(try! extractor.codepoints_of_text(text[:]), [
    0xF7B4, 0xF6F4, 0xF6F5, 0xF7B8, 0xF6F6, 0xF7A8, 0xF6F7, 0xF760, 0xF6F8, 0xF7AF,
    0xF6FB, 0xF6FC, 0xF6FE,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(text[:]), [
    text_name_for_test("/Acutesmall"),
    text_name_for_test("/Brevesmall"),
    text_name_for_test("/Caronsmall"),
    text_name_for_test("/Cedillasmall"),
    text_name_for_test("/Circumflexsmall"),
    text_name_for_test("/Dieresissmall"),
    text_name_for_test("/Dotaccentsmall"),
    text_name_for_test("/Gravesmall"),
    text_name_for_test("/Hungarumlautsmall"),
    text_name_for_test("/Macronsmall"),
    text_name_for_test("/Ogoneksmall"),
    text_name_for_test("/Ringsmall"),
    text_name_for_test("/Tildesmall"),
  ])
  @test.assert_eq(extractor.charcode_of_codepoint(0xF7B4), Some(0x27))
  @test.assert_eq(extractor.charcode_of_codepoint(0xF6F7), Some(0xFA))
  @test.assert_eq(extractor.charcode_of_codepoint(0xF6FE), Some(0x7E))
}

///|
test "PdfTextExtractor extracts MacExpert small punctuation and currency" {
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(PdfHelvetica, PdfMacExpertEncoding),
  )
  let extractor = standard_font.text_extractor()
  let text = text_bytes_for_test([
    0x20, 0x21, 0x23, 0x24, 0x26, 0x2A, 0x2B, 0x2C, 0x2D, 0x2E, 0x3A, 0x3B, 0x3F,
    0x7B, 0x7C, 0x7D, 0xC0, 0xD0, 0xD6,
  ])
  @test.assert_eq(try! extractor.codepoints_of_text(text[:]), [
    0x20, 0xF721, 0xF7A2, 0xF724, 0xF726, 0x2025, 0x2024, 0x2C, 0x2D, 0x2E, 0x3A,
    0x3B, 0xF73F, 0x20A1, 0xF6DC, 0xF6DD, 0xF7BF, 0x2012, 0xF7A1,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(text[:]), [
    text_name_for_test("/space"),
    text_name_for_test("/exclamsmall"),
    text_name_for_test("/centoldstyle"),
    text_name_for_test("/dollaroldstyle"),
    text_name_for_test("/ampersandsmall"),
    text_name_for_test("/twodotenleader"),
    text_name_for_test("/onedotenleader"),
    text_name_for_test("/comma"),
    text_name_for_test("/hyphen"),
    text_name_for_test("/period"),
    text_name_for_test("/colon"),
    text_name_for_test("/semicolon"),
    text_name_for_test("/questionsmall"),
    text_name_for_test("/colonmonetary"),
    text_name_for_test("/onefitted"),
    text_name_for_test("/rupiah"),
    text_name_for_test("/questiondownsmall"),
    text_name_for_test("/figuredash"),
    text_name_for_test("/exclamdownsmall"),
  ])
  @test.assert_eq(extractor.charcode_of_codepoint(0xF721), Some(0x21))
  @test.assert_eq(extractor.charcode_of_codepoint(0xF724), Some(0x24))
  @test.assert_eq(extractor.charcode_of_codepoint(0x20A1), Some(0x7B))
  @test.assert_eq(extractor.charcode_of_codepoint(0xF7A1), Some(0xD6))
}

///|
test "PdfTextExtractor extracts MacExpert superior and inferior punctuation and letters" {
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(PdfHelvetica, PdfMacExpertEncoding),
  )
  let extractor = standard_font.text_extractor()
  let text = text_bytes_for_test([
    0x28, 0x29, 0x5B, 0x5D, 0x5F, 0x81, 0x82, 0xA9, 0xAF, 0xB2, 0xB3, 0xB6, 0xE4,
    0xE5, 0xE6, 0xE9, 0xEA, 0xEB, 0xF1, 0xF5, 0xF6, 0xF7, 0xF8, 0xF9,
  ])
  @test.assert_eq(try! extractor.codepoints_of_text(text[:]), [
    0x207D, 0x207E, 0x208D, 0x208E, 0xF6E5, 0xF6E9, 0xF6E0, 0xF6DF, 0xF6F0, 0xF6E1,
    0xF6E7, 0xF6E3, 0xF6EC, 0xF6F1, 0xF6F3, 0xF6ED, 0xF6F2, 0xF6EB, 0xF6EE, 0xF6EA,
    0x207F, 0xF6EF, 0xF6E2, 0xF6E8,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(text[:]), [
    text_name_for_test("/parenleftsuperior"),
    text_name_for_test("/parenrightsuperior"),
    text_name_for_test("/parenleftinferior"),
    text_name_for_test("/parenrightinferior"),
    text_name_for_test("/hypheninferior"),
    text_name_for_test("/asuperior"),
    text_name_for_test("/centsuperior"),
    text_name_for_test("/centinferior"),
    text_name_for_test("/osuperior"),
    text_name_for_test("/commainferior"),
    text_name_for_test("/periodinferior"),
    text_name_for_test("/dollarinferior"),
    text_name_for_test("/esuperior"),
    text_name_for_test("/rsuperior"),
    text_name_for_test("/tsuperior"),
    text_name_for_test("/isuperior"),
    text_name_for_test("/ssuperior"),
    text_name_for_test("/dsuperior"),
    text_name_for_test("/lsuperior"),
    text_name_for_test("/bsuperior"),
    text_name_for_test("/nsuperior"),
    text_name_for_test("/msuperior"),
    text_name_for_test("/commasuperior"),
    text_name_for_test("/periodsuperior"),
  ])
  @test.assert_eq(extractor.charcode_of_codepoint(0x207D), Some(0x28))
  @test.assert_eq(extractor.charcode_of_codepoint(0xF6E5), Some(0x5F))
  @test.assert_eq(extractor.charcode_of_codepoint(0xF6E0), Some(0x82))
  @test.assert_eq(extractor.charcode_of_codepoint(0xF6EA), Some(0xF5))
  @test.assert_eq(extractor.charcode_of_codepoint(0xF6E8), Some(0xF9))
}

///|
test "PdfTextExtractor decodes MacExpert hyphensuperior glyph names" {
  let base_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(PdfHelvetica, PdfMacExpertEncoding),
  )
  let base_extractor = base_font.text_extractor()
  @test.assert_eq(
    try! base_extractor.codepoints_of_text(text_bytes_for_test([0x5F])[:]),
    [0xF6E5],
  )
  @test.assert_eq(base_extractor.charcode_of_codepoint(0xF6E6), Some(0x5F))
  let standard_base_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(PdfHelvetica, PdfStandardEncoding),
  )
  @test.assert_eq(
    standard_base_font.text_extractor().charcode_of_codepoint(0xF6E6),
    None,
  )
  let custom_base_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(
      PdfHelvetica,
      PdfCustomEncoding(PdfMacExpertEncoding, []),
    ),
  )
  @test.assert_eq(
    custom_base_font.text_extractor().charcode_of_codepoint(0xF6E6),
    Some(0x5F),
  )
  let filled_base_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(
      PdfHelvetica,
      PdfFillUndefinedWithStandard(PdfMacExpertEncoding),
    ),
  )
  @test.assert_eq(
    filled_base_font.text_extractor().charcode_of_codepoint(0xF6E6),
    Some(0x5F),
  )
  let simple_base_font : @pdflite.PdfFont = PdfFontSimple({
    fonttype: PdfType1,
    basefont: None,
    firstchar: 0,
    lastchar: 0,
    widths: [],
    fontdescriptor: None,
    fontmetrics: None,
    encoding: PdfMacExpertEncoding,
  })
  @test.assert_eq(
    simple_base_font.text_extractor().charcode_of_codepoint(0xF6E6),
    Some(0x5F),
  )
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(
      PdfHelvetica,
      PdfCustomEncoding(PdfMacExpertEncoding, [
        text_difference_for_test("/hyphensuperior", 0x41),
      ]),
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(text_bytes_for_test([0x41, 0x5F])[:]),
    [0xF6E6, 0xF6E5],
  )
  @test.assert_eq(
    try! extractor.glyphnames_of_text(text_bytes_for_test([0x41, 0x5F])[:]),
    [
      text_name_for_test("/hyphensuperior"),
      text_name_for_test("/hypheninferior"),
    ],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0xF6E6), Some(0x41))
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
      text_bytes_for_test([0x41, 0x44, 0x57, 0x61, 0x6D, 0xA5, 0xAE, 0xB3, 0xD6])[:],
    ),
    [0x0391, 0x0394, 0x03A9, 0x03B1, 0x03BC, 0x221E, 0x2192, 0x2265, 0x221A],
  )
  @test.assert_eq(
    try! extractor.glyphnames_of_text(
      text_bytes_for_test([0x41, 0x44, 0x57, 0x61, 0x6D, 0xA5, 0xAE, 0xB3, 0xD6])[:],
    ),
    [
      text_name_for_test("/Alpha"),
      text_name_for_test("/Delta"),
      text_name_for_test("/Omega"),
      text_name_for_test("/alpha"),
      text_name_for_test("/mu"),
      text_name_for_test("/infinity"),
      text_name_for_test("/arrowright"),
      text_name_for_test("/greaterequal"),
      text_name_for_test("/radical"),
    ],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x0391), Some(0x41))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0394), Some(0x44))
  @test.assert_eq(extractor.charcode_of_codepoint(0x03A9), Some(0x57))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2206), None)
  @test.assert_eq(extractor.charcode_of_codepoint(0x2126), None)
  @test.assert_eq(extractor.charcode_of_codepoint(0x03B1), Some(0x61))
  @test.assert_eq(extractor.charcode_of_codepoint(0x03BC), Some(0x6D))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00B5), None)
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
test "PdfTextExtractor extracts implicit Symbol punctuation and variant glyphs" {
  let symbol_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(PdfSymbol, PdfImplicitInFontFile),
  )
  let extractor = symbol_font.text_extractor()
  let text = text_bytes_for_test([
    0x3A, 0x3B, 0x3C, 0x3E, 0x3F, 0x4A, 0x56, 0x5B, 0x5D, 0x5F, 0x60, 0x6A, 0x76,
    0x7B, 0x7C, 0x7D, 0xA1,
  ])
  @test.assert_eq(try! extractor.codepoints_of_text(text[:]), [
    58, 59, 60, 62, 63, 0x03D1, 0x03C2, 91, 93, 95, 0xF8E5, 0x03D5, 0x03D6, 123,
    124, 125, 0x03D2,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(text[:]), [
    text_name_for_test("/colon"),
    text_name_for_test("/semicolon"),
    text_name_for_test("/less"),
    text_name_for_test("/greater"),
    text_name_for_test("/question"),
    text_name_for_test("/theta1"),
    text_name_for_test("/sigma1"),
    text_name_for_test("/bracketleft"),
    text_name_for_test("/bracketright"),
    text_name_for_test("/underscore"),
    text_name_for_test("/radicalex"),
    text_name_for_test("/phi1"),
    text_name_for_test("/omega1"),
    text_name_for_test("/braceleft"),
    text_name_for_test("/bar"),
    text_name_for_test("/braceright"),
    text_name_for_test("/Upsilon1"),
  ])
  @test.assert_eq(extractor.charcode_of_codepoint(0x03D1), Some(0x4A))
  @test.assert_eq(extractor.charcode_of_codepoint(0x03C2), Some(0x56))
  @test.assert_eq(extractor.charcode_of_codepoint(0xF8E5), Some(0x60))
  @test.assert_eq(extractor.charcode_of_codepoint(0x03D5), Some(0x6A))
  @test.assert_eq(extractor.charcode_of_codepoint(0x03D6), Some(0x76))
  @test.assert_eq(extractor.charcode_of_codepoint(0x03D2), Some(0xA1))
}

///|
test "PdfTextExtractor extracts implicit Symbol special glyphs" {
  let symbol_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(PdfSymbol, PdfImplicitInFontFile),
  )
  let extractor = symbol_font.text_extractor()
  let text = text_bytes_for_test([
    0xA2, 0xA4, 0xA6, 0xAF, 0xBD, 0xBE, 0xBF, 0xD2, 0xD3, 0xD4, 0xDD, 0xE1, 0xE2,
    0xE3, 0xE4, 0xF1,
  ])
  @test.assert_eq(try! extractor.codepoints_of_text(text[:]), [
    0x2032, 0x2044, 0x0192, 0x2193, 0xF8E6, 0xF8E7, 0x21B5, 0xF6DA, 0xF6D9, 0xF6DB,
    0x21D1, 0x2329, 0xF8E8, 0xF8E9, 0xF8EA, 0x232A,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(text[:]), [
    text_name_for_test("/minute"),
    text_name_for_test("/fraction"),
    text_name_for_test("/florin"),
    text_name_for_test("/arrowdown"),
    text_name_for_test("/arrowvertex"),
    text_name_for_test("/arrowhorizex"),
    text_name_for_test("/carriagereturn"),
    text_name_for_test("/registerserif"),
    text_name_for_test("/copyrightserif"),
    text_name_for_test("/trademarkserif"),
    text_name_for_test("/arrowdblup"),
    text_name_for_test("/angleleft"),
    text_name_for_test("/registersans"),
    text_name_for_test("/copyrightsans"),
    text_name_for_test("/trademarksans"),
    text_name_for_test("/angleright"),
  ])
  @test.assert_eq(extractor.charcode_of_codepoint(0x2032), Some(0xA2))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2193), Some(0xAF))
  @test.assert_eq(extractor.charcode_of_codepoint(0xF8E6), Some(0xBD))
  @test.assert_eq(extractor.charcode_of_codepoint(0x21D1), Some(0xDD))
  @test.assert_eq(extractor.charcode_of_codepoint(0x232A), Some(0xF1))
}

///|
test "PdfTextExtractor extracts implicit Symbol assembly glyphs" {
  let symbol_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(PdfSymbol, PdfImplicitInFontFile),
  )
  let extractor = symbol_font.text_extractor()
  let text = text_bytes_for_test([
    0xE6, 0xE7, 0xE8, 0xE9, 0xEA, 0xEB, 0xEC, 0xED, 0xEE, 0xEF, 0xF2, 0xF3, 0xF4,
    0xF5, 0xF6, 0xF7, 0xF8, 0xF9, 0xFA, 0xFB, 0xFC, 0xFD, 0xFE,
  ])
  @test.assert_eq(try! extractor.codepoints_of_text(text[:]), [
    0xF8EB, 0xF8EC, 0xF8ED, 0xF8EE, 0xF8EF, 0xF8F0, 0xF8F1, 0xF8F2, 0xF8F3, 0xF8F4,
    0x222B, 0x2320, 0xF8F5, 0x2321, 0xF8F6, 0xF8F7, 0xF8F8, 0xF8F9, 0xF8FA, 0xF8FB,
    0xF8FC, 0xF8FD, 0xF8FE,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(text[:]), [
    text_name_for_test("/parenlefttp"),
    text_name_for_test("/parenleftex"),
    text_name_for_test("/parenleftbt"),
    text_name_for_test("/bracketlefttp"),
    text_name_for_test("/bracketleftex"),
    text_name_for_test("/bracketleftbt"),
    text_name_for_test("/bracelefttp"),
    text_name_for_test("/braceleftmid"),
    text_name_for_test("/braceleftbt"),
    text_name_for_test("/braceex"),
    text_name_for_test("/integral"),
    text_name_for_test("/integraltp"),
    text_name_for_test("/integralex"),
    text_name_for_test("/integralbt"),
    text_name_for_test("/parenrighttp"),
    text_name_for_test("/parenrightex"),
    text_name_for_test("/parenrightbt"),
    text_name_for_test("/bracketrighttp"),
    text_name_for_test("/bracketrightex"),
    text_name_for_test("/bracketrightbt"),
    text_name_for_test("/bracerighttp"),
    text_name_for_test("/bracerightmid"),
    text_name_for_test("/bracerightbt"),
  ])
  @test.assert_eq(extractor.charcode_of_codepoint(0xF8EB), Some(0xE6))
  @test.assert_eq(extractor.charcode_of_codepoint(0x222B), Some(0xF2))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2321), Some(0xF5))
  @test.assert_eq(extractor.charcode_of_codepoint(0xF8FE), Some(0xFE))
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
test "PdfTextExtractor extracts implicit ZapfDingbats final arrow glyphs" {
  let dingbat_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(PdfZapfDingbats, PdfImplicitInFontFile),
  )
  let extractor = dingbat_font.text_extractor()
  let text = text_bytes_for_test([
    0xF1, 0xF2, 0xF3, 0xF4, 0xF5, 0xF6, 0xF7, 0xF8, 0xF9, 0xFA, 0xFB, 0xFC, 0xFD,
    0xFE,
  ])
  @test.assert_eq(try! extractor.codepoints_of_text(text[:]), [
    0x27B1, 0x27B2, 0x27B3, 0x27B4, 0x27B5, 0x27B6, 0x27B7, 0x27B8, 0x27B9, 0x27BA,
    0x27BB, 0x27BC, 0x27BD, 0x27BE,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(text[:]), [
    text_name_for_test("/a201"),
    text_name_for_test("/a183"),
    text_name_for_test("/a184"),
    text_name_for_test("/a197"),
    text_name_for_test("/a185"),
    text_name_for_test("/a194"),
    text_name_for_test("/a198"),
    text_name_for_test("/a186"),
    text_name_for_test("/a195"),
    text_name_for_test("/a187"),
    text_name_for_test("/a188"),
    text_name_for_test("/a189"),
    text_name_for_test("/a190"),
    text_name_for_test("/a191"),
  ])
  @test.assert_eq(
    try! extractor.glyphnames_of_text(text_bytes_for_test([0xF0])[:]),
    [text_name_for_test(".notdef")],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x27B0), None)
  @test.assert_eq(extractor.charcode_of_codepoint(0x27B1), Some(0xF1))
  @test.assert_eq(extractor.charcode_of_codepoint(0x27B8), Some(0xF8))
  @test.assert_eq(extractor.charcode_of_codepoint(0x27BE), Some(0xFE))
}

///|
test "PdfTextExtractor extracts custom ZapfDingbats bracket glyph names" {
  let dingbat_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(
      PdfZapfDingbats,
      PdfCustomEncoding(PdfStandardEncoding, [
        text_difference_for_test("/a89", 65),
        text_difference_for_test("/a90", 66),
        text_difference_for_test("/a93", 67),
        text_difference_for_test("/a94", 68),
        text_difference_for_test("/a91", 69),
        text_difference_for_test("/a92", 70),
        text_difference_for_test("/a205", 71),
        text_difference_for_test("/a85", 72),
        text_difference_for_test("/a206", 73),
        text_difference_for_test("/a86", 74),
        text_difference_for_test("/a87", 75),
        text_difference_for_test("/a88", 76),
        text_difference_for_test("/a95", 77),
        text_difference_for_test("/a96", 78),
      ]),
    ),
  )
  let extractor = dingbat_font.text_extractor()
  let text = text_bytes_for_test([
    65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78,
  ])
  @test.assert_eq(try! extractor.codepoints_of_text(text[:]), [
    0x2768, 0x2769, 0x276A, 0x276B, 0x276C, 0x276D, 0x276E, 0x276F, 0x2770, 0x2771,
    0x2772, 0x2773, 0x2774, 0x2775,
  ])
  @test.assert_eq(try! extractor.glyphnames_of_text(text[:]), [
    text_name_for_test("/a89"),
    text_name_for_test("/a90"),
    text_name_for_test("/a93"),
    text_name_for_test("/a94"),
    text_name_for_test("/a91"),
    text_name_for_test("/a92"),
    text_name_for_test("/a205"),
    text_name_for_test("/a85"),
    text_name_for_test("/a206"),
    text_name_for_test("/a86"),
    text_name_for_test("/a87"),
    text_name_for_test("/a88"),
    text_name_for_test("/a95"),
    text_name_for_test("/a96"),
  ])
  @test.assert_eq(extractor.charcode_of_codepoint(0x2768), Some(65))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2770), Some(73))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2775), Some(78))
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
        text_difference_for_test("/Delta", 71),
        text_difference_for_test("/Omega", 72),
      ]),
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(
      text_bytes_for_test([65, 66, 67, 68, 69, 70, 71, 72])[:],
    ),
    [0x20AC, 65, 0x20AC, 0x00A9, 65, 66, 70, 0x2206, 0x2126],
  )
  @test.assert_eq(
    try! extractor.glyphnames_of_text(
      text_bytes_for_test([65, 66, 67, 68, 69, 70, 71, 72])[:],
    ),
    [
      text_name_for_test("/Euro"),
      text_name_for_test("/A.alt"),
      text_name_for_test("/uni20AC"),
      text_name_for_test("/u00A9"),
      text_name_for_test("/uni00410042"),
      text_name_for_test("/F"),
      text_name_for_test("/Delta"),
      text_name_for_test("/Omega"),
    ],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x20AC), Some(65))
  @test.assert_eq(extractor.charcode_of_codepoint(65), Some(66))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00A9), Some(68))
  @test.assert_eq(extractor.charcode_of_codepoint(66), None)
  @test.assert_eq(extractor.charcode_of_codepoint(70), Some(70))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2206), Some(71))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2126), Some(72))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0394), None)
  @test.assert_eq(extractor.charcode_of_codepoint(0x03A9), None)
}

///|
test "PdfTextExtractor decodes Basic Latin AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/A", 65),
    ("/B", 66),
    ("/C", 67),
    ("/D", 68),
    ("/E", 69),
    ("/F", 70),
    ("/G", 71),
    ("/H", 72),
    ("/I", 73),
    ("/J", 74),
    ("/K", 75),
    ("/L", 76),
    ("/M", 77),
    ("/N", 78),
    ("/O", 79),
    ("/P", 80),
    ("/Q", 81),
    ("/R", 82),
    ("/S", 83),
    ("/T", 84),
    ("/U", 85),
    ("/V", 86),
    ("/W", 87),
    ("/X", 88),
    ("/Y", 89),
    ("/Z", 90),
    ("/a", 97),
    ("/b", 98),
    ("/c", 99),
    ("/controlACK", 6),
    ("/controlBEL", 7),
    ("/controlBS", 8),
    ("/controlCAN", 24),
    ("/controlDC1", 17),
    ("/controlDC2", 18),
    ("/controlDC3", 19),
    ("/controlDC4", 20),
    ("/controlDEL", 127),
    ("/controlDLE", 16),
    ("/controlEM", 25),
    ("/controlENQ", 5),
    ("/controlEOT", 4),
    ("/controlESC", 27),
    ("/controlETB", 23),
    ("/controlETX", 3),
    ("/controlFS", 28),
    ("/controlGS", 29),
    ("/controlNAK", 21),
    ("/controlRS", 30),
    ("/controlSI", 15),
    ("/controlSO", 14),
    ("/controlSOT", 2),
    ("/controlSTX", 1),
    ("/controlSUB", 26),
    ("/controlSYN", 22),
    ("/controlUS", 31),
    ("/controlVT", 11),
    ("/d", 100),
    ("/e", 101),
    ("/f", 102),
    ("/g", 103),
    ("/h", 104),
    ("/i", 105),
    ("/j", 106),
    ("/k", 107),
    ("/l", 108),
    ("/m", 109),
    ("/n", 110),
    ("/o", 111),
    ("/p", 112),
    ("/q", 113),
    ("/r", 114),
    ("/s", 115),
    ("/spacehackarabic", 32),
    ("/t", 116),
    ("/u", 117),
    ("/v", 118),
    ("/verticalbar", 124),
    ("/w", 119),
    ("/x", 120),
    ("/y", 121),
    ("/z", 122),
  ]
  let differences : Array[@pdflite.PdfEncodingDifference] = []
  let text_codes : Array[Int] = []
  let expected_codepoints : Array[Int] = []
  for index in 0..<entries.length() {
    let entry = entries[index]
    let code = index + 1
    differences.push(text_difference_for_test(entry.0, code))
    text_codes.push(code)
    expected_codepoints.push(entry.1)
  }
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(
      PdfHelvetica,
      PdfCustomEncoding(PdfStandardEncoding, differences),
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(text_bytes_for_test(text_codes)[:]),
    expected_codepoints,
  )
  @test.assert_eq(extractor.charcode_of_codepoint(65), Some(1))
  @test.assert_eq(extractor.charcode_of_codepoint(90), Some(26))
  @test.assert_eq(extractor.charcode_of_codepoint(6), Some(30))
  @test.assert_eq(extractor.charcode_of_codepoint(127), Some(38))
  @test.assert_eq(extractor.charcode_of_codepoint(32), Some(74))
  @test.assert_eq(extractor.charcode_of_codepoint(124), Some(78))
  @test.assert_eq(extractor.charcode_of_codepoint(122), Some(82))
}

///|
test "PdfTextExtractor decodes general punctuation AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/afii00208", 0x2015),
    ("/afii299", 0x200E),
    ("/afii300", 0x200F),
    ("/afii301", 0x200D),
    ("/afii61573", 0x202C),
    ("/afii61574", 0x202D),
    ("/afii61575", 0x202E),
    ("/afii61664", 0x200C),
    ("/asterism", 0x2042),
    ("/dbllowline", 0x2017),
    ("/dblverticalbar", 0x2016),
    ("/enspace", 0x2002),
    ("/exclamdbl", 0x203C),
    ("/horizontalbar", 0x2015),
    ("/hyphentwo", 0x2010),
    ("/overline", 0x203E),
    ("/primereversed", 0x2035),
    ("/quoteleftreversed", 0x201B),
    ("/quotereversed", 0x201B),
    ("/referencemark", 0x203B),
    ("/twodotleader", 0x2025),
    ("/underscoredbl", 0x2017),
    ("/zerowidthnonjoiner", 0x200C),
    ("/zerowidthspace", 0x200B),
  ]
  let differences : Array[@pdflite.PdfEncodingDifference] = []
  let text_codes : Array[Int] = []
  let expected_codepoints : Array[Int] = []
  for index in 0..<entries.length() {
    let entry = entries[index]
    let code = index + 1
    differences.push(text_difference_for_test(entry.0, code))
    text_codes.push(code)
    expected_codepoints.push(entry.1)
  }
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(
      PdfHelvetica,
      PdfCustomEncoding(PdfStandardEncoding, differences),
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(text_bytes_for_test(text_codes)[:]),
    expected_codepoints,
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x2015), Some(1))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2017), Some(10))
  @test.assert_eq(extractor.charcode_of_codepoint(0x200C), Some(8))
  @test.assert_eq(extractor.charcode_of_codepoint(0x200B), Some(24))
}

///|
test "PdfTextExtractor decodes Latin-1 spacing AGL aliases" {
  let entries : Array[(String, Int)] = [
    ("/blank", 0x2423),
    ("/equalsuperior", 0x207C),
    ("/middot", 0x00B7),
    ("/mu1", 0x00B5),
    ("/nbspace", 0x00A0),
    ("/nonbreakingspace", 0x00A0),
    ("/overscore", 0x00AF),
    ("/plussuperior", 0x207A),
    ("/sfthyphen", 0x00AD),
    ("/softhyphen", 0x00AD),
  ]
  let differences : Array[@pdflite.PdfEncodingDifference] = []
  let text_codes : Array[Int] = []
  let expected_codepoints : Array[Int] = []
  for index in 0..<entries.length() {
    let entry = entries[index]
    let code = index + 1
    differences.push(text_difference_for_test(entry.0, code))
    text_codes.push(code)
    expected_codepoints.push(entry.1)
  }
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(
      PdfHelvetica,
      PdfCustomEncoding(PdfStandardEncoding, differences),
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(text_bytes_for_test(text_codes)[:]),
    expected_codepoints,
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x2423), Some(1))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00B7), Some(3))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00A0), Some(5))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00AD), Some(9))
}

///|
test "PdfTextExtractor decodes IPA extension AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/Gsmallhook", 0x029B),
    ("/Rsmallinverted", 0x0281),
    ("/ascript", 0x0251),
    ("/ascriptturned", 0x0252),
    ("/aturned", 0x0250),
    ("/bhook", 0x0253),
    ("/bilabialclick", 0x0298),
    ("/ccurl", 0x0255),
    ("/cstretched", 0x0297),
    ("/dezh", 0x02A4),
    ("/dhook", 0x0257),
    ("/dotlessjstrokehook", 0x0284),
    ("/dtail", 0x0256),
    ("/dzaltone", 0x02A3),
    ("/dzcurl", 0x02A5),
    ("/eopen", 0x025B),
    ("/eopenclosed", 0x029A),
    ("/eopenreversed", 0x025C),
    ("/eopenreversedclosed", 0x025E),
    ("/eopenreversedhook", 0x025D),
    ("/ereversed", 0x0258),
    ("/esh", 0x0283),
    ("/eshcurl", 0x0286),
    ("/eshsquatreversed", 0x0285),
    ("/ezh", 0x0292),
    ("/ezhcurl", 0x0293),
    ("/gammalatinsmall", 0x0263),
    ("/ghook", 0x0260),
    ("/glottalstop", 0x0294),
    ("/glottalstopinverted", 0x0296),
    ("/glottalstopreversed", 0x0295),
    ("/glottalstopstroke", 0x02A1),
    ("/glottalstopstrokereversed", 0x02A2),
    ("/gscript", 0x0261),
    ("/henghook", 0x0267),
    ("/hhook", 0x0266),
    ("/hturned", 0x0265),
    ("/iotalatin", 0x0269),
    ("/istroke", 0x0268),
    ("/jcrossedtail", 0x029D),
    ("/jdotlessstroke", 0x025F),
    ("/kturned", 0x029E),
    ("/lbelt", 0x026C),
    ("/lezh", 0x026E),
    ("/lhookretroflex", 0x026D),
    ("/lmiddletilde", 0x026B),
    ("/mhook", 0x0271),
    ("/mlonglegturned", 0x0270),
    ("/mturned", 0x026F),
    ("/nhookleft", 0x0272),
    ("/nhookretroflex", 0x0273),
    ("/obarred", 0x0275),
    ("/omegalatinclosed", 0x0277),
    ("/oopen", 0x0254),
    ("/philatin", 0x0278),
    ("/qhook", 0x02A0),
    ("/ramshorn", 0x0264),
    ("/rfishhook", 0x027E),
    ("/rfishhookreversed", 0x027F),
    ("/rhook", 0x027D),
    ("/rhookturned", 0x027B),
    ("/rlongleg", 0x027C),
    ("/rlonglegturned", 0x027A),
    ("/rturned", 0x0279),
    ("/schwa", 0x0259),
    ("/schwahook", 0x025A),
    ("/shook", 0x0282),
    ("/tccurl", 0x02A8),
    ("/tesh", 0x02A7),
    ("/tretroflexhook", 0x0288),
    ("/ts", 0x02A6),
    ("/tturned", 0x0287),
    ("/ubar", 0x0289),
    ("/upsilonlatin", 0x028A),
    ("/vhook", 0x028B),
    ("/vturned", 0x028C),
    ("/wturned", 0x028D),
    ("/yturned", 0x028E),
    ("/zcurl", 0x0291),
    ("/zretroflexhook", 0x0290),
  ]
  let differences : Array[@pdflite.PdfEncodingDifference] = []
  let text_codes : Array[Int] = []
  let expected_codepoints : Array[Int] = []
  for index in 0..<entries.length() {
    let entry = entries[index]
    let code = index + 1
    differences.push(text_difference_for_test(entry.0, code))
    text_codes.push(code)
    expected_codepoints.push(entry.1)
  }
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(
      PdfHelvetica,
      PdfCustomEncoding(PdfStandardEncoding, differences),
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(text_bytes_for_test(text_codes)[:]),
    expected_codepoints,
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x029B), Some(1))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0251), Some(3))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0294), Some(29))
  @test.assert_eq(extractor.charcode_of_codepoint(0x02A1), Some(32))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0279), Some(64))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0290), Some(80))
}

///|
test "PdfTextExtractor decodes spacing modifier AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/Rsmallinvertedsuperior", 0x02B6),
    ("/acutelowmod", 0x02CF),
    ("/afii57929", 0x02BC),
    ("/afii64937", 0x02BD),
    ("/apostrophemod", 0x02BC),
    ("/arrowheaddownmod", 0x02C5),
    ("/arrowheadleftmod", 0x02C2),
    ("/arrowheadrightmod", 0x02C3),
    ("/arrowheadupmod", 0x02C4),
    ("/colontriangularhalfmod", 0x02D1),
    ("/colontriangularmod", 0x02D0),
    ("/commareversedmod", 0x02BD),
    ("/commaturnedmod", 0x02BB),
    ("/dblprimemod", 0x02BA),
    ("/downtackmod", 0x02D5),
    ("/firsttonechinese", 0x02C9),
    ("/fourthtonechinese", 0x02CB),
    ("/gammasuperior", 0x02E0),
    ("/glottalstopmod", 0x02C0),
    ("/glottalstopreversedmod", 0x02C1),
    ("/glottalstopreversedsuperior", 0x02E4),
    ("/gravelowmod", 0x02CE),
    ("/hhooksuperior", 0x02B1),
    ("/hsuperior", 0x02B0),
    ("/ilde", 0x02DC),
    ("/jsuperior", 0x02B2),
    ("/macronlowmod", 0x02CD),
    ("/minusmod", 0x02D7),
    ("/plusmod", 0x02D6),
    ("/primemod", 0x02B9),
    ("/rhookturnedsuperior", 0x02B5),
    ("/rhotichookmod", 0x02DE),
    ("/ringhalfleft", 0x02BF),
    ("/ringhalfleftcentered", 0x02D3),
    ("/ringhalfright", 0x02BE),
    ("/ringhalfrightcentered", 0x02D2),
    ("/rturnedsuperior", 0x02B4),
    ("/secondtonechinese", 0x02CA),
    ("/tonebarextrahighmod", 0x02E5),
    ("/tonebarextralowmod", 0x02E9),
    ("/tonebarhighmod", 0x02E6),
    ("/tonebarlowmod", 0x02E8),
    ("/tonebarmidmod", 0x02E7),
    ("/uptackmod", 0x02D4),
    ("/verticallinelowmod", 0x02CC),
    ("/verticallinemod", 0x02C8),
    ("/wsuperior", 0x02B7),
    ("/xsuperior", 0x02E3),
    ("/ysuperior", 0x02B8),
  ]
  let differences : Array[@pdflite.PdfEncodingDifference] = []
  let text_codes : Array[Int] = []
  let expected_codepoints : Array[Int] = []
  for index in 0..<entries.length() {
    let entry = entries[index]
    let code = index + 1
    differences.push(text_difference_for_test(entry.0, code))
    text_codes.push(code)
    expected_codepoints.push(entry.1)
  }
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(
      PdfHelvetica,
      PdfCustomEncoding(PdfStandardEncoding, differences),
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(text_bytes_for_test(text_codes)[:]),
    expected_codepoints,
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x02B0), Some(24))
  @test.assert_eq(extractor.charcode_of_codepoint(0x02BC), Some(3))
  @test.assert_eq(extractor.charcode_of_codepoint(0x02BD), Some(4))
  @test.assert_eq(extractor.charcode_of_codepoint(0x02DC), Some(25))
  @test.assert_eq(extractor.charcode_of_codepoint(0x02E9), Some(40))
  @test.assert_eq(extractor.charcode_of_codepoint(0x02B8), Some(49))
}

///|
test "PdfTextExtractor decodes combining mark AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/acutebelowcmb", 0x0317),
    ("/acutecmb", 0x0301),
    ("/acutecomb", 0x0301),
    ("/acutetonecmb", 0x0341),
    ("/brevebelowcmb", 0x032E),
    ("/brevecmb", 0x0306),
    ("/breveinvertedbelowcmb", 0x032F),
    ("/breveinvertedcmb", 0x0311),
    ("/breveinverteddoublecmb", 0x0361),
    ("/bridgebelowcmb", 0x032A),
    ("/bridgeinvertedbelowcmb", 0x033A),
    ("/candrabinducmb", 0x0310),
    ("/caronbelowcmb", 0x032C),
    ("/caroncmb", 0x030C),
    ("/cedillacmb", 0x0327),
    ("/circumflexbelowcmb", 0x032D),
    ("/circumflexcmb", 0x0302),
    ("/commaabovecmb", 0x0313),
    ("/commaaboverightcmb", 0x0315),
    ("/commareversedabovecmb", 0x0314),
    ("/commaturnedabovecmb", 0x0312),
    ("/dblarchinvertedbelowcmb", 0x032B),
    ("/dblgravecmb", 0x030F),
    ("/dbllowlinecmb", 0x0333),
    ("/dbloverlinecmb", 0x033F),
    ("/dblverticallineabovecmb", 0x030E),
    ("/dialytikatonoscmb", 0x0344),
    ("/dieresisbelowcmb", 0x0324),
    ("/dieresiscmb", 0x0308),
    ("/dotaccentcmb", 0x0307),
    ("/dotbelowcmb", 0x0323),
    ("/dotbelowcomb", 0x0323),
    ("/downtackbelowcmb", 0x031E),
    ("/gravebelowcmb", 0x0316),
    ("/gravecmb", 0x0300),
    ("/gravecomb", 0x0300),
    ("/gravetonecmb", 0x0340),
    ("/hookabovecomb", 0x0309),
    ("/hookcmb", 0x0309),
    ("/hookpalatalizedbelowcmb", 0x0321),
    ("/hookretroflexbelowcmb", 0x0322),
    ("/horncmb", 0x031B),
    ("/hungarumlautcmb", 0x030B),
    ("/koroniscmb", 0x0343),
    ("/leftangleabovecmb", 0x031A),
    ("/lefttackbelowcmb", 0x0318),
    ("/lowlinecmb", 0x0332),
    ("/macronbelowcmb", 0x0331),
    ("/macroncmb", 0x0304),
    ("/minusbelowcmb", 0x0320),
    ("/ogonekcmb", 0x0328),
    ("/overlinecmb", 0x0305),
    ("/perispomenigreekcmb", 0x0342),
    ("/plusbelowcmb", 0x031F),
    ("/righttackbelowcmb", 0x0319),
    ("/ringbelowcmb", 0x0325),
    ("/ringcmb", 0x030A),
    ("/ringhalfleftbelowcmb", 0x031C),
    ("/ringhalfrightbelowcmb", 0x0339),
    ("/seagullbelowcmb", 0x033C),
    ("/soliduslongoverlaycmb", 0x0338),
    ("/solidusshortoverlaycmb", 0x0337),
    ("/squarebelowcmb", 0x033B),
    ("/strokelongoverlaycmb", 0x0336),
    ("/strokeshortoverlaycmb", 0x0335),
    ("/tildebelowcmb", 0x0330),
    ("/tildecmb", 0x0303),
    ("/tildecomb", 0x0303),
    ("/tildedoublecmb", 0x0360),
    ("/tildeoverlaycmb", 0x0334),
    ("/tildeverticalcmb", 0x033E),
    ("/uptackbelowcmb", 0x031D),
    ("/verticallineabovecmb", 0x030D),
    ("/verticallinebelowcmb", 0x0329),
    ("/xabovecmb", 0x033D),
    ("/ypogegrammenigreekcmb", 0x0345),
  ]
  let differences : Array[@pdflite.PdfEncodingDifference] = []
  let text_codes : Array[Int] = []
  let expected_codepoints : Array[Int] = []
  for index in 0..<entries.length() {
    let entry = entries[index]
    let code = index + 1
    differences.push(text_difference_for_test(entry.0, code))
    text_codes.push(code)
    expected_codepoints.push(entry.1)
  }
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(
      PdfHelvetica,
      PdfCustomEncoding(PdfStandardEncoding, differences),
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(text_bytes_for_test(text_codes)[:]),
    expected_codepoints,
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x0301), Some(2))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0323), Some(31))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0300), Some(35))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0309), Some(38))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0303), Some(67))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0345), Some(76))
}

///|
test "PdfTextExtractor decodes currency and letterlike AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/afii08941", 0x20A4),
    ("/afii57636", 0x20AA),
    ("/colonsign", 0x20A1),
    ("/cruzeiro", 0x20A2),
    ("/dong", 0x20AB),
    ("/euro", 0x20AC),
    ("/franc", 0x20A3),
    ("/lira", 0x20A4),
    ("/newsheqelsign", 0x20AA),
    ("/peseta", 0x20A7),
    ("/sheqel", 0x20AA),
    ("/sheqelhebrew", 0x20AA),
    ("/won", 0x20A9),
    ("/Ohm", 0x2126),
    ("/afii61248", 0x2105),
    ("/afii61289", 0x2113),
    ("/afii61352", 0x2116),
    ("/angstrom", 0x212B),
    ("/careof", 0x2105),
    ("/centigrade", 0x2103),
    ("/estimated", 0x212E),
    ("/fahrenheit", 0x2109),
    ("/lsquare", 0x2113),
    ("/numero", 0x2116),
    ("/prescription", 0x211E),
    ("/telephone", 0x2121),
  ]
  let differences : Array[@pdflite.PdfEncodingDifference] = []
  let text_codes : Array[Int] = []
  let expected_codepoints : Array[Int] = []
  for index in 0..<entries.length() {
    let entry = entries[index]
    let code = index + 1
    differences.push(text_difference_for_test(entry.0, code))
    text_codes.push(code)
    expected_codepoints.push(entry.1)
  }
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(
      PdfHelvetica,
      PdfCustomEncoding(PdfStandardEncoding, differences),
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(text_bytes_for_test(text_codes)[:]),
    expected_codepoints,
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x20A4), Some(1))
  @test.assert_eq(extractor.charcode_of_codepoint(0x20AA), Some(2))
  @test.assert_eq(extractor.charcode_of_codepoint(0x20AC), Some(6))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2105), Some(15))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2113), Some(16))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2116), Some(17))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2121), Some(26))
}

///|
test "PdfTextExtractor decodes arrow AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/arrowdashdown", 0x21E3),
    ("/arrowdashleft", 0x21E0),
    ("/arrowdashright", 0x21E2),
    ("/arrowdashup", 0x21E1),
    ("/arrowdownleft", 0x2199),
    ("/arrowdownright", 0x2198),
    ("/arrowdownwhite", 0x21E9),
    ("/arrowleftdbl", 0x21D0),
    ("/arrowleftdblstroke", 0x21CD),
    ("/arrowleftoverright", 0x21C6),
    ("/arrowleftwhite", 0x21E6),
    ("/arrowrightdblstroke", 0x21CF),
    ("/arrowrightoverleft", 0x21C4),
    ("/arrowrightwhite", 0x21E8),
    ("/arrowtableft", 0x21E4),
    ("/arrowtabright", 0x21E5),
    ("/arrowupdn", 0x2195),
    ("/arrowupdnbse", 0x21A8),
    ("/arrowupdownbase", 0x21A8),
    ("/arrowupleft", 0x2196),
    ("/arrowupleftofdown", 0x21C5),
    ("/arrowupright", 0x2197),
    ("/arrowupwhite", 0x21E7),
    ("/capslock", 0x21EA),
    ("/dblarrowleft", 0x21D4),
    ("/dblarrowright", 0x21D2),
    ("/harpoonleftbarbup", 0x21BC),
    ("/harpoonrightbarbup", 0x21C0),
    ("/pagedown", 0x21DF),
    ("/pageup", 0x21DE),
  ]
  let differences : Array[@pdflite.PdfEncodingDifference] = []
  let text_codes : Array[Int] = []
  let expected_codepoints : Array[Int] = []
  for index in 0..<entries.length() {
    let entry = entries[index]
    let code = index + 1
    differences.push(text_difference_for_test(entry.0, code))
    text_codes.push(code)
    expected_codepoints.push(entry.1)
  }
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(
      PdfHelvetica,
      PdfCustomEncoding(PdfStandardEncoding, differences),
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(text_bytes_for_test(text_codes)[:]),
    expected_codepoints,
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x21D0), Some(8))
  @test.assert_eq(extractor.charcode_of_codepoint(0x21A8), Some(18))
  @test.assert_eq(extractor.charcode_of_codepoint(0x21D4), Some(25))
  @test.assert_eq(extractor.charcode_of_codepoint(0x21DE), Some(30))
}

///|
test "PdfTextExtractor decodes Greek AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/Alphatonos", 0x0386),
    ("/Deicoptic", 0x03EE),
    ("/Deltagreek", 0x0394),
    ("/Digammagreek", 0x03DC),
    ("/Epsilontonos", 0x0388),
    ("/Etatonos", 0x0389),
    ("/Feicoptic", 0x03E4),
    ("/Gangiacoptic", 0x03EA),
    ("/Horicoptic", 0x03E8),
    ("/Iotadieresis", 0x03AA),
    ("/Iotatonos", 0x038A),
    ("/Kheicoptic", 0x03E6),
    ("/Koppagreek", 0x03DE),
    ("/Omegagreek", 0x03A9),
    ("/Omegatonos", 0x038F),
    ("/Omicrontonos", 0x038C),
    ("/Sampigreek", 0x03E0),
    ("/Sheicoptic", 0x03E2),
    ("/Shimacoptic", 0x03EC),
    ("/Stigmagreek", 0x03DA),
    ("/Upsilonacutehooksymbolgreek", 0x03D3),
    ("/Upsilondieresis", 0x03AB),
    ("/Upsilondieresishooksymbolgreek", 0x03D4),
    ("/Upsilonhooksymbol", 0x03D2),
    ("/Upsilontonos", 0x038E),
    ("/alphatonos", 0x03AC),
    ("/anoteleia", 0x0387),
    ("/betasymbolgreek", 0x03D0),
    ("/deicoptic", 0x03EF),
    ("/dialytikatonos", 0x0385),
    ("/dieresistonos", 0x0385),
    ("/epsilontonos", 0x03AD),
    ("/etatonos", 0x03AE),
    ("/feicoptic", 0x03E5),
    ("/gangiacoptic", 0x03EB),
    ("/horicoptic", 0x03E9),
    ("/iotadieresis", 0x03CA),
    ("/iotadieresistonos", 0x0390),
    ("/iotatonos", 0x03AF),
    ("/kappasymbolgreek", 0x03F0),
    ("/kheicoptic", 0x03E7),
    ("/mugreek", 0x03BC),
    ("/numeralsigngreek", 0x0374),
    ("/numeralsignlowergreek", 0x0375),
    ("/omegatonos", 0x03CE),
    ("/omicrontonos", 0x03CC),
    ("/phisymbolgreek", 0x03D5),
    ("/pisymbolgreek", 0x03D6),
    ("/questiongreek", 0x037E),
    ("/rhosymbolgreek", 0x03F1),
    ("/sheicoptic", 0x03E3),
    ("/shimacoptic", 0x03ED),
    ("/sigmafinal", 0x03C2),
    ("/sigmalunatesymbolgreek", 0x03F2),
    ("/thetasymbolgreek", 0x03D1),
    ("/tonos", 0x0384),
    ("/upsilondieresis", 0x03CB),
    ("/upsilondieresistonos", 0x03B0),
    ("/upsilontonos", 0x03CD),
    ("/yotgreek", 0x03F3),
    ("/ypogegrammeni", 0x037A),
  ]
  let differences : Array[@pdflite.PdfEncodingDifference] = []
  let text_codes : Array[Int] = []
  let expected_codepoints : Array[Int] = []
  for index in 0..<entries.length() {
    let entry = entries[index]
    let code = index + 1
    differences.push(text_difference_for_test(entry.0, code))
    text_codes.push(code)
    expected_codepoints.push(entry.1)
  }
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(
      PdfHelvetica,
      PdfCustomEncoding(PdfStandardEncoding, differences),
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(text_bytes_for_test(text_codes)[:]),
    expected_codepoints,
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x0394), Some(3))
  @test.assert_eq(extractor.charcode_of_codepoint(0x03A9), Some(14))
  @test.assert_eq(extractor.charcode_of_codepoint(0x03D2), Some(24))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0385), Some(30))
  @test.assert_eq(extractor.charcode_of_codepoint(0x03BC), Some(42))
  @test.assert_eq(extractor.charcode_of_codepoint(0x037A), Some(61))
}

///|
test "PdfTextExtractor decodes Armenian AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/Aybarmenian", 0x0531),
    ("/Benarmenian", 0x0532),
    ("/Caarmenian", 0x053E),
    ("/Chaarmenian", 0x0549),
    ("/Cheharmenian", 0x0543),
    ("/Coarmenian", 0x0551),
    ("/Daarmenian", 0x0534),
    ("/Echarmenian", 0x0535),
    ("/Eharmenian", 0x0537),
    ("/Etarmenian", 0x0538),
    ("/Feharmenian", 0x0556),
    ("/Ghadarmenian", 0x0542),
    ("/Gimarmenian", 0x0533),
    ("/Hoarmenian", 0x0540),
    ("/Iniarmenian", 0x053B),
    ("/Jaarmenian", 0x0541),
    ("/Jheharmenian", 0x054B),
    ("/Keharmenian", 0x0554),
    ("/Kenarmenian", 0x053F),
    ("/Liwnarmenian", 0x053C),
    ("/Menarmenian", 0x0544),
    ("/Nowarmenian", 0x0546),
    ("/Oharmenian", 0x0555),
    ("/Peharmenian", 0x054A),
    ("/Piwrarmenian", 0x0553),
    ("/Raarmenian", 0x054C),
    ("/Reharmenian", 0x0550),
    ("/Seharmenian", 0x054D),
    ("/Shaarmenian", 0x0547),
    ("/Tiwnarmenian", 0x054F),
    ("/Toarmenian", 0x0539),
    ("/Vewarmenian", 0x054E),
    ("/Voarmenian", 0x0548),
    ("/Xeharmenian", 0x053D),
    ("/Yiarmenian", 0x0545),
    ("/Yiwnarmenian", 0x0552),
    ("/Zaarmenian", 0x0536),
    ("/Zhearmenian", 0x053A),
    ("/abbreviationmarkarmenian", 0x055F),
    ("/apostrophearmenian", 0x055A),
    ("/aybarmenian", 0x0561),
    ("/benarmenian", 0x0562),
    ("/caarmenian", 0x056E),
    ("/chaarmenian", 0x0579),
    ("/cheharmenian", 0x0573),
    ("/coarmenian", 0x0581),
    ("/commaarmenian", 0x055D),
    ("/daarmenian", 0x0564),
    ("/echarmenian", 0x0565),
    ("/echyiwnarmenian", 0x0587),
    ("/eharmenian", 0x0567),
    ("/emphasismarkarmenian", 0x055B),
    ("/etarmenian", 0x0568),
    ("/exclamarmenian", 0x055C),
    ("/feharmenian", 0x0586),
    ("/ghadarmenian", 0x0572),
    ("/gimarmenian", 0x0563),
    ("/hoarmenian", 0x0570),
    ("/iniarmenian", 0x056B),
    ("/jaarmenian", 0x0571),
    ("/jheharmenian", 0x057B),
    ("/keharmenian", 0x0584),
    ("/kenarmenian", 0x056F),
    ("/liwnarmenian", 0x056C),
    ("/menarmenian", 0x0574),
    ("/nowarmenian", 0x0576),
    ("/oharmenian", 0x0585),
    ("/peharmenian", 0x057A),
    ("/periodarmenian", 0x0589),
    ("/piwrarmenian", 0x0583),
    ("/questionarmenian", 0x055E),
    ("/raarmenian", 0x057C),
    ("/reharmenian", 0x0580),
    ("/ringhalfleftarmenian", 0x0559),
    ("/seharmenian", 0x057D),
    ("/shaarmenian", 0x0577),
    ("/tiwnarmenian", 0x057F),
    ("/toarmenian", 0x0569),
    ("/vewarmenian", 0x057E),
    ("/voarmenian", 0x0578),
    ("/xeharmenian", 0x056D),
    ("/yiarmenian", 0x0575),
    ("/yiwnarmenian", 0x0582),
    ("/zaarmenian", 0x0566),
    ("/zhearmenian", 0x056A),
  ]
  let differences : Array[@pdflite.PdfEncodingDifference] = []
  let text_codes : Array[Int] = []
  let expected_codepoints : Array[Int] = []
  for index in 0..<entries.length() {
    let entry = entries[index]
    let code = index + 1
    differences.push(text_difference_for_test(entry.0, code))
    text_codes.push(code)
    expected_codepoints.push(entry.1)
  }
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(
      PdfHelvetica,
      PdfCustomEncoding(PdfStandardEncoding, differences),
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(text_bytes_for_test(text_codes)[:]),
    expected_codepoints,
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x0531), Some(1))
  @test.assert_eq(extractor.charcode_of_codepoint(0x055A), Some(40))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0587), Some(50))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0589), Some(69))
  @test.assert_eq(extractor.charcode_of_codepoint(0x056A), Some(85))
}

///|
test "PdfTextExtractor decodes Devanagari AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/aadeva", 0x0906),
    ("/aavowelsigndeva", 0x093E),
    ("/abbreviationsigndeva", 0x0970),
    ("/acutedeva", 0x0954),
    ("/adeva", 0x0905),
    ("/aideva", 0x0910),
    ("/aivowelsigndeva", 0x0948),
    ("/anudattadeva", 0x0952),
    ("/anusvaradeva", 0x0902),
    ("/audeva", 0x0914),
    ("/auvowelsigndeva", 0x094C),
    ("/avagrahadeva", 0x093D),
    ("/badeva", 0x092C),
    ("/bhadeva", 0x092D),
    ("/cadeva", 0x091A),
    ("/candrabindudeva", 0x0901),
    ("/chadeva", 0x091B),
    ("/dadeva", 0x0926),
    ("/danda", 0x0964),
    ("/dbldanda", 0x0965),
    ("/ddadeva", 0x0921),
    ("/dddhadeva", 0x095C),
    ("/ddhadeva", 0x0922),
    ("/dhadeva", 0x0927),
    ("/ecandradeva", 0x090D),
    ("/ecandravowelsigndeva", 0x0945),
    ("/edeva", 0x090F),
    ("/eightdeva", 0x096E),
    ("/eshortdeva", 0x090E),
    ("/eshortvowelsigndeva", 0x0946),
    ("/evowelsigndeva", 0x0947),
    ("/fadeva", 0x095E),
    ("/fivedeva", 0x096B),
    ("/fourdeva", 0x096A),
    ("/gadeva", 0x0917),
    ("/ghadeva", 0x0918),
    ("/ghhadeva", 0x095A),
    ("/gravedeva", 0x0953),
    ("/hadeva", 0x0939),
    ("/ideva", 0x0907),
    ("/iideva", 0x0908),
    ("/iivowelsigndeva", 0x0940),
    ("/ivowelsigndeva", 0x093F),
    ("/jadeva", 0x091C),
    ("/jhadeva", 0x091D),
    ("/kadeva", 0x0915),
    ("/khadeva", 0x0916),
    ("/khhadeva", 0x0959),
    ("/ladeva", 0x0932),
    ("/lladeva", 0x0933),
    ("/llladeva", 0x0934),
    ("/llvocalicdeva", 0x0961),
    ("/llvocalicvowelsigndeva", 0x0963),
    ("/lvocalicdeva", 0x090C),
    ("/lvocalicvowelsigndeva", 0x0962),
    ("/madeva", 0x092E),
    ("/nadeva", 0x0928),
    ("/ngadeva", 0x0919),
    ("/ninedeva", 0x096F),
    ("/nnadeva", 0x0923),
    ("/nnnadeva", 0x0929),
    ("/nuktadeva", 0x093C),
    ("/nyadeva", 0x091E),
    ("/ocandradeva", 0x0911),
    ("/ocandravowelsigndeva", 0x0949),
    ("/odeva", 0x0913),
    ("/omdeva", 0x0950),
    ("/onedeva", 0x0967),
    ("/oshortdeva", 0x0912),
    ("/oshortvowelsigndeva", 0x094A),
    ("/ovowelsigndeva", 0x094B),
    ("/padeva", 0x092A),
    ("/phadeva", 0x092B),
    ("/qadeva", 0x0958),
    ("/radeva", 0x0930),
    ("/rhadeva", 0x095D),
    ("/rradeva", 0x0931),
    ("/rrvocalicdeva", 0x0960),
    ("/rrvocalicvowelsigndeva", 0x0944),
    ("/rvocalicdeva", 0x090B),
    ("/rvocalicvowelsigndeva", 0x0943),
    ("/sadeva", 0x0938),
    ("/sevendeva", 0x096D),
    ("/shadeva", 0x0936),
    ("/sixdeva", 0x096C),
    ("/ssadeva", 0x0937),
    ("/tadeva", 0x0924),
    ("/thadeva", 0x0925),
    ("/threedeva", 0x0969),
    ("/ttadeva", 0x091F),
    ("/tthadeva", 0x0920),
    ("/twodeva", 0x0968),
    ("/udattadeva", 0x0951),
    ("/udeva", 0x0909),
    ("/uudeva", 0x090A),
    ("/uuvowelsigndeva", 0x0942),
    ("/uvowelsigndeva", 0x0941),
    ("/vadeva", 0x0935),
    ("/viramadeva", 0x094D),
    ("/visargadeva", 0x0903),
    ("/yadeva", 0x092F),
    ("/yyadeva", 0x095F),
    ("/zadeva", 0x095B),
    ("/zerodeva", 0x0966),
  ]
  let differences : Array[@pdflite.PdfEncodingDifference] = []
  let text_codes : Array[Int] = []
  let expected_codepoints : Array[Int] = []
  for index in 0..<entries.length() {
    let entry = entries[index]
    let code = index + 1
    differences.push(text_difference_for_test(entry.0, code))
    text_codes.push(code)
    expected_codepoints.push(entry.1)
  }
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(
      PdfHelvetica,
      PdfCustomEncoding(PdfStandardEncoding, differences),
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(text_bytes_for_test(text_codes)[:]),
    expected_codepoints,
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x0906), Some(1))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0970), Some(3))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0964), Some(19))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0950), Some(67))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0966), Some(104))
}

///|
test "PdfTextExtractor decodes Thai AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/angkhankhuthai", 0x0E5A),
    ("/bahtthai", 0x0E3F),
    ("/bobaimaithai", 0x0E1A),
    ("/chochangthai", 0x0E0A),
    ("/chochanthai", 0x0E08),
    ("/chochingthai", 0x0E09),
    ("/chochoethai", 0x0E0C),
    ("/dochadathai", 0x0E0E),
    ("/dodekthai", 0x0E14),
    ("/eightthai", 0x0E58),
    ("/fivethai", 0x0E55),
    ("/fofanthai", 0x0E1F),
    ("/fofathai", 0x0E1D),
    ("/fongmanthai", 0x0E4F),
    ("/fourthai", 0x0E54),
    ("/hohipthai", 0x0E2B),
    ("/honokhukthai", 0x0E2E),
    ("/khokhaithai", 0x0E02),
    ("/khokhonthai", 0x0E05),
    ("/khokhuatthai", 0x0E03),
    ("/khokhwaithai", 0x0E04),
    ("/khomutthai", 0x0E5B),
    ("/khorakhangthai", 0x0E06),
    ("/kokaithai", 0x0E01),
    ("/lakkhangyaothai", 0x0E45),
    ("/lochulathai", 0x0E2C),
    ("/lolingthai", 0x0E25),
    ("/luthai", 0x0E26),
    ("/maichattawathai", 0x0E4B),
    ("/maiekthai", 0x0E48),
    ("/maihanakatthai", 0x0E31),
    ("/maitaikhuthai", 0x0E47),
    ("/maithothai", 0x0E49),
    ("/maitrithai", 0x0E4A),
    ("/maiyamokthai", 0x0E46),
    ("/momathai", 0x0E21),
    ("/ngonguthai", 0x0E07),
    ("/nikhahitthai", 0x0E4D),
    ("/ninethai", 0x0E59),
    ("/nonenthai", 0x0E13),
    ("/nonuthai", 0x0E19),
    ("/oangthai", 0x0E2D),
    ("/onethai", 0x0E51),
    ("/paiyannoithai", 0x0E2F),
    ("/phinthuthai", 0x0E3A),
    ("/phophanthai", 0x0E1E),
    ("/phophungthai", 0x0E1C),
    ("/phosamphaothai", 0x0E20),
    ("/poplathai", 0x0E1B),
    ("/roruathai", 0x0E23),
    ("/ruthai", 0x0E24),
    ("/saraaathai", 0x0E32),
    ("/saraaethai", 0x0E41),
    ("/saraaimaimalaithai", 0x0E44),
    ("/saraaimaimuanthai", 0x0E43),
    ("/saraamthai", 0x0E33),
    ("/saraathai", 0x0E30),
    ("/saraethai", 0x0E40),
    ("/saraiithai", 0x0E35),
    ("/saraithai", 0x0E34),
    ("/saraothai", 0x0E42),
    ("/saraueethai", 0x0E37),
    ("/sarauethai", 0x0E36),
    ("/sarauthai", 0x0E38),
    ("/sarauuthai", 0x0E39),
    ("/seventhai", 0x0E57),
    ("/sixthai", 0x0E56),
    ("/sorusithai", 0x0E29),
    ("/sosalathai", 0x0E28),
    ("/sosothai", 0x0E0B),
    ("/sosuathai", 0x0E2A),
    ("/thanthakhatthai", 0x0E4C),
    ("/thonangmonthothai", 0x0E11),
    ("/thophuthaothai", 0x0E12),
    ("/thothahanthai", 0x0E17),
    ("/thothanthai", 0x0E10),
    ("/thothongthai", 0x0E18),
    ("/thothungthai", 0x0E16),
    ("/threethai", 0x0E53),
    ("/topatakthai", 0x0E0F),
    ("/totaothai", 0x0E15),
    ("/twothai", 0x0E52),
    ("/wowaenthai", 0x0E27),
    ("/yamakkanthai", 0x0E4E),
    ("/yoyakthai", 0x0E22),
    ("/yoyingthai", 0x0E0D),
    ("/zerothai", 0x0E50),
  ]
  let differences : Array[@pdflite.PdfEncodingDifference] = []
  let text_codes : Array[Int] = []
  let expected_codepoints : Array[Int] = []
  for index in 0..<entries.length() {
    let entry = entries[index]
    let code = index + 1
    differences.push(text_difference_for_test(entry.0, code))
    text_codes.push(code)
    expected_codepoints.push(entry.1)
  }
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(
      PdfHelvetica,
      PdfCustomEncoding(PdfStandardEncoding, differences),
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(text_bytes_for_test(text_codes)[:]),
    expected_codepoints,
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x0E5A), Some(1))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0E01), Some(24))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0E40), Some(58))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0E50), Some(87))
}

///|
test "PdfTextExtractor decodes math operator AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/allequal", 0x224C),
    ("/approaches", 0x2250),
    ("/approxequalorimage", 0x2252),
    ("/approximatelyequal", 0x2245),
    ("/asteriskmath", 0x2217),
    ("/asymptoticallyequal", 0x2243),
    ("/because", 0x2235),
    ("/bulletoperator", 0x2219),
    ("/circleot", 0x2299),
    ("/contourintegral", 0x222E),
    ("/curlyand", 0x22CF),
    ("/curlyor", 0x22CE),
    ("/dblintegral", 0x222C),
    ("/divides", 0x2223),
    ("/divisionslash", 0x2215),
    ("/ellipsisvertical", 0x22EE),
    ("/forall", 0x2200),
    ("/geometricallyequal", 0x2251),
    ("/greaterequalorless", 0x22DB),
    ("/greaterorequivalent", 0x2273),
    ("/greaterorless", 0x2277),
    ("/greateroverequal", 0x2267),
    ("/imageorapproximatelyequal", 0x2253),
    ("/increment", 0x2206),
    ("/lessequalorgreater", 0x22DA),
    ("/lessorequivalent", 0x2272),
    ("/lessorgreater", 0x2276),
    ("/lessoverequal", 0x2266),
    ("/minus", 0x2212),
    ("/minuscircle", 0x2296),
    ("/minusplus", 0x2213),
    ("/muchgreater", 0x226B),
    ("/muchless", 0x226A),
    ("/nabla", 0x2207),
    ("/notcontains", 0x220C),
    ("/notelementof", 0x2209),
    ("/notgreater", 0x226F),
    ("/notgreaternorequal", 0x2271),
    ("/notgreaternorless", 0x2279),
    ("/notidentical", 0x2262),
    ("/notless", 0x226E),
    ("/notlessnorequal", 0x2270),
    ("/notparallel", 0x2226),
    ("/notprecedes", 0x2280),
    ("/notsucceeds", 0x2281),
    ("/notsuperset", 0x2285),
    ("/orthogonal", 0x221F),
    ("/parallel", 0x2225),
    ("/pluscircle", 0x2295),
    ("/precedes", 0x227A),
    ("/proportion", 0x2237),
    ("/ratio", 0x2236),
    ("/reversedtilde", 0x223D),
    ("/rightangle", 0x221F),
    ("/righttriangle", 0x22BF),
    ("/subset", 0x2282),
    ("/subsetnotequal", 0x228A),
    ("/subsetorequal", 0x2286),
    ("/succeeds", 0x227B),
    ("/superset", 0x2283),
    ("/supersetnotequal", 0x228B),
    ("/supersetorequal", 0x2287),
    ("/tackdown", 0x22A4),
    ("/tackleft", 0x22A3),
    ("/thereexists", 0x2203),
    ("/tildeoperator", 0x223C),
    ("/timescircle", 0x2297),
  ]
  let differences : Array[@pdflite.PdfEncodingDifference] = []
  let text_codes : Array[Int] = []
  let expected_codepoints : Array[Int] = []
  for index in 0..<entries.length() {
    let entry = entries[index]
    let code = index + 1
    differences.push(text_difference_for_test(entry.0, code))
    text_codes.push(code)
    expected_codepoints.push(entry.1)
  }
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(
      PdfHelvetica,
      PdfCustomEncoding(PdfStandardEncoding, differences),
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(text_bytes_for_test(text_codes)[:]),
    expected_codepoints,
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x2206), Some(24))
  @test.assert_eq(extractor.charcode_of_codepoint(0x221F), Some(47))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2282), Some(56))
  @test.assert_eq(extractor.charcode_of_codepoint(0x22A3), Some(64))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2297), Some(67))
}

///|
test "PdfTextExtractor decodes Roman numeral AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/Oneroman", 0x2160),
    ("/Tworoman", 0x2161),
    ("/Threeroman", 0x2162),
    ("/Fourroman", 0x2163),
    ("/Fiveroman", 0x2164),
    ("/Sixroman", 0x2165),
    ("/Sevenroman", 0x2166),
    ("/Eightroman", 0x2167),
    ("/Nineroman", 0x2168),
    ("/Tenroman", 0x2169),
    ("/Elevenroman", 0x216A),
    ("/Twelveroman", 0x216B),
    ("/oneroman", 0x2170),
    ("/tworoman", 0x2171),
    ("/threeroman", 0x2172),
    ("/fourroman", 0x2173),
    ("/fiveroman", 0x2174),
    ("/sixroman", 0x2175),
    ("/sevenroman", 0x2176),
    ("/eightroman", 0x2177),
    ("/nineroman", 0x2178),
    ("/tenroman", 0x2179),
    ("/elevenroman", 0x217A),
    ("/twelveroman", 0x217B),
  ]
  let differences : Array[@pdflite.PdfEncodingDifference] = []
  let text_codes : Array[Int] = []
  let expected_codepoints : Array[Int] = []
  for index in 0..<entries.length() {
    let entry = entries[index]
    let code = index + 1
    differences.push(text_difference_for_test(entry.0, code))
    text_codes.push(code)
    expected_codepoints.push(entry.1)
  }
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(
      PdfHelvetica,
      PdfCustomEncoding(PdfStandardEncoding, differences),
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(text_bytes_for_test(text_codes)[:]),
    expected_codepoints,
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x2160), Some(1))
  @test.assert_eq(extractor.charcode_of_codepoint(0x216B), Some(12))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2170), Some(13))
  @test.assert_eq(extractor.charcode_of_codepoint(0x217B), Some(24))
}

///|
test "PdfTextExtractor decodes technical AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/arc", 0x2312),
    ("/clear", 0x2327),
    ("/control", 0x2303),
    ("/deleteleft", 0x232B),
    ("/deleteright", 0x2326),
    ("/house", 0x2302),
    ("/integralbottom", 0x2321),
    ("/integraltop", 0x2320),
    ("/logicalnotreversed", 0x2310),
    ("/option", 0x2325),
    ("/projective", 0x2305),
    ("/propellor", 0x2318),
    ("/revlogicalnot", 0x2310),
  ]
  let differences : Array[@pdflite.PdfEncodingDifference] = []
  let text_codes : Array[Int] = []
  let expected_codepoints : Array[Int] = []
  for index in 0..<entries.length() {
    let entry = entries[index]
    let code = index + 1
    differences.push(text_difference_for_test(entry.0, code))
    text_codes.push(code)
    expected_codepoints.push(entry.1)
  }
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(
      PdfHelvetica,
      PdfCustomEncoding(PdfStandardEncoding, differences),
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(text_bytes_for_test(text_codes)[:]),
    expected_codepoints,
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x2302), Some(6))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2310), Some(9))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2320), Some(8))
  @test.assert_eq(extractor.charcode_of_codepoint(0x232B), Some(4))
}

///|
test "PdfTextExtractor decodes enclosed alphanumeric AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/Acircle", 0x24B6),
    ("/Bcircle", 0x24B7),
    ("/Ccircle", 0x24B8),
    ("/Dcircle", 0x24B9),
    ("/Ecircle", 0x24BA),
    ("/Fcircle", 0x24BB),
    ("/Gcircle", 0x24BC),
    ("/Hcircle", 0x24BD),
    ("/Icircle", 0x24BE),
    ("/Jcircle", 0x24BF),
    ("/Kcircle", 0x24C0),
    ("/Lcircle", 0x24C1),
    ("/Mcircle", 0x24C2),
    ("/Ncircle", 0x24C3),
    ("/Ocircle", 0x24C4),
    ("/Pcircle", 0x24C5),
    ("/Qcircle", 0x24C6),
    ("/Rcircle", 0x24C7),
    ("/Scircle", 0x24C8),
    ("/Tcircle", 0x24C9),
    ("/Ucircle", 0x24CA),
    ("/Vcircle", 0x24CB),
    ("/Wcircle", 0x24CC),
    ("/Xcircle", 0x24CD),
    ("/Ycircle", 0x24CE),
    ("/Zcircle", 0x24CF),
    ("/acircle", 0x24D0),
    ("/aparen", 0x249C),
    ("/bcircle", 0x24D1),
    ("/bparen", 0x249D),
    ("/ccircle", 0x24D2),
    ("/cparen", 0x249E),
    ("/dcircle", 0x24D3),
    ("/dparen", 0x249F),
    ("/ecircle", 0x24D4),
    ("/eightcircle", 0x2467),
    ("/eighteencircle", 0x2471),
    ("/eighteenparen", 0x2485),
    ("/eighteenperiod", 0x2499),
    ("/eightparen", 0x247B),
    ("/eightperiod", 0x248F),
    ("/elevencircle", 0x246A),
    ("/elevenparen", 0x247E),
    ("/elevenperiod", 0x2492),
    ("/eparen", 0x24A0),
    ("/fcircle", 0x24D5),
    ("/fifteencircle", 0x246E),
    ("/fifteenparen", 0x2482),
    ("/fifteenperiod", 0x2496),
    ("/fivecircle", 0x2464),
    ("/fiveparen", 0x2478),
    ("/fiveperiod", 0x248C),
    ("/fourcircle", 0x2463),
    ("/fourparen", 0x2477),
    ("/fourperiod", 0x248B),
    ("/fourteencircle", 0x246D),
    ("/fourteenparen", 0x2481),
    ("/fourteenperiod", 0x2495),
    ("/fparen", 0x24A1),
    ("/gcircle", 0x24D6),
    ("/gparen", 0x24A2),
    ("/hcircle", 0x24D7),
    ("/hparen", 0x24A3),
    ("/icircle", 0x24D8),
    ("/iparen", 0x24A4),
    ("/jcircle", 0x24D9),
    ("/jparen", 0x24A5),
    ("/kcircle", 0x24DA),
    ("/kparen", 0x24A6),
    ("/lcircle", 0x24DB),
    ("/lparen", 0x24A7),
    ("/mcircle", 0x24DC),
    ("/mparen", 0x24A8),
    ("/ncircle", 0x24DD),
    ("/ninecircle", 0x2468),
    ("/nineparen", 0x247C),
    ("/nineperiod", 0x2490),
    ("/nineteencircle", 0x2472),
    ("/nineteenparen", 0x2486),
    ("/nineteenperiod", 0x249A),
    ("/nparen", 0x24A9),
    ("/ocircle", 0x24DE),
    ("/onecircle", 0x2460),
    ("/oneparen", 0x2474),
    ("/oneperiod", 0x2488),
    ("/oparen", 0x24AA),
    ("/pcircle", 0x24DF),
    ("/pparen", 0x24AB),
    ("/qcircle", 0x24E0),
    ("/qparen", 0x24AC),
    ("/rcircle", 0x24E1),
    ("/rparen", 0x24AD),
    ("/scircle", 0x24E2),
    ("/sevencircle", 0x2466),
    ("/sevenparen", 0x247A),
    ("/sevenperiod", 0x248E),
    ("/seventeencircle", 0x2470),
    ("/seventeenparen", 0x2484),
    ("/seventeenperiod", 0x2498),
    ("/sixcircle", 0x2465),
    ("/sixparen", 0x2479),
    ("/sixperiod", 0x248D),
    ("/sixteencircle", 0x246F),
    ("/sixteenparen", 0x2483),
    ("/sixteenperiod", 0x2497),
    ("/sparen", 0x24AE),
    ("/tcircle", 0x24E3),
    ("/tencircle", 0x2469),
    ("/tenparen", 0x247D),
    ("/tenperiod", 0x2491),
    ("/thirteencircle", 0x246C),
    ("/thirteenparen", 0x2480),
    ("/thirteenperiod", 0x2494),
    ("/threecircle", 0x2462),
    ("/threeparen", 0x2476),
    ("/threeperiod", 0x248A),
    ("/tparen", 0x24AF),
    ("/twelvecircle", 0x246B),
    ("/twelveparen", 0x247F),
    ("/twelveperiod", 0x2493),
    ("/twentycircle", 0x2473),
    ("/twentyparen", 0x2487),
    ("/twentyperiod", 0x249B),
    ("/twocircle", 0x2461),
    ("/twoparen", 0x2475),
    ("/twoperiod", 0x2489),
    ("/ucircle", 0x24E4),
    ("/uparen", 0x24B0),
    ("/vcircle", 0x24E5),
    ("/vparen", 0x24B1),
    ("/wcircle", 0x24E6),
    ("/wparen", 0x24B2),
    ("/xcircle", 0x24E7),
    ("/xparen", 0x24B3),
    ("/ycircle", 0x24E8),
    ("/yparen", 0x24B4),
    ("/zcircle", 0x24E9),
    ("/zparen", 0x24B5),
  ]
  let differences : Array[@pdflite.PdfEncodingDifference] = []
  let text_codes : Array[Int] = []
  let expected_codepoints : Array[Int] = []
  for index in 0..<entries.length() {
    let entry = entries[index]
    let code = index + 1
    differences.push(text_difference_for_test(entry.0, code))
    text_codes.push(code)
    expected_codepoints.push(entry.1)
  }
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(
      PdfHelvetica,
      PdfCustomEncoding(PdfStandardEncoding, differences),
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(text_bytes_for_test(text_codes)[:]),
    expected_codepoints,
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x24B6), Some(1))
  @test.assert_eq(extractor.charcode_of_codepoint(0x24CF), Some(26))
  @test.assert_eq(extractor.charcode_of_codepoint(0x249C), Some(28))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2460), Some(83))
  @test.assert_eq(extractor.charcode_of_codepoint(0x249B), Some(123))
  @test.assert_eq(extractor.charcode_of_codepoint(0x24E9), Some(137))
  @test.assert_eq(extractor.charcode_of_codepoint(0x24B5), Some(138))
}

///|
test "PdfTextExtractor decodes CJK symbol AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/anglebracketleft", 0x3008),
    ("/anglebracketright", 0x3009),
    ("/blacklenticularbracketleft", 0x3010),
    ("/blacklenticularbracketright", 0x3011),
    ("/circlepostalmark", 0x3036),
    ("/cornerbracketleft", 0x300C),
    ("/cornerbracketright", 0x300D),
    ("/dblanglebracketleft", 0x300A),
    ("/dblanglebracketright", 0x300B),
    ("/dittomark", 0x3003),
    ("/eighthangzhou", 0x3028),
    ("/fivehangzhou", 0x3025),
    ("/fourhangzhou", 0x3024),
    ("/getamark", 0x3013),
    ("/ideographicclose", 0x3006),
    ("/ideographiccomma", 0x3001),
    ("/ideographiciterationmark", 0x3005),
    ("/ideographicperiod", 0x3002),
    ("/ideographicspace", 0x3000),
    ("/ideographiczero", 0x3007),
    ("/jis", 0x3004),
    ("/ninehangzhou", 0x3029),
    ("/onehangzhou", 0x3021),
    ("/postalmark", 0x3012),
    ("/postalmarkface", 0x3020),
    ("/quotedblprime", 0x301E),
    ("/quotedblprimereversed", 0x301D),
    ("/sevenhangzhou", 0x3027),
    ("/sixhangzhou", 0x3026),
    ("/threehangzhou", 0x3023),
    ("/tortoiseshellbracketleft", 0x3014),
    ("/tortoiseshellbracketright", 0x3015),
    ("/twentyhangzhou", 0x5344),
    ("/twohangzhou", 0x3022),
    ("/wavedash", 0x301C),
    ("/whitecornerbracketleft", 0x300E),
    ("/whitecornerbracketright", 0x300F),
    ("/whitelenticularbracketleft", 0x3016),
    ("/whitelenticularbracketright", 0x3017),
    ("/whitetortoiseshellbracketleft", 0x3018),
    ("/whitetortoiseshellbracketright", 0x3019),
  ]
  let differences : Array[@pdflite.PdfEncodingDifference] = []
  let text_codes : Array[Int] = []
  let expected_codepoints : Array[Int] = []
  for index in 0..<entries.length() {
    let entry = entries[index]
    let code = index + 1
    differences.push(text_difference_for_test(entry.0, code))
    text_codes.push(code)
    expected_codepoints.push(entry.1)
  }
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(
      PdfHelvetica,
      PdfCustomEncoding(PdfStandardEncoding, differences),
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(text_bytes_for_test(text_codes)[:]),
    expected_codepoints,
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x3008), Some(1))
  @test.assert_eq(extractor.charcode_of_codepoint(0x3000), Some(19))
  @test.assert_eq(extractor.charcode_of_codepoint(0x5344), Some(33))
  @test.assert_eq(extractor.charcode_of_codepoint(0x3019), Some(41))
}

///|
test "PdfTextExtractor decodes Hiragana AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/ahiragana", 0x3042),
    ("/asmallhiragana", 0x3041),
    ("/bahiragana", 0x3070),
    ("/behiragana", 0x3079),
    ("/bihiragana", 0x3073),
    ("/bohiragana", 0x307C),
    ("/buhiragana", 0x3076),
    ("/dahiragana", 0x3060),
    ("/dehiragana", 0x3067),
    ("/dihiragana", 0x3062),
    ("/dohiragana", 0x3069),
    ("/duhiragana", 0x3065),
    ("/ehiragana", 0x3048),
    ("/esmallhiragana", 0x3047),
    ("/gahiragana", 0x304C),
    ("/gehiragana", 0x3052),
    ("/gihiragana", 0x304E),
    ("/gohiragana", 0x3054),
    ("/guhiragana", 0x3050),
    ("/hahiragana", 0x306F),
    ("/hehiragana", 0x3078),
    ("/hihiragana", 0x3072),
    ("/hohiragana", 0x307B),
    ("/huhiragana", 0x3075),
    ("/ihiragana", 0x3044),
    ("/ismallhiragana", 0x3043),
    ("/iterationhiragana", 0x309D),
    ("/kahiragana", 0x304B),
    ("/kehiragana", 0x3051),
    ("/kihiragana", 0x304D),
    ("/kohiragana", 0x3053),
    ("/kuhiragana", 0x304F),
    ("/mahiragana", 0x307E),
    ("/mehiragana", 0x3081),
    ("/mihiragana", 0x307F),
    ("/mohiragana", 0x3082),
    ("/muhiragana", 0x3080),
    ("/nahiragana", 0x306A),
    ("/nehiragana", 0x306D),
    ("/nhiragana", 0x3093),
    ("/nihiragana", 0x306B),
    ("/nohiragana", 0x306E),
    ("/nuhiragana", 0x306C),
    ("/ohiragana", 0x304A),
    ("/osmallhiragana", 0x3049),
    ("/pahiragana", 0x3071),
    ("/pehiragana", 0x307A),
    ("/pihiragana", 0x3074),
    ("/pohiragana", 0x307D),
    ("/puhiragana", 0x3077),
    ("/rahiragana", 0x3089),
    ("/rehiragana", 0x308C),
    ("/rihiragana", 0x308A),
    ("/rohiragana", 0x308D),
    ("/ruhiragana", 0x308B),
    ("/sahiragana", 0x3055),
    ("/sehiragana", 0x305B),
    ("/semivoicedmarkkana", 0x309C),
    ("/sihiragana", 0x3057),
    ("/sohiragana", 0x305D),
    ("/suhiragana", 0x3059),
    ("/tahiragana", 0x305F),
    ("/tehiragana", 0x3066),
    ("/tihiragana", 0x3061),
    ("/tohiragana", 0x3068),
    ("/tuhiragana", 0x3064),
    ("/tusmallhiragana", 0x3063),
    ("/uhiragana", 0x3046),
    ("/usmallhiragana", 0x3045),
    ("/voicediterationhiragana", 0x309E),
    ("/voicedmarkkana", 0x309B),
    ("/vuhiragana", 0x3094),
    ("/wahiragana", 0x308F),
    ("/wasmallhiragana", 0x308E),
    ("/wehiragana", 0x3091),
    ("/wihiragana", 0x3090),
    ("/wohiragana", 0x3092),
    ("/yahiragana", 0x3084),
    ("/yasmallhiragana", 0x3083),
    ("/yohiragana", 0x3088),
    ("/yosmallhiragana", 0x3087),
    ("/yuhiragana", 0x3086),
    ("/yusmallhiragana", 0x3085),
    ("/zahiragana", 0x3056),
    ("/zehiragana", 0x305C),
    ("/zihiragana", 0x3058),
    ("/zohiragana", 0x305E),
    ("/zuhiragana", 0x305A),
  ]
  let differences : Array[@pdflite.PdfEncodingDifference] = []
  let text_codes : Array[Int] = []
  let expected_codepoints : Array[Int] = []
  for index in 0..<entries.length() {
    let entry = entries[index]
    let code = index + 1
    differences.push(text_difference_for_test(entry.0, code))
    text_codes.push(code)
    expected_codepoints.push(entry.1)
  }
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(
      PdfHelvetica,
      PdfCustomEncoding(PdfStandardEncoding, differences),
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(text_bytes_for_test(text_codes)[:]),
    expected_codepoints,
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x3042), Some(1))
  @test.assert_eq(extractor.charcode_of_codepoint(0x309D), Some(27))
  @test.assert_eq(extractor.charcode_of_codepoint(0x309B), Some(71))
  @test.assert_eq(extractor.charcode_of_codepoint(0x305A), Some(88))
}

///|
test "PdfTextExtractor decodes Katakana AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/akatakana", 0x30A2),
    ("/asmallkatakana", 0x30A1),
    ("/bakatakana", 0x30D0),
    ("/bekatakana", 0x30D9),
    ("/bikatakana", 0x30D3),
    ("/bokatakana", 0x30DC),
    ("/bukatakana", 0x30D6),
    ("/dakatakana", 0x30C0),
    ("/dekatakana", 0x30C7),
    ("/dikatakana", 0x30C2),
    ("/dokatakana", 0x30C9),
    ("/dotkatakana", 0x30FB),
    ("/dukatakana", 0x30C5),
    ("/ekatakana", 0x30A8),
    ("/esmallkatakana", 0x30A7),
    ("/gakatakana", 0x30AC),
    ("/gekatakana", 0x30B2),
    ("/gikatakana", 0x30AE),
    ("/gokatakana", 0x30B4),
    ("/gukatakana", 0x30B0),
    ("/hakatakana", 0x30CF),
    ("/hekatakana", 0x30D8),
    ("/hikatakana", 0x30D2),
    ("/hokatakana", 0x30DB),
    ("/hukatakana", 0x30D5),
    ("/ikatakana", 0x30A4),
    ("/ismallkatakana", 0x30A3),
    ("/iterationkatakana", 0x30FD),
    ("/kakatakana", 0x30AB),
    ("/kasmallkatakana", 0x30F5),
    ("/kekatakana", 0x30B1),
    ("/kesmallkatakana", 0x30F6),
    ("/kikatakana", 0x30AD),
    ("/kokatakana", 0x30B3),
    ("/kukatakana", 0x30AF),
    ("/makatakana", 0x30DE),
    ("/mekatakana", 0x30E1),
    ("/mikatakana", 0x30DF),
    ("/mokatakana", 0x30E2),
    ("/mukatakana", 0x30E0),
    ("/nakatakana", 0x30CA),
    ("/nekatakana", 0x30CD),
    ("/nikatakana", 0x30CB),
    ("/nkatakana", 0x30F3),
    ("/nokatakana", 0x30CE),
    ("/nukatakana", 0x30CC),
    ("/okatakana", 0x30AA),
    ("/osmallkatakana", 0x30A9),
    ("/pakatakana", 0x30D1),
    ("/pekatakana", 0x30DA),
    ("/pikatakana", 0x30D4),
    ("/pokatakana", 0x30DD),
    ("/prolongedkana", 0x30FC),
    ("/pukatakana", 0x30D7),
    ("/rakatakana", 0x30E9),
    ("/rekatakana", 0x30EC),
    ("/rikatakana", 0x30EA),
    ("/rokatakana", 0x30ED),
    ("/rukatakana", 0x30EB),
    ("/sakatakana", 0x30B5),
    ("/sekatakana", 0x30BB),
    ("/sikatakana", 0x30B7),
    ("/sokatakana", 0x30BD),
    ("/sukatakana", 0x30B9),
    ("/takatakana", 0x30BF),
    ("/tekatakana", 0x30C6),
    ("/tikatakana", 0x30C1),
    ("/tokatakana", 0x30C8),
    ("/tukatakana", 0x30C4),
    ("/tusmallkatakana", 0x30C3),
    ("/ukatakana", 0x30A6),
    ("/usmallkatakana", 0x30A5),
    ("/vakatakana", 0x30F7),
    ("/vekatakana", 0x30F9),
    ("/vikatakana", 0x30F8),
    ("/voicediterationkatakana", 0x30FE),
    ("/vokatakana", 0x30FA),
    ("/vukatakana", 0x30F4),
    ("/wakatakana", 0x30EF),
    ("/wasmallkatakana", 0x30EE),
    ("/wekatakana", 0x30F1),
    ("/wikatakana", 0x30F0),
    ("/wokatakana", 0x30F2),
    ("/yakatakana", 0x30E4),
    ("/yasmallkatakana", 0x30E3),
    ("/yokatakana", 0x30E8),
    ("/yosmallkatakana", 0x30E7),
    ("/yukatakana", 0x30E6),
    ("/yusmallkatakana", 0x30E5),
    ("/zakatakana", 0x30B6),
    ("/zekatakana", 0x30BC),
    ("/zikatakana", 0x30B8),
    ("/zokatakana", 0x30BE),
    ("/zukatakana", 0x30BA),
  ]
  let differences : Array[@pdflite.PdfEncodingDifference] = []
  let text_codes : Array[Int] = []
  let expected_codepoints : Array[Int] = []
  for index in 0..<entries.length() {
    let entry = entries[index]
    let code = index + 1
    differences.push(text_difference_for_test(entry.0, code))
    text_codes.push(code)
    expected_codepoints.push(entry.1)
  }
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(
      PdfHelvetica,
      PdfCustomEncoding(PdfStandardEncoding, differences),
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(text_bytes_for_test(text_codes)[:]),
    expected_codepoints,
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x30A2), Some(1))
  @test.assert_eq(extractor.charcode_of_codepoint(0x30FB), Some(12))
  @test.assert_eq(extractor.charcode_of_codepoint(0x30FC), Some(53))
  @test.assert_eq(extractor.charcode_of_codepoint(0x30BA), Some(94))
}

///|
test "PdfTextExtractor decodes Bopomofo AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/abopomofo", 0x311A),
    ("/aibopomofo", 0x311E),
    ("/anbopomofo", 0x3122),
    ("/angbopomofo", 0x3124),
    ("/aubopomofo", 0x3120),
    ("/bbopomofo", 0x3105),
    ("/cbopomofo", 0x3118),
    ("/chbopomofo", 0x3114),
    ("/dbopomofo", 0x3109),
    ("/ebopomofo", 0x311C),
    ("/ehbopomofo", 0x311D),
    ("/eibopomofo", 0x311F),
    ("/enbopomofo", 0x3123),
    ("/engbopomofo", 0x3125),
    ("/erbopomofo", 0x3126),
    ("/fbopomofo", 0x3108),
    ("/gbopomofo", 0x310D),
    ("/hbopomofo", 0x310F),
    ("/ibopomofo", 0x3127),
    ("/iubopomofo", 0x3129),
    ("/jbopomofo", 0x3110),
    ("/kbopomofo", 0x310E),
    ("/lbopomofo", 0x310C),
    ("/mbopomofo", 0x3107),
    ("/nbopomofo", 0x310B),
    ("/obopomofo", 0x311B),
    ("/oubopomofo", 0x3121),
    ("/pbopomofo", 0x3106),
    ("/qbopomofo", 0x3111),
    ("/rbopomofo", 0x3116),
    ("/sbopomofo", 0x3119),
    ("/shbopomofo", 0x3115),
    ("/tbopomofo", 0x310A),
    ("/ubopomofo", 0x3128),
    ("/xbopomofo", 0x3112),
    ("/zbopomofo", 0x3117),
    ("/zhbopomofo", 0x3113),
  ]
  let differences : Array[@pdflite.PdfEncodingDifference] = []
  let text_codes : Array[Int] = []
  let expected_codepoints : Array[Int] = []
  for index in 0..<entries.length() {
    let entry = entries[index]
    let code = index + 1
    differences.push(text_difference_for_test(entry.0, code))
    text_codes.push(code)
    expected_codepoints.push(entry.1)
  }
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(
      PdfHelvetica,
      PdfCustomEncoding(PdfStandardEncoding, differences),
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(text_bytes_for_test(text_codes)[:]),
    expected_codepoints,
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x311A), Some(1))
  @test.assert_eq(extractor.charcode_of_codepoint(0x3105), Some(6))
  @test.assert_eq(extractor.charcode_of_codepoint(0x3129), Some(20))
  @test.assert_eq(extractor.charcode_of_codepoint(0x3113), Some(37))
}

///|
test "PdfTextExtractor decodes Hangul compatibility jamo AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/aekorean", 0x3150),
    ("/akorean", 0x314F),
    ("/araeaekorean", 0x318E),
    ("/araeakorean", 0x318D),
    ("/chieuchkorean", 0x314A),
    ("/cieuckorean", 0x3148),
    ("/ekorean", 0x3154),
    ("/eokorean", 0x3153),
    ("/eukorean", 0x3161),
    ("/hangulfiller", 0x3164),
    ("/hieuhkorean", 0x314E),
    ("/ieungkorean", 0x3147),
    ("/ikorean", 0x3163),
    ("/kapyeounmieumkorean", 0x3171),
    ("/kapyeounphieuphkorean", 0x3184),
    ("/kapyeounpieupkorean", 0x3178),
    ("/kapyeounssangpieupkorean", 0x3179),
    ("/khieukhkorean", 0x314B),
    ("/kiyeokkorean", 0x3131),
    ("/kiyeoksioskorean", 0x3133),
    ("/mieumkorean", 0x3141),
    ("/mieumpansioskorean", 0x3170),
    ("/mieumpieupkorean", 0x316E),
    ("/mieumsioskorean", 0x316F),
    ("/nieuncieuckorean", 0x3135),
    ("/nieunhieuhkorean", 0x3136),
    ("/nieunkorean", 0x3134),
    ("/nieunpansioskorean", 0x3168),
    ("/nieunsioskorean", 0x3167),
    ("/nieuntikeutkorean", 0x3166),
    ("/oekorean", 0x315A),
    ("/okorean", 0x3157),
    ("/pansioskorean", 0x317F),
    ("/phieuphkorean", 0x314D),
    ("/pieupcieuckorean", 0x3176),
    ("/pieupkiyeokkorean", 0x3172),
    ("/pieupkorean", 0x3142),
    ("/pieupsioskiyeokkorean", 0x3174),
    ("/pieupsioskorean", 0x3144),
    ("/pieupsiostikeutkorean", 0x3175),
    ("/pieupthieuthkorean", 0x3177),
    ("/pieuptikeutkorean", 0x3173),
    ("/rieulhieuhkorean", 0x3140),
    ("/rieulkiyeokkorean", 0x313A),
    ("/rieulkiyeoksioskorean", 0x3169),
    ("/rieulkorean", 0x3139),
    ("/rieulmieumkorean", 0x313B),
    ("/rieulpansioskorean", 0x316C),
    ("/rieulphieuphkorean", 0x313F),
    ("/rieulpieupkorean", 0x313C),
    ("/rieulpieupsioskorean", 0x316B),
    ("/rieulsioskorean", 0x313D),
    ("/rieulthieuthkorean", 0x313E),
    ("/rieultikeutkorean", 0x316A),
    ("/rieulyeorinhieuhkorean", 0x316D),
    ("/sioscieuckorean", 0x317E),
    ("/sioskiyeokkorean", 0x317A),
    ("/sioskorean", 0x3145),
    ("/siosnieunkorean", 0x317B),
    ("/siospieupkorean", 0x317D),
    ("/siostikeutkorean", 0x317C),
    ("/ssangcieuckorean", 0x3149),
    ("/ssanghieuhkorean", 0x3185),
    ("/ssangieungkorean", 0x3180),
    ("/ssangkiyeokkorean", 0x3132),
    ("/ssangnieunkorean", 0x3165),
    ("/ssangpieupkorean", 0x3143),
    ("/ssangsioskorean", 0x3146),
    ("/ssangtikeutkorean", 0x3138),
    ("/thieuthkorean", 0x314C),
    ("/tikeutkorean", 0x3137),
    ("/ukorean", 0x315C),
    ("/waekorean", 0x3159),
    ("/wakorean", 0x3158),
    ("/wekorean", 0x315E),
    ("/weokorean", 0x315D),
    ("/wikorean", 0x315F),
    ("/yaekorean", 0x3152),
    ("/yakorean", 0x3151),
    ("/yekorean", 0x3156),
    ("/yeokorean", 0x3155),
    ("/yeorinhieuhkorean", 0x3186),
    ("/yesieungkorean", 0x3181),
    ("/yesieungpansioskorean", 0x3183),
    ("/yesieungsioskorean", 0x3182),
    ("/yikorean", 0x3162),
    ("/yoikorean", 0x3189),
    ("/yokorean", 0x315B),
    ("/yoyaekorean", 0x3188),
    ("/yoyakorean", 0x3187),
    ("/yuikorean", 0x318C),
    ("/yukorean", 0x3160),
    ("/yuyekorean", 0x318B),
    ("/yuyeokorean", 0x318A),
  ]
  let differences : Array[@pdflite.PdfEncodingDifference] = []
  let text_codes : Array[Int] = []
  let expected_codepoints : Array[Int] = []
  for index in 0..<entries.length() {
    let entry = entries[index]
    let code = index + 1
    differences.push(text_difference_for_test(entry.0, code))
    text_codes.push(code)
    expected_codepoints.push(entry.1)
  }
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(
      PdfHelvetica,
      PdfCustomEncoding(PdfStandardEncoding, differences),
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(text_bytes_for_test(text_codes)[:]),
    expected_codepoints,
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x3150), Some(1))
  @test.assert_eq(extractor.charcode_of_codepoint(0x3164), Some(10))
  @test.assert_eq(extractor.charcode_of_codepoint(0x3131), Some(19))
  @test.assert_eq(extractor.charcode_of_codepoint(0x318A), Some(94))
}

///|
test "PdfTextExtractor decodes Enclosed CJK AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/chieuchacirclekorean", 0x3277),
    ("/chieuchaparenkorean", 0x3217),
    ("/chieuchcirclekorean", 0x3269),
    ("/chieuchparenkorean", 0x3209),
    ("/cieucacirclekorean", 0x3276),
    ("/cieucaparenkorean", 0x3216),
    ("/cieuccirclekorean", 0x3268),
    ("/cieucparenkorean", 0x3208),
    ("/cieucuparenkorean", 0x321C),
    ("/eightideographicparen", 0x3227),
    ("/fiveideographicparen", 0x3224),
    ("/fourideographicparen", 0x3223),
    ("/hieuhacirclekorean", 0x327B),
    ("/hieuhaparenkorean", 0x321B),
    ("/hieuhcirclekorean", 0x326D),
    ("/hieuhparenkorean", 0x320D),
    ("/ideographearthcircle", 0x328F),
    ("/ideographfirecircle", 0x328B),
    ("/ideographicallianceparen", 0x323F),
    ("/ideographiccallparen", 0x323A),
    ("/ideographiccentrecircle", 0x32A5),
    ("/ideographiccongratulationparen", 0x3237),
    ("/ideographiccorrectcircle", 0x32A3),
    ("/ideographicearthparen", 0x322F),
    ("/ideographicenterpriseparen", 0x323D),
    ("/ideographicexcellentcircle", 0x329D),
    ("/ideographicfestivalparen", 0x3240),
    ("/ideographicfinancialcircle", 0x3296),
    ("/ideographicfinancialparen", 0x3236),
    ("/ideographicfireparen", 0x322B),
    ("/ideographichaveparen", 0x3232),
    ("/ideographichighcircle", 0x32A4),
    ("/ideographiclaborcircle", 0x3298),
    ("/ideographiclaborparen", 0x3238),
    ("/ideographicleftcircle", 0x32A7),
    ("/ideographiclowcircle", 0x32A6),
    ("/ideographicmedicinecircle", 0x32A9),
    ("/ideographicmetalparen", 0x322E),
    ("/ideographicmoonparen", 0x322A),
    ("/ideographicnameparen", 0x3234),
    ("/ideographicprintcircle", 0x329E),
    ("/ideographicreachparen", 0x3243),
    ("/ideographicrepresentparen", 0x3239),
    ("/ideographicresourceparen", 0x323E),
    ("/ideographicrightcircle", 0x32A8),
    ("/ideographicsecretcircle", 0x3299),
    ("/ideographicselfparen", 0x3242),
    ("/ideographicsocietyparen", 0x3233),
    ("/ideographicspecialparen", 0x3235),
    ("/ideographicstockparen", 0x3231),
    ("/ideographicstudyparen", 0x323B),
    ("/ideographicsunparen", 0x3230),
    ("/ideographicsuperviseparen", 0x323C),
    ("/ideographicwaterparen", 0x322C),
    ("/ideographicwoodparen", 0x322D),
    ("/ideographmetalcircle", 0x328E),
    ("/ideographmooncircle", 0x328A),
    ("/ideographnamecircle", 0x3294),
    ("/ideographsuncircle", 0x3290),
    ("/ideographwatercircle", 0x328C),
    ("/ideographwoodcircle", 0x328D),
    ("/ieungacirclekorean", 0x3275),
    ("/ieungaparenkorean", 0x3215),
    ("/ieungcirclekorean", 0x3267),
    ("/ieungparenkorean", 0x3207),
    ("/khieukhacirclekorean", 0x3278),
    ("/khieukhaparenkorean", 0x3218),
    ("/khieukhcirclekorean", 0x326A),
    ("/khieukhparenkorean", 0x320A),
    ("/kiyeokacirclekorean", 0x326E),
    ("/kiyeokaparenkorean", 0x320E),
    ("/kiyeokcirclekorean", 0x3260),
    ("/kiyeokparenkorean", 0x3200),
    ("/koreanstandardsymbol", 0x327F),
    ("/mieumacirclekorean", 0x3272),
    ("/mieumaparenkorean", 0x3212),
    ("/mieumcirclekorean", 0x3264),
    ("/mieumparenkorean", 0x3204),
    ("/nieunacirclekorean", 0x326F),
    ("/nieunaparenkorean", 0x320F),
    ("/nieuncirclekorean", 0x3261),
    ("/nieunparenkorean", 0x3201),
    ("/nineideographicparen", 0x3228),
    ("/oneideographicparen", 0x3220),
    ("/phieuphacirclekorean", 0x327A),
    ("/phieuphaparenkorean", 0x321A),
    ("/phieuphcirclekorean", 0x326C),
    ("/phieuphparenkorean", 0x320C),
    ("/pieupacirclekorean", 0x3273),
    ("/pieupaparenkorean", 0x3213),
    ("/pieupcirclekorean", 0x3265),
    ("/pieupparenkorean", 0x3205),
    ("/rieulacirclekorean", 0x3271),
    ("/rieulaparenkorean", 0x3211),
    ("/rieulcirclekorean", 0x3263),
    ("/rieulparenkorean", 0x3203),
    ("/sevenideographicparen", 0x3226),
    ("/siosacirclekorean", 0x3274),
    ("/siosaparenkorean", 0x3214),
    ("/sioscirclekorean", 0x3266),
    ("/siosparenkorean", 0x3206),
    ("/sixideographicparen", 0x3225),
    ("/tenideographicparen", 0x3229),
    ("/thieuthacirclekorean", 0x3279),
    ("/thieuthaparenkorean", 0x3219),
    ("/thieuthcirclekorean", 0x326B),
    ("/thieuthparenkorean", 0x320B),
    ("/threeideographicparen", 0x3222),
    ("/tikeutacirclekorean", 0x3270),
    ("/tikeutaparenkorean", 0x3210),
    ("/tikeutcirclekorean", 0x3262),
    ("/tikeutparenkorean", 0x3202),
    ("/twoideographicparen", 0x3221),
  ]
  let differences : Array[@pdflite.PdfEncodingDifference] = []
  let text_codes : Array[Int] = []
  let expected_codepoints : Array[Int] = []
  for index in 0..<entries.length() {
    let entry = entries[index]
    let code = index + 1
    differences.push(text_difference_for_test(entry.0, code))
    text_codes.push(code)
    expected_codepoints.push(entry.1)
  }
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(
      PdfHelvetica,
      PdfCustomEncoding(PdfStandardEncoding, differences),
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(text_bytes_for_test(text_codes)[:]),
    expected_codepoints,
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x3277), Some(1))
  @test.assert_eq(extractor.charcode_of_codepoint(0x328F), Some(17))
  @test.assert_eq(extractor.charcode_of_codepoint(0x327F), Some(74))
  @test.assert_eq(extractor.charcode_of_codepoint(0x3221), Some(113))
}

///|
test "PdfTextExtractor decodes box drawing AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/SF010000", 0x250C),
    ("/SF020000", 0x2514),
    ("/SF030000", 0x2510),
    ("/SF040000", 0x2518),
    ("/SF050000", 0x253C),
    ("/SF060000", 0x252C),
    ("/SF070000", 0x2534),
    ("/SF080000", 0x251C),
    ("/SF090000", 0x2524),
    ("/SF100000", 0x2500),
    ("/SF110000", 0x2502),
    ("/SF190000", 0x2561),
    ("/SF200000", 0x2562),
    ("/SF210000", 0x2556),
    ("/SF220000", 0x2555),
    ("/SF230000", 0x2563),
    ("/SF240000", 0x2551),
    ("/SF250000", 0x2557),
    ("/SF260000", 0x255D),
    ("/SF270000", 0x255C),
    ("/SF280000", 0x255B),
    ("/SF360000", 0x255E),
    ("/SF370000", 0x255F),
    ("/SF380000", 0x255A),
    ("/SF390000", 0x2554),
    ("/SF400000", 0x2569),
    ("/SF410000", 0x2566),
    ("/SF420000", 0x2560),
    ("/SF430000", 0x2550),
    ("/SF440000", 0x256C),
    ("/SF450000", 0x2567),
    ("/SF460000", 0x2568),
    ("/SF470000", 0x2564),
    ("/SF480000", 0x2565),
    ("/SF490000", 0x2559),
    ("/SF500000", 0x2558),
    ("/SF510000", 0x2552),
    ("/SF520000", 0x2553),
    ("/SF530000", 0x256B),
    ("/SF540000", 0x256A),
  ]
  let differences : Array[@pdflite.PdfEncodingDifference] = []
  let text_codes : Array[Int] = []
  let expected_codepoints : Array[Int] = []
  for index in 0..<entries.length() {
    let entry = entries[index]
    let code = index + 1
    differences.push(text_difference_for_test(entry.0, code))
    text_codes.push(code)
    expected_codepoints.push(entry.1)
  }
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(
      PdfHelvetica,
      PdfCustomEncoding(PdfStandardEncoding, differences),
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(text_bytes_for_test(text_codes)[:]),
    expected_codepoints,
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x250C), Some(1))
  @test.assert_eq(extractor.charcode_of_codepoint(0x253C), Some(5))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2500), Some(10))
  @test.assert_eq(extractor.charcode_of_codepoint(0x256C), Some(30))
  @test.assert_eq(extractor.charcode_of_codepoint(0x256A), Some(40))
}

///|
test "PdfTextExtractor decodes block element AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/block", 0x2588),
    ("/dkshade", 0x2593),
    ("/dnblock", 0x2584),
    ("/lfblock", 0x258C),
    ("/ltshade", 0x2591),
    ("/rtblock", 0x2590),
    ("/shade", 0x2592),
    ("/shadedark", 0x2593),
    ("/shadelight", 0x2591),
    ("/shademedium", 0x2592),
    ("/upblock", 0x2580),
  ]
  let differences : Array[@pdflite.PdfEncodingDifference] = []
  let text_codes : Array[Int] = []
  let expected_codepoints : Array[Int] = []
  for index in 0..<entries.length() {
    let entry = entries[index]
    let code = index + 1
    differences.push(text_difference_for_test(entry.0, code))
    text_codes.push(code)
    expected_codepoints.push(entry.1)
  }
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(
      PdfHelvetica,
      PdfCustomEncoding(PdfStandardEncoding, differences),
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(text_bytes_for_test(text_codes)[:]),
    expected_codepoints,
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x2593), Some(2))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2591), Some(5))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2592), Some(7))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2580), Some(11))
}

///|
test "PdfTextExtractor decodes geometric shape AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/H18533", 0x25CF),
    ("/H18543", 0x25AA),
    ("/H18551", 0x25AB),
    ("/H22073", 0x25A1),
    ("/blackcircle", 0x25CF),
    ("/blackdiamond", 0x25C6),
    ("/blackdownpointingtriangle", 0x25BC),
    ("/blackleftpointingpointer", 0x25C4),
    ("/blackleftpointingtriangle", 0x25C0),
    ("/blacklowerlefttriangle", 0x25E3),
    ("/blacklowerrighttriangle", 0x25E2),
    ("/blackrectangle", 0x25AC),
    ("/blackrightpointingpointer", 0x25BA),
    ("/blackrightpointingtriangle", 0x25B6),
    ("/blacksmallsquare", 0x25AA),
    ("/blacksquare", 0x25A0),
    ("/blackupperlefttriangle", 0x25E4),
    ("/blackupperrighttriangle", 0x25E5),
    ("/blackuppointingsmalltriangle", 0x25B4),
    ("/blackuppointingtriangle", 0x25B2),
    ("/bulletinverse", 0x25D8),
    ("/bullseye", 0x25CE),
    ("/circle", 0x25CB),
    ("/circlewithlefthalfblack", 0x25D0),
    ("/circlewithrighthalfblack", 0x25D1),
    ("/dottedcircle", 0x25CC),
    ("/filledbox", 0x25A0),
    ("/filledrect", 0x25AC),
    ("/fisheye", 0x25C9),
    ("/invbullet", 0x25D8),
    ("/invcircle", 0x25D9),
    ("/largecircle", 0x25EF),
    ("/openbullet", 0x25E6),
    ("/squarediagonalcrosshatchfill", 0x25A9),
    ("/squarehorizontalfill", 0x25A4),
    ("/squareorthogonalcrosshatchfill", 0x25A6),
    ("/squareupperlefttolowerrightfill", 0x25A7),
    ("/squareupperrighttolowerleftfill", 0x25A8),
    ("/squareverticalfill", 0x25A5),
    ("/squarewhitewithsmallblack", 0x25A3),
    ("/triagdn", 0x25BC),
    ("/triaglf", 0x25C4),
    ("/triagrt", 0x25BA),
    ("/triagup", 0x25B2),
    ("/whitebullet", 0x25E6),
    ("/whitecircle", 0x25CB),
    ("/whitecircleinverse", 0x25D9),
    ("/whitediamond", 0x25C7),
    ("/whitediamondcontainingblacksmalldiamond", 0x25C8),
    ("/whitedownpointingsmalltriangle", 0x25BF),
    ("/whitedownpointingtriangle", 0x25BD),
    ("/whiteleftpointingsmalltriangle", 0x25C3),
    ("/whiteleftpointingtriangle", 0x25C1),
    ("/whiterightpointingsmalltriangle", 0x25B9),
    ("/whiterightpointingtriangle", 0x25B7),
    ("/whitesmallsquare", 0x25AB),
    ("/whitesquare", 0x25A1),
    ("/whiteuppointingsmalltriangle", 0x25B5),
    ("/whiteuppointingtriangle", 0x25B3),
  ]
  let differences : Array[@pdflite.PdfEncodingDifference] = []
  let text_codes : Array[Int] = []
  let expected_codepoints : Array[Int] = []
  for index in 0..<entries.length() {
    let entry = entries[index]
    let code = index + 1
    differences.push(text_difference_for_test(entry.0, code))
    text_codes.push(code)
    expected_codepoints.push(entry.1)
  }
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(
      PdfHelvetica,
      PdfCustomEncoding(PdfStandardEncoding, differences),
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(text_bytes_for_test(text_codes)[:]),
    expected_codepoints,
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x25CF), Some(1))
  @test.assert_eq(extractor.charcode_of_codepoint(0x25AA), Some(2))
  @test.assert_eq(extractor.charcode_of_codepoint(0x25AB), Some(3))
  @test.assert_eq(extractor.charcode_of_codepoint(0x25A1), Some(4))
  @test.assert_eq(extractor.charcode_of_codepoint(0x25BC), Some(7))
  @test.assert_eq(extractor.charcode_of_codepoint(0x25E6), Some(33))
  @test.assert_eq(extractor.charcode_of_codepoint(0x25B3), Some(59))
}

///|
test "PdfTextExtractor decodes dingbat AGL alias glyph names" {
  let entries : Array[(String, Int)] = [
    ("/arrowrightheavy", 0x279E),
    ("/checkmark", 0x2713),
    ("/onecircleinversesansserif", 0x278A),
    ("/twocircleinversesansserif", 0x278B),
    ("/threecircleinversesansserif", 0x278C),
    ("/fourcircleinversesansserif", 0x278D),
    ("/fivecircleinversesansserif", 0x278E),
    ("/sixcircleinversesansserif", 0x278F),
    ("/sevencircleinversesansserif", 0x2790),
    ("/eightcircleinversesansserif", 0x2791),
    ("/ninecircleinversesansserif", 0x2792),
  ]
  let differences : Array[@pdflite.PdfEncodingDifference] = []
  let text_codes : Array[Int] = []
  let expected_codepoints : Array[Int] = []
  for index in 0..<entries.length() {
    let entry = entries[index]
    let code = index + 1
    differences.push(text_difference_for_test(entry.0, code))
    text_codes.push(code)
    expected_codepoints.push(entry.1)
  }
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(
      PdfHelvetica,
      PdfCustomEncoding(PdfStandardEncoding, differences),
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(text_bytes_for_test(text_codes)[:]),
    expected_codepoints,
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x279E), Some(1))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2713), Some(2))
  @test.assert_eq(extractor.charcode_of_codepoint(0x278A), Some(3))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2792), Some(11))
}

///|
test "PdfTextExtractor decodes miscellaneous symbol AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/beamedsixteenthnotes", 0x266C),
    ("/blacksmilingface", 0x263B),
    ("/blackstar", 0x2605),
    ("/clubsuitblack", 0x2663),
    ("/clubsuitwhite", 0x2667),
    ("/compass", 0x263C),
    ("/diamondsuitwhite", 0x2662),
    ("/earth", 0x2641),
    ("/eighthnotebeamed", 0x266B),
    ("/female", 0x2640),
    ("/heartsuitblack", 0x2665),
    ("/heartsuitwhite", 0x2661),
    ("/hotsprings", 0x2668),
    ("/invsmileface", 0x263B),
    ("/male", 0x2642),
    ("/mars", 0x2642),
    ("/musicalnote", 0x266A),
    ("/musicalnotedbl", 0x266B),
    ("/musicflatsign", 0x266D),
    ("/musicsharpsign", 0x266F),
    ("/pointingindexdownwhite", 0x261F),
    ("/pointingindexleftwhite", 0x261C),
    ("/pointingindexrightwhite", 0x261E),
    ("/pointingindexupwhite", 0x261D),
    ("/quarternote", 0x2669),
    ("/smileface", 0x263A),
    ("/spadesuitblack", 0x2660),
    ("/spadesuitwhite", 0x2664),
    ("/sun", 0x263C),
    ("/telephoneblack", 0x260E),
    ("/venus", 0x2640),
    ("/whitesmilingface", 0x263A),
    ("/whitestar", 0x2606),
    ("/whitetelephone", 0x260F),
    ("/yinyang", 0x262F),
  ]
  let differences : Array[@pdflite.PdfEncodingDifference] = []
  let text_codes : Array[Int] = []
  let expected_codepoints : Array[Int] = []
  for index in 0..<entries.length() {
    let entry = entries[index]
    let code = index + 1
    differences.push(text_difference_for_test(entry.0, code))
    text_codes.push(code)
    expected_codepoints.push(entry.1)
  }
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(
      PdfHelvetica,
      PdfCustomEncoding(PdfStandardEncoding, differences),
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(text_bytes_for_test(text_codes)[:]),
    expected_codepoints,
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x263B), Some(2))
  @test.assert_eq(extractor.charcode_of_codepoint(0x263C), Some(6))
  @test.assert_eq(extractor.charcode_of_codepoint(0x266B), Some(9))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2640), Some(10))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2642), Some(15))
  @test.assert_eq(extractor.charcode_of_codepoint(0x262F), Some(35))
}

///|
test "PdfTextExtractor decodes Latin Extended-A AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/Abreve", 0x0102),
    ("/Amacron", 0x0100),
    ("/Aogonek", 0x0104),
    ("/Cacute", 0x0106),
    ("/Ccaron", 0x010C),
    ("/Ccircumflex", 0x0108),
    ("/Cdot", 0x010A),
    ("/Cdotaccent", 0x010A),
    ("/Dcaron", 0x010E),
    ("/Dcroat", 0x0110),
    ("/Dslash", 0x0110),
    ("/Ebreve", 0x0114),
    ("/Ecaron", 0x011A),
    ("/Edot", 0x0116),
    ("/Edotaccent", 0x0116),
    ("/Emacron", 0x0112),
    ("/Eng", 0x014A),
    ("/Eogonek", 0x0118),
    ("/Gbreve", 0x011E),
    ("/Gcedilla", 0x0122),
    ("/Gcircumflex", 0x011C),
    ("/Gcommaaccent", 0x0122),
    ("/Gdot", 0x0120),
    ("/Gdotaccent", 0x0120),
    ("/Hbar", 0x0126),
    ("/Hcircumflex", 0x0124),
    ("/IJ", 0x0132),
    ("/Ibreve", 0x012C),
    ("/Idot", 0x0130),
    ("/Idotaccent", 0x0130),
    ("/Imacron", 0x012A),
    ("/Iogonek", 0x012E),
    ("/Itilde", 0x0128),
    ("/Jcircumflex", 0x0134),
    ("/Kcedilla", 0x0136),
    ("/Kcommaaccent", 0x0136),
    ("/Lacute", 0x0139),
    ("/Lcaron", 0x013D),
    ("/Lcedilla", 0x013B),
    ("/Lcommaaccent", 0x013B),
    ("/Ldot", 0x013F),
    ("/Ldotaccent", 0x013F),
    ("/Lslash", 0x0141),
    ("/Nacute", 0x0143),
    ("/Ncaron", 0x0147),
    ("/Ncedilla", 0x0145),
    ("/Ncommaaccent", 0x0145),
    ("/OE", 0x0152),
    ("/Obreve", 0x014E),
    ("/Odblacute", 0x0150),
    ("/Ohungarumlaut", 0x0150),
    ("/Omacron", 0x014C),
    ("/Racute", 0x0154),
    ("/Rcaron", 0x0158),
    ("/Rcedilla", 0x0156),
    ("/Rcommaaccent", 0x0156),
    ("/Sacute", 0x015A),
    ("/Scaron", 0x0160),
    ("/Scedilla", 0x015E),
    ("/Scircumflex", 0x015C),
    ("/Tbar", 0x0166),
    ("/Tcaron", 0x0164),
    ("/Tcedilla", 0x0162),
    ("/Tcommaaccent", 0x0162),
    ("/Ubreve", 0x016C),
    ("/Udblacute", 0x0170),
    ("/Uhungarumlaut", 0x0170),
    ("/Umacron", 0x016A),
    ("/Uogonek", 0x0172),
    ("/Uring", 0x016E),
    ("/Utilde", 0x0168),
    ("/Wcircumflex", 0x0174),
    ("/Ycircumflex", 0x0176),
    ("/Ydieresis", 0x0178),
    ("/Zacute", 0x0179),
    ("/Zcaron", 0x017D),
    ("/Zdot", 0x017B),
    ("/Zdotaccent", 0x017B),
    ("/abreve", 0x0103),
    ("/amacron", 0x0101),
    ("/aogonek", 0x0105),
    ("/cacute", 0x0107),
    ("/ccaron", 0x010D),
    ("/ccircumflex", 0x0109),
    ("/cdot", 0x010B),
    ("/cdotaccent", 0x010B),
    ("/dcaron", 0x010F),
    ("/dcroat", 0x0111),
    ("/dmacron", 0x0111),
    ("/dotlessi", 0x0131),
    ("/ebreve", 0x0115),
    ("/ecaron", 0x011B),
    ("/edot", 0x0117),
    ("/edotaccent", 0x0117),
    ("/emacron", 0x0113),
    ("/eng", 0x014B),
    ("/eogonek", 0x0119),
    ("/gbreve", 0x011F),
    ("/gcedilla", 0x0123),
    ("/gcircumflex", 0x011D),
    ("/gcommaaccent", 0x0123),
    ("/gdot", 0x0121),
    ("/gdotaccent", 0x0121),
    ("/hbar", 0x0127),
    ("/hcircumflex", 0x0125),
    ("/ibreve", 0x012D),
    ("/ij", 0x0133),
    ("/imacron", 0x012B),
    ("/iogonek", 0x012F),
    ("/itilde", 0x0129),
    ("/jcircumflex", 0x0135),
    ("/kcedilla", 0x0137),
    ("/kcommaaccent", 0x0137),
    ("/kgreenlandic", 0x0138),
    ("/lacute", 0x013A),
    ("/lcaron", 0x013E),
    ("/lcedilla", 0x013C),
    ("/lcommaaccent", 0x013C),
    ("/ldot", 0x0140),
    ("/ldotaccent", 0x0140),
    ("/longs", 0x017F),
    ("/lslash", 0x0142),
    ("/nacute", 0x0144),
    ("/napostrophe", 0x0149),
    ("/ncaron", 0x0148),
    ("/ncedilla", 0x0146),
    ("/ncommaaccent", 0x0146),
    ("/obreve", 0x014F),
    ("/odblacute", 0x0151),
    ("/oe", 0x0153),
    ("/ohungarumlaut", 0x0151),
    ("/omacron", 0x014D),
    ("/quoterightn", 0x0149),
    ("/racute", 0x0155),
    ("/rcaron", 0x0159),
    ("/rcedilla", 0x0157),
    ("/rcommaaccent", 0x0157),
    ("/sacute", 0x015B),
    ("/scaron", 0x0161),
    ("/scedilla", 0x015F),
    ("/scircumflex", 0x015D),
    ("/slong", 0x017F),
    ("/tbar", 0x0167),
    ("/tcaron", 0x0165),
    ("/tcedilla", 0x0163),
    ("/tcommaaccent", 0x0163),
    ("/ubreve", 0x016D),
    ("/udblacute", 0x0171),
    ("/uhungarumlaut", 0x0171),
    ("/umacron", 0x016B),
    ("/uogonek", 0x0173),
    ("/uring", 0x016F),
    ("/utilde", 0x0169),
    ("/wcircumflex", 0x0175),
    ("/ycircumflex", 0x0177),
    ("/zacute", 0x017A),
    ("/zcaron", 0x017E),
    ("/zdot", 0x017C),
    ("/zdotaccent", 0x017C),
  ]
  let differences : Array[@pdflite.PdfEncodingDifference] = []
  let text_codes : Array[Int] = []
  let expected_codepoints : Array[Int] = []
  for index in 0..<entries.length() {
    let entry = entries[index]
    let code = index + 1
    differences.push(text_difference_for_test(entry.0, code))
    text_codes.push(code)
    expected_codepoints.push(entry.1)
  }
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(
      PdfHelvetica,
      PdfCustomEncoding(PdfStandardEncoding, differences),
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(text_bytes_for_test(text_codes)[:]),
    expected_codepoints,
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x0102), Some(1))
  @test.assert_eq(extractor.charcode_of_codepoint(0x010A), Some(7))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0122), Some(20))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0149), Some(124))
  @test.assert_eq(extractor.charcode_of_codepoint(0x017F), Some(121))
}

///|
test "PdfTextExtractor decodes Latin Extended-B AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/AEacute", 0x01FC),
    ("/AEmacron", 0x01E2),
    ("/Acaron", 0x01CD),
    ("/Adblgrave", 0x0200),
    ("/Adieresismacron", 0x01DE),
    ("/Adotmacron", 0x01E0),
    ("/Ainvertedbreve", 0x0202),
    ("/Aringacute", 0x01FA),
    ("/Bhook", 0x0181),
    ("/Btopbar", 0x0182),
    ("/Chook", 0x0187),
    ("/DZ", 0x01F1),
    ("/DZcaron", 0x01C4),
    ("/Dafrican", 0x0189),
    ("/Dhook", 0x018A),
    ("/Dtopbar", 0x018B),
    ("/Dz", 0x01F2),
    ("/Dzcaron", 0x01C5),
    ("/Edblgrave", 0x0204),
    ("/Einvertedbreve", 0x0206),
    ("/Eopen", 0x0190),
    ("/Ereversed", 0x018E),
    ("/Esh", 0x01A9),
    ("/Ezh", 0x01B7),
    ("/Ezhcaron", 0x01EE),
    ("/Ezhreversed", 0x01B8),
    ("/Fhook", 0x0191),
    ("/Gacute", 0x01F4),
    ("/Gammaafrican", 0x0194),
    ("/Gcaron", 0x01E6),
    ("/Ghook", 0x0193),
    ("/Gstroke", 0x01E4),
    ("/Icaron", 0x01CF),
    ("/Idblgrave", 0x0208),
    ("/Iinvertedbreve", 0x020A),
    ("/Iotaafrican", 0x0196),
    ("/Istroke", 0x0197),
    ("/Kcaron", 0x01E8),
    ("/Khook", 0x0198),
    ("/LJ", 0x01C7),
    ("/Lj", 0x01C8),
    ("/Mturned", 0x019C),
    ("/NJ", 0x01CA),
    ("/Nhookleft", 0x019D),
    ("/Nj", 0x01CB),
    ("/Ocaron", 0x01D1),
    ("/Ocenteredtilde", 0x019F),
    ("/Odblgrave", 0x020C),
    ("/Ohorn", 0x01A0),
    ("/Oi", 0x01A2),
    ("/Oinvertedbreve", 0x020E),
    ("/Oogonek", 0x01EA),
    ("/Oogonekmacron", 0x01EC),
    ("/Oopen", 0x0186),
    ("/Oslashacute", 0x01FE),
    ("/Ostrokeacute", 0x01FE),
    ("/Phook", 0x01A4),
    ("/Rdblgrave", 0x0210),
    ("/Rinvertedbreve", 0x0212),
    ("/Schwa", 0x018F),
    ("/Scommaaccent", 0x0218),
    ("/Thook", 0x01AC),
    ("/Tonefive", 0x01BC),
    ("/Tonesix", 0x0184),
    ("/Tonetwo", 0x01A7),
    ("/Tretroflexhook", 0x01AE),
    ("/Ucaron", 0x01D3),
    ("/Udblgrave", 0x0214),
    ("/Udieresisacute", 0x01D7),
    ("/Udieresiscaron", 0x01D9),
    ("/Udieresisgrave", 0x01DB),
    ("/Udieresismacron", 0x01D5),
    ("/Uhorn", 0x01AF),
    ("/Uinvertedbreve", 0x0216),
    ("/Upsilonafrican", 0x01B1),
    ("/Vhook", 0x01B2),
    ("/Yhook", 0x01B3),
    ("/Zstroke", 0x01B5),
    ("/acaron", 0x01CE),
    ("/adblgrave", 0x0201),
    ("/adieresismacron", 0x01DF),
    ("/adotmacron", 0x01E1),
    ("/aeacute", 0x01FD),
    ("/aemacron", 0x01E3),
    ("/ainvertedbreve", 0x0203),
    ("/aringacute", 0x01FB),
    ("/bstroke", 0x0180),
    ("/btopbar", 0x0183),
    ("/chook", 0x0188),
    ("/clickalveolar", 0x01C2),
    ("/clickdental", 0x01C0),
    ("/clicklateral", 0x01C1),
    ("/clickretroflex", 0x01C3),
    ("/deltaturned", 0x018D),
    ("/dtopbar", 0x018C),
    ("/dz", 0x01F3),
    ("/dzcaron", 0x01C6),
    ("/edblgrave", 0x0205),
    ("/einvertedbreve", 0x0207),
    ("/eshreversedloop", 0x01AA),
    ("/eturned", 0x01DD),
    ("/ezhcaron", 0x01EF),
    ("/ezhreversed", 0x01B9),
    ("/ezhtail", 0x01BA),
    ("/gacute", 0x01F5),
    ("/gcaron", 0x01E7),
    ("/glottalinvertedstroke", 0x01BE),
    ("/gstroke", 0x01E5),
    ("/hv", 0x0195),
    ("/icaron", 0x01D0),
    ("/idblgrave", 0x0209),
    ("/iinvertedbreve", 0x020B),
    ("/jcaron", 0x01F0),
    ("/kcaron", 0x01E9),
    ("/khook", 0x0199),
    ("/lambdastroke", 0x019B),
    ("/lbar", 0x019A),
    ("/lj", 0x01C9),
    ("/nj", 0x01CC),
    ("/nlegrightlong", 0x019E),
    ("/ocaron", 0x01D2),
    ("/odblgrave", 0x020D),
    ("/ohorn", 0x01A1),
    ("/oi", 0x01A3),
    ("/oinvertedbreve", 0x020F),
    ("/oogonek", 0x01EB),
    ("/oogonekmacron", 0x01ED),
    ("/oslashacute", 0x01FF),
    ("/ostrokeacute", 0x01FF),
    ("/phook", 0x01A5),
    ("/rdblgrave", 0x0211),
    ("/rinvertedbreve", 0x0213),
    ("/scommaaccent", 0x0219),
    ("/thook", 0x01AD),
    ("/tonefive", 0x01BD),
    ("/tonesix", 0x0185),
    ("/tonetwo", 0x01A8),
    ("/tpalatalhook", 0x01AB),
    ("/twostroke", 0x01BB),
    ("/ucaron", 0x01D4),
    ("/udblgrave", 0x0215),
    ("/udieresisacute", 0x01D8),
    ("/udieresiscaron", 0x01DA),
    ("/udieresisgrave", 0x01DC),
    ("/udieresismacron", 0x01D6),
    ("/uhorn", 0x01B0),
    ("/uinvertedbreve", 0x0217),
    ("/wynn", 0x01BF),
    ("/yhook", 0x01B4),
    ("/yr", 0x01A6),
    ("/zstroke", 0x01B6),
  ]
  let differences : Array[@pdflite.PdfEncodingDifference] = []
  let text_codes : Array[Int] = []
  let expected_codepoints : Array[Int] = []
  for index in 0..<entries.length() {
    let entry = entries[index]
    let code = index + 1
    differences.push(text_difference_for_test(entry.0, code))
    text_codes.push(code)
    expected_codepoints.push(entry.1)
  }
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(
      PdfHelvetica,
      PdfCustomEncoding(PdfStandardEncoding, differences),
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(text_bytes_for_test(text_codes)[:]),
    expected_codepoints,
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x01FC), Some(1))
  @test.assert_eq(extractor.charcode_of_codepoint(0x01FE), Some(55))
  @test.assert_eq(extractor.charcode_of_codepoint(0x01FF), Some(128))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0219), Some(133))
}

///|
test "PdfTextExtractor decodes private-use AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/Acute", 0xF6C9),
    ("/Caron", 0xF6CA),
    ("/Dieresis", 0xF6CB),
    ("/DieresisAcute", 0xF6CC),
    ("/DieresisGrave", 0xF6CD),
    ("/Grave", 0xF6CE),
    ("/Hungarumlaut", 0xF6CF),
    ("/LL", 0xF6BF),
    ("/Macron", 0xF6D0),
    ("/afii10063", 0xF6C4),
    ("/afii10064", 0xF6C5),
    ("/afii10192", 0xF6C6),
    ("/afii10831", 0xF6C7),
    ("/afii10832", 0xF6C8),
    ("/apple", 0xF8FF),
    ("/commaaccent", 0xF6C3),
    ("/cyrBreve", 0xF6D1),
    ("/cyrFlex", 0xF6D2),
    ("/cyrbreve", 0xF6D4),
    ("/cyrflex", 0xF6D5),
    ("/dblGrave", 0xF6D3),
    ("/dblgrave", 0xF6D6),
    ("/dieresisacute", 0xF6D7),
    ("/dieresisgrave", 0xF6D8),
    ("/dollarsuperior", 0xF6E4),
    ("/dotlessj", 0xF6BE),
    ("/ll", 0xF6C0),
    ("/maichattawalowleftthai", 0xF895),
    ("/maichattawalowrightthai", 0xF894),
    ("/maichattawaupperleftthai", 0xF893),
    ("/maieklowleftthai", 0xF88C),
    ("/maieklowrightthai", 0xF88B),
    ("/maiekupperleftthai", 0xF88A),
    ("/maihanakatleftthai", 0xF884),
    ("/maitaikhuleftthai", 0xF889),
    ("/maitholowleftthai", 0xF88F),
    ("/maitholowrightthai", 0xF88E),
    ("/maithoupperleftthai", 0xF88D),
    ("/maitrilowleftthai", 0xF892),
    ("/maitrilowrightthai", 0xF891),
    ("/maitriupperleftthai", 0xF890),
    ("/nikhahitleftthai", 0xF899),
    ("/saraiileftthai", 0xF886),
    ("/saraileftthai", 0xF885),
    ("/saraueeleftthai", 0xF888),
    ("/saraueleftthai", 0xF887),
    ("/thanthakhatlowleftthai", 0xF898),
    ("/thanthakhatlowrightthai", 0xF897),
    ("/thanthakhatupperleftthai", 0xF896),
  ]
  let differences : Array[@pdflite.PdfEncodingDifference] = []
  let text_codes : Array[Int] = []
  let expected_codepoints : Array[Int] = []
  for index in 0..<entries.length() {
    let entry = entries[index]
    let code = index + 1
    differences.push(text_difference_for_test(entry.0, code))
    text_codes.push(code)
    expected_codepoints.push(entry.1)
  }
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(
      PdfHelvetica,
      PdfCustomEncoding(PdfStandardEncoding, differences),
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(text_bytes_for_test(text_codes)[:]),
    expected_codepoints,
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0xF6C9), Some(1))
  @test.assert_eq(extractor.charcode_of_codepoint(0xF8FF), Some(15))
  @test.assert_eq(extractor.charcode_of_codepoint(0xF6BE), Some(26))
  @test.assert_eq(extractor.charcode_of_codepoint(0xF896), Some(49))
}

///|
test "PdfTextExtractor decodes Halfwidth and Fullwidth AGL glyph names" {
  let entries : Array[(String, Int)] = [
    ("/Amonospace", 0xFF21),
    ("/Bmonospace", 0xFF22),
    ("/Cmonospace", 0xFF23),
    ("/Dmonospace", 0xFF24),
    ("/Emonospace", 0xFF25),
    ("/Fmonospace", 0xFF26),
    ("/Gmonospace", 0xFF27),
    ("/Hmonospace", 0xFF28),
    ("/Imonospace", 0xFF29),
    ("/Jmonospace", 0xFF2A),
    ("/Kmonospace", 0xFF2B),
    ("/Lmonospace", 0xFF2C),
    ("/Mmonospace", 0xFF2D),
    ("/Nmonospace", 0xFF2E),
    ("/Omonospace", 0xFF2F),
    ("/Pmonospace", 0xFF30),
    ("/Qmonospace", 0xFF31),
    ("/Rmonospace", 0xFF32),
    ("/Smonospace", 0xFF33),
    ("/Tmonospace", 0xFF34),
    ("/Umonospace", 0xFF35),
    ("/Vmonospace", 0xFF36),
    ("/Wmonospace", 0xFF37),
    ("/Xmonospace", 0xFF38),
    ("/Ymonospace", 0xFF39),
    ("/Zmonospace", 0xFF3A),
    ("/akatakanahalfwidth", 0xFF71),
    ("/amonospace", 0xFF41),
    ("/ampersandmonospace", 0xFF06),
    ("/asciicircummonospace", 0xFF3E),
    ("/asciitildemonospace", 0xFF5E),
    ("/asmallkatakanahalfwidth", 0xFF67),
    ("/asteriskmonospace", 0xFF0A),
    ("/atmonospace", 0xFF20),
    ("/backslashmonospace", 0xFF3C),
    ("/barmonospace", 0xFF5C),
    ("/bmonospace", 0xFF42),
    ("/braceleftmonospace", 0xFF5B),
    ("/bracerightmonospace", 0xFF5D),
    ("/bracketleftmonospace", 0xFF3B),
    ("/bracketrightmonospace", 0xFF3D),
    ("/centmonospace", 0xFFE0),
    ("/cmonospace", 0xFF43),
    ("/colonmonospace", 0xFF1A),
    ("/commamonospace", 0xFF0C),
    ("/cornerbracketlefthalfwidth", 0xFF62),
    ("/cornerbracketrighthalfwidth", 0xFF63),
    ("/dmonospace", 0xFF44),
    ("/dollarmonospace", 0xFF04),
    ("/eightmonospace", 0xFF18),
    ("/ekatakanahalfwidth", 0xFF74),
    ("/emonospace", 0xFF45),
    ("/equalmonospace", 0xFF1D),
    ("/esmallkatakanahalfwidth", 0xFF6A),
    ("/exclammonospace", 0xFF01),
    ("/fivemonospace", 0xFF15),
    ("/fmonospace", 0xFF46),
    ("/fourmonospace", 0xFF14),
    ("/gmonospace", 0xFF47),
    ("/gravemonospace", 0xFF40),
    ("/greatermonospace", 0xFF1E),
    ("/hakatakanahalfwidth", 0xFF8A),
    ("/hekatakanahalfwidth", 0xFF8D),
    ("/hikatakanahalfwidth", 0xFF8B),
    ("/hmonospace", 0xFF48),
    ("/hokatakanahalfwidth", 0xFF8E),
    ("/hukatakanahalfwidth", 0xFF8C),
    ("/hyphenmonospace", 0xFF0D),
    ("/ideographiccommaleft", 0xFF64),
    ("/ikatakanahalfwidth", 0xFF72),
    ("/imonospace", 0xFF49),
    ("/ismallkatakanahalfwidth", 0xFF68),
    ("/jmonospace", 0xFF4A),
    ("/kakatakanahalfwidth", 0xFF76),
    ("/katahiraprolongmarkhalfwidth", 0xFF70),
    ("/kekatakanahalfwidth", 0xFF79),
    ("/kikatakanahalfwidth", 0xFF77),
    ("/kmonospace", 0xFF4B),
    ("/kokatakanahalfwidth", 0xFF7A),
    ("/kukatakanahalfwidth", 0xFF78),
    ("/lessmonospace", 0xFF1C),
    ("/lmonospace", 0xFF4C),
    ("/macronmonospace", 0xFFE3),
    ("/makatakanahalfwidth", 0xFF8F),
    ("/mekatakanahalfwidth", 0xFF92),
    ("/middledotkatakanahalfwidth", 0xFF65),
    ("/mikatakanahalfwidth", 0xFF90),
    ("/mmonospace", 0xFF4D),
    ("/mokatakanahalfwidth", 0xFF93),
    ("/mukatakanahalfwidth", 0xFF91),
    ("/nakatakanahalfwidth", 0xFF85),
    ("/nekatakanahalfwidth", 0xFF88),
    ("/nikatakanahalfwidth", 0xFF86),
    ("/ninemonospace", 0xFF19),
    ("/nkatakanahalfwidth", 0xFF9D),
    ("/nmonospace", 0xFF4E),
    ("/nokatakanahalfwidth", 0xFF89),
    ("/nukatakanahalfwidth", 0xFF87),
    ("/numbersignmonospace", 0xFF03),
    ("/okatakanahalfwidth", 0xFF75),
    ("/omonospace", 0xFF4F),
    ("/onemonospace", 0xFF11),
    ("/osmallkatakanahalfwidth", 0xFF6B),
    ("/parenleftmonospace", 0xFF08),
    ("/parenrightmonospace", 0xFF09),
    ("/percentmonospace", 0xFF05),
    ("/periodhalfwidth", 0xFF61),
    ("/periodmonospace", 0xFF0E),
    ("/plusmonospace", 0xFF0B),
    ("/pmonospace", 0xFF50),
    ("/qmonospace", 0xFF51),
    ("/questionmonospace", 0xFF1F),
    ("/quotedblmonospace", 0xFF02),
    ("/quotesinglemonospace", 0xFF07),
    ("/rakatakanahalfwidth", 0xFF97),
    ("/rekatakanahalfwidth", 0xFF9A),
    ("/rikatakanahalfwidth", 0xFF98),
    ("/rmonospace", 0xFF52),
    ("/rokatakanahalfwidth", 0xFF9B),
    ("/rukatakanahalfwidth", 0xFF99),
    ("/sakatakanahalfwidth", 0xFF7B),
    ("/sekatakanahalfwidth", 0xFF7E),
    ("/semicolonmonospace", 0xFF1B),
    ("/semivoicedmarkkanahalfwidth", 0xFF9F),
    ("/sevenmonospace", 0xFF17),
    ("/sikatakanahalfwidth", 0xFF7C),
    ("/sixmonospace", 0xFF16),
    ("/slashmonospace", 0xFF0F),
    ("/smonospace", 0xFF53),
    ("/sokatakanahalfwidth", 0xFF7F),
    ("/sterlingmonospace", 0xFFE1),
    ("/sukatakanahalfwidth", 0xFF7D),
    ("/takatakanahalfwidth", 0xFF80),
    ("/tekatakanahalfwidth", 0xFF83),
    ("/threemonospace", 0xFF13),
    ("/tikatakanahalfwidth", 0xFF81),
    ("/tmonospace", 0xFF54),
    ("/tokatakanahalfwidth", 0xFF84),
    ("/tukatakanahalfwidth", 0xFF82),
    ("/tusmallkatakanahalfwidth", 0xFF6F),
    ("/twomonospace", 0xFF12),
    ("/ukatakanahalfwidth", 0xFF73),
    ("/umonospace", 0xFF55),
    ("/underscoremonospace", 0xFF3F),
    ("/usmallkatakanahalfwidth", 0xFF69),
    ("/vmonospace", 0xFF56),
    ("/voicedmarkkanahalfwidth", 0xFF9E),
    ("/wakatakanahalfwidth", 0xFF9C),
    ("/wmonospace", 0xFF57),
    ("/wokatakanahalfwidth", 0xFF66),
    ("/wonmonospace", 0xFFE6),
    ("/xmonospace", 0xFF58),
    ("/yakatakanahalfwidth", 0xFF94),
    ("/yasmallkatakanahalfwidth", 0xFF6C),
    ("/yenmonospace", 0xFFE5),
    ("/ymonospace", 0xFF59),
    ("/yokatakanahalfwidth", 0xFF96),
    ("/yosmallkatakanahalfwidth", 0xFF6E),
    ("/yukatakanahalfwidth", 0xFF95),
    ("/yusmallkatakanahalfwidth", 0xFF6D),
    ("/zeromonospace", 0xFF10),
    ("/zmonospace", 0xFF5A),
  ]
  let differences : Array[@pdflite.PdfEncodingDifference] = []
  let text_codes : Array[Int] = []
  let expected_codepoints : Array[Int] = []
  for index in 0..<entries.length() {
    let entry = entries[index]
    let code = index + 1
    differences.push(text_difference_for_test(entry.0, code))
    text_codes.push(code)
    expected_codepoints.push(entry.1)
  }
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(
      PdfHelvetica,
      PdfCustomEncoding(PdfStandardEncoding, differences),
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(text_bytes_for_test(text_codes)[:]),
    expected_codepoints,
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0xFF21), Some(1))
  @test.assert_eq(extractor.charcode_of_codepoint(0xFFE0), Some(42))
  @test.assert_eq(extractor.charcode_of_codepoint(0xFF61), Some(107))
  @test.assert_eq(extractor.charcode_of_codepoint(0xFF5A), Some(162))
}

///|
test "PdfTextExtractor decodes TrueType Gxx glyph names" {
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(
      PdfHelvetica,
      PdfCustomEncoding(PdfStandardEncoding, [
        text_difference_for_test("/G82", 1),
        text_difference_for_test("/G8a", 2),
        text_difference_for_test("/G8A", 3),
        text_difference_for_test("/G6D", 4),
        text_difference_for_test("/Gf0.alt", 5),
        text_difference_for_test("/GG2", 6),
        text_difference_for_test("/G2G", 7),
        text_difference_for_test("/G81", 8),
        text_difference_for_test("/GA6", 9),
        text_difference_for_test("/Ga6", 10),
      ]),
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(
      text_bytes_for_test([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])[:],
    ),
    [0x201A, 0x0160, 0x008A, 0x002D, 0x00F0, 6, 7, 8, 0x00B6, 0x00A6],
  )
  @test.assert_eq(
    try! extractor.glyphnames_of_text(
      text_bytes_for_test([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])[:],
    ),
    [
      text_name_for_test("/G82"),
      text_name_for_test("/G8a"),
      text_name_for_test("/G8A"),
      text_name_for_test("/G6D"),
      text_name_for_test("/Gf0.alt"),
      text_name_for_test("/GG2"),
      text_name_for_test("/G2G"),
      text_name_for_test("/G81"),
      text_name_for_test("/GA6"),
      text_name_for_test("/Ga6"),
    ],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x201A), Some(1))
  @test.assert_eq(extractor.charcode_of_codepoint(0x0160), Some(2))
  @test.assert_eq(extractor.charcode_of_codepoint(0x008A), Some(3))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00F0), Some(5))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00B6), Some(9))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00A6), Some(10))
}

///|
test "PdfTextExtractor decodes control glyph names" {
  let standard_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(
      PdfHelvetica,
      PdfCustomEncoding(PdfStandardEncoding, [
        text_difference_for_test("/controlCR", 1),
        text_difference_for_test("/controlLF", 2),
        text_difference_for_test("/controlHT", 3),
        text_difference_for_test("/controlFF", 4),
      ]),
    ),
  )
  let extractor = standard_font.text_extractor()
  @test.assert_eq(
    try! extractor.codepoints_of_text(text_bytes_for_test([1, 2, 3, 4])[:]),
    [13, 10, 9, 12],
  )
  @test.assert_eq(
    try! extractor.glyphnames_of_text(text_bytes_for_test([1, 2, 3, 4])[:]),
    [
      text_name_for_test("/controlCR"),
      text_name_for_test("/controlLF"),
      text_name_for_test("/controlHT"),
      text_name_for_test("/controlFF"),
    ],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(13), Some(1))
  @test.assert_eq(extractor.charcode_of_codepoint(10), Some(2))
  @test.assert_eq(extractor.charcode_of_codepoint(9), Some(3))
  @test.assert_eq(extractor.charcode_of_codepoint(12), Some(4))
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
