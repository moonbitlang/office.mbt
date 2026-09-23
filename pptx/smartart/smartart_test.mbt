// Modified for office.mbt: follow the workspace warning conventions.
// Unit tests for the `smartart` package.

///|
/// Count non-overlapping occurrences of `needle` in `s`.
fn count_occurrences(s : String, needle : String) -> Int {
  let mut count = 0
  let mut rest = s
  while rest.find(needle) is Some(off) {
    count = count + 1
    rest = rest[off + needle.length():].to_owned()
  }
  count
}

///|
test "list / process builders set kind + leaf nodes" {
  let l = @smartart.SmartArt::list(["A", "B", "C"])
  debug_inspect(l.kind, content="List")
  debug_inspect(l.nodes.length(), content="3")
  debug_inspect(l.nodes[0].text, content="\"A\"")
  debug_inspect(l.nodes[0].children.length(), content="0")
  let p = @smartart.SmartArt::process(["X"])
  debug_inspect(p.kind, content="Process")
  debug_inspect(p.nodes.length(), content="1")
}

///|
test "Node constructors + model equality" {
  let leaf = @smartart.Node::leaf("hi")
  debug_inspect(leaf == @smartart.Node::new("hi", []), content="true")
  let a = @smartart.SmartArt::list(["A", "B"])
  let b = @smartart.SmartArt::new(List, [
    @smartart.Node::leaf("A"),
    @smartart.Node::leaf("B"),
  ])
  debug_inspect(a == b, content="true")
}

///|
test "data_xml carries the node text, connections, and drawing ext" {
  let art = @smartart.SmartArt::list(["First", "Second"])
  let xml = @oxml.bytes_to_string(art.data_xml("rId7"))
  // Root + structure.
  debug_inspect(xml.find("<dgm:dataModel") is Some(_), content="true")
  debug_inspect(xml.find("type=\"doc\"") is Some(_), content="true")
  // One connection per node.
  debug_inspect(count_occurrences(xml, "<dgm:cxn "), content="2")
  // Node texts present.
  debug_inspect(xml.find("<a:t>First</a:t>") is Some(_), content="true")
  debug_inspect(xml.find("<a:t>Second</a:t>") is Some(_), content="true")
  // The dsp dataModelExt references the supplied drawing rel id.
  debug_inspect(
    xml.find("<dsp:dataModelExt relId=\"rId7\"") is Some(_),
    content="true",
  )
}

///|
test "drawing_xml lays out one shape per node" {
  let art = @smartart.SmartArt::list(["A", "B", "C"])
  let xml = @oxml.bytes_to_string(
    art.drawing_xml(cx=Emu(6_000_000L), cy=Emu(3_000_000L)),
  )
  debug_inspect(xml.find("<dsp:drawing") is Some(_), content="true")
  debug_inspect(count_occurrences(xml, "<dsp:sp "), content="3")
  debug_inspect(xml.find("<a:t>B</a:t>") is Some(_), content="true")
  debug_inspect(xml.find("prst=\"roundRect\"") is Some(_), content="true")
}

///|
test "layout_xml direction differs List vs Process" {
  let list_xml = @oxml.bytes_to_string(
    @smartart.SmartArt::list(["A"]).layout_xml(),
  )
  debug_inspect(list_xml.find("val=\"fromT\"") is Some(_), content="true")
  let proc_xml = @oxml.bytes_to_string(
    @smartart.SmartArt::process(["A"]).layout_xml(),
  )
  debug_inspect(proc_xml.find("val=\"fromL\"") is Some(_), content="true")
}

///|
test "cycle / pyramid builders + layout algorithms" {
  let c = @smartart.SmartArt::cycle(["A", "B", "C", "D"])
  debug_inspect(c.kind, content="Cycle")
  debug_inspect(c.nodes.length(), content="4")
  let p = @smartart.SmartArt::pyramid(["Top", "Mid", "Base"])
  debug_inspect(p.kind, content="Pyramid")
  // Layout defs carry the right algorithm type.
  debug_inspect(
    @oxml.bytes_to_string(c.layout_xml()).find("type=\"cycle\"") is Some(_),
    content="true",
  )
  debug_inspect(
    @oxml.bytes_to_string(p.layout_xml()).find("type=\"pyra\"") is Some(_),
    content="true",
  )
}

