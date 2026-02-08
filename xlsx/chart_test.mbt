///|

///|
fn find_chart_index_or_fail(xml : String, needle : String) -> Int raise Error {
  match xml.find(needle) {
    Some(value) => value
    None => fail("missing needle: \{needle}")
  }
}

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
  let opts = ChartOptions::new(Col)
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
  inspect(drawing_xml.contains("<xdr:twoCellAnchor>"), content="true")
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

///|
test "chart size twoCellAnchor computes to cell" {
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
  opts.dimension = ChartDimension::with_values(640, 480)
  opts.series.push(
    ChartSeries::new("Sheet1!$B$1:$D$1", "Sheet1!$B$2:$D$2", name="Sheet1!$A$2"),
  )
  opts.series.push(
    ChartSeries::new("Sheet1!$B$1:$D$1", "Sheet1!$B$3:$D$3", name="Sheet1!$A$3"),
  )
  opts.series.push(
    ChartSeries::new("Sheet1!$B$1:$D$1", "Sheet1!$B$4:$D$4", name="Sheet1!$A$4"),
  )
  workbook.add_chart_with_options("Sheet1", "E4", opts)
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let drawing_xml = match archive.get("xl/drawings/drawing1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing drawing")
  }
  inspect(drawing_xml.contains("<xdr:col>4</xdr:col>"), content="true")
  inspect(drawing_xml.contains("<xdr:row>3</xdr:row>"), content="true")
  inspect(drawing_xml.contains("<xdr:to>"), content="true")
  inspect(drawing_xml.contains("<xdr:col>14</xdr:col>"), content="true")
  inspect(drawing_xml.contains("<xdr:row>29</xdr:row>"), content="true")
}

///|
test "chart options combo (col + line) secondary axis" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let opts = ChartOptions::new(Col)
  opts.series.push(
    ChartSeries::new("Sheet1!$A$2:$A$4", "Sheet1!$B$2:$B$4", name="Series1"),
  )
  let combo = ChartOptions::new(Line)
  combo.series.push(
    ChartSeries::new("Sheet1!$A$2:$A$4", "Sheet1!$C$2:$C$4", name="Series2"),
  )
  combo.y_axis.secondary = true
  opts.add_combo_chart(combo)
  workbook.add_chart_with_options("Sheet1", "C3", opts)
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let chart_part = match archive.get("xl/charts/chart1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing chart")
  }
  inspect(chart_part.contains("<c:barChart>"), content="true")
  inspect(chart_part.contains("<c:lineChart>"), content="true")
  inspect(chart_part.contains("Sheet1!$B$2:$B$4"), content="true")
  inspect(chart_part.contains("Sheet1!$C$2:$C$4"), content="true")
  inspect(chart_part.contains("axPos val=\"r\""), content="true")
  inspect(chart_part.contains("axId val=\"3\""), content="true")
  inspect(chart_part.contains("axId val=\"4\""), content="true")
  inspect(chart_part.contains("<c:crosses val=\"max\"/>"), content="true")
  inspect(
    chart_part.contains("<c:crossBetween val=\"between\"/>"),
    content="true",
  )
  let line_chart_idx = find_chart_index_or_fail(chart_part, "<c:lineChart>")
  let line_grouping_idx = find_chart_index_or_fail(
    chart_part, "<c:grouping val=\"standard\"/>",
  )
  inspect(line_chart_idx < line_grouping_idx, content="true")
}

///|
test "chart options combo (scatter + col)" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let opts = ChartOptions::new(Scatter)
  opts.series.push(
    ChartSeries::new("Sheet1!$A$2:$A$4", "Sheet1!$B$2:$B$4", name="Series1"),
  )
  let combo = ChartOptions::new(Col)
  combo.series.push(
    ChartSeries::new("Sheet1!$A$2:$A$4", "Sheet1!$C$2:$C$4", name="Series2"),
  )
  opts.add_combo_chart(combo)
  workbook.add_chart_with_options("Sheet1", "C3", opts)
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let chart_part = match archive.get("xl/charts/chart1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing chart")
  }
  inspect(chart_part.contains("<c:scatterChart>"), content="true")
  inspect(chart_part.contains("<c:barChart>"), content="true")
  inspect(
    chart_part.contains("<c:scatterStyle val=\"lineMarker\""),
    content="true",
  )
  let scatter_style_idx = find_chart_index_or_fail(
    chart_part, "<c:scatterStyle",
  )
  let vary_colors_idx = find_chart_index_or_fail(chart_part, "<c:varyColors")
  inspect(scatter_style_idx < vary_colors_idx, content="true")
  inspect(chart_part.contains("axId val=\"1\""), content="true")
  inspect(chart_part.contains("axId val=\"2\""), content="true")
  inspect(chart_part.contains("axId val=\"3\""), content="true")
  inspect(chart_part.contains("axId val=\"4\""), content="true")
}

