///|
test "table list and delete" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  ignore(workbook.add_sheet("Sheet2"))
  ignore(workbook.add_table("Sheet1", "A1:B2", "Table1", ["A", "B"]))
  ignore(workbook.add_table("Sheet2", "C1:D2", "Table2", ["C", "D"]))
  inspect(
    workbook.get_tables("Sheet1").map(table => table.name),
    content="[\"Table1\"]",
  )
  inspect(
    workbook.get_tables("Sheet2").map(table => table.name),
    content="[\"Table2\"]",
  )
  workbook.delete_table("Table1")
  inspect(workbook.get_tables("Sheet1").map(table => table.name), content="[]")
}

///|
test "table delete missing" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let result : Result[Unit, Error] = try? workbook.delete_table("Missing")
  inspect(
    result,
    content=(
      #|Err(TableNotFound(name="Missing"))
    ),
  )
}
