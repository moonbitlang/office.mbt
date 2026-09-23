// Modified for office.mbt: follow the workspace warning conventions.
// Tests for shape-level hyperlinks:
// `AutoShape` / `Picture` `with_hyperlink` / `with_hyperlink_to_slide`,
// resolved by `update_slide_mut` (shared resolver with run hyperlinks).

///|
/// Decoded XML of the named slide part.
fn slide_xml_of(prs : @presentation.Presentation, name : String) -> String {
  @oxml.bytes_to_string(prs.opc_package().part_by_name(name).unwrap().bytes()) catch {
    _ => abort("slide part is not valid UTF-8")
  }
}

///|
test "shape with_hyperlink: external URL → rel + <a:hlinkClick> on cNvPr" {
  let prs = @presentation.Presentation::new()
  let slide_name = prs.add_slide_mut(0)
  let box = @slide.AutoShape::rect(
    id=2,
    name="btn",
    x=Emu(914_400L),
    y=Emu(914_400L),
    cx=Emu(2_000_000L),
    cy=Emu(800_000L),
  ).with_hyperlink(url="https://example.com")
  prs.update_slide_mut(0, prs.slides()[0].with_shape(AutoShape(box)))
  // A TargetMode::External hyperlink rel is registered on the slide.
  let rels = prs.opc_package().relationships_for(slide_name)
  let hl = rels.by_type(@opc.rt_hyperlink)[0]
  debug_inspect(hl.target, content="\"https://example.com\"")
  debug_inspect(hl.target_mode is External, content="true")
  // The slide XML carries an <a:hlinkClick> referencing that rId.
  let xml = slide_xml_of(prs, slide_name)
  debug_inspect(xml.contains("hlinkClick"), content="true")
  debug_inspect(xml.contains("r:id=\"" + hl.id + "\""), content="true")
}

///|
test "shape with_hyperlink_to_slide: rt_slide rel + ppaction jump" {
  let prs = @presentation.Presentation::new()
  let slide_name = prs.add_slide_mut(0)
  let _ = prs.add_slide_mut(0) // target slide index 1 exists
  let box = @slide.AutoShape::rect(
    id=2,
    name="nav",
    x=Emu(0L),
    y=Emu(0L),
    cx=Emu(1_000_000L),
    cy=Emu(1_000_000L),
  ).with_hyperlink_to_slide(slide_idx=1)
  prs.update_slide_mut(0, prs.slides()[0].with_shape(AutoShape(box)))
  let rels = prs.opc_package().relationships_for(slide_name)
  let jump = rels.by_type(@opc.rt_slide)[0]
  debug_inspect(jump.target_mode is Internal, content="true")
  let xml = slide_xml_of(prs, slide_name)
  debug_inspect(xml.contains("ppaction://hlinksldjump"), content="true")
  debug_inspect(xml.contains("r:id=\"" + jump.id + "\""), content="true")
}

///|
test "picture with_hyperlink: external URL → rel + hlinkClick" {
  let prs = @presentation.Presentation::new()
  let slide_name = prs.add_slide_mut(0)
  let pic = @slide.Picture::of_image(
    id=3,
    name="img",
    "rId99",
    x=Emu(0L),
    y=Emu(0L),
    cx=Emu(914_400L),
    cy=Emu(914_400L),
  ).with_hyperlink(url="https://pics.example")
  prs.update_slide_mut(0, prs.slides()[0].with_shape(Picture(pic)))
  let rels = prs.opc_package().relationships_for(slide_name)
  let hl = rels.by_type(@opc.rt_hyperlink)[0]
  debug_inspect(hl.target, content="\"https://pics.example\"")
  let xml = slide_xml_of(prs, slide_name)
  debug_inspect(xml.contains("hlinkClick"), content="true")
  debug_inspect(xml.contains("r:id=\"" + hl.id + "\""), content="true")
}

///|
test "shape with_hyperlink: survives save → reopen" {
  let prs = @presentation.Presentation::new()
  let slide_name = prs.add_slide_mut(0)
  let box = @slide.AutoShape::rect(
    id=2,
    name="btn",
    x=Emu(0L),
    y=Emu(0L),
    cx=Emu(1_000_000L),
    cy=Emu(1_000_000L),
  ).with_hyperlink(url="https://saved.example")
  prs.update_slide_mut(0, prs.slides()[0].with_shape(AutoShape(box)))
  let prs2 = @presentation.Presentation::open(prs.save())
  let rels = prs2.opc_package().relationships_for(slide_name)
  debug_inspect(
    rels.by_type(@opc.rt_hyperlink)[0].target,
    content="\"https://saved.example\"",
  )
  // The reopened slide still has the hlinkClick (round-trips via captured cNvPr).
  debug_inspect(
    slide_xml_of(prs2, slide_name).contains("hlinkClick"),
    content="true",
  )
}

