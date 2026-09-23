// Area-chart family parser / writer tests (2-D + 3-D).

///|
fn fixture_area_chart_xml(body : String) -> FixedArray[Byte] {
  let xml = "<?xml version=\"1.0\"?>" +
    "<c:chartSpace xmlns:c=\"" +
    chart_ns +
    "\">" +
    "<c:chart>" +
    "<c:plotArea>" +
    body +
    "</c:plotArea>" +
    "</c:chart>" +
    "</c:chartSpace>"
  @oxml.string_to_bytes(xml)
}

///|
test "AreaChart: grouping is optional" {
  let body = "<c:areaChart>" +
    "<c:grouping val=\"stacked\"/>" +
    "<c:ser><c:idx val=\"0\"/></c:ser>" +
    "<c:axId val=\"1\"/>" +
    "<c:axId val=\"2\"/>" +
    "</c:areaChart>"
  let chart = @chart.Chart::parse(fixture_area_chart_xml(body))
  match chart.chart.plot_area.plots[0] {
    AreaChart(b) => {
      debug_inspect(b.grouping is Some(Stacked), content="true")
      debug_inspect(b.series.length(), content="1")
      debug_inspect(b.ax_ids.length(), content="2")
    }
    _ => fail("expected AreaChart plot")
  }
}

///|
test "AreaChart: round-trip" {
  let body = "<c:areaChart>" +
    "<c:grouping val=\"standard\"/>" +
    "<c:axId val=\"1\"/>" +
    "<c:axId val=\"2\"/>" +
    "</c:areaChart>"
  let original = @chart.Chart::parse(fixture_area_chart_xml(body))
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  debug_inspect(re_parsed == original, content="true")
}

///|
test "Area3DChart: gapDepth lifts; three axIds for 3-D" {
  let body = "<c:area3DChart>" +
    "<c:grouping val=\"standard\"/>" +
    "<c:gapDepth val=\"150\"/>" +
    "<c:axId val=\"1\"/>" +
    "<c:axId val=\"2\"/>" +
    "<c:axId val=\"3\"/>" +
    "</c:area3DChart>"
  let chart = @chart.Chart::parse(fixture_area_chart_xml(body))
  match chart.chart.plot_area.plots[0] {
    Area3DChart(b) => {
      debug_inspect(b.gap_depth.unwrap(), content="150")
      debug_inspect(b.ax_ids.length(), content="3")
    }
    _ => fail("expected Area3DChart plot")
  }
}

///|
test "Area3DChart: round-trip" {
  let body = "<c:area3DChart>" +
    "<c:gapDepth val=\"150\"/>" +
    "<c:axId val=\"1\"/>" +
    "<c:axId val=\"2\"/>" +
    "<c:axId val=\"3\"/>" +
    "</c:area3DChart>"
  let original = @chart.Chart::parse(fixture_area_chart_xml(body))
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  debug_inspect(re_parsed == original, content="true")
}
