///|
test "calc behavior parity pack2 lookup cases" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")

  sheet.set_cell_value("A1", Numeric(1.0))
  sheet.set_cell_value("A2", Numeric(2.0))
  sheet.set_cell_value("A3", Numeric(3.0))
  sheet.set_cell_value("A4", Numeric(4.0))
  sheet.set_cell_value("A5", Numeric(5.0))
  sheet.set_cell_value("B1", String("one"))
  sheet.set_cell_value("B2", String("two"))
  sheet.set_cell_value("B3", String("three"))
  sheet.set_cell_value("B4", String("four"))
  sheet.set_cell_value("B5", String("five"))

  let cases : Array[(String, String)] = [
    ("INDEX(B1:B5,3)", "three"),
    ("MATCH(4,A1:A5,0)", "4"),
    ("MATCH(\"four\",B1:B5,0)", "4"),
    ("VLOOKUP(2,A1:B5,2,FALSE)", "two"),
    ("XLOOKUP(5,A1:A5,B1:B5)", "five"),
    ("IFNA(XLOOKUP(9,A1:A5,B1:B5),\"nf\")", "nf"),
  ]

  for i in 0..<cases.length() {
    let (formula, expected) = cases[i]
    let cell = "C\{i + 1}"
    sheet.set_cell_formula(cell, formula)
    inspect(workbook.calc_cell_value("Sheet1", cell), content=expected)
  }
}

///|
test "calc behavior parity pack2 financial cases" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")

  let cases : Array[(String, String)] = [
    ("PMT(0,10,1000)", "-100"),
    ("FV(0,10,-100,0,0)", "1000"),
    ("PV(0,10,-100,0,0)", "1000"),
    ("NPER(0,-100,1000,0,0)", "10"),
    ("PPMT(0,1,10,1000)", "-100"),
  ]

  for i in 0..<cases.length() {
    let (formula, expected) = cases[i]
    let cell = "D\{i + 1}"
    sheet.set_cell_formula(cell, formula)
    inspect(workbook.calc_cell_value("Sheet1", cell), content=expected)
  }
}

///|
test "calc behavior parity pack2 financial errors" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")

  let cases : Array[(String, String)] = [
    ("PMT()", "#VALUE!"),
    ("FV()", "#VALUE!"),
    ("PV()", "#VALUE!"),
    ("NPER()", "#VALUE!"),
  ]

  for i in 0..<cases.length() {
    let (formula, expected) = cases[i]
    let cell = "E\{i + 1}"
    sheet.set_cell_formula(cell, formula)
    inspect(workbook.calc_cell_value("Sheet1", cell), content=expected)
  }
}
