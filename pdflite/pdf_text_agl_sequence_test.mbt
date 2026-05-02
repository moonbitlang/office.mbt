///|
test "PdfTextExtractor decodes multi-codepoint AGL glyph names" {
  let entries : Array[(String, Array[Int])] = [
    ("/dalethatafpatah", [0x05D3, 0x05B2]),
    ("/dalethatafpatahhebrew", [0x05D3, 0x05B2]),
    ("/dalethatafsegol", [0x05D3, 0x05B1]),
    ("/dalethatafsegolhebrew", [0x05D3, 0x05B1]),
    ("/dalethiriq", [0x05D3, 0x05B4]),
    ("/dalethiriqhebrew", [0x05D3, 0x05B4]),
    ("/daletholam", [0x05D3, 0x05B9]),
    ("/daletholamhebrew", [0x05D3, 0x05B9]),
    ("/daletpatah", [0x05D3, 0x05B7]),
    ("/daletpatahhebrew", [0x05D3, 0x05B7]),
    ("/daletqamats", [0x05D3, 0x05B8]),
    ("/daletqamatshebrew", [0x05D3, 0x05B8]),
    ("/daletqubuts", [0x05D3, 0x05BB]),
    ("/daletqubutshebrew", [0x05D3, 0x05BB]),
    ("/daletsegol", [0x05D3, 0x05B6]),
    ("/daletsegolhebrew", [0x05D3, 0x05B6]),
    ("/daletsheva", [0x05D3, 0x05B0]),
    ("/daletshevahebrew", [0x05D3, 0x05B0]),
    ("/dalettsere", [0x05D3, 0x05B5]),
    ("/dalettserehebrew", [0x05D3, 0x05B5]),
    ("/finalkafqamats", [0x05DA, 0x05B8]),
    ("/finalkafqamatshebrew", [0x05DA, 0x05B8]),
    ("/finalkafsheva", [0x05DA, 0x05B0]),
    ("/finalkafshevahebrew", [0x05DA, 0x05B0]),
    ("/hamzadammaarabic", [0x0621, 0x064F]),
    ("/hamzadammatanarabic", [0x0621, 0x064C]),
    ("/hamzafathaarabic", [0x0621, 0x064E]),
    ("/hamzafathatanarabic", [0x0621, 0x064B]),
    ("/hamzalowkasraarabic", [0x0621, 0x0650]),
    ("/hamzalowkasratanarabic", [0x0621, 0x064D]),
    ("/hamzasukunarabic", [0x0621, 0x0652]),
    ("/lamedholam", [0x05DC, 0x05B9]),
    ("/lamedholamdagesh", [0x05DC, 0x05B9, 0x05BC]),
    ("/lamedholamdageshhebrew", [0x05DC, 0x05B9, 0x05BC]),
    ("/lamedholamhebrew", [0x05DC, 0x05B9]),
    ("/lammeemjeeminitialarabic", [0xFEDF, 0xFEE4, 0xFEA0]),
    ("/lammeemkhahinitialarabic", [0xFEDF, 0xFEE4, 0xFEA8]),
    ("/noonhehinitialarabic", [0xFEE7, 0xFEEC]),
    ("/qofhatafpatah", [0x05E7, 0x05B2]),
    ("/qofhatafpatahhebrew", [0x05E7, 0x05B2]),
    ("/qofhatafsegol", [0x05E7, 0x05B1]),
    ("/qofhatafsegolhebrew", [0x05E7, 0x05B1]),
    ("/qofhiriq", [0x05E7, 0x05B4]),
    ("/qofhiriqhebrew", [0x05E7, 0x05B4]),
    ("/qofholam", [0x05E7, 0x05B9]),
    ("/qofholamhebrew", [0x05E7, 0x05B9]),
    ("/qofpatah", [0x05E7, 0x05B7]),
    ("/qofpatahhebrew", [0x05E7, 0x05B7]),
    ("/qofqamats", [0x05E7, 0x05B8]),
    ("/qofqamatshebrew", [0x05E7, 0x05B8]),
    ("/qofqubuts", [0x05E7, 0x05BB]),
    ("/qofqubutshebrew", [0x05E7, 0x05BB]),
    ("/qofsegol", [0x05E7, 0x05B6]),
    ("/qofsegolhebrew", [0x05E7, 0x05B6]),
    ("/qofsheva", [0x05E7, 0x05B0]),
    ("/qofshevahebrew", [0x05E7, 0x05B0]),
    ("/qoftsere", [0x05E7, 0x05B5]),
    ("/qoftserehebrew", [0x05E7, 0x05B5]),
    ("/rehyehaleflamarabic", [0x0631, 0xFEF3, 0xFE8E, 0x0644]),
    ("/reshhatafpatah", [0x05E8, 0x05B2]),
    ("/reshhatafpatahhebrew", [0x05E8, 0x05B2]),
    ("/reshhatafsegol", [0x05E8, 0x05B1]),
    ("/reshhatafsegolhebrew", [0x05E8, 0x05B1]),
    ("/reshhiriq", [0x05E8, 0x05B4]),
    ("/reshhiriqhebrew", [0x05E8, 0x05B4]),
    ("/reshholam", [0x05E8, 0x05B9]),
    ("/reshholamhebrew", [0x05E8, 0x05B9]),
    ("/reshpatah", [0x05E8, 0x05B7]),
    ("/reshpatahhebrew", [0x05E8, 0x05B7]),
    ("/reshqamats", [0x05E8, 0x05B8]),
    ("/reshqamatshebrew", [0x05E8, 0x05B8]),
    ("/reshqubuts", [0x05E8, 0x05BB]),
    ("/reshqubutshebrew", [0x05E8, 0x05BB]),
    ("/reshsegol", [0x05E8, 0x05B6]),
    ("/reshsegolhebrew", [0x05E8, 0x05B6]),
    ("/reshsheva", [0x05E8, 0x05B0]),
    ("/reshshevahebrew", [0x05E8, 0x05B0]),
    ("/reshtsere", [0x05E8, 0x05B5]),
    ("/reshtserehebrew", [0x05E8, 0x05B5]),
    ("/shaddafathatanarabic", [0x0651, 0x064B]),
    ("/tchehmeeminitialarabic", [0xFB7C, 0xFEE4]),
  ]
  let differences : Array[@pdflite.PdfEncodingDifference] = []
  let text_codes : Array[Int] = []
  let expected_codepoints : Array[Int] = []
  for index in 0..<entries.length() {
    let entry = entries[index]
    let code = index + 1
    differences.push(text_difference_for_test(entry.0, code))
    text_codes.push(code)
    for codepoint in entry.1 {
      expected_codepoints.push(codepoint)
    }
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
  @test.assert_eq(extractor.charcode_of_codepoint(0x05D3), None)
  @test.assert_eq(extractor.charcode_of_codepoint(0x05B2), None)

  let suffixed_font : @pdflite.PdfFont = PdfFontStandard(
    text_standard_font_data_for_test(
      PdfHelvetica,
      PdfCustomEncoding(PdfStandardEncoding, [
        text_difference_for_test("/lamedholamdagesh.alt", 1),
      ]),
    ),
  )
  @test.assert_eq(
    try! suffixed_font
    .text_extractor()
    .codepoints_of_text(text_bytes_for_test([1])[:]),
    [0x05DC, 0x05B9, 0x05BC],
  )
}
