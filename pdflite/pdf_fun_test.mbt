///|
fn fun_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn fun_bytes_for_test(values : ArrayView[Int]) -> @pdflite.PdfBytes {
  try! @pdflite.pdf_bytes_of_int_array(values)
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
    fail("expected FunctionNotSupported")
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
