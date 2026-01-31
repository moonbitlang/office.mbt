///|
fn format_numeric(value : Double, fmt : String) -> String {
  let workbook = Workbook::new()
  ignore(try! workbook.add_sheet("Sheet1"))
  try! workbook.set_cell_value("Sheet1", "A1", Numeric(value))
  let style_id = workbook.add_style(Style::number_format(fmt))
  try! workbook.set_cell_style("Sheet1", "A1", style_id)
  match (try! workbook.get_cell_value("Sheet1", "A1")) {
    Some(text) => text
    None => ""
  }
}

///|
fn format_text(value : String, fmt : String) -> String {
  let workbook = Workbook::new()
  ignore(try! workbook.add_sheet("Sheet1"))
  try! workbook.set_cell_str("Sheet1", "A1", value)
  let style_id = workbook.add_style(Style::number_format(fmt))
  try! workbook.set_cell_style("Sheet1", "A1", style_id)
  match (try! workbook.get_cell_value("Sheet1", "A1")) {
    Some(text) => text
    None => ""
  }
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
}
