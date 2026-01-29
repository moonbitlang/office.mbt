///|
test "pivot APIs validate sheet name" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let add_pivot_xml_result : Result[PivotTable, Error] = try? workbook.add_pivot_table_xml(
    "Sheet:1", "<pivotTableDefinition/>", "<pivotCacheDefinition/>",
  )
  inspect(
    add_pivot_xml_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let get_pivot_tables_result : Result[Array[PivotTable], Error] = try? workbook.get_pivot_tables(
    "Sheet:1",
  )
  inspect(
    get_pivot_tables_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let delete_pivot_result : Result[Unit, Error] = try? workbook.delete_pivot_table(
    "Sheet:1", "PivotTable1",
  )
  inspect(
    delete_pivot_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
}
