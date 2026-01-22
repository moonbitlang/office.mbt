///|
test "conditional format set/get/unset" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let opt = ConditionalFormatOptions::new("cell")
  opt.criteria = ">"
  opt.value = "6"
  sheet.set_conditional_format("A1:A2", [opt])
  let xml = sheet.conditional_formats()[0]
  inspect(xml.contains("type=\"cellIs\""), content="true")
  inspect(xml.contains("operator=\"greaterThan\""), content="true")
  inspect(xml.contains("<formula>6</formula>"), content="true")
  let formats = sheet.get_conditional_formats()
  let opts = match formats.get("A1:A2") {
    Some(value) => value
    None => fail("missing formats")
  }
  inspect(opts.length(), content="1")
  inspect(opts[0].format_type, content="cell")
  inspect(opts[0].criteria, content="greater than")
  sheet.unset_conditional_format("A1")
  let updated = sheet.conditional_formats()[0]
  inspect(updated.contains("sqref=\"A2\""), content="true")
  sheet.unset_conditional_format("A2")
  inspect(sheet.conditional_formats().length(), content="0")
}

///|
test "conditional format color scale, data bar, icon set" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let scale = ConditionalFormatOptions::new("3_color_scale")
  scale.criteria = "="
  scale.min_type = "num"
  scale.mid_type = "num"
  scale.max_type = "num"
  scale.min_value = "-10"
  scale.mid_value = "0"
  scale.max_value = "10"
  scale.min_color = "ff0000"
  scale.mid_color = "00ff00"
  scale.max_color = "0000ff"
  sheet.set_conditional_format("B1:B2", [scale])
  let data_bar = ConditionalFormatOptions::new("data_bar")
  data_bar.min_type = "min"
  data_bar.max_type = "max"
  data_bar.bar_color = "#638EC6"
  sheet.set_conditional_format("C1:C2", [data_bar])
  let icons = ConditionalFormatOptions::new("icon_set")
  icons.icon_style = "3Stars"
  sheet.set_conditional_format("D1:D2", [icons])
  let formats = sheet.conditional_formats()
  inspect(formats[0].contains("colorScale"), content="true")
  inspect(formats[0].contains("rgb=\"FFFF0000\""), content="true")
  inspect(formats[1].contains("dataBar"), content="true")
  inspect(formats[1].contains("rgb=\"FF638EC6\""), content="true")
  inspect(formats[2].contains("iconSet=\"3Stars\""), content="true")
}

///|
test "conditional format invalid type" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let opt = ConditionalFormatOptions::new("unsupported")
  let result : Result[Unit, Error] = try? sheet.set_conditional_format("A1", [
    opt,
  ])
  guard result is Err(XlsxError::InvalidConditionalFormat(_)) else {
    fail("expected invalid type")
  }
}
