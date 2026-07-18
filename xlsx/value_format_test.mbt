///|
fn format_numeric(value : Double, fmt : String) -> String {
  let workbook = @xlsx.Workbook::new()
  ignore(try! workbook.add_sheet("Sheet1"))
  try! workbook.set_cell_value("Sheet1", "A1", Numeric(value))
  let style_id = workbook.add_style(@xlsx.Style::number_format(fmt))
  try! workbook.set_cell_style("Sheet1", "A1", style_id)
  match (try! workbook.get_cell_value("Sheet1", "A1")) {
    Some(text) => text
    None => ""
  }
}

///|
fn format_text(value : String, fmt : String) -> String {
  let workbook = @xlsx.Workbook::new()
  ignore(try! workbook.add_sheet("Sheet1"))
  try! workbook.set_cell_str("Sheet1", "A1", value)
  let style_id = workbook.add_style(@xlsx.Style::number_format(fmt))
  try! workbook.set_cell_style("Sheet1", "A1", style_id)
  match (try! workbook.get_cell_value("Sheet1", "A1")) {
    Some(text) => text
    None => ""
  }
}

///|
test "fraction formatting keeps zero finite across percent scaling" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.new_sheet("Sheet1"))
  workbook.set_cell_value("Sheet1", "A1", Numeric(0.0))
  let style_id = workbook.new_style(
    @xlsx.Style::number_format("# ?/?" + "%".repeat(155)),
  )
  workbook.set_cell_style("Sheet1", "A1", style_id)
  guard workbook.get_cell_value("Sheet1", "A1") is Some(formatted) else {
    fail("expected formatted numeric zero")
  }
  assert_true(formatted.has_prefix("0"))
  assert_true(formatted.has_suffix("%".repeat(155)))
}

///|
test "fraction formatting rejects non-finite nonzero percent scaling" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.new_sheet("Sheet1"))
  workbook.set_cell_value("Sheet1", "A1", Numeric(1.0))
  let style_id = workbook.new_style(
    @xlsx.Style::number_format("# ?/?" + "%".repeat(155)),
  )
  workbook.set_cell_style("Sheet1", "A1", style_id)
  let result : Result[String?, Error] = Ok(
    workbook.get_cell_value("Sheet1", "A1"),
  ) catch {
    error => Err(error)
  }
  match result {
    Err(@xlsx.XlsxError::InvalidXml(msg~)) =>
      inspect(msg, content="number format scale must remain finite")
    _ => fail("expected non-finite number-format scaling rejection")
  }
}

///|
test "TEXT percent scaling keeps finite tiny values and zero total" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let format = "# ?/?" + "%".repeat(155)
  sheet.set_cell_formula("A1", "TEXT(1E-300,\"" + format + "\")")
  sheet.set_cell_formula("A2", "TEXT(0,\"" + format + "\")")
  let finite = workbook.calc_cell_value("Sheet1", "A1")
  let zero = workbook.calc_cell_value("Sheet1", "A2")
  assert_true(finite.has_prefix("10000000000"))
  assert_true(finite.has_suffix("%".repeat(155)))
  assert_true(zero.has_prefix("0"))
  assert_true(zero.has_suffix("%".repeat(155)))
}

///|
test "general and literal formats" {
  inspect(format_numeric(43543.5448726851, "General"), content="43543.54487")
  inspect(format_numeric(1234567890.12345, "General"), content="1234567890")
  inspect(format_numeric(123.456, "\"\"0.00\"foo\""), content="123.46foo")
  inspect(format_numeric(123.456, "\"\";\"\""), content="")
  inspect(format_text("alpha", "\"\";\"\";\"\";@"), content="alpha")
}

///|
test "date tokens and elapsed" {
  inspect(format_numeric(43528.0, "ddd"), content="Mon")
  inspect(format_numeric(43528.0, "dddd"), content="Monday")
  inspect(format_numeric(43528.0, "mmmmm"), content="M")
  inspect(format_numeric(43528.0, "mmmmmm"), content="March")
  inspect(format_numeric(43543.544872685183, "mmhhmmmm"), content="0313March")
  inspect(
    format_numeric(43543.544872685183, "mm hh mm mm"),
    content="03 13 04 03",
  )
  inspect(format_numeric(43543.544872685183, "m s"), content="4 37")
  inspect(
    format_numeric(43528.2123, "YYYY-MM-DD hh:mm:ss"),
    content="2019-03-04 05:05:43",
  )
  inspect(
    format_numeric(43543.544872685183, "AM/PM h:mm:ss"),
    content="PM 1:04:37",
  )
  inspect(
    format_numeric(43543.086539351854, "AM/PM hh:mm:ss a/p"),
    content="AM 02:04:37 a",
  )
  inspect(format_numeric(0.609375, "[HH]:mm:ss"), content="14:37:30")
  inspect(format_numeric(43528.0, "[h]"), content="1044672")
  inspect(format_numeric(43528.0, "[m]"), content="62680320")
  inspect(format_numeric(43528.0, "[s]"), content="3760819200")
  inspect(format_numeric(60.0, "yyyy-mm-dd"), content="1900-02-29")
  inspect(format_numeric(43528.0, "[$-409]MM/DD/YYYY"), content="03/04/2019")
  inspect(
    format_numeric(43528.0, "[$US-409]MM/DD/YYYY"),
    content="US03/04/2019",
  )
  inspect(format_numeric(43528.0, "[$-111]MM/DD/YYYY"), content="43528")
}

///|
test "fraction, scientific, percent" {
  inspect(format_numeric(123.4567, "# ?/?"), content="123 1/2")
  inspect(format_numeric(123.4567, "# ??/??"), content="123 37/81")
  inspect(format_numeric(123.4567, "# ???/???"), content="123  58/127")
  inspect(format_numeric(-3.141592653589793, "# ?/?"), content="-3 1/7")
  inspect(format_numeric(0.0, "# ?/?"), content="0    ")
  inspect(format_numeric(123.456, "0.00E+00"), content="1.23E+02")
  inspect(format_numeric(0.256, "0.00%"), content="25.60%")
  let large_fraction = format_numeric(1.0e20, "# ?/?")
  assert_false(large_fraction.contains("9223372036854775807"))
}

///|
test "bounded numeric formatting rejects amplification before allocation" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.new_sheet("Sheet1")
  workbook.set_cell_value("Sheet1", "A1", Numeric(1.0))
  let style_id = workbook.new_style(
    @xlsx.Style::number_format("0".repeat(1024)),
  )
  workbook.set_cell_style("Sheet1", "A1", style_id)
  try
    workbook.get_cell_value_styled_from_worksheet_rc(
      sheet,
      1,
      1,
      style_id,
      max_output_chars=64,
    )
  catch {
    ResourceLimitExceeded(kind~, limit~, actual~) => {
      assert_eq(kind, "formatted_cell_value_chars")
      assert_eq(limit, 64)
      assert_true(actual > limit)
    }
    _ => fail("expected bounded numeric formatting failure")
  } noraise {
    _ => fail("expected bounded numeric formatting failure")
  }
}
