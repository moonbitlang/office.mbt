///|
test "xref stream field reader handles zero-width and bounds" {
  @test.assert_eq(
    try! @reader.pdf_xref_stream_read_field(@ascii.encode("ab"), 0, 0),
    (0, 0),
  )
  @test.assert_eq(
    try! @reader.pdf_xref_stream_read_field(@ascii.encode("ab"), 0, 2),
    (24930, 2),
  )

  let short_field : Result[(Int, Int), Error] = try
    @reader.pdf_xref_stream_read_field(@ascii.encode("a"), 0, 2)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard short_field is Err(@core.PdfError::XRefEntryExpected) else {
    fail("expected XRefEntryExpected")
  }

  let negative_width : Result[(Int, Int), Error] = try
    @reader.pdf_xref_stream_read_field(@ascii.encode("a"), 0, -1)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard negative_width is Err(@core.PdfError::XRefEntryExpected) else {
    fail("expected XRefEntryExpected")
  }
}

///|
test "xref stream entries decode normal, object stream, and unknown kinds" {
  let entries = try! @reader.pdf_xref_stream_entries(
    Bytes::from_array([1, 9, 0, 2, 7, 3, 5, 0, 0]),
    (1, 1, 1),
    [(5, 3)],
  )
  @test.assert_eq(entries.length(), 3)
  @test.assert_eq(entries[0], {
    object_number: 5,
    offset: 9,
    generation: 0,
    in_use: true,
    object_stream: None,
  })
  @test.assert_eq(entries[1], {
    object_number: 6,
    offset: 7,
    generation: 3,
    in_use: true,
    object_stream: Some({ object_stream_number: 7, index: 3 }),
  })
  @test.assert_eq(entries[2], {
    object_number: 7,
    offset: 0,
    generation: 0,
    in_use: false,
    object_stream: None,
  })

  let invalid_pairs : Result[Array[@reader.PdfClassicXRefEntry], Error] = try
    @reader.pdf_xref_stream_entries(Bytes::from_array([]), (1, 1, 1), [(0, -1)])
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard invalid_pairs is Err(@core.PdfError::XRefEntryExpected) else {
    fail("expected XRefEntryExpected")
  }

  let invalid_widths : Result[Array[@reader.PdfClassicXRefEntry], Error] = try
    @reader.pdf_xref_stream_entries(Bytes::from_array([]), (0, 0, 0), [])
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard invalid_widths is Err(@core.PdfError::XRefEntryExpected) else {
    fail("expected XRefEntryExpected")
  }
}

///|
test "xref stream entries default missing kind to in-use" {
  let entries = try! @reader.pdf_xref_stream_entries(
    Bytes::from_array([9, 0, 8, 1]),
    (0, 1, 1),
    [(5, 2)],
  )
  @test.assert_eq(entries.length(), 2)
  @test.assert_eq(entries[0].object_number, 5)
  @test.assert_eq(entries[0].offset, 9)
  @test.assert_eq(entries[0].generation, 0)
  @test.assert_eq(entries[0].in_use, true)
  @test.assert_eq(entries[1].object_number, 6)
  @test.assert_eq(entries[1].offset, 8)
  @test.assert_eq(entries[1].generation, 1)
  @test.assert_eq(entries[1].in_use, true)
}
