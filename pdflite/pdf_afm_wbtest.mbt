///|
fn afm_wb_ascii_for_test(text : String) -> PdfBytes {
  @ascii.encode(text)
}

///|
fn assert_afm_number_expected_for_test(
  result : Result[Int, Error],
) -> Unit raise {
  guard result is Err(PdfError::NumberExpected) else {
    fail("expected NumberExpected")
  }
}

///|
test "pdf_afm_parse_int handles signed values and rejects bad tokens" {
  @test.assert_eq(try! pdf_afm_parse_int(afm_wb_ascii_for_test("+42")), 42)
  assert_afm_number_expected_for_test(
    try? pdf_afm_parse_int(afm_wb_ascii_for_test("")),
  )
  assert_afm_number_expected_for_test(
    try? pdf_afm_parse_int(afm_wb_ascii_for_test("-")),
  )
  assert_afm_number_expected_for_test(
    try? pdf_afm_parse_int(afm_wb_ascii_for_test("4x")),
  )
}
