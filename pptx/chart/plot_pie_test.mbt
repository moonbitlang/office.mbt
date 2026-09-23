// Pie-chart parser / writer tests.

///|
fn fixture_pie_chart_xml(body : String) -> FixedArray[Byte] {
  // Pie charts have no axes, so the plotArea need not carry catAx /
  // valAx. PowerPoint nevertheless tolerates them; we omit to keep
  // the fixture minimal.
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
test "PieChart: empty body parses successfully (no required children)" {
  let body = "<c:pieChart/>"
  let chart = @chart.Chart::parse(fixture_pie_chart_xml(body))
  match chart.chart.plot_area.plots[0] {
    PieChart(b) => {
      debug_inspect(b.vary_colors is None, content="true")
      debug_inspect(b.series.length(), content="0")
      debug_inspect(b.first_slice_ang is None, content="true")
    }
    _ => fail("expected PieChart plot")
  }
}

///|
test "PieChart: full field set" {
  let body = "<c:pieChart>" +
    "<c:varyColors val=\"1\"/>" +
    "<c:ser><c:idx val=\"0\"/></c:ser>" +
    "<c:firstSliceAng val=\"90\"/>" +
    "</c:pieChart>"
  let chart = @chart.Chart::parse(fixture_pie_chart_xml(body))
  match chart.chart.plot_area.plots[0] {
    PieChart(b) => {
      debug_inspect(b.vary_colors.unwrap(), content="true")
      debug_inspect(b.series.length(), content="1")
      debug_inspect(b.first_slice_ang.unwrap(), content="90")
    }
    _ => fail("expected PieChart plot")
  }
}

///|
test "PieChart: parse → serialize → parse round-trip" {
  let body = "<c:pieChart>" +
    "<c:varyColors val=\"1\"/>" +
    "<c:ser><c:idx val=\"0\"/><c:order val=\"0\"/></c:ser>" +
    "<c:ser><c:idx val=\"1\"/><c:order val=\"1\"/></c:ser>" +
    "<c:firstSliceAng val=\"45\"/>" +
    "</c:pieChart>"
  let original = @chart.Chart::parse(fixture_pie_chart_xml(body))
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  debug_inspect(re_parsed == original, content="true")
}
