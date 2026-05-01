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
      (fun_name_for_test("/FunctionType"), PdfInteger(3)),
      (fun_name_for_test("/Domain"), PdfArray([PdfInteger(0), PdfInteger(1)])),
    ]),
  )
  guard unsupported is Err(@pdflite.PdfError::FunctionNotSupported(3)) else {
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
