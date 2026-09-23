// Modified for office.mbt: follow the workspace warning conventions.
// Shape / slide builder tests.

///|
test "AutoShape::rect: produces expected preset + transform" {
  let s = @slide.AutoShape::rect(
    id=42,
    name="MyRect",
    x=Emu(100L),
    y=Emu(200L),
    cx=Emu(300L),
    cy=Emu(400L),
  )
  debug_inspect(s.id, content="42")
  debug_inspect(s.name, content="\"MyRect\"")
  let xfrm = s.transform.unwrap()
  debug_inspect(xfrm.offset.x, content="Emu(100)")
  debug_inspect(xfrm.offset.y, content="Emu(200)")
  debug_inspect(xfrm.extent.cx, content="Emu(300)")
  debug_inspect(xfrm.extent.cy, content="Emu(400)")
  match s.geometry.unwrap() {
    Preset(p, adj) => {
      debug_inspect(p, content="Rect")
      debug_inspect(adj.length(), content="0")
    }
    _ => fail("expected Preset geometry")
  }
  debug_inspect(s.text_body is None, content="true")
}

///|
test "AutoShape::ellipse / round_rect: vary only the preset enum" {
  let e = @slide.AutoShape::ellipse(
    id=1,
    name="E",
    x=Emu(0L),
    y=Emu(0L),
    cx=Emu(1L),
    cy=Emu(1L),
  )
  match e.geometry.unwrap() {
    Preset(p, _) => debug_inspect(p, content="Ellipse")
    _ => fail("expected Ellipse")
  }
  let r = @slide.AutoShape::round_rect(
    id=2,
    name="R",
    x=Emu(0L),
    y=Emu(0L),
    cx=Emu(1L),
    cy=Emu(1L),
  )
  match r.geometry.unwrap() {
    Preset(p, _) => debug_inspect(p, content="RoundRect")
    _ => fail("expected RoundRect")
  }
}

///|
test "AutoShape::textbox: rect geometry + text body" {
  let tb = @slide.AutoShape::textbox(
    id=7,
    name="T1",
    x=Emu(0L),
    y=Emu(0L),
    cx=Emu(1L),
    cy=Emu(1L),
    "Hello",
  )
  match tb.geometry.unwrap() {
    Preset(p, _) => debug_inspect(p, content="Rect")
    _ => fail("expected Rect geometry on text box")
  }
  let body = tb.text_body.unwrap()
  debug_inspect(body.plain_text(), content="\"Hello\"")
}

///|
test "TextBody::of_text: single paragraph with one run" {
  let body = @slide.TextBody::of_text("Hi there")
  debug_inspect(body.paragraphs.length(), content="1")
  debug_inspect(body.paragraphs[0].content.length(), content="1")
  debug_inspect(body.plain_text(), content="\"Hi there\"")
}

///|
test "RunProperties: fluent setters chain" {
  let rp = @slide.RunProperties::default()
    .with_font_size(Pt(24.0))
    .with_bold()
    .with_italic()
    .with_font("Helvetica")
    .with_color(@units.RgbColor::new(0x10, 0x20, 0x30))
  debug_inspect(rp.font_size.unwrap(), content="Pt(24)")
  debug_inspect(rp.bold.unwrap(), content="true")
  debug_inspect(rp.italic.unwrap(), content="true")
  debug_inspect(rp.latin.unwrap(), content="\"Helvetica\"")
  debug_inspect(rp.fill is Some(_), content="true")
}

///|
test "RunProperties: fluent setters do not mutate the original" {
  let base = @slide.RunProperties::default()
  let bigger = base.with_font_size(Pt(36.0))
  debug_inspect(base.font_size is None, content="true")
  debug_inspect(bigger.font_size.unwrap(), content="Pt(36)")
}

///|
test "Paragraph::with_alignment: lifts to alignment field" {
  let p = @slide.Paragraph::of_text("Centred").with_alignment(AlignCenter)
  debug_inspect(p.properties.alignment is Some(AlignCenter), content="true")
}

///|
test "TextBody::of_styled_text: run carries the styling" {
  let rp = @slide.RunProperties::default().with_font_size(Pt(18.0)).with_bold()
  let body = @slide.TextBody::of_styled_text("Bold 18", rp)
  debug_inspect(body.paragraphs.length(), content="1")
  match body.paragraphs[0].content[0] {
    RunContent(r) => {
      debug_inspect(r.text, content="\"Bold 18\"")
      debug_inspect(r.properties.font_size.unwrap(), content="Pt(18)")
      debug_inspect(r.properties.bold.unwrap(), content="true")
    }
    _ => fail("expected RunContent")
  }
}

///|
test "TextBody::of_paragraphs: passes through" {
  let p0 = @slide.Paragraph::of_text("one")
  let p1 = @slide.Paragraph::of_text("two")
  let body = @slide.TextBody::of_paragraphs([p0, p1])
  debug_inspect(body.paragraphs.length(), content="2")
  debug_inspect(body.plain_text(), content="\"one\\ntwo\"")
}

