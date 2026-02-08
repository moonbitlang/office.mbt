///|
test "conditional format set/get/unset" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let opt = ConditionalFormatOptions::new("cell")
  opt.set_criteria(">")
  opt.set_value("6")
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
  scale.set_criteria("=")
  scale.set_min_type("num")
  scale.set_mid_type("num")
  scale.set_max_type("num")
  scale.set_min_value("-10")
  scale.set_mid_value("0")
  scale.set_max_value("10")
  scale.set_min_color("ff0000")
  scale.set_mid_color("00ff00")
  scale.set_max_color("0000ff")
  sheet.set_conditional_format("B1:B2", [scale])
  let data_bar = ConditionalFormatOptions::new("data_bar")
  data_bar.set_min_type("min")
  data_bar.set_max_type("max")
  data_bar.set_bar_color("#638EC6")
  sheet.set_conditional_format("C1:C2", [data_bar])
  let icons = ConditionalFormatOptions::new("icon_set")
  icons.set_icon_style("3Stars")
  sheet.set_conditional_format("D1:D2", [icons])
  let formats = sheet.conditional_formats()
  inspect(formats[0].contains("colorScale"), content="true")
  inspect(formats[0].contains("rgb=\"FFFF0000\""), content="true")
  inspect(formats[1].contains("dataBar"), content="true")
  inspect(formats[1].contains("rgb=\"FF638EC6\""), content="true")
  inspect(formats[2].contains("iconSet=\"3Stars\""), content="true")
  let first_color = match formats[0].find("<color rgb=") {
    Some(value) => value
    None => fail("missing color tag")
  }
  let last_cfvo = match formats[0].rev_find("<cfvo") {
    Some(value) => value
    None => fail("missing cfvo tag")
  }
  inspect(last_cfvo < first_color, content="true")
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

///|
test "conditional format setters: stopIfTrue and dxfId" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let opt = ConditionalFormatOptions::new("cell")
  opt.set_criteria(">")
  opt.set_value("1")
  opt.set_format(Some(3))
  opt.set_stop_if_true(true)
  sheet.set_conditional_format("A1:A2", [opt])
  let xml = sheet.conditional_formats()[0]
  inspect(xml.contains("dxfId=\"3\""), content="true")
  inspect(xml.contains("stopIfTrue=\"1\""), content="true")
}
