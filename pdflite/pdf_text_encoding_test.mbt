///|
fn text_encoding_name_for_test(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn text_encoding_bytes_for_test(values : ArrayView[Int]) -> @core.PdfBytes {
  try! @core.pdf_bytes_of_int_array(values)
}

///|
fn text_encoding_difference_for_test(
  name : String,
  code : Int,
) -> @pdflite.PdfEncodingDifference {
  { name: text_encoding_name_for_test(name), code }
}

///|
fn text_encoding_table_lookup_helper_for_test(
  table : ArrayView[(Int, @core.PdfName)],
  code : Int,
) -> @core.PdfName? {
  for entry in table {
    if entry.0 == code {
      break Some(entry.1)
    }
  } nobreak {
    None
  }
}

///|
fn text_encoding_reverse_table_lookup_for_test(
  table : ArrayView[(@core.PdfName, Int)],
  name : @core.PdfName,
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
fn text_encoding_font_descriptor_for_test() -> @pdflite.PdfFontDescriptor {
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
    name: text_encoding_name_for_test("/A"),
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
  let encodings : Array[(@pdflite.PdfEncoding, @core.PdfName)] = [
    (PdfStandardEncoding, text_encoding_name_for_test("/StandardEncoding")),
    (PdfMacRomanEncoding, text_encoding_name_for_test("/MacRomanEncoding")),
    (PdfWinAnsiEncoding, text_encoding_name_for_test("/WinAnsiEncoding")),
    (PdfMacExpertEncoding, text_encoding_name_for_test("/MacExpertEncoding")),
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
    @pdflite.pdf_encoding_of_name(
      text_encoding_name_for_test("/MissingEncoding"),
    ),
    None,
  )
}

///|
test "PdfEncoding exposes effective encoding tables" {
  let standard_table = @pdflite.PdfStandardEncoding.table()
  @test.assert_eq(
    text_encoding_table_lookup_helper_for_test(standard_table, 65),
    Some(text_encoding_name_for_test("/A")),
  )
  @test.assert_eq(
    text_encoding_table_lookup_helper_for_test(standard_table, 0),
    None,
  )
  let custom : @pdflite.PdfEncoding = PdfCustomEncoding(PdfStandardEncoding, [
    text_encoding_difference_for_test("/Alpha", 65),
  ])
  let custom_table = @pdflite.pdf_table_of_encoding(custom)
  @test.assert_eq(
    text_encoding_table_lookup_helper_for_test(custom_table, 65),
    Some(text_encoding_name_for_test("/Alpha")),
  )
  @test.assert_eq(
    text_encoding_table_lookup_helper_for_test(custom_table, 66),
    Some(text_encoding_name_for_test("/B")),
  )
  let reverse = @pdflite.pdf_reverse_table_of_encoding(custom)
  @test.assert_eq(
    text_encoding_reverse_table_lookup_for_test(
      reverse,
      text_encoding_name_for_test("/Alpha"),
    ),
    Some(65),
  )
  @test.assert_eq(
    text_encoding_reverse_table_lookup_for_test(
      reverse,
      text_encoding_name_for_test("/B"),
    ),
    Some(66),
  )
  let filled : @pdflite.PdfEncoding = PdfFillUndefinedWithStandard(
    PdfImplicitInFontFile,
  )
  @test.assert_eq(
    text_encoding_table_lookup_helper_for_test(filled.table(), 65),
    Some(text_encoding_name_for_test("/A")),
  )
  @test.assert_eq(@pdflite.PdfImplicitInFontFile.reverse_table(), [])
}

///|
test "Pdf font debug names cover non-Type1 variants" {
  let external_cmap : @pdflite.PdfCMapEncoding = PdfCMap(7)
  @test.assert_eq(external_cmap.is_identity_h(), false)
  @test.assert_eq(external_cmap.is_identity_v(), false)
  @test.assert_eq(external_cmap.uses_two_byte_codes(), false)
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
    basefont: text_encoding_name_for_test("/Top"),
    composite: {
      cid_system_info: {
        registry: text_encoding_bytes_for_test([82]),
        ordering: text_encoding_bytes_for_test([79]),
        supplement: 0,
      },
      cid_basefont: text_encoding_name_for_test("/Descendant"),
      cid_fontdescriptor: text_encoding_font_descriptor_for_test(),
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
  let direct_font = @syntax.pdf_dictionary([
    (
      text_encoding_name_for_test("/Encoding"),
      PdfNameObject(text_encoding_name_for_test("/WinAnsiEncoding")),
    ),
  ])
  @test.assert_eq(try! doc.read_encoding(direct_font), PdfWinAnsiEncoding)
  let unknown_direct = @syntax.pdf_dictionary([
    (
      text_encoding_name_for_test("/Encoding"),
      PdfNameObject(text_encoding_name_for_test("/UnknownEncoding")),
    ),
  ])
  @test.assert_eq(try! doc.read_encoding(unknown_direct), PdfImplicitInFontFile)
  let dictionary_font = @syntax.pdf_dictionary([
    (
      text_encoding_name_for_test("/Subtype"),
      PdfNameObject(text_encoding_name_for_test("/Type1")),
    ),
    (
      text_encoding_name_for_test("/Encoding"),
      @syntax.pdf_dictionary([
        (
          text_encoding_name_for_test("/BaseEncoding"),
          PdfNameObject(text_encoding_name_for_test("/MacRomanEncoding")),
        ),
        (
          text_encoding_name_for_test("/Differences"),
          PdfArray([
            PdfInteger(65),
            PdfNameObject(text_encoding_name_for_test("/A")),
            PdfNameObject(text_encoding_name_for_test("/B")),
            PdfInteger(70),
            PdfNameObject(text_encoding_name_for_test("/C")),
          ]),
        ),
      ]),
    ),
  ])
  @test.assert_eq(
    try! doc.read_encoding(dictionary_font),
    PdfCustomEncoding(PdfMacRomanEncoding, [
      text_encoding_difference_for_test("/A", 65),
      text_encoding_difference_for_test("/B", 66),
      text_encoding_difference_for_test("/C", 70),
    ]),
  )
}

///|
test "PdfDocument read_encoding handles default and TrueType encodings" {
  let doc = @pdflite.pdf_document_empty()
  let plain = @syntax.pdf_dictionary([
    (
      text_encoding_name_for_test("/Subtype"),
      PdfNameObject(text_encoding_name_for_test("/Type1")),
    ),
    (text_encoding_name_for_test("/Encoding"), @syntax.pdf_dictionary([])),
  ])
  @test.assert_eq(try! doc.read_encoding(plain), PdfStandardEncoding)
  let embedded = @syntax.pdf_dictionary([
    (
      text_encoding_name_for_test("/Subtype"),
      PdfNameObject(text_encoding_name_for_test("/Type1")),
    ),
    (text_encoding_name_for_test("/Encoding"), @syntax.pdf_dictionary([])),
    (
      text_encoding_name_for_test("/FontDescriptor"),
      @syntax.pdf_dictionary([
        (text_encoding_name_for_test("/FontFile"), PdfIndirect(99)),
      ]),
    ),
  ])
  @test.assert_eq(try! doc.read_encoding(embedded), PdfImplicitInFontFile)
  let symbolic = @syntax.pdf_dictionary([
    (
      text_encoding_name_for_test("/Subtype"),
      PdfNameObject(text_encoding_name_for_test("/Type1")),
    ),
    (text_encoding_name_for_test("/Encoding"), @syntax.pdf_dictionary([])),
    (
      text_encoding_name_for_test("/FontDescriptor"),
      @syntax.pdf_dictionary([
        (text_encoding_name_for_test("/Flags"), PdfInteger(8)),
      ]),
    ),
  ])
  @test.assert_eq(try! doc.read_encoding(symbolic), PdfImplicitInFontFile)
  let true_type = @syntax.pdf_dictionary([
    (
      text_encoding_name_for_test("/Subtype"),
      PdfNameObject(text_encoding_name_for_test("/TrueType")),
    ),
    (
      text_encoding_name_for_test("/Encoding"),
      @syntax.pdf_dictionary([
        (
          text_encoding_name_for_test("/BaseEncoding"),
          PdfNameObject(text_encoding_name_for_test("/WinAnsiEncoding")),
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
  let non_dictionary_encoding = @syntax.pdf_dictionary([
    (text_encoding_name_for_test("/Encoding"), PdfInteger(1)),
  ])
  @test.assert_eq(
    try! doc.read_encoding(non_dictionary_encoding),
    PdfImplicitInFontFile,
  )
  let bad_differences = @syntax.pdf_dictionary([
    (
      text_encoding_name_for_test("/Subtype"),
      PdfNameObject(text_encoding_name_for_test("/Type1")),
    ),
    (
      text_encoding_name_for_test("/Encoding"),
      @syntax.pdf_dictionary([
        (
          text_encoding_name_for_test("/Differences"),
          PdfArray([PdfNameObject(text_encoding_name_for_test("/A"))]),
        ),
      ]),
    ),
  ])
  let differences_result = try? doc.read_encoding(bad_differences)
  guard differences_result is Err(EncodingDifferencesMalformed) else {
    fail("expected @core.PdfError::EncodingDifferencesMalformed")
  }
  let bad_base = @syntax.pdf_dictionary([
    (
      text_encoding_name_for_test("/Subtype"),
      PdfNameObject(text_encoding_name_for_test("/Type1")),
    ),
    (
      text_encoding_name_for_test("/Encoding"),
      @syntax.pdf_dictionary([
        (text_encoding_name_for_test("/BaseEncoding"), PdfInteger(1)),
      ]),
    ),
  ])
  let base_result = try? doc.read_encoding(bad_base)
  guard base_result is Err(EncodingExpected) else {
    fail("expected @core.PdfError::EncodingExpected")
  }
  let unknown_base = @syntax.pdf_dictionary([
    (
      text_encoding_name_for_test("/Subtype"),
      PdfNameObject(text_encoding_name_for_test("/Type1")),
    ),
    (
      text_encoding_name_for_test("/Encoding"),
      @syntax.pdf_dictionary([
        (
          text_encoding_name_for_test("/BaseEncoding"),
          PdfNameObject(text_encoding_name_for_test("/UnknownEncoding")),
        ),
      ]),
    ),
  ])
  let unknown_base_result = try? doc.read_encoding(unknown_base)
  guard unknown_base_result is Err(EncodingExpected) else {
    fail("expected @core.PdfError::EncodingExpected for unknown base")
  }
  let bad_difference_object = @syntax.pdf_dictionary([
    (
      text_encoding_name_for_test("/Subtype"),
      PdfNameObject(text_encoding_name_for_test("/Type1")),
    ),
    (
      text_encoding_name_for_test("/Encoding"),
      @syntax.pdf_dictionary([
        (
          text_encoding_name_for_test("/Differences"),
          PdfArray([PdfInteger(65), PdfNull]),
        ),
      ]),
    ),
  ])
  let bad_difference_object_result = try? doc.read_encoding(
    bad_difference_object,
  )
  guard bad_difference_object_result is Err(EncodingDifferencesMalformed) else {
    fail(
      "expected @core.PdfError::EncodingDifferencesMalformed for bad difference object",
    )
  }
  let non_array_differences = @syntax.pdf_dictionary([
    (
      text_encoding_name_for_test("/Subtype"),
      PdfNameObject(text_encoding_name_for_test("/Type1")),
    ),
    (
      text_encoding_name_for_test("/Encoding"),
      @syntax.pdf_dictionary([
        (text_encoding_name_for_test("/Differences"), PdfInteger(65)),
      ]),
    ),
  ])
  let non_array_result = try? doc.read_encoding(non_array_differences)
  guard non_array_result is Err(EncodingDifferencesMalformed) else {
    fail(
      "expected @core.PdfError::EncodingDifferencesMalformed for non-array differences",
    )
  }
  let missing_flags = @syntax.pdf_dictionary([
    (
      text_encoding_name_for_test("/Subtype"),
      PdfNameObject(text_encoding_name_for_test("/Type1")),
    ),
    (text_encoding_name_for_test("/Encoding"), @syntax.pdf_dictionary([])),
    (text_encoding_name_for_test("/FontDescriptor"), @syntax.pdf_dictionary([])),
  ])
  let missing_flags_result = try? doc.read_encoding(missing_flags)
  guard missing_flags_result is Err(FontFlagsExpected) else {
    fail("expected @core.PdfError::FontFlagsExpected")
  }
  let bad_subtype = @syntax.pdf_dictionary([
    (text_encoding_name_for_test("/Encoding"), @syntax.pdf_dictionary([])),
  ])
  let subtype_result = try? doc.read_encoding(bad_subtype)
  guard subtype_result is Err(FontSubtypeExpected) else {
    fail("expected @core.PdfError::FontSubtypeExpected")
  }
}
