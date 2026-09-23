// Modified for office.mbt: follow the workspace warning conventions.
// Connector parser tests.

///|
fn slide_with_cxn(inner : String) -> FixedArray[Byte] {
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\">" +
    "<p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>" +
    "<p:cxnSp>" +
    inner +
    "</p:cxnSp>" +
    "</p:spTree></p:cSld></p:sld>"
  @oxml.string_to_bytes(xml)
}

// --- happy path ---

///|
test "parse: bound connector with both stCxn and endCxn" {
  let inner = "<p:nvCxnSpPr>" +
    "<p:cNvPr id=\"6\" name=\"Straight Connector 5\"/>" +
    "<p:cNvCxnSpPr>" +
    "<a:stCxn id=\"2\" idx=\"3\"/>" +
    "<a:endCxn id=\"3\" idx=\"1\"/>" +
    "</p:cNvCxnSpPr>" +
    "<p:nvPr/>" +
    "</p:nvCxnSpPr>" +
    "<p:spPr>" +
    "<a:xfrm><a:off x=\"100\" y=\"200\"/><a:ext cx=\"300\" cy=\"400\"/></a:xfrm>" +
    "<a:prstGeom prst=\"straightConnector1\"><a:avLst/></a:prstGeom>" +
    "</p:spPr>"
  let slide = @slide.Slide::parse(slide_with_cxn(inner))
  match slide.shapes[0] {
    Connector(c) => {
      debug_inspect(c.id, content="6")
      debug_inspect(c.name, content="\"Straight Connector 5\"")
      let st = c.start.unwrap()
      debug_inspect(st.shape_id, content="2")
      debug_inspect(st.idx, content="3")
      let en = c.end.unwrap()
      debug_inspect(en.shape_id, content="3")
      debug_inspect(en.idx, content="1")
      match c.geometry.unwrap() {
        Preset(kind, _) =>
          debug_inspect(kind is StraightConnector1, content="true")
        _ => fail("expected Preset")
      }
    }
    _ => fail("expected Connector")
  }
}

///|
test "parse: free-floating connector (no stCxn / endCxn)" {
  let inner = "<p:nvCxnSpPr>" +
    "<p:cNvPr id=\"7\" name=\"Free\"/>" +
    "<p:cNvCxnSpPr/>" +
    "<p:nvPr/>" +
    "</p:nvCxnSpPr>" +
    "<p:spPr/>"
  let slide = @slide.Slide::parse(slide_with_cxn(inner))
  match slide.shapes[0] {
    Connector(c) => {
      debug_inspect(c.start is None, content="true")
      debug_inspect(c.end is None, content="true")
      debug_inspect(c.id, content="7")
    }
    _ => fail("expected Connector")
  }
}

///|
test "parse: connector with only stCxn" {
  let inner = "<p:nvCxnSpPr>" +
    "<p:cNvPr id=\"8\" name=\"Half\"/>" +
    "<p:cNvCxnSpPr><a:stCxn id=\"2\" idx=\"0\"/></p:cNvCxnSpPr>" +
    "<p:nvPr/>" +
    "</p:nvCxnSpPr>" +
    "<p:spPr/>"
  let slide = @slide.Slide::parse(slide_with_cxn(inner))
  match slide.shapes[0] {
    Connector(c) => {
      debug_inspect(!(c.start is None), content="true")
      debug_inspect(c.end is None, content="true")
    }
    _ => fail("expected Connector")
  }
}
