///|
test "get_cell_value_styled applies the given style unless raw" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  workbook.set_cell_int("Data", "A1", 1)
  let priced = workbook.new_style(@xlsx.Style::number_format("0.00"))
  inspect(
    workbook.get_cell_value_styled("Data", "A1", priced).unwrap_or(""),
    content="1.00",
  )
  let raw = workbook.get_cell_value_styled(
    "Data",
    "A1",
    priced,
    options=@xlsx.Options::with_values(raw_cell_value=true),
  )
  inspect(raw.unwrap_or(""), content="1")
}
