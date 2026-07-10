///|
fn count_xml_tag_cross_sheet(xml : String, tag : String) -> Int {
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
test "integration sparkline cross-sheet formula references" {
  let workbook = @xlsx.Workbook::new()
  let source = workbook.add_sheet("Data O'Reilly")
  let dashboard = workbook.add_sheet("Dashboard")

  source.set_cell_value("B2", Numeric(12.0))
  source.set_cell_value("C2", Numeric(9.0))
  source.set_cell_value("D2", Numeric(15.0))
  source.set_cell_value("B3", Numeric(7.0))
  source.set_cell_value("C3", Numeric(14.0))
  source.set_cell_value("D3", Numeric(10.0))

  let options = @xlsx.SparklineOptions::new(["H2", "H3"], [
    "'Data O''Reilly'!B2:D2", "'Data O''Reilly'!B3:D3",
  ])
  options.set_markers(true)
  options.set_empty_cells("span")
  dashboard.add_sparkline_options(options)

  let bytes = @xlsx.write(workbook)
  let archive = @zip.read(bytes)
  let dashboard_xml = match archive.get("xl/worksheets/sheet2.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing sheet2.xml")
  }

  inspect(
    dashboard_xml.contains("<xm:f>'Data O''Reilly'!B2:D2</xm:f>"),
    content="true",
  )
  inspect(
    dashboard_xml.contains("<xm:f>'Data O''Reilly'!B3:D3</xm:f>"),
    content="true",
  )
  inspect(
    dashboard_xml.contains("<xm:f>'Dashboard'!B2:D2</xm:f>"),
    content="false",
  )
  inspect(
    count_xml_tag_cross_sheet(dashboard_xml, "<x14:sparkline>"),
    content="2",
  )
  inspect(dashboard_xml.contains("<xm:sqref>H2</xm:sqref>"), content="true")
  inspect(dashboard_xml.contains("<xm:sqref>H3</xm:sqref>"), content="true")

  let parsed = @xlsx.read(bytes)
  let parsed_dashboard = match parsed.sheet("Dashboard") {
    Some(value) => value
    None => fail("missing parsed dashboard sheet")
  }
  inspect(parsed_dashboard.sparkline_groups().length(), content="1")
  inspect(
    parsed_dashboard.sparkline_groups()[0].sparklines.length(),
    content="2",
  )
  inspect(
    parsed_dashboard.sparkline_groups()[0].sparklines[0].range_ref,
    content="B2:D2",
  )
  inspect(
    parsed_dashboard.sparkline_groups()[0].sparklines[1].range_ref,
    content="B3:D3",
  )
}
