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
