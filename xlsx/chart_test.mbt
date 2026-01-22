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
