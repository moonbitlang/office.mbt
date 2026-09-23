// Modified for office.mbt: follow the workspace warning conventions.
// ParagraphProperties parser tests.

///|
/// Build a slide with one paragraph whose `<a:pPr>` body is `ppr_body`,
/// followed by a single trivial run so the paragraph isn't empty.
fn slide_with_ppr(ppr_body : String) -> FixedArray[Byte] {
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
    "<p:txBody><a:p>" +
    ppr_body +
    "<a:r><a:t>x</a:t></a:r></a:p></p:txBody>" +
    "</p:sp>" +
    "</p:spTree></p:cSld></p:sld>"
  @oxml.string_to_bytes(xml)
}

///|
fn para_of(s : @slide.Slide) -> @slide.Paragraph {
  match s.shapes[0] {
    AutoShape(sp) => sp.text_body.unwrap().paragraphs[0]
    _ => abort("expected AutoShape")
  }
}

///|
fn ppr_of(s : @slide.Slide) -> @slide.ParagraphProperties {
  para_of(s).properties
}

// --- attributes ---

///|
test "pPr: lvl level captured" {
  let slide = @slide.Slide::parse(slide_with_ppr("<a:pPr lvl=\"2\"/>"))
  debug_inspect(ppr_of(slide).level, content="2")
}

///|
test "pPr: missing lvl defaults to 0" {
  let slide = @slide.Slide::parse(slide_with_ppr("<a:pPr/>"))
  debug_inspect(ppr_of(slide).level, content="0")
}

///|
test "pPr: alignment values map to typed enum" {
  let cases = [
    ("l", @slide.TextAlignment::AlignLeft),
    ("ctr", AlignCenter),
    ("r", AlignRight),
    ("just", AlignJustify),
    ("justLow", AlignJustifyLow),
    ("dist", AlignDistributed),
    ("thaiDist", AlignThaiDistributed),
  ]
  for c in cases {
    let slide = @slide.Slide::parse(
      slide_with_ppr("<a:pPr algn=\"" + c.0 + "\"/>"),
    )
    debug_inspect(ppr_of(slide).alignment.unwrap() == c.1, content="true")
  }
}

///|
test "pPr: marL and indent (negative supported for hanging)" {
  let slide = @slide.Slide::parse(
    slide_with_ppr("<a:pPr marL=\"457200\" indent=\"-457200\"/>"),
  )
  let p = ppr_of(slide)
  debug_inspect(p.margin_left.unwrap(), content="Emu(457200)")
  debug_inspect(p.indent.unwrap(), content="Emu(-457200)")
}

///|
test "pPr: lnSpc percent form (spcPct, 1/1000 %)" {
  let slide = @slide.Slide::parse(
    slide_with_ppr(
      "<a:pPr><a:lnSpc><a:spcPct val=\"120000\"/></a:lnSpc></a:pPr>",
    ),
  )
  // 120000 OOXML units = 120 % line spacing.
  debug_inspect(
    ppr_of(slide).line_spacing,
    content="Some(Percent(Percentage(120)))",
  )
}

///|
test "pPr: lnSpc absolute form (spcPts, 1/100 pt)" {
  let slide = @slide.Slide::parse(
    slide_with_ppr("<a:pPr><a:lnSpc><a:spcPts val=\"1800\"/></a:lnSpc></a:pPr>"),
  )
  debug_inspect(ppr_of(slide).line_spacing, content="Some(Points(Pt(18)))")
}

///|
test "pPr: spcBef points + spcAft percent forms" {
  let slide = @slide.Slide::parse(
    slide_with_ppr(
      "<a:pPr>" +
      "<a:spcBef><a:spcPts val=\"6000\"/></a:spcBef>" +
      "<a:spcAft><a:spcPct val=\"50000\"/></a:spcAft>" +
      "</a:pPr>",
    ),
  )
  let p = ppr_of(slide)
  debug_inspect(p.space_before, content="Some(Points(Pt(60)))")
  debug_inspect(p.space_after, content="Some(Percent(Percentage(50)))")
}