///|
test "chart options combo (stock + line) uses dateAx" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let opts = ChartOptions::new(StockOpenHighLowClose)
  opts.plot_area.up_bars.fill_color = "00FF00"
  opts.plot_area.down_bars.fill_color = "FF0000"
  opts.series.push(
    ChartSeries::new("Sheet1!$A$2:$A$4", "Sheet1!$B$2:$B$4", name="Open"),
  )
  opts.series.push(
    ChartSeries::new("Sheet1!$A$2:$A$4", "Sheet1!$C$2:$C$4", name="High"),
  )
  opts.series.push(
    ChartSeries::new("Sheet1!$A$2:$A$4", "Sheet1!$D$2:$D$4", name="Low"),
  )
  opts.series.push(
    ChartSeries::new("Sheet1!$A$2:$A$4", "Sheet1!$E$2:$E$4", name="Close"),
  )
  let combo = ChartOptions::new(Line)
  combo.series.push(
    ChartSeries::new("Sheet1!$A$2:$A$4", "Sheet1!$F$2:$F$4", name="MA"),
  )
  opts.add_combo_chart(combo)
  workbook.add_chart_with_options("Sheet1", "C3", opts)
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let chart_part = match archive.get("xl/charts/chart1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing chart")
  }
  inspect(chart_part.contains("<c:stockChart>"), content="true")
  inspect(chart_part.contains("<c:lineChart>"), content="true")
  inspect(chart_part.contains("<c:dateAx>"), content="true")
  inspect(chart_part.contains("<c:hiLowLines/>"), content="true")
  inspect(chart_part.contains("<c:upDownBars>"), content="true")
  inspect(chart_part.contains("<c:gapWidth val=\"150\"/>"), content="true")
  inspect(chart_part.contains("val=\"00FF00\""), content="true")
  inspect(chart_part.contains("val=\"FF0000\""), content="true")
  inspect(chart_part.contains("Sheet1!$F$2:$F$4"), content="true")
  let stock_ser_idx = find_chart_index_or_fail(chart_part, "<c:stockChart>")
  let ser_idx = find_chart_index_or_fail(chart_part, "<c:ser>")
  let hi_low_idx = find_chart_index_or_fail(chart_part, "<c:hiLowLines/>")
  inspect(stock_ser_idx < ser_idx, content="true")
  inspect(ser_idx < hi_low_idx, content="true")
}

///|
test "chart options legend none omits legend" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let opts = ChartOptions::new(Col)
  opts.series.push(
    ChartSeries::new("Sheet1!$A$2:$A$4", "Sheet1!$B$2:$B$4", name="Series1"),
  )
  opts.legend.position = "none"
  workbook.add_chart_with_options("Sheet1", "C3", opts)
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let chart_part = match archive.get("xl/charts/chart1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing chart")
  }
  inspect(chart_part.contains("<c:legend>"), content="false")
}

///|
test "chart options legend font emits txPr" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let opts = ChartOptions::new(Col)
  opts.series.push(
    ChartSeries::new("Sheet1!$A$2:$A$4", "Sheet1!$B$2:$B$4", name="Series1"),
  )
  opts.legend.position = "right"
  opts.legend.font = Some(
    Font::with_values(
      bold=true,
      underline="sng",
      size=9.0,
      color="#123456",
      family="Arial",
    ),
  )
  workbook.add_chart_with_options("Sheet1", "C3", opts)
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let chart_part = match archive.get("xl/charts/chart1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing chart")
  }
  inspect(chart_part.contains("<c:legend>"), content="true")
  inspect(chart_part.contains("<c:legendPos val=\"r\"/>"), content="true")
  inspect(chart_part.contains("<c:txPr>"), content="true")
  inspect(chart_part.contains("b=\"1\""), content="true")
  inspect(chart_part.contains("u=\"sng\""), content="true")
  inspect(chart_part.contains("sz=\"900\""), content="true")
  inspect(chart_part.contains("<a:latin typeface=\"Arial\""), content="true")
  inspect(chart_part.contains("<a:srgbClr val=\"123456\""), content="true")
}

///|
test "chart options default legend maps to OOXML short value" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let opts = ChartOptions::new(Col)
  opts.series.push(
    ChartSeries::new("Sheet1!$A$2:$A$4", "Sheet1!$B$2:$B$4", name="Series1"),
  )
  workbook.add_chart_with_options("Sheet1", "C3", opts)
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let chart_part = match archive.get("xl/charts/chart1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing chart")
  }
  inspect(chart_part.contains("<c:legendPos val=\"b\"/>"), content="true")
}

