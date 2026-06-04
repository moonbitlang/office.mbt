///|
fn test_dictionary(
  values : Array[(@core.PdfName, @syntax.PdfObject)],
) -> @syntax.PdfObject {
  PdfDictionary(values)
}

///|
fn test_array(values : Array[@syntax.PdfObject]) -> @syntax.PdfObject {
  PdfArray(values)
}

///|
fn test_name(name : @core.PdfName) -> @syntax.PdfObject {
  PdfNameObject(name)
}

///|
fn test_integer(value : Int) -> @syntax.PdfObject {
  PdfInteger(value)
}

///|
test "xref stream metadata recognizes type and width fallback" {
  let typed = test_dictionary([
    (@reader.pdf_reader_type_name(), test_name(@reader.pdf_reader_xref_name())),
  ])
  @test.assert_eq(@reader.pdf_reader_xref_stream_type_ok(typed), true)

  let width_only = test_dictionary([
    (
      @reader.pdf_reader_w_name(),
      test_array([test_integer(0), test_integer(1), test_integer(1)]),
    ),
  ])
  @test.assert_eq(@reader.pdf_reader_xref_stream_type_ok(width_only), true)

  let wrong_type = test_dictionary([
    (
      @reader.pdf_reader_type_name(),
      test_name(@reader.pdf_reader_objstm_name()),
    ),
  ])
  @test.assert_eq(@reader.pdf_reader_xref_stream_type_ok(wrong_type), false)
}

///|
test "xref stream metadata sanitizes stream dictionary keys" {
  let sanitized = try! @reader.pdf_reader_stream_dictionary_without_xref_keys(
    test_dictionary([
      (
        @reader.pdf_reader_type_name(),
        test_name(@reader.pdf_reader_xref_name()),
      ),
      (
        @reader.pdf_reader_w_name(),
        test_array([test_integer(0), test_integer(1), test_integer(1)]),
      ),
      (
        @reader.pdf_reader_index_name(),
        test_array([test_integer(0), test_integer(1)]),
      ),
      (@reader.pdf_length_name(), test_integer(4)),
      (
        @reader.pdf_reader_filter_name(),
        test_name(@reader.pdf_reader_name("/FlateDecode")),
      ),
      (
        @reader.pdf_reader_short_filter_name(),
        test_name(@reader.pdf_reader_name("/F")),
      ),
      (@reader.pdf_reader_decodeparms_name(), test_dictionary([])),
      (@reader.pdf_reader_short_decodeparms_name(), test_dictionary([])),
      (@reader.pdf_reader_size_name(), test_integer(1)),
    ]),
  )
  @test.assert_eq(
    sanitized.lookup_immediate(@reader.pdf_reader_type_name()),
    None,
  )
  @test.assert_eq(sanitized.lookup_immediate(@reader.pdf_reader_w_name()), None)
  @test.assert_eq(
    sanitized.lookup_immediate(@reader.pdf_reader_size_name()),
    Some(test_integer(1)),
  )
}

///|
test "xref stream metadata parses widths and indexes" {
  let dictionary = test_dictionary([
    (
      @reader.pdf_reader_w_name(),
      test_array([test_integer(0), test_integer(2), test_integer(1)]),
    ),
    (
      @reader.pdf_reader_index_name(),
      test_array([
        test_integer(2),
        test_integer(3),
        test_integer(9),
        test_integer(1),
      ]),
    ),
  ])
  @test.assert_eq(try! @reader.pdf_xref_stream_widths(dictionary), (0, 2, 1))
  @test.assert_eq(try! @reader.pdf_xref_stream_index_pairs(dictionary), [
    (2, 3),
    (9, 1),
  ])

  let default_index = test_dictionary([
    (@reader.pdf_reader_size_name(), test_integer(4)),
  ])
  @test.assert_eq(try! @reader.pdf_xref_stream_index_pairs(default_index), [
    (0, 4),
  ])
}

///|
test "xref stream metadata rejects malformed arrays" {
  let malformed_array_value : Result[Array[Int]?, Error] = try
    @reader.pdf_xref_stream_int_array(
      test_dictionary([
        (
          @reader.pdf_reader_w_name(),
          test_array([test_name(@reader.pdf_reader_name("/Name"))]),
        ),
      ]),
      @reader.pdf_reader_w_name(),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard malformed_array_value is Err(@core.PdfError::XRefEntryExpected) else {
    fail("expected XRefEntryExpected")
  }

  let malformed_widths : Result[(Int, Int, Int), Error] = try
    @reader.pdf_xref_stream_widths(
      test_dictionary([
        (@reader.pdf_reader_w_name(), test_array([test_integer(0)])),
      ]),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard malformed_widths is Err(@core.PdfError::XRefEntryExpected) else {
    fail("expected XRefEntryExpected")
  }

  let odd_index : Result[Array[(Int, Int)], Error] = try
    @reader.pdf_xref_stream_index_pairs(
      test_dictionary([
        (@reader.pdf_reader_index_name(), test_array([test_integer(0)])),
      ]),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard odd_index is Err(@core.PdfError::XRefEntryExpected) else {
    fail("expected XRefEntryExpected")
  }
}