///|
test "pPr: spacing round-trips (parse → serialize → parse)" {
  let xml = slide_with_ppr(
    "<a:pPr>" +
    "<a:lnSpc><a:spcPct val=\"150000\"/></a:lnSpc>" +
    "<a:spcBef><a:spcPts val=\"600\"/></a:spcBef>" +
    "<a:spcAft><a:spcPts val=\"1200\"/></a:spcAft>" +
    "</a:pPr>",
  )
  let s1 = @slide.Slide::parse(xml)
  let s2 = @slide.Slide::parse(s1.serialize())
  debug_inspect(ppr_of(s2) == ppr_of(s1), content="true")
  debug_inspect(ppr_of(s2).line_spacing is Some(Percent(_)), content="true")
}

///|
test "pPr: empty lnSpc (no choice child) raises" {
  try @slide.Slide::parse(slide_with_ppr("<a:pPr><a:lnSpc/></a:pPr>")) catch {
    _ => ()
  } noraise {
    _ => fail("expected an empty <a:lnSpc> to raise")
  }
}

///|
test "pPr: spacing builders (with_line_spacing / before / after)" {
  let para = @slide.Paragraph::of_text("hello")
    .with_line_spacing(Percent(Percentage(120.0)))
    .with_space_before(Points(Pt(6.0)))
    .with_space_after(Percent(Percentage(40.0)))
  let body = @slide.TextBody::of_paragraphs([para])
  let slide = @slide.Slide::parse(slide_with_ppr("<a:pPr/>")).map_shapes(s => {
    match s {
      AutoShape(sp) => AutoShape(sp.with_text_body(body))
      other => other
    }
  })
  let xml = @oxml.bytes_to_string(slide.serialize())
  debug_inspect(
    xml.find("<a:lnSpc><a:spcPct val=\"120000\"/></a:lnSpc>") is Some(_),
    content="true",
  )
  debug_inspect(
    xml.find("<a:spcBef><a:spcPts val=\"600\"/></a:spcBef>") is Some(_),
    content="true",
  )
  debug_inspect(
    xml.find("<a:spcAft><a:spcPct val=\"40000\"/></a:spcAft>") is Some(_),
    content="true",
  )
  // And the built spacing survives a reparse into the same model.
  let reparsed = @slide.Slide::parse(slide.serialize())
  debug_inspect(ppr_of(reparsed) == para.properties, content="true")
}

// --- bullets ---

///|
test "pPr: buNone explicit no-bullet" {
  let slide = @slide.Slide::parse(slide_with_ppr("<a:pPr><a:buNone/></a:pPr>"))
  debug_inspect(ppr_of(slide).bullet.unwrap() is BulNone, content="true")
}

///|
test "pPr: buChar carries the character" {
  let slide = @slide.Slide::parse(
    slide_with_ppr("<a:pPr><a:buChar char=\"•\"/></a:pPr>"),
  )
  match ppr_of(slide).bullet.unwrap() {
    Char(s) => debug_inspect(s, content="\"•\"")
    _ => fail("expected Char bullet")
  }
}

///|
test "pPr: buAutoNum captures type and startAt" {
  let slide = @slide.Slide::parse(
    slide_with_ppr(
      "<a:pPr><a:buAutoNum type=\"arabicPeriod\" startAt=\"3\"/></a:pPr>",
    ),
  )
  match ppr_of(slide).bullet.unwrap() {
    AutoNum(t, start) => {
      debug_inspect(t is ArabicPeriod, content="true")
      debug_inspect(start, content="3")
    }
    _ => fail("expected AutoNum bullet")
  }
}

///|
test "pPr: buAutoNum default startAt is 1" {
  let slide = @slide.Slide::parse(
    slide_with_ppr("<a:pPr><a:buAutoNum type=\"romanLcParenR\"/></a:pPr>"),
  )
  match ppr_of(slide).bullet.unwrap() {
    AutoNum(t, start) => {
      debug_inspect(t is RomanLcParenR, content="true")
      debug_inspect(start, content="1")
    }
    _ => fail("expected AutoNum bullet")
  }
}