///|
test "chart options plotArea fill + dTable" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let opts = ChartOptions::new(Col)
  opts.series.push(
    ChartSeries::new("Sheet1!$A$2:$A$4", "Sheet1!$B$2:$B$4", name="Series1"),
  )
  opts.plot_area.fill_color = "#112233"
  opts.plot_area.fill_transparency = 25
  opts.plot_area.show_data_table = true
  opts.plot_area.show_data_table_keys = true
  workbook.add_chart_with_options("Sheet1", "C3", opts)
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let chart_part = match archive.get("xl/charts/chart1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing chart")
  }
  inspect(chart_part.contains("<c:plotArea>"), content="true")
  inspect(chart_part.contains("<c:spPr>"), content="true")
  inspect(chart_part.contains("<a:srgbClr val=\"112233\""), content="true")
  inspect(chart_part.contains("alpha val=\"75000\""), content="true")
  inspect(chart_part.contains("<c:dTable>"), content="true")
  inspect(chart_part.contains("showKeys val=\"1\""), content="true")
}

///|
test "chart options series data label font + fill emits txPr/spPr" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let opts = ChartOptions::new(Col)
  let series = ChartSeries::new(
    "Sheet1!$A$2:$A$4",
    "Sheet1!$B$2:$B$4",
    name="Series1",
  )
  series.data_label.font = Font::with_values(
    bold=true,
    underline="sng",
    size=10.0,
    color="#00AA00",
    family="Arial",
  )
  series.data_label.fill_color = "#112233"
  series.data_label.fill_transparency = 60
  opts.series.push(series)
  workbook.add_chart_with_options("Sheet1", "C3", opts)
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let chart_part = match archive.get("xl/charts/chart1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing chart")
  }
  inspect(chart_part.contains("<c:dLbls>"), content="true")
  inspect(chart_part.contains("<c:txPr>"), content="true")
  inspect(chart_part.contains("b=\"1\""), content="true")
  inspect(chart_part.contains("u=\"sng\""), content="true")
  inspect(chart_part.contains("<a:srgbClr val=\"00AA00\""), content="true")
  inspect(chart_part.contains("<a:srgbClr val=\"112233\""), content="true")
  inspect(chart_part.contains("alpha val=\"40000\""), content="true")
}

///|
test "chart options chart root fill + border emits spPr" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let opts = ChartOptions::new(Col)
  opts.series.push(
    ChartSeries::new("Sheet1!$A$2:$A$4", "Sheet1!$B$2:$B$4", name="Series1"),
  )
  opts.fill_color = "#112233"
  opts.fill_transparency = 25
  opts.border.color = "#445566"
  opts.border.width = 1.5
  opts.border.dash = Dot
  opts.border.transparency = 60
  workbook.add_chart_with_options("Sheet1", "C3", opts)
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let chart_part = match archive.get("xl/charts/chart1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing chart")
  }
  inspect(chart_part.contains("<c:chart>"), content="true")
  inspect(chart_part.contains("<c:spPr>"), content="true")
  inspect(chart_part.contains("<a:srgbClr val=\"112233\""), content="true")
  inspect(chart_part.contains("alpha val=\"75000\""), content="true")
  inspect(chart_part.contains("<a:srgbClr val=\"445566\""), content="true")
  inspect(chart_part.contains("alpha val=\"40000\""), content="true")
  inspect(chart_part.contains("w=\"19050\""), content="true")
  inspect(chart_part.contains("prstDash val=\"dot\""), content="true")
}

///|
test "chart options stacked + axis + blanks + gap/overlap" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let opts = ChartOptions::new(ColStacked)
  opts.series.push(
    ChartSeries::new("Sheet1!$A$2:$A$4", "Sheet1!$B$2:$B$4", name="Series1"),
  )
  opts.gap_width = Some(200)
  opts.overlap = Some(-20)
  opts.show_blanks_as = "zero"
  opts.x_axis.title = "X Axis"
  opts.x_axis.major_grid_lines = true
  opts.y_axis.title = "Y Axis"
  opts.y_axis.minor_grid_lines = true
  opts.y_axis.tick_label_position = High
  opts.y_axis.num_fmt = ChartNumFmt::new(
    custom_num_fmt="0.00",
    source_linked=false,
  )
  workbook.add_chart_with_options("Sheet1", "C3", opts)
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let chart_part = match archive.get("xl/charts/chart1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing chart")
  }
  inspect(chart_part.contains("<c:barChart>"), content="true")
  inspect(chart_part.contains("<c:grouping val=\"stacked\"/>"), content="true")
  inspect(chart_part.contains("<c:gapWidth val=\"200\"/>"), content="true")
  inspect(chart_part.contains("<c:overlap val=\"-20\"/>"), content="true")
  inspect(chart_part.contains("<c:dispBlanksAs val=\"zero\"/>"), content="true")
  let bar_dir_idx = find_chart_index_or_fail(chart_part, "<c:barDir")
  let grouping_idx = find_chart_index_or_fail(chart_part, "<c:grouping")
  let vary_colors_idx = find_chart_index_or_fail(chart_part, "<c:varyColors")
  let ser_idx = find_chart_index_or_fail(chart_part, "<c:ser>")
  let gap_idx = find_chart_index_or_fail(chart_part, "<c:gapWidth")
  let plot_vis_only_idx = find_chart_index_or_fail(chart_part, "<c:plotVisOnly")
  let disp_blanks_idx = find_chart_index_or_fail(chart_part, "<c:dispBlanksAs")
  inspect(bar_dir_idx < grouping_idx, content="true")
  inspect(grouping_idx < vary_colors_idx, content="true")
  inspect(vary_colors_idx < ser_idx, content="true")
  inspect(ser_idx < gap_idx, content="true")
  inspect(plot_vis_only_idx < disp_blanks_idx, content="true")
  inspect(chart_part.contains("<c:majorGridlines/>"), content="true")
  inspect(chart_part.contains("<c:minorGridlines/>"), content="true")
  inspect(chart_part.contains("<a:t>X Axis</a:t>"), content="true")
  inspect(chart_part.contains("<a:t>Y Axis</a:t>"), content="true")
  inspect(chart_part.contains("tickLblPos val=\"high\""), content="true")
  inspect(
    chart_part.contains("formatCode=\"0.00\" sourceLinked=\"0\""),
    content="true",
  )
}

