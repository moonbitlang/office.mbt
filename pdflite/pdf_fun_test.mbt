///|
fn fun_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn fun_bytes_for_test(values : ArrayView[Int]) -> @pdflite.PdfBytes {
  try! @pdflite.pdf_bytes_of_int_array(values)
}

///|
fn fun_type4_for_test(calculator : @pdflite.PdfBytes) -> @pdflite.PdfObject {
  @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (fun_name_for_test("/Length"), PdfInteger(calculator.length())),
      (fun_name_for_test("/FunctionType"), PdfInteger(4)),
      (fun_name_for_test("/Domain"), PdfArray([])),
    ]),
    StreamGot(calculator),
  )
}

///|
test "PdfCalculatorOp debug strings preserve CamlPDF calculator syntax" {
  @test.assert_eq(
    @pdflite.pdf_string_of_calculator([
      PdfCalculatorIf([PdfCalculatorInt(1), PdfCalculatorAdd]),
      PdfCalculatorIfElse([PdfCalculatorBool(true)], [PdfCalculatorFloat(2.5)]),
      PdfCalculatorBool(false),
      PdfCalculatorFloat(1.5),
      PdfCalculatorInt(-7),
      PdfCalculatorAbs,
      PdfCalculatorAdd,
      PdfCalculatorAtan,
      PdfCalculatorCeiling,
      PdfCalculatorCos,
      PdfCalculatorCvi,
      PdfCalculatorCvr,
      PdfCalculatorDiv,
      PdfCalculatorExp,
      PdfCalculatorFloor,
      PdfCalculatorIdiv,
      PdfCalculatorLn,
      PdfCalculatorLog,
      PdfCalculatorMod,
      PdfCalculatorMul,
      PdfCalculatorNeg,
      PdfCalculatorRound,
      PdfCalculatorSin,
      PdfCalculatorSqrt,
      PdfCalculatorSub,
      PdfCalculatorTruncate,
      PdfCalculatorAnd,
      PdfCalculatorBitshift,
      PdfCalculatorEq,
      PdfCalculatorGe,
      PdfCalculatorGt,
      PdfCalculatorLe,
      PdfCalculatorLt,
      PdfCalculatorNe,
      PdfCalculatorNot,
      PdfCalculatorOr,
      PdfCalculatorXor,
      PdfCalculatorCopy,
      PdfCalculatorExch,
      PdfCalculatorPop,
      PdfCalculatorDup,
      PdfCalculatorIndex,
      PdfCalculatorRoll,
    ]),
    "{{1 add} if {true} {2.5} ifelse false 1.5 -7 abs add atan ceiling cos cvi cvr div exp floor idiv ln log mod mul neg round sin sqrt sub truncate and bitshift eq ge gt le lt ne not or xor copy exch pop dup index roll}",
  )
  let sqrt_op : @pdflite.PdfCalculatorOp = PdfCalculatorSqrt
  @test.assert_eq(sqrt_op.debug_name(), "sqrt")
  @test.assert_eq(@pdflite.pdf_string_of_calculator([]), "{}")
}

///|
test "PdfFunction debug strings cover all CamlPDF function kinds" {
  let interpolation : @pdflite.PdfFunction = {
    func: PdfFunctionInterpolation({ c0: [0.0], c1: [1.0], n: 2.0 }),
    domain: [0.0, 1.0],
    range: Some([0.0, 1.0]),
  }
  @test.assert_eq(
    @pdflite.pdf_string_of_function(interpolation),
    "Domain...\n0 1\n0 1\nInterpolation\nC0:\n0\nC1:\n1\nn = 2",
  )
  @test.assert_eq(
    interpolation.debug_string(),
    @pdflite.pdf_string_of_function(interpolation),
  )
  let sampled : @pdflite.PdfFunction = {
    func: PdfFunctionSampled({
      size: [2],
      order: 1,
      encode: [0.0, 1.0],
      decode: [0.0, 255.0],
      bits_per_sample: 8,
      samples: [0, 255],
    }),
    domain: [0.0, 1.0],
    range: None,
  }
  @test.assert_eq(
    sampled.debug_string(),
    "Domain...\n0 1\nnull range\nSampled\nsize: 2\norder: 1\nencode:\n0 1\ndecode:\n0 255\noriginal bits per sample..\n8\ndata:\n0 255",
  )
  let calculator : @pdflite.PdfFunction = {
    func: PdfFunctionCalculator({
      operations: [PdfCalculatorInt(1), PdfCalculatorAdd],
    }),
    domain: [],
    range: Some([]),
  }
  @test.assert_eq(
    calculator.debug_string(),
    "Domain...\n\n\nCalculator:\n{1 add}",
  )
  let stitching : @pdflite.PdfFunction = {
    func: PdfFunctionStitching({
      functions: [interpolation, calculator],
      bounds: [0.5],
      stitch_encode: [0.0, 1.0, 1.0, 0.0],
    }),
    domain: [0.0, 1.0],
    range: Some([0.0, 1.0]),
  }
  @test.assert_eq(
    stitching.debug_string(),
    "Domain...\n0 1\n0 1\nStitching\nDomain...\n0 1\n0 1\nInterpolation\nC0:\n0\nC1:\n1\nn = 2\nDomain...\n\n\nCalculator:\n{1 add}\nBounds:\n0.5\nEncode:\n0 1 1 0",
  )
}

///|
test "standalone pdffun helpers parse evaluate serialize and print functions" {
  let doc = @pdflite.pdf_document_empty()
  let function_object = @pdflite.pdf_dictionary([
    (fun_name_for_test("/FunctionType"), PdfInteger(2)),
    (fun_name_for_test("/Domain"), PdfArray([PdfInteger(0), PdfInteger(1)])),
    (fun_name_for_test("/Range"), PdfArray([PdfInteger(0), PdfInteger(2)])),
    (fun_name_for_test("/C0"), PdfArray([PdfInteger(0)])),
    (fun_name_for_test("/C1"), PdfArray([PdfInteger(2)])),
    (fun_name_for_test("/N"), PdfInteger(1)),
  ])
  let function = @pdflite.pdf_parse_function(doc, function_object)
  @test.assert_eq(@pdflite.pdf_eval_function(function, [0.25]), [0.5])
  @test.assert_eq(
    @pdflite.pdf_object_of_function(doc, function),
    @pdflite.pdf_dictionary([
      (fun_name_for_test("/FunctionType"), PdfInteger(2)),
      (fun_name_for_test("/Domain"), PdfArray([PdfReal(0.0), PdfReal(1.0)])),
      (fun_name_for_test("/Range"), PdfArray([PdfReal(0.0), PdfReal(2.0)])),
      (fun_name_for_test("/C0"), PdfArray([PdfReal(0.0)])),
      (fun_name_for_test("/C1"), PdfArray([PdfReal(2.0)])),
      (fun_name_for_test("/N"), PdfReal(1.0)),
    ]),
  )
  @test.assert_eq(
    @pdflite.pdf_string_of_function(function),
    "Domain...\n0 1\n0 2\nInterpolation\nC0:\n0\nC1:\n2\nn = 1",
  )
  @pdflite.pdf_print_function(function)
}

