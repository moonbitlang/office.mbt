///|
test "pdf_parse_unicode_data parses cpdf UnicodeData rows" {
  let rows = try! @pdflite.pdf_parse_unicode_data(
    @ascii.encode(
      "0041;LATIN CAPITAL LETTER A;Lu;0;L;;;;;N;;;;0061;\n" +
      "0030;DIGIT ZERO;Nd;0;EN;;0;0;0;N;;;;;\n" +
      "00A8;DIAERESIS;Sk;0;ON;<compat> 0020 0308;;;;N;SPACING DIAERESIS;;;;",
    ),
  )
  @test.assert_eq(rows.length(), 3)
  @test.assert_eq(rows[0].code_value, "0041")
  @test.assert_eq(rows[0].character_name, "LATIN CAPITAL LETTER A")
  @test.assert_eq(rows[0].general_category, "Lu")
  @test.assert_eq(rows[0].lowercase_mapping, "0061")
  @test.assert_eq(rows[1].decimal_digit_value, "0")
  @test.assert_eq(rows[1].digit_value, "0")
  @test.assert_eq(rows[1].numeric_value, "0")
  @test.assert_eq(rows[2].character_decomposition_mapping, "<compat> 0020 0308")
  @test.assert_eq(rows[2].unicode_10_name, "SPACING DIAERESIS")
  @test.assert_eq(rows[2].titlecase_mapping, "")
}

///|
test "pdf_parse_unicode_data accepts CRLF row endings" {
  let rows = try! @pdflite.pdf_parse_unicode_data(
    @ascii.encode(
      "000A;<control>;Cc;0;B;;;;;N;LINE FEED (LF);;;;\r\n" +
      "0061;LATIN SMALL LETTER A;Ll;0;L;;;;;N;;;0041;;0041\r\n",
    ),
  )
  @test.assert_eq(rows.length(), 2)
  @test.assert_eq(rows[0].code_value, "000A")
  @test.assert_eq(rows[0].unicode_10_name, "LINE FEED (LF)")
  @test.assert_eq(rows[1].uppercase_mapping, "0041")
  @test.assert_eq(rows[1].titlecase_mapping, "0041")
}

///|
test "pdf_parse_flate_unicode_data mirrors cpdf compressed source path" {
  let source = @ascii.encode(
    "0020;SPACE;Zs;0;WS;;;;;N;;;;;\n" +
    "00B2;SUPERSCRIPT TWO;No;0;EN;<super> 0032;;;2;N;SUPERSCRIPT DIGIT TWO;;;;",
  )
  let rows = try! @pdflite.pdf_parse_flate_unicode_data(
    @pdflite.pdf_flate_encode(source),
  )
  @test.assert_eq(rows.length(), 2)
  @test.assert_eq(rows[0].character_name, "SPACE")
  @test.assert_eq(rows[1].numeric_value, "2")
  @test.assert_eq(rows[1].unicode_10_name, "SUPERSCRIPT DIGIT TWO")
}

///|
test "pdf_unicode_data exposes cpdf embedded UnicodeData table" {
  let source = try! @pdflite.pdf_unicode_data_source()
  @test.assert_eq(try! @pdflite.pdf_unicodedata_source(), source)
  @test.assert_eq(source.length(), 272286)
  @test.assert_eq(source[0].to_int(), 0x78)
  @test.assert_eq(source[1].to_int(), 0x01)
  let rows = try! @pdflite.pdf_unicode_data()
  @test.assert_eq(try! @pdflite.pdf_unicodedata(), rows)
  @test.assert_eq(rows.length(), 34626)
  @test.assert_eq(rows[0].code_value, "0000")
  @test.assert_eq(rows[0].character_name, "<control>")
  @test.assert_eq(rows[0].general_category, "Cc")
  @test.assert_eq(rows[0].unicode_10_name, "NULL")
  @test.assert_eq(rows[65].code_value, "0041")
  @test.assert_eq(rows[65].character_name, "LATIN CAPITAL LETTER A")
  @test.assert_eq(rows[rows.length() - 1].code_value, "10FFFD")
  @test.assert_eq(
    rows[rows.length() - 1].character_name,
    "<Plane 16 Private Use, Last>",
  )
}

///|
test "pdf_parse_unicode_data rejects malformed rows" {
  let missing_fields : Result[Array[@unicodedata.PdfUnicodeDataEntry], Error] = try? @pdflite.pdf_parse_unicode_data(
    @ascii.encode("0041;LATIN CAPITAL LETTER A;Lu\n"),
  )
  guard missing_fields is Err(@pdflite.PdfError::SoftError(_)) else {
    fail("expected SoftError for missing UnicodeData fields")
  }
}