///|
test "AutoShape::with_fill / with_stroke / with_no_fill chain" {
  let s = @slide.AutoShape::rect(
    id=1,
    name="R",
    x=Emu(0L),
    y=Emu(0L),
    cx=Emu(100L),
    cy=Emu(100L),
  )
  // rect ships with default fill + stroke; with_no_fill explicitly opts out.
  let bare = s.with_no_fill().with_no_stroke()
  debug_inspect(bare.fill is Some(_), content="true") // NoFill, not None — explicit
  debug_inspect(bare.stroke is None, content="true")
  // with_fill overrides the default.
  let yellow = @units.RgbColor::new(0xFF, 0xCC, 0x00)
  let painted = s.with_fill(SolidFill(@oxml.Color::srgb(yellow)))
  match painted.fill.unwrap() {
    SolidFill(_) => ()
    _ => fail("expected SolidFill")
  }
}

///|
test "AutoShape::with_text_body: attaches styled body" {
  let s = @slide.AutoShape::rect(
    id=1,
    name="Card",
    x=Emu(0L),
    y=Emu(0L),
    cx=Emu(2_000_000L),
    cy=Emu(500_000L),
  )
  let body = @slide.TextBody::of_styled_text(
    "Header",
    @slide.RunProperties::default().with_font_size(Pt(28.0)).with_bold(),
  )
  let styled = s.with_text_body(body)
  debug_inspect(styled.text_body is Some(_), content="true")
  debug_inspect(styled.text_body.unwrap().plain_text(), content="\"Header\"")
}

///|
test "Slide::with_shape: appends shape; original unchanged" {
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\">" +
    "<p:cSld name=\"S\"><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr/>" +
    "</p:spTree></p:cSld></p:sld>"
  let original = @slide.Slide::parse(@oxml.string_to_bytes(xml))
  debug_inspect(original.shapes.length(), content="0")
  let rect = @slide.AutoShape::rect(
    id=2,
    name="R",
    x=Emu(0L),
    y=Emu(0L),
    cx=Emu(100L),
    cy=Emu(100L),
  )
  let modified = original.with_shape(AutoShape(rect))
  debug_inspect(modified.shapes.length(), content="1")
  // The original slide's shapes array stays empty — `with_shape`
  // copies before pushing.
  debug_inspect(original.shapes.length(), content="0")
}

///|
test "AutoShape: structural fields survive Slide::serialize" {
  // Build a slide from scratch with one rect shape and confirm the
  // structural fields survive serialize → re-parse.
  //
  // Strict `==` doesn't hold on the first round-trip because the
  // parser captures `<p:cNvPr>` / `<p:cNvSpPr>` / `<p:nvPr>` into
  // `extension` wholesale — the hand-built AutoShape starts with an
  // empty extension array, while the reparsed copy gains those
  // captured wrappers. Subsequent round-trips are Eq-stable (see
  // the "second round-trip is stable" test below).
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\">" +
    "<p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr/>" +
    "</p:spTree></p:cSld></p:sld>"
  let base = @slide.Slide::parse(@oxml.string_to_bytes(xml))
  let rect = @slide.AutoShape::rect(
    id=2,
    name="R",
    x=Emu(100L),
    y=Emu(200L),
    cx=Emu(300L),
    cy=Emu(400L),
  )
  let s = base.with_shape(AutoShape(rect))
  let bytes = s.serialize()
  let s_reparsed = @slide.Slide::parse(bytes)
  debug_inspect(s_reparsed.shapes.length(), content="1")
  match s_reparsed.shapes[0] {
    AutoShape(a) => {
      debug_inspect(a.id, content="2")
      debug_inspect(a.name, content="\"R\"")
      let xfrm = a.transform.unwrap()
      debug_inspect(xfrm.offset.x, content="Emu(100)")
      debug_inspect(xfrm.extent.cx, content="Emu(300)")
      match a.geometry.unwrap() {
        Preset(p, _) => debug_inspect(p, content="Rect")
        _ => fail("expected Rect preset")
      }
    }
    _ => fail("expected AutoShape")
  }
}

///|
test "AutoShape: second round-trip is Eq-stable" {
  // Once a hand-built shape has been through one parse cycle the
  // captured wrappers are populated, and every subsequent
  // serialize → parse cycle holds `==`.
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\">" +
    "<p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr/>" +
    "</p:spTree></p:cSld></p:sld>"
  let base = @slide.Slide::parse(@oxml.string_to_bytes(xml))
  let rect = @slide.AutoShape::rect(
    id=2,
    name="R",
    x=Emu(100L),
    y=Emu(200L),
    cx=Emu(300L),
    cy=Emu(400L),
  )
  let s_first = @slide.Slide::parse(
    base.with_shape(AutoShape(rect)).serialize(),
  )
  let s_second = @slide.Slide::parse(s_first.serialize())
  debug_inspect(s_first == s_second, content="true")
}

