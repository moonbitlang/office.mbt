///|
test "table APIs validate sheet name" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let add_table_cols_result : Result[Table, Error] = try? workbook.add_table_with_columns(
    "Sheet:1",
    "A1:B2",
    "Table1",
    ["Column1", "Column2"][:],
  )
  inspect(
    add_table_cols_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let get_tables_result : Result[Array[Table], Error] = try? workbook.get_tables(
    "Sheet:1",
  )
  inspect(
    get_tables_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
}