///|
test "PdfDocument parse_function reads and evaluates Type 0 sampled functions" {
  let doc = @pdflite.pdf_document_empty()
  let samples = fun_bytes_for_test([0x0F])
  let function_object = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (fun_name_for_test("/Length"), PdfInteger(samples.length())),
      (fun_name_for_test("/FunctionType"), PdfInteger(0)),
      (fun_name_for_test("/Domain"), PdfArray([PdfInteger(0), PdfInteger(1)])),
      (fun_name_for_test("/Range"), PdfArray([PdfInteger(0), PdfInteger(1)])),
      (fun_name_for_test("/Size"), PdfArray([PdfInteger(2)])),
      (fun_name_for_test("/BitsPerSample"), PdfInteger(4)),
    ]),
    StreamGot(samples),
  )
  let function = try! doc.parse_function(function_object)
  @test.assert_eq(try! function.eval([0.0]), [0.0])
  @test.assert_eq(try! function.eval([0.5]), [0.5])
  @test.assert_eq(try! function.eval([1.0]), [1.0])
}

///|
test "PdfDocument parse_function decodes filtered sampled function streams" {
  let doc = @pdflite.pdf_document_empty()
  let encoded = @pdflite.pdf_flate_encode(fun_bytes_for_test([0xF0]))
  let function_object = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (fun_name_for_test("/Length"), PdfInteger(encoded.length())),
      (fun_name_for_test("/FunctionType"), PdfInteger(0)),
      (fun_name_for_test("/Domain"), PdfArray([PdfInteger(0), PdfInteger(1)])),
      (fun_name_for_test("/Range"), PdfArray([PdfInteger(0), PdfInteger(1)])),
      (fun_name_for_test("/Size"), PdfArray([PdfInteger(2)])),
      (fun_name_for_test("/BitsPerSample"), PdfInteger(4)),
      (
        fun_name_for_test("/Filter"),
        PdfNameObject(fun_name_for_test("/FlateDecode")),
      ),
    ]),
    StreamGot(encoded),
  )
  let function = try! doc.parse_function(function_object)
  @test.assert_eq(try! function.eval([0.0]), [1.0])
  @test.assert_eq(try! function.eval([1.0]), [0.0])
  doc.add_object_given_number(
    8,
    PdfNameObject(fun_name_for_test("/FlateDecode")),
  )
  let function_object = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (fun_name_for_test("/Length"), PdfInteger(encoded.length())),
      (fun_name_for_test("/FunctionType"), PdfInteger(0)),
      (fun_name_for_test("/Domain"), PdfArray([PdfInteger(0), PdfInteger(1)])),
      (fun_name_for_test("/Range"), PdfArray([PdfInteger(0), PdfInteger(1)])),
      (fun_name_for_test("/Size"), PdfArray([PdfInteger(2)])),
      (fun_name_for_test("/BitsPerSample"), PdfInteger(4)),
      (fun_name_for_test("/Filter"), PdfIndirect(8)),
    ]),
    StreamGot(encoded),
  )
  let function = try! doc.parse_function(function_object)
  @test.assert_eq(try! function.eval([0.0]), [1.0])
  @test.assert_eq(try! function.eval([1.0]), [0.0])
}

///|
test "PdfDocument parse_function reads and evaluates Type 3 stitching functions" {
  let doc = @pdflite.pdf_document_empty()
  let first = @pdflite.pdf_dictionary([
    (fun_name_for_test("/FunctionType"), PdfInteger(2)),
    (fun_name_for_test("/Domain"), PdfArray([PdfInteger(0), PdfInteger(1)])),
    (fun_name_for_test("/C0"), PdfArray([PdfInteger(0)])),
    (fun_name_for_test("/C1"), PdfArray([PdfInteger(0)])),
    (fun_name_for_test("/N"), PdfInteger(1)),
  ])
  let second = @pdflite.pdf_dictionary([
    (fun_name_for_test("/FunctionType"), PdfInteger(2)),
    (fun_name_for_test("/Domain"), PdfArray([PdfInteger(0), PdfInteger(1)])),
    (fun_name_for_test("/C0"), PdfArray([PdfInteger(1)])),
    (fun_name_for_test("/C1"), PdfArray([PdfInteger(1)])),
    (fun_name_for_test("/N"), PdfInteger(1)),
  ])
  let function_object = @pdflite.pdf_dictionary([
    (fun_name_for_test("/FunctionType"), PdfInteger(3)),
    (fun_name_for_test("/Domain"), PdfArray([PdfInteger(0), PdfInteger(1)])),
    (fun_name_for_test("/Range"), PdfArray([PdfInteger(0), PdfInteger(1)])),
    (fun_name_for_test("/Functions"), PdfArray([first, second])),
    (fun_name_for_test("/Bounds"), PdfArray([PdfReal(0.5)])),
    (
      fun_name_for_test("/Encode"),
      PdfArray([PdfInteger(0), PdfInteger(1), PdfInteger(0), PdfInteger(1)]),
    ),
  ])
  let function = try! doc.parse_function(function_object)
  @test.assert_eq(try! function.eval([0.25]), [0.0])
  @test.assert_eq(try! function.eval([0.5]), [0.0])
  @test.assert_eq(try! function.eval([0.75]), [1.0])
}

