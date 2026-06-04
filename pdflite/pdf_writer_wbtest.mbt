///|
fn writer_wb_bytes_for_test(values : ArrayView[Int]) -> @core.PdfBytes {
  try! @core.pdf_bytes_of_int_array(values)
}

///|
test "pdf_writer_changed_object_numbers deduplicates changed event log" {
  let document = pdf_document_empty()
  document.objects.log.push((5, ObjectAltered))
  document.objects.log.push((3, ObjectAltered))
  document.objects.log.push((5, ObjectDeleted))
  document.objects.log.push((0, ObjectAltered))
  document.objects.log.push((-1, ObjectDeleted))
  document.objects.log.push((1, ObjectAltered))
  document.objects.log.push((3, ObjectDeleted))
  @test.assert_eq(pdf_writer_changed_object_numbers(document), [0, 1, 3, 5])
}

///|
test "pdf_writer_int_array_contains handles present and missing values" {
  let values : Array[Int] = [0, 2, 4]
  @test.assert_eq(pdf_writer_int_array_contains(values, 2), true)
  @test.assert_eq(pdf_writer_int_array_contains(values, 3), false)
}

///|
test "pdf_writer_push_classic_xref_subsection scans sorted xrefs in order" {
  let output : Array[Byte] = []
  let xrefs : Array[(Int, Int, Int)] = [(2, 33, 1), (4, 44, 2)]
  let xref_index : Ref[Int] = { val: 0 }
  pdf_writer_push_classic_xref_subsection(output, xrefs, 0, 3, xref_index)
  pdf_writer_push_classic_xref_subsection(output, xrefs, 4, 1, xref_index)
  @test.assert_eq(
    Bytes::from_array(output),
    @ascii.encode(
      "0 3\n0000000000 65535 f \n0000000000 65535 f \n0000000033 00001 n \n4 1\n0000000044 00002 n \n",
    ),
  )
}

///|
test "pdf_writer_xref_stream_data emits full table in object order" {
  let xrefs : Array[(Int, Int, Int)] = [(1, 20, 0), (3, 300, 2)]
  @test.assert_eq(
    pdf_writer_xref_stream_data(xrefs, 5, 4, 400),
    writer_wb_bytes_for_test([
      0, 0, 0, 0, 0, 255, 255, 1, 0, 0, 0, 20, 0, 0, 0, 0, 0, 0, 0, 255, 255, 1,
      0, 0, 1, 44, 0, 2, 1, 0, 0, 1, 144, 0, 0,
    ]),
  )
}

///|
test "pdf_writer_xref_stream_data_for_numbers emits sparse entries in order" {
  let xrefs : Array[(Int, Int, Int)] = [(2, 33, 1), (4, 44, 2)]
  let numbers : Array[Int] = [0, 2, 4, 5]
  @test.assert_eq(
    pdf_writer_xref_stream_data_for_numbers(xrefs, numbers, 5, 55),
    writer_wb_bytes_for_test([
      0, 0, 0, 0, 0, 255, 255, 1, 0, 0, 0, 33, 0, 1, 1, 0, 0, 0, 44, 0, 2, 1, 0,
      0, 0, 55, 0, 0,
    ]),
  )
}

///|
test "writer parses signed integer fragments for scientific reals" {
  @test.assert_eq(try! pdf_writer_parse_signed_int(@ascii.encode("+12"), 0), 12)
  @test.assert_eq(
    try! pdf_writer_parse_signed_int(@ascii.encode("-12"), 0),
    -12,
  )
  @test.assert_eq(try! pdf_writer_parse_signed_int(@ascii.encode("12"), 0), 12)
  let missing : Result[Int, Error] = try
    pdf_writer_parse_signed_int(@ascii.encode("+"), 0)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard missing is Err(@core.PdfError::NumberExpected) else {
    fail("expected @core.PdfError::NumberExpected")
  }
  let malformed : Result[Int, Error] = try
    pdf_writer_parse_signed_int(@ascii.encode("12a"), 0)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard malformed is Err(@core.PdfError::NumberExpected) else {
    fail("expected @core.PdfError::NumberExpected")
  }
}

