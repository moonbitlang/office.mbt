// Modified for office.mbt: follow the workspace warning conventions.
// Picture parser tests.

///|
/// Build a slide containing a single `<p:pic>` whose body is provided
/// verbatim. Caller controls the inner shape so we can exercise srcRect,
/// stretch, etc. independently.
fn slide_with_pic(inner : String) -> FixedArray[Byte] {
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
    inner +
    "</p:pic>" +
    "</p:spTree></p:cSld></p:sld>"
  @oxml.string_to_bytes(xml)
}

// --- happy path ---

///|
test "parse: typical picture with embed and stretch" {
  let inner = "<p:nvPicPr><p:cNvPr id=\"5\" name=\"Pic1\"/><p:cNvPicPr/><p:nvPr/></p:nvPicPr>" +
    "<p:blipFill>" +
    "<a:blip r:embed=\"rId7\" cstate=\"print\"/>" +
    "<a:stretch><a:fillRect/></a:stretch>" +
    "</p:blipFill>" +
    "<p:spPr>" +
    "<a:xfrm><a:off x=\"100\" y=\"200\"/><a:ext cx=\"300\" cy=\"400\"/></a:xfrm>" +
    "<a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom>" +
    "</p:spPr>"
  let slide = @slide.Slide::parse(slide_with_pic(inner))
  match slide.shapes[0] {
    Picture(p) => {
      debug_inspect(p.id, content="5")
      debug_inspect(p.name, content="\"Pic1\"")
      debug_inspect(p.blip_fill.embed_id, content="\"rId7\"")
      debug_inspect(p.blip_fill.link_id, content="\"\"")
      debug_inspect(p.blip_fill.src_rect is None, content="true")
      let xfrm = p.transform.unwrap()
      debug_inspect(xfrm.offset.x, content="Emu(100)")
      debug_inspect(xfrm.extent.cy, content="Emu(400)")
      match p.geometry.unwrap() {
        Preset(kind, _) => debug_inspect(kind is Rect, content="true")
        _ => fail("expected Preset")
      }
    }
    _ => fail("expected Picture")
  }
}

///|
test "parse: picture with linked rId (no embed)" {
  let inner = "<p:nvPicPr><p:cNvPr id=\"6\" name=\"Linked\"/><p:cNvPicPr/><p:nvPr/></p:nvPicPr>" +
    "<p:blipFill><a:blip r:link=\"rId9\"/></p:blipFill>" +
    "<p:spPr/>"
  let slide = @slide.Slide::parse(slide_with_pic(inner))
  match slide.shapes[0] {
    Picture(p) => {
      debug_inspect(p.blip_fill.embed_id, content="\"\"")
      debug_inspect(p.blip_fill.link_id, content="\"rId9\"")
    }
    _ => fail("expected Picture")
  }
}

///|
test "parse: picture with srcRect crop" {
  let inner = "<p:nvPicPr><p:cNvPr id=\"7\" name=\"Cropped\"/><p:cNvPicPr/><p:nvPr/></p:nvPicPr>" +
    "<p:blipFill>" +
    "<a:blip r:embed=\"rId1\"/>" +
    "<a:srcRect l=\"10000\" t=\"20000\" r=\"5000\" b=\"5000\"/>" +
    "<a:stretch><a:fillRect/></a:stretch>" +
    "</p:blipFill>" +
    "<p:spPr/>"
  let slide = @slide.Slide::parse(slide_with_pic(inner))
  match slide.shapes[0] {
    Picture(p) => {
      let sr = p.blip_fill.src_rect.unwrap()
      // l=10000 = 10% (1000ths-of-percent)
      debug_inspect(sr.left, content="Percentage(10)")
      debug_inspect(sr.top, content="Percentage(20)")
      debug_inspect(sr.right, content="Percentage(5)")
      debug_inspect(sr.bottom, content="Percentage(5)")
    }
    _ => fail("expected Picture")
  }
}

///|
test "parse: srcRect with no attributes defaults to zeros" {
  let inner = "<p:nvPicPr><p:cNvPr id=\"8\" name=\"x\"/><p:cNvPicPr/><p:nvPr/></p:nvPicPr>" +
    "<p:blipFill><a:blip r:embed=\"rId1\"/><a:srcRect/></p:blipFill>" +
    "<p:spPr/>"
  let slide = @slide.Slide::parse(slide_with_pic(inner))
  match slide.shapes[0] {
    Picture(p) => {
      let sr = p.blip_fill.src_rect.unwrap()
      debug_inspect(sr.left, content="Percentage(0)")
      debug_inspect(sr.top, content="Percentage(0)")
      debug_inspect(sr.right, content="Percentage(0)")
      debug_inspect(sr.bottom, content="Percentage(0)")
    }
    _ => fail("expected Picture")
  }
}

///|
test "parse: tile fill is consumed without raising" {
  let inner = "<p:nvPicPr><p:cNvPr id=\"9\" name=\"Tiled\"/><p:cNvPicPr/><p:nvPr/></p:nvPicPr>" +
    "<p:blipFill>" +
    "<a:blip r:embed=\"rId1\"/>" +
    "<a:tile tx=\"0\" ty=\"0\" sx=\"100000\" sy=\"100000\" flip=\"none\" algn=\"tl\"/>" +
    "</p:blipFill>" +
    "<p:spPr/>"
  let slide = @slide.Slide::parse(slide_with_pic(inner))
  match slide.shapes[0] {
    Picture(_) => () // ok
    _ => fail("expected Picture")
  }
}

///|
test "parse: blip with image effects nested children skipped cleanly" {
  let inner = "<p:nvPicPr><p:cNvPr id=\"10\" name=\"Mod\"/><p:cNvPicPr/><p:nvPr/></p:nvPicPr>" +
    "<p:blipFill>" +
    "<a:blip r:embed=\"rId1\">" +
    "<a:lum bright=\"-20000\"/>" +
    "<a:alphaModFix amt=\"50000\"/>" +
    "<a:extLst><a:ext uri=\"{x}\"><a:y/></a:ext></a:extLst>" +
    "</a:blip>" +
    "<a:stretch><a:fillRect/></a:stretch>" +
    "</p:blipFill>" +
    "<p:spPr/>"
  let slide = @slide.Slide::parse(slide_with_pic(inner))
  match slide.shapes[0] {
    Picture(p) => debug_inspect(p.blip_fill.embed_id, content="\"rId1\"")
    _ => fail("expected Picture")
  }
}

// --- error cases ---

///|
test "parse: blip with neither embed nor link is rejected" {
  let inner = "<p:nvPicPr><p:cNvPr id=\"1\" name=\"x\"/><p:cNvPicPr/><p:nvPr/></p:nvPicPr>" +
    "<p:blipFill><a:blip/></p:blipFill>" +
    "<p:spPr/>"
  try @slide.Slide::parse(slide_with_pic(inner)) catch {
    Malformed(_) => ()
    _ => fail("expected Malformed")
  } noraise {
    _ => fail("expected Malformed")
  }
}

///|
test "parse: srcRect with non-integer attribute is rejected" {
  let inner = "<p:nvPicPr><p:cNvPr id=\"1\" name=\"x\"/><p:cNvPicPr/><p:nvPr/></p:nvPicPr>" +
    "<p:blipFill><a:blip r:embed=\"rId1\"/><a:srcRect l=\"oops\"/></p:blipFill>" +
    "<p:spPr/>"
  try @slide.Slide::parse(slide_with_pic(inner)) catch {
    Malformed(_) => ()
    _ => fail("expected Malformed")
  } noraise {
    _ => fail("expected Malformed")
  }
}
