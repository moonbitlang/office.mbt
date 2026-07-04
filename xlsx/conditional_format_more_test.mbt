///|
test "conditional format: more rule types (time/text/top/bottom/blanks/errors/formula/icon)" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let time = ConditionalFormatOptions::new("time_period")
  time.set_criteria("today")
  time.set_stop_if_true(true)
  let text = ConditionalFormatOptions::new("text")
  text.set_criteria("containing")
  text.set_value("hi")
  let top = ConditionalFormatOptions::new("top")
  top.set_percent(true)
  top.set_value("5")
  let bottom = ConditionalFormatOptions::new("bottom")
  bottom.set_value("3")
  let avg = ConditionalFormatOptions::new("average")
  avg.set_above_average(true)
  let blanks = ConditionalFormatOptions::new("blanks")
  let no_blanks = ConditionalFormatOptions::new("no_blanks")
  let errors = ConditionalFormatOptions::new("errors")
  let no_errors = ConditionalFormatOptions::new("no_errors")
  let formula = ConditionalFormatOptions::new("formula")
  formula.set_criteria("A1>0")
  let icon = ConditionalFormatOptions::new("icon_set")
  icon.set_icon_style("3Stars")
  icon.set_reverse_icons(true)
  icon.set_icons_only(true)
  icon.set_percent(true)
  sheet.set_conditional_format("A1", [
    time, text, top, bottom, avg, blanks, no_blanks, errors, no_errors, formula,
    icon,
  ])
  let xml = sheet.conditional_formats()[0]
  inspect(xml.contains("type=\"timePeriod\""), content="true")
  inspect(xml.contains("type=\"containsText\""), content="true")
  inspect(xml.contains("text=\"hi\""), content="true")
  inspect(xml.contains("type=\"top10\""), content="true")
  inspect(xml.contains("bottom=\"1\""), content="true")
  inspect(xml.contains("percent=\"1\""), content="true")
  inspect(xml.contains("containsBlanks"), content="true")
  inspect(xml.contains("notContainsBlanks"), content="true")
  inspect(xml.contains("containsErrors"), content="true")
  inspect(xml.contains("notContainsErrors"), content="true")
  inspect(xml.contains("type=\"expression\""), content="true")
  inspect(xml.contains("iconSet=\"3Stars\""), content="true")
  inspect(xml.contains("reverse=\"1\""), content="true")
  inspect(xml.contains("showValue=\"0\""), content="true")
  inspect(xml.contains("stopIfTrue=\"1\""), content="true")
}

///|
test "conditional format: invalid time_period criteria" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let time = ConditionalFormatOptions::new("time_period")
  time.set_criteria("nope")
  let result : Result[Unit, Error] = Ok(
    sheet.set_conditional_format("A1", [time]),
  ) catch {
    e => Err(e)
  }
  inspect(result is Err(XlsxError::InvalidConditionalFormat(_)), content="true")
}
