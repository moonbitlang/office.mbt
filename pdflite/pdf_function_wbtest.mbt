// Whitebox tests for PDF function parser and evaluator internals.
// Public function behavior belongs in `_test.mbt` files.

///|
test "private function helpers cover parser and evaluator guards" {
  let doc = pdf_document_empty()

  let bad_number_array : Result[Array[Double], Error] = try
    doc.pdf_fun_number_array(PdfInteger(1))
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_number_array is Err(@core.PdfError::NumberExpected) else {
    fail("expected number-array object")
  }
  let missing_int_array : Result[Array[Int], Error] = try
    doc.pdf_fun_lookup_required_int_array(PdfDictionary([]), pdf_fun_size_key())
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard missing_int_array is Err(@core.PdfError::DictionaryKeyNotFound(name)) &&
    name == pdf_fun_size_key() else {
    fail("expected missing required int array")
  }
  let missing_int : Result[Int, Error] = try
    doc.pdf_fun_lookup_required_int(
      PdfDictionary([]),
      pdf_fun_bits_per_sample_key(),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard missing_int is Err(@core.PdfError::DictionaryKeyNotFound(name)) &&
    name == pdf_fun_bits_per_sample_key() else {
    fail("expected missing required int")
  }
  let bad_optional_int : Result[Int, Error] = try
    doc.pdf_fun_lookup_int_or(
      PdfDictionary([(pdf_fun_order_key(), PdfNameObject(pdf_fun_name("/Bad")))]),
      pdf_fun_order_key(),
      1,
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_optional_int is Err(@core.PdfError::NumberExpected) else {
    fail("expected malformed optional int")
  }
  let bad_stream : Result[@core.PdfBytes, Error] = try
    doc.pdf_fun_stream_data(PdfInteger(1))
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_stream is Err(@core.PdfError::ParseStreamExpected) else {
    fail("expected function stream")
  }
  let missing_function_type : Result[PdfFunction, Error] = try
    doc.parse_function(PdfDictionary([(pdf_fun_domain_key(), PdfArray([]))]))
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard missing_function_type
    is Err(@core.PdfError::DictionaryKeyNotFound(name)) &&
    name == pdf_fun_function_type_key() else {
    fail("expected missing function type")
  }

  @test.assert_eq(pdf_fun_clamp(-1.0, 0.0, 1.0), 0.0)
  let bad_clamp_range : Result[Array[Double], Error] = try
    pdf_fun_clamp_values([1.0], [0.0])
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_clamp_range is Err(@core.PdfError::BadFunctionEvaluation(_)) else {
    fail("expected clamp range arity failure")
  }

  let sampled : PdfSampledFunction = {
    size: [2],
    order: 1,
    encode: [0.0, 1.0],
    decode: [0.0, 1.0],
    bits_per_sample: 1,
    samples: [0, 1],
  }
  let sampled_function : PdfFunction = {
    domain: [0.0, 1.0],
    range: Some([0.0, 1.0]),
    func: PdfFunctionSampled(sampled),
  }
  let bad_sampled_input : Result[Array[Double], Error] = try
    sampled.encoded_inputs(sampled_function, [])
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_sampled_input is Err(@core.PdfError::BadFunctionEvaluation(_)) else {
    fail("expected sampled input arity failure")
  }
  let bad_table_arity : Result[Array[Double], Error] = try
    sampled.read_table([], 1)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_table_arity is Err(@core.PdfError::BadFunctionEvaluation(_)) else {
    fail("expected sampled table arity failure")
  }
  let bad_table_index : Result[Array[Double], Error] = try
    sampled.read_table([2], 1)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_table_index is Err(@core.PdfError::BadFunctionEvaluation(_)) else {
    fail("expected sampled table index failure")
  }
  let missing_sampled_range : PdfFunction = {
    domain: [0.0, 1.0],
    range: None,
    func: PdfFunctionSampled(sampled),
  }
  let missing_range : Result[Array[Double], Error] = try
    sampled.eval_sampled(missing_sampled_range, [0.0])
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard missing_range is Err(@core.PdfError::BadFunctionEvaluation(_)) else {
    fail("expected sampled range")
  }
  let bad_decode_sampled : PdfSampledFunction = {
    size: [2],
    order: 1,
    encode: [0.0, 1.0],
    decode: [0.0, 1.0, 0.0, 1.0],
    bits_per_sample: 1,
    samples: [0, 1, 0, 1],
  }
  let bad_decode : Result[Array[Double], Error] = try
    bad_decode_sampled.eval_sampled(sampled_function, [0.0])
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_decode is Err(@core.PdfError::BadFunctionEvaluation(_)) else {
    fail("expected sampled output arity failure")
  }

  let interpolation : PdfFunction = {
    domain: [0.0, 1.0],
    range: None,
    func: PdfFunctionInterpolation({ c0: [0.0], c1: [1.0], n: 1.0 }),
  }
  let stitching : PdfStitchingFunction = {
    functions: [interpolation],
    bounds: [],
    stitch_encode: [0.0, 1.0],
  }
  let stitching_function : PdfFunction = {
    domain: [0.0, 1.0],
    range: None,
    func: PdfFunctionStitching(stitching),
  }
  let stitching_arity : Result[Array[Double], Error] = try
    stitching.eval_stitching(stitching_function, [])
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard stitching_arity is Err(@core.PdfError::BadFunctionEvaluation(_)) else {
    fail("expected stitching arity failure")
  }
  let stitching_bounds : Result[Array[Double], Error] = try
    stitching.eval_stitching(stitching_function, [2.0])
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard stitching_bounds is Err(@core.PdfError::BadFunctionEvaluation(_)) else {
    fail("expected stitching bounds failure")
  }

  let bool_number : Result[Double, Error] = try
    pdf_fun_calculator_pop_number([PdfCalculatorBoolean(true)])
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bool_number is Err(@core.PdfError::BadFunctionEvaluation(_)) else {
    fail("expected calculator number")
  }
  @test.assert_eq(
    pdf_fun_calculator_values_equal(
      PdfCalculatorBoolean(true),
      PdfCalculatorBoolean(true),
    ),
    true,
  )
  @test.assert_eq(
    pdf_fun_calculator_values_equal(
      PdfCalculatorBoolean(true),
      PdfCalculatorInt(1),
    ),
    false,
  )
  @test.assert_eq(pdf_fun_calculator_int_max(), 2147483647)
  let min_abs_stack : Array[PdfCalculatorValue] = []
  try! pdf_fun_calculator_eval_operations(
    [PdfCalculatorInt(pdf_fun_calculator_int_min()), PdfCalculatorAbs],
    min_abs_stack,
  )
  guard min_abs_stack[0] is PdfCalculatorFloat(value) && value == 2147483647.0 else {
    fail("expected min-int abs to promote")
  }
  let min_neg_stack : Array[PdfCalculatorValue] = []
  try! pdf_fun_calculator_eval_operations(
    [PdfCalculatorInt(pdf_fun_calculator_int_min()), PdfCalculatorNeg],
    min_neg_stack,
  )
  guard min_neg_stack[0] is PdfCalculatorFloat(value) && value == 2147483647.0 else {
    fail("expected min-int neg to promote")
  }
}