///|
test "chart options rich title + axis title runs" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let font : RichTextFont = {
    bold: true,
    italic: false,
    strike: false,
    outline: false,
    shadow: false,
    condense: false,
    extend: false,
    underline: Some("single"),
    size: Some(12.0),
    color: Some("#FF0000"),
    color_theme: None,
    color_indexed: None,
    color_tint: None,
    charset: None,
    family_number: None,
    scheme: None,
    vert_align: None,
    family: Some("Calibri"),
  }
  let opts = ChartOptions::new(Col)
  opts.series.push(
    ChartSeries::new("Sheet1!$A$2:$A$4", "Sheet1!$B$2:$B$4", name="Series1"),
  )
  opts.title_rich = Some([
    { text: "Hello ", font: None },
    { text: "World", font: Some(font) },
  ])
  opts.x_axis.title_rich = Some([
    { text: "X ", font: None },
    { text: "Axis", font: Some(font) },
  ])
  workbook.add_chart_with_options("Sheet1", "C3", opts)
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let chart_part = match archive.get("xl/charts/chart1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing chart")
  }
  inspect(chart_part.contains("xml:space=\"preserve\">Hello"), content="true")
  inspect(chart_part.contains("<a:t>World</a:t>"), content="true")
  inspect(chart_part.contains("b=\"1\""), content="true")
  inspect(chart_part.contains("u=\"single\""), content="true")
  inspect(chart_part.contains("<a:latin typeface=\"Calibri\""), content="true")
  inspect(chart_part.contains("<a:srgbClr val=\"FF0000\""), content="true")
  inspect(chart_part.contains("xml:space=\"preserve\">X "), content="true")
  inspect(chart_part.contains("<a:t>Axis</a:t>"), content="true")
}

///|
test "chart options axis txPr font + alignment" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let opts = ChartOptions::new(Col)
  opts.series.push(
    ChartSeries::new("Sheet1!$A$2:$A$4", "Sheet1!$B$2:$B$4", name="Series1"),
  )
  opts.x_axis.font = Font::with_values(
    bold=true,
    underline="sng",
    size=10.0,
    color="#00AA00",
    family="Arial",
  )
  opts.x_axis.alignment = Alignment::with_values(
    text_rotation=45,
    vertical="vert270",
  )
  workbook.add_chart_with_options("Sheet1", "C3", opts)
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let chart_part = match archive.get("xl/charts/chart1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing chart")
  }
  inspect(chart_part.contains("<c:txPr>"), content="true")
  inspect(chart_part.contains("rot=\"2700000\""), content="true")
  inspect(chart_part.contains("vert=\"vert270\""), content="true")
  inspect(chart_part.contains("b=\"1\""), content="true")
  inspect(chart_part.contains("u=\"sng\""), content="true")
  inspect(chart_part.contains("sz=\"1000\""), content="true")
  inspect(chart_part.contains("<a:latin typeface=\"Arial\""), content="true")
  inspect(chart_part.contains("<a:srgbClr val=\"00AA00\""), content="true")
}

///|
test "chart options pie has no axes" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let opts = ChartOptions::new(Pie)
  opts.series.push(
    ChartSeries::new("Sheet1!$A$2:$A$4", "Sheet1!$B$2:$B$4", name="Series1"),
  )
  workbook.add_chart_with_options("Sheet1", "C3", opts)
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let chart_part = match archive.get("xl/charts/chart1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing chart")
  }
  inspect(chart_part.contains("<c:pieChart>"), content="true")
  inspect(chart_part.contains("<c:catAx>"), content="false")
  inspect(chart_part.contains("<c:valAx>"), content="false")
}