///|
test "org_chart data model: parent/child connections + all nodes drawn" {
  // CEO over CTO + CFO (CFO has one report) → 4 nodes total.
  let ceo = @smartart.Node::new("CEO", [
    @smartart.Node::leaf("CTO"),
    @smartart.Node::new("CFO", [@smartart.Node::leaf("Controller")]),
  ])
  let art = @smartart.SmartArt::org_chart(ceo)
  debug_inspect(art.kind, content="OrgChart")
  let data = @oxml.bytes_to_string(art.data_xml("rId1"))
  // One connection per node (every node has an incoming edge).
  debug_inspect(count_occurrences(data, "<dgm:cxn "), content="4")
  // Exactly one edge originates at the document root (the single CEO root);
  // the other three originate at a node (parent → child).
  debug_inspect(count_occurrences(data, "srcId=\"0\""), content="1")
  // Every node's text is present, including the nested ones.
  for label in ["CEO", "CTO", "CFO", "Controller"] {
    debug_inspect(
      data.find("<a:t>" + label + "</a:t>") is Some(_),
      content="true",
    )
  }
  // The cached drawing lays out every node (not just the root) plus one
  // connector line per parent→child edge.
  let drawing = @oxml.bytes_to_string(
    art.drawing_xml(cx=Emu(8_000_000L), cy=Emu(5_000_000L)),
  )
  debug_inspect(count_occurrences(drawing, "<dsp:sp "), content="7")
  debug_inspect(count_occurrences(drawing, "prst=\"line\""), content="3")
  debug_inspect(count_occurrences(drawing, "prst=\"roundRect\""), content="4")
  assert_well_formed(data)
  assert_well_formed(drawing)
  assert_well_formed(@oxml.bytes_to_string(art.layout_xml()))
}

///|
test "hier layoutDef recurses + wires connectors" {
  let xml = @oxml.bytes_to_string(
    @smartart.SmartArt::org_chart(@smartart.Node::leaf("CEO")).layout_xml(),
  )
  // The recursive skeleton: hierRoot/hierChild composites and the named
  // forEach re-invoked by reference — the piece the single-level template
  // lacked (nesting families rendered top-level only).
  debug_inspect(count_occurrences(xml, "type=\"hierRoot\""), content="2")
  debug_inspect(
    xml.find("<dgm:forEach name=\"childForEach\"") is Some(_),
    content="true",
  )
  debug_inspect(
    xml.find("<dgm:forEach name=\"recurseForEach\" ref=\"childForEach\"/>")
    is Some(_),
    content="true",
  )
  // Parent→child connectors ride the parTrans points.
  debug_inspect(xml.find("type=\"conn\"") is Some(_), content="true")
  debug_inspect(xml.find("ptType=\"parTrans\"") is Some(_), content="true")
  // Every text node names its styleLbl explicitly — PowerPoint Web
  // renders an absent styleLbl as black boxes (2026-07-06 finding).
  debug_inspect(
    xml.find("name=\"rootNode\" styleLbl=\"node0\"") is Some(_),
    content="true",
  )
  debug_inspect(
    xml.find("name=\"childNode\" styleLbl=\"node1\"") is Some(_),
    content="true",
  )
  // Org-chart identity + the org-chart UI variable.
  debug_inspect(xml.find("orgChart1") is Some(_), content="true")
  debug_inspect(
    xml.find("<dgm:orgChart val=\"1\"/>") is Some(_),
    content="true",
  )
  assert_well_formed(xml)
  // Hierarchy shares the skeleton without the org-chart variable.
  let hxml = @oxml.bytes_to_string(
    @smartart.SmartArt::hierarchy([@smartart.Node::leaf("A")]).layout_xml(),
  )
  debug_inspect(hxml.find("hierarchy1") is Some(_), content="true")
  debug_inspect(hxml.find("<dgm:orgChart") is None, content="true")
  debug_inspect(hxml.find("ref=\"childForEach\"") is Some(_), content="true")
  assert_well_formed(hxml)
}

///|
test "drawing connector geometry: bounding box + flipH" {
  // Root centred over two children in a wide frame: the left child's
  // connector runs down-left (flipH), the right child's down-right (no
  // flip). Both span from the parent box's bottom centre to the child's
  // top centre, so their exts are equal and non-degenerate.
  let art = @smartart.SmartArt::org_chart(
    @smartart.Node::new("Root", [
      @smartart.Node::leaf("L"),
      @smartart.Node::leaf("R"),
    ]),
  )
  let xml = @oxml.bytes_to_string(
    art.drawing_xml(cx=Emu(8_000_000L), cy=Emu(4_000_000L)),
  )
  debug_inspect(count_occurrences(xml, "prst=\"line\""), content="2")
  debug_inspect(count_occurrences(xml, "flipH=\"1\""), content="1")
}

