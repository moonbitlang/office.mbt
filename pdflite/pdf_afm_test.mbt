///|
fn afm_ascii_for_test(text : String) -> @pdflite.PdfBytes {
  @ascii.encode(text)
}

///|
fn afm_bytes_for_test(values : ArrayView[Int]) -> @pdflite.PdfBytes {
  try! @pdflite.pdf_bytes_of_int_array(values)
}

///|
fn afm_concat_for_test(
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
test "pdf_read_afm parses headers widths names and kerning" {
  let afm = afm_ascii_for_test(
    "\r\n" +
    "StartFontMetrics 4.1\r\n" +
    "FontName TestFont\r\n" +
    "StartCharMetrics 3\r\n" +
    "C 32 ; WX 250 ; N space ; B 0 0 0 0 ;\r\n" +
    "C 65 ; WX 600 ; N A ; B 0 0 0 0 ;\r\n" +
    "C -1 ; WX 700 ; N A.alt ; B 0 0 0 0 ;\r\n" +
    "EndCharMetrics\r\n" +
    "StartKernPairs 2\r\n" +
    "KPX A space -20\r\n" +
    "KPX A.alt A -10\r\n" +
    "EndKernPairs\r\n" +
    "EndFontMetrics\r\n",
  )
  let parsed = try! @afm.pdf_read_afm(afm)
  @test.assert_eq(parsed.headers.length(), 3)
  @test.assert_eq(
    parsed.headers[0],
    (afm_ascii_for_test("StartFontMetrics"), afm_ascii_for_test("4.1")),
  )
  @test.assert_eq(
    parsed.headers[1],
    (afm_ascii_for_test("FontName"), afm_ascii_for_test("TestFont")),
  )
  @test.assert_eq(
    parsed.headers[2],
    (afm_ascii_for_test("StartCharMetrics"), afm_ascii_for_test("3")),
  )
  @test.assert_eq(parsed.char_metrics, [(32, 250), (65, 600)])
  @test.assert_eq(parsed.char_name_widths, [
    (afm_ascii_for_test("space"), 250),
    (afm_ascii_for_test("A"), 600),
    (afm_ascii_for_test("A.alt"), 700),
  ])
  @test.assert_eq(parsed.kerns, [(65, 32, -20)])
}

///|
test "pdf_read_afm preserves non UTF-8 glyph names as bytes" {
  let glyph = afm_bytes_for_test([0xFF, 0x67])
  let afm = afm_concat_for_test([
    afm_ascii_for_test("StartCharMetrics 1\nC +66 ; WX 610 ; N "),
    glyph,
    afm_ascii_for_test(" ; B 0 0 0 0 ;\nEndCharMetrics\n"),
  ])
  let parsed = try! @afm.pdf_read_afm(afm)
  @test.assert_eq(parsed.char_metrics, [(66, 610)])
  @test.assert_eq(parsed.char_name_widths, [(glyph, 610)])
}

///|
test "pdf_read_afm rejects malformed metric and kern rows" {
  let bad_metric = afm_ascii_for_test(
    "StartCharMetrics 1\nC 65 ; BAD 600 ; N A ;\nEndCharMetrics\n",
  )
  let metric_result : Result[@afm.PdfAfmData, Error] = try? @afm.pdf_read_afm(
    bad_metric,
  )
  guard metric_result is Err(@pdflite.PdfError::AfmExpected) else {
    fail("expected @pdflite.PdfError::AfmExpected for bad metric row")
  }
  let missing_name = afm_ascii_for_test(
    "StartCharMetrics 1\nC 65 ; WX 600 ; N\nEndCharMetrics\n",
  )
  let missing_name_result : Result[@afm.PdfAfmData, Error] = try? @afm.pdf_read_afm(
    missing_name,
  )
  guard missing_name_result is Err(@pdflite.PdfError::AfmExpected) else {
    fail("expected @pdflite.PdfError::AfmExpected for incomplete metric row")
  }

  let bad_kern = afm_ascii_for_test(
    "StartCharMetrics 1\n" +
    "C 65 ; WX 600 ; N A ;\n" +
    "EndCharMetrics\n" +
    "StartKernPairs 1\n" +
    "KPX A Missing -20\n" +
    "EndKernPairs\n",
  )
  let kern_result : Result[@afm.PdfAfmData, Error] = try? @afm.pdf_read_afm(
    bad_kern,
  )
  guard kern_result is Err(@pdflite.PdfError::AfmExpected) else {
    fail("expected @pdflite.PdfError::AfmExpected for bad kern row")
  }

  let bad_kern_operator = afm_ascii_for_test(
    "StartCharMetrics 1\n" +
    "C 65 ; WX 600 ; N A ;\n" +
    "EndCharMetrics\n" +
    "StartKernPairs 1\n" +
    "BAD A A -20\n" +
    "EndKernPairs\n",
  )
  let kern_operator_result : Result[@afm.PdfAfmData, Error] = try? @afm.pdf_read_afm(
    bad_kern_operator,
  )
  guard kern_operator_result is Err(@pdflite.PdfError::AfmExpected) else {
    fail("expected @pdflite.PdfError::AfmExpected for bad kern operator")
  }
}