///|
test "chart options pie3D has no axes" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let opts = ChartOptions::new(Pie3D)
  opts.series.push(
    ChartSeries::new("Sheet1!$A$2:$A$4", "Sheet1!$B$2:$B$4", name="Series1"),
  )
  workbook.add_chart_with_options("Sheet1", "C3", opts)
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let chart_part = match archive.get("xl/charts/chart1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing chart")
  }
  inspect(chart_part.contains("<c:pie3DChart>"), content="true")
  inspect(chart_part.contains("<c:catAx>"), content="false")
  inspect(chart_part.contains("<c:valAx>"), content="false")
}

///|
test "chart options doughnut holeSize" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let opts = ChartOptions::new(Doughnut)
  opts.hole_size = Some(60)
  opts.series.push(
    ChartSeries::new("Sheet1!$A$2:$A$4", "Sheet1!$B$2:$B$4", name="Series1"),
  )
  workbook.add_chart_with_options("Sheet1", "C3", opts)
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let chart_part = match archive.get("xl/charts/chart1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing chart")
  }
  inspect(chart_part.contains("<c:doughnutChart>"), content="true")
  inspect(chart_part.contains("holeSize val=\"60\""), content="true")
  inspect(chart_part.contains("<c:catAx>"), content="false")
}

///|
test "chart options ofPie splitPos" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let opts = ChartOptions::new(PieOfPie)
  opts.plot_area.second_plot_values = 5
  opts.series.push(
    ChartSeries::new("Sheet1!$A$2:$A$4", "Sheet1!$B$2:$B$4", name="Series1"),
  )
  workbook.add_chart_with_options("Sheet1", "C3", opts)
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let chart_part = match archive.get("xl/charts/chart1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing chart")
  }
  inspect(chart_part.contains("<c:ofPieChart>"), content="true")
  inspect(chart_part.contains("splitPos val=\"5\""), content="true")
}

///|
test "chart options plotArea dLbls flags" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let opts = ChartOptions::new(Pie)
  opts.plot_area.show_cat_name = true
  opts.plot_area.show_ser_name = true
  opts.plot_area.show_percent = true
  opts.plot_area.show_leader_lines = true
  opts.plot_area.show_val = true
  opts.plot_area.show_bubble_size = true
  opts.series.push(
    ChartSeries::new("Sheet1!$A$2:$A$4", "Sheet1!$B$2:$B$4", name="Series1"),
  )
  workbook.add_chart_with_options("Sheet1", "C3", opts)
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let chart_part = match archive.get("xl/charts/chart1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing chart")
  }
  inspect(chart_part.contains("showCatName val=\"1\""), content="true")
  inspect(chart_part.contains("showSerName val=\"1\""), content="true")
  inspect(chart_part.contains("showPercent val=\"1\""), content="true")
  inspect(chart_part.contains("showLeaderLines val=\"1\""), content="true")
  inspect(chart_part.contains("showBubbleSize val=\"1\""), content="true")
  inspect(chart_part.contains("showVal val=\"1\""), content="true")
}

///|
test "chart options pieOfPie has no axes" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let opts = ChartOptions::new(PieOfPie)
  opts.series.push(
    ChartSeries::new("Sheet1!$A$2:$A$4", "Sheet1!$B$2:$B$4", name="Series1"),
  )
  workbook.add_chart_with_options("Sheet1", "C3", opts)
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let chart_part = match archive.get("xl/charts/chart1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing chart")
  }
  inspect(chart_part.contains("<c:ofPieChart>"), content="true")
  inspect(chart_part.contains("ofPieType val=\"pie\""), content="true")
  inspect(chart_part.contains("<c:catAx>"), content="false")
  inspect(chart_part.contains("<c:valAx>"), content="false")
}

///|
test "chart options barOfPie emits ofPieType bar" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let opts = ChartOptions::new(BarOfPie)
  opts.series.push(
    ChartSeries::new("Sheet1!$A$2:$A$4", "Sheet1!$B$2:$B$4", name="Series1"),
  )
  workbook.add_chart_with_options("Sheet1", "C3", opts)
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let chart_part = match archive.get("xl/charts/chart1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing chart")
  }
  inspect(chart_part.contains("<c:ofPieChart>"), content="true")
  inspect(chart_part.contains("ofPieType val=\"bar\""), content="true")
}

///|
test "chart options line3D emits line3DChart" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let opts = ChartOptions::new(Line3D)
  opts.series.push(
    ChartSeries::new("Sheet1!$A$2:$A$4", "Sheet1!$B$2:$B$4", name="Series1"),
  )
  workbook.add_chart_with_options("Sheet1", "C3", opts)
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let chart_part = match archive.get("xl/charts/chart1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing chart")
  }
  inspect(chart_part.contains("<c:line3DChart>"), content="true")
  inspect(chart_part.contains("<c:catAx>"), content="true")
  inspect(chart_part.contains("<c:valAx>"), content="true")
}

