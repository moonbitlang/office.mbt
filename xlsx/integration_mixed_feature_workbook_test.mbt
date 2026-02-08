///|
test "integration mixed feature workbook ooxml sanity" {
  let workbook = Workbook::new()
  let data = workbook.add_sheet("Data")
  ignore(workbook.add_sheet("Dashboard"))

  data.set_cell_value("A1", String("Region"))
  data.set_cell_value("B1", String("Value"))
  for row in 2..<=6 {
    data.set_cell_value("A\{row}", String("R\{row - 1}"))
    data.set_cell_value("B\{row}", Numeric(Double::from_int(row * 5)))
  }

  ignore(
    workbook.add_table_with_columns("Data", "A1:B6", "MixTable", [
      "Region", "Value",
    ]),
  )
  ignore(
    workbook.add_pivot_table_xml(
      "Data",
      "<pivotTableDefinition name=\"PivotMix\"/>",
      "<pivotCacheDefinition><cacheFields count=\"1\"><cacheField name=\"Region\"/></cacheFields></pivotCacheDefinition>",
      name="PivotMix",
    ),
  )

  let slicer_opts = SlicerOptions::new("Region", "A1", "Data", "PivotMix")
  workbook.add_slicer("Dashboard", slicer_opts)

  let chart_opts = ChartOptions::new(Line)
  chart_opts.series.push(
    ChartSeries::new("Data!$A$2:$A$6", "Data!$B$2:$B$6", name="Series1"),
  )
  workbook.add_chart_with_options("Dashboard", "D2", chart_opts)
  workbook.add_shape("Dashboard", Shape::new("H2", "rect", text="mix-shape"))

  let archive = @zip.read(write(workbook))

  inspect(archive.get("xl/workbook.xml") is Some(_), content="true")
  inspect(archive.get("xl/worksheets/sheet1.xml") is Some(_), content="true")
  inspect(archive.get("xl/worksheets/sheet2.xml") is Some(_), content="true")
  inspect(archive.get("xl/tables/table1.xml") is Some(_), content="true")
  inspect(
    archive.get("xl/pivotTables/pivotTable1.xml") is Some(_),
    content="true",
  )
  inspect(
    archive.get("xl/pivotCache/pivotCacheDefinition1.xml") is Some(_),
    content="true",
  )
  inspect(
    archive.get("xl/slicerCaches/slicerCache1.xml") is Some(_),
    content="true",
  )
  inspect(archive.get("xl/slicers/slicer1.xml") is Some(_), content="true")
  inspect(archive.get("xl/charts/chart1.xml") is Some(_), content="true")
  inspect(
    archive.get("xl/worksheets/_rels/sheet2.xml.rels") is Some(_),
    content="true",
  )

  let workbook_xml = match archive.get("xl/workbook.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing workbook xml")
  }
  let drawing_xml = match archive.get("xl/drawings/drawing1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None =>
      match archive.get("xl/drawings/drawing2.xml") {
        Some(value) => @encoding/utf8.decode(value)
        None => fail("missing drawing xml")
      }
  }
  let rels_xml = match archive.get("xl/worksheets/_rels/sheet2.xml.rels") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing dashboard rels")
  }
  let slicer_cache_xml = match archive.get("xl/slicerCaches/slicerCache1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing slicer cache xml")
  }

  inspect(workbook_xml.contains("slicerCaches"), content="true")
  inspect(drawing_xml.contains("chart"), content="true")
  inspect(drawing_xml.contains("slicer"), content="true")
  inspect(rels_xml.contains("relationships/slicer"), content="true")
  inspect(rels_xml.contains("relationships/drawing"), content="true")
  inspect(slicer_cache_xml.contains("pivotTable"), content="true")
}
