///|
test "capability registry claims only wired commands" {
  for command in @lib.capability_commands() {
    assert_true(is_implemented_command(command.name))
  }
  for name in ["help", "identify"] {
    assert_true(@lib.find_capability_command(name) is Some(_))
  }
}

///|
test "identify generated help marks its file positional as required" {
  let help = identify_command().render_help()
  assert_true(help.contains("<file>"))
  assert_false(help.contains("[file]"))
}

///|
test "bounded diagnostics do not amplify attacker-controlled tokens" {
  let long = "x".repeat(1_000)
  let bounded = bounded_text(long, 24)
  assert_eq(bounded.length(), 25)
  assert_true(bounded.has_suffix("…"))
  let error = unknown_help_token("format", long, ["docx", "xlsx"])
  assert_true(error.message.length() < 180)
  assert_false(error.message.contains("x".repeat(100)))
}

///|
test "output flag pre-scan respects the positional delimiter" {
  assert_eq(output_flags_from_args(["help", "--json"]), (true, false))
  assert_eq(
    output_flags_from_args(["identify", "--", "--json"]),
    (false, false),
  )
}

///|
test "help suggestions are deterministic and useful" {
  assert_eq(nearest_suggestion("xlxs", ["docx", "xlsx"]), Some("xlsx"))
  assert_eq(nearest_suggestion("wrod", ["word", "excel"]), Some("word"))
  assert_true(nearest_suggestion("unrelated", ["docx", "xlsx"]) is None)
  assert_true(
    nearest_suggestion("ppt", ["all", "docx", "word", "xlsx", "excel"]) is None,
  )
}

///|
test "human help contains no deferred PowerPoint or MCP surface" {
  let output = render_overview(true)
  assert_true(output.contains("docx"))
  assert_true(output.contains("xlsx"))
  assert_true(output.contains("identify"))
  assert_false(output.to_lower().contains("ppt"))
  assert_false(output.to_lower().contains("mcp"))
}