///|
test "chart options series styling emits spPr/marker/dLbls/dPt" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let opts = ChartOptions::new(Line)
  opts.plot_area.show_val = true
  opts.plot_area.num_fmt = ChartNumFmt::new(
    custom_num_fmt="0.00",
    source_linked=false,
  )
  opts.legend.show_legend_key = true
  let series = ChartSeries::new(
    "Sheet1!$A$2:$A$4",
    "Sheet1!$B$2:$B$4",
    name="Series1",
  )
  series.line.color = "#FF0000"
  series.line.transparency = 50
  series.line.width = 2.5
  series.line.dash = Dash
  series.line.smooth = true
  series.marker.symbol = "circle"
  series.marker.size = 7
  series.marker.fill_color = "#112233"
  series.marker.fill_transparency = 60
  series.marker.border.color = "#445566"
  series.marker.border.width = 1.5
  series.marker.border.dash = Dot
  series.marker.border.transparency = 25
  series.data_label_position = Top
  series.data_point.push(ChartDataPoint::new(0, fill_color="00FF00"))
  opts.series.push(series)
  workbook.add_chart_with_options("Sheet1", "C3", opts)
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let chart_part = match archive.get("xl/charts/chart1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing chart")
  }
  inspect(chart_part.contains("<c:dLbls>"), content="true")
  inspect(chart_part.contains("showLegendKey val=\"1\""), content="true")
  inspect(chart_part.contains("showVal val=\"1\""), content="true")
  inspect(
    chart_part.contains("formatCode=\"0.00\" sourceLinked=\"0\""),
    content="true",
  )
  inspect(chart_part.contains("<c:marker>"), content="true")
  inspect(chart_part.contains("symbol val=\"circle\""), content="true")
  inspect(chart_part.contains("size val=\"7\""), content="true")
  inspect(chart_part.contains("<c:smooth val=\"1\"/>"), content="true")
  inspect(chart_part.contains("srgbClr val=\"FF0000\""), content="true")
  inspect(chart_part.contains("alpha val=\"50000\""), content="true")
  inspect(chart_part.contains("w=\"31750\""), content="true")
  inspect(chart_part.contains("prstDash val=\"dash\""), content="true")
  inspect(chart_part.contains("srgbClr val=\"112233\""), content="true")
  inspect(chart_part.contains("alpha val=\"40000\""), content="true")
  inspect(chart_part.contains("srgbClr val=\"445566\""), content="true")
  inspect(chart_part.contains("alpha val=\"75000\""), content="true")
  inspect(chart_part.contains("w=\"19050\""), content="true")
  inspect(chart_part.contains("prstDash val=\"dot\""), content="true")
  inspect(chart_part.contains("<c:dPt>"), content="true")
  inspect(chart_part.contains("srgbClr val=\"00FF00\""), content="true")
  inspect(chart_part.contains("dLblPos val=\"t\""), content="true")
}

///|
test "chart options col3D cone emits shape" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let opts = ChartOptions::new(Col3DConeClustered)
  opts.series.push(
    ChartSeries::new("Sheet1!$A$2:$A$4", "Sheet1!$B$2:$B$4", name="Series1"),
  )
  workbook.add_chart_with_options("Sheet1", "C3", opts)
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let chart_part = match archive.get("xl/charts/chart1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing chart")
  }
  inspect(chart_part.contains("<c:bar3DChart>"), content="true")
  inspect(chart_part.contains("barDir val=\"col\""), content="true")
  inspect(chart_part.contains("shape val=\"cone\""), content="true")
}

///|
test "chart options surface3D wireframe emits serAx" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let opts = ChartOptions::new(WireframeSurface3D)
  opts.series.push(
    ChartSeries::new("Sheet1!$A$2:$A$4", "Sheet1!$B$2:$B$4", name="Series1"),
  )
  workbook.add_chart_with_options("Sheet1", "C3", opts)
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let chart_part = match archive.get("xl/charts/chart1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing chart")
  }
  inspect(chart_part.contains("<c:surface3DChart>"), content="true")
  inspect(chart_part.contains("wireframe val=\"1\""), content="true")
  inspect(chart_part.contains("<c:serAx>"), content="true")
}

