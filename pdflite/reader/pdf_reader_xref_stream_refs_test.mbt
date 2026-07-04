///|
test "xref stream ref set tracks offsets per object number" {
  let refs = @reader.pdf_reader_xref_stream_ref_set([(2, 20), (2, 40), (3, 20)])
  @test.assert_eq(refs.contains(2, 20), true)
  @test.assert_eq(refs.contains(2, 40), true)
  @test.assert_eq(refs.contains(3, 20), true)
  @test.assert_eq(refs.contains(2, 10), false)
  @test.assert_eq(refs.contains(4, 20), false)
}
