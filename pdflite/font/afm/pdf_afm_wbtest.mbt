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
