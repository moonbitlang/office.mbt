///|
test "comment fragments apply the escaped-byte cap before serialization" {
  let specification = @docx.comment_spec(author="D1", from=0, to=0, [
    @document.paragraph([@document.run([@document.text("&".repeat(100))])]),
  ])
  try
    @docx.comment_definition_fragment(
      specification,
      id="0",
      max_output_bytes=200,
    )
  catch {
    InvalidXml(message~) =>
      inspect(message, content="XML serialization byte limit exceeded")
    _ => fail("expected the escaped fragment to exceed its byte cap")
  } noraise {
    _ => fail("expected the escaped fragment to exceed its byte cap")
  }
}

///|
test "comment fragments preserve an explicitly selected Strict WML namespace" {
  let strict = "http://purl.oclc.org/ooxml/wordprocessingml/main"
  let transitional = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
  let (start, end) = @docx.comment_anchor_fragments(
    id="7",
    wordprocessing_namespace=strict,
  )
  assert_true(start.contains("xmlns:w=\"\{strict}\""))
  assert_true(end.contains("xmlns:w=\"\{strict}\""))
  assert_false(start.contains(transitional))
  assert_false(end.contains(transitional))
  let specification = @docx.comment_spec(author="Strict", from=0, to=0, [
    @document.paragraph([@document.run([@document.text("strict body")])]),
  ])
  let definition = @docx.comment_definition_fragment(
    specification,
    id="7",
    wordprocessing_namespace=strict,
  )
  assert_true(definition.contains("xmlns:w=\"\{strict}\""))
  assert_false(definition.contains(transitional))
}
