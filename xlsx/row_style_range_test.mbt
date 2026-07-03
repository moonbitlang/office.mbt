///|
test "row style range setters" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let style_id = workbook.add_style(Style::new())
  workbook.set_row_style_range("Sheet1", 2, 4, style_id)
  let bytes = write(workbook)
  let parsed = read(bytes)
  debug_inspect(
    [
      parsed.get_row_style("Sheet1", 2),
      parsed.get_row_style("Sheet1", 3),
      parsed.get_row_style("Sheet1", 4),
    ],
    content="[Some(1), Some(1), Some(1)]",
  )
}
