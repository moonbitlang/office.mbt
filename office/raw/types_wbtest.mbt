///|
fn raw_test_character_count(value : String) -> Int {
  let mut count = 0
  for _ in value {
    count = count + 1
  }
  count
}

///|
test "raw text limits count Unicode scalars without eager character arrays" {
  let exact = "😀".repeat(1024)
  assert_true(raw_text_within_scalar_limit(exact, 1024))
  assert_false(raw_text_within_scalar_limit(exact + "😀", 1024))
  let malformed = String::from_array([(0xD800).unsafe_to_char()])
  assert_false(raw_text_is_well_formed(malformed))
  assert_eq(bounded_raw_text(malformed, 80), "<invalid UTF-16>")
}

///|
test "bounded raw diagnostics count the truncation marker inside the limit" {
  let exact = bounded_raw_text(
    "x".repeat(raw_max_error_message),
    raw_max_error_message,
  )
  assert_eq(raw_test_character_count(exact), raw_max_error_message)
  assert_false(exact.has_suffix("…"))
  let truncated = bounded_raw_text(
    "x".repeat(raw_max_error_message + 1),
    raw_max_error_message,
  )
  assert_eq(raw_test_character_count(truncated), raw_max_error_message)
  assert_true(truncated.has_suffix("…"))
}

///|
test "raw inventory enforces its aggregate serialization budget" {
  let oversized = "x".repeat(1024 * 1024)
  let parts : Array[RawPartInfo] = []
  for index in 0..<17 {
    parts.push({
      name: "part-\{index}.xml",
      content_type: oversized,
      xml: true,
      size: 0,
      aliases: [],
    })
  }
  try check_inventory_serialization_budget(parts) catch {
    RawError(code~, ..) => assert_eq(code, "office.raw.resource_limit")
  } noraise {
    _ => fail("expected the inventory serialization budget to fail closed")
  }
}
