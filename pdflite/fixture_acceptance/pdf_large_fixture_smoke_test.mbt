///|
async test "large checked-in PDF fixture rewrites within sane size bounds" {
  let path = "fixtures/camlpdf/introduction_to_camlpdf.pdf"
  let original_bytes = fixture_acceptance_bytes_for_test(path)
  if original_bytes.length() < 100_000 {
    fail(path + " is no longer a large fixture")
  }
  let original = try! @pdflite.pdf_read_document_from_bytes(original_bytes)
  @test.assert_eq(try! original.endpage(), 10)
  @test.assert_eq(original.object_count(), 102)
  let rewritten = try! @pdflite.pdf_write_document(original)
  if rewritten.length() == 0 {
    fail(path + " produced empty rewritten output")
  }
  if rewritten.length() < original_bytes.length() / 2 {
    fail(path + " rewrite was unexpectedly small")
  }
  if rewritten.length() > original_bytes.length() * 2 {
    fail(path + " rewrite was unexpectedly large")
  }
  let reparsed = try! @pdflite.pdf_read_document_from_bytes(rewritten)
  @test.assert_eq(try! reparsed.endpage(), 10)
  @test.assert_eq(reparsed.object_count(), 102)
}
