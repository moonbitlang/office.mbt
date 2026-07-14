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
