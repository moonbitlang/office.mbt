// Modified for office.mbt: follow the workspace warning conventions.
// Geometry parser tests.

///|
/// Build a minimal slide containing one auto-shape whose `<p:spPr>` body
/// is `inner_sp_pr_body` (the part between `<p:spPr>` and `</p:spPr>`).
fn slide_with_sp_pr(inner_sp_pr_body : String) -> FixedArray[Byte] {
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\">" +
    "<p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>" +
    "<p:sp>" +
    "<p:nvSpPr><p:cNvPr id=\"2\" name=\"x\"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>" +
    "<p:spPr>" +
    inner_sp_pr_body +
    "</p:spPr>" +
    "</p:sp>" +
    "</p:spTree></p:cSld></p:sld>"
  @oxml.string_to_bytes(xml)
}

// --- PresetShape::from_xml / to_xml ---

///|
test "PresetShape: round-trip every variant via to_xml -> from_xml" {
  // Spot-check a representative spread covering each grouping in the enum.
  let cases = [
    @slide.PresetShape::Rect,
    RoundRect,
    Triangle,
    Pentagon,
    Star8,
    IrregularSeal2,
    Ellipse,
    Pie,
    RightArrow,
    QuadArrow,
    CurvedRightArrow,
    WedgeRectCallout,
    FlowChartProcess,
    FlowChartOffpageConnector,
    ActionButtonHome,
    ActionButtonMovie,
    MathPlus,
    Gear9,
    ChartPlus,
  ]
  for c in cases {
    let xml = c.to_xml()
    let parsed = @slide.PresetShape::from_xml(xml)
    debug_inspect(parsed == c, content="true")
  }
}

///|
test "PresetShape::from_xml: unknown value rejected" {
  try @slide.PresetShape::from_xml("notashape") catch {
    Malformed(_) => ()
    _ => fail("expected Malformed")
  } noraise {
    _ => fail("expected Malformed")
  }
}

// --- Slide / parser integration ---

///|
test "parse: prstGeom rect with no adjustments" {
  let bytes = slide_with_sp_pr(
    "<a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom>",
  )
  let slide = @slide.Slide::parse(bytes)
  match slide.shapes[0] {
    AutoShape(s) =>
      match s.geometry.unwrap() {
        Preset(kind, adj) => {
          debug_inspect(kind is Rect, content="true")
          debug_inspect(adj.length(), content="0")
        }
        _ => fail("expected Preset")
      }
    _ => fail("expected AutoShape")
  }
}

///|
test "parse: prstGeom roundRect carries adjustment values in source order" {
  let body = "<a:prstGeom prst=\"roundRect\">" +
    "<a:avLst>" +
    "<a:gd name=\"adj\" fmla=\"val 16667\"/>" +
    "<a:gd name=\"adj2\" fmla=\"val 25000\"/>" +
    "</a:avLst>" +
    "</a:prstGeom>"
  let slide = @slide.Slide::parse(slide_with_sp_pr(body))
  match slide.shapes[0] {
    AutoShape(s) =>
      match s.geometry.unwrap() {
        Preset(kind, adj) => {
          debug_inspect(kind is RoundRect, content="true")
          debug_inspect(adj.length(), content="2")
          debug_inspect(adj[0].name, content="\"adj\"")
          debug_inspect(adj[0].fmla, content="\"val 16667\"")
          debug_inspect(adj[1].name, content="\"adj2\"")
          debug_inspect(adj[1].fmla, content="\"val 25000\"")
        }
        _ => fail("expected Preset")
      }
    _ => fail("expected AutoShape")
  }
}

///|
test "parse: custGeom lifts into typed CustomGeometry" {
  let body = "<a:custGeom>" +
    "<a:pathLst><a:path w=\"100\" h=\"100\"><a:moveTo><a:pt x=\"0\" y=\"0\"/></a:moveTo></a:path></a:pathLst>" +
    "</a:custGeom>"
  let slide = @slide.Slide::parse(slide_with_sp_pr(body))
  match slide.shapes[0] {
    AutoShape(s) =>
      match s.geometry.unwrap() {
        Custom(cg) => {
          debug_inspect(cg.paths.length(), content="1")
          let p = cg.paths[0]
          debug_inspect(p.w, content="Emu(100)")
          debug_inspect(p.h, content="Emu(100)")
          debug_inspect(p.commands.length(), content="1")
          match p.commands[0] {
            MoveTo(pt) =>
              debug_inspect(
                pt.x is Literal(_) && pt.y is Literal(_),
                content="true",
              )
            _ => fail("expected MoveTo command")
          }
        }
        _ => fail("expected Geometry::Custom")
      }
    _ => fail("expected AutoShape")
  }
}

///|
test "parse: missing geometry leaves field None (permissive)" {
  let bytes = slide_with_sp_pr(
    "<a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"1\" cy=\"1\"/></a:xfrm>",
  )
  let slide = @slide.Slide::parse(bytes)
  match slide.shapes[0] {
    AutoShape(s) => debug_inspect(s.geometry is None, content="true")
    _ => fail("expected AutoShape")
  }
}

///|
test "parse: prstGeom unknown preset value rejected" {
  let body = "<a:prstGeom prst=\"unknownPreset\"><a:avLst/></a:prstGeom>"
  try @slide.Slide::parse(slide_with_sp_pr(body)) catch {
    Malformed(_) => ()
    _ => fail("expected Malformed")
  } noraise {
    _ => fail("expected Malformed")
  }
}

///|
test "parse: xfrm + prstGeom coexist on the same shape" {
  let body = "<a:xfrm><a:off x=\"100\" y=\"200\"/><a:ext cx=\"300\" cy=\"400\"/></a:xfrm>" +
    "<a:prstGeom prst=\"ellipse\"><a:avLst/></a:prstGeom>"
  let slide = @slide.Slide::parse(slide_with_sp_pr(body))
  match slide.shapes[0] {
    AutoShape(s) => {
      let xfrm = s.transform.unwrap()
      debug_inspect(xfrm.offset.x, content="Emu(100)")
      match s.geometry.unwrap() {
        Preset(kind, _) => debug_inspect(kind is Ellipse, content="true")
        _ => fail("expected Preset")
      }
    }
    _ => fail("expected AutoShape")
  }
}
