///|
test "worksheet row and column ops" {
  let sheet = Worksheet::new("Sheet1")
  sheet.set_row(1, ["a", "b", "c"])
  sheet.set_col(2, ["x", "y"])
  inspect(sheet.get_row(1), content="[\"a\", \"x\", \"c\"]")
  inspect(sheet.get_row(2), content="[\"\", \"y\"]")
  inspect(sheet.get_col(2), content="[\"x\", \"y\"]")
  inspect(sheet.get_row(3), content="[]")
  inspect(sheet.get_col(4), content="[]")
}

///|
test "workbook row and column ops" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_row("Sheet1", 1, ["a", "b"])
  workbook.set_col("Sheet1", 1, ["x", "y", "z"])
  inspect(workbook.get_row("Sheet1", 1), content="[\"x\", \"b\"]")
  inspect(workbook.get_col("Sheet1", 1), content="[\"x\", \"y\", \"z\"]")
  let bad_row : Result[Array[String], Error] = try? workbook.get_row(
    "Sheet1", 0,
  )
  inspect(bad_row is Err(_), content="true")
}