///|
test "chart options scatter uses xVal/yVal" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let opts = ChartOptions::new(Scatter)
  opts.series.push(
    ChartSeries::new("Sheet1!$A$2:$A$4", "Sheet1!$B$2:$B$4", name="Series1"),
  )
  workbook.add_chart_with_options("Sheet1", "C3", opts)
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let chart_part = match archive.get("xl/charts/chart1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing chart")
  }
  inspect(chart_part.contains("<c:scatterChart>"), content="true")
  inspect(
    chart_part.contains("scatterStyle val=\"lineMarker\""),
    content="true",
  )
  let scatter_style_idx = find_chart_index_or_fail(
    chart_part, "<c:scatterStyle",
  )
  let vary_colors_idx = find_chart_index_or_fail(chart_part, "<c:varyColors")
  let ser_idx = find_chart_index_or_fail(chart_part, "<c:ser>")
  inspect(scatter_style_idx < vary_colors_idx, content="true")
  inspect(vary_colors_idx < ser_idx, content="true")
  inspect(chart_part.contains("<c:xVal>"), content="true")
  inspect(chart_part.contains("<c:yVal>"), content="true")
  inspect(chart_part.contains("<c:valAx>"), content="true")
}

///|
test "chart options radar emits radarStyle" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let opts = ChartOptions::new(Radar)
  opts.series.push(
    ChartSeries::new("Sheet1!$A$2:$A$4", "Sheet1!$B$2:$B$4", name="Series1"),
  )
  workbook.add_chart_with_options("Sheet1", "C3", opts)
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let chart_part = match archive.get("xl/charts/chart1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing chart")
  }
  inspect(chart_part.contains("<c:radarChart>"), content="true")
  inspect(chart_part.contains("radarStyle val=\"standard\""), content="true")
}

///|
test "chart options bubble3D uses bubbleSize" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let opts = ChartOptions::new(Bubble3D)
  opts.bubble_scale = Some(200)
  let series = ChartSeries::new(
    "Sheet1!$A$2:$A$4",
    "Sheet1!$B$2:$B$4",
    name="Series1",
  )
  series.set_bubble_size("Sheet1!$C$2:$C$4")
  opts.series.push(series)
  workbook.add_chart_with_options("Sheet1", "C3", opts)
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let chart_part = match archive.get("xl/charts/chart1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing chart")
  }
  inspect(chart_part.contains("<c:bubbleChart>"), content="true")
  inspect(chart_part.contains("bubble3D val=\"1\""), content="true")
  inspect(chart_part.contains("bubbleScale val=\"200\""), content="true")
  inspect(chart_part.contains("<c:bubbleSize>"), content="true")
  inspect(chart_part.contains("Sheet1!$C$2:$C$4"), content="true")
}

///|
test "chart options bubble uses sizes alias" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let opts = ChartOptions::new(Bubble)
  let series = ChartSeries::new(
    "Sheet1!$A$2:$A$4",
    "Sheet1!$B$2:$B$4",
    name="Series1",
  )
  series.sizes = "Sheet1!$C$2:$C$4"
  opts.series.push(series)
  workbook.add_chart_with_options("Sheet1", "C3", opts)
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let chart_part = match archive.get("xl/charts/chart1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing chart")
  }
  inspect(chart_part.contains("<c:bubbleSize>"), content="true")
  inspect(chart_part.contains("Sheet1!$C$2:$C$4"), content="true")
}

///|
test "chart options bubble missing size errors" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let opts = ChartOptions::new(Bubble)
  opts.series.push(
    ChartSeries::new("Sheet1!$A$2:$A$4", "Sheet1!$B$2:$B$4", name="Series1"),
  )
  let result : Result[Unit, Error] = try? workbook.add_chart_with_options(
    "Sheet1", "C3", opts,
  )
  guard result is Err(XlsxError::InvalidSheetOperation(msg~)) else {
    fail("expected bubble size error")
  }
  inspect(msg, content="bubble size missing")
}

///|
test "chart options stock high-low-close" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let opts = ChartOptions::new(StockHighLowClose)
  opts.series.push(
    ChartSeries::new("Sheet1!$A$2:$A$4", "Sheet1!$B$2:$B$4", name="High"),
  )
  opts.series.push(
    ChartSeries::new("Sheet1!$A$2:$A$4", "Sheet1!$C$2:$C$4", name="Low"),
  )
  opts.series.push(
    ChartSeries::new("Sheet1!$A$2:$A$4", "Sheet1!$D$2:$D$4", name="Close"),
  )
  workbook.add_chart_with_options("Sheet1", "C3", opts)
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let chart_part = match archive.get("xl/charts/chart1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing chart")
  }
  inspect(chart_part.contains("<c:stockChart>"), content="true")
  inspect(chart_part.contains("<c:hiLowLines/>"), content="true")
  inspect(chart_part.contains("<c:dateAx>"), content="true")
  inspect(chart_part.contains("Sheet1!$D$2:$D$4"), content="true")
}

