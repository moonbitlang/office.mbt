// Modified for office.mbt: follow the workspace warning conventions.
// Tests for shape rotation & flip on `Transform`.
//
// Covers the `<a:xfrm rot/flipH/flipV>` lift: parse, write (with default
// omission), the `Transform` / `AutoShape` / `Picture` / `GroupShape`
// builders, and a graphicFrame `<p:xfrm>` round-trip.

///|
/// Wrap a single `<p:sp>` carrying `xfrm` (the full `<a:xfrm>…</a:xfrm>`
/// string) into a parseable one-slide deck.
fn slide_with_oriented_sp(xfrm : String) -> FixedArray[Byte] {
  let xml = "<?xml version=\"1.0\"?><p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\"><p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr/>" +
    "<p:sp><p:nvSpPr><p:cNvPr id=\"2\" name=\"R\"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>" +
    "<p:spPr>" +
    xfrm +
    "<a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom></p:spPr></p:sp>" +
    "</p:spTree></p:cSld></p:sld>"
  @oxml.string_to_bytes(xml)
}

///|
/// An empty spTree to append builder-made shapes onto.
fn empty_sptree_deck() -> FixedArray[Byte] {
  let xml = "<?xml version=\"1.0\"?><p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\"><p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr/>" +
    "</p:spTree></p:cSld></p:sld>"
  @oxml.string_to_bytes(xml)
}

///|
test "parse: xfrm rot/flipH/flipV populate Transform" {
  // 5400000 1/60000-deg units = 90°.
  let slide = @slide.Slide::parse(
    slide_with_oriented_sp(
      "<a:xfrm rot=\"5400000\" flipH=\"1\" flipV=\"1\"><a:off x=\"100\" y=\"200\"/><a:ext cx=\"300\" cy=\"400\"/></a:xfrm>",
    ),
  )
  match slide.shapes[0] {
    AutoShape(s) => {
      let xfrm = s.transform.unwrap()
      debug_inspect(xfrm.rotation.unwrap(), content="Angle(90)")
      debug_inspect(xfrm.flip_h, content="true")
      debug_inspect(xfrm.flip_v, content="true")
    }
    _ => fail("expected AutoShape")
  }
}

///|
test "parse: xfrm without orientation defaults to unrotated / un-flipped" {
  let slide = @slide.Slide::parse(
    slide_with_oriented_sp(
      "<a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"1\" cy=\"1\"/></a:xfrm>",
    ),
  )
  match slide.shapes[0] {
    AutoShape(s) => {
      let xfrm = s.transform.unwrap()
      debug_inspect(xfrm.rotation is None, content="true")
      debug_inspect(xfrm.flip_h, content="false")
      debug_inspect(xfrm.flip_v, content="false")
    }
    _ => fail("expected AutoShape")
  }
}

///|
test "Transform::new defaults + with_rotation / with_flip" {
  let t = @slide.Transform::new(offset={ x: Emu(0L), y: Emu(0L), }, extent={
    cx: Emu(1L),
    cy: Emu(1L),
  })
  debug_inspect(t.rotation is None, content="true")
  debug_inspect(t.flip_h, content="false")
  debug_inspect(t.flip_v, content="false")
  let t2 = t.with_rotation(Angle(30.0)).with_flip(h=true, v=true)
  debug_inspect(t2.rotation.unwrap(), content="Angle(30)")
  debug_inspect(t2.flip_h, content="true")
  debug_inspect(t2.flip_v, content="true")
  // with_flip() with no args clears both.
  debug_inspect(t2.with_flip().flip_h, content="false")
}

///|
test "AutoShape::with_rotation + with_flip emit attrs and round-trip" {
  let base = @slide.Slide::parse(empty_sptree_deck())
  let rect = @slide.AutoShape::rect(
      id=2,
      name="R",
      x=Emu(100L),
      y=Emu(200L),
      cx=Emu(300L),
      cy=Emu(400L),
    )
    .with_rotation(Angle(45.0)) // 45° → 2700000
    .with_flip(h=true)
  let s = base.with_shape(AutoShape(rect))
  let xml = @oxml.bytes_to_string(s.serialize())
  debug_inspect(xml.contains("rot=\"2700000\""), content="true")
  debug_inspect(xml.contains("flipH=\"1\""), content="true")
  // flipV not set → no attribute emitted.
  debug_inspect(!xml.contains("flipV"), content="true")
  let reparsed = @slide.Slide::parse(s.serialize())
  match reparsed.shapes[0] {
    AutoShape(a) => {
      let xfrm = a.transform.unwrap()
      debug_inspect(xfrm.rotation.unwrap(), content="Angle(45)")
      debug_inspect(xfrm.flip_h, content="true")
      debug_inspect(xfrm.flip_v, content="false")
    }
    _ => fail("expected AutoShape")
  }
}

