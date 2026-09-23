// Modified for office.mbt: qualify test types.
// Custom-geometry parser tests.
//
// `slide_with_sp_pr` from `geometry_test.mbt` builds the surrounding
// `<p:sp><p:spPr>…</p:spPr></p:sp>` wrapper; each test below just
// supplies the inner `<a:custGeom>` body.

///|
/// Extract the typed CustomGeometry from a slide built with
/// `slide_with_sp_pr`, panicking if anything earlier in the chain
/// doesn't match — we test the parsed body, not the surrounding plumbing.
fn extract_custom_geometry(
  body : String,
) -> @slide.CustomGeometry raise @slide.SlideError {
  let slide = @slide.Slide::parse(slide_with_sp_pr(body))
  match slide.shapes[0] {
    AutoShape(s) =>
      match s.geometry.unwrap() {
        Custom(cg) => cg
        _ => panic()
      }
    _ => panic()
  }
}

// --- PathFillMode round-trip ---

///|
test "PathFillMode: round-trip every variant via to_xml -> from_xml" {
  let cases = [
    @slide.PathFillMode::PathFillNone,
    PathFillNorm,
    PathFillLighten,
    PathFillLightenLess,
    PathFillDarken,
    PathFillDarkenLess,
  ]
  for c in cases {
    let xml = c.to_xml()
    debug_inspect(@slide.PathFillMode::from_xml(xml) == c, content="true")
  }
}

///|
test "PathFillMode::from_xml: unknown value defaults to PathFillNorm" {
  debug_inspect(@slide.PathFillMode::from_xml("bogus"), content="PathFillNorm")
}

// --- Empty / minimal custGeom ---

///|
test "parse: empty custGeom (no children) yields all-empty AST" {
  let cg = extract_custom_geometry("<a:custGeom/>")
  debug_inspect(cg.adjust_values.length(), content="0")
  debug_inspect(cg.guides.length(), content="0")
  debug_inspect(cg.connection_sites.length(), content="0")
  debug_inspect(cg.rect is None, content="true")
  debug_inspect(cg.paths.length(), content="0")
  debug_inspect(cg.extension.length(), content="0")
}

///|
test "parse: custGeom with empty pathLst yields zero-path CustomGeometry" {
  let cg = extract_custom_geometry("<a:custGeom><a:pathLst/></a:custGeom>")
  debug_inspect(cg.paths.length(), content="0")
}

// --- avLst / gdLst ---

///|
test "parse: avLst and gdLst populate independently in source order" {
  let body = "<a:custGeom>" +
    "<a:avLst>" +
    "<a:gd name=\"adj1\" fmla=\"val 25000\"/>" +
    "<a:gd name=\"adj2\" fmla=\"val 50000\"/>" +
    "</a:avLst>" +
    "<a:gdLst>" +
    "<a:gd name=\"x1\" fmla=\"*/ w adj1 100000\"/>" +
    "</a:gdLst>" +
    "<a:pathLst/>" +
    "</a:custGeom>"
  let cg = extract_custom_geometry(body)
  debug_inspect(cg.adjust_values.length(), content="2")
  debug_inspect(cg.adjust_values[0].name, content="\"adj1\"")
  debug_inspect(cg.adjust_values[0].fmla, content="\"val 25000\"")
  debug_inspect(cg.adjust_values[1].name, content="\"adj2\"")
  debug_inspect(cg.guides.length(), content="1")
  debug_inspect(cg.guides[0].name, content="\"x1\"")
  debug_inspect(cg.guides[0].fmla, content="\"*/ w adj1 100000\"")
}

// --- Path commands ---

///|
test "parse: moveTo + lnTo + close" {
  let body = "<a:custGeom><a:pathLst>" +
    "<a:path w=\"100\" h=\"100\">" +
    "<a:moveTo><a:pt x=\"0\" y=\"0\"/></a:moveTo>" +
    "<a:lnTo><a:pt x=\"100\" y=\"100\"/></a:lnTo>" +
    "<a:close/>" +
    "</a:path>" +
    "</a:pathLst></a:custGeom>"
  let cg = extract_custom_geometry(body)
  let p = cg.paths[0]
  debug_inspect(p.commands.length(), content="3")
  match p.commands[0] {
    MoveTo(pt) => {
      debug_inspect(pt.x, content="Literal(Emu(0))")
      debug_inspect(pt.y, content="Literal(Emu(0))")
    }
    _ => fail("expected MoveTo")
  }
  match p.commands[1] {
    LnTo(pt) => {
      debug_inspect(pt.x, content="Literal(Emu(100))")
      debug_inspect(pt.y, content="Literal(Emu(100))")
    }
    _ => fail("expected LnTo")
  }
  match p.commands[2] {
    Close => ()
    _ => fail("expected Close")
  }
}

