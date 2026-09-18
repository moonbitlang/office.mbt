///|
test "calc behavior parity pack1 cases" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")

  let cases : Array[(String, String)] = [
    ("ABS(-1.25)", "1.25"),
    ("ROUND(4.567,2)", "4.57"),
    ("UPPER(\"Abc\")", "ABC"),
    ("LOWER(\"AbC\")", "abc"),
    ("PROPER(\"hello world\")", "Hello World"),
    ("LEFT(\"MoonBit\",4)", "Moon"),
    ("RIGHT(\"MoonBit\",3)", "Bit"),
    ("LEN(\"MoonBit\")", "7"),
    ("TRIM(\"  a   b  \")", "a b"),
    ("TEXT(DATE(2020,1,2),\"m/d/yy\")", "1/2/20"),
    ("TEXT(TIME(1,2,3),\"h:mm:ss\")", "1:02:03"),
    ("YEAR(DATE(2020,1,2))", "2020"),
    ("MONTH(DATE(2020,1,2))", "1"),
    ("DAY(DATE(2020,1,2))", "2"),
    ("WEEKDAY(DATE(2020,1,1),2)", "3"),
    ("DAYS(DATE(2020,1,3),DATE(2020,1,1))", "2"),
    ("NETWORKDAYS(DATE(2020,1,1),DATE(2020,1,7))", "5"),
    ("TEXT(WORKDAY(DATE(2020,1,1),1),\"m/d/yy\")", "1/2/20"),
    ("IFERROR(1/0,42)", "42"),
    ("IFNA(NA(),5)", "5"),
    ("SWITCH(2,1,\"a\",2,\"b\",\"c\")", "b"),
  ]

  for i in 0..<cases.length() {
    let (formula, expected) = cases[i]
    let cell = "A\{i + 1}"
    sheet.set_cell_formula(cell, formula)
    inspect(workbook.calc_cell_value("Sheet1", cell), content=expected)
  }
}

///|
test "calc behavior parity pack1 errors" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")

  let cases : Array[(String, String)] = [
    ("LEFT(\"abc\",-1)", "#VALUE!"),
    ("RIGHT(\"abc\",-1)", "#VALUE!"),
    ("NETWORKDAYS(DATE(2020,1,1))", "#VALUE!"),
    ("WORKDAY(DATE(2020,1,1))", "#VALUE!"),
    ("IFERROR()", "#VALUE!"),
    ("IFNA()", "#VALUE!"),
    ("SWITCH()", "#VALUE!"),
  ]

  for i in 0..<cases.length() {
    let (formula, expected) = cases[i]
    let cell = "B\{i + 1}"
    sheet.set_cell_formula(cell, formula)
    inspect(workbook.calc_cell_value("Sheet1", cell), content=expected)
  }
}
