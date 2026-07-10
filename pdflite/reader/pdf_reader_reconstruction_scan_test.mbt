///|
test "reconstruction scan recognizes indirect object headers" {
  let noisy_digits = @ascii.encode(
    "12345 67 notobj\n90 0 nope\nabc 4 0 obj\n42\nendobj\n",
  )
  let valid_header = @core.pdf_find_ascii_from(noisy_digits, 0, [
    52, 32, 48, 32, 111, 98, 106,
  ])

  @test.assert_eq(
    @reader.pdf_reader_reconstruction_indirect_header_at(noisy_digits, 0),
    false,
  )
  @test.assert_eq(
    @reader.pdf_reader_reconstruction_indirect_header_at(
      noisy_digits, valid_header,
    ),
    true,
  )
  @test.assert_eq(
    @reader.pdf_reader_reconstruction_indirect_header_at(b"1 0 object", 0),
    false,
  )
  @test.assert_eq(
    @reader.pdf_reader_reconstruction_indirect_header_at(b"1 0 obj/Name", 0),
    true,
  )
}

///|
test "reconstruction scan skips malformed object candidates" {
  let nested_bad_object = @ascii.encode(
    "1 0 obj\n]\n2 0 obj\n<< /Type /Catalog >>\nendobj\n3 0 obj\n42\nendobj\n",
  )
  let endobj : ReadOnlyArray[Int] = [101, 110, 100, 111, 98, 106]
  let nested_endobj = @core.pdf_find_ascii_from(nested_bad_object, 0, endobj)
  @test.assert_eq(
    @reader.pdf_reader_reconstruction_skip_malformed_object(
      nested_bad_object, 0,
    ),
    Some(nested_endobj + 7),
  )
  @test.assert_eq(
    @reader.pdf_reader_reconstruction_skip_malformed_object(
      nested_bad_object, 1,
    ),
    None,
  )

  let line_ending_endobj = b"1 0 obj\n]\nabcendobj\r\n4 0 obj\n"
  let trailing_endobj = @core.pdf_find_ascii_from(line_ending_endobj, 0, endobj)
  @test.assert_eq(
    @reader.pdf_reader_reconstruction_skip_malformed_object(
      line_ending_endobj, 0,
    ),
    Some(trailing_endobj + 8),
  )

  let leading_trim_endobj = b"1 0 obj\n]\n  endobj\n"
  @test.assert_eq(
    @reader.pdf_reader_reconstruction_skip_malformed_object(
      leading_trim_endobj, 0,
    ),
    Some(leading_trim_endobj.length()),
  )

  let no_endobj = b"1 0 obj\n]"
  @test.assert_eq(
    @reader.pdf_reader_reconstruction_skip_malformed_object(no_endobj, 0),
    Some(no_endobj.length()),
  )
}