///|
test "writer expands scientific real edge forms" {
  @test.assert_eq(pdf_writer_exponent_marker(@ascii.encode("1E2")), 1)

  let plus_output : Array[Byte] = []
  try! pdf_writer_push_scientific_real(plus_output, @ascii.encode("+1.25e2"), 5)
  @test.assert_eq(Bytes::from_array(plus_output), @ascii.encode("125"))

  let negative_output : Array[Byte] = []
  try! pdf_writer_push_scientific_real(
    negative_output,
    @ascii.encode("-1.25e2"),
    5,
  )
  @test.assert_eq(Bytes::from_array(negative_output), @ascii.encode("-125"))

  let padded_output : Array[Byte] = []
  try! pdf_writer_push_scientific_real(padded_output, @ascii.encode("1.2e3"), 3)
  @test.assert_eq(Bytes::from_array(padded_output), @ascii.encode("1200"))

  let middle_output : Array[Byte] = []
  try! pdf_writer_push_scientific_real(
    middle_output,
    @ascii.encode("1.25e1"),
    4,
  )
  @test.assert_eq(Bytes::from_array(middle_output), @ascii.encode("12.5"))

  let negative_exponent_output : Array[Byte] = []
  try! pdf_writer_push_scientific_real(
    negative_exponent_output,
    @ascii.encode("1.25e-3"),
    4,
  )
  @test.assert_eq(
    Bytes::from_array(negative_exponent_output),
    @ascii.encode("0.00125"),
  )

  let rounded_exponent_output : Array[Byte] = []
  try! pdf_writer_push_scientific_real(
    rounded_exponent_output,
    @ascii.encode("1.23456789012345e21"),
    16,
  )
  @test.assert_eq(
    Bytes::from_array(rounded_exponent_output),
    @ascii.encode("1234567890120000000000"),
  )

  let carry_exponent_output : Array[Byte] = []
  try! pdf_writer_push_scientific_real(
    carry_exponent_output,
    @ascii.encode("9.999999999999e21"),
    14,
  )
  @test.assert_eq(
    Bytes::from_array(carry_exponent_output),
    @ascii.encode("10000000000000000000000"),
  )

  let rounded_no_carry_output : Array[Byte] = []
  try! pdf_writer_push_scientific_real(
    rounded_no_carry_output,
    @ascii.encode("1.234567890125e21"),
    14,
  )
  @test.assert_eq(
    Bytes::from_array(rounded_no_carry_output),
    @ascii.encode("1234567890130000000000"),
  )

  let trimmed_fraction_output : Array[Byte] = []
  try! pdf_writer_push_scientific_real(
    trimmed_fraction_output,
    @ascii.encode("1.230000000001e-1"),
    14,
  )
  @test.assert_eq(
    Bytes::from_array(trimmed_fraction_output),
    @ascii.encode("0.123"),
  )

  let zero_digits_output : Array[Byte] = []
  try! pdf_writer_push_scientific_real(
    zero_digits_output,
    @ascii.encode("0.000e10"),
    5,
  )
  @test.assert_eq(Bytes::from_array(zero_digits_output), @ascii.encode("0"))

  let zero_output : Array[Byte] = []
  try! pdf_writer_push_scientific_real(zero_output, @ascii.encode(".e1"), 1)
  @test.assert_eq(Bytes::from_array(zero_output), @ascii.encode("0"))

  let malformed_output : Array[Byte] = []
  let malformed : Result[Unit, Error] = try
    pdf_writer_push_scientific_real(malformed_output, @ascii.encode("1Ae1"), 2)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard malformed is Err(@core.PdfError::NumberExpected) else {
    fail("expected @core.PdfError::NumberExpected")
  }
}

///|
test "writer rounds plain significant real helper edge forms" {
  let plus_output : Array[Byte] = []
  try! pdf_writer_push_plain_significant_real(
    plus_output,
    @ascii.encode("+1.23456789012345"),
  )
  @test.assert_eq(
    Bytes::from_array(plus_output),
    @ascii.encode("1.23456789012"),
  )

  let negative_output : Array[Byte] = []
  try! pdf_writer_push_plain_significant_real(
    negative_output,
    @ascii.encode("-1.23456789012345"),
  )
  @test.assert_eq(
    Bytes::from_array(negative_output),
    @ascii.encode("-1.23456789012"),
  )

  let leading_decimal_output : Array[Byte] = []
  try! pdf_writer_push_plain_significant_real(
    leading_decimal_output,
    @ascii.encode(".000123456789012345"),
  )
  @test.assert_eq(
    Bytes::from_array(leading_decimal_output),
    @ascii.encode("0.000123456789012"),
  )

  let zero_output : Array[Byte] = []
  try! pdf_writer_push_plain_significant_real(zero_output, @ascii.encode("0.0"))
  @test.assert_eq(Bytes::from_array(zero_output), @ascii.encode("0"))

  let double_dot : Result[Unit, Error] = try
    pdf_writer_push_plain_significant_real([], @ascii.encode("1.2.3"))
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard double_dot is Err(@core.PdfError::NumberExpected) else {
    fail("expected @core.PdfError::NumberExpected")
  }

  let bad_digit : Result[Unit, Error] = try
    pdf_writer_push_plain_significant_real([], @ascii.encode("1a"))
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_digit is Err(@core.PdfError::NumberExpected) else {
    fail("expected @core.PdfError::NumberExpected")
  }
}

///|
test "incremental writer rejects changed deferred objects" {
  let original_doc = pdf_document_empty()
  original_doc.set_version(1, 4)
  original_doc.set_root(1)
  original_doc.add_object_given_number(1, PdfDictionary([]))
  let original = try! pdf_write_document(original_doc)

  let changed = try! pdf_read_document_from_bytes(original)
  changed.objects.set_entry(1, pdf_object_entry(ObjectToParse))
  changed.objects.log.push((1, ObjectAltered))
  let result : Result[@core.PdfBytes, Error] = try
    pdf_write_document_incremental_update(original, changed)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard result is Err(@core.PdfError::ParsedObjectExpected) else {
    fail("expected @core.PdfError::ParsedObjectExpected")
  }
}

///|
test "pdf_write_document rejects deferred object states" {
  let doc = pdf_document_empty()
  doc.objects.set_entry(1, pdf_object_entry(ObjectToParse))
  let result : Result[@core.PdfBytes, Error] = try
    pdf_write_document(doc)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard result is Err(@core.PdfError::ParsedObjectExpected) else {
    fail("expected @core.PdfError::ParsedObjectExpected")
  }
}

///|
test "private writer stream dictionary uses materialized deferred length" {
  let cursor = @core.byte_cursor_of_bytes(@ascii.encode("abc"))
  let stream = @syntax.pdf_stream(
    PdfDictionary([]),
    StreamToGet(@syntax.stream_to_get(cursor, 0, 1)),
  )
  guard stream is PdfStreamObject(stream_value) else {
    fail("expected PdfStreamObject")
  }
  @test.assert_eq(
    pdf_write_stream_dictionary(
      stream_value,
      @syntax.pdf_stream_data_view(stream_value.data).length(),
    ),
    PdfDictionary([
      (@core.pdf_name_of_bytes(@ascii.encode("/Length")), PdfInteger(1)),
    ]),
  )
}
