///|
test "options raw cell value for rows and cols" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell_float("Sheet1", "A1", 1.0)
  let style_id = workbook.add_style(@xlsx.Style::builtin_number_format(2))
  workbook.set_cell_style("Sheet1", "A1", style_id)
  debug_inspect(workbook.get_rows("Sheet1"), content="[[\"1.00\"]]")
  let raw_opts = @xlsx.Options::with_values(raw_cell_value=true)
  debug_inspect(
    workbook.get_rows("Sheet1", options=raw_opts),
    content="[[\"1\"]]",
  )
  debug_inspect(workbook.get_cols("Sheet1"), content="[[\"1.00\"]]")
  debug_inspect(
    workbook.get_cols("Sheet1", options=raw_opts),
    content="[[\"1\"]]",
  )
}

///|
test "options short date pattern" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell_float("Sheet1", "A1", 2.0)
  let style_id = workbook.add_style(@xlsx.Style::builtin_number_format(14))
  workbook.set_cell_style("Sheet1", "A1", style_id)
  let opts = @xlsx.Options::with_values(short_date_pattern="yyyy/m/d")
  debug_inspect(
    workbook.get_cell_value("Sheet1", "A1", options=opts),
    content="Some(\"1900/1/2\")",
  )
}

///|
test "options long date pattern" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell_float("Sheet1", "A1", 2.0)
  let style_id = workbook.add_style(@xlsx.Style::builtin_number_format(15))
  workbook.set_cell_style("Sheet1", "A1", style_id)
  let opts = @xlsx.Options::with_values(long_date_pattern="yyyy/mm/dd")
  debug_inspect(
    workbook.get_cell_value("Sheet1", "A1", options=opts),
    content="Some(\"1900/01/02\")",
  )
}

///|
test "options long time pattern" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell_float("Sheet1", "A1", 0.75)
  let style_id = workbook.add_style(@xlsx.Style::builtin_number_format(21))
  workbook.set_cell_style("Sheet1", "A1", style_id)
  let opts = @xlsx.Options::with_values(long_time_pattern="hh:mm:ss")
  debug_inspect(
    workbook.get_cell_value("Sheet1", "A1", options=opts),
    content="Some(\"18:00:00\")",
  )
}

///|
test "options enforce unzip size limit" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let bytes = @xlsx.write(workbook)
  let opts = @xlsx.Options::with_values(unzip_size_limit=1)
  let result : Result[@xlsx.Workbook, Error] = Ok(
    @xlsx.read(bytes, options=opts),
  ) catch {
    e => Err(e)
  }
  guard result is Err(_) else { fail("expected unzip size limit error") }
}

///|
test "options invalid unzip xml size limit" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let bytes = @xlsx.write(workbook)
  let opts = @xlsx.Options::with_values(
    unzip_size_limit=2,
    unzip_xml_size_limit=3,
  )
  let result : Result[@xlsx.Workbook, Error] = Ok(
    @xlsx.read(bytes, options=opts),
  ) catch {
    e => Err(e)
  }
  inspect(result is Err(@xlsx.XlsxError::InvalidOptions(_)), content="true")
}
