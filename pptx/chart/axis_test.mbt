// AxisCore typed parser / writer tests.
//
// Round-trip floor: parse → serialize → parse → Eq for every modelled
// child of CT_AxBase. The shared fixture in `parser_test.mbt` wraps
// the axis fragment in a minimal `<c:chartSpace>` / `<c:chart>` /
// `<c:plotArea>` envelope so the top-level parser is exercised too.

///|
fn fixture_axis_chart_xml(axis_body : String) -> FixedArray[Byte] {
  let xml = "<?xml version=\"1.0\"?>" +
    "<c:chartSpace xmlns:c=\"" +
    chart_ns +
    "\">" +
    "<c:chart>" +
    "<c:plotArea>" +
    axis_body +
    "</c:plotArea>" +
    "</c:chart>" +
    "</c:chartSpace>"
  @oxml.string_to_bytes(xml)
}

///|
test "AxisCore: minimal catAx with only axId parses" {
  let body = "<c:catAx><c:axId val=\"1\"/></c:catAx>"
  let chart = @chart.Chart::parse(fixture_axis_chart_xml(body))
  debug_inspect(chart.chart.plot_area.axes.length(), content="1")
  let core = chart.chart.plot_area.axes[0].core()
  debug_inspect(core.ax_id, content="1")
  debug_inspect(core.scaling is None, content="true")
  debug_inspect(core.ax_pos is None, content="true")
  debug_inspect(core.cross_ax is None, content="true")
}

///|
test "AxisCore: full catAx fields lift to typed values" {
  let body = "<c:catAx>" +
    "<c:axId val=\"10\"/>" +
    "<c:scaling><c:orientation val=\"minMax\"/></c:scaling>" +
    "<c:delete val=\"0\"/>" +
    "<c:axPos val=\"b\"/>" +
    "<c:numFmt formatCode=\"General\" sourceLinked=\"1\"/>" +
    "<c:majorTickMark val=\"out\"/>" +
    "<c:minorTickMark val=\"none\"/>" +
    "<c:tickLblPos val=\"nextTo\"/>" +
    "<c:crossAx val=\"20\"/>" +
    "<c:crosses val=\"autoZero\"/>" +
    "</c:catAx>"
  let chart = @chart.Chart::parse(fixture_axis_chart_xml(body))
  let core = chart.chart.plot_area.axes[0].core()
  debug_inspect(core.ax_id, content="10")
  debug_inspect(
    core.scaling.unwrap().orientation is Some(MinMax),
    content="true",
  )
  debug_inspect(core.delete.unwrap(), content="false")
  debug_inspect(core.ax_pos is Some(Bottom), content="true")
  debug_inspect(core.num_fmt.unwrap().format_code, content="\"General\"")
  debug_inspect(core.num_fmt.unwrap().source_linked.unwrap(), content="true")
  debug_inspect(core.major_tick_mark is Some(Out), content="true")
  debug_inspect(core.minor_tick_mark is Some(NoTick), content="true")
  debug_inspect(core.tick_lbl_pos is Some(NextTo), content="true")
  debug_inspect(core.cross_ax.unwrap(), content="20")
  debug_inspect(core.crosses is Some(AutoZero), content="true")
}

///|
test "AxisCore: valAx with scaling max/min and crossesAt" {
  let body = "<c:valAx>" +
    "<c:axId val=\"2\"/>" +
    "<c:scaling>" +
    "<c:orientation val=\"minMax\"/>" +
    "<c:max val=\"100\"/>" +
    "<c:min val=\"-50\"/>" +
    "</c:scaling>" +
    "<c:axPos val=\"l\"/>" +
    "<c:crossAx val=\"1\"/>" +
    "<c:crossesAt val=\"0\"/>" +
    "</c:valAx>"
  let chart = @chart.Chart::parse(fixture_axis_chart_xml(body))
  let core = chart.chart.plot_area.axes[0].core()
  let scaling = core.scaling.unwrap()
  debug_inspect(scaling.max.unwrap(), content="\"100\"")
  debug_inspect(scaling.min.unwrap(), content="\"-50\"")
  debug_inspect(core.ax_pos is Some(Left), content="true")
  debug_inspect(core.crosses_at.unwrap(), content="\"0\"")
}

