///|
test "rich text truncate utf16 handles non-positive limit" {
  inspect(truncate_utf16_units("abc", 0), content="")
  inspect(truncate_utf16_units("abc", -1), content="")
}

///|
test "rich text truncate runs supports partial and exact limits" {
  let runs : Array[RichTextRun] = [
    { text: "AB", font: None },
    { text: "C", font: None },
  ]
  debug_inspect(
    rich_text_truncate_runs(runs, 1),
    content=(
      #|[{ text: "A", font: None }]
    ),
  )
  debug_inspect(
    rich_text_truncate_runs(runs, 2),
    content=(
      #|[{ text: "AB", font: None }]
    ),
  )
}
