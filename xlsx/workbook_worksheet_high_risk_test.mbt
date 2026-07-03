///|
test "workbook cell setters: missing sheet errors" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let set_cell_missing : Result[Unit, Error] = try? workbook.set_cell(
    "Missing", "A1", "x",
  )
  inspect(set_cell_missing is Err(XlsxError::SheetNotFound(_)), content="true")
  let set_value_missing : Result[Unit, Error] = try? workbook.set_cell_value(
    "Missing",
    "A1",
    Bool(true),
  )
  inspect(set_value_missing is Err(XlsxError::SheetNotFound(_)), content="true")
}

///|
test "worksheet delete table/pivot edge branches" {
  let sheet = Worksheet::new("Sheet1")
  ignore(sheet.add_table("A1:B2", "Table1", ["A", "B"]))
  ignore(sheet.add_table("D1:E2", "Table2", ["C", "D"]))
  sheet.delete_table("Table1")
  let table_names : Array[String] = []
  for table in sheet.tables() {
    table_names.push(table.name)
  }
  debug_inspect(table_names, content="[\"Table2\"]")
  let missing_table : Result[Unit, Error] = try? sheet.delete_table("Missing")
  debug_inspect(
    missing_table,
    content=(
      #|Err(TableNotFound(name="Missing"))
    ),
  )

  ignore(
    sheet.add_pivot_table_xml(
      "<pivotTableDefinition/>",
      "<pivotCacheDefinition/>",
      name="Pivot1",
    ),
  )
  ignore(
    sheet.add_pivot_table_xml(
      "<pivotTableDefinition/>",
      "<pivotCacheDefinition/>",
      name="Pivot2",
    ),
  )
  let empty_name : Result[Unit, Error] = try? sheet.delete_pivot_table("")
  debug_inspect(
    empty_name,
    content=(
      #|Err(InvalidSheetOperation(msg="pivot table name empty"))
    ),
  )
  let missing_pivot : Result[Unit, Error] = try? sheet.delete_pivot_table(
    "Missing",
  )
  debug_inspect(
    missing_pivot,
    content=(
      #|Err(InvalidSheetOperation(msg="pivot table not found"))
    ),
  )
  sheet.delete_pivot_table("Pivot1")
  let pivot_names : Array[String] = []
  for pivot in sheet.pivot_tables() {
    pivot_names.push(pivot.name)
  }
  debug_inspect(pivot_names, content="[\"Pivot2\"]")
}
