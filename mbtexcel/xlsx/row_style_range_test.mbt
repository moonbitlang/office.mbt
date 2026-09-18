///|
test "row style range setters" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let style_id = workbook.add_style(@xlsx.Style::new())
  workbook.set_row_style_range("Sheet1", 2, 4, style_id)
  let bytes = @xlsx.write(workbook)
  let parsed = @xlsx.read(bytes)
  debug_inspect(
    [
      parsed.get_row_style("Sheet1", 2),
      parsed.get_row_style("Sheet1", 3),
      parsed.get_row_style("Sheet1", 4),
    ],
    content="[Some(1), Some(1), Some(1)]",
  )
}