///|
test "chart options stock open-high-low-close uses upDownBars" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let opts = ChartOptions::new(StockOpenHighLowClose)
  opts.plot_area.up_bars.fill_color = "00FF00"
  opts.plot_area.down_bars.fill_color = "FF0000"
  opts.series.push(
    ChartSeries::new("Sheet1!$A$2:$A$4", "Sheet1!$B$2:$B$4", name="Open"),
  )
  opts.series.push(
    ChartSeries::new("Sheet1!$A$2:$A$4", "Sheet1!$C$2:$C$4", name="High"),
  )
  opts.series.push(
    ChartSeries::new("Sheet1!$A$2:$A$4", "Sheet1!$D$2:$D$4", name="Low"),
  )
  opts.series.push(
    ChartSeries::new("Sheet1!$A$2:$A$4", "Sheet1!$E$2:$E$4", name="Close"),
  )
  workbook.add_chart_with_options("Sheet1", "C3", opts)
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let chart_part = match archive.get("xl/charts/chart1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing chart")
  }
  inspect(chart_part.contains("<c:stockChart>"), content="true")
  inspect(chart_part.contains("<c:upDownBars>"), content="true")
  inspect(chart_part.contains("<c:gapWidth val=\"150\"/>"), content="true")
  inspect(chart_part.contains("val=\"00FF00\""), content="true")
  inspect(chart_part.contains("val=\"FF0000\""), content="true")
}

///|
test "chart options stock invalid series count" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let opts = ChartOptions::new(StockHighLowClose)
  opts.series.push(
    ChartSeries::new("Sheet1!$A$2:$A$4", "Sheet1!$B$2:$B$4", name="High"),
  )
  let result : Result[Unit, Error] = try? workbook.add_chart_with_options(
    "Sheet1", "C3", opts,
  )
  guard result is Err(XlsxError::InvalidSheetOperation(msg~)) else {
    fail("expected stock series count error")
  }
  inspect(msg.contains("stock chart requires"), content="true")
}

///|
test "chart data label alignment emits txPr paragraph align" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let opts = ChartOptions::new(Col)
  let series = ChartSeries::new(
    "Sheet1!$A$2:$A$4",
    "Sheet1!$B$2:$B$4",
    name="Series1",
  )
  let align = Alignment::with_values(horizontal="center", text_rotation=45)
  series.data_label.alignment = align
  opts.series.push(series)
  workbook.add_chart_with_options("Sheet1", "C3", opts)
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let chart_part = match archive.get("xl/charts/chart1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing chart")
  }
  inspect(chart_part.contains("<c:dLbls>"), content="true")
  inspect(chart_part.contains("algn=\"ctr\""), content="true")
  inspect(chart_part.contains("rot=\"2700000\""), content="true")
}

///|
test "chart axis none emits delete without dropping axis" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let opts = ChartOptions::new(Col)
  opts.series.push(
    ChartSeries::new("Sheet1!$A$2:$A$4", "Sheet1!$B$2:$B$4", name="Series1"),
  )
  opts.x_axis.none = true
  workbook.add_chart_with_options("Sheet1", "C3", opts)
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let chart_part = match archive.get("xl/charts/chart1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing chart")
  }
  inspect(chart_part.contains("<c:catAx>"), content="true")
  inspect(chart_part.contains("<c:valAx>"), content="true")
  inspect(chart_part.contains("<c:delete val=\"1\"/>"), content="true")
  inspect(chart_part.contains("<c:delete val=\"0\"/>"), content="true")
}

///|
test "chart axis reverse order emits flipped positions and crossing tags" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let opts = ChartOptions::new(Col)
  opts.series.push(
    ChartSeries::new("Sheet1!$A$2:$A$4", "Sheet1!$B$2:$B$4", name="Series1"),
  )
  opts.x_axis.reverse_order = true
  opts.y_axis.reverse_order = true
  workbook.add_chart_with_options("Sheet1", "C3", opts)
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let chart_part = match archive.get("xl/charts/chart1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing chart")
  }
  inspect(chart_part.contains("<c:axPos val=\"t\"/>"), content="true")
  inspect(chart_part.contains("<c:axPos val=\"r\"/>"), content="true")
  inspect(chart_part.contains("<c:crosses val=\"autoZero\"/>"), content="true")
  inspect(
    chart_part.contains("<c:crossBetween val=\"between\"/>"),
    content="true",
  )
}

///|
test "chart options contour uses none tick labels and midCat crossBetween" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let opts = ChartOptions::new(Contour)
  opts.series.push(
    ChartSeries::new("Sheet1!$A$2:$A$4", "Sheet1!$B$2:$B$4", name="Series1"),
  )
  workbook.add_chart_with_options("Sheet1", "C3", opts)
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let chart_part = match archive.get("xl/charts/chart1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing chart")
  }
  inspect(chart_part.contains("<c:surfaceChart>"), content="true")
  inspect(chart_part.contains("<c:tickLblPos val=\"none\"/>"), content="true")
  inspect(
    chart_part.contains("<c:crossBetween val=\"midCat\"/>"),
    content="true",
  )
}
