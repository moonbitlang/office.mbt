// Modified for office.mbt: follow the workspace warning conventions.
// @oxml.Color parser tests.

///|
/// Drive `parse_color_element` against the body of a `<wrapper>` element
/// whose payload is `inner`. The wrapper's outer namespace doesn't matter
/// — we just want the colour element + its modifier children.
fn parse_inner_color(inner : String) -> @oxml.Color raise @oxml.ColorError {
  let xml = "<wrapper xmlns:a=\"" +
    @oxml.drawing_ns +
    "\">" +
    inner +
    "</wrapper>"
  let r = @xml.XmlReader::new(xml)
  // consume <wrapper>
  let _ = r.next() catch {
    _ => raise MalformedColor("test wrapper open failed")
  }
  while true {
    let ev = r.next() catch {
      _ => raise MalformedColor("test wrapper inner failed")
    }
    match ev {
      Some(StartElement(name, attrs)) =>
        return @oxml.parse_color_element(r, name, attrs)
      Some(EndElement(_)) => raise MalformedColor("empty wrapper")
      Some(_) => ()
      None => raise MalformedColor("unexpected end of test wrapper")
    }
  }
  raise MalformedColor("unreachable")
}

// --- base colour kinds ---

///|
test "Color: srgbClr base" {
  let c = parse_inner_color("<a:srgbClr val=\"FF0000\"/>")
  match c.base {
    Srgb(rgb) => debug_inspect(rgb.to_hex(), content="\"FF0000\"")
    _ => fail("expected Srgb")
  }
  debug_inspect(c.transforms.length(), content="0")
}

///|
test "Color: schemeClr base" {
  let c = parse_inner_color("<a:schemeClr val=\"accent3\"/>")
  match c.base {
    Scheme(t) => debug_inspect(t is Accent3, content="true")
    _ => fail("expected Scheme")
  }
}

///|
test "Color: sysClr base with lastClr fallback" {
  let c = parse_inner_color("<a:sysClr val=\"windowText\" lastClr=\"000000\"/>")
  match c.base {
    Sys(s) => {
      debug_inspect(s.val, content="\"windowText\"")
      debug_inspect(s.last_clr.unwrap().to_hex(), content="\"000000\"")
    }
    _ => fail("expected Sys")
  }
}

///|
test "Color: hslClr base" {
  // hue: 1/60_000 deg, sat / lum: 1/1000 %
  let c = parse_inner_color(
    "<a:hslClr hue=\"7200000\" sat=\"50000\" lum=\"60000\"/>",
  )
  // 7_200_000 = 120 deg, 50_000 OOXML = 50%
  match c.base {
    Hsl(h) => {
      debug_inspect(h.hue, content="120")
      debug_inspect(h.saturation, content="50")
      debug_inspect(h.lightness, content="60")
    }
    _ => fail("expected Hsl")
  }
}

///|
test "Color: prstClr base preserves the preset name" {
  let c = parse_inner_color("<a:prstClr val=\"slateGray\"/>")
  match c.base {
    Preset(s) => debug_inspect(s, content="\"slateGray\"")
    _ => fail("expected Preset")
  }
}

///|
test "Color: scrgbClr base reads three percentages" {
  // 100% = 100_000 in OOXML 1/1000-percent units
  let c = parse_inner_color("<a:scrgbClr r=\"100000\" g=\"0\" b=\"50000\"/>")
  match c.base {
    Scrgb(r, g, b) => {
      debug_inspect(r, content="Percentage(100)")
      debug_inspect(g, content="Percentage(0)")
      debug_inspect(b, content="Percentage(50)")
    }
    _ => fail("expected Scrgb")
  }
}

// --- transforms ---

///|
test "Color: tint + shade transforms preserved in source order" {
  let c = parse_inner_color(
    "<a:schemeClr val=\"accent1\"><a:tint val=\"40000\"/><a:shade val=\"20000\"/></a:schemeClr>",
  )
  debug_inspect(c.transforms.length(), content="2")
  match c.transforms[0] {
    Tint(p) => debug_inspect(p, content="Percentage(40)")
    _ => fail("expected Tint")
  }
  match c.transforms[1] {
    Shade(p) => debug_inspect(p, content="Percentage(20)")
    _ => fail("expected Shade")
  }
}

///|
test "Color: every supported transform variant" {
  let c = parse_inner_color(
    "<a:srgbClr val=\"112233\">" +
    "<a:tint val=\"50000\"/>" +
    "<a:shade val=\"50000\"/>" +
    "<a:satMod val=\"75000\"/>" +
    "<a:lumMod val=\"60000\"/>" +
    "<a:alpha val=\"80000\"/>" +
    "</a:srgbClr>",
  )
  debug_inspect(c.transforms.length(), content="5")
  debug_inspect(c.transforms[0] is Tint(_), content="true")
  debug_inspect(c.transforms[1] is Shade(_), content="true")
  debug_inspect(c.transforms[2] is SatMod(_), content="true")
  debug_inspect(c.transforms[3] is LumMod(_), content="true")
  debug_inspect(c.transforms[4] is Alpha(_), content="true")
}

///|
test "Color: long-tail modifiers (hueMod, redMod, comp) silently dropped" {
  // These appear in real PPTX but we don't model them today. We still need
  // to consume the subtree without raising or leaking events.
  let c = parse_inner_color(
    "<a:srgbClr val=\"FF0000\">" +
    "<a:hueMod val=\"50000\"/>" +
    "<a:redMod val=\"40000\"/>" +
    "<a:comp/>" +
    "</a:srgbClr>",
  )
  debug_inspect(c.transforms.length(), content="0")
}

// --- error paths ---

///|
test "Color: unknown colour element rejected" {
  try parse_inner_color("<a:weirdClr val=\"x\"/>") catch {
    UnknownColorElement(_) => ()
    _ => fail("expected UnknownColorElement")
  } noraise {
    _ => fail("expected UnknownColorElement")
  }
}

///|
test "Color: srgbClr missing val rejected" {
  try parse_inner_color("<a:srgbClr/>") catch {
    MalformedColor(_) => ()
    _ => fail("expected MalformedColor")
  } noraise {
    _ => fail("expected MalformedColor")
  }
}

///|
test "Color: srgbClr with bad hex rejected" {
  try parse_inner_color("<a:srgbClr val=\"GG0000\"/>") catch {
    MalformedColor(_) => ()
    _ => fail("expected MalformedColor")
  } noraise {
    _ => fail("expected MalformedColor")
  }
}

///|
test "Color: schemeClr with unknown val rejected" {
  try parse_inner_color("<a:schemeClr val=\"weirdo\"/>") catch {
    MalformedColor(_) => ()
    _ => fail("expected MalformedColor")
  } noraise {
    _ => fail("expected MalformedColor")
  }
}

// --- convenience constructors ---

///|
test "Color::srgb / Color::scheme constructors" {
  let c1 = @oxml.Color::srgb(@units.RgbColor::parse_hex("ABCDEF"))
  debug_inspect(c1.base is Srgb(_), content="true")
  debug_inspect(c1.transforms.length(), content="0")
  let c2 = @oxml.Color::scheme(Accent4)
  debug_inspect(c2.base is Scheme(_), content="true")
}
