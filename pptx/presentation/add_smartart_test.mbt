// Modified for office.mbt: follow the workspace warning conventions.
// Tests for `Presentation::add_smartart_mut`.

///|
/// Find the `<dgm:relIds>` element inside a SmartArt graphicFrame's captured
/// `<a:graphicData>` body, then read one `r:*` attribute by local name.
fn rel_ids_attr(captured : @xml.XmlElement, lname : String) -> String? {
  for child in captured.children {
    match child {
      Element(e) =>
        if e.name.local_name == "relIds" {
          for kv in e.attributes {
            if kv.0.local_name == lname {
              return Some(kv.1)
            }
          }
        }
      _ => ()
    }
  }
  None
}

///|
test "add_smartart_mut: wires five diagram parts with content types" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let art = @smartart.SmartArt::list(["Plan", "Build", "Ship"])
  prs.add_smartart_mut(
    0,
    art,
    x=Emu(914_400L),
    y=Emu(914_400L),
    cx=Emu(6_858_000L),
    cy=Emu(4_572_000L),
  )
  // Five parts with the right content types.
  let cases = [
    ("/ppt/diagrams/data1.xml", @oxml.ct_diagram_data),
    ("/ppt/diagrams/layout1.xml", @oxml.ct_diagram_layout),
    ("/ppt/diagrams/quickStyle1.xml", @oxml.ct_diagram_style),
    ("/ppt/diagrams/colors1.xml", @oxml.ct_diagram_colors),
    ("/ppt/drawings/drawing1.xml", @oxml.ct_diagram_drawing),
  ]
  for c in cases {
    let part = prs.opc_package().part_by_name(c.0).unwrap()
    debug_inspect(part.content_type == c.1, content="true")
    // Each part is registered as an Override.
    debug_inspect(
      prs
      .opc_package()
      .content_types()
      .overrides()
      .iter()
      .any(kv => kv.0 == c.0 && kv.1 == c.1),
      content="true",
    )
  }
}

///|
test "add_smartart_mut: graphicFrame carries the four diagram relIds" {
  let prs = @presentation.Presentation::new()
  let slide_name = prs.add_slide_mut(0)
  prs.add_smartart_mut(
    0,
    @smartart.SmartArt::process(["A", "B"]),
    x=Emu(0L),
    y=Emu(0L),
    cx=Emu(6_000_000L),
    cy=Emu(2_000_000L),
  )
  let slide = prs.slides()[0]
  debug_inspect(slide.shapes.length(), content="1")
  let captured = match slide.shapes[0] {
    GraphicFrame(gf) =>
      match gf.content {
        OtherGraphic(uri, el) => {
          debug_inspect(uri == @oxml.graphic_data_diagram_uri, content="true")
          el
        }
        _ => fail("expected OtherGraphic (SmartArt) content")
      }
    _ => fail("expected GraphicFrame")
  }
  // The four relIds reference real slide relationships.
  let rels = prs.opc_package().relationships_for(slide_name)
  for lname in ["dm", "lo", "qs", "cs"] {
    let rid = rel_ids_attr(captured, lname).unwrap()
    debug_inspect(rels.by_id(rid) is Some(_), content="true")
  }
  // dm points at the data part, cs at the colors part.
  let dm = rel_ids_attr(captured, "dm").unwrap()
  debug_inspect(
    rels.by_id(dm).unwrap().rel_type == @opc.rt_diagram_data,
    content="true",
  )
  let cs = rel_ids_attr(captured, "cs").unwrap()
  debug_inspect(
    rels.by_id(cs).unwrap().rel_type == @opc.rt_diagram_colors,
    content="true",
  )
}