///|
test "PdfDocument pdf_object_of_function writes interpolation functions" {
  let doc = @pdflite.pdf_document_empty()
  let function : @pdflite.PdfFunction = {
    domain: [0.0, 1.0],
    range: Some([0.0, 2.0]),
    func: PdfFunctionInterpolation({ c0: [0.0], c1: [2.0], n: 1.0 }),
  }
  let object = doc.pdf_object_of_function(function)
  @test.assert_eq(
    object,
    @pdflite.pdf_dictionary([
      (fun_name_for_test("/FunctionType"), PdfInteger(2)),
      (fun_name_for_test("/Domain"), PdfArray([PdfReal(0.0), PdfReal(1.0)])),
      (fun_name_for_test("/Range"), PdfArray([PdfReal(0.0), PdfReal(2.0)])),
      (fun_name_for_test("/C0"), PdfArray([PdfReal(0.0)])),
      (fun_name_for_test("/C1"), PdfArray([PdfReal(2.0)])),
      (fun_name_for_test("/N"), PdfReal(1.0)),
    ]),
  )
  let parsed = try! doc.parse_function(object)
  @test.assert_eq(parsed, function)
  @test.assert_eq(try! parsed.eval([0.5]), [1.0])
}

///|
test "PdfDocument pdf_object_of_function writes stitching child objects" {
  let doc = @pdflite.pdf_document_empty()
  let first : @pdflite.PdfFunction = {
    domain: [0.0, 1.0],
    range: None,
    func: PdfFunctionInterpolation({ c0: [0.0], c1: [0.0], n: 1.0 }),
  }
  let second : @pdflite.PdfFunction = {
    domain: [0.0, 1.0],
    range: None,
    func: PdfFunctionInterpolation({ c0: [1.0], c1: [1.0], n: 1.0 }),
  }
  let function : @pdflite.PdfFunction = {
    domain: [0.0, 1.0],
    range: Some([0.0, 1.0]),
    func: PdfFunctionStitching({
      functions: [first, second],
      bounds: [0.5],
      stitch_encode: [0.0, 1.0, 0.0, 1.0],
    }),
  }
  let object = doc.pdf_object_of_function(function)
  @test.assert_eq(
    object,
    @pdflite.pdf_dictionary([
      (fun_name_for_test("/FunctionType"), PdfInteger(3)),
      (fun_name_for_test("/Domain"), PdfArray([PdfReal(0.0), PdfReal(1.0)])),
      (fun_name_for_test("/Range"), PdfArray([PdfReal(0.0), PdfReal(1.0)])),
      (
        fun_name_for_test("/Functions"),
        PdfArray([PdfIndirect(1), PdfIndirect(2)]),
      ),
      (fun_name_for_test("/Bounds"), PdfArray([PdfReal(0.5)])),
      (
        fun_name_for_test("/Encode"),
        PdfArray([PdfReal(0.0), PdfReal(1.0), PdfReal(0.0), PdfReal(1.0)]),
      ),
    ]),
  )
  @test.assert_eq(
    doc.lookup_object_or_null(1),
    @pdflite.pdf_dictionary([
      (fun_name_for_test("/FunctionType"), PdfInteger(2)),
      (fun_name_for_test("/Domain"), PdfArray([PdfReal(0.0), PdfReal(1.0)])),
      (fun_name_for_test("/C0"), PdfArray([PdfReal(0.0)])),
      (fun_name_for_test("/C1"), PdfArray([PdfReal(0.0)])),
      (fun_name_for_test("/N"), PdfReal(1.0)),
    ]),
  )
  @test.assert_eq(
    doc.lookup_object_or_null(2),
    @pdflite.pdf_dictionary([
      (fun_name_for_test("/FunctionType"), PdfInteger(2)),
      (fun_name_for_test("/Domain"), PdfArray([PdfReal(0.0), PdfReal(1.0)])),
      (fun_name_for_test("/C0"), PdfArray([PdfReal(1.0)])),
      (fun_name_for_test("/C1"), PdfArray([PdfReal(1.0)])),
      (fun_name_for_test("/N"), PdfReal(1.0)),
    ]),
  )
  let parsed = try! doc.parse_function(object)
  @test.assert_eq(try! parsed.eval([0.25]), [0.0])
  @test.assert_eq(try! parsed.eval([0.75]), [1.0])
}

///|
test "PdfDocument pdf_object_of_function writes sampled and calculator common entries" {
  let doc = @pdflite.pdf_document_empty()
  let sampled : @pdflite.PdfFunction = {
    domain: [0.0, 1.0],
    range: Some([0.0, 1.0]),
    func: PdfFunctionSampled({
      size: [2],
      order: 1,
      encode: [0.0, 1.0],
      decode: [0.0, 1.0],
      bits_per_sample: 8,
      samples: [0, 255],
    }),
  }
  @test.assert_eq(
    doc.pdf_object_of_function(sampled),
    @pdflite.pdf_dictionary([
      (fun_name_for_test("/FunctionType"), PdfInteger(0)),
      (fun_name_for_test("/Domain"), PdfArray([PdfReal(0.0), PdfReal(1.0)])),
      (fun_name_for_test("/Range"), PdfArray([PdfReal(0.0), PdfReal(1.0)])),
    ]),
  )
  let calculator : @pdflite.PdfFunction = {
    domain: [],
    range: None,
    func: PdfFunctionCalculator({
      operations: [PdfCalculatorInt(1), PdfCalculatorAdd],
    }),
  }
  @test.assert_eq(
    doc.pdf_object_of_function(calculator),
    @pdflite.pdf_dictionary([
      (fun_name_for_test("/FunctionType"), PdfInteger(4)),
      (fun_name_for_test("/Domain"), PdfArray([])),
    ]),
  )
}

///|
test "PdfDocument parse_function reads simple Type 4 calculator functions" {
  let doc = @pdflite.pdf_document_empty()
  let calculator = @ascii.encode("{ 2 mul 1 add }")
  let function_object = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (fun_name_for_test("/Length"), PdfInteger(calculator.length())),
      (fun_name_for_test("/FunctionType"), PdfInteger(4)),
      (fun_name_for_test("/Domain"), PdfArray([PdfInteger(0), PdfInteger(1)])),
      (fun_name_for_test("/Range"), PdfArray([PdfInteger(0), PdfInteger(3)])),
    ]),
    StreamGot(calculator),
  )
  let function = try! doc.parse_function(function_object)
  @test.assert_eq(try! function.eval([0.5]), [2.0])
}

