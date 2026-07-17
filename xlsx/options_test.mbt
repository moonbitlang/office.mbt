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
test "read limits enforce aggregate expansion" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let bytes = @xlsx.write(workbook)
  let limits = @xlsx.ReadLimits::with_values(
    max_entry_uncompressed_bytes=1,
    max_total_uncompressed_bytes=1,
    max_xml_part_bytes=1,
  )
  let result : Result[@xlsx.Workbook, Error] = Ok(@xlsx.read(bytes, limits~)) catch {
    e => Err(e)
  }
  inspect(result is Err(@xlsx.ResourceLimitExceeded(..)), content="true")
}

///|
test "read limits reject XML ceiling above entry ceiling" {
  let result : Result[@xlsx.ReadLimits, Error] = Ok(
    @xlsx.ReadLimits::with_values(
      max_entry_uncompressed_bytes=2,
      max_total_uncompressed_bytes=4,
      max_xml_part_bytes=3,
    ),
  ) catch {
    e => Err(e)
  }
  inspect(result is Err(@xlsx.InvalidOptions(_)), content="true")
}

///|
test "read limits reject a non-positive Agile KDF ceiling" {
  let result : Result[@xlsx.ReadLimits, Error] = Ok(
    @xlsx.ReadLimits::with_values(max_kdf_iterations=0),
  ) catch {
    error => Err(error)
  }
  inspect(result is Err(@xlsx.InvalidOptions(_)), content="true")
}

///|
test "read limits reject non-positive semantic ceilings" {
  for
    limits in [
      () => @xlsx.ReadLimits::with_values(max_workbook_sheets=0),
      () => @xlsx.ReadLimits::with_values(max_parser_items=0),
      () => @xlsx.ReadLimits::with_values(max_parser_work_units=0),
    ] {
    let result : Result[@xlsx.ReadLimits, Error] = Ok(limits()) catch {
      error => Err(error)
    }
    inspect(result is Err(@xlsx.InvalidOptions(_)), content="true")
  }
}

///|
test "default read limits expose the complete ZIP policy" {
  let limits = @xlsx.ReadLimits::new()
  assert_eq(limits.max_package_bytes(), 128 * 1024 * 1024)
  assert_eq(limits.max_archive_entries(), 8192)
  assert_eq(limits.max_entry_uncompressed_bytes(), 64 * 1024 * 1024)
  assert_eq(limits.max_total_uncompressed_bytes(), 256 * 1024 * 1024)
  assert_eq(
    limits.max_total_preserved_source_bytes(),
    128 * 1024 * 1024 + 65_535,
  )
  assert_eq(limits.max_xml_part_bytes(), 16 * 1024 * 1024)
  assert_eq(limits.max_kdf_iterations(), 1_000_000)
  assert_eq(limits.max_workbook_sheets(), 1024)
  assert_eq(limits.max_parser_items(), 2_000_000)
  assert_eq(limits.max_parser_work_units(), 512 * 1024 * 1024)
}
