///|
test "worksheet cell index: set/get paths preserve values and styles" {
  let sheet = Worksheet::new("Sheet1")
  sheet.set_cell("A1", "one")
  sheet.set_cell("A1", "two")
  sheet.set_cell_style("A1", 7)
  sheet.set_cell_formula("C1", "SUM(1,1)", value="2")
  inspect(sheet.get_cell("A1"), content="Some(\"two\")")
  inspect(sheet.get_cell_style("A1"), content="Some(7)")
  inspect(sheet.get_cell_formula("C1"), content="Some(\"SUM(1,1)\")")
}

///|
test "worksheet cell index: invalidates across row/col structural edits" {
  let sheet = Worksheet::new("Sheet1")
  sheet.set_cell("A1", "a")
  sheet.set_cell("C2", "c")
  ignore(sheet.get_cell("A1"))
  ignore(sheet.get_cell("C2"))
  sheet.insert_rows(1, 1)
  inspect(sheet.get_cell("A2"), content="Some(\"a\")")
  inspect(sheet.get_cell("C3"), content="Some(\"c\")")
  sheet.remove_cols(2, 1)
  inspect(sheet.get_cell("A2"), content="Some(\"a\")")
  inspect(sheet.get_cell("B3"), content="Some(\"c\")")
  sheet.set_cell("D4", "d")
  inspect(sheet.get_cell("D4"), content="Some(\"d\")")
}

///|
test "worksheet cell index: formula opts array upserts existing cells" {
  let sheet = Worksheet::new("Sheet1")
  sheet.set_cell("A1", "seed")
  let opts = FormulaOpts::array("A1:B1")
  sheet.set_cell_formula_opts("A1", "ROW()", opts~, value="1")
  inspect(sheet.cells().length(), content="2")
  sheet.set_cell_formula_opts("A1", "ROW()", opts~, value="1")
  inspect(sheet.cells().length(), content="2")
}