///|
test "shape without hyperlink: no hyperlink rel, no hlinkClick" {
  let prs = @presentation.Presentation::new()
  let slide_name = prs.add_slide_mut(0)
  let box = @slide.AutoShape::rect(
    id=2,
    name="plain",
    x=Emu(0L),
    y=Emu(0L),
    cx=Emu(1_000_000L),
    cy=Emu(1_000_000L),
  )
  prs.update_slide_mut(0, prs.slides()[0].with_shape(AutoShape(box)))
  let rels = prs.opc_package().relationships_for(slide_name)
  debug_inspect(rels.by_type(@opc.rt_hyperlink).length(), content="0")
  debug_inspect(
    slide_xml_of(prs, slide_name).contains("hlinkClick"),
    content="false",
  )
}

///|
test "ShapeHyperlink::external / to_slide constructors carry the target" {
  let ext = @slide.ShapeHyperlink::external("https://example.com")
  debug_inspect(
    ext.target,
    content="Some(ExternalUrl(\"https://example.com\"))",
  )
  debug_inspect(ext.click is None && ext.action is None, content="true")
  let jump = @slide.ShapeHyperlink::to_slide(3)
  debug_inspect(jump.target, content="Some(InternalSlide(3))")
  debug_inspect(jump.click is None && jump.action is None, content="true")
}

// --- whole-shape hyperlinks on the remaining kinds (Connector / Group / GraphicFrame) ---

///|
/// A free-floating straight connector for these tests (no builder
/// constructor exists for connectors — literal construction is the norm).
fn test_connector(id : Int) -> @slide.Connector {
  {
    id,
    name: "conn",
    transform: Some(
      @slide.Transform::new(offset={ x: Emu(0L), y: Emu(0L), }, extent={
        cx: Emu(1_000_000L),
        cy: Emu(0L),
      }),
    ),
    geometry: Some(Preset(Line, [])),
    stroke: None,
    effects: None,
    start: None,
    end: None,
    hyperlink: None,
    extension: [],
  }
}

///|
test "connector with_hyperlink: external URL → rel + hlinkClick on cNvPr" {
  let prs = @presentation.Presentation::new()
  let slide_name = prs.add_slide_mut(0)
  let conn = test_connector(2).with_hyperlink(url="https://conn.example")
  prs.update_slide_mut(0, prs.slides()[0].with_shape(Connector(conn)))
  let rels = prs.opc_package().relationships_for(slide_name)
  let hl = rels.by_type(@opc.rt_hyperlink)[0]
  debug_inspect(hl.target, content="\"https://conn.example\"")
  debug_inspect(hl.target_mode is External, content="true")
  let xml = slide_xml_of(prs, slide_name)
  debug_inspect(xml.contains("hlinkClick"), content="true")
  debug_inspect(xml.contains("r:id=\"" + hl.id + "\""), content="true")
}

///|
test "group with_hyperlink_to_slide: rt_slide rel + ppaction jump" {
  let prs = @presentation.Presentation::new()
  let slide_name = prs.add_slide_mut(0)
  let _ = prs.add_slide_mut(0) // target slide index 1 exists
  let g : @slide.GroupShape = {
    id: 2,
    name: "grp",
    transform: Some(
      @slide.Transform::new(offset={ x: Emu(0L), y: Emu(0L), }, extent={
        cx: Emu(1_000_000L),
        cy: Emu(1_000_000L),
      }),
    ),
    child_offset: Some({ x: Emu(0L), y: Emu(0L), }),
    child_extent: Some({ cx: Emu(1_000_000L), cy: Emu(1_000_000L), }),
    children: [],
    hyperlink: None,
    extension: [],
  }
  prs.update_slide_mut(
    0,
    prs.slides()[0].with_shape(Group(g.with_hyperlink_to_slide(slide_idx=1))),
  )
  let rels = prs.opc_package().relationships_for(slide_name)
  let jump = rels.by_type(@opc.rt_slide)[0]
  debug_inspect(jump.target_mode is Internal, content="true")
  let xml = slide_xml_of(prs, slide_name)
  debug_inspect(xml.contains("ppaction://hlinksldjump"), content="true")
  debug_inspect(xml.contains("r:id=\"" + jump.id + "\""), content="true")
}

