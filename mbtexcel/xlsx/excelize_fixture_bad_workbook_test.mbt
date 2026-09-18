///|
#cfg(target="native")
async test "excelize fixture BadWorkbook.xlsx opens" {
  let workbook = @xlsx.open_file("fixtures/excelize/test/BadWorkbook.xlsx")
  workbook.set_active_sheet(1)
  inspect(workbook.active_sheet_index(), content="0")
}
