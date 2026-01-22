///|
test "chart sheet write and read" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let chart_xml =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<c:chartSpace xmlns:c="http://schemas.openxmlformats.org/drawingml/2006/chart">
    #|  <c:chart/>
    #|</c:chartSpace>
  ignore(workbook.add_chart_sheet("Chart1", chart_xml))
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let workbook_xml = match archive.get("xl/workbook.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing workbook.xml")
  }
  inspect(workbook_xml.contains("Chart1"), content="true")
  let chartsheet_xml = match archive.get("xl/chartsheets/sheet1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing chartsheet")
  }
  inspect(chartsheet_xml.contains("<chartsheet"), content="true")
  inspect(chartsheet_xml.contains("<drawing r:id=\"rId1\"/>"), content="true")
  let chartsheet_rels = match
    archive.get("xl/chartsheets/_rels/sheet1.xml.rels") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing chartsheet rels")
  }
  inspect(chartsheet_rels.contains("drawing"), content="true")
  let chart_part = match archive.get("xl/charts/chart1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing chart")
  }
  inspect(chart_part.contains("<c:chartSpace"), content="true")
  let drawing_rels = match archive.get("xl/drawings/_rels/drawing2.xml.rels") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing drawing rels")
  }
  inspect(drawing_rels.contains("../charts/chart1.xml"), content="true")
  let types_xml = match archive.get("[Content_Types].xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing content types")
  }
  inspect(types_xml.contains("/xl/chartsheets/sheet1.xml"), content="true")
  let parsed = read(bytes)
  inspect(parsed.chart_sheets().length(), content="1")
  let parsed_chart = parsed.chart_sheets()[0]
  inspect(parsed_chart.name(), content="Chart1")
  inspect(parsed_chart.chart_xml().contains("<c:chartSpace"), content="true")
}
