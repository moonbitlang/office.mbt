///|
test "search_sheet: regex basics (anchors, escapes, classes, repeats)" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell("A1", "abc123")
  sheet.set_cell("A2", "hello-world")
  sheet.set_cell("A3", "a^b")
  sheet.set_cell("A4", "abc$")
  sheet.set_cell("A5", "abbbc")
  sheet.set_cell("A6", "a1Z")
  debug_inspect(workbook.search_sheet("Sheet1", "abc123"), content="[\"A1\"]")
  debug_inspect(
    workbook.search_sheet("Sheet1", "^abc", reg=true),
    content="[\"A1\", \"A4\"]",
  )
  debug_inspect(
    workbook.search_sheet("Sheet1", "123$", reg=true),
    content="[\"A1\"]",
  )
  debug_inspect(
    workbook.search_sheet("Sheet1", "^a\\^b$", reg=true),
    content="[\"A3\"]",
  )

  // Escaped '$' should not be treated as an end anchor.
  debug_inspect(
    workbook.search_sheet("Sheet1", "abc\\$", reg=true),
    content="[\"A4\"]",
  )

  // Any char + repeat.
  debug_inspect(
    workbook.search_sheet("Sheet1", "h.llo.*", reg=true),
    content="[\"A2\"]",
  )
  debug_inspect(
    workbook.search_sheet("Sheet1", "^ab*c$", reg=true),
    content="[\"A5\"]",
  )

  // Character classes (with range).
  debug_inspect(
    workbook.search_sheet("Sheet1", "^[a-z][0-9][A-Z]$", reg=true),
    content="[\"A6\"]",
  )

  // Unclosed class is treated as literal '['.
  debug_inspect(workbook.search_sheet("Sheet1", "[", reg=true), content="[]")
}
