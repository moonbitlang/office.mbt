///|
test "cell reference conversions" {
  let pairs : Array[(String, (Int, Int))] = [
    ("A1", (1, 1)),
    ("Z1", (1, 26)),
    ("AA1", (1, 27)),
    ("AB10", (10, 28)),
    ("ZZ2", (2, 702)),
    ("AAA3", (3, 703)),
  ]
  for _, pair in pairs {
    let (reference, (row, col)) = pair
    let (r, c) = cell_ref_to_rc(reference)
    inspect(r == row && c == col, content="true")
    let round = cell_ref_from(row, col)
    inspect(round == reference, content="true")
  }
  @test.assert_raise(() => cell_ref_to_rc("1A"))
}

///|
test "worksheet cell access" {
  let sheet = Worksheet::new("Sheet1")
  sheet.set_cell_rc(2, 3, "value")
  debug_inspect(sheet.get_cell("C2"), content="Some(\"value\")")
  debug_inspect(sheet.get_cell_rc(2, 3), content="Some(\"value\")")
  sheet.set_cell("C2", "updated")
  debug_inspect(sheet.get_cell_rc(2, 3), content="Some(\"updated\")")
}

///|
test "workbook cell access" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell("Sheet1", "A1", "hello")
  debug_inspect(workbook.get_cell("Sheet1", "A1"), content="Some(\"hello\")")
  workbook.set_cell_rc("Sheet1", 2, 2, "world")
  debug_inspect(workbook.get_cell("Sheet1", "B2"), content="Some(\"world\")")
  @test.assert_raise(() => workbook.get_cell("Missing", "A1"))
}
