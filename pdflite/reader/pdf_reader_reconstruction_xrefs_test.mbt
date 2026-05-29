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
  stream_object_number? : Int? = None,
  stream_object_offset? : Int? = None,
) -> @reader.PdfXRefSection {
  {
    entries,
    trailer: PdfDictionary([]),
    stream_object_number,
    stream_object_offset,
  }
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
