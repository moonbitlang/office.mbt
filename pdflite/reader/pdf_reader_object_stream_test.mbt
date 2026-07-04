///|
test "object stream number offsets parse header pairs" {
  @test.assert_eq(
    try! @reader.pdf_object_stream_number_offsets(
      @ascii.encode("2 0 3 4 truefalse"),
      8,
      2,
    ),
    [(2, 0), (3, 4)],
  )
}

///|
test "object stream number offsets reject malformed headers" {
  let bad_first : Result[Array[(Int, Int)], Error] = try
    @reader.pdf_object_stream_number_offsets(@ascii.encode("1 0"), 4, 1)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_first is Err(@core.PdfError::StreamDataExpected) else {
    fail("expected StreamDataExpected")
  }

  let short_header : Result[Array[(Int, Int)], Error] = try
    @reader.pdf_object_stream_number_offsets(@ascii.encode("2 "), 2, 1)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard short_header is Err(@core.PdfError::XRefEntryExpected) else {
    fail("expected XRefEntryExpected")
  }

  let malformed_pair : Result[Array[(Int, Int)], Error] = try
    @reader.pdf_object_stream_number_offsets(@ascii.encode("/Name 0 "), 8, 1)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard malformed_pair is Err(@core.PdfError::XRefEntryExpected) else {
    fail("expected XRefEntryExpected")
  }
}

///|
test "object stream end offsets preserve duplicate starts" {
  @test.assert_eq(
    @reader.pdf_object_stream_end_offsets(
      [(2, 4), (3, 0), (4, 4), (5, 8)],
      20,
      8,
    ),
    [8, 4, 8, 12],
  )
  @test.assert_eq(
    @reader.pdf_object_stream_end_offsets([(2, 0), (3, 100)], 20, 8),
    [12, 12],
  )
}

///|
fn reader_object_stream_xref_for_test(
  object_number : Int,
  object_stream_number : Int,
  index : Int,
  in_use? : Bool = true,
) -> @reader.PdfClassicXRefEntry {
  {
    object_number,
    offset: 0,
    generation: 0,
    in_use,
    object_stream: Some({ object_stream_number, index }),
  }
}

///|
test "object stream groups keep active compressed entries by stream" {
  let groups = @reader.pdf_reader_object_stream_groups([
    reader_object_stream_xref_for_test(0, 7, 0),
    reader_object_stream_xref_for_test(2, 7, 0),
    reader_object_stream_xref_for_test(4, 9, 0, in_use=false),
    reader_object_stream_xref_for_test(3, 7, 1),
    reader_object_stream_xref_for_test(5, 9, 0),
    {
      object_number: 6,
      offset: 0,
      generation: 0,
      in_use: true,
      object_stream: None,
    },
  ])
  @test.assert_eq(groups.length(), 2)
  @test.assert_eq(groups[0].0, 7)
  @test.assert_eq(groups[0].1.length(), 2)
  @test.assert_eq(groups[0].1[0].0.object_number, 2)
  @test.assert_eq(groups[0].1[0].1.index, 0)
  @test.assert_eq(groups[0].1[1].0.object_number, 3)
  @test.assert_eq(groups[0].1[1].1.index, 1)
  @test.assert_eq(groups[1].0, 9)
  @test.assert_eq(groups[1].1.length(), 1)
  @test.assert_eq(groups[1].1[0].0.object_number, 5)
}

///|
test "object stream number offsets reject overflowing declared counts" {
  // `count * 2` overflows Int for huge `/N` values; the guard must reject the
  // count instead of bypassing the length check and allocating gigabytes.
  let overflow : Result[Array[(Int, Int)], Error] = try
    @reader.pdf_object_stream_number_offsets(
      @ascii.encode("2 0 "),
      4,
      0x40000000,
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard overflow is Err(@core.PdfError::XRefEntryExpected) else {
    fail("expected XRefEntryExpected")
  }
}
