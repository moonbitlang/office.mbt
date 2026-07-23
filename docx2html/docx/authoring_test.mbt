// Tests for the shared fresh-DOCX authoring assembler.

///|
fn authoring_script(text : String) -> @batch.BatchScript raise {
  @batch.parse_batch(@json.parse(text))
}

///|
test "author_docx_bytes builds a structurally valid package" {
  let script = authoring_script(
    (
      #|{"schema": "docx.batch/2", "ops": [
      #|  {"op": "paragraph", "params": {"text": "Hello", "style": "Heading1"}},
      #|  {"op": "paragraph", "params": {"runs": [{"text": "bold", "bold": true}]}}
      #|]}
    ),
  )
  let bytes = @docx.author_docx_bytes(script, Map::new())
  // the built package passes the structural validity tier
  let findings = @opc.validate_docx_package(bytes)
  assert_eq(findings.length(), 0)
}

///|
test "author_docx_bytes refuses over the serialization ceiling with a typed limit" {
  let script = authoring_script(
    (
      #|{"schema": "docx.batch/2", "ops": [
      #|  {"op": "paragraph", "params": {"text": "content that will not fit"}}
      #|]}
    ),
  )
  // a 1-byte output ceiling cannot hold a real package
  try
    @docx.author_docx_bytes(script, Map::new(), limits={
      max_output_bytes: 1,
      max_entries: 64,
      max_entry_uncompressed_bytes: 1 << 20,
      max_total_uncompressed_bytes: 1 << 20,
    })
    |> ignore
  catch {
    WriteResourceLimit(kind~, ..) => assert_eq(kind, "output_bytes")
    err => fail("expected a typed write limit, got: \{err.description()}")
  } noraise {
    _ => fail("expected the serialization ceiling to be exceeded")
  }
}
