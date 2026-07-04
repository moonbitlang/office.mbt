///|
fn reader_reconstruction_xref_entry_for_test(
  object_number : Int,
  offset : Int,
) -> @reader.PdfClassicXRefEntry {
  { object_number, offset, generation: 0, in_use: true, object_stream: None }
}

///|
fn reader_reconstruction_xref_section_for_test(
  entries : Array[@reader.PdfClassicXRefEntry],
  trailer? : @syntax.PdfObject = PdfDictionary([]),
  stream_object_number? : Int? = None,
  stream_object_offset? : Int? = None,
) -> @reader.PdfXRefSection {
  { entries, trailer, stream_object_number, stream_object_offset }
}

///|
fn reader_reconstruction_verify_xref_for_test(
  _data : BytesView,
  _entries : ArrayView[@reader.PdfClassicXRefEntry],
  _xref_index : @reader.PdfClassicXRefIndex,
  _xref : @reader.PdfClassicXRefEntry,
) -> Bool {
  true
}

///|
fn reader_reconstruction_object_xref_parser_for_test(
  cursor : @core.ByteCursor,
  position : Int,
  _xrefs : ArrayView[@reader.PdfClassicXRefEntry],
  _xref_index : @reader.PdfClassicXRefIndex,
) -> (@reader.PdfClassicXRefEntry?, Int?) raise @core.PdfError {
  cursor.seek_absolute(position)
  (
    Some(reader_reconstruction_xref_entry_for_test(1, position)),
    Some(position + 18),
  )
}

///|
fn reader_reconstruction_object_xref_skip_parser_for_test(
  cursor : @core.ByteCursor,
  position : Int,
  _xrefs : ArrayView[@reader.PdfClassicXRefEntry],
  _xref_index : @reader.PdfClassicXRefIndex,
) -> (@reader.PdfClassicXRefEntry?, Int?) raise @core.PdfError {
  cursor.seek_absolute(position)
  if position == 0 {
    raise XRefExpected
  }
  (Some(reader_reconstruction_xref_entry_for_test(2, position)), None)
}

///|
fn reader_reconstruction_object_xref_none_parser_for_test(
  cursor : @core.ByteCursor,
  position : Int,
  _xrefs : ArrayView[@reader.PdfClassicXRefEntry],
  _xref_index : @reader.PdfClassicXRefIndex,
) -> (@reader.PdfClassicXRefEntry?, Int?) raise @core.PdfError {
  cursor.seek_absolute(position)
  (None, Some(position + 18))
}

///|
test "reconstructed xref stream entries keep newest section entries first" {
  let older = reader_reconstruction_xref_section_for_test([
    reader_reconstruction_xref_entry_for_test(1, 10),
    reader_reconstruction_xref_entry_for_test(2, 20),
  ])
  let newer = reader_reconstruction_xref_section_for_test([
    reader_reconstruction_xref_entry_for_test(2, 200),
    reader_reconstruction_xref_entry_for_test(3, 300),
  ])
  let xrefs = @reader.pdf_reader_reconstruction_xref_stream_entries([
    older, newer,
  ])
  @test.assert_eq([ for xref in xrefs => xref.object_number ], [2, 3, 1])
  @test.assert_eq([ for xref in xrefs => xref.offset ], [200, 300, 10])
}

///|
test "reconstructed classic xref entries keep newest section entries first" {
  let older = reader_reconstruction_xref_section_for_test([
    reader_reconstruction_xref_entry_for_test(4, 40),
    reader_reconstruction_xref_entry_for_test(5, 50),
  ])
  let newer = reader_reconstruction_xref_section_for_test([
    reader_reconstruction_xref_entry_for_test(5, 500),
    reader_reconstruction_xref_entry_for_test(6, 600),
  ])
  let xrefs = @reader.pdf_reader_reconstruction_classic_xref_entries([
    (100, older),
    (200, newer),
  ])
  @test.assert_eq([ for xref in xrefs => xref.object_number ], [5, 6, 4])
  @test.assert_eq([ for xref in xrefs => xref.offset ], [500, 600, 40])
}

