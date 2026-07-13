///|
fn raw_test_character_count(value : String) -> Int {
  let mut count = 0
  for _ in value {
    count = count + 1
  }
  count
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
