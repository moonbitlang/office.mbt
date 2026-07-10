///|
fn count_xml_tag_three_cycle(xml : String, tag : String) -> Int {
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
test "integration pivot mixed ext stable across three roundtrip cycles" {
  let workbook = @xlsx.Workbook::new()
  let data = workbook.add_sheet("Data")
  let dash = workbook.add_sheet("Dash")

  data.set_cell_value("A1", String("Region"))
  data.set_cell_value("B1", String("Value"))
  data.set_cell_value("A2", String("North"))
  data.set_cell_value("B2", Numeric(12.0))
  data.set_cell_value("A3", String("South"))
  data.set_cell_value("B3", Numeric(9.0))
  data.set_cell_value("A4", String("East"))
  data.set_cell_value("B4", Numeric(15.0))
  data.set_cell_value("A5", String("West"))
  data.set_cell_value("B5", Numeric(11.0))

  ignore(
    workbook.add_pivot_table_xml(
      "Data",
      "<pivotTableDefinition name=\"PivotData\"/>",
      "<pivotCacheDefinition><cacheFields count=\"1\"><cacheField name=\"Region\"/></cacheFields></pivotCacheDefinition>",
      name="PivotData",
    ),
  )
  workbook.add_slicer(
    "Dash",
    @xlsx.SlicerOptions::new("Region", "A1", "Data", "PivotData"),
  )

  dash.set_cell_value("C2", Numeric(10.0))
  dash.set_cell_value("C3", Numeric(24.0))
  dash.set_cell_value("C4", Numeric(18.0))

  let sparkline_opts = @xlsx.SparklineOptions::new(["G2", "G3", "G4"], [
    "'Data'!B2:B5", "'Data'!B2:B5", "'Data'!B2:B5",
  ])
  sparkline_opts.set_markers(true)
  sparkline_opts.set_series_color("4F81BD")
  workbook.add_sparkline_options("Dash", sparkline_opts)

  let cf_opt = @xlsx.ConditionalFormatOptions::new("data_bar")
  cf_opt.set_min_type("min")
  cf_opt.set_max_type("max")
  cf_opt.set_bar_color("#638EC6")
  cf_opt.set_bar_direction("rightToLeft")
  cf_opt.set_bar_solid(true)
  cf_opt.set_bar_border_color("#0000FF")
  workbook.set_conditional_format("Dash", "C2:C4", [cf_opt])

  let chart_opts = @xlsx.ChartOptions::new(Line)
  chart_opts.series.push(
    @xlsx.ChartSeries::new("Data!$A$2:$A$5", "Data!$B$2:$B$5", name="Series1"),
  )
  workbook.add_chart_with_options("Dash", "J2", chart_opts)

  let bytes1 = @xlsx.write(workbook)
  let archive1 = @zip.read(bytes1)
  let sheet_xml1 = match archive1.get("xl/worksheets/sheet2.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing dash xml after cycle 1")
  }

  inspect(count_xml_tag_three_cycle(sheet_xml1, "<x14:sparkline>"), content="3")
  inspect(
    count_xml_tag_three_cycle(sheet_xml1, "<x14:cfRule type=\"dataBar\""),
    content="1",
  )

  let workbook2 = @xlsx.read(bytes1)
  let bytes2 = @xlsx.write(workbook2)
  let workbook3 = @xlsx.read(bytes2)
  let bytes3 = @xlsx.write(workbook3)
  let archive3 = @zip.read(bytes3)
  let sheet_xml3 = match archive3.get("xl/worksheets/sheet2.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing dash xml after cycle 3")
  }

  inspect(
    sheet_xml3.contains("{05C60535-1F16-4fd2-B633-F4F36F0B64E0}"),
    content="true",
  )
  inspect(
    sheet_xml3.contains("{78C0D931-6437-407d-A8EE-F0AAD7539E65}"),
    content="true",
  )
  inspect(
    sheet_xml3.contains("{3A4CF648-6AED-40f4-86FF-DC5316D8AED3}") ||
    sheet_xml3.contains("{A8765BA9-456A-4dab-B4F3-ACF838C121DE}"),
    content="true",
  )
  inspect(sheet_xml3.contains("x14:sparklineGroups"), content="true")
  inspect(sheet_xml3.contains("x14:conditionalFormattings"), content="true")
  inspect(sheet_xml3.contains("x14:slicerList"), content="true")
  inspect(count_xml_tag_three_cycle(sheet_xml3, "<x14:sparkline>"), content="3")
  inspect(
    count_xml_tag_three_cycle(sheet_xml3, "<x14:cfRule type=\"dataBar\""),
    content="1",
  )
  inspect(archive3.get("xl/charts/chart1.xml") is Some(_), content="true")
  inspect(
    archive3.get("xl/drawings/drawing1.xml") is Some(_) ||
    archive3.get("xl/drawings/drawing2.xml") is Some(_),
    content="true",
  )
  inspect(
    archive3.get("xl/slicerCaches/slicerCache1.xml") is Some(_),
    content="true",
  )
  inspect(archive3.get("xl/slicers/slicer1.xml") is Some(_), content="true")
  inspect(
    archive3.get("xl/pivotCache/pivotCacheDefinition1.xml") is Some(_),
    content="true",
  )
  inspect(
    archive3.get("xl/pivotTables/pivotTable1.xml") is Some(_),
    content="true",
  )

  let parsed3 = @xlsx.read(bytes3)
  let parsed_dash = match parsed3.sheet("Dash") {
    Some(value) => value
    None => fail("missing parsed dash after cycle 3")
  }
  inspect(parsed_dash.sparkline_groups().length(), content="1")
  inspect(parsed_dash.sparkline_groups()[0].sparklines.length(), content="3")
  inspect(parsed_dash.charts().length(), content="1")
  let formats = parsed3.get_conditional_formats("Dash")
  let opts = match formats.get("C2:C4") {
    Some(value) => value
    None => fail("missing conditional format after cycle 3")
  }
  inspect(opts.length(), content="1")
  inspect(opts[0].bar_direction, content="rightToLeft")
  inspect(opts[0].bar_solid, content="true")
  inspect(opts[0].bar_border_color, content="#0000FF")
  let slicers = parsed3.get_slicers("Dash")
  inspect(slicers.length(), content="1")
  inspect(slicers[0].source_name, content="Region")
}
