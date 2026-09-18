///|
test "table list and delete" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  ignore(workbook.add_sheet("Sheet2"))
  ignore(
    workbook.add_table_with_columns("Sheet1", "A1:B2", "Table1", ["A", "B"]),
  )
  ignore(
    workbook.add_table_with_columns("Sheet2", "C1:D2", "Table2", ["C", "D"]),
  )
  debug_inspect(
    workbook.get_tables("Sheet1").map(table => table.name),
    content="[\"Table1\"]",
  )
  debug_inspect(
    workbook.get_tables("Sheet2").map(table => table.name),
    content="[\"Table2\"]",
  )
  workbook.delete_table("Table1")
  debug_inspect(
    workbook.get_tables("Sheet1").map(table => table.name),
    content="[]",
  )
}

///|
test "table delete missing" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let result : Result[Unit, Error] = Ok(workbook.delete_table("Missing")) catch {
    e => Err(e)
  }
  debug_inspect(
    result,
    content=(
      #|Err(TableNotFound(name="Missing"))
    ),
  )
}
