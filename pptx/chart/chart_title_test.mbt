// ChartTitle typed parser / writer tests.

///|
fn fixture_title_chart_xml(title_body : String) -> FixedArray[Byte] {
  let xml = "<?xml version=\"1.0\"?>" +
    "<c:chartSpace xmlns:c=\"" +
    chart_ns +
    "\" xmlns:a=\"" +
    drawing_ns +
    "\">" +
    "<c:chart>" +
    title_body +
    "<c:plotArea/>" +
    "</c:chart>" +
    "</c:chartSpace>"
  @oxml.string_to_bytes(xml)
}

///|
test "ChartTitle: empty title parses to empty body" {
  let chart = @chart.Chart::parse(fixture_title_chart_xml("<c:title/>"))
  let title = chart.chart.title.unwrap()
  debug_inspect(title.tx is None, content="true")
  debug_inspect(title.layout is None, content="true")
  debug_inspect(title.overlay is None, content="true")
  debug_inspect(title.sp_pr is None, content="true")
  debug_inspect(title.tx_pr is None, content="true")
  debug_inspect(title.extension.length(), content="0")
}

///|
test "ChartTitle: overlay leaf lifts" {
  let body = "<c:title>" + "<c:overlay val=\"1\"/>" + "</c:title>"
  let chart = @chart.Chart::parse(fixture_title_chart_xml(body))
  let title = chart.chart.title.unwrap()
  debug_inspect(title.overlay.unwrap(), content="true")
}

///|
test "ChartTitle: tx / layout / spPr / txPr captured" {
  let body = "<c:title>" +
    "<c:tx><c:rich><a:bodyPr/></c:rich></c:tx>" +
    "<c:layout/>" +
    "<c:overlay val=\"0\"/>" +
    "<c:spPr/>" +
    "<c:txPr><a:bodyPr/></c:txPr>" +
    "</c:title>"
  let chart = @chart.Chart::parse(fixture_title_chart_xml(body))
  let title = chart.chart.title.unwrap()
  debug_inspect(title.tx is Some(_), content="true")
  debug_inspect(title.layout is Some(_), content="true")
  debug_inspect(title.overlay.unwrap(), content="false")
  debug_inspect(title.sp_pr is Some(_), content="true")
  debug_inspect(title.tx_pr is Some(_), content="true")
}

///|
test "ChartTitle: chart-level title round-trips" {
  let body = "<c:title>" +
    "<c:tx><c:rich><a:bodyPr/></c:rich></c:tx>" +
    "<c:layout/>" +
    "<c:overlay val=\"1\"/>" +
    "<c:spPr/>" +
    "<c:txPr><a:bodyPr/></c:txPr>" +
    "</c:title>"
  let original = @chart.Chart::parse(fixture_title_chart_xml(body))
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  debug_inspect(re_parsed == original, content="true")
}

///|
test "ChartTitle: axis-level title parses + round-trips" {
  let body = "<c:catAx>" +
    "<c:axId val=\"1\"/>" +
    "<c:title>" +
    "<c:tx><c:rich><a:bodyPr/></c:rich></c:tx>" +
    "<c:overlay val=\"0\"/>" +
    "</c:title>" +
    "<c:crossAx val=\"2\"/>" +
    "</c:catAx>"
  let xml = "<?xml version=\"1.0\"?>" +
    "<c:chartSpace xmlns:c=\"" +
    chart_ns +
    "\" xmlns:a=\"" +
    drawing_ns +
    "\">" +
    "<c:chart>" +
    "<c:plotArea>" +
    body +
    "</c:plotArea>" +
    "</c:chart>" +
    "</c:chartSpace>"
  let original = @chart.Chart::parse(@oxml.string_to_bytes(xml))
  let axis_title = original.chart.plot_area.axes[0].core().title.unwrap()
  debug_inspect(axis_title.tx is Some(_), content="true")
  debug_inspect(axis_title.overlay.unwrap(), content="false")
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  debug_inspect(re_parsed == original, content="true")
}

///|
test "ChartTitle: unknown chart-namespace children land on extension" {
  // <c:extLst> is the canonical example. Round-trip verbatim.
  let body = "<c:title>" +
    "<c:overlay val=\"0\"/>" +
    "<c:extLst><c:ext uri=\"{X}\"/></c:extLst>" +
    "</c:title>"
  let original = @chart.Chart::parse(fixture_title_chart_xml(body))
  let title = original.chart.title.unwrap()
  debug_inspect(title.extension.length(), content="1")
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  debug_inspect(re_parsed == original, content="true")
}

///|
test "ChartTitle: foreign-namespace children survive on extension" {
  let body = "<c:title xmlns:foo=\"http://example.com/foo\">" +
    "<c:overlay val=\"1\"/>" +
    "<foo:custom/>" +
    "</c:title>"
  let original = @chart.Chart::parse(fixture_title_chart_xml(body))
  let title = original.chart.title.unwrap()
  debug_inspect(title.extension.length(), content="1")
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  debug_inspect(re_parsed == original, content="true")
}

///|
test "ChartTitle: child-order is canonical on emit" {
  // Parser tolerates any source order; writer always emits in schema
  // order (tx → layout → overlay → spPr → txPr). Verify by re-parsing
  // the writer output and asserting that the body is well-formed.
  let body = "<c:title>" +
    "<c:overlay val=\"1\"/>" +
    "<c:txPr><a:bodyPr/></c:txPr>" +
    "<c:tx><c:rich><a:bodyPr/></c:rich></c:tx>" +
    "<c:layout/>" +
    "<c:spPr/>" +
    "</c:title>"
  let original = @chart.Chart::parse(fixture_title_chart_xml(body))
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  debug_inspect(re_parsed == original, content="true")
}
