///|
test "integration three-cycle mixed ext relationship ids remain unique" {
  let workbook = Workbook::new()
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
    SlicerOptions::new("Region", "A1", "Data", "PivotData"),
  )

  dash.set_cell_value("C2", Numeric(10.0))
  dash.set_cell_value("C3", Numeric(24.0))
  dash.set_cell_value("C4", Numeric(18.0))

  let sparkline_opts = SparklineOptions::new(["G2", "G3", "G4"], [
    "'Data'!B2:B5", "'Data'!B2:B5", "'Data'!B2:B5",
  ])
  sparkline_opts.set_markers(true)
  sparkline_opts.set_series_color("4F81BD")
  workbook.add_sparkline_options("Dash", sparkline_opts)

  let cf_opt = ConditionalFormatOptions::new("data_bar")
  cf_opt.set_min_type("min")
  cf_opt.set_max_type("max")
  cf_opt.set_bar_color("#638EC6")
  cf_opt.set_bar_direction("rightToLeft")
  cf_opt.set_bar_solid(true)
  cf_opt.set_bar_border_color("#0000FF")
  workbook.set_conditional_format("Dash", "C2:C4", [cf_opt])

  let chart_opts = ChartOptions::new(Line)
  chart_opts.series.push(
    ChartSeries::new("Data!$A$2:$A$5", "Data!$B$2:$B$5", name="Series1"),
  )
  workbook.add_chart_with_options("Dash", "J2", chart_opts)

  let bytes1 = write(workbook)
  let bytes2 = write(read(bytes1))
  let bytes3 = write(read(bytes2))
  let archive = @zip.read(bytes3)

  let sheet_rels_xml = match
    archive.get("xl/worksheets/_rels/sheet2.xml.rels") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing sheet rels")
  }
  let drawing_rels_xml = match
    archive.get("xl/drawings/_rels/drawing1.xml.rels") {
    Some(value) => @encoding/utf8.decode(value)
    None =>
      match archive.get("xl/drawings/_rels/drawing2.xml.rels") {
        Some(value) => @encoding/utf8.decode(value)
        None => fail("missing drawing rels")
      }
  }

  let sheet_ids = integration_rel_attr_values(sheet_rels_xml, "Id")
  let sheet_targets = integration_rel_attr_values(sheet_rels_xml, "Target")
  let drawing_ids = integration_rel_attr_values(drawing_rels_xml, "Id")
  let drawing_targets = integration_rel_attr_values(drawing_rels_xml, "Target")

  inspect(integration_unique_values(sheet_ids[:]), content="true")
  inspect(integration_unique_values(drawing_ids[:]), content="true")
  inspect(
    integration_has_value(drawing_targets[:], "../charts/chart1.xml"),
    content="true",
  )

  let mut has_drawing_target = false
  for target in sheet_targets {
    if target.has_prefix("../drawings/drawing") {
      has_drawing_target = true
      break
    }
  }
  inspect(has_drawing_target, content="true")
  inspect(
    integration_has_value(sheet_targets[:], "../slicers/slicer1.xml"),
    content="true",
  )

  let all_targets = sheet_targets + drawing_targets
  let mut all_exist = true
  for target in all_targets {
    let part = integration_rel_target_to_part_path(target)
    if archive.get(part) is None {
      all_exist = false
      break
    }
  }
  inspect(all_exist, content="true")
}
