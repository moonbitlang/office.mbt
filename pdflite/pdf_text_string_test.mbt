///|
fn text_string_bytes_for_test(values : ArrayView[Int]) -> @pdflite.PdfBytes {
  try! @pdflite.pdf_bytes_of_int_array(values)
}

///|
test "pdf_utf16be_of_codepoints writes PDF Unicode strings as bytes" {
  let encoded = try! @pdflite.pdf_utf16be_of_codepoints([0x41, 0x20AC, 0x1D11E])
  @test.assert_eq(
    encoded,
    text_string_bytes_for_test([
      0xFE, 0xFF, 0x00, 0x41, 0x20, 0xAC, 0xD8, 0x34, 0xDD, 0x1E,
    ]),
  )
  @test.assert_eq(@pdflite.pdf_is_unicode_string(encoded), true)
  @test.assert_eq(try! @pdflite.pdf_codepoints_of_utf16be(encoded[2:]), [
    0x41, 0x20AC, 0x1D11E,
  ])
}

///|
test "pdf_codepoints_of_utf16be rejects malformed UTF16BE bytes" {
  let odd = try? @pdflite.pdf_codepoints_of_utf16be(
    text_string_bytes_for_test([0x00]),
  )
  guard odd is Err(InvalidUTF16BE) else {
    fail("expected @pdflite.PdfError::InvalidUTF16BE for odd byte length")
  }
  let unpaired_high = try? @pdflite.pdf_codepoints_of_utf16be(
    text_string_bytes_for_test([0xD8, 0x34, 0x00, 0x41]),
  )
  guard unpaired_high is Err(InvalidUTF16BE) else {
    fail(
      "expected @pdflite.PdfError::InvalidUTF16BE for unpaired high surrogate",
    )
  }
  let isolated_low = try? @pdflite.pdf_codepoints_of_utf16be(
    text_string_bytes_for_test([0xDD, 0x1E]),
  )
  guard isolated_low is Err(InvalidUTF16BE) else {
    fail(
      "expected @pdflite.PdfError::InvalidUTF16BE for isolated low surrogate",
    )
  }
}

///|
test "pdf_utf16be_of_codepoints rejects invalid Unicode scalar values" {
  let surrogate = try? @pdflite.pdf_utf16be_of_codepoints([0xD800])
  guard surrogate is Err(InvalidUnicodeCodepoint(0xD800)) else {
    fail(
      "expected @pdflite.PdfError::InvalidUnicodeCodepoint for surrogate scalar",
    )
  }
  let too_large = try? @pdflite.pdf_utf16be_of_codepoints([0x110000])
  guard too_large is Err(InvalidUnicodeCodepoint(0x110000)) else {
    fail(
      "expected @pdflite.PdfError::InvalidUnicodeCodepoint for out-of-range scalar",
    )
  }
}

///|
test "pdf_utf8_of_codepoints writes UTF8 bytes and roundtrips" {
  let encoded = try! @pdflite.pdf_utf8_of_codepoints([
    0x41, 0xA2, 0x20AC, 0x1D11E,
  ])
  @test.assert_eq(
    encoded,
    text_string_bytes_for_test([
      0x41, 0xC2, 0xA2, 0xE2, 0x82, 0xAC, 0xF0, 0x9D, 0x84, 0x9E,
    ]),
  )
  @test.assert_eq(try! @pdflite.pdf_codepoints_of_utf8(encoded), [
    0x41, 0xA2, 0x20AC, 0x1D11E,
  ])
}