///|
test "graphic frame with_hyperlink: a clickable table survives save → reopen" {
  let prs = @presentation.Presentation::new()
  let slide_name = prs.add_slide_mut(0)
  let table = @slide.Table::of_grid(
    rows=2,
    cols=2,
    col_width=Emu(1_000_000L),
    row_height=Emu(370_000L),
  )
  let frame = @slide.GraphicFrame::of_table(
    id=2,
    name="tbl",
    x=Emu(0L),
    y=Emu(0L),
    cx=Emu(2_000_000L),
    cy=Emu(740_000L),
    table,
  ).with_hyperlink(url="https://table.example")
  prs.update_slide_mut(0, prs.slides()[0].with_shape(GraphicFrame(frame)))
  let rels = prs.opc_package().relationships_for(slide_name)
  debug_inspect(
    rels.by_type(@opc.rt_hyperlink)[0].target,
    content="\"https://table.example\"",
  )
  let xml = slide_xml_of(prs, slide_name)
  debug_inspect(xml.contains("hlinkClick"), content="true")
  // Save → reopen: the hlinkClick round-trips via the captured cNvPr.
  let prs2 = @presentation.Presentation::open(prs.save())
  debug_inspect(
    slide_xml_of(prs2, slide_name).contains("hlinkClick"),
    content="true",
  )
}

///|
test "shape hyperlink builders set the unresolved target and leave the original intact" {
  let conn = test_connector(9)
  let conn_ext = conn.with_hyperlink(url="https://a.example")
  let conn_jump = conn.with_hyperlink_to_slide(slide_idx=2)
  debug_inspect(conn.hyperlink is None, content="true") // ADR-003 immutability
  debug_inspect(
    conn_ext.hyperlink.unwrap().target,
    content="Some(ExternalUrl(\"https://a.example\"))",
  )
  debug_inspect(
    conn_jump.hyperlink.unwrap().target,
    content="Some(InternalSlide(2))",
  )
  let frame = @slide.GraphicFrame::of_table(
    id=1,
    name="t",
    x=Emu(0L),
    y=Emu(0L),
    cx=Emu(1L),
    cy=Emu(1L),
    @slide.Table::of_grid(rows=1, cols=1, col_width=Emu(1L), row_height=Emu(1L)),
  )
  debug_inspect(
    frame.with_hyperlink(url="https://f.example").hyperlink.unwrap().target,
    content="Some(ExternalUrl(\"https://f.example\"))",
  )
  debug_inspect(
    frame.with_hyperlink_to_slide(slide_idx=1).hyperlink.unwrap().target,
    content="Some(InternalSlide(1))",
  )
  debug_inspect(frame.hyperlink is None, content="true")
  let g : @slide.GroupShape = {
    id: 3,
    name: "g",
    transform: None,
    child_offset: None,
    child_extent: None,
    children: [],
    hyperlink: None,
    extension: [],
  }
  debug_inspect(
    g.with_hyperlink(url="https://g.example").hyperlink.unwrap().target,
    content="Some(ExternalUrl(\"https://g.example\"))",
  )
  debug_inspect(g.hyperlink is None, content="true")
}

///|
test "picture with_hyperlink_to_slide: rt_slide rel + ppaction jump" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let _ = prs.add_slide_mut(0)
  // A 1×1 BMP is enough for add_picture_mut; then rebuild the picture
  // with the jump hyperlink via update.
  let bmp : FixedArray[Byte] = [
    b'B', b'M', 58, 0, 0, 0, 0, 0, 0, 0, 54, 0, 0, 0, 40, 0, 0, 0, 1, 0, 0, 0, 1,
    0, 0, 0, 1, 0, 24, 0, 0, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 255, 255, 255, 0,
  ]
  prs.add_picture_mut(0, bmp, x=Emu(0L), y=Emu(0L), cx=Emu(100L), cy=Emu(100L))
  prs.update_slide_mut(
    0,
    prs.slides()[0].map_shapes(s => {
      match s {
        Picture(p) => Picture(p.with_hyperlink_to_slide(slide_idx=1))
        other => other
      }
    }),
  )
  let xml = @oxml.bytes_to_string(
    prs.opc_package().part_by_name("/ppt/slides/slide1.xml").unwrap().bytes(),
  )
  debug_inspect(xml.find("ppaction://hlinksldjump") is Some(_), content="true")
  // The slide rels carry an rt_slide relationship at slide2.
  let rels = @oxml.bytes_to_string(
    prs
    .opc_package()
    .part_by_name("/ppt/slides/_rels/slide1.xml.rels")
    .unwrap()
    .bytes(),
  )
  debug_inspect(rels.find("slide2.xml") is Some(_), content="true")
}
