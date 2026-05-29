// Whitebox tests for codec internals.
// Public codec behavior belongs in `_test.mbt` files.

///|
test "private codec dictionary and predictor guards report malformed inputs" {
  let empty = @syntax.PdfDictionary([])
  @test.assert_eq(pdf_remove_first_filter_entry(empty, pdf_filter_key()), empty)
  let bad_filter = @syntax.PdfDictionary([(pdf_filter_key(), PdfInteger(1))])
  let bad_filter_result : Result[PdfObject, Error] = try? pdf_remove_first_filter_entry(
    bad_filter,
    pdf_filter_key(),
  )
  guard bad_filter_result is Err(PdfError::FilterExpected) else {
    fail("expected PdfError::FilterExpected")
  }
  let bad_decodeparms = @syntax.PdfDictionary([
    (pdf_decodeparms_key(), PdfInteger(1)),
  ])
  let bad_decodeparms_result : Result[PdfObject, Error] = try? pdf_remove_first_decodeparms_entry(
    bad_decodeparms,
    pdf_decodeparms_key(),
  )
  guard bad_decodeparms_result is Err(PdfError::FilterExpected) else {
    fail("expected PdfError::FilterExpected")
  }
  let bad_bpp : Result[Int, Error] = try? pdf_predictor_bytes_per_pixel(0, 8)
  guard bad_bpp is Err(PdfError::PredictorExpected) else {
    fail("expected PdfError::PredictorExpected")
  }
  let bad_png_predictor : Result[Int, Error] = try? pdf_encode_png_predictor_value(
    5,
    @ascii.encode("x"),
    0,
    0,
    1,
    1,
  )
  guard bad_png_predictor is Err(PdfError::PredictorNotSupported(5)) else {
    fail("expected PdfError::PredictorNotSupported")
  }
}