///|
test "AxisCore: scaling logBase round-trips" {
  let body = "<c:valAx>" +
    "<c:axId val=\"2\"/>" +
    "<c:scaling><c:logBase val=\"10\"/></c:scaling>" +
    "<c:crossAx val=\"1\"/>" +
    "</c:valAx>"
  let original = @chart.Chart::parse(fixture_axis_chart_xml(body))
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  debug_inspect(re_parsed == original, content="true")
  let core = re_parsed.chart.plot_area.axes[0].core()
  debug_inspect(core.scaling.unwrap().log_base.unwrap(), content="\"10\"")
}

///|
test "AxisCore: tickMark variants round-trip" {
  let body = "<c:catAx>" +
    "<c:axId val=\"1\"/>" +
    "<c:majorTickMark val=\"cross\"/>" +
    "<c:minorTickMark val=\"in\"/>" +
    "<c:crossAx val=\"2\"/>" +
    "</c:catAx>"
  let original = @chart.Chart::parse(fixture_axis_chart_xml(body))
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  debug_inspect(re_parsed == original, content="true")
}

///|
test "AxisCore: tickLblPos every variant" {
  // Run the full enum through parse → write → parse.
  let cases = ["high", "low", "nextTo", "none"]
  for v in cases {
    let body = "<c:valAx>" +
      "<c:axId val=\"1\"/>" +
      "<c:tickLblPos val=\"" +
      v +
      "\"/>" +
      "<c:crossAx val=\"2\"/>" +
      "</c:valAx>"
    let original = @chart.Chart::parse(fixture_axis_chart_xml(body))
    let bytes = original.serialize()
    let re_parsed = @chart.Chart::parse(bytes)
    debug_inspect(re_parsed == original, content="true")
  }
}

///|
test "AxisCore: crosses every variant" {
  let cases = ["autoZero", "min", "max"]
  for v in cases {
    let body = "<c:catAx>" +
      "<c:axId val=\"1\"/>" +
      "<c:crossAx val=\"2\"/>" +
      "<c:crosses val=\"" +
      v +
      "\"/>" +
      "</c:catAx>"
    let original = @chart.Chart::parse(fixture_axis_chart_xml(body))
    let bytes = original.serialize()
    let re_parsed = @chart.Chart::parse(bytes)
    debug_inspect(re_parsed == original, content="true")
  }
}

///|
test "AxisCore: axPos every variant" {
  let cases = ["b", "l", "r", "t"]
  for v in cases {
    let body = "<c:catAx>" +
      "<c:axId val=\"1\"/>" +
      "<c:axPos val=\"" +
      v +
      "\"/>" +
      "<c:crossAx val=\"2\"/>" +
      "</c:catAx>"
    let original = @chart.Chart::parse(fixture_axis_chart_xml(body))
    let bytes = original.serialize()
    let re_parsed = @chart.Chart::parse(bytes)
    debug_inspect(re_parsed == original, content="true")
  }
}

///|
test "AxisCore: orientation maxMin round-trips" {
  let body = "<c:valAx>" +
    "<c:axId val=\"2\"/>" +
    "<c:scaling><c:orientation val=\"maxMin\"/></c:scaling>" +
    "<c:crossAx val=\"1\"/>" +
    "</c:valAx>"
  let original = @chart.Chart::parse(fixture_axis_chart_xml(body))
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  debug_inspect(re_parsed == original, content="true")
  let core = re_parsed.chart.plot_area.axes[0].core()
  debug_inspect(
    core.scaling.unwrap().orientation is Some(MaxMin),
    content="true",
  )
}

///|
test "AxisCore: numFmt without sourceLinked attribute" {
  let body = "<c:valAx>" +
    "<c:axId val=\"2\"/>" +
    "<c:numFmt formatCode=\"0.00%\"/>" +
    "<c:crossAx val=\"1\"/>" +
    "</c:valAx>"
  let original = @chart.Chart::parse(fixture_axis_chart_xml(body))
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  debug_inspect(re_parsed == original, content="true")
  let core = re_parsed.chart.plot_area.axes[0].core()
  debug_inspect(core.num_fmt.unwrap().format_code, content="\"0.00%\"")
  debug_inspect(core.num_fmt.unwrap().source_linked is None, content="true")
}

///|
test "AxisCore: missing axId raises Malformed" {
  let body = "<c:catAx><c:crossAx val=\"2\"/></c:catAx>"
  try @chart.Chart::parse(fixture_axis_chart_xml(body)) catch {
    _ => ()
  } noraise {
    _ => fail("expected Malformed for axis without axId")
  }
}

