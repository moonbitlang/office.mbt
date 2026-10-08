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
  let style = @xlsx.Style::protection(protection).with_number_format("0.0000")
  let id = workbook.new_style(style)
  workbook.set_cell_style("Input", "A1", id)
  let reopened = @xlsx.read(@xlsx.write(workbook))
  let actual = reopened.get_style(
    reopened.get_cell_style("Input", "A1").unwrap(),
  )
  debug_inspect(actual.number_format, content="Some(Custom(\"0.0000\"))")
  debug_inspect(
    actual.protection,
    content="Some({ hidden: Some(true), locked: Some(false) })",
  )
}
