///|
async test "excelize fixture BadWorkbook.xlsx opens" {
  let workbook = open_file(".repos/excelize/test/BadWorkbook.xlsx")
  workbook.set_active_sheet(1)
  inspect(workbook.active_sheet_index(), content="0")
}