///|
test "pPr: buAutoNum with unknown type rejected" {
  try
    @slide.Slide::parse(
      slide_with_ppr(
        "<a:pPr><a:buAutoNum type=\"thisIsNotASchemeAtAll\"/></a:pPr>",
      ),
    )
  catch {
    Malformed(_) => ()
    _ => fail("expected Malformed")
  } noraise {
    _ => fail("expected Malformed")
  }
}

///|
test "pPr: buBlip captures r:id" {
  let slide = @slide.Slide::parse(
    slide_with_ppr(
      "<a:pPr><a:buBlip><a:blip r:embed=\"rId7\"/></a:buBlip></a:pPr>",
    ),
  )
  match ppr_of(slide).bullet.unwrap() {
    Picture(rid) => debug_inspect(rid, content="\"rId7\"")
    _ => fail("expected Picture bullet")
  }
}

// --- absent / graceful ---

///|
test "pPr: missing attributes leave fields None" {
  let slide = @slide.Slide::parse(slide_with_ppr("<a:pPr/>"))
  let p = ppr_of(slide)
  debug_inspect(p.alignment is None, content="true")
  debug_inspect(p.margin_left is None, content="true")
  debug_inspect(p.indent is None, content="true")
  debug_inspect(p.line_spacing is None, content="true")
  debug_inspect(p.space_before is None, content="true")
  debug_inspect(p.space_after is None, content="true")
  debug_inspect(p.bullet is None, content="true")
}

///|
test "pPr: unknown algn value collapses to None" {
  let slide = @slide.Slide::parse(slide_with_ppr("<a:pPr algn=\"weird\"/>"))
  debug_inspect(ppr_of(slide).alignment is None, content="true")
}

///|
test "pPr: tabLst and other unmodelled children silently skipped" {
  let slide = @slide.Slide::parse(
    slide_with_ppr(
      "<a:pPr><a:tabLst><a:tab pos=\"914400\" algn=\"l\"/></a:tabLst></a:pPr>",
    ),
  )
  // Did not raise; bullet stays None since tabLst doesn't define one.
  debug_inspect(ppr_of(slide).bullet is None, content="true")
}

///|
test "AutoNumType::from_xml round-trips a representative spread" {
  let cases = [
    "arabicPeriod", "arabicParenBoth", "romanUcPeriod", "romanLcParenR", "alphaUcPeriod",
    "alphaLcParenBoth", "circleNumDbPlain", "ea1JpnKorPeriod", "hindiAlphaPeriod",
    "thaiNumParenBoth",
  ]
  for c in cases {
    debug_inspect(!(@slide.AutoNumType::from_xml(c) is None), content="true")
  }
  debug_inspect(
    @slide.AutoNumType::from_xml("notAScheme") is None,
    content="true",
  )
}

// --- rtl (right-to-left paragraph direction) ---

///|
test "pPr: rtl accepts both OOXML boolean spellings" {
  for raw in ["1", "true"] {
    let slide = @slide.Slide::parse(
      slide_with_ppr("<a:pPr rtl=\"" + raw + "\"/>"),
    )
    debug_inspect(ppr_of(slide).rtl, content="Some(true)")
  }
  for raw in ["0", "false"] {
    let slide = @slide.Slide::parse(
      slide_with_ppr("<a:pPr rtl=\"" + raw + "\"/>"),
    )
    debug_inspect(ppr_of(slide).rtl, content="Some(false)")
  }
}

///|
test "pPr: absent rtl inherits rather than defaulting to LTR" {
  let slide = @slide.Slide::parse(slide_with_ppr("<a:pPr lvl=\"1\"/>"))
  debug_inspect(ppr_of(slide).rtl, content="None")
}

///|
test "pPr: rtl round-trips (parse → serialize → parse)" {
  for want in [true, false] {
    let raw = if want { "1" } else { "0" }
    let s1 = @slide.Slide::parse(slide_with_ppr("<a:pPr rtl=\"" + raw + "\"/>"))
    let s2 = @slide.Slide::parse(s1.serialize())
    debug_inspect(ppr_of(s2).rtl == Some(want), content="true")
    debug_inspect(ppr_of(s2) == ppr_of(s1), content="true")
  }
}

