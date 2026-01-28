///|
test "chart package" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let chart_xml =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<c:chartSpace xmlns:c="http://schemas.openxmlformats.org/drawingml/2006/chart">
    #|  <c:chart/>
    #|</c:chartSpace>
  sheet.add_chart("C3", chart_xml)
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let chart = match archive.get("xl/charts/chart1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing chart")
  }
  inspect(chart.contains("<c:chartSpace"), content="true")
  let drawing_xml = match archive.get("xl/drawings/drawing1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing drawing")
  }
  inspect(drawing_xml.contains("graphicFrame"), content="true")
  inspect(drawing_xml.contains("rId1"), content="true")
  let drawing_rels = match archive.get("xl/drawings/_rels/drawing1.xml.rels") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing drawing rels")
  }
  inspect(drawing_rels.contains("../charts/chart1.xml"), content="true")
  let types_xml = match archive.get("[Content_Types].xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing content types")
  }
  inspect(types_xml.contains("chart1.xml"), content="true")
}

///|
test "chart delete" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let chart_xml =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<c:chartSpace xmlns:c="http://schemas.openxmlformats.org/drawingml/2006/chart">
    #|  <c:chart/>
    #|</c:chartSpace>
  sheet.add_chart("A1", chart_xml)
  sheet.add_chart("C3", chart_xml)
  inspect(sheet.charts().length(), content="2")
  sheet.delete_chart("A1")
  inspect(sheet.charts().length(), content="1")
  workbook.delete_chart("Sheet1", "C3")
  inspect(sheet.charts().length(), content="0")
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  inspect(archive.get("xl/charts/chart1.xml") is None, content="true")
}

///|
test "chart options write" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let opts = ChartOptions::new(ChartType::Col)
  opts.series.push(
    ChartSeries::new("Sheet1!$A$2:$A$4", "Sheet1!$B$2:$B$4", name="Sheet1!$B$1"),
  )
  opts.title = "Sales"
  opts.format = GraphicOptions::with_values(
    offset_x=10,
    offset_y=20,
    locked=false,
    print_object=false,
  )
  workbook.add_chart_with_options("Sheet1", "C3", opts)
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let chart_part = match archive.get("xl/charts/chart1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing chart")
  }
  inspect(chart_part.contains("<c:barChart>"), content="true")
  inspect(chart_part.contains("Sheet1!$A$2:$A$4"), content="true")
  inspect(chart_part.contains("Sheet1!$B$2:$B$4"), content="true")
  inspect(chart_part.contains("<a:t>Sales</a:t>"), content="true")
  let drawing_xml = match archive.get("xl/drawings/drawing1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing drawing")
  }
  inspect(drawing_xml.contains("<xdr:col>2</xdr:col>"), content="true")
  inspect(drawing_xml.contains("<xdr:row>2</xdr:row>"), content="true")
  inspect(
    drawing_xml.contains("<xdr:colOff>95250</xdr:colOff>"),
    content="true",
  )
  inspect(
    drawing_xml.contains("<xdr:rowOff>190500</xdr:rowOff>"),
    content="true",
  )
  inspect(drawing_xml.contains("cx=\"4572000\""), content="true")
  inspect(drawing_xml.contains("cy=\"2476500\""), content="true")
  inspect(drawing_xml.contains("fLocksWithSheet=\"0\""), content="true")
  inspect(drawing_xml.contains("fPrintsWithSheet=\"0\""), content="true")
}
