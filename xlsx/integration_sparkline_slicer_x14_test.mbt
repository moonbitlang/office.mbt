///|
fn count_xml_tag_sparkline_slicer(xml : String, tag : String) -> Int {
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
fn rel_attr_values_sparkline_slicer(xml : String, attr : String) -> Array[String] {
  let values : Array[String] = []
  let marker = "\{attr}=\""
  let mut first = true
  for chunk in xml.split("<Relationship ") {
    if first {
      first = false
      continue
    }
    let part = chunk.to_string()
    match part.find(marker) {
      Some(start) => {
        let rest = part[start + marker.length():] catch { _ => "" }
        match rest.find("\"") {
          Some(end) => {
            let value = (rest[:end] catch { _ => "" }).to_string()
            values.push(value)
          }
          None => ()
        }
      }
      None => ()
    }
  }
  values
}

///|
fn has_value_sparkline_slicer(
  values : ArrayView[String],
  expected : String,
) -> Bool {
  for value in values {
    if value == expected {
      return true
    }
  }
  false
}

///|
test "integration sparkline slicer and x14 conditional formatting coexistence" {
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

  let sparkline_opts = SparklineOptions::new(
    ["G2", "G3", "G4"],
    ["'Data'!B2:B5", "'Data'!B2:B5", "'Data'!B2:B5"],
  )
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

  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let sheet_xml = match archive.get("xl/worksheets/sheet2.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing dashboard xml")
  }
  let rels_xml = match archive.get("xl/worksheets/_rels/sheet2.xml.rels") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing dashboard rels")
  }

  inspect(sheet_xml.contains("{05C60535-1F16-4fd2-B633-F4F36F0B64E0}"), content="true")
  inspect(sheet_xml.contains("{78C0D931-6437-407d-A8EE-F0AAD7539E65}"), content="true")
  inspect(
    sheet_xml.contains("{A8765BA9-456A-4dab-B4F3-ACF838C121DE}") ||
      sheet_xml.contains("{3A4CF648-6AED-40f4-86FF-DC5316D8AED3}"),
    content="true",
  )
  inspect(sheet_xml.contains("x14:sparklineGroups"), content="true")
  inspect(sheet_xml.contains("x14:conditionalFormattings"), content="true")
  inspect(sheet_xml.contains("x14:slicerList"), content="true")
  inspect(count_xml_tag_sparkline_slicer(sheet_xml, "<x14:sparkline>"), content="3")
  inspect(
    count_xml_tag_sparkline_slicer(sheet_xml, "<x14:cfRule type=\"dataBar\""),
    content="1",
  )

  let sheet_targets = rel_attr_values_sparkline_slicer(rels_xml, "Target")
  inspect(
    has_value_sparkline_slicer(sheet_targets[:], "../slicers/slicer1.xml"),
    content="true",
  )
  inspect(archive.get("xl/slicerCaches/slicerCache1.xml") is Some(_), content="true")
  inspect(archive.get("xl/slicers/slicer1.xml") is Some(_), content="true")

  let parsed = read(bytes)
  let parsed_dashboard = match parsed.sheet("Dashboard") {
    Some(value) => value
    None => fail("missing parsed dashboard")
  }
  inspect(parsed_dashboard.sparkline_groups().length(), content="1")
  inspect(parsed_dashboard.sparkline_groups()[0].sparklines.length(), content="3")
  let formats = parsed.get_conditional_formats("Dashboard")
  let opts = match formats.get("C2:C4") {
    Some(value) => value
    None => fail("missing conditional format")
  }
  inspect(opts.length(), content="1")
  inspect(opts[0].bar_direction, content="rightToLeft")
  inspect(opts[0].bar_solid, content="true")
  inspect(opts[0].bar_border_color, content="#0000FF")
}
