///|
fn pdf_ua_matterhorn_test_31_001() -> PdfUAMatterhornTest {
  {
    name: "31-001",
    error: "A Type 0 font dictionary with encoding other than Identity-H and Identity-V has values for Registry in both CIDSystemInfo dictionaries that are not identical.",
    section: "UA1:7.21.3-1",
  }
}

///|
fn pdf_ua_matterhorn_test_31_002() -> PdfUAMatterhornTest {
  {
    name: "31-002",
    error: "A Type 0 font dictionary with encoding other than Identity-H and Identity-V has values for Ordering in both CIDSystemInfo dictionaries that are not identical.",
    section: "UA1:7.21.3.1-1",
  }
}

///|
fn pdf_ua_matterhorn_test_31_003() -> PdfUAMatterhornTest {
  {
    name: "31-003",
    error: "A Type 0 font dictionary with encoding other than Identity-H and Identity-V has a value for Supplement in the CIDSystemInfo dictionary of the CID font that is less than the value for Supplement in the CIDSystemInfo dictionary of the CMap.",
    section: "UA1:7.21.3.1-1",
  }
}

///|
fn pdf_ua_matterhorn_test_31_004() -> PdfUAMatterhornTest {
  {
    name: "31-004",
    error: "A Type 2 CID font contains neither a stream nor the name Identity as the value of the CIDToGIDMap entry.",
    section: "UA1:7.21.3.2-1",
  }
}

///|
fn pdf_ua_matterhorn_test_31_005() -> PdfUAMatterhornTest {
  {
    name: "31-005",
    error: "A Type 2 CID font does not contain a CIDToGIDMap entry.",
    section: "UA1:7.21.3.2-1",
  }
}

///|
fn pdf_ua_matterhorn_test_31_006() -> PdfUAMatterhornTest {
  {
    name: "31-006",
    error: "A CMap is neither listed as described in ISO 32000- 1:2008, 9.7.5.2, Table 118 nor is it embedded.",
    section: "UA1:7.21.3.3-1",
  }
}

///|
fn pdf_ua_matterhorn_test_31_007() -> PdfUAMatterhornTest {
  {
    name: "31-007",
    error: "The WMode entry in a CMap dictionary is not identical to the WMode value in the CMap stream.",
    section: "UA1:7.21.3.3-1",
  }
}

///|
fn pdf_ua_matterhorn_test_31_008() -> PdfUAMatterhornTest {
  {
    name: "31-008",
    error: "A CMap references another CMap which is not listed in ISO 32000-1:2008, 9.7.5.2, Table 118.",
    section: "UA1:7.21.3.3-2",
  }
}

///|
fn pdf_ua_matterhorn_test_31_009() -> PdfUAMatterhornTest {
  {
    name: "31-009",
    error: "For a font used by text intended to be rendered the font program is not embedded.",
    section: "UA1:7.21.4.1-1",
  }
}

///|
fn pdf_ua_matterhorn_test_31_011() -> PdfUAMatterhornTest {
  {
    name: "31-011",
    error: "For a font used by text the font program is embedded but it does not contain glyphs for all of the glyphs referenced by the text used for rendering.",
    section: "UA1:7.21.4.1-3",
  }
}

///|
fn pdf_ua_matterhorn_test_31_012() -> PdfUAMatterhornTest {
  {
    name: "31-012",
    error: "The FontDescriptor dictionary of an embedded Type 1 font contains a CharSet string, but at least one of the glyphs present in the font program is not listed in the CharSet string.",
    section: "UA1:7.21.4.2-1",
  }
}

///|
fn pdf_ua_matterhorn_test_31_013() -> PdfUAMatterhornTest {
  {
    name: "31-013",
    error: "The FontDescriptor dictionary of an embedded Type 1 font contains a CharSet string, but at least one of the glyphs listed in the CharSet string is not present in the font program.",
    section: "UA1:7.21.4.2-2",
  }
}

///|
fn pdf_ua_matterhorn_test_31_014() -> PdfUAMatterhornTest {
  {
    name: "31-014",
    error: "The FontDescriptor dictionary of an embedded CID font contains a CIDSet string, but at least one of the glyphs present in the font program is not listed in the CIDSet string.",
    section: "UA1:7.21.4.2-3",
  }
}

///|
fn pdf_ua_matterhorn_test_31_015() -> PdfUAMatterhornTest {
  {
    name: "31-015",
    error: "The FontDescriptor dictionary of an embedded CID font contains a CIDSet string, but at least one of the glyphs listed in the CIDSet string is not present in the font program.",
    section: "UA1:7.21.4.2-4",
  }
}

///|
fn pdf_ua_matterhorn_test_31_016() -> PdfUAMatterhornTest {
  {
    name: "31-016",
    error: "For one or more glyphs, the glyph width information in the font dictionary and in the embedded font program differ by more than 1/1000 unit.",
    section: "UA1:7.21.5-1",
  }
}