///|
test "add_smartart_mut: data part references the cached drawing" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.add_smartart_mut(
    0,
    @smartart.SmartArt::list(["One"]),
    x=Emu(0L),
    y=Emu(0L),
    cx=Emu(100L),
    cy=Emu(100L),
  )
  // The data part's rels point at the drawing via the diagramDrawing rel.
  let data_rels = prs.opc_package().relationships_for("/ppt/diagrams/data1.xml")
  let drawing_rel = data_rels
    .items()
    .iter()
    .find_first(r => r.rel_type == @opc.rt_diagram_drawing)
    .unwrap()
  debug_inspect(drawing_rel.target.contains("drawing1.xml"), content="true")
  // And the data model records that relId inside <dsp:dataModelExt>.
  let data_part = prs
    .opc_package()
    .part_by_name("/ppt/diagrams/data1.xml")
    .unwrap()
  let xml = @oxml.bytes_to_string(data_part.bytes())
  debug_inspect(xml.find("dataModelExt") is Some(_), content="true")
  debug_inspect(
    xml.find("relId=\"" + drawing_rel.id + "\"") is Some(_),
    content="true",
  )
}

///|
test "add_smartart_mut: survives save -> reopen" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.add_smartart_mut(
    0,
    @smartart.SmartArt::list(["Plan", "Build", "Ship"]),
    x=Emu(0L),
    y=Emu(0L),
    cx=Emu(6_000_000L),
    cy=Emu(4_000_000L),
  )
  let prs2 = @presentation.Presentation::open(prs.save())
  // All five parts survive.
  for
    name in [
      "/ppt/diagrams/data1.xml", "/ppt/diagrams/layout1.xml", "/ppt/diagrams/quickStyle1.xml",
      "/ppt/diagrams/colors1.xml", "/ppt/drawings/drawing1.xml",
    ] {
    debug_inspect(
      prs2.opc_package().part_by_name(name) is Some(_),
      content="true",
    )
  }
  // The graphicFrame survives as SmartArt content.
  let slide = prs2.slides()[0]
  debug_inspect(slide.shapes.length(), content="1")
  match slide.shapes[0] {
    GraphicFrame(gf) =>
      match gf.content {
        OtherGraphic(uri, _) =>
          debug_inspect(uri == @oxml.graphic_data_diagram_uri, content="true")
        _ => fail("expected OtherGraphic after reopen")
      }
    _ => fail("expected GraphicFrame after reopen")
  }
}

///|
test "add_smartart_mut: escapes node text in data + drawing parts" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.add_smartart_mut(
    0,
    @smartart.SmartArt::list(["A < B & C"]),
    x=Emu(0L),
    y=Emu(0L),
    cx=Emu(100L),
    cy=Emu(100L),
  )
  let data = prs.opc_package().part_by_name("/ppt/diagrams/data1.xml").unwrap()
  let xml = @oxml.bytes_to_string(data.bytes())
  debug_inspect(xml.find("A &lt; B &amp; C") is Some(_), content="true")
  // The raw unescaped form must not appear as element text.
  debug_inspect(xml.find("A < B & C") is None, content="true")
}

///|
test "add_smartart_mut: second diagram gets index 2 across all parts" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.add_smartart_mut(
    0,
    @smartart.SmartArt::list(["x"]),
    x=Emu(0L),
    y=Emu(0L),
    cx=Emu(100L),
    cy=Emu(100L),
  )
  prs.add_smartart_mut(
    0,
    @smartart.SmartArt::process(["y"]),
    x=Emu(0L),
    y=Emu(0L),
    cx=Emu(100L),
    cy=Emu(100L),
  )
  debug_inspect(
    prs.opc_package().part_by_name("/ppt/diagrams/data2.xml") is Some(_),
    content="true",
  )
  debug_inspect(
    prs.opc_package().part_by_name("/ppt/drawings/drawing2.xml") is Some(_),
    content="true",
  )
  debug_inspect(prs.slides()[0].shapes.length(), content="2")
}

