///|
test "rows iterator includes dimension-only rows" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_row(1, ["A"])
  sheet.set_row_height(2, 18.0)
  sheet.set_row(3, ["C"])
  let rows = workbook.rows("Sheet1")
  inspect(rows.next(), content="true")
  debug_inspect(rows.row_index(), content="Some(1)")
  let row1 = rows.columns() catch {
    err => fail("row1 columns failed: \{repr(err)}")
  }
  debug_inspect(row1, content="[\"A\"]")
  inspect(rows.next(), content="true")
  debug_inspect(rows.row_index(), content="Some(2)")
  let row2 = rows.columns() catch {
    err => fail("row2 columns failed: \{repr(err)}")
  }
  debug_inspect(row2, content="[]")
  inspect(rows.next(), content="true")
  debug_inspect(rows.row_index(), content="Some(3)")
  let row3 = rows.columns() catch {
    err => fail("row3 columns failed: \{repr(err)}")
  }
  debug_inspect(row3, content="[\"C\"]")
  inspect(rows.next(), content="false")
}

///|
test "rows get_row_opts reflects dimensions" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell("A1", "A")
  sheet.set_row_height(2, 18.5)
  sheet.set_row_visible(2, false)
  sheet.set_row_outline_level(2, 2)
  sheet.set_row_style(2, 3)
  let rows = sheet.rows()
  inspect(rows.next(), content="true")
  debug_inspect(rows.row_index(), content="Some(1)")
  let first_opts = rows.get_row_opts()
  inspect(first_opts.height, content="15")
  inspect(first_opts.hidden, content="false")
  inspect(first_opts.style_id, content="0")
  inspect(first_opts.outline_level, content="0")
  inspect(rows.next(), content="true")
  debug_inspect(rows.row_index(), content="Some(2)")
  let second_opts = rows.get_row_opts()
  inspect(second_opts.height, content="18.5")
  inspect(second_opts.hidden, content="true")
  inspect(second_opts.style_id, content="3")
  inspect(second_opts.outline_level, content="2")
}

///|
test "rows error and close are no-ops" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let rows = workbook.rows("Sheet1")
  debug_inspect(rows.error(), content="None")
  rows.close()
  inspect(rows.next(), content="false")
}

///|
test "rows columns honors options" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell_float("Sheet1", "A1", 1.0)
  let style_id = workbook.add_style(@xlsx.Style::builtin_number_format(2))
  workbook.set_cell_style("Sheet1", "A1", style_id)
  let rows = workbook.rows("Sheet1")
  inspect(rows.next(), content="true")
  let formatted = rows.columns() catch {
    err => fail("formatted columns failed: \{repr(err)}")
  }
  debug_inspect(formatted, content="[\"1.00\"]")
  let raw_opts = @xlsx.Options::with_values(raw_cell_value=true)
  let raw_values = rows.columns(options=raw_opts) catch {
    err => fail("raw columns failed: \{repr(err)}")
  }
  debug_inspect(raw_values, content="[\"1\"]")
}

///|
test "cols iterator yields columns by max cell col" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell("A1", "A")
  sheet.set_cell("C2", "C")
  let cols = sheet.cols()
  inspect(cols.next(), content="true")
  debug_inspect(cols.col_index(), content="Some(1)")
  debug_inspect(cols.rows(), content="[\"A\", \"\"]")
  inspect(cols.next(), content="true")
  debug_inspect(cols.col_index(), content="Some(2)")
  debug_inspect(cols.rows(), content="[\"\", \"\"]")
  inspect(cols.next(), content="true")
  debug_inspect(cols.col_index(), content="Some(3)")
  debug_inspect(cols.rows(), content="[\"\", \"C\"]")
  inspect(cols.next(), content="false")
}

///|
test "get_rows and get_cols expand gaps" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_row(1, ["A"])
  sheet.set_row(3, ["C"])
  let rows = sheet.get_rows()
  debug_inspect(rows, content="[[\"A\"], [], [\"C\"]]")
  let cols = sheet.get_cols()
  debug_inspect(cols, content="[[\"A\", \"\", \"C\"]]")
}
