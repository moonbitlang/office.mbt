///|
fn reader_reconstruction_section_scan_entry_for_test(
  object_number : Int,
  offset : Int,
) -> @reader.PdfClassicXRefEntry {
  { object_number, offset, generation: 0, in_use: true, object_stream: None }
}

///|
fn reader_reconstruction_section_scan_section_for_test(
  object_number : Int,
  offset : Int,
  stream_object_offset? : Int? = None,
) -> @reader.PdfXRefSection {
  {
    entries: [
      reader_reconstruction_section_scan_entry_for_test(object_number, offset),
    ],
    trailer: PdfDictionary([]),
    stream_object_number: Some(object_number),
    stream_object_offset,
  }
}

///|
fn reader_reconstruction_classic_section_parser_for_test(
  cursor : @core.ByteCursor,
  position : Int,
) -> (@reader.PdfXRefSection, Int) raise @core.PdfError {
  cursor.seek_absolute(position)
  if position == 3 {
    (
      reader_reconstruction_section_scan_section_for_test(1, position),
      position + 4,
    )
  } else {
    raise XRefExpected
  }
}

///|
fn reader_reconstruction_xref_stream_section_parser_for_test(
  cursor : @core.ByteCursor,
  position : Int,
) -> (@reader.PdfXRefSection, Int) raise @core.PdfError {
  cursor.seek_absolute(position)
  if position == 0 {
    (
      reader_reconstruction_section_scan_section_for_test(
        1,
        position,
        stream_object_offset=Some(position),
      ),
      17,
    )
  } else {
    raise XRefExpected
  }
}

///|
test "reconstructed classic xref section scanner advances after failed matches" {
  let sections = @reader.pdf_reader_reconstruction_classic_xref_sections(
    b"abcxrefjunkxref", reader_reconstruction_classic_section_parser_for_test,
  )
  @test.assert_eq(sections.length(), 1)
  @test.assert_eq(sections[0].0, 3)
  @test.assert_eq(sections[0].1.entries[0].object_number, 1)
}

///|
test "reconstructed xref stream section scanner skips malformed object candidates" {
  let sections = @reader.pdf_reader_reconstruction_xref_stream_sections(
    b"1 0 obj\nok\nendobj\n2 0 obj\nbad\nendobj\n", reader_reconstruction_xref_stream_section_parser_for_test,
  )
  @test.assert_eq(sections.length(), 1)
  @test.assert_eq(sections[0].entries[0].object_number, 1)
}
