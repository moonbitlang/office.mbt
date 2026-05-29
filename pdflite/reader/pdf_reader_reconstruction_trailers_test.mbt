///|
fn reader_reconstruction_trailer_parser_for_test(
  cursor : @core.ByteCursor,
  position : Int,
) -> @syntax.PdfObject raise @core.PdfError {
  cursor.seek_absolute(position)
  if position == 3 {
    PdfDictionary([(@reader.pdf_reader_root_name(), PdfIndirect(1))])
  } else {
    raise TrailerExpected
  }
}

///|
fn reader_reconstruction_xref_stream_trailer_parser_for_test(
  cursor : @core.ByteCursor,
  position : Int,
) -> @syntax.PdfObject raise @core.PdfError {
  cursor.seek_absolute(position)
  if position == 0 {
    PdfDictionary([(@reader.pdf_reader_size_name(), PdfInteger(2))])
  } else {
    raise XRefExpected
  }
}

///|
test "reconstructed trailer scanner keeps parsed literal trailers" {
  let trailers = @reader.pdf_reader_reconstruction_trailers(
    b"xxxtrailer bad trailer", false, reader_reconstruction_trailer_parser_for_test,
    reader_reconstruction_xref_stream_trailer_parser_for_test,
  )
  @test.assert_eq(trailers.length(), 1)
  @test.assert_eq(
    trailers[0],
    PdfDictionary([(@reader.pdf_reader_root_name(), PdfIndirect(1))]),
  )
}

///|
test "reconstructed trailer scanner gates xref stream trailers" {
  let data = b"1 0 obj\n<< /Type /XRef >>\nendobj\n"
  let without_xref_streams = @reader.pdf_reader_reconstruction_trailers(
    data, false, reader_reconstruction_trailer_parser_for_test, reader_reconstruction_xref_stream_trailer_parser_for_test,
  )
  let with_xref_streams = @reader.pdf_reader_reconstruction_trailers(
    data, true, reader_reconstruction_trailer_parser_for_test, reader_reconstruction_xref_stream_trailer_parser_for_test,
  )
  @test.assert_eq(without_xref_streams.length(), 0)
  @test.assert_eq(with_xref_streams.length(), 1)
  @test.assert_eq(
    with_xref_streams[0],
    PdfDictionary([(@reader.pdf_reader_size_name(), PdfInteger(2))]),
  )
}