///|
test "reconstructed object xref scanner records parsed candidates" {
  let xrefs = @reader.pdf_reader_reconstruction_object_xrefs(
    b"1 0 obj\n<< >>\nendobj\n", reader_reconstruction_object_xref_parser_for_test,
  )
  @test.assert_eq(xrefs.length(), 1)
  @test.assert_eq(xrefs[0].object_number, 1)
  @test.assert_eq(xrefs[0].offset, 0)
}

///|
test "reconstructed object xref scanner skips malformed candidates" {
  let xrefs = @reader.pdf_reader_reconstruction_object_xrefs(
    b"1 0 obj\nbad\nendobj\n2 0 obj\nok\nendobj\n", reader_reconstruction_object_xref_skip_parser_for_test,
  )
  @test.assert_eq(xrefs.length(), 1)
  @test.assert_eq(xrefs[0].object_number, 2)
  @test.assert_eq(xrefs[0].offset > 0, true)
}

///|
test "reconstructed object xref scanner ignores empty candidates" {
  let xrefs = @reader.pdf_reader_reconstruction_object_xrefs(
    b"1 0 obj\n<< >>\nendobj\n", reader_reconstruction_object_xref_none_parser_for_test,
  )
  @test.assert_eq(xrefs.length(), 0)
}

///|
test "reconstructed xref stream refs keep object numbers and offsets" {
  let refs = @reader.pdf_reader_reconstruction_xref_stream_refs([
    reader_reconstruction_xref_section_for_test(
      [],
      stream_object_number=Some(7),
      stream_object_offset=Some(70),
    ),
    reader_reconstruction_xref_section_for_test(
      [],
      stream_object_number=Some(9),
      stream_object_offset=Some(90),
    ),
  ])
  @test.assert_eq(refs, [(7, 70), (9, 90)])
}

///|
test "reconstructed xref coverage ignores xref stream sections without offsets" {
  let coverage = @reader.pdf_reader_reconstruction_xref_coverage(
    b"%PDF-1.5\n",
    [],
    [
      reader_reconstruction_xref_section_for_test(
        [],
        stream_object_number=Some(7),
        stream_object_offset=None,
      ),
    ],
    reader_reconstruction_verify_xref_for_test,
  )
  @test.assert_eq(coverage.contains(7, 0), false)
}

///|
test "reconstructed xref coverage skips free trailer root entries" {
  let root_entry : @reader.PdfClassicXRefEntry = {
    object_number: 3,
    offset: 30,
    generation: 0,
    in_use: false,
    object_stream: None,
  }
  let ordinary_free : @reader.PdfClassicXRefEntry = {
    object_number: 4,
    offset: 40,
    generation: 0,
    in_use: false,
    object_stream: None,
  }
  let section = reader_reconstruction_xref_section_for_test(
    [root_entry, ordinary_free],
    trailer=PdfDictionary([(@reader.pdf_reader_root_name(), PdfIndirect(3))]),
  )
  let coverage = @reader.pdf_reader_reconstruction_xref_coverage(
    b"%PDF-1.4\n",
    [(100, section)],
    [],
    reader_reconstruction_verify_xref_for_test,
  )
  @test.assert_eq(coverage.contains(3, 30), false)
  @test.assert_eq(coverage.contains(4, 40), true)
}

///|
test "reconstructed xref stream refs reject sections missing stream identity" {
  let refs : Result[Array[(Int, Int)], Error] = try
    @reader.pdf_reader_reconstruction_xref_stream_refs([
      reader_reconstruction_xref_section_for_test(
        [],
        stream_object_number=None,
        stream_object_offset=Some(70),
      ),
    ])
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard refs is Err(@core.PdfError::XRefEntryExpected) else {
    fail("expected XRefEntryExpected")
  }
}
