///|
test "conditional format data bar x14 extLst roundtrip" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let opt = ConditionalFormatOptions::new("data_bar")
  opt.set_min_type("min")
  opt.set_max_type("max")
  opt.set_bar_color("#638EC6")
  opt.set_bar_border_color("#0000FF")
  opt.set_bar_direction("rightToLeft")
  opt.set_bar_solid(true)
  sheet.set_conditional_format("A1:A3", [opt])
  let bytes = write(workbook)
  let archive = @zip.read(bytes) catch {
    err => fail("zip read failed: \{err}")
  }
  let sheet_xml = match archive.get("xl/worksheets/sheet1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing sheet1.xml")
  }
  inspect(
    sheet_xml.contains("{B025F937-C7B1-47D3-B67F-A62EFF666E3E}"),
    content="true",
  )
  inspect(
    sheet_xml.contains(
      "<x14:id>{00000000-0000-0000-0000-000000000001}</x14:id>",
    ),
    content="true",
  )
  inspect(
    sheet_xml.contains("{78C0D931-6437-407d-A8EE-F0AAD7539E65}"),
    content="true",
  )
  inspect(sheet_xml.contains("x14:conditionalFormattings"), content="true")
  inspect(sheet_xml.contains("direction=\"rightToLeft\""), content="true")
  inspect(sheet_xml.contains("gradient=\"0\""), content="true")
  inspect(
    sheet_xml.contains("x14:borderColor rgb=\"FF0000FF\""),
    content="true",
  )
  let parsed = read(bytes)
  let formats = parsed.get_conditional_formats("Sheet1")
  let opts = match formats.get("A1:A3") {
    Some(value) => value
    None => fail("missing formats")
  }
  inspect(opts.length(), content="1")
  inspect(opts[0].format_type, content="data_bar")
  inspect(opts[0].criteria, content="=")
  inspect(opts[0].bar_direction, content="rightToLeft")
  inspect(opts[0].bar_solid, content="true")
  inspect(opts[0].bar_border_color, content="#0000FF")
}
