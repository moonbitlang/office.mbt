///|
fn reader_xref_entry_for_test(
  object_number : Int,
  offset : Int,
  in_use? : Bool = true,
) -> @reader.PdfClassicXRefEntry {
  { object_number, offset, generation: 0, in_use, object_stream: None }
}

///|
test "classic xref lookup ignores free entries" {
  let entries : ReadOnlyArray[@reader.PdfClassicXRefEntry] = [
    reader_xref_entry_for_test(4, 40, in_use=false),
    reader_xref_entry_for_test(4, 44),
  ]
  @test.assert_eq(@reader.pdf_classic_xref_lookup(entries, 4), Some(entries[1]))
  @test.assert_eq(@reader.pdf_classic_xref_lookup(entries, 9), None)
}

///|
test "classic xref index keeps newest active entry" {
  let newer = reader_xref_entry_for_test(7, 70)
  let older = reader_xref_entry_for_test(7, 17)
  let entries : ReadOnlyArray[@reader.PdfClassicXRefEntry] = [newer, older]
  let index = @reader.pdf_classic_xref_index(entries)
  @test.assert_eq(index.lookup(7), Some(newer))
}

///|
test "classic xref merge keeps first entry for each object" {
  let target = [reader_xref_entry_for_test(1, 10)]
  let seen = @core.pdf_number_set([1])
  @reader.pdf_classic_xrefs_add_newer_first_with_seen(target, seen, [
    reader_xref_entry_for_test(1, 99),
    reader_xref_entry_for_test(2, 20),
  ])
  @test.assert_eq(target, [
    reader_xref_entry_for_test(1, 10),
    reader_xref_entry_for_test(2, 20),
  ])
}