///|
test "parse: cubicBezTo carries three points in source order" {
  let body = "<a:custGeom><a:pathLst><a:path>" +
    "<a:cubicBezTo>" +
    "<a:pt x=\"10\" y=\"20\"/>" +
    "<a:pt x=\"30\" y=\"40\"/>" +
    "<a:pt x=\"50\" y=\"60\"/>" +
    "</a:cubicBezTo>" +
    "</a:path></a:pathLst></a:custGeom>"
  let cg = extract_custom_geometry(body)
  match cg.paths[0].commands[0] {
    CubicBezTo(c1, c2, end) => {
      debug_inspect(c1.x, content="Literal(Emu(10))")
      debug_inspect(c2.x, content="Literal(Emu(30))")
      debug_inspect(end.x, content="Literal(Emu(50))")
    }
    _ => fail("expected CubicBezTo")
  }
}

///|
test "parse: quadBezTo carries two points" {
  let body = "<a:custGeom><a:pathLst><a:path>" +
    "<a:quadBezTo>" +
    "<a:pt x=\"1\" y=\"2\"/><a:pt x=\"3\" y=\"4\"/>" +
    "</a:quadBezTo>" +
    "</a:path></a:pathLst></a:custGeom>"
  let cg = extract_custom_geometry(body)
  match cg.paths[0].commands[0] {
    QuadBezTo(c, end) => {
      debug_inspect(c.x, content="Literal(Emu(1))")
      debug_inspect(end.y, content="Literal(Emu(4))")
    }
    _ => fail("expected QuadBezTo")
  }
}

///|
test "parse: arcTo carries wR/hR/stAng/swAng" {
  let body = "<a:custGeom><a:pathLst><a:path>" +
    "<a:arcTo wR=\"500\" hR=\"600\" stAng=\"0\" swAng=\"5400000\"/>" +
    "</a:path></a:pathLst></a:custGeom>"
  let cg = extract_custom_geometry(body)
  match cg.paths[0].commands[0] {
    ArcTo(w_r, h_r, st, sw) => {
      debug_inspect(w_r, content="Literal(Emu(500))")
      debug_inspect(h_r, content="Literal(Emu(600))")
      debug_inspect(st == Literal(@units.Angle::from_ooxml(0)), content="true")
      debug_inspect(
        sw == Literal(@units.Angle::from_ooxml(5400000)),
        content="true",
      )
    }
    _ => fail("expected ArcTo")
  }
}

///|
test "parse: cubicBezTo with wrong point count raises Malformed" {
  let body = "<a:custGeom><a:pathLst><a:path>" +
    "<a:cubicBezTo><a:pt x=\"0\" y=\"0\"/></a:cubicBezTo>" +
    "</a:path></a:pathLst></a:custGeom>"
  try @slide.Slide::parse(slide_with_sp_pr(body)) catch {
    Malformed(_) => ()
    _ => fail("expected Malformed")
  } noraise {
    _ => fail("expected Malformed")
  }
}

// --- AdjCoordinate / AdjAngle disambiguation ---

///|
test "parse: guide-name in coordinate becomes GuideRef" {
  let body = "<a:custGeom><a:pathLst><a:path w=\"21600\" h=\"21600\">" +
    "<a:moveTo><a:pt x=\"adj1\" y=\"0\"/></a:moveTo>" +
    "</a:path></a:pathLst></a:custGeom>"
  let cg = extract_custom_geometry(body)
  match cg.paths[0].commands[0] {
    MoveTo(pt) => {
      debug_inspect(pt.x, content="GuideRef(\"adj1\")")
      debug_inspect(pt.y, content="Literal(Emu(0))")
    }
    _ => fail("expected MoveTo")
  }
}

///|
test "parse: guide-name in arcTo angle becomes AdjAngle::GuideRef" {
  let body = "<a:custGeom><a:pathLst><a:path>" +
    "<a:arcTo wR=\"100\" hR=\"100\" stAng=\"startAng\" swAng=\"swA\"/>" +
    "</a:path></a:pathLst></a:custGeom>"
  let cg = extract_custom_geometry(body)
  match cg.paths[0].commands[0] {
    ArcTo(_, _, st, sw) => {
      debug_inspect(st, content="GuideRef(\"startAng\")")
      debug_inspect(sw, content="GuideRef(\"swA\")")
    }
    _ => fail("expected ArcTo")
  }
}

///|
test "parse: negative coordinate parses as Literal Emu" {
  let body = "<a:custGeom><a:pathLst><a:path>" +
    "<a:moveTo><a:pt x=\"-100\" y=\"-200\"/></a:moveTo>" +
    "</a:path></a:pathLst></a:custGeom>"
  let cg = extract_custom_geometry(body)
  match cg.paths[0].commands[0] {
    MoveTo(pt) => {
      debug_inspect(pt.x, content="Literal(Emu(-100))")
      debug_inspect(pt.y, content="Literal(Emu(-200))")
    }
    _ => fail("expected MoveTo")
  }
}

// --- Path attribute defaults ---

///|
test "parse: path without w/h/fill/stroke/extrusionOk uses defaults" {
  let cg = extract_custom_geometry(
    "<a:custGeom><a:pathLst><a:path/></a:pathLst></a:custGeom>",
  )
  let p = cg.paths[0]
  debug_inspect(p.w, content="Emu(0)")
  debug_inspect(p.h, content="Emu(0)")
  debug_inspect(p.fill, content="PathFillNorm")
  debug_inspect(p.stroke, content="true")
  debug_inspect(p.extrusion_ok, content="true")
}

