// Lossless preservation tests (ADR-004) for slide-level + shape-level
// `extension` arrays. The fixtures intentionally pack in elements the
// typed parsers do *not* model (transition / timing / style / extLst /
// graphicFrame / foreign-namespace nodes) and assert that every one
// survives the parse.

///|
/// Find the captured `<p:transition>` (or any other element by local name)
/// inside a `Slide.extension` array. Returns the first match, or `None`.
fn find_ext(slide : @slide.Slide, local_name : String) -> @xml.XmlElement? {
  for el in slide.extension {
    if el.name.local_name == local_name {
      return Some(el)
    }
  }
  None
}

// --- Slide.extension captures the top-level non-shape children. ---

///|
test "ADR-004: slide-level timing survives parse; transition lifts to typed field" {
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\">" +
    "<p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>" +
    "</p:spTree></p:cSld>" +
    "<p:transition spd=\"med\"><p:fade/></p:transition>" +
    "<p:timing/>" +
    "</p:sld>"
  let slide = @slide.Slide::parse(@oxml.string_to_bytes(xml))
  // `<p:transition>` is now the typed `Slide.transition` field, so it must
  // *not* appear in extension (mirrors the `<p:bg>` lift below).
  debug_inspect(find_ext(slide, "transition") is None, content="true")
  match slide.transition {
    Some(t) => {
      debug_inspect(t.speed, content="Medium")
      debug_inspect(t.kind, content="Fade(false)")
    }
    None => fail("expected a typed transition")
  }
  // `<p:timing>` is still unmodelled and round-trips via extension.
  let timing = find_ext(slide, "timing")
  debug_inspect(timing is Some(_), content="true")
}

///|
test "<p:cSld><p:bg> lifts into the typed background field, not extension" {
  // Previously this `<p:bg>` round-tripped through `Slide.extension`; it is now
  // the typed `Slide.background` field, so it must *not* appear in extension.
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\">" +
    "<p:cSld>" +
    "<p:bg><p:bgRef idx=\"1001\"><a:schemeClr val=\"bg1\"/></p:bgRef></p:bg>" +
    "<p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>" +
    "</p:spTree>" +
    "</p:cSld>" +
    "</p:sld>"
  let slide = @slide.Slide::parse(@oxml.string_to_bytes(xml))
  debug_inspect(find_ext(slide, "bg") is None, content="true")
  match slide.background {
    Some(StyleReference(idx, _)) => debug_inspect(idx, content="1001")
    _ => fail("expected a typed StyleReference background")
  }
}

///|
test "ADR-004: foreign-namespace <p:sld> child is preserved" {
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\" xmlns:x=\"http://example.org/ext\">" +
    "<p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>" +
    "</p:spTree></p:cSld>" +
    "<x:custom payload=\"42\"/>" +
    "</p:sld>"
  let slide = @slide.Slide::parse(@oxml.string_to_bytes(xml))
  let custom = find_ext(slide, "custom")
  debug_inspect(custom is Some(_), content="true")
  let c = custom.unwrap()
  debug_inspect(c.name.uri, content="\"http://example.org/ext\"")
  debug_inspect(c.attributes[0].0.local_name, content="\"payload\"")
  debug_inspect(c.attributes[0].1, content="\"42\"")
}

// --- Shape::GraphicFrame chart content lifts to ChartContent(rid). ---

///|
test "chart graphicFrame lifts to GraphicFrame(ChartContent)" {
  // Chart embedded in a graphicFrame. The chart-uri case lifts
  // alongside the table-uri case: the slide-side body is just
  // `<c:chart r:id="…"/>`, so we lift the rel id to `ChartContent(rid)`
  // and leave the actual chart data (in a separate `chartN.xml` part)
  // to `@presentation.Presentation::charts()`.
  let chart_uri = "http://schemas.openxmlformats.org/drawingml/2006/chart"
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\" xmlns:r=\"" +
    off_rel_ns +
    "\" xmlns:c=\"" +
    chart_uri +
    "\">" +
    "<p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>" +
    "<p:graphicFrame>" +
    "<p:nvGraphicFramePr><p:cNvPr id=\"5\" name=\"Chart 1\"/><p:cNvGraphicFramePr/><p:nvPr/></p:nvGraphicFramePr>" +
    "<p:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"100\" cy=\"200\"/></p:xfrm>" +
    "<a:graphic><a:graphicData uri=\"" +
    chart_uri +
    "\"><c:chart r:id=\"rId7\"/></a:graphicData></a:graphic>" +
    "</p:graphicFrame>" +
    "</p:spTree></p:cSld>" +
    "</p:sld>"
  let slide = @slide.Slide::parse(@oxml.string_to_bytes(xml))
  debug_inspect(slide.shapes.length(), content="1")
  match slide.shapes[0] {
    GraphicFrame(gf) => {
      debug_inspect(gf.id, content="5")
      debug_inspect(gf.name, content="\"Chart 1\"")
      match gf.content {
        ChartContent(rid) => debug_inspect(rid, content="\"rId7\"")
        _ => fail("expected ChartContent for chart uri")
      }
    }
    _ => fail("expected GraphicFrame shape")
  }
}

