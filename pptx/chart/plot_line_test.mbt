// Modified for office.mbt: follow the workspace warning conventions.
// Line-chart parser / writer tests.

///|
fn fixture_line_chart_xml(body : String) -> FixedArray[Byte] {
  let xml = "<?xml version=\"1.0\"?>" +
    "<c:chartSpace xmlns:c=\"" +
    chart_ns +
    "\">" +
    "<c:chart>" +
    "<c:plotArea>" +
    body +
    "<c:catAx><c:axId val=\"1\"/></c:catAx>" +
    "<c:valAx><c:axId val=\"2\"/></c:valAx>" +
    "</c:plotArea>" +
    "</c:chart>" +
    "</c:chartSpace>"
  @oxml.string_to_bytes(xml)
}

///|
test "LineChart: minimum (grouping + axIds) types correctly" {
  let body = "<c:lineChart>" +
    "<c:grouping val=\"standard\"/>" +
    "<c:axId val=\"1\"/>" +
    "<c:axId val=\"2\"/>" +
    "</c:lineChart>"
  let chart = @chart.Chart::parse(fixture_line_chart_xml(body))
  match chart.chart.plot_area.plots[0] {
    LineChart(b) => {
      debug_inspect(b.grouping, content="Standard")
      debug_inspect(b.ax_ids.length(), content="2")
      debug_inspect(b.ax_ids[0], content="1")
      debug_inspect(b.ax_ids[1], content="2")
    }
    _ => fail("expected LineChart plot")
  }
}

///|
test "LineChart: marker + smooth round-trip" {
  let body = "<c:lineChart>" +
    "<c:grouping val=\"stacked\"/>" +
    "<c:varyColors val=\"1\"/>" +
    "<c:ser><c:idx val=\"0\"/></c:ser>" +
    "<c:marker val=\"1\"/>" +
    "<c:smooth val=\"0\"/>" +
    "<c:axId val=\"1\"/>" +
    "<c:axId val=\"2\"/>" +
    "</c:lineChart>"
  let chart = @chart.Chart::parse(fixture_line_chart_xml(body))
  match chart.chart.plot_area.plots[0] {
    LineChart(b) => {
      debug_inspect(b.grouping, content="Stacked")
      debug_inspect(b.vary_colors.unwrap(), content="true")
      debug_inspect(b.marker.unwrap(), content="true")
      debug_inspect(b.smooth.unwrap(), content="false")
      debug_inspect(b.series.length(), content="1")
    }
    _ => fail("expected LineChart plot")
  }
}

///|
test "LineChart: dropLines / hiLowLines / upDownBars round-trip via capture" {
  let body = "<c:lineChart>" +
    "<c:grouping val=\"standard\"/>" +
    "<c:dropLines/>" +
    "<c:hiLowLines/>" +
    "<c:upDownBars><c:gapWidth val=\"150\"/></c:upDownBars>" +
    "<c:axId val=\"1\"/>" +
    "<c:axId val=\"2\"/>" +
    "</c:lineChart>"
  let original = @chart.Chart::parse(fixture_line_chart_xml(body))
  match original.chart.plot_area.plots[0] {
    LineChart(b) => {
      debug_inspect(b.drop_lines is Some(_), content="true")
      debug_inspect(b.hi_low_lines is Some(_), content="true")
      debug_inspect(b.up_down_bars is Some(_), content="true")
    }
    _ => fail("expected LineChart plot")
  }
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  debug_inspect(re_parsed == original, content="true")
}

///|
test "LineChart: missing <c:grouping> raises Malformed" {
  let body = "<c:lineChart>" +
    "<c:axId val=\"1\"/>" +
    "<c:axId val=\"2\"/>" +
    "</c:lineChart>"
  let bytes = fixture_line_chart_xml(body)
  try @chart.Chart::parse(bytes) catch {
    _ => ()
  } noraise {
    _ => fail("expected Malformed for lineChart without grouping")
  }
}

///|
test "LineChart: combined with BarChart in one plotArea" {
  // Combination chart — a typed BarChart and a typed LineChart side
  // by side. Verifies the parser handles the heterogeneous plot list.
  let body = "<c:barChart>" +
    "<c:barDir val=\"col\"/>" +
    "<c:axId val=\"1\"/>" +
    "<c:axId val=\"2\"/>" +
    "</c:barChart>" +
    "<c:lineChart>" +
    "<c:grouping val=\"standard\"/>" +
    "<c:axId val=\"1\"/>" +
    "<c:axId val=\"2\"/>" +
    "</c:lineChart>"
  let chart = @chart.Chart::parse(fixture_line_chart_xml(body))
  debug_inspect(chart.chart.plot_area.plots.length(), content="2")
  debug_inspect(chart.chart.plot_area.plots[0] is BarChart(_), content="true")
  debug_inspect(chart.chart.plot_area.plots[1] is LineChart(_), content="true")
}

///|
test "Grouping enum round-trips" {
  for g in [@chart.Grouping::Standard, Stacked, PercentStacked] {
    debug_inspect(
      @chart.Grouping::from_xml(g.to_xml()) is Some(_),
      content="true",
    )
    debug_inspect(
      @chart.Grouping::from_xml(g.to_xml()).unwrap() == g,
      content="true",
    )
  }
}
