///|
test "pdf_date_of_string parses full PDF dates" {
  @test.assert_eq(try! @pdflite.pdf_date_of_string("D:20240203040506+08'30'"), {
    year: 2024,
    month: 2,
    day: 3,
    hour: 4,
    minute: 5,
    second: 6,
    hour_offset: 8,
    minute_offset: 30,
  })
  @test.assert_eq(try! @pdflite.pdf_date_of_string("20240203040506-07'15'"), {
    year: 2024,
    month: 2,
    day: 3,
    hour: 4,
    minute: 5,
    second: 6,
    hour_offset: -7,
    minute_offset: -15,
  })
}

///|
test "pdf_date byte APIs parse borrowed PDF date slices" {
  let wrapped = @ascii.encode("xxD:20240203040506+08'30'yy")
  let view = wrapped[2:wrapped.length() - 2]
  let expected : @pdflite.PdfDate = {
    year: 2024,
    month: 2,
    day: 3,
    hour: 4,
    minute: 5,
    second: 6,
    hour_offset: 8,
    minute_offset: 30,
  }
  @test.assert_eq(try! @pdflite.pdf_date_of_view(view), expected)
  @test.assert_eq(try! @pdflite.pdf_date_of_bytes(view.to_owned()), expected)
  @test.assert_eq(
    try! @pdflite.pdf_bytes_of_date(expected),
    @ascii.encode("D:20240203040506+08'30'"),
  )
}

///|
test "pdf_date object APIs bridge PDF strings and typed dates" {
  let object : @pdflite.PdfObject = PdfString(
    @ascii.encode("D:20240203040506+08'30'"),
  )
  let expected : @pdflite.PdfDate = {
    year: 2024,
    month: 2,
    day: 3,
    hour: 4,
    minute: 5,
    second: 6,
    hour_offset: 8,
    minute_offset: 30,
  }
  @test.assert_eq(try! @pdflite.pdf_date_of_object(object), expected)
  @test.assert_eq(
    try! @pdflite.pdf_object_of_date(expected),
    PdfString(@ascii.encode("D:20240203040506+08'30'")),
  )
  let non_string : Result[@pdflite.PdfDate, Error] = try? @pdflite.pdf_date_of_object(
    PdfNameObject(@pdflite.pdf_name_of_bytes(@ascii.encode("/Date"))),
  )
  guard non_string is Err(@pdflite.PdfError::BadDate) else {
    fail("expected @pdflite.PdfError::BadDate for non-string date object")
  }
}

///|
test "pdf_date_of_string applies CamlPDF defaults and Y2K recovery" {
  @test.assert_eq(try! @pdflite.pdf_date_of_string("D:2024"), {
    year: 2024,
    month: 1,
    day: 1,
    hour: 0,
    minute: 0,
    second: 0,
    hour_offset: 0,
    minute_offset: 0,
  })
  @test.assert_eq(try! @pdflite.pdf_date_of_string("D:2024Z"), {
    year: 2024,
    month: 1,
    day: 1,
    hour: 0,
    minute: 0,
    second: 0,
    hour_offset: 0,
    minute_offset: 0,
  })
  @test.assert_eq(try! @pdflite.pdf_date_of_string("D:20241"), {
    year: 2024,
    month: 1,
    day: 1,
    hour: 0,
    minute: 0,
    second: 0,
    hour_offset: 0,
    minute_offset: 0,
  })
  @test.assert_eq(try! @pdflite.pdf_date_of_string("D:20240102030405X"), {
    year: 2024,
    month: 1,
    day: 2,
    hour: 3,
    minute: 4,
    second: 5,
    hour_offset: 0,
    minute_offset: 0,
  })
  @test.assert_eq((try! @pdflite.pdf_date_of_string("D:19100")).year, 2000)
}

///|
test "pdf_date_of_string preserves CamlPDF local-time quirks" {
  @test.assert_eq(try! @pdflite.pdf_date_of_string("D:20240102030405+0830"), {
    year: 2024,
    month: 1,
    day: 2,
    hour: 3,
    minute: 4,
    second: 5,
    hour_offset: 8,
    minute_offset: 0,
  })
  @test.assert_eq(try! @pdflite.pdf_date_of_string("D:20240102030405+08x30"), {
    year: 2024,
    month: 1,
    day: 2,
    hour: 3,
    minute: 4,
    second: 5,
    hour_offset: 8,
    minute_offset: 30,
  })
  @test.assert_eq(try! @pdflite.pdf_date_of_string("D:20240102030405+08"), {
    year: 2024,
    month: 1,
    day: 2,
    hour: 3,
    minute: 4,
    second: 5,
    hour_offset: 0,
    minute_offset: 0,
  })
}

///|
test "pdf_string_of_date renders checked PDF date syntax" {
  @test.assert_eq(
    try! @pdflite.pdf_string_of_date({
      year: 7,
      month: 1,
      day: 2,
      hour: 3,
      minute: 4,
      second: 5,
      hour_offset: 6,
      minute_offset: 7,
    }),
    "D:00070102030405+06'07'",
  )
  @test.assert_eq(
    try! @pdflite.pdf_string_of_date({
      year: 42,
      month: 1,
      day: 2,
      hour: 3,
      minute: 4,
      second: 5,
      hour_offset: 0,
      minute_offset: 0,
    }),
    "D:00420102030405Z",
  )
  @test.assert_eq(
    try! @pdflite.pdf_string_of_date({
      year: 999,
      month: 1,
      day: 2,
      hour: 3,
      minute: 4,
      second: 5,
      hour_offset: 0,
      minute_offset: 0,
    }),
    "D:09990102030405Z",
  )
  @test.assert_eq(
    try! @pdflite.pdf_string_of_date({
      year: 2024,
      month: 2,
      day: 3,
      hour: 4,
      minute: 5,
      second: 6,
      hour_offset: 0,
      minute_offset: 45,
    }),
    "D:20240203040506Z",
  )
  @test.assert_eq(
    try! @pdflite.pdf_string_of_date({
      year: 2024,
      month: 2,
      day: 3,
      hour: 4,
      minute: 5,
      second: 6,
      hour_offset: -7,
      minute_offset: -15,
    }),
    "D:20240203040506-07'15'",
  )
}

///|
test "pdf_date_of_string rejects malformed dates" {
  let bad_month : Result[@pdflite.PdfDate, Error] = try? @pdflite.pdf_date_of_string(
    "D:20241301",
  )
  guard bad_month is Err(@pdflite.PdfError::BadDate) else {
    fail("expected @pdflite.PdfError::BadDate for month")
  }
  let short : Result[@pdflite.PdfDate, Error] = try? @pdflite.pdf_date_of_string(
    "D:20",
  )
  guard short is Err(@pdflite.PdfError::BadDate) else {
    fail("expected @pdflite.PdfError::BadDate for short date")
  }
  let bad_year_digit : Result[@pdflite.PdfDate, Error] = try? @pdflite.pdf_date_of_string(
    "D:20A4",
  )
  guard bad_year_digit is Err(@pdflite.PdfError::BadDate) else {
    fail("expected @pdflite.PdfError::BadDate for year")
  }
  let bad_month_digit : Result[@pdflite.PdfDate, Error] = try? @pdflite.pdf_date_of_string(
    "D:2024AA",
  )
  guard bad_month_digit is Err(@pdflite.PdfError::BadDate) else {
    fail("expected @pdflite.PdfError::BadDate for month digits")
  }
}
