// ChartLegend typed parser / writer tests.

///|
fn fixture_legend_chart_xml(legend_body : String) -> FixedArray[Byte] {
  let xml = "<?xml version=\"1.0\"?>" +
    "<c:chartSpace xmlns:c=\"" +
    chart_ns +
    "\" xmlns:a=\"" +
    drawing_ns +
    "\">" +
    "<c:chart>" +
    "<c:plotArea/>" +
    legend_body +
    "</c:chart>" +
    "</c:chartSpace>"
  @oxml.string_to_bytes(xml)
}

///|
test "ChartLegend: empty legend parses to empty body" {
  let chart = @chart.Chart::parse(fixture_legend_chart_xml("<c:legend/>"))
  let lg = chart.chart.legend.unwrap()
  debug_inspect(lg.legend_pos is None, content="true")
  debug_inspect(lg.legend_entries.length(), content="0")
  debug_inspect(lg.overlay is None, content="true")
}

///|
test "ChartLegend: legendPos every variant" {
  let cases = ["b", "tr", "l", "r", "t"]
  for v in cases {
    let body = "<c:legend>" + "<c:legendPos val=\"" + v + "\"/>" + "</c:legend>"
    let original = @chart.Chart::parse(fixture_legend_chart_xml(body))
    let bytes = original.serialize()
    let re_parsed = @chart.Chart::parse(bytes)
    debug_inspect(re_parsed == original, content="true")
  }
}

///|
test "ChartLegend: typed values lift correctly" {
  let body = "<c:legend>" +
    "<c:legendPos val=\"r\"/>" +
    "<c:overlay val=\"0\"/>" +
    "</c:legend>"
  let chart = @chart.Chart::parse(fixture_legend_chart_xml(body))
  let lg = chart.chart.legend.unwrap()
  debug_inspect(lg.legend_pos is Some(LegendRight), content="true")
  debug_inspect(lg.overlay.unwrap(), content="false")
}

///|
test "ChartLegend: legendEntry collected with idx + delete" {
  let body = "<c:legend>" +
    "<c:legendPos val=\"b\"/>" +
    "<c:legendEntry>" +
    "<c:idx val=\"0\"/>" +
    "<c:delete val=\"1\"/>" +
    "</c:legendEntry>" +
    "<c:legendEntry>" +
    "<c:idx val=\"2\"/>" +
    "</c:legendEntry>" +
    "</c:legend>"
  let chart = @chart.Chart::parse(fixture_legend_chart_xml(body))
  let lg = chart.chart.legend.unwrap()
  debug_inspect(lg.legend_entries.length(), content="2")
  debug_inspect(lg.legend_entries[0].idx, content="0")
  debug_inspect(lg.legend_entries[0].delete.unwrap(), content="true")
  debug_inspect(lg.legend_entries[1].idx, content="2")
  debug_inspect(lg.legend_entries[1].delete is None, content="true")
}

///|
test "ChartLegend: legendEntry without idx raises Malformed" {
  let body = "<c:legend>" +
    "<c:legendEntry><c:delete val=\"1\"/></c:legendEntry>" +
    "</c:legend>"
  try @chart.Chart::parse(fixture_legend_chart_xml(body)) catch {
    _ => ()
  } noraise {
    _ => fail("expected Malformed for legendEntry without idx")
  }
}

///|
test "ChartLegend: layout / spPr / txPr captured" {
  let body = "<c:legend>" +
    "<c:legendPos val=\"r\"/>" +
    "<c:layout/>" +
    "<c:overlay val=\"0\"/>" +
    "<c:spPr/>" +
    "<c:txPr><a:bodyPr/></c:txPr>" +
    "</c:legend>"
  let original = @chart.Chart::parse(fixture_legend_chart_xml(body))
  let lg = original.chart.legend.unwrap()
  debug_inspect(lg.layout is Some(_), content="true")
  debug_inspect(lg.sp_pr is Some(_), content="true")
  debug_inspect(lg.tx_pr is Some(_), content="true")
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  debug_inspect(re_parsed == original, content="true")
}

///|
test "ChartLegend: legendEntry txPr captured + round-trips" {
  let body = "<c:legend>" +
    "<c:legendEntry>" +
    "<c:idx val=\"1\"/>" +
    "<c:txPr><a:bodyPr/></c:txPr>" +
    "</c:legendEntry>" +
    "</c:legend>"
  let original = @chart.Chart::parse(fixture_legend_chart_xml(body))
  let entry = original.chart.legend.unwrap().legend_entries[0]
  debug_inspect(entry.tx_pr is Some(_), content="true")
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  debug_inspect(re_parsed == original, content="true")
}

///|
test "ChartLegend: extLst rides on extension and round-trips" {
  let body = "<c:legend>" +
    "<c:legendPos val=\"b\"/>" +
    "<c:extLst><c:ext uri=\"{X}\"/></c:extLst>" +
    "</c:legend>"
  let original = @chart.Chart::parse(fixture_legend_chart_xml(body))
  let lg = original.chart.legend.unwrap()
  debug_inspect(lg.extension.length(), content="1")
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  debug_inspect(re_parsed == original, content="true")
}

///|
test "ChartLegend: out-of-source-order children re-emit canonically" {
  // Parser tolerates any order; writer emits schema order.
  let body = "<c:legend>" +
    "<c:overlay val=\"1\"/>" +
    "<c:txPr><a:bodyPr/></c:txPr>" +
    "<c:legendPos val=\"t\"/>" +
    "<c:legendEntry><c:idx val=\"0\"/></c:legendEntry>" +
    "<c:layout/>" +
    "<c:spPr/>" +
    "</c:legend>"
  let original = @chart.Chart::parse(fixture_legend_chart_xml(body))
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  debug_inspect(re_parsed == original, content="true")
}