///|
test "PdfDocument parse_function ignores Type 4 calculator comments" {
  let doc = @pdflite.pdf_document_empty()
  let calculator = @ascii.encode("{ 2 % ignored add\n mul 1 add }")
  let function_object = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (fun_name_for_test("/Length"), PdfInteger(calculator.length())),
      (fun_name_for_test("/FunctionType"), PdfInteger(4)),
      (fun_name_for_test("/Domain"), PdfArray([PdfInteger(0), PdfInteger(1)])),
      (fun_name_for_test("/Range"), PdfArray([PdfInteger(0), PdfInteger(3)])),
    ]),
    StreamGot(calculator),
  )
  let function = try! doc.parse_function(function_object)
  @test.assert_eq(try! function.eval([0.5]), [2.0])
}

///|
test "PdfDocument parse_function salvages doubled-minus calculator numbers" {
  let doc = @pdflite.pdf_document_empty()
  let calculator = @ascii.encode("{ --2 mul --1.5 add }")
  let function_object = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (fun_name_for_test("/Length"), PdfInteger(calculator.length())),
      (fun_name_for_test("/FunctionType"), PdfInteger(4)),
      (fun_name_for_test("/Domain"), PdfArray([PdfInteger(0), PdfInteger(1)])),
      (fun_name_for_test("/Range"), PdfArray([PdfInteger(-3), PdfInteger(0)])),
    ]),
    StreamGot(calculator),
  )
  let function = try! doc.parse_function(function_object)
  @test.assert_eq(try! function.eval([0.5]), [-2.5])
}

///|
test "PdfDocument parse_function evaluates calculator functions with multiple inputs" {
  let doc = @pdflite.pdf_document_empty()
  let calculator = @ascii.encode("{ add }")
  let function_object = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (fun_name_for_test("/Length"), PdfInteger(calculator.length())),
      (fun_name_for_test("/FunctionType"), PdfInteger(4)),
      (
        fun_name_for_test("/Domain"),
        PdfArray([PdfInteger(0), PdfInteger(1), PdfInteger(0), PdfInteger(1)]),
      ),
      (fun_name_for_test("/Range"), PdfArray([PdfInteger(0), PdfInteger(2)])),
    ]),
    StreamGot(calculator),
  )
  let function = try! doc.parse_function(function_object)
  @test.assert_eq(try! function.eval([0.25, 0.5]), [0.75])
}

///|
test "PdfDocument parse_function evaluates unary calculator operators" {
  let doc = @pdflite.pdf_document_empty()
  let calculator = @ascii.encode("{ neg abs sqrt }")
  let function_object = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (fun_name_for_test("/Length"), PdfInteger(calculator.length())),
      (fun_name_for_test("/FunctionType"), PdfInteger(4)),
      (fun_name_for_test("/Domain"), PdfArray([PdfInteger(0), PdfInteger(1)])),
      (fun_name_for_test("/Range"), PdfArray([PdfInteger(0), PdfInteger(1)])),
    ]),
    StreamGot(calculator),
  )
  let function = try! doc.parse_function(function_object)
  @test.assert_eq(try! function.eval([0.25]), [0.5])
}

///|
test "PdfDocument parse_function evaluates numeric calculator operators" {
  let doc = @pdflite.pdf_document_empty()
  let calculator = @ascii.encode(
    "{ 3.8 floor 2.1 ceiling add 2 exp 10 log add 1.5 truncate add }",
  )
  let function_object = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (fun_name_for_test("/Length"), PdfInteger(calculator.length())),
      (fun_name_for_test("/FunctionType"), PdfInteger(4)),
      (fun_name_for_test("/Domain"), PdfArray([])),
      (fun_name_for_test("/Range"), PdfArray([PdfInteger(0), PdfInteger(40)])),
    ]),
    StreamGot(calculator),
  )
  let function = try! doc.parse_function(function_object)
  @test.assert_eq(try! function.eval([]), [38.0])
}

///|
test "PdfDocument parse_function evaluates remaining numeric calculator operators" {
  let doc = @pdflite.pdf_document_empty()
  let calculator = @ascii.encode(
    "{ 90 sin 0 cos 1 0 atan 2.6 round 2.9 cvi 2 cvr 7 3 idiv 7 3 mod 1 ln }",
  )
  let function_object = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (fun_name_for_test("/Length"), PdfInteger(calculator.length())),
      (fun_name_for_test("/FunctionType"), PdfInteger(4)),
      (fun_name_for_test("/Domain"), PdfArray([])),
    ]),
    StreamGot(calculator),
  )
  let function = try! doc.parse_function(function_object)
  @test.assert_eq(try! function.eval([]), [
    1.0, 1.0, 90.0, 3.0, 2.0, 2.0, 2.0, 1.0, 0.0,
  ])
}

///|
test "PdfDocument parse_function evaluates calculator stack operators" {
  let doc = @pdflite.pdf_document_empty()
  let calculator = @ascii.encode("{ dup 1 index add exch pop }")
  let function_object = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (fun_name_for_test("/Length"), PdfInteger(calculator.length())),
      (fun_name_for_test("/FunctionType"), PdfInteger(4)),
      (fun_name_for_test("/Domain"), PdfArray([PdfInteger(0), PdfInteger(1)])),
      (fun_name_for_test("/Range"), PdfArray([PdfInteger(0), PdfInteger(1)])),
    ]),
    StreamGot(calculator),
  )
  let function = try! doc.parse_function(function_object)
  @test.assert_eq(try! function.eval([0.25]), [0.5])
}

///|
test "PdfDocument parse_function evaluates calculator copy and roll operators" {
  let doc = @pdflite.pdf_document_empty()
  let copy_calculator = @ascii.encode("{ 2 3 2 copy add add add }")
  let copy_function_object = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (fun_name_for_test("/Length"), PdfInteger(copy_calculator.length())),
      (fun_name_for_test("/FunctionType"), PdfInteger(4)),
      (fun_name_for_test("/Domain"), PdfArray([])),
      (fun_name_for_test("/Range"), PdfArray([PdfInteger(0), PdfInteger(20)])),
    ]),
    StreamGot(copy_calculator),
  )
  let copy_function = try! doc.parse_function(copy_function_object)
  @test.assert_eq(try! copy_function.eval([]), [10.0])
  let roll_calculator = @ascii.encode("{ 1 2 3 3 1 roll sub sub }")
  let roll_function_object = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (fun_name_for_test("/Length"), PdfInteger(roll_calculator.length())),
      (fun_name_for_test("/FunctionType"), PdfInteger(4)),
      (fun_name_for_test("/Domain"), PdfArray([])),
      (fun_name_for_test("/Range"), PdfArray([PdfInteger(0), PdfInteger(10)])),
    ]),
    StreamGot(roll_calculator),
  )
  let roll_function = try! doc.parse_function(roll_function_object)
  @test.assert_eq(try! roll_function.eval([]), [4.0])
}

