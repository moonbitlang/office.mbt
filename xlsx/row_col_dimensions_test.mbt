///|
test "row and column dimensions roundtrip" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let style_id = workbook.add_style(Style::new())
  workbook.set_row_height("Sheet1", 2, 18.5)
  workbook.set_row_visible("Sheet1", 2, false)
  workbook.set_row_outline_level("Sheet1", 2, 3)
  workbook.set_row_style("Sheet1", 2, style_id)
  workbook.set_col_width("Sheet1", 3, 12.25)
  workbook.set_col_visible("Sheet1", 3, false)
  workbook.set_col_outline_level("Sheet1", 3, 2)
  workbook.set_col_style("Sheet1", 3, style_id)
  let bytes = write(workbook)
  let parsed = read(bytes)
  inspect(parsed.get_row_height("Sheet1", 2), content="Some(18.5)")
  inspect(parsed.row_visible("Sheet1", 2), content="false")
  inspect(parsed.row_outline_level("Sheet1", 2), content="3")
  inspect(parsed.get_row_style("Sheet1", 2), content="Some(1)")
  inspect(parsed.get_col_width("Sheet1", 3), content="Some(12.25)")
  inspect(parsed.col_visible("Sheet1", 3), content="false")
  inspect(parsed.col_outline_level("Sheet1", 3), content="2")
  inspect(parsed.get_col_style("Sheet1", 3), content="Some(1)")
}

///|
test "insert and remove rows adjust ranges" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell("Sheet1", "A1", "a")
  workbook.set_cell("Sheet1", "B3", "b")
  workbook.merge_cells("Sheet1", "A1:B2")
  ignore(workbook.add_table("Sheet1", "C1:D3", "Table1", ["c1", "c2"]))
  workbook.add_sparkline("Sheet1", "E1", "A1:A3")
  workbook.set_row_height("Sheet1", 3, 15.0)
  workbook.insert_rows("Sheet1", 2, 1)
  inspect(workbook.get_cell("Sheet1", "A1"), content="Some(\"a\")")
  inspect(workbook.get_cell("Sheet1", "B4"), content="Some(\"b\")")
  let sheet = match workbook.sheet("Sheet1") {
    Some(value) => value
    None => fail("missing Sheet1")
  }
  let table = match sheet.tables().get(0) {
    Some(value) => value
    None => fail("missing table")
  }
  let group = match sheet.sparkline_groups().get(0) {
    Some(value) => value
    None => fail("missing sparkline group")
  }
  inspect(sheet.merged_cells(), content="[\"A1:B3\"]")
  inspect(table.range_ref, content="C1:D4")
  inspect(group.sparklines[0].range_ref, content="A1:A4")
  inspect(group.sparklines[0].location, content="E1")
  inspect(workbook.get_row_height("Sheet1", 4), content="Some(15)")
  workbook.remove_rows("Sheet1", 2, 1)
  inspect(workbook.get_cell("Sheet1", "A1"), content="Some(\"a\")")
  inspect(workbook.get_cell("Sheet1", "B3"), content="Some(\"b\")")
  let updated_table = match sheet.tables().get(0) {
    Some(value) => value
    None => fail("missing table")
  }
  let updated_group = match sheet.sparkline_groups().get(0) {
    Some(value) => value
    None => fail("missing sparkline group")
  }
  inspect(sheet.merged_cells(), content="[\"A1:B2\"]")
  inspect(updated_table.range_ref, content="C1:D3")
  inspect(updated_group.sparklines[0].range_ref, content="A1:A3")
  inspect(workbook.get_row_height("Sheet1", 3), content="Some(15)")
}

///|
test "insert and remove cols adjust ranges" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell("Sheet1", "A1", "a")
  workbook.set_cell("Sheet1", "C1", "c")
  workbook.merge_cells("Sheet1", "A1:C1")
  ignore(workbook.add_table("Sheet1", "B1:C3", "Table1", ["b1", "c1"]))
  workbook.add_sparkline("Sheet1", "D1", "A1:C1")
  workbook.set_col_width("Sheet1", 3, 11.0)
  workbook.insert_cols("Sheet1", 2, 1)
  inspect(workbook.get_cell("Sheet1", "A1"), content="Some(\"a\")")
  inspect(workbook.get_cell("Sheet1", "D1"), content="Some(\"c\")")
  let sheet = match workbook.sheet("Sheet1") {
    Some(value) => value
    None => fail("missing Sheet1")
  }
  let table = match sheet.tables().get(0) {
    Some(value) => value
    None => fail("missing table")
  }
  let group = match sheet.sparkline_groups().get(0) {
    Some(value) => value
    None => fail("missing sparkline group")
  }
  inspect(sheet.merged_cells(), content="[\"A1:D1\"]")
  inspect(table.range_ref, content="C1:D3")
  inspect(group.sparklines[0].range_ref, content="A1:D1")
  inspect(group.sparklines[0].location, content="E1")
  inspect(workbook.get_col_width("Sheet1", 4), content="Some(11)")
  workbook.remove_cols("Sheet1", 1, 1)
  inspect(workbook.get_cell("Sheet1", "A1"), content="None")
  inspect(workbook.get_cell("Sheet1", "C1"), content="Some(\"c\")")
  let updated_table = match sheet.tables().get(0) {
    Some(value) => value
    None => fail("missing table")
  }
  let updated_group = match sheet.sparkline_groups().get(0) {
    Some(value) => value
    None => fail("missing sparkline group")
  }
  inspect(sheet.merged_cells(), content="[\"A1:C1\"]")
  inspect(updated_table.range_ref, content="B1:C3")
  inspect(updated_group.sparklines[0].range_ref, content="A1:C1")
  inspect(workbook.get_col_width("Sheet1", 3), content="Some(11)")
}
