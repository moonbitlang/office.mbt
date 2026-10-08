///|
test "cell styles compose number formats with protection" {
  let protection = @xlsx.Protection::with_values(locked=false, hidden=true)
  let custom = @xlsx.Style::number_format("0.00").with_protection(protection)
  let reverse = @xlsx.Style::protection(protection).with_number_format("0.00")
  debug_inspect(custom == reverse, content="true")
  let builtin = custom.with_builtin_number_format(10)
  debug_inspect(builtin.number_format, content="Some(Builtin(10))")
  debug_inspect(builtin.protection == Some(protection), content="true")
}

///|
test "composed number format and protection survive XLSX writing" {
  let workbook = @xlsx.Workbook::new()
  workbook.add_sheet("Input") |> ignore
  let protection = @xlsx.Protection::with_values(locked=false, hidden=true)
  let style = @xlsx.Style::builtin_number_format(14)
    .with_font(@xlsx.Font::with_values(bold=true))
    .with_fill(@xlsx.Fill::pattern(pattern=1, color="FFFF00"))
    .with_border([@xlsx.Border::with_values("left", style=1)])
    .with_alignment(@xlsx.Alignment::with_values(horizontal="center"))
    .with_protection(protection)
    .with_number_format("0.0000")
  let id = workbook.new_style(style)
  workbook.set_cell_style("Input", "A1", id)
  let builtin_id = workbook.new_style(style.with_builtin_number_format(10))
  workbook.set_cell_style("Input", "A2", builtin_id)
  let reopened = @xlsx.read(@xlsx.write(workbook))
  let actual = reopened.get_style(
    reopened.get_cell_style("Input", "A1").unwrap(),
  )
  let builtin = reopened.get_style(
    reopened.get_cell_style("Input", "A2").unwrap(),
  )
  debug_inspect(builtin.number_format, content="Some(Builtin(10))")
  debug_inspect(builtin.with_number_format("0.0000") == actual, content="true")
  debug_inspect(actual.font.unwrap().bold, content="Some(true)")
  debug_inspect(actual.fill.unwrap().colors, content="Some([\"FFFF00\"])")
  debug_inspect(actual.border.unwrap()[0].style, content="Some(1)")
  debug_inspect(
    actual.alignment.unwrap().horizontal,
    content="Some(\"center\")",
  )
  debug_inspect(actual.number_format, content="Some(Custom(\"0.0000\"))")
  debug_inspect(
    actual.protection,
    content="Some({ hidden: Some(true), locked: Some(false) })",
  )
}
