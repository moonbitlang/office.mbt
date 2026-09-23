// Tests for PlaceholderType + Slide placeholder accessors.

///|
/// A slide whose spTree carries a representative spread of placeholders plus
/// one ordinary drawn shape. Placeholder kinds, in order:
///   ctrTitle · body(idx 1) · ftr · sldNum(idx 10) · content(no type → obj)
/// followed by a plain rectangle with no `<p:ph>` (skipped by accessors).
fn slide_with_placeholders() -> FixedArray[Byte] {
  fn ph_sp(id : Int, name : String, ph : String) -> String {
    "<p:sp><p:nvSpPr>" +
    "<p:cNvPr id=\"" +
    id.to_string() +
    "\" name=\"" +
    name +
    "\"/>" +
    "<p:cNvSpPr/><p:nvPr>" +
    ph +
    "</p:nvPr></p:nvSpPr>" +
    "<p:spPr/><p:txBody><a:bodyPr/><a:lstStyle/><a:p/></p:txBody></p:sp>"
  }

  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\" xmlns:r=\"" +
    off_rel_ns +
    "\"><p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr/>" +
    ph_sp(2, "Title 1", "<p:ph type=\"ctrTitle\"/>") +
    ph_sp(3, "Body 2", "<p:ph type=\"body\" idx=\"1\"/>") +
    ph_sp(4, "Footer 3", "<p:ph type=\"ftr\"/>") +
    ph_sp(5, "Slide Number 4", "<p:ph type=\"sldNum\" idx=\"10\"/>") +
    // No `type` attribute → spec default obj (content placeholder).
    ph_sp(6, "Content 5", "<p:ph idx=\"2\"/>") +
    // Ordinary drawn shape — no <p:ph>, so accessors must skip it.
    "<p:sp><p:nvSpPr><p:cNvPr id=\"7\" name=\"Rect 6\"/><p:cNvSpPr/><p:nvPr/>" +
    "</p:nvSpPr><p:spPr/></p:sp>" +
    "</p:spTree></p:cSld>" +
    "<p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>"
  @oxml.string_to_bytes(xml)
}

// --- PlaceholderType conversions ---

///|
test "PlaceholderType::from_xml maps known + default + unknown" {
  debug_inspect(@slide.PlaceholderType::from_xml("title"), content="Title")
  debug_inspect(
    @slide.PlaceholderType::from_xml("ctrTitle"),
    content="CtrTitle",
  )
  debug_inspect(@slide.PlaceholderType::from_xml("body"), content="Body")
  debug_inspect(@slide.PlaceholderType::from_xml("sldNum"), content="SldNum")
  debug_inspect(@slide.PlaceholderType::from_xml("pic"), content="Pic")
  // Explicit "obj" and an absent attribute both read as Obj.
  debug_inspect(@slide.PlaceholderType::from_xml("obj"), content="Obj")
  debug_inspect(@slide.PlaceholderType::from_xml(""), content="Obj")
  // Unmodelled value is preserved verbatim.
  debug_inspect(
    @slide.PlaceholderType::from_xml("foo"),
    content="Other(\"foo\")",
  )
}

///|
test "PlaceholderType::to_xml round-trips every modelled value" {
  let kinds : Array[@slide.PlaceholderType] = [
    Title,
    Body,
    CtrTitle,
    SubTitle,
    Dt,
    SldNum,
    Ftr,
    Hdr,
    Obj,
    Chart,
    Tbl,
    ClipArt,
    Dgm,
    Media,
    SldImg,
    Pic,
  ]
  for k in kinds {
    debug_inspect(
      @slide.PlaceholderType::from_xml(k.to_xml()) == k,
      content="true",
    )
  }
  // Other carries its raw string through to_xml.
  debug_inspect(
    (Other("custom") : @slide.PlaceholderType).to_xml(),
    content="\"custom\"",
  )
}

///|
test "Placeholder::kind reads the raw ph_type" {
  let slide = @slide.Slide::parse(slide_with_placeholders())
  match slide.shapes[4] {
    AutoShape(s) => {
      let ph = s.placeholder.unwrap()
      debug_inspect(ph.ph_type, content="\"\"") // attribute was absent
      debug_inspect(ph.kind(), content="Obj") // …and reads as the spec default
    }
    _ => fail("expected AutoShape at index 4")
  }
}

// --- Slide accessors ---

///|
test "Slide::placeholders lists kinds in source order, skips non-placeholders" {
  let slide = @slide.Slide::parse(slide_with_placeholders())
  let kinds = slide.placeholders().map(pair => pair.0)
  debug_inspect(kinds, content="[CtrTitle, Body, Ftr, SldNum, Obj]")
}

///|
test "Slide::title matches ctrTitle" {
  let slide = @slide.Slide::parse(slide_with_placeholders())
  match slide.title() {
    Some(AutoShape(s)) => debug_inspect(s.id, content="2")
    _ => fail("expected the ctrTitle placeholder")
  }
}

///|
test "Slide::title also matches a plain title placeholder" {
  let xml = "<?xml version=\"1.0\"?><p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\"><p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr/>" +
    "<p:sp><p:nvSpPr><p:cNvPr id=\"9\" name=\"Title\"/><p:cNvSpPr/>" +
    "<p:nvPr><p:ph type=\"title\"/></p:nvPr></p:nvSpPr><p:spPr/></p:sp>" +
    "</p:spTree></p:cSld></p:sld>"
  let slide = @slide.Slide::parse(@oxml.string_to_bytes(xml))
  match slide.title() {
    Some(AutoShape(s)) => debug_inspect(s.id, content="9")
    _ => fail("expected the title placeholder")
  }
}

///|
test "Slide::body matches body, not content/obj" {
  let slide = @slide.Slide::parse(slide_with_placeholders())
  match slide.body() {
    Some(AutoShape(s)) => debug_inspect(s.id, content="3")
    _ => fail("expected the body placeholder")
  }
}

///|
test "Slide::placeholder finds a specific kind by index" {
  let slide = @slide.Slide::parse(slide_with_placeholders())
  match slide.placeholder(SldNum) {
    Some(AutoShape(s)) => {
      debug_inspect(s.id, content="5")
      debug_inspect(s.placeholder.unwrap().idx, content="10")
    }
    _ => fail("expected the slide-number placeholder")
  }
  // The no-type content placeholder is reachable as Obj.
  match slide.placeholder(Obj) {
    Some(AutoShape(s)) => debug_inspect(s.id, content="6")
    _ => fail("expected the content placeholder via Obj")
  }
}

///|
test "Slide accessors return None when the kind is absent" {
  let slide = @slide.Slide::parse(slide_with_placeholders())
  debug_inspect(slide.placeholder(Chart) is None, content="true")
  debug_inspect(slide.placeholder(SubTitle) is None, content="true")
  // A slide with no placeholders at all.
  let bare = "<?xml version=\"1.0\"?><p:sld xmlns:p=\"" +
    pml_ns +
    "\"><p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr/></p:spTree></p:cSld></p:sld>"
  let empty = @slide.Slide::parse(@oxml.string_to_bytes(bare))
  debug_inspect(empty.placeholders().length(), content="0")
  debug_inspect(empty.title() is None, content="true")
  debug_inspect(empty.body() is None, content="true")
}
