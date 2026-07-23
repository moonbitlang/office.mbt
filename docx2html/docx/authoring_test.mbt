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

///|
test "image_occurrences counts every reference, image_paths deduplicates" {
  let script = authoring_script(
    (
      #|{"schema": "docx.batch/2", "ops": [
      #|  {"op": "paragraph", "params": {"runs": [
      #|    {"image": {"path": "a.png"}}, {"image": {"path": "a.png"}},
      #|    {"image": {"path": "b.png"}}
      #|  ]}}
      #|]}
    ),
  )
  // three occurrences (two of a.png), two distinct assets to load
  assert_eq(script.image_occurrences().length(), 3)
  assert_eq(script.image_paths().length(), 2)
}

///|
test "author_docx_bytes refuses over the emitted-media part ceiling" {
  let runs = StringBuilder::new()
  for i in 0..<1001 {
    if i > 0 {
      runs.write_string(",")
    }
    runs.write_string("{\"image\":{\"path\":\"d.png\"}}")
  }
  let script = authoring_script(
    "{\"schema\":\"docx.batch/2\",\"ops\":[{\"op\":\"paragraph\",\"params\":{\"runs\":[" +
    runs.to_string() +
    "]}}]}",
  )
  // the parts ceiling is checked BEFORE build_body, so no image bytes are
  // needed to trip it
  try @docx.author_docx_bytes(script, Map::new()) |> ignore catch {
    WriteResourceLimit(kind~, ..) => assert_eq(kind, "media_parts")
    err => fail("expected a media-parts limit, got: \{err.description()}")
  } noraise {
    _ => fail("expected the emitted-media part ceiling to be exceeded")
  }
}