///|
test "pdf_codepoints_of_utf8 rejects malformed UTF8 bytes" {
  let truncated = try? @pdflite.pdf_codepoints_of_utf8(
    text_string_bytes_for_test([0xE2, 0x82]),
  )
  guard truncated is Err(InvalidUTF8) else {
    fail("expected @pdflite.PdfError::InvalidUTF8 for truncated sequence")
  }
  let bad_continuation = try? @pdflite.pdf_codepoints_of_utf8(
    text_string_bytes_for_test([0xE2, 0x28, 0xAC]),
  )
  guard bad_continuation is Err(InvalidUTF8) else {
    fail("expected @pdflite.PdfError::InvalidUTF8 for bad continuation")
  }
  let overlong = try? @pdflite.pdf_codepoints_of_utf8(
    text_string_bytes_for_test([0xC0, 0x80]),
  )
  guard overlong is Err(InvalidUTF8) else {
    fail("expected @pdflite.PdfError::InvalidUTF8 for overlong sequence")
  }
  let surrogate = try? @pdflite.pdf_codepoints_of_utf8(
    text_string_bytes_for_test([0xED, 0xA0, 0x80]),
  )
  guard surrogate is Err(InvalidUnicodeCodepoint(0xD800)) else {
    fail(
      "expected @pdflite.PdfError::InvalidUnicodeCodepoint for decoded surrogate",
    )
  }
  let bad_four_byte_continuation = try? @pdflite.pdf_codepoints_of_utf8(
    text_string_bytes_for_test([0xF0, 0x9D, 0x28, 0x9E]),
  )
  guard bad_four_byte_continuation is Err(InvalidUTF8) else {
    fail(
      "expected @pdflite.PdfError::InvalidUTF8 for bad four-byte continuation",
    )
  }
  let invalid_leading_byte = try? @pdflite.pdf_codepoints_of_utf8(
    text_string_bytes_for_test([0xFF]),
  )
  guard invalid_leading_byte is Err(InvalidUTF8) else {
    fail("expected @pdflite.PdfError::InvalidUTF8 for invalid leading byte")
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
    fail("expected @pdflite.PdfError::InvalidPDFDocEncoding for undefined byte")
  }
  @test.assert_eq(
    try! @pdflite.pdf_codepoints_of_pdfdocencoding(
      text_string_bytes_for_test([0x41, 0xA0, 0x93]),
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
    Some(text_string_bytes_for_test([0x41, 0xA0, 0x93])),
  )
  @test.assert_eq(@pdflite.pdf_pdfdocencoding_of_codepoints([0x4E2D]), None)
  @test.assert_eq(
    try! @pdflite.pdf_pdfdocstring_of_codepoints([0x4E2D]),
    text_string_bytes_for_test([0xFE, 0xFF, 0x4E, 0x2D]),
  )
}

///|
test "PDF document string helpers bridge PDFDoc UTF16BE and UTF8 bytes" {
  @test.assert_eq(
    try! @pdflite.pdf_codepoints_of_pdfdocstring(
      text_string_bytes_for_test([0x41, 0xA0]),
    ),
    [0x41, 0x20AC],
  )
  @test.assert_eq(
    try! @pdflite.pdf_codepoints_of_pdfdocstring(
      text_string_bytes_for_test([0xFE, 0xFF, 0x00, 0x41, 0x20, 0xAC]),
    ),
    [0x41, 0x20AC],
  )
  @test.assert_eq(
    try! @pdflite.pdf_utf8_of_pdfdocstring(
      text_string_bytes_for_test([0x41, 0xA0]),
    ),
    text_string_bytes_for_test([0x41, 0xE2, 0x82, 0xAC]),
  )
  @test.assert_eq(
    try! @pdflite.pdf_pdfdocstring_of_utf8(
      text_string_bytes_for_test([0x41, 0xE2, 0x82, 0xAC]),
    ),
    text_string_bytes_for_test([0x41, 0xA0]),
  )
  @test.assert_eq(
    try! @pdflite.pdf_simplify_utf16be(
      text_string_bytes_for_test([0xFE, 0xFF, 0x00, 0x41, 0x20, 0xAC]),
    ),
    text_string_bytes_for_test([0x41, 0xA0]),
  )
  @test.assert_eq(
    try! @pdflite.pdf_simplify_utf16be(text_string_bytes_for_test([0x41])),
    text_string_bytes_for_test([0x41]),
  )
}
