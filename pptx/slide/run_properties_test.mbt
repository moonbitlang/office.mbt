// Modified for office.mbt: follow the workspace warning conventions.
// RunProperties parser tests.

///|
/// Build a slide with one auto-shape whose `<p:txBody>` contains a single
/// paragraph with a single run whose `<a:rPr>` body is `rpr_body`.
fn slide_with_rpr(rpr_body : String) -> FixedArray[Byte] {
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
    "<p:sp>" +
    "<p:nvSpPr><p:cNvPr id=\"2\" name=\"T\"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>" +
    "<p:spPr/>" +
    "<p:txBody><a:p><a:r>" +
    rpr_body +
    "<a:t>x</a:t></a:r></a:p></p:txBody>" +
    "</p:sp>" +
    "</p:spTree></p:cSld></p:sld>"
  @oxml.string_to_bytes(xml)
}

///|
fn rpr_of(s : @slide.Slide) -> @slide.RunProperties {
  match s.shapes[0] {
    AutoShape(sp) =>
      match sp.text_body.unwrap().paragraphs[0].content[0] {
        RunContent(r) => r.properties
        _ => abort("expected Run")
      }
    _ => abort("expected AutoShape")
  }
}

// --- attributes ---

///|
test "rPr: lang attribute captured" {
  let slide = @slide.Slide::parse(slide_with_rpr("<a:rPr lang=\"en-US\"/>"))
  debug_inspect(rpr_of(slide).lang, content="\"en-US\"")
}

///|
test "rPr: sz attribute converts 1/100 pt to Pt" {
  let slide = @slide.Slide::parse(slide_with_rpr("<a:rPr sz=\"2400\"/>"))
  debug_inspect(rpr_of(slide).font_size.unwrap(), content="Pt(24)")
}

///|
test "rPr: b/i/u attributes" {
  let slide = @slide.Slide::parse(
    slide_with_rpr("<a:rPr b=\"1\" i=\"1\" u=\"sng\"/>"),
  )
  let p = rpr_of(slide)
  debug_inspect(p.bold.unwrap(), content="true")
  debug_inspect(p.italic.unwrap(), content="true")
  debug_inspect(p.underline.unwrap() is UlSingle, content="true")
}

///|
test "rPr: b='0' is false (not None)" {
  let slide = @slide.Slide::parse(slide_with_rpr("<a:rPr b=\"0\"/>"))
  debug_inspect(rpr_of(slide).bold.unwrap(), content="false")
}

///|
test "rPr: b='true' / b='false' accepted" {
  let s1 = @slide.Slide::parse(slide_with_rpr("<a:rPr b=\"true\"/>"))
  debug_inspect(rpr_of(s1).bold.unwrap(), content="true")
  let s2 = @slide.Slide::parse(slide_with_rpr("<a:rPr b=\"false\"/>"))
  debug_inspect(rpr_of(s2).bold.unwrap(), content="false")
}

///|
test "rPr: strike attribute" {
  let slide = @slide.Slide::parse(
    slide_with_rpr("<a:rPr strike=\"sngStrike\"/>"),
  )
  debug_inspect(
    rpr_of(slide).strikethrough.unwrap() is StSingle,
    content="true",
  )
}

///|
test "rPr: cap attribute" {
  let slide = @slide.Slide::parse(slide_with_rpr("<a:rPr cap=\"all\"/>"))
  debug_inspect(rpr_of(slide).caps.unwrap() is CapsAll, content="true")
}

///|
test "rPr: baseline as Percentage (subscript/superscript)" {
  let slide = @slide.Slide::parse(slide_with_rpr("<a:rPr baseline=\"30000\"/>"))
  // 30000 OOXML units = 30%
  debug_inspect(rpr_of(slide).baseline.unwrap(), content="Percentage(30)")
}

///|
test "rPr: baseline negative for subscript" {
  let slide = @slide.Slide::parse(
    slide_with_rpr("<a:rPr baseline=\"-25000\"/>"),
  )
  debug_inspect(rpr_of(slide).baseline.unwrap(), content="Percentage(-25)")
}

// --- children ---

///|
test "rPr: latin / ea / cs font typefaces" {
  let slide = @slide.Slide::parse(
    slide_with_rpr(
      "<a:rPr><a:latin typeface=\"Calibri\"/>" +
      "<a:ea typeface=\"Yu Gothic\"/>" +
      "<a:cs typeface=\"\"/></a:rPr>",
    ),
  )
  let p = rpr_of(slide)
  debug_inspect(p.latin.unwrap(), content="\"Calibri\"")
  debug_inspect(p.east_asian.unwrap(), content="\"Yu Gothic\"")
  debug_inspect(p.complex_script.unwrap(), content="\"\"")
}