///|
test "Picture::with_crop: applies SrcRect with the given percentages" {
  let pic = @slide.Picture::of_image(
    id=1,
    name="Pic",
    "rId99",
    x=Emu(0L),
    y=Emu(0L),
    cx=Emu(100L),
    cy=Emu(100L),
  ).with_crop(
    left=Percentage(5.0),
    top=Percentage(10.0),
    right=Percentage(15.0),
    bottom=Percentage(20.0),
  )
  let rect = pic.blip_fill.src_rect.unwrap()
  debug_inspect(rect.left, content="Percentage(5)")
  debug_inspect(rect.top, content="Percentage(10)")
  debug_inspect(rect.right, content="Percentage(15)")
  debug_inspect(rect.bottom, content="Percentage(20)")
}

///|
test "Picture::with_crop: defaults to 0% on all edges" {
  let pic = @slide.Picture::of_image(
    id=1,
    name="Pic",
    "rId99",
    x=Emu(0L),
    y=Emu(0L),
    cx=Emu(100L),
    cy=Emu(100L),
  ).with_crop(left=Percentage(10.0))
  let rect = pic.blip_fill.src_rect.unwrap()
  debug_inspect(rect.left, content="Percentage(10)")
  debug_inspect(rect.top, content="Percentage(0)")
  debug_inspect(rect.right, content="Percentage(0)")
  debug_inspect(rect.bottom, content="Percentage(0)")
}

///|
test "Picture::with_crop: idempotent — second call replaces, not merges" {
  let pic = @slide.Picture::of_image(
      id=1,
      name="Pic",
      "rId99",
      x=Emu(0L),
      y=Emu(0L),
      cx=Emu(100L),
      cy=Emu(100L),
    )
    .with_crop(left=Percentage(5.0), right=Percentage(5.0))
    .with_crop(top=Percentage(10.0))
  let rect = pic.blip_fill.src_rect.unwrap()
  // Only `top` survives — the earlier left+right crop was replaced.
  debug_inspect(rect.left, content="Percentage(0)")
  debug_inspect(rect.top, content="Percentage(10)")
  debug_inspect(rect.right, content="Percentage(0)")
  debug_inspect(rect.bottom, content="Percentage(0)")
}

///|
test "AutoShape::of_preset: carries the chosen preset geometry" {
  let s = @slide.AutoShape::of_preset(
    id=7,
    name="Star",
    Star5,
    x=Emu(10L),
    y=Emu(20L),
    cx=Emu(30L),
    cy=Emu(40L),
  )
  debug_inspect(s.id, content="7")
  debug_inspect(s.name, content="\"Star\"")
  let xfrm = s.transform.unwrap()
  debug_inspect(xfrm.offset.x, content="Emu(10)")
  debug_inspect(xfrm.extent.cy, content="Emu(40)")
  match s.geometry.unwrap() {
    Preset(p, adj) => {
      debug_inspect(p, content="Star5")
      debug_inspect(adj.length(), content="0")
    }
    _ => fail("expected Preset geometry")
  }
}

///|
test "AutoShape::with_stroke sets the outline; other fields untouched" {
  let stroke : @oxml.Stroke = {
    width: Some(Emu(12700L)),
    cap: None,
    compound: None,
    alignment: None,
    fill: Some(
      SolidFill(@oxml.Color::srgb(@units.RgbColor::new(0x11, 0x22, 0x33))),
    ),
    dash: None,
    join: None,
    head_end: None,
    tail_end: None,
    extension: [],
  }
  // of_preset (unlike rect/ellipse) starts with no fill/stroke.
  let base = @slide.AutoShape::of_preset(
    id=1,
    name="R",
    Rect,
    x=Emu(0L),
    y=Emu(0L),
    cx=Emu(10L),
    cy=Emu(10L),
  )
  let styled = base.with_stroke(stroke)
  debug_inspect(styled.stroke == Some(stroke), content="true")
  debug_inspect(base.stroke is None, content="true") // immutable builder
  debug_inspect(styled.id == base.id, content="true")
}

///|
test "Paragraph::of_styled_text + with_properties" {
  let rp = @slide.RunProperties::default().with_bold()
  let para = @slide.Paragraph::of_styled_text("hi", rp)
  match para.content[0] {
    RunContent(r) => {
      debug_inspect(r.text, content="\"hi\"")
      debug_inspect(r.properties.bold.unwrap(), content="true")
    }
    _ => fail("expected a run")
  }
  // with_properties replaces the paragraph-level properties wholesale.
  let props = { ..@slide.ParagraphProperties::default(), level: 2, }
  let levelled = para.with_properties(props)
  debug_inspect(levelled.properties.level, content="2")
  debug_inspect(para.properties.level, content="0") // original unchanged
}
