///|
fn count_xml_tag_mixed(xml : String, tag : String) -> Int {
  let mut count = 0
  let mut first = true
  for _ in xml.split(tag) {
    if first {
      first = false
      continue
    }
    count = count + 1
  }
  count
}

///|
test "integration sparkline and x14 conditional formatting coexistence" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")

  sheet.set_cell_value("B2", Numeric(12.0))
  sheet.set_cell_value("C2", Numeric(9.0))
  sheet.set_cell_value("D2", Numeric(15.0))
  sheet.set_cell_value("B3", Numeric(7.0))
  sheet.set_cell_value("C3", Numeric(14.0))
  sheet.set_cell_value("D3", Numeric(10.0))
  sheet.set_cell_value("B4", Numeric(8.0))
  sheet.set_cell_value("C4", Numeric(11.0))
  sheet.set_cell_value("D4", Numeric(16.0))

  let sparkline_opts = @xlsx.SparklineOptions::new(["E2", "E3", "E4"], [
    "B2:D2", "B3:D3", "B4:D4",
  ])
  sparkline_opts.set_markers(true)
  sparkline_opts.set_empty_cells("span")
  sparkline_opts.set_series_color("00AA00")
  sheet.add_sparkline_options(sparkline_opts)

  let cf_opt = @xlsx.ConditionalFormatOptions::new("data_bar")
  cf_opt.set_min_type("min")
  cf_opt.set_max_type("max")
  cf_opt.set_bar_color("#638EC6")
  cf_opt.set_bar_direction("rightToLeft")
  cf_opt.set_bar_solid(true)
  cf_opt.set_bar_border_color("#0000FF")
  sheet.set_conditional_format("B2:B4", [cf_opt])

  let bytes = @xlsx.write(workbook)
  let archive = @zip.read(bytes)
  let sheet_xml = match archive.get("xl/worksheets/sheet1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing sheet1.xml")
  }

  inspect(
    count_xml_tag_mixed(
      sheet_xml, "<ext uri=\"{78C0D931-6437-407d-A8EE-F0AAD7539E65}\">",
    ),
    content="1",
  )
  inspect(
    count_xml_tag_mixed(
      sheet_xml, "<ext uri=\"{05C60535-1F16-4fd2-B633-F4F36F0B64E0}\">",
    ),
    content="1",
  )
  inspect(
    sheet_xml.contains("{78C0D931-6437-407d-A8EE-F0AAD7539E65}"),
    content="true",
  )
  inspect(
    sheet_xml.contains("{05C60535-1F16-4fd2-B633-F4F36F0B64E0}"),
    content="true",
  )
  inspect(sheet_xml.contains("x14:conditionalFormattings"), content="true")
  inspect(sheet_xml.contains("x14:sparklineGroups"), content="true")
  inspect(sheet_xml.contains("<xm:sqref>B2:B4</xm:sqref>"), content="true")
  inspect(sheet_xml.contains("<xm:sqref>E2</xm:sqref>"), content="true")
  inspect(sheet_xml.contains("mc:Ignorable=\"x14\""), content="true")
  inspect(
    sheet_xml.contains(
      "xmlns:x14=\"http://schemas.microsoft.com/office/spreadsheetml/2009/9/main\"",
    ),
    content="true",
  )
  inspect(count_xml_tag_mixed(sheet_xml, "<x14:sparkline>"), content="3")
  inspect(
    count_xml_tag_mixed(sheet_xml, "<x14:cfRule type=\"dataBar\""),
    content="1",
  )

  let parsed = @xlsx.read(bytes)
  let parsed_sheet = match parsed.sheet("Sheet1") {
    Some(value) => value
    None => fail("missing parsed sheet")
  }
  inspect(parsed_sheet.sparkline_groups().length(), content="1")
  inspect(parsed_sheet.sparkline_groups()[0].sparklines.length(), content="3")

  let formats = parsed.get_conditional_formats("Sheet1")
  let opts = match formats.get("B2:B4") {
    Some(value) => value
    None => fail("missing conditional formats")
  }
  inspect(opts.length(), content="1")
  inspect(opts[0].bar_direction, content="rightToLeft")
  inspect(opts[0].bar_solid, content="true")
  inspect(opts[0].bar_border_color, content="#0000FF")
}
