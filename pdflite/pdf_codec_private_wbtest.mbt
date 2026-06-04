// Whitebox tests for codec internals.
// Public codec behavior belongs in `_test.mbt` files.

///|
test "private codec dictionary and predictor guards report malformed inputs" {
  let empty = @syntax.PdfDictionary([])
  @test.assert_eq(pdf_remove_first_filter_entry(empty, pdf_filter_key()), empty)
  let bad_filter = @syntax.PdfDictionary([(pdf_filter_key(), PdfInteger(1))])
  let bad_filter_result : Result[@syntax.PdfObject, Error] = try
    pdf_remove_first_filter_entry(bad_filter, pdf_filter_key())
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_filter_result is Err(@core.PdfError::FilterExpected) else {
    fail("expected @core.PdfError::FilterExpected")
  }
  let bad_decodeparms = @syntax.PdfDictionary([
    (pdf_decodeparms_key(), PdfInteger(1)),
  ])
  let bad_decodeparms_result : Result[@syntax.PdfObject, Error] = try
    pdf_remove_first_decodeparms_entry(bad_decodeparms, pdf_decodeparms_key())
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_decodeparms_result is Err(@core.PdfError::FilterExpected) else {
    fail("expected @core.PdfError::FilterExpected")
  }
  let bad_bpp : Result[Int, Error] = try
    pdf_predictor_bytes_per_pixel(0, 8)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_bpp is Err(@core.PdfError::PredictorExpected) else {
    fail("expected @core.PdfError::PredictorExpected")
  }
  let bad_png_predictor : Result[Int, Error] = try
    pdf_encode_png_predictor_value(5, @ascii.encode("x"), 0, 0, 1, 1)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_png_predictor is Err(@core.PdfError::PredictorNotSupported(5)) else {
    fail("expected @core.PdfError::PredictorNotSupported")
  }
}
