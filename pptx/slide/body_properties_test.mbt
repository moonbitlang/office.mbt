// Modified for office.mbt: follow the workspace warning conventions.
// BodyProperties + ListStyle parser tests.

///|
/// Build a slide with one auto-shape whose `<p:txBody>` body is
/// `tx_body_inner` (the part between `<p:txBody>` and `</p:txBody>`).
fn slide_with_txbody_inner(tx_body_inner : String) -> FixedArray[Byte] {
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
    "<p:txBody>" +
    tx_body_inner +
    "</p:txBody>" +
    "</p:sp>" +
    "</p:spTree></p:cSld></p:sld>"
  @oxml.string_to_bytes(xml)
}

///|
fn txbody_of(s : @slide.Slide) -> @slide.TextBody {
  match s.shapes[0] {
    AutoShape(sp) => sp.text_body.unwrap()
    _ => abort("expected AutoShape")
  }
}

// --- bodyPr ---

///|
test "bodyPr: anchor, wrap, vertical text" {
  let body = "<a:bodyPr wrap=\"square\" anchor=\"ctr\" vert=\"vert\"/>" +
    "<a:p><a:r><a:t>x</a:t></a:r></a:p>"
  let tb = txbody_of(@slide.Slide::parse(slide_with_txbody_inner(body)))
  let bp = tb.body_properties.unwrap()
  debug_inspect(bp.wrap.unwrap() is WrapSquare, content="true")
  debug_inspect(bp.anchor.unwrap() is AnchorCenter, content="true")
  debug_inspect(bp.vertical_text.unwrap() is VertVert, content="true")
}

///|
test "bodyPr: insets and rotation" {
  let body = "<a:bodyPr lIns=\"91440\" tIns=\"45720\" rIns=\"91440\"" +
    " bIns=\"45720\" rot=\"5400000\"/>" +
    "<a:p/>"
  let tb = txbody_of(@slide.Slide::parse(slide_with_txbody_inner(body)))
  let bp = tb.body_properties.unwrap()
  debug_inspect(bp.left_inset.unwrap(), content="Emu(91440)")
  debug_inspect(bp.top_inset.unwrap(), content="Emu(45720)")
  debug_inspect(bp.right_inset.unwrap(), content="Emu(91440)")
  debug_inspect(bp.bottom_inset.unwrap(), content="Emu(45720)")
  // 5_400_000 = 90 degrees (60000 per degree)
  debug_inspect(bp.rotation.unwrap(), content="Angle(90)")
}

///|
test "bodyPr: all 5 anchor values map distinctly" {
  let cases = [
    ("t", @slide.Anchor::AnchorTop),
    ("ctr", AnchorCenter),
    ("b", AnchorBottom),
    ("just", AnchorJustify),
    ("dist", AnchorDistributed),
  ]
  for c in cases {
    let body = "<a:bodyPr anchor=\"" + c.0 + "\"/><a:p/>"
    let tb = txbody_of(@slide.Slide::parse(slide_with_txbody_inner(body)))
    debug_inspect(
      tb.body_properties.unwrap().anchor.unwrap() == c.1,
      content="true",
    )
  }
}

///|
test "bodyPr: noAutofit / normAutofit / spAutoFit" {
  // noAutofit
  let b1 = "<a:bodyPr><a:noAutofit/></a:bodyPr><a:p/>"
  let tb1 = txbody_of(@slide.Slide::parse(slide_with_txbody_inner(b1)))
  debug_inspect(
    tb1.body_properties.unwrap().auto_fit.unwrap() is NoAutoFit,
    content="true",
  )

  // normAutofit with both attributes
  let b2 = "<a:bodyPr><a:normAutofit fontScale=\"90000\" lnSpcReduction=\"20000\"/></a:bodyPr><a:p/>"
  let tb2 = txbody_of(@slide.Slide::parse(slide_with_txbody_inner(b2)))
  match tb2.body_properties.unwrap().auto_fit.unwrap() {
    NormAutoFit(fs, lr) => {
      debug_inspect(fs, content="Percentage(90)")
      debug_inspect(lr, content="Percentage(20)")
    }
    _ => fail("expected NormAutoFit")
  }

  // spAutoFit
  let b3 = "<a:bodyPr><a:spAutoFit/></a:bodyPr><a:p/>"
  let tb3 = txbody_of(@slide.Slide::parse(slide_with_txbody_inner(b3)))
  debug_inspect(
    tb3.body_properties.unwrap().auto_fit.unwrap() is SpAutoFit,
    content="true",
  )
}

