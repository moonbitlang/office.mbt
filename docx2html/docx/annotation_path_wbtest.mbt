///|
test "annotation scanner and verification share bounded path materialization" {
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r/></w:p></w:body></w:document>
  let verify_budget = AnnotationPathBudget::new(None, max_chars=10)
  let document = @document.document([@document.paragraph([@document.run([])])])
  try build_verify_context(document, [], [], [], [], [], verify_budget) catch {
    ResourceLimit(limit~, message~) => {
      debug_inspect(limit, content="DocxXmlMaterializedCharacters")
      inspect(message, content="XML materialized character budget exceeded")
    }
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
    ResourceLimit(limit~, message~) => {
      debug_inspect(limit, content="DocxXmlMaterializedCharacters")
      inspect(message, content="XML materialized character budget exceeded")
    }
    _ => fail("expected shared scanner path materialization to be bounded")
  } noraise {
    _ =>
      fail("expected retained verification and scanner paths to share a budget")
  }
}

///|
fn annotation_hash_clustered_prefixes(
  count : Int,
  bucket_mask : Int,
) -> Array[String] {
  let prefixes : Array[String] = []
  let mut candidate = 0
  while prefixes.length() < count {
    let prefix = "n\{candidate}"
    if (prefix.hash() & bucket_mask) == 0 {
      prefixes.push(prefix)
    }
    candidate += 1
  }
  prefixes
}

///|
test "annotation namespace scope ignores deterministic hash clustering" {
  let source = StringBuilder()
  source.write_string(
    "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"",
  )
  for index, prefix in annotation_hash_clustered_prefixes(256, 0x3FF) {
    assert_eq(prefix.hash() & 0x3FF, 0)
    source.write_string(" xmlns:\{prefix}=\"urn:mbt:\{index}\"")
  }
  source.write_string("><w:body><w:p/></w:body></w:document>")
  let scan = scan_story(@utf8.encode(source.to_string()))
  assert_true(scan.root is Some(_))
  assert_eq(scan.root_namespace_uri, Some(WORDPROCESSINGML_NAMESPACE))
  assert_eq(scan.warnings.length(), 0)
}