///|
test "radial layoutDef pins the hub and rings the spokes" {
  let xml = @oxml.bytes_to_string(
    @smartart.SmartArt::relationship(@smartart.Node::leaf("Core"), [
      @smartart.Node::leaf("A"),
    ]).layout_xml(),
  )
  // cycle + ctrShpMap="fNode" = hub-and-spoke; conn lines per parTrans.
  debug_inspect(xml.find("type=\"cycle\"") is Some(_), content="true")
  debug_inspect(xml.find("val=\"fNode\"") is Some(_), content="true")
  debug_inspect(xml.find("type=\"conn\"") is Some(_), content="true")
  debug_inspect(xml.find("radial1") is Some(_), content="true")
  assert_well_formed(xml)
}

///|
test "hierarchy forest: two roots both connect to the document" {
  let art = @smartart.SmartArt::hierarchy([
    @smartart.Node::new("A", [@smartart.Node::leaf("A1")]),
    @smartart.Node::new("B", [@smartart.Node::leaf("B1")]),
  ])
  debug_inspect(art.kind, content="Hierarchy")
  let data = @oxml.bytes_to_string(art.data_xml("rId1"))
  debug_inspect(count_occurrences(data, "<dgm:cxn "), content="4")
  // Two roots → two edges from the document root.
  debug_inspect(count_occurrences(data, "srcId=\"0\""), content="2")
  debug_inspect(
    @oxml.bytes_to_string(art.layout_xml()).find("hierarchy1") is Some(_),
    content="true",
  )
}

///|
test "matrix grid + relationship hub layouts" {
  // Matrix: four items → 2×2 grid, four boxes.
  let m = @smartart.SmartArt::matrix(["Q1", "Q2", "Q3", "Q4"])
  debug_inspect(m.kind, content="Matrix")
  let mxml = @oxml.bytes_to_string(
    m.drawing_xml(cx=Emu(5_000_000L), cy=Emu(5_000_000L)),
  )
  debug_inspect(count_occurrences(mxml, "<dsp:sp "), content="4")
  debug_inspect(
    @oxml.bytes_to_string(m.layout_xml()).find("matrix1") is Some(_),
    content="true",
  )
  // Relationship: hub + 3 spokes → 4 nodes; the spokes connect to the hub.
  let r = @smartart.SmartArt::relationship(@smartart.Node::leaf("Core"), [
    @smartart.Node::leaf("People"),
    @smartart.Node::leaf("Process"),
    @smartart.Node::leaf("Tools"),
  ])
  debug_inspect(r.kind, content="Relationship")
  let rdata = @oxml.bytes_to_string(r.data_xml("rId1"))
  debug_inspect(count_occurrences(rdata, "<dgm:cxn "), content="4")
  // One edge from the doc (the hub), three from the hub node (the spokes).
  debug_inspect(count_occurrences(rdata, "srcId=\"0\""), content="1")
  let rxml = @oxml.bytes_to_string(
    r.drawing_xml(cx=Emu(5_000_000L), cy=Emu(5_000_000L)),
  )
  // Four boxes + three hub→spoke connector lines.
  debug_inspect(count_occurrences(rxml, "<dsp:sp "), content="7")
  debug_inspect(count_occurrences(rxml, "prst=\"line\""), content="3")
  // All parts well-formed for both families.
  assert_well_formed(mxml)
  assert_well_formed(rdata)
  assert_well_formed(rxml)
  assert_well_formed(@oxml.bytes_to_string(r.layout_xml()))
}

///|
test "cycle / pyramid drawings lay out one box per node" {
  let c = @smartart.SmartArt::cycle(["A", "B", "C", "D"])
  let cxml = @oxml.bytes_to_string(
    c.drawing_xml(cx=Emu(5_000_000L), cy=Emu(5_000_000L)),
  )
  debug_inspect(count_occurrences(cxml, "<dsp:sp "), content="4")
  let p = @smartart.SmartArt::pyramid(["Top", "Mid", "Base"])
  let pxml = @oxml.bytes_to_string(
    p.drawing_xml(cx=Emu(5_000_000L), cy=Emu(3_000_000L)),
  )
  debug_inspect(count_occurrences(pxml, "<dsp:sp "), content="3")
  // All generated parts well-formed for the new families too.
  assert_well_formed(cxml)
  assert_well_formed(pxml)
  assert_well_formed(@oxml.bytes_to_string(c.data_xml("rId1")))
  assert_well_formed(@oxml.bytes_to_string(p.layout_xml()))
}

///|
test "colors + quickStyle parts are well-formed roots" {
  let art = @smartart.SmartArt::list(["A"])
  let colors = @oxml.bytes_to_string(art.colors_xml())
  debug_inspect(colors.find("<dgm:colorsDef") is Some(_), content="true")
  let qs = @oxml.bytes_to_string(art.quick_style_xml())
  debug_inspect(qs.find("<dgm:styleDef") is Some(_), content="true")
}

