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
test "rows get_row_opts reflects dimensions" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell("A1", "A")
  sheet.set_row_height(2, 18.5)
  sheet.set_row_visible(2, false)
  sheet.set_row_outline_level(2, 2)
  sheet.set_row_style(2, 3)
  let rows = sheet.rows()
  inspect(rows.next(), content="true")
  inspect(rows.row_index(), content="Some(1)")
  let first_opts = rows.get_row_opts()
  inspect(first_opts.height, content="15")
  inspect(first_opts.hidden, content="false")
  inspect(first_opts.style_id, content="0")
  inspect(first_opts.outline_level, content="0")
  inspect(rows.next(), content="true")
  inspect(rows.row_index(), content="Some(2)")
  let second_opts = rows.get_row_opts()
  inspect(second_opts.height, content="18.5")
  inspect(second_opts.hidden, content="true")
  inspect(second_opts.style_id, content="3")
  inspect(second_opts.outline_level, content="2")
}

///|
test "rows error and close are no-ops" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let rows = workbook.rows("Sheet1")
  inspect(rows.error(), content="None")
  rows.close()
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
