///|
#cfg(target="native")
async test "excelize fixture CalcChain.xlsx can remove formulas" {
  let workbook = open_file(".repos/excelize/test/CalcChain.xlsx")
  workbook.set_cell_formula("Sheet1", "A1", "")
  workbook.set_cell_formula("Sheet1", "B1", "")
  let parsed = read(write(workbook))
  debug_inspect(parsed.get_cell_formula("Sheet1", "A1"), content="None")
  debug_inspect(parsed.get_cell_formula("Sheet1", "B1"), content="None")
}
