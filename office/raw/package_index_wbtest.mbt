///|
test "XLSX relationship IDs use one bounded lookup index" {
  let relationships : Array[RawRelationship] = []
  let prefix = "relationship-id-with-a-long-common-prefix-"
  for ordinal in 0..<512 {
    relationships.push({
      id: prefix + ordinal.to_string(),
      kind: transitional_office_relationship_prefix + "worksheet",
      target: "xl/worksheets/sheet\{ordinal}.xml",
      external: false,
    })
  }
  let index = relationship_index_by_id(relationships)
  assert_eq(index.length(), relationships.length())
  for ordinal in [0, 255, 511] {
    let id = prefix + ordinal.to_string()
    guard index.get(id) is Some(relationship) else {
      fail("relationship index lost ID '\{id}'")
    }
    assert_eq(relationship.target, "xl/worksheets/sheet\{ordinal}.xml")
  }
}
