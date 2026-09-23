// <c:externalData> round-trip preservation tests.
//
// `<c:externalData r:id="…">` is the optional chartSpace-level child
// that references an embedded `.xlsx` part (the spreadsheet cache
// PowerPoint shows when the user clicks "Edit Data"). Our builders
// emit inline `<c:strLit>` / `<c:numLit>` data instead (which the
// schema permits and PowerPoint renders correctly without an xlsx),
// so we don't generate this element. But when *reading* a deck
// produced by PowerPoint, the element must round-trip verbatim so
// the reference to the xlsx part survives a parse → serialize cycle.
//
// The xlsx part itself rides through @opc.Package as an opaque part
// keyed by content type — no SpreadsheetML parsing happens. This is
// formalised in ADR-009.

///|
test "externalData: round-trips via Chart.extension" {
  let xml = "<?xml version=\"1.0\"?>" +
    "<c:chartSpace xmlns:c=\"" +
    chart_ns +
    "\" xmlns:r=\"" +
    r_ns +
    "\">" +
    "<c:chart><c:plotArea/></c:chart>" +
    "<c:externalData r:id=\"rId1\">" +
    "<c:autoUpdate val=\"0\"/>" +
    "</c:externalData>" +
    "</c:chartSpace>"
  let original = @chart.Chart::parse(@oxml.string_to_bytes(xml))
  // externalData isn't a typed field; it rides on Chart.extension.
  debug_inspect(original.extension.length(), content="1")
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  debug_inspect(re_parsed == original, content="true")
}

///|
test "externalData: rId attribute survives the round-trip" {
  let xml = "<?xml version=\"1.0\"?>" +
    "<c:chartSpace xmlns:c=\"" +
    chart_ns +
    "\" xmlns:r=\"" +
    r_ns +
    "\">" +
    "<c:chart><c:plotArea/></c:chart>" +
    "<c:externalData r:id=\"rId42\"/>" +
    "</c:chartSpace>"
  let original = @chart.Chart::parse(@oxml.string_to_bytes(xml))
  let ext = original.extension[0]
  debug_inspect(ext.name.local_name, content="\"externalData\"")
  // Verify the r:id attribute is captured verbatim.
  let mut found_rid = false
  for kv in ext.attributes {
    if kv.0.local_name == "id" {
      debug_inspect(kv.1, content="\"rId42\"")
      found_rid = true
    }
  }
  debug_inspect(found_rid, content="true")
}

///|
test "externalData: works alongside a typed chart" {
  // Mix externalData with a typed bar chart -- the externalData ride
  // on Chart.extension while the chart body lifts fully.
  let xml = "<?xml version=\"1.0\"?>" +
    "<c:chartSpace xmlns:c=\"" +
    chart_ns +
    "\" xmlns:r=\"" +
    r_ns +
    "\">" +
    "<c:chart>" +
    "<c:plotArea>" +
    "<c:barChart>" +
    "<c:barDir val=\"col\"/>" +
    "<c:ser><c:idx val=\"0\"/></c:ser>" +
    "<c:axId val=\"1\"/>" +
    "<c:axId val=\"2\"/>" +
    "</c:barChart>" +
    "</c:plotArea>" +
    "</c:chart>" +
    "<c:externalData r:id=\"rId1\"/>" +
    "</c:chartSpace>"
  let original = @chart.Chart::parse(@oxml.string_to_bytes(xml))
  debug_inspect(original.extension.length(), content="1")
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  debug_inspect(re_parsed == original, content="true")
}