///|
test "parse: path explicit fill / stroke=0 / extrusionOk=0" {
  let body = "<a:custGeom><a:pathLst>" +
    "<a:path w=\"500\" h=\"800\" fill=\"lighten\" stroke=\"0\" extrusionOk=\"0\"/>" +
    "</a:pathLst></a:custGeom>"
  let cg = extract_custom_geometry(body)
  let p = cg.paths[0]
  debug_inspect(p.w, content="Emu(500)")
  debug_inspect(p.h, content="Emu(800)")
  debug_inspect(p.fill, content="PathFillLighten")
  debug_inspect(p.stroke, content="false")
  debug_inspect(p.extrusion_ok, content="false")
}

// --- cxnLst / rect ---

///|
test "parse: cxnLst with two connection sites" {
  let body = "<a:custGeom><a:cxnLst>" +
    "<a:cxn ang=\"0\"><a:pos x=\"0\" y=\"0\"/></a:cxn>" +
    "<a:cxn ang=\"5400000\"><a:pos x=\"100\" y=\"200\"/></a:cxn>" +
    "</a:cxnLst><a:pathLst/></a:custGeom>"
  let cg = extract_custom_geometry(body)
  debug_inspect(cg.connection_sites.length(), content="2")
  let s0 = cg.connection_sites[0]
  debug_inspect(s0.ang == Literal(@units.Angle::from_ooxml(0)), content="true")
  debug_inspect(s0.pos.x, content="Literal(Emu(0))")
  let s1 = cg.connection_sites[1]
  debug_inspect(s1.pos.y, content="Literal(Emu(200))")
}

///|
test "parse: cxn without <a:pos> raises Malformed" {
  let body = "<a:custGeom><a:cxnLst>" +
    "<a:cxn ang=\"0\"/>" +
    "</a:cxnLst><a:pathLst/></a:custGeom>"
  try @slide.Slide::parse(slide_with_sp_pr(body)) catch {
    Malformed(_) => ()
    _ => fail("expected Malformed")
  } noraise {
    _ => fail("expected Malformed")
  }
}

///|
test "parse: rect with literal corners + guide refs" {
  let body = "<a:custGeom>" +
    "<a:rect l=\"0\" t=\"0\" r=\"w\" b=\"h\"/>" +
    "<a:pathLst/></a:custGeom>"
  let cg = extract_custom_geometry(body)
  let r = cg.rect.unwrap()
  debug_inspect(r.l, content="Literal(Emu(0))")
  debug_inspect(r.t, content="Literal(Emu(0))")
  debug_inspect(r.r, content="GuideRef(\"w\")")
  debug_inspect(r.b, content="GuideRef(\"h\")")
}

// --- Lossless preservation ---

///|
test "parse: <a:ahLst> is preserved on CustomGeometry.extension" {
  let body = "<a:custGeom>" +
    "<a:ahLst><a:ahXY gdRefX=\"adj1\" minX=\"0\" maxX=\"100\"><a:pos x=\"0\" y=\"0\"/></a:ahXY></a:ahLst>" +
    "<a:pathLst/></a:custGeom>"
  let cg = extract_custom_geometry(body)
  debug_inspect(cg.extension.length(), content="1")
  debug_inspect(cg.extension[0].name.local_name, content="\"ahLst\"")
}

///|
test "parse: foreign-namespace child of custGeom is preserved" {
  let body = "<a:custGeom xmlns:x=\"urn:x\">" +
    "<x:future foo=\"bar\"/>" +
    "<a:pathLst/></a:custGeom>"
  let cg = extract_custom_geometry(body)
  debug_inspect(cg.extension.length(), content="1")
  debug_inspect(cg.extension[0].name.local_name, content="\"future\"")
}

///|
test "parse: unknown child of <a:path> is preserved on Path.extension" {
  let body = "<a:custGeom><a:pathLst>" +
    "<a:path><a:futureCmd foo=\"x\"/></a:path>" +
    "</a:pathLst></a:custGeom>"
  let cg = extract_custom_geometry(body)
  let p = cg.paths[0]
  debug_inspect(p.commands.length(), content="0")
  debug_inspect(p.extension.length(), content="1")
  debug_inspect(p.extension[0].name.local_name, content="\"futureCmd\"")
}

// --- Multiple paths ---

///|
test "parse: multiple <a:path> children land in source order" {
  let body = "<a:custGeom><a:pathLst>" +
    "<a:path w=\"100\" h=\"100\"><a:moveTo><a:pt x=\"0\" y=\"0\"/></a:moveTo></a:path>" +
    "<a:path w=\"200\" h=\"200\"><a:moveTo><a:pt x=\"10\" y=\"10\"/></a:moveTo></a:path>" +
    "</a:pathLst></a:custGeom>"
  let cg = extract_custom_geometry(body)
  debug_inspect(cg.paths.length(), content="2")
  debug_inspect(cg.paths[0].w, content="Emu(100)")
  debug_inspect(cg.paths[1].w, content="Emu(200)")
}