///|
test "PdfDocument parse_function evaluates calculator ifelse procedures" {
  let doc = @pdflite.pdf_document_empty()
  let calculator = @ascii.encode("{ dup 0.5 lt { 0 } { 1 } ifelse exch pop }")
  let function_object = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (fun_name_for_test("/Length"), PdfInteger(calculator.length())),
      (fun_name_for_test("/FunctionType"), PdfInteger(4)),
      (fun_name_for_test("/Domain"), PdfArray([PdfInteger(0), PdfInteger(1)])),
      (fun_name_for_test("/Range"), PdfArray([PdfInteger(0), PdfInteger(1)])),
    ]),
    StreamGot(calculator),
  )
  let function = try! doc.parse_function(function_object)
  @test.assert_eq(try! function.eval([0.25]), [0.0])
  @test.assert_eq(try! function.eval([0.75]), [1.0])
}

///|
test "PdfDocument parse_function evaluates calculator if and boolean operators" {
  let doc = @pdflite.pdf_document_empty()
  let calculator = @ascii.encode("{ dup 0.5 ge true and { 2 mul } if }")
  let function_object = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (fun_name_for_test("/Length"), PdfInteger(calculator.length())),
      (fun_name_for_test("/FunctionType"), PdfInteger(4)),
      (fun_name_for_test("/Domain"), PdfArray([PdfInteger(0), PdfInteger(1)])),
      (fun_name_for_test("/Range"), PdfArray([PdfInteger(0), PdfInteger(2)])),
    ]),
    StreamGot(calculator),
  )
  let function = try! doc.parse_function(function_object)
  @test.assert_eq(try! function.eval([0.25]), [0.25])
  @test.assert_eq(try! function.eval([0.75]), [1.5])
}

///|
test "PdfDocument parse_function evaluates integer calculator operators" {
  let doc = @pdflite.pdf_document_empty()
  let calculator = @ascii.encode(
    "{ 6 3 and 8 1 bitshift or 3 xor 0 not 0 ne { 1 } { 0 } ifelse exch pop }",
  )
  let function_object = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (fun_name_for_test("/Length"), PdfInteger(calculator.length())),
      (fun_name_for_test("/FunctionType"), PdfInteger(4)),
      (fun_name_for_test("/Domain"), PdfArray([])),
      (fun_name_for_test("/Range"), PdfArray([PdfInteger(0), PdfInteger(1)])),
    ]),
    StreamGot(calculator),
  )
  let function = try! doc.parse_function(function_object)
  @test.assert_eq(try! function.eval([]), [1.0])
}

///|
test "PdfDocument parse_function evaluates calculator bitshift directions" {
  let doc = @pdflite.pdf_document_empty()
  let calculator = @ascii.encode(
    "{ 1 5 bitshift 32 -2 bitshift -8 -1 bitshift 1 32 bitshift }",
  )
  let function_object = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (fun_name_for_test("/Length"), PdfInteger(calculator.length())),
      (fun_name_for_test("/FunctionType"), PdfInteger(4)),
      (fun_name_for_test("/Domain"), PdfArray([])),
    ]),
    StreamGot(calculator),
  )
  let function = try! doc.parse_function(function_object)
  @test.assert_eq(try! function.eval([]), [32.0, 8.0, 2147483644.0, 1.0])
}

///|
test "PdfDocument parse_function preserves calculator integer value semantics" {
  let doc = @pdflite.pdf_document_empty()
  let calculator = @ascii.encode(
    "{ 2147483647 1 add -2147483647 2 sub 65536 65536 mul -2.1 cvi }",
  )
  let function_object = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (fun_name_for_test("/Length"), PdfInteger(calculator.length())),
      (fun_name_for_test("/FunctionType"), PdfInteger(4)),
      (fun_name_for_test("/Domain"), PdfArray([])),
    ]),
    StreamGot(calculator),
  )
  let function = try! doc.parse_function(function_object)
  @test.assert_eq(try! function.eval([]), [
    (-2147483648).to_double(),
    2147483647.0,
    0.0,
    -3.0,
  ])
}

///|
test "PdfDocument parse_function rejects float operands for integer operators" {
  let doc = @pdflite.pdf_document_empty()
  let calculator = @ascii.encode("{ 6.0 3 and }")
  let function_object = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (fun_name_for_test("/Length"), PdfInteger(calculator.length())),
      (fun_name_for_test("/FunctionType"), PdfInteger(4)),
      (fun_name_for_test("/Domain"), PdfArray([])),
    ]),
    StreamGot(calculator),
  )
  let function = try! doc.parse_function(function_object)
  let result : Result[Array[Double], Error] = try? function.eval([])
  guard result is Err(@pdflite.PdfError::BadFunctionEvaluation(_)) else {
    fail("expected PdfError::BadFunctionEvaluation for float bitwise operand")
  }
}

///|
test "PdfDocument parse_function reads and evaluates Type 2 interpolation functions" {
  let doc = @pdflite.pdf_document_empty()
  let function_object = @pdflite.pdf_dictionary([
    (fun_name_for_test("/FunctionType"), PdfInteger(2)),
    (fun_name_for_test("/Domain"), PdfArray([PdfInteger(0), PdfInteger(1)])),
    (fun_name_for_test("/C0"), PdfArray([PdfInteger(0), PdfInteger(0)])),
    (fun_name_for_test("/C1"), PdfArray([PdfInteger(1), PdfInteger(2)])),
    (fun_name_for_test("/N"), PdfInteger(2)),
  ])
  let function = try! doc.parse_function(function_object)
  @test.assert_eq(function.domain, [0.0, 1.0])
  @test.assert_eq(function.range, None)
  @test.assert_eq(try! function.eval([0.5]), [0.25, 0.5])
}