///|
test "pPr: rtl alone is enough to emit a <a:pPr>" {
  // Guards `needs_p_pr` — a paragraph whose only non-default property is
  // rtl must still emit the wrapper instead of dropping the attribute.
  let s0 = @slide.Slide::parse(slide_with_ppr(""))
  debug_inspect(
    ppr_of(s0) == @slide.ParagraphProperties::default(),
    content="true",
  )
  let s1 = s0.map_shapes(sh => {
    match sh {
      AutoShape(sp) => {
        let body = sp.text_body.unwrap()
        AutoShape(
          sp.with_text_body({
            ..body,
            paragraphs: body.paragraphs.map(p => p.with_rtl(true)),
          }),
        )
      }
      other => other
    }
  })
  let s2 = @slide.Slide::parse(s1.serialize())
  debug_inspect(ppr_of(s2).rtl, content="Some(true)")
}

///|
test "Paragraph::with_rtl sets only the direction" {
  let p = @slide.Paragraph::of_text("שלום").with_rtl(true)
  debug_inspect(p.properties.rtl, content="Some(true)")
  // Everything else stays at its default so the builder composes.
  debug_inspect(
    p.properties ==
    { ..@slide.ParagraphProperties::default(), rtl: Some(true), },
    content="true",
  )
  debug_inspect(p.with_rtl(false).properties.rtl, content="Some(false)")
}

// --- endParaRPr (properties of the paragraph mark) ---

///|
/// A slide with one paragraph: a trivial run followed by `end_para` as
/// the paragraph's terminal `<a:endParaRPr>` (which is last per the spec,
/// so `slide_with_ppr` cannot place it).
fn slide_with_end_para_rpr(end_para : String) -> FixedArray[Byte] {
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\">" +
    "<p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>" +
    "<p:sp>" +
    "<p:nvSpPr><p:cNvPr id=\"2\" name=\"T\"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>" +
    "<p:spPr/>" +
    "<p:txBody><a:p><a:r><a:t>x</a:t></a:r>" +
    end_para +
    "</a:p></p:txBody>" +
    "</p:sp>" +
    "</p:spTree></p:cSld></p:sld>"
  @oxml.string_to_bytes(xml)
}

///|
test "endParaRPr: round-trips through serialize with its formatting" {
  let s1 = @slide.Slide::parse(
    slide_with_end_para_rpr(
      "<a:endParaRPr lang=\"ar-SA\" sz=\"2400\" b=\"1\"/>",
    ),
  )
  let s2 = @slide.Slide::parse(s1.serialize())
  debug_inspect(para_of(s2) == para_of(s1), content="true")
  let end = para_of(s2).end_run_properties.unwrap()
  debug_inspect(end.lang, content="\"ar-SA\"")
  debug_inspect(end.font_size, content="Some(Pt(24))")
  debug_inspect(end.bold, content="Some(true)")
}

///|
test "endParaRPr: absent stays None and is not emitted" {
  let s1 = @slide.Slide::parse(slide_with_ppr("<a:pPr/>"))
  debug_inspect(para_of(s1).end_run_properties, content="None")
  let s2 = @slide.Slide::parse(s1.serialize())
  debug_inspect(para_of(s2).end_run_properties, content="None")
}

///|
test "Paragraph::with_end_run_properties round-trips a built paragraph" {
  let end = @slide.RunProperties::default().with_font_size(Pt(32.0))
  let s0 = @slide.Slide::parse(slide_with_ppr(""))
  let s1 = s0.map_shapes(sh => {
    match sh {
      AutoShape(sp) => {
        let body = sp.text_body.unwrap()
        AutoShape(
          sp.with_text_body({
            ..body,
            paragraphs: body.paragraphs.map(p => p.with_end_run_properties(end)),
          }),
        )
      }
      other => other
    }
  })
  let s2 = @slide.Slide::parse(s1.serialize())
  debug_inspect(
    para_of(s2).end_run_properties.unwrap().font_size,
    content="Some(Pt(32))",
  )
}