///|
test "AxisCore: per-axis-kind extras ride on extension (CT_ValAx)" {
  // crossBetween / majorUnit are CT_ValAx-specific and not yet
  // typed — they must round-trip via extension. The round-trip
  // assertion is the only behaviour we promise here.
  let body = "<c:valAx>" +
    "<c:axId val=\"2\"/>" +
    "<c:crossAx val=\"1\"/>" +
    "<c:crossBetween val=\"between\"/>" +
    "<c:majorUnit val=\"10\"/>" +
    "</c:valAx>"
  let original = @chart.Chart::parse(fixture_axis_chart_xml(body))
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  debug_inspect(re_parsed == original, content="true")
  let core = re_parsed.chart.plot_area.axes[0].core()
  debug_inspect(core.extension.length(), content="2")
}

///|
test "AxisCore: gridlines and styling subtrees captured" {
  // majorGridlines / minorGridlines / spPr / txPr / title are
  // modelled as captured XmlElement until later slices type them.
  // Round-trip should keep them verbatim.
  let body = "<c:catAx>" +
    "<c:axId val=\"1\"/>" +
    "<c:majorGridlines/>" +
    "<c:minorGridlines/>" +
    "<c:title/>" +
    "<c:spPr/>" +
    "<c:txPr/>" +
    "<c:crossAx val=\"2\"/>" +
    "</c:catAx>"
  let original = @chart.Chart::parse(fixture_axis_chart_xml(body))
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  debug_inspect(re_parsed == original, content="true")
  let core = re_parsed.chart.plot_area.axes[0].core()
  debug_inspect(core.major_gridlines is Some(_), content="true")
  debug_inspect(core.minor_gridlines is Some(_), content="true")
  debug_inspect(core.title is Some(_), content="true")
  debug_inspect(core.sp_pr is Some(_), content="true")
  debug_inspect(core.tx_pr is Some(_), content="true")
}

///|
test "AxisCore: builder-produced of_bar embeds typed axes" {
  // `Chart::of_bar` uses `simple_axis_core(...)` internally; verify
  // the typed values come through end-to-end.
  let data = @chart.ChartData::new()
    .with_category("Q1")
    .with_category("Q2")
    .with_series("Revenue", [100.0, 200.0])
  let chart = @chart.Chart::of_bar(data)
  let axes = chart.chart.plot_area.axes
  debug_inspect(axes.length(), content="2")
  let cat = axes[0].core()
  debug_inspect(cat.ax_id, content="1")
  debug_inspect(cat.ax_pos is Some(Bottom), content="true")
  debug_inspect(cat.cross_ax.unwrap(), content="2")
  debug_inspect(
    cat.scaling.unwrap().orientation is Some(MinMax),
    content="true",
  )
  let val = axes[1].core()
  debug_inspect(val.ax_id, content="2")
  debug_inspect(val.ax_pos is Some(Left), content="true")
  debug_inspect(val.cross_ax.unwrap(), content="1")
}

///|
test "AxisCore: builder of_bar serialized → re-parsed yields typed axes" {
  let data = @chart.ChartData::new()
    .with_category("Q1")
    .with_series("S1", [1.0])
  let chart = @chart.Chart::of_bar(data)
  let bytes = chart.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  debug_inspect(re_parsed == chart, content="true")
}

///|
test "AxisCore: dateAx and serAx variants discriminated" {
  let body = "<c:dateAx>" +
    "<c:axId val=\"1\"/>" +
    "<c:crossAx val=\"2\"/>" +
    "</c:dateAx>" +
    "<c:serAx>" +
    "<c:axId val=\"3\"/>" +
    "<c:crossAx val=\"1\"/>" +
    "</c:serAx>"
  let chart = @chart.Chart::parse(fixture_axis_chart_xml(body))
  debug_inspect(chart.chart.plot_area.axes.length(), content="2")
  match chart.chart.plot_area.axes[0] {
    DateAx(c) => debug_inspect(c.ax_id, content="1")
    _ => fail("expected DateAx at index 0")
  }
  match chart.chart.plot_area.axes[1] {
    SerAx(c) => debug_inspect(c.ax_id, content="3")
    _ => fail("expected SerAx at index 1")
  }
}