///|
test "PdfFunction eval clamps domain inputs and output range" {
  let doc = @pdflite.pdf_document_empty()
  let function_object = @pdflite.pdf_dictionary([
    (fun_name_for_test("/FunctionType"), PdfInteger(2)),
    (fun_name_for_test("/Domain"), PdfArray([PdfInteger(0), PdfInteger(1)])),
    (fun_name_for_test("/Range"), PdfArray([PdfInteger(0), PdfInteger(1)])),
    (fun_name_for_test("/C0"), PdfArray([PdfInteger(0)])),
    (fun_name_for_test("/C1"), PdfArray([PdfInteger(2)])),
    (fun_name_for_test("/N"), PdfInteger(1)),
  ])
  let function = try! doc.parse_function(function_object)
  @test.assert_eq(try! function.eval([2.0]), [1.0])
}

///|
test "PdfDocument parse_function reports unsupported or malformed functions" {
  let doc = @pdflite.pdf_document_empty()
  let unsupported : Result[@pdflite.PdfFunction, Error] = try? doc.parse_function(
    @pdflite.pdf_dictionary([
      (fun_name_for_test("/FunctionType"), PdfInteger(5)),
      (fun_name_for_test("/Domain"), PdfArray([PdfInteger(0), PdfInteger(1)])),
    ]),
  )
  guard unsupported is Err(@pdflite.PdfError::FunctionNotSupported(5)) else {
    fail("expected PdfError::FunctionNotSupported")
  }
  let missing_domain : Result[@pdflite.PdfFunction, Error] = try? doc.parse_function(
    @pdflite.pdf_dictionary([
      (fun_name_for_test("/FunctionType"), PdfInteger(2)),
      (fun_name_for_test("/N"), PdfInteger(1)),
    ]),
  )
  guard missing_domain is Err(@pdflite.PdfError::DictionaryKeyNotFound(name)) &&
    name == fun_name_for_test("/Domain") else {
    fail("expected missing /Domain")
  }
}

///|
test "PdfDocument parse_function covers sampled function options and errors" {
  let doc = @pdflite.pdf_document_empty()
  let samples = fun_bytes_for_test([0x0F])
  let explicit_options = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (fun_name_for_test("/Length"), PdfInteger(samples.length())),
      (fun_name_for_test("/FunctionType"), PdfInteger(0)),
      (fun_name_for_test("/Domain"), PdfArray([PdfInteger(0), PdfInteger(1)])),
      (fun_name_for_test("/Range"), PdfArray([PdfInteger(0), PdfInteger(1)])),
      (fun_name_for_test("/Size"), PdfArray([PdfInteger(2)])),
      (fun_name_for_test("/Order"), PdfInteger(3)),
      (fun_name_for_test("/Encode"), PdfArray([PdfInteger(0), PdfInteger(1)])),
      (fun_name_for_test("/Decode"), PdfArray([PdfInteger(0), PdfInteger(1)])),
      (fun_name_for_test("/BitsPerSample"), PdfInteger(4)),
    ]),
    StreamGot(samples),
  )
  let explicit = try! doc.parse_function(explicit_options)
  guard explicit.func is PdfFunctionSampled(sampled) else {
    fail("expected sampled function")
  }
  @test.assert_eq(sampled.order, 3)
  @test.assert_eq(sampled.encode, [0.0, 1.0])
  @test.assert_eq(sampled.decode, [0.0, 1.0])

  let fallback_encode = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (fun_name_for_test("/Length"), PdfInteger(samples.length())),
      (fun_name_for_test("/FunctionType"), PdfInteger(0)),
      (fun_name_for_test("/Domain"), PdfArray([PdfInteger(0), PdfInteger(1)])),
      (fun_name_for_test("/Range"), PdfArray([PdfInteger(0), PdfInteger(1)])),
      (fun_name_for_test("/Size"), PdfArray([PdfInteger(2)])),
      (fun_name_for_test("/Encode"), PdfArray([PdfInteger(0)])),
      (fun_name_for_test("/BitsPerSample"), PdfInteger(4)),
    ]),
    StreamGot(samples),
  )
  let fallback = try! doc.parse_function(fallback_encode)
  guard fallback.func is PdfFunctionSampled(fallback_sampled) else {
    fail("expected sampled function")
  }
  @test.assert_eq(fallback_sampled.encode, [0.0, 1.0])

  let bad_size_item : Result[@pdflite.PdfFunction, Error] = try? doc.parse_function(
    @pdflite.pdf_stream(
      @pdflite.pdf_dictionary([
        (fun_name_for_test("/Length"), PdfInteger(samples.length())),
        (fun_name_for_test("/FunctionType"), PdfInteger(0)),
        (fun_name_for_test("/Domain"), PdfArray([PdfInteger(0), PdfInteger(1)])),
        (fun_name_for_test("/Range"), PdfArray([PdfInteger(0), PdfInteger(1)])),
        (
          fun_name_for_test("/Size"),
          PdfArray([PdfNameObject(fun_name_for_test("/Bad"))]),
        ),
        (fun_name_for_test("/BitsPerSample"), PdfInteger(4)),
      ]),
      StreamGot(samples),
    ),
  )
  guard bad_size_item is Err(@pdflite.PdfError::NumberExpected) else {
    fail("expected malformed sampled size item")
  }

  let bad_size_array : Result[@pdflite.PdfFunction, Error] = try? doc.parse_function(
    @pdflite.pdf_stream(
      @pdflite.pdf_dictionary([
        (fun_name_for_test("/Length"), PdfInteger(samples.length())),
        (fun_name_for_test("/FunctionType"), PdfInteger(0)),
        (fun_name_for_test("/Domain"), PdfArray([PdfInteger(0), PdfInteger(1)])),
        (fun_name_for_test("/Range"), PdfArray([PdfInteger(0), PdfInteger(1)])),
        (fun_name_for_test("/Size"), PdfInteger(2)),
        (fun_name_for_test("/BitsPerSample"), PdfInteger(4)),
      ]),
      StreamGot(samples),
    ),
  )
  guard bad_size_array is Err(@pdflite.PdfError::NumberExpected) else {
    fail("expected malformed sampled size array")
  }

  let missing_range : Result[@pdflite.PdfFunction, Error] = try? doc.parse_function(
    @pdflite.pdf_stream(
      @pdflite.pdf_dictionary([
        (fun_name_for_test("/Length"), PdfInteger(samples.length())),
        (fun_name_for_test("/FunctionType"), PdfInteger(0)),
        (fun_name_for_test("/Domain"), PdfArray([PdfInteger(0), PdfInteger(1)])),
        (fun_name_for_test("/Size"), PdfArray([PdfInteger(2)])),
        (fun_name_for_test("/BitsPerSample"), PdfInteger(4)),
      ]),
      StreamGot(samples),
    ),
  )
  guard missing_range is Err(@pdflite.PdfError::DictionaryKeyNotFound(name)) &&
    name == fun_name_for_test("/Range") else {
    fail("expected sampled range or decode")
  }

  let odd_decode : Result[@pdflite.PdfFunction, Error] = try? doc.parse_function(
    @pdflite.pdf_stream(
      @pdflite.pdf_dictionary([
        (fun_name_for_test("/Length"), PdfInteger(samples.length())),
        (fun_name_for_test("/FunctionType"), PdfInteger(0)),
        (fun_name_for_test("/Domain"), PdfArray([PdfInteger(0), PdfInteger(1)])),
        (fun_name_for_test("/Size"), PdfArray([PdfInteger(2)])),
        (fun_name_for_test("/Decode"), PdfArray([PdfInteger(0)])),
        (fun_name_for_test("/BitsPerSample"), PdfInteger(4)),
      ]),
      StreamGot(samples),
    ),
  )
  guard odd_decode is Err(@pdflite.PdfError::FunctionExpected) else {
    fail("expected malformed sampled decode")
  }

  let bad_bits : Result[@pdflite.PdfFunction, Error] = try? doc.parse_function(
    @pdflite.pdf_stream(
      @pdflite.pdf_dictionary([
        (fun_name_for_test("/Length"), PdfInteger(samples.length())),
        (fun_name_for_test("/FunctionType"), PdfInteger(0)),
        (fun_name_for_test("/Domain"), PdfArray([PdfInteger(0), PdfInteger(1)])),
        (fun_name_for_test("/Range"), PdfArray([PdfInteger(0), PdfInteger(1)])),
        (fun_name_for_test("/Size"), PdfArray([PdfInteger(2)])),
        (
          fun_name_for_test("/BitsPerSample"),
          PdfNameObject(fun_name_for_test("/Bad")),
        ),
      ]),
      StreamGot(samples),
    ),
  )
  guard bad_bits is Err(@pdflite.PdfError::NumberExpected) else {
    fail("expected malformed bits per sample")
  }
}