///|
test "bodyPr: normAutofit with missing attributes defaults to 100% / 0%" {
  let b = "<a:bodyPr><a:normAutofit/></a:bodyPr><a:p/>"
  let tb = txbody_of(@slide.Slide::parse(slide_with_txbody_inner(b)))
  match tb.body_properties.unwrap().auto_fit.unwrap() {
    NormAutoFit(fs, lr) => {
      debug_inspect(fs, content="Percentage(100)")
      debug_inspect(lr, content="Percentage(0)")
    }
    _ => fail("expected NormAutoFit")
  }
}

///|
test "bodyPr: absent leaves text body's body_properties = None" {
  let tb = txbody_of(
    @slide.Slide::parse(
      slide_with_txbody_inner("<a:p><a:r><a:t>x</a:t></a:r></a:p>"),
    ),
  )
  debug_inspect(tb.body_properties is None, content="true")
}

///|
test "bodyPr: prstTxWarp and other unmodelled children skipped" {
  let body = "<a:bodyPr><a:prstTxWarp prst=\"textArchUp\"><a:avLst/></a:prstTxWarp></a:bodyPr>" +
    "<a:p/>"
  let tb = txbody_of(@slide.Slide::parse(slide_with_txbody_inner(body)))
  // Parsed without raising; warp body intentionally not yet modelled.
  debug_inspect(tb.body_properties.unwrap().auto_fit is None, content="true")
}

// --- lstStyle ---

///|
test "lstStyle: defPPr and lvl1pPr through lvl9pPr in order" {
  let body = "<a:lstStyle>" +
    "<a:defPPr><a:pPr/></a:defPPr>" + // defPPr's child is the pPr element body
    "<a:lvl1pPr algn=\"l\"/>" +
    "<a:lvl3pPr algn=\"ctr\"/>" +
    "<a:lvl9pPr algn=\"r\"/>" +
    "</a:lstStyle>" +
    "<a:p/>"
  let tb = txbody_of(@slide.Slide::parse(slide_with_txbody_inner(body)))
  let ls = tb.list_style.unwrap()
  debug_inspect(ls.level_props.length(), content="9")
  debug_inspect(
    ls.level_props[0].unwrap().alignment.unwrap() is AlignLeft,
    content="true",
  )
  debug_inspect(ls.level_props[1] is None, content="true") // lvl2pPr absent
  debug_inspect(
    ls.level_props[2].unwrap().alignment.unwrap() is AlignCenter,
    content="true",
  )
  debug_inspect(
    ls.level_props[8].unwrap().alignment.unwrap() is AlignRight,
    content="true",
  )
}

///|
test "lstStyle: empty body yields nine None level slots" {
  let body = "<a:lstStyle/><a:p/>"
  let tb = txbody_of(@slide.Slide::parse(slide_with_txbody_inner(body)))
  let ls = tb.list_style.unwrap()
  debug_inspect(ls.level_props.length(), content="9")
  for slot in ls.level_props {
    debug_inspect(slot is None, content="true")
  }
  debug_inspect(ls.default_props is None, content="true")
}

///|
test "lstStyle: absent leaves list_style = None" {
  let tb = txbody_of(
    @slide.Slide::parse(
      slide_with_txbody_inner("<a:p><a:r><a:t>x</a:t></a:r></a:p>"),
    ),
  )
  debug_inspect(tb.list_style is None, content="true")
}

///|
test "lstStyle: lvl-level pPr carries bullet config" {
  let body = "<a:lstStyle>" +
    "<a:lvl1pPr><a:buChar char=\"-\"/></a:lvl1pPr>" +
    "</a:lstStyle>" +
    "<a:p/>"
  let tb = txbody_of(@slide.Slide::parse(slide_with_txbody_inner(body)))
  let p1 = tb.list_style.unwrap().level_props[0].unwrap()
  match p1.bullet.unwrap() {
    Char(s) => debug_inspect(s, content="\"-\"")
    _ => fail("expected Char bullet at lvl1")
  }
}

// --- combined ---

///|
test "txBody: bodyPr + lstStyle + paragraphs coexist in source order" {
  let body = "<a:bodyPr anchor=\"t\"/>" +
    "<a:lstStyle><a:lvl1pPr algn=\"ctr\"/></a:lstStyle>" +
    "<a:p><a:r><a:t>One</a:t></a:r></a:p>" +
    "<a:p><a:r><a:t>Two</a:t></a:r></a:p>"
  let tb = txbody_of(@slide.Slide::parse(slide_with_txbody_inner(body)))
  debug_inspect(
    tb.body_properties.unwrap().anchor.unwrap() is AnchorTop,
    content="true",
  )
  debug_inspect(
    tb.list_style.unwrap().level_props[0].unwrap().alignment.unwrap()
    is AlignCenter,
    content="true",
  )
  debug_inspect(tb.paragraphs.length(), content="2")
  debug_inspect(tb.plain_text(), content="\"One\\nTwo\"")
}