///|
test "rPr: solidFill with srgbClr" {
  let slide = @slide.Slide::parse(
    slide_with_rpr(
      "<a:rPr><a:solidFill><a:srgbClr val=\"FF0000\"/></a:solidFill></a:rPr>",
    ),
  )
  match rpr_of(slide).fill.unwrap() {
    SolidFill({ base: Srgb(c), .. }) =>
      debug_inspect(c.to_hex(), content="\"FF0000\"")
    _ => fail("expected solid Srgb fill")
  }
}

///|
test "rPr: solidFill with schemeClr" {
  let slide = @slide.Slide::parse(
    slide_with_rpr(
      "<a:rPr><a:solidFill><a:schemeClr val=\"accent2\"/></a:solidFill></a:rPr>",
    ),
  )
  match rpr_of(slide).fill.unwrap() {
    SolidFill({ base: Scheme(t), .. }) =>
      debug_inspect(t is Accent2, content="true")
    _ => fail("expected solid Scheme fill")
  }
}

///|
test "rPr: hlinkClick captures r:id" {
  let slide = @slide.Slide::parse(
    slide_with_rpr("<a:rPr><a:hlinkClick r:id=\"rId5\"/></a:rPr>"),
  )
  debug_inspect(rpr_of(slide).hyperlink_click.unwrap(), content="\"rId5\"")
}

// --- error / absent ---

///|
test "rPr: missing attributes leave fields None" {
  let slide = @slide.Slide::parse(slide_with_rpr("<a:rPr/>"))
  let p = rpr_of(slide)
  debug_inspect(p.font_size is None, content="true")
  debug_inspect(p.bold is None, content="true")
  debug_inspect(p.italic is None, content="true")
  debug_inspect(p.underline is None, content="true")
  debug_inspect(p.strikethrough is None, content="true")
  debug_inspect(p.baseline is None, content="true")
  debug_inspect(p.caps is None, content="true")
  debug_inspect(p.latin is None, content="true")
  debug_inspect(p.east_asian is None, content="true")
  debug_inspect(p.complex_script is None, content="true")
  debug_inspect(p.fill is None, content="true")
  debug_inspect(p.hyperlink_click is None, content="true")
}

///|
test "rPr: gradFill lifts to the typed fill; effectLst to typed field" {
  let slide = @slide.Slide::parse(
    slide_with_rpr(
      "<a:rPr>" +
      "<a:gradFill><a:gsLst>" +
      "<a:gs pos=\"0\"><a:srgbClr val=\"FF0000\"/></a:gs>" +
      "<a:gs pos=\"100000\"><a:srgbClr val=\"0000FF\"/></a:gs>" +
      "</a:gsLst><a:lin ang=\"5400000\" scaled=\"1\"/></a:gradFill>" +
      "<a:effectLst><a:outerShdw blurRad=\"38100\"><a:srgbClr val=\"000000\"/></a:outerShdw></a:effectLst>" +
      "</a:rPr>",
    ),
  )
  // The run fill is the full @oxml.Fill ADT — a gradient text fill is
  // typed, not an extension escape hatch.
  debug_inspect(rpr_of(slide).fill is Some(GradientFill(_)), content="true")
  // The minimal effectLst (dist/dir absent) lifts into the typed
  // `text_effects` field (the shadow parsers default absent dist/dir to 0).
  debug_inspect(rpr_of(slide).text_effects is Some(_), content="true")
  // And the writer emits it back: serialize → reparse is model-equal.
  let reparsed = @slide.Slide::parse(slide.serialize())
  debug_inspect(rpr_of(reparsed) == rpr_of(slide), content="true")
}

///|
test "rPr: noFill + pattFill round-trip through the typed fill" {
  // noFill (invisible text) is a distinct typed state, not "inherit" —
  // and it survives a serialize → reparse round-trip.
  let slide = @slide.Slide::parse(slide_with_rpr("<a:rPr><a:noFill/></a:rPr>"))
  debug_inspect(rpr_of(slide).fill is Some(NoFill), content="true")
  debug_inspect(
    rpr_of(@slide.Slide::parse(slide.serialize())).fill is Some(NoFill),
    content="true",
  )
  // A pattern text fill parses, serialises, and re-parses to the same
  // model (parse → write → parse).
  let patt = slide_with_rpr(
    "<a:rPr><a:pattFill prst=\"ltDnDiag\">" +
    "<a:fgClr><a:srgbClr val=\"FF0000\"/></a:fgClr>" +
    "<a:bgClr><a:srgbClr val=\"FFFFFF\"/></a:bgClr>" +
    "</a:pattFill></a:rPr>",
  )
  let s1 = @slide.Slide::parse(patt)
  debug_inspect(rpr_of(s1).fill is Some(PatternFill(_)), content="true")
  let s2 = @slide.Slide::parse(s1.serialize())
  debug_inspect(rpr_of(s2) == rpr_of(s1), content="true")
}