///|
fn pdf_ua_matterhorn_test_31_017() -> PdfUAMatterhornTest {
  {
    name: "31-017",
    error: "A non-symbolic TrueType font is used for rendering, but none of the cmap entries in the embedded font program is a non-symbolic cmap.",
    section: "UA1:7.21.6-1",
  }
}

///|
fn pdf_ua_matterhorn_test_31_018() -> PdfUAMatterhornTest {
  {
    name: "31-018",
    error: "A non-symbolic TrueType font is used for rendering, but for at least one glyph to be rendered the glyph cannot be looked up by any of the non-symbolic cmap entries in the embedded font program.",
    section: "UA1:7.21.6-2",
  }
}

///|
fn pdf_ua_matterhorn_test_31_019() -> PdfUAMatterhornTest {
  {
    name: "31-019",
    error: "The font dictionary for a non-symbolic TrueType font does not contain an Encoding entry.",
    section: "UA1:7.21.6-3",
  }
}

///|
fn pdf_ua_matterhorn_test_31_020() -> PdfUAMatterhornTest {
  {
    name: "31-020",
    error: "The font dictionary for a non-symbolic TrueType font contains an Encoding dictionary which does not contain a BaseEncoding entry.",
    section: "UA1:7.21.6-4",
  }
}

///|
fn pdf_ua_matterhorn_test_31_021() -> PdfUAMatterhornTest {
  {
    name: "31-021",
    error: "The value for either the Encoding entry or the BaseEncoding entry in the Encoding dictionary in a non-symbolic TrueType font dictionary is neither MacRomanEncoding nor WinAnsiEncoding.",
    section: "UA1:7.21.6-5",
  }
}

///|
fn pdf_ua_matterhorn_test_31_022() -> PdfUAMatterhornTest {
  {
    name: "31-022",
    error: "The Differences array in the Encoding entry in a non-symbolic TrueType font dictionary contains one or more glyph names which are not listed in the Adobe Glyph List.",
    section: "UA1:7.21.6-6",
  }
}

///|
fn pdf_ua_matterhorn_test_31_023() -> PdfUAMatterhornTest {
  {
    name: "31-023",
    error: "The Differences array is present in the Encoding entry in a non-symbolic TrueType font dictionary but the embedded font program does not contain a (3,1) Microsoft Unicode cmap.",
    section: "UA1:7.21.6-7",
  }
}

///|
fn pdf_ua_matterhorn_test_31_024() -> PdfUAMatterhornTest {
  {
    name: "31-024",
    error: "The Encoding entry is present in the font dictionary for a symbolic TrueType font.",
    section: "UA1:7.21.6-8",
  }
}

///|
fn pdf_ua_matterhorn_test_31_025() -> PdfUAMatterhornTest {
  {
    name: "31-025",
    error: "The embedded font program for a symbolic TrueType font contains no cmap.",
    section: "UA1:7.21.6-9",
  }
}

///|
fn pdf_ua_matterhorn_test_31_026() -> PdfUAMatterhornTest {
  {
    name: "31-026",
    error: "The embedded font program for a symbolic TrueType font contains more than one cmap, but none of the cmap entries is a (3,0) Microsoft Symbol cmap.",
    section: "UA1:7.21.6-10",
  }
}

///|
fn pdf_ua_matterhorn_test_31_027() -> PdfUAMatterhornTest {
  {
    name: "31-027",
    error: "A font dictionary does not contain the ToUnicode entry and none of the following is true: the font uses MacRomanEncoding, MacExpertEncoding or WinAnsiEncoding; the font is a Type 1 or Type 3 font and the glyph names of the glyphs referenced are all contained in the Adobe Glyph List or the set of named characters in the Symbol font, as defined in ISO 32000-1:2008, Annex D; the font is a Type 0 font, and its descendant CIDFont uses Adobe-GB1, Adobe-CNS1, Adobe-Japan1 or Adobe-Korea1 character collections; the font is a non-symbolic TrueType font.",
    section: "UA1:7.21.7-1",
  }
}

///|
fn pdf_ua_matterhorn_test_31_028() -> PdfUAMatterhornTest {
  {
    name: "31-028",
    error: "One or more Unicode values specified in the ToUnicode CMap are zero (0).",
    section: "UA1:7.21.7-2",
  }
}

///|
fn pdf_ua_matterhorn_test_31_029() -> PdfUAMatterhornTest {
  {
    name: "31-029",
    error: "One or more Unicode values specified in the ToUnicode CMap are equal to either U+FEFF or U+FFFE.",
    section: "UA1:7.21.7-3",
  }
}

///|
fn pdf_ua_matterhorn_test_31_030() -> PdfUAMatterhornTest {
  {
    name: "31-030",
    error: "One or more characters used in text showing operators reference the .notdef glyph.",
    section: "UA1:7.21.8-1",
  }
}
