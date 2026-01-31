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

///|
test "chart sheet with options (excelize-like)" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell("A2", "Small")
  sheet.set_cell("A3", "Normal")
  sheet.set_cell("A4", "Large")
  sheet.set_cell("B1", "Apple")
  sheet.set_cell("C1", "Orange")
  sheet.set_cell("D1", "Pear")
  sheet.set_cell("B2", "2")
  sheet.set_cell("C2", "3")
  sheet.set_cell("D2", "3")
  sheet.set_cell("B3", "5")
  sheet.set_cell("C3", "2")
  sheet.set_cell("D3", "4")
  sheet.set_cell("B4", "6")
  sheet.set_cell("C4", "7")
  sheet.set_cell("D4", "8")
  let opts = ChartOptions::new(Col3DClustered)
  opts.title = "Fruit 3D Clustered Column Chart"
  opts.series.push(
    ChartSeries::new("Sheet1!$B$1:$D$1", "Sheet1!$B$2:$D$2", name="Sheet1!$A$2"),
  )
  opts.series.push(
    ChartSeries::new("Sheet1!$B$1:$D$1", "Sheet1!$B$3:$D$3", name="Sheet1!$A$3"),
  )
  opts.series.push(
    ChartSeries::new("Sheet1!$B$1:$D$1", "Sheet1!$B$4:$D$4", name="Sheet1!$A$4"),
  )
  ignore(workbook.add_chart_sheet_with_options("Chart1", opts))
  let mut sheet_idx = 0
  for i, name in workbook.get_sheet_list() {
    if name == "Chart1" {
      sheet_idx = i
      break
    }
  }
  workbook.set_active_sheet(sheet_idx)
  let result : Result[Unit, Error] = try? workbook.set_cell_value(
    "Chart1",
    "A1",
    Bool(true),
  )
  guard result is Err(XlsxError::InvalidSheetOperation(msg~)) else {
    fail("expected chartsheet not-a-worksheet error")
  }
  inspect(msg.contains("not a worksheet"), content="true")
  let exists_result : Result[ChartSheet, Error] = try? workbook.add_chart_sheet_with_options(
    "Sheet1", opts,
  )
  inspect(
    exists_result is Err(XlsxError::SheetAlreadyExists(_)),
    content="true",
  )
  let name_result : Result[ChartSheet, Error] = try? workbook.add_chart_sheet_with_options(
    "Sheet:1", opts,
  )
  inspect(name_result is Err(XlsxError::InvalidSheetName(_)), content="true")
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let chart_part = match archive.get("xl/charts/chart1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing chart")
  }
  inspect(
    chart_part.contains("<a:t>Fruit 3D Clustered Column Chart</a:t>"),
    content="true",
  )
}
