// 3-D variants of bar / line / pie — parser / writer tests.

///|
fn fixture_3d_chart_xml(body : String) -> FixedArray[Byte] {
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

// --- Bar3DChart ---

///|
test "Bar3DChart: shape enum + three axIds" {
  let body = "<c:bar3DChart>" +
    "<c:barDir val=\"col\"/>" +
    "<c:grouping val=\"clustered\"/>" +
    "<c:gapWidth val=\"150\"/>" +
    "<c:gapDepth val=\"100\"/>" +
    "<c:shape val=\"cylinder\"/>" +
    "<c:axId val=\"1\"/>" +
    "<c:axId val=\"2\"/>" +
    "<c:axId val=\"3\"/>" +
    "</c:bar3DChart>"
  let chart = @chart.Chart::parse(fixture_3d_chart_xml(body))
  match chart.chart.plot_area.plots[0] {
    Bar3DChart(b) => {
      debug_inspect(b.bar_dir, content="Col")
      debug_inspect(b.grouping is Some(Clustered), content="true")
      debug_inspect(b.gap_width.unwrap(), content="150")
      debug_inspect(b.gap_depth.unwrap(), content="100")
      debug_inspect(b.shape is Some(Cylinder), content="true")
      debug_inspect(b.ax_ids.length(), content="3")
    }
    _ => fail("expected Bar3DChart plot")
  }
}

///|
test "Bar3DChart: missing barDir raises Malformed" {
  let body = "<c:bar3DChart>" +
    "<c:axId val=\"1\"/>" +
    "<c:axId val=\"2\"/>" +
    "<c:axId val=\"3\"/>" +
    "</c:bar3DChart>"
  try @chart.Chart::parse(fixture_3d_chart_xml(body)) catch {
    _ => ()
  } noraise {
    _ => fail("expected Malformed")
  }
}

///|
test "Bar3DChart: round-trip" {
  let body = "<c:bar3DChart>" +
    "<c:barDir val=\"col\"/>" +
    "<c:grouping val=\"clustered\"/>" +
    "<c:axId val=\"1\"/>" +
    "<c:axId val=\"2\"/>" +
    "<c:axId val=\"3\"/>" +
    "</c:bar3DChart>"
  let original = @chart.Chart::parse(fixture_3d_chart_xml(body))
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  debug_inspect(re_parsed == original, content="true")
}

// --- Line3DChart ---

///|
test "Line3DChart: grouping is required" {
  let body = "<c:line3DChart>" +
    "<c:grouping val=\"standard\"/>" +
    "<c:gapDepth val=\"150\"/>" +
    "<c:axId val=\"1\"/>" +
    "<c:axId val=\"2\"/>" +
    "<c:axId val=\"3\"/>" +
    "</c:line3DChart>"
  let chart = @chart.Chart::parse(fixture_3d_chart_xml(body))
  match chart.chart.plot_area.plots[0] {
    Line3DChart(b) => {
      debug_inspect(b.grouping, content="Standard")
      debug_inspect(b.gap_depth.unwrap(), content="150")
      debug_inspect(b.ax_ids.length(), content="3")
    }
    _ => fail("expected Line3DChart plot")
  }
}

///|
test "Line3DChart: round-trip" {
  let body = "<c:line3DChart>" +
    "<c:grouping val=\"standard\"/>" +
    "<c:axId val=\"1\"/>" +
    "<c:axId val=\"2\"/>" +
    "<c:axId val=\"3\"/>" +
    "</c:line3DChart>"
  let original = @chart.Chart::parse(fixture_3d_chart_xml(body))
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  debug_inspect(re_parsed == original, content="true")
}

// --- Pie3DChart ---

///|
test "Pie3DChart: minimal body — no firstSliceAng (2-D pie only)" {
  let body = "<c:pie3DChart>" +
    "<c:varyColors val=\"1\"/>" +
    "<c:ser><c:idx val=\"0\"/></c:ser>" +
    "</c:pie3DChart>"
  let chart = @chart.Chart::parse(fixture_3d_chart_xml(body))
  match chart.chart.plot_area.plots[0] {
    Pie3DChart(b) => {
      debug_inspect(b.vary_colors.unwrap(), content="true")
      debug_inspect(b.series.length(), content="1")
    }
    _ => fail("expected Pie3DChart plot")
  }
}

///|
test "Pie3DChart: round-trip" {
  let body = "<c:pie3DChart>" +
    "<c:varyColors val=\"1\"/>" +
    "<c:ser><c:idx val=\"0\"/></c:ser>" +
    "</c:pie3DChart>"
  let original = @chart.Chart::parse(fixture_3d_chart_xml(body))
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  debug_inspect(re_parsed == original, content="true")
}
