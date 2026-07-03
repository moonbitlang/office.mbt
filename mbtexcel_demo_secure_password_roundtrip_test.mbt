///|
test "demo secure password: encrypted read/write roundtrip remains stable" {
  let password = "moonbit"
  let bytes = @demos.demo_secure_bytes(password~)

  let bad : Result[@xlsx.Workbook, Error] = try? read_with_password(
    bytes, "wrong-password",
  )
  inspect(bad is Err(_), content="true")

  let parsed = read_with_password(bytes, password)
  debug_inspect(parsed.sheet_name(0), content="Some(\"Secure\")")
  debug_inspect(
    parsed.get_cell("Secure", "A1"),
    content="Some(\"This workbook is password-protected.\")",
  )
  debug_inspect(parsed.get_cell("Secure", "B4"), content="Some(\"moonbit\")")

  let encrypted_roundtrip = write_with_password(parsed, password)
  let parsed_roundtrip = read_with_password(encrypted_roundtrip, password)
  debug_inspect(parsed_roundtrip.sheet_name(0), content="Some(\"Secure\")")
  debug_inspect(
    parsed_roundtrip.get_cell("Secure", "A2"),
    content="Some(\"Try opening it in Excel and enter the password.\")",
  )
  debug_inspect(
    parsed_roundtrip.get_cell("Secure", "B4"),
    content="Some(\"moonbit\")",
  )
}
