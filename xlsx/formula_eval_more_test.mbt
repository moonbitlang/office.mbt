///|
test "calc: defined name with invalid refers_to returns #VALUE!" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  workbook.set_defined_name(DefinedName::new("BadName", "1+"))
  sheet.set_cell_formula("A1", "BadName")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="#VALUE!")
}

///|
test "calc: ANCHORARRAY error/empty/list/value paths" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", Numeric(42.0))
  sheet.set_cell_formula("B1", "ANCHORARRAY(A1)")
  inspect(workbook.calc_cell_value("Sheet1", "B1"), content="")
  sheet.set_cell_formula("A2", "MUNIT(2)")
  sheet.set_cell_formula("B2", "TEXTJOIN(\",\",TRUE(),ANCHORARRAY(A2))")
  inspect(workbook.calc_cell_value("Sheet1", "B2"), content="1,0,0,1")
  sheet.set_cell_formula("A3", "1+1")
  sheet.set_cell_formula("B3", "ANCHORARRAY(A3)")
  inspect(workbook.calc_cell_value("Sheet1", "B3"), content="2")
  sheet.set_cell_formula("A4", "1/0")
  sheet.set_cell_formula("B4", "ANCHORARRAY(A4)")
  inspect(workbook.calc_cell_value("Sheet1", "B4"), content="#DIV/0!")
  sheet.set_cell_formula("C1", "ANCHORARRAY(1)")
  inspect(workbook.calc_cell_value("Sheet1", "C1"), content="#VALUE!")
  sheet.set_cell_formula("C2", "ANCHORARRAY(NoSuchSheet!A1)")
  inspect(workbook.calc_cell_value("Sheet1", "C2"), content="#VALUE!")
  sheet.set_cell_formula("C3", "ANCHORARRAY(Sheet1!A1)")
  inspect(workbook.calc_cell_value("Sheet1", "C3"), content="")
}