///|
test "add_smartart_mut: cycle + pyramid wire end-to-end and reopen" {
  for
    art in [
      @smartart.SmartArt::cycle(["A", "B", "C"]),
      @smartart.SmartArt::pyramid(["Top", "Mid", "Base"]),
    ] {
    let prs = @presentation.Presentation::new()
    let _ = prs.add_slide_mut(0)
    prs.add_smartart_mut(
      0,
      art,
      x=Emu(0L),
      y=Emu(0L),
      cx=Emu(5_000_000L),
      cy=Emu(3_000_000L),
    )
    let prs2 = @presentation.Presentation::open(prs.save())
    debug_inspect(
      prs2.opc_package().part_by_name("/ppt/diagrams/data1.xml") is Some(_),
      content="true",
    )
    debug_inspect(
      prs2.opc_package().part_by_name("/ppt/drawings/drawing1.xml") is Some(_),
      content="true",
    )
    debug_inspect(prs2.slides()[0].shapes.length(), content="1")
  }
}

///|
test "add_smartart_mut: org_chart with nested children wires + reopens" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let root = @smartart.Node::new("CEO", [
    @smartart.Node::leaf("Eng"),
    @smartart.Node::new("Ops", [@smartart.Node::leaf("Support")]),
  ])
  prs.add_smartart_mut(
    0,
    @smartart.SmartArt::org_chart(root),
    x=Emu(0L),
    y=Emu(0L),
    cx=Emu(8_000_000L),
    cy=Emu(5_000_000L),
  )
  // The cached drawing draws all four nodes plus one connector line per
  // parent→child edge.
  let drawing = @oxml.bytes_to_string(
    prs
    .opc_package()
    .part_by_name("/ppt/drawings/drawing1.xml")
    .unwrap()
    .bytes(),
  )
  let mut sp = 0
  let mut rest = drawing
  while rest.find("<dsp:sp ") is Some(off) {
    sp = sp + 1
    rest = rest[off + 8:].to_owned()
  }
  debug_inspect(sp, content="7")
  let prs2 = @presentation.Presentation::open(prs.save())
  debug_inspect(prs2.slides()[0].shapes.length(), content="1")
}

///|
test "add_smartart_mut: matrix + relationship wire end-to-end and reopen" {
  for
    art in [
      @smartart.SmartArt::matrix(["Q1", "Q2", "Q3", "Q4"]),
      @smartart.SmartArt::relationship(@smartart.Node::leaf("Hub"), [
        @smartart.Node::leaf("A"),
        @smartart.Node::leaf("B"),
      ]),
    ] {
    let prs = @presentation.Presentation::new()
    let _ = prs.add_slide_mut(0)
    prs.add_smartart_mut(
      0,
      art,
      x=Emu(0L),
      y=Emu(0L),
      cx=Emu(5_000_000L),
      cy=Emu(5_000_000L),
    )
    let prs2 = @presentation.Presentation::open(prs.save())
    debug_inspect(
      prs2.opc_package().part_by_name("/ppt/diagrams/data1.xml") is Some(_),
      content="true",
    )
    debug_inspect(prs2.slides()[0].shapes.length(), content="1")
  }
}

///|
test "add_smartart_mut: out-of-range slide_idx raises Malformed" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  try
    prs.add_smartart_mut(
      5,
      @smartart.SmartArt::list(["x"]),
      x=Emu(0L),
      y=Emu(0L),
      cx=Emu(100L),
      cy=Emu(100L),
    )
  catch {
    Malformed(_) => ()
    _ => fail("expected Malformed")
  } noraise {
    _ => fail("expected Malformed")
  }
}

///|
test "add_smartart_mut: empty diagram raises Malformed" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  try
    prs.add_smartart_mut(
      0,
      @smartart.SmartArt::list([]),
      x=Emu(0L),
      y=Emu(0L),
      cx=Emu(100L),
      cy=Emu(100L),
    )
  catch {
    Malformed(_) => ()
    _ => fail("expected Malformed")
  } noraise {
    _ => fail("expected Malformed")
  }
}