///|
test "rPr: with_text_fill / with_color builders set the Fill ADT" {
  let grad = @oxml.Fill::GradientFill({
    stops: [
      {
        position: Percentage(0.0),
        color: @oxml.Color::srgb(@units.RgbColor::new(0xFF, 0x00, 0x00)),
      },
      {
        position: Percentage(100.0),
        color: @oxml.Color::srgb(@units.RgbColor::new(0x00, 0x00, 0xFF)),
      },
    ],
    direction: Linear(Angle(90.0), true),
    rotate_with_shape: None,
    flip: None,
    extension: [],
  })
  let p = @slide.RunProperties::default().with_text_fill(grad)
  debug_inspect(p.fill == Some(grad), content="true")
  // with_color stays the solid shorthand on the widened field.
  let solid = @slide.RunProperties::default().with_color(
    @units.RgbColor::new(0x10, 0x20, 0x30),
  )
  debug_inspect(solid.fill is Some(SolidFill(_)), content="true")
}

///|
test "rPr: unknown underline value collapses to None (graceful)" {
  let slide = @slide.Slide::parse(slide_with_rpr("<a:rPr u=\"weirdValue\"/>"))
  debug_inspect(rpr_of(slide).underline is None, content="true")
}

// --- character spacing (spc) — issue #7 ---

///|
test "rPr: spc attribute converts 1/100 pt to Pt" {
  let slide = @slide.Slide::parse(slide_with_rpr("<a:rPr spc=\"150\"/>"))
  debug_inspect(rpr_of(slide).character_spacing.unwrap(), content="Pt(1.5)")
}

///|
test "rPr: negative spc (tightening) parses" {
  let slide = @slide.Slide::parse(slide_with_rpr("<a:rPr spc=\"-50\"/>"))
  debug_inspect(rpr_of(slide).character_spacing.unwrap(), content="Pt(-0.5)")
}

///|
test "rPr: absent spc is None (behaviour unchanged)" {
  let slide = @slide.Slide::parse(slide_with_rpr("<a:rPr sz=\"2400\"/>"))
  debug_inspect(rpr_of(slide).character_spacing is None, content="true")
}

///|
test "rPr: spc survives a parse -> serialize -> parse round-trip" {
  let slide = @slide.Slide::parse(slide_with_rpr("<a:rPr spc=\"120\"/>"))
  let reparsed = @slide.Slide::parse(slide.serialize())
  debug_inspect(rpr_of(reparsed).character_spacing.unwrap(), content="Pt(1.2)")
}

///|
test "builder: with_character_spacing emits spc and round-trips" {
  let rp = @slide.RunProperties::default().with_character_spacing(Pt(2.0))
  let body = @slide.TextBody::of_styled_text("tracked", rp)
  let shape = @slide.AutoShape::textbox(
    id=2,
    name="T",
    x=Emu(0L),
    y=Emu(0L),
    cx=Emu(914_400L),
    cy=Emu(914_400L),
    "",
  ).with_text_body(body)
  // An empty base slide to drop the built shape onto.
  let base_xml = "<?xml version=\"1.0\"?>" +
    "<p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\" xmlns:r=\"" +
    off_rel_ns +
    "\"><p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>" +
    "</p:spTree></p:cSld></p:sld>"
  let slide = @slide.Slide::parse(@oxml.string_to_bytes(base_xml)).with_shape(
    AutoShape(shape),
  )
  let reparsed = @slide.Slide::parse(slide.serialize())
  debug_inspect(rpr_of(reparsed).character_spacing.unwrap(), content="Pt(2)")
}

// --- kerning (kern) + highlight ---

///|
test "rPr: kern attribute converts 1/100 pt to Pt" {
  let slide = @slide.Slide::parse(slide_with_rpr("<a:rPr kern=\"1200\"/>"))
  debug_inspect(rpr_of(slide).kerning.unwrap(), content="Pt(12)")
}

///|
test "rPr: absent kern is None" {
  let slide = @slide.Slide::parse(slide_with_rpr("<a:rPr sz=\"2400\"/>"))
  debug_inspect(rpr_of(slide).kerning is None, content="true")
}

///|
test "rPr: kern survives parse -> serialize -> parse" {
  let slide = @slide.Slide::parse(slide_with_rpr("<a:rPr kern=\"800\"/>"))
  let reparsed = @slide.Slide::parse(slide.serialize())
  debug_inspect(rpr_of(reparsed).kerning.unwrap(), content="Pt(8)")
}

