///|
#cfg(target="native")
async test "excelize fixture OverflowNumericCell.xlsx reads large integer" {
  let workbook = open_file(".repos/excelize/test/OverflowNumericCell.xlsx")
  debug_inspect(
    workbook.get_cell_value("Sheet1", "A1"),
    content="Some(\"8595602512225\")",
  )
}
