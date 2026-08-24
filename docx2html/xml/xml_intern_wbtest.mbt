///|
/// Pins the invalidation MECHANISM, not just its observable output: budget
/// accounting never charges cache-teardown work, so a blackbox test cannot
/// tell O(1) instance replacement apart from an O(capacity) `clear()` per
/// binding change. Instance identity can. A `clear()` regression would keep
/// the warmed instance (emptied), failing both assertions below.
test "invalidation replaces cache instances instead of rescanning them" {
  let parser = XmlParser::{
    source: "",
    pos: 0,
    depth: 0,
    strict: true,
    budget: None,
    source_encoding: None,
    retain_namespace_declarations: false,
    seen_xml_declaration: false,
    root_namespace_uri: None,
    namespace_map: build_direct_namespace_lookup(Map([])),
    namespaces: SortedMap([]),
    expanded_element_names: SortedMap([]),
    expanded_attribute_names: SortedMap([]),
    mapped_element_names: SortedMap([]),
    mapped_attribute_names: SortedMap([]),
  }
  for index in 0..<512 {
    parser.expanded_element_names["name\{index}"] = "expanded\{index}"
    parser.mapped_attribute_names["attr\{index}"] = "mapped\{index}"
  }
  let warmed_expanded = parser.expanded_element_names
  let warmed_mapped = parser.mapped_attribute_names
  parser.invalidate_name_caches()
  assert_false(physical_equal(warmed_expanded, parser.expanded_element_names))
  assert_false(physical_equal(warmed_mapped, parser.mapped_attribute_names))
  assert_eq(warmed_expanded.length(), 512)
  assert_eq(warmed_mapped.length(), 512)
  assert_eq(parser.expanded_element_names.length(), 0)
  assert_eq(parser.expanded_attribute_names.length(), 0)
  assert_eq(parser.mapped_element_names.length(), 0)
  assert_eq(parser.mapped_attribute_names.length(), 0)
}