///|
test "PdfDocument parse_function rejects malformed interpolation and stitching dictionaries" {
  let doc = @pdflite.pdf_document_empty()
  let default_c0_c1 = try! doc.parse_function(
    @pdflite.pdf_dictionary([
      (fun_name_for_test("/FunctionType"), PdfInteger(2)),
      (fun_name_for_test("/Domain"), PdfArray([PdfInteger(0), PdfInteger(1)])),
      (fun_name_for_test("/N"), PdfInteger(1)),
    ]),
  )
  @test.assert_eq(try! default_c0_c1.eval([1.0]), [1.0])

  let bad_function_type : Result[@pdflite.PdfFunction, Error] = try? doc.parse_function(
    @pdflite.pdf_dictionary([
      (
        fun_name_for_test("/FunctionType"),
        PdfNameObject(fun_name_for_test("/Bad")),
      ),
      (fun_name_for_test("/Domain"), PdfArray([PdfInteger(0), PdfInteger(1)])),
    ]),
  )
  guard bad_function_type is Err(@pdflite.PdfError::NumberExpected) else {
    fail("expected malformed function type")
  }

  let missing_n : Result[@pdflite.PdfFunction, Error] = try? doc.parse_function(
    @pdflite.pdf_dictionary([
      (fun_name_for_test("/FunctionType"), PdfInteger(2)),
      (fun_name_for_test("/Domain"), PdfArray([PdfInteger(0), PdfInteger(1)])),
    ]),
  )
  guard missing_n is Err(@pdflite.PdfError::DictionaryKeyNotFound(name)) &&
    name == fun_name_for_test("/N") else {
    fail("expected missing interpolation exponent")
  }

  let mismatched_c_arrays : Result[@pdflite.PdfFunction, Error] = try? doc.parse_function(
    @pdflite.pdf_dictionary([
      (fun_name_for_test("/FunctionType"), PdfInteger(2)),
      (fun_name_for_test("/Domain"), PdfArray([PdfInteger(0), PdfInteger(1)])),
      (fun_name_for_test("/C0"), PdfArray([PdfInteger(0), PdfInteger(0)])),
      (fun_name_for_test("/C1"), PdfArray([PdfInteger(1)])),
      (fun_name_for_test("/N"), PdfInteger(1)),
    ]),
  )
  guard mismatched_c_arrays is Err(@pdflite.PdfError::FunctionExpected) else {
    fail("expected mismatched interpolation arrays")
  }

  let first = @pdflite.pdf_dictionary([
    (fun_name_for_test("/FunctionType"), PdfInteger(2)),
    (fun_name_for_test("/Domain"), PdfArray([PdfInteger(0), PdfInteger(1)])),
    (fun_name_for_test("/N"), PdfInteger(1)),
  ])
  let malformed_functions : Result[@pdflite.PdfFunction, Error] = try? doc.parse_function(
    @pdflite.pdf_dictionary([
      (fun_name_for_test("/FunctionType"), PdfInteger(3)),
      (fun_name_for_test("/Domain"), PdfArray([PdfInteger(0), PdfInteger(1)])),
      (fun_name_for_test("/Functions"), PdfInteger(1)),
      (fun_name_for_test("/Bounds"), PdfArray([])),
      (fun_name_for_test("/Encode"), PdfArray([PdfInteger(0), PdfInteger(1)])),
    ]),
  )
  guard malformed_functions is Err(@pdflite.PdfError::FunctionExpected) else {
    fail("expected malformed stitching function array")
  }

  let missing_functions : Result[@pdflite.PdfFunction, Error] = try? doc.parse_function(
    @pdflite.pdf_dictionary([
      (fun_name_for_test("/FunctionType"), PdfInteger(3)),
      (fun_name_for_test("/Domain"), PdfArray([PdfInteger(0), PdfInteger(1)])),
      (fun_name_for_test("/Bounds"), PdfArray([])),
      (fun_name_for_test("/Encode"), PdfArray([PdfInteger(0), PdfInteger(1)])),
    ]),
  )
  guard missing_functions is Err(@pdflite.PdfError::DictionaryKeyNotFound(name)) &&
    name == fun_name_for_test("/Functions") else {
    fail("expected missing stitching functions")
  }

  let missing_bounds : Result[@pdflite.PdfFunction, Error] = try? doc.parse_function(
    @pdflite.pdf_dictionary([
      (fun_name_for_test("/FunctionType"), PdfInteger(3)),
      (fun_name_for_test("/Domain"), PdfArray([PdfInteger(0), PdfInteger(1)])),
      (fun_name_for_test("/Functions"), PdfArray([first])),
      (fun_name_for_test("/Encode"), PdfArray([PdfInteger(0), PdfInteger(1)])),
    ]),
  )
  guard missing_bounds is Err(@pdflite.PdfError::DictionaryKeyNotFound(name)) &&
    name == fun_name_for_test("/Bounds") else {
    fail("expected missing stitching bounds")
  }

  let inconsistent_stitching : Result[@pdflite.PdfFunction, Error] = try? doc.parse_function(
    @pdflite.pdf_dictionary([
      (fun_name_for_test("/FunctionType"), PdfInteger(3)),
      (fun_name_for_test("/Domain"), PdfArray([PdfInteger(0), PdfInteger(1)])),
      (fun_name_for_test("/Functions"), PdfArray([first])),
      (fun_name_for_test("/Bounds"), PdfArray([PdfReal(0.5)])),
      (fun_name_for_test("/Encode"), PdfArray([PdfInteger(0), PdfInteger(1)])),
    ]),
  )
  guard inconsistent_stitching is Err(@pdflite.PdfError::FunctionExpected) else {
    fail("expected inconsistent stitching arrays")
  }
}

