///|
test "dingbat lookup dispatches every supported font without case sensitivity" {
  assert_eq(dingbat_to_unicode("symbol", 100), Some("\u{3B4}"))
  assert_eq(dingbat_to_unicode("Webdings", 100), Some("\u{1F6E1}"))
  assert_eq(dingbat_to_unicode("Wingdings", 100), Some("\u{264E}"))
  assert_eq(dingbat_to_unicode("Wingdings 2", 100), Some("\u{1F667}"))
  assert_eq(dingbat_to_unicode("Wingdings 3", 100), Some("\u{1F8AA}"))
}

///|
test "dingbat lookup rejects unsupported fonts and codes" {
  assert_eq(dingbat_to_unicode("Arial", 100), None)
  assert_eq(dingbat_to_unicode("Symbol", -1), None)
}
