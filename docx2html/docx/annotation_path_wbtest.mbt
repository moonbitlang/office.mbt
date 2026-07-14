///|
test "annotation scanner and verification share bounded path materialization" {
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r/></w:p></w:body></w:document>
  let verify_budget = AnnotationPathBudget::new(None, max_chars=10)
  let document = @document.document([@document.paragraph([@document.run([])])])
  try build_verify_context(document, [], [], [], [], [], verify_budget) catch {
    InvalidXml(message~) =>
      inspect(message, content="XML materialized character budget exceeded")
    _ => fail("expected verification path materialization to be bounded")
  } noraise {
    _ => fail("expected verification paths to exhaust their budget")
  }

  // Verification retains 25 path characters for this p/r tree. The scanner
  // would retain another 13; one shared 30-character envelope therefore
  // admits verification but rejects the second raw-scan copy.
  let shared_budget = AnnotationPathBudget::new(None, max_chars=30)
  ignore(build_verify_context(document, [], [], [], [], [], shared_budget))
  try scan_story(@utf8.encode(source), path_budget=shared_budget) catch {
    InvalidXml(message~) =>
      inspect(message, content="XML materialized character budget exceeded")
    _ => fail("expected shared scanner path materialization to be bounded")
  } noraise {
    _ =>
      fail("expected retained verification and scanner paths to share a budget")
  }
}
