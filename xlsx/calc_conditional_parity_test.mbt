///|
test "calc conditional parity cases" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", Numeric(1.0))
  sheet.set_cell_value("A4", Numeric(0.4))
  sheet.set_cell_value("D1", String("Month"))

  let cases : Array[(String, String)] = [
    ("IF(2<0, 1, (4))", "4"),
    ("IF(2>0, (1), 4)", "1"),
    ("IF(2>0, (A1)*2.5, 4)", "2.5"),
    ("IF(1=1)", "TRUE"),
    ("IF(1<>1)", "FALSE"),
    ("IF(5<0, \"negative\", \"positive\")", "positive"),
    ("IF(-2<0, \"negative\", \"positive\")", "negative"),
    ("IF(1=1, \"equal\", \"notequal\")", "equal"),
    ("IF(1<>1, \"equal\", \"notequal\")", "notequal"),
    ("IF(\"A\"=\"A\", \"equal\", \"notequal\")", "equal"),
    ("IF(\"A\"<>\"A\", \"equal\", \"notequal\")", "notequal"),
    ("IF(FALSE,0,ROUND(4/2,0))", "2"),
    ("IF(TRUE,ROUND(4/2,0),0)", "2"),
    ("IF(A4>0.4,\"TRUE\",\"FALSE\")", "FALSE"),
  ]
  for i in 0..<cases.length() {
    let (formula, expected) = cases[i]
    let cell = "F\{i + 1}"
    sheet.set_cell_formula(cell, formula)
    inspect(workbook.calc_cell_value("Sheet1", cell), content=expected)
  }
}

///|
test "calc conditional parity errors" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("D1", String("Month"))

  let cases : Array[(String, String)] = [
    ("IF()", "#VALUE!"),
    ("IF(0,1,2,3)", "#VALUE!"),
    ("IF(D1,1,2)", "#VALUE!"),
    ("IFERROR()", "#VALUE!"),
    ("IFNA()", "#VALUE!"),
    ("SWITCH()", "#VALUE!"),
    ("SWITCH(0,1,2)", "#N/A"),
    ("XOR()", "#VALUE!"),
    ("XOR(\"1\")", "#VALUE!"),
    ("XOR(\"text\")", "#VALUE!"),
    ("XOR(XOR(\"text\"))", "#VALUE!"),
  ]
  for i in 0..<cases.length() {
    let (formula, expected) = cases[i]
    let cell = "G\{i + 1}"
    sheet.set_cell_formula(cell, formula)
    inspect(workbook.calc_cell_value("Sheet1", cell), content=expected)
  }
}

///|
test "calc logical parity cases" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", Numeric(1.0))
  sheet.set_cell_value("B1", Numeric(4.0))

  let cases : Array[(String, String)] = [
    ("AND(0)", "FALSE"),
    ("AND(1)", "TRUE"),
    ("AND(1,0)", "FALSE"),
    ("AND(0,1)", "FALSE"),
    ("AND(1=1)", "TRUE"),
    ("AND(1<2)", "TRUE"),
    ("AND(1>2,2<3,2>0,3>1)", "FALSE"),
    ("AND(\"TRUE\",\"FALSE\")", "FALSE"),
    ("OR(1)", "TRUE"),
    ("OR(0)", "FALSE"),
    ("OR(1=2,2=2)", "TRUE"),
    ("OR(1=2,2=3)", "FALSE"),
    ("OR(1=1,2=3)", "TRUE"),
    ("OR(\"TRUE\",\"FALSE\")", "TRUE"),
    ("OR(A1:B1)", "TRUE"),
    ("NOT(TRUE())", "FALSE"),
    ("NOT(FALSE())", "TRUE"),
    ("NOT(1)", "FALSE"),
    ("NOT(0)", "TRUE"),
  ]
  for i in 0..<cases.length() {
    let (formula, expected) = cases[i]
    let cell = "H\{i + 1}"
    sheet.set_cell_formula(cell, formula)
    inspect(workbook.calc_cell_value("Sheet1", cell), content=expected)
  }
}

///|
test "calc logical parity errors" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", Numeric(1.0))
  sheet.set_cell_value("B1", Numeric(4.0))

  let cases : Array[(String, String)] = [
    ("AND()", "#VALUE!"),
    ("AND(\"text\")", "#VALUE!"),
    ("AND(A1:B1)", "#VALUE!"),
    ("AND(\"1\",\"TRUE\",\"FALSE\")", "#VALUE!"),
    ("OR()", "#VALUE!"),
    ("OR(\"text\")", "#VALUE!"),
    ("OR(\"1\",\"TRUE\",\"FALSE\")", "#VALUE!"),
    ("NOT(\"1\")", "#VALUE!"),
  ]
  for i in 0..<cases.length() {
    let (formula, expected) = cases[i]
    let cell = "I\{i + 1}"
    sheet.set_cell_formula(cell, formula)
    inspect(workbook.calc_cell_value("Sheet1", cell), content=expected)
  }
}
