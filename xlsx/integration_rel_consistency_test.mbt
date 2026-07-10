///|
test "integration ooxml relationship consistency for mixed drawing parts" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))

  workbook.set_cell("Sheet1", "A1", "Category")
  workbook.set_cell("Sheet1", "B1", "Value")
  workbook.set_cell("Sheet1", "A2", "A")
  workbook.set_cell("Sheet1", "B2", "1")
  workbook.set_cell("Sheet1", "A3", "B")
  workbook.set_cell("Sheet1", "B3", "2")

  let table_opts = TableOptions::new("A1:B3")
  table_opts.set_name("RelTable")
  ignore(workbook.add_table("Sheet1", table_opts))

  let chart_opts = ChartOptions::new(Line)
  chart_opts.series.push(
    ChartSeries::new("Sheet1!$A$2:$A$3", "Sheet1!$B$2:$B$3", name="Series1"),
  )
  workbook.add_chart_with_options("Sheet1", "C5", chart_opts)

  workbook.add_shape(
    "Sheet1",
    Shape::new("F2", "rect", text="integration-shape"),
  )

  let archive = @zip.read(write(workbook))
  let sheet_rels = match archive.get("xl/worksheets/_rels/sheet1.xml.rels") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing sheet rels")
  }
  let drawing_rels = match archive.get("xl/drawings/_rels/drawing1.xml.rels") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing drawing rels")
  }

  let sheet_rel_ids = integration_rel_attr_values(sheet_rels, "Id")
  let sheet_targets = integration_rel_attr_values(sheet_rels, "Target")
  let drawing_rel_ids = integration_rel_attr_values(drawing_rels, "Id")
  let drawing_targets = integration_rel_attr_values(drawing_rels, "Target")

  inspect(integration_unique_values(sheet_rel_ids), content="true")
  inspect(integration_unique_values(drawing_rel_ids), content="true")
  inspect(
    integration_has_value(sheet_targets, "../drawings/drawing1.xml"),
    content="true",
  )
  inspect(
    integration_has_value(sheet_targets, "../tables/table1.xml"),
    content="true",
  )
  inspect(
    integration_has_value(drawing_targets, "../charts/chart1.xml"),
    content="true",
  )

  inspect(archive.get("xl/drawings/drawing1.xml") is Some(_), content="true")
  inspect(archive.get("xl/tables/table1.xml") is Some(_), content="true")
  inspect(archive.get("xl/charts/chart1.xml") is Some(_), content="true")
}