///|
test "writer: un-rotated transform emits no rot / flipH / flipV" {
  let base = @slide.Slide::parse(empty_sptree_deck())
  let rect = @slide.AutoShape::rect(
    id=2,
    name="R",
    x=Emu(100L),
    y=Emu(200L),
    cx=Emu(300L),
    cy=Emu(400L),
  )
  let s = base.with_shape(AutoShape(rect))
  let xml = @oxml.bytes_to_string(s.serialize())
  debug_inspect(!xml.contains("rot="), content="true")
  debug_inspect(!xml.contains("flipH"), content="true")
  debug_inspect(!xml.contains("flipV"), content="true")
}

///|
test "Picture::with_rotation + with_flip round-trip" {
  let base = @slide.Slide::parse(empty_sptree_deck())
  let pic = @slide.Picture::of_image(
      id=3,
      name="Pic",
      "rId2",
      x=Emu(0L),
      y=Emu(0L),
      cx=Emu(914400L),
      cy=Emu(914400L),
    )
    .with_rotation(Angle(90.0))
    .with_flip(v=true)
  let s = base.with_shape(Picture(pic))
  let reparsed = @slide.Slide::parse(s.serialize())
  match reparsed.shapes[0] {
    Picture(p) => {
      let xfrm = p.transform.unwrap()
      debug_inspect(xfrm.rotation.unwrap(), content="Angle(90)")
      debug_inspect(xfrm.flip_h, content="false")
      debug_inspect(xfrm.flip_v, content="true")
    }
    _ => fail("expected Picture")
  }
}

///|
test "GroupShape::with_rotation + with_flip set the transform" {
  let g : @slide.GroupShape = {
    id: 4,
    name: "G",
    transform: Some(
      @slide.Transform::new(offset={ x: Emu(0L), y: Emu(0L), }, extent={
        cx: Emu(10L),
        cy: Emu(10L),
      }),
    ),
    child_offset: None,
    child_extent: None,
    children: [],
    hyperlink: None,
    extension: [],
  }
  let g2 = g.with_rotation(Angle(60.0)).with_flip(h=true)
  let xfrm = g2.transform.unwrap()
  debug_inspect(xfrm.rotation.unwrap(), content="Angle(60)")
  debug_inspect(xfrm.flip_h, content="true")
  debug_inspect(xfrm.flip_v, content="false")
}

///|
test "GroupShape: rotated group emits orientation and round-trips" {
  // Exercises the group-shape writer path (`write_group_xfrm`), not just
  // the builder — the group `<a:xfrm>` carries rot/flipH.
  let base = @slide.Slide::parse(empty_sptree_deck())
  let g : @slide.GroupShape = {
    id: 5,
    name: "G",
    transform: Some(
      @slide.Transform::new(offset={ x: Emu(0L), y: Emu(0L), }, extent={
        cx: Emu(100L),
        cy: Emu(100L),
      }),
    ),
    child_offset: Some({ x: Emu(0L), y: Emu(0L), }),
    child_extent: Some({ cx: Emu(100L), cy: Emu(100L), }),
    children: [],
    hyperlink: None,
    extension: [],
  }
  let s = base.with_shape(Group(g.with_rotation(Angle(90.0)).with_flip(h=true)))
  let xml = @oxml.bytes_to_string(s.serialize())
  debug_inspect(xml.contains("rot=\"5400000\""), content="true")
  debug_inspect(xml.contains("flipH=\"1\""), content="true")
  let reparsed = @slide.Slide::parse(s.serialize())
  match reparsed.shapes[0] {
    Group(rg) => {
      let xfrm = rg.transform.unwrap()
      debug_inspect(xfrm.rotation.unwrap(), content="Angle(90)")
      debug_inspect(xfrm.flip_h, content="true")
      debug_inspect(xfrm.flip_v, content="false")
    }
    _ => fail("expected GroupShape")
  }
}

///|
test "graphicFrame: <p:xfrm> rot/flip round-trips losslessly" {
  let gf = "<p:graphicFrame>" +
    "<p:nvGraphicFramePr><p:cNvPr id=\"7\" name=\"T\"/><p:cNvGraphicFramePr/><p:nvPr/></p:nvGraphicFramePr>" +
    "<p:xfrm rot=\"5400000\" flipH=\"1\">" +
    "<a:off x=\"0\" y=\"0\"/><a:ext cx=\"100\" cy=\"100\"/>" +
    "</p:xfrm>" +
    "<a:graphic><a:graphicData uri=\"http://example.com/x\"/></a:graphic>" +
    "</p:graphicFrame>"
  let slide = @slide.Slide::parse(slide_with_shapes_xml(gf))
  match slide.shapes[0] {
    GraphicFrame(f) => {
      let xfrm = f.transform.unwrap()
      debug_inspect(xfrm.rotation.unwrap(), content="Angle(90)")
      debug_inspect(xfrm.flip_h, content="true")
      debug_inspect(xfrm.flip_v, content="false")
    }
    _ => fail("expected GraphicFrame")
  }
  // Re-serialise → re-parse keeps the orientation.
  let reparsed = @slide.Slide::parse(slide.serialize())
  match reparsed.shapes[0] {
    GraphicFrame(f) => {
      let xfrm = f.transform.unwrap()
      debug_inspect(xfrm.rotation.unwrap(), content="Angle(90)")
      debug_inspect(xfrm.flip_h, content="true")
    }
    _ => fail("expected GraphicFrame")
  }
}
