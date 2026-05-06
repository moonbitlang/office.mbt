///|
fn writer_wb_bytes_for_test(values : ArrayView[Int]) -> PdfBytes {
  try! pdf_bytes_of_int_array(values)
}

///|
test "pdf_writer_changed_object_numbers deduplicates changed event log" {
  let document = pdf_document_empty()
  document.objects.log.push((5, ObjectAltered))
  document.objects.log.push((3, ObjectAltered))
  document.objects.log.push((5, ObjectDeleted))
  document.objects.log.push((0, ObjectAltered))
  document.objects.log.push((-1, ObjectDeleted))
  document.objects.log.push((1, ObjectAltered))
  document.objects.log.push((3, ObjectDeleted))
  @test.assert_eq(pdf_writer_changed_object_numbers(document), [0, 1, 3, 5])
}

///|
test "pdf_writer_int_array_contains handles present and missing values" {
  let values : Array[Int] = [0, 2, 4]
  @test.assert_eq(pdf_writer_int_array_contains(values[:], 2), true)
  @test.assert_eq(pdf_writer_int_array_contains(values[:], 3), false)
}

///|
test "pdf_writer_push_classic_xref_subsection scans sorted xrefs in order" {
  let output : Array[Byte] = []
  let xrefs : Array[(Int, Int, Int)] = [(2, 33, 1), (4, 44, 2)]
  let xref_index : Ref[Int] = { val: 0 }
  pdf_writer_push_classic_xref_subsection(output, xrefs[:], 0, 3, xref_index)
  pdf_writer_push_classic_xref_subsection(output, xrefs[:], 4, 1, xref_index)
  @test.assert_eq(
    Bytes::from_array(output),
    @ascii.encode(
      "0 3\n0000000000 65535 f \n0000000000 65535 f \n0000000033 00001 n \n4 1\n0000000044 00002 n \n",
    ),
  )
}

///|
test "pdf_writer_xref_stream_data emits full table in object order" {
  let xrefs : Array[(Int, Int, Int)] = [(1, 20, 0), (3, 300, 2)]
  @test.assert_eq(
    pdf_writer_xref_stream_data(xrefs[:], 5, 4, 400),
    writer_wb_bytes_for_test([
      0, 0, 0, 0, 0, 255, 255, 1, 0, 0, 0, 20, 0, 0, 0, 0, 0, 0, 0, 255, 255, 1,
      0, 0, 1, 44, 0, 2, 1, 0, 0, 1, 144, 0, 0,
    ]),
  )
}

///|
test "pdf_writer_xref_stream_data_for_numbers emits sparse entries in order" {
  let xrefs : Array[(Int, Int, Int)] = [(2, 33, 1), (4, 44, 2)]
  let numbers : Array[Int] = [0, 2, 4, 5]
  @test.assert_eq(
    pdf_writer_xref_stream_data_for_numbers(xrefs[:], numbers[:], 5, 55),
    writer_wb_bytes_for_test([
      0, 0, 0, 0, 0, 255, 255, 1, 0, 0, 0, 33, 0, 1, 1, 0, 0, 0, 44, 0, 2, 1, 0,
      0, 0, 55, 0, 0,
    ]),
  )
}
