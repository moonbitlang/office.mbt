// Modified for office.mbt: follow the workspace warning conventions.
// Bar-chart parser / writer tests.

///|
fn fixture_bar_chart_xml(body : String) -> FixedArray[Byte] {
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
test "BarChart: minimum (barDir + axIds) types correctly" {
  let body = "<c:barChart>" +
    "<c:barDir val=\"col\"/>" +
    "<c:axId val=\"1\"/>" +
    "<c:axId val=\"2\"/>" +
    "</c:barChart>"
  let chart = @chart.Chart::parse(fixture_bar_chart_xml(body))
  match chart.chart.plot_area.plots[0] {
    BarChart(b) => {
      debug_inspect(b.bar_dir, content="Col")
      debug_inspect(b.grouping is None, content="true")
      debug_inspect(b.ax_ids.length(), content="2")
      debug_inspect(b.ax_ids[0], content="1")
      debug_inspect(b.ax_ids[1], content="2")
      debug_inspect(b.series.length(), content="0")
    }
    _ => fail("expected BarChart plot")
  }
}

///|
test "BarChart: full scalar field set" {
  let body = "<c:barChart>" +
    "<c:barDir val=\"bar\"/>" +
    "<c:grouping val=\"stacked\"/>" +
    "<c:varyColors val=\"1\"/>" +
    "<c:gapWidth val=\"150\"/>" +
    "<c:overlap val=\"-25\"/>" +
    "<c:axId val=\"10\"/>" +
    "<c:axId val=\"20\"/>" +
    "</c:barChart>"
  let chart = @chart.Chart::parse(fixture_bar_chart_xml(body))
  match chart.chart.plot_area.plots[0] {
    BarChart(b) => {
      debug_inspect(b.bar_dir, content="Bar")
      debug_inspect(b.grouping is Some(Stacked), content="true")
      debug_inspect(b.vary_colors.unwrap(), content="true")
      debug_inspect(b.gap_width.unwrap(), content="150")
      debug_inspect(b.overlap.unwrap(), content="-25")
      debug_inspect(b.ax_ids[0], content="10")
      debug_inspect(b.ax_ids[1], content="20")
    }
    _ => fail("expected BarChart plot")
  }
}

///|
test "BarChart: missing <c:barDir> raises Malformed" {
  let body = "<c:barChart>" +
    "<c:axId val=\"1\"/>" +
    "<c:axId val=\"2\"/>" +
    "</c:barChart>"
  let bytes = fixture_bar_chart_xml(body)
  try @chart.Chart::parse(bytes) catch {
    _ => ()
  } noraise {
    _ => fail("expected Malformed for barChart without barDir")
  }
}

///|
test "BarChart: <c:ser> children captured verbatim until typed" {
  // A single series with a few inner children. CT_BarSer is not yet
  // typed; this test verifies the captured payload survives.
  let body = "<c:barChart>" +
    "<c:barDir val=\"col\"/>" +
    "<c:ser>" +
    "<c:idx val=\"0\"/>" +
    "<c:order val=\"0\"/>" +
    "<c:tx><c:strRef><c:f>S1!$B$1</c:f></c:strRef></c:tx>" +
    "</c:ser>" +
    "<c:ser>" +
    "<c:idx val=\"1\"/>" +
    "<c:order val=\"1\"/>" +
    "</c:ser>" +
    "<c:axId val=\"1\"/>" +
    "<c:axId val=\"2\"/>" +
    "</c:barChart>"
  let chart = @chart.Chart::parse(fixture_bar_chart_xml(body))
  match chart.chart.plot_area.plots[0] {
    BarChart(b) => debug_inspect(b.series.length(), content="2")
    _ => fail("expected BarChart plot")
  }
}

///|
test "BarChart: parse → serialize → parse round-trip" {
  let body = "<c:barChart>" +
    "<c:barDir val=\"col\"/>" +
    "<c:grouping val=\"clustered\"/>" +
    "<c:varyColors val=\"0\"/>" +
    "<c:ser><c:idx val=\"0\"/></c:ser>" +
    "<c:gapWidth val=\"150\"/>" +
    "<c:overlap val=\"100\"/>" +
    "<c:axId val=\"1\"/>" +
    "<c:axId val=\"2\"/>" +
    "</c:barChart>"
  let original = @chart.Chart::parse(fixture_bar_chart_xml(body))
  let serialized = original.serialize()
  let re_parsed = @chart.Chart::parse(serialized)
  debug_inspect(re_parsed == original, content="true")
}

///|
test "BarDir / BarGrouping enum round-trips" {
  // Direct enum check — every `to_xml` value must round-trip through
  // `from_xml` to the same value.
  for d in [@chart.BarDir::Bar, Col] {
    debug_inspect(
      @chart.BarDir::from_xml(d.to_xml()) is Some(_),
      content="true",
    )
    debug_inspect(
      @chart.BarDir::from_xml(d.to_xml()).unwrap() == d,
      content="true",
    )
  }
  for g in [@chart.BarGrouping::PercentStacked, Clustered, Standard, Stacked] {
    debug_inspect(
      @chart.BarGrouping::from_xml(g.to_xml()) is Some(_),
      content="true",
    )
    debug_inspect(
      @chart.BarGrouping::from_xml(g.to_xml()).unwrap() == g,
      content="true",
    )
  }
}