///|
test "rPr: highlight colour parses into the typed field" {
  let slide = @slide.Slide::parse(
    slide_with_rpr(
      "<a:rPr><a:highlight><a:srgbClr val=\"FFFF00\"/></a:highlight></a:rPr>",
    ),
  )
  debug_inspect(
    rpr_of(slide).highlight.unwrap() ==
    @oxml.Color::srgb(@units.RgbColor::parse_hex("FFFF00")),
    content="true",
  )
}

///|
test "rPr: absent highlight is None" {
  let slide = @slide.Slide::parse(slide_with_rpr("<a:rPr/>"))
  debug_inspect(rpr_of(slide).highlight is None, content="true")
}

///|
test "builder: with_kerning + with_highlight emit and round-trip" {
  let rp = @slide.RunProperties::default()
    .with_kerning(Pt(10.0))
    .with_highlight(@units.RgbColor::new(0xFF, 0xCC, 0x00))
  let body = @slide.TextBody::of_styled_text("hi", rp)
  let shape = @slide.AutoShape::textbox(
    id=2,
    name="T",
    x=Emu(0L),
    y=Emu(0L),
    cx=Emu(914_400L),
    cy=Emu(914_400L),
    "",
  ).with_text_body(body)
  let base_xml = "<?xml version=\"1.0\"?>" +
    "<p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\" xmlns:r=\"" +
    off_rel_ns +
    "\"><p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>" +
    "</p:spTree></p:cSld></p:sld>"
  let slide = @slide.Slide::parse(@oxml.string_to_bytes(base_xml)).with_shape(
    AutoShape(shape),
  )
  let reparsed = @slide.Slide::parse(slide.serialize())
  let got = rpr_of(reparsed)
  debug_inspect(got.kerning.unwrap(), content="Pt(10)")
  debug_inspect(
    got.highlight.unwrap() ==
    @oxml.Color::srgb(@units.RgbColor::new(0xFF, 0xCC, 0x00)),
    content="true",
  )
}

// --- text outline (a:ln) + text effects (a:effectLst) ---

///|
test "rPr: text outline (a:ln) parses into the typed field" {
  let slide = @slide.Slide::parse(
    slide_with_rpr(
      "<a:rPr><a:ln w=\"12700\"><a:solidFill><a:srgbClr val=\"FF0000\"/></a:solidFill></a:ln></a:rPr>",
    ),
  )
  debug_inspect(
    rpr_of(slide).outline.unwrap().width.unwrap(),
    content="Emu(12700)",
  )
}

///|
test "rPr: text effects (a:effectLst glow) parse into the typed field" {
  let slide = @slide.Slide::parse(
    slide_with_rpr(
      "<a:rPr><a:effectLst><a:glow rad=\"63500\"><a:srgbClr val=\"FFC000\"/></a:glow></a:effectLst></a:rPr>",
    ),
  )
  debug_inspect(
    rpr_of(slide).text_effects.unwrap().glow.unwrap().rad,
    content="Emu(63500)",
  )
}

///|
test "rPr: absent outline / effects are None" {
  let slide = @slide.Slide::parse(slide_with_rpr("<a:rPr/>"))
  debug_inspect(rpr_of(slide).outline is None, content="true")
  debug_inspect(rpr_of(slide).text_effects is None, content="true")
}

///|
test "builder: with_text_outline + with_text_effects emit and round-trip" {
  let glow_fx = @oxml.EffectList::empty().with_glow(
    @oxml.Glow::new(
      Emu(63500L),
      @oxml.Color::srgb(@units.RgbColor::parse_hex("FFC000")),
    ),
  )
  let rp = @slide.RunProperties::default()
    .with_text_outline(thin_stroke())
    .with_text_effects(glow_fx)
  let body = @slide.TextBody::of_styled_text("fx", rp)
  let shape = @slide.AutoShape::textbox(
    id=2,
    name="T",
    x=Emu(0L),
    y=Emu(0L),
    cx=Emu(914_400L),
    cy=Emu(914_400L),
    "",
  ).with_text_body(body)
  let base_xml = "<?xml version=\"1.0\"?>" +
    "<p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\" xmlns:r=\"" +
    off_rel_ns +
    "\"><p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>" +
    "</p:spTree></p:cSld></p:sld>"
  let slide = @slide.Slide::parse(@oxml.string_to_bytes(base_xml)).with_shape(
    AutoShape(shape),
  )
  let reparsed = @slide.Slide::parse(slide.serialize())
  let got = rpr_of(reparsed)
  debug_inspect(got.outline.unwrap().width.unwrap(), content="Emu(12700)")
  debug_inspect(
    got.text_effects.unwrap().glow.unwrap().rad,
    content="Emu(63500)",
  )
}
