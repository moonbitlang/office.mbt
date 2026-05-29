///|
fn reader_reconstruction_plan_entry_for_test(
  object_number : Int,
  offset : Int,
) -> @reader.PdfClassicXRefEntry {
  { object_number, offset, generation: 0, in_use: true, object_stream: None }
}

///|
fn reader_reconstruction_plan_section_for_test(
  object_number : Int,
  offset : Int,
  trailer? : @syntax.PdfObject = PdfDictionary([]),
  stream_object_number? : Int? = None,
  stream_object_offset? : Int? = None,
) -> @reader.PdfXRefSection {
  {
    entries: [reader_reconstruction_plan_entry_for_test(object_number, offset)],
    trailer,
    stream_object_number,
    stream_object_offset,
  }
}

///|
fn reader_reconstruction_plan_classic_section_for_test(
  cursor : @core.ByteCursor,
  position : Int,
) -> (@reader.PdfXRefSection, Int) raise @core.PdfError {
  cursor.seek_absolute(position)
  if position == 0 {
    (
      reader_reconstruction_plan_section_for_test(
        1,
        position,
        trailer=PdfDictionary([(@reader.pdf_reader_root_name(), PdfIndirect(1))]),
      ),
      position + 4,
    )
  } else {
    raise XRefExpected
  }
}

///|
fn reader_reconstruction_plan_xref_stream_section_for_test(
  cursor : @core.ByteCursor,
  position : Int,
) -> (@reader.PdfXRefSection, Int) raise @core.PdfError {
  cursor.seek_absolute(position)
  (
    reader_reconstruction_plan_section_for_test(
      7,
      position,
      stream_object_number=Some(7),
      stream_object_offset=Some(position),
    ),
    position + 18,
  )
}

///|
fn reader_reconstruction_plan_object_xref_for_test(
  cursor : @core.ByteCursor,
  position : Int,
  _xrefs : ArrayView[@reader.PdfClassicXRefEntry],
  _xref_index : @reader.PdfClassicXRefIndex,
) -> (@reader.PdfClassicXRefEntry?, Int?) raise @core.PdfError {
  cursor.seek_absolute(position)
  (
    Some(reader_reconstruction_plan_entry_for_test(2, position)),
    Some(position + 18),
  )
}

///|
fn reader_reconstruction_plan_trailer_for_test(
  cursor : @core.ByteCursor,
  position : Int,
) -> @syntax.PdfObject raise @core.PdfError {
  cursor.seek_absolute(position)
  PdfDictionary([(@reader.pdf_reader_size_name(), PdfInteger(3))])
}

///|
fn reader_reconstruction_plan_xref_stream_trailer_for_test(
  cursor : @core.ByteCursor,
  position : Int,
) -> @syntax.PdfObject raise @core.PdfError {
  cursor.seek_absolute(position)
  PdfDictionary([(@reader.pdf_reader_size_name(), PdfInteger(8))])
}

///|
fn reader_reconstruction_plan_verify_for_test(
  _data : BytesView,
  _entries : ArrayView[@reader.PdfClassicXRefEntry],
  _xref_index : @reader.PdfClassicXRefIndex,
  _xref : @reader.PdfClassicXRefEntry,
) -> Bool {
  true
}

///|
fn reader_reconstruction_plan_callbacks_for_test() -> @reader.PdfReaderReconstructionCallbacks {
  {
    read_classic_xref_section_at: reader_reconstruction_plan_classic_section_for_test,
    read_xref_stream_section_at: reader_reconstruction_plan_xref_stream_section_for_test,
    read_object_xref_at_current: reader_reconstruction_plan_object_xref_for_test,
    read_trailer_at: reader_reconstruction_plan_trailer_for_test,
    read_xref_stream_trailer_at: reader_reconstruction_plan_xref_stream_trailer_for_test,
    verify_classic_xref_entry: reader_reconstruction_plan_verify_for_test,
  }
}

///|
test "reconstruction plan gathers classic object and trailer scan outputs" {
  let plan = @reader.pdf_reader_reconstruction_plan(
    b"xref\ntrailer\n1 0 obj\n<< >>\nendobj\n",
    false,
    reader_reconstruction_plan_callbacks_for_test(),
  )
  @test.assert_eq(plan.classic_xref_sections.length(), 1)
  @test.assert_eq(plan.xref_stream_sections.length(), 0)
  @test.assert_eq(plan.classic_xrefs[0].object_number, 1)
  @test.assert_eq(plan.object_xrefs[0].object_number, 2)
  @test.assert_eq(plan.object_xrefs[0].offset > 0, true)
  @test.assert_eq(plan.trailers.length(), 1)
  @test.assert_eq(plan.xref_coverage.contains(1, 0), true)
}

///|
test "reconstruction plan gates xref stream scans" {
  let without_streams = @reader.pdf_reader_reconstruction_plan(
    b"1 0 obj\n<< /Type /XRef >>\nendobj\n",
    false,
    reader_reconstruction_plan_callbacks_for_test(),
  )
  let with_streams = @reader.pdf_reader_reconstruction_plan(
    b"1 0 obj\n<< /Type /XRef >>\nendobj\n",
    true,
    reader_reconstruction_plan_callbacks_for_test(),
  )
  @test.assert_eq(without_streams.xref_stream_sections.length(), 0)
  @test.assert_eq(without_streams.trailers.length(), 0)
  @test.assert_eq(with_streams.xref_stream_sections.length(), 1)
  @test.assert_eq(with_streams.trailers.length(), 1)
  @test.assert_eq(with_streams.xref_coverage.contains(7, 0), true)
}
