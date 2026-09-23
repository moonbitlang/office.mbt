// Modified for office.mbt: follow the workspace warning conventions.
// Of-pie chart parser / writer tests.

///|
fn fixture_ofpie_chart_xml(body : String) -> FixedArray[Byte] {
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
test "OfPieChart: pie-of-pie variant" {
  let body = "<c:ofPieChart>" +
    "<c:ofPieType val=\"pie\"/>" +
    "<c:varyColors val=\"1\"/>" +
    "<c:ser><c:idx val=\"0\"/></c:ser>" +
    "<c:gapWidth val=\"150\"/>" +
    "<c:splitType val=\"percent\"/>" +
    "<c:splitPos val=\"10\"/>" +
    "<c:secondPieSize val=\"75\"/>" +
    "</c:ofPieChart>"
  let chart = @chart.Chart::parse(fixture_ofpie_chart_xml(body))
  match chart.chart.plot_area.plots[0] {
    OfPieChart(b) => {
      debug_inspect(b.of_pie_type, content="Pie")
      debug_inspect(b.split_type is Some(Percent), content="true")
      debug_inspect(b.split_pos.unwrap(), content="\"10\"")
      debug_inspect(b.second_pie_size.unwrap(), content="75")
    }
    _ => fail("expected OfPieChart plot")
  }
}

///|
test "OfPieChart: bar-of-pie + custSplit" {
  let body = "<c:ofPieChart>" +
    "<c:ofPieType val=\"bar\"/>" +
    "<c:ser><c:idx val=\"0\"/></c:ser>" +
    "<c:splitType val=\"cust\"/>" +
    "<c:custSplit><c:secondPiePt val=\"3\"/></c:custSplit>" +
    "<c:serLines/>" +
    "</c:ofPieChart>"
  let chart = @chart.Chart::parse(fixture_ofpie_chart_xml(body))
  match chart.chart.plot_area.plots[0] {
    OfPieChart(b) => {
      debug_inspect(b.of_pie_type, content="Bar")
      debug_inspect(b.split_type is Some(Cust), content="true")
      debug_inspect(b.cust_split is Some(_), content="true")
      debug_inspect(b.ser_lines.length(), content="1")
    }
    _ => fail("expected OfPieChart plot")
  }
}

///|
test "OfPieChart: missing ofPieType raises Malformed" {
  let body = "<c:ofPieChart>" +
    "<c:ser><c:idx val=\"0\"/></c:ser>" +
    "</c:ofPieChart>"
  try @chart.Chart::parse(fixture_ofpie_chart_xml(body)) catch {
    _ => ()
  } noraise {
    _ => fail("expected Malformed")
  }
}

///|
test "OfPieChart: round-trip" {
  let body = "<c:ofPieChart>" +
    "<c:ofPieType val=\"bar\"/>" +
    "<c:ser><c:idx val=\"0\"/></c:ser>" +
    "<c:gapWidth val=\"150\"/>" +
    "<c:splitType val=\"auto\"/>" +
    "</c:ofPieChart>"
  let original = @chart.Chart::parse(fixture_ofpie_chart_xml(body))
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  debug_inspect(re_parsed == original, content="true")
}

///|
test "OfPieType + SplitType enums round-trip" {
  for t in [@chart.OfPieType::Pie, Bar] {
    debug_inspect(
      @chart.OfPieType::from_xml(t.to_xml()).unwrap() == t,
      content="true",
    )
  }
  for s in [@chart.SplitType::Auto, Cust, Percent, Pos, Val] {
    debug_inspect(
      @chart.SplitType::from_xml(s.to_xml()).unwrap() == s,
      content="true",
    )
  }
}
