// Modified for office.mbt: follow the workspace warning conventions.
// Tests for the typed slide background (`<p:bg>`).

///|
/// Wrap a `<p:cSld>` body (the `<p:bg>` plus a minimal empty spTree) into a
/// parseable `<p:sld>`.
fn slide_with_bg(bg : String) -> FixedArray[Byte] {
  let xml = "<?xml version=\"1.0\"?><p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\"><p:cSld>" +
    bg +
    "<p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr/></p:spTree></p:cSld></p:sld>"
  @oxml.string_to_bytes(xml)
}

// --- parse ---

///|
test "background: parse <p:bgRef> into StyleReference" {
  let slide = @slide.Slide::parse(
    slide_with_bg(
      "<p:bg><p:bgRef idx=\"1001\"><a:schemeClr val=\"bg1\"/></p:bgRef></p:bg>",
    ),
  )
  match slide.background {
    Some(StyleReference(idx, color)) => {
      debug_inspect(idx, content="1001")
      debug_inspect(color.base is Scheme(_), content="true")
    }
    _ => fail("expected StyleReference background")
  }
}

///|
test "background: parse <p:bgPr> solid fill" {
  let slide = @slide.Slide::parse(
    slide_with_bg(
      "<p:bg><p:bgPr><a:solidFill><a:srgbClr val=\"FF0000\"/></a:solidFill>" +
      "<a:effectLst/></p:bgPr></p:bg>",
    ),
  )
  match slide.background {
    Some(Properties(p)) => {
      debug_inspect(p.shade_to_title, content="false")
      debug_inspect(p.fill is Some(SolidFill(_)), content="true")
    }
    _ => fail("expected Properties background")
  }
}

///|
test "background: shadeToTitle attribute is read" {
  let slide = @slide.Slide::parse(
    slide_with_bg(
      "<p:bg><p:bgPr shadeToTitle=\"1\"><a:noFill/></p:bgPr></p:bg>",
    ),
  )
  match slide.background {
    Some(Properties(p)) => {
      debug_inspect(p.shade_to_title, content="true")
      debug_inspect(p.fill is Some(NoFill), content="true")
    }
    _ => fail("expected Properties background")
  }
}

///|
test "background: unmodelled grpFill is preserved (ADR-004), fill stays None" {
  let slide = @slide.Slide::parse(
    slide_with_bg("<p:bg><p:bgPr><a:grpFill/></p:bgPr></p:bg>"),
  )
  match slide.background {
    Some(Properties(p)) => {
      debug_inspect(p.fill is None, content="true")
      debug_inspect(p.extension.length(), content="1")
      debug_inspect(p.extension[0].name.local_name, content="\"grpFill\"")
    }
    _ => fail("expected Properties background")
  }
}

///|
test "background: absent <p:bg> reads as None" {
  let slide = @slide.Slide::parse(slide_with_bg(""))
  debug_inspect(slide.background is None, content="true")
}

// --- round-trip (parse → serialize → parse via Eq) ---

///|
test "background: bgPr solid-fill round-trips" {
  let bytes = slide_with_bg(
    "<p:bg><p:bgPr><a:solidFill><a:srgbClr val=\"112233\"/></a:solidFill>" +
    "</p:bgPr></p:bg>",
  )
  let s0 = @slide.Slide::parse(bytes)
  let s1 = @slide.Slide::parse(s0.serialize())
  debug_inspect(s1.background == s0.background, content="true")
}

///|
test "background: bgRef round-trips" {
  let bytes = slide_with_bg(
    "<p:bg><p:bgRef idx=\"1001\"><a:schemeClr val=\"bg2\"/></p:bgRef></p:bg>",
  )
  let s0 = @slide.Slide::parse(bytes)
  let s1 = @slide.Slide::parse(s0.serialize())
  debug_inspect(s1.background == s0.background, content="true")
}

///|
test "background: grpFill round-trips losslessly" {
  let bytes = slide_with_bg("<p:bg><p:bgPr><a:grpFill/></p:bgPr></p:bg>")
  let s0 = @slide.Slide::parse(bytes)
  let s1 = @slide.Slide::parse(s0.serialize())
  debug_inspect(s1.background == s0.background, content="true")
}

///|
test "background: <p:bg> serialises before <p:spTree>" {
  let bytes = slide_with_bg(
    "<p:bg><p:bgPr><a:solidFill><a:srgbClr val=\"FF0000\"/></a:solidFill>" +
    "</p:bgPr></p:bg>",
  )
  let slide = @slide.Slide::parse(bytes)
  let xml = @oxml.bytes_to_string(slide.serialize())
  let bg_at = xml.find("<p:bg>").unwrap()
  let sptree_at = xml.find("<p:spTree>").unwrap()
  debug_inspect(bg_at >= 0, content="true")
  debug_inspect(bg_at < sptree_at, content="true")
}

// --- builders ---

///|
test "background: Slide::with_background sets a solid-fill bgPr" {
  let slide = @slide.Slide::parse(slide_with_bg("")).with_background(
    SolidFill(@oxml.Color::srgb(@units.RgbColor::new(0x11, 0x66, 0xCC))),
  )
  match slide.background {
    Some(Properties(p)) =>
      debug_inspect(p.fill is Some(SolidFill(_)), content="true")
    _ => fail("expected Properties background")
  }
  // …and it survives serialisation.
  let s1 = @slide.Slide::parse(slide.serialize())
  debug_inspect(s1.background == slide.background, content="true")
}

///|
test "background: with_background_ref / without_background" {
  let base = @slide.Slide::parse(slide_with_bg(""))
  let ref_slide = base.with_background_ref(1002, @oxml.Color::scheme(Bg1))
  match ref_slide.background {
    Some(StyleReference(idx, _)) => debug_inspect(idx, content="1002")
    _ => fail("expected StyleReference background")
  }
  // Clearing yields no background.
  debug_inspect(
    ref_slide.without_background().background is None,
    content="true",
  )
}

///|
test "BackgroundProperties::of_fill wraps the fill with defaults" {
  let fill = @oxml.Fill::SolidFill(
    @oxml.Color::srgb(@units.RgbColor::new(0x10, 0x20, 0x30)),
  )
  let p = @slide.BackgroundProperties::of_fill(fill)
  debug_inspect(p.fill == Some(fill), content="true")
  debug_inspect(p.shade_to_title, content="false")
  debug_inspect(p.effects is None, content="true")
  debug_inspect(p.extension.length(), content="0")
}
