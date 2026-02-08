///|
fn count_xml_tag_roundtrip(xml : String, tag : String) -> Int {
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
test "integration mixed ext features stable across repeated roundtrip" {
  let workbook = Workbook::new()
  let data = workbook.add_sheet("Data")
  let dashboard = workbook.add_sheet("Dashboard")

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
    workbook.add_table_with_columns("Data", "A1:B5", "MixTable", [
      "Region", "Value",
    ]),
  )
  workbook.add_slicer(
    "Dashboard",
    SlicerOptions::new("Region", "B2", "Data", "MixTable"),
  )

  dashboard.set_cell_value("C2", Numeric(10.0))
  dashboard.set_cell_value("C3", Numeric(24.0))
  dashboard.set_cell_value("C4", Numeric(18.0))

  let sparkline_opts = SparklineOptions::new(["G2", "G3", "G4"], [
    "'Data'!B2:B5", "'Data'!B2:B5", "'Data'!B2:B5",
  ])
  sparkline_opts.set_markers(true)
  sparkline_opts.set_series_color("4F81BD")
  workbook.add_sparkline_options("Dashboard", sparkline_opts)

  let cf_opt = ConditionalFormatOptions::new("data_bar")
  cf_opt.set_min_type("min")
  cf_opt.set_max_type("max")
  cf_opt.set_bar_color("#638EC6")
  cf_opt.set_bar_direction("rightToLeft")
  cf_opt.set_bar_solid(true)
  cf_opt.set_bar_border_color("#0000FF")
  workbook.set_conditional_format("Dashboard", "C2:C4", [cf_opt])

  let bytes_once = write(workbook)
  let archive_once = @zip.read(bytes_once)
  let dashboard_xml_once = match archive_once.get("xl/worksheets/sheet2.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing dashboard xml after first write")
  }

  inspect(
    dashboard_xml_once.contains("{05C60535-1F16-4fd2-B633-F4F36F0B64E0}"),
    content="true",
  )
  inspect(
    dashboard_xml_once.contains("{78C0D931-6437-407d-A8EE-F0AAD7539E65}"),
    content="true",
  )
  inspect(
    dashboard_xml_once.contains("{A8765BA9-456A-4dab-B4F3-ACF838C121DE}") ||
    dashboard_xml_once.contains("{3A4CF648-6AED-40f4-86FF-DC5316D8AED3}"),
    content="true",
  )
  inspect(
    count_xml_tag_roundtrip(dashboard_xml_once, "<x14:sparkline>"),
    content="3",
  )
  inspect(
    count_xml_tag_roundtrip(dashboard_xml_once, "<x14:cfRule type=\"dataBar\""),
    content="1",
  )

  let parsed_once = read(bytes_once)
  let bytes_twice = write(parsed_once)
  let archive_twice = @zip.read(bytes_twice)
  let dashboard_xml_twice = match
    archive_twice.get("xl/worksheets/sheet2.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing dashboard xml after second write")
  }

  inspect(
    dashboard_xml_twice.contains("{05C60535-1F16-4fd2-B633-F4F36F0B64E0}"),
    content="true",
  )
  inspect(
    dashboard_xml_twice.contains("{78C0D931-6437-407d-A8EE-F0AAD7539E65}"),
    content="true",
  )
  inspect(
    dashboard_xml_twice.contains("{A8765BA9-456A-4dab-B4F3-ACF838C121DE}") ||
    dashboard_xml_twice.contains("{3A4CF648-6AED-40f4-86FF-DC5316D8AED3}"),
    content="true",
  )
  inspect(
    count_xml_tag_roundtrip(dashboard_xml_twice, "<x14:sparkline>"),
    content="3",
  )
  inspect(
    count_xml_tag_roundtrip(dashboard_xml_twice, "<x14:cfRule type=\"dataBar\""),
    content="1",
  )
  inspect(
    archive_twice.get("xl/slicerCaches/slicerCache1.xml") is Some(_),
    content="true",
  )
  inspect(
    archive_twice.get("xl/slicers/slicer1.xml") is Some(_),
    content="true",
  )

  let parsed_twice = read(bytes_twice)
  let parsed_dashboard = match parsed_twice.sheet("Dashboard") {
    Some(value) => value
    None => fail("missing parsed dashboard")
  }
  inspect(parsed_dashboard.sparkline_groups().length(), content="1")
  inspect(
    parsed_dashboard.sparkline_groups()[0].sparklines.length(),
    content="3",
  )
  let formats = parsed_twice.get_conditional_formats("Dashboard")
  let opts = match formats.get("C2:C4") {
    Some(value) => value
    None => fail("missing conditional format")
  }
  inspect(opts.length(), content="1")
  inspect(opts[0].bar_direction, content="rightToLeft")
  inspect(opts[0].bar_solid, content="true")
  inspect(opts[0].bar_border_color, content="#0000FF")
}