// --- AutoShape.extension captures sibling elements like <p:style>. ---

///|
test "ADR-004: AutoShape preserves <p:style> in extension" {
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
    "<p:spPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"100\" cy=\"100\"/></a:xfrm></p:spPr>" +
    "<p:style><a:lnRef idx=\"2\"><a:schemeClr val=\"accent1\"/></a:lnRef></p:style>" +
    "</p:sp>" +
    "</p:spTree></p:cSld>" +
    "</p:sld>"
  let slide = @slide.Slide::parse(@oxml.string_to_bytes(xml))
  match slide.shapes[0] {
    AutoShape(s) => {
      // Find <p:style> in the extension. The parser also captures
      // <p:cNvPr>, <p:cNvSpPr> etc. from inside <p:nvSpPr>, so there
      // are several entries — assert on the one we care about by name.
      let style = find_local(s.extension, "style").unwrap()
      debug_inspect(style.children.length(), content="1")
      match style.children[0] {
        Element(ln_ref) =>
          debug_inspect(ln_ref.name.local_name, content="\"lnRef\"")
        _ => fail("expected <a:lnRef> child of <p:style>")
      }
    }
    _ => fail("expected AutoShape")
  }
}

///|
/// Locate an element by local name inside an `extension` array.
fn find_local(
  extension : Array[@xml.XmlElement],
  local_name : String,
) -> @xml.XmlElement? {
  for el in extension {
    if el.name.local_name == local_name {
      return Some(el)
    }
  }
  None
}

// --- Picture.extension and Connector.extension behave the same way. ---

///|
test "ADR-004: Picture preserves <p:extLst> in extension" {
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\" xmlns:r=\"" +
    off_rel_ns +
    "\">" +
    "<p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>" +
    "<p:pic>" +
    "<p:nvPicPr><p:cNvPr id=\"4\" name=\"P\"/><p:cNvPicPr/><p:nvPr/></p:nvPicPr>" +
    "<p:blipFill><a:blip r:embed=\"rId2\"/><a:stretch><a:fillRect/></a:stretch></p:blipFill>" +
    "<p:spPr/>" +
    "<p:extLst><p:ext uri=\"{x}\"><p:custom/></p:ext></p:extLst>" +
    "</p:pic>" +
    "</p:spTree></p:cSld>" +
    "</p:sld>"
  let slide = @slide.Slide::parse(@oxml.string_to_bytes(xml))
  match slide.shapes[0] {
    Picture(p) =>
      debug_inspect(
        find_local(p.extension, "extLst") is Some(_),
        content="true",
      )
    _ => fail("expected Picture")
  }
}

///|
test "ADR-004: Connector preserves <p:style> in extension" {
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\">" +
    "<p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>" +
    "<p:cxnSp>" +
    "<p:nvCxnSpPr><p:cNvPr id=\"6\" name=\"C\"/><p:cNvCxnSpPr/><p:nvPr/></p:nvCxnSpPr>" +
    "<p:spPr/>" +
    "<p:style><a:lnRef idx=\"1\"/></p:style>" +
    "</p:cxnSp>" +
    "</p:spTree></p:cSld>" +
    "</p:sld>"
  let slide = @slide.Slide::parse(@oxml.string_to_bytes(xml))
  match slide.shapes[0] {
    Connector(c) =>
      debug_inspect(find_local(c.extension, "style") is Some(_), content="true")
    _ => fail("expected Connector")
  }
}

///|
test "ADR-004: GroupShape captures foreign-namespace siblings" {
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\" xmlns:x=\"http://example.org/ext\">" +
    "<p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>" +
    "<p:grpSp>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"10\" name=\"G\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr/>" +
    "<x:special tag=\"1\"/>" +
    "</p:grpSp>" +
    "</p:spTree></p:cSld>" +
    "</p:sld>"
  let slide = @slide.Slide::parse(@oxml.string_to_bytes(xml))
  match slide.shapes[0] {
    Group(g) => {
      let special = find_local(g.extension, "special").unwrap()
      debug_inspect(special.name.uri, content="\"http://example.org/ext\"")
    }
    _ => fail("expected Group")
  }
}