///|
/// Drain the streaming reader to completion — raises on malformed XML.
fn assert_well_formed(xml : String) -> Unit raise {
  let r = @xml.XmlReader::new(xml)
  while r.next() is Some(_) {

  }
}

///|
test "all generated parts are well-formed XML" {
  let art = @smartart.SmartArt::process(["Alpha", "Beta < Gamma"])
  assert_well_formed(@oxml.bytes_to_string(art.data_xml("rId1")))
  assert_well_formed(
    @oxml.bytes_to_string(art.drawing_xml(cx=Emu(100L), cy=Emu(100L))),
  )
  assert_well_formed(@oxml.bytes_to_string(art.layout_xml()))
  assert_well_formed(@oxml.bytes_to_string(art.colors_xml()))
  assert_well_formed(@oxml.bytes_to_string(art.quick_style_xml()))
}

///|
test "Node style builders merge aspects on one style" {
  let red = @units.RgbColor::new(0xFF, 0x00, 0x00)
  let white = @units.RgbColor::new(0xFF, 0xFF, 0xFF)
  let n = @smartart.Node::leaf("Hot").with_fill(red).with_text_color(white)
  match n.style {
    Some(s) => {
      debug_inspect(s.fill == Some(red), content="true")
      debug_inspect(s.text_color == Some(white), content="true")
      debug_inspect(s.line, content="None")
    }
    None => fail("expected a style")
  }
  // Styling doesn't disturb the rest of the node.
  debug_inspect(n.text, content="\"Hot\"")
  debug_inspect(n.children.length(), content="0")
  let s = @smartart.NodeStyle::new(line=red)
  debug_inspect(s.line == Some(red), content="true")
  debug_inspect(s.fill == None && s.text_color == None, content="true")
}

///|
test "data_xml carries per-node colour overrides" {
  let red = @units.RgbColor::new(0xFF, 0x00, 0x00)
  let blue = @units.RgbColor::new(0x00, 0x00, 0xFF)
  let white = @units.RgbColor::new(0xFF, 0xFF, 0xFF)
  let art = @smartart.SmartArt::new(List, [
    @smartart.Node::leaf("Hot")
    .with_fill(red)
    .with_line(blue)
    .with_text_color(white),
    @smartart.Node::leaf("Plain"),
  ])
  let xml = @oxml.bytes_to_string(art.data_xml("rId1"))
  // Fill + line ride the styled point's <dgm:spPr>.
  debug_inspect(
    xml.find("<a:srgbClr val=\"FF0000\"") is Some(_),
    content="true",
  )
  debug_inspect(
    xml.find("<a:ln><a:solidFill><a:srgbClr val=\"0000FF\"") is Some(_),
    content="true",
  )
  // The text colour rides the run properties, flagged as a manual
  // customisation — and only on the styled node.
  debug_inspect(
    xml.find("<a:rPr lang=\"en-US\"><a:solidFill><a:srgbClr val=\"FFFFFF\"")
    is Some(_),
    content="true",
  )
  debug_inspect(count_occurrences(xml, "custT=\"1\""), content="1")
  // The unstyled node keeps an empty <dgm:spPr>.
  debug_inspect(count_occurrences(xml, "<dgm:spPr/>") >= 1, content="true")
}

///|
test "drawing_xml overrides the styled box, keeps quick-style defaults elsewhere" {
  let red = @units.RgbColor::new(0xFF, 0x00, 0x00)
  let white = @units.RgbColor::new(0xFF, 0xFF, 0xFF)
  let art = @smartart.SmartArt::new(List, [
    @smartart.Node::leaf("Hot").with_fill(red).with_text_color(white),
    @smartart.Node::leaf("Plain"),
  ])
  let xml = @oxml.bytes_to_string(
    art.drawing_xml(cx=Emu(6_000_000L), cy=Emu(3_000_000L)),
  )
  // The styled box fills FF0000; the unstyled one keeps accent1.
  debug_inspect(
    xml.find("<a:srgbClr val=\"FF0000\"") is Some(_),
    content="true",
  )
  debug_inspect(
    count_occurrences(xml, "schemeClr val=\"accent1\""),
    content="1",
  )
  // Its text run carries the white override.
  debug_inspect(
    xml.find("<a:srgbClr val=\"FFFFFF\"") is Some(_),
    content="true",
  )
  // The outline wasn't overridden, so both boxes keep the lt1 default.
  debug_inspect(count_occurrences(xml, "schemeClr val=\"lt1\""), content="2")
}
