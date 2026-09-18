///|
fn count_xml_tag_sparkline(xml : String, tag : String) -> Int {
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
test "integration sparkline ooxml consistency" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Trend Data")

  sheet.set_cell_value("B2", Numeric(12.0))
  sheet.set_cell_value("C2", Numeric(9.0))
  sheet.set_cell_value("D2", Numeric(15.0))
  sheet.set_cell_value("E2", Numeric(11.0))
  sheet.set_cell_value("B3", Numeric(7.0))
  sheet.set_cell_value("C3", Numeric(14.0))
  sheet.set_cell_value("D3", Numeric(10.0))
  sheet.set_cell_value("E3", Numeric(16.0))

  let options = @xlsx.SparklineOptions::new(["F2", "F3"], ["B2:E2", "B3:E3"])
  options.set_type(Column)
  options.set_date_axis(true)
  options.set_markers(true)
  options.set_axis(true)
  options.set_hidden(true)
  options.set_manual_min(-5)
  options.set_manual_max(25)
  options.set_empty_cells("zero")
  options.set_series_color("4F81BD")
  options.set_negative_color("C0504D")
  options.set_high_color("9BBB59")
  sheet.add_sparkline_options(options)

  let archive = @zip.read(@xlsx.write(workbook))
  let sheet_xml = match archive.get("xl/worksheets/sheet1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing sheet1.xml")
  }

  inspect(
    sheet_xml.contains("{05C60535-1F16-4fd2-B633-F4F36F0B64E0}"),
    content="true",
  )
  inspect(sheet_xml.contains("x14:sparklineGroups"), content="true")
  inspect(
    sheet_xml.contains(
      "xmlns:xm=\"http://schemas.microsoft.com/office/excel/2006/main\"",
    ),
    content="true",
  )
  inspect(sheet_xml.contains("type=\"column\""), content="true")
  inspect(sheet_xml.contains("dateAxis=\"1\""), content="true")
  inspect(sheet_xml.contains("markers=\"1\""), content="true")
  inspect(sheet_xml.contains("displayXAxis=\"1\""), content="true")
  inspect(sheet_xml.contains("displayHidden=\"1\""), content="true")
  inspect(sheet_xml.contains("manualMin=\"-5\""), content="true")
  inspect(sheet_xml.contains("manualMax=\"25\""), content="true")
  inspect(sheet_xml.contains("displayEmptyCellsAs=\"zero\""), content="true")
  inspect(sheet_xml.contains("<xm:f>'Trend Data'!B2:E2</xm:f>"), content="true")
  inspect(sheet_xml.contains("<xm:f>'Trend Data'!B3:E3</xm:f>"), content="true")
  inspect(sheet_xml.contains("<xm:sqref>F2</xm:sqref>"), content="true")
  inspect(sheet_xml.contains("<xm:sqref>F3</xm:sqref>"), content="true")
  inspect(sheet_xml.contains("x14:colorSeries"), content="true")
  inspect(sheet_xml.contains("rgb=\"FF4F81BD\""), content="true")
  inspect(sheet_xml.contains("x14:colorNegative"), content="true")
  inspect(sheet_xml.contains("rgb=\"FFC0504D\""), content="true")
  inspect(sheet_xml.contains("x14:colorHigh"), content="true")
  inspect(sheet_xml.contains("rgb=\"FF9BBB59\""), content="true")
  inspect(
    count_xml_tag_sparkline(sheet_xml, "<x14:sparklineGroup type="),
    content="1",
  )
  inspect(count_xml_tag_sparkline(sheet_xml, "<x14:sparkline>"), content="2")
}
