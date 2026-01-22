///|
test "rows iterator includes dimension-only rows" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_row(1, ["A"])
  sheet.set_row_height(2, 18.0)
  sheet.set_row(3, ["C"])
  let rows = workbook.rows("Sheet1")
  inspect(rows.next(), content="true")
  inspect(rows.row_index(), content="Some(1)")
  inspect(rows.columns(), content="[\"A\"]")
  inspect(rows.next(), content="true")
  inspect(rows.row_index(), content="Some(2)")
  inspect(rows.columns(), content="[]")
  inspect(rows.next(), content="true")
  inspect(rows.row_index(), content="Some(3)")
  inspect(rows.columns(), content="[\"C\"]")
  inspect(rows.next(), content="false")
}

///|
test "cols iterator yields columns by max cell col" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell("A1", "A")
  sheet.set_cell("C2", "C")
  let cols = sheet.cols()
  inspect(cols.next(), content="true")
  inspect(cols.col_index(), content="Some(1)")
  inspect(cols.rows(), content="[\"A\", \"\"]")
  inspect(cols.next(), content="true")
  inspect(cols.col_index(), content="Some(2)")
  inspect(cols.rows(), content="[\"\", \"\"]")
  inspect(cols.next(), content="true")
  inspect(cols.col_index(), content="Some(3)")
  inspect(cols.rows(), content="[\"\", \"C\"]")
  inspect(cols.next(), content="false")
}

///|
test "get_rows and get_cols expand gaps" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_row(1, ["A"])
  sheet.set_row(3, ["C"])
  let rows = sheet.get_rows()
  inspect(rows, content="[[\"A\"], [], [\"C\"]]")
  let cols = sheet.get_cols()
  inspect(cols, content="[[\"A\", \"\", \"C\"]]")
}
