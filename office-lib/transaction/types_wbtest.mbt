///|
test "transaction text limits count Unicode scalar values" {
  let exact = "😀".repeat(transaction_max_part_length)
  assert_true(scan_text(exact, transaction_max_part_length) is Valid)
  assert_true(scan_text(exact + "😀", transaction_max_part_length) is TooLong)
}