///|
test "PdfDocument parse_function rejects malformed calculator syntax" {
  let doc = @pdflite.pdf_document_empty()
  let bare = try! doc.parse_function(
    fun_type4_for_test(@ascii.encode("1 2 add")),
  )
  @test.assert_eq(try! bare.eval([]), [3.0])

  let bad_cases = [
    @ascii.encode("{ --bad }"),
    @ascii.encode("{ bogus }"),
    fun_bytes_for_test([123, 255, 125]),
    @ascii.encode("{ true if }"),
    @ascii.encode("{ { 1 } }"),
    @ascii.encode("}"),
    @ascii.encode("{ { 1 }"),
    @ascii.encode("{ 1 } 2"),
  ]
  for calculator in bad_cases {
    let parsed : Result[@pdflite.PdfFunction, Error] = try? doc.parse_function(
      fun_type4_for_test(calculator),
    )
    guard parsed is Err(@pdflite.PdfError::FunctionExpected) else {
      fail("expected malformed calculator syntax")
    }
  }
}

///|
test "PdfFunction calculator evaluator covers comparison and numeric edge cases" {
  let doc = @pdflite.pdf_document_empty()
  let comparisons = @ascii.encode(
    "{ false not { 1 } { 0 } ifelse 1.0 1.0 eq { 1 } { 0 } ifelse 3 2 gt { 1 } { 0 } ifelse 2 3 le { 1 } { 0 } ifelse true false or { 1 } { 0 } ifelse true false xor { 1 } { 0 } ifelse true true and { 1 } { 0 } ifelse }",
  )
  let comparison_function = try! doc.parse_function(
    fun_type4_for_test(comparisons),
  )
  @test.assert_eq(try! comparison_function.eval([]), [
    1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0,
  ])

  let division = try! doc.parse_function(
    fun_type4_for_test(@ascii.encode("{ 6 3 div }")),
  )
  @test.assert_eq(try! division.eval([]), [2.0])

  let float_compare = try! doc.parse_function(
    fun_type4_for_test(@ascii.encode("{ 1.0 2.0 ne { 1 } { 0 } ifelse }")),
  )
  @test.assert_eq(try! float_compare.eval([]), [1.0])

  let integer_edges = try! doc.parse_function(
    fun_type4_for_test(
      @ascii.encode(
        "{ 3 abs 3 ceiling 3 cvi 3.5 cvr 5.0 2.0 sub 3 floor 3 neg true false or { 1 } { 0 } ifelse 3 round 3 truncate true false xor { 1 } { 0 } ifelse }",
      ),
    ),
  )
  @test.assert_eq(try! integer_edges.eval([]), [
    3.0, 3.0, 3.0, 3.5, 3.0, 3.0, -3.0, 1.0, 3.0, 3.0, 1.0,
  ])
}

///|
test "PdfFunction calculator evaluator reports stack and type errors" {
  let doc = @pdflite.pdf_document_empty()
  let bad_cases = [
    @ascii.encode("{ pop }"),
    @ascii.encode("{ true abs }"),
    @ascii.encode("{ 1.0 2 bitshift }"),
    @ascii.encode("{ 1 { 2 } if }"),
    @ascii.encode("{ 1 3 copy }"),
    @ascii.encode("{ 1 1 index }"),
    @ascii.encode("{ 1 2 0 roll }"),
    @ascii.encode("{ true 1 add }"),
    @ascii.encode("{ 1.0 not }"),
    @ascii.encode("{ dup }"),
    @ascii.encode("{ exch }"),
    @ascii.encode("{ true ceiling }"),
    @ascii.encode("{ true cvi }"),
    @ascii.encode("{ true cvr }"),
    @ascii.encode("{ true floor }"),
    @ascii.encode("{ true neg }"),
    @ascii.encode("{ true round }"),
    @ascii.encode("{ true truncate }"),
    @ascii.encode("{ true }"),
  ]
  for calculator in bad_cases {
    let function = try! doc.parse_function(fun_type4_for_test(calculator))
    let result : Result[Array[Double], Error] = try? function.eval([])
    guard result is Err(@pdflite.PdfError::BadFunctionEvaluation(_)) else {
      fail("expected calculator evaluation failure")
    }
  }

  let domain_function = try! doc.parse_function(
    @pdflite.pdf_stream(
      @pdflite.pdf_dictionary([
        (fun_name_for_test("/Length"), PdfInteger(9)),
        (fun_name_for_test("/FunctionType"), PdfInteger(4)),
        (fun_name_for_test("/Domain"), PdfArray([PdfInteger(0), PdfInteger(1)])),
      ]),
      StreamGot(@ascii.encode("{ 1 add }")),
    ),
  )
  let arity : Result[Array[Double], Error] = try? domain_function.eval([])
  guard arity is Err(@pdflite.PdfError::BadFunctionEvaluation(_)) else {
    fail("expected domain arity failure")
  }
}
