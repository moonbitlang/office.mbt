// Modified for office.mbt: follow the workspace warning conventions.
// Bubble-chart parser / writer tests.

///|
fn fixture_bubble_chart_xml(body : String) -> FixedArray[Byte] {
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
test "BubbleChart: full attribute set" {
  let body = "<c:bubbleChart>" +
    "<c:varyColors val=\"1\"/>" +
    "<c:ser><c:idx val=\"0\"/></c:ser>" +
    "<c:bubble3D val=\"1\"/>" +
    "<c:bubbleScale val=\"100\"/>" +
    "<c:showNegBubbles val=\"0\"/>" +
    "<c:sizeRepresents val=\"area\"/>" +
    "<c:axId val=\"1\"/>" +
    "<c:axId val=\"2\"/>" +
    "</c:bubbleChart>"
  let chart = @chart.Chart::parse(fixture_bubble_chart_xml(body))
  match chart.chart.plot_area.plots[0] {
    BubbleChart(b) => {
      debug_inspect(b.bubble_3d.unwrap(), content="true")
      debug_inspect(b.bubble_scale.unwrap(), content="100")
      debug_inspect(b.show_neg_bubbles.unwrap(), content="false")
      debug_inspect(b.size_represents is Some(Area), content="true")
      debug_inspect(b.ax_ids.length(), content="2")
    }
    _ => fail("expected BubbleChart plot")
  }
}

///|
test "BubbleChart: round-trip" {
  let body = "<c:bubbleChart>" +
    "<c:bubble3D val=\"0\"/>" +
    "<c:sizeRepresents val=\"w\"/>" +
    "<c:axId val=\"1\"/>" +
    "<c:axId val=\"2\"/>" +
    "</c:bubbleChart>"
  let original = @chart.Chart::parse(fixture_bubble_chart_xml(body))
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  debug_inspect(re_parsed == original, content="true")
}

///|
test "SizeRepresents enum round-trips" {
  for s in [@chart.SizeRepresents::Area, Width] {
    debug_inspect(
      @chart.SizeRepresents::from_xml(s.to_xml()).unwrap() == s,
      content="true",
    )
  }
}
