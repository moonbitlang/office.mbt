///|
test "calculated dates honor the workbook 1904 date system" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  workbook.set_workbook_props(
    Some(@xlsx.WorkbookPropsOptions::with_values(date_1904=true)),
  )
  let date_style = workbook.add_style(@xlsx.Style::number_format("yyyy-mm-dd"))
  sheet.set_cell_formula("A1", "DATE(1904,1,1)")
  workbook.set_cell_style("Sheet1", "A1", date_style)
  inspect(workbook.calc_cell_value("Sheet1", "A1", raw=true), content="0")
  inspect(workbook.calc_cell_value("Sheet1", "A1"), content="1904-01-01")
  debug_inspect(
    workbook.calc_cell_typed("Sheet1", "A1"),
    content="Some(Numeric(0))",
  )

  let cases : Array[(String, String)] = [
    ("DATEVALUE(\"1904-01-02\")", "1"),
    ("TEXT(DATE(1904,1,1),\"yyyy-mm-dd\")", "1904-01-01"),
    ("YEAR(0)", "1904"),
    ("MONTH(0)", "1"),
    ("DAY(0)", "1"),
    ("TEXT(EDATE(DATE(1904,1,31),1),\"yyyy-mm-dd\")", "1904-02-29"),
    ("DAYS(DATE(1904,1,3),DATE(1904,1,1))", "2"),
    ("NETWORKDAYS(DATE(1904,1,1),DATE(1904,1,4))", "2"),
    ("TEXT(WORKDAY(DATE(1904,1,1),1),\"yyyy-mm-dd\")", "1904-01-04"),
    ("ISOWEEKNUM(DATE(1904,1,1))", "53"),
    ("ISOWEEKNUM(DATE(1904,1,2))", "53"),
    ("ISOWEEKNUM(DATE(1904,1,3))", "53"),
    ("ISOWEEKNUM(DATE(1904,1,4))", "1"),
    ("INT(NOW())=TODAY()", "TRUE"),
    ("TODAY()=DATE(YEAR(TODAY()),MONTH(TODAY()),DAY(TODAY()))", "TRUE"),
    ("DATE(1903,12,31)", "#NUM!"),
  ]
  for index, case in cases {
    let (formula, expected) = case
    let cell = "B\{index + 1}"
    sheet.set_cell_formula(cell, formula)
    inspect(workbook.calc_cell_value("Sheet1", cell), content=expected)
  }
}

///|
test "date-aware financial formulas are invariant across date systems" {
  let workbook_1900 = @xlsx.Workbook::new()
  let sheet_1900 = workbook_1900.add_sheet("Sheet1")
  let workbook_1904 = @xlsx.Workbook::new()
  let sheet_1904 = workbook_1904.add_sheet("Sheet1")
  workbook_1904.set_workbook_props(
    Some(@xlsx.WorkbookPropsOptions::with_values(date_1904=true)),
  )
  let formulas : Array[String] = [
    "ACCRINT(DATE(2020,1,1),DATE(2020,7,1),DATE(2020,3,1),0.05,1000,2,0)", "AMORLINC(1000,DATE(2020,1,1),DATE(2020,12,31),100,1,0.1,0)",
    "COUPDAYS(DATE(2020,1,15),DATE(2021,1,15),2,0)", "DURATION(DATE(2020,1,15),DATE(2021,1,15),0.05,0.04,2,0)",
    "PRICE(DATE(2020,1,15),DATE(2021,1,15),0.05,0.04,100,2,0)", "ODDFPRICE(DATE(2017,2,1),DATE(2021,3,31),DATE(2016,12,1),DATE(2017,3,31),5.5%,3.5%,100,2)",
    "ODDLPRICE(DATE(2008,4,20),DATE(2008,6,15),DATE(2007,12,24),3.75%,99.875,100,2)",
    "TEXT(COUPNCD(DATE(2020,1,15),DATE(2021,1,15),2,0),\"yyyy-mm-dd\")",
  ]
  for index, formula in formulas {
    let cell = "A\{index + 1}"
    sheet_1900.set_cell_formula(cell, formula)
    sheet_1904.set_cell_formula(cell, formula)
    assert_eq(
      workbook_1904.calc_cell_value("Sheet1", cell, raw=true),
      workbook_1900.calc_cell_value("Sheet1", cell, raw=true),
    )
  }
}

///|
test "workday formulas terminate at supported date-system boundaries" {
  let workbook_1904 = @xlsx.Workbook::new()
  let sheet_1904 = workbook_1904.add_sheet("Sheet1")
  workbook_1904.set_workbook_props(
    Some(@xlsx.WorkbookPropsOptions::with_values(date_1904=true)),
  )
  let cases_1904 : Array[String] = [
    "WORKDAY(DATE(1904,1,1),-1)", "WORKDAY.INTL(DATE(1904,1,1),-1)", "WORKDAY.INTL(DATE(1904,1,4),-1,1,DATE(1904,1,1))",
    "WORKDAY(DATE(9999,12,31),1)",
  ]
  for index, formula in cases_1904 {
    let cell = "A\{index + 1}"
    sheet_1904.set_cell_formula(cell, formula)
    inspect(workbook_1904.calc_cell_value("Sheet1", cell), content="#NUM!")
  }

  let workbook_1900 = @xlsx.Workbook::new()
  let sheet_1900 = workbook_1900.add_sheet("Sheet1")
  let cases_1900 : Array[String] = [
    "WORKDAY(DATE(1900,1,1),-2)", "WORKDAY(DATE(9999,12,31),1)",
  ]
  for index, formula in cases_1900 {
    let cell = "A\{index + 1}"
    sheet_1900.set_cell_formula(cell, formula)
    inspect(workbook_1900.calc_cell_value("Sheet1", cell), content="#NUM!")
  }
}
