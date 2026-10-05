///|
fn afm_wb_ascii_for_test(text : String) -> PdfBytes {
  @ascii.encode(text)
}

///|
fn assert_afm_number_expected_for_test(
  result : Result[Int, Error],
) -> Unit raise {
  guard result is Err(PdfError::NumberExpected) else {
    fail("expected PdfError::NumberExpected")
  }
}

///|
test "pdf_afm_parse_int handles signed values and rejects bad tokens" {
  @test.assert_eq(try! pdf_afm_parse_int(afm_wb_ascii_for_test("+42")), 42)
  assert_afm_number_expected_for_test(
    try pdf_afm_parse_int(afm_wb_ascii_for_test("")) catch {
      err => Err(err)
    } noraise {
      value => Ok(value)
    },
  )
  assert_afm_number_expected_for_test(
    try pdf_afm_parse_int(afm_wb_ascii_for_test("-")) catch {
      err => Err(err)
    } noraise {
      value => Ok(value)
    },
  )
  assert_afm_number_expected_for_test(
    try pdf_afm_parse_int(afm_wb_ascii_for_test("4x")) catch {
      err => Err(err)
    } noraise {
      value => Ok(value)
    },
  )
}

///|
test "pdf_read_afm_kern_pairs keeps pairs of unencoded glyphs" {
  let afm = afm_wb_ascii_for_test(
    (
      #|StartFontMetrics 4.1
      #|FontName Test
      #|StartCharMetrics 3
      #|C 65 ; WX 667 ; N A ; B 14 0 654 718 ;
      #|C 86 ; WX 667 ; N V ; B 14 0 653 718 ;
      #|C -1 ; WX 556 ; N eacute ; B 40 -15 516 734 ;
      #|EndCharMetrics
      #|StartKernPairs 3
      #|Comment a comment line among the pairs
      #|
      #|KPY A V 5
      #|KPX A V -70
      #|KPX V eacute -60
      #|KPX eacute V -15
      #|EndKernPairs
      #|EndFontMetrics
    ),
  )
  let pairs = pdf_read_afm_kern_pairs(afm).map(p => {
    (@ascii.decode(p.0), @ascii.decode(p.1), p.2)
  })
  @debug.debug_inspect(
    pairs,
    content=(
      #|[("A", "V", -70), ("V", "eacute", -60), ("eacute", "V", -15)]
    ),
  )
  // the code-keyed table keeps only the pair of encoded glyphs
  @debug.debug_inspect(
    (try! pdf_read_afm(afm)).kerns,
    content="[(65, 86, -70)]",
  )
  let malformed = afm_wb_ascii_for_test(
    (
      #|StartKernPairs 1
      #|KPX
      #|EndKernPairs
    ),
  )
  try pdf_read_afm_kern_pairs(malformed) catch {
    AfmExpected => ()
    _ => fail("expected AfmExpected")
  } noraise {
    _ => fail("expected AfmExpected")
  }
}
