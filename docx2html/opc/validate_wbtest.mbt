///|
test "relationship semantic validation polls cancellation within elements" {
  let source =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    #|  <Relationship Id="rId1" Type="https://example.com/type" Target="target.xml"/>
    #|</Relationships>
  let root = read_opc_relationships_xml_limited(
    @utf8.encode(source),
    @xml.xml_read_budget(
      max_source_units=4096,
      max_tokens=64,
      max_materialized_chars=4096,
      max_token_chars=4096,
    ),
  )
  let mut checks = 0
  let findings = FindingCollector::new_with_xml_limits(
    8,
    256,
    256,
    1024,
    4096,
    64,
    4096,
    4096,
    () => {
      checks += 1
      checks >= 4
    },
  )
  let mut visits = 0
  let completed = for_each_relationship("_rels/.rels", root, findings, (
    _id,
    _kind,
    _target,
    _external,
  ) => visits += 1)
  assert_false(completed)
  assert_eq(checks, 4)
  assert_eq(visits, 0)
  assert_true(findings.report().findings_truncated())
}
