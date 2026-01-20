///|
test "large workbook regression snapshot" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  for row in 1..<=50 {
    for col in 1..<=20 {
      sheet.set_cell_rc(row, col, "\{row}-\{col}")
    }
  }
  let bytes = write(workbook)
  inspect(bytes.length(), content="69430")
  let parsed = read(bytes)
  inspect(parsed.get_cell_rc("Sheet1", 50, 20), content="Some(\"50-20\")")
}
